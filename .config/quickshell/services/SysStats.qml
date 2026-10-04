pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU (every 1 s) and memory (every 5 s) usage read from /proc, and the CPU's
// temperature (every 1 s) from its sensor in /sys. reload() only starts a
// read: without the wait, text() is still the previous content, a whole
// interval old.
Singleton {
    id: root

    property int cpuUsage: 0
    property var coreUsages: []
    property string loadAvg: ""
    // In °C; 0 until the sensor is found, or if there is none.
    property real cpuTemp: 0
    // 0 as it should be, 1 warm (from 80 °C), 2 hot (from 95 °C, close to
    // where the CPU throttles itself, at 100). A level is left 3 °C below
    // where it is entered: the reading moves a degree or two every second.
    property int cpuTempLevel: 0

    function tempLevel(temp, level) {
        if (temp >= 95 || (level === 2 && temp >= 92))
            return 2;
        if (temp >= 80 || (level >= 1 && temp >= 77))
            return 1;
        return 0;
    }

    property int memPercent: 0
    // 0 as it should be, 1 much of it taken (from 80%), 2 nearly all (from
    // 92%); left 3 points below where it is entered, like cpuTempLevel.
    property int memLevel: 0
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0

    property var prevCpu: ({})

    function parseStat(text) {
        const next = {};
        const cores = [];
        for (const line of text.split("\n")) {
            if (!line.startsWith("cpu"))
                continue;
            const parts = line.trim().split(/\s+/);
            const name = parts[0];
            const t = parts.slice(1).map(Number);
            const idle = t[3] + t[4];
            const total = t.reduce((a, b) => a + b, 0);
            next[name] = {idle, total};
            const prev = prevCpu[name];
            let usage = 0;
            if (prev && total > prev.total)
                usage = Math.round(100 * (1 - (idle - prev.idle) / (total - prev.total)));
            if (name === "cpu")
                cpuUsage = usage;
            else
                cores.push(usage);
        }
        prevCpu = next;
        coreUsages = cores;
    }

    function parseMeminfo(text) {
        const kb = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                kb[m[1]] = Number(m[2]);
        }
        const gib = 1024 * 1024;
        const used = kb.MemTotal - kb.MemAvailable;
        memPercent = Math.round(100 * used / kb.MemTotal);
        if (memPercent >= 92 || (memLevel === 2 && memPercent >= 89))
            memLevel = 2;
        else if (memPercent >= 80 || (memLevel >= 1 && memPercent >= 77))
            memLevel = 1;
        else
            memLevel = 0;
        memUsedGiB = used / gib;
        memTotalGiB = kb.MemTotal / gib;
        swapTotalGiB = kb.SwapTotal / gib;
        swapUsedGiB = (kb.SwapTotal - kb.SwapFree) / gib;
    }

    FileView {
        id: stat
        path: "/proc/stat"
        blockLoading: true
    }
    FileView {
        id: loadavg
        path: "/proc/loadavg"
        blockLoading: true
    }
    // The CPU's sensor is the hwmon device named k10temp (AMD) or coretemp
    // (Intel). Its number changes from boot to boot, so it is looked up once.
    FileView {
        id: temp
        blockLoading: true
    }
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in k10temp|coretemp) echo $h/temp1_input; break;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: temp.path = text.trim()
        }
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        blockLoading: true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            stat.waitForJob();
            root.parseStat(stat.text());
            loadavg.reload();
            loadavg.waitForJob();
            root.loadAvg = loadavg.text().split(" ").slice(0, 3).join("  ");
            if (temp.path != "") {
                temp.reload();
                temp.waitForJob();
                root.cpuTemp = Number(temp.text()) / 1000;
                root.cpuTempLevel = root.tempLevel(root.cpuTemp, root.cpuTempLevel);
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            meminfo.waitForJob();
            root.parseMeminfo(meminfo.text());
        }
    }
}
