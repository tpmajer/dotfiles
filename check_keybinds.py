#!/usr/bin/env python3
"""
check_keybinds — scan dotfiles for keybinding conflicts.

Usage:
    python check_keybinds.py [DOTFILES_DIR] [--no-live]

DOTFILES_DIR defaults to ~ if not given.

Fish bindings are mostly installed at runtime by plugins rather than written
into a config file, so they are collected by running `bind` in an interactive
fish (private mode, so nothing is added to the shell history). Pass --no-live
to skip that and scan files only.
"""

import json
import re
import shlex
import shutil
import subprocess
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


FISH_MODIFIERS = ("ctrl-", "alt-", "shift-")


def fish_key_to_combo(seq: str) -> str:
    """Turn a fish key sequence (ctrl-alt-f) into a combo string (ctrl+alt+f)."""
    mods, rest = [], seq
    peeled = True
    while peeled:
        peeled = False
        for mod in FISH_MODIFIERS:
            if rest.startswith(mod) and len(rest) > len(mod):
                mods.append(mod[:-1])
                rest = rest[len(mod):]
                peeled = True
                break
    return "+".join(mods + ([rest] if rest else []))


MODE_SUFFIX_RE = re.compile(r"\[[^\]]+\]$")


def base_key(norm_key: str) -> str:
    """Drop a trailing [mode] tag, so keys compare across scopes."""
    return MODE_SUFFIX_RE.sub("", norm_key)


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


GHOSTTY_TRIGGER_PREFIXES = ("global:", "all:", "unconsumed:", "performable:")


def parse_ghostty(path: Path):
    results = []
    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        name, sep, value = stripped.partition("=")
        if not sep or name.strip() != "keybind":
            continue

        trigger, sep, action = value.strip().partition("=")
        if not sep:
            continue  # `keybind = clear` and friends bind nothing

        trigger = trigger.strip()
        changed = True
        while changed:
            changed = False
            for prefix in GHOSTTY_TRIGGER_PREFIXES:
                if trigger.startswith(prefix):
                    trigger = trigger[len(prefix):]
                    changed = True

        if not trigger:
            continue

        # `ctrl+a>n` is a two-chord sequence; normalise each chord separately
        norm = ">".join(normalize(chord) for chord in trigger.split(">"))
        results.append((norm, trigger, action.strip(), lineno))
    return results


def parse_fish_bind(argstr: str):
    """Parse the arguments of one `bind` command.

    Returns (norm_key, raw_key, action, is_preset) or None when the line does
    not define a binding.
    """
    if "\\e" in argstr or "\\x" in argstr:
        return None  # raw escape sequences (arrow keys and such)

    try:
        args = shlex.split(argstr)
    except ValueError:
        return None

    preset, mode, rest = False, "default", []
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--preset":
            preset = True
        elif arg in ("-M", "--mode"):
            mode = args[i + 1] if i + 1 < len(args) else mode
            i += 1
        elif arg.startswith("--mode="):
            mode = arg.split("=", 1)[1]
        elif arg in ("-m", "--sets-mode"):
            i += 1  # takes a value we do not care about
        elif arg in ("-e", "--erase", "-a", "--all", "--user", "-f",
                     "--function-names", "-L", "--list-modes", "-K", "--key-names"):
            return None  # queries and erasures, not definitions
        else:
            rest.append(arg)
        i += 1

    if len(rest) < 2 or not rest[0]:
        return None

    seq, action = rest[0], " ".join(rest[1:])
    combo = fish_key_to_combo(seq)
    if not combo:
        return None
    return f"{normalize(combo)}[{mode}]", seq, action, preset


def parse_fish_config(path: Path):
    """Literal `bind` commands written into a fish config file."""
    results = []
    for lineno, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        stripped = line.strip()
        if not stripped.startswith("bind ") or stripped.startswith("#"):
            continue
        parsed = parse_fish_bind(stripped[len("bind "):])
        if parsed:
            norm_key, raw_key, action, _preset = parsed
            results.append((norm_key, raw_key, action, lineno))
    return results


ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

FISH_LIVE_LABEL = "fish (live `bind`)"


def fish_live_bindings():
    """Bindings actually installed in an interactive fish.

    Plugins bind keys from conf.d and config.fish, so the file contents alone
    say very little. `fish -c 'bind'` only reports a small preset subset, so a
    real interactive session is needed; -P keeps it out of the shell history.

    Returns a list of (origin, norm_key, raw_key, action), or None when the
    bindings could not be collected.
    """
    if shutil.which("fish") is None or shutil.which("script") is None:
        return None

    try:
        proc = subprocess.run(
            ["script", "-qec", "fish -P", "/dev/null"],
            input="bind\nexit\n",
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (subprocess.SubprocessError, OSError):
        return None

    results = []
    for line in ANSI_RE.sub("", proc.stdout.replace("\r", "")).splitlines():
        stripped = line.strip()
        if not stripped.startswith("bind "):
            continue
        parsed = parse_fish_bind(stripped[len("bind "):])
        if not parsed:
            continue
        norm_key, raw_key, action, preset = parsed
        origin = "fish:default" if preset else "fish:user"
        results.append((origin, norm_key, raw_key, action))

    return results or None


# ── conflict detection ────────────────────────────────────────────────────────

SCOPE_GLOBAL   = "global"
SCOPE_MPV      = "mpv"
SCOPE_TERMINAL = "terminal"
SCOPE_LOGOUT   = "logout"
SCOPE_SHELL    = "shell"
SCOPE_TERM_EMU = "terminal-emulator"

FILE_META = {
    ".config/niri/config.kdl":     (parse_niri,    SCOPE_GLOBAL,   "niri"),
    ".config/mpv/input.conf":      (parse_mpv,     SCOPE_MPV,      "mpv"),
    ".config/micro/bindings.json": (parse_micro,   SCOPE_TERMINAL, "micro"),
    ".config/fuzzel/fuzzel.ini":   (parse_fuzzel,  SCOPE_GLOBAL,   "fuzzel"),
    ".config/helix/config.toml":   (parse_helix,   SCOPE_TERMINAL, "helix"),
    ".config/wlogout/layout":      (parse_wlogout, SCOPE_LOGOUT,   "wlogout"),
    ".config/ghostty/config":      (parse_ghostty, SCOPE_TERM_EMU, "ghostty"),
}

# Patterns rather than single files: fish spreads bindings over several files.
GLOB_META = {
    ".config/fish/config.fish":   (parse_fish_config, SCOPE_SHELL, "fish"),
    ".config/fish/conf.d/*.fish": (parse_fish_config, SCOPE_SHELL, "fish"),
}


def dedupe(entries):
    """Drop repeated entries, keeping order. Modes multiply otherwise-identical rows."""
    seen, out = set(), []
    for entry in entries:
        if entry not in seen:
            seen.add(entry)
            out.append(entry)
    return out


def collect_shadowing(binds, over_scope, under_scopes, reason, out):
    """Flag keys claimed by `over_scope` that a lower layer also binds.

    Keys are compared with their [mode] tag stripped, and each key is reported
    once however many modes bind it.
    """
    over, under = defaultdict(list), defaultdict(list)

    for norm_key, entries in binds.get(over_scope, {}).items():
        over[base_key(norm_key)].extend(entries)

    for scope in under_scopes:
        for norm_key, entries in binds.get(scope, {}).items():
            under[base_key(norm_key)].extend(entries)

    for key, app_entries in under.items():
        outer = over.get(key)
        if not outer:
            continue
        all_entries = dedupe(outer + app_entries)
        if len({e[2] for e in all_entries}) > 1:
            out.append((key, all_entries, reason))


def check(dotfiles_dir: Path, include_live: bool = True):
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

    for pattern, (parser, scope, _label) in GLOB_META.items():
        matches = sorted(dotfiles_dir.glob(pattern))
        if not matches:
            missing.append(pattern)
            continue
        for path in matches:
            rel = str(path.relative_to(dotfiles_dir))
            scanned.append(rel)
            for norm_key, raw_key, action, lineno in parser(path):
                binds[scope][norm_key].append((rel, raw_key, action, lineno))

    if include_live:
        live = fish_live_bindings()
        if live is None:
            missing.append(FISH_LIVE_LABEL)
        else:
            scanned.append(FISH_LIVE_LABEL)
            for origin, norm_key, raw_key, action in live:
                binds[SCOPE_SHELL][norm_key].append((origin, raw_key, action, None))

    high, medium, info = [], [], []

    for scope, keys in binds.items():
        for norm_key, entries in keys.items():
            if len(entries) < 2:
                continue
            actions = {e[2] for e in entries}
            files   = {e[0] for e in entries}
            presets = [e for e in entries if e[0] == "fish:default"]
            others  = [e for e in entries if e[0] != "fish:default"]

            if len(actions) == 1:
                info.append((norm_key, entries, "Duplicate aliases → same action"))
            elif presets and len({e[2] for e in others}) <= 1:
                medium.append((norm_key, entries,
                               "fish default replaced by a plugin binding"))
            elif len(files) == 1:
                high.append((norm_key, entries, f"Same key, different actions in {entries[0][0]}"))
            else:
                high.append((norm_key, entries, "Same key, different actions across files in same scope"))

    collect_shadowing(binds, SCOPE_GLOBAL,
                      (SCOPE_MPV, SCOPE_TERMINAL, SCOPE_SHELL, SCOPE_TERM_EMU),
                      "Global shortcut may shadow app binding", medium)
    collect_shadowing(binds, SCOPE_TERM_EMU, (SCOPE_SHELL, SCOPE_TERMINAL),
                      "Terminal grabs the key before the shell or TUI app sees it", medium)

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
    args = [a for a in sys.argv[1:] if a != "--no-live"]
    include_live = "--no-live" not in sys.argv[1:]

    dotfiles_dir = Path(args[0] if args else "~").expanduser().resolve()
    high, medium, info, scanned, missing = check(dotfiles_dir, include_live)
    print_report(high, medium, info, scanned, missing)
    sys.exit(1 if high else 0)


if __name__ == "__main__":
    main()
