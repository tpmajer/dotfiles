import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.services
import qs.widgets

// What a lock surface and a curtain both show: the clock, the date, the
// battery, the weather and the count of notifications, the password field
// and the fingerprint icon, over the wallpaper, blurred and dimmed.
Rectangle {
    id: view

    // The image awww shows on the view's output; none, and it is plain.
    property string wallpaper: ""
    // Whether the field animates what is typed. Not in a curtain: hidden
    // while that happens, it would play it all when it is next shown.
    property bool animated: true
    // The field: how many marks, pulsing while the password is checked, green
    // once it is accepted, red when it is not, and what the red marks turn
    // into.
    property int marks: 0
    property bool checking: false
    property bool accepted: false
    property bool rejected: false
    property string rejection: ""
    // The fingerprint icon: "", "waiting", "bad" or "ok" (Fingerprint.qml).
    property string fingerMark: ""
    // The line below the field.
    property bool capsLock: false
    property string status: ""

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    color: Theme.base

    Image {
        id: image
        anchors.fill: parent
        visible: false
        source: view.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // Fades in over the plain colour if the image is not in Qt's cache.
    // The curtain keeps it there, and then it is ready a moment after
    // the view is created, once the output is known: that must not fade.
    Item {
        id: backdrop
        property bool late: false

        anchors.fill: parent
        opacity: image.status === Image.Ready ? 1 : 0
        visible: opacity > 0

        Timer {
            interval: 50
            running: true
            onTriggered: backdrop.late = true
        }

        Behavior on opacity {
            enabled: backdrop.late && view.animated
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: image
            blurEnabled: true
            blur: 1
            blurMax: 64
            autoPaddingEnabled: false
        }

        // Dims the wallpaper, so the text reads on a bright one.
        Rectangle {
            anchors.fill: parent
            color: Theme.base
            opacity: 0.7
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 24

        PopupText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: 96
            font.bold: true
            color: Theme.subtext1
            opacity: 0.9
            // Qt's default renderer leaves text this large with rough,
            // colour-fringed edges.
            renderType: Text.CurveRendering
        }

        PopupText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Theme.subtext0
        }

        // The battery, the weather when it is known, and the notifications
        // when there are any.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            PopupText {
                text: Battery.icon + " " + Battery.capacity + "%"
                // Coloured only when low and not charging, as the
                // bar's warning; the bar's green for charging would read
                // as good.
                color: Battery.discharging && (Battery.state === "warning" || Battery.state === "critical") ? Battery.color : Theme.subtext0
            }

            PopupText {
                visible: Weather.known
                text: Weather.icon + " " + Weather.temperatureText
                color: Theme.subtext0
            }

            // How many notifications wait, under the bar's bell; none, and
            // it is not there.
            PopupText {
                visible: Notifications.waitingCount > 0
                text: Theme.glyph(Notifications.quiet ? 0xf009b : 0xf009a) + " " + Notifications.waitingCount
                color: Theme.subtext0
            }
        }

        Item {
            width: 1
            height: 24
        }

        // The password field: a mark per character typed.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: Theme.barHeight

            // The bar's shape and shadow (PopupHost), see-through as a
            // whole the way niri's layer rule makes the bar, only more:
            // the wallpaper under it is blurred already.
            Item {
                anchors.fill: parent
                opacity: 0.7

                layer.enabled: true
                layer.effect: Shadow {}

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: Theme.base
                }
            }

            PopupText {
                id: placeholder
                readonly property bool shown: view.marks === 0

                anchors.centerIn: parent

                text: view.rejection !== "" ? view.rejection : view.checking ? "checking…" : "password"
                color: view.rejection !== "" ? Theme.red : Theme.subtext0

                Behavior on color {
                    enabled: view.animated
                    ColorAnimation {
                        duration: 250
                    }
                }

                // Gone at the first key; back once the marks have faded.
                states: State {
                    name: "typing"
                    when: !placeholder.shown
                    PropertyChanges {
                        placeholder.opacity: 0
                    }
                }
                transitions: Transition {
                    from: "typing"
                    enabled: view.animated
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 100
                        }
                        NumberAnimation {
                            property: "opacity"
                            duration: 150
                        }
                    }
                }
            }

            // As in hyprlock: a mark fades and grows in at the end of the
            // row, which stays centred by sliding, not jumping.
            Row {
                id: marksRow
                x: (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Pulses while the password is checked: PAM takes a couple
                // of seconds to say no.
                SequentialAnimation {
                    running: view.checking && view.animated
                    loops: Animation.Infinite
                    onStarted: pulseEnd.stop()
                    onStopped: pulseEnd.start()

                    NumberAnimation {
                        target: marksRow
                        property: "opacity"
                        to: 0.35
                        duration: 450
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: marksRow
                        property: "opacity"
                        to: 1
                        duration: 450
                        easing.type: Easing.InOutSine
                    }
                }

                // Back to full from wherever the pulse was.
                NumberAnimation {
                    id: pulseEnd
                    target: marksRow
                    property: "opacity"
                    to: 1
                    duration: 150
                }

                Behavior on x {
                    enabled: view.animated
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {
                    // As many as the field is wide, shown one per
                    // character: a Repeater counting the characters
                    // would make all of them anew at every key.
                    model: 18

                    // The bar's mark of the active workspace.
                    PopupText {
                        required property int index
                        readonly property bool typed: index < view.marks

                        text: Theme.glyph(0xf14fb)
                        color: view.accepted ? Theme.green : view.rejected ? Theme.red : Theme.subtext1

                        // Red comes in gradually. Green does not: the
                        // curtain takes over within a few frames, and
                        // has it at once.
                        Behavior on color {
                            enabled: view.animated && !view.accepted
                            ColorAnimation {
                                duration: 250
                            }
                        }
                        opacity: typed ? 1 : 0
                        scale: typed ? 1 : 0.4
                        // Out of the row once faded: the row is as wide
                        // as what was typed.
                        visible: opacity > 0

                        Behavior on opacity {
                            enabled: view.animated
                            NumberAnimation {
                                duration: typed ? 150 : 100
                            }
                        }
                        Behavior on scale {
                            enabled: view.animated
                            NumberAnimation {
                                duration: typed ? 200 : 100
                                easing.type: typed ? Easing.OutBack : Easing.InQuad
                            }
                        }
                    }
                }
            }
        }

        // The reader waits for a finger; red for one it did not
        // recognise, green for one it did. Keeps its place when not
        // shown, so nothing moves.
        PopupText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.glyph(0xf0237)
            font.pixelSize: 36
            opacity: view.fingerMark === "" ? 0 : 1
            color: view.fingerMark === "ok" ? Theme.green : view.fingerMark === "bad" ? Theme.red : Theme.subtext0

            Behavior on opacity {
                enabled: view.animated
                NumberAnimation {
                    duration: 150
                }
            }
            Behavior on color {
                enabled: view.animated
                ColorAnimation {
                    duration: 150
                }
            }
        }

        PopupText {
            anchors.horizontalCenter: parent.horizontalCenter
            // Caps Lock, which matters while typing, else what the
            // reader or PAM had to say. Keeps its line when empty, so
            // nothing moves.
            text: view.capsLock ? "caps lock is on" : view.status !== "" ? view.status : " "
            color: view.capsLock ? Theme.peach : Theme.red
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
