# ~/.config/fish/config.fish
status is-interactive; or return

# The prompt (starship) and fzf's own key bindings are set up by NixOS
# (programs.starship, programs.fzf), in /etc/fish/config.fish.
set fish_greeting

# fzf's bindings there override those of the fzf.fish plugin, so re-apply them
fzf_configure_bindings
if not set -q sponge_regex_patterns
    set -U sponge_regex_patterns 'nh os (switch|boot)'
end
