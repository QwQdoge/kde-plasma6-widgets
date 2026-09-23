import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts

Rectangle {
    id: card

    property string title: ""
    property string iconName: ""
    property var sensor: null
    property string subtitle: ""
    property color accent: Kirigami.Theme.highlightColor
    property bool showChart: true
    property bool automaticRange: false
    property real chartMaximum: 100
    property int historyPoints: 40
    property bool compact: false

    readonly property real numericValue: {
        const n = Number(sensor ? sensor.value : 0)
        return isNaN(n) ? 0 : n
    }
    readonly property string valueText: {
        if (!sensor) {
            return "—"
        }
        const formatted = sensor.formattedValue
        return formatted && formatted.length > 0 ? formatted : "—"
    }

    signal activated()

    implicitWidth: 140
    implicitHeight: compact ? 76 : 88
    radius: compact ? 18 : 22
    color: Kirigami.Theme.backgroundColor
    clip: true

    scale: hover.hovered ? 1.012 : 1.0
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
        opacity: hover.hovered ? 0.18 : 0.11

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    Charts.LineChart {
        id: chart
        visible: card.showChart && card.sensor !== null
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 10
            rightMargin: 10
            bottomMargin: 8
        }
        height: Math.max(28, parent.height * 0.42)
        opacity: hover.hovered ? 0.86 : 0.68

        yRange {
            from: 0
            to: card.chartMaximum
            automatic: card.automaticRange
        }

        valueSources: Charts.HistoryProxySource {
            source: Charts.SingleValueSource {
                value: card.numericValue
            }
            maximumHistory: card.historyPoints
            fillMode: Charts.HistoryProxySource.FillFromStart
        }

        colorSource: Charts.SingleValueSource {
            value: card.accent
        }

        lineWidth: 2
        fillOpacity: 0.12

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: card.compact ? 10 : 12
        }
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Kirigami.Icon {
                visible: card.iconName.length > 0
                source: card.iconName
                implicitWidth: card.compact ? 15 : 17
                implicitHeight: implicitWidth
                color: Kirigami.Theme.textColor
            }

            Text {
                Layout.fillWidth: true
                text: card.title
                color: Kirigami.Theme.textColor
                font.pixelSize: card.compact ? 11 : 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Text {
            text: card.valueText
            color: Kirigami.Theme.textColor
            font.pixelSize: card.compact ? 22 : 27
            font.weight: Font.DemiBold
            font.letterSpacing: -0.5
            z: 2
        }

        Text {
            visible: card.subtitle.length > 0
            text: card.subtitle
            color: Kirigami.Theme.textColor
            opacity: 0.62
            font.pixelSize: 10
            elide: Text.ElideRight
            Layout.maximumWidth: parent.width
            z: 2
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
