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
    // How long the fill takes to get to a new level, in ms; 0 for at once.
    property int glide: 300
    // The level as drawn, on its way to a new one. The fill's width
    // follows it at once: animated itself, it would also creep along
    // whenever a layout gives the track its width, as a popup opens.
    property real shown: level
    // Off at 0, not an animation of no time: that one takes a frame, and
    // a level set again within it starts from the old one.
    Behavior on shown {
        enabled: bar.glide > 0
        NumberAnimation { duration: bar.glide }
    }

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
            width: Math.max(height, parent.width * Math.min(1, bar.shown))
            opacity: bar.level > 0 ? 1 : 0
            Behavior on opacity {
                enabled: bar.glide > 0
                NumberAnimation { duration: Math.min(300, bar.glide) }
            }
            height: parent.height
            radius: parent.radius
            color: bar.fill

        }
    }
}
