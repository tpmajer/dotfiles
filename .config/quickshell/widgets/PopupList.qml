import QtQuick

// A popup of clickable rows, one below the other, whose columns line up:
// a row takes its labelWidth and valueWidth from here.
Column {
    id: list

    // Tells the PopupHost not to inset the popup: the rows inset their text.
    property bool hasRows: true
    readonly property real nameWidth: widest(i => i.labelImplicitWidth)
    readonly property real valueWidth: widest(i => i.valueImplicitWidth)
    spacing: 2

    function widest(width) {
        let w = 0;
        for (const item of children) {
            if (item instanceof PopupAction)
                w = Math.max(w, width(item));
        }
        return w;
    }
}
