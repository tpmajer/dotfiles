#!/usr/bin/env bash
# hypridle's before_sleep_cmd: fade to the lock and to black, and return only
# once that is done (or after 3 s, logind waits 5), so the laptop does not wake
# up showing the desktop. hypridle delays the suspend until then.
# Nothing to wait for if Quickshell does not answer.

qs ipc call lock doze 2>/dev/null || exit

# By the clock, in microseconds: asking takes its time too.
end=$((${EPOCHREALTIME/[.,]/} + 3000000))
while [ "${EPOCHREALTIME/[.,]/}" -lt "$end" ]; do
    [ "$(qs ipc call lock isDark 2>/dev/null)" = "true" ] && exit 0
    sleep 0.05
done
