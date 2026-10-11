pragma Singleton

import QtQuick
import Quickshell
import qs

// The power menu's actions.
Singleton {
    readonly property var actions: [
        {icon: 0xf023, text: "Lock", command: "qs ipc call lock lock"},
        {icon: 0xf2f5, text: "Logout", command: "niri msg action quit -s"},
        {icon: 0xf011, text: "Shutdown", command: "systemctl poweroff", color: Theme.red},
        {icon: 0x100002, text: "Suspend", command: "systemctl suspend"},
        {icon: 0xf2f9, text: "Reboot", command: "systemctl reboot", color: Theme.peach}
    ]
    // The action a menu opens on.
    readonly property int defaultIndex: actions.findIndex(a => a.text === "Shutdown")

    function run(command) {
        Quickshell.execDetached(["sh", "-c", command]);
    }
}
