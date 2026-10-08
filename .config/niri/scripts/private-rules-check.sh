#!/usr/bin/env bash
# config.kdl includes block-screen-capture.kdl only if it is there: it is kept
# out of the repo, and on a machine without it niri starts all the same, with
# nothing kept out of screen captures and nothing said. Say it.

rules="$HOME/.config/niri/block-screen-capture.kdl"
[ -e "$rules" ] && exit 0

# The notification server (Quickshell) comes up after niri.
for _ in $(seq 30); do
    notify-send -u critical "niri" "No block-screen-capture.kdl: no window is kept out of screen captures. See block-screen-capture.kdl.example." && exit 0
    sleep 1
done
