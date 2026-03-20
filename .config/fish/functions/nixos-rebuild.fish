function nixos-rebuild --description 'alias nixos-rebuild=systemd-inhibit nixos-rebuild'
  systemd-inhibit nixos-rebuild $argv
        
end
