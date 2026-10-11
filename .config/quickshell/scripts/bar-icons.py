#!/usr/bin/env python3

# Builds fonts/bar-icons.ttf: the glyphs Font Awesome Free has none for in
# the Nerd Font, cut from the ones it has. The Wi-Fi levels come from the
# full icon, which is two arcs and a dot apart, the filled moon from the
# outlined one without its inner contour. They sit above U+100000, where
# the Nerd Font has nothing, with its metrics, so the shell falls back to
# them in the same line of text.
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
MOON = 0xF186
# A glyph's name, the one it is cut from, how many contours that one has
# and which of them stay, counted from the top: the outer arc, the inner
# arc and the dot of the Wi-Fi icon, the moon's edge and the hole in it.
GLYPHS = {
    0x100000: ("wifi-weak", WIFI, 3, (2,)),
    0x100001: ("wifi-fair", WIFI, 3, (1, 2)),
    0x100002: ("moon-filled", MOON, 2, (0,)),
}

source = TTFont(sys.argv[1])
glyphs = source.getGlyphSet()
codes = source.getBestCmap()


def top(contour):
    return max(point[1] for _, points in contour for point in points)


def cut(code, count, kept):
    pen = DecomposingRecordingPen(glyphs)
    glyphs[codes[code]].draw(pen)
    contours, contour = [], []
    for step in pen.value:
        contour.append(step)
        if step[0] in ("closePath", "endPath"):
            contours.append(contour)
            contour = []
    if len(contours) != count:
        sys.exit(f"U+{code:X} has {len(contours)} contours, not {count}")
    contours.sort(key=top, reverse=True)
    pen = TTGlyphPen(None)
    for index in kept:
        for operator, points in contours[index]:
            getattr(pen, operator)(*points)
    return pen.glyph()


outlines = {".notdef": TTGlyphPen(None).glyph()}
advances = {".notdef": 0}
for glyph, code, count, kept in GLYPHS.values():
    outlines[glyph] = cut(code, count, kept)
    advances[glyph] = glyphs[codes[code]].width

font = FontBuilder(source["head"].unitsPerEm, isTTF=True)
font.setupGlyphOrder(list(outlines))
font.setupCharacterMap({code: glyph for code, (glyph, *_) in GLYPHS.items()})
font.setupGlyf(outlines)
font.setupHorizontalMetrics({glyph: (advances[glyph], font.font["glyf"][glyph].xMin if glyph != ".notdef" else 0) for glyph in outlines})
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
