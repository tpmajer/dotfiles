pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The spectrum of what the computer plays, for the bar's wave: cava,
// run only while a player plays here. Not for Spotify on a Connect
// device, which makes no sound here, and not behind the lock.
Singleton {
    id: root

    // Set by the shell.
    property bool locked: false

    readonly property int bars: 5
    readonly property bool wanted: Media.playing && !Media.remote && !locked
    // One level a bar, 0 to 1; all 0 while cava does not run.
    property var levels: Array(bars).fill(0)

    Process {
        id: cava
        command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]
        running: root.wanted
        stdout: SplitParser {
            onRead: line => {
                const values = line.split(";").slice(0, root.bars).map(n => Math.min(1, (parseInt(n) || 0) / 100));
                if (values.length === root.bars)
                    root.levels = values;
            }
        }
        onRunningChanged: if (!running)
            root.levels = Array(root.bars).fill(0)
    }

    IpcHandler {
        target: "spectrum"

        // For tests: `qs ipc call spectrum state`.
        function state(): string {
            return JSON.stringify({
                wanted: root.wanted,
                running: cava.running,
                levels: root.levels
            });
        }
    }
}
