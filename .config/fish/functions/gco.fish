function gco --description 'git checkout branch via fzf'
    set branch (git branch -a | grep -v HEAD | string trim | fzf)
    and git checkout (string replace 'remotes/origin/' '' $branch | string trim)
end
