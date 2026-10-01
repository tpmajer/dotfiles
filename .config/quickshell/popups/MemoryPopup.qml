import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Like the network popup: the label left, used and total right-aligned.
GridLayout {
    columns: 3
    columnSpacing: 16
    rowSpacing: 4

    Repeater {
        model: [
            {label: "RAM", used: SysStats.memUsedGiB, total: SysStats.memTotalGiB},
            {label: "Swap", used: SysStats.swapUsedGiB, total: SysStats.swapTotalGiB}
        ].filter(r => r.total > 0)

        delegate: Repeater {
            required property var modelData
            model: [modelData.label, modelData.used.toFixed(1) + " GiB", "/ " + modelData.total.toFixed(1) + " GiB"]

            PopupText {
                required property var modelData
                required property int index
                text: modelData
                Layout.alignment: index === 0 ? Qt.AlignLeft : Qt.AlignRight
            }
        }
    }
}
