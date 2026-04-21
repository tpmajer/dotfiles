function nix --wraps=nix --description 'wrapper for nix: runs via systemd-inhibit and auto-commits flake.lock changes'
    systemd-inhibit nix $argv
    set exit_code $status

    if test $exit_code -eq 0
        if not git -C ~/.nixos diff --quiet flake.lock
            git -C ~/.nixos add flake.lock
            git -C ~/.nixos commit -m "chore: update flake.lock"
        end
    end

    return $exit_code
end
