import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// The battery as a level with its percent, as the memory popup's, in the
// module's color. Below it the time left, the power going out or in, the
// battery's health and its cycles. At the bottom the charge limit, which the
// percent is of: clicking it charges the battery full, or limits it again.
Column {
    id: popup

    readonly property bool hasRows: true
    // What a row has besides its label and value, as PopupAction lays them
    // out: the icon, and a gap on either side of the label.
    readonly property real rowExtra: 20 + 2 * Theme.popupIconGap
    // The level, the rows below and the switch's text are as wide as the
    // widest of the three.
    readonly property real wide: Math.max(level.implicitWidth, details.implicitWidth, rowExtra + limit.labelImplicitWidth + limit.valueImplicitWidth)
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
    // The battery icon of that level: four fifths, or full.
    PopupAction {
        id: limit
        labelWidth: popup.wide - popup.rowExtra - valueImplicitWidth
        icon: Theme.glyph(Battery.defaultIcons[Math.min(9, Math.floor(Battery.fullAt / 10) - 1)])
        iconColor: Battery.limited ? Theme.subtext0 : Theme.green
        bright: !Battery.limited
        text: "Charge limit"
        value: Battery.fullAt + "%"
        onTriggered: Battery.toggleLimit()
    }
}
