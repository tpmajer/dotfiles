import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

// One bar module: colored text on a transparent background, a faint Surface 0
// rectangle on hover and an optional popup (tooltip) below the bar.
Item {
    id: root

    property string text
    property color color: Theme.text
    // Optional text before the main one, in its own color (e.g. a warning icon).
    property string prefix: ""
    property color prefixColor: color
    // A width for the prefix, which is centered in it: for an icon that
    // changes, so that the module keeps its width. Its own width otherwise.
    property real prefixWidth: -1
    property bool bold: false
    property int fontSize: Theme.fontSize
    property string iconSource: ""
    property int iconSize: 22

    // Geometry: margins around the hover rectangle, padding inside it.
    property int leftMargin: 3
    property int rightMargin: 3
    property int hPadding: 12
    property int minWidth: 0
    property bool underline: true      // colored underline on hover

    property var host: null            // the PopupHost, which owns the popup
    property Component popup: null
    readonly property bool hovered: mouse.containsMouse
    readonly property real centerX: leftMargin + bg.width / 2
    property int maxTextWidth: -1

    signal clicked(var mouse)
    signal scrolled(int steps)

    visible: text !== "" || prefix !== "" || iconSource !== ""
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
            // At the bottom of the rectangle, on whole device pixels. The bar
            // is Theme.barMargin below the top of its window.
            readonly property real windowY: Theme.barMargin + bg.y + bg.height - height
            y: bg.height - height + Theme.snap(windowY, QsWindow.window?.devicePixelRatio ?? 1) - windowY
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.moduleRadius
            height: Theme.lineWidth
            radius: height / 2
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
                visible: root.prefix !== ""
                text: root.prefix
                color: root.prefixColor
                Behavior on color {
                    ColorAnimation { duration: Theme.hoverDuration }
                }
                font.family: Theme.font
                font.pixelSize: root.fontSize
                width: root.prefixWidth > 0 ? root.prefixWidth : implicitWidth
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: root.text !== ""
                text: root.text
                color: root.color
                // With the hover rectangle, for a module whose text brightens on hover.
                Behavior on color {
                    ColorAnimation { duration: Theme.hoverDuration }
                }
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
