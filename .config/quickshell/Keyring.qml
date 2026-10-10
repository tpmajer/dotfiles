import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.widgets

// The keyring's prompt: the password oo7 asks for to unlock a keyring, or
// to make a new one, in the middle of the focused output as polkit's is.
// oo7 asks through secret-prompter (~/.nixos), which connects to the socket
// here for each prompt: a line of JSON each way. Esc cancels.
Overlay {
    id: keyring

    // The session is locked: what is asked for is cancelled, then and while
    // it stays so.
    property bool locked: false
    onLockedChanged: if (locked)
        cancel()

    // polkit's prompt is on show: this one is out of its way until it is
    // gone, what was typed kept. PAM would not wait, oo7 does.
    property bool waits: false

    // The connection of the prompt on show.
    property var link: null
    // There a moment longer once it is taken, for the green to be seen, or
    // what went wrong to be read.
    shown: !waits && (link !== null || granted.running || failed.running)
    keyboard: !waits && link !== null
    boxWidth: 460
    boxHeight: column.implicitHeight + 2 * pad
    readonly property int pad: Theme.popupPadding + Theme.popupTextInset
    // "unlock" or "create", and the keyring's name: kept while the window
    // fades out.
    property string role: "unlock"
    property string collection: ""
    property string buffer: ""
    // A new keyring's password, until it is typed again.
    property string first: ""
    // Sent, not answered yet.
    property bool checking: false
    // The marks, kept green or red for a moment after the answer.
    property int frozenMarks: -1
    property bool accepted: false
    property bool rejected: false
    readonly property int marks: frozenMarks >= 0 ? frozenMarks : buffer.length
    // The line below the field, an error.
    property string status: ""

    // What was typed is not kept past its use.
    function forget() {
        buffer = "";
        first = "";
        checking = false;
    }

    function tell(socket, message) {
        socket.write(JSON.stringify(message) + "\n");
        socket.flush();
    }

    function cancel() {
        forget();
        if (link)
            tell(link, {cancel: true});
    }

    // The marks turn red for a moment.
    function refuse(text) {
        frozenMarks = buffer.length;
        rejected = true;
        rejectionShown.restart();
        forget();
        status = text;
    }

    function enter() {
        if (buffer === "" || checking || !link)
            return;
        if (role === "create" && first === "") {
            first = buffer;
            buffer = "";
        } else if (role === "create" && buffer !== first) {
            refuse("the passwords differ");
        } else {
            checking = true;
            tell(link, {password: buffer});
        }
    }

    function heard(socket, line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (message.event === "prompt") {
            // One at a time: the one on show gives way.
            if (link && link !== socket)
                tell(link, {cancel: true});
            granted.stop();
            failed.stop();
            rejectionShown.stop();
            forget();
            frozenMarks = -1;
            accepted = false;
            rejected = false;
            status = "";
            role = message.role;
            collection = message.collection;
            link = socket;
            keyHandler.forceActiveFocus();
            if (locked)
                cancel();
        } else if (socket !== link) {
            return;
        } else if (message.event === "retry") {
            // oo7's words for it are a sentence, and translated.
            refuse(role === "unlock" ? "wrong password" : message.reason);
        } else if (message.event === "done") {
            frozenMarks = buffer.length;
            accepted = true;
            forget();
            status = "";
            granted.restart();
        } else if (message.event === "failed") {
            // oo7 took the password and then could not do what was asked.
            refuse("the keyring did not answer");
            failed.restart();
        }
    }

    function left(socket) {
        if (socket !== link)
            return;
        link = null;
        forget();
    }

    SocketServer {
        reloadableId: "keyring"
        active: true
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-keyring.sock"
        handler: Socket {
            id: socket
            parser: SplitParser {
                onRead: line => keyring.heard(socket, line)
            }
            onConnectionStateChanged: if (!connected)
                keyring.left(socket)
        }
    }

    Timer {
        id: granted
        interval: 400
    }

    Timer {
        id: failed
        interval: 2000
    }

    Timer {
        id: rejectionShown
        interval: 800
        onTriggered: {
            keyring.rejected = false;
            keyring.frozenMarks = -1;
        }
    }

    // polkit's prompt's, for niri's rule for it.
    WlrLayershell.namespace: "quickshell-auth"

    Item {
        id: keyHandler
        focus: true
        Keys.onPressed: event => {
            event.accepted = true;
            if (event.key === Qt.Key_Escape) {
                keyring.cancel();
                return;
            }
            if (keyring.checking || keyring.accepted)
                return;
            // A key during the red marks starts the next attempt.
            if (keyring.rejected) {
                rejectionShown.stop();
                keyring.rejected = false;
                keyring.frozenMarks = -1;
            }
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                keyring.enter();
                break;
            case Qt.Key_Backspace:
                keyring.buffer = event.modifiers & Qt.ControlModifier ? "" : keyring.buffer.slice(0, -1);
                break;
            default:
                // Printable characters only.
                if (event.text.length > 0 && event.text >= " " && event.text !== "\x7f") {
                    keyring.buffer += event.text;
                    keyring.status = "";
                }
            }
        }
    }

    Column {
        id: column
        x: keyring.pad
        y: keyring.pad
        width: keyring.boxWidth - 2 * keyring.pad
        spacing: Theme.popupGridGap

        PopupText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.glyph(0xf0306)
            font.pixelSize: 44
            color: Theme.white
        }

        PopupText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: keyring.role === "create" ? `A password for the new keyring “${keyring.collection}”` : `Unlock the keyring “${keyring.collection}”`
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
                visible: keyring.marks === 0
                text: keyring.checking ? "checking…" : keyring.role !== "create" ? "password" : keyring.first === "" ? "new password" : "the password again"
                color: Theme.subtext0
            }

            Marks {
                marks: keyring.marks
                checking: keyring.checking
                accepted: keyring.accepted
                rejected: keyring.rejected
                most: 22
            }
        }

        // Keeps its place when empty.
        PopupText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: keyring.status !== "" ? keyring.status : " "
            color: Theme.red
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
