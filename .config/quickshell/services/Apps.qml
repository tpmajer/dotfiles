pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The applications the launcher lists, and how often each was started.
Singleton {
    id: root

    readonly property var listed: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    // Without those whose program is gone, as a removed program's entries.
    readonly property var entries: listed.filter(e => !missing.includes(e.command[0]))

    // The commands of the listed entries that are not there to run.
    property var missing: []
    onListedChanged: check.restart()
    Timer {
        id: check
        interval: 200
        onTriggered: which.running = true
    }
    Process {
        id: which
        command: ["sh", "-c", 'for c; do command -v "$c" > /dev/null || echo "$c"; done', "sh"].concat([...new Set(root.listed.map(e => e.command[0]).filter(c => c))])
        stdout: StdioCollector {
            onStreamFinished: root.missing = text.split("\n").filter(l => l)
        }
    }

    // Starts by desktop entry id, kept across restarts.
    property var counts: ({})
    FileView {
        id: store
        path: Quickshell.statePath("launcher.json")
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        try {
            counts = JSON.parse(store.text());
        } catch (e) {}
    }

    // How well a text answers one word, both in lower case; 0 if it does not.
    // Loosely, the word's letters in order are enough, as in fuzzel.
    function scoreWord(word, text, loose) {
        const at = text.indexOf(word);
        if (at === 0)
            return 100;
        if (at > 0)
            return /[\s._-]/.test(text[at - 1]) ? 80 : 60;
        if (!loose)
            return 0;
        let from = 0;
        for (const letter of word) {
            from = text.indexOf(letter, from) + 1;
            if (!from)
                return 0;
        }
        return 20;
    }

    // The same for a query of several words, each of which must be answered.
    function score(query, text, loose = true) {
        let sum = 0;
        for (const word of query.toLowerCase().split(/\s+/).filter(w => w)) {
            const s = scoreWord(word, text.toLowerCase(), loose);
            if (!s)
                return 0;
            sum += s;
        }
        return sum;
    }

    // Where in a text a query's words fall, as scoreWord finds them loosely.
    function marks(query, text) {
        const lower = text.toLowerCase();
        const hit = new Set();
        for (const word of query.toLowerCase().split(/\s+/).filter(w => w)) {
            const at = lower.indexOf(word);
            const found = [];
            let from = 0;
            for (const letter of at < 0 ? word : "") {
                from = lower.indexOf(letter, from) + 1;
                if (!from)
                    break;
                found.push(from - 1);
            }
            for (let i = 0; at >= 0 && i < word.length; i++)
                found.push(at + i);
            if (found.length === word.length)
                found.forEach(i => hit.add(i));
        }
        return hit;
    }

    // The text as Text.StyledText, with those places in a color. Spaces
    // are kept: lines from outside are laid out with them.
    function styled(query, text, color) {
        const hit = marks(query, text);
        const escape = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;");
        let out = "";
        let start = 0;
        for (let i = 1; i <= text.length; i++) {
            if (i < text.length && hit.has(i) === hit.has(start))
                continue;
            const run = escape(text.slice(start, i));
            out += hit.has(start) ? '<font color="' + color + '">' + run + "</font>" : run;
            start = i;
        }
        return out;
    }

    // An entry by its name first, then by what else describes it, which is
    // long enough to hold any letters in order.
    function scoreEntry(query, entry) {
        const other = [entry.keywords.join(" "), entry.categories.join(" "), entry.command[0] ?? ""].join(" ");
        return Math.max(score(query, entry.name), 0.7 * score(query, entry.genericName, false), 0.7 * score(query, entry.id, false), 0.5 * score(query, other, false));
    }

    // The entries that answer a query, best first; all of them for none.
    // Those started more often come first among equals.
    function search(query) {
        const started = e => Math.min(counts[e.id] ?? 0, 10);
        const byName = (a, b) => a.name.localeCompare(b.name);
        if (!query.trim())
            return entries.slice().sort((a, b) => started(b) - started(a) || byName(a, b));
        return entries.map(e => ({entry: e, score: scoreEntry(query, e)})).filter(r => r.score > 0).map(r => ({entry: r.entry, score: r.score + started(r.entry)})).sort((a, b) => b.score - a.score || byName(a.entry, b.entry)).map(r => r.entry);
    }

    // Started by niri, so that nothing started here ends with quickshell.
    function launch(entry) {
        counts = Object.assign({}, counts, {[entry.id]: (counts[entry.id] ?? 0) + 1});
        store.setText(JSON.stringify(counts));
        const command = Array.from(entry.command);
        Niri.send({Action: {Spawn: {command: entry.runInTerminal ? ["ghostty", "-e"].concat(command) : command}}});
    }

    // A command line as typed.
    function run(line) {
        Niri.send({Action: {SpawnSh: {command: line}}});
    }
}
