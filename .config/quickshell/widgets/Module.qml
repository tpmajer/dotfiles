import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

// One bar module: colored text on a transparent background, a faint Surface 0
// rectangle on hover and an optional popup below the bar.
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
    property int prefixSize: fontSize
    property bool bold: false
    property int fontSize: Theme.fontSize
    property string iconSource: ""
    property int iconSize: 22
    // What a module shows that is neither text nor an icon, after them.
    property Component content: null

    // Geometry: margins around the hover rectangle, padding inside it.
    property int leftMargin: 3
    property int rightMargin: 3
    property int hPadding: 12
    property int minWidth: 0
    property bool underline: true      // colored underline on hover

    property var host: null            // the PopupHost, which owns the popup
    property Component popup: null
    readonly property bool hovered: mouse.containsMouse
    // Shown as hovered without the pointer on it: a drop target.
    property bool highlighted: false
    readonly property real centerX: leftMargin + bg.width / 2
    // The most the text takes; no limit below 0.
    property int maxTextWidth: -1

    // What a right click runs, and whether a left one shows the popup at
    // once. Each button has its signal, sent whatever else its click does.
    property var rightCommand: []
    property bool clickOpensPopup: false
    // Whether a left click closes the popup, or keeps one from opening: for
    // a click that opens something else.
    property bool clickDismissesPopup: false

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int steps)

    // Shows the popup at once, without the wait a hover takes.
    function openPopup() {
        if (host && popup)
            host.showPopup(root);
    }

    visible: text !== "" || prefix !== "" || iconSource !== "" || content !== null
    implicitWidth: visible ? bg.width + leftMargin + rightMargin : 0
    implicitHeight: Theme.barHeight

    Rectangle {
        id: bg
        x: root.leftMargin
        y: 6
        width: Math.max(contentRow.implicitWidth + 2 * root.hPadding, root.minWidth)
        height: root.height - 12
        radius: Theme.moduleRadius
        // Fade only the alpha: animating from "transparent" (black) flashes dark.
        color: mouse.containsMouse || root.highlighted ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
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
            opacity: mouse.containsMouse || root.highlighted ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.hoverDuration }
            }
        }

        Row {
            id: contentRow
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
                textFormat: Text.PlainText
                color: root.prefixColor
                Behavior on color {
                    ColorAnimation { duration: Theme.hoverDuration }
                }
                font.family: Theme.font
                font.pixelSize: root.prefixSize
                width: root.prefixWidth > 0 ? root.prefixWidth : implicitWidth
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: root.text !== ""
                text: root.text
                // As written: a window's title is not markup.
                textFormat: Text.PlainText
                color: root.color
                // With the hover rectangle, for a module whose text brightens on hover.
                Behavior on color {
                    ColorAnimation { duration: Theme.hoverDuration }
                }
                font.family: Theme.font
                font.pixelSize: root.fontSize
                font.bold: root.bold
                width: root.maxTextWidth >= 0 ? Math.min(implicitWidth, root.maxTextWidth) : implicitWidth
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            Loader {
                visible: root.content !== null
                sourceComponent: root.content
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: bg
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.RightButton) {
                // Through niri, as from the launcher: a child of this
                // service would go with it when it restarts.
                if (root.rightCommand.length > 0)
                    Niri.send({Action: {Spawn: {command: root.rightCommand}}});
                root.rightClicked();
            } else if (m.button === Qt.MiddleButton) {
                root.middleClicked();
            } else {
                if (root.clickOpensPopup)
                    root.openPopup();
                else if (root.clickDismissesPopup && root.host)
                    root.host.dismiss();
                root.clicked();
            }
        }
        onWheel: w => wheel.turn(w.angleDelta.y)

        WheelSteps {
            id: wheel
            onStepped: steps => root.scrolled(steps)
        }
        onContainsMouseChanged: if (root.host)
            root.host.moduleHovered(root, containsMouse)
    }
}
