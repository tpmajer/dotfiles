function nix --wraps=nix --description 'wrapper for nix: keeps the system awake during a build and auto-commits flake.lock changes'
    # Under systemd-inhibit only for what runs by itself and takes long. Not
    # for a shell (develop, shell, run, repl): its inhibitor would be there
    # for as long as the shell is open, and hypridle would neither lock the
    # screen nor suspend.
    set -l subcommand
    for arg in $argv
        if not string match -q -- '-*' $arg
            set subcommand $arg
            break
        end
    end
    switch "$subcommand"
        case build copy flake profile store
            systemd-inhibit nix $argv
        case '*'
            command nix $argv
    end
    set exit_code $status

    if test $exit_code -eq 0
        if not git -C ~/.nixos diff --quiet flake.lock
            git -C ~/.nixos add flake.lock
            git -C ~/.nixos commit -m "chore: update flake.lock" -- flake.lock
        end
    end

    return $exit_code
end
