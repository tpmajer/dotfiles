pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The spectrum of what the computer plays, for the bar's wave: cava,
// run only while a player plays, and not behind the lock. It also tells
// when a player plays and nothing sounds here: Spotify on a Connect
// device.
Singleton {
    id: root

    // Set by the shell.
    property bool locked: false

    // As many as cava.conf has cava make.
    readonly property int bars: 15
    readonly property bool wanted: Media.playing && !locked
    // One level a bar, 0 to 1; all 0 while cava does not run.
    property var levels: Array(bars).fill(0)
    // Nothing has sounded for a while with cava running. Spotify keeps
    // its stream open on a Connect device, so the silence is what tells.
    property bool silent: false

    Process {
        id: cava
        command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]
        // Not while it waits to be started again, see below.
        running: root.wanted && !again.running
        stdout: SplitParser {
            onRead: line => {
                const values = line.split(";").slice(0, root.bars).map(n => Math.min(1, (parseInt(n) || 0) / 100));
                if (values.length !== root.bars)
                    return;
                if (values.some(v => v > 0)) {
                    root.silent = false;
                    quiet.restart();
                } else if (root.silent) {
                    return;
                }
                root.levels = values;
            }
        }
        onRunningChanged: {
            root.silent = false;
            if (running) {
                quiet.restart();
            } else {
                quiet.stop();
                root.levels = Array(root.bars).fill(0);
                // It went by itself, with a player still playing: PipeWire
                // was restarted, or it crashed.
                if (root.wanted)
                    again.restart();
            }
        }
    }

    // cava is started again once this is over.
    Timer {
        id: again
        interval: 2000
    }

    // Longer than the gap between two tracks.
    Timer {
        id: quiet
        interval: 1500
        onTriggered: root.silent = true
    }

    IpcHandler {
        target: "spectrum"

        // For tests: `qs ipc call spectrum state`.
        function state(): string {
            return JSON.stringify({
                wanted: root.wanted,
                running: cava.running,
                silent: root.silent,
                levels: root.levels
            });
        }
    }
}
