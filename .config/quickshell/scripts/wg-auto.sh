#!/usr/bin/env bash

# Switch for wg-auto (~/.nixos, wireguard.nix), which brings wg0 up, with a kill
# switch, on every network that is not trusted, Wi-Fi or wired, unless
# /var/lib/wg-auto-disabled exists. It acts on the flag the moment it is set
# or removed (wg-auto.path); with the flag set on a foreign network it still
# lets nothing in.
# Shared by the fish function `wgauto` and the quickshell network popup.
#   off     set the flag and stop wg0 (always asks for the password)
#   up      set the flag and start wg0: a manual tunnel, e.g. on a trusted
#           network, that the dispatcher leaves alone (asks for the password)
#   on      remove the flag
#   status  print the state (default)

flag=/var/lib/wg-auto-disabled
bin=/run/current-system/sw/bin

# sudo in a terminal, the polkit dialog from the bar (no tty to ask on). run0,
# not pkexec: NixOS ships no setuid pkexec wrapper by default.
as_root() {
    if [ -t 0 ]; then
        sudo "$@"
    else
        run0 "$@"
    fi
}

case "${1:-status}" in
    off)
        # One command, so one password prompt. Absolute paths: run0 does not pass PATH on.
        as_root "$bin/sh" -c "$bin/touch $flag && $bin/systemctl stop wg-quick-wg0.service" || exit
        ;;
    up)
        as_root "$bin/sh" -c "$bin/touch $flag && $bin/systemctl start wg-quick-wg0.service" || exit
        ;;
    on)
        # NOPASSWD in sudoers (wireguard.nix); fall back to asking if that rule is missing.
        sudo -n "$bin/rm" -f "$flag" 2>/dev/null || as_root "$bin/rm" -f "$flag" || exit
        ;;
    status) ;;
    *)
        echo "Usage: wgauto [on|off|up|status]"
        exit 1
        ;;
esac

if [ -e "$flag" ]; then
    echo "wg-auto: disabled"
else
    echo "wg-auto: enabled"
fi
echo "wg0: $(systemctl is-active wg-quick-wg0.service)"
