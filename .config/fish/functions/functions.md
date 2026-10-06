# Fish Shell Functions

## Navigation

| Function | Usage | Description |
|----------|-------|-------------|
| `fcd` | `fcd` | Fuzzy cd — pick a directory via fzf with tree preview (requires `fd`) |
| `mkcd` | `mkcd <dir>` | Create a directory and cd into it in one step |

## Git

| Function | Usage | Description |
|----------|-------|-------------|
| `gitstat` | `gitstat` | Status of `~/.nixos` and `~/.dotfiles`: branch, ahead/behind origin (↑↓), last commit, changes |

## Processes and networking

| Function | Usage | Description |
|----------|-------|-------------|
| `fkill` | `fkill` | Pick and kill a process via fzf (supports multi-select) |
| `port` | `port <number>` | Show what is listening on a given port (`ss -tlnp`) |
| `wgauto` | `wgauto [on\|off\|up\|status]` | Toggle WireGuard auto-start: `off` sets `/var/lib/wg-auto-disabled` and stops wg0, `on` removes it and re-activates Wi-Fi so the SSID rule applies, `up` sets the flag and starts wg0 (manual tunnel, e.g. on a trusted network); no argument shows the state |

## Nix

| Function | Usage | Description |
|----------|-------|-------------|
| `nix` | `nix <args>` | Wrapper for `nix` — runs `build`, `copy`, `flake`, `profile` and `store` via `systemd-inhibit`, auto-commits `flake.lock` changes on success |
| `nh` | `nh <args>` | Wrapper for `nh` — runs via `systemd-inhibit`, auto-commits `flake.lock` changes on success |
| `nixos-rebuild` | `nixos-rebuild <args>` | Wrapper for `nixos-rebuild` via `systemd-inhibit` |

## Fzf

| Function | Usage | Description |
|----------|-------|-------------|
| `f` | `f` | Alias for `fzf` |
| `fp` | `fp` | fzf with file preview via `bat` (syntax highlighting) |
| `fi` | `fi` | fzf with image preview via `timg` |
| `wp` | `wp [dir]` | Pick a wallpaper via fzf (`timg` preview) and set it with `awww` |
| `fcd` | `fcd` | fzf directory navigation (see above) |
| `fkill` | `fkill` | fzf process killer (see above) |

## File listing (eza)

| Function | Usage | Description |
|----------|-------|-------------|
| `eza` | `eza [args]` | Wrapper for `eza` — always with `--hyperlink`, so the functions below get it too |
| `e` | `e [args]` | Alias for `eza --hyperlink` |
| `ez` | `ez [args]` | `eza -al` — detailed listing including hidden files |
| `etree` | `etree [args]` | `eza -aT` — directory tree |
| `edot` | `edot [args]` | `eza -aT --git-ignore` — directory tree excluding files in .gitignore |

## Multimedia

| Function | Usage | Description |
|----------|-------|-------------|
| `y` | `y [args]` | Alias for `yt-dlp` |
| `yt-dlp` | `yt-dlp [args]` | Wrapper for `yt-dlp` via `systemd-inhibit` (prevents sleep during downloads) |

## Misc

| Function | Usage | Description |
|----------|-------|-------------|
| `cc` | `cc [args]` | Alias for `claude` (Claude Code CLI) |
| `t` | `t [args]` | Alias for `tmux` |
| `p` | `p` | Start fish in private mode (`fish -P`) |
