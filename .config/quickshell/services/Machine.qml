pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The machine's state for the power module: read every minute by
// scripts/machine.py, and at once as the module's popup opens.
Singleton {
    id: root

    // Milliseconds since the epoch; wokeAt is 0 if it has not slept.
    property real bootedAt: 0
    property real wokeAt: 0
    property string kernel: ""
    // 0 if the running system is no generation.
    property int generation: 0
    // What runs is no longer what the system would boot.
    property bool restartPending: false
    property string nextKernel: ""
    property var failedUnits: []
    // Who blocks sleep or shutdown.
    property var blockers: []

    // The module's color: it tells of failed units and of a restart due.
    readonly property color color: failedUnits.length > 0 ? Theme.red : restartPending ? Theme.peach : Theme.subtext0

    function refresh() {
        reader.running = true;
    }

    // A time as "2 d 4 h", "3 h 12 min" or "24 min".
    function span(ms) {
        const minutes = Math.max(0, Math.floor(ms / 60000));
        const hours = Math.floor(minutes / 60);
        if (hours >= 24)
            return Math.floor(hours / 24) + " d " + hours % 24 + " h";
        return (hours > 0 ? hours + " h " : "") + minutes % 60 + " min";
    }

    // The first of the names, and how many more there are.
    function names(list) {
        return list[0] + (list.length > 1 ? " +" + (list.length - 1) : "");
    }

    // The popup's rows at the given time: a label and a value.
    function details(now) {
        const list = [];
        if (bootedAt > 0)
            list.push({label: "Uptime", value: span(now - bootedAt)});
        if (wokeAt > 0)
            list.push({label: "Awake", value: span(now - wokeAt)});
        if (kernel !== "")
            list.push({label: "Kernel", value: kernel});
        if (generation > 0)
            list.push({label: "Generation", value: String(generation)});
        if (restartPending)
            list.push({label: "Restart", value: nextKernel !== "" && nextKernel !== kernel ? "to " + nextKernel : "needed", color: Theme.peach});
        if (failedUnits.length > 0)
            list.push({label: "Failed", value: names(failedUnits), color: Theme.red});
        if (blockers.length > 0)
            list.push({label: "Inhibited by", value: names(blockers)});
        return list;
    }

    Process {
        id: reader
        command: [Quickshell.shellDir + "/scripts/machine.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                let state;
                try {
                    state = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.bootedAt = state.booted * 1000;
                root.wokeAt = state.woke * 1000;
                root.kernel = state.kernel;
                root.generation = state.generation;
                root.restartPending = state.restart;
                root.nextKernel = state.nextKernel;
                root.failedUnits = state.failed;
                root.blockers = state.blockers;
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
