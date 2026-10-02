#!/usr/bin/env bash

# Volume keys: when Spotify plays on a Spotify Connect device (e.g. Mu-so),
# control Spotify's volume; otherwise control the default PipeWire sink.
# Usage: volume.sh up|down|mute

STEP_LOCAL="0.02"
STEP_SPOTIFY="0.03"
SAVED_VOLUME="${XDG_RUNTIME_DIR:-/tmp}/spotify-connect-volume"

# Spotify reports "Playing" but has no audio stream in PipeWire -> the sound
# comes out of a remote Connect device, not this machine.
spotify_on_connect() {
    [ "$(playerctl -p spotify status 2>/dev/null)" = "Playing" ] || return 1
    ! pw-dump 2>/dev/null | jq -e '
        any(.[]; .type == "PipeWire:Interface:Node"
            and .info.props["media.class"] == "Stream/Output/Audio"
            and ((.info.props["application.name"] // "") | test("spotify"; "i")))' >/dev/null
}

if spotify_on_connect; then
    case "$1" in
        up)   playerctl -p spotify volume "${STEP_SPOTIFY}+" ;;
        down) playerctl -p spotify volume "${STEP_SPOTIFY}-" ;;
        mute)
            if [ -f "$SAVED_VOLUME" ]; then
                playerctl -p spotify volume "$(cat "$SAVED_VOLUME")"
                rm -f "$SAVED_VOLUME"
            else
                playerctl -p spotify volume > "$SAVED_VOLUME"
                playerctl -p spotify volume 0
            fi
            ;;
    esac
else
    case "$1" in
        up)   wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP_LOCAL}+" --limit 1.00 ;;
        down) wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP_LOCAL}-" ;;
        mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    esac
fi
