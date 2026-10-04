import QtQuick
import qs
import qs.services
import qs.widgets

// The idle inhibitor's switch, and below it what happens once nothing is
// touched and after how long. Not a countdown: the pointer coming here ends
// the idle time, so the time left is in the module itself.
Column {
    id: popup

    readonly property bool hasRows: true
    readonly property bool inhibited: Custom.idle.class === "activated"
    // The switch's text and the rows below are as wide as the wider of the two.
    readonly property real wide: Math.max(details.implicitWidth, inhibitor.chromeWidth + inhibitor.labelImplicitWidth + inhibitor.valueImplicitWidth)
    spacing: Theme.popupRowGap
    // What is below the switch is inset like the switch's text, on the sides
    // and at the bottom.
    bottomPadding: Theme.popupTextInsetV

    PopupAction {
        id: inhibitor
        labelWidth: popup.wide - chromeWidth - valueImplicitWidth
        bright: popup.inhibited
        text: "Idle inhibitor"
        value: popup.inhibited ? "on" : "off"
        onTriggered: Custom.toggleIdle()
    }

    PopupDetails {
        id: details
        x: Theme.popupTextInset
        width: popup.wide
        // Nothing of it happens while the inhibitor is on.
        opacity: popup.inhibited ? 0.4 : 1
        rows: Custom.idleStages.map(s => ({label: s.label, value: "after " + s.after / 60 + " min"}))
    }
}
