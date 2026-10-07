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
PanelWindow {
    id: menu

    property bool shown: false
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

    readonly property var results: !dmenu ? Apps.search(input.text) : input.text.trim() ? lines.filter(l => Apps.score(input.text, l) > 0) : lines
    onResultsChanged: {
        index = 0;
        list.positionViewAtBeginning();
    }

    // A little larger than the bar's.
    readonly property int fontSize: Theme.fontSize + 2
    readonly property int boxWidth: 620
    readonly property int inputHeight: 40
    readonly property int rowHeight: 34
    readonly property int maxRows: 12
    function heightFor(rows) {
        return 2 * Theme.popupPadding + inputHeight + (rows ? Theme.popupSectionGap + rows * rowHeight : 0);
    }
    property real boxHeight: heightFor(Math.min(results.length, maxRows))
    // Not while it opens: it opens at the size of what it shows.
    Behavior on boxHeight {
        enabled: menu.shown && menu.backingWindowVisible
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    Pop {
        id: pop
        shown: menu.shown
        mapped: menu.backingWindowVisible
    }

    // Where the pointer was last seen over a row.
    property var pointer: null

    function open() {
        input.text = "";
        index = 0;
        pointer = null;
        shown = true;
        input.forceActiveFocus();
    }

    function close() {
        answer(null);
        shown = false;
    }

    function toggle() {
        if (shown) {
            close();
            return;
        }
        dmenu = false;
        open();
    }

    // A question from scripts/dmenu/fuzzel: the lines of a file to choose
    // from, the answer to a FIFO.
    function ask(file, fifo, prompt, hidden) {
        answer(null);
        feed.path = file;
        feed.reload();
        const text = feed.text();
        lines = text ? text.replace(/\n$/, "").split("\n") : [];
        placeholder = prompt;
        password = hidden;
        dmenu = true;
        reply = fifo;
        open();
    }

    // "+" and the line chosen, or "-" for none.
    function answer(line) {
        if (!reply)
            return;
        Quickshell.execDetached(["sh", "-c", '[ -p "$1" ] && printf "%s\\n" "$2" > "$1"', "sh", reply, line === null ? "-" : "+" + line]);
        reply = "";
    }

    function accept() {
        const item = results[index];
        if (dmenu)
            answer(item ?? input.text);
        else if (item)
            Apps.launch(item);
        else if (input.text.trim())
            Apps.run(input.text);
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

    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The blur and its resending are the power menu's; see PowerMenu.
    readonly property bool blurred: pop.openness > 0.5
    BackgroundEffect.blurRegion: Region {
        x: content.x
        y: content.y
        width: menu.blurred ? content.width : 0
        height: menu.blurred ? content.height : 0
        radius: Theme.barRadius

        Region {
            x: content.x + Theme.barRadius
            y: content.y + Theme.barRadius
            width: menu.blurred ? 1 : 0
            height: 1 + menu.blurResend % 2
        }
    }

    property int blurResend: 0
    onBlurredChanged: if (blurred) {
        blurResendTimer.left = 8;
        blurResendTimer.restart();
    }
    Timer {
        id: blurResendTimer
        property int left: 0
        interval: 48
        repeat: true
        onTriggered: {
            menu.blurResend++;
            if (--left <= 0)
                stop();
        }
    }

    // A click beside the launcher closes it.
    MouseArea {
        anchors.fill: parent
        onClicked: menu.close()
    }

    // Only as large as the launcher and its shadow, as in the power menu.
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
        // The line to type in stays where it is while the list below it
        // grows and shrinks: the top is that of a full list, centered.
        x: Theme.snap((parent.width - width) / 2, menu.devicePixelRatio)
        y: Theme.snap((parent.height - menu.heightFor(menu.maxRows)) / 2, menu.devicePixelRatio)
        width: menu.boxWidth
        height: menu.boxHeight
        opacity: pop.openness
        scale: pop.scale
        clip: true

        // A click inside does not close.
        MouseArea {
            anchors.fill: parent
        }

        PopupText {
            font.pixelSize: menu.fontSize
            id: prompt
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

            PopupText {
                font.pixelSize: menu.fontSize
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: menu.dmenu ? menu.placeholder : ""
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
            boundsBehavior: Flickable.StopAtBounds
            model: menu.results
            currentIndex: menu.index
            highlightMoveDuration: 0

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: index === menu.index

                width: list.width
                height: menu.rowHeight
                radius: Theme.moduleRadius
                color: selected ? Theme.surface0 : Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0)
                Behavior on color {
                    ColorAnimation { duration: Theme.hoverDuration }
                }

                IconImage {
                    id: icon
                    visible: !menu.dmenu
                    x: Theme.popupTextInset
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 22
                    source: menu.dmenu ? "" : Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                }

                PopupText {
                    font.pixelSize: menu.fontSize
                    id: name
                    anchors.verticalCenter: parent.verticalCenter
                    x: menu.dmenu ? Theme.popupTextInset : icon.x + icon.width + Theme.popupColumnGap
                    width: Math.min(implicitWidth, row.width - x - Theme.popupTextInset)
                    elide: Text.ElideRight
                    // The letters that answer what is typed stand out, as
                    // in fuzzel.
                    textFormat: Text.StyledText
                    text: Apps.styled(input.text, menu.dmenu ? row.modelData : row.modelData.name, row.selected ? Theme.peach : Theme.teal)
                    // Lines from outside are laid out in columns.
                    font.family: menu.dmenu ? Theme.monoFont : Theme.font
                    color: row.selected ? Theme.text : Theme.subtext0
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverDuration }
                    }
                }

                PopupText {
                    font.pixelSize: menu.fontSize
                    visible: !menu.dmenu
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: name.right
                        leftMargin: Theme.popupColumnGap
                        right: parent.right
                        rightMargin: Theme.popupTextInset
                    }
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: menu.dmenu ? "" : row.modelData.genericName
                    color: Theme.surface1
                }

                // The pointer selects by moving, not by lying where a row
                // comes up, which is reported as a move too.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: mouse => {
                        const at = mapToItem(null, mouse.x, mouse.y);
                        if (menu.pointer && (at.x !== menu.pointer.x || at.y !== menu.pointer.y))
                            menu.index = row.index;
                        menu.pointer = at;
                    }
                    onClicked: {
                        menu.index = row.index;
                        menu.accept();
                    }
                }
            }
        }
    }
}
