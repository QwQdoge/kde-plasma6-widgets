import QtQuick
import "../js/PreviewUtils.js" as PreviewUtils

QtObject {
    id: resolver

    required property var manager
    property string fileUrl: ""
    property string category: ""
    property bool active: false
    property var settings: ({})
    property string freedesktopThumbnailBase: ""
    property string source: ""
    property int requestGeneration: 0
    property string requestToken: ""

    function cancelCurrentRequest() {
        if (requestToken && manager && manager.cancel)
            manager.cancel(requestToken);
        requestToken = "";
    }

    function refresh() {
        cancelCurrentRequest();
        var generation = ++requestGeneration;
        source = "";
        if (!active || !PreviewUtils.isPreviewAvailable(fileUrl, category, settings))
            return;

        var immediate = PreviewUtils.getPreviewSource(fileUrl, true, settings, freedesktopThumbnailBase, category);
        var ext = PreviewUtils.getExtension(fileUrl);
        if (PreviewUtils.isImageExtension(ext)) {
            source = immediate;
            return;
        }

        source = immediate;
        var path = PreviewUtils.getLocalPreviewPath(fileUrl);
        if (!path || !manager || !manager.requestPreview)
            return;
        requestToken = manager.requestPreview(path, function (previewPath) {
            if (generation !== requestGeneration || !active)
                return;
            requestToken = "";
            source = previewPath ? PreviewUtils.toLocalFileUrl(previewPath) + "?v=" + generation : immediate;
        });
    }

    onFileUrlChanged: refresh()
    onCategoryChanged: refresh()
    onActiveChanged: refresh()
    onSettingsChanged: refresh()
    Component.onDestruction: {
        requestGeneration++;
        cancelCurrentRequest();
    }
}
