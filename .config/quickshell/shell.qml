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

        Bar {
            onPowerMenuRequested: powerMenu.toggle()
        }
    }

    Osd {}
    Toasts {
        locked: lock.locked
    }

    Lock {
        id: lock
    }

    PowerMenu {
        id: powerMenu
        locked: lock.locked
    }

    // The bar on the focused output.
    function focusedBar() {
        return bars.instances.find(b => b.screen.name === Niri.focusedOutput) ?? bars.instances[0];
    }

    // `qs ipc call power toggle` (Super+Esc in niri): the power menu in the
    // middle of the focused output.
    IpcHandler {
        target: "power"

        function toggle(): void {
            powerMenu.toggle();
        }
    }

    // `qs ipc call notifications toggle`: the notification center on the
    // focused output's bar, driven from the keyboard. `toggleDnd`: do not
    // disturb. `dismissToasts`: the toasts go to the center. `clear`: what
    // waits in the center is closed.
    IpcHandler {
        target: "notifications"

        function toggle(): void {
            const bar = focusedBar();
            if (bar)
                bar.toggleNotifications();
        }

        function toggleDnd(): void {
            Notifications.toggleDnd();
        }

        function dismissToasts(): void {
            Notifications.hideAll();
        }

        function clear(): void {
            Notifications.clear();
        }
    }
}
