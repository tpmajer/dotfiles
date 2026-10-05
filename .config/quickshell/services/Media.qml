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

    // One track per call, however fast the wheel turns: a touchpad sends
    // a run of steps for one swipe.
    function skip(steps) {
        if (!active || steps === 0 || skipGuard.running)
            return;
        if (steps > 0 && active.canGoNext)
            active.next();
        else if (steps < 0 && active.canGoPrevious)
            active.previous();
        else
            return;
        skipGuard.restart();
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
    // the tab that plays.
    function focusWindow() {
        if (active)
            Niri.focusApp(active.desktopEntry || sourceOf(active));
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
