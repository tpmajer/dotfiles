#!/usr/bin/env python3

# The programs that take the most memory, for the bar's memory popup: JSON,
# [{"name", "kib"}], the largest first. A program is every process with the
# same executable, so a browser with its content processes is one. Memory is
# PSS, in which a page shared by several processes counts once in all; for
# processes of other users, whose PSS cannot be read, it is RSS.

import json
import os
import re
import sys

count = int(sys.argv[1]) if len(sys.argv) > 1 else 5
totals = {}

for pid in os.listdir("/proc"):
    if not pid.isdigit():
        continue
    base = "/proc/" + pid
    try:
        try:
            name = os.path.basename(os.readlink(base + "/exe"))
        except OSError:
            with open(base + "/comm") as f:
                name = f.read().strip()
        kib = 0
        try:
            with open(base + "/smaps_rollup") as f:
                for line in f:
                    if line.startswith("Pss:"):
                        kib = int(line.split()[1])
                        break
        except OSError:
            with open(base + "/status") as f:
                for line in f:
                    if line.startswith("VmRSS:"):
                        kib = int(line.split()[1])
                        break
    except OSError:
        # Gone in the meantime, or a kernel thread.
        continue
    if kib == 0:
        continue
    # Nix wraps a program as .name-wrapped, with the program itself next to it.
    name = re.sub(r"^\.(.+?)-(un)?wrapped_?$", r"\1", name)
    totals[name] = totals.get(name, 0) + kib

top = sorted(totals.items(), key=lambda item: -item[1])[:count]
print(json.dumps([{"name": name, "kib": kib} for name, kib in top]))
