function port --description 'show what is listening on a port'
    if test (count $argv) -eq 0
        echo "Usage: port <number>"
        return 1
    end
    ss -tlnp | grep ":$argv[1]"
end
