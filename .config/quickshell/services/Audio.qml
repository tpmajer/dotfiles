pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs

// Audio outputs (sinks) and how the bar shows them: the volume level icon,
// a headphone icon for bluetooth headphones, a muted icon. Also the programs
// playing sound, the microphone and the programs recording from it.
Singleton {
    id: root

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource   // the microphone
    // The default sink first, the rest in PipeWire's order.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio).sort((a, b) => (b === defaultSink) - (a === defaultSink))

    // Programs playing sound, in PipeWire's order.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
    // Programs recording from the microphone: what its links lead to, so that
    // one listening to an output's monitor (a level meter) doesn't count.
    readonly property var recorders: sourceLinks.linkGroups.map(g => g.target).filter(n => n && n.isStream && n.audio)

    // Devices whose BlueZ type is wrong, by address. The Mu-so Qb is a speaker
    // but reports itself as a headset.
    readonly property var deviceTypeOverrides: ({
            "00:12:6F:4D:1D:FD": "audio-card"
        })

    function deviceType(device) {
        return deviceTypeOverrides[device.address] || device.icon;
    }

    function volume(node) {
        return node && node.audio ? Math.round(node.audio.volume * 100) : 0;
    }

    // Bluetooth sinks are named bluez_output.<MAC>.N; BlueZ knows whether the
    // device is headphones or a headset.
    function isHeadphones(node) {
        const m = node ? (node.name || "").match(/^bluez_output\.([0-9A-Fa-f_]{17})/) : null;
        if (!m)
            return false;
        const address = m[1].replace(/_/g, ":").toUpperCase();
        const device = Bluetooth.devices.values.find(d => d.address === address);
        return !!device && /^audio-head(phones|set)/.test(deviceType(device));
    }

    function icon(node) {
        if (!node || !node.audio)
            return "";
        if (node.audio.muted)
            return Theme.glyph(0xf075f);
        if (isHeadphones(node))
            return Theme.glyph(0xf025);
        return Theme.glyph([0xf057f, 0xf0580, 0xf057e][Math.min(2, Math.floor(volume(node) / (100 / 3)))]);
    }

    // One scroll step = 1%, capped at 100%.
    function changeVolume(node, steps) {
        if (node && node.audio)
            node.audio.volume = Math.max(0, Math.min(1, (volume(node) + steps) / 100));
    }

    function toggleMute(node) {
        if (node && node.audio)
            node.audio.muted = !node.audio.muted;
    }

    function name(node) {
        return node.description || node.nickname || node.name;
    }

    // A stream is called after its program.
    function appName(node) {
        return (node.properties && node.properties["application.name"]) || name(node);
    }

    // Makes the output the default one: what plays moves to it.
    function setDefault(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // Keeps volume/mute of every sink up to date, not only the default one.
    PwObjectTracker {
        objects: root.sinks
    }

    PwObjectTracker {
        objects: [root.defaultSource]
    }

    PwObjectTracker {
        objects: root.streams.concat(root.recorders)
    }

    PwNodeLinkTracker {
        id: sourceLinks
        node: root.defaultSource
    }
}
