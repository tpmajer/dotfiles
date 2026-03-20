function nix --description 'alias nix=systemd-inhibit nix'
  systemd-inhibit nix $argv
        
end
