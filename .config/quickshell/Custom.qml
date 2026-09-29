pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The two script-backed modules: idle inhibitor and network.
// Both scripts print JSON: {"text", "tooltip", "class"}.
Singleton {
    id: root

    readonly property string scripts: Quickshell.shellDir + "/scripts/"

    property var idle: ({})
    property var network: ({})

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

    Process {
        id: networkStatus
        command: [root.scripts + "network.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.network = root.parse(text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            idleStatus.running = true;
            networkStatus.running = true;
        }
    }
}
