#!/usr/bin/env python3
"""
AFL Auto-Battler — simulation balance harness.

This file is NOT part of the shipped game. It is a fast, runnable Python
mirror of the GDScript match engine (scripts/sim/MatchSim.gd). Its job is to
tune the engine constants so a simulated match reproduces the *real* 2026 AFL
team totals harvested into data/players_2026.csv.

    python3 tools/sim_harness.py             # calibration report
    python3 tools/sim_harness.py --sample     # one narrated match
    python3 tools/sim_harness.py --ratings    # dump derived ratings to CSV

The GDScript port must stay behaviourally identical to this file. When a
constant changes here, change it in scripts/sim/MatchSim.gd too.
"""

from __future__ import annotations

import argparse
import csv
import math
import os
import random
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAYERS_CSV = os.path.join(ROOT, "data", "players_2026.csv")
ENRICHED_CSV = os.path.join(ROOT, "data", "players_enriched_2026.csv")

# ---------------------------------------------------------------------------
# Who crumbs off a spoil, and how often (MatchSim.CRUMB_*).
CRUMB_ROLES = {"FWD": 1.0, "MID": 0.25, "RUCK": 0.1, "DEF": 0.03}
CRUMB_P = 0.30
CRUMB_SNAP = 0.85

# Tunables — the single source of truth for match balance.
# Mirrored in scripts/sim/MatchSim.gd.
# ---------------------------------------------------------------------------
T = {
    "chains_per_game": 180,          # possession chains across BOTH teams
    "max_touches_per_chain": 14,
    "forward50_line": 35.0,          # metres from the centre square
    "goal_line": 85.0,
    "metres_gain_mean": 9.7,         # base metres per effective disposal
    "tackle_retention": 0.44,        # attacking team wins the ball back
    "pressure_base": 0.160,          # chance a touch is tackled
    "clanger_per_chain": 0.625,      # chance the chain ends in an error
    "clanger_is_free": 0.34,         # ...of which are free kicks against
    "mark_share_of_kicks": 0.330,
    "handball_share": 0.44,
    "inside50_goal": 0.269,           # of inside-50 entries
    "inside50_behind": 0.180,
    "stoppage_share": 0.465,         # chains that begin at a genuine stoppage
    "hitouts_per_stoppage": 0.81,    # split between the two rucks
    "clearance_per_stoppage": 0.815,  # to the team that wins the stoppage
    "one_percenter_share": 0.83,     # of inside-50 entries that yield a 1%
    "rebound_on_exit": 0.55,         # defensive-half chains that yield a reb50
    "shooter_power": 0.5,            # how strongly shots go to the best kicks
    "rebound_from": -18.0,           # a carry from behind this line...
    "rebound_to": -13.0,             # ...to beyond this one is a rebound 50
    "shrink_games": 5.0,             # sample-size shrink for per-game rates
    "shrink_accuracy": 14.0,         # sample-size shrink for goal conversion
    "home_ground_bonus": 0.030,
    "contest_swing": 360.0,          # higher == less sensitive to strength
    "contest_clamp": 0.60,           # max stoppage win probability
}

STAT_KEYS = [
    "gm", "ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "rb", "if50",
    "cl", "cg", "ff", "fa", "br", "cp", "up", "cm", "mi", "onepct",
    "bo", "ga", "pctp",
]

# On-ground structure: 18 players = 6 DEF, 6 MID, 6 FWD, where the ruck is
# counted with midfield (1 RUCK + 5 MID). Keep in lockstep with
# Ratings.GROUND_SLOTS.
ROLE_CORRECTIONS = {"RIC|Maurice Rioli": "FWD", "WBD|Cody Weightman": "FWD"}
# Ratings.ATTR_ADJUSTMENTS: director's named-player balance corrections.
ATTR_ADJUSTMENTS = {"MEL|Harvey Langford": 1.15, "MEL|Jake Bowey": 1.022, "PAD|Connor Rozee": 1.10}
GROUND_SLOTS = {"RUCK": 1, "MID": 5, "DEF": 6, "FWD": 6}
INTERCHANGE = 4
LIST_SIZE = 44


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------
def load_players(path=PLAYERS_CSV):
    players = []
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            p = {"club": row["club"], "num": int(row["num"]),
                 "name": "%s %s" % (row["first"], row["last"]),
                 "surname": row["last"]}
            for k in STAT_KEYS:
                p[k] = float(row[k])
            p["id"] = "%s_%d" % (p["club"], p["num"])
            players.append(p)
    # The club's listed position (Ratings.listed_secondary reads it).
    listed = {}
    if os.path.exists(ENRICHED_CSV):
        with open(ENRICHED_CSV, newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                listed["%s_%s" % (row["club"], row["num"])] = row.get("real_pos", "")
    for p in players:
        p["real_pos"] = listed.get(p["id"], "")
    return players


def games_played_by_club(players):
    best = defaultdict(float)
    for p in players:
        best[p["club"]] = max(best[p["club"]], p["gm"])
    return dict(best)


def real_benchmarks(players):
    """Per-team-per-game averages implied by the real harvested data."""
    gp = games_played_by_club(players)
    tot = defaultdict(float)
    for p in players:
        for k in STAT_KEYS:
            tot[k] += p[k]
    games = sum(gp.values())
    out = {k: tot[k] / games for k in STAT_KEYS}
    out["hb"] = out["di"] - out["ki"]
    out["score"] = out["gl"] * 6 + out["bh"]
    return out, gp


def player_league_rates(players):
    """
    Average *per player per game* rate for each stat.

    This is the shrinkage target for individual ratings. It must NOT be the
    team-per-game figure: shrinking a player's disposals toward 364 (a whole
    team's output) makes fringe players look superhuman.
    """
    gm = sum(max(1.0, p["gm"]) for p in players)
    out = {}
    for metric, stat in METRIC_SPECS:
        if stat == "hb":
            total = sum(p["di"] - p["ki"] for p in players)
        else:
            total = sum(p[stat] for p in players)
        out[metric] = total / gm
    return out


def _pctile(vals, q):
    vals = sorted(vals)
    if not vals:
        return 0.0
    i = q * (len(vals) - 1)
    lo = int(math.floor(i))
    hi = min(len(vals) - 1, lo + 1)
    return vals[lo] + (vals[hi] - vals[lo]) * (i - lo)


# ---------------------------------------------------------------------------
# Ratings
# ---------------------------------------------------------------------------
def _shrunk_rate(total, games, league_rate, k):
    return (total + k * league_rate) / (games + k)


def _norm_map(values, invert=False, lo=None, hi=None, cap=0.98):
    """
    Map a raw value onto 0..1.

    Deliberately NOT a percentile rank: most of these stats are zero for the
    majority of the player pool (hit-outs, bounces, marks inside 50), so a
    percentile rank hands a *high* score to a zero. We use capped linear
    scaling against the 98th percentile instead, which keeps zero == zero.
    """
    if lo is not None and hi is not None:
        span = float(hi - lo) or 1.0

        def f(v):
            x = (v - lo) / span
            return (1.0 - x) if invert else x
    else:
        ref = _pctile(values, cap) or 1.0

        def f(v):
            x = v / ref
            return (1.0 - x) if invert else x

    return lambda v: max(0.0, min(1.0, f(v)))


METRIC_SPECS = [
    ("disposals_pg", "di"), ("kicks_pg", "ki"), ("marks_pg", "mk"),
    ("handballs_pg", "hb"), ("goals_pg", "gl"), ("behinds_pg", "bh"),
    ("hitouts_pg", "ho"), ("tackles_pg", "tk"), ("rebounds_pg", "rb"),
    ("inside50s_pg", "if50"), ("clearances_pg", "cl"), ("clangers_pg", "cg"),
    ("frees_for_pg", "ff"), ("frees_against_pg", "fa"),
    ("brownlow_pg", "br"), ("contested_pg", "cp"),
    ("contested_marks_pg", "cm"), ("marks_inside50_pg", "mi"),
    ("one_percenters_pg", "onepct"), ("bounces_pg", "bo"),
    ("goal_assists_pg", "ga"),
]


def derive_ratings(players):
    """Attach per-game rates, 0..1 norms, role, 1-99 attributes and value."""
    league = player_league_rates(players)

    for p in players:
        gm = max(1.0, p["gm"])
        r = {}
        for metric, stat in METRIC_SPECS:
            total = p["di"] - p["ki"] if stat == "hb" else p[stat]
            r[metric] = _shrunk_rate(total, gm, league[metric], T["shrink_games"])
        shots = p["gl"] + p["bh"]
        r["accuracy"] = (p["gl"] + T["shrink_accuracy"] * 0.52) / (
            shots + T["shrink_accuracy"])
        r["contested_share"] = (p["cp"] + 40.0) / (max(1.0, p["di"]) + 100.0)
        r["games"] = gm
        r["time_on_ground"] = p["pctp"] / 100.0
        r["score_involved_pg"] = _shrunk_rate(
            p["gl"] + p["bh"] + p["ga"] + p["mi"], gm, 4.0, T["shrink_games"])
        p["rates"] = r

    keys = list(players[0]["rates"].keys())
    norms = {}
    for k in keys:
        vals = [p["rates"][k] for p in players]
        invert = k in ("clangers_pg", "frees_against_pg")
        if k == "accuracy":
            norms[k] = _norm_map(vals, lo=0.22, hi=0.82)
        elif k == "games":
            norms[k] = _norm_map(vals, lo=0.0, hi=26.0)
        elif k == "time_on_ground":
            norms[k] = _norm_map(vals, lo=0.30, hi=0.95)
        elif k == "brownlow_pg":
            norms[k] = _norm_map(vals, cap=1.0)
        else:
            norms[k] = _norm_map(vals, invert=invert)

    def scale(v):
        return int(round(1 + 98 * max(0.0, min(1.0, v))))

    for p in players:
        q = {k: norms[k](p["rates"][k]) for k in keys}
        p["norm"] = q

        a = {}
        a["disposal"] = scale(0.60 * q["disposals_pg"] + 0.25 * q["contested_pg"]
                              + 0.15 * q["clearances_pg"])
        a["contested"] = scale(0.45 * q["contested_pg"] + 0.30 * q["clearances_pg"]
                               + 0.25 * q["contested_share"])
        a["marking"] = scale(0.50 * q["marks_pg"] + 0.28 * q["contested_marks_pg"]
                             + 0.22 * q["marks_inside50_pg"])
        a["pressure"] = scale(0.62 * q["tackles_pg"] + 0.38 * q["one_percenters_pg"])
        a["intercept"] = scale(0.45 * q["rebounds_pg"] + 0.28 * q["marks_pg"]
                               + 0.27 * q["one_percenters_pg"])
        a["carry"] = scale(0.45 * q["inside50s_pg"] + 0.28 * q["bounces_pg"]
                           + 0.27 * q["disposals_pg"])
        a["goalkicking"] = scale(0.66 * q["goals_pg"] + 0.34 * q["marks_inside50_pg"])
        a["accuracy"] = scale(q["accuracy"])
        a["creating"] = scale(0.45 * q["goal_assists_pg"] + 0.30 * q["inside50s_pg"]
                              + 0.25 * q["marks_inside50_pg"])
        a["ruck"] = scale(0.70 * q["hitouts_pg"] + 0.18 * q["clearances_pg"]
                          + 0.12 * q["contested_marks_pg"])
        a["discipline"] = scale(0.62 * q["clangers_pg"] + 0.38 * q["frees_against_pg"])
        a["durability"] = scale(0.55 * q["games"] + 0.45 * q["time_on_ground"])
        a["star"] = scale(0.68 * q["brownlow_pg"] + 0.32 * q["disposals_pg"])
        adj = ATTR_ADJUSTMENTS.get("%s|%s" % (p.get("club", ""), p.get("name", "")), 1.0)
        if adj != 1.0:
            a = {k: max(1, min(99, int(v * adj + 0.5))) for k, v in a.items()}  # GDScript rounds half up
        p["attr"] = a

        # ---- role classification -----------------------------------------
        hitouts_pg = p["ho"] / max(1.0, p["gm"])
        role_scores = {
            "FWD": (0.50 * q["goals_pg"] + 0.26 * q["marks_inside50_pg"]
                    + 0.14 * q["goal_assists_pg"] + 0.10 * q["behinds_pg"]),
            "MID": (0.42 * q["disposals_pg"] + 0.30 * q["contested_pg"]
                    + 0.28 * q["clearances_pg"]),
            "DEF": (0.42 * q["rebounds_pg"] + 0.30 * q["one_percenters_pg"]
                    + 0.20 * q["marks_pg"] + 0.08 * (1.0 - q["goals_pg"])),
        }
        if hitouts_pg >= 7.0:
            role_scores["RUCK"] = 0.25 + 0.85 * q["hitouts_pg"]
        else:
            role_scores["RUCK"] = -1.0
        p["role"] = max(role_scores, key=role_scores.get)
        # Ratings.listed_primary: the listing first, unless the numbers
        # have all but left his listed line.
        listed = p.get("real_pos", "")
        if p["role"] == "MID" and listed in ("FWD", "DEF") and (
                p["gm"] < LISTED_TRUST_GAMES
                or role_scores[listed] >= LISTED_KEEP * role_scores["MID"]
                or (role_scores[listed] >= LISTED_GONE * role_scores["MID"]
                    and p["cl"] / p["gm"] < LISTED_MID_CLEARANCES)):
            p["role"] = listed
        # Ratings.ROLE_CORRECTIONS: clearly misread forwards.
        p["role"] = ROLE_CORRECTIONS.get("%s|%s" % (p.get("club", ""), p.get("name", "")), p["role"])
        p["role_scores"] = role_scores
        p["role2"] = assign_secondary(p)

        # ---- overall + salary value --------------------------------------
        core = role_core(a, p["role"])
        overall = 0.70 * core + 0.22 * a["star"] + 0.08 * a["durability"]
        overall = position_stretch(overall, p["role"])
        conf = min(1.0, p["gm"] / 14.0)
        overall = 40.0 + (overall - 40.0) * (0.40 + 0.60 * conf)
        p["overall"] = scale_overall(overall)
        p["value"] = salary_value(p["overall"])

    return players


ROLE_WEIGHTS = {  # role core: attribute -> weight (Ratings.gd::ROLE_WEIGHTS)
    "RUCK": {"ruck": 0.90, "contested": 0.10},
    "FWD": {"goalkicking": 0.30, "pressure": 0.20, "marking": 0.15, "accuracy": 0.15, "creating": 0.12, "carry": 0.08},
    "MID": {"contested": 0.55, "disposal": 0.13, "carry": 0.14, "pressure": 0.10, "goalkicking": 0.04, "accuracy": 0.04},
    "DEF": {"intercept": 0.40, "pressure": 0.35, "carry": 0.15, "contested": 0.10},
}


# Position scale - see Ratings.gd::position_stretch. [p10, p50, p98] of each
# position's raw blend -> where it lands; one for one outside that band.
STRETCH_ANCHORS = {"MID": (41.22, 53.99, 82.62), "DEF": (40.07, 47.75, 58.86),
                   "FWD": (36.86, 48.25, 61.42), "RUCK": (39.13, 66.27, 86.90)}
STRETCH_TARGETS = {"MID": (37.74, 49.36, 78.04), "DEF": (43.07, 49.41, 73.72),
                   "FWD": (38.38, 49.48, 78.04), "RUCK": (37.50, 49.36, 73.56)}


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


def scale_overall(raw):
    """Match Ratings.gd::scale_overall. Best players land near 90."""
    raw = float(raw)
    if raw < 32.0:
        return int(max(1, min(99, round(30.0 + (raw - 20.0) * (14.0 / 12.0)))))
    t = (raw - 32.0) / 49.0
    t = 0.0 if t < 0.0 else (1.2 if t > 1.2 else t)
    eased = t ** 0.92
    return int(max(1, min(99, round(44.0 + eased * 48.0))))


def assign_secondary(p):
    """Match Ratings.gd::assign_secondary."""
    scores = p["role_scores"]
    primary = p["role"]
    best, best_v = "", -1.0
    for role in ("FWD", "MID", "DEF", "RUCK"):
        if role == primary:
            continue
        sc = scores.get(role, -1.0)
        if sc < 0.0 or not _secondary_ok(p, primary, role, sc):
            continue
        if sc > best_v:
            best_v, best = sc, role
    if best == "":
        best = listed_secondary(p)
    return best


LISTED_KEEP = 0.65
LISTED_GONE = 0.50
LISTED_MID_CLEARANCES = 1.5
LISTED_TRUST_GAMES = 6.0
LISTED_FWD_GOALS = 0.35
LISTED_FWD_MARKS_I50 = 0.5
LISTED_DEF_ACTIONS = 2.0


def listed_secondary(p):
    """Match Ratings.gd::listed_secondary: a midfielder on the numbers gets
    the line his club lists him in when his own numbers back it up."""
    if p["role"] != "MID":
        return ""
    listed = p.get("real_pos", "")
    games = max(1.0, p["gm"])
    if listed == "FWD" and (p["gl"] / games >= LISTED_FWD_GOALS
                            or p["mi"] / games >= LISTED_FWD_MARKS_I50):
        return "FWD"
    if listed == "DEF" and (p["rb"] + p["onepct"]) / games >= LISTED_DEF_ACTIONS:
        return "DEF"
    return ""


def _secondary_ok(p, primary, role, sc):
    primary_sc = p["role_scores"].get(primary, 0.0)
    games = max(1.0, p["gm"])
    if role == "FWD":
        if sc < 0.46 or (p["gl"] < 12 and p["mi"] < 18):
            return False
        return sc >= primary_sc * 0.50
    if role == "MID":
        if sc < 0.52 or p["di"] / games < 16.0:
            return False
        return sc >= primary_sc * 0.58
    if role == "DEF":
        if sc < 0.50 or (p["rb"] + p["onepct"]) / games < 3.2:
            return False
        return sc >= primary_sc * 0.60
    if role == "RUCK":
        return p["ho"] / games >= 5.0 and sc >= 0.75
    return False


def usage_multiplier(disposals, focused=False):
    """Match MatchSim.gd::_usage_mult. Fades a player out of possession once
    they have already had a realistic game."""
    start = 21.0 if focused else 18.0
    if disposals <= start:
        return 1.0
    over = disposals - start
    width = 5.4 if focused else 6.4
    return max(0.02, math.exp(-(over * over) / (width * width)))


def salary_value(overall):
    """Draft salary-cap cost (1-10) derived from the overall rating."""
    for threshold, cost in ((90, 10), (85, 9), (79, 8), (73, 7), (67, 6),
                            (61, 5), (55, 4), (48, 3), (41, 2)):
        if overall >= threshold:
            return cost
    return 1


# ---------------------------------------------------------------------------
# Squads
# ---------------------------------------------------------------------------
class Squad:
    def __init__(self, name, list_players, home=False):
        self.name = name
        self.list = list_players
        self.home = home
        self.ground, self.bench = select_22(list_players)
        self._aggregate()

    def _aggregate(self):
        by_role = defaultdict(list)
        for p in self.ground:
            by_role[p["role"]].append(p)

        def mean(group, key, fallback=45.0):
            return (sum(x["attr"][key] for x in group) / len(group)) if group else fallback

        def top(group, key, n):
            vals = sorted((x["attr"][key] for x in group), reverse=True)[:n]
            return sum(vals) / len(vals) if vals else 45.0

        mids, defs, fwds = by_role["MID"], by_role["DEF"], by_role["FWD"]
        rucks = by_role["RUCK"]
        # Roles: the centre square wins the stoppage ball, the wings do not.
        centre = [p for p in mids if p.get("line") != "WING"] or mids
        self.ruck = mean(rucks, "ruck")
        self.mid_contest = mean(centre, "contested")
        self.mid_disposal = mean(mids, "disposal")
        self.mid_carry = mean(mids, "carry")
        self.def_pressure = mean(defs, "pressure")
        self.def_intercept = mean(defs, "intercept")
        self.fwd_goal = mean(fwds, "goalkicking")
        self.fwd_mark = mean(fwds, "marking")
        self.fwd_create = mean(fwds, "creating")
        self.team_discipline = mean(self.ground, "discipline")
        self.team_pressure = mean(self.ground, "pressure")
        self.team_disposal = mean(self.ground, "disposal")
        self.team_intercept = mean(self.ground, "intercept")
        self.team_star = top(self.ground, "star", 5)

        self.contest = (0.42 * self.mid_contest + 0.24 * self.ruck
                        + 0.22 * self.mid_disposal + 0.12 * self.team_star)
        self.attack = (0.40 * self.fwd_goal + 0.26 * self.mid_carry
                       + 0.20 * self.fwd_create + 0.14 * self.fwd_mark)
        self.defence = (0.50 * self.def_pressure + 0.32 * self.def_intercept
                        + 0.18 * self.team_discipline)


def _for_slot(p, slot):
    copy = dict(p)
    copy["role"] = slot
    return copy


def select_22(list_players):
    pool = sorted(list_players, key=lambda p: p["overall"], reverse=True)
    ground, used = [], set()
    for role, need in GROUND_SLOTS.items():
        added = 0
        for p in pool:
            if added >= need:
                break
            if p["role"] == role and p["id"] not in used:
                ground.append(_for_slot(p, role))
                used.add(p["id"])
                added += 1
        for p in pool:
            if added >= need:
                break
            if p.get("role2", "") == role and p["id"] not in used:
                ground.append(_for_slot(p, role))
                used.add(p["id"])
                added += 1
    for p in pool:                      # fill structural shortfalls
        if len(ground) >= 18:
            break
        if p["id"] not in used:
            ground.append(_for_slot(p, p["role"]))
            used.add(p["id"])
    bench = [p for p in pool if p["id"] not in used][:INTERCHANGE]
    ground = ground[:18]
    mark_wings(ground)
    return ground, bench


# Roles.gd: two of the five midfielders play the wings.
WING_SLOTS, WING_TRANSITION, WING_STOPPAGE = 2, 1.6, 0.4


def mark_wings(ground):
    def wing_fit(p):
        return 0.55 * p["attr"]["carry"] + 0.45 * p["attr"]["disposal"]

    def centre_fit(p):
        return 0.75 * p["attr"]["contested"] + 0.25 * p["attr"]["disposal"]

    mids = [p for p in ground if p["role"] == "MID"]
    rest = sorted(mids, key=lambda p: (centre_fit(p), -wing_fit(p), p["id"]))
    for p in rest[:min(WING_SLOTS, max(0, len(mids) - 1))]:
        p["line"] = "WING"


# ---------------------------------------------------------------------------
# Match simulation
# ---------------------------------------------------------------------------
class MatchStats:
    def __init__(self):
        self.team = {0: defaultdict(float), 1: defaultdict(float)}
        self.player = defaultdict(lambda: defaultdict(float))

    def t(self, side, key, n=1.0):
        self.team[side][key] += n

    def p(self, player, key, n=1.0):
        if player:
            self.player[player["id"]][key] += n

    def score(self, side):
        return int(self.team[side]["goals"] * 6 + self.team[side]["behinds"])


# Pressure by zone (MatchSim.gd PRESS_ZONES): the carrier's back third (their
# forwards press), the middle (their midfield), his forward third (their
# defenders). Each role's share of the pressing there.
PRESS_ZONES = [
    {"FWD": 1.0, "MID": 0.75, "RUCK": 0.30, "DEF": 0.10},
    {"FWD": 0.30, "MID": 1.0, "RUCK": 0.70, "DEF": 0.30},
    {"FWD": 0.10, "MID": 0.75, "RUCK": 0.30, "DEF": 1.0},
]
PRESS_ZONE_EDGE = 20.0
PRESS_RUSH_RATIO = 2.0     # non-tackle pressure acts per tackle chance
PRESS_TURNOVER = 0.08      # of those, the share that turn it over outright
PRESS_RUSH_GAIN = 0.80     # the ground a rushed disposal still gains
FEED_BASE, FEED_SLOPE = 0.94, 0.12   # inside-50 kick's Creating on the shot


def press_zone(atk_fp):
    if atk_fp < -PRESS_ZONE_EDGE:
        return 0
    return 2 if atk_fp > PRESS_ZONE_EDGE else 1


class MatchSim:
    def __init__(self, squad_home, squad_away, seed=0, narrate=False):
        self.squads = [squad_home, squad_away]
        self.rng = random.Random(seed)
        self.stats = MatchStats()
        self.events = []
        self.narrate = narrate

    def log(self, minute, quarter, text, side=None, kind="info"):
        if self.narrate:
            self.events.append({
                "minute": minute, "quarter": quarter, "text": text,
                "side": side, "kind": kind,
                "score": [self.stats.score(0), self.stats.score(1)]})

    def _weighted(self, group, key, power=2.0, usage=False, wing=1.0):
        if not group:
            return None
        w = []
        for p in group:
            base = max(1.0, p["attr"][key]) ** power
            if p.get("line") == "WING":
                base *= wing
            if usage:
                base *= usage_multiplier(self.stats.player[p["id"]]["disposals"])
            w.append(max(base, 1e-6))
        return self.rng.choices(group, w)[0]

    def zone_pressure(self, side, zone):
        w = PRESS_ZONES[zone]
        tot = wt = 0.0
        for p in self.squads[side].ground:
            rw = w.get(p["role"], 0.0)
            tot += rw * p["attr"]["pressure"]
            wt += rw
        return tot / wt if wt else 45.0

    def pick_presser(self, side, zone):
        w = PRESS_ZONES[zone]
        group = self.squads[side].ground
        weights = [max(w.get(p["role"], 0.0) * max(1.0, p["attr"]["pressure"]) ** 2, 1e-6)
                   for p in group]
        return self.rng.choices(group, weights)[0]

    def contest_winner(self, fp):
        a, b = self.squads[0].contest, self.squads[1].contest
        p_home = 0.5 + (a - b) / T["contest_swing"] + T["home_ground_bonus"]
        if fp is not None:
            p_home += max(-0.07, min(0.07, fp / 900.0))
        lim = T["contest_clamp"]
        return 0 if self.rng.random() < max(1 - lim, min(lim, p_home)) else 1

    def pick_carrier(self, side, fp):
        sq = self.squads[side]
        atk_fp = fp if side == 0 else -fp
        if atk_fp < -10:
            group = [p for p in sq.ground if p["role"] in ("DEF", "MID")]
            key = "intercept"
        elif atk_fp > T["forward50_line"]:
            group = [p for p in sq.ground if p["role"] in ("FWD", "MID")]
            key = "goalkicking"
        elif atk_fp > 5:
            group = [p for p in sq.ground if p["role"] in ("MID", "FWD")]
            key = "carry"
        else:
            group = [p for p in sq.ground if p["role"] in ("MID", "RUCK", "DEF")]
            key = "disposal"
        wing = WING_TRANSITION if -10 <= atk_fp <= T["forward50_line"] else 1.0
        return self._weighted(group or sq.ground, key, usage=True, wing=wing)

    def _stoppage(self, side, opp, from_bounce):
        """Ruck contest + clearance at a genuine stoppage."""
        st = self.stats
        atk, dfn = self.squads[side], self.squads[opp]
        if not from_bounce:
            return
        ruck_a = [p for p in atk.ground if p["role"] == "RUCK"]
        ruck_b = [p for p in dfn.ground if p["role"] == "RUCK"]
        total_hits = sum(1 for _ in range(3)
                         if self.rng.random() < T["hitouts_per_stoppage"] / 3.0)
        if total_hits:
            share = 0.5 + (atk.ruck - dfn.ruck) / 260.0
            share = max(0.15, min(0.85, share))
            ha = int(round(total_hits * share))
            hb = total_hits - ha
            st.t(side, "hitouts", ha)
            st.t(opp, "hitouts", hb)
            st.p(ruck_a[0] if ruck_a else None, "hitouts", ha)
            st.p(ruck_b[0] if ruck_b else None, "hitouts", hb)
        if self.rng.random() < T["clearance_per_stoppage"]:
            st.t(side, "clearances")
            mid = self._weighted([p for p in atk.ground if p["role"] in ("MID", "RUCK")],
                                 "contested", wing=WING_STOPPAGE)
            st.p(mid, "clearances")

    def play_chain(self, side, fp, minute, quarter, from_bounce, from_kick_in=False):
        st = self.stats
        opp = 1 - side
        atk, dfn = self.squads[side], self.squads[opp]
        st.t(side, "chains")
        self._stoppage(side, opp, from_bounce)

        atk_fp = fp if side == 0 else -fp
        # A chain that starts inside its forward 50 (a ball-up won there) goes
        # through the normal entry below on its first disposal, so it can score.
        touched_i50 = False

        touches = 0
        while touches < T["max_touches_per_chain"]:
            touches += 1
            carrier = self.pick_carrier(side, fp)
            st.t(side, "disposals")
            st.p(carrier, "disposals")

            hb_bias = 0.85 + 0.30 * (100 - carrier["attr"]["marking"]) / 100.0
            # A kick-in is kicked: no handball roll for its first disposal.
            if not (from_kick_in and touches == 1) and \
                    self.rng.random() < T["handball_share"] * hb_bias:
                st.t(side, "handballs")
                st.p(carrier, "handballs")
            else:
                st.t(side, "kicks")
                st.p(carrier, "kicks")
                mark_p = T["mark_share_of_kicks"] * (
                    0.75 + 0.50 * carrier["attr"]["marking"] / 100.0)
                if self.rng.random() < mark_p:
                    st.t(side, "marks")
                    st.p(carrier, "marks")

            atk_fp = fp if side == 0 else -fp
            zone = press_zone(atk_fp)
            pressure = T["pressure_base"] * (0.72 + 0.56 * self.zone_pressure(opp, zone) / 100.0)
            pressure *= 1.10 if atk_fp < 0 else 0.95

            # One roll, three outcomes: tackle, rushed disposal, or nothing.
            press_roll = self.rng.random()
            rushed = False
            if press_roll < pressure:
                tackler = self.pick_presser(opp, zone)
                st.t(opp, "tackles")
                st.p(tackler, "tackles")
                st.t(opp, "pressure_acts")
                st.p(tackler, "pressure_acts")
                retain = T["tackle_retention"] * (
                    0.75 + 0.50 * carrier["attr"]["contested"] / 100.0)
                if self.rng.random() < retain:
                    fp = max(-T["goal_line"], min(T["goal_line"],
                             fp + self.rng.uniform(4, 12) * (1 if side == 0 else -1)))
                    continue
                st.t(opp, "pressure_wins")
                self.log(minute, quarter, "%s tackles %s — ball up"
                         % (tackler["name"], carrier["name"]), opp, "tackle")
                return ("stoppage", fp, carrier, False)
            if press_roll < pressure * (1.0 + PRESS_RUSH_RATIO):
                presser = self.pick_presser(opp, zone)
                st.t(opp, "pressure_acts")
                st.p(presser, "pressure_acts")
                turn_p = (PRESS_TURNOVER * (0.80 + 0.40 * presser["attr"]["pressure"] / 100.0)
                          * (1.20 - 0.40 * carrier["attr"]["disposal"] / 100.0))
                if self.rng.random() < turn_p:
                    st.t(opp, "pressure_wins")
                    self.log(minute, quarter, "%s forces the turnover" % presser["name"],
                             opp, "pressure")
                    return ("turnover", fp, presser, False)
                rushed = True

            prev_atk_fp = atk_fp
            gain = T["metres_gain_mean"] * (0.55 + 0.90 * carrier["attr"]["carry"] / 100.0)
            gain *= self.rng.uniform(0.45, 1.75)
            if rushed:
                gain *= PRESS_RUSH_GAIN
            fp += gain if side == 0 else -gain
            fp = max(-T["goal_line"], min(T["goal_line"], fp))

            atk_fp = fp if side == 0 else -fp

            # Rebound 50: winning it out of your own defensive arc.
            if prev_atk_fp < T["rebound_from"] and atk_fp > T["rebound_to"]:
                st.t(side, "rebounds")
                st.p(carrier, "rebounds")

            if atk_fp >= T["forward50_line"] and not touched_i50:
                touched_i50 = True
                st.t(side, "inside50")
                st.p(carrier, "inside50")
                self.log(minute, quarter, "%s sends it inside 50" % carrier["name"],
                         side, "inside50")
                return self.resolve_forward50(side, fp, minute, quarter, carrier)

            # A clean exit from your own defensive 50 is a rebound.
            if atk_fp > 5.0 and (fp if side == 0 else -fp) - gain <= -T["forward50_line"]:
                st.t(opp, "rebounds")
                st.p(carrier, "rebounds")

        return ("stoppage", fp, None, True)

    def resolve_forward50(self, side, fp, minute, quarter, feeder):
        st = self.stats
        opp = 1 - side
        atk, dfn = self.squads[side], self.squads[opp]
        st.p(feeder, "goal_assists")

        shooter = self._weighted(
            [p for p in atk.ground if p["role"] in ("FWD", "MID")] or atk.ground,
            "goalkicking", T["shooter_power"])
        defender = self._weighted(
            [p for p in dfn.ground if p["role"] == "DEF"] or dfn.ground, "intercept")

        marked = self.rng.random() < max(0.10, min(0.72,
            0.5 + (atk.fwd_mark - dfn.def_intercept) / 240.0))
        if marked:
            st.t(side, "marks")
            st.p(shooter, "marks")
        spoilt = self.rng.random() < 0.30 + 0.35 * dfn.def_intercept / 100.0
        if spoilt and not marked:
            st.t(opp, "spoils")
            st.p(defender, "spoils")
        if self.rng.random() < T["one_percenter_share"]:
            st.t(opp, "one_percenters")
            st.p(defender, "one_percenters")

        goal_p = T["inside50_goal"]
        goal_p *= 0.80 + 0.40 * shooter["attr"]["goalkicking"] / 100.0
        goal_p *= 1.16 if marked else 0.74
        goal_p *= 0.82 + 0.36 * shooter["attr"]["accuracy"] / 100.0
        if spoilt and not marked:
            goal_p *= 0.58
        goal_p *= 0.90 + 0.20 * atk.attack / 100.0
        goal_p *= FEED_BASE + FEED_SLOPE * feeder["attr"]["creating"] / 100.0 if feeder else 1.0
        goal_p *= 1.06 - 0.12 * dfn.defence / 100.0
        behind_p = T["inside50_behind"] * (0.80 + 0.40 * shooter["attr"]["goalkicking"] / 100.0)

        roll = self.rng.random()
        if roll < goal_p:
            st.t(side, "goals")
            st.p(shooter, "goals")
            self.log(minute, quarter, "GOAL %s — %s %d.%d (%d) def %s %d.%d (%d)" % (
                shooter["name"], self.squads[side].name,
                int(st.team[side]["goals"]), int(st.team[side]["behinds"]), st.score(side),
                self.squads[opp].name, int(st.team[opp]["goals"]),
                int(st.team[opp]["behinds"]), st.score(opp)), side, "goal")
            return ("score", 0.0, shooter, True)
        if roll < goal_p + behind_p:
            st.t(side, "behinds")
            st.p(shooter, "behinds")
            self.log(minute, quarter, "Behind %s (%s)" % (
                shooter["name"], self.squads[side].name), side, "behind")
            return ("behind", kick_in_fp(side), shooter, True)

        # A spoil puts it on the deck: the forwards crumb it now and then and
        # snap (MatchSim._crumb), otherwise the defence clears.
        if spoilt and not marked:
            pool = atk.ground
            weights = [CRUMB_ROLES.get(p["role"], 0.0) * max(1.0, p["attr"]["pressure"]) ** 2 for p in pool]
            if sum(weights) > 0:
                crumber = self.rng.choices(pool, weights)[0]
                if self.rng.random() < CRUMB_P * (0.7 + 0.6 * crumber["attr"]["pressure"] / 100.0):
                    snap = T["inside50_goal"]
                    snap *= 0.80 + 0.40 * crumber["attr"]["goalkicking"] / 100.0
                    snap *= 0.74 * (0.82 + 0.36 * crumber["attr"]["accuracy"] / 100.0)
                    snap *= (0.90 + 0.20 * atk.attack / 100.0) * (1.06 - 0.12 * dfn.defence / 100.0)
                    snap *= CRUMB_SNAP
                    c_behind = T["inside50_behind"] * (0.80 + 0.40 * crumber["attr"]["goalkicking"] / 100.0)
                    r = self.rng.random()
                    if r < snap:
                        st.t(side, "goals")
                        st.p(crumber, "goals")
                        self.log(minute, quarter, "GOAL %s (crumb)" % crumber["name"], side, "goal")
                        return ("score", 0.0, crumber, True)
                    if r < snap + c_behind:
                        st.t(side, "behinds")
                        st.p(crumber, "behinds")
                        self.log(minute, quarter, "Behind %s (%s)" % (
                            crumber["name"], self.squads[side].name), side, "behind")
                        return ("behind", kick_in_fp(side), crumber, True)

        st.t(opp, "rebounds")
        st.p(defender, "rebounds")
        self.log(minute, quarter, "%s rebounds it out of danger" % defender["name"],
                 opp, "rebound")
        return ("turnover", fp, defender, False)

    def run(self):
        """
        Drive the match as a sequence of possession chains.

        A chain either starts at a genuine stoppage (centre bounce / ball-up,
        which is where hit-outs and clearances come from: a centre bounce
        after a score or at a quarter start, otherwise a ball-up where play
        stopped) or continues from where the previous chain died — a turnover hands the ball to the other
        team on the spot, a score restarts at the centre.
        """
        per_quarter = T["chains_per_game"] // 4
        fp = 0.0
        next_side = None              # None => the stoppage is contested
        at_centre = True
        kick_in = False
        for quarter in range(1, 5):
            at_centre = True          # every quarter starts with a centre bounce
            kick_in = False
            for i in range(per_quarter):
                minute = (quarter - 1) * 30 + int(30 * i / max(1, per_quarter)) + 1
                # A kick-in after a behind is not a stoppage: no ruck contest,
                # no clearance.
                from_kick_in = kick_in
                kick_in = False
                stoppage = at_centre or (not from_kick_in
                                         and self.rng.random() < T["stoppage_share"])
                if stoppage:
                    # Centre bounce after a score or at a quarter start;
                    # otherwise a ball-up where play stopped.
                    start_fp = 0.0 if at_centre else fp
                    side = self.contest_winner(None)
                else:
                    start_fp = fp
                    side = (next_side if next_side is not None
                            else self.contest_winner(fp))

                outcome, fp, actor, _ = self.play_chain(
                    side, start_fp, minute, quarter, stoppage, from_kick_in)

                # Goal: centre bounce. Behind: the other side kicks in (fp is
                # already the goal square). Turnover: play on from here.
                at_centre = (outcome == "score")
                kick_in = (outcome == "behind")
                next_side = (1 - side) if outcome in ("turnover", "behind") else None
                if outcome == "score":
                    fp = 0.0

                # End-of-chain error: clanger, sometimes a free kick against.
                if self.rng.random() < T["clanger_per_chain"]:
                    ground = self.squads[side].ground
                    w = [max(1.0, 101 - p["attr"]["discipline"]) ** 1.6 for p in ground]
                    err = self.rng.choices(ground, w)[0]
                    self.stats.t(side, "clangers")
                    self.stats.p(err, "clangers")
                    if self.rng.random() < T["clanger_is_free"]:
                        self.stats.t(1 - side, "frees_for")
                        self.stats.t(side, "frees_against")
                        self.stats.p(err, "frees_against")
                        next_side = 1 - side
        return self.stats


GOAL_SQUARE_DEPTH = 9.0  # metres; kick-ins are taken from inside it


def kick_in_fp(side):
    """Where the defending side kicks in from after `side` scores a behind:
    the middle of the goal square at the end `side` attacks."""
    return (1 if side == 0 else -1) * (T["goal_line"] - GOAL_SQUARE_DEPTH * 0.5)


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------
def by_club(players):
    out = defaultdict(list)
    for p in players:
        out[p["club"]].append(p)
    return out


def simulate_sample(players, n_matches, seed):
    rng = random.Random(seed)
    clubs_map = by_club(players)
    clubs = sorted(clubs_map)
    agg = MatchStats()
    margins, scores = [], []
    for i in range(n_matches):
        a, b = rng.sample(clubs, 2)
        res = MatchSim(Squad(a, clubs_map[a], True), Squad(b, clubs_map[b], False),
                       seed=seed + i).run()
        for side in (0, 1):
            for k, v in res.team[side].items():
                agg.team[0][k] += v
        margins.append(abs(res.score(0) - res.score(1)))
        scores.extend([res.score(0), res.score(1)])
    return agg, n_matches * 2, margins, scores


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--matches", type=int, default=400)
    ap.add_argument("--seed", type=int, default=1234)
    ap.add_argument("--sample", action="store_true")
    ap.add_argument("--ratings", action="store_true")
    args = ap.parse_args()

    players = derive_ratings(load_players())
    bench, gp = real_benchmarks(players)

    print("Loaded %d players from %d clubs" % (len(players), len(gp)))
    print("Club season lengths: %s" % ", ".join(
        "%s=%d" % (k, int(v)) for k, v in sorted(gp.items())))
    roles = defaultdict(int)
    for p in players:
        roles[p["role"]] += 1
    print("Role split: %s\n" % dict(sorted(roles.items())))

    if args.ratings:
        out = os.path.join(ROOT, "data", "ratings_preview.csv")
        with open(out, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["club", "num", "name", "role", "overall", "value"]
                       + sorted(players[0]["attr"].keys()))
            for p in sorted(players, key=lambda x: (-x["overall"], x["club"])):
                w.writerow([p["club"], p["num"], p["name"], p["role"], p["overall"],
                            p["value"]]
                           + [p["attr"][k] for k in sorted(p["attr"].keys())])
        print("wrote %s" % out)
        return

    if args.sample:
        cm = by_club(players)
        clubs = sorted(cm)
        a, b = clubs[0], clubs[3]
        sim = MatchSim(Squad(a, cm[a], True), Squad(b, cm[b], False),
                       seed=args.seed, narrate=True)
        sim.run()
        print("=== %s (home) vs %s ===" % (a, b))
        for e in sim.events[:60]:
            print("Q%d %2d' %-9s %s" % (e["quarter"], e["minute"], e["kind"], e["text"]))
        print("Final: %s %d.%d (%d)  |  %s %d.%d (%d)" % (
            a, int(sim.stats.team[0]["goals"]), int(sim.stats.team[0]["behinds"]),
            sim.stats.score(0), b, int(sim.stats.team[1]["goals"]),
            int(sim.stats.team[1]["behinds"]), sim.stats.score(1)))
        return

    agg, games, margins, scores = simulate_sample(players, args.matches, args.seed)
    rows = [
        ("Score (pts)", None, bench["score"]),
        ("Goals", "goals", bench["gl"]),
        ("Behinds", "behinds", bench["bh"]),
        ("Disposals", "disposals", bench["di"]),
        ("Kicks", "kicks", bench["ki"]),
        ("Handballs", "handballs", bench["di"] - bench["ki"]),
        ("Marks", "marks", bench["mk"]),
        ("Tackles", "tackles", bench["tk"]),
        ("Inside 50s", "inside50", bench["if50"]),
        ("Clearances", "clearances", bench["cl"]),
        ("Hit-outs", "hitouts", bench["ho"]),
        ("Rebound 50s", "rebounds", bench["rb"]),
        ("One percenters", "one_percenters", bench["onepct"]),
        ("Clangers", "clangers", bench["cg"]),
        ("Free kicks for", "frees_for", bench["ff"]),
    ]
    print("%-18s %10s %9s %7s" % ("Stat /team/game", "REAL 2026", "SIM", "ratio"))
    print("-" * 48)
    worst = 0.0
    for label, key, real in rows:
        if key is None:
            sim_v = (agg.team[0]["goals"] * 6 + agg.team[0]["behinds"]) / games
        else:
            sim_v = agg.team[0][key] / games
        ratio = sim_v / real if real else 0.0
        worst = max(worst, abs(math.log(max(ratio, 1e-6))))
        flag = "  <-- off" if abs(ratio - 1) > 0.12 else ""
        print("%-18s %10.1f %9.1f %7.2f%s" % (label, real, sim_v, ratio, flag))

    print("-" * 48)
    print("Avg margin %.1f pts | median %.1f | max %d"
          % (sum(margins) / len(margins), _pctile(margins, 0.5), max(margins)))
    print("Team score p5=%d p50=%d p95=%d"
          % (_pctile(scores, 0.05), _pctile(scores, 0.5), _pctile(scores, 0.95)))
    print("Close games (<=12 pts): %.1f%%"
          % (100.0 * sum(1 for m in margins if m <= 12) / len(margins)))
    print("Worst stat deviation: %.0f%%" % (100 * (math.exp(worst) - 1)))

    print("\nTop 20 by derived overall rating:")
    for p in sorted(players, key=lambda x: -x["overall"])[:20]:
        print("  %3d %-4s $%-2d %-22s %-4s GM=%2d BR=%2d DI=%.1f GL=%d" % (
            p["overall"], p["club"], p["value"], p["name"], p["role"],
            p["gm"], p["br"], p["di"] / max(1, p["gm"]), p["gl"]))


if __name__ == "__main__":
    main()
