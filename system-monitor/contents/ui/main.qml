import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    implicitWidth: 328
    implicitHeight: 620

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation

    Plasmoid.title: i18n("Meo Performance")
    toolTipSubText: i18n("CPU %1 · Memory %2", root.display(cpuUsage), root.display(memoryUsage))

    function display(sensor) {
        if (!sensor) {
            return "—"
        }
        const value = sensor.formattedValue
        return value && value.length > 0 ? value : "—"
    }

    Sensors.Sensor {
        id: cpuUsage
        sensorId: "cpu/all/usage"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: cpuFrequency
        sensorId: "cpu/all/averageFrequency"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: cpuTemperature
        sensorId: "cpu/all/averageTemperature"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: memoryUsage
        sensorId: "memory/physical/usedPercent"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: gpuUsage
        sensorId: "gpu/all/usage"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: vramUsage
        sensorId: "gpu/all/usedPercent"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: networkDownload
        sensorId: "network/all/download"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: networkUpload
        sensorId: "network/all/upload"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: diskRead
        sensorId: "disk/all/read"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: diskWrite
        sensorId: "disk/all/write"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: diskUsage
        sensorId: "disk/all/usedPercent"
        updateRateLimit: 1500
    }

    compactRepresentation: Rectangle {
        id: compactRoot

        implicitWidth: Kirigami.Units.gridUnit * 3.2
        implicitHeight: Kirigami.Units.gridUnit * 2
        radius: Math.min(width, height) / 2
        color: Kirigami.Theme.backgroundColor

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Kirigami.Theme.highlightColor
            opacity: compactHover.hovered ? 0.18 : 0.10
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 9
                rightMargin: 9
            }
            spacing: 5

            Kirigami.Icon {
                source: "cpu"
                implicitWidth: 16
                implicitHeight: 16
                color: Kirigami.Theme.textColor
            }

            Text {
                text: root.display(cpuUsage)
                color: Kirigami.Theme.textColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        HoverHandler {
            id: compactHover
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        id: fullRoot

        Layout.minimumWidth: 286
        Layout.preferredWidth: 328
        Layout.minimumHeight: 552
        Layout.preferredHeight: 620

        Rectangle {
            anchors.fill: parent
            radius: 30
            color: Kirigami.Theme.backgroundColor

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Kirigami.Theme.highlightColor
                opacity: 0.035
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -1

                    Text {
                        text: i18n("Performance")
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: i18n("Live system activity")
                        color: Kirigami.Theme.textColor
                        opacity: 0.52
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    implicitWidth: 50
                    implicitHeight: 24
                    radius: 12
                    color: Kirigami.Theme.backgroundColor

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Kirigami.Theme.positiveTextColor
                        opacity: 0.12
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: Kirigami.Theme.positiveTextColor
                        }

                        Text {
                            text: i18n("Live")
                            color: Kirigami.Theme.textColor
                            font.pixelSize: 9
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            MetricCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 96

                title: i18n("CPU")
                iconName: "cpu"
                sensor: cpuUsage
                subtitle: cpuFrequency.formattedValue && cpuFrequency.formattedValue.length > 0
                    ? i18n("Average %1", cpuFrequency.formattedValue)
                    : i18n("Average frequency")
                accent: Kirigami.Theme.highlightColor
                chartMaximum: 100
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                spacing: 8

                MetricCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    compact: true
                    title: i18n("Temperature")
                    iconName: "temperature-normal"
                    sensor: cpuTemperature
                    accent: Kirigami.Theme.neutralTextColor
                    showChart: false
                }

                MetricCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    compact: true
                    title: i18n("Memory")
                    iconName: "memory"
                    sensor: memoryUsage
                    accent: Kirigami.Theme.positiveTextColor
                    showChart: false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                spacing: 8

                MetricCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    compact: true
                    title: i18n("GPU")
                    iconName: "video-display"
                    sensor: gpuUsage
                    accent: Kirigami.Theme.linkColor
                    showChart: false
                }

                MetricCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    compact: true
                    title: i18n("VRAM")
                    iconName: "video-display"
                    sensor: vramUsage
                    accent: Kirigami.Theme.highlightColor
                    showChart: false
                }
            }

            DualMetricCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 88

                title: i18n("Network")
                iconName: "network-wired"
                primarySensor: networkDownload
                secondarySensor: networkUpload
                primaryLabel: i18n("Download")
                secondaryLabel: i18n("Upload")
                accent: Kirigami.Theme.positiveTextColor
            }

            DualMetricCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 88

                title: i18n("Disk I/O")
                iconName: "drive-harddisk"
                primarySensor: diskRead
                secondarySensor: diskWrite
                primaryLabel: i18n("Read")
                secondaryLabel: i18n("Write")
                accent: Kirigami.Theme.neutralTextColor
            }

            MetricCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 72

                compact: true
                title: i18n("Storage")
                iconName: "drive-harddisk"
                sensor: diskUsage
                accent: Kirigami.Theme.highlightColor
                showChart: false
            }
        }
    }

}
