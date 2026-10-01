import QtQuick
import qs
import qs.widgets

Column {
    id: cal
    readonly property var locale: Qt.locale("en_US")
    // The bar's clock, so the calendar and the clock module agree.
    required property date now
    readonly property int year: now.getFullYear()
    readonly property int month: now.getMonth()
    // Weeks start on Monday: getDay() is 0 for Sunday, so shift it to the end.
    readonly property int firstDay: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    spacing: 6

    TextMetrics {
        id: cell
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
        text: "00"
    }

    PopupText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: cal.locale.standaloneMonthName(cal.month) + " " + cal.year
    }

    Grid {
        columns: 7
        columnSpacing: 10
        rowSpacing: 4

        Repeater {
            model: 7
            PopupText {
                required property int index
                width: cell.width
                horizontalAlignment: Text.AlignRight
                text: cal.locale.dayName((index + 1) % 7, Locale.ShortFormat).slice(0, 2)
                color: Theme.pink
                font.bold: true
            }
        }

        Repeater {
            model: Math.ceil((cal.firstDay + cal.daysInMonth) / 7) * 7
            PopupText {
                required property int index
                readonly property int day: index - cal.firstDay + 1
                readonly property bool today: day === cal.now.getDate()
                width: cell.width
                horizontalAlignment: Text.AlignRight
                text: day >= 1 && day <= cal.daysInMonth ? day : ""
                color: today ? Theme.pink : Theme.white
                font.bold: today
                font.underline: today
            }
        }
    }
}
