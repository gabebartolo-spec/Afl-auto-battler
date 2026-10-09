#!/usr/bin/env python3
"""Cut 2x crops of the figures out of full-size scene captures.

    python3 tools/figure_crops.py OUT_DIR IN_FRAMES_DIR PREFIX [X0,Y0,X1,Y1]

Visual audit Phase 6.1 (docs/research/VISUAL_AUDIT_2026-10-10.md): feet,
hands, shadows and contact points are judged at 2x, not at the size a whole
frame is reviewed at. For every movie frame set <PREFIX>_film_NNN.png in
IN_FRAMES_DIR (the --film frames of capture_prematch and capture_vignette) this
takes the first, middle and last frame, crops the box X0,Y0,X1,Y1 (fractions of
the frame; default 0.25,0.45,0.75,0.95: the players' legs and boots on the
phone-size scene) and writes it at 2x (nearest neighbour, so the pixels stay honest) to
OUT_DIR/<PREFIX>_<first|contact|last>_2x.png.
"""
import glob
import os
import sys

from PIL import Image

BOX = (0.25, 0.45, 0.75, 0.95)
SCALE = 2


def main() -> int:
    if len(sys.argv) not in (4, 5):
        print(__doc__)
        return 2
    out_dir, in_dir, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    box = tuple(float(v) for v in sys.argv[4].split(",")) if len(sys.argv) == 5 else BOX
    frames = sorted(glob.glob(os.path.join(in_dir, "%s_film_*.png" % prefix)))
    if not frames:
        print("no frames for %s in %s" % (prefix, in_dir))
        return 1
    os.makedirs(out_dir, exist_ok=True)
    picks = [("first", frames[0]), ("contact", frames[len(frames) // 2]), ("last", frames[-1])]
    for name, path in picks:
        im = Image.open(path).convert("RGB")
        w, h = im.size
        px = (round(w * box[0]), round(h * box[1]), round(w * box[2]), round(h * box[3]))
        crop = im.crop(px)
        crop = crop.resize((crop.width * SCALE, crop.height * SCALE), Image.NEAREST)
        dest = os.path.join(out_dir, "%s_%s_2x.png" % (prefix, name))
        crop.save(dest)
        print("wrote %s (%dx%d from %s)" % (dest, crop.width, crop.height, os.path.basename(path)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
