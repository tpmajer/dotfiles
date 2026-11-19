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
    // It refused the last time: told once, until it takes one again.
    property bool failing: false

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
                root.failing = false;
            } else {
                console.warn(`USBGuard refused ${setter.sent}: ${setterError.text.trim()}`);
                if (!root.failing) {
                    root.failing = true;
                    const blocking = setter.sent === "block";
                    Quickshell.execDetached([Quickshell.shellDir + "/scripts/notify-replace.sh", "usbguard-error", "-a", "USBGuard", "-u", blocking ? "critical" : "normal", blocking ? "USB devices not blocked under the lock" : "New USB devices stay blocked", setterError.text.trim()]);
                }
            }
            if (root.target !== setter.sent)
                root.apply();
        }
    }

    // Retries what USBGuard refused. Under the lock, also checks that it
    // still blocks: restarted, it is back at its default, allow.
    Timer {
        interval: 5000
        repeat: true
        running: root.settled && (root.applied !== root.target || root.locked)
        onTriggered: {
            if (root.applied !== root.target)
                root.apply();
            else
                check.running = true;
        }
    }

    Process {
        id: check

        command: ["usbguard", "get-parameter", "ImplicitPolicyTarget"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.locked && text.trim() !== "block") {
                    root.applied = "";
                    root.apply();
                }
            }
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
