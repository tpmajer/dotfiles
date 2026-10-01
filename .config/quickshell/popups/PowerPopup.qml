import QtQuick
import qs
import qs.widgets

// Power menu: lock, logout, shutdown, suspend, reboot. The actions, the
// keyboard selection and running a command stay in the Bar, which also drives
// the menu from the keyboard.
Column {
    id: actionList

    required property var host   // the Bar
    readonly property bool hasRows: true
    // Rows share the width of the widest one.
    property real rowWidth: 0
    spacing: 2

    Repeater {
        model: actionList.host.powerActions

        PopupAction {
            required property var modelData
            required property int index
            width: actionList.rowWidth
            Component.onCompleted: actionList.rowWidth = Math.max(actionList.rowWidth, implicitWidth)
            icon: Theme.glyph(modelData.icon)
            iconColor: modelData.color || Theme.text
            text: modelData.text
            // With the keyboard, one row is selected; the mouse moves the selection.
            highlighted: actionList.host.keyboardMode && index === actionList.host.powerIndex
            onHoveredChanged: if (hovered)
                actionList.host.powerIndex = index
            onTriggered: actionList.host.runAction(modelData.command)
        }
    }
}
