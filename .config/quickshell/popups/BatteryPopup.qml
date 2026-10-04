import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// The battery as a level with its percent, as the memory popup's, in the
// module's color.
Column {
    id: popup

    spacing: Theme.popupSectionGap

    RowLayout {
        id: level
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
    PopupText {
        visible: Battery.timeText !== ""
        text: (Battery.charging ? "Full in " : "Empty in ") + Battery.timeText
        color: Theme.subtext0
    }
}
