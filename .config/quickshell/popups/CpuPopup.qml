import QtQuick
import qs
import qs.services
import qs.widgets

Column {
    spacing: 8

    PopupText { text: "Load " + SysStats.loadAvg }

    // The widest core number, so the grid starts flush with the line above.
    TextMetrics {
        id: coreIndex
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: String(Math.max(SysStats.coreUsages.length - 1, 0))
    }

    Grid {
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

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    height: 6
                    radius: 3
                    color: Theme.surface0

                    Rectangle {
                        width: parent.width * parent.parent.usage / 100
                        height: parent.height
                        radius: parent.radius
                        color: Theme.lavender
                        Behavior on width {
                            NumberAnimation { duration: 300 }
                        }
                    }
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
