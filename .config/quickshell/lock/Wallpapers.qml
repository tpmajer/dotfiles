import QtQuick
import Quickshell
import Quickshell.Io

// The image awww shows on each output, which the lock shows blurred.
Scope {
    id: root

    // Output name -> URL of the image awww shows there.
    property var images: ({})

    function refresh() {
        query.running = true;
    }

    // Asked at startup and at every lock, and by what changes the wallpaper
    // (the `wallpaper` IPC): awww does not tell. Until an image is known it
    // is asked again every half a minute, for awww may start after this.
    Process {
        id: query
        command: ["awww", "query"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // ": eDP-1: 1800x1200, scale: 1.6, currently displaying: image: /path"
                // An output that is off is not listed at all: its image is
                // kept for the lock that is there when it comes back.
                const found = Object.assign({}, root.images);
                for (const line of text.split("\n")) {
                    const m = line.match(/^:?\s*(\S+): .*currently displaying: (?:image: (.+))?/);
                    if (!m)
                        continue;
                    if (m[2])
                        found[m[1]] = "file://" + m[2].split("/").map(encodeURIComponent).join("/");
                    else
                        delete found[m[1]];
                }
                // Unchanged: nothing is loaded again.
                if (JSON.stringify(found) !== JSON.stringify(root.images))
                    root.images = found;
            }
        }
    }

    Timer {
        interval: 30000
        running: Object.keys(root.images).length === 0
        repeat: true
        onTriggered: root.refresh()
    }

    // Keeps the wallpapers decoded while unlocked. A curtain loads its image
    // anew when its window is shown, and a lock surface is new each time: both
    // ask for the same file and get it from Qt's cache at once, as long as
    // something holds it there. The cache is keyed by the fill mode, hence the
    // same one here, and by sourceSize, which none of them sets: a window
    // scales it by a ratio that is not known out here.
    Variants {
        model: Quickshell.screens

        Image {
            required property ShellScreen modelData
            source: root.images[modelData?.name ?? ""] ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
