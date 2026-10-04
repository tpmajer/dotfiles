import QtQuick
import Quickshell.Bluetooth
import qs
import qs.services
import qs.widgets

PopupList {
    id: btList
    readonly property var adapter: Bluetooth.defaultAdapter
    // Paired devices, the connected ones first, then by name; clicking one
    // connects or disconnects it.
    readonly property var devices: Bluetooth.devices.values.filter(d => d.paired || d.connected).sort((a, b) => b.connected - a.connected || a.name.localeCompare(b.name))
    hasRows: !!adapter

    PopupText {
        visible: !btList.adapter
        text: "No bluetooth controller found"
    }

    // The adapter's switch: clicking it turns bluetooth on or off.
    PopupAction {
        id: power
        readonly property bool on: !!btList.adapter && btList.adapter.enabled
        visible: !!btList.adapter
        labelWidth: btList.nameWidth
        valueWidth: btList.valueWidth
        icon: Theme.glyph(on ? 0xf00af : 0xf00b2)
        iconColor: on ? Theme.sapphire : Theme.subtext0
        bright: on
        text: "Bluetooth"
        value: on ? "on" : "off"
        onTriggered: btList.adapter.enabled = !on
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
        model: power.on ? btList.devices : []

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
