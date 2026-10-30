import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The way out of the session: the screens fade to the colour the VT and the
// login screen have (~/.nixos, notes/greeter.md), then niri quits.
Scope {
    id: root

    property bool fading: false
    property real shade: 0

    function start() {
        if (fading)
            return;
        fading = true;
        fade.start();
    }

    NumberAnimation {
        id: fade
        target: root
        property: "shade"
        to: 1
        duration: 200
        easing.type: Easing.InOutSine
        onFinished: {
            Quickshell.execDetached(["niri", "msg", "action", "quit", "-s"]);
            stillHere.start();
        }
    }

    // niri did not quit: the screens come back.
    Timer {
        id: stillHere
        interval: 3000
        onTriggered: {
            root.fading = false;
            root.shade = 0;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            visible: root.fading
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-logout-fade"
            mask: Region {}

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.colors.crust
                opacity: root.shade
            }
        }
    }

    IpcHandler {
        target: "logout"

        function start(): void {
            root.start();
        }
    }
}
