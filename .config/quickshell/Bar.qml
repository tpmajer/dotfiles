import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Bluetooth
import qs.popups
import qs.services
import qs.widgets

// The bar's window and its modules. The layer surface is taller than the bar
// so popups can open below it in the same window; only the bar and the open
// popup take input and get blurred, the rest of the surface is transparent.
// PopupHost draws the bar and runs the popups.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    // The tallest popup is the notification center: its list, and 96 px for
    // its header, the popup's paddings and the shadow below it.
    implicitHeight: Theme.barMargin + Theme.barHeight + Theme.popupGap + Theme.centerMaxHeight + 96
    exclusiveZone: Theme.barMargin + Theme.barHeight
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    // The keyboard only while a popup is open from the keyboard.
    WlrLayershell.keyboardFocus: keyboardMode ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: popups.inputRegion
    BackgroundEffect.blurRegion: popups.blurRegion

    // The power module was clicked: the menu itself lives in the shell.
    signal powerMenuRequested

    // ---- a popup driven from the keyboard (qs ipc call notifications toggle) ----

    // The open popup is pinned and gets the keys, through its keyPressed().
    property bool keyboardMode: false

    function toggleKeyboardPopup(module) {
        if (keyboardMode && popups.popupOpen && popups.popupOwner === module) {
            popups.popupOpen = false;
            return;
        }
        popups.showPopup(module);
        keyboardMode = true;
        keyHandler.forceActiveFocus();
    }

    function toggleNotifications() {
        toggleKeyboardPopup(bellModule);
    }

    Item {
        id: keyHandler
        focus: true
        Keys.onPressed: event => {
            if (!bar.keyboardMode)
                return;
            if (event.key === Qt.Key_Escape) {
                popups.popupOpen = false;
                event.accepted = true;
                return;
            }
            const popup = popups.popupItem;
            if (popup && popup.keyPressed)
                popup.keyPressed(event);
        }
    }

    PopupHost {
        id: popups
        anchors.fill: parent
        pinned: bar.keyboardMode
        // Another module's popup is not driven from the keyboard. The owner
        // is still the previous one here.
        onAboutToShow: module => {
            if (module !== popups.popupOwner)
                bar.keyboardMode = false;
        }
        onPopupOpenChanged: if (!popupOpen)
            bar.keyboardMode = false

        Row {
            id: leftRow
            height: parent.height

            // custom/logo
            Module {
                host: popups
                text: Theme.glyph(0xf313)
                color: Theme.blue
                fontSize: 22
                leftMargin: 5
                hPadding: 9
                onClicked: Quickshell.execDetached(["fuzzel"])
            }

            // niri/workspaces
            Row {
                id: workspaceRow
                readonly property var workspaces: Niri.workspacesOn(bar.screen.name)
                leftPadding: 3
                height: parent.height

                Repeater {
                    model: workspaceRow.workspaces.length

                    Module {
                        required property int index
                        readonly property var ws: workspaceRow.workspaces[index]
                        host: popups
                        text: !ws ? "" : ws.is_active ? Theme.glyph(0xf14fb) : String(ws.name || ws.idx)
                        bold: !!ws && ws.is_active
                        color: !ws ? Theme.subtext0 : ws.is_urgent ? Theme.red : (ws.is_active || hovered) ? Theme.text : Theme.subtext0
                        hPadding: 0
                        minWidth: 46
                        underline: false
                        onClicked: Niri.focusWorkspace(ws)
                    }
                }
            }

            // niri/window
            Module {
                id: windowModule
                property bool alt: false
                readonly property var win: Niri.focusedWindow
                // Desktop entries load asynchronously; the length makes this re-evaluate once they do.
                readonly property var entry: win && DesktopEntries.applications.values.length >= 0 ? DesktopEntries.heuristicLookup(win.app_id) : null
                host: popups
                text: !win ? "" : alt ? (win.app_id || "") : (win.title || "")
                iconSource: entry ? Quickshell.iconPath(entry.icon, true) : ""
                maxTextWidth: Math.max(0, weatherModule.x - leftRow.x - windowModule.x - 80)
                popup: WindowPopup {}
                onClicked: alt = !alt
            }
        }

        // clock
        Module {
            id: clock
            property bool alt: false
            anchors.horizontalCenter: parent.horizontalCenter
            host: popups
            text: alt ? Theme.glyph(0xf00ed) + " " + Qt.formatDate(systemClock.date, "dd.MM.yyyy") : Theme.glyph(0xf017) + " " + Qt.formatTime(systemClock.date, "HH:mm:ss")
            color: Theme.mauve
            popup: CalendarPopup {
                now: systemClock.date
            }
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Quickshell.execDetached(["ghostty", "-e", "calcure"]);
                else
                    alt = !alt;
            }
        }

        // weather, left of the clock; not there until it is known
        Module {
            id: weatherModule
            anchors.right: clock.left
            host: popups
            text: Weather.known ? Weather.icon + " " + Weather.temperatureText : ""
            color: Theme.sky
            popup: WeatherPopup {}
            onClicked: m => {
                if (m.button === Qt.LeftButton)
                    openPopup();
            }
        }

        // notifications, right of the clock: how many wait in the center,
        // which is its popup; a click opens it, a right click switches do
        // not disturb
        Module {
            id: bellModule
            anchors.left: clock.right
            host: popups
            prefix: Theme.glyph(Notifications.quiet ? 0xf009b : 0xf009a)
            // Both bells in the wider one's width: the module keeps its
            // width, and its popup its place, as do not disturb is switched.
            prefixWidth: Math.ceil(Math.max(bellMetrics.advanceWidth(Theme.glyph(0xf009a)), bellMetrics.advanceWidth(Theme.glyph(0xf009b))))
            text: Notifications.missedCount > 0 ? String(Notifications.missedCount) : ""
            // Gray only under do not disturb. Else in the color of the
            // most urgent notification in the center, as the line on its
            // card; with none there, or only low ones, whose line is gray,
            // the bell is white, brighter than plain text.
            color: Notifications.quiet ? Theme.subtext0 : Notifications.missedUrgency === NotificationUrgency.Low ? Theme.white : Notifications.urgencyColor(Notifications.missedUrgency)
            popup: NotificationsPopup {
                panel: bar
            }
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Notifications.toggleDnd();
                else if (m.button === Qt.LeftButton)
                    openPopup();
            }

            FontMetrics {
                id: bellMetrics
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }

        // what plays, right of the bell: a wave in the player's color,
        // gone a while after the last one was paused. Its popup tells
        // what it is and has the buttons. A middle click pauses, a
        // right one goes to the player's window, the wheel skips a
        // track.
        Module {
            id: mediaModule
            anchors.left: bellModule.right
            host: popups
            hPadding: 8
            color: Media.color
            content: Media.active ? mediaWave : null
            popup: MediaPopup {}
            onClicked: m => {
                if (m.button === Qt.MiddleButton)
                    Media.playPause();
                else if (m.button === Qt.RightButton)
                    Media.focusWindow();
                else if (m.button === Qt.LeftButton)
                    openPopup();
            }
            // Down for the next one, as down a list.
            onScrolled: steps => Media.scroll(-steps)

            // The popup goes with the module, not left open and empty
            // under the pointer.
            Connections {
                target: Media
                function onActiveChanged() {
                    if (!Media.active && popups.popupOwner === mediaModule)
                        popups.popupOpen = false;
                }
            }

            Component {
                id: mediaWave

                Wave {
                    levels: Spectrum.levels
                    color: Media.color
                    // Not behind the lock, where the pattern would
                    // run on unseen.
                    simulated: Media.remote && !Spectrum.locked
                    playing: Media.playing
                }
            }
        }

        Row {
            id: rightRow
            anchors.right: parent.right
            height: parent.height

            // custom/idle-inhibit
            Module {
                host: popups
                // Idle: the time left until the lock, in a color that tells.
                text: (Custom.idle.text || "") + (Custom.systemIdle ? " " + Custom.lockCountdown(systemClock.date) : "")
                color: Custom.idle.class === "activated" ? Theme.sky : Custom.systemIdle ? Theme.peach : Theme.subtext0
                popup: Custom.idle.tooltip ? idlePopup : null
                onClicked: Custom.toggleIdle()
            }

            // cpu
            Module {
                host: popups
                text: "CPU " + SysStats.cpuUsage + "%"
                // Red while the CPU is hot; warm shows only in the popup,
                // with the temperature.
                color: SysStats.cpuTempLevel === 2 ? Theme.red : Theme.lavender
                popup: CpuPopup {}
                onClicked: m => {
                    if (m.button === Qt.RightButton)
                        Quickshell.execDetached(["ghostty", "-e", "btop"]);
                    else if (m.button === Qt.LeftButton)
                        openPopup();
                }
            }

            // memory
            Module {
                host: popups
                text: "RAM " + SysStats.memPercent + "%"
                // Red with nearly all of it taken.
                color: SysStats.memLevel === 2 ? Theme.red : Theme.peach
                popup: MemoryPopup {}
                onClicked: m => {
                    if (m.button === Qt.RightButton)
                        Quickshell.execDetached(["ghostty", "-e", "btop"]);
                    else if (m.button === Qt.LeftButton)
                        openPopup();
                }
            }

            // custom/network
            Module {
                host: popups
                prefix: Network.wiredText
                prefixColor: Network.slowUsb ? Theme.maroon : Theme.teal
                text: Network.text
                // Red with no internet, or on Wi-Fi alone with nearly no signal.
                color: Network.alarm ? Theme.red : Theme.teal
                popup: NetworkPopup {
                    host: popups
                }
                onClicked: m => {
                    if (m.button === Qt.RightButton)
                        Quickshell.execDetached(["networkmanager_dmenu"]);
                    else if (m.button === Qt.LeftButton)
                        openPopup();
                }
            }

            // bluetooth
            Module {
                readonly property var adapter: Bluetooth.defaultAdapter
                host: popups
                text: !adapter || adapter.state === BluetoothAdapterState.Blocked ? "" : Theme.glyph(adapter.enabled ? 0xf00af : 0xf00b2)
                // Gray while bluetooth is off, as its row in the popup.
                color: adapter && adapter.enabled ? Theme.sapphire : Theme.subtext0
                popup: BluetoothPopup {}
                onClicked: m => {
                    if (m.button === Qt.RightButton)
                        Quickshell.execDetached(["ghostty", "-e", "bluetui"]);
                    else if (m.button === Qt.LeftButton)
                        openPopup();
                }
            }

            // wireplumber#sink
            Module {
                readonly property var sink: Audio.defaultSink
                readonly property bool ready: !!sink && !!sink.audio
                host: popups
                text: !ready ? "" : Audio.icon(sink) + (sink.audio.muted ? "" : " " + Audio.volume(sink) + "%")
                color: Theme.yellow
                popup: VolumePopup {}
                onClicked: m => {
                    if (m.button === Qt.RightButton)
                        Quickshell.execDetached(["ghostty", "-e", "wiremix"]);
                    else
                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                }
                onScrolled: steps => Audio.changeVolume(sink, steps)
            }

            // battery
            Module {
                property bool alt: false
                host: popups
                text: Battery.icon + " " + (alt && Battery.timeText !== "" ? Battery.timeText : Battery.capacity + "%")
                color: Battery.color
                popup: BatteryPopup {}
                onClicked: alt = !alt
            }

            // custom/power
            Module {
                host: popups
                text: Theme.glyph(0xf0906)
                color: Theme.subtext0
                rightMargin: 6
                onClicked: bar.powerMenuRequested()
            }
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    // ---- popup contents live in popups/; this one is assigned conditionally --------

    Component {
        id: idlePopup
        IdlePopup {}
    }
}
