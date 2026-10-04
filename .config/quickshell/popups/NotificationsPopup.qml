import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

// The notification center: the notifications whose toast timed out, or that
// came under do not disturb, the newest first. A card works as a toast does:
// a left click runs its default action and closes it, a right click only
// closes it. The list scrolls past Theme.centerMaxHeight. With the bar in its
// keyboard mode one card is selected and the bar passes the keys on here.
Column {
    id: center

    required property var host   // the Bar
    readonly property bool hasRows: true
    readonly property var list: Notifications.missed
    // The card selected from the keyboard.
    property int selected: 0
    onListChanged: selected = Math.max(0, Math.min(selected, list.length - 1))
    spacing: 6

    function keyPressed(event) {
        const notification = list[selected];
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_K:
            selected = Math.max(0, selected - 1);
            reveal();
            break;
        case Qt.Key_Down:
        case Qt.Key_J:
        case Qt.Key_Tab:
            selected = Math.max(0, Math.min(selected + 1, list.length - 1));
            reveal();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (notification)
                Notifications.activate(notification);
            break;
        case Qt.Key_D:
            if (event.modifiers & Qt.ShiftModifier)
                Notifications.clear();
            else if (notification)
                notification.dismiss();
            break;
        case Qt.Key_Delete:
            if (notification)
                notification.dismiss();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // Scrolls the list so that the selected card is all there.
    function reveal() {
        const card = cards.itemAt(selected);
        if (!card)
            return;
        if (card.y < flick.contentY)
            flick.contentY = card.y;
        else if (card.y + card.height > flick.contentY + flick.height)
            flick.contentY = card.y + card.height - flick.height;
    }

    // Opened from the keyboard anew: from the newest.
    Connections {
        target: center.host
        function onKeyboardModeChanged() {
            if (center.host.keyboardMode) {
                center.selected = 0;
                flick.contentY = 0;
            }
        }
    }

    Item {
        width: Theme.notificationWidth
        height: title.implicitHeight + 8

        PopupText {
            id: title
            x: Theme.popupTextInset
            anchors.verticalCenter: parent.verticalCenter
            text: Notifications.dnd ? "Notifications · Do not disturb" : "Notifications"
            font.bold: true
        }

        PopupText {
            visible: center.list.length > 0
            anchors.right: parent.right
            anchors.rightMargin: Theme.popupTextInset
            anchors.baseline: title.baseline
            text: "Clear"
            color: clearMouse.containsMouse ? Theme.text : Theme.subtext0
            font.pixelSize: Theme.fontSize - 2

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.clear()
            }
        }
    }

    PopupText {
        visible: center.list.length === 0
        x: Theme.popupTextInset
        text: "No notifications"
        color: Theme.subtext0
        font.pixelSize: Theme.fontSize - 2
    }

    Flickable {
        id: flick
        visible: center.list.length > 0
        width: Theme.notificationWidth
        height: Math.min(rows.implicitHeight, Theme.centerMaxHeight)
        contentHeight: rows.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: rows
            spacing: 2

            Repeater {
                id: cards
                model: center.list

                Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    // With the keyboard, one card is selected; the mouse moves the selection.
                    readonly property bool active: hover.hovered || (center.host.keyboardMode && index === center.selected)

                    width: Theme.notificationWidth
                    height: body.implicitHeight
                    radius: Theme.moduleRadius
                    color: active ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverDuration }
                    }

                    HoverHandler {
                        id: hover
                        onHoveredChanged: if (hovered)
                            center.selected = row.index
                    }

                    NotificationCard {
                        id: body
                        anchors.fill: parent
                        notification: row.modelData
                        // The popup puts its content on a whole device pixel.
                        devicePixelRatio: QsWindow.window?.devicePixelRatio ?? 1
                        actionColor: Theme.surface1
                    }
                }
            }
        }
    }
}
