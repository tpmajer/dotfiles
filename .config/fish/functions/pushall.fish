function pushall --description 'git push in ~/.nixos and ~/.dotfiles'
    for repo in ~/.nixos ~/.dotfiles
        set_color --bold cyan
        echo (basename $repo)
        set_color normal
        git -C $repo push; or return
    end
end
