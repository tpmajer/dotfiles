pragma Singleton

import QtQuick
import Quickshell
import qs
import Quickshell.Io
import Quickshell.Networking

// The network module: cable and/or Wi-Fi. Connection, SSID, signal and link
// speed come from NetworkManager through Quickshell.Networking (events, nothing
// polled); traffic and the VPN (wg0 exists only while it is up) from
// /proc/net/dev every 2 s. Only the Wi-Fi frequency still needs nmcli, run on a
// network change and every 30 s (roaming between bands keeps the SSID). The
// Wi-Fi scanner is never enabled: this reads what NetworkManager already knows,
// without triggering rescans. What the popup shows of the default route (the
// address, the gateway and how long it takes to answer) is read only when
// the popup asks for it; whether it leads to an iPhone's hotspot is read at
// each change `ip monitor` reports.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property bool wired: wiredDevice !== null

    readonly property string ssid: wifiNetwork ? wifiNetwork.name : ""
    // A Wi-Fi wg-auto trusts (~/.nixos, wireguard.nix): the bar leaves its
    // name out. Without the list every name shows. Read again at each
    // network: a rebuild swaps the link in /etc, which no watch sees.
    readonly property bool trusted: ssid !== "" && trustedList.text().split("\n").includes(ssid)
    FileView {
        id: trustedList
        path: "/etc/wg-auto/trusted-ssids"
        printErrors: false
    }
    readonly property int signal: wifiNetwork ? Math.round(wifiNetwork.signalStrength * 100) : 0
    // 0 a signal that will do, 1 weak (under 40%), 2 nearly none (under 20%).
    // A level is left 5 points above where it is entered: the signal wavers.
    property int signalLevel: 0
    // The arcs of the bar's icon: 2 from 50%, 1 from 30%, left the same way.
    property int signalArcs: 2
    onSignalChanged: {
        if (!wifiNetwork)
            signalLevel = 0;
        else if (signal < 20 || (signalLevel === 2 && signal < 25))
            signalLevel = 2;
        else if (signal < 40 || (signalLevel >= 1 && signal < 45))
            signalLevel = 1;
        else
            signalLevel = 0;
        if (!wifiNetwork)
            signalArcs = 2;
        else if (signal < 30 || (signalArcs === 0 && signal < 35))
            signalArcs = 0;
        else if (signal < 50 || (signalArcs <= 1 && signal < 55))
            signalArcs = 1;
        else
            signalArcs = 2;
    }

    // Connected to a network that does not lead to the internet, by
    // NetworkManager's own check: "" while it does, or while that is not known.
    readonly property string offline: {
        if (!wired && !wifiNetwork && !hotspot)
            return "";
        switch (Networking.connectivity) {
        case NetworkConnectivity.None:
            return "No internet";
        case NetworkConnectivity.Limited:
            return "Limited connectivity";
        case NetworkConnectivity.Portal:
            return "Sign-in needed";
        default:
            return "";
        }
    }
    // For the bar: no internet, or on Wi-Fi alone with nearly no signal.
    // Airplane mode with no cable: offline on purpose, so no alarm.
    readonly property bool grounded: Rfkill.airplane && !wired
    readonly property bool alarm: !grounded && (offline !== "" || (!wired && signalLevel === 2))

    property bool vpn: false
    property string frequency: ""
    property var rates: ({})      // interface -> {down, up}

    // USB speed of the cable adapter in Mb/s (5000 = USB 3, 480 = USB 2.0), 0 if
    // it is not on USB. The RTL8156 sometimes comes up on USB 2.0 and then tops
    // out around 350 Mb/s although the link still reads 2500 Mb/s.
    property int usbSpeed: 0
    readonly property bool slowUsb: !wiredHotspot && usbSpeed > 0 && usbSpeed < 5000
    // The cable's link under 1 Gb/s, whatever the USB: a bad cable or socket.
    readonly property bool slowLink: wired && !wiredHotspot && wiredDevice.linkSpeed > 0 && wiredDevice.linkSpeed < 1000
    // Either way the cable is slow: its icon and the popup's row tell.
    readonly property bool slowWired: slowUsb || slowLink
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

    // The internet comes through an iPhone's hotspot, whichever way it is
    // joined (Wi-Fi, Bluetooth, USB): iOS always hands out this gateway, and
    // NetworkManager's Bluetooth device is not in Quickshell.Networking. Read
    // apart from the popup's route, which is wg0 under the tunnel.
    property string hotspotDevice: ""
    readonly property bool hotspot: hotspotDevice !== ""
    readonly property bool wiredHotspot: wired && wiredDevice.name === hotspotDevice
    readonly property bool wifiHotspot: wifiDevice !== null && wifiDevice.name === hotspotDevice
    property bool routeStale: false

    function readHotspot() {
        // A tunnel up or down is a link and its routes: wg0 is told then.
        readTraffic();
        if (defaultRoute.running)
            routeStale = true;
        else
            defaultRoute.running = true;
    }

    Process {
        id: defaultRoute
        command: ["ip", "-j", "route", "show", "default"]
        stdout: StdioCollector {
            onStreamFinished: {
                let routes = [];
                try {
                    routes = JSON.parse(text);
                } catch (e) {}
                routes.sort((a, b) => (a.metric ?? 0) - (b.metric ?? 0));
                root.hotspotDevice = routes[0]?.gateway === "172.20.10.1" ? routes[0].dev : "";
            }
        }
        onRunningChanged: {
            if (!running && root.routeStale) {
                root.routeStale = false;
                running = true;
            }
        }
    }

    // A link going down takes its routes with no word of them: links and
    // addresses too.
    Watcher {
        restartDelay: 2000
        command: ["ip", "monitor", "link", "address", "route"]
        stdout: SplitParser {
            onRead: routeChanged.restart()
        }
        onStarted: root.readHotspot()
    }

    // Routes change in bursts.
    Timer {
        id: routeChanged
        interval: 200
        onTriggered: root.readHotspot()
    }

    // The bar shows the cable icon (red on a slow cable) apart from the rest:
    // cable first, then Wi-Fi if it is connected too (it usually stays up).
    readonly property string wiredText: wired && !wiredHotspot ? Theme.glyph(0xef44) : ""
    readonly property string text: {
        const parts = [];
        if (hotspot && !wifiHotspot)
            parts.push(Theme.glyph(0xf0c1));
        if (wifiNetwork) {
            const icon = wifiHotspot ? 0xf0c1 : [0x100000, 0x100001, 0xf1eb][signalArcs];
            parts.push(Theme.glyph(icon) + (trusted ? "" : " " + ssid));
        } else if (Rfkill.airplane) {
            parts.push(Theme.glyph(0xf072));
        }
        if (vpn)
            parts.push(Theme.glyph(0xf084));
        if (!wired && !wifiNetwork && !Rfkill.airplane && !hotspot)
            return Theme.glyph(0xf127);
        return parts.join(" ");
    }

    // Popup sections, one per connection: its name and the traffic, which
    // the popup right-aligns in columns of a set width, and below them what
    // does not change every other second (a label, a value and its color).
    // Last the default route: the connection it takes, the address on it and
    // the gateway.
    function section(label, device, details) {
        const r = rates[device.name];
        return {label, details, down: downIcon + " " + (r ? r.down : "?"), up: upIcon + " " + (r ? r.up : "?")};
    }

    readonly property var sections: {
        const list = [];
        if (wired) {
            const details = [];
            if (wiredDevice.linkSpeed > 0)
                details.push({label: "Link", value: wiredDevice.linkSpeed + " Mb/s" + (slowUsb ? "  " + usbName : ""), color: slowWired ? Theme.maroon : undefined});
            list.push(section(wiredHotspot ? "iPhone hotspot" : "Ethernet", wiredDevice, details));
        }
        // The name the bar leaves out on a trusted network.
        if (wifiNetwork)
            list.push(section("Wi-Fi", wifiDevice, [
                {label: "Network", value: ssid},
                {label: "Signal", value: (frequency !== "" ? frequency + "  " : "") + signal + "%", color: signalLevel === 2 ? Theme.red : signalLevel === 1 ? Theme.peach : undefined}
            ]));
        if (routeDevice !== "") {
            const details = [];
            if (address !== "")
                details.push({label: "Address", value: address});
            if (gateway !== "")
                details.push({label: "Gateway", value: gateway + (latency !== "" ? "  " + latency : "")});
            const through = routeDevice === hotspotDevice ? "iPhone hotspot" : wired && routeDevice === wiredDevice.name ? "Ethernet" : wifiNetwork && routeDevice === wifiDevice.name ? "Wi-Fi" : routeDevice === "wg0" ? "WireGuard" : routeDevice;
            list.push({label: "Route", value: through, details});
        }
        return list;
    }

    // In two units only, so that a rate is as wide whatever it is: under
    // half a KiB/s it reads 0.
    function formatRate(bytesPerSecond) {
        if (bytesPerSecond >= 1048576)
            return (bytesPerSecond / 1048576).toFixed(1) + " MiB/s";
        return Math.round(bytesPerSecond / 1024) + " KiB/s";
    }
    // The widest a rate gets, for the popup's columns.
    readonly property string widestRate: downIcon + " 1023 KiB/s"
    readonly property string downIcon: "↓"
    readonly property string upIcon: "↑"

    property var previous: ({})   // interface -> {rx, tx, time}

    function readTraffic() {
        // Without the wait, text() is still the previous read's.
        netDev.reload();
        netDev.waitForJob();
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
            // Not over a long gap, as when the popup comes up again.
            if (prev && now > prev.time && now - prev.time < 5000 && current.rx >= prev.rx && current.tx >= prev.tx) {
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

    // The default route, for the popup: this machine's address on it, the
    // interface, the gateway and the time of one ping to it. Asked for by the
    // popup while it is open; the ping follows the route, as it needs the
    // gateway. Through wg0 there is no gateway to ping.
    property string address: ""
    property string routeDevice: ""
    property string gateway: ""
    property string latency: ""

    function refreshRoute() {
        routeQuery.running = true;
    }

    Process {
        id: routeQuery
        command: ["ip", "-j", "route", "get", "1.1.1.1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let route = {};
                try {
                    route = JSON.parse(text)[0] ?? {};
                } catch (e) {}
                root.address = route.prefsrc ?? "";
                root.routeDevice = route.dev ?? "";
                root.gateway = route.gateway ?? "";
                if (root.gateway === "") {
                    root.latency = "";
                } else {
                    pingQuery.command = ["ping", "-c1", "-W1", root.gateway];
                    pingQuery.running = true;
                }
            }
        }
    }

    Process {
        id: pingQuery
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/time=([0-9.]+) ms/);
                root.latency = m ? (Number(m[1]) < 10 ? Number(m[1]).toFixed(1) : Math.round(Number(m[1]))) + " ms" : "no answer";
            }
        }
    }

    // wg-auto: brings wg0 up, with a kill switch, on every network that is not
    // trusted, off while /var/lib/wg-auto-disabled exists. scripts/wg-auto.sh flips
    // it; the state is read when the popup opens and after a toggle, not polled.
    // Switching the tunnel by hand turns wg-auto off, or the dispatcher would undo
    // it on the next "up" event (which also comes with DHCP renewals).
    property bool wgAuto: true

    function refreshWgAuto() {
        wgAutoQuery.running = true;
    }

    function runWgAuto(action) {
        wgAutoToggle.command = [Quickshell.shellDir + "/scripts/wg-auto.sh", action];
        wgAutoToggle.running = true;
    }

    function toggleWgAuto() {
        runWgAuto(wgAuto ? "off" : "on");
    }

    function toggleTunnel() {
        runWgAuto(vpn ? "off" : "up");
    }

    // The Wi-Fi band of the connected network's profile: "a" keeps it on
    // 5 GHz, off a weaker 6 GHz it would roam to; "" lets the card choose.
    // NetworkManager applies a band only when it connects, so a switch
    // reconnects. Read when the popup opens, at a new network and after a
    // switch.
    property string band: ""
    readonly property bool bandSwitching: bandSwitch.running
    readonly property var wifiProfile: wifiNetwork?.nmSettings[0] ?? null

    // From the network itself: called on its change, when wifiProfile may
    // still be the previous one's.
    function refreshBand() {
        const profile = wifiNetwork?.nmSettings[0];
        band = profile ? (profile.read()["802-11-wireless"]?.band ?? "") : "";
    }

    function toggleBand() {
        if (!wifiProfile || bandSwitch.running)
            return;
        band = band === "a" ? "" : "a";
        bandSwitch.command = ["sh", "-c", 'nmcli connection modify uuid "$1" 802-11-wireless.band "$2" && nmcli connection up uuid "$1"', "sh", wifiProfile.uuid, band];
        bandSwitch.running = true;
    }

    Process {
        id: bandSwitch
        onExited: root.refreshBand()
    }

    // Looks for Wi-Fi networks anew, for the list networkmanager_dmenu shows.
    // The scan takes a moment only: it counts as running for 2 s more, so
    // that the popup's row can be read.
    readonly property bool scanning: wifiScan.running || scanShown.running
    // A scan NetworkManager refused, with the Wi-Fi off or right after
    // another scan: said for as long as a scan is.
    readonly property bool scanFailed: !scanning && scanRefused.running
    function rescan() {
        scanShown.stop();
        scanRefused.stop();
        wifiScan.running = true;
    }

    Process {
        id: wifiScan
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: exitCode => {
            if (exitCode === 0)
                scanShown.restart();
            else
                scanRefused.restart();
        }
    }

    Timer {
        id: scanShown
        interval: 2000
    }

    Timer {
        id: scanRefused
        interval: 2000
    }

    Process {
        id: wgAutoQuery
        running: true
        command: ["test", "-e", "/var/lib/wg-auto-disabled"]
        onExited: exitCode => root.wgAuto = exitCode !== 0
    }

    Process {
        id: wgAutoToggle
        onExited: root.refreshWgAuto()
    }

    onSsidChanged: {
        frequencyQuery.running = true;
        trustedList.reload();
        refreshBand();
    }

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

    // Only the popup shows it: asked while it is open.
    function refreshFrequency() {
        if (ssid !== "")
            frequencyQuery.running = true;
    }
}
