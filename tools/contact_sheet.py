#!/usr/bin/env python3
"""Tile a set of screen captures into one labelled contact sheet.

    python3 tools/contact_sheet.py OUT.png TITLE A.png B.png ...

Each capture keeps its aspect ratio and is scaled to the same cell height;
the file name (without the tool prefix) labels it. Used by ui-review.yml so a
reviewer sees every main screen of a UI change at a glance, at phone and PC
sizes, before opening any one capture at full size.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

CELL_H = 640
GAP = 16
LABEL_H = 34
# About this wide: five phone captures a row, two or three PC ones.
TARGET_W = 3400
BG = (18, 18, 18)
INK = (235, 230, 220)


def label_of(path: str) -> str:
    stem = os.path.splitext(os.path.basename(path))[0]
    # capture_screens_light writes <prefix>_<mode>_<screen>.png
    return stem.split("_dark_", 1)[-1].replace("_", " ")


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    out, title, paths = sys.argv[1], sys.argv[2], sorted(sys.argv[3:])
    shots = []
    for p in paths:
        im = Image.open(p).convert("RGB")
        w = max(1, round(im.width * CELL_H / im.height))
        shots.append((label_of(p), im.resize((w, CELL_H), Image.LANCZOS)))
    avg_w = sum(im.width for _, im in shots) / max(1, len(shots))
    per_row = max(1, int(TARGET_W // (avg_w + GAP)))
    rows = [shots[i:i + per_row] for i in range(0, len(shots), per_row)]
    width = max(sum(im.width for _, im in r) + GAP * (len(r) + 1) for r in rows)
    height = LABEL_H * 2 + len(rows) * (CELL_H + LABEL_H + GAP) + GAP
    sheet = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 24)
        big = ImageFont.truetype("DejaVuSans-Bold.ttf", 30)
    except OSError:
        font = big = ImageFont.load_default()
    draw.text((GAP, 14), title, fill=INK, font=big)
    y = LABEL_H * 2
    for r in rows:
        x = GAP
        for name, im in r:
            draw.text((x, y), name, fill=INK, font=font)
            sheet.paste(im, (x, y + LABEL_H))
            x += im.width + GAP
        y += CELL_H + LABEL_H + GAP
    sheet.save(out)
    print("wrote %s (%d captures)" % (out, len(shots)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
