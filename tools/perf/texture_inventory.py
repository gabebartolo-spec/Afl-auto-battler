#!/usr/bin/env python3
"""List every texture under assets/vignette and assets/ui with its import settings.

Reads the committed .import files and the PNG header, so it needs no Godot run.
Filter is not an import setting in Godot 4: it comes from the project default
(nearest or linear) unless a node overrides it, so the column says "project default".
Run from the repo root: python3 tools/perf/texture_inventory.py
"""
import re, struct, sys
from pathlib import Path

MODES = {0: "lossless", 1: "lossy", 2: "VRAM compressed", 3: "VRAM uncompressed", 4: "Basis Universal"}
PACKED = ("figures_mask", "figures_design", "figures_digits", "figures_shade")


def size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return "?"
    w, h = struct.unpack(">II", head[16:24])
    return f"{w}x{h}"


def main():
    rows = []
    for d in ("assets/vignette", "assets/ui"):
        for p in sorted(Path(d).rglob("*")):
            if p.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
                continue
            imp = Path(str(p) + ".import")
            s = imp.read_text(encoding="utf8") if imp.exists() else ""
            m = re.search(r"^compress/mode=(\d+)", s, re.M)
            mm = re.search(r"^mipmaps/generate=(\w+)", s, re.M)
            mode = int(m[1]) if m else None
            rows.append((p.as_posix(), size(p), MODES.get(mode, "no .import file"), mm[1] if mm else "?", p.stem, mode))
    print("| texture | size | compress mode | mipmaps | filter |")
    print("|---|---|---|---|---|")
    flags = []
    for path, sz, mode, mm, stem, raw in rows:
        print(f"| `{path}` | {sz} | {mode} | {mm} | project default |")
        if stem in PACKED and raw != 0:
            flags.append(f"{path}: {mode}")
    print()
    if flags:
        print("Packed data textures that are not lossless:")
        for f in flags:
            print(f"- {f}")
    else:
        print("Every packed data texture is lossless.")


if __name__ == "__main__":
    sys.exit(main())
