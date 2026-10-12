import QtQuick
import Quickshell
import qs.services
import qs.widgets

// The machine at a glance: how long it has been up and awake, what it runs,
// and what is wrong with it, if anything is.
PopupDetails {
    id: popup

    rows: Machine.details(clock.date.getTime())

    // Read anew as the popup opens, and while it is open.
    Timer {
        interval: 10000
        running: popup.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: Machine.refresh()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
