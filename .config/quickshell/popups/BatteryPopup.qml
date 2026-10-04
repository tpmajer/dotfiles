import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// The battery as a level with its percent, as the memory popup's, in the
// module's color. Below it the time left, the power going out or in, the
// battery's health and its cycles. At the bottom the charge limit, where the
// percent stops: clicking it charges the battery full, or limits it again.
Column {
    id: popup

    readonly property bool hasRows: true
    // The level, the rows below and the switch's text are as wide as the
    // widest of the three.
    readonly property real wide: Math.max(level.implicitWidth, details.implicitWidth, limit.chromeWidth + limit.labelImplicitWidth + limit.valueImplicitWidth)
    spacing: Theme.popupRowGap
    // What is above the switch is inset like the switch's text, on the sides
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
    PopupAction {
        id: limit
        labelWidth: popup.wide - limit.chromeWidth - valueImplicitWidth
        text: "Charge limit"
        value: Battery.fullAt + "%"
        onTriggered: Battery.toggleLimit()
    }
}
