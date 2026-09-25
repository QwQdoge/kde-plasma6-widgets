import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.ksysguard.sensors as Sensors
import org.kde.kitemmodels as KItemModels
import org.kde.ksysguard.process as Process

PlasmoidItem {
    id: root

    implicitWidth: 360
    implicitHeight: 560

    readonly property int updateInterval: Math.max(500, Number(Plasmoid.configuration.updateInterval) || 1000)
    readonly property int historyLength: Math.max(20, Number(Plasmoid.configuration.historyLength) || 60)

    readonly property bool showCpu: Plasmoid.configuration.showCpu !== false
    readonly property bool showMemory: Plasmoid.configuration.showMemory !== false
    readonly property bool showGpu: Plasmoid.configuration.showGpu !== false
    readonly property bool showNetwork: Plasmoid.configuration.showNetwork !== false
    readonly property bool showDisk: Plasmoid.configuration.showDisk !== false
    readonly property bool showTopApps: Plasmoid.configuration.showTopApps !== false
    readonly property string topAppMetric: String(Plasmoid.configuration.topAppMetric || "cpu")
    readonly property int topAppCount: Math.max(1, Math.min(8, Number(Plasmoid.configuration.topAppCount) || 3))

    property var cpuHistory: []
    property var memoryHistory: []
    property var gpuHistory: []
    property var networkDownHistory: []
    property var networkUpHistory: []
    property var diskReadHistory: []
    property var diskWriteHistory: []
    property var topApplications: []

    property string gpuId: ""
    property string gpuName: ""
    property bool sensorTreeDirty: false

    readonly property real cpuUsage: numberFrom(cpuUsageSensor)
    readonly property real cpuFrequency: numberFrom(cpuFrequencySensor)
    readonly property real cpuTemperature: positiveNumberFrom(cpuTemperatureSensor)

    readonly property real memoryUsed: numberFrom(memoryUsedSensor)
    readonly property real memoryTotal: numberFrom(memoryTotalSensor)
    readonly property real memoryPercent: memoryTotal > 0 ? memoryUsed / memoryTotal * 100 : NaN

    readonly property real gpuUsage: numberFrom(gpuUsageSensor)
    readonly property real gpuTemperature: positiveNumberFrom(gpuTemperatureSensor)
    readonly property real gpuVramUsed: numberFrom(gpuVramUsedSensor)
    readonly property real gpuVramTotal: numberFrom(gpuVramTotalSensor)

    readonly property real networkDown: numberFrom(networkDownSensor)
    readonly property real networkUp: numberFrom(networkUpSensor)

    readonly property real diskRead: numberFrom(diskReadSensor)
    readonly property real diskWrite: numberFrom(diskWriteSensor)
    readonly property real diskUsedPercent: numberFrom(diskUsedPercentSensor)

    readonly property real uptimeSeconds: numberFrom(uptimeSensor)

    readonly property bool systemDataReady:
        !isNaN(cpuUsage) || !isNaN(memoryPercent) || !isNaN(networkDown) || !isNaN(diskRead)

    function numberFrom(sensor) {
        if (!sensor || sensor.status !== Sensors.Sensor.Ready || sensor.value === undefined || sensor.value === null)
            return NaN;
        var value = Number(sensor.value);
        return isFinite(value) ? value : NaN;
    }

    function positiveNumberFrom(sensor) {
        var value = numberFrom(sensor);
        return !isNaN(value) && value > 0 ? value : NaN;
    }

    function percentText(value) {
        return isNaN(value) ? "—" : Math.round(value) + "%";
    }

    function formatFrequency(mhz) {
        if (isNaN(mhz) || mhz <= 0)
            return "";
        return mhz >= 1000 ? (mhz / 1000).toFixed(2) + " GHz" : Math.round(mhz) + " MHz";
    }

    function formatTemperature(value) {
        return isNaN(value) ? "" : Math.round(value) + "°C";
    }

    function formatBytes(value) {
        if (isNaN(value) || value < 0)
            return "—";
        var units = ["B", "KiB", "MiB", "GiB", "TiB"];
        var scaled = value;
        var index = 0;
        while (scaled >= 1024 && index < units.length - 1) {
            scaled /= 1024;
            ++index;
        }
        var digits = scaled >= 100 ? 0 : scaled >= 10 ? 1 : 2;
        return scaled.toFixed(digits) + " " + units[index];
    }

    function formatRate(value) {
        if (isNaN(value) || value < 0)
            return "—";
        return formatBytes(value) + "/s";
    }

    function formatUptime(seconds) {
        if (isNaN(seconds) || seconds < 0)
            return "";
        var totalMinutes = Math.floor(seconds / 60);
        var days = Math.floor(totalMinutes / 1440);
        var hours = Math.floor((totalMinutes % 1440) / 60);
        var minutes = totalMinutes % 60;
        if (days > 0)
            return days + "d " + hours + "h";
        if (hours > 0)
            return hours + "h " + minutes + "m";
        return minutes + "m";
    }

    function appendHistory(history, value) {
        if (isNaN(value))
            return history;
        var next = history.slice();
        next.push(value);
        while (next.length > historyLength)
            next.shift();
        return next;
    }

    function sample() {
        if (showCpu)
            cpuHistory = appendHistory(cpuHistory, cpuUsage);
        if (showMemory)
            memoryHistory = appendHistory(memoryHistory, memoryPercent);
        if (showGpu && gpuId.length > 0)
            gpuHistory = appendHistory(gpuHistory, gpuUsage);
        if (showNetwork) {
            networkDownHistory = appendHistory(networkDownHistory, networkDown);
            networkUpHistory = appendHistory(networkUpHistory, networkUp);
        }
        if (showDisk) {
            diskReadHistory = appendHistory(diskReadHistory, diskRead);
            diskWriteHistory = appendHistory(diskWriteHistory, diskWrite);
        }
    }

    function discoverGpu() {
        var rowCount = flatSensors.rowCount();
        var firstId = "";
        var firstName = "";
        for (var row = 0; row < rowCount; ++row) {
            var index = flatSensors.index(row, 0);
            var sensorId = flatSensors.data(index, Sensors.SensorTreeModel.SensorId);
            if (!sensorId)
                continue;
            var match = String(sensorId).match(/^gpu\/(gpu\d+)\/usage$/);
            if (!match)
                continue;
            firstId = match[1];
            firstName = String(flatSensors.data(index, Qt.DisplayRole) || "").replace(/\s*Usage\s*$/i, "");
            break;
        }
        gpuId = firstId;
        gpuName = firstName.length > 0 ? firstName : (firstId.length > 0 ? "GPU" : "");
    }

    function applicationColumn(attribute) {
        return appModel.enabledAttributes.indexOf(attribute);
    }

    function applicationValue(row, attribute, fallback) {
        var column = applicationColumn(attribute);
        if (column < 0)
            return fallback;
        var value = appModel.data(appModel.index(row, column), Process.ProcessDataModel.Value);
        return value === undefined || value === null ? fallback : value;
    }

    function applicationPids(row) {
        if (appModel.enabledAttributes.length === 0)
            return [];
        var value = appModel.data(appModel.index(row, 0), Process.ProcessDataModel.PIDs);
        return value || [];
    }

    function rebuildTopApplications() {
        if (!showTopApps || !appModel.available) {
            topApplications = [];
            return;
        }

        var rows = [];
        var count = appModel.rowCount();
        for (var row = 0; row < count; ++row) {
            var name = String(applicationValue(row, "appName", ""));
            var pids = applicationPids(row);
            if (name.length === 0 || pids.length === 0)
                continue;

            var cpu = Number(applicationValue(row, "usage", 0)) || 0;
            var memory = (Number(applicationValue(row, "memory", 0)) || 0) * 1024;
            var down = Number(applicationValue(row, "netInbound", 0)) || 0;
            var up = Number(applicationValue(row, "netOutbound", 0)) || 0;
            var read = Number(applicationValue(row, "ioCharactersActuallyReadRate", 0)) || 0;
            var write = Number(applicationValue(row, "ioCharactersActuallyWrittenRate", 0)) || 0;

            var metricValue = cpu;
            var valueText = cpu.toFixed(1) + "%";
            if (topAppMetric === "memory") {
                metricValue = memory;
                valueText = formatBytes(memory);
            } else if (topAppMetric === "network") {
                metricValue = down + up;
                valueText = formatRate(metricValue);
            } else if (topAppMetric === "disk") {
                metricValue = read + write;
                valueText = formatRate(metricValue);
            }

            rows.push({
                name: name,
                iconName: String(applicationValue(row, "iconName", "application-x-executable")),
                metricValue: metricValue,
                valueText: valueText,
                cpuText: cpu.toFixed(1) + "%",
                memoryText: formatBytes(memory)
            });
        }

        rows.sort(function(a, b) { return b.metricValue - a.metricValue; });
        topApplications = rows.slice(0, topAppCount);
    }

    function topMetricLabel() {
        switch (topAppMetric) {
        case "memory": return i18n("Memory");
        case "network": return i18n("Network");
        case "disk": return i18n("Disk");
        default: return i18n("CPU");
        }
    }

    Component.onCompleted: {
        discoverGpu();
        sample();
        rebuildTopApplications();
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    Timer {
        interval: Math.max(1500, root.updateInterval * 2)
        repeat: true
        running: root.visible && root.showTopApps
        triggeredOnStart: true
        onTriggered: root.rebuildTopApplications()
    }

    Timer {
        id: gpuDiscoveryDebounce
        interval: 350
        repeat: false
        onTriggered: root.discoverGpu()
    }

    Sensors.Sensor {
        id: cpuUsageSensor
        sensorId: "cpu/all/usage"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showCpu
    }

    Sensors.Sensor {
        id: cpuFrequencySensor
        sensorId: "cpu/all/averageFrequency"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showCpu
    }

    Sensors.Sensor {
        id: cpuTemperatureSensor
        sensorId: "cpu/all/averageTemperature"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showCpu
    }

    Sensors.Sensor {
        id: memoryUsedSensor
        sensorId: "memory/physical/used"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showMemory
    }

    Sensors.Sensor {
        id: memoryTotalSensor
        sensorId: "memory/physical/total"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showMemory
    }

    Sensors.Sensor {
        id: networkDownSensor
        sensorId: "network/all/download"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showNetwork
    }

    Sensors.Sensor {
        id: networkUpSensor
        sensorId: "network/all/upload"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showNetwork
    }

    Sensors.Sensor {
        id: diskReadSensor
        sensorId: "disk/all/read"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showDisk
    }

    Sensors.Sensor {
        id: diskWriteSensor
        sensorId: "disk/all/write"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showDisk
    }

    Sensors.Sensor {
        id: diskUsedPercentSensor
        sensorId: "disk/all/usedPercent"
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showDisk
    }

    Sensors.Sensor {
        id: uptimeSensor
        sensorId: "os/system/uptime"
        updateRateLimit: Math.max(5000, root.updateInterval)
        enabled: root.visible
    }

    Sensors.SensorTreeModel {
        id: sensorTree
    }

    KItemModels.KDescendantsProxyModel {
        id: flatSensors
        model: sensorTree
    }

    Connections {
        target: flatSensors
        function onRowsInserted() { gpuDiscoveryDebounce.restart(); }
        function onRowsRemoved() { gpuDiscoveryDebounce.restart(); }
        function onModelReset() { gpuDiscoveryDebounce.restart(); }
        function onLayoutChanged() { gpuDiscoveryDebounce.restart(); }
    }

    Sensors.Sensor {
        id: gpuUsageSensor
        sensorId: root.gpuId.length > 0 ? "gpu/" + root.gpuId + "/usage" : ""
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showGpu && root.gpuId.length > 0
    }

    Sensors.Sensor {
        id: gpuTemperatureSensor
        sensorId: root.gpuId.length > 0 ? "gpu/" + root.gpuId + "/temperature" : ""
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showGpu && root.gpuId.length > 0
    }

    Sensors.Sensor {
        id: gpuVramUsedSensor
        sensorId: root.gpuId.length > 0 ? "gpu/" + root.gpuId + "/usedVram" : ""
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showGpu && root.gpuId.length > 0
    }

    Sensors.Sensor {
        id: gpuVramTotalSensor
        sensorId: root.gpuId.length > 0 ? "gpu/" + root.gpuId + "/totalVram" : ""
        updateRateLimit: root.updateInterval
        enabled: root.visible && root.showGpu && root.gpuId.length > 0
    }

    Process.ApplicationDataModel {
        id: appModel

        property var requiredAttributes: [
            "iconName",
            "appName",
            "usage",
            "memory",
            "netInbound",
            "netOutbound",
            "ioCharactersActuallyReadRate",
            "ioCharactersActuallyWrittenRate"
        ]

        enabled: root.visible && root.showTopApps

        enabledAttributes: {
            var available = appModel.availableAttributes || [];
            var result = [];
            for (var i = 0; i < requiredAttributes.length; ++i) {
                if (available.indexOf(requiredAttributes[i]) >= 0)
                    result.push(requiredAttributes[i]);
            }
            return result;
        }
    }

    Connections {
        target: appModel
        function onRowsInserted() { root.rebuildTopApplications(); }
        function onRowsRemoved() { root.rebuildTopApplications(); }
        function onModelReset() { root.rebuildTopApplications(); }
        function onLayoutChanged() { root.rebuildTopApplications(); }
    }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                       Kirigami.Theme.backgroundColor.g,
                       Kirigami.Theme.backgroundColor.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                              Kirigami.Theme.textColor.g,
                              Kirigami.Theme.textColor.b, 0.08)

        Controls.ScrollView {
            anchors.fill: parent
            anchors.margins: 10
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 2

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        Controls.Label {
                            text: i18n("System Monitor")
                            font.pixelSize: Math.max(Kirigami.Theme.defaultFont.pixelSize + 3, 16)
                            font.weight: Font.DemiBold
                        }

                        Controls.Label {
                            text: root.uptimeSeconds > 0
                                  ? i18n("Up %1", root.formatUptime(root.uptimeSeconds))
                                  : i18n("Live system resources")
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }
                    }

                    Controls.ToolButton {
                        icon.name: "utilities-system-monitor"
                        display: Controls.AbstractButton.IconOnly
                        onClicked: Qt.openUrlExternally("applications:org.kde.plasma-systemmonitor.desktop")
                        Controls.ToolTip.visible: hovered
                        Controls.ToolTip.text: i18n("Open System Monitor")
                    }
                }

                Rectangle {
                    visible: !root.systemDataReady
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 14
                    color: Qt.rgba(Kirigami.Theme.neutralTextColor.r,
                                   Kirigami.Theme.neutralTextColor.g,
                                   Kirigami.Theme.neutralTextColor.b, 0.10)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        Kirigami.Icon {
                            source: "dialog-information"
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                        }
                        Controls.Label {
                            Layout.fillWidth: true
                            text: i18n("Waiting for KSystemStats sensors…")
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                GridLayout {
                    id: metricGrid
                    Layout.fillWidth: true
                    columns: width < 280 ? 1 : 2
                    rowSpacing: 8
                    columnSpacing: 8

                    MetricCard {
                        visible: root.showCpu
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        title: i18n("CPU")
                        iconName: "cpu"
                        valueText: root.percentText(root.cpuUsage)
                        detailText: {
                            var parts = [];
                            var freq = root.formatFrequency(root.cpuFrequency);
                            var temp = root.formatTemperature(root.cpuTemperature);
                            if (freq.length > 0) parts.push(freq);
                            if (temp.length > 0) parts.push(temp);
                            return parts.join("  ·  ");
                        }
                        graphValues: root.cpuHistory
                        graphMaximum: 100
                        progress: isNaN(root.cpuUsage) ? -1 : root.cpuUsage / 100
                        accentColor: Kirigami.Theme.highlightColor
                    }

                    MetricCard {
                        visible: root.showMemory
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        title: i18n("Memory")
                        iconName: "memory"
                        valueText: root.percentText(root.memoryPercent)
                        detailText: !isNaN(root.memoryUsed) && !isNaN(root.memoryTotal)
                                    ? root.formatBytes(root.memoryUsed) + " / " + root.formatBytes(root.memoryTotal)
                                    : ""
                        graphValues: root.memoryHistory
                        graphMaximum: 100
                        progress: isNaN(root.memoryPercent) ? -1 : root.memoryPercent / 100
                        accentColor: Kirigami.Theme.positiveTextColor
                    }

                    MetricCard {
                        visible: root.showGpu && root.gpuId.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        title: root.gpuName.length > 0 ? root.gpuName : i18n("GPU")
                        iconName: "video-display"
                        valueText: root.percentText(root.gpuUsage)
                        detailText: {
                            var parts = [];
                            if (!isNaN(root.gpuVramUsed) && !isNaN(root.gpuVramTotal) && root.gpuVramTotal > 0)
                                parts.push(root.formatBytes(root.gpuVramUsed) + " / " + root.formatBytes(root.gpuVramTotal));
                            var temp = root.formatTemperature(root.gpuTemperature);
                            if (temp.length > 0) parts.push(temp);
                            return parts.join("  ·  ");
                        }
                        graphValues: root.gpuHistory
                        graphMaximum: 100
                        progress: isNaN(root.gpuUsage) ? -1 : root.gpuUsage / 100
                        accentColor: Kirigami.Theme.neutralTextColor
                    }

                    MetricCard {
                        visible: root.showDisk
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        title: i18n("Disk I/O")
                        iconName: "drive-harddisk"
                        valueText: root.percentText(root.diskUsedPercent)
                        detailText: "↓ " + root.formatRate(root.diskRead) + "   ↑ " + root.formatRate(root.diskWrite)
                        graphValues: root.diskReadHistory
                        secondaryGraphValues: root.diskWriteHistory
                        graphAutoScale: true
                        progress: isNaN(root.diskUsedPercent) ? -1 : root.diskUsedPercent / 100
                        accentColor: Kirigami.Theme.neutralTextColor
                    }

                    MetricCard {
                        visible: root.showNetwork
                        Layout.fillWidth: true
                        Layout.columnSpan: metricGrid.columns
                        Layout.preferredHeight: implicitHeight
                        title: i18n("Network")
                        iconName: "network-wireless"
                        valueText: "↓ " + root.formatRate(root.networkDown)
                        detailText: "↑ " + root.formatRate(root.networkUp)
                        graphValues: root.networkDownHistory
                        secondaryGraphValues: root.networkUpHistory
                        graphAutoScale: true
                        accentColor: Kirigami.Theme.positiveTextColor
                    }
                }

                Rectangle {
                    visible: root.showTopApps
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(82, 52 + Math.max(1, root.topApplications.length) * 40)
                    radius: 18
                    color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                                   Kirigami.Theme.backgroundColor.g,
                                   Kirigami.Theme.backgroundColor.b, 0.82)
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                          Kirigami.Theme.textColor.g,
                                          Kirigami.Theme.textColor.b, 0.08)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Controls.Label {
                                text: i18n("Top applications")
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }

                            Controls.Label {
                                text: root.topMetricLabel()
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }
                        }

                        Controls.Label {
                            visible: root.topApplications.length === 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: appModel.available
                                  ? i18n("Waiting for application activity…")
                                  : i18n("Application statistics are unavailable")
                            color: Kirigami.Theme.disabledTextColor
                        }

                        Repeater {
                            model: root.topApplications

                            RowLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                spacing: 8

                                Kirigami.Icon {
                                    source: modelData.iconName.length > 0
                                            ? modelData.iconName
                                            : "application-x-executable"
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Controls.Label {
                                        text: modelData.name
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.weight: Font.Medium
                                    }

                                    Controls.Label {
                                        text: modelData.cpuText + " CPU  ·  " + modelData.memoryText
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        color: Kirigami.Theme.disabledTextColor
                                        font.pixelSize: Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1)
                                    }
                                }

                                Controls.Label {
                                    text: modelData.valueText
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 76
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4

                    Controls.Label {
                        text: root.gpuId.length > 0
                              ? i18n("KSystemStats · GPU detected")
                              : i18n("KSystemStats")
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1)
                        Layout.fillWidth: true
                    }

                    Controls.Label {
                        text: (root.updateInterval / 1000).toFixed(root.updateInterval < 1000 ? 1 : 0) + "s"
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: Math.max(9, Kirigami.Theme.smallFont.pixelSize - 1)
                    }
                }
            }
        }
    }
}
