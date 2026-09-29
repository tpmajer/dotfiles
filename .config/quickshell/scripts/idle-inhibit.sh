#!/usr/bin/env bash

# Manual idle inhibitor for the quickshell bar's idle-inhibit module.
# Holds a logind "idle" inhibitor, which hypridle honours even when the bar is
# hidden behind a fullscreen window (the built-in idle_inhibitor module ties the
# inhibitor to the bar's surface, so niri ignores it while the bar is covered).
# The inhibitor ends on toggle, after $timeout (wall clock), or on suspend
# (before_sleep_cmd in hypridle.conf stops the unit).

unit=idle-inhibit.service
timeout=${IDLE_INHIBIT_TIMEOUT:-30m}

case "$1" in
    toggle)
        if systemctl --user is-active --quiet "$unit"; then
            systemctl --user stop "$unit"
        else
            systemd-run --user --collect --quiet --unit="$unit" \
                systemd-inhibit --what=idle --who=quickshell --why="Manual idle inhibit" \
                timeout "$timeout" sleep infinity
        fi
        ;;
    *)
        if systemctl --user is-active --quiet "$unit"; then
            printf '{"text":"󰒳","class":"activated","tooltip":"Idle inhibitor on"}\n'
        else
            printf '{"text":"󰒲","class":"deactivated","tooltip":"Idle inhibitor off"}\n'
        fi
        ;;
esac
