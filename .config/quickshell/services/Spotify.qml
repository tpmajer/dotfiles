pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Spotify's own volume, over MPRIS. It is the speaker's volume when Spotify
// plays on a Connect device, where the audio outputs here have no say.
Singleton {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.dbusName.endsWith(".spotify")) ?? null
    readonly property bool ready: !!player && player.volumeSupported
    readonly property bool muted: ready && player.volume === 0
    readonly property int volume: ready ? Math.round(player.volume * 100) : 0
    // Spotify has no mute: muting sets the volume to 0 and keeps the old one here.
    property real unmuted: 0.3

    // One scroll step = 1%, capped at 100%.
    function changeVolume(steps) {
        if (ready)
            player.volume = Math.max(0, Math.min(1, (volume + steps) / 100));
    }

    function toggleMute() {
        if (!ready)
            return;
        if (muted) {
            player.volume = unmuted;
        } else {
            unmuted = player.volume;
            player.volume = 0;
        }
    }

    IpcHandler {
        target: "spotify"

        function toggleMute(): void {
            root.toggleMute();
        }
    }
}
