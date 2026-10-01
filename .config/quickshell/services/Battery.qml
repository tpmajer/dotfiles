pragma Singleton

import QtQuick
import Quickshell
import qs
import Quickshell.Io

// BAT1 read from sysfs every 5 s and on power_supply udev events. Capacity is
// scaled so the 80% charge threshold reads as 100%, with notify-send on low
// battery and when charging reaches full.
Singleton {
    id: root

    readonly property int fullAt: 80
    readonly property string sysfs: "/sys/class/power_supply/BAT1/"

    property int capacity: 0
    property string status: ""
    readonly property bool charging: status === "Charging"
    readonly property bool discharging: status === "Discharging"
    property real hoursLeft: -1

    // States by capacity: good up to 100, normal 94, warning 25, critical 15
    readonly property string state: capacity <= 15 ? "critical" : capacity <= 25 ? "warning" : capacity <= 94 ? "normal" : "good"

    readonly property color color: charging || state === "good" ? Theme.green : (state === "warning" || state === "critical") ? Theme.maroon : Theme.red

    readonly property var chargingIcons: [0xf089c, 0xf0086, 0xf0087, 0xf0088, 0xf089d, 0xf0089, 0xf089e, 0xf008a, 0xf008b, 0xf0085]
    readonly property var defaultIcons: [0xf007a, 0xf007b, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0080, 0xf0081, 0xf0082, 0xf0079]
    readonly property string icon: Theme.glyph((charging ? chargingIcons : defaultIcons)[Math.min(9, Math.floor(capacity / 10))])

    readonly property string timeText: {
        if (hoursLeft < 0)
            return "";
        const minutes = Math.round(hoursLeft * 60);
        return `${Math.floor(minutes / 60)} h ${minutes % 60} min`;
    }

    property string lastEvent: ""

    function read(file) {
        file.reload();
        return file.text().trim();
    }

    function refresh() {
        const raw = Number(read(capacityFile));
        const chargeNow = Number(read(chargeNowFile));
        const chargeFull = Number(read(chargeFullFile));
        const current = Number(read(currentFile));
        status = read(statusFile);
        capacity = Math.min(100, Math.round(raw * 100 / fullAt));

        if (current > 0 && discharging)
            hoursLeft = chargeNow / current;
        else if (current > 0 && charging)
            hoursLeft = Math.max(0, chargeFull * fullAt / 100 - chargeNow) / current;
        else
            hoursLeft = -1;

        let event = "";
        if (discharging && (state === "warning" || state === "critical"))
            event = "discharging-" + state;
        else if (charging && capacity >= 100)
            event = "charging-100";
        if (event !== lastEvent) {
            lastEvent = event;
            if (event === "discharging-warning")
                Quickshell.execDetached(["notify-send", "-u", "normal", "Low Battery"]);
            else if (event === "discharging-critical")
                Quickshell.execDetached(["notify-send", "-u", "critical", "Very Low Battery!"]);
            else if (event === "charging-100")
                Quickshell.execDetached(["notify-send", "-u", "normal", "Battery Full"]);
        }
    }

    FileView { id: capacityFile; path: root.sysfs + "capacity"; blockLoading: true }
    FileView { id: statusFile; path: root.sysfs + "status"; blockLoading: true }
    FileView { id: chargeNowFile; path: root.sysfs + "charge_now"; blockLoading: true }
    FileView { id: chargeFullFile; path: root.sysfs + "charge_full"; blockLoading: true }
    FileView { id: currentFile; path: root.sysfs + "current_now"; blockLoading: true }

    // Plug/unplug shows up immediately instead of on the next poll.
    Process {
        id: udev
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=power_supply"]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
        onExited: udevRestart.start()
    }

    Timer {
        id: udevRestart
        interval: 5000
        onTriggered: udev.running = true
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
