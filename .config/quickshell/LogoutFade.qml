import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.lock

// The way out of the session: the lock's blurred wallpaper comes up, as before
// a suspend, then the screens fade to the colour the VT and the login screen
// have (~/.nixos, notes/greeter.md), then session-logout starts
// the login screen and quits niri; without it, niri quits at once.
Scope {
    id: root

    // Output name -> URL of its wallpaper (Wallpapers.qml).
    property var wallpapers: ({})
    property bool fading: false
    // How far the wallpaper has come up, 0 to 1.
    property real rise: 0
    property real shade: 0

    function start() {
        if (fading)
            return;
        fading = true;
        fade.start();
    }

    // The times of a suspend's (Lock.qml).
    SequentialAnimation {
        id: fade
        NumberAnimation {
            target: root
            property: "rise"
            to: 1
            duration: 500
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "shade"
            to: 1
            duration: 800
            easing.type: Easing.InOutSine
        }
        onFinished: {
            Quickshell.execDetached(["sh", "-c", "session-logout || niri msg action quit -s"]);
            stillHere.start();
        }
    }

    // niri did not quit: the screens come back.
    Timer {
        id: stillHere
        interval: 15000
        onTriggered: {
            root.fading = false;
            root.rise = 0;
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

            LockView {
                anchors.fill: parent
                wallpaper: root.wallpapers[modelData?.name ?? ""] ?? ""
                animated: false
                concealed: true
                opacity: root.rise
                // Fades as one picture, not layer by layer.
                layer.enabled: opacity < 1
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
