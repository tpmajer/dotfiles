import QtQuick
import Quickshell
import qs
import qs.widgets

// The bar's background and the popup that opens from it: which module's popup
// is open, its animation and paddings, the bar and the popup drawn under one
// shadow, and the regions the window takes input in and gets blurred in.
// The modules are its children and sit on top of the bar.
Item {
    id: root

    // Keeps the popup open wherever the pointer is.
    property bool pinned: false
    default property alias content: modules.data

    // Right before a module's popup is shown or switched to.
    signal aboutToShow(Item module)

    // The bar's window is on screen: the bar pops in then, once.
    property bool mapped: false

    Pop {
        id: arrival
        shown: true
        mapped: root.mapped
    }

    readonly property real devicePixelRatio: QsWindow.window?.devicePixelRatio ?? 1

    // For the window: what takes input, and what the compositor blurs.
    readonly property Region inputRegion: Region {
        // Not barRect itself: an item comes with its transform, and the mask
        // would keep the scale the bar pops in from.
        x: barRect.x
        y: barRect.y
        width: barRect.width
        height: barRect.height
        Region { item: popupHitArea }
        Region { item: popupGapArea }
    }

    readonly property Region blurRegion: Region {
        // Not under a bar that is still popping in.
        readonly property bool shown: arrival.openness > 0.5
        x: barRect.x
        y: barRect.y
        width: shown ? barRect.width : 0
        height: shown ? barRect.height : 0
        radius: Theme.barRadius

        BlurBump {
            id: blurBump
            x: barRect.x + Theme.barRadius
            y: barRect.y + Theme.barRadius
        }

        Region {
            x: popupBody.x
            readonly property bool shown: popupBody.visible && root.openness > 0.5
            y: root.popupTop
            width: shown ? popupBody.width : 0
            height: shown ? root.popupVisibleHeight : 0
            radius: Theme.popupRadius
        }
    }

    // ---- popup state ------------------------------------------------------

    // Something is dragged out of the popup (its dragging): it stays open
    // as the pointer leaves it, and the closed hand shows all the way.
    readonly property bool popupDragging: popupLoader.item?.dragging === true

    property Item popupOwner: null
    property Item pendingOwner: null
    property bool popupOpen: false
    // The popup goes with its module, not left open and empty under the
    // pointer: a module hidden, or a workspace's gone.
    readonly property bool ownerGone: popupOpen && (!popupOwner || !popupOwner.visible)
    onOwnerGoneChanged: if (ownerGone)
        popupOpen = false
    readonly property real openness: pop.openness
    // What the open popup shows, for the keys the bar passes on to it.
    readonly property Item popupItem: popupLoader.item

    // Scaled from its top edge, towards the module.
    Pop {
        id: pop
        shown: root.popupOpen
    }

    // The blur is sent anew as a popup closes, opens or moves (BlurBump). Its
    // region is only sent halfway through the opening, hence the longer run.
    onPopupOpenChanged: blurBump.send(popupOpen ? 8 : 4)
    onPopupOwnerChanged: if (popupOpen)
        blurBump.send(8)

    readonly property real popupContentWidth: popupLoader.item ? popupLoader.item.implicitWidth : 0
    readonly property real popupContentHeight: popupLoader.item ? popupLoader.item.implicitHeight : 0
    // Popups made of clickable rows set hasRows and inset their own text.
    readonly property bool popupHasRows: !!popupLoader.item && popupLoader.item.hasRows === true
    readonly property real popupPadH: Theme.popupPadding + (popupHasRows ? 0 : Theme.popupTextInset)
    readonly property real popupPadV: Theme.popupPaddingV + (popupHasRows ? 0 : Theme.popupTextInsetV)
    readonly property real popupWidth: popupContentWidth + 2 * popupPadH
    // The popup's least distance from the bar's ends.
    readonly property real popupEdgeGap: Theme.popupRadius + 4
    // The widest content that fits, for a popup that can grow as wide.
    readonly property real maxContentWidth: barRect.width - 2 * popupEdgeGap - 2 * popupPadH
    property real popupHeight: popupContentHeight + 2 * popupPadV
    Behavior on popupHeight {
        enabled: root.openness > 0.01
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }
    // The popup is there whole for as long as it shows at all.
    readonly property real popupVisibleHeight: openness > 0.001 ? popupHeight : 0
    // Where the popup starts: below a gap under the bar.
    readonly property real popupTop: barRect.y + barRect.height + Theme.popupGap

    readonly property real ownerCenter: {
        const o = popupOwner;
        if (!o)
            return 0;
        // Referenced so the binding re-evaluates when the module or its row moves.
        void (o.x + o.width + o.parent.x + o.parent.width);
        return o.mapToItem(barRect, o.centerX, 0).x;
    }

    // The popup stays open while the pointer is over its module, over the popup,
    // or over the strip of bar right above the popup (the way between the two).
    // This is state, not enter/leave events, whose order Qt doesn't guarantee.
    readonly property bool popupHovered: {
        if (pinned || popupDragging)
            return true;
        if (popupOwner && popupOwner.hovered)
            return true;
        if (popupHover.hovered || gapHover.hovered)
            return true;
        if (!barHover.hovered)
            return false;
        const x = modules.x + barHover.point.position.x;
        return x >= popupBody.x && x <= popupBody.x + popupBody.width;
    }

    onPopupHoveredChanged: {
        if (popupHovered)
            hideTimer.stop();
        else if (popupOpen)
            hideTimer.restart();
    }

    // Closes the popup, and one that a hover is about to open: for a module
    // whose click opens something else.
    function dismiss() {
        showTimer.stop();
        pendingOwner = null;
        popupOpen = false;
    }

    function moduleHovered(module, hovered) {
        if (hovered) {
            if (!module.popup) {
                pendingOwner = null;
                showTimer.stop();
            } else if (popupOpen) {
                showPopup(module);
            } else {
                pendingOwner = module;
                showTimer.restart();
            }
        } else if (pendingOwner === module) {
            pendingOwner = null;
            showTimer.stop();
        }
    }

    function showPopup(module) {
        showTimer.stop();
        aboutToShow(module);
        popupOwner = module;
        popupLoader.sourceComponent = module.popup;
        popupOpen = true;
    }

    Timer {
        id: showTimer
        interval: 350
        onTriggered: if (root.pendingOwner)
            root.showPopup(root.pendingOwner)
    }

    // Long enough to come back to a popup the pointer has slipped off.
    Timer {
        id: hideTimer
        interval: 500
        onTriggered: if (!root.popupHovered)
            root.popupOpen = false
    }

    // ---- background: bar + popup, under one shadow ---------------------------

    Item {
        anchors.fill: parent

        layer.enabled: true
        layer.effect: Shadow {}

        Rectangle {
            id: barRect
            x: Theme.barMargin
            y: Theme.barMargin
            width: parent.width - 2 * Theme.barMargin
            height: Theme.barHeight
            radius: Theme.barRadius
            color: Theme.base
            opacity: arrival.openness
            transform: Scale {
                origin.x: barRect.width / 2
                origin.y: barRect.height / 2
                xScale: arrival.scale
                yScale: arrival.scale
            }
        }

        Rectangle {
            id: popupBody

            readonly property real targetX: {
                const minX = root.popupEdgeGap;
                const maxX = barRect.width - root.popupWidth - root.popupEdgeGap;
                // Centered under its module, but on a whole device pixel: off
                // one, everything in the popup is drawn slightly soft.
                return Theme.snap(barRect.x + Math.max(minX, Math.min(maxX, root.ownerCenter - root.popupWidth / 2)), root.devicePixelRatio);
            }

            x: targetX
            y: root.popupTop
            width: root.popupWidth
            height: root.popupVisibleHeight
            visible: root.popupVisibleHeight > 0.5
            color: Theme.base
            radius: Theme.popupRadius
            opacity: root.openness
            transform: Scale {
                origin.x: popupBody.width / 2
                xScale: pop.scale
                yScale: pop.scale
            }

            Behavior on x {
                enabled: root.openness > 0.01
                NumberAnimation {
                    duration: Theme.popupDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                enabled: root.openness > 0.01
                NumberAnimation {
                    duration: Theme.popupDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // ---- popup content --------------------------------------------------------

    // The popup's input area: popupBody's geometry without its animation
    // transform, which the mask region doesn't follow (a transformed popupBody
    // dropped out of the mask and the pointer fell through to the window below).
    Item {
        id: popupHitArea
        x: popupBody.x
        y: popupBody.y
        width: popupBody.visible ? popupBody.width : 0
        height: popupBody.height
    }

    // The gap between the bar and the popup: part of the popup for input,
    // so moving the pointer slowly across it doesn't close the popup.
    Item {
        id: popupGapArea
        x: popupBody.x
        y: barRect.y + barRect.height
        width: popupBody.visible ? popupBody.width : 0
        height: Theme.popupGap

        HoverHandler {
            id: gapHover
        }
    }

    Item {
        id: popupClip
        x: popupBody.x
        y: root.popupTop
        transform: Scale {
            origin.x: popupClip.width / 2
            xScale: pop.scale
            yScale: pop.scale
        }
        width: popupBody.width
        height: root.popupVisibleHeight
        clip: true
        visible: popupBody.visible

        Loader {
            id: popupLoader
            // The content's origin on a whole device pixel too.
            x: Theme.snap(popupClip.x + root.popupPadH, root.devicePixelRatio) - popupClip.x
            y: Theme.snap(popupClip.y + root.popupPadV, root.devicePixelRatio) - popupClip.y
            opacity: root.openness
        }

        // A HoverHandler, not a MouseArea, so clickable rows in the popup still get the mouse.
        HoverHandler {
            id: popupHover
        }
    }

    // ---- modules ----------------------------------------------------------------

    Item {
        id: modules
        x: barRect.x
        y: barRect.y
        width: barRect.width
        height: barRect.height
        opacity: arrival.openness
        transform: Scale {
            origin.x: modules.width / 2
            origin.y: modules.height / 2
            xScale: arrival.scale
            yScale: arrival.scale
        }

        HoverHandler {
            id: barHover
        }
    }

    // The closed hand while something is dragged out of the popup: the
    // cursor of what is dragged goes once the pointer leaves it.
    MouseArea {
        anchors.fill: parent
        visible: root.popupDragging
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ClosedHandCursor
    }
}
