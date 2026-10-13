pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The laptop panel's backlight, read from sysfs on backlight udev events.
Singleton {
    id: root

    readonly property int percent: level.percent

    // The brightness changed after startup (the keys, brightnessctl, anything).
    signal changed

    // A fade is under way (scripts/idle-dim.sh), which is not announced.
    // It ends by itself, should the script not say so.
    property bool quiet: false
    onQuietChanged: if (quiet)
        quietEnd.restart()
    Timer {
        id: quietEnd
        interval: 5000
        onTriggered: root.quiet = false
    }

    SysfsLevel {
        id: level
        sysfs: "/sys/class/backlight/amdgpu_bl1/"
        quiet: root.quiet
        onChanged: root.changed()
    }

    Process {
        id: udev
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("change"))
                    level.reload();
            }
        }
        onExited: udevRestart.start()
    }

    Timer {
        id: udevRestart
        interval: 5000
        onTriggered: udev.running = true
    }
}
