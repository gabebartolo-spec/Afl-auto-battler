#!/usr/bin/env python3
"""P-77 "One sweep of every screen": turn the sweep JSONs into a report and
check them against the committed baseline.

  python3 tools/screen_sweep.py --phone out/sweep_phone.json --pc out/sweep_pc.json \
      --baseline tools/visual/screen_sweep_baseline.json \
      --doc docs/research/SCREEN_SWEEP_2026-10-18.md [--write-baseline] [--tighten]

The JSONs come from tools/visual/sweep_screens.gd (one run per window size).
Exit status 1 when any screen got worse than the baseline: a smaller smallest
font, more controls off screen, more clipped labels, more small targets, or a
screen that built before and does not now. The floor only tightens: --tighten
rewrites the baseline with the better of the old and new value per figure and
never a worse one; --write-baseline writes it fresh (the first run).
"""
import argparse
import json
import sys

SIZES = ["phone", "pc"]
COUNTS = ["offscreen", "clipped", "small"]
LABELS = {"offscreen": "Off screen", "clipped": "Clipped text", "small": "Targets under 44 px"}


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def figures(entry):
    """The four numbers the baseline holds for one screen at one size."""
    if not entry.get("built", False):
        return {"built": False}
    return {"built": True, "min_font": entry["min_font"], "offscreen": entry["offscreen"],
            "clipped": entry["clipped"], "small": entry["small"]}


def compare(base, now):
    """Regressions of `now` against `base`: a list of sentences."""
    bad = []
    for size in SIZES:
        for key, b in base.get(size, {}).items():
            n = now.get(size, {}).get(key)
            if n is None:
                bad.append("%s %s: missing from this run" % (size, key))
                continue
            if b.get("built") and not n.get("built"):
                bad.append("%s %s: built before, does not build now (%s)" % (size, key, n.get("error", "")))
                continue
            if not b.get("built"):
                continue
            if n["min_font"] < b["min_font"] - 0.01:
                bad.append("%s %s: smallest font %.1f px, baseline %.1f px" % (size, key, n["min_font"], b["min_font"]))
            for c in COUNTS:
                if n[c] > b[c]:
                    bad.append("%s %s: %s %d, baseline %d" % (size, key, LABELS[c].lower(), n[c], b[c]))
    return bad


def tighten(base, now):
    """Per figure the better of old and new; new screens added as they come."""
    out = {s: dict(base.get(s, {})) for s in SIZES}
    for size in SIZES:
        for key, n in now.get(size, {}).items():
            b = out[size].get(key)
            if b is None or (not b.get("built") and n.get("built")):
                out[size][key] = n
            elif b.get("built") and n.get("built"):
                b["min_font"] = max(b["min_font"], n["min_font"])
                for c in COUNTS:
                    b[c] = min(b[c], n[c])
    return out


def worst(shots, n=5):
    """The n screens with most findings, each with its first example."""
    rows = []
    for size in SIZES:
        for key, e in shots[size]["screens"].items():
            if not e.get("built"):
                rows.append((10 ** 6, size, key, "did not build: " + e.get("error", "")))
                continue
            score = e["offscreen"] + e["clipped"] + e["small"]
            ex = ""
            for c, tag in (("clipped", "clipped"), ("offscreen", "off screen"), ("small", "small target")):
                if e[c]:
                    ex = "%s: %s" % (tag, e[c + "_examples"][0])
                    break
            rows.append((score, size, key, ex))
    rows.sort(key=lambda r: -r[0])
    return rows[:n]


def write_doc(path, date, shots, regressions, baseline_note):
    L = []
    L.append("# Screen sweep, %s" % date)
    L.append("")
    L.append("P-77 \"One sweep of every screen\" (director yes 2026-10-18). Every screen in `Router.SCENES`, opened on one "
             "seeded Melbourne career (seed 2031), dark theme, at the Android phone reference and the wide desktop. "
             "Made by `tools/visual/sweep_screens.gd` and `tools/screen_sweep.py`; the check against the committed "
             "baseline (`tools/visual/screen_sweep_baseline.json`) runs in the UI review sheets workflow.")
    L.append("")
    for size in SIZES:
        s = shots[size]
        L.append("- %s: window %s, %s UI units, %s px per unit." % (size, s["size"], s["units"], s["px_per_unit"]))
    L.append("")
    L.append("Figures: the smallest font on the screen in rendered px; controls whose rect leaves the viewport "
             "(sideways always, up or down only outside a scroll area); labels and buttons whose text is cut or "
             "ellipsised; buttons and tappable rows under 44 px in either direction. Examples are the first few "
             "found, not all.")
    L.append("")
    L.append("## Result")
    L.append("")
    L.append(baseline_note)
    if regressions:
        L.append("")
        L.append("**Regressions against the baseline:**")
        for r in regressions:
            L.append("- " + r)
    L.append("")
    L.append("## The table")
    L.append("")
    L.append("| Screen | Size | Smallest font (px) | Off screen | Clipped | Targets under 44 px |")
    L.append("|---|---|---|---|---|---|")
    keys = []
    for size in SIZES:
        for k in shots[size]["screens"]:
            if k not in keys:
                keys.append(k)
    for k in keys:
        for size in SIZES:
            e = shots[size]["screens"].get(k)
            if e is None:
                continue
            if not e.get("built"):
                L.append("| %s | %s | did not build: %s | | | |" % (k, size, e.get("error", "")))
            else:
                L.append("| %s | %s | %.1f | %d | %d | %d |" % (k, size, e["min_font"], e["offscreen"], e["clipped"], e["small"]))
    L.append("")
    L.append("## Worst five findings")
    L.append("")
    L.append("The five screen and size pairs with the most findings (off screen + clipped + small targets), with the first example of each.")
    L.append("")
    for score, size, key, ex in worst(shots):
        L.append("- **%s at %s**, %s findings. %s" % (key, size, score if score < 10 ** 6 else "-", ex))
    L.append("")
    L.append("## Smallest font by screen")
    L.append("")
    L.append("Where the smallest text sits (phone), smallest first.")
    L.append("")
    small = []
    for size in SIZES:
        for key, e in shots[size]["screens"].items():
            if e.get("built"):
                small.append((e["min_font"], size, key, e["min_font_node"]))
    small.sort()
    for f, size, key, node in small[:8]:
        L.append("- %.1f px, %s at %s: %s" % (f, key, size, node))
    L.append("")
    L.append("## Examples")
    L.append("")
    for size in SIZES:
        for key, e in shots[size]["screens"].items():
            if not e.get("built"):
                continue
            lines = []
            for c in COUNTS:
                for ex in e[c + "_examples"][:3]:
                    lines.append("  - %s: %s" % (LABELS[c].lower(), ex))
            if lines:
                L.append("- %s at %s" % (key, size))
                L.extend(lines)
    L.append("")
    L.append("## Not exercised")
    L.append("")
    L.append("- One state per screen: the first view, not every tab, sheet, popup or scrolled position. A screen with "
             "several states (the hub across a season, the match through its quarters) is measured once.")
    L.append("- Text sizes other than the default: P-04's text-size setting does not exist yet, so the sweep runs at one.")
    L.append("- A tap is not made: a target is judged by the size of its rect, not by whether another control covers it.")
    L.append("- Wrapped text that is simply too long for a screen is not a finding unless it is cut; only a person looking at the sheets sees that.")
    L.append("- The light theme (parked by the director, 2026-10-13) and the club colour choice: one club, dark only.")
    L.append("- Real devices: sizes are the window's pixels on a software renderer; a phone's own scaling is not applied.")
    L.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--pc", required=True)
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--doc", default="")
    ap.add_argument("--date", default="")
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("--tighten", action="store_true")
    a = ap.parse_args()

    shots = {"phone": load(a.phone), "pc": load(a.pc)}
    now = {s: {k: figures(e) for k, e in shots[s]["screens"].items()} for s in SIZES}
    regressions = []
    if a.write_baseline:
        with open(a.baseline, "w", encoding="utf-8") as f:
            json.dump(now, f, indent=1, sort_keys=True)
            f.write("\n")
        note = "This run is the baseline: the first run. Every figure above is now the floor."
    else:
        base = load(a.baseline)
        regressions = compare(base, now)
        if a.tighten:
            with open(a.baseline, "w", encoding="utf-8") as f:
                json.dump(tighten(base, now), f, indent=1, sort_keys=True)
                f.write("\n")
        note = ("No screen is worse than the baseline." if not regressions
                else "%d figure(s) worse than the baseline." % len(regressions))
    if a.doc:
        date = a.date or "undated"
        write_doc(a.doc, date, shots, regressions, note)
        print("wrote", a.doc)
    for r in regressions:
        print("REGRESSION", r)
    print(note)
    return 1 if regressions else 0


if __name__ == "__main__":
    sys.exit(main())
