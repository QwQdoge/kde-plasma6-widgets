import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property string title: ""

    property alias cfg_showCpu: showCpu.checked
    property alias cfg_showGpu: showGpu.checked
    property alias cfg_showMemory: showMemory.checked
    property alias cfg_showSwap: showSwap.checked
    property alias cfg_showNetwork: showNetwork.checked
    property alias cfg_showStorage: showStorage.checked
    property alias cfg_showTemperatures: showTemperatures.checked
    property int cfg_updateInterval: 1000

    property bool cfg_showCpuDefault: true
    property bool cfg_showGpuDefault: true
    property bool cfg_showMemoryDefault: true
    property bool cfg_showSwapDefault: true
    property bool cfg_showNetworkDefault: true
    property bool cfg_showStorageDefault: true
    property bool cfg_showTemperaturesDefault: true
    property int cfg_updateIntervalDefault: 1000

    CheckBox {
        id: showCpu
        Kirigami.FormData.label: i18n("Resources:")
        text: i18n("CPU")
    }
    CheckBox { id: showGpu; text: i18n("GPU") }
    CheckBox { id: showMemory; text: i18n("Memory") }
    CheckBox { id: showSwap; text: i18n("Swap") }
    CheckBox { id: showNetwork; text: i18n("Network") }
    CheckBox { id: showStorage; text: i18n("Storage") }

    CheckBox {
        id: showTemperatures
        Kirigami.FormData.label: i18n("Details:")
        text: i18n("Show temperatures when sensors are available")
    }

    ComboBox {
        id: intervalBox
        Kirigami.FormData.label: i18n("Refresh:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Fast — 0.5 s"), value: 500 },
            { text: i18n("Normal — 1 s"), value: 1000 },
            { text: i18n("Efficient — 2 s"), value: 2000 },
            { text: i18n("Low power — 5 s"), value: 5000 }
        ]
        onActivated: cfg_updateInterval = currentValue

        Component.onCompleted: syncIndex()
        function syncIndex() {
            for (let i = 0; i < model.length; ++i) {
                if (model[i].value === cfg_updateInterval) {
                    currentIndex = i
                    return
                }
            }
            currentIndex = 1
        }
    }

    onCfg_updateIntervalChanged: intervalBox.syncIndex()

    Kirigami.InlineMessage {
        Kirigami.FormData.isSection: true
        Layout.fillWidth: true
        type: Kirigami.MessageType.Information
        text: i18n("The widget uses KDE System Stats sensors and rate-limits updates. Unsupported hardware is shown as unavailable instead of running vendor-specific polling commands.")
        visible: true
    }
}
