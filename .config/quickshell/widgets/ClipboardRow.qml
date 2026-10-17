import QtQuick
import qs
import qs.services

// An entry of the clipboard's history in its popup: its text on one line,
// or an image's thumbnail and what it is. Highlighted on hover as a
// popup's clickable row is; bright for what the clipboard holds.
Rectangle {
    id: root

    required property var entry
    property bool bright: false
    readonly property bool hovered: mouse.containsMouse

    signal triggered
    signal secondaryTriggered      // a right click

    implicitHeight: Math.max(thumb.visible ? thumb.height : 0, label.implicitHeight) + 8
    radius: Theme.moduleRadius
    color: hovered ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
    Behavior on color {
        ColorAnimation { duration: Theme.hoverDuration }
    }

    Image {
        id: thumb
        visible: root.entry.image
        x: Theme.popupTextInset
        anchors.verticalCenter: parent.verticalCenter
        width: 96
        height: 48
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignLeft
        asynchronous: true
        sourceSize.width: 2 * width
        sourceSize.height: 2 * height
        source: visible ? Clipboard.thumbnail(root.entry) : ""
    }

    PopupText {
        id: label
        // Right after the image as drawn, which may be narrower than its box.
        x: thumb.visible ? thumb.x + thumb.paintedWidth + Theme.popupIconGap : Theme.popupTextInset
        width: root.width - x - Theme.popupTextInset
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.entry.text
        color: root.hovered || root.bright ? Theme.text : Theme.subtext0
        Behavior on color {
            ColorAnimation { duration: Theme.hoverDuration }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton)
                root.secondaryTriggered();
            else
                root.triggered();
        }
    }
}
