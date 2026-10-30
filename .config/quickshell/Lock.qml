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
    // The curtain's way out, 0 to 1 (LockView's leaving).
    property real leave: 0
    // Asked to lock, the curtain is not at full shade yet.
    property bool locking: false
    // The password is accepted, the curtain is not mapped under the lock yet.
    property bool unlocking: false
    // The screen is off with the lock up: its lines wait to come in.
    property bool concealed: false
    // Locked with the screen on: the lines come in once the lock is drawn.
    property bool arriving: false
    // A suspend is coming: a slower fade, the lock goes dark. Only IPC unlocks
    // meanwhile: the laptop would wake up showing the desktop.
    property bool dozing: false
    // Locked by that suspend: the clock and the lines under it come in, not
    // the field and the finger. Up already, the lock stays as it is.
    property bool bare: false
    // How far the lock has gone dark, 0 to 1.
    property real dark: 0
    // The session is being logged out of, the screen faded already.
    property bool leavingSession: false

    function conceal() {
        if (state.locked)
            concealed = true;
    }

    function uncover() {
        revealFallback.stop();
        concealed = false;
        dozing = false;
        bare = false;
        if (leavingSession) {
            leavingSession = false;
            finger.watch(state.locked && !unlocking);
        }
        dozeFallback.stop();
        dozeHold.stop();
        darken.stop();
        if (dark > 0)
            brighten.start();
    }

    function doze() {
        dozing = true;
        dozeFallback.restart();
        revealFallback.stop();
        brighten.stop();
        if (!state.locked)
            bare = true;
        lock();
        // The screen is off already: nothing to see going dark.
        if (state.locked && concealed && !arriving)
            dark = 1;
        else if (sessionLock.secure)
            darken.start();
    }

    // Locks unseen, in the colour the screen has faded to, for the login
    // screen to take over: its VT switch must not lead back to a desktop.
    // The next session must not find the marker, nor the login screen the
    // reader taken.
    function leaveSession() {
        leavingSession = true;
        dozing = true;
        dozeFallback.restart();
        revealFallback.stop();
        brighten.stop();
        dozeHold.stop();
        darken.stop();
        bare = false;
        dark = 1;
        Quickshell.execDetached(["rm", "-f", marker]);
        finger.watch(false);
        if (state.locked && !unlocking) {
            concealed = true;
            return;
        }
        fadeOut.stop();
        fadeDelay.stop();
        curtain = false;
        leave = 0;
        buffer = "";
        status = "";
        unlocking = false;
        unlockDeadline.stop();
        curtainSettle.stop();
        locking = true;
        engage(false);
    }

    // A key or the pointer: the screen is surely on, even if hypridle
    // does not say so.
    function nudge() {
        if (concealed && !dozing && !revealFallback.running)
            revealFallback.start();
    }

    function lock() {
        // Asked while the accepted password waits for the curtain, as a lid
        // closed right after Enter: it stays locked.
        if (unlocking) {
            unlocking = false;
            unlockDeadline.stop();
            curtainSettle.stop();
            frozenMarks = -1;
            accepted = false;
            finger.mark = "";
            finger.watch(true);
            curtainDrop.restart();
            return;
        }
        if (state.locked || locking)
            return;
        buffer = "";
        status = "";
        wallpapers.refresh();
        capsQuery.running = true;
        Weather.refreshIfStale();
        finger.mark = "";
        // Locked again while it leaves: it fades in from the shade it has
        // reached, with the wallpaper only.
        if (fadeOut.running)
            shade = shade * (1 - leave);
        fadeOut.stop();
        fadeDelay.stop();
        leave = 0;
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

    // arrive: the lines come in once the lock is drawn; else they wait for
    // screenOn.
    function engage(arrive = true) {
        if (!locking)
            return;
        locking = false;
        lockDeadline.stop();
        fadeIn.stop();
        shade = 1;
        arriving = arrive;
        concealed = true;
        state.locked = true;
        curtainDrop.restart();
    }

    // accepted: by the password, which turns its marks green.
    function unlock(accepted = false) {
        arriving = false;
        uncover();
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
        fadeDelay.restart();
    }

    // A moment at full shade after the unlock, before the curtain goes.
    Timer {
        id: fadeDelay
        interval: 150
        onTriggered: fadeOut.start()
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "shade"
        to: 1
        duration: root.dozing ? 500 : 200
        easing.type: root.dozing ? Easing.InOutSine : Easing.OutCubic
        onFinished: root.engage(!root.dozing || root.bare)
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "leave"
        to: 1
        duration: 350
        onFinished: {
            root.curtain = false;
            root.shade = 0;
            root.leave = 0;
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
        interval: 800
        onTriggered: root.engage(!root.dozing || root.bare)
    }

    Timer {
        id: revealFallback
        interval: 1500
        onTriggered: root.uncover()
    }

    // The clock's lines come in and stay a moment before the lock goes dark.
    Timer {
        id: dozeHold
        interval: 800
        onTriggered: darken.start()
    }

    NumberAnimation {
        id: darken
        target: root
        property: "dark"
        to: 1
        duration: 800
        easing.type: Easing.InOutSine
        // Its lines wait for the wake, if the lock had them up.
        onFinished: root.conceal()
    }

    NumberAnimation {
        id: brighten
        target: root
        property: "dark"
        to: 0
        duration: 300
    }

    // Still awake long after the delay logind allows: the suspend did not
    // happen, and nothing will say so.
    Timer {
        id: dozeFallback
        interval: 10000
        onTriggered: root.uncover()
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
        // No such PAM service or user: no answer would come.
        if (!pam.start()) {
            checking = false;
            status = "authentication could not start";
        }
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
            if (root.leavingSession)
                return;
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
        // It is set up in ~/.nixos (desktop.nix) and stays without hyprlock.
        config: "hyprlock"

        onPamMessage: {
            if (responseRequired)
                respond(root.buffer);
        }
        onCompleted: result => {
            if (result === PamResult.Success && root.dozing) {
                root.checking = false;
                root.buffer = "";
                return;
            }
            if (result === PamResult.Success) {
                root.unlock(true);
                return;
            }
            // onError, just before, has said what it was.
            if (result === PamResult.Error)
                return;
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
        onRecognised: {
            if (root.dozing) {
                finger.mark = "";
                finger.woke();
                return;
            }
            root.unlock();
        }
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
        bare: root.bare
    }

    WlSessionLock {
        id: sessionLock
        locked: state.locked

        onSecureChanged: {
            if (secure && root.arriving) {
                root.arriving = false;
                if (!root.dozing)
                    root.uncover();
                else if (root.bare)
                    root.concealed = false;
            }
            if (secure && root.dozing) {
                if (root.bare)
                    dozeHold.start();
                else
                    darken.start();
            }
        }

        WlSessionLockSurface {
            id: surface
            color: Theme.base

            // No pointer over the lock: there is nothing to click.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: Qt.BlankCursor

                // The first event is the lock showing up under the pointer,
                // not a move.
                property point seen: Qt.point(-1, -1)
                onPositionChanged: mouse => {
                    if (seen.x >= 0 && (mouse.x !== seen.x || mouse.y !== seen.y))
                        root.nudge();
                    seen = Qt.point(mouse.x, mouse.y);
                }
            }

            View {
                anchors.fill: parent
                output: surface.screen?.name ?? ""
                concealed: root.concealed
                focus: true
                // Caps Lock goes on when the key is pressed, off when it is
                // released.
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_CapsLock)
                        capsDelay.restart();
                }
                Keys.onPressed: event => {
                    root.nudge();
                    if (event.key === Qt.Key_CapsLock)
                        capsDelay.restart();
                    // Nothing more once the password is accepted.
                    if (root.checking || root.unlocking || root.dozing)
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

            Rectangle {
                anchors.fill: parent
                color: root.leavingSession ? Theme.colors.crust : "black"
                opacity: root.dark
                visible: opacity > 0
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
                // Fading in, the wallpaper only, until the lock is drawn: it
                // brings the lines. Nor while the lock keeps them hidden.
                concealed: root.locking || root.arriving || root.concealed
                leaving: root.leave
                // Fades all the way out, as the wallpaper sharpens: the windows
                // come through from the start.
                opacity: root.shade * (1 - root.leave)
                // Fades as one picture, not layer by layer.
                layer.enabled: root.shade < 1 || root.leave > 0
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

        // Before a suspend: fades to the wallpaper, locks, shows the clock and
        // goes dark.
        function doze(): void {
            root.doze();
        }

        // session-logout, ahead of the login screen.
        function leaveSession(): void {
            root.leaveSession();
        }

        // doze() is done: the suspend can go ahead.
        function isDark(): bool {
            return root.dark === 1;
        }

        // The compositor has locked the session and the lock is drawn.
        function isLocked(): bool {
            return sessionLock.secure;
        }

        // The wallpaper has changed: niri's scripts/wallpaper.sh, fish's wp.
        function wallpaper(): void {
            wallpapers.refresh();
        }

        // hypridle's after_sleep_cmd.
        function woke(): void {
            finger.woke();
        }

        // hypridle, as it turns the screens off and on.
        function screenOff(): void {
            root.conceal();
        }

        function screenOn(): void {
            root.uncover();
        }

        function unlock(): void {
            root.unlock();
        }
    }
}
