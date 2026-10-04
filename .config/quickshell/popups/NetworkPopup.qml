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
    // value to a row. Both are as wide as the wider one, so the values end
    // where the rates do.
    TextMetrics {
        id: rate
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: Network.widestRate
    }
    Column {
        id: info
        readonly property real wide: Math.max(trafficGrid.implicitWidth, details.implicitWidth)
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
    // WireGuard switches at the bottom: the tunnel by hand at the left end,
    // wg-auto at the right. Each is as wide as what it shows, so its text
    // sits under the labels, or ends where the values do.
    Item {
        id: wgSwitches
        implicitWidth: Math.max(tunnelAction.implicitWidth + 2 + wgAutoAction.implicitWidth, info.wide + 2 * Theme.popupTextInset)
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
