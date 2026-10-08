#!/usr/bin/env bash
# A random image from a directory as the wallpaper.
#   wallpaper.sh [directory] [transition]
# The transition is one of awww's: none, simple, fade, left, right, top,
# bottom, wipe, wave, grow, center, any, outer, random.

dir="${1:-$HOME/Pictures/Wallpapers}"
transition="${2:-wipe}"

if ! systemctl --user is-active --quiet awww-daemon; then
    systemctl --user start awww-daemon
    sleep 1
fi

mapfile -t images < <(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \))

if [ ${#images[@]} -eq 0 ]; then
    echo "No images found in $dir" >&2
    exit 1
fi

image="${images[RANDOM % ${#images[@]}]}"

awww img "$image" --transition-step 255 --transition-fps 120 --transition-type "$transition" --transition-duration 1 --transition-angle 30 --resize crop
# The lock screen shows the wallpaper too: tell it now, not at its next poll.
qs ipc call lock wallpaper 2>/dev/null
# Transient: a toast only, not kept in the notification center.
notify-send -u low "Wallpaper changed" "$image"
