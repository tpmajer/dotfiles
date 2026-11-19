import QtQuick
import Quickshell
import Quickshell.Io

// USBGuard (usbguard.nix in ~/.nixos) blocks the devices new to it while the
// session is locked and lets any in otherwise. After the unlock, a device in
// before the lock that came back under it (a reset in sleep) is let in again;
// any other stays blocked until plugged in again, named in a notification.
Scope {
    id: root

    required property bool locked
    // Whether the session is locked is known: a start finds that out after
    // a moment, and would let devices in under a lock meanwhile.
    required property bool settled

    readonly property string target: locked ? "block" : "allow"
    // What USBGuard was last told, "" before that.
    property string applied: ""
    // Hashes of the devices let in and of those blocked as the lock began,
    // kept for the unlock while snapped.
    property list<string> trusted: []
    property list<string> blockedBefore: []
    property bool snapped: false
    // It refused the last time: told once, until it takes one again.
    property bool failing: false

    function apply() {
        if (!settled || setter.running || applied === target)
            return;
        setter.sent = target;
        setter.exec(["usbguard", "set-parameter", "ImplicitPolicyTarget", target]);
    }

    // An attribute of a device as `usbguard list-devices` prints it, with
    // its escapes undone.
    function attribute(line, name) {
        const found = line.match(new RegExp(` ${name} "((?:[^"\\\\]|\\\\.)*)"`));
        return found ? found[1].replace(/\\x([0-9a-fA-F]{2})|\\(.)/g, (_, hex, char) => hex ? String.fromCharCode(parseInt(hex, 16)) : char) : "";
    }

    // A device names itself: its name is kept out of the notification's markup.
    function escaped(text) {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
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
                if (setter.sent === "block" && !root.snapped) {
                    root.snapped = true;
                    snapshot.running = true;
                } else if (setter.sent === "allow" && root.snapped) {
                    review.running = true;
                }
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
        id: snapshot

        command: ["usbguard", "list-devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.locked)
                    return;
                const allowed = [];
                const blocked = [];
                for (const line of text.split("\n")) {
                    const hash = root.attribute(line, "hash");
                    if (hash)
                        (/^\d+: allow /.test(line) ? allowed : blocked).push(hash);
                }
                root.trusted = allowed;
                root.blockedBefore = blocked;
            }
        }
    }

    Process {
        id: review

        command: ["usbguard", "list-devices", "--blocked"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                for (const line of text.split("\n")) {
                    const id = line.match(/^(\d+): /);
                    if (!id)
                        continue;
                    const hash = root.attribute(line, "hash");
                    if (root.trusted.includes(hash))
                        Quickshell.execDetached(["usbguard", "allow-device", id[1]]);
                    else if (!root.blockedBefore.includes(hash))
                        names.push(root.escaped(root.attribute(line, "name") || "Unnamed device"));
                }
                root.snapped = false;
                root.trusted = [];
                root.blockedBefore = [];
                if (names.length)
                    Quickshell.execDetached([Quickshell.shellDir + "/scripts/notify-replace.sh", "usbguard", "-a", "USBGuard", "Blocked while locked", names.join("\n") + "\nPlug in again to use."]);
            }
        }
    }
}
