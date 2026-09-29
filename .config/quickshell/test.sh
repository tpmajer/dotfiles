#!/usr/bin/env bash
# Try the quickshell bar in place of waybar. Waybar comes back when quickshell
# exits (Ctrl+C, or `pkill -x quickshell` from another terminal).
set -u
dir=$(dirname "$(readlink -f "$0")")
systemctl --user stop waybar
trap 'systemctl --user start waybar' EXIT
nix run nixpkgs#quickshell -- -p "$dir"
