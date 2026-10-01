import QtQuick
import qs
import qs.services
import qs.widgets

Column {
    spacing: 4
    PopupText { text: "Battery " + Battery.capacity + "%" }
    PopupText {
        visible: Battery.timeText !== ""
        text: (Battery.charging ? "Full in " : "Empty in ") + Battery.timeText
        color: Theme.subtext0
    }
}
