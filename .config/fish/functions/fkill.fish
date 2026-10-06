function fkill --description 'kill process via fzf'
    set -l pids (ps aux | tail -n +2 | fzf --multi | awk '{print $2}')
    test -n "$pids"; and kill -9 $pids
end
