#!/usr/bin/env python3
"""Render docs/preview_match.{svg,png} - a static picture of the match screen.

Godot cannot run headless everywhere, so this reproduces the exact geometry and
palette of scripts/ui/PitchView.gd and scripts/ui/MatchScene.gd. The match it
shows is real: tools/sim_harness.py simulates it from the harvested 2026 data
and this script freezes one moment of it.

The layout is built once as a display list, then emitted twice - as SVG (crisp,
for the repo) and as a rasterised PNG (viewable anywhere). If you change the
oval's proportions, slot formations or colours in PitchView.gd, mirror it here:

    python3 tools/render_preview.py
"""

from __future__ import annotations

import csv
import math
import os
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import sim_harness as H  # noqa: E402

OUT_SVG = os.path.join(ROOT, "docs", "preview_match.svg")
OUT_PNG = os.path.join(ROOT, "docs", "preview_match.png")

# --- palette, kept in step with scripts/ui/UiKit.gd -------------------------
BG = "#0b170c"
PANEL = "#19231b"
PANEL_ALT = "#222e24"
LINE = "#ffffff1a"
TEXT = "#edf2ed"
MUTED = "#a1b0a3"
GOLD = "#fad152"
GOOD = "#73d97a"
TURF = "#1e5522"
STRIPE = "#225d26"
BALL = "#faedd9"
BALL_EDGE = "#40201a"
SHADOW = "#00000047"
TOKEN_EDGE = "#00000059"
ACTOR_RING = "#ffff8cf2"
BOUNDARY = "#ffffffd9"
PITCH_LINE = "#ffffff8c"
POST = "#ffffffe6"

# --- geometry, kept in step with scripts/ui/PitchView.gd --------------------
GOAL_LINE_M = 85.0
ASPECT = 1.28
SLOTS = {
    "RUCK": [(0.0, 0.0)],
    "MID": [(0.12, -0.46), (0.12, 0.46), (-0.04, -0.20), (-0.04, 0.20),
            (0.24, 0.02), (-0.20, -0.58), (-0.20, 0.58)],
    "DEF": [(-0.50, -0.52), (-0.50, 0.52), (-0.63, -0.22), (-0.63, 0.22),
            (-0.76, 0.0)],
    "FWD": [(0.54, -0.42), (0.54, 0.42), (0.67, -0.16), (0.67, 0.16),
            (0.80, 0.0)],
}

VIEW_W, VIEW_H = 1280, 720
FONT = "DejaVu Sans, Helvetica, sans-serif"


def wrap(line, width):
    out, cur = [], ""
    for word in line.split(" "):
        if cur and len(cur) + 1 + len(word) > width:
            out.append(cur)
            cur = word
        else:
            cur = (cur + " " + word) if cur else word
    if cur:
        out.append(cur)
    return out or [""]


def arc_span(cx, cy, a, b, gx, gy, r):
    """Mirror of PitchView._arc_span: keep only the arc inside the oval."""
    base = math.atan2(cy - gy, cx - gx)
    lo, hi = base - math.pi * 0.5, base + math.pi * 0.5
    steps = 64
    a0, a1 = lo, hi
    for i in range(steps + 1):
        ang = lo + (hi - lo) * i / steps
        if _inside(gx + r * math.cos(ang), gy + r * math.sin(ang), cx, cy, a, b):
            a0 = ang
            break
    for i in range(steps + 1):
        ang = hi + (lo - hi) * i / steps
        if _inside(gx + r * math.cos(ang), gy + r * math.sin(ang), cx, cy, a, b):
            a1 = ang
            break
    return a0, a1


def _inside(px, py, cx, cy, a, b):
    dx, dy = (px - cx) / a, (py - cy) / b
    return dx * dx + dy * dy <= 1.0


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def readable_on(hexcol: str) -> str:
    h = hexcol.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return "#14141a" if 0.299 * r + 0.587 * g + 0.114 * b > 0.55 else "#ffffff"


def spare_slot(i: int):
    """Mirrors PitchView._spare_slot, before the side's direction is applied."""
    return (math.fmod(i * 0.17, 0.5) - 0.25, math.fmod(i * 0.31, 1.2) - 0.6)


# ---------------------------------------------------------------------------
# The match
# ---------------------------------------------------------------------------
def build_moment(home_code="RIC", away_code="COL", seed=20260714):
    players = H.load_players()
    H.derive_ratings(players)
    cm = H.by_club(players)

    with open(os.path.join(ROOT, "data", "clubs.csv"), newline="",
              encoding="utf-8") as fh:
        clubs = {r["code"]: r for r in csv.DictReader(fh)}

    sim = H.MatchSim(H.Squad(home_code, cm[home_code], True),
                     H.Squad(away_code, cm[away_code], False),
                     seed=seed, narrate=True)
    sim.run()

    # Freeze on the home side's first second-half goal: it shows the score
    # flare, a meaningful field position and a feed with something in it.
    moment = None
    for i, e in enumerate(sim.events):
        if e["kind"] == "goal" and e["quarter"] >= 3 and e["side"] == 0:
            moment = (i, e)
            break
    if moment is None:
        for i, e in enumerate(sim.events):
            if e["kind"] == "goal":
                moment = (i, e)
                break
    idx, ev = moment
    feed = [e for e in sim.events[:idx + 1]
            if e["kind"] not in ("kick", "handball", "info")][-11:]

    ground = {}
    for code in (home_code, away_code):
        g, _bench = H.select_22(cm[code])
        ground[code] = g
    return {"clubs": clubs, "home": home_code, "away": away_code,
            "ground": ground, "ev": ev, "idx": idx, "feed": feed,
            "final": (sim.stats.score(0), sim.stats.score(1))}


def scoreline(total: int) -> str:
    return "%d.%d (%d)" % (total // 6, total - (total // 6) * 6, total)


# ---------------------------------------------------------------------------
# Display list
# ---------------------------------------------------------------------------
class Scene:
    """Primitives in paint order. Each is a tuple; both backends read these."""

    def __init__(self):
        self.ops = []

    def rect(self, x, y, w, h, fill=None, radius=0.0, stroke=None, sw=1.0,
             clip=None):
        self.ops.append(("rect", x, y, w, h, fill, radius, stroke, sw, clip))

    def circle(self, cx, cy, r, fill=None, stroke=None, sw=1.0):
        self.ops.append(("circle", cx, cy, r, fill, stroke, sw))

    def ellipse(self, cx, cy, rx, ry, fill=None, stroke=None, sw=1.0):
        self.ops.append(("ellipse", cx, cy, rx, ry, fill, stroke, sw))

    def arc(self, cx, cy, r, a0, a1, stroke, sw=1.0):
        self.ops.append(("arc", cx, cy, r, a0, a1, stroke, sw))

    def text(self, x, y, s, size=14, fill=TEXT, anchor="start", weight="normal"):
        self.ops.append(("text", x, y, s, size, fill, anchor, weight))


# ---------------------------------------------------------------------------
# Build the screen
# ---------------------------------------------------------------------------
def build_scene(m) -> Scene:
    s = Scene()
    clubs, home, away = m["clubs"], m["home"], m["away"]
    hp, _hs, ha = colour(clubs, home)
    ap, _as, aa = colour(clubs, away)
    ev = m["ev"]
    sc = ev["score"]

    s.rect(0, 0, VIEW_W, VIEW_H, BG)

    mx, my = 12, 10
    iw, ih = VIEW_W - mx * 2, VIEW_H - my * 2

    # --- scoreboard --------------------------------------------------------
    sb_h = 76
    s.rect(mx, my, iw, sb_h, PANEL, 10, LINE)
    s.rect(mx + 10, my + 12, 14, sb_h - 24, hp, 4, ha, 2)
    s.rect(mx + iw - 24, my + 12, 14, sb_h - 24, ap, 4, aa, 2)
    s.text(mx + iw * 0.245, my + 47, clubs[home]["name"], 17, TEXT, "end", "bold")
    s.text(mx + iw * 0.40, my + 51, scoreline(sc[0]), 27, ha, "end", "bold")
    s.text(mx + iw * 0.60, my + 51, scoreline(sc[1]), 27, aa, "start", "bold")
    s.text(mx + iw * 0.755, my + 47, clubs[away]["name"], 17, TEXT, "start", "bold")
    mid = mx + iw / 2
    s.text(mid, my + 22, "Round 14", 12, MUTED, "middle")
    s.text(mid, my + 47, "Q%d %d'" % (ev["quarter"], ev["minute"]), 20, TEXT,
           "middle", "bold")
    s.text(mid, my + 65, clubs[home]["ground"], 11, MUTED, "middle")

    # --- body --------------------------------------------------------------
    gap, top = 10, my + sb_h + 8
    body_h = ih - sb_h - 8
    side_w = 340
    pitch_w = iw - side_w - gap
    build_pitch(s, mx, top, pitch_w, body_h, m)

    sx = mx + pitch_w + gap
    s.rect(sx, top, side_w, body_h, PANEL, 10, LINE)
    s.text(sx + 12, top + 26, "Commentary", 15, GOLD, "start", "bold")

    kinds = {"goal": GOLD, "behind": "#b8d1f2", "tackle": "#ccb8f2",
             "clanger": "#f2b39e", "free": "#f2b39e", "inside50": "#a8e6b3",
             "mark": "#d9e6f2", "quarter": GOOD, "final": GOOD}
    fy = top + 48
    for e in m["feed"]:
        line = "Q%d %2d'  %s" % (e["quarter"], e["minute"], e["text"])
        line = line.replace("\u2014", "-").replace("\u2019", "'")
        bold = "bold" if e["kind"] in ("goal", "quarter", "final") else "normal"
        col = kinds.get(e["kind"], MUTED)
        for chunk in wrap(line, 33):
            s.text(sx + 12, fy, chunk, 11, col, "start", bold)
            fy += 15
        fy += 3

    cy0 = top + body_h - 96
    bw = (side_w - 24 - 5 * 5) / 5
    s.rect(sx + 12, cy0, bw * 1.6, 40, "#294d30", 8, GOLD, 2)
    s.text(sx + 12 + bw * 0.8, cy0 + 25, "Pause", 13, TEXT, "middle")
    bx = sx + 12 + bw * 1.6 + 5
    for i, lab in enumerate(["1x", "2x", "4x", "8x"]):
        s.rect(bx, cy0, bw * 0.72, 40, PANEL_ALT, 8, LINE)
        s.text(bx + bw * 0.36, cy0 + 25, lab, 13,
               TEXT if i == 2 else "#edf2ed73", "middle")
        bx += bw * 0.72 + 5
    half = (side_w - 24 - 5) / 2
    for i, lab in enumerate(["Skip to full time", "Back to Hub"]):
        s.rect(sx + 12 + i * (half + 5), cy0 + 46, half, 40, PANEL_ALT, 8, LINE)
        s.text(sx + 12 + i * (half + 5) + half / 2, cy0 + 71, lab, 13, TEXT,
               "middle")

    s.text(VIEW_W / 2, VIEW_H - 6,
           "Static preview from tools/render_preview.py - a real simulated match. "
           "The game itself is Godot 4.7.", 10, "#7d8a7f", "middle")
    return s


def colour(clubs, code):
    c = clubs.get(code, {})
    return (c.get("primary", "#ffffff"), c.get("secondary", "#555555"),
            c.get("accent", GOLD))


def build_pitch(s: Scene, x, y, w, h, m) -> None:
    """Reproduces PitchView._draw() for a control at (x, y) sized (w, h)."""
    margin = 10.0
    avail_w, avail_h = w - margin * 2, h - margin * 2
    pw, ph = avail_w, avail_w / ASPECT
    if ph > avail_h:
        ph, pw = avail_h, avail_h * ASPECT
    px, py = x + (w - pw) / 2, y + (h - ph) / 2
    cx, cy = px + pw / 2, py + ph / 2
    a, b = pw / 2, ph / 2

    s.rect(x, y, w, h, BG)
    clip = (cx, cy, a, b)
    s.ellipse(cx, cy, a, b, TURF)

    n = 9
    for i in range(n):
        if i % 2 == 1:
            continue
        sx = cx - a + (2 * a) * i / n
        s.rect(sx, cy - b, (2 * a) / n, 2 * b, STRIPE, clip=clip)

    s.ellipse(cx, cy, a, b, None, BOUNDARY, 2.5)

    m2px = a / GOAL_LINE_M
    sq = 22.5 * m2px
    s.rect(cx - sq, cy - sq, sq * 2, sq * 2, None, 0, PITCH_LINE, 1.6)
    s.arc(cx, cy, 3.0 * m2px, 0, math.tau, PITCH_LINE, 1.6)

    for sgn in (-1.0, 1.0):
        gx = cx + sgn * a * 0.985
        a0, a1 = arc_span(cx, cy, a, b, gx, cy, 50.0 * m2px)
        s.arc(gx, cy, 50.0 * m2px, a0, a1, PITCH_LINE, 1.6)
        depth, width = 9.0 * m2px, 6.44 * m2px
        rx = gx - depth if sgn > 0 else gx
        s.rect(rx, cy - width / 2, depth, width, None, 0, PITCH_LINE, 1.6)
        for pys in (-1.0, 1.0):
            s.circle(gx, cy + pys * 3.22 * m2px, max(2.0, b * 0.012), POST)

    ev = m["ev"]
    fp = 82.0 if ev["kind"] in ("goal", "behind") else 24.0
    if ev["side"] == 1:
        fp = -fp
    nx = clamp(fp / GOAL_LINE_M, -1.0, 1.0)
    ny = clamp(math.sin(m["idx"] * 1.7) * 0.22, -0.6, 0.6)
    tr = max(4.0, min(a, b) * 0.030)

    def to_px(ux, uy):
        return (px + (ux * 0.5 + 0.5) * pw, py + (uy * 0.5 + 0.5) * ph)

    actor_pos = None
    for code, side in ((m["home"], 0), (m["away"], 1)):
        d = 1.0 if side == 0 else -1.0
        primary, secondary, _accent = colour(m["clubs"], code)
        groups = {"RUCK": [], "MID": [], "DEF": [], "FWD": []}
        for p in m["ground"][code]:
            groups.get(p["role"], groups["MID"]).append(p)
        for role in ("RUCK", "MID", "DEF", "FWD"):
            for i, p in enumerate(groups[role]):
                slots = SLOTS[role]
                base = slots[i] if i < len(slots) else spare_slot(i)
                bx_, by_ = base[0] * d, base[1]
                tx = clamp(bx_ + 0.45 * nx, -0.94, 0.94)
                ty = clamp(by_ * (0.88 + 0.10 * abs(nx)), -0.90, 0.90)
                if ev.get("side") == side and p["name"] in ev["text"]:
                    tx, ty = nx, ny
                    actor_pos = to_px(tx, ty)
                ux, uy = to_px(tx, ty)
                fs = clamp(tr * 1.15, 6.0, 14.0)
                s.circle(ux, uy + tr * 0.22, tr, SHADOW)
                s.circle(ux, uy, tr, primary)
                s.circle(ux, uy, tr * 0.62, secondary)
                s.circle(ux, uy, tr, None, TOKEN_EDGE, 1.2)
                s.text(ux, uy + fs * 0.36, str(int(p["num"])), fs,
                       readable_on(primary), "middle", "bold")

    if actor_pos is not None:
        s.circle(actor_pos[0], actor_pos[1], tr * 1.9, None, ACTOR_RING, 2.0)

    bx, by = to_px(nx, ny)
    if ev["kind"] in ("goal", "behind"):
        t = 0.42
        rad = tr + (min(a, b) * 0.42 - tr) * t
        alpha = "%02x" % int((1.0 - t) * 0.85 * 255)
        col = "#fad159" if ev["kind"] == "goal" else "#d9e6ff"
        s.circle(bx, by, rad, None, col + alpha, 4.0)
    s.ellipse(bx, by, tr * 0.42, tr * 0.30, BALL, BALL_EDGE, 1.0)


# ---------------------------------------------------------------------------
# SVG backend
# ---------------------------------------------------------------------------
def esc(t: str) -> str:
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def to_svg(s: Scene) -> str:
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{VIEW_W}" '
           f'height="{VIEW_H}" viewBox="0 0 {VIEW_W} {VIEW_H}">']
    clips = {}
    for op in s.ops:
        kind = op[0]
        if kind == "rect":
            _t, x, y, w, h, fill, radius, stroke, sw, clip = op
            attrs = (f'x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}"')
            if radius:
                attrs += f' rx="{radius}"'
            if fill:
                attrs += f' fill="{fill}"'
            else:
                attrs += ' fill="none"'
            if stroke:
                attrs += f' stroke="{stroke}" stroke-width="{sw}"'
            if clip:
                key = "c%d" % len(clips)
                if tuple(clip) not in clips:
                    clips[tuple(clip)] = key
                    key = clips[tuple(clip)]
                    out.append(f'<defs><clipPath id="{key}"><ellipse '
                               f'cx="{clip[0]:.1f}" cy="{clip[1]:.1f}" '
                               f'rx="{clip[2]:.1f}" ry="{clip[3]:.1f}"/>'
                               f'</clipPath></defs>')
                else:
                    key = clips[tuple(clip)]
                attrs += f' clip-path="url(#{key})"'
            out.append(f"<rect {attrs}/>")
        elif kind == "circle":
            _t, cx, cy, r, fill, stroke, sw = op
            attrs = f'cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}"'
            attrs += f' fill="{fill}"' if fill else ' fill="none"'
            if stroke:
                attrs += f' stroke="{stroke}" stroke-width="{sw}"'
            out.append(f"<circle {attrs}/>")
        elif kind == "ellipse":
            _t, cx, cy, rx, ry, fill, stroke, sw = op
            attrs = f'cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}"'
            attrs += f' fill="{fill}"' if fill else ' fill="none"'
            if stroke:
                attrs += f' stroke="{stroke}" stroke-width="{sw}"'
            out.append(f"<ellipse {attrs}/>")
        elif kind == "arc":
            _t, cx, cy, r, a0, a1, stroke, sw = op
            if abs(a1 - a0) >= math.tau - 1e-6:
                out.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" '
                           f'fill="none" stroke="{stroke}" stroke-width="{sw}"/>')
                continue
            x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
            x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
            large = 1 if abs(a1 - a0) > math.pi else 0
            sweep = 1 if a1 > a0 else 0
            out.append(f'<path d="M {x0:.2f} {y0:.2f} A {r:.2f} {r:.2f} 0 '
                       f'{large} {sweep} {x1:.2f} {y1:.2f}" fill="none" '
                       f'stroke="{stroke}" stroke-width="{sw}"/>')
        elif kind == "text":
            _t, x, y, txt, size, fill, anchor, weight = op
            out.append(f'<text x="{x:.1f}" y="{y:.1f}" font-family="{FONT}" '
                       f'font-size="{size:.1f}" fill="{fill}" '
                       f'text-anchor="{anchor}" font-weight="{weight}">'
                       f"{esc(txt)}</text>")
    out.append("</svg>")
    return "".join(out)


# ---------------------------------------------------------------------------
# PNG backend: a small software rasteriser (stdlib only)
# ---------------------------------------------------------------------------
GLYPHS = {
    " ": ".....|.....|.....|.....|.....|.....|.....",
    "0": ".###.|#...#|#..##|#.#..|##...#|#...#|.###.",
    "1": "..#..|.##..|..#..|..#..|..#..|..#..|.###.",
    "2": ".###.|#...#|....#|...#.|..#..|.#...|#####",
    "3": "#####|...#.|..##.|....#|#...#|#...#|.###.",
    "4": "#..#.|#..#.|#..#.|#####|...#.|...#.|...#.",
    "5": "#####|#....|####.|....#|....#|#...#|.###.",
    "6": "..##.|.#...|#....|####.|#...#|#...#|.###.",
    "7": "#####|....#|...#.|..#..|..#..|..#..|..#..",
    "8": ".###.|#...#|#...#|.###.|#...#|#...#|.###.",
    "9": ".###.|#...#|#...#|.####|....#|...#.|.##..",
    "A": ".###.|#...#|#...#|#####|#...#|#...#|#...#",
    "B": "####.|#...#|#...#|####.|#...#|#...#|####.",
    "C": ".###.|#...#|#....|#....|#....|#...#|.###.",
    "D": "####.|#...#|#...#|#...#|#...#|#...#|####.",
    "E": "#####|#....|#....|####.|#....|#....|#####",
    "F": "#####|#....|#....|####.|#....|#....|#....",
    "G": ".###.|#...#|#....|#.###|#...#|#...#|.###.",
    "H": "#...#|#...#|#...#|#####|#...#|#...#|#...#",
    "I": ".###.|..#..|..#..|..#..|..#..|..#..|.###.",
    "J": "..###|...#.|...#.|...#.|...#.|#..#.|.##..",
    "K": "#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#",
    "L": "#....|#....|#....|#....|#....|#....|#####",
    "M": "#...#|##.##|#.#.#|#...#|#...#|#...#|#...#",
    "N": "#...#|##..#|#.#.#|#..##|#...#|#...#|#...#",
    "O": ".###.|#...#|#...#|#...#|#...#|#...#|.###.",
    "P": "####.|#...#|#...#|####.|#....|#....|#....",
    "Q": ".###.|#...#|#...#|#...#|#.#.#|#..#.|.##.#",
    "R": "####.|#...#|#...#|####.|#.#..|#..#.|#...#",
    "S": ".####|#....|#....|.###.|....#|....#|####.",
    "T": "#####|..#..|..#..|..#..|..#..|..#..|..#..",
    "U": "#...#|#...#|#...#|#...#|#...#|#...#|.###.",
    "V": "#...#|#...#|#...#|#...#|#...#|.#.#.|..#..",
    "W": "#...#|#...#|#...#|#.#.#|#.#.#|##.##|#...#",
    "X": "#...#|#...#|.#.#.|..#..|.#.#.|#...#|#...#",
    "Y": "#...#|#...#|.#.#.|..#..|..#..|..#..|..#..",
    "Z": "#####|....#|...#.|..#..|.#...|#....|#####",
    ".": ".....|.....|.....|.....|.....|.##..|.##..",
    ",": ".....|.....|.....|.....|.##..|.##..|..#..",
    "'": "..#..|..#..|.....|.....|.....|.....|.....",
    ":": ".....|.##..|.##..|.....|.##..|.##..|.....",
    "-": ".....|.....|.....|#####|.....|.....|.....",
    "/": "....#|....#|...#.|..#..|.#...|#....|#....",
    "(": "...#.|..#..|.#...|.#...|.#...|..#..|...#.",
    ")": ".#...|..#..|...#.|...#.|...#.|..#..|.#...",
    "%": "#...#|#..#.|...#.|..#..|.#...|.#..#|#...#",
    "+": ".....|..#..|..#..|#####|..#..|..#..|.....",
}


class Raster:
    def __init__(self, w, h, bg):
        self.w, self.h = w, h
        r, g, b, _a = parse_colour(bg)
        self.buf = bytearray()
        row = bytes((r, g, b)) * w
        for _ in range(h):
            self.buf += row

    def put(self, x, y, rgba):
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        r, g, b, a = rgba
        if a >= 255:
            i = (y * self.w + x) * 3
            self.buf[i] = r
            self.buf[i + 1] = g
            self.buf[i + 2] = b
            return
        if a <= 0:
            return
        i = (y * self.w + x) * 3
        f = a / 255.0
        self.buf[i] = int(self.buf[i] * (1 - f) + r * f)
        self.buf[i + 1] = int(self.buf[i + 1] * (1 - f) + g * f)
        self.buf[i + 2] = int(self.buf[i + 2] * (1 - f) + b * f)

    def png(self) -> bytes:
        raw = bytearray()
        stride = self.w * 3
        for y in range(self.h):
            raw.append(0)
            raw += self.buf[y * stride:(y + 1) * stride]

        def chunk(tag, data):
            return (len(data).to_bytes(4, "big") + tag + data
                    + zlib.crc32(tag + data).to_bytes(4, "big"))

        ihdr = (self.w.to_bytes(4, "big") + self.h.to_bytes(4, "big")
                + bytes((8, 2, 0, 0, 0)))
        return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))


def parse_colour(c):
    c = c.lstrip("#")
    r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    a = int(c[6:8], 16) if len(c) >= 8 else 255
    return (r, g, b, a)


def to_png(s: Scene) -> bytes:
    img = Raster(VIEW_W, VIEW_H, BG)
    for op in s.ops:
        kind = op[0]
        if kind == "rect":
            _t, x, y, w, h, fill, radius, stroke, sw, clip = op
            if fill:
                fill_rect(img, x, y, w, h, parse_colour(fill), radius, clip)
            if stroke:
                stroke_rect(img, x, y, w, h, parse_colour(stroke), sw, radius)
        elif kind == "circle":
            _t, cx, cy, r, fill, stroke, sw = op
            if fill:
                fill_ellipse(img, cx, cy, r, r, parse_colour(fill))
            if stroke:
                stroke_ellipse(img, cx, cy, r, r, parse_colour(stroke), sw)
        elif kind == "ellipse":
            _t, cx, cy, rx, ry, fill, stroke, sw = op
            if fill:
                fill_ellipse(img, cx, cy, rx, ry, parse_colour(fill))
            if stroke:
                stroke_ellipse(img, cx, cy, rx, ry, parse_colour(stroke), sw)
        elif kind == "arc":
            _t, cx, cy, r, a0, a1, stroke, sw = op
            steps = max(24, int(abs(a1 - a0) * r * 1.5))
            col = parse_colour(stroke)
            px_, py_ = None, None
            for i in range(steps + 1):
                ang = a0 + (a1 - a0) * i / steps
                qx, qy = cx + r * math.cos(ang), cy + r * math.sin(ang)
                if px_ is not None:
                    draw_line(img, px_, py_, qx, qy, col, sw)
                px_, py_ = qx, qy
        elif kind == "text":
            _t, x, y, txt, size, fill, anchor, _weight = op
            draw_text(img, x, y, txt, size, parse_colour(fill), anchor)
    return img.png()


def inside_ellipse(x, y, clip):
    cx, cy, rx, ry = clip
    dx, dy = (x - cx) / rx, (y - cy) / ry
    return dx * dx + dy * dy <= 1.0


def fill_rect(img, x, y, w, h, col, radius=0.0, clip=None):
    x0, y0 = int(round(x)), int(round(y))
    x1, y1 = int(round(x + w)), int(round(y + h))
    for py in range(max(0, y0), min(img.h, y1)):
        for px in range(max(0, x0), min(img.w, x1)):
            if clip and not inside_ellipse(px + 0.5, py + 0.5, clip):
                continue
            if radius > 0 and not _in_rounded(px + 0.5, py + 0.5, x, y, w, h,
                                               radius):
                continue
            img.put(px, py, col)


def _in_rounded(px, py, x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    cx = clamp(px, x + r, x + w - r)
    cy = clamp(py, y + r, y + h - r)
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def stroke_rect(img, x, y, w, h, col, sw, radius=0.0):
    steps = int(2 * (w + h))
    for i in range(steps + 1):
        t = i / steps * 2 * (w + h)
        if t < w:
            px, py = x + t, y
        elif t < w + h:
            px, py = x + w, y + (t - w)
        elif t < 2 * w + h:
            px, py = x + w - (t - w - h), y + h
        else:
            px, py = x, y + h - (t - 2 * w - h)
        blob(img, px, py, col, sw)


def fill_ellipse(img, cx, cy, rx, ry, col):
    x0, x1 = int(cx - rx - 1), int(cx + rx + 2)
    y0, y1 = int(cy - ry - 1), int(cy + ry + 2)
    for py in range(max(0, y0), min(img.h, y1)):
        for px in range(max(0, x0), min(img.w, x1)):
            dx, dy = (px + 0.5 - cx) / rx, (py + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                img.put(px, py, col)


def stroke_ellipse(img, cx, cy, rx, ry, col, sw):
    steps = max(48, int(math.tau * max(rx, ry) * 2))
    px_, py_ = None, None
    for i in range(steps + 1):
        ang = math.tau * i / steps
        qx, qy = cx + rx * math.cos(ang), cy + ry * math.sin(ang)
        if px_ is not None:
            draw_line(img, px_, py_, qx, qy, col, sw)
        px_, py_ = qx, qy


def blob(img, x, y, col, d):
    r = max(0.5, d / 2.0)
    for py in range(int(y - r - 1), int(y + r + 2)):
        for px in range(int(x - r - 1), int(x + r + 2)):
            if (px + 0.5 - x) ** 2 + (py + 0.5 - y) ** 2 <= r * r:
                img.put(px, py, col)


def draw_line(img, x0, y0, x1, y1, col, sw):
    dist = math.hypot(x1 - x0, y1 - y0)
    steps = max(1, int(dist * 2))
    for i in range(steps + 1):
        t = i / steps
        blob(img, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, col, sw)


def draw_text(img, x, y, s, size, col, anchor):
    scale = max(1.0, size / 7.0)
    cw, ch = 5 * scale, 7 * scale
    width = len(s) * 6 * scale - scale
    if anchor == "middle":
        x -= width / 2
    elif anchor == "end":
        x -= width
    top = y - ch * 0.78          # SVG y is the baseline
    for i, ch_ in enumerate(s.upper()):
        g = GLYPHS.get(ch_)
        if g is None:
            continue
        gx = x + i * 6 * scale
        for row, line in enumerate(g.split("|")):
            for cxi, on in enumerate(line):
                if on == "#":
                    fill_rect(img, gx + cxi * scale, top + row * scale,
                              scale + 0.35, scale + 0.35, col)


# ---------------------------------------------------------------------------
def main() -> None:
    m = build_moment()
    scene = build_scene(m)

    svg = to_svg(scene)
    with open(OUT_SVG, "w", encoding="utf-8") as fh:
        fh.write(svg)
    png = to_png(scene)
    with open(OUT_PNG, "wb") as fh:
        fh.write(png)

    ev = m["ev"]
    print("wrote %s (%.1f KB)" % (OUT_SVG, len(svg) / 1024))
    print("wrote %s (%.1f KB)" % (OUT_PNG, len(png) / 1024))
    print("frozen moment: Q%d %d' %s - %s" % (
        ev["quarter"], ev["minute"], ev["kind"], ev["text"]))
    print("score there: %s %s | %s %s   (final %s vs %s)" % (
        m["home"], scoreline(ev["score"][0]), m["away"],
        scoreline(ev["score"][1]), scoreline(m["final"][0]),
        scoreline(m["final"][1])))


if __name__ == "__main__":
    main()
