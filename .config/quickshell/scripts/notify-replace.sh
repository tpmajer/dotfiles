#!/usr/bin/env bash

# notify-send, replacing the notification sent last under the same key
# rather than adding one.
#   notify-replace.sh key [notify-send's arguments]
# The id is kept with the server's bus name: ids start anew with the server,
# and an old one would by then be another sender's notification.

key=$1
shift
[ -n "$XDG_RUNTIME_DIR" ] || exec notify-send "$@"
file="$XDG_RUNTIME_DIR/notify-replace-$key"

# One at a time under a key: those started together would all add one.
exec 9> "$file.lock"
flock 9

server=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications 2>/dev/null)
id=
[ -r "$file" ] && read -r id kept < "$file"
[ -n "$server" ] && [ "$kept" = "$server" ] && [[ $id =~ ^[0-9]+$ ]] || id=

new=$(notify-send -p ${id:+-r "$id"} "$@") || new=$(notify-send -p "$@")
if [ -n "$server" ] && [[ $new =~ ^[0-9]+$ ]]; then
    printf '%s %s\n' "$new" "$server" > "$file"
else
    rm -f "$file"
fi
