//@ pragma IconTheme Papirus
// Polish, render and commit in one thread, so a new blur region always goes out
// before the commit that carries it. With the threaded loop it often arrived
// right after a commit still waiting on its GPU fence; niri then applied the
// flag with that older commit and kept blurring a closed popup for ~200 ms.
//@ pragma Env QSG_RENDER_LOOP=basic

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
