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
// a right click only closes it. Only the newest few are shown; the rest fold
// into a row at the top that unfolds them on a click.
PanelWindow {
    id: toasts

    readonly property bool atTop: Theme.notificationsPosition.startsWith("top")
    readonly property bool atLeft: Theme.notificationsPosition.endsWith("left")
    // Room around the cards for their shadow.
    readonly property int shadowRoom: 30
    property var cards: []
    readonly property int count: Notifications.list.values.length
    readonly property int hiddenCount: Math.max(0, count - Theme.notificationsVisible)
    property bool expanded: false
    onHiddenCountChanged: if (hiddenCount === 0)
        expanded = false

    // The window is on screen and has its size, so an animation started now is seen.
    property bool live: false
    onBackingWindowVisibleChanged: {
        if (backingWindowVisible) {
            liveTimer.restart();
        } else {
            liveTimer.stop();
            live = false;
        }
    }
    Timer {
        id: liveTimer
        interval: 50
        onTriggered: toasts.live = true
    }

    // The first card slides in from the side of the screen the stack is on:
    // 1 with the stack past that edge, 0 with it in place.
    property real enter: 1
    onLiveChanged: {
        if (live) {
            enterAnimation.restart();
        } else {
            enterAnimation.stop();
            enter = 1;
        }
    }
    NumberAnimation {
        id: enterAnimation
        target: toasts
        property: "enter"
        from: 1
        to: 0
        duration: Theme.notificationSlide
        easing.type: Easing.OutCubic
    }

    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    // The whole height of the screen: the window never resizes, so the stack
    // can slide inside it. It is there only while there are notifications.
    anchors {
        top: true
        bottom: true
        left: atLeft
        right: !atLeft
    }
    // Over everything and reserving nothing: anchored to three edges, the
    // window would otherwise claim its width and push the other windows aside.
    exclusionMode: ExclusionMode.Ignore
    margins {
        left: Theme.notificationMargin - shadowRoom
        right: Theme.notificationMargin - shadowRoom
    }
    implicitWidth: Theme.notificationWidth + 2 * shadowRoom
    color: "transparent"
    visible: count > 0

    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the cards take input and get blurred, not the gaps or the shadow room.
    mask: Region {
        regions: toasts.cards.filter(c => c.visible).map(c => c.inputRegion)
    }
    BackgroundEffect.blurRegion: Region {
        regions: toasts.cards.filter(c => c.visible).map(c => c.blurRegion)
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

        // Only the cards' backgrounds. Text drawn into the shadow's layer comes
        // out soft, so the cards themselves sit on top of this, outside it.
        Repeater {
            model: toasts.cards.filter(c => c.visible)

            Rectangle {
                required property var modelData
                x: stack.x + modelData.x
                y: stack.y + modelData.y
                width: modelData.width
                height: modelData.height
                radius: Theme.barRadius
                color: Theme.base
                opacity: modelData.opacity
            }
        }
    }

    Column {
        id: stack
        x: toasts.shadowRoom + toasts.enter * (toasts.atLeft ? -toasts.width : toasts.width)
        // In a bottom corner the stack ends at the bottom edge and slides up
        // as it grows: a new card comes from below the screen edge and
        // pushes the older ones up. Not before the window is on screen: the
        // stack takes its place unseen, then slides in from the side.
        y: toasts.atTop ? Theme.barMargin + Theme.barHeight + Theme.popupGap : Math.round(parent.height - Theme.notificationMargin - height)
        spacing: Theme.notificationGap

        Behavior on y {
            enabled: !toasts.atTop && toasts.live
            NumberAnimation {
                duration: Theme.notificationSlide
                easing.type: Easing.OutCubic
            }
        }
        // Same timing as the stack: when a card goes, the ones below it
        // stay where they are and the ones above come down.
        move: Transition {
            NumberAnimation {
                property: "y"
                duration: Theme.notificationSlide
                easing.type: Easing.OutCubic
            }
        }

        // The folded notifications: "+N more", or "Show less" once unfolded.
        Rectangle {
            id: fold

            // Explicit geometry: the cards move with the stack.
            readonly property Region inputRegion: Region {
                x: stack.x + fold.x
                y: stack.y + fold.y
                width: fold.width
                height: fold.height
            }
            readonly property Region blurRegion: Region {
                x: stack.x + fold.x
                y: stack.y + fold.y
                width: fold.width
                height: fold.height
                radius: Theme.barRadius
            }

            visible: toasts.hiddenCount > 0
            width: Theme.notificationWidth
            height: foldLabel.implicitHeight + 2 * Theme.popupPaddingV
            radius: Theme.barRadius
            color: "transparent"   // the background is drawn below, with the shadow

            Component.onCompleted: toasts.cards = toasts.cards.concat([fold])

            PopupText {
                id: foldLabel
                anchors.centerIn: parent
                text: toasts.expanded ? "Show less" : "+" + toasts.hiddenCount + " more"
                color: foldMouse.containsMouse ? Theme.text : Theme.subtext0
                font.pixelSize: Theme.fontSize - 2
            }

            MouseArea {
                id: foldMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: toasts.expanded = !toasts.expanded
            }
        }

        Repeater {
            model: Notifications.list

            Rectangle {
                id: card

                required property var modelData
                required property int index
                readonly property var notification: modelData
                readonly property color accent: notification.urgency === NotificationUrgency.Critical ? Theme.red : notification.urgency === NotificationUrgency.Low ? Theme.subtext0 : Theme.teal
                readonly property var extraActions: notification.actions.filter(a => a.identifier !== "default")
                readonly property Region inputRegion: Region {
                    x: stack.x + card.x
                    y: stack.y + card.y
                    width: card.width
                    height: card.height
                }
                readonly property Region blurRegion: Region {
                    x: stack.x + card.x
                    y: stack.y + card.y
                    width: card.width
                    height: card.height
                    radius: Theme.barRadius
                }
                property bool appeared: false

                visible: toasts.expanded || index >= toasts.hiddenCount
                width: Theme.notificationWidth
                height: content.implicitHeight + 2 * (Theme.popupPaddingV + Theme.popupTextInsetV)
                radius: Theme.barRadius
                color: "transparent"   // the background is drawn below, with the shadow
                // In a top corner it fades in instead.
                opacity: appeared || !toasts.atTop ? 1 : 0
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
                    // On whole device pixels, like a module's underline.
                    readonly property real windowX: stack.x + card.x + Theme.popupPadding
                    x: Theme.popupPadding + Theme.snap(windowX, toasts.devicePixelRatio) - windowX
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
