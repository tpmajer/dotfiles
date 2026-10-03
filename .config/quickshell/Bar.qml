import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import qs.popups
import qs.services
import qs.widgets

// The bar's window and its modules. The layer surface is taller than the bar
// so popups can grow out of it as one connected shape; only the bar and the open
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
    implicitHeight: 480
    exclusiveZone: Theme.barMargin + Theme.barHeight
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    // The keyboard only while the power menu is open from the keyboard.
    WlrLayershell.keyboardFocus: keyboardMode ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: popups.inputRegion
    BackgroundEffect.blurRegion: popups.blurRegion

    // ---- power menu from the keyboard (qs ipc call power toggleBar) ---------------

    readonly property var powerActions: Power.actions
    property bool keyboardMode: false
    property int powerIndex: 0

    function togglePowerMenu() {
        if (keyboardMode && popups.popupOpen) {
            popups.popupOpen = false;
            return;
        }
        powerIndex = 0;
        popups.showPopup(powerModule);
        keyboardMode = true;
        keyHandler.forceActiveFocus();
    }

    // For the key handler and the power popup.
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
            const count = bar.powerActions.length;
            switch (event.key) {
            case Qt.Key_Up:
            case Qt.Key_K:
                bar.powerIndex = (bar.powerIndex + count - 1) % count;
                break;
            case Qt.Key_Down:
            case Qt.Key_J:
            case Qt.Key_Tab:
                bar.powerIndex = (bar.powerIndex + 1) % count;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                bar.runAction(bar.powerActions[bar.powerIndex].command);
                break;
            case Qt.Key_Escape:
                popups.popupOpen = false;
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    PopupHost {
        id: popups
        anchors.fill: parent
        pinned: bar.keyboardMode
        onAboutToShow: module => {
            if (module !== powerModule)
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
                maxTextWidth: Math.max(0, clock.x - leftRow.x - windowModule.x - 80)
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

        // weather, next to the clock; not there until it is known
        Module {
            anchors.left: clock.right
            host: popups
            text: Weather.known ? Weather.icon + " " + Weather.temperatureText : ""
            color: Theme.sky
            popup: WeatherPopup {}
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
