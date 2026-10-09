import QtQuick
import Quickshell

// A 1 px region to put inside a blur region, where it blurs nothing new.
// With Qt's threaded render loop a new blur region can reach niri with an
// older commit, and is then not applied until the region changes again:
// send() changes this one's height a few more times, 48 ms apart.
Region {
    id: root

    property int sent: 0

    function send(times) {
        timer.left = times;
        timer.restart();
    }

    width: 1
    height: 1 + sent % 2

    property Timer timer: Timer {
        id: timer
        property int left: 0
        interval: 48
        repeat: true
        onTriggered: {
            root.sent++;
            if (--left <= 0)
                stop();
        }
    }
}
