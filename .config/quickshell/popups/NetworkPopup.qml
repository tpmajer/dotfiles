import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

Column {
    id: root

    required property var host   // the PopupHost, which opens and closes the popup
    readonly property bool hasRows: true
    spacing: Theme.popupRowGap
    // The rows above the switches are inset like the switches' text, on
    // the sides and at the top.
    topPadding: info.visible ? Theme.popupTextInsetV : 0

    Component.onCompleted: Network.refreshWgAuto()
    Connections {
        target: root.host
        function onPopupOpenChanged() {
            if (root.host.popupOpen)
                Network.refreshWgAuto();
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

    // A connection's traffic in two columns of a set width, so that the
    // popup keeps its width as the rates change, and below it a label and a
    // value to a row. Both are as wide as the widest of them and the switches
    // below, so the values end where the rates do.
    TextMetrics {
        id: rate
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: Network.widestRate
    }
    Column {
        id: info
        readonly property real wide: Math.max(trafficGrid.implicitWidth, details.implicitWidth, wgSwitches.textWidth)
        visible: Network.rows.length + Network.details.length > 0
        x: Theme.popupTextInset
        spacing: Theme.popupRowGap

        GridLayout {
            id: trafficGrid
            visible: Network.rows.length > 0
            width: info.wide
            columns: 3
            columnSpacing: Theme.popupGridGap
            rowSpacing: Theme.popupRowGap

            Repeater {
                model: Network.rows

                delegate: Repeater {
                    required property var modelData
                    model: [modelData.label, modelData.down, modelData.up]

                    PopupText {
                        required property var modelData
                        required property int index
                        text: modelData
                        horizontalAlignment: index === 0 ? Text.AlignLeft : Text.AlignRight
                        Layout.fillWidth: index === 0
                        Layout.preferredWidth: index === 0 ? implicitWidth : Math.ceil(rate.width)
                    }
                }
            }
        }
        PopupDetails {
            id: details
            visible: Network.details.length > 0
            width: info.wide
            rows: Network.details
        }
    }
    PopupText {
        visible: text !== ""
        x: Theme.popupTextInset
        text: Network.offline
        color: Theme.red
    }
    // At the bottom the WireGuard switches, the tunnel by hand and wg-auto,
    // and the Wi-Fi scan. Their labels sit under the labels above, their
    // values end where the values do.
    Column {
        id: wgSwitches
        readonly property real valueWidth: Math.max(tunnelAction.valueImplicitWidth, wgAutoAction.valueImplicitWidth, scanAction.valueImplicitWidth)
        readonly property real labelWidth: info.wide - tunnelAction.chromeWidth - valueWidth
        // What the wider of the two needs for its text.
        readonly property real textWidth: tunnelAction.chromeWidth + Math.max(tunnelAction.labelImplicitWidth, wgAutoAction.labelImplicitWidth, scanAction.labelImplicitWidth) + valueWidth
        spacing: 2

        PopupAction {
            id: tunnelAction
            labelWidth: wgSwitches.labelWidth
            valueWidth: wgSwitches.valueWidth
            bright: Network.vpn
            text: "WireGuard"
            value: Network.vpn ? "on" : "off"
            onTriggered: Network.toggleTunnel()
        }
        PopupAction {
            id: wgAutoAction
            labelWidth: wgSwitches.labelWidth
            valueWidth: wgSwitches.valueWidth
            bright: Network.wgAuto
            text: "WireGuard auto"
            value: Network.wgAuto ? "on" : "off"
            onTriggered: Network.toggleWgAuto()
        }
        PopupAction {
            id: scanAction
            labelWidth: wgSwitches.labelWidth
            valueWidth: wgSwitches.valueWidth
            bright: Network.scanning
            text: "Scan Wi-Fi"
            value: Network.scanning ? "scanning" : Network.scanFailed ? "refused" : ""
            widestValue: "scanning"
            onTriggered: Network.rescan()
        }
    }
}
