import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.widgets

// Memory and swap, each as a level with what is used of the total, and below
// them the programs that take the most memory. Those are read only while the
// popup is open.
Column {
    id: popup

    // [{name, kib}], the largest first: scripts/mem-top.py.
    property var programs: []
    spacing: 8

    function size(kib) {
        return kib >= 1024 * 1024 ? (kib / 1024 / 1024).toFixed(1) + " GiB" : Math.round(kib / 1024) + " MiB";
    }

    Process {
        id: topProcess
        command: [Quickshell.shellDir + "/scripts/mem-top.py", "5"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    popup.programs = JSON.parse(text);
                } catch (e) {
                    popup.programs = [];
                }
            }
        }
    }
    Timer {
        interval: 3000
        running: popup.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: topProcess.running = true
    }

    GridLayout {
        id: levels
        columns: 4
        columnSpacing: 12
        rowSpacing: 4

        Repeater {
            model: [
                {label: "RAM", used: SysStats.memUsedGiB, total: SysStats.memTotalGiB, level: SysStats.memLevel},
                {label: "Swap", used: SysStats.swapUsedGiB, total: SysStats.swapTotalGiB, level: 0}
            ].filter(r => r.total > 0)

            delegate: Repeater {
                id: row
                required property var modelData
                readonly property color accent: modelData.level === 2 ? Theme.red : Theme.peach
                model: 4

                Loader {
                    id: cell
                    required property int index
                    Layout.alignment: (index >= 2 ? Qt.AlignRight : Qt.AlignLeft) | Qt.AlignVCenter
                    sourceComponent: index === 1 ? level : label

                    Component {
                        id: level
                        LevelBar {
                            popupY: levels.y + cell.y
                            level: row.modelData.used / row.modelData.total
                            fill: row.accent
                        }
                    }
                    Component {
                        id: label
                        PopupText {
                            text: cell.index === 0 ? row.modelData.label : cell.index === 2 ? row.modelData.used.toFixed(1) + " GiB" : "/ " + row.modelData.total.toFixed(1) + " GiB"
                            // The amount used tells when much of it is.
                            color: cell.index === 2 && row.modelData.level > 0 ? row.accent : Theme.text
                        }
                    }
                }
            }
        }
    }

    PopupDetails {
        visible: popup.programs.length > 0
        width: levels.width
        rows: popup.programs.map(p => ({label: p.name, value: popup.size(p.kib)}))
    }
}
