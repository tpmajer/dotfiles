import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
    // A new keyring's password, until it is typed again.
    property string first: ""
    // The line below the field, an error.
    property string status: ""

    // What was typed is not kept past its use.
    function forget() {
        field.forget();
        first = "";
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
        field.refuse();
        first = "";
        status = text;
    }

    function enter() {
        if (field.buffer === "" || field.checking || !link)
            return;
        if (role === "create" && first === "") {
            first = field.buffer;
            field.buffer = "";
        } else if (role === "create" && field.buffer !== first) {
            refuse("the passwords differ");
        } else {
            field.checking = true;
            tell(link, {password: field.buffer});
        }
    }

    function heard(socket, line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (e) {
            return;
        }
        // A line that is JSON and no message, such as null.
        if (!message)
            return;
        if (message.event === "prompt") {
            // One at a time: the one on show gives way.
            if (link && link !== socket)
                tell(link, {cancel: true});
            granted.stop();
            failed.stop();
            field.clear();
            first = "";
            status = "";
            role = message.role;
            collection = message.collection;
            link = socket;
            field.forceActiveFocus();
            if (locked)
                cancel();
        } else if (socket !== link) {
            return;
        } else if (message.event === "retry") {
            // oo7's words for it are a sentence, and translated.
            refuse(role === "unlock" ? "wrong password" : message.reason);
        } else if (message.event === "done") {
            field.succeed();
            first = "";
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

    // polkit's prompt's, for niri's rule for it.
    WlrLayershell.namespace: "quickshell-auth"

    Column {
        id: column
        x: keyring.pad
        y: keyring.pad
        width: keyring.boxWidth - 2 * keyring.pad
        spacing: Theme.popupGridGap

        PopupText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.glyph(0xf084)
            font.pixelSize: 44
            color: Theme.white
        }

        PopupText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: keyring.role === "create" ? `A password for the new keyring “${keyring.collection}”` : `Unlock the keyring “${keyring.collection}”`
            wrapMode: Text.Wrap
        }

        PasswordField {
            id: field
            width: parent.width
            placeholder: keyring.role !== "create" ? "password" : keyring.first === "" ? "new password" : "the password again"
            onEntered: keyring.enter()
            onCancelled: keyring.cancel()
            onEdited: typed => {
                if (typed)
                    keyring.status = "";
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
