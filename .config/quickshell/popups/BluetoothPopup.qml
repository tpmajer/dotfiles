import QtQuick
import Quickshell.Bluetooth
import qs
import qs.services
import qs.widgets

Column {
    id: btList
    readonly property var adapter: Bluetooth.defaultAdapter
    // Paired devices by name; clicking one connects or disconnects it.
    readonly property var devices: Bluetooth.devices.values.filter(d => d.paired || d.connected).sort((a, b) => a.name.localeCompare(b.name))
    readonly property bool hasRows: !!adapter && adapter.enabled && devices.length > 0
    // Columns line up across rows.
    readonly property real nameWidth: widest(i => i.labelImplicitWidth)
    readonly property real valueWidth: widest(i => i.valueImplicitWidth)
    spacing: 2

    function widest(width) {
        let w = 0;
        for (let i = 0; i < btRows.count; i++) {
            const item = btRows.itemAt(i);
            if (item)
                w = Math.max(w, width(item));
        }
        return w;
    }

    PopupText {
        visible: !btList.hasRows
        text: !parent.adapter ? "No bluetooth controller found" : parent.adapter.enabled ? "Bluetooth on" : "Bluetooth off"
    }

    // Icon by the BlueZ device type; headphones match the volume module.
    function deviceIcon(type) {
        const icons = {
            "audio-headphones": 0xf025,
            "audio-headset": 0xf02ce,
            "audio-card": 0xf04c3,
            "input-mouse": 0xf037d,
            "input-keyboard": 0xf030c,
            "input-gaming": 0xf0297,
            "phone": 0xf011c,
            "computer": 0xf0322
        };
        return Theme.glyph(icons[type] || 0xf00af);
    }

    Repeater {
        id: btRows
        model: btList.hasRows ? btList.devices : []

        PopupAction {
            required property var modelData
            readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
            labelWidth: btList.nameWidth
            valueWidth: btList.valueWidth
            icon: btList.deviceIcon(Audio.deviceType(modelData))
            iconColor: modelData.connected ? Theme.sapphire : Theme.subtext0
            bright: modelData.connected
            text: modelData.name
            value: modelData.state === BluetoothDeviceState.Connecting ? "connecting…" : modelData.state === BluetoothDeviceState.Disconnecting ? "disconnecting…" : modelData.connected ? Audio.batteryText(modelData) : ""
            onTriggered: {
                if (busy)
                    return;
                if (modelData.connected)
                    modelData.disconnect();
                else
                    modelData.connect();
            }
        }
    }
}
