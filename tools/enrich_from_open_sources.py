#!/usr/bin/env python3
"""
Enrich players_2026.csv using fully open sources, no Champion Data.

Sources used (all free, MIT or public facts):
- /tmp/squad-data/squads.json (akaifu/afl-squad-data) -> real listed position DEF/MID/RUC/FWD from official club sites
- /tmp/squad-data/ages.json (akaifu) -> DOB/age from AFL Tables + DraftGuru gapfill
- /tmp/afldata/data/players/*_personal_details.csv (akareen/AFL-Data-Analysis, MIT) -> height_cm, weight_kg, born_date, debut_date
- data/players_2026.csv (base from AFL Tables) -> season totals

Output: data/players_enriched_2026.csv with optional columns:
  real_pos,dob,age,height_cm,weight_kg,debut,foot,draft_year,draft_pick,height_source

Backward-compatible: GameDB.gd can still read base columns; new columns are optional.

Usage:
  python3 tools/enrich_from_open_sources.py
  python3 tools/enrich_from_open_sources.py --check
"""

import csv
import json
import os
import glob
import re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "data")
BASE_CSV = os.path.join(DATA_DIR, "players_2026.csv")
ENRICHED_CSV = os.path.join(DATA_DIR, "players_enriched_2026.csv")
SQUADS_JSON = "/tmp/squad-data/squads.json"
AGES_JSON = "/tmp/squad-data/ages.json"
AKAREEN_GLOB = os.path.join(os.environ.get("AKAREEN_DIR", "/tmp/afldata"), "data", "players", "*_personal_details.csv")
AFLTABLES_CACHE = os.path.join(DATA_DIR, "afltables_bio_cache.json")

# Club code mapping: our codes vs squad-data ids
CLUB_MAP = {
    "ADE": "adelaide",
    "BRL": "brisbane",
    "CAR": "carlton",
    "COL": "collingwood",
    "ESS": "essendon",
    "FRE": "fremantle",
    "GEE": "geelong",
    "GCS": "goldcoast",
    "GWS": "gws",
    "HAW": "hawthorn",
    "MEL": "melbourne",
    "NTH": "northmelbourne",
    "PAD": "portadelaide",
    "RIC": "richmond",
    "STK": "stkilda",
    "SYD": "sydney",
    "WCE": "westcoast",
    "WBD": "westernbulldogs",
}
INV_CLUB_MAP = {v: k for k, v in CLUB_MAP.items()}

def normalize_name(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9 ]", "", s)
    s = re.sub(r"\s+", " ", s)
    return s

def load_base():
    with open(BASE_CSV, newline='', encoding='utf-8') as f:
        r = csv.DictReader(f)
        rows = list(r)
        fields = r.fieldnames
    return rows, fields

def load_squads():
    # squads.json -> dict[club_id][norm_name] = pos
    mapping = {}
    try:
        with open(SQUADS_JSON, encoding='utf-8') as f:
            data = json.load(f)
        clubs = data.get("clubs", {})
        for club_id, club_data in clubs.items():
            for p in club_data.get("players", []):
                name = p.get("name", "")
                pos = p.get("pos", "")
                norm = normalize_name(name)
                mapping.setdefault(club_id, {})[norm] = pos
                # also by last name? keep full
                # add first last split for fallback
    except FileNotFoundError:
        print(f"WARNING: {SQUADS_JSON} not found, skipping real_pos")
    return mapping

def load_ages():
    # ages.json -> dict[club_id][norm_name] = {birthYear, birthMonth, birthDay, age, dob_str}
    mapping = {}
    try:
        with open(AGES_JSON, encoding='utf-8') as f:
            data = json.load(f)
        clubs = data.get("clubs", {})
        for club_id, players in clubs.items():
            for p in players:
                name = p.get("name", "")
                norm = normalize_name(name)
                by = p.get("birthYear")
                bm = p.get("birthMonth")
                bd = p.get("birthDay")
                age = p.get("age")
                if by and bm and bd:
                    dob = f"{by:04d}-{bm:02d}-{bd:02d}"
                else:
                    dob = ""
                mapping.setdefault(club_id, {})[norm] = {
                    "dob": dob,
                    "age": age,
                    "birthYear": by,
                    "birthMonth": bm,
                    "birthDay": bd,
                    "source": p.get("source", "afltables"),
                }
    except FileNotFoundError:
        print(f"WARNING: {AGES_JSON} not found, skipping dob/age")
    return mapping

def load_afltables_cache():
    mapping = {}
    try:
        with open(AFLTABLES_CACHE, encoding='utf-8') as f:
            raw = json.load(f)
        for name, info in raw.items():
            norm = normalize_name(name)
            mapping[norm] = info
        print(f"Loaded {len(mapping)} entries from afltables_bio_cache.json")
    except FileNotFoundError:
        print(f"WARNING: {AFLTABLES_CACHE} not found")
    return mapping

def load_akareen():
    # personal_details.csv -> dict[norm_full_name] = [record, ...]
    # Every same-name record is kept: AFL history reuses names (Jack Henry
    # 1944 and 2018), so a name alone never identifies a player. The caller
    # picks one with resolve_identity().
    mapping = defaultdict(list)
    files = glob.glob(AKAREEN_GLOB)
    if not files:
        print(f"WARNING: no files match {AKAREEN_GLOB}")
        return mapping
    for fp in files:
        try:
            with open(fp, newline='', encoding='utf-8') as f:
                r = csv.DictReader(f)
                for row in r:
                    first = row.get("first_name", "").strip()
                    last = row.get("last_name", "").strip()
                    if not first or not last:
                        continue
                    mapping[normalize_name(f"{first} {last}")].append({
                        "height": clean_measure(row.get("height", "")),
                        "weight": clean_measure(row.get("weight", "")),
                        "born_date": row.get("born_date", "").strip(),
                        "debut_date": row.get("debut_date", "").strip(),
                        "first": first,
                        "last": last,
                    })
        except Exception as e:
            print(f"  skip {fp}: {e}")
    print(f"Loaded {sum(len(v) for v in mapping.values())} personal_details records "
          f"({len(mapping)} names) from akareen")
    return mapping

# --- Identity -------------------------------------------------------------
# A 2026 list player was born in this window (ages 16-46); a record born
# earlier is a historical namesake, whatever its name.
EARLIEST_BIRTH_YEAR = 1980
LATEST_BIRTH_YEAR = 2010
# No one debuts before 15.
MIN_DEBUT_AGE = 15
# The ages in ages.json were taken on this date; an age we have to compute
# ourselves uses the same date so the column stays consistent.
AGE_AS_OF = "2026-09-21"

def clean_measure(v) -> str:
    # "-1", "0" and blanks mean "not recorded".
    v = str(v or "").strip()
    try:
        return v if float(v) > 0 else ""
    except ValueError:
        return ""

def parse_date(s: str):
    # YYYY-MM-DD or DD-MM-YYYY -> (y, m, d), or None.
    s = (s or "").strip()
    m = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", s)
    if m:
        return int(m.group(1)), int(m.group(2)), int(m.group(3))
    m = re.fullmatch(r"(\d{2})-(\d{2})-(\d{4})", s)
    if m:
        return int(m.group(3)), int(m.group(2)), int(m.group(1))
    return None

def plausible_dob(dob: str) -> bool:
    d = parse_date(dob)
    return d is not None and EARLIEST_BIRTH_YEAR <= d[0] <= LATEST_BIRTH_YEAR

def plausible_record(rec: dict) -> bool:
    # A source identity that could be on a 2026 list: born in the window, and
    # a debut (if any) no earlier than MIN_DEBUT_AGE and no later than 2026.
    born = rec.get("born_date") or rec.get("dob") or ""
    if not plausible_dob(born):
        return False
    deb = parse_date(rec.get("debut_date", ""))
    if deb is not None and not (parse_date(born)[0] + MIN_DEBUT_AGE <= deb[0] <= 2026):
        return False
    return True

def resolve_identity(candidates: list, dob: str):
    """The one source record that is this 2026 player, or None.

    With a trustworthy date of birth, only a record born that day qualifies:
    two current players can share a name (Bailey Williams, WBD and WCE).
    Without one, a record is accepted only when it is the sole candidate
    whose timeline fits a 2026 list. Never guesses between namesakes."""
    if plausible_dob(dob):
        hits = [c for c in candidates if (c.get("born_date") or c.get("dob")) == dob and plausible_record(c)]
        return hits[0] if len(hits) == 1 else None
    fits = [c for c in candidates if plausible_record(c)]
    return fits[0] if len(fits) == 1 else None

def age_on(dob: str, as_of: str = AGE_AS_OF) -> str:
    d, t = parse_date(dob), parse_date(as_of)
    if d is None or t is None:
        return ""
    return str(t[0] - d[0] - ((t[1], t[2]) < (d[1], d[2])))

def enrich():
    base_rows, base_fields = load_base()
    squads = load_squads()
    ages = load_ages()
    afl_cache = load_afltables_cache()
    akareen = load_akareen()

    # Load existing enriched if present to preserve any manual fixes
    existing = {}
    if os.path.exists(ENRICHED_CSV):
        try:
            with open(ENRICHED_CSV, newline='', encoding='utf-8') as f:
                r = csv.DictReader(f)
                for row in r:
                    key = (row.get("club",""), row.get("num",""), normalize_name(f"{row.get('first','')} {row.get('last','')}"))
                    existing[key] = row
        except Exception as e:
            print(f"Could not load existing enriched: {e}")

    enriched_fields = base_fields + ["real_pos", "dob", "age", "height_cm", "weight_kg", "debut", "height_source"]

    # Ensure base_fields includes src
    if "src" not in base_fields:
        enriched_fields = base_fields + ["real_pos", "dob", "age", "height_cm", "weight_kg", "debut", "height_source"]

    out_rows = []
    stats = defaultdict(int)

    for row in base_rows:
        club = row.get("club","")
        num = row.get("num","")
        last = row.get("last","")
        first = row.get("first","")
        full = f"{first} {last}"
        norm_full = normalize_name(full)
        norm_last_first = normalize_name(f"{last} {first}")

        club_id = CLUB_MAP.get(club, club.lower())

        # Try to get real_pos from squads
        real_pos = ""
        if club_id in squads:
            # exact full name
            if norm_full in squads[club_id]:
                real_pos = squads[club_id][norm_full]
                stats["real_pos_squad_hit"] += 1
            else:
                # fallback: try last name only or partial
                # Search for last name in squad list
                for nm, pos in squads[club_id].items():
                    if normalize_name(last) in nm and normalize_name(first).split()[0] in nm:
                        real_pos = pos
                        stats["real_pos_fuzzy"] += 1
                        break
        if not real_pos:
            stats["real_pos_miss"] += 1

        # DOB/age from ages.json
        dob = ""
        age = ""
        if club_id in ages:
            if norm_full in ages[club_id]:
                dob = ages[club_id][norm_full].get("dob","")
                age = str(ages[club_id][norm_full].get("age","") or "")
                stats["dob_ages_hit"] += 1
            else:
                # fuzzy
                for nm, info in ages[club_id].items():
                    if normalize_name(last) in nm and normalize_name(first).split()[0] in nm:
                        dob = info.get("dob","")
                        age = str(info.get("age","") or "")
                        stats["dob_fuzzy"] += 1
                        break
        if not dob:
            stats["dob_miss"] += 1

        # A date of birth we can trust anchors every identity match below:
        # ages.json first, else the previous run's, unless it is a historical
        # namesake's (Archie Roberts was once written as born 1910).
        key = (club, num, norm_full)
        er = existing.get(key, {})
        if not dob and plausible_dob(er.get("dob", "")):
            dob = er["dob"]
            age = age or er.get("age", "")

        # Height/weight from afltables_bio_cache.json (primary), then akareen.
        # Both are looked up by name, so each record must also be this player:
        # same date of birth, or the only candidate whose career fits 2026.
        height = ""
        weight = ""
        debut = ""
        born_date = ""
        height_source = ""
        info = resolve_identity([afl_cache[norm_full]] if norm_full in afl_cache else [], dob)
        if info is not None:
            height = clean_measure(info.get("height_cm", "") or info.get("height", ""))
            weight = info.get("weight_kg", "") or info.get("weight", "")
            born_date = info.get("dob", "")
            if height:
                height_source = "afltables_player_page"
                stats["height_afltables_hit"] += 1
        elif norm_full in afl_cache:
            stats["afltables_namesake_rejected"] += 1
        if not height:
            cands = akareen.get(norm_full, []) + [c for c in akareen.get(norm_last_first, [])
                                                   if norm_last_first != norm_full]
            rec = resolve_identity(cands, dob)
            if rec is not None:
                height = rec["height"]
                weight = rec["weight"] or weight
                debut = rec["debut_date"]
                born_date = rec["born_date"] or born_date
                if height:
                    height_source = "akareen"
                    stats["height_akareen_hit"] += 1
            elif cands:
                stats["akareen_namesake_rejected"] += 1
        # If still no dob, use the matched identity's
        if not dob and born_date:
            dob = born_date
            stats["dob_identity_fallback"] += 1
        if dob and not age:
            age = age_on(dob)
        if not height:
            stats["height_miss"] += 1

        # Keep the previous run's values only where this run found nothing
        # (e.g. the akareen checkout is absent) and they still fit this
        # player: a previous akareen row must carry a debut his own date of
        # birth allows, or it may be a namesake's (Jack Henry, debut 1944).
        if er:
            if not real_pos and er.get("real_pos"):
                real_pos = er["real_pos"]
            prev_fits = er.get("height_source") not in ("akareen", "previous_enriched", "") or (
                plausible_dob(dob) and parse_date(er.get("debut", "")) is not None
                and plausible_record({"born_date": dob, "debut_date": er.get("debut", "")}))
            if not height and clean_measure(er.get("height_cm")) and prev_fits:
                height = er["height_cm"]
                weight = weight or er.get("weight_kg", "")
                debut = debut or er.get("debut", "")
                height_source = er["height_source"]
            if not weight and er.get("weight_kg") and prev_fits:
                weight = er["weight_kg"]

        # Build enriched row
        new_row = dict(row)  # copy base
        new_row["real_pos"] = real_pos
        new_row["dob"] = dob
        new_row["age"] = age
        new_row["height_cm"] = height
        new_row["weight_kg"] = weight
        new_row["debut"] = debut
        new_row["height_source"] = height_source

        out_rows.append(new_row)

    # Write
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(ENRICHED_CSV, "w", newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=enriched_fields)
        w.writeheader()
        for r in out_rows:
            # ensure all fields present
            out = {k: r.get(k,"") for k in enriched_fields}
            w.writerow(out)

    print(f"Wrote {len(out_rows)} rows to {ENRICHED_CSV}")
    print("Stats:")
    for k,v in sorted(stats.items()):
        print(f"  {k}: {v}")

    # Coverage report
    def cov(field):
        return sum(1 for r in out_rows if r.get(field))
    print("\nCoverage:")
    for fld in ["real_pos","dob","age","height_cm","weight_kg","debut"]:
        print(f"  {fld}: {cov(fld)}/{len(out_rows)} ({cov(fld)/len(out_rows)*100:.1f}%)")

    return out_rows

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="only report, don't write")
    args = ap.parse_args()
    if args.check:
        base_rows, _ = load_base()
        print(f"Base {len(base_rows)} players")
        squads = load_squads()
        ages = load_ages()
        akareen = load_akareen()
        print(f"Squads clubs: {len(squads)} total players: {sum(len(v) for v in squads.values())}")
        print(f"Ages clubs: {len(ages)} total entries: {sum(len(v) for v in ages.values())}")
        print(f"Akareen entries: {len(akareen)}")
    else:
        enrich()
