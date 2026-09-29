import QtQuick
import Quickshell.Widgets

// One bar module: colored text on a transparent background, a faint Surface 0
// rectangle on hover and an optional popup (tooltip) grown out of the bar.
Item {
    id: root

    property string text
    property color color: Theme.text
    property bool bold: false
    property int fontSize: Theme.fontSize
    property string iconSource: ""
    property int iconSize: 22

    // Geometry, as margin/padding in waybar's CSS.
    property int leftMargin: 3
    property int rightMargin: 3
    property int hPadding: 12
    property int minWidth: 0
    property bool underline: true      // colored underline on hover

    property var host: null            // the Bar, which owns the popup
    property Component popup: null
    readonly property bool hovered: mouse.containsMouse
    readonly property real centerX: leftMargin + bg.width / 2
    property int maxTextWidth: -1

    signal clicked(var mouse)
    signal scrolled(int steps)

    visible: text !== "" || iconSource !== ""
    implicitWidth: visible ? bg.width + leftMargin + rightMargin : 0
    implicitHeight: Theme.barHeight

    Rectangle {
        id: bg
        x: root.leftMargin
        y: 6
        width: Math.max(content.implicitWidth + 2 * root.hPadding, root.minWidth)
        height: root.height - 12
        radius: Theme.moduleRadius
        // Fade only the alpha: animating from "transparent" (black) flashes dark.
        color: mouse.containsMouse ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
        Behavior on color {
            ColorAnimation { duration: Theme.hoverDuration }
        }

        // Underline in the module's color, faded in with the rectangle.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.moduleRadius
            height: 2
            radius: 1
            color: root.color
            visible: root.underline
            opacity: mouse.containsMouse ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.hoverDuration }
            }
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 6

            IconImage {
                visible: root.iconSource !== ""
                source: root.iconSource
                implicitSize: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.text
                color: root.color
                font.family: Theme.font
                font.pixelSize: root.fontSize
                font.bold: root.bold
                width: root.maxTextWidth > 0 ? Math.min(implicitWidth, root.maxTextWidth) : implicitWidth
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: bg
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y > 0 ? 1 : w.angleDelta.y < 0 ? -1 : 0)
        onContainsMouseChanged: if (root.host)
            root.host.moduleHovered(root, containsMouse)
    }
}
