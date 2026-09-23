import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root

    property alias cfg_showCpu: showCpu.checked
    property alias cfg_showMemory: showMemory.checked
    property alias cfg_showGpu: showGpu.checked
    property alias cfg_showNetwork: showNetwork.checked
    property alias cfg_showDisk: showDisk.checked
    property alias cfg_showTopApps: showTopApps.checked
    property alias cfg_topAppCount: topAppCount.value
    property alias cfg_updateInterval: updateInterval.value
    property alias cfg_historyLength: historyLength.value
    property string cfg_topAppMetric: "cpu"

    onCfg_topAppMetricChanged: {
        for (var i = 0; i < metricModel.count; ++i) {
            if (metricModel.get(i).value === cfg_topAppMetric) {
                topAppMetric.currentIndex = i;
                return;
            }
        }
        topAppMetric.currentIndex = 0;
    }

    ListModel {
        id: metricModel
        ListElement { text: "CPU"; value: "cpu" }
        ListElement { text: "Memory"; value: "memory" }
        ListElement { text: "Network"; value: "network" }
        ListElement { text: "Disk I/O"; value: "disk" }
    }

    Controls.CheckBox {
        id: showCpu
        Kirigami.FormData.label: i18n("Metrics:")
        text: i18n("CPU")
    }

    Controls.CheckBox {
        id: showMemory
        text: i18n("Memory")
    }

    Controls.CheckBox {
        id: showGpu
        text: i18n("GPU (when available)")
    }

    Controls.CheckBox {
        id: showNetwork
        text: i18n("Network")
    }

    Controls.CheckBox {
        id: showDisk
        text: i18n("Disk")
    }

    Controls.CheckBox {
        id: showTopApps
        text: i18n("Top applications")
    }

    Controls.ComboBox {
        id: topAppMetric
        Kirigami.FormData.label: i18n("Rank applications by:")
        model: metricModel
        textRole: "text"
        valueRole: "value"
        enabled: showTopApps.checked
        onActivated: root.cfg_topAppMetric = currentValue
    }

    Controls.SpinBox {
        id: topAppCount
        Kirigami.FormData.label: i18n("Applications shown:")
        from: 1
        to: 8
        enabled: showTopApps.checked
    }

    Controls.SpinBox {
        id: updateInterval
        Kirigami.FormData.label: i18n("Refresh interval:")
        from: 500
        to: 10000
        stepSize: 500
        editable: true
        textFromValue: function(value) {
            return (value / 1000).toFixed(value < 1000 ? 1 : 0) + " s";
        }
        valueFromText: function(text) {
            var number = Number(String(text).replace(/[^0-9.]/g, ""));
            return Math.max(500, Math.round(number * 1000));
        }
    }

    Controls.SpinBox {
        id: historyLength
        Kirigami.FormData.label: i18n("Graph samples:")
        from: 20
        to: 180
        stepSize: 10
    }

    Controls.Label {
        Kirigami.FormData.label: i18n("Data source:")
        text: i18n("KSystemStats / libksysguard")
        color: Kirigami.Theme.disabledTextColor
    }
}
