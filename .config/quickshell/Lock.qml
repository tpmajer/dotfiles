import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.widgets

// Lock screen (prototype): a session lock with the clock and a password
// field on every output, over the output's wallpaper, blurred and dimmed.
// `qs ipc call lock lock` locks; nothing else does yet, hyprlock stays the lock
// that hypridle and the power menus start.
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
    // What the field shows: a mark per character and whether they are dimmed.
    // Frozen while the curtain fades out, as the buffer is cleared at once and
    // the field would otherwise empty itself during the fade.
    property int frozenMarks: -1
    property bool frozenDimmed: false
    readonly property int marks: frozenMarks >= 0 ? frozenMarks : buffer.length
    readonly property bool dimmed: frozenMarks >= 0 ? frozenDimmed : checking
    readonly property bool locked: state.locked
    // The reader: "" not watched, "waiting" for a finger, "bad" for a moment
    // after one it did not recognise, "ok" after one it did, which stays
    // through the fade out.
    property string fingerState: ""
    // Caps Lock is on, as the keyboards' LEDs have it: Qt does not tell.
    property bool capsLock: false
    // Output name -> URL of the image awww shows there.
    property var wallpapers: ({})
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
        wallpaperQuery.running = true;
        capsQuery.running = true;
        fingerState = "";
        fadeOut.stop();
        frozenMarks = -1;
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

    // dimmed: the marks stay as they were while the password was checked.
    function unlock(dimmed = false) {
        if (pam.active)
            pam.abort();
        if (state.locked) {
            frozenMarks = buffer.length;
            frozenDimmed = dimmed;
        }
        checking = false;
        fingerRetry.stop();
        if (finger.active)
            finger.abort();
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
            root.watchFinger();
        }
        onLockedChanged: {
            Quickshell.execDetached(locked ? ["touch", root.marker] : ["rm", "-f", root.marker]);
            root.watchFinger();
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

        // hyprlock's PAM service for now: the password only, no fingerprint.
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
            root.buffer = "";
            root.status = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password";
        }
        onError: error => {
            root.checking = false;
            root.buffer = "";
            root.status = "Authentication error: " + PamError.toString(error);
        }
    }

    // The fingerprint reader, watched for as long as the session is locked.
    function watchFinger() {
        fingerRetry.stop();
        if (state.locked && !unlocking) {
            if (!finger.active)
                finger.start();
        } else if (finger.active) {
            finger.abort();
        }
    }

    // A second conversation, next to the password's: pam_fprintd waits for a
    // finger and nothing else. It gives up after three wrong ones or half a
    // minute without any, and is started again.
    PamContext {
        id: finger

        // GDM's service for now: it has pam_fprintd, hyprlock's has not.
        config: "gdm-fingerprint"

        // Its prompt for a finger, then an error for each one not recognised.
        onPamMessage: {
            if (!state.locked || root.unlocking)
                return;
            if (messageIsError) {
                root.status = "Fingerprint not recognised";
                root.fingerState = "bad";
                fingerBad.restart();
            } else if (root.fingerState !== "bad") {
                root.fingerState = "waiting";
            }
        }
        onCompleted: result => {
            if (!state.locked || root.unlocking)
                return;
            if (result === PamResult.Success) {
                fingerBad.stop();
                root.fingerState = "ok";
                root.unlock();
                return;
            }
            if (!fingerBad.running)
                root.fingerState = "";
            fingerRetry.interval = 1000;
            fingerRetry.restart();
        }
        // No reader, or fprintd has lost it (a suspend): not as often.
        onError: error => {
            root.fingerState = "";
            fingerRetry.interval = 3000;
            fingerRetry.restart();
        }
    }

    // How long the mark of a finger not recognised stays.
    Timer {
        id: fingerBad
        interval: 1000
        onTriggered: root.fingerState = finger.active ? "waiting" : ""
    }

    Timer {
        id: fingerRetry
        onTriggered: root.watchFinger()
    }

    // Asked at startup, every half a minute and at every lock: awww does not
    // tell when the wallpaper changes. The lock does not wait for it: a surface
    // is plain until its image is there, and stays plain if awww shows none.
    Process {
        id: wallpaperQuery
        command: ["awww", "query"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // ": eDP-1: 1800x1200, scale: 1.6, currently displaying: image: /path"
                const found = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^:?\s*(\S+): .*currently displaying: image: (.+)$/);
                    if (m)
                        found[m[1]] = "file://" + m[2].split("/").map(encodeURIComponent).join("/");
                }
                // Unchanged: nothing is loaded again.
                if (JSON.stringify(found) !== JSON.stringify(root.wallpapers))
                    root.wallpapers = found;
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: wallpaperQuery.running = true
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

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // What a lock surface and a curtain both show.
    component View: Rectangle {
        id: view

        // The name of the output it is on.
        property string output: ""
        // Whether the field animates what is typed. Not in a curtain: hidden
        // while that happens, it would play it all when it is next shown.
        property bool animated: true

        color: Theme.base

        Image {
            id: wallpaper
            anchors.fill: parent
            visible: false
            source: root.wallpapers[view.output] ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        // Fades in over the plain colour if the image is not in Qt's cache.
        // The curtain keeps it there, and then it is ready a moment after
        // the view is created, once the output is known: that must not fade.
        Item {
            id: backdrop
            property bool late: false

            anchors.fill: parent
            opacity: wallpaper.status === Image.Ready ? 1 : 0
            visible: opacity > 0

            Timer {
                interval: 50
                running: true
                onTriggered: backdrop.late = true
            }

            Behavior on opacity {
                enabled: backdrop.late
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: wallpaper
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }

            // Dims the wallpaper, so the text reads on a bright one.
            Rectangle {
                anchors.fill: parent
                color: Theme.base
                opacity: 0.45
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 24

            PopupText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: 96
                font.bold: true
            }

            PopupText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.subtext0
            }

            Item {
                width: 1
                height: 24
            }

            // The password field: a mark per character typed.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: Theme.barHeight

                // The bar's shape and shadow (PopupHost), see-through as a
                // whole the way niri's layer rule makes the bar, only more:
                // the wallpaper under it is blurred already.
                Item {
                    anchors.fill: parent
                    opacity: 0.7

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#77000000"
                        shadowBlur: 1.0
                        blurMax: 24
                        shadowVerticalOffset: 3
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.barRadius
                        color: Theme.base
                    }
                }

                PopupText {
                    id: placeholder
                    readonly property bool shown: root.marks === 0

                    anchors.centerIn: parent

                    text: root.checking ? "Checking…" : "Password"
                    color: Theme.subtext0

                    // Gone at the first key; back once the marks have faded.
                    states: State {
                        name: "typing"
                        when: !placeholder.shown
                        PropertyChanges {
                            placeholder.opacity: 0
                        }
                    }
                    transitions: Transition {
                        from: "typing"
                        enabled: view.animated
                        SequentialAnimation {
                            PauseAnimation {
                                duration: 100
                            }
                            NumberAnimation {
                                property: "opacity"
                                duration: 150
                            }
                        }
                    }
                }

                // As in hyprlock: a mark fades and grows in at the end of the
                // row, which stays centred by sliding, not jumping.
                Row {
                    x: (parent.width - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.dimmed ? 0.5 : 1
                    spacing: 8

                    Behavior on x {
                        enabled: view.animated
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        // As many as the field is wide, shown one per
                        // character: a Repeater counting the characters
                        // would make all of them anew at every key.
                        model: 18

                        // The bar's mark of the active workspace.
                        PopupText {
                            required property int index
                            readonly property bool typed: index < root.marks

                            text: Theme.glyph(0xf14fb)
                            opacity: typed ? 1 : 0
                            scale: typed ? 1 : 0.4
                            // Out of the row once faded: the row is as wide
                            // as what was typed.
                            visible: opacity > 0

                            Behavior on opacity {
                                enabled: view.animated
                                NumberAnimation {
                                    duration: typed ? 150 : 100
                                }
                            }
                            Behavior on scale {
                                enabled: view.animated
                                NumberAnimation {
                                    duration: typed ? 200 : 100
                                    easing.type: typed ? Easing.OutBack : Easing.InQuad
                                }
                            }
                        }
                    }
                }
            }

            // The reader waits for a finger; red for one it did not
            // recognise, green for one it did. Keeps its place when not
            // shown, so nothing moves.
            PopupText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Theme.glyph(0xf0237)
                font.pixelSize: 36
                opacity: root.fingerState === "" ? 0 : 1
                color: root.fingerState === "ok" ? Theme.green : root.fingerState === "bad" ? Theme.red : Theme.subtext0

                Behavior on opacity {
                    enabled: view.animated
                    NumberAnimation {
                        duration: 150
                    }
                }
                Behavior on color {
                    enabled: view.animated
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            PopupText {
                anchors.horizontalCenter: parent.horizontalCenter
                // Why the last attempt failed, else a warning about Caps
                // Lock. Keeps its line when empty, so nothing moves.
                text: root.status !== "" ? root.status : root.capsLock ? "Caps Lock is on" : " "
                color: root.status !== "" ? Theme.red : Theme.peach
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }

    WlSessionLock {
        locked: state.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.base

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
    // under it. Its views also keep the wallpapers decoded while unlocked, a
    // hidden window's items being alive: neither they nor the lock's set
    // sourceSize, which the cache is keyed by and a window scales by its own
    // ratio.
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

    // `unlock` is for testing the prototype and for getting out when the
    // password does not work. Any program of this user can call it, which is
    // what `pkill -USR1 hyprlock` allows too.
    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function unlock(): void {
            root.unlock();
        }
    }
}
