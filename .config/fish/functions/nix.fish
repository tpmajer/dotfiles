function nix --wraps=nix --description 'wrapper for nix: runs via systemd-inhibit and auto-commits flake.lock changes'
    set flake_before (md5sum ~/.nixos/flake.lock)

    systemd-inhibit nix $argv
    set exit_code $status

    if test $exit_code -eq 0
        set flake_after (md5sum ~/.nixos/flake.lock)
        if test "$flake_before" != "$flake_after"
            git -C ~/.nixos add flake.lock
            git -C ~/.nixos commit -m "chore: update flake.lock"
        end
    end

    return $exit_code
end
