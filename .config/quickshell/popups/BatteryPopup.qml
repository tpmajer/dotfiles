import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// The battery as a level with its percent, as the memory popup's, in the
// module's color. Below it the time left, the power going out or in, and
// what does not change by the hour: the charge limit, which the percent is
// of, the battery's health and its cycles.
Column {
    id: popup

    // The level and the rows below are as wide as the wider of the two.
    readonly property real wide: Math.max(level.implicitWidth, details.implicitWidth)
    spacing: Theme.popupSectionGap

    RowLayout {
        id: level
        width: popup.wide
        spacing: Theme.popupColumnGap

        PopupText {
            text: "Battery"
        }
        LevelBar {
            id: bar
            Layout.fillWidth: true
            popupY: level.y + y
            level: Battery.capacity / 100
            fill: Battery.color
        }
        PopupText {
            text: Battery.capacity + "%"
        }
    }
    PopupDetails {
        id: details
        width: popup.wide
        rows: Battery.details
    }
}
