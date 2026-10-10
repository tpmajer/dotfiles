import QtQuick
import qs

// A prompt's password field: a mark per character typed, as on the lock, and
// the keys that type it. What it holds is its owner's to send: Enter and Esc
// are only told.
Rectangle {
    id: field

    property string buffer: ""
    // Sent, not answered yet: no key but Esc is taken.
    property bool checking: false
    // Entered, and waiting to be sent: the marks pulse as when checking.
    property bool pending: false
    // What is typed may be seen, as a second factor's code.
    property bool plain: false
    // What the empty field says.
    property string placeholder: "password"
    // The marks, kept green or red for a moment after the answer.
    property int frozenMarks: -1
    property bool accepted: false
    property bool rejected: false
    readonly property int marks: frozenMarks >= 0 ? frozenMarks : buffer.length

    signal entered
    signal cancelled
    // A character typed, or one erased.
    signal edited(bool typed)

    // What was typed is not kept past its use.
    function forget() {
        buffer = "";
        checking = false;
    }

    // As new, for another question.
    function clear() {
        rejectionShown.stop();
        forget();
        frozenMarks = -1;
        accepted = false;
        rejected = false;
    }

    // The marks turn green, and stay so.
    function succeed() {
        frozenMarks = buffer.length;
        accepted = true;
        forget();
    }

    // The marks turn red for a moment.
    function refuse() {
        frozenMarks = buffer.length;
        rejected = true;
        rejectionShown.restart();
        forget();
    }

    height: 40
    radius: Theme.moduleRadius
    color: Theme.surface0
    focus: true

    Timer {
        id: rejectionShown
        interval: 800
        onTriggered: {
            field.rejected = false;
            field.frozenMarks = -1;
        }
    }

    Keys.onPressed: event => {
        event.accepted = true;
        if (event.key === Qt.Key_Escape) {
            field.cancelled();
            return;
        }
        if (field.checking || field.accepted)
            return;
        // A key during the red marks starts the next attempt.
        if (field.rejected) {
            rejectionShown.stop();
            field.rejected = false;
            field.frozenMarks = -1;
        }
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            field.entered();
            break;
        case Qt.Key_Backspace:
            field.buffer = event.modifiers & Qt.ControlModifier ? "" : field.buffer.slice(0, -1);
            field.edited(false);
            break;
        default:
            // Printable characters only.
            if (event.text.length > 0 && event.text >= " " && event.text !== "\x7f") {
                field.buffer += event.text;
                field.edited(true);
            }
        }
    }

    PopupText {
        anchors.centerIn: parent
        visible: field.marks === 0
        text: field.checking ? "checking…" : field.placeholder
        color: Theme.subtext0
    }

    PopupText {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 2 * Theme.popupTextInset)
        elide: Text.ElideLeft
        visible: field.plain
        text: field.buffer
        opacity: marksRow.opacity
    }

    Marks {
        id: marksRow
        visible: !field.plain
        marks: field.marks
        checking: field.checking || field.pending
        accepted: field.accepted
        rejected: field.rejected
        most: 22
    }
}
