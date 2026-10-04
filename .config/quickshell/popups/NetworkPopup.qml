import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

Column {
    id: root

    required property var host   // the PopupHost, which opens and closes the popup
    readonly property bool hasRows: true
    spacing: 4
    // The rows above the switches are inset like the switches' text, on
    // the sides and at the top.
    topPadding: trafficGrid.visible ? Theme.popupTextInsetV : 0

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

    // One grid: a connection's traffic in two columns of a set width, so
    // that the popup keeps its width as the rates change, and below them a
    // label and a value to a row, the value across both columns.
    TextMetrics {
        id: rate
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: Network.widestRate
    }
    GridLayout {
        id: trafficGrid
        visible: Network.rows.length + Network.details.length > 0
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
                    horizontalAlignment: index === 0 ? Text.AlignLeft : Text.AlignRight
                    Layout.preferredWidth: index === 0 ? implicitWidth : Math.ceil(rate.width)
                }
            }
        }

        Repeater {
            model: Network.details

            delegate: Repeater {
                id: detail
                required property var modelData
                model: 2

                PopupText {
                    required property int index
                    text: index === 0 ? detail.modelData.label : detail.modelData.value
                    color: index === 0 ? Theme.subtext0 : detail.modelData.color
                    Layout.columnSpan: index === 0 ? 1 : 2
                    Layout.alignment: index === 0 ? Qt.AlignLeft : Qt.AlignRight
                }
            }
        }
    }
    PopupText {
        visible: text !== ""
        x: 12
        text: Network.offline
        color: Theme.red
    }
    // WireGuard switches at the bottom: the tunnel by hand at the left end,
    // wg-auto at the right. Each is as wide as what it shows, so its text
    // sits under the labels, or ends where the values do.
    Item {
        id: wgSwitches
        implicitWidth: Math.max(tunnelAction.implicitWidth + 2 + wgAutoAction.implicitWidth, trafficGrid.implicitWidth + 24)
        implicitHeight: tunnelAction.implicitHeight

        PopupAction {
            id: tunnelAction
            icon: Theme.glyph(Network.vpn ? 0xf0565 : 0xf099e)
            iconColor: Network.vpn ? Theme.teal : Theme.subtext0
            bright: Network.vpn
            text: "WireGuard " + (Network.vpn ? "on" : "off")
            onTriggered: Network.toggleTunnel()
        }
        PopupAction {
            id: wgAutoAction
            anchors.right: parent.right
            icon: Theme.glyph(0xf006a)
            iconColor: Network.wgAuto ? Theme.teal : Theme.subtext0
            bright: Network.wgAuto
            text: "Auto " + (Network.wgAuto ? "on" : "off")
            onTriggered: Network.toggleWgAuto()
        }
    }
}
