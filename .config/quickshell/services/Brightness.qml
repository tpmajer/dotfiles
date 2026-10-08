pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The laptop panel's backlight, read from sysfs on backlight udev events.
Singleton {
    id: root

    readonly property string sysfs: "/sys/class/backlight/amdgpu_bl1/"

    property int percent: 0
    property bool ready: false

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

    function update() {
        const max = Number(maxFile.text().trim());
        if (!(max > 0))
            return;
        const now = Math.round(Number(valueFile.text().trim()) * 100 / max);
        const differs = now !== percent;
        percent = now;
        if (ready && differs && !quiet)
            changed();
        ready = true;
    }

    FileView { id: maxFile; path: root.sysfs + "max_brightness"; blockLoading: true }
    // reload() only starts the read; the new value is there in onLoaded.
    FileView { id: valueFile; path: root.sysfs + "brightness"; onLoaded: root.update() }

    Process {
        id: udev
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("change"))
                    valueFile.reload();
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
