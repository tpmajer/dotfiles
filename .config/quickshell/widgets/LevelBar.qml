import QtQuick
import qs

// A level from 0 to 1 as a filled track, like a core's usage in the CPU popup.
Rectangle {
    id: bar

    property real level: 0
    property color fill: Theme.text

    implicitWidth: 60
    implicitHeight: Theme.levelHeight
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
