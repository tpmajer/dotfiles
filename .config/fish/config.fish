# ~/.config/fish/config.fish
starship init fish | source
set fish_greeting

# Set up fzf key bindings
fzf --fish | source
# `fzf --fish` above overrides the plugin bindings, so re-apply them
fzf_configure_bindings
if not set -q sponge_regex_patterns
  set -U sponge_regex_patterns 'nh os (switch|boot)'
end
