import QtQuick
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.widgets

// Polkit's authentication agent: what a program asks the password or a
// finger for, in the middle of the focused output, as the launcher is.
// PAM asks the reader first and for the password only once the reader gives
// up: a password typed meanwhile is kept and sent then. Esc cancels.
Overlay {
    id: auth

    // The session is locked: what is asked for is cancelled, then and while
    // it stays so.
    property bool locked: false
    onLockedChanged: if (locked)
        cancel()

    // There a moment longer once it is granted, for the green to be seen.
    shown: agent.isActive || granted.running
    keyboard: agent.isActive
    boxWidth: 460
    boxHeight: column.implicitHeight + 2 * pad
    readonly property int pad: Theme.popupPadding + Theme.popupTextInset
    // What is asked, kept while the window fades out.
    property string message: ""
    // Enter was pressed: the answer goes out once it is asked for.
    property bool entered: false
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
        field.forget();
        entered = false;
    }

    function cancel() {
        forget();
        if (agent.flow)
            agent.flow.cancelAuthenticationRequest();
    }

    function send() {
        field.checking = true;
        entered = false;
        agent.flow.submit(field.buffer);
    }

    function sendEntered() {
        if (entered && agent.flow?.isResponseRequired)
            send();
    }

    function enter() {
        if (field.buffer === "" || field.checking || !agent.flow)
            return;
        if (agent.flow.isResponseRequired)
            send();
        else
            entered = true;
    }

    // Granted: the marks or the reader's icon turn green.
    function succeed() {
        field.succeed();
        entered = false;
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
        field.forceActiveFocus();
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
            field.clear();
            auth.entered = false;
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
            if (field.checking) {
                // Another question after the answer: a second factor.
                auth.forget();
                field.frozenMarks = -1;
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
            field.refuse();
            auth.entered = false;
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

    WlrLayershell.namespace: "quickshell-auth"

    Column {
        id: column
        x: auth.pad
        y: auth.pad
        width: auth.boxWidth - 2 * auth.pad
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

        // Its marks pulse while the password waits for the reader, too.
        PasswordField {
            id: field
            width: parent.width
            placeholder: auth.prompt !== "" ? auth.prompt : "password"
            plain: auth.plain
            pending: auth.entered
            onEntered: auth.enter()
            onCancelled: auth.cancel()
            onEdited: typed => {
                auth.entered = false;
                if (typed && auth.statusIsError)
                    auth.say("", false);
            }
        }

        // The reader's icon and, under it, the line that tells what
        // goes on, as on the lock. Both keep their place when empty.
        Column {
            width: parent.width
            spacing: Theme.popupRowGap

            FingerMark {
                anchors.horizontalCenter: parent.horizontalCenter
                mark: auth.finger
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
