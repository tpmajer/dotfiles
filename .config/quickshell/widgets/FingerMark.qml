import QtQuick
import qs

// The fingerprint reader's icon: there while the reader waits for a finger,
// red for one it did not recognise, green for one it did. It keeps its
// place when not shown, so nothing moves.
PopupText {
    id: root

    // "" not asked, "waiting", "bad" or "ok".
    property string mark: ""
    property bool animated: true

    text: Theme.glyph(0xf0237)
    font.pixelSize: 44
    opacity: mark === "" ? 0 : 1
    color: mark === "ok" ? Theme.green : mark === "bad" ? Theme.red : Theme.subtext0

    Behavior on opacity {
        enabled: root.animated
        NumberAnimation {
            duration: 150
        }
    }
    Behavior on color {
        enabled: root.animated
        ColorAnimation {
            duration: 150
        }
    }
}
