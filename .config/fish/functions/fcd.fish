function fcd --description 'cd to directory with fzf'
    set dir (fd --type d --hidden --exclude .git | fzf --preview 'eza -aT --level=2 {}')
    and cd $dir
end
