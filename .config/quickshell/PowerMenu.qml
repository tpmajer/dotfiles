import QtQuick
import QtQuick.Effects
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
    property int index: 0
    // Closing to run an action skips the fade; see runAction().
    property bool instantClose: false

    function toggle() {
        if (shown) {
            shown = false;
            return;
        }
        index = 0;
        shown = true;
        keyHandler.forceActiveFocus();
    }

    // Runs the command only once the menu is gone and a frame without it has
    // been drawn: hyprlock (Lock, and Suspend via hypridle) screenshots the
    // screen right away and would otherwise capture the closing menu.
    function runAction(command) {
        instantClose = true;
        shown = false;
        actionTimer.command = command;
        actionTimer.restart();
    }

    Timer {
        id: actionTimer
        property string command
        interval: 100
        onTriggered: {
            menu.instantClose = false;
            Quickshell.execDetached(["sh", "-c", command]);
        }
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
    visible: box.opacity > 0

    WlrLayershell.namespace: "quickshell-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region {
        x: box.x
        y: box.y
        width: box.opacity > 0.5 ? box.width : 0
        height: box.opacity > 0.5 ? box.height : 0
        radius: Theme.barRadius
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.35 * box.opacity
    }

    MouseArea {
        anchors.fill: parent
        onClicked: menu.shown = false
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
                menu.runAction(Power.actions[menu.index].command);
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
            x: Theme.snap((parent.width - width) / 2, menu.devicePixelRatio)
            y: Theme.snap((parent.height - height) / 2, menu.devicePixelRatio)
            width: tiles.width + 2 * Theme.popupPadding
            height: tiles.height + 2 * Theme.popupPadding
            radius: Theme.barRadius
            color: Theme.base
            opacity: menu.shown ? 1 : 0
            Behavior on opacity {
                enabled: !menu.instantClose
                NumberAnimation { duration: Theme.hoverDuration }
            }
        }
    }

    // Outside the shadow's layer: text drawn into it comes out soft.
    Row {
        id: tiles
        x: Theme.snap((parent.width - width) / 2, menu.devicePixelRatio)
        y: Theme.snap((parent.height - height) / 2, menu.devicePixelRatio)
        opacity: Math.max(0, 2 * box.opacity - 1)
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
                    }
                }

                // One tile is always selected; the mouse moves the selection.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse)
                        menu.index = tile.index
                    onClicked: menu.runAction(tile.modelData.command)
                }
            }
        }
    }
}
