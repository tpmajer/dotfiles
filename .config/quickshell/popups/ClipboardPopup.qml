import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

// The newest entries of the clipboard's history: a click copies one back
// and closes the popup, a right click deletes it. By the title, as in the
// notification center, the button that clears the history: it takes a
// second click, so that a stray one does not.
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

    Item {
        width: popup.rowWidth
        height: title.implicitHeight + 8

        PopupText {
            id: title
            x: Theme.popupTextInset
            anchors.verticalCenter: parent.verticalCenter
            text: "Clipboard"
        }

        PopupButton {
            visible: Clipboard.entries.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: popup.armed ? "Clear all?" : "Clear"
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
    }

    // ScriptModel by id (each refresh parses the entries into new objects):
    // an entry deleted here takes its row alone, the others stay.
    Repeater {
        model: ScriptModel {
            values: Clipboard.entries.slice(0, 8)
            objectProp: "id"
        }

        ClipboardRow {
            required property var modelData
            required property int index
            width: popup.rowWidth
            entry: modelData
            // The newest is what the clipboard holds, unless it was cleared.
            bright: index === 0 && Clipboard.current !== ""
            onTriggered: {
                Clipboard.copy(modelData);
                popup.host.dismiss();
            }
            onSecondaryTriggered: Clipboard.remove(modelData)
        }
    }

    PopupText {
        visible: Clipboard.entries.length === 0
        x: Theme.popupTextInset
        text: "Clipboard is empty"
        color: Theme.subtext0
        font.pixelSize: Theme.fontSize - 2
    }

    // Not armed for long: a click much later is not the second one.
    Timer {
        id: disarm
        interval: 3000
        onTriggered: popup.armed = false
    }
}
