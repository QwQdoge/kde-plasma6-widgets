import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.toolTipMainText: i18n("Performance Monitor")
    Plasmoid.toolTipSubText: i18n("CPU %1 · Memory %2")
                                .arg(cpuText)
                                .arg(memoryText)

    readonly property bool isPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                    || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int sampleInterval: Math.max(500, Plasmoid.configuration.updateInterval || 1000)
    readonly property bool monitoring: root.visible

    readonly property bool cpuReady: cpuUsage.status === Sensors.Sensor.Ready
    readonly property bool memoryReady: memoryUsed.status === Sensors.Sensor.Ready
                                        && memoryTotal.status === Sensors.Sensor.Ready
                                        && Number(memoryTotal.value) > 0
    readonly property bool gpuReady: gpuUsage.status === Sensors.Sensor.Ready
    readonly property bool networkReady: networkDownload.status === Sensors.Sensor.Ready
                                         || networkUpload.status === Sensors.Sensor.Ready

    readonly property real cpuPercent: cpuReady ? clamp(Number(cpuUsage.value), 0, 100) : -1
    readonly property real memoryPercent: memoryReady
                                          ? clamp(Number(memoryUsed.value) / Number(memoryTotal.value) * 100, 0, 100)
                                          : -1
    readonly property real swapPercent: swapTotal.status === Sensors.Sensor.Ready
                                        && Number(swapTotal.value) > 0
                                        ? clamp(Number(swapUsed.value) / Number(swapTotal.value) * 100, 0, 100)
                                        : -1
    readonly property real gpuPercent: gpuReady ? clamp(Number(gpuUsage.value), 0, 100) : -1

    readonly property string cpuText: cpuPercent >= 0 ? Math.round(cpuPercent) + "%" : "—"
    readonly property string memoryText: memoryPercent >= 0 ? Math.round(memoryPercent) + "%" : "—"
    readonly property string gpuText: gpuPercent >= 0 ? Math.round(gpuPercent) + "%" : "—"

    Layout.minimumWidth: isPanel ? implicitWidth : 300
    Layout.minimumHeight: isPanel ? implicitHeight : 260
    Layout.preferredWidth: isPanel ? implicitWidth : 430
    Layout.preferredHeight: isPanel ? implicitHeight : 410

    preferredRepresentation: isPanel ? compactRepresentation : fullRepresentation

    function clamp(value, minimum, maximum) {
        if (!isFinite(value))
            return minimum
        return Math.max(minimum, Math.min(maximum, value))
    }

    function formatBytes(bytes) {
        const value = Number(bytes)
        if (!isFinite(value) || value < 0)
            return "—"
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let scaled = value
        let unit = 0
        while (scaled >= 1024 && unit < units.length - 1) {
            scaled /= 1024
            unit++
        }
        const digits = scaled >= 100 || unit === 0 ? 0 : (scaled >= 10 ? 1 : 2)
        return scaled.toFixed(digits) + " " + units[unit]
    }

    function formatRate(bytesPerSecond) {
        const text = formatBytes(bytesPerSecond)
        return text === "—" ? text : text + "/s"
    }

    function modelMaximum(model) {
        if (!model || !model.ready)
            return -1
        let result = -1
        for (let column = 0; column < model.columnCount(); ++column) {
            const value = Number(model.data(model.index(0, column), Sensors.SensorDataModel.Value))
            if (isFinite(value))
                result = Math.max(result, value)
        }
        return result
    }

    function modelSum(model) {
        if (!model || !model.ready)
            return -1
        let result = 0
        let count = 0
        for (let column = 0; column < model.columnCount(); ++column) {
            const value = Number(model.data(model.index(0, column), Sensors.SensorDataModel.Value))
            if (isFinite(value)) {
                result += value
                count++
            }
        }
        return count > 0 ? result : -1
    }

    function sensorText(sensor) {
        return sensor.status === Sensors.Sensor.Ready && sensor.formattedValue !== ""
               ? sensor.formattedValue : "—"
    }

    Sensors.Sensor {
        id: cpuUsage
        sensorId: "cpu/all/usage"
        enabled: root.monitoring
        updateRateLimit: root.sampleInterval
    }
    Sensors.Sensor {
        id: cpuFrequency
        sensorId: "cpu/all/averageFrequency"
        enabled: root.monitoring && Plasmoid.configuration.showCpu
        updateRateLimit: root.sampleInterval
    }
    Sensors.Sensor {
        id: cpuTemperature
        sensorId: "cpu/all/maximumTemperature"
        enabled: root.monitoring && Plasmoid.configuration.showTemperatures
        updateRateLimit: root.sampleInterval
    }

    Sensors.Sensor {
        id: gpuUsage
        sensorId: "gpu/all/usage"
        enabled: root.monitoring && Plasmoid.configuration.showGpu
        updateRateLimit: root.sampleInterval
    }
    Sensors.Sensor {
        id: gpuUsedVram
        sensorId: "gpu/all/usedVram"
        enabled: root.monitoring && Plasmoid.configuration.showGpu
        updateRateLimit: root.sampleInterval
    }
    Sensors.Sensor {
        id: gpuTotalVram
        sensorId: "gpu/all/totalVram"
        enabled: root.monitoring && Plasmoid.configuration.showGpu
        updateRateLimit: root.sampleInterval
    }

    Sensors.Sensor {
        id: memoryUsed
        sensorId: "memory/physical/used"
        enabled: root.monitoring
        updateRateLimit: root.sampleInterval
    }
    Sensors.Sensor {
        id: memoryTotal
        sensorId: "memory/physical/total"
        enabled: root.monitoring
        updateRateLimit: root.sampleInterval
    }
    Sensors.Sensor {
        id: swapUsed
        sensorId: "memory/swap/used"
        enabled: root.monitoring && Plasmoid.configuration.showSwap
        updateRateLimit: root.sampleInterval
    }
    Sensors.Sensor {
        id: swapTotal
        sensorId: "memory/swap/total"
        enabled: root.monitoring && Plasmoid.configuration.showSwap
        updateRateLimit: root.sampleInterval
    }

    Sensors.Sensor {
        id: networkDownload
        sensorId: "network/all/download"
        enabled: root.monitoring && Plasmoid.configuration.showNetwork
        updateRateLimit: root.sampleInterval
    }
    Sensors.Sensor {
        id: networkUpload
        sensorId: "network/all/upload"
        enabled: root.monitoring && Plasmoid.configuration.showNetwork
        updateRateLimit: root.sampleInterval
    }

    Sensors.SensorDataModel {
        id: gpuTemperatureModel
        sensors: ["gpu/(?!all).*/temperature"]
        enabled: root.monitoring && Plasmoid.configuration.showGpu
                 && Plasmoid.configuration.showTemperatures
        updateRateLimit: root.sampleInterval
    }
    Sensors.SensorDataModel {
        id: diskReadModel
        sensors: ["disk/(?!all).*/read"]
        enabled: root.monitoring && Plasmoid.configuration.showStorage
        updateRateLimit: root.sampleInterval
    }
    Sensors.SensorDataModel {
        id: diskWriteModel
        sensors: ["disk/(?!all).*/write"]
        enabled: root.monitoring && Plasmoid.configuration.showStorage
        updateRateLimit: root.sampleInterval
    }
    Sensors.SensorDataModel {
        id: diskUsageModel
        sensors: ["disk/(?!all).*/usedPercent"]
        enabled: root.monitoring && Plasmoid.configuration.showStorage
        updateRateLimit: Math.max(2000, root.sampleInterval)
    }

    compactRepresentation: Item {
        implicitWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: compactRow.implicitHeight + Kirigami.Units.smallSpacing * 2

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "speedometer"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: width
            }
            PlasmaComponents.Label {
                text: root.cpuText
                font.weight: Font.DemiBold
            }
            PlasmaComponents.Label {
                visible: Plasmoid.configuration.showMemory
                text: root.memoryText
                opacity: 0.72
            }
        }
    }

    fullRepresentation: Item {
        implicitWidth: 430
        implicitHeight: 410

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius * 2
            color: Kirigami.Theme.backgroundColor
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: Kirigami.Units.largeSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents.Label {
                            text: i18n("Performance")
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.45
                            font.weight: Font.DemiBold
                        }
                        PlasmaComponents.Label {
                            text: i18n("Live system resources")
                            opacity: 0.68
                        }
                    }

                    PlasmaComponents.Label {
                        text: i18n("%1 ms", root.sampleInterval)
                        opacity: 0.58
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 390 ? 2 : 1
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.largeSpacing

                    MetricCard {
                        visible: Plasmoid.configuration.showCpu
                        Layout.fillWidth: true
                        title: i18n("CPU")
                        iconName: "cpu-symbolic"
                        mainText: root.cpuText
                        secondaryText: [
                            root.sensorText(cpuFrequency),
                            Plasmoid.configuration.showTemperatures ? root.sensorText(cpuTemperature) : ""
                        ].filter(text => text !== "" && text !== "—").join(" · ")
                        progress: root.cpuPercent
                    }

                    MetricCard {
                        visible: Plasmoid.configuration.showMemory
                        Layout.fillWidth: true
                        title: i18n("Memory")
                        iconName: "memory"
                        mainText: root.memoryText
                        secondaryText: root.memoryReady
                                       ? i18n("%1 / %2")
                                           .arg(root.formatBytes(Number(memoryUsed.value)))
                                           .arg(root.formatBytes(Number(memoryTotal.value)))
                                       : i18n("Waiting for sensor")
                        progress: root.memoryPercent
                    }

                    MetricCard {
                        visible: Plasmoid.configuration.showGpu
                        Layout.fillWidth: true
                        title: i18n("GPU")
                        iconName: "video-display"
                        mainText: root.gpuText
                        secondaryText: {
                            const pieces = []
                            if (gpuUsedVram.status === Sensors.Sensor.Ready
                                    && gpuTotalVram.status === Sensors.Sensor.Ready
                                    && Number(gpuTotalVram.value) > 0) {
                                pieces.push(i18n("%1 / %2 VRAM")
                                            .arg(root.formatBytes(Number(gpuUsedVram.value)))
                                            .arg(root.formatBytes(Number(gpuTotalVram.value))))
                            }
                            if (Plasmoid.configuration.showTemperatures) {
                                const temperature = root.modelMaximum(gpuTemperatureModel)
                                if (temperature >= 0)
                                    pieces.push(i18n("%1 °C").arg(Math.round(temperature)))
                            }
                            return pieces.length > 0 ? pieces.join(" · ") : i18n("Sensor unavailable")
                        }
                        progress: root.gpuPercent
                    }

                    MetricCard {
                        visible: Plasmoid.configuration.showSwap
                        Layout.fillWidth: true
                        title: i18n("Swap")
                        iconName: "drive-harddisk"
                        mainText: root.swapPercent >= 0 ? Math.round(root.swapPercent) + "%" : "—"
                        secondaryText: swapTotal.status === Sensors.Sensor.Ready && Number(swapTotal.value) > 0
                                       ? i18n("%1 / %2")
                                           .arg(root.formatBytes(Number(swapUsed.value)))
                                           .arg(root.formatBytes(Number(swapTotal.value)))
                                       : i18n("No swap or sensor unavailable")
                        progress: root.swapPercent
                    }
                }

                Rectangle {
                    visible: Plasmoid.configuration.showNetwork
                    Layout.fillWidth: true
                    implicitHeight: networkLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
                    radius: Kirigami.Units.cornerRadius * 1.5
                    color: Kirigami.Theme.alternateBackgroundColor

                    ColumnLayout {
                        id: networkLayout
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            Kirigami.Icon {
                                source: "network-wired"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: width
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: i18n("Network")
                                font.weight: Font.DemiBold
                            }
                            PlasmaComponents.Label {
                                text: networkReady ? i18n("Live") : i18n("Unavailable")
                                opacity: 0.6
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: i18n("↓ Download"); opacity: 0.72 }
                            Item { Layout.fillWidth: true }
                            PlasmaComponents.Label {
                                text: networkDownload.status === Sensors.Sensor.Ready
                                      ? networkDownload.formattedValue : "—"
                                font.weight: Font.DemiBold
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: i18n("↑ Upload"); opacity: 0.72 }
                            Item { Layout.fillWidth: true }
                            PlasmaComponents.Label {
                                text: networkUpload.status === Sensors.Sensor.Ready
                                      ? networkUpload.formattedValue : "—"
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                Rectangle {
                    visible: Plasmoid.configuration.showStorage
                    Layout.fillWidth: true
                    implicitHeight: storageLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
                    radius: Kirigami.Units.cornerRadius * 1.5
                    color: Kirigami.Theme.alternateBackgroundColor

                    ColumnLayout {
                        id: storageLayout
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            Kirigami.Icon {
                                source: "drive-harddisk"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: width
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: i18n("Storage")
                                font.weight: Font.DemiBold
                            }
                            PlasmaComponents.Label {
                                readonly property real maxUsage: root.modelMaximum(diskUsageModel)
                                text: maxUsage >= 0 ? i18n("%1% max used").arg(Math.round(maxUsage)) : i18n("Unavailable")
                                opacity: 0.6
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: i18n("Read"); opacity: 0.72 }
                            PlasmaComponents.Label {
                                text: root.modelSum(diskReadModel) >= 0
                                      ? root.formatRate(root.modelSum(diskReadModel)) : "—"
                                font.weight: Font.DemiBold
                            }
                            Item { Layout.fillWidth: true }
                            PlasmaComponents.Label { text: i18n("Write"); opacity: 0.72 }
                            PlasmaComponents.Label {
                                text: root.modelSum(diskWriteModel) >= 0
                                      ? root.formatRate(root.modelSum(diskWriteModel)) : "—"
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: !Plasmoid.configuration.showCpu
                             && !Plasmoid.configuration.showGpu
                             && !Plasmoid.configuration.showMemory
                             && !Plasmoid.configuration.showSwap
                             && !Plasmoid.configuration.showNetwork
                             && !Plasmoid.configuration.showStorage
                    text: i18n("Enable at least one resource in the widget settings.")
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.7
                }
            }
        }
    }

    component MetricCard: Rectangle {
        id: card
        required property string title
        required property string iconName
        required property string mainText
        property string secondaryText: ""
        property real progress: -1

        implicitHeight: 120
        radius: Kirigami.Units.cornerRadius * 1.5
        color: Kirigami.Theme.alternateBackgroundColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: card.iconName
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: width
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.title
                    font.weight: Font.DemiBold
                }
                PlasmaComponents.Label {
                    text: card.mainText
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.25
                    font.weight: Font.DemiBold
                }
            }

            PlasmaComponents.ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: card.progress >= 0 ? card.progress : 0
                indeterminate: card.progress < 0
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: card.secondaryText
                visible: text !== ""
                elide: Text.ElideRight
                opacity: 0.68
            }
        }
    }
}
