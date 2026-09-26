#!/usr/bin/env python3
"""Intake-draft calibration harness - the repo's established mirror pattern.

Like tools/sim_harness.py mirrors MatchSim.gd, this file mirrors the numeric
half of scripts/sim/Prospects.gd (projection bands, attribute fit, development
curves) plus tools-level data validation for data/draftees_2026.csv, and it
plays a full end-of-season intake + rollover over the REAL 2026 lists so the
logic can be checked outside Godot. It is a validation harness, not shipped
game code. When a constant changes in Prospects.gd, change it here too.

Usage:  python3 tools/intake_harness.py [--years N] [--quiet]
"""
import argparse
import csv
import math
from datetime import date
import os
import random
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, "data")

# ---------------------------------------------------------------------------
# Mirror of Ratings.gd constants
# ---------------------------------------------------------------------------
SHRINK_GAMES = 5.0  # unused here, kept for constant parity notes
ROLE_WEIGHTS = {  # role core: attribute -> weight (Ratings.gd::ROLE_WEIGHTS)
    "RUCK": {"ruck": 0.90, "contested": 0.10},
    "FWD": {"goalkicking": 0.35, "marking": 0.30, "carry": 0.15, "accuracy": 0.15, "creating": 0.05},
    "MID": {"contested": 0.60, "disposal": 0.15, "carry": 0.15, "goalkicking": 0.05, "accuracy": 0.05},
    "DEF": {"intercept": 0.40, "pressure": 0.35, "carry": 0.15, "contested": 0.10},
}
ATTRS = ["disposal", "contested", "marking", "pressure", "intercept", "carry",
         "goalkicking", "accuracy", "creating", "ruck", "discipline",
         "durability", "star"]
LIST_SIZE = 44
MIN_LIST = 32
MAX_RETIRE_PER_CLUB = 8


def scale_overall(raw):
    if raw < 32.0:
        return int(round(30.0 + (raw - 20.0) * (14.0 / 12.0)))
    t = max(0.0, min(1.2, (raw - 32.0) / 49.0))
    return int(round(44.0 + t ** 0.92 * 48.0))


# Position scale - see Ratings.gd::position_stretch. [p10, p50, p98] of each
# position's raw blend -> where it lands; one for one outside that band.
STRETCH_ANCHORS = {"MID": (39.66, 51.48, 83.84), "DEF": (40.37, 47.88, 58.90),
                   "FWD": (39.24, 53.72, 68.00), "RUCK": (39.13, 66.27, 86.90)}
STRETCH_TARGETS = {"MID": (37.74, 49.36, 78.04), "DEF": (43.07, 49.41, 73.72),
                   "FWD": (38.38, 49.48, 73.42), "RUCK": (37.50, 49.36, 73.56)}


def position_stretch(raw, role):
    if role not in STRETCH_ANCHORS:
        return raw
    g10, g50, g98 = STRETCH_ANCHORS[role]
    t10, t50, t98 = STRETCH_TARGETS[role]
    if raw <= g10:
        return raw + (t10 - g10)
    if raw <= g50:
        return t10 + (raw - g10) * (t50 - t10) / (g50 - g10)
    if raw <= g98:
        return t50 + (raw - g50) * (t98 - t50) / (g98 - g50)
    return t98 + (raw - g98)


def role_core(attr, role):
    return sum(w * attr[k] for k, w in ROLE_WEIGHTS[role].items())


def rate_overall(attr, role, games):
    core = role_core(attr, role)
    overall = 0.70 * core + 0.22 * attr["star"] + 0.08 * attr["durability"]
    overall = position_stretch(overall, role)
    conf = min(1.0, games / 14.0)
    overall = 40.0 + (overall - 40.0) * (0.40 + 0.60 * conf)
    return max(1, min(99, scale_overall(overall)))


def salary_value(overall):
    for step, val in [(90, 10), (85, 9), (79, 8), (73, 7), (67, 6),
                      (61, 5), (55, 4), (48, 3), (41, 2)]:
        if overall >= step:
            return val
    return 1


# ---------------------------------------------------------------------------
# Mirror of Prospects.gd
# ---------------------------------------------------------------------------
RANK_BANDS = [(1, 70.0), (10, 64.0), (20, 61.0), (30, 58.0), (40, 55.0), (50, 52.0), (64, 47.0)]
ROLE_DELTAS = {
    "MID": {"disposal": 6, "contested": 5, "pressure": 3, "carry": 4, "creating": 2,
            "marking": -1, "goalkicking": -3, "intercept": 0, "accuracy": -4,
            "discipline": -1, "star": 0, "durability": 0, "ruck": -30},
    "DEF": {"intercept": 8, "pressure": 6, "marking": 4, "disposal": 1, "accuracy": -5,
            "goalkicking": -8, "creating": -4, "carry": -3, "contested": 1,
            "discipline": 0, "star": 0, "durability": 0, "ruck": -30},
    "FWD": {"goalkicking": 8, "marking": 5, "accuracy": 3, "creating": 4, "disposal": -1,
            "intercept": -4, "pressure": 2, "carry": 1, "contested": 0, "discipline": 0,
            "star": 0, "durability": 0, "ruck": -24},
    "RUCK": {"ruck": 26, "contested": 8, "marking": 3, "disposal": -5, "goalkicking": -1,
             "intercept": -3, "pressure": 0, "carry": -5, "accuracy": -5, "creating": -2,
             "discipline": -2, "star": 0, "durability": 1, "ruck": 0},
}


def rank_base(rank):
    if rank <= 1:
        return RANK_BANDS[0][1]
    prev_r, prev_v = RANK_BANDS[0]
    for r, v in RANK_BANDS[1:]:
        if rank <= r:
            return prev_v + (v - prev_v) * (rank - prev_r) / (r - prev_r)
        prev_r, prev_v = r, v
    return max(42.0, prev_v - (rank - prev_r) * 0.18)


def _rng_for(key):
    # Stand-in for GDScript's String.hash-seeded RNG: deterministic per key.
    h = 1469598103934665603
    for ch in key.encode():
        h = ((h ^ ch) * 1099511628211) % (2 ** 64)
    rnd = random.Random(h)
    return rnd


def project(p):
    rnd = _rng_for("%s|%s" % (p["id"], p["draft_year"]))
    role = p["role"]
    target = rank_base(p["draft_rank"])
    gm, di, gl, ho, tk, mk = (float(p.get(k, 0) or 0) for k in
                              ("u18_gm", "u18_di", "u18_gl", "u18_ho", "u18_tk", "u18_mk"))
    if di >= 18:
        target += min(3.0, (di - 18) * 0.25)
    if role == "FWD" and gl >= 1.5:
        target += min(3.0, (gl - 1.5) * 0.8)
    if role == "RUCK" and ho >= 15:
        target += min(3.0, (ho - 15) * 0.15)
    if tk >= 5:
        target += min(2.0, (tk - 5) * 0.3)
    if role in ("DEF", "FWD") and mk >= 5:
        target += min(2.0, (mk - 5) * 0.25)
    height = float(p.get("height_cm", 0) or 0)
    if role == "RUCK":
        if height >= 200:
            target += 1.5
        elif 0 < height < 192:
            target -= 1.5
    elif height >= 190 and role in ("FWD", "DEF"):
        target += 1.0
    age = float(p.get("age", 18.0))
    if age >= 19:
        target += 1.0
    target += rnd.uniform(-1.5, 1.5)
    target = max(38.0, min(74.0, target))

    a = {k: target for k in ATTRS}
    for k, d in ROLE_DELTAS[role].items():
        a[k] += d
    if di > 0:
        a["disposal"] += max(-4.0, min(10.0, (di - 16) * 0.8))
    if gl > 0:
        a["goalkicking"] += max(-3.0, min(12.0, (gl - 1.2) * 2.2))
    if mk > 0:
        a["marking"] += max(-2.0, min(8.0, (mk - 3) * 1.5))
    if ho > 0 and role == "RUCK":
        a["ruck"] += max(0.0, min(14.0, (ho - 10) * 0.8))
    if tk > 0:
        a["pressure"] += max(0.0, min(8.0, (tk - 3) * 1.0))
    a["star"] = max(20.0, min(74.0, target - 10 + rnd.uniform(-4, 4)))
    a["durability"] = max(24.0, min(62.0, 24.0 + gm * 1.8))
    a = fit(a, role, target, 14.0)
    p["attr"] = {k: max(1, min(99, int(round(v)))) for k, v in a.items()}
    p["overall"] = rate_overall(p["attr"], role, 14.0)
    p["value"] = salary_value(p["overall"])
    p.pop("potential", None)
    assign_potential(p)


def fit(a, role, target, games):
    lo, hi = -40.0, 40.0
    for _ in range(14):
        mid = (lo + hi) / 2
        if _shifted(a, role, mid, games) < target:
            lo = mid
        else:
            hi = mid
    off = (lo + hi) / 2
    return {k: max(1.0, min(99.0, round(v + off))) for k, v in a.items()}


def _shifted(a, role, off, games):
    return rate_overall({k: max(1.0, min(99.0, v + off)) for k, v in a.items()}, role, games)


def days_between(a, b):
    da = date(*map(int, a.split("-")))
    db = date(*map(int, b.split("-")))
    return (db - da).days


# ---------------------------------------------------------------------------
# Data validation
# ---------------------------------------------------------------------------
def load_class(quiet=False):
    path = os.path.join(DATA, "draftees_2026.csv")
    errors = []
    rows = []
    with open(path, newline="") as f:
        rdr = csv.DictReader(f)
        expect = ["rank", "first", "last", "pos", "pos2", "pos_detail", "height_cm", "dob",
                  "state", "team", "league", "tied_club", "tied_type", "u18_gm", "u18_di",
                  "u18_gl", "u18_mk", "u18_tk", "u18_if50", "u18_ho", "note", "data_src"]
        if rdr.fieldnames != expect:
            errors.append("header mismatch: %s" % rdr.fieldnames)
        ranks = set()
        names = set()
        for r in rdr:
            rows.append(r)
            for col in ("note", "team", "first", "last"):
                if "," in (r.get(col) or ""):
                    errors.append("comma in %s: %r" % (col, r[col]))
            rk = int(r["rank"])
            if rk in ranks:
                errors.append("duplicate rank %d" % rk)
            ranks.add(rk)
            nm = (r["first"] + " " + r["last"]).lower()
            if nm in names:
                errors.append("duplicate name %s" % nm)
            names.add(nm)
            if r["pos"] not in ("MID", "DEF", "FWD", "RUC"):
                errors.append("bad pos %s" % r["pos"])
            if r["state"] not in ("SA", "WA", "VICM", "VICC", "QLD", "NSW", "TAS"):
                errors.append("bad state %s" % r["state"])
            h = int(r["height_cm"])
            if not 165 <= h <= 212:
                errors.append("implausible height %d for %s %s" % (h, r["first"], r["last"]))
            if r["dob"]:
                d = date(*map(int, r["dob"].split("-")))
                if not (date(2006, 1, 1) <= d <= date(2009, 6, 30)):
                    errors.append("dob out of class range: %s" % r["dob"])
            for k in ("u18_di", "u18_gl", "u18_mk", "u18_tk", "u18_if50", "u18_ho"):
                v = float(r[k])
                if v < 0 or v > 45:
                    errors.append("bad %s=%s" % (k, r[k]))
    rows.sort(key=lambda r: int(r["rank"]))
    if not quiet:
        print("CSV: %d rows; header/schema %s" % (len(rows), "OK" if not errors else "FAILED"))
    return rows, errors


def to_prospect(r):
    p = {
        "id": "D2026_%02d" % int(r["rank"]),
        "name": r["first"] + " " + r["last"],
        "club": r["team"], "num": int(r["rank"]),
        "role": "RUCK" if r["pos"] == "RUC" else r["pos"],
        "role2": ("RUCK" if r["pos2"] == "RUC" else r["pos2"]),
        "height_cm": int(r["height_cm"]),
        "age": (days_between(r["dob"], "2026-11-20") / 365.25) if r["dob"] else 18.0,
        "draft_year": 2026, "draft_rank": int(r["rank"]),
        "tied_club": r["tied_club"], "tied_type": r["tied_type"],
        "u18_gm": float(r["u18_gm"]), "u18_di": float(r["u18_di"]),
        "u18_gl": float(r["u18_gl"]), "u18_mk": float(r["u18_mk"]),
        "u18_tk": float(r["u18_tk"]), "u18_if50": float(r["u18_if50"]),
        "u18_ho": float(r["u18_ho"]),
    }
    project(p)
    return p


# ---------------------------------------------------------------------------
# Draft + rollover over the real lists
# ---------------------------------------------------------------------------
def load_lists():
    lists = defaultdict(list)
    path = os.path.join(DATA, "players_enriched_2026.csv")
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            r["id"] = "%s_%s" % (r["club"], r["num"])
            r["name"] = r["first"] + " " + r["last"]
            lists[r["club"]].append(r)
    return lists


def play_intake(clubs, lists, pool, order, rng, cap=LIST_SIZE):
    picks = {c: [] for c in clubs}
    sizes = {c: len(lists[c]) for c in clubs}
    rounds = max(1, min(4, math.ceil(len(pool) / len(clubs))))
    seq = []
    for rnd in range(rounds):
        o = list(order) if rnd % 2 == 0 else list(reversed(order))
        seq.extend(o)
    seq = seq[:len(pool)]
    by_club_turn = {}
    for i, code in enumerate(seq):
        by_club_turn.setdefault(code, []).append(i)
    taken = set()
    history = []
    # Greedy per-club best-available, mirroring _best_ai_pick (overall-first
    # under an effectively open budget; need bonuses ~0 on full lists).
    per_club_next = {c: 0 for c in clubs}
    remaining = sorted(pool, key=lambda p: -p["overall"])
    for code in clubs:
        n_turns = len(by_club_turn.get(code, []))
        budget = cap - sizes[code]
        for p in remaining:
            if len(picks[code]) >= min(n_turns, budget):
                break
            if p["id"] in taken:
                continue
            taken.add(p["id"])
            picks[code].append(p)
            history.append((code, p))
    return picks, history


# ---------------------------------------------------------------------------
# Potential mirror (scripts/sim/Potential.gd)
# ---------------------------------------------------------------------------
MAX_POT = 97
ROLE_CAP = {"MID": 95, "RUCK": 92, "FWD": 92, "DEF": 92}
AGE_HEADROOM = [(20.0, 16.0), (22.0, 12.0), (24.0, 8.0), (26.0, 4.0), (28.0, 2.0)]
GAP_PULL = [(21.0, 0.30), (24.0, 0.22), (28.0, 0.15)]
REHAB_PULL = 0.9
MIN_STEP = 2.0


def _headroom(age):
    for top, room in AGE_HEADROOM:
        if age <= top:
            return room
    return 0.0


def assign_potential(p):
    if "potential" in p:
        return
    ov = int(p.get("overall", 50))
    rnd = _rng_for("pot|%s|%s" % (p["id"], p.get("draft_year", "")))
    if p.get("projected"):
        rank = max(1, min(80, int(p.get("draft_rank", 40))))
        pot = ov + max(6.0, 22.0 - 0.25 * (rank - 1)) + rnd.uniform(-3.0, 3.0)
    else:
        pot = ov + _headroom(float(p.get("age", 26.0))) + rnd.uniform(-2.0, 3.0)
    cap = min(MAX_POT, ROLE_CAP.get(p.get("role", "MID"), MAX_POT))
    p["potential"] = max(ov, min(max(ov, cap), int(round(pot))))


def potential_growth(p, age):
    gap = float(int(p.get("potential", p.get("overall", 0))) - int(p.get("overall", 0)))
    if gap <= 0:
        return 0.0
    pull = 0.0
    for top, share in GAP_PULL:
        if age <= top:
            pull = share
            break
    if p.pop("rehab", False):
        pull = max(pull, REHAB_PULL)
    if pull <= 0:
        return 0.0
    return max(gap * pull, min(gap, MIN_STEP))


def age_player(p, year):
    rnd = _rng_for("%s|%d" % (p["id"], year))
    age = float(p.get("age", 26.0)) + 1.0
    p["age"] = age
    ov = int(p.get("overall", 50))
    if age <= 20:
        d = rnd.uniform(2.5, 6.0)
    elif age <= 23:
        d = rnd.uniform(1.0, 4.0)
    elif age <= 27:
        d = rnd.uniform(0.0, 2.0)
    elif age <= 30:
        d = rnd.uniform(-1.0, 1.0)
    elif age <= 33:
        d = rnd.uniform(-3.0, 0.0)
    else:
        d = rnd.uniform(-6.0, -1.5)
    if age <= 25 and ov < 55:
        d += 1.0
    if age <= 23 and ov >= 80:
        d += 1.0
    grow = potential_growth(p, age)
    if grow > 0:
        d = max(d, grow)
    target = max(25.0, min(93.0, ov + d))
    if d > 0 and "potential" in p:
        target = min(target, float(max(ov, int(p["potential"]))))
    if p.get("attr"):
        p["attr"] = fit(p["attr"], p.get("role", "MID"), target, 20.0)
        p["overall"] = rate_overall(p["attr"], p.get("role", "MID"), 20.0)
    else:
        p.setdefault("overall", int(round(ov + d)))
    return int(p["overall"]) - ov


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--years", type=int, default=5)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    fails = []

    rows, errs = load_class(args.quiet)
    fails += errs

    prospects = [to_prospect(r) for r in rows]
    ovs = [p["overall"] for p in prospects]
    if not (max(ovs) <= 74 and min(ovs) >= 38):
        fails.append("projection band violated: %d..%d" % (min(ovs), max(ovs)))
    mono = all(ovs[i] >= ovs[i + 1] - 8 for i in range(len(ovs) - 1))
    if not mono:
        fails.append("rank -> overall not broadly monotonic")
    rucks = [p for p in prospects if p["role"] == "RUCK"]
    if len(rucks) < 3:
        fails.append("too few projected rucks: %d" % len(rucks))
    tied = [p for p in prospects if p["tied_club"]]
    if not args.quiet:
        print("class: %d prospects, %d rucks, %d club-tied; overall %d..%d (median %.0f)"
              % (len(prospects), len(rucks), len(tied), min(ovs), max(ovs),
                 sorted(ovs)[len(ovs) // 2]))

    lists = load_lists()
    clubs = sorted(lists)
    # Mirror only: the real rows keep their season columns; aging uses the
    # enriched CSV age and a neutral 50 overall for veteran players.
    for c in clubs:
        for p in lists[c]:
            p["gm"] = float(p.get("gm") or 18)
            p["age"] = float(p.get("age") or 26)
            p["overall"] = 50
            assign_potential(p)

    order = list(clubs)
    random.Random(4242).shuffle(order)
    rng = random.Random(7)
    pool = list(prospects)
    undrafted_total = 0
    for year_off in range(args.years):
        draft_year = 2026 + year_off
        next_year = draft_year + 1
        open_pool = [p for p in pool if p.get("club_owner") is None]
        if year_off > 0:
            open_pool += generate_mirror_class(next_year)
        picks, history = play_intake(clubs, lists, open_pool, order, rng)
        n_picks = sum(len(v) for v in picks.values())
        for c in clubs:
            lists[c] = lists[c] + picks[c]
        drafted_ids = {p["id"] for c in clubs for p in picks[c]}
        undrafted = [p for p in open_pool if p["id"] not in drafted_ids]
        for p in undrafted:  # age the pool
            p["age"] = float(p["age"]) + 1.0
            if p["age"] >= 22.0:
                continue
        pool = [p for p in undrafted if p["age"] < 22.0]
        undrafted_total = len(pool)
        # rollover: age everyone on the lists
        retired = 0
        for c in clubs:
            aged = []
            drops = 0
            for p in lists[c]:
                before = int(p.get("overall", 50))
                age_player(p, next_year)
                if int(p["overall"]) > max(before, int(p.get("potential", 99))) + 1:  # refit rounding
                    fails.append("%s grew past its POT (%d > %d)" % (p["id"], p["overall"], p["potential"]))
                aged.append(p)
            keep = []
            for p in aged:
                age = float(p.get("age", 26.0))
                ov = int(p.get("overall", 50))
                want = ov <= 32 or age >= 37 or (age >= 35 and _rng_for(p["id"] + str(next_year)).random() < 0.7)
                if want and drops < MAX_RETIRE_PER_CLUB and len(aged) - drops > MIN_LIST:
                    drops += 1
                    retired += 1
                else:
                    keep.append(p)
            lists[c] = keep
            if len(keep) > LIST_SIZE:
                fails.append("list overflow at %s: %d" % (c, len(keep)))
        if not args.quiet:
            sizes = sorted(len(v) for v in lists.values())
            print("%d: picked %3d, retired %2d, pool carry %2d; list sizes %d..%d"
                  % (next_year, n_picks, retired, undrafted_total, sizes[0], sizes[-1]))
            if sizes[0] < MIN_LIST:
                fails.append("a club fell below MIN_LIST")

    for c in clubs:
        for p in lists[c]:
            for k, v in p.get("attr", {}).items():
                if not 1 <= v <= 99:
                    fails.append("attr out of range at %s: %s=%s" % (c, k, v))
    det_a = sorted(generate_mirror_class(2031), key=lambda p: p["id"])
    det_b = sorted(generate_mirror_class(2031), key=lambda p: p["id"])
    if [p["overall"] for p in det_a] != [p["overall"] for p in det_b]:
        fails.append("mirror class generation not deterministic")

    if fails:
        print("FAILURES (%d):" % len(fails))
        for e in fails:
            print("  -", e)
        sys.exit(1)
    print("intake harness: all checks passed (%d prospects, %d seasons)" % (len(prospects), args.years))


def generate_mirror_class(year):
    rnd = _rng_for("class-%d" % year)
    size = 46 + rnd.randrange(11)
    out = []
    for r in range(1, size + 1):
        role = rnd.choice(["MID", "MID", "MID", "FWD", "FWD", "DEF", "DEF", "RUCK"])
        if r % 12 == 8:
            role = "RUCK"
        height = {"RUCK": (197, 208), "FWD": (184, 203), "DEF": (182, 198), "MID": (173, 192)}[role]
        p = {
            "id": "D%d_%02d" % (year, r), "name": "Generated %d %02d" % (year, r),
            "club": "Gen", "num": r, "role": role, "role2": "",
            "height_cm": rnd.randint(*height),
            "age": float(year - 18) + rnd.random(),
            "draft_year": year, "draft_rank": r, "tied_club": "", "tied_type": "",
            "u18_gm": float(rnd.randint(6, 16)),
            "u18_di": float(rnd.randint(10, 26)), "u18_gl": rnd.randint(3, 26) / 10,
            "u18_mk": float(rnd.randint(1, 7)), "u18_tk": float(rnd.randint(1, 7)),
            "u18_if50": float(rnd.randint(1, 6)),
            "u18_ho": float(rnd.randint(12, 28)) if role == "RUCK" else 0.0,
        }
        project(p)
        out.append(p)
    return out


if __name__ == "__main__":
    main()
