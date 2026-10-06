#!/usr/bin/env bash

# Volume keys: when Spotify plays on a Spotify Connect device (e.g. Mu-so),
# control Spotify's volume; otherwise control the default PipeWire sink.
# Usage: volume.sh up|down|mute

STEP_LOCAL="0.02"
STEP_SPOTIFY="0.03"

# As the bar's wave tells it (quickshell, services/Media.qml): Spotify plays
# and nothing sounds here. Not by its stream in PipeWire, which stays open
# on a Connect device. With no answer from Quickshell the keys are the sink's.
spotify_on_connect() {
    qs ipc call media state 2>/dev/null | jq -e '.remote' >/dev/null 2>&1
}

if spotify_on_connect; then
    case "$1" in
        up)   playerctl -p spotify volume "${STEP_SPOTIFY}+" ;;
        down) playerctl -p spotify volume "${STEP_SPOTIFY}-" ;;
        mute) qs ipc call spotify toggleMute ;;
    esac
else
    case "$1" in
        up)   wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP_LOCAL}+" --limit 1.00 ;;
        down) wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP_LOCAL}-" ;;
        mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    esac
fi
