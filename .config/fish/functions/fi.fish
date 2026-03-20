function fi --wraps="fzf --preview='timg -g70x200 {}'" --description "alias fi=fzf --preview='timg -g70x200 {}'"
    fzf --preview='timg -g70x200 {}' $argv
end
