function wp --description 'Pick a wallpaper with fzf (timg preview) and set it with awww'
    find $argv -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
        | fzf --preview 'timg -pq -U --frames=1 -g $FZF_PREVIEW_COLUMNS"x"$FZF_PREVIEW_LINES {}' \
        --preview-window 'right,60%' \
        --bind 'enter:become(awww img {} --transition-type any --transition-fps 120; qs ipc call lock wallpaper 2>/dev/null)'
end
