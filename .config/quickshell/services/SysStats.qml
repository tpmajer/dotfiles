pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU (every 1 s) and memory (every 5 s) usage read from /proc.
Singleton {
    id: root

    property int cpuUsage: 0
    property var coreUsages: []
    property string loadAvg: ""

    property int memPercent: 0
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
            root.parseStat(stat.text());
            loadavg.reload();
            root.loadAvg = loadavg.text().split(" ").slice(0, 3).join("  ");
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            root.parseMeminfo(meminfo.text());
        }
    }
}
