#!/usr/bin/env python3
"""Cut 2x crops of the figures out of full-size scene captures.

    python3 tools/figure_crops.py OUT_DIR IN_FRAMES_DIR PREFIX

Visual audit Phase 6.1 (docs/research/VISUAL_AUDIT_2026-10-10.md): feet,
hands, shadows and contact points are judged at 2x, not at the size a whole
frame is reviewed at. For every movie frame set <PREFIX>_fNNNN.png in
IN_FRAMES_DIR this takes the first, middle and last frame, crops the middle of
the pitch where the contest is (the centre 50% of the width and height) and
writes it at 2x to OUT_DIR/<PREFIX>_<first|contact|last>_2x.png. The middle
frame is the event the capture was aimed at (capture_match --kind K).
"""
import glob
import os
import sys

from PIL import Image

KEEP = 0.5  # share of the width and height kept around the centre
SCALE = 2


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    out_dir, in_dir, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    frames = sorted(glob.glob(os.path.join(in_dir, "%s_f*.png" % prefix)))
    if not frames:
        print("no frames for %s in %s" % (prefix, in_dir))
        return 1
    os.makedirs(out_dir, exist_ok=True)
    picks = [("first", frames[0]), ("contact", frames[len(frames) // 2]), ("last", frames[-1])]
    for name, path in picks:
        im = Image.open(path).convert("RGB")
        w, h = im.size
        cw, ch = round(w * KEEP), round(h * KEEP)
        box = ((w - cw) // 2, (h - ch) // 2, (w - cw) // 2 + cw, (h - ch) // 2 + ch)
        crop = im.crop(box).resize((cw * SCALE, ch * SCALE), Image.LANCZOS)
        dest = os.path.join(out_dir, "%s_%s_2x.png" % (prefix, name))
        crop.save(dest)
        print("wrote %s (%dx%d from %s)" % (dest, crop.width, crop.height, os.path.basename(path)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
