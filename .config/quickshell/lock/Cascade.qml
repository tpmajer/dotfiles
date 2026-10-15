import QtQuick

// Lines that come in one after another: hidden while concealed; uncovered,
// each fades in and rises into place (Step.qml). One file, two copies:
// ~/.dotfiles/.config/quickshell/lock and ~/.nixos/greeter; keep them alike.
QtObject {
    id: cascade

    property bool concealed: false
    // Off, and it shows or hides at once.
    property bool animated: true
    // Its time, 0 to 1.
    property real entrance: 1

    readonly property int stepDelay: 60
    readonly property int stepTime: 250
    readonly property int steps: 6
    readonly property int cascadeTime: stepTime + (steps - 1) * stepDelay

    function ease(t) {
        const c = Math.max(0, Math.min(1, t));
        return 1 - Math.pow(1 - c, 3);
    }

    // How far in the line at the given place in the cascade is.
    function stage(order) {
        return ease((entrance * cascadeTime - order * stepDelay) / stepTime);
    }

    // Made concealed: no change to react to.
    Component.onCompleted: {
        if (concealed)
            entrance = 0;
    }

    onConcealedChanged: {
        entering.stop();
        if (concealed)
            entrance = 0;
        else if (animated)
            entering.restart();
        else
            entrance = 1;
    }

    property NumberAnimation entering: NumberAnimation {
        target: cascade
        property: "entrance"
        from: 0
        to: 1
        duration: cascade.cascadeTime
    }
}
