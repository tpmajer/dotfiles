function yt-dlp --wraps=yt-dlp --description 'alias yt-dlp=systemd-inhibit yt-dlp'
  systemd-inhibit yt-dlp $argv
        
end
