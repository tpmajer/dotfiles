#!/bin/bash

# Directory containing your wallpapers
WALLPAPER_DIR="$HOME/Pictures/.Wallpapers2"

# Transition settings (optional)
TRANSITION_TYPE="wipe" # none, simple, fade, left, right, top, bottom, wipe, wave, grow, center, any, outer, random
TRANSITION_ANGLE="30"
TRANSITION_DURATION="1" # in seconds

# Start awww daemon if not running
if ! pgrep -x "awww-daemon" > /dev/null; then
    echo "Starting awww-daemon..."
    awww-daemon
fi

# Get a list of image files
mapfile -t IMAGES < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \))

# Exit if no images found
if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "No images found in $WALLPAPER_DIR"
    exit 1
fi

# Pick a random image
RANDOM_IMAGE="${IMAGES[RANDOM % ${#IMAGES[@]}]}"

# Set the wallpaper
awww img "$RANDOM_IMAGE" --transition-step 255 --transition-fps 120  --transition-type "$TRANSITION_TYPE" --transition-duration "$TRANSITION_DURATION" --transition-angle "$TRANSITION_ANGLE" --resize crop
notify-send "Wallpaper changed" "$RANDOM_IMAGE"

