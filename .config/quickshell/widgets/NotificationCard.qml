import QtQuick
import Quickshell.Services.Notifications
import qs
import qs.services

// What a notification's card shows, as a toast and in the notification
// center: the urgency as a line on the left, the summary with the time it
// came, the body, a button for each action and, where the card is told to, a
// field for the reply its sender takes. A left click runs the default action
// and closes the notification, a right click only closes it. The background
// is drawn by what the card is in.
Item {
    id: card

    required property var notification
    // Where the card's left edge is in its window, and the window's scale:
    // the urgency line goes on whole device pixels.
    property real windowX: 0
    property real devicePixelRatio: 1
    // The action buttons' color: one that shows on the card's background.
    property color actionColor: Theme.surface0
    // The card is in a window that can take the keyboard, so it shows the
    // reply field of a notification that has one.
    property bool replyEnabled: false

    readonly property bool hasReply: replyEnabled && notification.hasInlineReply
    // A reply is being written: the card is not to go meanwhile.
    readonly property bool replying: hasReply && (reply.activeFocus || reply.text !== "")
    // The reply is sent or given up: the keyboard is no longer needed.
    signal replyClosed
    // Closes the notification on a right click. What the card is in may
    // have its own way, such as fading the card out first.
    property var close: () => card.notification.dismiss()

    readonly property color accent: Notifications.urgencyColor(notification.urgency)
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
                card.close();
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
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverDuration }
                    }

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
                        // Invoking it closes a notification that is not resident.
                        onClicked: button.modelData.invoke()
                    }
                }
            }
        }

        // The reply: Enter sends it, which closes a notification that is not
        // resident; Escape gives it up.
        Item {
            visible: card.hasReply
            width: parent.width
            height: field.height + 4

            Rectangle {
                id: field
                y: 4
                width: parent.width
                height: reply.implicitHeight + 8
                radius: Theme.moduleRadius
                color: reply.activeFocus ? card.actionColor : Qt.rgba(card.actionColor.r, card.actionColor.g, card.actionColor.b, 0.5)

                HoverHandler {
                    cursorShape: Qt.IBeamCursor
                }

                PopupText {
                    anchors.fill: reply
                    visible: reply.text === ""
                    verticalAlignment: Text.AlignVCenter
                    text: card.notification.inlineReplyPlaceholder || "Reply"
                    color: Theme.subtext0
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                }

                TextInput {
                    id: reply
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.surface1
                    selectedTextColor: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    clip: true
                    selectByMouse: true

                    function close() {
                        text = "";
                        focus = false;
                        card.replyClosed();
                    }

                    onAccepted: {
                        if (text.trim() === "")
                            return;
                        card.notification.sendInlineReply(text);
                        close();
                    }
                    Keys.onEscapePressed: close()
                }
            }
        }
    }
}
