function fkill --description 'kill process via fzf'
    set pid (ps aux | tail -n +2 | fzf --multi | awk '{print $2}')
    and echo $pid | xargs kill -9
end
