import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

// Every audio output with its volume or mute, as a bar and a percent, the
// default one (the one the module controls) first, in brighter text with a yellow icon; a bluetooth
// one with its codec and battery. Clicking a row mutes or unmutes that output,
// scrolling over it changes its volume, a right click makes it the default.
// Below them, the same for Spotify while it runs and for every program that
// plays, then the microphone and the programs recording from it.
PopupList {
    id: sinkList

    // The programs playing. Spotify has its row of its own.
    readonly property var streams: Audio.streams.filter(n => !(Spotify.ready && /^spotify$/i.test(Audio.appName(n))))
    readonly property bool playing: Spotify.ready || streams.length > 0
    readonly property bool hasMic: !!Audio.defaultSource && !!Audio.defaultSource.audio

    function level(node) {
        return node.audio.muted ? "muted" : Audio.volume(node) + "%";
    }

    // Muted, the level stays, in gray.
    function levelColor(node, color) {
        return node.audio.muted ? Theme.subtext0 : color;
    }

    // ScriptModel: a row stays while its node does, with its hover and its
    // part-turn of the wheel, when another output or program comes or goes.
    Repeater {
        model: ScriptModel {
            values: Audio.sinks
        }

        PopupAction {
            required property var modelData
            readonly property bool isDefault: modelData === Audio.defaultSink
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Audio.icon(modelData)
            iconColor: isDefault ? Theme.yellow : Theme.subtext0
            bright: isDefault
            text: Audio.name(modelData)
            detail: Audio.bluetoothDetail(modelData)
            widestValue: "muted"
            value: sinkList.level(modelData)
            level: modelData.audio.volume
            levelColor: sinkList.levelColor(modelData, Theme.yellow)
            onTriggered: Audio.toggleMute(modelData)
            onSecondaryTriggered: Audio.setDefault(modelData)
            onScrolled: steps => Audio.changeVolume(modelData, steps)
        }
    }

    // The outputs, the programs and the microphone apart, as the popups'
    // parts are.
    Item {
        visible: Audio.sinks.length > 0 && sinkList.playing
        width: 1
        height: Theme.popupSectionGap - 2 * sinkList.spacing
    }

    // Spotify's own volume, while it runs: the speaker's when it plays on a
    // Connect device.
    Repeater {
        model: Spotify.ready ? 1 : 0

        PopupAction {
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Theme.glyph(0xf1bc)
            iconColor: Spotify.muted ? Theme.subtext0 : Theme.green
            text: "Spotify"
            widestValue: "muted"
            value: Spotify.muted ? "muted" : Spotify.volume + "%"
            level: Spotify.volume / 100
            levelColor: Theme.green
            onTriggered: Spotify.toggleMute()
            onScrolled: steps => Spotify.changeVolume(steps)
        }
    }

    Repeater {
        model: ScriptModel {
            values: sinkList.streams
        }

        PopupAction {
            required property var modelData
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Theme.glyph(modelData.audio.muted ? 0xeee8 : 0xf001)
            iconColor: Theme.subtext0
            text: Audio.appName(modelData)
            widestValue: "muted"
            value: sinkList.level(modelData)
            level: modelData.audio.volume
            levelColor: sinkList.levelColor(modelData, Theme.yellow)
            onTriggered: Audio.toggleMute(modelData)
            onScrolled: steps => Audio.changeVolume(modelData, steps)
        }
    }

    Item {
        visible: (Audio.sinks.length > 0 || sinkList.playing) && sinkList.hasMic
        width: 1
        height: Theme.popupSectionGap - 2 * sinkList.spacing
    }

    // The microphone, red while something records from it.
    Repeater {
        model: sinkList.hasMic ? [Audio.defaultSource] : []

        PopupAction {
            required property var modelData
            readonly property bool recording: Audio.recorders.length > 0
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Theme.glyph(modelData.audio.muted ? 0xf131 : 0xf130)
            iconColor: modelData.audio.muted ? Theme.subtext0 : recording ? Theme.red : Theme.yellow
            bright: recording
            text: Audio.name(modelData)
            widestValue: "muted"
            value: sinkList.level(modelData)
            level: modelData.audio.volume
            levelColor: sinkList.levelColor(modelData, recording ? Theme.red : Theme.yellow)
            onTriggered: Audio.toggleMute(modelData)
            onScrolled: steps => Audio.changeVolume(modelData, steps)
        }
    }

    Repeater {
        model: ScriptModel {
            values: Audio.recorders
        }

        PopupAction {
            required property var modelData
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Theme.glyph(0xf111)
            iconColor: modelData.audio.muted ? Theme.subtext0 : Theme.red
            text: Audio.appName(modelData)
            widestValue: "muted"
            value: sinkList.level(modelData)
            level: modelData.audio.volume
            levelColor: sinkList.levelColor(modelData, Theme.red)
            onTriggered: Audio.toggleMute(modelData)
            onScrolled: steps => Audio.changeVolume(modelData, steps)
        }
    }
}
