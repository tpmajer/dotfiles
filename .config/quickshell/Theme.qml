pragma Singleton

import QtQuick
import Quickshell

// Catppuccin Mocha colors and the bar geometry.
Singleton {
    readonly property color base: "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color text: "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color white: "#ffffff"
    readonly property color pink: "#ea76cb"

    readonly property color blue: "#89b4fa"
    readonly property color sky: "#89dceb"
    readonly property color sapphire: "#74c7ec"
    readonly property color teal: "#94e2d5"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"
    readonly property color peach: "#fab387"
    readonly property color red: "#f38ba8"
    readonly property color maroon: "#e64553"
    readonly property color lavender: "#8caaee"
    readonly property color mauve: "#cba6f7"

    readonly property string font: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 17

    readonly property int barHeight: 48
    readonly property int barMargin: 10
    readonly property int barRadius: 6
    readonly property int moduleRadius: 4
    readonly property int hoverDuration: 200

    // Popups ("dymki") growing out of the bar.
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
    readonly property int popupFillet: barRadius  // same as the bar corners
    // false: popups float below the bar with a gap and all corners rounded.
    readonly property bool popupAttached: false
    readonly property int popupGap: 8
    readonly property int popupDuration: 180
    // "grow": the popup grows down out of the bar. "niri": like niri's window
    // open/close in animations/prism-glide.kdl (fade, slight slide and scale).
    // "pop": a popover scaling up from its module with a slight overshoot.
    readonly property string popupAnimation: "pop"

    function glyph(codepoint) {
        return String.fromCodePoint(codepoint);
    }
}
