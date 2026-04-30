function mkcd --description 'mkdir and cd into it'
    mkdir -p $argv[1] && cd $argv[1]
end
