import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth

// The bar, a port of ~/.config/waybar. The layer surface is taller than the bar
// so popups can grow out of it as one connected shape; only the bar and the open
// popup take input and get blurred, the rest of the surface is transparent.
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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: barRect
        Region { item: popupBody }
    }

    BackgroundEffect.blurRegion: Region {
        x: barRect.x
        y: barRect.y
        width: barRect.width
        height: barRect.height
        radius: Theme.barRadius

        Region {
            x: popupBody.x
            y: barRect.y + barRect.height
            width: popupBody.visible ? popupBody.width : 0
            height: popupBody.visible ? bar.popupVisibleHeight : 0
            bottomLeftRadius: Theme.popupRadius
            bottomRightRadius: Theme.popupRadius
        }
    }

    // ---- popup state ------------------------------------------------------

    property Item popupOwner: null
    property Item pendingOwner: null
    property bool popupOpen: false
    property real openness: popupOpen ? 1 : 0
    Behavior on openness {
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property real popupContentWidth: popupLoader.item ? popupLoader.item.implicitWidth : 0
    readonly property real popupContentHeight: popupLoader.item ? popupLoader.item.implicitHeight : 0
    readonly property real popupWidth: popupContentWidth + 2 * Theme.popupPadding
    property real popupHeight: popupContentHeight + 2 * Theme.popupPadding
    Behavior on popupHeight {
        enabled: bar.openness > 0.01
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }
    readonly property real popupVisibleHeight: popupHeight * openness

    readonly property real ownerCenter: {
        const o = popupOwner;
        if (!o)
            return 0;
        // Referenced so the binding re-evaluates when the module or its row moves.
        void (o.x + o.width + o.parent.x + o.parent.width);
        return o.mapToItem(barRect, o.centerX, 0).x;
    }

    // The popup stays open while the pointer is over its module, over the popup,
    // or over the strip of bar right above the popup (the way between the two).
    // This is state, not enter/leave events, whose order Qt doesn't guarantee.
    readonly property bool popupHovered: {
        if (popupOwner && popupOwner.hovered)
            return true;
        if (popupHover.hovered)
            return true;
        if (!barHover.hovered)
            return false;
        const x = modules.x + barHover.point.position.x;
        return x >= popupBody.x && x <= popupBody.x + popupBody.width;
    }

    onPopupHoveredChanged: {
        if (popupHovered)
            hideTimer.stop();
        else if (popupOpen)
            hideTimer.restart();
    }

    function moduleHovered(module, hovered) {
        if (hovered) {
            if (!module.popup) {
                pendingOwner = null;
                showTimer.stop();
            } else if (popupOpen) {
                showPopup(module);
            } else {
                pendingOwner = module;
                showTimer.restart();
            }
        } else if (pendingOwner === module) {
            pendingOwner = null;
            showTimer.stop();
        }
    }

    function runAction(command) {
        popupOpen = false;
        Quickshell.execDetached(["sh", "-c", command]);
    }

    function showPopup(module) {
        showTimer.stop();
        popupOwner = module;
        popupLoader.sourceComponent = module.popup;
        popupOpen = true;
    }

    Timer {
        id: showTimer
        interval: 350
        onTriggered: if (bar.pendingOwner)
            bar.showPopup(bar.pendingOwner)
    }

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: if (!bar.popupHovered)
            bar.popupOpen = false
    }

    // ---- background: bar + popup as one shape, with a shadow ----------------

    Item {
        id: shapes
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#77000000"
            shadowBlur: 1.0
            blurMax: 24
            shadowVerticalOffset: 3
        }

        Rectangle {
            id: barRect
            x: Theme.barMargin
            y: Theme.barMargin
            width: parent.width - 2 * Theme.barMargin
            height: Theme.barHeight
            radius: Theme.barRadius
            color: Theme.base
        }

        Rectangle {
            id: popupBody

            readonly property real targetX: {
                const minX = Theme.popupFillet + 4;
                const maxX = barRect.width - bar.popupWidth - Theme.popupFillet - 4;
                return barRect.x + Math.max(minX, Math.min(maxX, bar.ownerCenter - bar.popupWidth / 2));
            }

            // Starts inside the bar so the join has no seam.
            x: targetX
            y: barRect.y + barRect.height - Theme.popupFillet
            width: bar.popupWidth
            height: bar.popupVisibleHeight + Theme.popupFillet
            visible: bar.popupVisibleHeight > 0.5
            color: Theme.base
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Math.min(Theme.popupRadius, bar.popupVisibleHeight / 2)
            bottomRightRadius: Math.min(Theme.popupRadius, bar.popupVisibleHeight / 2)

            Behavior on x {
                enabled: bar.openness > 0.01
                NumberAnimation {
                    duration: Theme.popupDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                enabled: bar.openness > 0.01
                NumberAnimation {
                    duration: Theme.popupDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Concave corners joining the popup to the bar's bottom edge.
        Shape {
            id: leftFillet
            readonly property real r: Math.min(Theme.popupFillet, bar.popupVisibleHeight)
            visible: popupBody.visible
            x: popupBody.x - r
            y: barRect.y + barRect.height
            width: r
            height: r
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: leftFillet.r; y: 0 }
                PathLine { x: leftFillet.r; y: leftFillet.r }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: leftFillet.r
                    radiusY: leftFillet.r
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            id: rightFillet
            readonly property real r: leftFillet.r
            visible: popupBody.visible
            x: popupBody.x + popupBody.width
            y: barRect.y + barRect.height
            width: r
            height: r
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: rightFillet.r; y: 0 }
                PathArc {
                    x: 0
                    y: rightFillet.r
                    radiusX: rightFillet.r
                    radiusY: rightFillet.r
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    // ---- popup content --------------------------------------------------------

    Item {
        id: popupClip
        x: popupBody.x
        y: barRect.y + barRect.height
        width: popupBody.width
        height: bar.popupVisibleHeight
        clip: true
        visible: popupBody.visible

        Loader {
            id: popupLoader
            x: Theme.popupPadding
            // Slides down with the popup instead of being revealed in place.
            y: Theme.popupPadding - (bar.popupHeight - bar.popupVisibleHeight)
            opacity: bar.openness
        }

        // A HoverHandler, not a MouseArea, so clickable rows in the popup still get the mouse.
        HoverHandler {
            id: popupHover
        }
    }

    // ---- modules ----------------------------------------------------------------

    Item {
        id: modules
        x: barRect.x
        y: barRect.y
        width: barRect.width
        height: barRect.height

        HoverHandler {
            id: barHover
        }

        Row {
            id: leftRow
            height: parent.height

            // custom/logo
            Module {
                host: bar
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
                        host: bar
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
                host: bar
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
            host: bar
            text: alt ? Theme.glyph(0xf00ed) + " " + Qt.formatDate(systemClock.date, "dd.MM.yyyy") : Theme.glyph(0xf017) + " " + Qt.formatTime(systemClock.date, "HH:mm:ss")
            color: Theme.mauve
            popup: calendarPopup
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Quickshell.execDetached(["ghostty", "-e", "calcure"]);
                else
                    alt = !alt;
            }
        }

        Row {
            id: rightRow
            anchors.right: parent.right
            height: parent.height

            // custom/idle-inhibit
            Module {
                host: bar
                text: Custom.idle.text || ""
                color: Custom.idle.class === "activated" ? Theme.sky : Theme.subtext0
                popup: Custom.idle.tooltip ? idlePopup : null
                onClicked: Custom.toggleIdle()
            }

            // cpu
            Module {
                host: bar
                text: "CPU " + SysStats.cpuUsage + "%"
                color: Theme.lavender
                popup: cpuPopup
                onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])
            }

            // memory
            Module {
                host: bar
                text: "RAM " + SysStats.memPercent + "%"
                color: Theme.peach
                popup: memoryPopup
                onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])
            }

            // custom/network
            Module {
                host: bar
                text: Custom.network.text || ""
                color: Theme.teal
                popup: Custom.network.tooltip ? networkPopup : null
                onClicked: m => Quickshell.execDetached(m.button === Qt.RightButton ? ["nmcli", "device", "wifi", "rescan"] : ["networkmanager_dmenu"])
            }

            // bluetooth
            Module {
                readonly property var adapter: Bluetooth.defaultAdapter
                host: bar
                text: !adapter || adapter.state === BluetoothAdapterState.Blocked ? "" : Theme.glyph(adapter.enabled ? 0xf00af : 0xf00b2)
                color: Theme.sapphire
                popup: bluetoothPopup
                onClicked: Quickshell.execDetached(["ghostty", "-e", "bluetui"])
            }

            // wireplumber#sink
            Module {
                readonly property var sink: Audio.defaultSink
                readonly property bool ready: !!sink && !!sink.audio
                host: bar
                text: !ready ? "" : Audio.icon(sink) + (sink.audio.muted ? "" : " " + Audio.volume(sink) + "%")
                color: Theme.yellow
                popup: volumePopup
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
                host: bar
                text: Battery.icon + " " + (alt ? Battery.timeText : Battery.capacity + "%")
                color: Battery.color
                popup: batteryPopup
                onClicked: alt = !alt
            }

            // custom/power
            Module {
                host: bar
                text: Theme.glyph(0xf0906)
                color: Theme.subtext0
                rightMargin: 6
                popup: powerPopup
                onClicked: bar.showPopup(this)
            }
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    // ---- popup contents -----------------------------------------------------------

    Component {
        id: calendarPopup

        Column {
            id: cal
            readonly property var locale: Qt.locale("en_US")
            readonly property date now: systemClock.date
            readonly property int year: now.getFullYear()
            readonly property int month: now.getMonth()
            // Weeks start on Monday: getDay() is 0 for Sunday, so shift it to the end.
            readonly property int firstDay: (new Date(year, month, 1).getDay() + 6) % 7
            readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
            spacing: 6

            TextMetrics {
                id: cell
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
                text: "00"
            }

            PopupText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: cal.locale.standaloneMonthName(cal.month) + " " + cal.year
            }

            Grid {
                columns: 7
                columnSpacing: 10
                rowSpacing: 4

                Repeater {
                    model: 7
                    PopupText {
                        required property int index
                        width: cell.width
                        horizontalAlignment: Text.AlignRight
                        text: cal.locale.dayName((index + 1) % 7, Locale.ShortFormat).slice(0, 2)
                        color: Theme.pink
                        font.bold: true
                    }
                }

                Repeater {
                    model: Math.ceil((cal.firstDay + cal.daysInMonth) / 7) * 7
                    PopupText {
                        required property int index
                        readonly property int day: index - cal.firstDay + 1
                        readonly property bool today: day === cal.now.getDate()
                        width: cell.width
                        horizontalAlignment: Text.AlignRight
                        text: day >= 1 && day <= cal.daysInMonth ? day : ""
                        color: today ? Theme.pink : Theme.white
                        font.bold: today
                        font.underline: today
                    }
                }
            }
        }
    }

    Component {
        id: idlePopup
        PopupText { text: Custom.idle.tooltip || "" }
    }

    Component {
        id: cpuPopup

        Column {
            spacing: 8

            PopupText { text: "Load: " + SysStats.loadAvg }

            Grid {
                columns: 4
                columnSpacing: 20
                rowSpacing: 4

                Repeater {
                    model: SysStats.coreUsages.length

                    Row {
                        required property int index
                        readonly property int usage: SysStats.coreUsages[index] || 0
                        spacing: 8

                        PopupText {
                            width: 28
                            horizontalAlignment: Text.AlignRight
                            text: parent.index
                            color: Theme.subtext0
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60
                            height: 6
                            radius: 3
                            color: Theme.surface0

                            Rectangle {
                                width: parent.width * parent.parent.usage / 100
                                height: parent.height
                                radius: parent.radius
                                color: Theme.lavender
                                Behavior on width {
                                    NumberAnimation { duration: 300 }
                                }
                            }
                        }

                        PopupText {
                            width: 44
                            horizontalAlignment: Text.AlignRight
                            text: parent.usage + "%"
                        }
                    }
                }
            }
        }
    }

    Component {
        id: memoryPopup

        Column {
            spacing: 4
            PopupText { text: `RAM:  ${SysStats.memUsedGiB.toFixed(1)} / ${SysStats.memTotalGiB.toFixed(1)} GiB` }
            PopupText {
                visible: SysStats.swapTotalGiB > 0
                text: `Swap: ${SysStats.swapUsedGiB.toFixed(1)} / ${SysStats.swapTotalGiB.toFixed(1)} GiB`
            }
        }
    }

    Component {
        id: networkPopup
        PopupText { text: Custom.network.tooltip || "" }
    }

    Component {
        id: bluetoothPopup

        Column {
            id: btList
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
            spacing: 4

            PopupText {
                visible: parent.connected.length === 0
                text: !parent.adapter ? "No bluetooth controller found" : parent.adapter.enabled ? "Bluetooth on" : "Bluetooth off"
            }

            // Icon by the BlueZ device type; headphones match the volume module.
            function deviceIcon(type) {
                const icons = {
                    "audio-headphones": 0xf025,
                    "audio-headset": 0xf02ce,
                    "audio-card": 0xf04c3,
                    "input-mouse": 0xf037d,
                    "input-keyboard": 0xf030c,
                    "input-gaming": 0xf0297,
                    "phone": 0xf011c,
                    "computer": 0xf0322
                };
                return Theme.glyph(icons[type] || 0xf00af);
            }

            Grid {
                visible: btList.connected.length > 0
                columns: 3
                columnSpacing: 12
                rowSpacing: 4

                Repeater {
                    model: btList.connected

                    delegate: Repeater {
                        required property var modelData
                        model: [
                            {text: btList.deviceIcon(Audio.deviceType(modelData)), color: Theme.sapphire, align: Text.AlignHCenter},
                            {text: modelData.name, color: Theme.text, align: Text.AlignLeft},
                            {text: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : "", color: Theme.subtext0, align: Text.AlignRight}
                        ]

                        PopupText {
                            required property var modelData
                            text: modelData.text
                            color: modelData.color
                            horizontalAlignment: modelData.align
                        }
                    }
                }
            }
        }
    }

    // Every audio output with its volume or mute, the default one (the one the
    // module controls) first, in brighter text with a yellow icon. Clicking a row
    // mutes or unmutes that output, scrolling over it changes its volume.
    Component {
        id: volumePopup

        Column {
            id: sinkList
            // Columns line up across rows: each keeps the widest text seen so far.
            property real nameWidth: 0
            property real valueWidth: 0
            spacing: 2

            Repeater {
                model: Audio.sinks

                Rectangle {
                    id: sinkRow
                    required property var modelData
                    readonly property bool isDefault: modelData === Audio.defaultSink
                    readonly property color textColor: isDefault ? Theme.text : Theme.subtext0

                    implicitWidth: cells.implicitWidth + 24
                    implicitHeight: cells.implicitHeight + 8
                    radius: Theme.moduleRadius
                    color: rowMouse.containsMouse ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverDuration }
                    }

                    Row {
                        id: cells
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        PopupText {
                            width: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: Audio.icon(sinkRow.modelData)
                            color: sinkRow.isDefault ? Theme.yellow : Theme.subtext0
                        }
                        PopupText {
                            width: sinkList.nameWidth
                            text: Audio.name(sinkRow.modelData)
                            color: sinkRow.textColor
                            onImplicitWidthChanged: sinkList.nameWidth = Math.max(sinkList.nameWidth, implicitWidth)
                            Component.onCompleted: sinkList.nameWidth = Math.max(sinkList.nameWidth, implicitWidth)
                        }
                        PopupText {
                            width: sinkList.valueWidth
                            horizontalAlignment: Text.AlignRight
                            text: sinkRow.modelData.audio && sinkRow.modelData.audio.muted ? "muted" : Audio.volume(sinkRow.modelData) + "%"
                            color: sinkRow.textColor
                            onImplicitWidthChanged: sinkList.valueWidth = Math.max(sinkList.valueWidth, implicitWidth)
                            Component.onCompleted: sinkList.valueWidth = Math.max(sinkList.valueWidth, implicitWidth)
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMute(sinkRow.modelData)
                        onWheel: w => Audio.changeVolume(sinkRow.modelData, w.angleDelta.y > 0 ? 1 : w.angleDelta.y < 0 ? -1 : 0)
                    }
                }
            }
        }
    }

    Component {
        id: batteryPopup

        Column {
            spacing: 4
            PopupText { text: "Battery: " + Battery.capacity + "%" }
            PopupText {
                visible: Battery.timeText !== ""
                text: (Battery.charging ? "Full in " : "Empty in ") + Battery.timeText
                color: Theme.subtext0
            }
        }
    }

    // Replaces wlogout (~/.config/wlogout/layout), without hibernate.
    Component {
        id: powerPopup

        Column {
            id: actionList
            // Rows share the width of the widest one.
            property real rowWidth: 0
            spacing: 2

            Repeater {
                model: [
                    {icon: 0xf033e, text: "Lock", command: "loginctl lock-session"},
                    {icon: 0xf0343, text: "Logout", command: "niri msg action quit -s"},
                    {icon: 0xf0425, text: "Shutdown", command: "systemctl poweroff", color: Theme.red},
                    {icon: 0xf0904, text: "Suspend", command: "systemctl suspend"},
                    {icon: 0xf0709, text: "Reboot", command: "systemctl reboot", color: Theme.peach}
                ]

                PopupAction {
                    required property var modelData
                    width: actionList.rowWidth
                    Component.onCompleted: actionList.rowWidth = Math.max(actionList.rowWidth, implicitWidth)
                    icon: Theme.glyph(modelData.icon)
                    iconColor: modelData.color || Theme.text
                    text: modelData.text
                    onTriggered: bar.runAction(modelData.command)
                }
            }
        }
    }
}
