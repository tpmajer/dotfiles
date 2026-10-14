#!/usr/bin/env bash

# A random wallpaper from the palette's own directory, as the palette is
# chosen: Theme.qml. No directory or no image in it, and the wallpaper stays.
#   palette-wallpaper.sh palette
# Images or links to them; with two or more, not the one shown.

dir="$HOME/Pictures/.palettes/$1"
[ -d "$dir" ] || exit 0

mapfile -t images < <(find -L "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \))
[ ${#images[@]} -gt 0 ] || exit 0

if [ ${#images[@]} -gt 1 ]; then
    current=$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n 1)
    current=$(readlink -f "$current" 2>/dev/null)
    others=()
    for image in "${images[@]}"; do
        [ "$(readlink -f "$image")" = "$current" ] || others+=("$image")
    done
    [ ${#others[@]} -gt 0 ] && images=("${others[@]}")
fi

image="${images[RANDOM % ${#images[@]}]}"

# As Mod+X sets one, and the lock told of it.
awww img "$image" --transition-step 255 --transition-fps 120 --transition-type random --transition-duration 1 --transition-angle 30 --resize crop &&
    qs ipc call lock wallpaper 2>/dev/null
