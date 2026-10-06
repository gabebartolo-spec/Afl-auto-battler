#!/usr/bin/env python3
"""
Integrity check for data/players_2026.csv and the bio columns of
data/players_enriched_2026.csv.

Re-sums every club's per-player stats and compares them against the club
aggregate ("N players used") totals that AFL Tables publishes at the foot of
each club table on https://afltables.com/afl/stats/2026.html.

This catches transcription errors: a mis-read digit in any player row shows up
as a column-level mismatch for that club. The published totals are embedded
below as captured from the source page.

    python3 tools/validate_data.py

The bio check guards identity: heights and birth dates are looked up by
name, and AFL history reuses names (Jack Henry 1944 and 2018), so every row
must fit a 2026 list and the known namesakes must carry their own facts.

Exit code 0 = every available check passed, 1 = at least one mismatch.
"""

from __future__ import annotations

import collections
import csv
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(ROOT, "data", "players_2026.csv")
ENRICHED_PATH = os.path.join(ROOT, "data", "players_enriched_2026.csv")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import enrich_from_open_sources as enrich  # noqa: E402

# Every 2026 player AFL Tables disambiguates from a namesake (its player page
# carries a number: Jack_Henry1.html), with the date of birth and height from
# that page. A name-only join once gave each of these someone else's height.
# (first, last, club, dob, height_cm)
NAMESAKES = [
    ("Archie", "Roberts", "ESS", "2005-11-18", 184),
    ("Arthur", "Jones", "WBD", "2003-07-18", 180),
    ("Bailey", "Williams", "WBD", "1997-10-10", 187),
    ("Bailey", "Williams", "WCE", "2000-04-17", 199),
    ("Billy", "Wilson", "CAR", "2005-06-16", 183),
    ("Callum", "Brown", "GWS", "2000-08-15", 188),
    ("Charlie", "Cameron", "BRL", "1994-07-05", 181),
    ("Charlie", "West", "COL", "2006-02-01", 194),
    ("Harry", "Jones", "ESS", "2001-02-25", 194),
    ("Jack", "Buckley", "GWS", "1997-12-17", 193),
    ("Jack", "Carroll", "STK", "2002-12-20", 188),
    ("Jack", "Dalton", "HAW", "2007-04-05", 178),
    ("Jack", "Graham", "WCE", "1998-02-25", 181),
    ("Jack", "Henry", "GEE", "1998-08-29", 191),
    ("Jack", "Ross", "RIC", "2000-09-03", 187),
    ("Jack", "Williams", "WCE", "2003-12-01", 198),
    ("Jamie", "Elliott", "COL", "1992-08-21", 178),
    ("Luke", "Trainor", "RIC", "2006-04-10", 193),
    ("Matthew", "Kennedy", "WBD", "1997-04-06", 188),
    ("Maurice", "Rioli", "RIC", "2002-09-01", 179),
    ("Sam", "Butler", "HAW", "2003-02-10", 184),
    ("Tom", "Lynch", "RIC", "1992-10-31", 199),
    ("Will", "Hayes", "COL", "2006-05-16", 180),
]
# AFL heights outside this are a data error, not a player (Caleb Daniel 168,
# Mason Cox 211 are the real extremes).
HEIGHT_RANGE = (160, 215)

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
    "STK": (36, "5148 2270 3835 8983 x 293 230 702 1302 894 1201 859 1297 432 392 71 2993 5740 204 294 960 231 213"),
    "SYD": (36, "5142 1948 4414 9556 x 406 264 981 1537 1047 1509 941 1503 518 481 102 3467 5729 239 341 1235 370 298"),
    "WCE": (40, "4555 1927 3252 7807 x 226 212 788 1326 873 1133 796 1323 460 475 31 2917 4717 180 223 911 187 162"),
    "WBD": (39, "5213 2124 3747 8960 x 298 226 742 1420 981 1288 961 1360 469 466 62 3210 5499 188 289 1271 200 224"),
}

# Player counts published for every club (totals rows for the first eight clubs
# were not captured, but the "N players used" figures were).
PLAYER_COUNTS = {
    "ADE": 38, "BRL": 35, "CAR": 39, "COL": 35, "ESS": 41, "FRE": 32,
    "GEE": 32, "GCS": 36, "GWS": 37, "HAW": 40, "MEL": 37, "NTH": 36,
    "PAD": 39, "RIC": 41, "STK": 36, "SYD": 36, "WCE": 40, "WBD": 39,
}

CLUB_ORDER = list(PLAYER_COUNTS)

NUMERIC_FIELDS = [c for c in TOTAL_COLS if c != "DA"]


def check_identity_rules() -> list[str]:
    """The matcher never takes a namesake: unit cases from real collisions."""
    problems = []
    old = {"born_date": "1922-01-21", "debut_date": "10-07-1944", "height": "168"}
    new = {"born_date": "1998-08-29", "debut_date": "28-03-2018", "height": "191"}
    wbd = {"born_date": "1997-10-10", "debut_date": "11-05-2016", "height": "187"}
    wce = {"born_date": "2000-04-17", "debut_date": "22-08-2020", "height": "199"}
    west = {"born_date": "1884-05-19", "debut_date": "22-07-1903", "height": ""}
    cases = [
        ("Jack Henry by birth date", enrich.resolve_identity([old, new], "1998-08-29"), new),
        ("Jack Henry, no birth date: only one fits 2026", enrich.resolve_identity([old, new], ""), new),
        ("A historical namesake's birth date is not trusted", enrich.resolve_identity([old, new], "1922-01-21"), new),
        ("Two current Bailey Williams, by birth date", enrich.resolve_identity([wbd, wce], "2000-04-17"), wce),
        ("Two current Bailey Williams, no birth date: no guess", enrich.resolve_identity([wbd, wce], ""), None),
        ("Only an 1884 namesake: unknown, not his height", enrich.resolve_identity([west], "2006-02-01"), None),
        ("Birth date matches no record: unknown", enrich.resolve_identity([wbd], "2001-01-01"), None),
    ]
    for label, got, want in cases:
        if got is not want:
            problems.append(f"identity rule: {label}")
    if enrich.clean_measure("-1") != "" or enrich.clean_measure("0") != "" or enrich.clean_measure("191") != "191":
        problems.append("identity rule: -1 / 0 heights must read as unknown")
    if enrich.age_on("2005-11-18") != "20" or enrich.age_on("1998-08-29") != "28":
        problems.append("identity rule: age_on is off")
    return problems


def check_bio() -> list[str]:
    """Heights, birth dates and debuts in the enriched CSV fit a 2026 list."""
    problems: list[str] = []
    with open(ENRICHED_PATH, newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    print(f"\n{ENRICHED_PATH}")
    for r in rows:
        who = f"{r['first']} {r['last']} ({r['club']})"
        try:
            h = float(r["height_cm"])
        except ValueError:
            h = 0.0
        if not HEIGHT_RANGE[0] <= h <= HEIGHT_RANGE[1]:
            problems.append(f"{who}: height {r['height_cm']!r} is missing or impossible")
        if not enrich.plausible_dob(r["dob"]):
            problems.append(f"{who}: born {r['dob']!r}, not a 2026 list player")
        elif r["age"] != enrich.age_on(r["dob"]):
            problems.append(f"{who}: age {r['age']} does not match born {r['dob']}")
        if r["debut"] and not enrich.plausible_record({"born_date": r["dob"], "debut_date": r["debut"]}):
            problems.append(f"{who}: debut {r['debut']} is impossible for born {r['dob']} (a namesake's record)")
    for first, last, club, dob, height in NAMESAKES:
        hits = [r for r in rows if r["first"] == first and r["last"] == last and r["club"] == club]
        if len(hits) != 1 or hits[0]["dob"] != dob or hits[0]["height_cm"] != str(height):
            got = [(r["dob"], r["height_cm"]) for r in hits]
            problems.append(f"namesake {first} {last} ({club}): want born {dob}, {height} cm; got {got}")
    print(f"  {len(rows)} players; {len(NAMESAKES)} AFL Tables namesakes pinned")
    return problems


def check_afl_ladders() -> list[str]:
    """tools/balance/afl_ladders.json (real-AFL reference): every season has
    16-18 clubs, every premier and finals club is on that year's ladder
    (2020 has no ladder here, so its clubs are only checked against its own
    finals), and every finals winner is one of the two clubs or a draw."""
    import json

    path = os.path.join(ROOT, "tools", "balance", "afl_ladders.json")
    if not os.path.exists(path):
        return []
    problems: list[str] = []
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
    for year, rows in doc.get("seasons", {}).items():
        if not 16 <= len(rows) <= 18:
            problems.append(f"afl_ladders {year}: {len(rows)} clubs")
    finals = doc.get("finals", {})
    for year, games in finals.items():
        for hi, lo, win in games:
            if win not in (hi, lo, "draw"):
                problems.append(f"afl_ladders {year}: winner {win} is not {hi} or {lo}")
        clubs = {c for g in games for c in g[:2]}
        prem = doc.get("premiers", {}).get(year)
        if not prem:
            problems.append(f"afl_ladders {year}: no premier")
            continue
        if prem["club"] not in clubs:
            problems.append(f"afl_ladders {year}: premier {prem['club']} not in that year's finals")
        n = len(doc["seasons"].get(year, [])) or 18
        if not 1 <= prem["ladder_position"] <= n:
            problems.append(f"afl_ladders {year}: premier ladder position {prem['ladder_position']}")
    for year in doc.get("seasons", {}):
        if year not in doc.get("premiers", {}) or year not in finals:
            problems.append(f"afl_ladders {year}: season without premiers or finals")
    print(f"  afl ladders: {len(doc.get('seasons', {}))} seasons, {len(finals)} finals series checked")
    return problems


def check_forge_locations() -> list[str]:
    """data/forge_locations.json (Club Forge location library, ARD-M7-009):
    unique ids, the required fields, a ground and a source on every entry, the
    mandatory Northern Territory places present, ACT entries as districts, no
    place an AFL club already represents, and no coordinates."""
    import json

    path = os.path.join(ROOT, "data", "forge_locations.json")
    if not os.path.exists(path):
        return []
    problems: list[str] = []
    with open(path, encoding="utf-8") as f:
        places = json.load(f).get("locations", [])
    afl = {"adelaide", "brisbane", "carlton", "collingwood", "essendon", "fremantle",
           "geelong", "gold coast", "greater western sydney", "hawthorn", "melbourne",
           "north melbourne", "port adelaide", "richmond", "st kilda", "sydney",
           "west coast", "western bulldogs", "tasmania", "canberra"}
    required = ("id", "place", "state", "ground", "heritage", "sources")
    seen: set[str] = set()
    for e in places:
        who = e.get("id", "?")
        for k in required:
            if not e.get(k):
                problems.append(f"forge location {who}: missing {k}")
        if who in seen:
            problems.append(f"forge location {who}: duplicate id")
        seen.add(who)
        if e.get("place", "").strip().lower() in afl:
            problems.append(f"forge location {who}: an AFL club already represents it")
        if e.get("state") == "ACT" and "canberra" == e.get("place", "").strip().lower():
            problems.append(f"forge location {who}: ACT entries are districts")
        for k in ("lat", "lng", "latitude", "longitude"):
            if k in e:
                problems.append(f"forge location {who}: no coordinates ({k})")
    for must in ("darwin", "alice-springs"):
        if must not in seen:
            problems.append(f"forge location {must}: mandatory place missing")
    print(f"  forge locations: {len(places)} entries checked")
    return problems


def check_role_rates() -> list[str]:
    """tools/balance/afl_role_rates.json (real 2026 per-game rates by role):
    all four roles present with players, and every rate in a sane range;
    kicks plus handballs equal disposals."""
    import json

    path = os.path.join(ROOT, "tools", "balance", "afl_role_rates.json")
    if not os.path.exists(path):
        return []
    problems: list[str] = []
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
    ranges = {"disposals": (5, 35), "kicks": (2, 20), "handballs": (1, 20), "marks": (1, 8),
              "tackles": (0.5, 6), "goals": (0, 3), "hitouts": (0, 30), "inside_50s": (0.3, 6),
              "clearances": (0, 6), "rebound_50s": (0, 6), "frees_for": (0.2, 2.5),
              "frees_against": (0.2, 2.5)}
    for role in ("DEF", "MID", "FWD", "RUCK"):
        r = doc.get("roles", {}).get(role)
        if not r or int(r.get("players", 0)) < 10:
            problems.append(f"afl_role_rates {role}: missing or too few players")
            continue
        rates = r["per_game"]
        for k, (lo, hi) in ranges.items():
            v = rates.get(k)
            if v is None or not lo <= float(v) <= hi:
                problems.append(f"afl_role_rates {role} {k}: {v} outside {lo}-{hi}")
        if abs(float(rates.get("kicks", 0)) + float(rates.get("handballs", 0)) - float(rates.get("disposals", 0))) > 0.1:
            problems.append(f"afl_role_rates {role}: kicks plus handballs differ from disposals")
    if float(doc.get("roles", {}).get("RUCK", {}).get("per_game", {}).get("hitouts", 0)) < 10:
        problems.append("afl_role_rates RUCK: hitouts below 10 a game")
    print("  afl role rates: 4 roles checked")
    return problems


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

    # --- bio / identity checks ---------------------------------------------
    problems.extend(check_afl_ladders())
    problems.extend(check_role_rates())
    problems.extend(check_forge_locations())
    problems.extend(check_identity_rules())
    problems.extend(check_bio())

    if problems:
        print(f"\n{len(problems)} problem(s) found:")
        for p in problems:
            print(f"  - {p}")
        return 1

    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
