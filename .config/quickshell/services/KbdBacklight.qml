pragma Singleton

import QtQuick
import Quickshell

// The keyboard's backlight. The laptop's controller steps it by itself
// (Fn+Space) and no event tells: read from sysfs four times a second, not
// behind the lock, where the OSD does not show.
Singleton {
    id: root

    readonly property int percent: level.percent
    property bool locked: false
    // A step taken behind the lock is not told of after it.
    onLockedChanged: if (!locked)
        quiet()

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

    SysfsLevel {
        id: level
        sysfs: "/sys/class/leds/chromeos::kbd_backlight/"
        printErrors: false
        quiet: quietEnd.running
        onChanged: root.changed()
    }

    Timer {
        interval: 250
        running: level.present && !root.locked
        repeat: true
        onTriggered: level.reload()
    }
}
