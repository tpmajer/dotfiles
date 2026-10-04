import QtQuick
import qs

// A clickable row in a popup: icon + label and an optional value on the right,
// Surface 0 highlight on hover or when selected from the keyboard. The label is
// dim unless the row is active or bright (what it shows is on). An optional
// detail follows the label, always dim. The detail and the value are styled
// text, so that a part of either can be in a color of its own.
Rectangle {
    id: root

    property string icon
    property string text
    property string detail: ""
    property string value: ""
    property color iconColor: Theme.text
    property bool bright: false
    property bool highlighted: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool active: hovered || highlighted

    // Set by a list to line its rows' columns up; the row's own width otherwise.
    property real labelWidth: -1
    property real valueWidth: -1
    readonly property real labelImplicitWidth: label.implicitWidth + (detail === "" ? 0 : detailText.implicitWidth)
    readonly property real valueImplicitWidth: value === "" ? 0 : valueText.implicitWidth

    signal triggered
    signal secondaryTriggered      // a right click
    signal scrolled(int steps)

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
        Row {
            width: root.labelWidth >= 0 ? root.labelWidth : implicitWidth

            PopupText {
                id: label
                text: root.text
                color: root.active || root.bright ? Theme.text : Theme.subtext0
            }
            PopupText {
                id: detailText
                visible: root.detail !== ""
                leftPadding: Theme.popupColumnGap
                textFormat: Text.StyledText
                text: root.detail
                color: Theme.subtext0
            }
        }
        PopupText {
            id: valueText
            visible: root.value !== "" || root.valueWidth > 0
            width: root.valueWidth >= 0 ? root.valueWidth : implicitWidth
            leftPadding: Theme.popupColumnGap - Theme.popupIconGap
            horizontalAlignment: Text.AlignRight
            textFormat: Text.StyledText
            text: root.value
            color: label.color
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
        onWheel: w => root.scrolled(w.angleDelta.y > 0 ? 1 : w.angleDelta.y < 0 ? -1 : 0)
    }
}
