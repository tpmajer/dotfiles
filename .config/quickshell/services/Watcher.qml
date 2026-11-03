import QtQuick
import Quickshell.Io

// A process kept running: started again a while after it exits or fails to
// start (that only changes `running`, with no `exited`).
Process {
    id: root

    property int restartDelay: 5000

    running: true
    onRunningChanged: if (!running)
        restart.start()

    readonly property Timer restart: Timer {
        interval: root.restartDelay
        onTriggered: root.running = true
    }
}
