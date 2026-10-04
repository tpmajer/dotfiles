import QtQuick
import Quickshell
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
    // The keyboard only while the power menu is open from the keyboard.
    WlrLayershell.keyboardFocus: keyboardMode ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: popups.inputRegion
    BackgroundEffect.blurRegion: popups.blurRegion

    // ---- a popup driven from the keyboard (qs ipc call power toggleBar,
    // ---- qs ipc call notifications toggle) ---------------------------------------

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

    function togglePowerMenu() {
        toggleKeyboardPopup(powerModule);
    }

    function toggleNotifications() {
        toggleKeyboardPopup(bellModule);
    }

    // For the power popup.
    function runAction(command) {
        popups.popupOpen = false;
        Power.run(command);
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
        }

        // notifications, right of the clock: how many wait in the center,
        // which is its popup; a click switches do not disturb, a right click
        // clears
        Module {
            id: bellModule
            anchors.left: clock.right
            host: popups
            text: Theme.glyph(Notifications.dnd ? 0xf009b : 0xf009a) + (Notifications.missedCount > 0 ? " " + Notifications.missedCount : "")
            color: !Notifications.dnd && Notifications.missedCount > 0 ? Theme.pink : Theme.subtext0
            popup: NotificationsPopup {
                host: bar
            }
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Notifications.clear();
                else if (m.button === Qt.LeftButton)
                    Notifications.toggleDnd();
            }
        }

        Row {
            id: rightRow
            anchors.right: parent.right
            height: parent.height

            // custom/idle-inhibit
            Module {
                host: popups
                text: Custom.idle.text || ""
                color: Custom.idle.class === "activated" ? Theme.sky : Theme.subtext0
                popup: Custom.idle.tooltip ? idlePopup : null
                onClicked: Custom.toggleIdle()
            }

            // cpu
            Module {
                host: popups
                text: "CPU " + SysStats.cpuUsage + "%"
                color: Theme.lavender
                popup: CpuPopup {}
                onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])
            }

            // memory
            Module {
                host: popups
                text: "RAM " + SysStats.memPercent + "%"
                color: Theme.peach
                popup: MemoryPopup {}
                onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])
            }

            // custom/network
            Module {
                host: popups
                prefix: Network.wiredText
                prefixColor: Network.slowUsb ? Theme.maroon : Theme.teal
                text: Network.text
                color: Theme.teal
                popup: NetworkPopup {
                    host: popups
                }
                onClicked: m => Quickshell.execDetached(m.button === Qt.RightButton ? ["nmcli", "device", "wifi", "rescan"] : ["networkmanager_dmenu"])
            }

            // bluetooth
            Module {
                readonly property var adapter: Bluetooth.defaultAdapter
                host: popups
                text: !adapter || adapter.state === BluetoothAdapterState.Blocked ? "" : Theme.glyph(adapter.enabled ? 0xf00af : 0xf00b2)
                color: Theme.sapphire
                popup: BluetoothPopup {}
                onClicked: Quickshell.execDetached(["ghostty", "-e", "bluetui"])
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
                text: Battery.icon + " " + (alt ? Battery.timeText : Battery.capacity + "%")
                color: Battery.color
                popup: BatteryPopup {}
                onClicked: alt = !alt
            }

            // custom/power
            Module {
                id: powerModule
                host: popups
                text: Theme.glyph(0xf0906)
                color: Theme.subtext0
                rightMargin: 6
                popup: PowerPopup {
                    host: bar
                }
                onClicked: popups.showPopup(this)
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
