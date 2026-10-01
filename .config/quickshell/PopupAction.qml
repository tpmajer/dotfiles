import QtQuick

// A clickable row in a popup: icon + label, Surface 0 highlight on hover or
// when selected from the keyboard.
Rectangle {
    id: root

    property string icon
    property string text
    property color iconColor: Theme.text
    property bool highlighted: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool active: hovered || highlighted

    signal triggered

    implicitWidth: row.implicitWidth + 24
    implicitHeight: row.implicitHeight + 8
    radius: Theme.moduleRadius
    color: active ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
    Behavior on color {
        ColorAnimation { duration: Theme.hoverDuration }
    }

    Row {
        id: row
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.popupIconGap

        PopupText {
            width: 20
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            color: root.iconColor
        }
        PopupText {
            text: root.text
            color: root.active ? Theme.text : Theme.subtext0
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
