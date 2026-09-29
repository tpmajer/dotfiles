pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// The network module: cable and/or Wi-Fi. Connection, SSID, signal and link
// speed come from NetworkManager through Quickshell.Networking (events, nothing
// polled); traffic and the VPN (wg0 exists only while it is up) from
// /proc/net/dev every 2 s. Only the Wi-Fi frequency still needs nmcli, run on a
// network change and every 30 s (roaming between bands keeps the SSID). The
// Wi-Fi scanner is never enabled: this reads what NetworkManager already knows,
// without triggering rescans.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property bool wired: wiredDevice !== null

    readonly property string ssid: wifiNetwork ? wifiNetwork.name : ""
    readonly property int signal: wifiNetwork ? Math.round(wifiNetwork.signalStrength * 100) : 0
    property bool vpn: false
    property string frequency: ""
    property var rates: ({})      // interface -> {down, up}

    // USB speed of the cable adapter in Mb/s (5000 = USB 3, 480 = USB 2.0), 0 if
    // it is not on USB. The RTL8156 sometimes comes up on USB 2.0 and then tops
    // out around 350 Mb/s although the link still reads 2500 Mb/s.
    property int usbSpeed: 0
    readonly property bool slowUsb: usbSpeed > 0 && usbSpeed < 5000
    readonly property string usbName: usbSpeed >= 5000 ? "USB 3" : usbSpeed >= 480 ? "USB 2.0" : usbSpeed >= 12 ? "USB 1.1" : "USB 1.0"

    onWiredDeviceChanged: {
        usbSpeed = 0;
        if (wiredDevice) {
            usbQuery.command = ["cat", `/sys/class/net/${wiredDevice.name}/device/../speed`];
            usbQuery.running = true;
        }
    }

    Process {
        id: usbQuery
        stdout: StdioCollector {
            onStreamFinished: root.usbSpeed = parseInt(text) || 0
        }
    }

    // The bar shows the cable icon (red on slow USB) apart from the rest:
    // cable first, then Wi-Fi if it is connected too (it usually stays up).
    readonly property string wiredText: wired ? Theme.glyph(0xf0002) : ""
    readonly property string text: {
        const parts = [];
        if (wifiNetwork) {
            const icon = signal >= 80 ? 0xf0928 : signal >= 60 ? 0xf0925 : signal >= 40 ? 0xf0922 : signal >= 20 ? 0xf091f : 0xf092f;
            parts.push(Theme.glyph(icon) + " " + ssid);
        }
        if (vpn)
            parts.push(Theme.glyph(0xf0306));
        if (!wired && !wifiNetwork)
            return Theme.glyph(0xf092e);
        return parts.join(" ");
    }

    // Popup rows: a label and the traffic, which the popup right-aligns.
    function row(label, device) {
        const r = device ? rates[device.name] : null;
        return {label, down: "⇣ " + (r ? r.down : "?"), up: "⇡ " + (r ? r.up : "?")};
    }

    readonly property var rows: {
        const list = [];
        if (wired)
            list.push(row("Ethernet" + (wiredDevice.linkSpeed > 0 ? " " + wiredDevice.linkSpeed + " Mb/s" : ""), wiredDevice));
        if (wifiNetwork)
            list.push(row(`${frequency} ${signal}%`, wifiDevice));
        return list;
    }

    function formatRate(bytesPerSecond) {
        if (bytesPerSecond >= 1048576)
            return (bytesPerSecond / 1048576).toFixed(1) + " MiB/s";
        if (bytesPerSecond >= 1024)
            return Math.round(bytesPerSecond / 1024) + " KiB/s";
        return Math.round(bytesPerSecond) + " B/s";
    }

    property var previous: ({})   // interface -> {rx, tx, time}

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

        const now = Date.now();
        const nextPrevious = {};
        const nextRates = {};
        for (const device of [wiredDevice, wifiDevice]) {
            const current = device ? counters[device.name] : null;
            if (!current)
                continue;
            const prev = previous[device.name];
            if (prev && now > prev.time && current.rx >= prev.rx && current.tx >= prev.tx) {
                const seconds = (now - prev.time) / 1000;
                nextRates[device.name] = {
                    down: formatRate((current.rx - prev.rx) / seconds),
                    up: formatRate((current.tx - prev.tx) / seconds)
                };
            }
            nextPrevious[device.name] = {rx: current.rx, tx: current.tx, time: now};
        }
        previous = nextPrevious;
        rates = nextRates;
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
