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

    required property var panel   // the Bar
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
        target: center.panel
        function onKeyboardModeChanged() {
            if (center.panel.keyboardMode) {
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
            text: "Notifications"
            font.bold: true
        }

        // Highlighted on hover as a popup's clickable row is.
        Rectangle {
            visible: center.list.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: clearLabel.implicitWidth + 2 * Theme.popupTextInset
            height: clearLabel.implicitHeight + 8
            radius: Theme.moduleRadius
            color: clearMouse.containsMouse ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
            Behavior on color {
                ColorAnimation { duration: Theme.hoverDuration }
            }

            PopupText {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear"
                color: clearMouse.containsMouse ? Theme.text : Theme.subtext0
                font.pixelSize: Theme.fontSize - 2
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
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
                    // With the keyboard, the selected card alone, even with
                    // the pointer resting on another; the mouse moves the
                    // selection.
                    readonly property bool active: center.panel.keyboardMode ? index === center.selected : hover.hovered

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
