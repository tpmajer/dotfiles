import QtQuick
import qs
import qs.services
import qs.widgets

// Every audio output with its volume or mute, the default one (the one the
// module controls) first, in brighter text with a yellow icon. Clicking a row
// mutes or unmutes that output, scrolling over it changes its volume, a right
// click makes it the default. Below them, the same for Spotify while it runs
// and for every program that plays, then the microphone and the programs
// recording from it.
Column {
    id: sinkList
    readonly property bool hasRows: true
    // Columns line up across rows.
    readonly property real nameWidth: widest(i => i.labelImplicitWidth)
    readonly property real valueWidth: widest(i => i.valueImplicitWidth)
    spacing: 2

    function widest(width) {
        let w = 0;
        for (const item of children) {
            if (item instanceof PopupAction)
                w = Math.max(w, width(item));
        }
        return w;
    }

    function level(node) {
        return node.audio.muted ? "muted" : Audio.volume(node) + "%";
    }

    Repeater {
        model: Audio.sinks

        PopupAction {
            required property var modelData
            readonly property bool isDefault: modelData === Audio.defaultSink
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Audio.icon(modelData)
            iconColor: isDefault ? Theme.yellow : Theme.subtext0
            bright: isDefault
            text: Audio.name(modelData)
            value: sinkList.level(modelData)
            onTriggered: Audio.toggleMute(modelData)
            onSecondaryTriggered: Audio.setDefault(modelData)
            onScrolled: steps => Audio.changeVolume(modelData, steps)
        }
    }

    // Spotify's own volume, while it runs: the speaker's when it plays on a
    // Connect device.
    Repeater {
        model: Spotify.ready ? 1 : 0

        PopupAction {
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Theme.glyph(0xf04c7)
            iconColor: Spotify.muted ? Theme.subtext0 : Theme.green
            text: "Spotify"
            value: Spotify.muted ? "muted" : Spotify.volume + "%"
            onTriggered: Spotify.toggleMute()
            onScrolled: steps => Spotify.changeVolume(steps)
        }
    }

    // The programs playing. Spotify has its row above.
    Repeater {
        model: Audio.streams.filter(n => !(Spotify.ready && /^spotify$/i.test(Audio.appName(n))))

        PopupAction {
            required property var modelData
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Theme.glyph(modelData.audio.muted ? 0xf075f : 0xf0387)
            iconColor: Theme.subtext0
            text: Audio.appName(modelData)
            value: sinkList.level(modelData)
            onTriggered: Audio.toggleMute(modelData)
            onScrolled: steps => Audio.changeVolume(modelData, steps)
        }
    }

    // The microphone, red while something records from it.
    Repeater {
        model: Audio.defaultSource && Audio.defaultSource.audio ? [Audio.defaultSource] : []

        PopupAction {
            required property var modelData
            readonly property bool recording: Audio.recorders.length > 0
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Theme.glyph(modelData.audio.muted ? 0xf036d : 0xf036c)
            iconColor: modelData.audio.muted ? Theme.subtext0 : recording ? Theme.red : Theme.yellow
            bright: recording
            text: Audio.name(modelData)
            value: sinkList.level(modelData)
            onTriggered: Audio.toggleMute(modelData)
            onScrolled: steps => Audio.changeVolume(modelData, steps)
        }
    }

    Repeater {
        model: Audio.recorders

        PopupAction {
            required property var modelData
            labelWidth: sinkList.nameWidth
            valueWidth: sinkList.valueWidth
            icon: Theme.glyph(0xf044a)
            iconColor: modelData.audio.muted ? Theme.subtext0 : Theme.red
            text: Audio.appName(modelData)
            value: sinkList.level(modelData)
            onTriggered: Audio.toggleMute(modelData)
            onScrolled: steps => Audio.changeVolume(modelData, steps)
        }
    }
}
