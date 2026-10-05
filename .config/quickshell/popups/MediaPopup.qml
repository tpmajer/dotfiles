import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

// What plays: the cover, the title, the artist and the album, how far
// into the track it is, and the buttons for the previous track, a
// pause and the next one. Below them the other players; a click on one
// makes it the one the bar is about.
Column {
    id: popup

    readonly property bool hasRows: true
    readonly property var player: Media.active
    readonly property var others: Media.players.filter(p => p !== player)
    readonly property real wide: 340
    readonly property real coverSize: 72
    spacing: Theme.popupSectionGap
    // What is above the rows is inset like the rows' text, on the sides
    // and at the top.
    topPadding: Theme.popupTextInsetV

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const pad = n => String(n).padStart(2, "0");
        return s >= 3600 ? Math.floor(s / 3600) + ":" + pad(Math.floor(s / 60) % 60) + ":" + pad(s % 60) : Math.floor(s / 60) + ":" + pad(s % 60);
    }

    // How far into the track it is, in seconds. A player's position is
    // not a property that tells of its changes: it is read, once a second
    // and only while the popup shows. The bar takes that second to get to
    // the new reading, and so moves on evenly; over a jump, and to
    // another track, wherever that one starts, it takes no time.
    property real elapsed: 0
    // The same as a part of the track's length, for the bar: set here
    // with the rest, not bound, so that the bar moves only as told.
    property real played: 0
    property int glide: 0
    // What the last reading was of.
    property string readOf: ""
    function read() {
        const known = !!player && player.positionSupported && player.lengthSupported && player.length > 0;
        const now = known ? player.position : 0;
        const key = player ? [player.dbusName, player.trackTitle, player.length].join("\n") : "";
        // Evenly only from one second's reading to the next one's.
        glide = key === readOf && now >= elapsed && now - elapsed < 1.5 ? 1000 : 0;
        readOf = key;
        elapsed = now;
        played = known ? now / player.length : 0;
    }
    Component.onCompleted: read()
    onPlayerChanged: read()
    onVisibleChanged: if (visible)
        read()

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: popup.visible && Media.playing
        onTriggered: popup.read()
    }
    Connections {
        target: popup.player
        function onPostTrackChanged() {
            popup.read();
        }
        function onLengthChanged() {
            popup.read();
        }
        // A seek.
        function onPositionChanged() {
            popup.read();
        }
    }

    component Control: Rectangle {
        id: control

        property string glyph
        // Whether the player can do it.
        property bool usable: true
        signal triggered

        implicitWidth: 56
        implicitHeight: 42
        radius: Theme.moduleRadius
        color: area.containsMouse && usable ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
        Behavior on color {
            ColorAnimation { duration: Theme.hoverDuration }
        }

        PopupText {
            anchors.centerIn: parent
            text: control.glyph
            font.pixelSize: 30
            color: !control.usable ? Theme.surface1 : area.containsMouse ? Theme.text : Theme.subtext0
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: control.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (control.usable)
                control.triggered()
        }
    }

    // As wide as the rows below, which may not be there.
    Column {
        id: info
        leftPadding: Theme.popupTextInset
        rightPadding: Theme.popupTextInset
        spacing: Theme.popupSectionGap

        Row {
            id: track
            width: popup.wide
            spacing: Theme.popupColumnGap

            ClippingRectangle {
                width: popup.coverSize
                height: popup.coverSize
                radius: Theme.moduleRadius
                color: Theme.surface0

                // Without a cover, the player's glyph in its color.
                PopupText {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: Media.glyphOf(popup.player)
                    font.pixelSize: 30
                    color: Media.color
                }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: Media.artUrl
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    // The height alone: a wide cover, a video's, is
                    // cropped to the square and has to fill its height.
                    sourceSize.height: popup.coverSize * 2
                }
            }

            Column {
                width: parent.width - popup.coverSize - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.popupRowGap

                PopupText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Media.title
                }
                PopupText {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text !== ""
                    text: Media.artist
                    color: Theme.subtext0
                }
                PopupText {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text !== ""
                    text: Media.album
                    color: Theme.subtext0
                }
            }
        }

        RowLayout {
            id: progress
            width: popup.wide
            spacing: Theme.popupColumnGap
            visible: !!popup.player && popup.player.lengthSupported && popup.player.length > 0

            PopupText {
                text: progress.visible && popup.player.positionSupported ? popup.time(popup.elapsed) : ""
                color: Theme.subtext0
            }
            LevelBar {
                Layout.fillWidth: true
                popupY: info.y + progress.y + y
                // Not by whether the row shows: it does not in a closed
                // popup, and the bar would fill up anew as that opens.
                level: popup.played
                fill: Media.color
                glide: popup.glide
            }
            PopupText {
                text: progress.visible ? popup.time(popup.player.length) : ""
                color: Theme.subtext0
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.popupColumnGap

            Control {
                glyph: Theme.glyph(0xf04ae)
                usable: Media.canSkip(popup.player, -1)
                onTriggered: Media.skip(-1)
            }
            Control {
                glyph: Theme.glyph(Media.playing ? 0xf03e4 : 0xf040a)
                usable: !!popup.player && popup.player.canTogglePlaying
                onTriggered: Media.playPause()
            }
            Control {
                glyph: Theme.glyph(0xf04ad)
                usable: Media.canSkip(popup.player, 1)
                onTriggered: Media.skip(1)
            }
        }
    }

    // The other players, each with what it plays.
    Column {
        visible: popup.others.length > 0
        spacing: 2

        Repeater {
            model: popup.others

            PopupAction {
                id: row
                required property var modelData
                // Its text is cut to the popup's width.
                readonly property string label: modelData.trackTitle || modelData.identity
                width: popup.wide + 2 * Theme.popupTextInset
                icon: Media.glyphOf(modelData)
                iconColor: modelData.isPlaying ? Media.colorOf(modelData) : Theme.subtext0
                bright: modelData.isPlaying
                text: metrics.elidedText
                onTriggered: Media.select(modelData)

                TextMetrics {
                    id: metrics
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                    elideWidth: popup.wide - row.chromeWidth
                    text: row.label
                }
            }
        }
    }
}
