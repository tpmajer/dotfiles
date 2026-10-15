import QtQuick

// A line of a Cascade: fades in, 12 px up into its place. One file, two
// copies: ~/.dotfiles/.config/quickshell/lock and ~/.nixos/greeter; keep
// them alike.
Item {
    id: step

    required property QtObject cascade
    property int order: 0
    default property alias content: holder.data
    readonly property real shown: cascade.stage(order)

    anchors.horizontalCenter: parent?.horizontalCenter
    implicitWidth: holder.childrenRect.width
    implicitHeight: holder.childrenRect.height
    opacity: shown
    transform: Translate {
        y: 12 * (1 - step.shown)
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
