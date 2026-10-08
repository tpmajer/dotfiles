#!/usr/bin/env bash
set -euo pipefail

# GTK's stylesheets and settings for Flatpak applications, which do not see
# those in ~/.config: a copy for each. palette.css is the one quickshell's
# scripts/palette-apply.sh makes, which also writes it to the copies.

sources=(gtk.css colors.css adwaita.css settings.ini)
versions=(gtk-3.0 gtk-4.0)

for version in "${versions[@]}"; do
    for file in "${sources[@]}"; do
        src="$HOME/.dotfiles/.config/$version/$file"
        if [[ ! -f "$src" ]]; then
            notify-send -u critical "flatpak-gtk-theme" "Missing source file: $src"
            exit 1
        fi
    done
done

# With no Flatpak app installed the pattern must match nothing, not itself.
shopt -s nullglob
for app_dir in "$HOME"/.var/app/*/; do
    for version in "${versions[@]}"; do
        mkdir -p "$app_dir/config/$version"
        for file in "${sources[@]}"; do
            cp --remove-destination "$HOME/.dotfiles/.config/$version/$file" "$app_dir/config/$version/$file"
        done
        palette="$HOME/.config/$version/palette.css"
        if [[ -f "$palette" ]]; then
            cp --remove-destination "$palette" "$app_dir/config/$version/palette.css"
        else
            : > "$app_dir/config/$version/palette.css"
        fi
    done
done
