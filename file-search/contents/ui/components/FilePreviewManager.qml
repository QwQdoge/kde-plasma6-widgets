import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support
import "../js/utils.js" as Utils

QtObject {
    id: manager

    property string cacheBase: ""
    property var cache: ({})
    property var cacheOrder: []
    property var requests: ({})
    property var pathTokens: ({})
    property var activeSources: ({})
    property var queuedPaths: []
    property int activeCount: 0
    property int serial: 0
    readonly property int maximumConcurrentRequests: 1
    readonly property int maximumQueuedPaths: 8
    readonly property int cacheLimit: 32
    readonly property int successCacheTtlMs: 30000
    readonly property int failureCacheTtlMs: 5000
    readonly property int watchdogMs: 15000

    function encodedArgument(value) {
        return encodeURIComponent(String(value || "")).replace(/!/g, "%21").replace(/'/g, "%27").replace(/\(/g, "%28").replace(/\)/g, "%29").replace(/\*/g, "%2A");
    }

    function isLocalPath(path) {
        var value = String(path || "");
        if (!value.startsWith("/") || /[\x00-\x1f\x7f]/.test(value))
            return false;
        return true;
    }

    function touchCache(path) {
        var order = cacheOrder.slice();
        var oldIndex = order.indexOf(path);
        if (oldIndex !== -1)
            order.splice(oldIndex, 1);
        order.push(path);
        while (order.length > cacheLimit) {
            var evicted = order.shift();
            delete cache[evicted];
        }
        cacheOrder = order;
    }

    function cachedResult(path) {
        var entry = cache[path];
        if (!entry)
            return null;
        var ttl = entry.success ? successCacheTtlMs : failureCacheTtlMs;
        if (Date.now() - entry.cachedAt >= ttl) {
            delete cache[path];
            return null;
        }
        touchCache(path);
        return entry.path;
    }

    function requestPreview(path, callback) {
        path = String(path || "");
        if (!isLocalPath(path) || !cacheBase) {
            if (callback)
                callback("");
            return "";
        }

        var cached = cachedResult(path);
        if (cached !== null) {
            if (callback)
                callback(cached);
            return "";
        }

        serial++;
        var token = "preview_" + serial;
        requests[token] = {
            "path": path,
            "callback": callback || null
        };
        var listeners = pathTokens[path] || [];
        listeners.push(token);
        pathTokens[path] = listeners;

        if (!activeSources[path] && queuedPaths.indexOf(path) === -1) {
            if (queuedPaths.length >= maximumQueuedPaths)
                failPath(queuedPaths.shift());
            queuedPaths.push(path);
        }
        pump();
        return token;
    }

    function cancel(token) {
        var request = requests[token];
        if (!request)
            return;
        var path = request.path;
        delete requests[token];
        var listeners = (pathTokens[path] || []).filter(function (candidate) {
            return candidate !== token;
        });
        if (listeners.length > 0) {
            pathTokens[path] = listeners;
            return;
        }
        delete pathTokens[path];
        var queueIndex = queuedPaths.indexOf(path);
        if (queueIndex !== -1)
            queuedPaths.splice(queueIndex, 1);
        var source = activeSources[path];
        if (source) {
            delete activeSources[path];
            activeCount = Math.max(0, activeCount - 1);
            executor.disconnectSource(source);
            pump();
        }
    }

    function cancelAll() {
        var sources = Object.keys(activeSources);
        for (var i = 0; i < sources.length; i++)
            executor.disconnectSource(activeSources[sources[i]]);
        activeSources = ({});
        activeCount = 0;
        queuedPaths = [];
        requests = ({});
        pathTokens = ({});
        watchdog.stop();
    }

    function failPath(path) {
        finishPath(path, "", false);
    }

    function finishPath(path, previewPath, success) {
        var source = activeSources[path];
        if (source) {
            delete activeSources[path];
            activeCount = Math.max(0, activeCount - 1);
            executor.disconnectSource(source);
        }
        cache[path] = {
            "path": previewPath,
            "cachedAt": Date.now(),
            "success": success
        };
        touchCache(path);
        var listeners = pathTokens[path] || [];
        delete pathTokens[path];
        for (var i = 0; i < listeners.length; i++) {
            var token = listeners[i];
            var request = requests[token];
            delete requests[token];
            if (request && request.callback)
                request.callback(previewPath);
        }
        if (activeCount === 0)
            watchdog.stop();
        pump();
    }

    function helperPath() {
        var path = Qt.resolvedUrl("../../tools/thumbnailer.py").toString();
        return path.indexOf("file://") === 0 ? path.replace(/^file:\/\/\/?/, "/") : path;
    }

    function startPath(path) {
        var sourceEncoded = encodedArgument(path);
        var cacheEncoded = encodedArgument(cacheBase);
        if (!/^[A-Za-z0-9._~%\-]+$/.test(sourceEncoded) || !/^[A-Za-z0-9._~%\-]+$/.test(cacheEncoded)) {
            failPath(path);
            return;
        }
        var key = Qt.md5("file://" + encodeURI(path));
        var command = "exec python3 " + Utils.shellEscape(helperPath()) + " --source-encoded=" + sourceEncoded + " --cache-encoded=" + cacheEncoded + " --cache-key=" + key;
        var source = command + " # file_preview_" + (++serial);
        activeSources[path] = source;
        activeCount++;
        executor.connectSource(source);
        if (!watchdog.running)
            watchdog.start();
    }

    function pump() {
        while (activeCount < maximumConcurrentRequests && queuedPaths.length > 0) {
            var path = queuedPaths.shift();
            if (pathTokens[path] && pathTokens[path].length > 0)
                startPath(path);
        }
    }

    function pathForSource(source) {
        var paths = Object.keys(activeSources);
        for (var i = 0; i < paths.length; i++) {
            if (activeSources[paths[i]] === source)
                return paths[i];
        }
        return "";
    }

    property Plasma5Support.DataSource executor: Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            var exitCode = data["exit code"];
            if (exitCode === undefined)
                return;
            var path = manager.pathForSource(source);
            if (!path) {
                disconnectSource(source);
                return;
            }
            var previewPath = "";
            if (Number(exitCode) === 0) {
                var lines = String(data["stdout"] || "").split("\n");
                for (var i = lines.length - 1; i >= 0; i--) {
                    if (lines[i].startsWith("READY:")) {
                        var candidate = lines[i].substring(6).trim();
                        if (candidate.startsWith(manager.cacheBase + "/") && !/[\x00-\x1f\x7f]/.test(candidate))
                            previewPath = candidate;
                        break;
                    }
                }
            }
            manager.finishPath(path, previewPath, previewPath.length > 0);
        }
    }

    property Timer watchdog: Timer {
        interval: manager.watchdogMs
        repeat: false
        onTriggered: {
            var paths = Object.keys(manager.activeSources);
            for (var i = 0; i < paths.length; i++)
                manager.failPath(paths[i]);
        }
    }

    Component.onDestruction: cancelAll()
}
