import QtQuick
import Quickshell
import qs

// A level from 0 to 1 as a filled track: a core's usage in the CPU popup, the
// memory taken in the memory one.
Item {
    id: bar

    property real level: 0
    property color fill: Theme.text
    // Its y in the popup. With that the track is drawn on whole device pixels
    // (the popup's origin is on one), and so with hard edges.
    property real popupY: 0

    implicitWidth: 60
    implicitHeight: Theme.levelHeight

    Rectangle {
        y: Theme.snap(bar.popupY, QsWindow.window?.devicePixelRatio ?? 1) - bar.popupY
        width: parent.width
        height: parent.height
        radius: height / 2
        color: Theme.surface0

        Rectangle {
            // Never narrower than its height, or it can't be round and sticks
            // out of the track's end: at 0 it shrinks to a dot and fades out.
            width: Math.max(height, parent.width * Math.min(1, bar.level))
            opacity: bar.level > 0 ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
            height: parent.height
            radius: parent.radius
            color: bar.fill
            Behavior on width {
                NumberAnimation { duration: 300 }
            }
        }
    }
}
