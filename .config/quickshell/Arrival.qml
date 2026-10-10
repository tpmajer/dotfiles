import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// The session's first moments after a login: a curtain in niri's backdrop
// colour over everything, lifted in a fade once the wallpaper is there.
Scope {
    id: root

    // niri's socket, one per niri: the session the curtain was last drawn in
    // is kept, so a later start of the shell in it draws none.
    readonly property string session: Quickshell.env("NIRI_SOCKET") ?? ""
    property bool drawn: false
    property bool lifting: false

    FileView {
        id: last
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-arrived"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: drawn = session !== "" && last.text().trim() !== session

    // The curtain's first frame is on the screen. awww-daemon waits for this
    // (~/.nixos, session.nix), so the wallpaper comes under the curtain.
    function onScreen() {
        if (last.text().trim() === session)
            return;
        last.setText(session + "\n");
        wallpaper.running = true;
        patience.start();
    }

    function lift() {
        patience.stop();
        again.stop();
        lifting = true;
    }

    // Asked until awww shows an image, then a moment for it to be drawn.
    Process {
        id: wallpaper
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.lifting)
                    return;
                if (/currently displaying: image: /.test(text))
                    settle.start();
                else
                    again.start();
            }
        }
    }

    Timer {
        id: again
        interval: 100
        onTriggered: wallpaper.running = true
    }

    Timer {
        id: settle
        interval: 250
        onTriggered: root.lift()
    }

    // No wallpaper, and the curtain is lifted all the same.
    Timer {
        id: patience
        interval: 4000
        onTriggered: root.lift()
    }

    // Nothing reaches it: the pointer and the keys go to what is under it.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            visible: root.drawn
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-arrival"
            mask: Region {}

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Shown is not drawn yet: the grab is done with the first frame.
            onBackingWindowVisibleChanged: {
                if (!backingWindowVisible)
                    return;
                if (!probe.grabToImage(() => root.onScreen()))
                    root.onScreen();
            }

            Item {
                id: probe
                width: 1
                height: 1
            }

            Rectangle {
                id: shade
                anchors.fill: parent
                color: Theme.base
                opacity: root.lifting ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                        onRunningChanged: if (!running && root.lifting)
                            root.drawn = false
                    }
                }
            }
        }
    }
}
