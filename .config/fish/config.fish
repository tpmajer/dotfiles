# ~/.config/fish/config.fish
starship init fish | source
set fish_greeting

# Set up fzf key bindings
fzf --fish | source
if not set -q sponge_regex_patterns
  set -U sponge_regex_patterns 'nh os (switch|boot)'
end
