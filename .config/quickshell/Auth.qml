import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.services
import qs.widgets

// Polkit's authentication agent: what a program asks the password or a
// finger for, in the middle of the focused output, as the launcher is.
// PAM asks the reader first and for the password only once the reader gives
// up: a password typed meanwhile is kept and sent then. Esc cancels.
PanelWindow {
    id: auth

    // The session is locked: what is asked for is cancelled, then and while
    // it stays so.
    property bool locked: false
    onLockedChanged: if (locked)
        cancel()

    // There a moment longer once it is granted, for the green to be seen.
    readonly property bool shown: agent.isActive || granted.running
    // What is asked, kept while the window fades out.
    property string message: ""
    property string buffer: ""
    // Enter was pressed: the answer goes out once it is asked for.
    property bool entered: false
    // Sent, not answered yet.
    property bool checking: false
    // The marks, kept green or red for a moment after the answer.
    property int frozenMarks: -1
    property bool accepted: false
    property bool rejected: false
    readonly property int marks: frozenMarks >= 0 ? frozenMarks : buffer.length
    // What PAM asks for, "" for the password, and whether it may be seen.
    readonly property string prompt: (agent.flow?.inputPrompt ?? "").trim().replace(/:$/, "").replace(/^password$/i, "")
    readonly property bool plain: agent.flow?.responseVisible ?? false
    // The reader: "" not asked, "waiting" for a finger, "bad" for a moment
    // after one it did not recognise, "ok" after one it did.
    property string finger: ""
    readonly property string badFingerText: "fingerprint not recognised"
    // PAM has asked for an answer in this conversation: the reader is done.
    property bool asked: false
    // The line below the field, and whether it is an error.
    property string status: ""
    property bool statusIsError: false

    function say(text, isError) {
        status = text;
        statusIsError = isError;
    }

    // What was typed is not kept past its use.
    function forget() {
        buffer = "";
        entered = false;
        checking = false;
    }

    function cancel() {
        forget();
        if (agent.flow)
            agent.flow.cancelAuthenticationRequest();
    }

    function send() {
        checking = true;
        entered = false;
        agent.flow.submit(buffer);
    }

    function sendEntered() {
        if (entered && agent.flow?.isResponseRequired)
            send();
    }

    function enter() {
        if (buffer === "" || checking || !agent.flow)
            return;
        if (agent.flow.isResponseRequired)
            send();
        else
            entered = true;
    }

    // Granted: the marks or the reader's icon turn green.
    function succeed() {
        frozenMarks = buffer.length;
        accepted = true;
        forget();
        if (finger !== "")
            finger = "ok";
        say("", false);
        granted.restart();
    }

    // Before PAM asks for an answer it is the reader that speaks: its
    // prompt, then an error for each finger not recognised. Told by their
    // order, not their words, which are translated.
    // Whether the message to be read came before PAM asked for an answer.
    property bool fromReader: false
    function heard() {
        const flow = agent.flow;
        if (!flow)
            return;
        const text = flow.supplementaryMessage;
        const reader = fromReader;
        if (flow.supplementaryIsError) {
            // The reader's words for a wrong finger; the lock's instead.
            say(reader && /match/i.test(text) ? badFingerText : text, true);
            if (reader && !asked) {
                finger = "bad";
                badFinger.restart();
            }
        } else if (!reader) {
            say(text, false);
        } else if (!asked && finger !== "bad") {
            // Its next prompt comes at once after a wrong finger.
            finger = "waiting";
        }
    }

    // The flow before this one, to ask how it ended.
    property var previous: null

    // A flow is there: a new one, or one in progress that a reloaded
    // configuration takes over, which is not told as started.
    function adopt() {
        const flow = agent.flow;
        if (previous?.isSuccessful)
            succeed();
        else if (!flow)
            forget();
        previous = flow;
        if (!flow)
            return;
        message = flow.message;
        keyHandler.forceActiveFocus();
        if (locked)
            Qt.callLater(cancel);
    }
    Component.onCompleted: adopt()

    PolkitAgent {
        id: agent

        // The agent drops a flow before the flow says it succeeded: its
        // signal for that reaches nobody.
        onFlowChanged: auth.adopt()

        onAuthenticationRequestStarted: {
            granted.stop();
            auth.forget();
            auth.frozenMarks = -1;
            auth.accepted = false;
            auth.rejected = false;
            auth.finger = "";
            auth.asked = false;
            auth.say("", false);
        }
    }

    Connections {
        target: agent.flow

        function onIsResponseRequiredChanged() {
            if (!agent.flow.isResponseRequired)
                return;
            // The reader has given up, and what it said goes with it.
            badFinger.stop();
            auth.finger = "";
            auth.asked = true;
            auth.say("", false);
            if (auth.checking) {
                // Another question after the answer: a second factor.
                auth.forget();
                auth.frozenMarks = -1;
            } else if (auth.entered) {
                // Once the flow is done setting the question up.
                Qt.callLater(auth.sendEntered);
            }
        }

        // The message changes before its being an error does: both are
        // read once the flow has set the two.
        function onSupplementaryMessageChanged() {
            auth.fromReader = !auth.asked;
            Qt.callLater(auth.heard);
        }
        function onSupplementaryIsErrorChanged() {
            Qt.callLater(auth.heard);
        }

        // PAM starts over, with the reader.
        function onAuthenticationFailed() {
            auth.frozenMarks = auth.buffer.length;
            auth.rejected = true;
            rejectionShown.restart();
            auth.forget();
            auth.asked = false;
            auth.say("not authorised", true);
        }
    }

    Timer {
        id: granted
        interval: 400
    }

    Timer {
        id: badFinger
        interval: 1500
        onTriggered: {
            if (auth.finger === "bad")
                auth.finger = "waiting";
            if (auth.status === auth.badFingerText)
                auth.say("", false);
        }
    }

    Timer {
        id: rejectionShown
        interval: 800
        onTriggered: {
            auth.rejected = false;
            auth.frozenMarks = -1;
        }
    }

    Pop {
        id: pop
        shown: auth.shown
        mapped: auth.backingWindowVisible
    }

    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || pop.openness > 0

    WlrLayershell.namespace: "quickshell-auth"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: agent.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The blur and its resending are the power menu's; see PowerMenu.
    readonly property bool blurred: pop.openness > 0.5
    BackgroundEffect.blurRegion: Region {
        x: content.x
        y: content.y
        width: auth.blurred ? content.width : 0
        height: auth.blurred ? content.height : 0
        radius: Theme.barRadius

        BlurBump {
            id: blurBump
            x: content.x + Theme.barRadius
            y: content.y + Theme.barRadius
            width: auth.blurred ? 1 : 0
        }
    }

    onBlurredChanged: if (blurred)
        blurBump.send(8)

    // The output dims, as under the power menu. A click does not cancel.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45 * Math.min(1, pop.openness)
    }

    MouseArea {
        anchors.fill: parent
    }

    Item {
        id: keyHandler
        focus: true
        Keys.onPressed: event => {
            event.accepted = true;
            if (event.key === Qt.Key_Escape) {
                auth.cancel();
                return;
            }
            if (auth.checking || auth.accepted)
                return;
            // A key during the red marks starts the next attempt.
            if (auth.rejected) {
                rejectionShown.stop();
                auth.rejected = false;
                auth.frozenMarks = -1;
            }
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                auth.enter();
                break;
            case Qt.Key_Backspace:
                auth.buffer = event.modifiers & Qt.ControlModifier ? "" : auth.buffer.slice(0, -1);
                auth.entered = false;
                break;
            default:
                // Printable characters only.
                if (event.text.length > 0 && event.text >= " " && event.text !== "\x7f") {
                    auth.buffer += event.text;
                    auth.entered = false;
                    if (auth.statusIsError)
                        auth.say("", false);
                }
            }
        }
    }

    // Only as large as the box and its shadow, as in the power menu.
    Item {
        id: shadowLayer
        readonly property int room: 30
        x: content.x - room
        y: content.y - room
        width: content.width + 2 * room
        height: content.height + 2 * room

        opacity: pop.openness
        scale: pop.scale

        layer.enabled: true
        layer.effect: Shadow {}

        Rectangle {
            x: shadowLayer.room
            y: shadowLayer.room
            width: content.width
            height: content.height
            radius: Theme.barRadius
            color: Theme.base
        }
    }

    // Outside the shadow's layer: text drawn into it comes out soft.
    Item {
        id: content
        readonly property int pad: Theme.popupPadding + Theme.popupTextInset
        x: Theme.snap((parent.width - width) / 2, auth.devicePixelRatio)
        y: Theme.snap((parent.height - height) / 2, auth.devicePixelRatio)
        width: 460
        height: column.implicitHeight + 2 * pad
        opacity: pop.openness
        scale: pop.scale

        Column {
            id: column
            x: content.pad
            y: content.pad
            width: content.width - 2 * content.pad
            spacing: Theme.popupGridGap

            PopupText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Theme.glyph(0xf033e)
                font.pixelSize: 44
                color: Theme.white
            }

            PopupText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: auth.message
                wrapMode: Text.Wrap
            }

            // The field: a mark per character, as on the lock.
            Rectangle {
                width: parent.width
                height: 40
                radius: Theme.moduleRadius
                color: Theme.surface0

                PopupText {
                    anchors.centerIn: parent
                    visible: auth.marks === 0
                    text: auth.checking ? "checking…" : auth.prompt !== "" ? auth.prompt : "password"
                    color: Theme.subtext0
                }

                // An answer PAM lets be seen, as a second factor's code.
                PopupText {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 2 * Theme.popupTextInset)
                    elide: Text.ElideLeft
                    visible: auth.plain
                    text: auth.buffer
                    opacity: marksRow.opacity
                }

                Row {
                    id: marksRow
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !auth.plain
                    // Dimmed while the password waits or is checked.
                    opacity: auth.checking || auth.entered ? 0.5 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    Repeater {
                        // As many as the field is wide.
                        model: 22

                        PopupText {
                            required property int index
                            visible: index < auth.marks
                            text: Theme.glyph(0xf14fb)
                            color: auth.accepted ? Theme.green : auth.rejected ? Theme.red : Theme.subtext1
                        }
                    }
                }
            }

            // The reader's icon and, under it, the line that tells what
            // goes on, as on the lock. Both keep their place when empty.
            Column {
                width: parent.width
                spacing: Theme.popupRowGap

                PopupText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Theme.glyph(0xf0237)
                    font.pixelSize: 36
                    opacity: auth.finger === "" ? 0 : 1
                    color: auth.finger === "ok" ? Theme.green : auth.finger === "bad" ? Theme.red : Theme.subtext0
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                PopupText {
                    // Whatever PAM says stays inside the box.
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: auth.entered ? "waiting for the reader" : auth.status !== "" ? auth.status : " "
                    color: auth.entered || !auth.statusIsError ? Theme.subtext0 : Theme.red
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }
    }
}
