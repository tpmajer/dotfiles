function port --description 'show what is listening on a port'
    if test (count $argv) -eq 0
        echo "Usage: port <number>"
        return 1
    end
    # By ss's own filter: grep for ":80" would find :8080 too.
    ss -tlnp "sport = :$argv[1]"
end
