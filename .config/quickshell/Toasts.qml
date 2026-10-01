import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.services
import qs.widgets

// Notifications: a stack of cards in a corner of the focused output, the
// newest at the bottom. A card stays for a time set by its urgency (not while
// the pointer is over it); a left click runs its default action and closes it,
// a right click only closes it.
PanelWindow {
    id: toasts

    readonly property bool atTop: Theme.notificationsPosition.startsWith("top")
    readonly property bool atLeft: Theme.notificationsPosition.endsWith("left")
    // Room around the cards for their shadow.
    readonly property int shadowRoom: 30
    property var cards: []

    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors {
        top: atTop
        bottom: !atTop
        left: atLeft
        right: !atLeft
    }
    // Below the bar at the top, by the screen edge elsewhere.
    margins {
        top: Theme.popupGap - shadowRoom
        bottom: Theme.barMargin - shadowRoom
        left: Theme.barMargin - shadowRoom
        right: Theme.barMargin - shadowRoom
    }
    implicitWidth: Theme.notificationWidth + 2 * shadowRoom
    implicitHeight: stack.height + 2 * shadowRoom
    color: "transparent"
    visible: cards.length > 0

    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the cards take input and get blurred, not the gaps or the shadow room.
    mask: Region {
        regions: toasts.cards.map(c => c.inputRegion)
    }
    BackgroundEffect.blurRegion: Region {
        regions: toasts.cards.map(c => c.blurRegion)
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

        Column {
            id: stack
            x: toasts.shadowRoom
            y: toasts.shadowRoom
            spacing: Theme.notificationGap

            Repeater {
                model: Notifications.list

                Rectangle {
                    id: card

                    required property var modelData
                    readonly property var notification: modelData
                    readonly property color accent: notification.urgency === NotificationUrgency.Critical ? Theme.red : notification.urgency === NotificationUrgency.Low ? Theme.subtext0 : Theme.teal
                    readonly property var extraActions: notification.actions.filter(a => a.identifier !== "default")
                    readonly property Region inputRegion: Region {
                        item: card
                    }
                    readonly property Region blurRegion: Region {
                        item: card
                        radius: Theme.barRadius
                    }
                    property bool appeared: false

                    width: Theme.notificationWidth
                    height: content.implicitHeight + 2 * (Theme.popupPaddingV + Theme.popupTextInsetV)
                    radius: Theme.barRadius
                    color: Theme.base
                    opacity: appeared ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.hoverDuration }
                    }

                    Component.onCompleted: {
                        appeared = true;
                        toasts.cards = toasts.cards.concat([card]);
                    }
                    Component.onDestruction: toasts.cards = toasts.cards.filter(c => c !== card)

                    Timer {
                        interval: Notifications.timeout(card.notification)
                        running: interval > 0 && !hover.hovered
                        onTriggered: card.notification.expire()
                    }

                    HoverHandler {
                        id: hover
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            const action = card.notification.actions.find(a => a.identifier === "default");
                            if (m.button === Qt.LeftButton && action)
                                action.invoke();
                            card.notification.dismiss();
                        }
                    }

                    // The urgency, in the place of a module's underline.
                    Rectangle {
                        x: Theme.popupPadding
                        y: Theme.popupPaddingV + Theme.popupTextInsetV
                        width: 3
                        height: parent.height - 2 * y
                        radius: 1.5
                        color: card.accent
                    }

                    Column {
                        id: content
                        x: Theme.popupPadding + Theme.popupTextInset
                        y: Theme.popupPaddingV + Theme.popupTextInsetV
                        width: parent.width - x - Theme.popupPadding - Theme.popupTextInset + 3
                        spacing: 4

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
                                    color: buttonMouse.containsMouse ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0.5)

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
            }
        }
    }
}
