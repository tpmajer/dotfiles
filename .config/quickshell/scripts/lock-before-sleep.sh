#!/usr/bin/env bash
# hypridle's before_sleep_cmd: lock the session at once, without the fade, and
# return only once it is locked and drawn (or after 2 s), so the laptop does
# not wake up showing the desktop. hypridle delays the suspend until then.
# hyprlock if Quickshell does not answer.

if ! qs ipc call lock lockNow 2>/dev/null; then
    pidof hyprlock >/dev/null || hyprlock &
    sleep 0.5
    exit 0
fi

for _ in $(seq 40); do
    [ "$(qs ipc call lock isLocked 2>/dev/null)" = "true" ] && exit 0
    sleep 0.05
done
