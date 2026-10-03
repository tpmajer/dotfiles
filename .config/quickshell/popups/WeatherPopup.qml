import QtQuick
import qs
import qs.services
import qs.widgets

Column {
    spacing: 4
    PopupText { text: Weather.place + " " + Weather.temperatureText }
    PopupText {
        text: Weather.description
        color: Theme.subtext0
    }
}
