pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Airplane mode: every radio (Wi-Fi, bluetooth) is blocked. `rfkill event`
// prints each radio once at startup and then again whenever its block changes.
Singleton {
    id: root

    property var blocked: ({})     // rfkill index -> blocked (soft or hard)
    readonly property bool airplane: {
        const states = Object.values(blocked);
        return states.length > 0 && states.every(b => b);
    }
    // False while the radios present at startup are still being listed.
    readonly property bool ready: !startup.running

    Process {
        id: events
        running: true
        command: ["rfkill", "event"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/idx (\d+) type \d+ op (\d+) soft (\d+) hard (\d+)/);
                if (!m)
                    return;
                const next = Object.assign({}, root.blocked);
                if (m[2] === "1")           // op 1: the radio is gone
                    delete next[m[1]];
                else
                    next[m[1]] = m[3] === "1" || m[4] === "1";
                root.blocked = next;
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: startup
        interval: 1000
        running: true
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: {
            root.blocked = ({});
            startup.restart();
            events.running = true;
        }
    }
}
