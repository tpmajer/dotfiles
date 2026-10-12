#!/usr/bin/env python3

# The machine's state, for the bar's power popup: JSON. When it booted and
# last woke (seconds since the epoch, 0 if it has not slept), the running
# kernel, the system's generation, whether what runs is no longer what the
# system would boot, the units that failed and who blocks sleep or shutdown.

import json
import os
import re
import subprocess
import time

BOOTED = "/run/booted-system/"
CURRENT = "/run/current-system/"
PROFILES = "/nix/var/nix/profiles"
SLEEPS = ["suspend", "hibernate", "hybrid-sleep", "suspend-then-hibernate"]


def run(*command):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def parsed(*command):
    try:
        return json.loads(run(*command))
    except ValueError:
        return []


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ""


def failed(*scope):
    return [u["unit"] for u in parsed("systemctl", *scope, "list-units", "--failed", "--output=json")]


# The services that put the machine to sleep end as it wakes.
def woke():
    out = run("systemctl", "show", "-P", "InactiveEnterTimestamp", "--timestamp=unix",
              *("systemd-" + s + ".service" for s in SLEEPS))
    return max((int(t) for t in re.findall(r"@(\d+)", out)), default=0)


# The newest generation that is the running system: 0 if none is, as after
# `nixos-rebuild test`.
def generation():
    current = os.path.realpath(CURRENT)
    numbers = []
    try:
        for name in os.listdir(PROFILES):
            m = re.fullmatch(r"system-(\d+)-link", name)
            if m and os.path.realpath(os.path.join(PROFILES, name)) == current:
                numbers.append(int(m.group(1)))
    except OSError:
        pass
    return max(numbers, default=0)


# Only what a switch cannot replace: the initrd is not in use once booted.
def restart():
    if any(os.path.realpath(BOOTED + f) != os.path.realpath(CURRENT + f) for f in ("kernel", "kernel-modules")):
        return True
    return read(BOOTED + "kernel-params") != read(CURRENT + "kernel-params")


def next_kernel():
    try:
        return sorted(os.listdir(CURRENT + "kernel-modules/lib/modules"))[0]
    except (OSError, IndexError):
        return ""


blockers = [
    i["who"]
    for i in parsed("systemd-inhibit", "--list", "--json=short")
    if i["mode"] == "block" and {"sleep", "shutdown"} & set(i["what"].split(":"))
]

print(json.dumps({
    "booted": round(time.time() - float(read("/proc/uptime").split()[0])),
    "woke": woke(),
    "kernel": os.uname().release,
    "generation": generation(),
    "restart": restart(),
    "nextKernel": next_kernel(),
    "failed": failed() + failed("--user"),
    "blockers": blockers,
}))
