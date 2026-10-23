pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Command lines run from the launcher, the last first, kept across restarts.
Singleton {
    id: root

    // Typed first, it makes the rest a command line, not a search.
    readonly property string prefix: ":"
    readonly property int kept: 50

    property var history: []
    FileView {
        id: store
        path: Quickshell.statePath("commands.json")
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        try {
            history = JSON.parse(store.text());
        } catch (e) {}
    }

    function save(lines) {
        history = lines;
        store.setText(JSON.stringify(lines));
    }

    // A command line as a row of the launcher's list: "run" as typed,
    // "terminal" as typed but in Ghostty, or "history".
    function row(line, kind) {
        return {
            id: kind + ":" + line,
            name: line,
            genericName: ({run: "Run", terminal: "Ghostty", history: "History"})[kind],
            glyph: ({run: 0x276f, terminal: 0xf489, history: 0xf1da})[kind],
            color: kind === "history" ? Theme.subtext0 : Theme.green,
            shell: line,
            typed: kind !== "history",
            terminal: kind === "terminal"
        };
    }

    // The line typed, to run, then to run in a terminal.
    function typed(line) {
        return [row(line, "run"), row(line, "terminal")];
    }

    // The line typed, then the history's lines that answer it, the better
    // first, among equals the last run.
    function search(query) {
        const line = query.trim();
        const found = history.map((l, i) => ({line: l, i, score: line ? Apps.score(line, l, false) : 1})).filter(r => r.score > 0 && r.line !== line).sort((a, b) => b.score - a.score || a.i - b.i).map(r => row(r.line, "history"));
        return line ? typed(line).concat(found) : found;
    }

    // Started by niri; in a terminal the shell stays for what it printed.
    function run(line, terminal) {
        save([line].concat(history.filter(l => l !== line)).slice(0, kept));
        if (terminal)
            Niri.send({Action: {Spawn: {command: Apps.inTerminal(["fish", "-C", line])}}});
        else
            Apps.run(line);
    }

    function remove(line) {
        save(history.filter(l => l !== line));
    }
}
