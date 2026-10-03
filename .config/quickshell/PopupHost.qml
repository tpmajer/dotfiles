import QtQuick
import QtQuick.Shapes
import Quickshell
import qs
import qs.widgets

// The bar's background and the popup that grows out of it: which module's popup
// is open, its animation and paddings, the bar and the popup drawn as one shape
// with a shadow, and the regions the window takes input in and gets blurred in.
// The modules are its children and sit on top of the bar.
Item {
    id: root

    // Keeps the popup open wherever the pointer is.
    property bool pinned: false
    default property alias content: modules.data

    // Right before a module's popup is shown or switched to.
    signal aboutToShow(Item module)

    readonly property real devicePixelRatio: QsWindow.window?.devicePixelRatio ?? 1

    // For the window: what takes input, and what the compositor blurs.
    readonly property Region inputRegion: Region {
        item: barRect
        Region { item: popupHitArea }
        Region { item: popupGapArea }
    }

    readonly property Region blurRegion: Region {
        x: barRect.x
        y: barRect.y
        width: barRect.width
        height: barRect.height
        radius: Theme.barRadius

        // Inside the bar, so it blurs nothing new; see blurResend.
        Region {
            x: barRect.x + Theme.barRadius
            y: barRect.y + Theme.barRadius
            width: 1
            height: 1 + root.blurResend % 2
        }

        Region {
            x: popupBody.x
            readonly property bool shown: popupBody.visible && (!root.fadeAnimation || root.openness > 0.5)
            y: root.popupTop + root.animShift
            width: shown ? popupBody.width : 0
            height: shown ? root.popupVisibleHeight : 0
            topLeftRadius: Theme.popupAttached ? 0 : Theme.popupRadius
            topRightRadius: Theme.popupAttached ? 0 : Theme.popupRadius
            bottomLeftRadius: Theme.popupRadius
            bottomRightRadius: Theme.popupRadius
        }
    }

    // ---- popup state ------------------------------------------------------

    property Item popupOwner: null
    property Item pendingOwner: null
    property bool popupOpen: false
    property real openness: popupOpen ? 1 : 0

    // With Qt's threaded render loop (the one that runs animations at the
    // screen's refresh rate) a new blur region sometimes goes out right after a
    // commit still waiting on its GPU fence; niri then applies it with that
    // older commit and keeps blurring a closed popup until the region changes
    // again. So change it a few more times once a popup closes: each bump
    // resizes a 1 px region inside the bar, which sends the whole region anew.
    property int blurResend: 0
    onPopupOpenChanged: {
        if (popupOpen) {
            action.pending = "";
        } else {
            blurResendTimer.left = 4;
            blurResendTimer.start();
        }
    }
    Timer {
        id: blurResendTimer
        property int left: 0
        interval: 48
        repeat: true
        onTriggered: {
            root.blurResend++;
            if (--left <= 0)
                stop();
        }
    }
    readonly property bool niriAnimation: Theme.popupAnimation === "niri"
    readonly property bool popAnimation: Theme.popupAnimation === "pop"
    // Both show the popup whole and fade it, instead of growing it.
    readonly property bool fadeAnimation: niriAnimation || popAnimation
    Behavior on openness {
        // The target is already set when this starts, so popupOpen tells open from close.
        // "niri": prism-glide.kdl's window-open/close timings and curves, times its
        // slowdown 1.3. "pop": quick with a slight overshoot in, quicker out.
        NumberAnimation {
            duration: root.niriAnimation ? (root.popupOpen ? 260 * 1.3 : 120 * 1.3) : root.popAnimation ? (root.popupOpen ? 220 : 120) : Theme.popupDuration
            easing.type: root.niriAnimation ? Easing.BezierSpline : root.popAnimation ? (root.popupOpen ? Easing.OutBack : Easing.InQuad) : Easing.OutCubic
            easing.bezierCurve: root.popupOpen ? [0.22, 1.0, 0.36, 1.0, 1, 1] : [0.32, 0.0, 0.67, 0.0, 1, 1]
            easing.overshoot: 1.2
        }
    }

    // prism-glide: opening slides up 60 px-ish into place and scales from 0.985,
    // closing slides 40 px-ish down and scales to 0.988. Its shader shifts by
    // px / width in height units, hence the height / width factor.
    // pop: scales from 0.9 at the top edge (towards the module) and back to 0.95.
    readonly property real animShift: niriAnimation ? (1 - openness) * (popupOpen ? 60 : 40) * popupHeight / Math.max(popupWidth, 1) : 0
    readonly property real animScale: {
        if (niriAnimation)
            return popupOpen ? 0.985 + 0.015 * openness : 1 - 0.012 * (1 - openness);
        if (popAnimation)
            return popupOpen ? 0.9 + 0.1 * openness : 0.95 + 0.05 * openness;
        return 1;
    }
    readonly property bool scaleFromTop: popAnimation

    readonly property real popupContentWidth: popupLoader.item ? popupLoader.item.implicitWidth : 0
    readonly property real popupContentHeight: popupLoader.item ? popupLoader.item.implicitHeight : 0
    // Popups made of clickable rows set hasRows and inset their own text.
    readonly property bool popupHasRows: !!popupLoader.item && popupLoader.item.hasRows === true
    readonly property real popupPadH: Theme.popupPadding + (popupHasRows ? 0 : Theme.popupTextInset)
    readonly property real popupPadV: Theme.popupPaddingV + (popupHasRows ? 0 : Theme.popupTextInsetV)
    readonly property real popupWidth: popupContentWidth + 2 * popupPadH
    property real popupHeight: popupContentHeight + 2 * popupPadV
    Behavior on popupHeight {
        enabled: root.openness > 0.01
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }
    // "grow" reveals the popup gradually; "niri" shows it whole and fades it.
    readonly property real popupVisibleHeight: fadeAnimation ? (openness > 0.001 ? popupHeight : 0) : popupHeight * openness
    // Where the popup starts: right at the bar's bottom edge, or below a gap.
    readonly property real popupTop: barRect.y + barRect.height + (Theme.popupAttached ? 0 : Theme.popupGap)

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
        if (pinned)
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

    // Closes the popup and runs the command only once it is gone, see
    // DeferredAction.
    function runAction(command) {
        action.pending = command;
        popupOpen = false;
    }

    DeferredAction {
        id: action
        openness: root.openness
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

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: if (!root.popupHovered)
            root.popupOpen = false
    }

    // ---- background: bar + popup as one shape, with a shadow ----------------

    Item {
        id: shapes
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
        }

        Rectangle {
            id: popupBody

            readonly property real targetX: {
                const minX = Theme.popupFillet + 4;
                const maxX = barRect.width - root.popupWidth - Theme.popupFillet - 4;
                // Centered under its module, but on a whole device pixel: off
                // one, everything in the popup is drawn slightly soft.
                return Theme.snap(barRect.x + Math.max(minX, Math.min(maxX, root.ownerCenter - root.popupWidth / 2)), root.devicePixelRatio);
            }

            // Attached, it starts inside the bar so the join has no seam.
            readonly property real overlap: Theme.popupAttached ? Theme.popupFillet : 0
            readonly property real topRadius: Theme.popupAttached ? 0 : Math.min(Theme.popupRadius, root.popupVisibleHeight / 2)
            x: targetX
            y: root.popupTop - overlap
            width: root.popupWidth
            height: root.popupVisibleHeight + overlap
            visible: root.popupVisibleHeight > 0.5
            color: Theme.base
            topLeftRadius: topRadius
            topRightRadius: topRadius
            opacity: root.fadeAnimation ? root.openness : 1
            transform: [
                Scale {
                    origin.x: popupBody.width / 2
                    origin.y: root.scaleFromTop ? 0 : popupBody.height / 2
                    xScale: root.animScale
                    yScale: root.animScale
                },
                Translate { y: root.animShift }
            ]
            bottomLeftRadius: Math.min(Theme.popupRadius, root.popupVisibleHeight / 2)
            bottomRightRadius: Math.min(Theme.popupRadius, root.popupVisibleHeight / 2)

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

        // Concave corners joining the popup to the bar's bottom edge.
        Shape {
            id: leftFillet
            readonly property real r: Math.min(Theme.popupFillet, root.popupVisibleHeight)
            visible: popupBody.visible && Theme.popupAttached
            x: popupBody.x - r
            y: barRect.y + barRect.height
            width: r
            height: r
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: leftFillet.r; y: 0 }
                PathLine { x: leftFillet.r; y: leftFillet.r }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: leftFillet.r
                    radiusY: leftFillet.r
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            id: rightFillet
            readonly property real r: leftFillet.r
            visible: popupBody.visible && Theme.popupAttached
            x: popupBody.x + popupBody.width
            y: barRect.y + barRect.height
            width: r
            height: r
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: rightFillet.r; y: 0 }
                PathArc {
                    x: 0
                    y: rightFillet.r
                    radiusX: rightFillet.r
                    radiusY: rightFillet.r
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: 0 }
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

    // The gap between the bar and a detached popup: part of the popup for input,
    // so moving the pointer slowly across it doesn't close the popup.
    Item {
        id: popupGapArea
        x: popupBody.x
        y: barRect.y + barRect.height
        width: popupBody.visible && !Theme.popupAttached ? popupBody.width : 0
        height: Theme.popupAttached ? 0 : Theme.popupGap

        HoverHandler {
            id: gapHover
        }
    }

    Item {
        id: popupClip
        x: popupBody.x
        y: root.popupTop
        transform: [
            Scale {
                origin.x: popupClip.width / 2
                origin.y: root.scaleFromTop ? 0 : popupClip.height / 2
                xScale: root.animScale
                yScale: root.animScale
            },
            Translate { y: root.animShift }
        ]
        width: popupBody.width
        height: root.popupVisibleHeight
        clip: true
        visible: popupBody.visible

        Loader {
            id: popupLoader
            // The content's origin on a whole device pixel too.
            x: Theme.snap(popupClip.x + root.popupPadH, root.devicePixelRatio) - popupClip.x
            // Slides down with the popup instead of being revealed in place.
            y: Theme.snap(popupClip.y + root.popupPadV, root.devicePixelRatio) - popupClip.y - (root.popupHeight - root.popupVisibleHeight)
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

        HoverHandler {
            id: barHover
        }
    }
}
