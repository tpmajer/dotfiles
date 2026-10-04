import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// The idle inhibitor's state, and below it what happens once nothing is
// touched and after how long. Not a countdown: the pointer coming here ends
// the idle time, so the time left is in the module itself.
Column {
    spacing: 6

    PopupText {
        text: Custom.idle.tooltip || ""
    }

    GridLayout {
        // Nothing of it happens while the inhibitor is on.
        opacity: Custom.idle.class === "activated" ? 0.4 : 1
        columns: 2
        columnSpacing: 16
        rowSpacing: 4

        Repeater {
            model: Custom.idleStages

            delegate: Repeater {
                required property var modelData
                model: [modelData.label, "after " + modelData.after / 60 + " min"]

                PopupText {
                    required property var modelData
                    required property int index
                    text: modelData
                    color: Theme.subtext0
                    Layout.alignment: index === 0 ? Qt.AlignLeft : Qt.AlignRight
                }
            }
        }
    }
}
