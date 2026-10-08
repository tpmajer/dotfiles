pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The colors, under Catppuccin's names, and the bar geometry.
Singleton {
    // The palettes to choose from. Past Catppuccin Mocha, a palette's
    // nearest colors stand in for Catppuccin's.
    readonly property var palettes: ({
            "catppuccin": {
                label: "Catppuccin",
                base: "#1e1e2e",
                surface0: "#313244",
                surface1: "#45475a",
                text: "#cdd6f4",
                subtext1: "#bac2de",
                subtext0: "#a6adc8",
                white: "#ffffff",
                pink: "#f5c2e7",
                blue: "#89b4fa",
                sky: "#89dceb",
                sapphire: "#74c7ec",
                teal: "#94e2d5",
                green: "#a6e3a1",
                yellow: "#f9e2af",
                peach: "#fab387",
                red: "#f38ba8",
                maroon: "#eba0ac",
                lavender: "#b4befe",
                mauve: "#cba6f7"
            },
            "night": {
                label: "Tokyo Night",
                base: "#1a1b26",
                surface0: "#292e42",
                surface1: "#414868",
                text: "#c0caf5",
                subtext1: "#a9b1d6",
                subtext0: "#9aa5ce",
                white: "#ffffff",
                pink: "#ff007c",
                blue: "#7aa2f7",
                sky: "#7dcfff",
                sapphire: "#2ac3de",
                teal: "#73daca",
                green: "#9ece6a",
                yellow: "#e0af68",
                peach: "#ff9e64",
                red: "#f7768e",
                maroon: "#db4b4b",
                lavender: "#bb9af7",
                mauve: "#9d7cd8"
            },
            "storm": {
                label: "Tokyo Night Storm",
                base: "#24283b",
                surface0: "#3b4261",
                surface1: "#545c7e",
                text: "#c0caf5",
                subtext1: "#a9b1d6",
                subtext0: "#9aa5ce",
                white: "#ffffff",
                pink: "#ff007c",
                blue: "#7aa2f7",
                sky: "#7dcfff",
                sapphire: "#2ac3de",
                teal: "#73daca",
                green: "#9ece6a",
                yellow: "#e0af68",
                peach: "#ff9e64",
                red: "#f7768e",
                maroon: "#db4b4b",
                lavender: "#bb9af7",
                mauve: "#9d7cd8"
            }
        })

    // The one in use, kept across restarts. `qs ipc call theme set night`,
    // `qs ipc call theme next`.
    property string palette: "catppuccin"
    readonly property var colors: palettes[palette] ?? palettes.catppuccin
    FileView {
        id: store
        path: Quickshell.statePath("palette")
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        const kept = store.text().trim();
        if (kept in palettes)
            palette = kept;
    }

    function setPalette(name) {
        if (!(name in palettes) || name === palette)
            return;
        palette = name;
        store.setText(name);
    }

    function nextPalette() {
        const names = Object.keys(palettes);
        setPalette(names[(names.indexOf(palette) + 1) % names.length]);
    }

    readonly property color base: colors.base
    readonly property color surface0: colors.surface0
    readonly property color surface1: colors.surface1
    readonly property color text: colors.text
    readonly property color subtext1: colors.subtext1
    readonly property color subtext0: colors.subtext0
    readonly property color white: colors.white
    readonly property color pink: colors.pink

    readonly property color blue: colors.blue
    readonly property color sky: colors.sky
    readonly property color sapphire: colors.sapphire
    readonly property color teal: colors.teal
    readonly property color green: colors.green
    readonly property color yellow: colors.yellow
    readonly property color peach: colors.peach
    readonly property color red: colors.red
    readonly property color maroon: colors.maroon
    readonly property color lavender: colors.lavender
    readonly property color mauve: colors.mauve

    readonly property string font: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 17
    // Icons a cell wide, for text laid out in columns.
    readonly property string monoFont: "JetBrainsMono Nerd Font"

    readonly property int barHeight: 48
    readonly property int barMargin: 10
    readonly property int barRadius: 6
    readonly property int moduleRadius: 4
    readonly property int hoverDuration: 50

    // Popups ("dymki") below the bar.
    // Padding around clickable rows: sides, and top/bottom. Plain text gets the
    // inset on top, so it sits where the text inside a row does.
    readonly property int popupPadding: 14
    readonly property int popupPaddingV: 10
    readonly property int popupTextInset: 12
    readonly property int popupTextInsetV: 4
    // Between an icon and its label (about a space, as in the bar), and
    // between text columns.
    readonly property int popupIconGap: 8
    readonly property int popupColumnGap: 12
    // In a grid of text: between its columns, and between its rows, which is
    // also what lines of text are apart. Between the parts of a popup.
    readonly property int popupGridGap: 16
    readonly property int popupRowGap: 4
    readonly property int popupSectionGap: 8
    readonly property int popupRadius: barRadius
    // Popups float below the bar, with this gap.
    readonly property int popupGap: 8
    // A popup changing its size or moving to another module, in ms.
    readonly property int popupDuration: 180

    // On-screen display for volume and brightness: distance from the bottom
    // edge of the screen, and how long it stays.
    readonly property int osdBottom: 90
    readonly property int osdTimeout: 1500

    // Notifications: the corner they stack in ("bottom-right", "bottom-left",
    // "top-right", "top-left"), the card width and the gap between cards.
    readonly property string notificationsPosition: "bottom-right"
    readonly property int notificationWidth: 380
    readonly property int notificationGap: 8
    // Distance from the screen's side and bottom edges (top corners keep the
    // popup gap below the bar).
    readonly property int notificationMargin: 24
    readonly property int notificationSlide: 250   // ms, cards sliding in and closing ranks
    // More than this many are folded into a "+N more" row; a click unfolds them.
    readonly property int notificationsVisible: 5
    // The notification center in the bar lists this much, and scrolls the rest.
    readonly property int centerMaxHeight: 560
    // No more notifications than this are kept, on screen and in the center
    // together: past it the oldest are closed.
    readonly property int notificationsKept: 100

    // Thin colored lines: a module's underline, a notification's urgency.
    // 2.5 px is 4 whole device pixels at scale 1.6.
    readonly property real lineWidth: 2.5

    // Level bars (the OSD, CPU cores): 5 px is 8 whole device pixels at 1.6.
    readonly property real levelHeight: 5

    // The nearest position, in a window's coordinates, that falls on a whole
    // device pixel. A line both placed and sized in whole device pixels has
    // hard edges; otherwise its edges are smoothed over two.
    function snap(position, devicePixelRatio) {
        return Math.round(position * devicePixelRatio) / devicePixelRatio;
    }

    function glyph(codepoint) {
        return String.fromCodePoint(codepoint);
    }

    // The glyphs that stand for the icon theme's general icons, by name:
    // a kind of device, a state. Headphones match the volume module.
    readonly property var iconGlyphs: ({
            "audio-headphones": 0xf025,
            "audio-headset": 0xf02ce,
            "audio-card": 0xf04c3,
            "input-mouse": 0xf037d,
            "input-keyboard": 0xf030c,
            "input-gaming": 0xf0297,
            "phone": 0xf011c,
            "computer": 0xf0322,
            "bluetooth": 0xf00af,
            "battery": 0xf0079,
            "network-wireless": 0xf0928,
            "network-wired": 0xf0002,
            "dialog-information": 0xf02fc,
            "dialog-warning": 0xf0026,
            "dialog-error": 0xf0028
        })
    // The glyph for such a name, "input-mouse" or "battery-low-symbolic",
    // by the longest of the names above it starts with; "" if it has none.
    function iconGlyph(name) {
        const key = Object.keys(iconGlyphs).filter(k => name === k || name.startsWith(k + "-")).sort((a, b) => b.length - a.length)[0];
        return key ? glyph(iconGlyphs[key]) : "";
    }
}
