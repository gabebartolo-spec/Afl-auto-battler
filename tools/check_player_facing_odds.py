#!/usr/bin/env python3
"""Intent on the button, never odds (director, 2026-10-18, proposal P-62).

SUPERSEDED (bible §4, director 2026-10-18, later the same day): every decision gate now shows each
option's upside, downside, size and odds, as percentages in football words. This lint enforces the old
rule and is to be retired or turned into a check that each gate names a positive and a negative; the
transparency work owns that change. Only this note was edited, not the behaviour.

Fails on any player-facing string in scripts/ui/**/*.gd or data/stories/** that
quotes odds: a percent sign, or "chance" / "odds" / "probability" / "percent"
next to a number (a digit or a format or story placeholder). A call button
says what it changes in football words, never a predicted result.

The few legitimate stats (disposal efficiency, kicking accuracy, a ladder
percentage) are listed in tools/player_facing_odds_allowlist.txt, one per line:

    <path>::<a snippet of the string, as written>::<why it is a stat>

Usage:
    python3 tools/check_player_facing_odds.py            # lint, exit 1 on any offender
    python3 tools/check_player_facing_odds.py --report   # list every hit, allowed or not, exit 0
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ALLOWLIST = ROOT / "tools" / "player_facing_odds_allowlist.txt"

# A percent sign: a literal "%%" (GDScript's escaped percent) or a digit followed by "%"
# that is not a format spec ("%d", "%s", "%.1f").
PERCENT = re.compile(r"%%|\d\s?%(?![sdfxXoeEgGcv])|\bper ?cent\b|\bpercent\b", re.I)
ODDS_WORD = re.compile(r"\b(chance|chances|odds|probability|probabilities)\b", re.I)
NUMBER = re.compile(r"\d|%[-+ #0-9.]*[dfi]")
# Developer output, not the player's screen.
DEBUG_CALL = re.compile(r"\b(print|printerr|print_rich|push_warning|push_error|assert|printraw)\s*\(")


def offending(text):
    """Why a string quotes odds, or None."""
    if PERCENT.search(text):
        return "percent sign"
    if ODDS_WORD.search(text) and NUMBER.search(text):
        return "chance/odds word beside a number"
    return None


def gd_strings(path):
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        if DEBUG_CALL.search(line):
            continue
        # Walk the line: collect each string literal, stop at a # outside any string.
        i, n_chars = 0, len(line)
        while i < n_chars:
            ch = line[i]
            if ch == "#":
                break
            if ch == '"':
                j, buf = i + 1, []
                while j < n_chars and line[j] != '"':
                    if line[j] == "\\" and j + 1 < n_chars:
                        buf.append(line[j:j + 2])
                        j += 2
                    else:
                        buf.append(line[j])
                        j += 1
                yield n, "".join(buf)
                i = j + 1
            else:
                i += 1


def json_strings(path):
    def walk(node):
        if isinstance(node, str):
            yield node
        elif isinstance(node, list):
            for x in node:
                yield from walk(x)
        elif isinstance(node, dict):
            for k, v in node.items():
                if k in ("id", "op", "key", "category", "kind"):
                    continue
                yield from walk(v)
    for s in walk(json.loads(path.read_text(encoding="utf-8"))):
        yield 0, s


def load_allowlist():
    out = []
    if ALLOWLIST.exists():
        for line in ALLOWLIST.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                parts = [p.strip() for p in line.split("::")]
                if len(parts) == 3 and all(parts):
                    out.append(tuple(parts))
                else:
                    print("allowlist line needs path::snippet::why : " + line)
                    sys.exit(2)
    return out


def main():
    report = "--report" in sys.argv
    allow = load_allowlist()
    used = set()
    files = sorted((ROOT / "scripts" / "ui").rglob("*.gd")) + sorted((ROOT / "data" / "stories").rglob("*.json"))
    bad, allowed = [], []
    for f in files:
        rel = f.relative_to(ROOT).as_posix()
        gen = gd_strings(f) if f.suffix == ".gd" else json_strings(f)
        for n, s in gen:
            why = offending(s)
            if not why:
                continue
            hit = next((a for a in allow if a[0] == rel and a[1] in s), None)
            if hit:
                used.add(hit)
                allowed.append((rel, n, s, why, hit[2]))
            else:
                bad.append((rel, n, s, why))
    stale = [a for a in allow if a not in used]
    if report:
        print("== Offenders (%d)" % len(bad))
        for rel, n, s, why in bad:
            print("%s:%d  [%s]  %s" % (rel, n, why, s))
        print("== Allowed stats (%d)" % len(allowed))
        for rel, n, s, why, reason in allowed:
            print("%s:%d  [%s]  %s  -- %s" % (rel, n, why, s, reason))
        return 0
    for rel, n, s, why in bad:
        print("%s:%d: %s: %s" % (rel, n, why, s))
    for a in stale:
        print("allowlist entry matches nothing (remove it): %s :: %s" % (a[0], a[1]))
    if bad or stale:
        print("%d player-facing string(s) quote odds. Say what the call changes in football words, "
              "or, for a real stat, add it to tools/player_facing_odds_allowlist.txt." % len(bad))
        return 1
    print("No player-facing odds in %d files (%d allowed stats)." % (len(files), len(allowed)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
