#!/usr/bin/env python3
"""
check_keybinds — scan dotfiles for keybinding conflicts.

Usage:
    python check_keybinds.py [DOTFILES_DIR]

DOTFILES_DIR defaults to ~ if not given.
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path


# ── helpers ──────────────────────────────────────────────────────────────────

MODIFIER_ALIASES = {
    "super": "mod", "win": "mod", "meta": "mod",
    "control": "ctrl",
    "alt": "alt", "option": "alt",
    "shift": "shift",
}
KEY_ALIASES = {
    "minus": "-", "dash": "-",
    "equal": "=", "equals": "=",
    "slash": "/",
    "backslash": "\\",
    "underscore": "_",
    "space": "space",
    "tab": "tab",
    "return": "return", "enter": "return",
    "escape": "escape", "esc": "escape",
    "delete": "delete", "del": "delete",
    "backspace": "backspace",
    "page_up": "pageup", "pageup": "pageup",
    "page_down": "pagedown", "pagedown": "pagedown",
    "bracketleft": "[", "bracketright": "]",
    "comma": ",", "period": ".", "semicolon": ";",
    "apostrophe": "'", "grave": "`",
}
MODIFIER_ORDER = ["ctrl", "alt", "shift", "mod"]


def normalize(key: str) -> str:
    """Return a canonical lower-case key combo string."""
    key = key.strip()
    # split on + or - (but keep single - as a key)
    if "+" in key:
        parts = [p.strip() for p in key.split("+") if p.strip()]
    elif key.startswith("Alt-") or key.startswith("Ctrl-"):
        parts = [p.strip() for p in key.split("-", 1) if p.strip()]
    else:
        parts = [key]

    parts = [p.lower() for p in parts]
    parts = [MODIFIER_ALIASES.get(p, p) for p in parts]

    mods = [p for p in parts if p in MODIFIER_ORDER]
    rest = [p for p in parts if p not in MODIFIER_ORDER]

    if rest:
        k = rest[0]
        k = KEY_ALIASES.get(k, k)
        rest = [k] + rest[1:]

    mods.sort(key=lambda m: MODIFIER_ORDER.index(m))
    return "+".join(mods + rest)


# ── parsers ───────────────────────────────────────────────────────────────────

def parse_niri(path: Path):
    """Yield (normalized_key, raw_key, action, lineno) from niri config.kdl binds block."""
    in_binds = False
    depth = 0
    results = []
    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        # skip comments
        if stripped.startswith("//") or stripped.startswith("/-"):
            continue
        if stripped == "binds {":
            in_binds = True
            depth = 1
            continue
        if in_binds:
            depth += stripped.count("{") - stripped.count("}")
            if depth <= 0:
                in_binds = False
                continue
            # a binding line looks like:  Key+Combo { action; }
            m = re.match(r'^([\w+\-]+(?:\s+[\w\-=".]+)*?)\s*\{(.+?)\}', stripped)
            if not m:
                continue
            raw_key_part = m.group(1).strip()
            action_part = m.group(2).strip().rstrip(";").strip()
            # strip flags like allow-when-locked=true, repeat=false, hotkey-overlay-title="..."
            raw_key = re.split(r'\s+(?:allow-when-locked|repeat|hotkey-overlay-title)', raw_key_part)[0].strip()
            results.append((normalize(raw_key), raw_key, action_part, lineno))
    return results


def parse_mpv(path: Path):
    results = []
    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        # commented-out example: " # something" or " #something"
        if line.startswith(" #") or line.startswith("\t#"):
            continue
        parts = stripped.split()
        if len(parts) < 2:
            continue
        raw_key = parts[0]
        # strip uosc menu label (#! ...)
        action_parts = []
        for p in parts[1:]:
            if p.startswith("#!"):
                break
            if p.startswith("#"):
                break
            action_parts.append(p)
        action = " ".join(action_parts)
        results.append((normalize(raw_key), raw_key, action, lineno))
    return results


def parse_micro(path: Path):
    results = []
    try:
        data = json.loads(path.read_text(errors="replace"))
    except json.JSONDecodeError:
        return results
    for raw_key, action in data.items():
        results.append((normalize(raw_key), raw_key, str(action), None))
    return results


def parse_fuzzel(path: Path):
    results = []
    in_section = False
    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        if stripped == "[key-bindings]":
            in_section = True
            continue
        if stripped.startswith("[") and in_section:
            in_section = False
            continue
        if not in_section:
            continue
        if not stripped or stripped.startswith("#") or stripped.startswith(";"):
            continue
        if "=" not in stripped:
            continue
        action, _, keys_str = stripped.partition("=")
        action = action.strip()
        for raw_key in keys_str.split():
            results.append((normalize(raw_key), raw_key, action, lineno))
    return results


def parse_helix(path: Path):
    results = []
    current_mode = None
    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        m = re.match(r'^\[keys\.(normal|insert|select)\]', stripped)
        if m:
            current_mode = m.group(1)
            continue
        if stripped.startswith("["):
            current_mode = None
            continue
        if current_mode and "=" in stripped:
            raw_key, _, action = stripped.partition("=")
            raw_key = raw_key.strip()
            action = action.strip().strip('"')
            results.append((normalize(raw_key) + f"[{current_mode}]", raw_key, action, lineno))
    return results


def parse_wlogout(path: Path):
    results = []
    try:
        # wlogout layout is newline-separated JSON objects
        text = "[" + path.read_text(errors="replace").replace("}\n{", "},\n{") + "]"
        data = json.loads(text)
    except Exception:
        return results
    for obj in data:
        if "keybind" in obj:
            raw_key = obj["keybind"]
            label = obj.get("label", "?")
            results.append((normalize(raw_key), raw_key, label, None))
    return results


# ── conflict detection ────────────────────────────────────────────────────────

# scope groups: keys in the same group can conflict with each other
SCOPE_GLOBAL = "global"      # niri — intercepted before apps
SCOPE_MPV = "mpv"
SCOPE_TERMINAL = "terminal"  # micro, helix
SCOPE_LOGOUT = "logout"      # wlogout — separate session


FILE_META = {
    ".config/niri/config.kdl":     (parse_niri,   SCOPE_GLOBAL,   "niri"),
    ".config/mpv/input.conf":      (parse_mpv,    SCOPE_MPV,      "mpv"),
    ".config/micro/bindings.json": (parse_micro,  SCOPE_TERMINAL, "micro"),
    ".config/fuzzel/fuzzel.ini":   (parse_fuzzel, SCOPE_GLOBAL,   "fuzzel"),
    ".config/helix/config.toml":   (parse_helix,  SCOPE_TERMINAL, "helix"),
    ".config/wlogout/layout":      (parse_wlogout, SCOPE_LOGOUT,  "wlogout"),
}


def check(dotfiles_dir: Path):
    # binds[scope][norm_key] = list of (file_label, raw_key, action, lineno)
    binds = defaultdict(lambda: defaultdict(list))
    scanned = []
    missing = []

    for rel, (parser, scope, label) in FILE_META.items():
        path = dotfiles_dir / rel
        if not path.exists():
            missing.append(rel)
            continue
        scanned.append(rel)
        for norm_key, raw_key, action, lineno in parser(path):
            binds[scope][norm_key].append((rel, raw_key, action, lineno))

    high, medium, info = [], [], []

    # within-scope duplicates
    for scope, keys in binds.items():
        for norm_key, entries in keys.items():
            if len(entries) < 2:
                continue
            # check if all entries point to the same action
            actions = set(e[2] for e in entries)
            files = set(e[0] for e in entries)

            if len(actions) == 1:
                # same action, different aliases — INFO
                info.append((norm_key, entries, "Duplicate aliases → same action"))
            elif len(files) == 1:
                # same file, different actions — HIGH
                high.append((norm_key, entries, f"Same key, different actions in {entries[0][0]}"))
            else:
                high.append((norm_key, entries, "Same key, different actions across files in same scope"))

    # cross-scope: global (niri) keys that start with Mod+ don't shadow bare app keys
    # Flag only if a global bind is a bare key (no Mod) that an app also uses
    niri_binds = binds.get(SCOPE_GLOBAL, {})
    for scope in [SCOPE_MPV, SCOPE_TERMINAL]:
        for norm_key, app_entries in binds.get(scope, {}).items():
            if norm_key in niri_binds:
                global_entries = niri_binds[norm_key]
                # only flag if both sides have the exact same norm_key (not just substring)
                all_entries = global_entries + app_entries
                actions = set(e[2] for e in all_entries)
                if len(actions) > 1:
                    medium.append((norm_key, all_entries,
                        "Global shortcut may shadow app binding"))

    return high, medium, info, scanned, missing


# ── report ────────────────────────────────────────────────────────────────────

RESET  = "\033[0m"
BOLD   = "\033[1m"
RED    = "\033[31m"
YELLOW = "\033[33m"
CYAN   = "\033[36m"
DIM    = "\033[2m"


def fmt_entry(file_rel, raw_key, action, lineno):
    loc = f":{lineno}" if lineno else ""
    return f"  {DIM}{file_rel}{loc}{RESET}  →  {action}  {DIM}(raw: {raw_key}){RESET}"


def print_report(high, medium, info, scanned, missing):
    print()
    print(f"{BOLD}Keybinding Conflict Report{RESET}")
    print("=" * 44)

    if not high and not medium and not info:
        print(f"\n✓  No conflicts found.\n")
    else:
        if high:
            print()
            for norm_key, entries, reason in high:
                print(f"{RED}{BOLD}✗ HIGH{RESET}  —  {BOLD}{norm_key}{RESET}:  {reason}")
                for e in entries:
                    print(fmt_entry(*e))
                print()

        if medium:
            print()
            for norm_key, entries, reason in medium:
                print(f"{YELLOW}{BOLD}⚠ MEDIUM{RESET}  —  {BOLD}{norm_key}{RESET}:  {reason}")
                for e in entries:
                    print(fmt_entry(*e))
                print()

        if info:
            print()
            for norm_key, entries, reason in info:
                print(f"{CYAN}ℹ INFO{RESET}  —  {BOLD}{norm_key}{RESET}:  {reason}")
                for e in entries:
                    print(fmt_entry(*e))
                print()

    print("─" * 44)
    counts = []
    if high:   counts.append(f"{RED}{BOLD}{len(high)} high{RESET}")
    if medium: counts.append(f"{YELLOW}{BOLD}{len(medium)} medium{RESET}")
    if info:   counts.append(f"{CYAN}{len(info)} info{RESET}")
    if counts:
        print("  " + ",  ".join(counts))
    else:
        print(f"  {BOLD}All clean.{RESET}")

    print()
    print(f"{DIM}Scanned:{RESET}")
    for f in scanned:
        print(f"  ✓  {f}")
    if missing:
        print(f"{DIM}Not found (skipped):{RESET}")
        for f in missing:
            print(f"  –  {f}")
    print()


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    dotfiles_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home()
    dotfiles_dir = dotfiles_dir.expanduser().resolve()
    high, medium, info, scanned, missing = check(dotfiles_dir)
    print_report(high, medium, info, scanned, missing)
    sys.exit(1 if high else 0)


if __name__ == "__main__":
    main()
