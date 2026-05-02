#!/usr/bin/env bash

format_bytes() {
    local b=$1
    if   [ "$b" -ge 1048576 ]; then awk "BEGIN{printf \"%.1f MiB/s\",$b/1048576}"
    elif [ "$b" -ge 1024 ];    then awk "BEGIN{printf \"%.0f KiB/s\",$b/1024}"
    else printf "%d B/s" "$b"
    fi
}

vpn=""
if ip link show wg0 2>/dev/null | grep -q "UP"; then
    vpn=" 󰌆"
fi

if nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep -q ":wifi:connected$"; then
    dev=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep ":wifi:connected$" | cut -d: -f1 | head -1)
    ssid=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ":802-11-wireless$" | cut -d: -f1 | head -1)
    signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | grep "^\*:" | cut -d: -f2 | head -1)
    signal=${signal:-0}
    freq_mhz=$(nmcli -t -f IN-USE,FREQ dev wifi 2>/dev/null | grep "^\*:" | grep -o '[0-9]\+' | head -1)
    freq=$(awk "BEGIN{printf \"%.1f GHz\", ${freq_mhz:-0}/1000}")

    rx_now=$(awk -v d="$dev:" '$1==d{print $2}' /proc/net/dev)
    tx_now=$(awk -v d="$dev:" '$1==d{print $10}' /proc/net/dev)
    now=$(date +%s%3N)
    tmp="/tmp/waybar-network-$dev"
    down="?" up="?"
    if [ -f "$tmp" ]; then
        read -r rx_prev tx_prev time_prev < "$tmp"
        elapsed=$(( now - time_prev ))
        if [ "$elapsed" -gt 0 ] && [ "$rx_now" -ge "$rx_prev" ] && [ "$tx_now" -ge "$tx_prev" ]; then
            down=$(format_bytes $(( (rx_now - rx_prev) * 1000 / elapsed )))
            up=$(format_bytes $(( (tx_now - tx_prev) * 1000 / elapsed )))
        fi
    fi
    printf "%s %s %s\n" "$rx_now" "$tx_now" "$now" > "$tmp"

    if   [ "$signal" -ge 80 ]; then icon="󰤨"
    elif [ "$signal" -ge 60 ]; then icon="󰤥"
    elif [ "$signal" -ge 40 ]; then icon="󰤢"
    elif [ "$signal" -ge 20 ]; then icon="󰤟"
    else icon="󰤯"
    fi

    printf '{"text":"%s %s%s","tooltip":"%s %s%%  ⇣ %s ⇡ %s"}\n' \
        "$icon" "$ssid" "$vpn" "$freq" "$signal" "$down" "$up"

elif nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep -q ":ethernet:connected$"; then
    printf '{"text":"󰀂%s"}\n' "$vpn"
else
    printf '{"text":"󰤮"}\n'
fi
