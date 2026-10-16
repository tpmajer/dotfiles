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
    // Hidden while the screen is off; shown again, the lines come in one
    // after another.
    property bool concealed: false
    // Unlocking, on the curtain: 0 to 1, linear in time. The lines grow and
    // fade over the first 70%, the wallpaper sharpens.
    property real leaving: 0
    readonly property real fade: lines.ease(leaving / 0.7)

    Cascade {
        id: lines
        concealed: view.concealed
        animated: view.animated
    }

    SystemClock {
        id: day
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
            blur: 1 - lines.ease(view.leaving)
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
        opacity: 1 - view.fade
        scale: 1 + 0.06 * view.fade

        Step {
            cascade: lines
            order: 0

            PopupText {
                text: Qt.formatDateTime(day.date, "HH:mm")
                font.pixelSize: 96
                font.bold: true
                color: Theme.subtext1
                opacity: 0.9
                // Qt's default renderer leaves text this large with rough,
                // colour-fringed edges.
                renderType: Text.CurveRendering
            }
        }

        Step {
            cascade: lines
            order: 1

            PopupText {
                text: Qt.formatDateTime(day.date, "dddd, d MMMM")
                color: Theme.subtext0
            }
        }

        // The battery, the weather when it is known, and the notifications
        // when there are any.
        Step {
            cascade: lines
            order: 2

            Row {
                spacing: 24

                // The icon a little larger than the text, as in the bar.
                Row {
                    // Coloured only when low and not charging, as the
                    // bar's warning; the bar's green for charging would read
                    // as good.
                    readonly property color color: Battery.discharging && (Battery.state === "warning" || Battery.state === "critical") ? Battery.color : Theme.subtext0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    PopupText {
                        text: Battery.icon
                        color: parent.color
                        font.pixelSize: Theme.fontSize + 3
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    PopupText {
                        text: Battery.capacity + "%"
                        color: parent.color
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    visible: Weather.known
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    PopupText {
                        text: Weather.icon
                        color: Theme.subtext0
                        font.pixelSize: Theme.fontSize + 2
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    PopupText {
                        text: Weather.temperatureText
                        color: Theme.subtext0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // How many notifications wait, under the bar's bell; none, and
                // it is not there.
                PopupText {
                    visible: Notifications.waitingCount > 0
                    text: Theme.glyph(Notifications.quiet ? 0xf1f6 : 0xf0f3) + " " + Notifications.waitingCount
                    color: Theme.subtext0
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item {
            width: 1
            height: 24
        }

        Step {
            cascade: lines
            order: 3

            // The password field: a mark per character typed.
            Item {
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

                Marks {
                    marks: view.marks
                    checking: view.checking
                    accepted: view.accepted
                    rejected: view.rejected
                    animated: view.animated
                }
            }
        }

        Step {
            cascade: lines
            order: 4

            FingerMark {
                mark: view.fingerMark
                animated: view.animated
            }
        }

        Step {
            cascade: lines
            order: 5

            PopupText {
                // Caps Lock, which matters while typing, else what the
                // reader or PAM had to say. Keeps its line when empty, so
                // nothing moves.
                text: view.capsLock ? "caps lock is on" : view.status !== "" ? view.status : " "
                color: view.capsLock ? Theme.peach : Theme.red
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
