import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.widgets

// Launcher in the middle of the focused output (Super+Space in niri): a line
// to type in above the applications that answer it. It also stands in for
// `fuzzel --dmenu` (scripts/dmenu/fuzzel): lines to choose from, or a password.
// It also lists the clipboard's history (services/Clipboard.qml).
Overlay {
    id: menu

    property int index: 0
    // The session is locked.
    property bool locked: false
    onLockedChanged: if (locked)
        close()

    // Choosing from lines rather than applications; kept while it fades out.
    property bool dmenu: false
    property var lines: []
    property string placeholder: ""
    property bool password: false
    // The FIFO the question's answer goes to; "" once it is answered.
    property string reply: ""
    // Choosing from the clipboard's history.
    property bool clipboard: false

    readonly property var results: clipboard ? Clipboard.search(input.text) : !dmenu ? Apps.search(input.text) : input.text.trim() ? lines.filter(l => Apps.score(input.text, l) > 0) : lines
    // A new query, or the clipboard's history in place of the applications,
    // starts at the top. A list read again, as the history is after each
    // change, keeps the entry chosen wherever it moved, or with that one
    // gone the row; the view forgets either with its model.
    property var shown: ({results: [], query: ""})
    onResultsChanged: {
        const query = (clipboard ? "clipboard:" : "") + input.text;
        const was = shown.query === query ? shown.results[index] : undefined;
        const key = r => r?.id ?? r;
        const kept = was === undefined ? -1 : results.findIndex(r => key(r) === key(was));
        index = kept >= 0 ? kept : Math.min(index, Math.max(0, results.length - 1));
        shown = {results, query};
        Qt.callLater(() => list.currentIndex = Qt.binding(() => menu.index));
    }
    onClipboardChanged: index = 0

    // A little larger than the bar's.
    readonly property int fontSize: Theme.fontSize + 2
    boxWidth: 620
    readonly property int inputHeight: 40
    readonly property int rowHeight: 34
    readonly property int maxRows: 12
    function heightFor(rows) {
        return 2 * Theme.popupPadding + inputHeight + (rows ? Theme.popupSectionGap + rows * rowHeight : 0);
    }
    boxHeight: heightFor(Math.min(results.length, maxRows))
    // The line to type in stays where it is while the list below it grows
    // and shrinks: the top is that of a full list, centered.
    boxTop: (height - heightFor(maxRows)) / 2
    boxClip: true
    onOutsideClicked: close()
    // Not while it opens: it opens at the size of what it shows.
    Behavior on boxHeight {
        enabled: menu.shown && menu.backingWindowVisible
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }


    function open() {
        input.text = "";
        index = 0;
        shown = true;
        input.forceActiveFocus();
    }

    function close() {
        answer(null);
        forget();
        shown = false;
    }

    // A password is not kept in the hidden field until the next question.
    function forget() {
        if (dmenu && password)
            input.text = "";
    }

    function toggle() {
        if (shown) {
            close();
            return;
        }
        dmenu = false;
        clipboard = false;
        open();
    }

    // The clipboard's history (Super+Ctrl+V in niri, the bar's module), in
    // place of the applications; open on it, it closes. A question is kept.
    function toggleClipboard() {
        if (shown && dmenu)
            return;
        if (shown && clipboard) {
            close();
            return;
        }
        dmenu = false;
        clipboard = true;
        if (shown)
            input.text = "";
        else
            open();
    }

    // A question from scripts/dmenu/fuzzel: the lines of a file to choose
    // from, the answer to a FIFO.
    function ask(file, fifo, prompt, hidden) {
        answer(null);
        feed.path = file;
        feed.reload();
        // Without the wait it is still the question before.
        feed.waitForJob();
        const text = feed.text();
        lines = text ? text.replace(/\n$/, "").split("\n") : [];
        placeholder = prompt;
        password = hidden;
        dmenu = true;
        clipboard = false;
        reply = fifo;
        open();
    }

    // "+" and the line chosen, or "-" for none.
    function answer(line) {
        if (!reply)
            return;
        writer.createObject(menu, {fifo: reply, line: line === null ? "-" : "+" + line});
        reply = "";
    }

    // The answer goes to the FIFO by this one's input: a password is not
    // for a command line, which any process can read. Opened for reading
    // too, so that it does not wait forever for a script that was killed.
    Component {
        id: writer

        Process {
            required property string fifo
            required property string line
            command: ["sh", "-c", '[ -p "$1" ] && cat 1<> "$1"', "sh", fifo]
            stdinEnabled: true
            running: true
            onStarted: {
                write(line + "\n");
                stdinEnabled = false;
            }
            onExited: destroy()
        }
    }

    function accept() {
        const item = results[index];
        if (clipboard) {
            // Nothing typed is copied in place of an entry.
            if (!item)
                return;
            Clipboard.copy(item);
        } else if (dmenu)
            answer(item ?? input.text);
        else if (item && item.history) {
            // Not closed: the launcher goes on to the clipboard's history.
            input.text = "";
            clipboard = true;
            return;
        } else if (item)
            Apps.launch(item);
        else if (input.text.trim())
            Apps.run(input.text);
        forget();
        shown = false;
    }

    function move(by) {
        if (results.length)
            index = (index + by + results.length) % results.length;
    }

    FileView {
        id: feed
        blockLoading: true
        printErrors: false
    }

    WlrLayershell.namespace: "quickshell-launcher"

    PopupText {
        id: prompt
        font.pixelSize: menu.fontSize
        x: Theme.popupPadding + Theme.popupTextInset
        anchors.verticalCenter: input.verticalCenter
        text: "❯"
        color: Theme.green
    }

    TextInput {
        id: input
        anchors {
            left: prompt.right
            leftMargin: Theme.popupIconGap
            right: parent.right
            rightMargin: Theme.popupPadding + Theme.popupTextInset
        }
        y: Theme.popupPadding
        height: menu.inputHeight
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.text
        selectionColor: Theme.surface1
        selectedTextColor: Theme.text
        font.family: Theme.font
        font.pixelSize: menu.fontSize
        echoMode: menu.dmenu && menu.password ? TextInput.Password : TextInput.Normal
        onTextChanged: menu.index = 0

        PopupText {
            font.pixelSize: menu.fontSize
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: menu.clipboard ? "Search the clipboard" : menu.dmenu ? menu.placeholder : ""
            color: Theme.surface1
        }

        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            switch (event.key) {
            case Qt.Key_Down:
            case Qt.Key_Tab:
                menu.move(1);
                break;
            case Qt.Key_Up:
            case Qt.Key_Backtab:
                menu.move(-1);
                break;
            case Qt.Key_N:
            case Qt.Key_J:
                if (!ctrl)
                    return;
                menu.move(1);
                break;
            case Qt.Key_P:
            case Qt.Key_K:
                if (!ctrl)
                    return;
                menu.move(-1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                menu.accept();
                break;
            // An entry of the clipboard's history goes, as in a browser's
            // address bar.
            case Qt.Key_Delete:
                if (!menu.clipboard || !(event.modifiers & Qt.ShiftModifier) || !menu.results.length)
                    return;
                Clipboard.remove(menu.results[menu.index]);
                break;
            case Qt.Key_Escape:
                menu.close();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    ListView {
        id: list
        x: Theme.popupPadding
        y: Theme.popupPadding + menu.inputHeight + Theme.popupSectionGap
        width: parent.width - 2 * Theme.popupPadding
        height: Math.min(count, menu.maxRows) * menu.rowHeight
        clip: true
        // The wheel does not scroll it.
        interactive: false
        model: menu.results
        currentIndex: menu.index
        highlightMoveDuration: 0

        // A notch of the wheel is a row, as an arrow is, but it stops at
        // the list's ends.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => wheel.turn(event.angleDelta.y)
        }
        WheelSteps {
            id: wheel
            onStepped: rows => menu.index = Math.max(0, Math.min(menu.results.length - 1, menu.index - rows))
        }

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool selected: index === menu.index
            // Not menu.dmenu: it changes before the old rows are gone.
            readonly property bool line: typeof modelData === "string"
            // An entry of the clipboard's history.
            readonly property bool clip: !line && !!modelData.clipboard

            width: list.width
            height: menu.rowHeight
            radius: Theme.moduleRadius
            color: selected ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
            Behavior on color {
                ColorAnimation { duration: Theme.hoverDuration }
            }

            IconImage {
                id: icon
                visible: !row.line && !row.clip && !row.modelData.glyph
                x: Theme.popupTextInset
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 22
                source: visible ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
            }

            // An action has its glyph for an icon, as a text in the
            // clipboard's history has.
            PopupText {
                visible: !row.line && (row.clip ? !row.modelData.image : !!row.modelData.glyph)
                anchors.centerIn: icon
                font.pixelSize: 22
                text: visible ? Theme.glyph(row.clip ? 0xf15c : row.modelData.glyph) : ""
                color: visible && row.modelData.color || Theme.text
            }

            // An image in the clipboard's history, in the icon's place.
            Image {
                visible: row.clip && row.modelData.image
                anchors.centerIn: icon
                width: icon.width
                height: icon.height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 2 * width
                sourceSize.height: 2 * height
                source: visible ? Clipboard.thumbnail(row.modelData) : ""
            }

            PopupText {
                id: name
                font.pixelSize: menu.fontSize
                anchors.verticalCenter: parent.verticalCenter
                x: row.line ? Theme.popupTextInset : icon.x + icon.width + Theme.popupColumnGap
                width: Math.min(implicitWidth, row.width - x - Theme.popupTextInset)
                elide: Text.ElideRight
                // The letters that answer what is typed stand out, as
                // in fuzzel.
                textFormat: Text.StyledText
                text: Apps.styled(input.text, row.line ? row.modelData : row.clip ? row.modelData.text : row.modelData.name, row.selected ? Theme.teal : Theme.red)
                // Lines from outside are laid out in columns.
                font.family: row.line ? Theme.monoFont : Theme.font
                color: row.selected ? Theme.text : Theme.subtext0
                Behavior on color {
                    ColorAnimation { duration: Theme.hoverDuration }
                }
            }

            PopupText {
                font.pixelSize: menu.fontSize
                visible: !row.line && !row.clip
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: name.right
                    leftMargin: Theme.popupColumnGap
                    right: parent.right
                    rightMargin: Theme.popupTextInset
                }
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: row.line || row.clip ? "" : row.modelData.genericName
                color: Theme.surface1
            }

            // The pointer selects by moving, not by lying where a row
            // comes up.
            Connections {
                target: menu
                function onPointerMoved() {
                    if (rowMouse.containsMouse)
                        menu.index = row.index;
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    menu.index = row.index;
                    menu.accept();
                }
            }
        }
    }
}
