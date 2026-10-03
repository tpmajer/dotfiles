import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.lock
import qs.services

// Lock screen: a session lock with the clock and a password field on every
// output, over the output's wallpaper, blurred and dimmed. hypridle starts it
// (`qs ipc call lock lock` as its lock_cmd), for loginctl lock-session and
// Mod+L too; the power menus call it themselves, hypridle or not; before a
// suspend, scripts/lock-before-sleep.sh.
//
// The session is unlocked the moment the password is accepted, with nothing
// animated while it is still locked: niri ignores most key bindings until then.
// The fades are a curtain's instead: an overlay that looks like the lock, over
// the desktop. It fades in and then the session locks, a fifth of a second
// after it was asked to; the session unlocks and then it fades out. For that
// it is mapped anew under the lock when the password is accepted, which takes
// some 70 ms: kept there since the lock, it would show what it last drew.
Scope {
    id: root

    // What has been typed, shared by the surfaces of all outputs.
    property string buffer: ""
    // The line below the field: why the last attempt failed.
    property string status: ""
    // From Enter until the answer is acted on. Not pam.active, which is over a
    // moment before that: the marks would be undimmed for a frame in between.
    property bool checking: false
    // What the field shows: a mark per character, green once the password is
    // accepted, red for a moment when it is not. The buffer is cleared at
    // once either way, so the count is frozen for as long as that shows: while
    // the curtain fades out, or until the red marks go.
    property int frozenMarks: -1
    property bool accepted: false
    property bool rejected: false
    // What the red marks turn into, in the field for three seconds or until
    // the next key.
    property string rejection: ""
    readonly property int marks: frozenMarks >= 0 ? frozenMarks : buffer.length
    readonly property bool locked: state.locked
    // Caps Lock is on, as the keyboards' LEDs have it: Qt does not tell.
    property bool capsLock: false
    property bool curtain: false
    property real shade: 0
    // Asked to lock, the curtain is not at full shade yet.
    property bool locking: false
    // The password is accepted, the curtain is not mapped under the lock yet.
    property bool unlocking: false

    function lock() {
        if (state.locked || locking)
            return;
        buffer = "";
        status = "";
        wallpapers.refresh();
        capsQuery.running = true;
        Weather.refreshIfStale();
        finger.mark = "";
        fadeOut.stop();
        endRejection();
        rejection = "";
        frozenMarks = -1;
        accepted = false;
        locking = true;
        lockDeadline.restart();
        // Else the fade starts when a curtain is drawn, see below.
        if (curtain)
            fadeIn.start();
        curtain = true;
    }

    function engage() {
        if (!locking)
            return;
        locking = false;
        lockDeadline.stop();
        fadeIn.stop();
        shade = 1;
        state.locked = true;
        curtainDrop.restart();
    }

    // accepted: by the password, which turns its marks green.
    function unlock(accepted = false) {
        if (pam.active)
            pam.abort();
        endRejection();
        rejectionGone.stop();
        rejection = "";
        if (state.locked) {
            frozenMarks = buffer.length;
            root.accepted = accepted;
        }
        checking = false;
        finger.stop();
        buffer = "";
        status = "";
        locking = false;
        lockDeadline.stop();
        fadeIn.stop();
        curtainDrop.stop();
        if (!state.locked) {
            // Still fading in.
            fadeOut.start();
        } else if (curtain) {
            release();
        } else {
            // release() follows when a curtain is drawn, see below.
            unlocking = true;
            shade = 1;
            curtain = true;
            unlockDeadline.restart();
        }
    }

    function curtainDrawn() {
        if (locking && !fadeIn.running)
            fadeIn.start();
        if (unlocking)
            curtainSettle.restart();
    }

    function release() {
        unlocking = false;
        unlockDeadline.stop();
        state.locked = false;
        fadeOut.start();
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "shade"
        to: 1
        duration: 200
        easing.type: Easing.OutCubic
        onFinished: root.engage()
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "shade"
        to: 0
        duration: 250
        easing.type: Easing.InOutQuad
        onFinished: {
            root.curtain = false;
            root.frozenMarks = -1;
            root.accepted = false;
        }
    }

    // The curtain goes once the lock is surely over it.
    Timer {
        id: curtainDrop
        interval: 500
        onTriggered: {
            if (state.locked && !root.unlocking)
                root.curtain = false;
        }
    }

    // The session unlocks even if no curtain shows up to fade out.
    Timer {
        id: unlockDeadline
        interval: 300
        onTriggered: root.release()
    }

    // For a drawn curtain's frame to reach niri and the screen.
    Timer {
        id: curtainSettle
        interval: 25
        onTriggered: {
            if (root.unlocking)
                root.release();
        }
    }

    // The session locks even if no curtain shows up to fade in.
    Timer {
        id: lockDeadline
        interval: 600
        onTriggered: root.engage()
    }

    // The red marks go, the field is empty again. They stay red while they
    // fade, unless a key has already started the next attempt.
    function endRejection(now = true) {
        if (!rejected)
            return;
        rejectionShown.stop();
        frozenMarks = -1;
        if (now) {
            rejectionFade.stop();
            rejected = false;
        } else {
            rejectionFade.restart();
        }
    }

    Timer {
        id: rejectionShown
        interval: 800
        onTriggered: root.endRejection(false)
    }

    // From the rejection: the red marks' time, then the three seconds.
    Timer {
        id: rejectionGone
        interval: rejectionShown.interval + 3000
        onTriggered: root.rejection = ""
    }

    Timer {
        id: rejectionFade
        interval: 120
        onTriggered: root.rejected = false
    }

    function submit() {
        if (buffer === "" || pam.active)
            return;
        status = "";
        checking = true;
        pam.start();
    }

    // Survives a reload of the configuration: a reload must not unlock.
    PersistentProperties {
        id: state
        reloadableId: "lock"
        property bool locked: false
        // Not a new process: this configuration is a reload's.
        property bool started: false

        // Locked through a reload: at full shade for the fade out.
        onLoaded: {
            if (locked)
                root.shade = 1;
            finger.watch(state.locked && !root.unlocking);
        }
        onLockedChanged: {
            Quickshell.execDetached(locked ? ["touch", root.marker] : ["rm", "-f", root.marker]);
            finger.watch(state.locked && !root.unlocking);
        }
    }

    // Survives the process: if it dies while locked, niri keeps the session
    // locked with nothing to unlock it, a plain red screen. The process
    // systemd starts next finds the marker and locks again, over that.
    readonly property string marker: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-lock"

    Process {
        id: markerCheck
        command: ["test", "-e", root.marker]
        onExited: exitCode => {
            if (exitCode === 0 && !state.locked) {
                root.shade = 1;
                state.locked = true;
            }
        }
    }

    // After the persisted state is back, which tells a reload from a start.
    Timer {
        interval: 50
        running: true
        onTriggered: {
            if (!state.started)
                markerCheck.running = true;
            state.started = true;
        }
    }

    PamContext {
        id: pam

        // hyprlock's PAM service, borrowed: the password only, no fingerprint.
        // It is set up in ~/.nixos (system.nix) and stays without hyprlock.
        config: "hyprlock"

        onPamMessage: {
            if (responseRequired)
                respond(root.buffer);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock(true);
                return;
            }
            root.checking = false;
            root.frozenMarks = root.buffer.length;
            root.rejected = true;
            rejectionShown.restart();
            rejectionGone.restart();
            root.buffer = "";
            root.rejection = result === PamResult.MaxTries ? "too many attempts" : "wrong password";
        }
        onError: error => {
            root.checking = false;
            root.buffer = "";
            root.status = "authentication error: " + PamError.toString(error);
        }
    }

    Fingerprint {
        id: finger
        onSaid: text => root.status = text
        onUnsaid: text => {
            if (root.status === text)
                root.status = "";
        }
        onRecognised: root.unlock()
    }

    Wallpapers {
        id: wallpapers
    }

    // Read at every lock and after the Caps Lock key is pressed and released,
    // a moment later for niri to have set the LED.
    Process {
        id: capsQuery
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = /[1-9]/.test(text)
        }
    }

    Timer {
        id: capsDelay
        interval: 60
        onTriggered: capsQuery.running = true
    }

    // A view of this lock, on a lock surface and on a curtain.
    component View: LockView {
        // The name of the output it is on.
        property string output: ""

        wallpaper: wallpapers.images[output] ?? ""
        marks: root.marks
        checking: root.checking
        accepted: root.accepted
        rejected: root.rejected
        rejection: root.rejection
        fingerMark: finger.mark
        capsLock: root.capsLock
        status: root.status
    }

    WlSessionLock {
        id: sessionLock
        locked: state.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.base

            // No pointer over the lock: there is nothing to click.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
            }

            View {
                anchors.fill: parent
                output: surface.screen?.name ?? ""
                focus: true
                // Caps Lock goes on when the key is pressed, off when it is
                // released.
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_CapsLock)
                        capsDelay.restart();
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_CapsLock)
                        capsDelay.restart();
                    if (root.checking)
                        return;
                    // A key during the red marks starts the next attempt.
                    root.endRejection();
                    root.rejection = "";
                    switch (event.key) {
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.submit();
                        break;
                    case Qt.Key_Backspace:
                        root.buffer = event.modifiers & Qt.ControlModifier ? "" : root.buffer.slice(0, -1);
                        break;
                    case Qt.Key_Escape:
                        root.buffer = "";
                        break;
                    default:
                        // Printable characters only.
                        if (event.text.length > 0 && event.text >= " " && event.text !== "\x7f") {
                            root.buffer += event.text;
                            root.status = "";
                        }
                    }
                    event.accepted = true;
                }
            }
        }
    }

    // The curtain. Nothing reaches it: the pointer and the keys go to what is
    // under it.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            visible: root.curtain
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-lock-curtain"
            mask: Region {}

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Shown is not drawn yet: its first frame takes some 40-50 ms,
            // which would come out of the fade in's start, and unlocking
            // before it would show the desktop for a frame. The grab is done
            // with that first frame, which is how its end is known here.
            onBackingWindowVisibleChanged: {
                if (!backingWindowVisible)
                    return;
                if (!probe.grabToImage(() => root.curtainDrawn()))
                    root.curtainDrawn();
            }

            Item {
                id: probe
                width: 1
                height: 1
            }

            View {
                anchors.fill: parent
                output: modelData?.name ?? ""
                animated: false
                opacity: root.shade
                // Fades as one picture, not layer by layer.
                layer.enabled: root.shade < 1
            }
        }
    }

    // `unlock` is for getting out, from a TTY, when neither the password nor
    // the finger works. Any program of this user can call it; one that can
    // could as well write it into this file, which is loaded anew when it
    // changes.
    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        // Before a suspend: no fade, the session locks at once.
        function lockNow(): void {
            root.lock();
            root.engage();
        }

        // The compositor has locked the session and the lock is drawn.
        function isLocked(): bool {
            return sessionLock.secure;
        }

        // The wallpaper has changed: the scripts behind Mod+S and Mod+X, wp.
        function wallpaper(): void {
            wallpapers.refresh();
        }

        // hypridle's after_sleep_cmd.
        function woke(): void {
            finger.woke();
        }

        function unlock(): void {
            root.unlock();
        }
    }
}
