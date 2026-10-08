pragma Singleton

import QtQuick
import Quickshell
import qs
import Quickshell.Io

// BAT1 read from sysfs every 5 s and on power_supply udev events, with
// notify-send on low battery and when charging reaches the charge limit.
// Capacity is of the whole battery, so at a limit of 80% it stops at 80. For
// the popup: the power going out or in, and how worn the battery is.
Singleton {
    id: root

    // The charge limit, in percent of the whole battery: read with the rest,
    // this until then and if the battery has none.
    property int fullAt: 80
    // What the limit is kept at, and what the popup's switch goes back to.
    readonly property int limitedAt: 80
    readonly property bool limited: fullAt < 100
    readonly property string sysfs: "/sys/class/power_supply/BAT1/"

    property int capacity: 0
    property string status: ""
    readonly property bool charging: status === "Charging"
    readonly property bool discharging: status === "Discharging"
    property real hoursLeft: -1
    // What the battery gives or takes, in watts; 0 while it does neither.
    property real watts: 0
    // What is left of the capacity it was made with, in percent.
    property int health: 0
    property int cycles: 0

    // States by capacity: good up to 100, normal 94, warning 25, critical 15
    readonly property string state: capacity <= 15 ? "critical" : capacity <= 25 ? "warning" : capacity <= 94 ? "normal" : "good"

    // Green, but while it runs low: peach as a warning, then red, the colors
    // the CPU, the memory and the Wi-Fi signal warn in.
    readonly property color color: !discharging ? Theme.green : state === "critical" ? Theme.red : state === "warning" ? Theme.peach : Theme.green

    readonly property var chargingIcons: [0xf089c, 0xf0086, 0xf0087, 0xf0088, 0xf089d, 0xf0089, 0xf089e, 0xf008a, 0xf008b, 0xf0085]
    readonly property var defaultIcons: [0xf007a, 0xf007b, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0080, 0xf0081, 0xf0082, 0xf0079]
    readonly property string icon: Theme.glyph((charging ? chargingIcons : defaultIcons)[Math.min(9, Math.floor(capacity / 10))])

    readonly property string timeText: {
        if (hoursLeft < 0)
            return "";
        const minutes = Math.round(hoursLeft * 60);
        return `${Math.floor(minutes / 60)} h ${minutes % 60} min`;
    }

    // The popup's rows: a label and a value.
    readonly property var details: {
        const list = [];
        if (timeText !== "")
            list.push({label: charging ? "Full in" : "Empty in", value: timeText});
        if (watts > 0)
            list.push({label: charging ? "Charging" : "Power", value: watts.toFixed(1) + " W"});
        if (health > 0)
            list.push({label: "Health", value: health + "%"});
        if (cycles > 0)
            list.push({label: "Cycles", value: String(cycles)});
        return list;
    }

    // The limit off, to charge the battery full, or back on. Only root can
    // write it: battery-charge-limit@.service does, and polkit lets it be
    // started (~/.nixos, modules/power.nix).
    function toggleLimit() {
        limitSwitch.command = ["systemctl", "--no-ask-password", "start", "battery-charge-limit@" + (limited ? 100 : limitedAt) + ".service"];
        limitSwitch.running = true;
    }

    Process {
        id: limitSwitch
        onExited: root.refresh()
    }

    property string lastEvent: ""

    // reload() only starts the read; without the wait, text() is still the
    // previous content.
    function read(file) {
        file.reload();
        file.waitForJob();
        return file.text().trim();
    }

    function refresh() {
        const chargeNow = Number(read(chargeNowFile));
        const chargeFull = Number(read(chargeFullFile));
        const current = Number(read(currentFile));
        const design = Number(read(chargeDesignFile));
        const limit = Number(read(limitFile));
        if (limit > 0 && limit <= 100)
            fullAt = limit;
        status = read(statusFile);
        capacity = Number(read(capacityFile));
        // Microamperes by microvolts.
        watts = charging || discharging ? current * Number(read(voltageFile)) / 1e12 : 0;
        health = design > 0 ? Math.round(chargeFull * 100 / design) : 0;
        cycles = Number(read(cyclesFile)) || 0;

        if (current > 0 && discharging)
            hoursLeft = chargeNow / current;
        else if (current > 0 && charging)
            hoursLeft = Math.max(0, chargeFull * fullAt / 100 - chargeNow) / current;
        else
            hoursLeft = -1;

        let event = "";
        if (discharging && (state === "warning" || state === "critical"))
            event = "discharging-" + state;
        else if (charging && capacity >= fullAt)
            event = "charging-100";
        if (event !== lastEvent) {
            lastEvent = event;
            if (event === "discharging-warning")
                Quickshell.execDetached(["notify-send", "-u", "normal", "Low Battery"]);
            else if (event === "discharging-critical")
                Quickshell.execDetached(["notify-send", "-u", "critical", "Very Low Battery!"]);
            else if (event === "charging-100")
                Quickshell.execDetached(["notify-send", "-u", "low", "Battery Full"]);
        }
    }

    FileView { id: capacityFile; path: root.sysfs + "capacity"; blockLoading: true }
    FileView { id: statusFile; path: root.sysfs + "status"; blockLoading: true }
    FileView { id: chargeNowFile; path: root.sysfs + "charge_now"; blockLoading: true }
    FileView { id: chargeFullFile; path: root.sysfs + "charge_full"; blockLoading: true }
    FileView { id: currentFile; path: root.sysfs + "current_now"; blockLoading: true }
    FileView { id: voltageFile; path: root.sysfs + "voltage_now"; blockLoading: true }
    FileView { id: chargeDesignFile; path: root.sysfs + "charge_full_design"; blockLoading: true }
    FileView { id: limitFile; path: root.sysfs + "charge_control_end_threshold"; blockLoading: true }
    FileView { id: cyclesFile; path: root.sysfs + "cycle_count"; blockLoading: true }

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
