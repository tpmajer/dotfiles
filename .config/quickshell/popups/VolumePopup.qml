import QtQuick
import qs
import qs.services
import qs.widgets

// Every audio output with its volume or mute, the default one (the one the
// module controls) first, in brighter text with a yellow icon. Clicking a row
// mutes or unmutes that output, scrolling over it changes its volume.
Column {
    id: sinkList
    readonly property bool hasRows: true
    // Columns line up across rows: each keeps the widest text seen so far.
    property real nameWidth: 0
    property real valueWidth: 0
    spacing: 2

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
            value: modelData.audio && modelData.audio.muted ? "muted" : Audio.volume(modelData) + "%"
            onLabelImplicitWidthChanged: sinkList.nameWidth = Math.max(sinkList.nameWidth, labelImplicitWidth)
            onValueImplicitWidthChanged: sinkList.valueWidth = Math.max(sinkList.valueWidth, valueImplicitWidth)
            Component.onCompleted: {
                sinkList.nameWidth = Math.max(sinkList.nameWidth, labelImplicitWidth);
                sinkList.valueWidth = Math.max(sinkList.valueWidth, valueImplicitWidth);
            }
            onTriggered: Audio.toggleMute(modelData)
            onScrolled: steps => Audio.changeVolume(modelData, steps)
        }
    }
}
