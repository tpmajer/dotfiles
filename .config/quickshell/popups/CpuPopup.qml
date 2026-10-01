import QtQuick
import Quickshell
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

                Rectangle {
                    // Centered in its row, on whole device pixels (the popup's
                    // origin is on one).
                    readonly property real popupY: grid.y + parent.y + (parent.height - height) / 2
                    y: Theme.snap(popupY, QsWindow.window?.devicePixelRatio ?? 1) - grid.y - parent.y
                    width: 60
                    height: Theme.levelHeight
                    radius: height / 2
                    color: Theme.surface0

                    Rectangle {
                        // Never narrower than its height, or it can't be round
                        // and sticks out of the track's end: at 0 it shrinks to
                        // a dot and fades out.
                        width: Math.max(height, parent.width * parent.parent.usage / 100)
                        opacity: parent.parent.usage > 0 ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 300 }
                        }
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
