import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// The weather now on the left, the week on the right, row by row: both have
// the same spacing, and seven rows each, the first apart from the rest.
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

    // The place at the top, level with today, and the rest below it, level
    // with the days after.
    Item {
        width: Math.max(place.width, now.width)
        height: Math.max(place.height + Theme.popupSectionGap + now.height, week.visible ? week.height : 0)

        PopupText {
            id: place
            text: Weather.place + " " + Weather.temperatureText
        }

        Column {
            id: now
            y: place.height + Theme.popupSectionGap
            spacing: Theme.popupRowGap
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
    }

    // Not shown, only measured: a line of text's height.
    PopupText {
        id: line
        visible: false
        text: "M"
    }

    // A day to a row, today first and in bold: its name, its weather, in
    // the rain's color on a day more likely wet than not, and its range, in
    // columns of its own so that the slashes line up.
    GridLayout {
        id: week
        visible: Weather.days.length > 0
        columns: 5
        columnSpacing: 0
        rowSpacing: Theme.popupRowGap

        Repeater {
            model: Weather.days

            delegate: Repeater {
                id: day
                required property var modelData
                required property int index
                readonly property bool today: index === 0
                model: 5

                PopupText {
                    required property int index
                    text: [Qt.formatDate(new Date(day.modelData.time), "ddd"), Weather.glyphFor(day.modelData.code, true), Math.round(day.modelData.low) + "°", " / ", Math.round(day.modelData.high) + "°"][index]
                    color: index === 1 && day.modelData.chance >= 50 ? Theme.sky : index === 0 && !day.today ? Theme.subtext0 : Theme.text
                    font.bold: day.today
                    font.pixelSize: index === 1 ? Theme.fontSize + 6 : Theme.fontSize
                    // The larger icon in a line's height: it overflows it
                    // instead of spacing the rows out.
                    Layout.preferredHeight: index === 1 ? line.implicitHeight : -1
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: index === 2 || index === 4 ? Qt.AlignRight : index === 1 ? Qt.AlignHCenter : Qt.AlignLeft
                    // The grid's gap before the icon and the range only.
                    Layout.leftMargin: index === 1 || index === 2 ? Theme.popupGridGap : 0
                    // Today apart from the rest, as the place is on the left.
                    Layout.topMargin: day.index === 1 ? Theme.popupSectionGap - Theme.popupRowGap : 0
                }
            }
        }
    }
}
