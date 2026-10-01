function wgauto --description 'toggle WireGuard auto-start (wg-auto dispatcher)'
    set -l flag /var/lib/wg-auto-disabled
    switch "$argv[1]"
        case off
            sudo touch $flag
            and sudo systemctl stop wg-quick-wg0.service
            or return
        case on
            sudo rm -f $flag
            or return
            # Re-activate Wi-Fi so the dispatcher gets an "up" event and applies the SSID rule now
            for uuid in (nmcli -g TYPE,UUID connection show --active | string replace -rf '^802-11-wireless:' '')
                nmcli connection up uuid $uuid >/dev/null
            end
        case '' status
        case '*'
            echo "Usage: wgauto [on|off|status]"
            return 1
    end
    if test -e $flag
        echo "wg-auto: disabled"
    else
        echo "wg-auto: enabled"
    end
    echo "wg0: "(systemctl is-active wg-quick-wg0.service)
end
