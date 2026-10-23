import QtQuick
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

// A workspace's windows as a map: its columns side by side, each window in
// proportion and with its application's icon; the floating ones in a row
// below, as niri does not tell where they are. A click focuses the window.
Item {
    id: popup

    required property var ws
    // The screen's logical height, which the map's height stands for.
    required property real screenHeight
    // The widest the map may be: PopupHost's maxContentWidth.
    required property real maxWidth

    signal launched
    // A window is being dragged out, to a workspace in the bar.
    readonly property bool dragging: draggedId >= 0
    property int draggedId: -1

    // Its first tiles are there whole; those that come later pop in.
    property bool ready: false
    Component.onCompleted: Qt.callLater(() => ready = true)

    // niri's gaps, and the map's height; lower only for a strip that would
    // not fit across otherwise.
    readonly property real gap: 12
    readonly property real mapHeight: 160
    readonly property real spacing: 8
    // The floating windows' row.
    readonly property real floatingSize: 30
    readonly property real floatingSpacing: 6

    // Not one whose layout is stale, as it closes.
    readonly property var own: !ws ? [] : Object.values(Niri.windows).filter(w => w.workspace_id === ws.id && !w.stale)
    // With no place in the columns, a window goes with the floating ones.
    readonly property var floating: own.filter(w => w.is_floating || !w.layout?.pos_in_scrolling_layout)

    // [{ key: the column's, see below; all: its windows, top to bottom;
    // width, height, windows: as drawn; keys: theirs, the window's id, or
    // the column's in tabs; tabs: how many there are, 0 for a column not in
    // tabs }], left to right.
    readonly property var columns: {
        const byIndex = {};
        for (const w of own) {
            if (floating.includes(w))
                continue;
            const col = w.layout.pos_in_scrolling_layout[0];
            (byIndex[col] = byIndex[col] || []).push(w);
        }
        const stamp = w => w.focus_timestamp ? w.focus_timestamp.secs + w.focus_timestamp.nanos / 1e9 : 0;
        const built = Object.keys(byIndex).map(Number).sort((a, b) => a - b).map(col => {
            const windows = byIndex[col].sort((a, b) => a.layout.pos_in_scrolling_layout[1] - b.layout.pos_in_scrolling_layout[1]);
            const stacked = windows.reduce((sum, w) => sum + w.layout.tile_size[1], 0) + gap * (windows.length - 1);
            // In tabs each window has the column's whole height, so together
            // they would be taller than the screen: one tile, the tab shown
            // last.
            const tabbed = windows.length > 1 && stacked > screenHeight;
            const shown = !tabbed ? windows : [windows.find(w => w.id === ws.active_window_id) ?? windows.slice().sort((a, b) => stamp(b) - stamp(a))[0]];
            return {
                all: windows,
                width: Math.max(...windows.map(w => w.layout.tile_size[0])),
                height: tabbed ? shown[0].layout.tile_size[1] : stacked,
                windows: shown,
                tabs: tabbed ? windows.length : 0
            };
        });
        // A column keeps its key while windows of it are in it, so that it
        // stays when its top one goes: it takes the key most of its windows
        // had, those still in their rows first, and one with none a new key.
        const before = keyState.of;
        const claims = [];
        built.forEach((c, i) => {
            const weight = {};
            for (const w of c.all) {
                const was = before[w.id];
                if (was)
                    weight[was.key] = (weight[was.key] ?? 0) + (was.row === w.layout.pos_in_scrolling_layout[1] ? 1.5 : 1);
            }
            for (const key in weight)
                claims.push({column: i, key: Number(key), weight: weight[key]});
        });
        claims.sort((a, b) => b.weight - a.weight || a.column - b.column);
        const keys = [];
        const taken = new Set();
        for (const claim of claims)
            if (keys[claim.column] === undefined && !taken.has(claim.key)) {
                keys[claim.column] = claim.key;
                taken.add(claim.key);
            }
        const of = {};
        built.forEach((c, i) => {
            c.key = keys[i] ?? keyState.next--;
            c.keys = c.tabs > 0 ? [c.key] : c.windows.map(w => w.id);
            for (const w of c.all)
                of[w.id] = {key: c.key, row: w.layout.pos_in_scrolling_layout[1]};
        });
        keyState.of = of;
        return built;
    }
    // The keys the columns last had, by window, and the next new one; kept
    // out of the bindings.
    readonly property var keyState: ({
            of: {},
            next: -1
        })


    readonly property real stripWidth: columns.reduce((sum, c) => sum + c.width, 0)
    readonly property real stripHeight: Math.max(screenHeight, ...columns.map(c => c.height))
    // The gaps drawn no thinner than 2 px, and left out of the scaling so
    // that the map stays within maxWidth: at most as wide as at the scale
    // the height gives.
    readonly property real gapCount: Math.max(0, columns.length - 1)
    readonly property real heightScale: mapHeight / stripHeight
    readonly property real mapScale: stripWidth > 0 ? Math.min(heightScale, Math.max(0, maxWidth - gapCount * Math.max(2, gap * heightScale)) / stripWidth) : 0
    readonly property real scaledGap: Math.max(2, gap * mapScale)

    function tileWidth(c) {
        return Math.floor(c.width * mapScale);
    }
    function tileHeight(w) {
        return Math.floor(w.layout.tile_size[1] * mapScale);
    }

    // The size the popup ends up at, from the layout rather than from the
    // tiles: as they animate, the popup would chase them, a step behind.
    readonly property real mapWidth: columns.reduce((sum, c) => sum + tileWidth(c), 0) + scaledGap * gapCount
    readonly property real mapContentHeight: Math.max(0, ...columns.map(c => c.windows.reduce((sum, w) => sum + tileHeight(w), 0) + scaledGap * (c.windows.length - 1)))
    // The floating windows' row, wrapped where it would be wider than
    // maxWidth.
    readonly property int floatingPerRow: Math.max(1, Math.floor((maxWidth + floatingSpacing) / (floatingSize + floatingSpacing)))
    readonly property int floatingRows: Math.ceil(floating.length / floatingPerRow)
    readonly property real floatingWidth: Math.min(floating.length, floatingPerRow) * (floatingSize + floatingSpacing) - floatingSpacing
    readonly property real floatingHeight: floatingRows * (floatingSize + floatingSpacing) - floatingSpacing
    readonly property var parts: [
        own.length === 0 ? [empty.implicitWidth, empty.implicitHeight] : null,
        columns.length > 0 ? [mapWidth, mapContentHeight] : null,
        floating.length > 0 ? [floatingWidth, floatingHeight] : null
    ].filter(part => part)
    implicitWidth: Math.max(0, ...parts.map(part => part[0]))
    implicitHeight: parts.reduce((sum, part) => sum + part[1], 0) + spacing * Math.max(0, parts.length - 1)

    // How what comes and goes moves: its place opens or closes as the popup
    // itself resizes, and it pops in or out (Pop) where it is to be or was,
    // under the rest as they close up over it.
    readonly property int moveDuration: Theme.popupDuration

    Column {
        spacing: popup.spacing

        Row {
            visible: columnSlots.count > 0

            // By keys, not by the arrays: a new array would make every tile
            // anew, and their sizes could not animate; a column or window
            // that comes or goes does so where it is.
            Repeater {
                model: Keyed {
                    id: columnSlots
                    keys: popup.columns.map(c => c.key)
                }

                // A column's place, the gap before it included, so that the
                // gap opens and closes with it.
                Item {
                    id: slot
                    required property int key
                    required property int index
                    required property bool leaving
                    // What it last was, for while it goes.
                    readonly property var col: popup.columns.find(c => c.key === key)
                    property var shown: col
                    onColChanged: if (col)
                        shown = col

                    // Not after one that goes, which has no place.
                    readonly property real gapBefore: popup.columns.findIndex(c => c.key === key) > 0 ? popup.scaledGap : 0
                    property real shownGap: gapBefore
                    Behavior on shownGap {
                        enabled: popup.ready
                        Move {}
                    }
                    readonly property real columnWidth: shown ? popup.tileWidth(shown) : 0
                    readonly property real targetWidth: columnWidth + gapBefore

                    // The first ones are there whole; those that come later
                    // pop in.
                    property bool appeared: !popup.ready
                    // Over the others while its place opens, under them as
                    // they close up over it.
                    property bool entering: false
                    Component.onCompleted: {
                        entering = popup.ready;
                        appeared = true;
                    }
                    onWidthChanged: if (entering && width >= targetWidth)
                        entering = false

                    width: appeared && !leaving ? targetWidth : 0
                    height: stack.height
                    z: leaving ? -1 : entering ? 1 : 0
                    Behavior on width {
                        enabled: popup.ready
                        Move {}
                    }

                    // Where it was, in the row, for while it goes.
                    property real leftAt: 0
                    onLeavingChanged: if (leaving) {
                        leftAt = x + shownGap;
                        gone.start();
                    }
                    Timer {
                        id: gone
                        interval: popup.moveDuration
                        onTriggered: columnSlots.remove(slot.index)
                    }

                    Pop {
                        id: pop
                        shown: slot.appeared && !slot.leaving
                    }

                    Column {
                        id: stack
                        x: slot.leaving ? slot.leftAt - slot.x : slot.shownGap
                        width: slot.columnWidth
                        opacity: pop.openness
                        scale: pop.scale

                        Repeater {
                            model: Keyed {
                                id: windowSlots
                                keys: slot.shown?.keys ?? []
                            }

                            Tile {
                                required property int index
                                win: slot.col?.windows[slot.col.keys.indexOf(key)]
                                tabs: slot.shown?.tabs ?? 0
                                targetWidth: slot.columnWidth
                                targetHeight: shownWin ? popup.tileHeight(shownWin) : 0
                                // Not after one that goes, which has no place.
                                gapBefore: (slot.shown?.keys.indexOf(key) ?? 0) > 0 ? popup.scaledGap : 0
                                finalTop: {
                                    const c = slot.col;
                                    const k = c ? c.keys.indexOf(key) : -1;
                                    let top = 0;
                                    for (let i = 0; i < k; i++)
                                        top += popup.tileHeight(c.windows[i]) + popup.scaledGap;
                                    return top;
                                }
                                // Comes and goes with its column, or else in it, by its
                                // height.
                                stacked: (slot.shown?.windows.length ?? 1) > 1 || leaving
                                onGone: windowSlots.remove(index)
                            }
                        }
                    }
                }
            }
        }

        // Wide enough for those that go too, which would wrap otherwise.
        Flow {
            visible: floatingSlots.count > 0
            width: Math.min(floatingSlots.count, popup.floatingPerRow) * (popup.floatingSize + popup.floatingSpacing) - popup.floatingSpacing
            spacing: popup.floatingSpacing

            Repeater {
                model: Keyed {
                    id: floatingSlots
                    keys: popup.floating.map(w => w.id)
                }

                Tile {
                    required property int index
                    win: popup.floating.find(w => w.id === key)
                    targetWidth: popup.floatingSize
                    targetHeight: popup.floatingSize
                    stacked: true
                    onGone: floatingSlots.remove(index)
                }
            }
        }
    }

    // Over the last column, as it pops out.
    PopupText {
        id: empty
        text: "Empty"
        color: Theme.subtext0
        opacity: emptyPop.openness
        scale: emptyPop.scale

        Pop {
            id: emptyPop
            shown: popup.own.length === 0
        }
    }

    // How a place opens, closes or resizes.
    component Move: NumberAnimation {
        duration: popup.moveDuration
        easing.type: Easing.OutCubic
    }

    // An element for each key, in their order: those whose keys go are
    // marked leaving, for their delegates to remove when they have gone;
    // new ones are inserted where they are and the rest moved, so that the
    // delegates of the others stay.
    component Keyed: ListModel {
        property var keys: []
        function fit() {
            for (let i = 0; i < count; i++)
                if (!get(i).leaving && !keys.includes(get(i).key))
                    setProperty(i, "leaving", true);
            let i = 0;
            for (const key of keys) {
                while (i < count && get(i).leaving)
                    i++;
                if (i < count && get(i).key === key) {
                    i++;
                    continue;
                }
                let from = -1;
                for (let j = i + 1; j < count && from < 0; j++)
                    if (!get(j).leaving && get(j).key === key)
                        from = j;
                if (from >= 0)
                    move(from, i, 1);
                else
                    insert(i, {key: key, leaving: false});
                i++;
            }
        }
        onKeysChanged: fit()
        Component.onCompleted: fit()
    }

    // A window's tile, with the gap before it. In a column of one, it comes
    // and goes with the column; stacked, it does by its own height, as the
    // column does by its width.
    component Tile: Item {
        id: tile
        required property int key
        required property bool leaving
        property var win
        // What it last showed, for while it goes.
        property var shownWin: win
        onWinChanged: if (win)
            shownWin = win
        // How many tabs the column has; 0 for none.
        property int tabs: 0
        property real targetWidth
        property real targetHeight
        property real gapBefore: 0
        property real shownGap: gapBefore
        Behavior on shownGap {
            enabled: popup.ready
            Move {}
        }
        property bool stacked: false
        readonly property bool going: leaving && stacked

        signal gone

        property bool appeared: !popup.ready
        // Whole as its place opens, and where it ends up, not where its
        // place is while the others move.
        property bool entering: false
        property real finalTop: y + gapBefore
        Component.onCompleted: {
            entering = popup.ready && stacked;
            appeared = true;
        }
        onHeightChanged: if (entering && height >= gapBefore + targetHeight)
            entering = false

        // In a row, it closes up too.
        width: going ? 0 : targetWidth
        height: (appeared || !stacked) && !going ? gapBefore + targetHeight : 0
        z: going ? -1 : entering ? 1 : 0
        Behavior on height {
            enabled: popup.ready
            Move {}
        }
        Behavior on width {
            enabled: popup.ready
            Move {}
        }

        // Where it was, in the column, for while it goes.
        property real topAt: 0
        onGoingChanged: if (going) {
            topAt = y + shownGap;
            closed.start();
        }
        Timer {
            id: closed
            interval: popup.moveDuration
            onTriggered: tile.gone()
        }

        // A tile gone in the middle of its drag, as its window closed or
        // the columns changed, ends it.
        Component.onDestruction: if (dragged.windowId >= 0 && popup.draggedId === dragged.windowId)
            popup.draggedId = -1

        Pop {
            id: pop
            shown: (tile.appeared || !tile.stacked) && !tile.going
        }

        Rectangle {
            id: card
            y: tile.going ? tile.topAt - tile.y : tile.entering ? tile.finalTop - tile.y : tile.shownGap
            width: tile.going ? tile.targetWidth : tile.width
            height: tile.entering || tile.going ? tile.targetHeight : tile.height - tile.shownGap
            radius: Theme.moduleRadius
            opacity: pop.openness * (popup.draggedId >= 0 && popup.draggedId === tile.shownWin?.id ? 0.4 : 1)
            scale: pop.scale
            color: mouse.containsMouse ? Theme.surface1 : Theme.surface0
            Behavior on color {
                ColorAnimation { duration: Theme.hoverDuration }
            }
            border.width: tile.shownWin && (tile.shownWin.is_urgent || tile.shownWin.id === popup.ws?.active_window_id) ? 2 : 0
            border.color: tile.shownWin?.is_urgent ? Theme.red : Theme.teal

            // The icon, and under it the title's start, where there is room.
            Column {
                anchors.centerIn: parent
                spacing: 2

                IconImage {
                    id: icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: Math.max(0, Math.min(32, card.width - 8, card.height - 8))
                    source: tile.shownWin ? Apps.icon(tile.shownWin.app_id, "application-x-executable") : ""
                }

                PopupText {
                    id: title
                    readonly property real room: card.width - 16 - 2 * (tabCount.visible ? tabCount.width + 4 : 0)
                    visible: text !== "" && room >= 24 && card.height - 16 >= icon.height + parent.spacing + implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, room)
                    text: tile.shownWin?.title ?? ""
                    elide: Text.ElideRight
                    color: Theme.subtext0
                    font.pixelSize: Theme.fontSize - 4
                }
            }

            PopupText {
                id: tabCount
                visible: tile.tabs > 0
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                text: tile.tabs
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 4
            }
        }

        // What is dragged, unseen: the window's id, to a DropArea in the
        // bar. It starts under the pointer, and the id is the one pressed
        // on, whatever the tile shows by the time it is dropped.
        Item {
            id: dragged
            property int windowId: -1
            Drag.active: mouse.drag.active
            Drag.keys: ["niri-window"]
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: !tile.leaving
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            drag.target: dragged
            onPressed: mouse => {
                dragged.x = mouse.x;
                dragged.y = mouse.y;
                dragged.windowId = tile.shownWin?.id ?? -1;
            }
            drag.onActiveChanged: {
                popup.draggedId = drag.active ? dragged.windowId : -1;
                if (!drag.active)
                    dragged.windowId = -1;
            }
            onReleased: if (drag.active)
                dragged.Drag.drop()
            onClicked: {
                if (!tile.shownWin)
                    return;
                Niri.focusWindow(tile.shownWin.id);
                popup.launched();
            }
        }
    }
}
