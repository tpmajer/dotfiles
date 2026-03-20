function fp --wraps="fzf --preview='bat --color=always -n {}'" --description "alias fp=fzf --preview='bat --color=always -n {}'"
    fzf --preview='bat --color=always -n {}' $argv
end
