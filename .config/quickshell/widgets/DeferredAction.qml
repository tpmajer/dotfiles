import QtQuick
import Quickshell
import qs

// A power menu's action: the command runs only once the menu is gone and a
// frame without it has been drawn. The menu sets pending and closes. What
// locks (Lock, and Suspend through hypridle) starts from the desktop as it is
// then: the lock's curtain fades in over it, and hyprlock, the fallback,
// takes a screenshot of it. Either would show the closing menu.
Timer {
    id: root

    // The menu's: 0 once it has closed.
    property real openness: 0
    property string pending: ""

    interval: Theme.actionDelay
    onOpennessChanged: if (openness <= 0 && pending !== "")
        restart()
    onTriggered: {
        const command = pending;
        pending = "";
        if (command !== "")
            Quickshell.execDetached(["sh", "-c", command]);
    }
}
