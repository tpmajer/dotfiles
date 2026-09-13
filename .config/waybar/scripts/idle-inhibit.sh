#!/usr/bin/env bash

# Manual idle inhibitor for waybar's custom/idle-inhibit module.
# Holds a logind "idle" inhibitor, which hypridle honours even when the bar is
# hidden behind a fullscreen window (the built-in idle_inhibitor module ties the
# inhibitor to the bar's surface, so niri ignores it while the bar is covered).
# The inhibitor ends on toggle, after $timeout (wall clock), or on suspend
# (before_sleep_cmd in hypridle.conf stops the unit).

unit=idle-inhibit.service
signal=8                                  # "signal" of custom/idle-inhibit in waybar config
timeout=${IDLE_INHIBIT_TIMEOUT:-30m}

case "$1" in
    toggle)
        if systemctl --user is-active --quiet "$unit"; then
            systemctl --user stop "$unit"
        else
            refresh="-$(type -P pkill) -RTMIN+$signal waybar"
            systemd-run --user --collect --quiet --unit="$unit" \
                -p "ExecStartPost=$refresh" -p "ExecStopPost=$refresh" \
                systemd-inhibit --what=idle --who=waybar --why="Manual idle inhibit" \
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
