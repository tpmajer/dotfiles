import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// On-screen display: a pill at the bottom of the focused output, shown for a
// moment when the default output's volume or mute, the screen brightness, the
// microphone's mute, airplane mode or Spotify's own volume changes. It reacts
// to the change itself, so it doesn't matter what made it (the keys, the bar,
// another program).
PanelWindow {
    id: osd

    property string icon: ""
    property color accent: Theme.text
    property real level: 0          // 0..1, or -1 for no level bar (a switch)
    // The colored part of the bar; below level, the rest of it shows in grey.
    property real fill: 0
    property color fillColor: accent
    property string label: ""
    property bool shown: false

    function show(icon, accent, level, label, fill = level, fillColor = accent) {
        osd.icon = icon;
        osd.accent = accent;
        osd.level = Math.min(1, level);
        osd.fill = Math.min(1, fill);
        osd.fillColor = fillColor;
        osd.label = label;
        shown = true;
        hideTimer.restart();
    }

    function showVolume() {
        const sink = Audio.defaultSink;
        if (!sink || !sink.audio || settle.running)
            return;
        const muted = sink.audio.muted;
        // Muted, the yellow bar runs out and leaves the level in grey.
        show(Audio.icon(sink), muted ? Theme.subtext0 : Theme.yellow, sink.audio.volume, muted ? "muted" : Audio.volume(sink) + "%", muted ? 0 : sink.audio.volume, Theme.yellow);
    }

    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors.bottom: true
    margins.bottom: Theme.osdBottom - shadowRoom
    exclusionMode: ExclusionMode.Ignore
    // Room around the pill for its shadow.
    readonly property int shadowRoom: 30
    implicitWidth: box.width + 2 * shadowRoom
    implicitHeight: box.height + 2 * shadowRoom
    color: "transparent"
    visible: box.opacity > 0

    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Clicks go through to whatever is below.
    mask: Region {}

    BackgroundEffect.blurRegion: Region {
        x: box.x
        y: box.y
        width: box.opacity > 0.5 ? box.width : 0
        height: box.opacity > 0.5 ? box.height : 0
        radius: Theme.barRadius
    }

    // A new or switched output reports its volume as it appears; that is not a change.
    Timer {
        id: settle
        interval: 1000
        running: true
    }

    Connections {
        target: Audio
        function onDefaultSinkChanged() {
            settle.restart();
        }
    }

    Connections {
        target: Audio.defaultSink ? Audio.defaultSink.audio : null
        function onVolumeChanged() {
            osd.showVolume();
        }
        function onMutedChanged() {
            osd.showVolume();
        }
    }

    // Spotify reports its volume as it starts; that is not a change either.
    Connections {
        target: Spotify
        function onPlayerChanged() {
            spotifySettle.restart();
        }
    }

    Timer {
        id: spotifySettle
        interval: 1000
    }

    Connections {
        target: Spotify.player
        function onVolumeChanged() {
            if (spotifySettle.running)
                return;
            const muted = Spotify.muted;
            osd.show(Theme.glyph(0xf04c7), muted ? Theme.subtext0 : Theme.green, Spotify.player.volume, muted ? "muted" : Spotify.volume + "%");
        }
    }

    Connections {
        target: Audio
        function onDefaultSourceChanged() {
            settle.restart();
        }
    }

    Connections {
        target: Audio.defaultSource ? Audio.defaultSource.audio : null
        function onMutedChanged() {
            if (settle.running)
                return;
            const muted = Audio.defaultSource.audio.muted;
            osd.show(Theme.glyph(muted ? 0xf036d : 0xf036c), muted ? Theme.red : Theme.green, -1, muted ? "Microphone muted" : "Microphone on");
        }
    }

    Connections {
        target: Rfkill
        function onAirplaneChanged() {
            if (Rfkill.ready)
                osd.show(Theme.glyph(Rfkill.airplane ? 0xf001d : 0xf001e), Rfkill.airplane ? Theme.sky : Theme.subtext0, -1, "Airplane mode " + (Rfkill.airplane ? "on" : "off"));
        }
    }

    Connections {
        target: Brightness
        function onChanged() {
            osd.show(Theme.glyph(0xf00e0), Theme.peach, Brightness.percent / 100, Brightness.percent + "%");
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.osdTimeout
        onTriggered: osd.shown = false
    }

    Item {
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#77000000"
            shadowBlur: 1.0
            blurMax: 24
            shadowVerticalOffset: 3
        }

        Rectangle {
            id: box
            // Centered, on whole device pixels.
            x: Theme.snap((parent.width - width) / 2, osd.devicePixelRatio)
            y: Theme.snap((parent.height - height) / 2, osd.devicePixelRatio)
            width: content.implicitWidth + 2 * (Theme.popupPadding + Theme.popupTextInset)
            height: Theme.barHeight
            radius: Theme.barRadius
            color: Theme.base
            opacity: osd.shown ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.hoverDuration }
            }
        }
    }

    // Outside the shadow's layer: text drawn into it comes out soft. Centered
    // on whole device pixels, and so is each part within the row.
    Row {
        id: content
        x: Theme.snap((parent.width - width) / 2, osd.devicePixelRatio)
        y: Theme.snap((parent.height - height) / 2, osd.devicePixelRatio)
        // Fades with the pill, but twice as fast: gone by the time the pill is
        // half faded (when its blur goes too) and back only after that. Bright
        // text on a nearly faded pill reads as the content outliving it.
        opacity: Math.max(0, 2 * box.opacity - 1)
        spacing: Theme.popupColumnGap

        PopupText {
            y: Theme.snap(content.y + (content.height - height) / 2, osd.devicePixelRatio) - content.y
            width: iconSize.width
            horizontalAlignment: Text.AlignHCenter
            text: osd.icon
            color: osd.accent
        }

        Rectangle {
            visible: osd.level >= 0
            y: Theme.snap(content.y + (content.height - height) / 2, osd.devicePixelRatio) - content.y
            width: 200
            height: Theme.levelHeight
            radius: height / 2
            color: Theme.surface0

            Rectangle {
                // Never narrower than its height, or it can't be round and
                // sticks out of the track's end: at 0 it shrinks to a dot and
                // fades out.
                width: Math.max(height, parent.width * osd.level)
                opacity: osd.level > 0 ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 80 }
                }
                height: parent.height
                radius: parent.radius
                color: Theme.subtext0
                Behavior on width {
                    NumberAnimation { duration: 80 }
                }
            }

            Rectangle {
                width: Math.max(height, parent.width * osd.fill)
                opacity: osd.fill > 0 ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 80 }
                }
                height: parent.height
                radius: parent.radius
                color: osd.fillColor
                Behavior on width {
                    NumberAnimation { duration: 80 }
                }
            }
        }

        PopupText {
            y: Theme.snap(content.y + (content.height - height) / 2, osd.devicePixelRatio) - content.y
            width: osd.level >= 0 ? labelSize.width : implicitWidth
            horizontalAlignment: Text.AlignRight
            text: osd.label
        }
    }

    // Fixed widths, so the pill doesn't resize between icons and levels.
    TextMetrics {
        id: iconSize
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: Theme.glyph(0xf057e)
    }
    TextMetrics {
        id: labelSize
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: "muted"
    }
}
