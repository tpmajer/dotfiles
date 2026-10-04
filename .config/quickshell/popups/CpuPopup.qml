import QtQuick
import qs
import qs.services
import qs.widgets

Column {
    spacing: 8

    // The load on the left, the temperature at the right end of the grid.
    Item {
        width: grid.width
        height: load.height

        PopupText {
            id: load
            text: "Load " + SysStats.loadAvg
        }
        PopupText {
            anchors.right: parent.right
            visible: SysStats.cpuTemp > 0
            text: Math.round(SysStats.cpuTemp) + "°C"
            color: SysStats.cpuTempLevel === 2 ? Theme.red : SysStats.cpuTempLevel === 1 ? Theme.peach : Theme.text
        }
    }

    // The widest core number, so the grid starts flush with the line above.
    TextMetrics {
        id: coreIndex
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: String(Math.max(SysStats.coreUsages.length - 1, 0))
    }

    Grid {
        id: grid
        columns: 4
        columnSpacing: 20
        rowSpacing: 4

        Repeater {
            model: SysStats.coreUsages.length

            Row {
                required property int index
                readonly property int usage: SysStats.coreUsages[index] || 0
                spacing: 8

                PopupText {
                    width: Math.ceil(coreIndex.width)
                    horizontalAlignment: Text.AlignRight
                    text: parent.index
                    color: Theme.subtext0
                }

                LevelBar {
                    anchors.verticalCenter: parent.verticalCenter
                    popupY: grid.y + parent.y + y
                    level: parent.usage / 100
                    fill: Theme.lavender
                }

                PopupText {
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: parent.usage + "%"
                }
            }
        }
    }
}
