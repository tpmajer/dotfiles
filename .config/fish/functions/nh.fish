function nh --wraps=nh --description 'alias nh=systemd-inhibit nh'
    systemd-inhibit nh $argv
end
