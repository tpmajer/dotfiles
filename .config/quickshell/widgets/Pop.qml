import QtQuick

// The "pop" of the bar's popups, the OSD and the power menu: quick with a
// slight overshoot in, quicker out, scaling from 0.9 and back to 0.95 while it
// fades. What pops takes its opacity from openness and its scale from scale,
// around a point of its choice.
QtObject {
    id: root

    // Whether it is to be there.
    property bool shown: false
    // Its window is on screen, for what has one of its own. Opening waits for
    // that: mapping the window takes a few frames, which would otherwise come
    // out of the animation's start.
    property bool mapped: true

    property real openness: shown && mapped ? 1 : 0
    Behavior on openness {
        // The target is already set when this starts, so shown tells open from close.
        NumberAnimation {
            duration: root.shown ? 220 : 120
            easing.type: root.shown ? Easing.OutBack : Easing.InQuad
            easing.overshoot: 1.2
        }
    }
    readonly property real scale: shown ? 0.9 + 0.1 * openness : 0.95 + 0.05 * openness
}
