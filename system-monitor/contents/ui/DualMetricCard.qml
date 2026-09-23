import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts

Rectangle {
    id: card

    property string title: ""
    property string iconName: ""
    property var primarySensor: null
    property var secondarySensor: null
    property string primaryLabel: ""
    property string secondaryLabel: ""
    property color accent: Kirigami.Theme.highlightColor
    property int historyPoints: 40

    readonly property real primaryNumericValue: {
        const n = Number(primarySensor ? primarySensor.value : 0)
        return isNaN(n) ? 0 : n
    }

    function formatted(sensor) {
        if (!sensor) {
            return "—"
        }
        const value = sensor.formattedValue
        return value && value.length > 0 ? value : "—"
    }

    signal activated()

    implicitWidth: 280
    implicitHeight: 88
    radius: 22
    color: Kirigami.Theme.backgroundColor
    clip: true

    scale: hover.hovered ? 1.01 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: card.accent
        opacity: hover.hovered ? 0.17 : 0.10

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    Charts.LineChart {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 10
            rightMargin: 10
            bottomMargin: 7
        }
        height: Math.max(26, parent.height * 0.38)
        opacity: hover.hovered ? 0.82 : 0.62

        yRange {
            from: 0
            to: 1
            automatic: true
        }

        valueSources: Charts.HistoryProxySource {
            source: Charts.SingleValueSource {
                value: card.primaryNumericValue
            }
            maximumHistory: card.historyPoints
            fillMode: Charts.HistoryProxySource.FillFromStart
        }

        colorSource: Charts.SingleValueSource {
            value: card.accent
        }

        lineWidth: 2
        fillOpacity: 0.10
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Kirigami.Icon {
                visible: card.iconName.length > 0
                source: card.iconName
                implicitWidth: 17
                implicitHeight: 17
                color: Kirigami.Theme.textColor
            }

            Text {
                Layout.fillWidth: true
                text: card.title
                color: Kirigami.Theme.textColor
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            z: 2

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: card.primaryLabel
                    color: Kirigami.Theme.textColor
                    opacity: 0.58
                    font.pixelSize: 9
                }

                Text {
                    text: card.formatted(card.primarySensor)
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width
                }
            }

            Rectangle {
                implicitWidth: 1
                implicitHeight: 28
                color: Kirigami.Theme.textColor
                opacity: 0.12
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: card.secondaryLabel
                    color: Kirigami.Theme.textColor
                    opacity: 0.58
                    font.pixelSize: 9
                }

                Text {
                    text: card.formatted(card.secondarySensor)
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: card.activated()
    }
}
