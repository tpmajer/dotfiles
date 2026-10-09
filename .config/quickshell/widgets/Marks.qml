import QtQuick
import qs

// A password field's marks, one per character typed, as in hyprlock: a mark
// fades and grows in at the end of the row, which stays centred in its
// parent by sliding, not jumping.
Row {
    id: root

    property int marks: 0
    // Pulses while the password is checked: PAM takes a couple of seconds.
    property bool checking: false
    // Green once the password is accepted, red when it is not.
    property bool accepted: false
    property bool rejected: false
    // Not where it is hidden while that happens: it would play it all when
    // it is next shown.
    property bool animated: true
    // As many as the field is wide.
    property int most: 18

    x: (parent.width - width) / 2
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    SequentialAnimation {
        running: root.checking && root.animated
        loops: Animation.Infinite
        onStarted: pulseEnd.stop()
        onStopped: pulseEnd.start()

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0.35
            duration: 450
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: 450
            easing.type: Easing.InOutSine
        }
    }

    // Back to full from wherever the pulse was.
    NumberAnimation {
        id: pulseEnd
        target: root
        property: "opacity"
        to: 1
        duration: 150
    }

    Behavior on x {
        enabled: root.animated
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Repeater {
        // Shown one per character: a Repeater counting the characters would
        // make all of them anew at every key.
        model: root.most

        // The bar's mark of the active workspace.
        PopupText {
            required property int index
            readonly property bool typed: index < root.marks

            text: Theme.glyph(0xf14fb)
            color: root.accepted ? Theme.green : root.rejected ? Theme.red : Theme.subtext1

            // Red comes in gradually. Green does not: what shows it is
            // gone within a few frames.
            Behavior on color {
                enabled: root.animated && !root.accepted
                ColorAnimation {
                    duration: 250
                }
            }
            opacity: typed ? 1 : 0
            scale: typed ? 1 : 0.4
            // Out of the row once faded: the row is as wide as what was
            // typed.
            visible: opacity > 0

            Behavior on opacity {
                enabled: root.animated
                NumberAnimation {
                    duration: typed ? 150 : 100
                }
            }
            Behavior on scale {
                enabled: root.animated
                NumberAnimation {
                    duration: typed ? 200 : 100
                    easing.type: typed ? Easing.OutBack : Easing.InQuad
                }
            }
        }
    }
}
