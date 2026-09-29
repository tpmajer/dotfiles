pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// The network module. Connection, SSID and signal come from NetworkManager
// through Quickshell.Networking (events, nothing polled); traffic and the VPN
// (wg0 exists only while it is up) from /proc/net/dev every 2 s. Only the Wi-Fi
// frequency still needs nmcli, run on a network change and every 30 s (roaming
// between bands keeps the SSID). The Wi-Fi scanner is never enabled: this reads
// what NetworkManager already knows, without triggering rescans.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wired: devices.some(d => d.type === DeviceType.Wired && d.connected)

    readonly property string ssid: wifiNetwork ? wifiNetwork.name : ""
    readonly property int signal: wifiNetwork ? Math.round(wifiNetwork.signalStrength * 100) : 0
    property bool vpn: false
    property string frequency: ""
    property string down: "?"
    property string up: "?"

    readonly property string vpnSuffix: vpn ? " " + Theme.glyph(0xf0306) : ""
    readonly property string text: {
        if (wifiNetwork) {
            const icon = signal >= 80 ? 0xf0928 : signal >= 60 ? 0xf0925 : signal >= 40 ? 0xf0922 : signal >= 20 ? 0xf091f : 0xf092f;
            return Theme.glyph(icon) + " " + ssid + vpnSuffix;
        }
        if (wired)
            return Theme.glyph(0xf0002) + vpnSuffix;
        return Theme.glyph(0xf092e);
    }
    readonly property string tooltip: wifiNetwork ? `${frequency} ${signal}%  ⇣ ${down} ⇡ ${up}` : ""

    function formatRate(bytesPerSecond) {
        if (bytesPerSecond >= 1048576)
            return (bytesPerSecond / 1048576).toFixed(1) + " MiB/s";
        if (bytesPerSecond >= 1024)
            return Math.round(bytesPerSecond / 1024) + " KiB/s";
        return Math.round(bytesPerSecond) + " B/s";
    }

    property var previous: null   // {device, rx, tx, time}

    function readTraffic() {
        netDev.reload();
        const counters = {};
        for (const line of netDev.text().split("\n").slice(2)) {
            const [name, data] = line.split(":");
            if (!data)
                continue;
            const fields = data.trim().split(/\s+/).map(Number);
            counters[name.trim()] = {rx: fields[0], tx: fields[8]};
        }
        vpn = "wg0" in counters;

        const device = wifiDevice ? wifiDevice.name : "";
        const now = Date.now();
        const current = counters[device];
        if (current && previous && previous.device === device && now > previous.time && current.rx >= previous.rx && current.tx >= previous.tx) {
            const seconds = (now - previous.time) / 1000;
            down = formatRate((current.rx - previous.rx) / seconds);
            up = formatRate((current.tx - previous.tx) / seconds);
        } else {
            down = "?";
            up = "?";
        }
        previous = current ? {device, rx: current.rx, tx: current.tx, time: now} : null;
    }

    FileView {
        id: netDev
        path: "/proc/net/dev"
        blockLoading: true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.readTraffic()
    }

    onSsidChanged: frequencyQuery.running = true

    Process {
        id: frequencyQuery
        command: ["nmcli", "-t", "-f", "IN-USE,FREQ", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l.startsWith("*:"));
                const mhz = line ? parseInt(line.split(":")[1]) : NaN;
                root.frequency = isNaN(mhz) ? "" : (mhz / 1000).toFixed(1) + " GHz";
            }
        }
    }

    Timer {
        interval: 30000
        running: root.ssid !== ""
        repeat: true
        onTriggered: frequencyQuery.running = true
    }
}
