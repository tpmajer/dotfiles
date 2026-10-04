pragma Singleton

import QtQuick
import Quickshell
import qs

// The power menu's actions.
Singleton {
    readonly property var actions: [
        {icon: 0xf033e, text: "Lock", command: "qs ipc call lock lock"},
        {icon: 0xf0343, text: "Logout", command: "niri msg action quit -s"},
        {icon: 0xf0425, text: "Shutdown", command: "systemctl poweroff", color: Theme.red},
        {icon: 0xf0904, text: "Suspend", command: "systemctl suspend"},
        {icon: 0xf0709, text: "Reboot", command: "systemctl reboot", color: Theme.peach}
    ]
    // The action a menu opens on.
    readonly property int defaultIndex: actions.findIndex(a => a.text === "Shutdown")

    function run(command) {
        Quickshell.execDetached(["sh", "-c", command]);
    }
}
