pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The keyboard's backlight. The laptop's controller steps it by itself
// (Fn+Space) and no event tells: read from sysfs four times a second.
Singleton {
    id: root

    readonly property string sysfs: "/sys/class/leds/framework_laptop::kbd_backlight/"

    property int percent: 0
    property bool ready: false

    // The backlight changed after startup.
    signal changed

    // hypridle is about to turn it off or back on, which is not announced:
    // the next second's change. Longer than the wait for a read.
    function quiet() {
        quietEnd.restart();
    }
    Timer {
        id: quietEnd
        interval: 1000
    }

    function update() {
        const max = Number(maxFile.text().trim());
        if (!(max > 0))
            return;
        const now = Math.round(Number(valueFile.text().trim()) * 100 / max);
        const differs = now !== percent;
        percent = now;
        if (ready && differs && !quietEnd.running)
            changed();
        ready = true;
    }

    FileView { id: maxFile; path: root.sysfs + "max_brightness"; blockLoading: true; printErrors: false }
    // reload() only starts the read; the new value is there in onLoaded.
    FileView { id: valueFile; path: root.sysfs + "brightness"; printErrors: false; onLoaded: root.update() }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: valueFile.reload()
    }
}
