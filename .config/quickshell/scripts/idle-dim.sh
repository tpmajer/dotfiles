#!/usr/bin/env bash

# hypridle's dimming of the screen, in steps too small to see rather than
# at once.
#   dim      fade the backlight to its minimum, keeping what it was
#   restore  stop a fade under way and fade back, faster, to what it was

run=${XDG_RUNTIME_DIR:-/tmp}
pidfile=$run/idle-dim.pid
# What the backlight was, for the way back.
keep=$run/idle-dim.from
# Not 0, to which an OLED panel answers by turning off.
target=10

# The OSD stays out of a fade.
quiet() {
    qs ipc call brightness quiet "$1" > /dev/null 2>&1
}

# The PID of a fade under way: the one on file, if it is still this script.
fading() {
    local pid
    [[ -f $pidfile ]] && pid=$(< "$pidfile")
    [[ -n $pid && $pid != "$$" ]] && grep -qs "${0##*/}" "/proc/$pid/cmdline" && echo "$pid"
}

# Until that fade is over, 2 s at most.
ended() {
    for _ in $(seq 200); do
        kill -0 "$1" 2> /dev/null || return 0
        sleep 0.01
    done
}

# From one brightness to another in so many steps, each the same fraction
# of the one before, which the eye takes for even; a pause between them.
fade() {
    quiet true
    for value in $(awk -v a="$1" -v b="$2" -v n="$3" \
        'BEGIN { if (a < 1) a = 1; for (i = 1; i <= n; i++) printf "%d\n", a * (b / a) ^ (i / n) }'); do
        brightnessctl -q set "$value" 2> /dev/null
        sleep "$4"
    done
    brightnessctl -q set "$2" 2> /dev/null
    # The last step's news is still on its way to quickshell.
    sleep 0.1
    quiet false
}

# One fade at a time: a dim lets the way back finish, which is short; the
# way back stops whatever runs.
other=$(fading)
if [[ -n $other ]]; then
    [[ $1 == restore ]] && kill "$other" 2> /dev/null
    ended "$other"
fi
echo $$ > "$pidfile"
trap '[[ $(cat "$pidfile" 2> /dev/null) == "$$" ]] && rm -f "$pidfile"' EXIT
trap 'exit 143' TERM

case $1 in
    dim)
        from=$(brightnessctl get 2> /dev/null)
        if ((from > target)); then
            echo "$from" > "$keep"
            # Saved for the `brightnessctl -r` of hypridle's other listeners too.
            brightnessctl -sq set "$from" 2> /dev/null
            fade "$from" "$target" 80 0.01
        fi
        ;;
    restore)
        # Nothing on file: nothing was dimmed.
        if [[ -f $keep ]]; then
            fade "$(brightnessctl get 2> /dev/null)" "$(< "$keep")" 25 0
            rm -f "$keep"
        else
            quiet false
        fi
        ;;
esac
