#!/usr/bin/env bash

GTK4_SRC="$HOME/.dotfiles/.config/gtk-4.0"
GTK3_SRC="$HOME/.dotfiles/.config/gtk-3.0"

for app_dir in "$HOME"/.var/app/*/; do
  mkdir -p "$app_dir/config/gtk-4.0"
  mkdir -p "$app_dir/config/gtk-3.0"
  cp --remove-destination "$GTK4_SRC/gtk.css"      "$app_dir/config/gtk-4.0/gtk.css"
  cp --remove-destination "$GTK4_SRC/settings.ini" "$app_dir/config/gtk-4.0/settings.ini"
  cp --remove-destination "$GTK3_SRC/gtk.css"      "$app_dir/config/gtk-3.0/gtk.css"
  cp --remove-destination "$GTK3_SRC/settings.ini" "$app_dir/config/gtk-3.0/settings.ini"
done
