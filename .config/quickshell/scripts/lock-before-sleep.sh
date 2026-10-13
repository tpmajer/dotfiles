#!/usr/bin/env bash
# hypridle's before_sleep_cmd: lock the session at once, without the fade, and
# return only once it is locked and drawn (or after 2 s), so the laptop does
# not wake up showing the desktop. hypridle delays the suspend until then.
# Nothing to wait for if Quickshell does not answer.

qs ipc call lock lockNow 2>/dev/null || exit

# By the clock, in microseconds: asking takes its time too.
end=$((${EPOCHREALTIME/[.,]/} + 2000000))
while [ "${EPOCHREALTIME/[.,]/}" -lt "$end" ]; do
    [ "$(qs ipc call lock isLocked 2>/dev/null)" = "true" ] && exit 0
    sleep 0.05
done
