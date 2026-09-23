import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property string title: ""
    property string iconName: "utilities-system-monitor"
    property string valueText: "—"
    property string detailText: ""
    property var graphValues: []
    property var secondaryGraphValues: []
    property bool graphAutoScale: false
    property real graphMaximum: 100
    property real progress: -1
    property color accentColor: Kirigami.Theme.highlightColor

    implicitHeight: 106
    radius: 18
    color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                   Kirigami.Theme.backgroundColor.g,
                   Kirigami.Theme.backgroundColor.b, 0.82)
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                          Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.08)
    clip: true

    Sparkline {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: root.progress >= 0 ? 16 : 10
        height: 34
        values: root.graphValues
        secondaryValues: root.secondaryGraphValues
        lineColor: root.accentColor
        secondaryLineColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.38)
        autoScale: root.graphAutoScale
        maximum: root.graphMaximum
        opacity: 0.78
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        Kirigami.Icon {
            source: root.iconName
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            color: root.accentColor
        }

        Controls.Label {
            text: root.title
            Layout.fillWidth: true
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Controls.Label {
            text: root.valueText
            font.pixelSize: Math.max(Kirigami.Theme.defaultFont.pixelSize + 4, 16)
            font.weight: Font.DemiBold
        }
    }

    Controls.Label {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 38
        anchors.rightMargin: 12
        anchors.topMargin: 40
        text: root.detailText
        color: Kirigami.Theme.disabledTextColor
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        elide: Text.ElideRight
    }

    Rectangle {
        visible: root.progress >= 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 8
        height: 4
        radius: 2
        color: Qt.rgba(Kirigami.Theme.textColor.r,
                       Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, 0.10)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.progress))
            height: parent.height
            radius: parent.radius
            color: root.progress >= 0.90
                   ? Kirigami.Theme.negativeTextColor
                   : root.progress >= 0.75
                     ? Kirigami.Theme.neutralTextColor
                     : root.accentColor

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }
}
