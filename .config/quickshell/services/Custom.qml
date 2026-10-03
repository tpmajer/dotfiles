pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The idle inhibitor module, backed by scripts/idle-inhibit.sh, which prints
// JSON: {"text", "tooltip", "class"}. Asked right after a toggle, and every
// half a minute for what ends it elsewhere: its timeout, or a suspend.
Singleton {
    id: root

    readonly property string scripts: Quickshell.shellDir + "/scripts/"

    property var idle: ({})

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
