import QtQuick
import qs
import qs.widgets

// The clock's popup: today's date in full, and the month as a grid of weeks
// starting on Monday. Today is a filled cell, the weekend is dimmer than the
// working days, and the first and last week are filled up with the days of
// the months next to this one, fainter still. The wheel goes through the
// months, with the month's name for a header; the popup is back at the
// current one the next time it opens.
Column {
    id: cal
    readonly property var locale: Qt.locale("en_US")
    // The bar's clock, so the calendar and the clock module agree.
    required property date now
    // How many months from the current one the grid shows.
    property int offset: 0
    onVisibleChanged: if (!visible)
        offset = 0
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    readonly property int year: shown.getFullYear()
    readonly property int month: shown.getMonth()
    // Not now itself in the cells: it changes every second.
    readonly property int today: cal.key(now)

    // A date as one number, to tell whether two are the same day.
    function key(date) {
        return date.getFullYear() * 10000 + date.getMonth() * 100 + date.getDate();
    }

    // A notch of the wheel is a month; a touchpad sends it in small parts.
    WheelHandler {
        property real turned: 0
        // The touchpad too: on its own a WheelHandler takes only a mouse's wheel.
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            turned += event.angleDelta.y;
            const months = Math.trunc(turned / 120);
            turned -= months * 120;
            cal.offset -= months;
        }
    }
    // Weeks start on Monday: getDay() is 0 for Sunday, so shift it to the end.
    readonly property int firstDay: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    // A square that holds two bold digits with room around them.
    readonly property int cellSize: Math.ceil(Math.max(cell.width, cell.height)) + 8
    spacing: 8

    TextMetrics {
        id: cell
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
        text: "00"
    }

    PopupText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: cal.offset === 0 ? cal.locale.toString(cal.now, "dddd, d MMMM yyyy") : cal.locale.standaloneMonthName(cal.month) + " " + cal.year
        font.bold: true
    }

    Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 7
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: 7
            PopupText {
                required property int index
                width: cal.cellSize
                horizontalAlignment: Text.AlignHCenter
                text: cal.locale.dayName((index + 1) % 7, Locale.ShortFormat).slice(0, 2)
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 2
                opacity: index >= 5 ? 0.6 : 1
            }
        }

        Repeater {
            model: Math.ceil((cal.firstDay + cal.daysInMonth) / 7) * 7

            Rectangle {
                id: day
                required property int index
                // Past either end of the month, the date rolls over into the one next to it.
                readonly property date date: new Date(cal.year, cal.month, index - cal.firstDay + 1)
                readonly property bool inMonth: date.getMonth() === cal.month
                readonly property bool today: cal.key(date) === cal.today
                readonly property bool weekend: index % 7 >= 5

                width: cal.cellSize
                height: cal.cellSize
                radius: Theme.moduleRadius
                color: today ? Theme.mauve : "transparent"

                PopupText {
                    anchors.centerIn: parent
                    text: day.date.getDate()
                    color: day.today ? Theme.base : day.weekend ? Theme.subtext0 : Theme.white
                    font.bold: day.today
                    opacity: day.inMonth || day.today ? 1 : 0.35
                }
            }
        }
    }
}
