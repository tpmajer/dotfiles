pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The idle inhibitor module, backed by scripts/idle-inhibit.sh, which tells
// by its exit code whether the inhibitor is on. Asked right after a toggle,
// and every half a minute for what ends it elsewhere: its timeout, or a
// suspend. The module also tells that the system is idle, and how long is
// left until it locks.
Singleton {
    id: root

    readonly property string scripts: Quickshell.shellDir + "/scripts/"

    property bool inhibited: false

    // What hypridle does once nothing is touched, and after how many
    // seconds: the listeners of its configuration, told by their commands.
    readonly property var stageCommands: [
        {label: "Dim", command: /idle-dim\.sh dim/},
        {label: "Lock", command: /lock-session/},
        {label: "Screen off", command: /power-off-monitors/},
        {label: "Suspend", command: /systemctl suspend/}
    ]
    readonly property var stages: {
        const stages = [];
        for (const stage of stageCommands) {
            const listener = listeners.find(l => stage.command.test(l.command));
            if (listener)
                stages.push({label: stage.label, after: listener.after});
        }
        stages.sort((a, b) => a.after - b.after);
        return stages;
    }
    // 0 with no lock among the stages: nothing to count down to.
    readonly property int lockAfter: stages.find(s => s.label === "Lock")?.after ?? 0
    readonly property bool locks: lockAfter > 0
    // Idle is told after this long, in seconds: its notification's listener.
    readonly property int idleAfter: listeners.find(l => /notify-replace\.sh idle/.test(l.command))?.after ?? 30

    // The listeners that are not commented out: [{ after: the timeout, in
    // seconds; command: what it runs then, without its comment }].
    property string hypridle: ""
    readonly property var listeners: {
        const found = [];
        // A block ends at the brace that starts a line, not at one in a
        // command or a comment.
        const block = /^[ \t]*listener\s*\{([\s\S]*?)^[ \t]*\}/gm;
        for (let m = block.exec(hypridle); m; m = block.exec(hypridle)) {
            const after = m[1].match(/^\s*timeout\s*=\s*(\d+)/m);
            const command = m[1].match(/^\s*on-timeout\s*=\s*(.*)$/m);
            if (after && command)
                found.push({after: Number(after[1]), command: command[1].replace(/\s#.*$/, "")});
        }
        return found;
    }

    // Read when hypridle starts, not when the file changes: hypridle goes
    // by what it read then.
    FileView {
        id: configuration
        path: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
        printErrors: false
        onLoaded: root.hypridle = text()
    }

    // When hypridle was started, as systemd tells it; asked with the
    // inhibitor.
    property string hypridleStart: ""

    Process {
        id: hypridleStatus
        command: ["systemctl", "--user", "show", "hypridle.service", "-p", "ExecMainStartTimestampMonotonic", "--value"]
        stdout: StdioCollector {
            onStreamFinished: {
                const start = text.trim();
                if (start === root.hypridleStart)
                    return;
                root.hypridleStart = start;
                configuration.reload();
            }
        }
    }

    // Nothing touched for idleAfter, and nothing holds the idle off: hypridle
    // is on its way to the lock. The script's inhibitor is logind's, which
    // the compositor, and so the monitor, knows nothing of.
    readonly property bool systemIdle: idleMonitor.isIdle && !inhibited
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

    // A toggle ended while the state was being asked: the answer may be
    // from before it, so it is asked again.
    property bool stale: false

    function toggle() {
        idleToggle.running = true;
    }

    Process {
        id: idleStatus
        command: [root.scripts + "idle-inhibit.sh"]
        onExited: exitCode => {
            if (!root.stale) {
                root.inhibited = exitCode === 0;
                return;
            }
            root.stale = false;
            Qt.callLater(() => idleStatus.running = true);
        }
    }

    Process {
        id: idleToggle
        command: [root.scripts + "idle-inhibit.sh", "toggle"]
        onExited: {
            if (idleStatus.running)
                root.stale = true;
            else
                idleStatus.running = true;
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            idleStatus.running = true;
            hypridleStatus.running = true;
        }
    }
}
