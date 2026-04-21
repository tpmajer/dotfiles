function gitstat --description 'show git status of ~/.nixos and ~/.dotfiles'
    for repo in ~/.nixos ~/.dotfiles
        set branch (git -C $repo branch --show-current)
        set last_commit (git -C $repo log --format="%s" -1)
        set changes (git -C $repo status --short)

        set_color --bold cyan
        printf "%-16s" (basename $repo)
        set_color normal
        set_color yellow
        printf "%-10s" $branch
        set_color normal
        echo $last_commit

        if test -n "$changes"
            echo $changes | while read line
                printf "%-26s%s\n" "" $line
            end
        else
            printf "%-26s%s\n" "" "(clean)"
        end

        echo ""
    end
end
