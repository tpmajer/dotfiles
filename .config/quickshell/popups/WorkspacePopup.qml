import QtQuick
import Quickshell
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

    // [{ width, height, windows: as drawn, top to bottom; tabs: how many
    // there are, 0 for a column not in tabs }], left to right.
    readonly property var columns: {
        const byIndex = {};
        for (const w of own) {
            if (floating.includes(w))
                continue;
            const col = w.layout.pos_in_scrolling_layout[0];
            (byIndex[col] = byIndex[col] || []).push(w);
        }
        const stamp = w => w.focus_timestamp ? w.focus_timestamp.secs + w.focus_timestamp.nanos / 1e9 : 0;
        return Object.keys(byIndex).map(Number).sort((a, b) => a - b).map(col => {
            const windows = byIndex[col].sort((a, b) => a.layout.pos_in_scrolling_layout[1] - b.layout.pos_in_scrolling_layout[1]);
            const stacked = windows.reduce((sum, w) => sum + w.layout.tile_size[1], 0) + gap * (windows.length - 1);
            // In tabs each window has the column's whole height, so together
            // they would be taller than the screen: one tile, the tab shown
            // last.
            const tabbed = windows.length > 1 && stacked > screenHeight;
            const shown = !tabbed ? windows : [windows.find(w => w.id === ws.active_window_id) ?? windows.slice().sort((a, b) => stamp(b) - stamp(a))[0]];
            return {
                width: Math.max(...windows.map(w => w.layout.tile_size[0])),
                height: tabbed ? shown[0].layout.tile_size[1] : stacked,
                windows: shown,
                tabs: tabbed ? windows.length : 0
            };
        });
    }

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

    // The popup's size, from the layout.
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

    Column {
        spacing: popup.spacing

        PopupText {
            id: empty
            visible: popup.own.length === 0
            text: "Empty"
            color: Theme.subtext0
        }

        Row {
            visible: popup.columns.length > 0
            spacing: popup.scaledGap

            // A delegate on its way out may still see an index past the end.
            Repeater {
                model: popup.columns

                Column {
                    id: column
                    required property var modelData
                    readonly property var col: modelData
                    spacing: popup.scaledGap

                    Repeater {
                        model: column.col?.windows ?? []

                        Tile {
                            required property var modelData
                            win: modelData
                            tabs: column.col?.tabs ?? 0
                            width: column.col ? popup.tileWidth(column.col) : 0
                            height: win ? popup.tileHeight(win) : 0
                        }
                    }
                }
            }
        }

        Flow {
            visible: popup.floating.length > 0
            width: popup.floatingWidth
            spacing: popup.floatingSpacing

            Repeater {
                model: popup.floating

                Tile {
                    required property var modelData
                    win: modelData
                    width: popup.floatingSize
                    height: popup.floatingSize
                }
            }
        }
    }

    component Tile: Rectangle {
        id: tile
        property var win
        // How many tabs the column has; 0 for none.
        property int tabs: 0

        radius: Theme.moduleRadius
        color: mouse.containsMouse ? Theme.surface1 : Theme.surface0
        Behavior on color {
            ColorAnimation { duration: Theme.hoverDuration }
        }
        border.width: win && (win.is_urgent || win.id === popup.ws?.active_window_id) ? 2 : 0
        border.color: win?.is_urgent ? Theme.red : Theme.blue

        IconImage {
            anchors.centerIn: parent
            implicitSize: Math.max(0, Math.min(32, tile.width - 8, tile.height - 8))
            source: tile.win ? Apps.icon(tile.win.app_id, "application-x-executable") : ""
        }

        PopupText {
            visible: tile.tabs > 0
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            text: tile.tabs
            color: Theme.subtext0
            font.pixelSize: Theme.fontSize - 4
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!tile.win)
                    return;
                Niri.focusWindow(tile.win.id);
                popup.launched();
            }
        }
    }
}
