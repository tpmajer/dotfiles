import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// The weather now on the left, the week on the right, row by row: both have
// the same spacing, and seven rows each.
Row {
    id: weather
    spacing: 32

    // A click anywhere in the popup opens the weather application.
    signal launched
    TapHandler {
        onTapped: {
            Apps.run("gnome-weather");
            weather.launched();
        }
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    Column {
        spacing: Theme.popupRowGap
        PopupText { text: Weather.place + " " + Weather.temperatureText }
        PopupText {
            text: Weather.description
            color: Theme.subtext0
        }
        // When it is to rain, how it feels, the wind and the sun.
        PopupDetails {
            visible: Weather.details.length > 0
            rows: Weather.details
        }
    }

    // A day to a row, today first and in bold: its name, its weather, in
    // the rain's color on a day more likely wet than not, and its range.
    GridLayout {
        visible: Weather.days.length > 0
        columns: 3
        columnSpacing: Theme.popupGridGap
        rowSpacing: Theme.popupRowGap

        Repeater {
            model: Weather.days

            delegate: Repeater {
                id: day
                required property var modelData
                required property int index
                readonly property bool today: index === 0
                model: 3

                PopupText {
                    required property int index
                    text: index === 0 ? Qt.formatDate(new Date(day.modelData.time), "ddd") : index === 1 ? Weather.glyphFor(day.modelData.code, true) : Math.round(day.modelData.low) + "° / " + Math.round(day.modelData.high) + "°"
                    color: index === 1 && day.modelData.chance >= 50 ? Theme.sky : index === 0 && !day.today ? Theme.subtext0 : Theme.text
                    font.bold: day.today
                    font.pixelSize: index === 1 ? Theme.fontSize + 2 : Theme.fontSize
                    Layout.alignment: index === 2 ? Qt.AlignRight : index === 1 ? Qt.AlignHCenter : Qt.AlignLeft
                }
            }
        }
    }
}
