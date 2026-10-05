#!/usr/bin/env python3

# The file next to the one mpv plays, for the bar's "next" and "previous"
# without a playlist: the video or audio file after it in its directory,
# or before it, by name with the numbers in it as numbers (2 before 10).
# The types are uosc's, whose shift+right does the same in mpv itself.
# Prints its file:// address, or nothing at the directory's end.
#
#   media-sibling.py <file:// address or path> <1 | -1>

import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

TYPES = set(
    # video
    "3g2 3gp asf avi f4v flv h264 h265 m2ts m4v mkv mov mp4 mp4v mpeg mpg"
    " ogm ogv rm rmvb ts vob webm wmv y4m"
    # audio
    " aac ac3 aiff ape au cue dsf dts flac m4a mid midi mka mp3 mp4a oga"
    " ogg opus spx tak tta wav weba wma wv".split()
)


def natural(path):
    return [
        (0, int(part), "") if part.isdigit() else (1, 0, part)
        for part in re.split(r"(\d+)", path.name.casefold())
        if part
    ]


def main():
    address, step = sys.argv[1], int(sys.argv[2])
    current = Path(unquote(urlparse(address).path) if address.startswith("file://") else address)
    try:
        files = sorted(
            (f for f in current.parent.iterdir() if f.suffix[1:].lower() in TYPES and f.is_file()),
            key=natural,
        )
        sibling = files.index(current) + step
    except (OSError, ValueError):
        return
    if 0 <= sibling < len(files):
        print(files[sibling].as_uri())


main()
