function gitstat --description 'show git status of ~/.nixos and ~/.dotfiles'
    for repo in ~/.nixos ~/.dotfiles
        set branch (git -C $repo branch --show-current)
        set last_commit (git -C $repo log --format="%s" -1)
        set changes (git -C $repo status --short)
        set ahead_behind (git -C $repo rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)

        set_color --bold cyan
        printf "%s" (basename $repo)
        set_color normal
        printf "  ·  "
        set_color yellow
        printf "%s" $branch
        set_color normal

        if test -n "$ahead_behind"
            set parts (string split \t $ahead_behind)
            set ahead $parts[1]
            set behind $parts[2]
            if test $ahead -gt 0
                set_color green
                printf "  ↑%s" $ahead
                set_color normal
            end
            if test $behind -gt 0
                set_color red
                printf "  ↓%s" $behind
                set_color normal
            end
        end
        echo

        echo $last_commit

        if test -n "$changes"
            set_color red
            for line in $changes
                echo $line
            end
            set_color normal
        else
            set_color green
            echo "(clean)"
            set_color normal
        end

        echo ""
    end
end
