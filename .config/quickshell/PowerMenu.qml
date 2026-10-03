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
    property int index: 0

    Pop {
        id: pop
        shown: menu.shown
        mapped: menu.backingWindowVisible
    }
    readonly property real openness: pop.openness

    function toggle() {
        if (shown) {
            shown = false;
            return;
        }
        index = 0;
        shown = true;
        keyHandler.forceActiveFocus();
    }

    // Closes the menu and runs the command only once it is gone and a frame
    // without it has been drawn: hyprlock (Lock, and Suspend via hypridle)
    // screenshots the screen right away and would otherwise capture the
    // closing menu.
    property string pendingAction: ""
    function runAction(command) {
        pendingAction = command;
        shown = false;
    }
    onOpennessChanged: if (openness <= 0 && pendingAction !== "")
        actionTimer.restart()
    onShownChanged: if (shown)
        pendingAction = ""

    Timer {
        id: actionTimer
        interval: Theme.actionDelay
        onTriggered: {
            const command = menu.pendingAction;
            menu.pendingAction = "";
            if (command !== "")
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
    visible: shown || pop.openness > 0

    WlrLayershell.namespace: "quickshell-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region {
        x: shadowLayer.x + box.x
        y: shadowLayer.y + box.y
        width: pop.openness > 0.5 ? box.width : 0
        height: pop.openness > 0.5 ? box.height : 0
        radius: Theme.barRadius
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.35 * Math.min(1, pop.openness)
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
