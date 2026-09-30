//@ pragma IconTheme Papirus

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        id: bars
        model: Quickshell.screens

        Bar {}
    }

    // `qs ipc call power toggle` (Super+Esc in niri): the power menu on the
    // focused output's bar, driven from the keyboard.
    IpcHandler {
        target: "power"

        function toggle(): void {
            const bar = bars.instances.find(b => b.screen.name === Niri.focusedOutput) ?? bars.instances[0];
            if (bar)
                bar.togglePowerMenu();
        }
    }
}
