import QtQuick

// The wheel's turns counted in steps, one per notch of a mouse's wheel: a
// touchpad sends a notch in many small turns. What takes the wheel passes
// each turn's angleDelta.y to turn().
QtObject {
    id: root

    // What is turned short of a step.
    property real turned: 0

    signal stepped(int steps)

    function turn(delta) {
        // A turn back starts anew.
        if (turned * delta < 0)
            turned = 0;
        turned += delta;
        const steps = Math.trunc(turned / 120);
        turned -= steps * 120;
        if (steps !== 0)
            stepped(steps);
    }
}
