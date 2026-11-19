import QtQuick
import Quickshell
import Quickshell.Io

// USBGuard (usbguard.nix in ~/.nixos) blocks the devices new to it while the
// session is locked and lets any in otherwise. One blocked meanwhile stays so
// until it is plugged in again: a notification after the unlock names it.
Scope {
    id: root

    required property bool locked
    // Whether the session is locked is known: a start finds that out after
    // a moment, and would let devices in under a lock meanwhile.
    required property bool settled

    readonly property string target: locked ? "block" : "allow"
    // What USBGuard was last told, "" before that.
    property string applied: ""

    function apply() {
        if (!settled || setter.running || applied === target)
            return;
        setter.sent = target;
        setter.exec(["usbguard", "set-parameter", "ImplicitPolicyTarget", target]);
    }

    onTargetChanged: apply()
    onSettledChanged: apply()

    Process {
        id: setter

        property string sent

        stderr: StdioCollector {
            id: setterError
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                if (root.applied === "block" && setter.sent === "allow")
                    blocked.running = true;
                root.applied = setter.sent;
            } else {
                console.warn(`USBGuard refused ${setter.sent}: ${setterError.text.trim()}`);
            }
            if (root.target !== setter.sent)
                root.apply();
        }
    }

    Process {
        id: blocked

        command: ["usbguard", "list-devices", "--blocked"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").map(line => line.match(/ name "([^"]*)"/)).filter(m => m).map(m => m[1] || "Unnamed device");
                if (names.length)
                    Quickshell.execDetached([Quickshell.shellDir + "/scripts/notify-replace.sh", "usbguard", "-a", "USBGuard", "Blocked while locked", names.join("\n") + "\nPlug in again to use."]);
            }
        }
    }
}
