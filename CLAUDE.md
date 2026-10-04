# CLAUDE.md

# Tools

Nix is installed on this system. When you need a tool that is not
available, use `nix run nixpkgs#<package>` or `nix shell nixpkgs#<package>`
to run it ad-hoc. Do not install packages permanently.

Search for packages with `nix search nixpkgs <term>`.

# Commits

Conventional Commits, title in the imperative ("add…", "remove…",
"stop…"), not a description of the result. Title including
`type(scope): ` at most 72 characters; body wrapped at 72 columns.

The title says what changes — no "tweaks", "review fixes", "cleanups".

Scopes, one per area:

- the directory name in `.config`: `quickshell`, `niri`, `fish`,
  `micro`, …
- `hypr` for everything in `.config/hypr` (not `hypridle`, `hyprlock`)
- `git` (not `gitconfig`)
- `docs:` without a scope for the README
- no comma-joined scopes and no one-off ones

Do not copy the style from `git log`: part of the history predates this
convention.

One commit is one logical change. A fix, a style change and a feature
go into separate commits even when they touch the same file — split by
hunk. Do not rewrite pushed history for style alone.

Commit and push only when asked.
