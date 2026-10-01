import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

Column {
    id: root

    required property var host   // the Bar, which opens and closes the popup
    readonly property bool hasRows: true
    spacing: 4
    // The rows below the switches are inset like the switches' text, on
    // the sides and at the bottom.
    bottomPadding: Network.rows.length ? Theme.popupTextInsetV : 0

    Component.onCompleted: Network.refreshWgAuto()
    Connections {
        target: root.host
        function onPopupOpenChanged() {
            if (root.host.popupOpen)
                Network.refreshWgAuto();
        }
    }

    // WireGuard switches, side by side: the tunnel by hand, and wg-auto.
    // They share the popup width evenly.
    Item {
        id: wgSwitches
        readonly property real cell: Math.max(tunnelAction.implicitWidth, wgAutoAction.implicitWidth, (trafficGrid.implicitWidth + 24 - wgActions.spacing) / 2)
        implicitWidth: 2 * cell + wgActions.spacing
        implicitHeight: wgActions.implicitHeight

        Row {
            id: wgActions
            spacing: 2

            PopupAction {
                id: tunnelAction
                width: wgSwitches.cell
                icon: Theme.glyph(Network.vpn ? 0xf0565 : 0xf099e)
                iconColor: Network.vpn ? Theme.teal : Theme.subtext0
                text: "WireGuard " + (Network.vpn ? "on" : "off")
                onTriggered: Network.toggleTunnel()
            }
            PopupAction {
                id: wgAutoAction
                width: wgSwitches.cell
                icon: Theme.glyph(0xf006a)
                iconColor: Network.wgAuto ? Theme.teal : Theme.subtext0
                text: "Auto " + (Network.wgAuto ? "on" : "off")
                onTriggered: Network.toggleWgAuto()
            }
        }
    }
    GridLayout {
        id: trafficGrid
        visible: Network.rows.length > 0
        x: 12
        columns: 3
        columnSpacing: 16
        rowSpacing: 4

        Repeater {
            model: Network.rows

            delegate: Repeater {
                required property var modelData
                model: [modelData.label, modelData.down, modelData.up]

                PopupText {
                    required property var modelData
                    required property int index
                    text: modelData
                    // The label left, the two rates right-aligned in their columns.
                    Layout.alignment: index === 0 ? Qt.AlignLeft : Qt.AlignRight
                }
            }
        }
    }
    PopupText {
        visible: Network.wired && Network.slowUsb
        x: 12
        text: Network.usbName
        color: Theme.maroon
    }
}
