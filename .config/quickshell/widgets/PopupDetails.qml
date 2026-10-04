import QtQuick
import QtQuick.Layouts
import qs

// A label and a value to a row: the label dim at the left, the value at the
// right end, in the row's own color when it has one. Given a width, labels
// too long for it are cut short.
GridLayout {
    id: root

    property var rows: []       // [{label, value, color}]
    // A value's color in a row without one of its own.
    property color valueColor: Theme.subtext0

    columns: 2
    columnSpacing: Theme.popupGridGap
    rowSpacing: Theme.popupRowGap

    Repeater {
        model: root.rows

        delegate: Repeater {
            id: row
            required property var modelData
            model: 2

            PopupText {
                required property int index
                text: index === 0 ? row.modelData.label : row.modelData.value
                color: index === 0 ? Theme.subtext0 : row.modelData.color ?? root.valueColor
                elide: Text.ElideRight
                Layout.fillWidth: index === 0
                Layout.alignment: index === 0 ? Qt.AlignLeft : Qt.AlignRight
            }
        }
    }
}
