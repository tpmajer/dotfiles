function nh --wraps=nh --description 'wrapper for nh: runs via systemd-inhibit and auto-commits flake.lock changes'
    systemd-inhibit nh $argv
    set exit_code $status

    if test $exit_code -eq 0
        if not git -C ~/.nixos diff --quiet flake.lock
            git -C ~/.nixos add flake.lock
            git -C ~/.nixos commit -m "chore: update flake.lock" -- flake.lock
        end
    end

    return $exit_code
end
