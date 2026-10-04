import QtQuick
import Quickshell.Services.Notifications
import qs
import qs.services

// What a notification's card shows, as a toast and in the notification
// center: the urgency as a line on the left, the summary with the time it
// came, the body and a button for each action. A left click runs the default
// action and closes the notification, a right click only closes it. The
// background is drawn by what the card is in.
Item {
    id: card

    required property var notification
    // Where the card's left edge is in its window, and the window's scale:
    // the urgency line goes on whole device pixels.
    property real windowX: 0
    property real devicePixelRatio: 1
    // The action buttons' color: one that shows on the card's background.
    property color actionColor: Theme.surface0

    readonly property color accent: notification.urgency === NotificationUrgency.Critical ? Theme.red : notification.urgency === NotificationUrgency.Low ? Theme.subtext0 : Theme.teal
    readonly property var extraActions: notification.actions.filter(a => a.identifier !== "default")

    implicitWidth: Theme.notificationWidth
    implicitHeight: content.implicitHeight + 2 * (Theme.popupPaddingV + Theme.popupTextInsetV)

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.LeftButton)
                Notifications.activate(card.notification);
            else
                card.notification.dismiss();
        }
    }

    // The urgency, in the place of a module's underline.
    Rectangle {
        // On whole device pixels, like a module's underline.
        readonly property real windowX: card.windowX + Theme.popupPadding
        x: Theme.popupPadding + Theme.snap(windowX, card.devicePixelRatio) - windowX
        y: Theme.popupPaddingV + Theme.popupTextInsetV
        width: Theme.lineWidth
        height: parent.height - 2 * y
        radius: width / 2
        color: card.accent
    }

    Column {
        id: content
        x: Theme.popupPadding + Theme.popupTextInset
        y: Theme.popupPaddingV + Theme.popupTextInsetV
        width: parent.width - x - Theme.popupPadding - Theme.popupTextInset + 3
        spacing: 4

        // The summary, and when it came in the top right corner.
        Item {
            width: parent.width
            height: summary.height

            PopupText {
                id: summary
                width: parent.width - (arrival.text !== "" ? arrival.width + Theme.popupColumnGap : 0)
                text: card.notification.summary
                textFormat: Text.PlainText
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            PopupText {
                id: arrival
                anchors.right: parent.right
                // On the summary's first line.
                anchors.baseline: summary.baseline
                text: Notifications.arrival(card.notification)
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 2
            }
        }

        PopupText {
            visible: text !== ""
            width: parent.width
            text: card.notification.body
            textFormat: Text.StyledText
            color: Theme.subtext0
            font.pixelSize: Theme.fontSize - 2
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
        }

        Row {
            visible: card.extraActions.length > 0
            topPadding: 4
            spacing: 6

            Repeater {
                model: card.extraActions

                Rectangle {
                    id: button
                    required property var modelData
                    width: label.implicitWidth + 20
                    height: label.implicitHeight + 8
                    radius: Theme.moduleRadius
                    color: buttonMouse.containsMouse ? card.actionColor : Qt.rgba(card.actionColor.r, card.actionColor.g, card.actionColor.b, 0.5)

                    PopupText {
                        id: label
                        anchors.centerIn: parent
                        text: button.modelData.text
                        font.pixelSize: Theme.fontSize - 2
                    }

                    MouseArea {
                        id: buttonMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            button.modelData.invoke();
                            if (!card.notification.resident)
                                card.notification.dismiss();
                        }
                    }
                }
            }
        }
    }
}
