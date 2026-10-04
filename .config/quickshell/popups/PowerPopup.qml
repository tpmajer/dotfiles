import QtQuick
import qs
import qs.services
import qs.widgets

// Power menu: lock, logout, shutdown, suspend, reboot. With the bar in its
// keyboard mode one row is selected and the bar passes the keys on here;
// running a command stays in the Bar.
PopupList {
    id: actionList

    required property var host   // the Bar
    // The row selected from the keyboard.
    property int selected: 0

    function keyPressed(event) {
        const count = Power.actions.length;
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_K:
            selected = (selected + count - 1) % count;
            break;
        case Qt.Key_Down:
        case Qt.Key_J:
        case Qt.Key_Tab:
            selected = (selected + 1) % count;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            host.runAction(Power.actions[selected].command);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // Opened from the keyboard anew: from the first row.
    Connections {
        target: actionList.host
        function onKeyboardModeChanged() {
            if (actionList.host.keyboardMode)
                actionList.selected = 0;
        }
    }

    Repeater {
        model: Power.actions

        PopupAction {
            required property var modelData
            required property int index
            labelWidth: actionList.nameWidth
            icon: Theme.glyph(modelData.icon)
            iconColor: modelData.color || Theme.text
            text: modelData.text
            // With the keyboard, one row is selected; the mouse moves the selection.
            highlighted: actionList.host.keyboardMode && index === actionList.selected
            onHoveredChanged: if (hovered)
                actionList.selected = index
            onTriggered: actionList.host.runAction(modelData.command)
        }
    }
}
