pragma Singleton

import QtQuick
import Quickshell
import qs

// The power menus' actions: the bar's popup and the centered menu show the same.
Singleton {
    readonly property var actions: [
        {icon: 0xf033e, text: "Lock", command: "qs ipc call lock lock"},
        {icon: 0xf0343, text: "Logout", command: "niri msg action quit -s"},
        {icon: 0xf0425, text: "Shutdown", command: "systemctl poweroff", color: Theme.red},
        {icon: 0xf0904, text: "Suspend", command: "systemctl suspend"},
        {icon: 0xf0709, text: "Reboot", command: "systemctl reboot", color: Theme.peach}
    ]

    function run(command) {
        Quickshell.execDetached(["sh", "-c", command]);
    }
}
