import QtQuick
import qs

// A word or a glyph to click, highlighted on hover as a popup's clickable
// row is.
Rectangle {
    id: root

    property alias text: label.text
    property alias font: label.font
    // Bright without the pointer on it: what it shows is on.
    property bool bright: false

    signal clicked

    implicitWidth: label.implicitWidth + 2 * Theme.popupTextInset
    implicitHeight: label.implicitHeight + 8
    radius: Theme.moduleRadius
    color: mouse.containsMouse ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
    Behavior on color {
        ColorAnimation { duration: Theme.hoverDuration }
    }

    PopupText {
        id: label
        anchors.centerIn: parent
        color: mouse.containsMouse || root.bright ? Theme.text : Theme.subtext0
        Behavior on color {
            ColorAnimation { duration: Theme.hoverDuration }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
