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


# ── normalisation ─────────────────────────────────────────────────────────────

MODIFIER_ALIASES = {
    "super": "mod", "win": "mod", "meta": "mod",
    "control": "ctrl",
    "option": "alt",
    "enter": "return",
    "esc": "escape",
    "del": "delete",
    "page_up": "pageup",
    "page_down": "pagedown",
    "equal": "=", "equals": "=",
    "minus": "-", "dash": "-",
    "slash": "/",
    "backslash": "\\",
    "underscore": "_",
    "bracketleft": "[", "bracketright": "]",
    "comma": ",", "period": ".", "semicolon": ";",
    "apostrophe": "'", "grave": "`",
}

MODIFIER_ORDER = ["ctrl", "alt", "shift", "mod"]


def normalize(key: str) -> str:
    """Return a canonical lower-case key combo string."""
    key = key.strip()

    if "+" in key:
        parts = [p.strip().lower() for p in key.split("+") if p.strip()]
    elif re.match(r"^(Alt|Ctrl)-", key):
        parts = [p.strip().lower() for p in key.split("-", 1)]
    else:
        parts = [key.lower()]

    parts = [MODIFIER_ALIASES.get(p, p) for p in parts]
    mods = sorted((p for p in parts if p in MODIFIER_ORDER), key=MODIFIER_ORDER.index)
    keys = [MODIFIER_ALIASES.get(p, p) for p in parts if p not in MODIFIER_ORDER]
    return "+".join(mods + keys)


# ── parsers ───────────────────────────────────────────────────────────────────

def parse_niri(path: Path):
    results = []
    in_binds = False
    depth = 0

    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("/-"):
            continue
        if stripped == "binds {":
            in_binds, depth = True, 1
            continue
        if not in_binds:
            continue

        depth += stripped.count("{") - stripped.count("}")
        if depth <= 0:
            in_binds = False
            continue

        m = re.match(r'^([\w+\-]+(?:\s+[\w\-=".]+)*?)\s*\{(.+?)\}', stripped)
        if not m:
            continue

        raw_key_part = m.group(1).strip()
        action = m.group(2).strip().rstrip(";")
        raw_key = re.split(r'\s+(?:allow-when-locked|repeat|hotkey-overlay-title)', raw_key_part)[0].strip()
        results.append((normalize(raw_key), raw_key, action, lineno))

    return results


def parse_mpv(path: Path):
    results = []
    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or line.startswith((" #", "\t#")):
            continue
        parts = stripped.split()
        if len(parts) < 2:
            continue
        raw_key = parts[0]
        action_parts = []
        for p in parts[1:]:
            if p.startswith("#"):
                break
            action_parts.append(p)
        results.append((normalize(raw_key), raw_key, " ".join(action_parts), lineno))
    return results


def parse_micro(path: Path):
    try:
        data = json.loads(path.read_text(errors="replace"))
    except json.JSONDecodeError:
        return []
    return [(normalize(k), k, str(v), None) for k, v in data.items()]


def parse_fuzzel(path: Path):
    results = []
    in_section = False
    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        if stripped == "[key-bindings]":
            in_section = True
            continue
        if stripped.startswith("["):
            in_section = False
            continue
        if not in_section or not stripped or stripped.startswith(("#", ";")):
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
    current_prefix = ""
    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        m = re.match(r'^\[keys\.(normal|insert|select)(\.(.+))?\]', stripped)
        if m:
            current_mode = m.group(1)
            current_prefix = (m.group(3) + "+") if m.group(3) else ""
            continue
        if stripped.startswith("["):
            current_mode = None
            current_prefix = ""
            continue
        if current_mode and "=" in stripped:
            raw_key, _, action = stripped.partition("=")
            raw_key = raw_key.strip()
            action = action.strip().strip('"')
            full_key = current_prefix + raw_key
            results.append((normalize(full_key) + f"[{current_mode}]", full_key, action, lineno))
    return results


def parse_wlogout(path: Path):
    try:
        text = "[" + path.read_text(errors="replace").replace("}\n{", "},\n{") + "]"
        data = json.loads(text)
    except Exception:
        return []
    return [
        (normalize(obj["keybind"]), obj["keybind"], obj.get("label", "?"), None)
        for obj in data if "keybind" in obj
    ]


# ── conflict detection ────────────────────────────────────────────────────────

SCOPE_GLOBAL   = "global"
SCOPE_MPV      = "mpv"
SCOPE_TERMINAL = "terminal"
SCOPE_LOGOUT   = "logout"

FILE_META = {
    ".config/niri/config.kdl":     (parse_niri,    SCOPE_GLOBAL,   "niri"),
    ".config/mpv/input.conf":      (parse_mpv,     SCOPE_MPV,      "mpv"),
    ".config/micro/bindings.json": (parse_micro,   SCOPE_TERMINAL, "micro"),
    ".config/fuzzel/fuzzel.ini":   (parse_fuzzel,  SCOPE_GLOBAL,   "fuzzel"),
    ".config/helix/config.toml":   (parse_helix,   SCOPE_TERMINAL, "helix"),
    ".config/wlogout/layout":      (parse_wlogout, SCOPE_LOGOUT,   "wlogout"),
}


def check(dotfiles_dir: Path):
    binds = defaultdict(lambda: defaultdict(list))
    scanned, missing = [], []

    for rel, (parser, scope, _label) in FILE_META.items():
        path = dotfiles_dir / rel
        if not path.exists():
            missing.append(rel)
            continue
        scanned.append(rel)
        for norm_key, raw_key, action, lineno in parser(path):
            binds[scope][norm_key].append((rel, raw_key, action, lineno))

    high, medium, info = [], [], []

    for scope, keys in binds.items():
        for norm_key, entries in keys.items():
            if len(entries) < 2:
                continue
            actions = {e[2] for e in entries}
            files   = {e[0] for e in entries}
            if len(actions) == 1:
                info.append((norm_key, entries, "Duplicate aliases → same action"))
            elif len(files) == 1:
                high.append((norm_key, entries, f"Same key, different actions in {entries[0][0]}"))
            else:
                high.append((norm_key, entries, "Same key, different actions across files in same scope"))

    niri_binds = binds.get(SCOPE_GLOBAL, {})
    for scope in (SCOPE_MPV, SCOPE_TERMINAL):
        for norm_key, app_entries in binds.get(scope, {}).items():
            if norm_key in niri_binds:
                all_entries = niri_binds[norm_key] + app_entries
                if len({e[2] for e in all_entries}) > 1:
                    medium.append((norm_key, all_entries, "Global shortcut may shadow app binding"))

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
    print(f"\n{BOLD}Keybinding Conflict Report{RESET}")
    print("=" * 44)

    sections = [
        (high,   RED,    "✗ HIGH"),
        (medium, YELLOW, "⚠ MEDIUM"),
        (info,   CYAN,   "ℹ INFO"),
    ]

    if not any(s[0] for s in sections):
        print(f"\n✓  No conflicts found.\n")
    else:
        for entries_list, color, label in sections:
            if not entries_list:
                continue
            print()
            for norm_key, entries, reason in entries_list:
                print(f"{color}{BOLD}{label}{RESET}  —  {BOLD}{norm_key}{RESET}:  {reason}")
                for e in entries:
                    print(fmt_entry(*e))
                print()

    print("─" * 44)
    counts = [
        f"{RED}{BOLD}{len(high)} high{RESET}"     if high   else None,
        f"{YELLOW}{BOLD}{len(medium)} medium{RESET}" if medium else None,
        f"{CYAN}{len(info)} info{RESET}"           if info   else None,
    ]
    summary = ",  ".join(c for c in counts if c)
    print(f"  {summary}" if summary else f"  {BOLD}All clean.{RESET}")

    print(f"\n{DIM}Scanned:{RESET}")
    for f in scanned:
        print(f"  ✓  {f}")
    if missing:
        print(f"{DIM}Not found (skipped):{RESET}")
        for f in missing:
            print(f"  –  {f}")
    print()


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    dotfiles_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "~").expanduser().resolve()
    high, medium, info, scanned, missing = check(dotfiles_dir)
    print_report(high, medium, info, scanned, missing)
    sys.exit(1 if high else 0)


if __name__ == "__main__":
    main()
