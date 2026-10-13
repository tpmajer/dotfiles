import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// A box in the middle of the focused output, over the output dimmed: the
// launcher, the power menu, polkit's prompt and the keyring's. It pops in and
// out, blurred and under a shadow as the bar is. Its children are what is in
// the box.
PanelWindow {
    id: overlay

    property bool shown: false
    // The keyboard is this window's while this is set.
    property bool keyboard: shown
    property real boxWidth: 0
    property real boxHeight: 0
    // The box's top edge: in the middle unless set.
    property real boxTop: (height - boxHeight) / 2
    property alias boxClip: box.clip
    // The dimming stays although the box is gone.
    property bool dimHeld: false
    readonly property real openness: pop.openness
    // Where the box is, on whole device pixels.
    readonly property real boxX: box.x
    readonly property real boxY: box.y
    default property alias contents: box.data

    // A click beside the box.
    signal outsideClicked

    // The pointer moved. Not sent for one lying where the box comes up, or
    // where something in it changes: an item is told of a move then too,
    // which is not to select it.
    signal pointerMoved
    property var pointerAt: null
    onShownChanged: if (shown)
        pointerAt = null

    Pop {
        id: pop
        shown: overlay.shown
        mapped: overlay.backingWindowVisible
    }

    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || pop.openness > 0 || dimHeld

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Not under a box half faded out, as with the OSD.
    readonly property bool blurred: pop.openness > 0.5
    BackgroundEffect.blurRegion: Region {
        x: box.x
        y: box.y
        width: overlay.blurred ? box.width : 0
        height: overlay.blurred ? box.height : 0
        radius: Theme.barRadius

        BlurBump {
            id: blurBump
            x: box.x + Theme.barRadius
            y: box.y + Theme.barRadius
            width: overlay.blurred ? 1 : 0
        }
    }

    // Sent anew once the box is in it (BlurBump).
    onBlurredChanged: if (blurred)
        blurBump.send(8)

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45 * (overlay.dimHeld ? 1 : Math.min(1, pop.openness))
    }

    MouseArea {
        anchors.fill: parent
        onClicked: overlay.outsideClicked()
    }

    // Only as large as the box and its shadow: the effect redraws its whole
    // layer on every frame of the fade, and one the size of the output stutters.
    Item {
        readonly property int room: 30
        x: box.x - room
        y: box.y - room
        width: box.width + 2 * room
        height: box.height + 2 * room

        opacity: pop.openness
        scale: pop.scale

        layer.enabled: true
        layer.effect: Shadow {}

        Rectangle {
            x: parent.room
            y: parent.room
            width: box.width
            height: box.height
            radius: Theme.barRadius
            color: Theme.base
        }
    }

    // On what everything is in, so in the way of nothing: where the pointer
    // is in the window, whatever is under it and however that is scaled.
    HoverHandler {
        parent: overlay.contentItem
        onPointChanged: {
            if (!hovered)
                return;
            const at = point.scenePosition;
            const moved = overlay.pointerAt && (at.x !== overlay.pointerAt.x || at.y !== overlay.pointerAt.y);
            overlay.pointerAt = Qt.point(at.x, at.y);
            // Once the items under it know where it is.
            if (moved)
                Qt.callLater(overlay.pointerMoved);
        }
    }

    // Outside the shadow's layer: text drawn into it comes out soft.
    Item {
        id: box
        x: Theme.snap((parent.width - width) / 2, overlay.devicePixelRatio)
        y: Theme.snap(overlay.boxTop, overlay.devicePixelRatio)
        width: overlay.boxWidth
        height: overlay.boxHeight
        opacity: pop.openness
        scale: pop.scale
    }
}
