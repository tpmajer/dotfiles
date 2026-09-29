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
    readonly property int popupPadding: 14
    readonly property int popupRadius: barRadius
    readonly property int popupFillet: barRadius  // same as the bar corners
    readonly property int popupDuration: 180

    function glyph(codepoint) {
        return String.fromCodePoint(codepoint);
    }
}
