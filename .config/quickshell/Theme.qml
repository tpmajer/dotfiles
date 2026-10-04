pragma Singleton

import QtQuick
import Quickshell

// Catppuccin colors and the bar geometry.
Singleton {
    readonly property color base: "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color text: "#cdd6f4"
    readonly property color subtext1: "#bac2de"
    readonly property color subtext0: "#a6adc8"
    readonly property color white: "#ffffff"
    readonly property color pink: "#f5c2e7"

    readonly property color blue: "#89b4fa"
    readonly property color sky: "#89dceb"
    readonly property color sapphire: "#74c7ec"
    readonly property color teal: "#94e2d5"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"
    readonly property color peach: "#fab387"
    readonly property color red: "#f38ba8"
    readonly property color maroon: "#eba0ac"
    readonly property color lavender: "#b4befe"
    readonly property color mauve: "#cba6f7"

    readonly property string font: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 17

    readonly property int barHeight: 48
    readonly property int barMargin: 10
    readonly property int barRadius: 6
    readonly property int moduleRadius: 4
    readonly property int hoverDuration: 200

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
}
