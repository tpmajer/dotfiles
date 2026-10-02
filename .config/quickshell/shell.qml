//@ pragma IconTheme Papirus
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING = gray

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    Variants {
        id: bars
        model: Quickshell.screens

        Bar {}
    }

    Osd {}
    Toasts {}
    Lock {}

    PowerMenu {
        id: powerMenu
    }

    // `qs ipc call power toggle` (Super+Esc in niri): the power menu in the
    // middle of the focused output. `toggleBar`: the small one on that output's
    // bar, driven from the keyboard.
    IpcHandler {
        target: "power"

        function toggle(): void {
            powerMenu.toggle();
        }

        function toggleBar(): void {
            const bar = bars.instances.find(b => b.screen.name === Niri.focusedOutput) ?? bars.instances[0];
            if (bar)
                bar.togglePowerMenu();
        }
    }
}
