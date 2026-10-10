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
    readonly property bool inhibited: Idle.inhibited
    // The switch's text and the rows below are as wide as the wider of the two.
    readonly property real wide: Math.max(details.implicitWidth, inhibitor.chromeWidth + inhibitor.labelImplicitWidth + inhibitor.valueImplicitWidth)
    spacing: Theme.popupRowGap
    // What is below the switch is inset like the switch's text, on the sides
    // and at the bottom.
    bottomPadding: Theme.popupTextInsetV

    // Seconds as "3.5 min", or as "1 min 40 s" where minutes would not be
    // a short number.
    function span(seconds) {
        if (seconds >= 60 && seconds % 30 === 0)
            return seconds / 60 + " min";
        const minutes = Math.floor(seconds / 60);
        return (minutes > 0 ? minutes + " min " : "") + seconds % 60 + " s";
    }

    PopupAction {
        id: inhibitor
        labelWidth: popup.wide - chromeWidth - valueImplicitWidth
        bright: popup.inhibited
        onColor: Theme.sky
        text: "Idle inhibitor"
        value: popup.inhibited ? "on" : "off"
        onTriggered: Idle.toggle()
    }

    PopupDetails {
        id: details
        x: Theme.popupTextInset
        width: popup.wide
        // Nothing of it happens while the inhibitor is on.
        opacity: popup.inhibited ? 0.4 : 1
        rows: Idle.stages.map(s => ({label: s.label, value: popup.span(s.after)}))
    }
}
