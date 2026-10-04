import QtQuick
import QtQuick.Layouts
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
    // A label and a value to a row, as in the network popup: when it is to
    // rain, how it feels, the wind and the sun.
    GridLayout {
        visible: Weather.details.length > 0
        columns: 2
        columnSpacing: 16
        rowSpacing: 4

        Repeater {
            model: Weather.details

            delegate: Repeater {
                id: detail
                required property var modelData
                model: 2

                PopupText {
                    required property int index
                    text: index === 0 ? detail.modelData.label : detail.modelData.value
                    color: index === 0 ? Theme.subtext0 : detail.modelData.color
                    Layout.alignment: index === 0 ? Qt.AlignLeft : Qt.AlignRight
                }
            }
        }
    }
}
