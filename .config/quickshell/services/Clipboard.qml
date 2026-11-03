pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The clipboard's history, which cliphist keeps (its watchers are in
// ~/.nixos, modules/session.nix), and what the clipboard holds now.
Singleton {
    id: root

    // Newest first, as parse() makes them.
    property var entries: []
    // "text" or "image", or "" with the clipboard cleared.
    property string current: ""
    // For the module's color: what the clipboard holds, or else the newest
    // entry; "" only with both empty.
    readonly property string kind: current || (entries.length ? (entries[0].image ? "image" : "text") : "")
    // The thumbnails decoded so far, by file name.
    property var thumbs: ({})
    property bool decodeQueued: false

    readonly property string thumbDir: Quickshell.cachePath("clipboard")

    // A line of `cliphist list`, "<id>\t<preview>"; an image's preview is
    // "[[ binary data <size> <format> <width>x<height> ]]". `text` is
    // what is shown and searched: for an image, its format and size.
    function parse(line) {
        const tab = line.indexOf("\t");
        const preview = line.slice(tab + 1);
        const image = /^\[\[ binary data .* (\w+) (\d+)x(\d+) \]\]$/.exec(preview);
        return {
            clipboard: true,
            id: line.slice(0, tab),
            line: line,
            image: !!image,
            format: image ? image[1] : "",
            text: image ? image[1].toUpperCase() + " " + image[2] + "×" + image[3] : preview
        };
    }

    // An image entry's thumbnail as a URL, or "" until it is decoded.
    function thumbnail(entry) {
        const name = entry.id + "." + entry.format;
        return thumbs[name] ? "file://" + thumbDir + "/" + name : "";
    }

    // The entries that answer a query, newest first.
    function search(query) {
        return query.trim() ? entries.filter(e => Apps.score(query, e.text) > 0) : entries;
    }

    // Back to the clipboard; the watchers put it at the top of the history.
    // Started by niri: wl-copy holds the clipboard and must outlive quickshell.
    function copy(entry) {
        Niri.send({Action: {Spawn: {command: ["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", entry.id]}}});
    }

    // Gone from the list at once; the history read after it agrees. If the
    // clipboard holds the same, it is cleared too, as wipe() does.
    function remove(entry) {
        entries = entries.filter(e => e.id !== entry.id);
        run(["sh", "-c", 'a=$(cliphist decode "$2" | md5sum); b=$(wl-paste --no-newline --type "$3" 2>/dev/null | md5sum); printf "%s\\n" "$1" | cliphist delete; [ "$a" != "$b" ] || wl-copy --clear', "sh", entry.line, entry.id, entry.image ? "image/png" : "text"]);
    }

    // The clipboard too: nothing of it is left to paste.
    function wipe() {
        entries = [];
        thumbs = {};
        current = "";
        run(["sh", "-c", 'cliphist wipe; wl-copy --clear; rm -rf -- "$1"', "sh", thumbDir]);
    }

    // A command that changes the history, which is read again after it.
    Component {
        id: job

        Process {
            running: true
            onExited: {
                refresh.restart();
                destroy();
            }
        }
    }
    function run(command) {
        job.createObject(root, {command: command});
    }

    // The clipboard's changes, seen as cliphist's watchers see them: the
    // history is read again once they have had the time to store it.
    function changed(state, kind) {
        current = state === "nil" ? "" : kind;
        refresh.restart();
    }
    Watcher {
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c", 'cat > /dev/null; echo "$CLIPBOARD_STATE"']
        stdout: SplitParser {
            onRead: state => root.changed(state, "text")
        }
    }
    Watcher {
        command: ["wl-paste", "--type", "image/png", "--watch", "sh", "-c", 'cat > /dev/null; echo "$CLIPBOARD_STATE"']
        stdout: SplitParser {
            onRead: state => root.changed(state, "image")
        }
    }

    Timer {
        id: refresh
        interval: 300
        onTriggered: {
            if (list.running)
                restart();
            else
                list.running = true;
        }
    }
    Component.onCompleted: list.running = true

    // Without a database yet, cliphist lists nothing (and says so on stderr).
    // One it could not open in time is "failed": the entries stay as they are.
    // Previews are longer than its default, for the search.
    Process {
        id: list
        command: ["sh", "-c", 'cliphist -preview-width 300 list || { [ -e "${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/db" ] && echo failed; }']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                if (lines.includes("failed"))
                    return;
                root.entries = lines.filter(l => l.includes("\t")).map(root.parse);
                root.decode();
            }
        }
    }

    // Thumbnails for the images listed, at full size, and none for the rest.
    function decode() {
        if (thumbJob.running) {
            decodeQueued = true;
            return;
        }
        const names = entries.filter(e => e.image).map(e => e.id + "." + e.format);
        const script = ['dir=$1; shift; mkdir -p "$dir" && cd "$dir" || exit',
            'for f in *; do case " $* " in *" $f "*) ;; *) rm -f -- "$f" ;; esac; done',
            'for f; do [ -s "$f" ] || { cliphist decode "${f%%.*}" > "$f.tmp" && mv -- "$f.tmp" "$f"; }; [ -s "$f" ] && echo "$f"; done'].join("\n");
        thumbJob.command = ["sh", "-c", script, "sh", thumbDir].concat(names);
        thumbJob.running = true;
    }
    Process {
        id: thumbJob
        stdout: StdioCollector {
            onStreamFinished: {
                const thumbs = {};
                for (const name of text.split("\n").filter(n => n))
                    thumbs[name] = true;
                root.thumbs = thumbs;
            }
        }
        onExited: {
            if (root.decodeQueued) {
                root.decodeQueued = false;
                root.decode();
            }
        }
    }
}
