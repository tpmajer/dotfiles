import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// Power menu in the middle of the focused output: a row of large icons with
// their names below, driven from the keyboard (Super+Esc in niri) or the mouse.
// The surface covers the whole output, dimmed, so a click beside the menu
// closes it.
Overlay {
    id: menu

    property int index: Power.defaultIndex
    // The session is locked.
    property bool locked: false
    // The menu is gone, the dimming stays (dimHeld): an action was chosen
    // and what it brings is not there yet. The lock's curtain fades in over
    // the dimming, and the session ends under it; it would otherwise be gone
    // for a moment before either.
    onLockedChanged: if (locked)
        dimHeld = false

    // The dimming goes even if nothing comes of the action. A click ends
    // it too.
    Timer {
        id: dimRelease
        interval: 5000
        onTriggered: menu.dimHeld = false
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

    boxWidth: tiles.width + 2 * Theme.popupPadding
    boxHeight: tiles.height + 2 * Theme.popupPadding
    onOutsideClicked: {
        shown = false;
        dimHeld = false;
    }

    WlrLayershell.namespace: "quickshell-power"

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

    // On whole device pixels, as the box is.
    Row {
        id: tiles
        x: Theme.snap(menu.boxX + Theme.popupPadding, menu.devicePixelRatio) - menu.boxX
        y: Theme.snap(menu.boxY + Theme.popupPadding, menu.devicePixelRatio) - menu.boxY
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
