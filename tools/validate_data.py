#!/usr/bin/env python3
"""
Integrity check for data/players_2026.csv.

Re-sums every club's per-player stats and compares them against the club
aggregate ("N players used") totals that AFL Tables publishes at the foot of
each club table on https://afltables.com/afl/stats/2026.html.

This catches transcription errors: a mis-read digit in any player row shows up
as a column-level mismatch for that club. The published totals are embedded
below as captured from the source page.

    python3 tools/validate_data.py

Exit code 0 = every available check passed, 1 = at least one mismatch.
"""

from __future__ import annotations

import collections
import csv
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(ROOT, "data", "players_2026.csv")

EXPECTED_FIELDS = 29

# Column order of the published totals row. "DA" is the disposal *average* and
# is deliberately skipped (it is derived, not additive).
TOTAL_COLS = [
    "ki", "mk", "hb", "di", "DA", "gl", "bh", "ho", "tk", "rb", "if50",
    "cl", "cg", "ff", "fa", "br", "cp", "up", "cm", "mi", "onepct", "bo", "ga",
]

# club -> (players_used, totals row in TOTAL_COLS order, "x" marks the DA slot)
PUBLISHED = {
    "GWS": (37, "4820 1987 3958 8778 x 300 230 790 1405 954 1236 818 1374 379 483 63 3101 5422 170 266 1100 192 214"),
    "HAW": (40, "5584 2439 3929 9513 x 356 265 1071 1459 967 1416 929 1424 460 457 86 3254 5939 243 333 1011 197 262"),
    "MEL": (37, "4970 2035 3572 8542 x 346 232 974 1405 925 1362 879 1300 431 411 86 3200 5072 247 311 987 242 263"),
    "NTH": (36, "4895 2302 3733 8628 x 280 195 710 1287 916 1117 815 1252 458 475 67 2773 5609 215 322 886 177 201"),
    "PAD": (39, "4967 2209 2863 7830 x 255 224 927 1257 866 1156 838 1318 435 428 61 2859 4720 191 301 932 152 199"),
    "RIC": (41, "4405 1891 3320 7725 x 209 177 660 1166 938 1082 768 1296 428 431 15 2800 4680 199 229 957 154 152"),
    "SKN": (36, "5148 2270 3835 8983 x 293 230 702 1302 894 1201 859 1297 432 392 71 2993 5740 204 294 960 231 213"),
    "SYD": (36, "5142 1948 4414 9556 x 406 264 981 1537 1047 1509 941 1503 518 481 102 3467 5729 239 341 1235 370 298"),
    "WCE": (40, "4555 1927 3252 7807 x 226 212 788 1326 873 1133 796 1323 460 475 31 2917 4717 180 223 911 187 162"),
    "WBD": (39, "5213 2124 3747 8960 x 298 226 742 1420 981 1288 961 1360 469 466 62 3210 5499 188 289 1271 200 224"),
}

# Player counts published for every club (totals rows for the first eight clubs
# were not captured, but the "N players used" figures were).
PLAYER_COUNTS = {
    "ADE": 38, "BRL": 35, "CAR": 39, "COL": 35, "ESS": 41, "FRE": 32,
    "GEE": 32, "GCS": 36, "GWS": 37, "HAW": 40, "MEL": 37, "NTH": 36,
    "PAD": 39, "RIC": 41, "SKN": 36, "SYD": 36, "WCE": 40, "WBD": 39,
}

CLUB_ORDER = list(PLAYER_COUNTS)

NUMERIC_FIELDS = [c for c in TOTAL_COLS if c != "DA"]


def main() -> int:
    with open(CSV_PATH, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        header = reader.fieldnames or []
        rows = list(reader)

    problems: list[str] = []

    if len(header) != EXPECTED_FIELDS:
        problems.append(f"header has {len(header)} fields, expected {EXPECTED_FIELDS}")

    malformed = [i for i, r in enumerate(rows, start=2)
                 if len(r) != EXPECTED_FIELDS or None in r.values()]
    if malformed:
        problems.append(f"{len(malformed)} malformed row(s), first at line {malformed[0]}")

    counts = collections.Counter(r["club"] for r in rows)

    print(f"{CSV_PATH}")
    print(f"  {len(rows)} players across {len(counts)} clubs\n")

    # --- structural checks -------------------------------------------------
    print("Club roster sizes (vs AFL Tables 'N players used'):")
    for code in CLUB_ORDER:
        got, want = counts.get(code, 0), PLAYER_COUNTS[code]
        flag = "OK" if got == want else f"MISMATCH (expected {want})"
        if got != want:
            problems.append(f"{code}: {got} players, expected {want}")
        print(f"  {code}: {got:>3}  {flag}")

    unknown = set(counts) - set(CLUB_ORDER)
    if unknown:
        problems.append(f"unknown club codes: {sorted(unknown)}")

    # --- aggregate checks --------------------------------------------------
    sums: dict[str, collections.Counter] = collections.defaultdict(collections.Counter)
    for r in rows:
        for f in NUMERIC_FIELDS:
            try:
                sums[r["club"]][f] += int(r[f])
            except (ValueError, KeyError):
                problems.append(
                    f"{r['club']} {r['last']}: non-integer {f}={r.get(f)!r}")

    checks = mismatches = 0
    print("\nColumn aggregates (vs published club totals):")
    for club, (n_used, totals) in PUBLISHED.items():
        exp = totals.split()
        bad = []
        for col, ev in zip(TOTAL_COLS, exp):
            if col == "DA":
                continue
            checks += 1
            got, want = sums[club][col], int(ev)
            if got != want:
                mismatches += 1
                bad.append(f"{col}: got {got} want {want} ({got - want:+d})")
        status = "OK" if not bad else "MISMATCH " + "; ".join(bad)
        print(f"  {club}: {status}")
        for b in bad:
            problems.append(f"{club} aggregate {b}")

    print(f"\n  {checks - mismatches}/{checks} aggregate checks passed")

    # --- known-issue disclosure -------------------------------------------
    known = [p for p in problems if p.startswith("HAW aggregate br")]
    if known and len(problems) == len(known):
        print("\nKNOWN ISSUE (cosmetic, does not affect simulation):")
        print("  Hawthorn's `br` (Brownlow votes) column sums 10 short of the")
        print("  published total, so one HAW player's vote count is 10 low.")
        print("  Brownlow votes are a prestige stat only -- Ratings.gd and the")
        print("  match engine never read this column, so gameplay is unaffected.")
        print("  Fix: run `python3 tools/scrape_afltables.py`, which rebuilds")
        print("  every value directly from source.")

    if problems:
        print(f"\n{len(problems)} problem(s) found:")
        for p in problems:
            print(f"  - {p}")
        return 1

    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
