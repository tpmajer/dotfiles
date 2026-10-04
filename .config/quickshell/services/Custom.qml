pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The idle inhibitor module, backed by scripts/idle-inhibit.sh, which prints
// JSON: {"text", "tooltip", "class"}. Asked right after a toggle, and every
// half a minute for what ends it elsewhere: its timeout, or a suspend.
// The module also tells that the system is idle, and how long is left until
// it locks.
Singleton {
    id: root

    readonly property string scripts: Quickshell.shellDir + "/scripts/"

    property var idle: ({})

    // What hypridle does once nothing is touched, and after how many
    // seconds: the listeners of ~/.config/hypr/hypridle.conf, to be kept the
    // same as there.
    readonly property var idleStages: [
        {label: "Dim", after: 120},
        {label: "Lock", after: 180},
        {label: "Screen off", after: 210},
        {label: "Suspend", after: 600}
    ]
    readonly property int lockAfter: 180
    // Idle is told after this long, in seconds.
    readonly property int idleAfter: 30

    // Nothing touched for idleAfter, and nothing holds the idle off: hypridle
    // is on its way to the lock. The script's inhibitor is logind's, which
    // the compositor, and so the monitor, knows nothing of.
    readonly property bool systemIdle: idleMonitor.isIdle && idle.class !== "activated"
    // When the last thing was touched, in ms; told idleAfter later.
    property real idleSince: 0

    // The time left until the lock, as "2:05", at the given time.
    function lockCountdown(now) {
        const left = Math.max(0, Math.round(lockAfter - (now.getTime() - idleSince) / 1000));
        return Math.floor(left / 60) + ":" + String(left % 60).padStart(2, "0");
    }

    IdleMonitor {
        id: idleMonitor
        timeout: root.idleAfter
        onIsIdleChanged: if (isIdle)
            root.idleSince = Date.now() - root.idleAfter * 1000
    }

    function parse(text) {
        try {
            return JSON.parse(text.trim());
        } catch (e) {
            return {};
        }
    }

    function toggleIdle() {
        idleToggle.running = true;
    }

    Process {
        id: idleStatus
        command: [root.scripts + "idle-inhibit.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.idle = root.parse(text)
        }
    }

    Process {
        id: idleToggle
        command: [root.scripts + "idle-inhibit.sh", "toggle"]
        onExited: idleStatus.running = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: idleStatus.running = true
    }
}
