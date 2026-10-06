"""Build one style of the game's own typeface from the art agent's SVG glyphs.

The director's decision (2026-10-06): our own type family, drawn from old
scoreboard numerals; the art agent draws, this builds. One SVG per glyph,
named by code point (u0030.svg) or by glyph name (zero.svg, A.svg,
period.svg), filled outlines only. The SVG's viewBox width is the advance.

    python tools/typeface/build_font.py --src ../ard-asset-pipeline/out/typeface/display \
        --family "ARD Scoreboard" --style Bold --out /tmp/ARDScoreboard-Bold.ttf

Coordinates: 1000 units per em by default. --baseline-y is where the
baseline sits in the SVG's own coordinates (SVG y grows downward); the
default 0 means the art is drawn above y=0 with negative y going up.
Optional files beside the SVGs:
    kern.json   {"A V": -40, "T o": -60, "one one": 0} - pair adjustments
    style.json  any of the command-line metrics, e.g. {"cap": 700, "xh": 520}
Needs fontTools and skia-pathops (pip install fonttools skia-pathops).
Prints what it built and anything a reviewer should know: missing glyphs
the game uses, digits that aren't all one width (scores would jitter).
"""

import argparse
import json
import re
import sys
from pathlib import Path

import pathops
from fontTools.agl import UV2AGL, toUnicode
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.svgLib.path import SVGPath

# What the game draws: every character a screen can show must exist, or
# Godot falls back to another font mid-word.
NEEDED = (
    "0123456789"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    ".,:;!?'\"()[]-/%$&+*#@_"
    "’‘“”–—·…▲▼‹›"
    "éèüöáíóç"
)
DIGITS = "0123456789"


def codepoint(stem: str):
    m = re.fullmatch(r"u(?:ni)?([0-9A-Fa-f]{4,6})", stem)
    if m:
        return int(m.group(1), 16)
    u = toUnicode(stem)
    return ord(u) if len(u) == 1 else None


def glyph_name(cp: int) -> str:
    return UV2AGL.get(cp, "uni%04X" % cp)


def view_box(svg_text: str):
    m = re.search(r'viewBox\s*=\s*"([^"]+)"', svg_text)
    if not m:
        raise ValueError("no viewBox")
    return [float(v) for v in m.group(1).replace(",", " ").split()]


def read_glyph(path: Path, baseline_y: float):
    """(advance, quadratic TrueType glyph, bounds) from one SVG."""
    text = path.read_text(encoding="utf-8")
    vb = view_box(text)
    advance = round(vb[2])
    outline = pathops.Path()
    # Counters drawn as a second same-way shape rely on the even-odd rule.
    if "evenodd" in text:
        outline.fillType = pathops.FillType.EVEN_ODD
    # SVG y grows down; font y grows up from the baseline.
    flip = (1, 0, 0, -1, -vb[0], baseline_y)
    SVGPath.fromstring(text.encode("utf-8"), transform=flip).draw(outline.getPen())
    # Overlapping strokes and shapes become one clean outline.
    outline = pathops.simplify(outline, fix_winding=True, keep_starting_points=False)
    tt = TTGlyphPen(None)
    outline.draw(Cu2QuPen(tt, max_err=1.0, reverse_direction=True))
    bounds = BoundsPen(None)
    outline.draw(bounds)
    return advance, tt.glyph(), bounds.bounds


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--family", default="ARD Scoreboard")
    ap.add_argument("--style", default="Regular")
    ap.add_argument("--upm", type=int, default=1000)
    ap.add_argument("--asc", type=int, default=900)
    ap.add_argument("--desc", type=int, default=-250)
    ap.add_argument("--cap", type=int, default=700)
    ap.add_argument("--xh", type=int, default=500)
    ap.add_argument("--space", type=int, default=0, help="space advance; default a quarter em")
    ap.add_argument("--baseline-y", type=float, default=0.0)
    ap.add_argument("--version", default="0.1")
    args = ap.parse_args()
    src = Path(args.src)
    style_file = src / "style.json"
    if style_file.exists():
        for k, v in json.loads(style_file.read_text(encoding="utf-8")).items():
            setattr(args, k.replace("-", "_"), v)

    glyphs = {".notdef": None}
    advances = {".notdef": args.upm // 2}
    cmap = {}
    lsb_bounds = {}
    skipped = []
    for svg in sorted(src.glob("*.svg")):
        cp = codepoint(svg.stem)
        if cp is None:
            skipped.append(svg.name)
            continue
        name = glyph_name(cp)
        adv, g, b = read_glyph(svg, args.baseline_y)
        glyphs[name] = g
        advances[name] = adv
        cmap[cp] = name
        lsb_bounds[name] = b
    space = args.space or args.upm // 4
    for cp, w in ((0x20, space), (0xA0, space)):
        if cp not in cmap:
            name = "space" if cp == 0x20 else "uni00A0"
            glyphs[name] = None
            advances[name] = w
            cmap[cp] = name
    # .notdef: a plain box, so a missing glyph is visible in review.
    pen = TTGlyphPen(None)
    w, h, t = args.upm // 2, args.cap, 60
    for (x0, y0, x1, y1), rev in (((50, 0, w - 50, h), False), ((50 + t, t, w - 50 - t, h - t), True)):
        pts = [(x0, y0), (x0, y1), (x1, y1), (x1, y0)]
        if rev:
            pts.reverse()
        pen.moveTo(pts[0])
        for p in pts[1:]:
            pen.lineTo(p)
        pen.closePath()
    glyphs[".notdef"] = pen.glyph()
    for k, v in list(glyphs.items()):
        if v is None:
            glyphs[k] = TTGlyphPen(None).glyph()

    order = [".notdef"] + sorted(n for n in glyphs if n != ".notdef")
    fb = FontBuilder(args.upm, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    metrics = {}
    for n in order:
        b = lsb_bounds.get(n)
        metrics[n] = (advances[n], int(b[0]) if b else 0)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=args.asc, descent=args.desc)
    fb.setupNameTable({
        "familyName": args.family,
        "styleName": args.style,
        "uniqueFontIdentifier": "%s-%s %s" % (args.family.replace(" ", ""), args.style, args.version),
        "fullName": "%s %s" % (args.family, args.style),
        "psName": "%s-%s" % (args.family.replace(" ", ""), args.style),
        "version": "Version %s" % args.version,
        "copyright": "Aussie Rules Dynasties. Original design, drawn for the game.",
    })
    fb.setupOS2(sTypoAscender=args.asc, sTypoDescender=args.desc, sTypoLineGap=0,
                usWinAscent=args.asc, usWinDescent=-args.desc, sxHeight=args.xh, sCapHeight=args.cap,
                fsType=0, usWeightClass=700 if "bold" in args.style.lower() else 400)
    fb.setupPost()
    kern_file = src / "kern.json"
    pairs = 0
    if kern_file.exists():
        lines = []
        for pair, value in json.loads(kern_file.read_text(encoding="utf-8")).items():
            a, b = pair.split()
            na, nb = cmap.get(codepoint(a) or ord(a[0])), cmap.get(codepoint(b) or ord(b[0]))
            if na and nb and int(value) != 0:
                lines.append("  pos %s %s %d;" % (na, nb, int(value)))
        if lines:
            addOpenTypeFeaturesFromString(fb.font, "feature kern {\n%s\n} kern;\n" % "\n".join(lines))
            pairs = len(lines)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(out))

    missing = [c for c in NEEDED if ord(c) not in cmap]
    widths = sorted({advances[cmap[ord(d)]] for d in DIGITS if ord(d) in cmap})
    print("built %s: %d glyphs, %d kern pairs, upm %d, cap %d, x-height %d" % (
        out, len(cmap), pairs, args.upm, args.cap, args.xh))
    if len(widths) > 1:
        print("  digits are not one width %s: scores and ratings will shift as they change" % widths)
    if missing:
        print("  missing %d characters the game shows: %s" % (len(missing), "".join(missing)))
    if skipped:
        print("  skipped (not a code point or glyph name): %s" % ", ".join(skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
