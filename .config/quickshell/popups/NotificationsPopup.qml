import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

// The notification center: the notifications whose toast timed out, or that
// came under do not disturb, the newest first. A card works as a toast does:
// a left click runs its default action and closes it, a right click only
// closes it. The list scrolls past Theme.centerMaxHeight.
Column {
    id: center

    readonly property bool hasRows: true
    readonly property var list: Notifications.missed
    spacing: 6

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
                    readonly property bool active: hover.hovered

                    width: Theme.notificationWidth
                    height: body.implicitHeight
                    radius: Theme.moduleRadius
                    color: active ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverDuration }
                    }

                    HoverHandler {
                        id: hover
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
