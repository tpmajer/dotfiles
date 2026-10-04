import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// Power menu in the middle of the focused output: a row of large icons with
// their names below, driven from the keyboard (Super+Esc in niri) or the mouse.
// The surface covers the whole output, dimmed, so a click beside the menu
// closes it.
PanelWindow {
    id: menu

    property bool shown: false
    property int index: Power.defaultIndex
    // The session is locked.
    property bool locked: false
    // The menu is gone, the dimming stays: an action was chosen and what it
    // brings is not there yet. The lock's curtain fades in over the dimming,
    // and the session ends under it; it would otherwise be gone for a moment
    // before either.
    property bool dimHeld: false
    onLockedChanged: if (locked)
        dimHeld = false

    // The dimming goes even if nothing comes of the action. A click ends
    // it too.
    Timer {
        id: dimRelease
        interval: 5000
        onTriggered: menu.dimHeld = false
    }

    Pop {
        id: pop
        shown: menu.shown
        mapped: menu.backingWindowVisible
    }

    function toggle() {
        dimHeld = false;
        if (shown) {
            shown = false;
            return;
        }
        index = Power.defaultIndex;
        shown = true;
        keyHandler.forceActiveFocus();
    }

    function runAction(action) {
        shown = false;
        dimHeld = true;
        dimRelease.restart();
        Power.run(action.command);
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

    WlrLayershell.namespace: "quickshell-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Not under a menu half faded out, as with the OSD.
    readonly property bool blurred: pop.openness > 0.5
    BackgroundEffect.blurRegion: Region {
        x: shadowLayer.x + box.x
        y: shadowLayer.y + box.y
        width: menu.blurred ? box.width : 0
        height: menu.blurred ? box.height : 0
        radius: Theme.barRadius

        // Inside the menu, so it blurs nothing new; see blurResend.
        Region {
            x: shadowLayer.x + box.x + Theme.barRadius
            y: shadowLayer.y + box.y + Theme.barRadius
            width: menu.blurred ? 1 : 0
            height: 1 + menu.blurResend % 2
        }
    }

    // A new blur region can reach niri with a commit older than itself, and
    // is then not applied until the region changes again (see PopupHost):
    // the menu stays without its blur. So the region is sent a few more
    // times once the menu is in it.
    property int blurResend: 0
    onBlurredChanged: if (blurred) {
        blurResendTimer.left = 8;
        blurResendTimer.restart();
    }
    Timer {
        id: blurResendTimer
        property int left: 0
        interval: 48
        repeat: true
        onTriggered: {
            menu.blurResend++;
            if (--left <= 0)
                stop();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45 * (dimHeld ? 1 : Math.min(1, pop.openness))
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            menu.shown = false;
            menu.dimHeld = false;
        }
    }

    Item {
        id: keyHandler
        focus: true
        Keys.onPressed: event => {
            const count = Power.actions.length;
            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_H:
            case Qt.Key_Backtab:
                menu.index = (menu.index + count - 1) % count;
                break;
            case Qt.Key_Right:
            case Qt.Key_L:
            case Qt.Key_Tab:
                menu.index = (menu.index + 1) % count;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                menu.runAction(Power.actions[menu.index]);
                break;
            case Qt.Key_Escape:
                menu.shown = false;
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    // Only as large as the menu and its shadow: the effect redraws its whole
    // layer on every frame of the fade, and one the size of the output stutters.
    Item {
        id: shadowLayer
        readonly property int room: 30
        // Centered, on whole device pixels.
        x: Theme.snap((parent.width - box.width) / 2, menu.devicePixelRatio) - room
        y: Theme.snap((parent.height - box.height) / 2, menu.devicePixelRatio) - room
        width: box.width + 2 * room
        height: box.height + 2 * room

        opacity: pop.openness
        scale: pop.scale

        layer.enabled: true
        layer.effect: Shadow {}

        Rectangle {
            id: box
            x: shadowLayer.room
            y: shadowLayer.room
            width: tiles.width + 2 * Theme.popupPadding
            height: tiles.height + 2 * Theme.popupPadding
            radius: Theme.barRadius
            color: Theme.base
        }
    }

    // Outside the shadow's layer: text drawn into it comes out soft.
    Row {
        id: tiles
        x: Theme.snap((parent.width - width) / 2, menu.devicePixelRatio)
        y: Theme.snap((parent.height - height) / 2, menu.devicePixelRatio)
        opacity: pop.openness
        scale: pop.scale
        spacing: Theme.popupIconGap

        Repeater {
            model: Power.actions

            Rectangle {
                id: tile
                required property var modelData
                required property int index
                readonly property bool selected: index === menu.index

                width: 128
                height: 128
                radius: Theme.moduleRadius
                color: selected ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
                Behavior on color {
                    ColorAnimation { duration: Theme.hoverDuration }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.popupIconGap

                    PopupText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 52
                        text: Theme.glyph(tile.modelData.icon)
                        color: tile.modelData.color || Theme.text
                    }
                    PopupText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.text
                        color: tile.selected ? Theme.text : Theme.subtext0
                        // With the tile: a label that dims at once flickers
                        // over a background still fading out.
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverDuration }
                        }
                    }
                }

                // One tile is always selected; the mouse moves the selection.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse)
                        menu.index = tile.index
                    onClicked: menu.runAction(tile.modelData)
                }
            }
        }
    }
}
