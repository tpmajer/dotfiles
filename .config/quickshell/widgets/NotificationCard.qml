import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.services

// What a notification's card shows, as a toast and in the notification
// center: the urgency as a line on the left, who it is from with the time it
// came, the summary, the body, a button for each action and, where the card
// is told to, a field for the reply its sender takes. A left click runs the
// default action and closes the notification, but the first one on a body
// cut short, which shows the whole of it; a right click only closes it. The
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

    // The whole body is shown, not its first lines: after a click on a
    // body cut short.
    property bool expanded: false
    // The lines of a body cut short, and of one shown whole: as much as
    // still leaves the card on the screen.
    readonly property int bodyLines: 6
    readonly property int bodyLinesExpanded: 40

    readonly property color accent: Notifications.urgencyColor(notification.urgency)
    // Who it is from: the name the sender gives, or that of its desktop
    // entry, and its icon. An application's own icon is shown as it is: the
    // one the sender names, as such or as the notification's image (a
    // picture there is not the sender's), or its desktop entry's. Any other
    // icon of the theme, such as a mouse's, is shown as the glyph the bar
    // has for it. A battery that took the place of the icon it came with,
    // as blueman puts one on a device just connected, goes to the body, by
    // the charge it tells; the icon it came with stays.
    readonly property var entry: notification.desktopEntry !== "" && DesktopEntries.applications.values.length >= 0 ? DesktopEntries.heuristicLookup(notification.desktopEntry) : null
    readonly property string sender: notification.appName || entry?.name || ""
    readonly property string namedIcon: Notifications.iconName(notification)
    readonly property string firstIcon: Notifications.icon(notification)
    readonly property bool batteryInBody: Notifications.isBatteryIcon(namedIcon) && firstIcon !== "" && !Notifications.isBatteryIcon(firstIcon)
    readonly property string iconName: batteryInBody ? firstIcon : namedIcon
    readonly property string bodyText: {
        const text = Notifications.markup(notification.body);
        if (!batteryInBody)
            return text;
        // The battery as full as the charge told, before it; with none
        // told, a battery before the body.
        const charge = /\d+\s*%/.exec(text);
        if (!charge)
            return Theme.iconGlyph(namedIcon) + " " + text;
        const glyph = Theme.glyph(Battery.defaultIcons[Math.min(9, Math.floor(parseInt(charge[0]) / 10))]);
        return text.slice(0, charge.index) + glyph + " " + text.slice(charge.index);
    }
    readonly property bool iconIsFile: iconName.startsWith("/") || iconName.includes("://")
    readonly property bool iconIsApp: iconName !== "" && !iconIsFile && DesktopEntries.applications.values.some(e => e.icon === iconName)
    readonly property string glyph: iconName !== "" && !iconIsFile && !iconIsApp ? Theme.iconGlyph(iconName) : ""
    readonly property string icon: {
        if (glyph !== "")
            return "";
        if (iconIsFile)
            return iconName.startsWith("/") ? "file://" + iconName : iconName;
        // Nothing for a name no icon goes by, not a placeholder.
        const name = iconIsApp ? iconName : entry?.icon || "";
        return name === "" ? "" : Quickshell.iconPath(name, true);
    }
    readonly property var extraActions: notification.actions.filter(a => a.identifier !== "default")

    implicitWidth: Theme.notificationWidth
    implicitHeight: content.implicitHeight + 2 * (Theme.popupPaddingV + Theme.popupTextInsetV)

    // A left click, or its key in the notification center.
    function activate() {
        if (body.truncated && !expanded)
            expanded = true;
        else
            Notifications.activate(notification);
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.LeftButton)
                card.activate();
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

        // Who it is from, and when it came in the top right corner.
        Item {
            width: parent.width
            height: sender.height

            IconImage {
                id: senderIcon
                visible: card.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                source: card.icon
                implicitSize: Theme.fontSize - 1
            }

            PopupText {
                id: senderGlyph
                visible: card.glyph !== ""
                text: card.glyph
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 2
            }

            PopupText {
                id: sender
                x: senderIcon.visible ? senderIcon.width + 6 : senderGlyph.visible ? senderGlyph.width + 6 : 0
                width: parent.width - x - (arrival.text !== "" ? arrival.width + Theme.popupColumnGap : 0)
                text: card.sender
                textFormat: Text.PlainText
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideRight
            }

            PopupText {
                id: arrival
                anchors.right: parent.right
                text: Notifications.arrival(card.notification)
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 2
            }
        }

        PopupText {
            width: parent.width
            text: card.notification.summary
            textFormat: Text.PlainText
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        PopupText {
            id: body
            visible: text !== ""
            width: parent.width
            text: card.bodyText
            textFormat: Text.StyledText
            color: Theme.subtext0
            font.pixelSize: Theme.fontSize - 2
            wrapMode: Text.Wrap
            maximumLineCount: card.expanded ? card.bodyLinesExpanded : card.bodyLines
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
