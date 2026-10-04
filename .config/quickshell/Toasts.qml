import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// Notifications: a stack of cards in a corner of the focused output, the
// newest at the bottom. A card stays for a time set by its urgency (not while
// the pointer is over it), then goes to the notification center in the bar; a
// left click runs its default action and closes it, a right click only closes
// it. A card whose time is up, or closed with a right click, fades out before
// the others close ranks; one closed by its action or its sender is gone at
// once. A card whose sender takes a reply has a field for it, and stays while
// one is being written. Only the newest few are shown; the rest fold into a
// row at the top that unfolds them on a click. None goes while the session is
// locked: they are all there, for their whole time, once it is not.
PanelWindow {
    id: toasts

    readonly property bool atTop: Theme.notificationsPosition.startsWith("top")
    readonly property bool atLeft: Theme.notificationsPosition.endsWith("left")
    // Room around the cards for their shadow.
    readonly property int shadowRoom: 30
    property var cards: []
    readonly property int count: Notifications.toasts.length
    // The cards fading out: no longer toasts, still in the stack. They count
    // against the visible ones, so that none unfolds into the stack before
    // they are gone.
    readonly property int fading: cards.filter(c => c.fading === true).length
    readonly property int hiddenCount: Math.max(0, count + fading - Theme.notificationsVisible)
    property bool expanded: false
    // The session is locked: the lock is over the cards, nobody sees them.
    property bool locked: false
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
    // There while a card is: not by count and fading, which change one
    // after the other when the last toast's time is up. Between the two the
    // window would go, and come back sliding in from the side. By the
    // cards' present, not their visible: that one is false for everything
    // in a window that is not there, which would then never come back.
    visible: cards.some(c => c.present)

    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // The keyboard only on a click, and only with a reply field to click
    // on. Taken away for a moment once a reply is closed: the window that
    // had the keyboard gets it back.
    readonly property bool hasReply: Notifications.toasts.some(n => n.hasInlineReply)
    property bool releasing: false
    Timer {
        id: releaseTimer
        interval: 50
        onTriggered: toasts.releasing = false
    }
    WlrLayershell.keyboardFocus: hasReply && !releasing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the cards take input and get blurred, not the gaps or the shadow room.
    mask: Region {
        regions: toasts.cards.filter(c => c.visible).map(c => c.inputRegion)
    }
    // Not under a card half faded out, as with the OSD.
    readonly property var blurred: cards.filter(c => c.visible && (c.openness ?? 1) > 0.5)
    BackgroundEffect.blurRegion: Region {
        regions: toasts.blurred.map(c => c.blurRegion).concat(toasts.blurred.length > 0 ? [toasts.blurBump] : [])
    }

    // A new blur region can reach niri with a commit older than itself, and
    // is then not applied until the region changes again (see PopupHost): a
    // card stays without its blur, or the blur stays without its card. So
    // the region is sent a few more times after the cards change, past the
    // end of their slide: each bump resizes a 1 px region inside the first
    // card, which blurs nothing new.
    property int blurResend: 0
    readonly property Region blurBump: Region {
        readonly property var card: toasts.blurred[0] ?? null
        x: card ? stack.x + card.x + Theme.barRadius : 0
        y: card ? stack.y + card.y + Theme.barRadius : 0
        width: 1
        height: 1 + toasts.blurResend % 2
    }
    onBlurredChanged: {
        blurResendTimer.left = 10;
        blurResendTimer.restart();
    }
    Timer {
        id: blurResendTimer
        property int left: 0
        interval: 48
        repeat: true
        onTriggered: {
            toasts.blurResend++;
            if (--left <= 0)
                stop();
        }
    }

    Item {
        anchors.fill: parent

        layer.enabled: true
        layer.effect: Shadow {}

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
                // The fold row has neither: it is just there.
                opacity: modelData.openness ?? 1
                scale: modelData.popScale ?? 1
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

        // With cards folded, a new one takes the place of the card above it
        // and the stack does not grow, so it does not slide: the card comes
        // up from below on its own, as the stack would have brought it. Only
        // the newest: one unfolded by another's leaving is just there.
        add: Transition {
            id: arrive
            enabled: !toasts.atTop && toasts.live && toasts.hiddenCount > 0 && !toasts.expanded
            NumberAnimation {
                // There is no item once the transition is over.
                readonly property Item item: arrive.ViewTransition.item
                property: "y"
                from: arrive.ViewTransition.destination.y + (item && item.toastIndex === toasts.count - 1 ? item.height + Theme.notificationGap : 0)
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

            readonly property bool present: toasts.hiddenCount > 0
            visible: present
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
            // Every notification, so that a card and its timer are not made
            // anew as the others come and go; those not toasts are hidden.
            model: Notifications.tracked

            Rectangle {
                id: card

                required property var modelData
                readonly property var notification: modelData
                // Its place among the toasts; -1 once it waits in the center.
                readonly property int toastIndex: Notifications.toasts.indexOf(notification)
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
                // Among the cards shown: a toast, and not folded.
                readonly property bool shown: toastIndex >= 0 && (toasts.expanded || toastIndex >= toasts.hiddenCount)
                // What is to be done to the notification once its card has
                // faded out: closing it after a right click, or when the time
                // of a transient one is up. Both take the card with them.
                property var leave: null
                readonly property bool leaving: leave !== null
                // To be seen whole; in a top corner a new card fades in
                // instead of sliding in.
                readonly property bool open: shown && !leaving && (appeared || !toasts.atTop)
                // Its time is up or it is being closed: still there, fading.
                readonly property bool fading: (toastIndex < 0 || leaving) && openness > 0
                onOpennessChanged: if (leaving && openness === 0)
                    leave()
                // A folded card has faded out already: there is nothing to
                // wait for, and it would stay a toast nobody sees.
                onLeavingChanged: if (leaving && openness === 0)
                    leave()

                // 1 with the card there, 0 with it gone. It goes as the OSD
                // and the bar's popups do (widgets/Pop.qml): quickly, down
                // to 0.95 of its size while it fades. In a bottom corner it
                // comes at once, and so does an unfolded card. By the value
                // it goes to, which is set by the time the animation starts;
                // what the card's own properties say then is not certain.
                property real openness: open ? 1 : 0
                Behavior on openness {
                    id: fade
                    NumberAnimation {
                        duration: fade.targetValue === 0 ? 120 : toasts.atTop ? Theme.hoverDuration : 0
                        easing.type: fade.targetValue === 0 ? Easing.InQuad : Easing.Linear
                    }
                }
                readonly property real popScale: open ? 1 : 0.95 + 0.05 * openness

                // A folded card is gone at once: it went into the row above.
                // One no longer a toast, or being closed, stays until it has
                // faded. Told from toastIndex here, not from shown and
                // fading: those change one after the other, and the card
                // would be gone between the two.
                readonly property bool present: toastIndex >= 0 && !leaving ? toasts.expanded || toastIndex >= toasts.hiddenCount : openness > 0
                visible: present
                width: Theme.notificationWidth
                height: body.implicitHeight
                radius: Theme.barRadius
                color: "transparent"   // the background is drawn below, with the shadow
                // What is on the card fades out twice as fast as its
                // background, drawn below: bright text on a nearly faded
                // card reads as the content outliving it.
                opacity: open ? openness : Math.max(0, 2 * openness - 1)
                scale: popScale

                Component.onCompleted: {
                    appeared = true;
                    toasts.cards = toasts.cards.concat([card]);
                }
                Component.onDestruction: toasts.cards = toasts.cards.filter(c => c !== card)

                // Replaced by its sender: its time starts anew.
                readonly property real arrivedAt: Notifications.time(notification)
                onArrivedAtChanged: if (timeLeft.running)
                    timeLeft.restart()

                Timer {
                    id: timeLeft
                    interval: Notifications.timeout(card.notification)
                    running: card.toastIndex >= 0 && interval > 0 && !hover.hovered && !body.replying && !toasts.locked
                    // A transient one is closed by this, so it fades first.
                    onTriggered: {
                        if (Notifications.isTransient(card.notification))
                            card.leave = () => Notifications.timedOut(card.notification);
                        else
                            Notifications.timedOut(card.notification);
                    }
                }

                HoverHandler {
                    id: hover
                }

                NotificationCard {
                    id: body
                    anchors.fill: parent
                    notification: card.notification
                    windowX: stack.x + card.x
                    devicePixelRatio: toasts.devicePixelRatio
                    replyEnabled: true
                    close: () => card.leave = () => card.notification.dismiss()
                    onReplyClosed: {
                        toasts.releasing = true;
                        releaseTimer.restart();
                    }
                }
            }
        }
    }
}
