pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs

// What plays, over MPRIS: Spotify, a browser's tab (YouTube told from
// the rest), mpv. One player is the active one, which the bar's wave and
// its popup are about: the one that started to play last, or the one
// picked in the popup.
Singleton {
    id: root

    // playerctld mirrors the other players; it is not one itself.
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.endsWith(".playerctld"))

    // Null with nothing playing, once the last one has been paused for
    // a while.
    property var active: null
    readonly property bool playing: !!active && active.isPlaying

    readonly property string source: sourceOf(active)
    readonly property color color: colorOf(active)

    // Spotify plays on a Connect device: it says it plays, and nothing
    // sounds here. Its stream is no telling, it stays open there.
    readonly property bool remote: source === "spotify" && playing && Spectrum.silent

    readonly property string title: active ? active.trackTitle || active.identity : ""
    readonly property string artist: active ? active.trackArtist : ""
    readonly property string album: active ? active.trackAlbum : ""
    readonly property string artUrl: active ? active.trackArtUrl : ""

    function sourceOf(player) {
        const name = player ? player.dbusName.replace("org.mpris.MediaPlayer2.", "") : "";
        if (/^spotify/.test(name))
            return "spotify";
        // A browser gives the page's site as the track's address.
        if (/^(firefox|chromium|chrome)/.test(name))
            return /^https?:\/\/([^\/]*\.)?(youtube\.com|youtu\.be)(\/|$)/.test(player.metadata["xesam:url"] ?? "") ? "youtube" : "browser";
        if (/^mpv/.test(name))
            return "mpv";
        return "other";
    }

    function colorOf(player) {
        return ({
                spotify: Theme.green,
                youtube: Theme.red,
                mpv: Theme.teal
            })[sourceOf(player)] ?? Theme.text;
    }

    function glyphOf(player) {
        return Theme.glyph(({
                spotify: 0xf04c7,
                youtube: 0xf05c3,
                browser: 0xf059f,
                mpv: 0xf0381
            })[sourceOf(player)] ?? 0xf075a);
    }

    function playPause() {
        if (active && active.canTogglePlaying)
            active.togglePlaying();
    }

    // mpv plays a file of the disk with no playlist: the next one and the
    // previous one are then the files beside it, as with uosc's keys in
    // mpv itself.
    function besideFiles(player) {
        return sourceOf(player) === "mpv" && !player.canGoNext && !player.canGoPrevious && String(player.metadata["xesam:url"] ?? "").startsWith("file://");
    }

    // Whether the player has a next track (1) or a previous one (-1) to
    // go to. Beside a file there may be none; that is found out on the go.
    function canSkip(player, step) {
        return !!player && ((step > 0 ? player.canGoNext : player.canGoPrevious) || besideFiles(player));
    }

    // To the next track (1) or the previous one (-1).
    function skip(steps) {
        if (!active || steps === 0)
            return;
        const step = steps > 0 ? 1 : -1;
        if (!canSkip(active, step))
            return;
        if (besideFiles(active))
            sibling.ask(active, step);
        else if (step > 0)
            active.next();
        else
            active.previous();
    }

    // The same by the wheel, one track a swipe however fast it turns: a
    // touchpad sends a run of steps for one. Not for a button, which may
    // well be clicked twice in that time.
    function scroll(steps) {
        if (steps === 0 || skipGuard.running)
            return;
        skip(steps);
        skipGuard.restart();
    }

    // scripts/media-sibling.py: the address of the file to go to, if any.
    // One search at a time. Steps asked for meanwhile are taken next, from
    // the file this search got to: the player still names the old one.
    // Another player's wait for their turn.
    Process {
        id: sibling
        property var player: null
        property string from: ""
        property int waiting: 0
        property var other: null

        function ask(player, step) {
            if (!running && !next.running)
                look(player, String(player.metadata["xesam:url"]), step);
            else if (player === sibling.player)
                waiting += step;
            else
                other = {player: player, step: step};
        }

        function look(player, from, step) {
            sibling.player = player;
            sibling.from = from;
            command = [Quickshell.shellDir + "/scripts/media-sibling.py", from, String(step)];
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const address = text.trim();
                if (address && root.players.includes(sibling.player)) {
                    sibling.player.openUri(address);
                    sibling.from = address;
                }
                next.restart();
            }
        }
    }

    // What was asked for during a search, once its process is gone.
    Timer {
        id: next
        interval: 10
        onTriggered: {
            if (sibling.running) {
                restart();
            } else if (sibling.waiting !== 0 && root.players.includes(sibling.player)) {
                const step = sibling.waiting;
                sibling.waiting = 0;
                sibling.look(sibling.player, sibling.from, step);
            } else if (sibling.other && root.players.includes(sibling.other.player)) {
                const asked = sibling.other;
                sibling.waiting = 0;
                sibling.other = null;
                sibling.ask(asked.player, asked.step);
            } else {
                sibling.waiting = 0;
                sibling.other = null;
            }
        }
    }

    // From the popup's list. It stays the active one until another
    // starts to play.
    function select(player) {
        active = player;
        if (player.isPlaying)
            linger.stop();
        else
            linger.restart();
    }

    // To the player's window, wherever it is. A browser's window, not
    // the tab that plays. The window is looked for by the desktop entry
    // the player names, then by the name it has on the bus (firefox of
    // org.mpris.MediaPlayer2.firefox.instance_1_23), which a browser's
    // differs from: Chrome and Chromium are both chromium there.
    function focusWindow() {
        if (!active)
            return;
        const name = active.dbusName.replace("org.mpris.MediaPlayer2.", "").split(".")[0];
        const ids = [active.desktopEntry, name];
        if (/^(chromium|chrome)/.test(name))
            ids.push("google-chrome", "chromium-browser", "chromium");
        ids.filter(id => id).some(id => Niri.focusApp(id));
    }

    // A player started or stopped playing, or came or went.
    function update(player) {
        if (player && player.isPlaying) {
            active = player;
            linger.stop();
            return;
        }
        if (active && !players.includes(active))
            active = null;
        if (active && active.isPlaying)
            return;
        // A paused one stays for its while, the one picked in the popup
        // too, whatever the others do short of starting to play.
        if (active && linger.running)
            return;
        const other = players.find(p => p.isPlaying);
        if (other) {
            active = other;
            linger.stop();
        } else if (active) {
            linger.restart();
        }
    }

    onPlayersChanged: update(null)

    // Over the players' own model, not the list above: one here is made
    // as its player shows up, and so tells of one that plays by then.
    Instantiator {
        model: Mpris.players

        Connections {
            required property var modelData
            readonly property bool own: !modelData.dbusName.endsWith(".playerctld")
            target: own ? modelData : null
            function onIsPlayingChanged() {
                root.update(modelData);
            }
            // A player is listed once it has said that it plays.
            Component.onCompleted: if (own && modelData.isPlaying)
                root.update(modelData)
        }
    }

    // How long a paused player stays in the bar. Then the bar is about
    // another that plays, if there is one.
    Timer {
        id: linger
        interval: 30000
        onTriggered: if (!root.playing)
            root.active = root.players.find(p => p.isPlaying) ?? null
    }

    Timer {
        id: skipGuard
        interval: 400
    }

    IpcHandler {
        target: "media"

        // For tests: `qs ipc call media state`.
        function state(): string {
            return JSON.stringify({
                players: root.players.map(p => p.dbusName),
                active: root.active ? root.active.dbusName : null,
                source: root.source,
                playing: root.playing,
                remote: root.remote,
                position: root.active ? root.active.position : 0,
                title: root.title,
                artist: root.artist
            });
        }
    }
}
