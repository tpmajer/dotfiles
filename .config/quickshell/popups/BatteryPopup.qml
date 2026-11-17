import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// The battery as a level with its percent, as the memory popup's, in the
// module's color. Below it the time left, the power going out or in, the
// battery's health and its cycles. At the bottom two switches: the charge
// limit, where the percent stops (clicking it charges the battery full, or
// limits it again), and quiet mode, off for full power until the next plug,
// wake or boot.
Column {
    id: popup

    readonly property bool hasRows: true
    // The level, the rows below and the switches' text are as wide as the
    // widest of the three.
    readonly property real wide: Math.max(level.implicitWidth, details.implicitWidth, switches.textWidth)
    spacing: Theme.popupRowGap
    // What is above the switches is inset like their text, on the sides
    // and at the top.
    topPadding: Theme.popupTextInsetV

    Column {
        id: info
        x: Theme.popupTextInset
        spacing: Theme.popupSectionGap

        RowLayout {
            id: level
            width: popup.wide
            spacing: Theme.popupColumnGap

            PopupText {
                text: "Battery"
            }
            LevelBar {
                Layout.fillWidth: true
                Layout.minimumWidth: Theme.levelWidth
                popupY: info.y + level.y + y
                level: Battery.capacity / 100
                fill: Battery.color
            }
            PopupText {
                text: Battery.capacity + "%"
            }
        }
        PopupDetails {
            id: details
            visible: Battery.details.length > 0
            width: popup.wide
            rows: Battery.details
        }
    }
    Column {
        id: switches
        readonly property real valueWidth: Math.max(limit.valueImplicitWidth, quiet.valueImplicitWidth)
        readonly property real textWidth: limit.chromeWidth + Math.max(limit.labelImplicitWidth, quiet.labelImplicitWidth) + valueWidth
        spacing: 2

        PopupAction {
            id: limit
            labelWidth: popup.wide - limit.chromeWidth - switches.valueWidth
            valueWidth: switches.valueWidth
            text: "Charge limit"
            value: Battery.fullAt + "%"
            onTriggered: Battery.toggleLimit()
        }
        PopupAction {
            id: quiet
            labelWidth: popup.wide - quiet.chromeWidth - switches.valueWidth
            valueWidth: switches.valueWidth
            bright: Battery.quiet
            onColor: Theme.green
            text: "Quiet mode"
            value: Battery.quiet ? "on" : "off"
            widestValue: "off"
            onTriggered: Battery.toggleQuiet()
        }
    }
}
