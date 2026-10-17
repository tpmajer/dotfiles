import QtQuick
import qs
import qs.services
import qs.widgets

// The newest entries of the clipboard's history: a click copies one back
// and closes the popup, a right click deletes it. Clearing the history
// takes a second click, so that a stray one does not.
Column {
    id: popup

    required property var host   // the PopupHost, which opens and closes the popup
    readonly property bool hasRows: true
    readonly property int rowWidth: 380
    property bool armed: false
    // When it was armed: a double click is not two clicks.
    property real armedAt: 0
    spacing: Theme.popupRowGap

    // Disarmed as the popup opens or closes.
    Connections {
        target: popup.host
        function onPopupOpenChanged() {
            popup.armed = false;
        }
    }

    Repeater {
        model: Clipboard.entries.slice(0, 8)

        ClipboardRow {
            required property var modelData
            required property int index
            width: popup.rowWidth
            entry: modelData
            bright: index === 0
            onTriggered: {
                Clipboard.copy(modelData);
                popup.host.dismiss();
            }
            onSecondaryTriggered: Clipboard.remove(modelData)
        }
    }

    // Inset as a row's text is: the popup has none of its own around rows.
    PopupText {
        visible: Clipboard.entries.length === 0
        leftPadding: Theme.popupTextInset
        rightPadding: Theme.popupTextInset
        topPadding: Theme.popupTextInsetV
        bottomPadding: Theme.popupTextInsetV
        text: "Clipboard is empty"
        color: Theme.subtext0
    }

    PopupButton {
        visible: Clipboard.entries.length > 0
        x: popup.rowWidth - width
        text: popup.armed ? "Clear all?" : "Clear history"
        bright: popup.armed
        font.pixelSize: Theme.fontSize - 2
        onClicked: {
            if (!popup.armed) {
                popup.armed = true;
                popup.armedAt = Date.now();
                disarm.restart();
            } else if (Date.now() - popup.armedAt > Qt.styleHints.mouseDoubleClickInterval) {
                disarm.stop();
                popup.armed = false;
                Clipboard.wipe();
            }
        }
    }

    // Not armed for long: a click much later is not the second one.
    Timer {
        id: disarm
        interval: 3000
        onTriggered: popup.armed = false
    }
}
