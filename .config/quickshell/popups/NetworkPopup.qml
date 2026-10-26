import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

Column {
    id: root

    required property var host   // the PopupHost, which opens and closes the popup
    readonly property bool hasRows: true
    spacing: Theme.popupSectionGap
    // The text above the switches is inset like the switches' text, on the
    // sides and at the top.
    topPadding: alarm.visible || info.visible ? Theme.popupTextInsetV : 0

    Component.onCompleted: {
        Network.refreshWgAuto();
        Network.refreshBand();
    }
    Connections {
        target: root.host
        function onPopupOpenChanged() {
            if (root.host.popupOpen) {
                Network.refreshWgAuto();
                Network.refreshBand();
            }
        }
    }
    // The route and the ping to the gateway, while the popup is open.
    Timer {
        interval: 5000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: Network.refreshRoute()
    }

    // The rates show only with the pointer on the popup, as they change too
    // often to read at a glance.
    HoverHandler {
        id: hover
    }

    PopupText {
        id: alarm
        visible: text !== ""
        x: Theme.popupTextInset
        text: Network.offline
        color: Theme.red
    }

    // A section to a connection: its name and traffic in two columns of a
    // set width, so that the popup keeps its width as the rates change, and
    // below them its details; last the route, the same way. All
    // are as wide as the widest of them and the switches below, so the
    // values end where the rates do.
    TextMetrics {
        id: rate
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: Network.widestRate
    }
    Column {
        id: info
        readonly property real wide: {
            let w = switches.textWidth;
            for (let i = 0; i < sectionRepeater.count; i++)
                w = Math.max(w, sectionRepeater.itemAt(i)?.needed ?? 0);
            return w;
        }
        visible: Network.sections.length > 0
        x: Theme.popupTextInset
        spacing: Theme.popupSectionGap

        Repeater {
            id: sectionRepeater
            // By the count, so that a section stays as its rates change.
            model: Network.sections.length

            delegate: Column {
                id: section
                required property int index
                // None for a moment as the sections get fewer.
                readonly property var entry: Network.sections[index] ?? {details: []}
                readonly property real needed: Math.max(header.implicitWidth, details.implicitWidth)
                spacing: Theme.popupRowGap

                RowLayout {
                    id: header
                    width: info.wide
                    spacing: Theme.popupGridGap

                    PopupText {
                        text: section.entry.label ?? ""
                        Layout.fillWidth: true
                    }
                    // The route's connection, in place of traffic.
                    PopupText {
                        visible: section.entry.value !== undefined
                        text: section.entry.value ?? ""
                    }
                    PopupText {
                        visible: section.entry.down !== undefined
                        text: section.entry.down ?? ""
                        horizontalAlignment: Text.AlignRight
                        opacity: hover.hovered ? 1 : 0
                        Layout.preferredWidth: Math.ceil(rate.width)

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.popupDuration }
                        }
                    }
                    PopupText {
                        visible: section.entry.up !== undefined
                        text: section.entry.up ?? ""
                        horizontalAlignment: Text.AlignRight
                        opacity: hover.hovered ? 1 : 0
                        Layout.preferredWidth: Math.ceil(rate.width)

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.popupDuration }
                        }
                    }
                }
                PopupDetails {
                    id: details
                    visible: section.entry.details.length > 0
                    width: info.wide
                    // Dimmer than elsewhere; alarms keep their own color.
                    labelColor: Qt.tint(Theme.subtext0, Qt.alpha(Theme.base, 0.2))
                    valueColor: labelColor
                    rows: section.entry.details
                }
            }
        }
    }

    // At the bottom the switches: the WireGuard tunnel by hand and wg-auto,
    // then the radio: the Wi-Fi scan, its band and airplane mode. Their
    // labels sit under the names above, their values end where the values do.
    Column {
        id: switches
        readonly property real valueWidth: Math.max(tunnelAction.valueImplicitWidth, wgAutoAction.valueImplicitWidth, scanAction.valueImplicitWidth, bandAction.valueImplicitWidth, airplaneAction.valueImplicitWidth)
        readonly property real labelWidth: info.wide - tunnelAction.chromeWidth - valueWidth
        // What the widest of them needs for its text.
        readonly property real textWidth: tunnelAction.chromeWidth + Math.max(tunnelAction.labelImplicitWidth, wgAutoAction.labelImplicitWidth, scanAction.labelImplicitWidth, bandAction.labelImplicitWidth, airplaneAction.labelImplicitWidth) + valueWidth
        spacing: Theme.popupSectionGap

        Column {
            spacing: 2

            PopupAction {
                id: tunnelAction
                labelWidth: switches.labelWidth
                valueWidth: switches.valueWidth
                bright: Network.vpn
                onColor: Theme.teal
                text: "WireGuard"
                value: Network.vpn ? "on" : "off"
                onTriggered: Network.toggleTunnel()
            }
            PopupAction {
                id: wgAutoAction
                labelWidth: switches.labelWidth
                valueWidth: switches.valueWidth
                bright: Network.wgAuto
                onColor: Theme.teal
                text: "WireGuard auto"
                value: Network.wgAuto ? "on" : "off"
                onTriggered: Network.toggleWgAuto()
            }
        }
        Column {
            spacing: 2

            PopupAction {
                id: scanAction
                labelWidth: switches.labelWidth
                valueWidth: switches.valueWidth
                bright: Network.scanning
                text: "Scan Wi-Fi"
                value: Network.scanning ? "scanning" : Network.scanFailed ? "refused" : ""
                widestValue: "scanning"
                onTriggered: Network.rescan()
            }
            // While it reconnects there is no network: the row stays.
            PopupAction {
                id: bandAction
                visible: Network.wifiProfile !== null || Network.bandSwitching
                labelWidth: switches.labelWidth
                valueWidth: switches.valueWidth
                bright: Network.band === "a"
                onColor: Theme.teal
                text: "Wi-Fi band"
                value: Network.band === "a" ? "5 GHz" : "auto"
                widestValue: "5 GHz"
                onTriggered: Network.toggleBand()
            }
            PopupAction {
                id: airplaneAction
                labelWidth: switches.labelWidth
                valueWidth: switches.valueWidth
                bright: Rfkill.airplane
                onColor: Theme.sky
                text: "Airplane mode"
                value: Rfkill.airplane ? "on" : "off"
                onTriggered: Rfkill.toggle()
            }
        }
    }
}
