import QtQuick
import qs
import qs.services
import qs.widgets

// The idle inhibitor's state, and below it what happens once nothing is
// touched and after how long. Not a countdown: the pointer coming here ends
// the idle time, so the time left is in the module itself.
Column {
    spacing: 6

    PopupText {
        text: Custom.idle.tooltip || ""
    }

    PopupDetails {
        // Nothing of it happens while the inhibitor is on.
        opacity: Custom.idle.class === "activated" ? 0.4 : 1
        rows: Custom.idleStages.map(s => ({label: s.label, value: "after " + s.after / 60 + " min"}))
    }
}
