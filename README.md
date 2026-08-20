# dotfiles

Personal dotfiles for my daily Linux setup. Currently built around the [Catppuccin Mocha](https://catppuccin.com) color scheme, the [Niri](https://github.com/niri-wm/niri) scrolling compositor, and [Ghostty](https://ghostty.org) terminal.

Includes configuration for: [Niri](https://github.com/niri-wm/niri) · [Ghostty](https://ghostty.org) · [Fish](https://fishshell.com) · [Waybar](https://github.com/Alexays/Waybar) · [Fuzzel](https://codeberg.org/dnkl/fuzzel) · [Mako](https://github.com/emersion/mako) · [MPV](https://mpv.io) · [uosc](https://github.com/tomasklaen/uosc) · [btop](https://github.com/aristocratos/btop) · [bat](https://github.com/sharkdp/bat) · [fastfetch](https://github.com/fastfetch-cli/fastfetch) · [starship](https://starship.rs) · [wlogout](https://github.com/ArtsyMacaw/wlogout) · [hyprlock](https://github.com/hyprwm/hyprlock/)

#

<img src="assets/screenshot.png" width="800" alt="My desktop">

#

## Installation

Clone into `~/.dotfiles` and stow from inside the repo. The target defaults to
the parent directory, so `~` is picked up automatically:

```sh
cd ~/.dotfiles
stow .
```

Run the same command again to link files added later. On a conflict it aborts
with a list of what is in the way and changes nothing.

Note that `stow -d ~ -t ~ .dotfiles` does **not** work: with the stow directory
equal to the target, stow skips it and plans no operations at all.

### A warning about `--adopt`

`stow --adopt .` was used once, for the initial import, when the configs still
lived in `~` and this repo was empty.

On a conflict `--adopt` **moves the file from `~` into the repo, overwriting the
committed version**, and only then creates the symlink. Data flows from home
into the repo, not the other way round — the name suggests the opposite of what
it does.

Do not use it for routine re-stowing. If an application ever replaces a symlink
with a real file, `--adopt` imports that copy over the tracked one without
saying so. If you do run it here, read `git diff` before committing:
`git restore <file>` undoes the overwrite and `stow .` recreates the link.

#

Many of the configurations in this repository are inspired by or borrowed from the work of others in the community. There are too many sources to credit individually, but I'm grateful to everyone who shares their dotfiles publicly.

___
