#!/usr/bin/env python3

# Builds fonts/bar-icons.ttf: the Wi-Fi levels Font Awesome Free has no
# glyph for, cut from its full one, which is two arcs and a dot apart. They
# sit above U+100000, where the Nerd Font has nothing, with its metrics,
# so the shell falls back to them in the same line of text.
#
#   nix shell --impure --expr 'with import (builtins.getFlake "nixpkgs") {};
#     python3.withPackages (p: [p.fonttools])' -c \
#     scripts/bar-icons.py <JetBrainsMonoNerdFontPropo-Regular.ttf>
#
# Font Awesome Free's font is under the SIL OFL 1.1, as is this one.

import sys
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

WIFI = 0xF1EB
# The glyph's contours from the outside in: the outer arc, the inner arc,
# the dot. A level keeps the ones named.
LEVELS = {
    0x100000: ("wifi-weak", (2,)),
    0x100001: ("wifi-fair", (1, 2)),
}

source = TTFont(sys.argv[1])
glyphs = source.getGlyphSet()
name = source.getBestCmap()[WIFI]

pen = DecomposingRecordingPen(glyphs)
glyphs[name].draw(pen)
contours, contour = [], []
for step in pen.value:
    contour.append(step)
    if step[0] in ("closePath", "endPath"):
        contours.append(contour)
        contour = []
if len(contours) != 3:
    sys.exit(f"the Wi-Fi glyph has {len(contours)} contours, not 3")


def top(contour):
    return max(point[1] for _, points in contour for point in points)


contours.sort(key=top, reverse=True)


def cut(kept):
    pen = TTGlyphPen(None)
    for index in kept:
        for operator, points in contours[index]:
            getattr(pen, operator)(*points)
    return pen.glyph()


outlines = {".notdef": TTGlyphPen(None).glyph()}
outlines.update({glyph: cut(kept) for glyph, kept in LEVELS.values()})
advance = glyphs[name].width

font = FontBuilder(source["head"].unitsPerEm, isTTF=True)
font.setupGlyphOrder(list(outlines))
font.setupCharacterMap({code: glyph for code, (glyph, _) in LEVELS.items()})
font.setupGlyf(outlines)
font.setupHorizontalMetrics({glyph: (advance, font.font["glyf"][glyph].xMin if glyph != ".notdef" else 0) for glyph in outlines})
font.setupHorizontalHeader(ascent=source["hhea"].ascent, descent=source["hhea"].descent, lineGap=source["hhea"].lineGap)
font.setupNameTable({
    "familyName": "Bar Icons",
    "styleName": "Regular",
    "copyright": "Glyphs derived from Font Awesome Free, (c) Fonticons, Inc.",
    "licenseDescription": "SIL Open Font License 1.1",
    "licenseInfoURL": "https://openfontlicense.org",
})
os2 = source["OS/2"]
font.setupOS2(
    version=os2.version if os2.version >= 4 else 4,
    sTypoAscender=os2.sTypoAscender,
    sTypoDescender=os2.sTypoDescender,
    sTypoLineGap=os2.sTypoLineGap,
    usWinAscent=os2.usWinAscent,
    usWinDescent=os2.usWinDescent,
    fsSelection=os2.fsSelection,
)
font.setupPost()

target = Path(__file__).resolve().parent.parent / "fonts" / "bar-icons.ttf"
target.parent.mkdir(exist_ok=True)
font.save(target)
print(target)
