#!/usr/bin/env bash

# Manual idle inhibitor for the quickshell bar's idle module.
# Holds a logind "idle" inhibitor, which hypridle honours even when the bar is
# hidden behind a fullscreen window (a Wayland idle inhibitor is tied to the
# bar's surface, so niri ignores it while the bar is covered).
# The inhibitor ends on toggle, after $timeout seconds on battery (wall clock,
# counted anew on each unplug; never on AC), or on suspend (before_sleep_cmd
# in hypridle.conf stops the unit).
# Without an argument, exits 0 while the inhibitor is on.

unit=idle-inhibit.service
timeout=${IDLE_INHIBIT_TIMEOUT:-1800}
ac=/sys/class/power_supply/ACAD/online

case "$1" in
    toggle)
        if systemctl --user is-active --quiet "$unit"; then
            systemctl --user stop "$unit"
        else
            systemd-run --user --collect --quiet --unit="$unit" \
                systemd-inhibit --what=idle --who=quickshell --why="Manual idle inhibit" \
                "$(realpath "$0")" hold
        fi
        ;;
    hold)
        deadline=$(($(date +%s) + timeout))
        while :; do
            now=$(date +%s)
            grep -qx 1 "$ac" && deadline=$((now + timeout))
            [ "$now" -ge "$deadline" ] && exit 0
            sleep 5
        done
        ;;
    *)
        systemctl --user is-active --quiet "$unit"
        ;;
esac
