#!/usr/bin/env python3
"""Merge draft-compression experiment shards into a markdown report.

Measurement only. Shards come from tools/balance/draft_experiment.gd:
  d_*.json  --mode draft   (list shape and preseason strength, many seeds)
  s_*.json  --mode season  (the same drafts played through Season -> MatchSim)

  python3 tools/balance/draft_experiment_report.py DIR [--md out.md]

Also prints the real-AFL parity benchmark from tools/balance/afl_ladders.json
plus data/raw/standings_2026.json. Standard library only.
"""
import json
import math
import os
import statistics as st
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNITS = ["contest", "attack", "defence"]
SUBUNITS = ["ruck", "mid_contest", "mid_disposal", "mid_carry", "def_pressure",
            "def_intercept", "fwd_goal", "fwd_mark", "fwd_create", "team_star",
            "team_discipline"]
FINALISTS = 10

# Row order and labels in the report. Missing shards are skipped.
ORDER = [
    ("real", "", "Real 2026 lists (no draft)"),
    ("current", "ai", "Shipped draft, all-AI (snake)"),
    ("current", "board", "Shipped draft, naive human (board)"),
    ("linear", "ai", "Order: linear (same order every round)"),
    ("random_round", "ai", "Order: fresh random order each round"),
    ("need50", "ai", "Scoring: need weighting halved"),
    ("need0", "ai", "Scoring: no need weighting"),
    ("vorp0", "ai", "Scoring: no replacement (VORP) term"),
    ("capsoft_off", "ai", "Scoring: no soft cap penalty"),
    ("cap_off", "ai", "Cap: no soft penalty, hard cap x10"),
    ("bpa", "ai", "Scoring: best available by worth (cap kept)"),
    ("bpa_cap_off", "ai", "Mechanical snake: BPA, no cap"),
    ("bpa_cap_off_linear", "ai", "Mechanical linear: BPA, no cap"),
    ("noise2", "ai", "Valuation noise SD 2 (all clubs)"),
    ("noise4", "ai", "Valuation noise SD 4 (all clubs)"),
    ("noise8", "ai", "Valuation noise SD 8 (all clubs)"),
    ("comp4", "ai", "Competence: club SD ~ U[0,4]"),
    ("comp8", "ai", "Competence: club SD ~ U[0,8]"),
    ("comp12", "ai", "Competence: club SD ~ U[0,12]"),
    ("comp8_need50", "ai", "Competence U[0,8] + need halved"),
    ("comp8_linear", "ai", "Competence U[0,8] + linear order"),
    ("comp8", "board", "Competence U[0,8], naive human"),
]


def mean(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else float("nan")


def sd(xs):
    xs = list(xs)
    return st.pstdev(xs) if len(xs) > 1 else 0.0


def pearson(x, y):
    mx, my = mean(x), mean(y)
    sxy = sum((a - mx) * (b - my) for a, b in zip(x, y))
    sxx = sum((a - mx) ** 2 for a in x)
    syy = sum((b - my) ** 2 for b in y)
    return sxy / math.sqrt(sxx * syy) if sxx > 0 and syy > 0 else float("nan")


def ols_r2(rows, y):
    """R^2 of y on the columns of rows (intercept included), by normal equations."""
    k = len(rows[0])
    X = [[1.0] + list(r) for r in rows]
    n = len(X)
    A = [[sum(X[i][a] * X[i][b] for i in range(n)) for b in range(k + 1)] for a in range(k + 1)]
    v = [sum(X[i][a] * y[i] for i in range(n)) for a in range(k + 1)]
    for a in range(k + 1):  # ridge-free Gauss-Jordan with partial pivoting
        piv = max(range(a, k + 1), key=lambda r: abs(A[r][a]))
        A[a], A[piv] = A[piv], A[a]
        v[a], v[piv] = v[piv], v[a]
        if abs(A[a][a]) < 1e-12:
            continue
        for r in range(k + 1):
            if r != a:
                f = A[r][a] / A[a][a]
                for c in range(a, k + 1):
                    A[r][c] -= f * A[a][c]
                v[r] -= f * v[a]
    beta = [v[a] / A[a][a] if abs(A[a][a]) > 1e-12 else 0.0 for a in range(k + 1)]
    pred = [sum(b * x for b, x in zip(beta, row)) for row in X]
    my = mean(y)
    ss_tot = sum((t - my) ** 2 for t in y)
    ss_res = sum((t - p) ** 2 for t, p in zip(y, pred))
    return 1.0 - ss_res / ss_tot if ss_tot > 0 else float("nan")


def wilson(k, n):
    if n == 0:
        return (float("nan"), float("nan"))
    z = 1.96
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (c - h, c + h)


def load(path):
    with open(path) as f:
        return json.load(f)


def key_of(d):
    return (d["variant"], "" if d["variant"] == "real" else d.get("policy", "ai"))


# ---------------------------------------------------------------------------
# Role counts (primary role) seen across the real 2026 lists; a drafted list
# outside this band on any role is flagged as not believable.
REAL_BAND = {"RUCK": (2, 4), "MID": (12, 24), "DEF": (7, 14), "FWD": (4, 9)}


def draft_metrics(leagues):
    """Preseason spread of the drafted leagues, averaged over leagues."""
    per = defaultdict(list)
    roles = defaultdict(list)
    short_lines = 0
    n_clubs = 0
    for lg in leagues:
        u = lg["units"]
        cs = list(u.values())
        for m in ["ovr22", "strength", "list_ovr", "top5_ovr", "value"] + UNITS + SUBUNITS:
            xs = [c[m] for c in cs]
            per[m + "_sd"].append(sd(xs))
            per[m + "_rng"].append(max(xs) - min(xs))
        per["r_ovr_str"].append(pearson([c["ovr22"] for c in cs], [c["strength"] for c in cs]))
        for c in cs:
            n_clubs += 1
            for r in ["RUCK", "MID", "DEF", "FWD"]:
                roles[r].append(c["roles"][r])
            if any(not (REAL_BAND[r][0] <= c["roles"][r] <= REAL_BAND[r][1]) for r in REAL_BAND):
                short_lines += 1
    out = {k: mean(v) for k, v in per.items()}
    out["n"] = len(leagues)
    out["distinct"] = len({lg["sig"] for lg in leagues})
    for r in roles:
        out["role_" + r] = (min(roles[r]), mean(roles[r]), max(roles[r]))
    out["short_lines"] = short_lines / max(1, n_clubs)
    return out


def season_metrics(shard_list):
    units = {}
    seasons = []
    for d in shard_list:
        for lg in d["leagues"]:
            units[lg["league"]] = lg["units"]
        seasons.extend(d["seasons"])
    fav = [0.0, 0]
    fav_ovr = [0.0, 0]
    r_str, r_ovr = [], []
    prem_rank, spoon_rank, fin_top5 = [], [], []
    by_league = defaultdict(list)
    margins60 = [0, 0]
    for s in seasons:
        rows = s["clubs"]
        str_of = {c["club"]: c["strength"] for c in rows}
        ovr_of = {c["club"]: c["ovr22"] for c in rows}
        wins = [c["w"] + 0.5 * c["d"] for c in rows]
        r_str.append(pearson([c["strength"] for c in rows], wins))
        r_ovr.append(pearson([c["ovr22"] for c in rows], wins))
        for c in rows:
            if c["premier"]:
                prem_rank.append(c["strength_rank"])
            if c["spoon"]:
                spoon_rank.append(c["strength_rank"])
            if c["strength_rank"] <= 5:
                fin_top5.append(1 if c["finals"] else 0)
        by_league[s["league"]].append(s)
        for m in s["matches"]:
            if m["final"]:
                continue
            h, a = m["h"], m["a"]
            res = 1.0 if m["hs"] > m["as"] else (0.5 if m["hs"] == m["as"] else 0.0)
            margins60[1] += 1
            if abs(m["hs"] - m["as"]) >= 60:
                margins60[0] += 1
            if str_of[h] != str_of[a]:
                fav[0] += res if str_of[h] > str_of[a] else 1.0 - res
                fav[1] += 1
            if ovr_of[h] != ovr_of[a]:
                fav_ovr[0] += res if ovr_of[h] > ovr_of[a] else 1.0 - res
                fav_ovr[1] += 1
    within_all, skill_all, shares = [], [], []
    reliab = []   # (share of club-mean-wins variance that is skill, clubs) per league
    club_means = []   # (league, club, mean wins, n seasons)
    distinct_prem = []
    for lg, ss in by_league.items():
        per_club = defaultdict(list)
        prem = []
        for s in ss:
            for c in s["clubs"]:
                per_club[c["club"]].append(c["w"] + 0.5 * c["d"])
                if c["premier"]:
                    prem.append(c["club"])
        if len(ss) >= 3:
            distinct_prem.append(len(set(prem)) / len(prem))
        if len(ss) < 2:
            continue
        within = mean(st.variance(v) for v in per_club.values())
        means = [mean(v) for v in per_club.values()]
        between = st.variance(means)
        skill = max(0.0, between - within / len(ss))
        within_all.append(within)
        skill_all.append(skill)
        shares.append(skill / (skill + within) if skill + within > 0 else 0.0)
        reliab.append((skill / (skill + within / len(ss)) if skill > 0 else 0.0, len(per_club)))
        for club, v in per_club.items():
            club_means.append((lg, club, mean(v), len(v)))
    skill = mean(skill_all)
    luck = mean(within_all)
    ci = wilson(fav[0], fav[1])
    return {
        "seasons": len(seasons), "leagues": len(by_league), "matches": fav[1],
        "fav": fav[0] / fav[1] if fav[1] else float("nan"), "fav_ci": ci,
        "fav_ovr": fav_ovr[0] / fav_ovr[1] if fav_ovr[1] else float("nan"),
        "skill_share": skill / (skill + luck) if skill + luck > 0 else float("nan"),
        "skill_sd": math.sqrt(skill),
        "share_se": sd(shares) / math.sqrt(len(shares)) if len(shares) > 1 else float("nan"), "luck_sd": math.sqrt(luck),
        "r_str": mean(r_str), "r_ovr": mean(r_ovr),
        "prem_top3": mean(1 if r <= 3 else 0 for r in prem_rank),
        "prem_rank": mean(prem_rank),
        "spoon_bot3": mean(1 if r >= 16 else 0 for r in spoon_rank),
        "fin_top5": mean(fin_top5),
        "distinct_prem": mean(distinct_prem) if distinct_prem else float("nan"),
        "m60": margins60[0] / max(1, margins60[1]),
        "club_means": club_means, "units": units, "reliab": reliab,
    }


def explain(all_season_metrics):
    """D: how much of the skill (club mean wins over replayed seasons) each
    preseason measure explains, pooled over every drafted league, centred
    within league."""
    xs = defaultdict(list)
    y = []
    rel = []
    for key, m in all_season_metrics.items():
        if key[0] == "real":
            continue
        by_lg = defaultdict(list)
        for lg, club, w, n in m["club_means"]:
            by_lg[(key, lg)].append((club, w, n))
        for (k2, lg), rows in by_lg.items():
            u = m["units"][lg]
            mw = mean(w for _, w, _ in rows)
            cols = {"ovr22": [], "strength": [], "units3": [], "sub": []}
            for club, w, n in rows:
                c = u[club]
                y.append(w - mw)
                cols["ovr22"].append([c["ovr22"]])
                cols["strength"].append([c["strength"]])
                cols["units3"].append([c[k] for k in UNITS])
                cols["sub"].append([c[k] for k in SUBUNITS])
            for name, vals in cols.items():
                cm = [mean(col) for col in zip(*vals)]
                xs[name].extend([[a - b for a, b in zip(r, cm)] for r in vals])
            rel.append((key, lg, len(rows)))
    out = {"n": len(y)}
    rs = [(r, n) for k, m in all_season_metrics.items() if k[0] != "real" for r, n in m["reliab"]]
    out["ceiling"] = sum(r * n for r, n in rs) / max(1, sum(n for _, n in rs))
    for name in ["ovr22", "strength", "units3", "sub"]:
        out[name] = ols_r2(xs[name], y)
    both = [a + b for a, b in zip(xs["ovr22"], xs["sub"])]
    out["ovr_plus_sub"] = ols_r2(both, y)
    return out


def afl_benchmark():
    d = load(os.path.join(ROOT, "tools/balance/afl_ladders.json"))["seasons"]
    s26 = load(os.path.join(ROOT, "data/raw/standings_2026.json"))["standings"]
    d = dict(d)
    d["2026"] = [[r["wins"], r["losses"], r["draws"]] for r in s26]
    rows = []
    for y, clubs in sorted(d.items()):
        w = [a + 0.5 * c for a, b, c in clubs]
        g = mean(a + b + c for a, b, c in clubs)
        var = st.pvariance(w)
        luck = g * 0.25
        rows.append((y, g, math.sqrt(var), math.sqrt(luck), var, luck))
    return rows


# ---------------------------------------------------------------------------
def f(x, spec="%.2f"):
    return "-" if x is None or (isinstance(x, float) and math.isnan(x)) else spec % x


def pct(x):
    return f(x * 100 if x == x else x, "%.1f%%")


def build(dirpath):
    drafts, seasons = {}, defaultdict(list)
    for name in sorted(os.listdir(dirpath)):
        if not name.endswith(".json") or name[:2] not in ("d_", "s_"):
            continue
        d = load(os.path.join(dirpath, name))
        k = key_of(d)
        if name.startswith("d_"):
            drafts[k] = draft_metrics(d["leagues"])
        else:
            seasons[k].append(d)
    for k, shards in list(seasons.items()):
        if k not in drafts:
            drafts[k] = draft_metrics([lg for s in shards for lg in s["leagues"]])
    sm = {k: season_metrics(v) for k, v in seasons.items()}
    rows = [(v, p, label) for v, p, label in ORDER if (v, p) in drafts or (v, p) in sm]

    md = "## Preseason spread (draft sweep)\n\n"
    md += "Mean over leagues of the across-club SD (and max - min) of each measure. "
    md += "Leagues: number of drafts (distinct = distinct sets of 18 lists).\n\n"
    md += "| Model | Leagues (distinct) | Sel-22 OVR SD | OVR spread | Squad.strength SD | Strength spread | Contest SD | Attack SD | Defence SD | r(OVR, strength) |\n"
    md += "|---|---|---|---|---|---|---|---|---|---|\n"
    for v, p, label in rows:
        m = drafts.get((v, p))
        if not m:
            continue
        md += "| %s | %d (%d) | %s | %s | %s | %s | %s | %s | %s | %s |\n" % (
            label, m["n"], m["distinct"], f(m["ovr22_sd"]), f(m["ovr22_rng"]),
            f(m["strength_sd"]), f(m["strength_rng"]), f(m["contest_sd"]),
            f(m["attack_sd"]), f(m["defence_sd"]), f(m["r_ovr_str"]))
    md += "\n### Line (unit) spreads\n\nAcross-club SD of each Squad line aggregate (the engine's inputs), mean over leagues.\n\n"
    md += "| Model | " + " | ".join(SUBUNITS) + " |\n|---|" + "---|" * len(SUBUNITS) + "\n"
    for v, p, label in rows:
        m = drafts.get((v, p))
        if m:
            md += "| %s | %s |\n" % (label, " | ".join(f(m[s + "_sd"]) for s in SUBUNITS))
    md += "\n### List construction (believability)\n\n"
    md += "Role counts on the 37-man list, over every club in every league (min / mean / max). "
    md += "Outside real = share of clubs whose count in any role falls outside the range the real 2026 lists span (RUCK 2-4, MID 12-24, DEF 7-14, FWD 4-9; the dataset has few primary forwards, so every model averages 6.8). "
    md += "Top-5 OVR SD = spread of each club's five best players. Spend SD = spread of list value.\n\n"
    md += "| Model | RUCK | MID | DEF | FWD | Outside real | List-mean OVR SD | Top-5 OVR SD | Top-5 spread | Spend SD |\n|---|---|---|---|---|---|---|---|---|---|\n"
    for v, p, label in rows:
        m = drafts.get((v, p))
        if not m:
            continue
        rr = ["%d / %.1f / %d" % m["role_" + r] for r in ["RUCK", "MID", "DEF", "FWD"]]
        md += "| %s | %s | %s | %s | %s | %s | %s |\n" % (label, " | ".join(rr), pct(m["short_lines"]),
                                              f(m["list_ovr_sd"]), f(m["top5_ovr_sd"]),
                                              f(m["top5_ovr_rng"]), f(m["value_sd"], "%.0f"))

    md += "\n## Match outcomes (unchanged MatchSim)\n\n"
    md += "Stronger side = higher preseason Squad.strength (home-and-away matches, draw = half). "
    md += "Skill share and skill SD from replaying the same lists with new season seeds "
    md += "(± = standard error across leagues; a league with one draft seed is one labelling of clubs to fixture and venues). "
    md += "r = mean per-season correlation with wins. Premier top-3 = share of premierships won by a "
    md += "top-3-strength club; spoon bottom-3 likewise; top-5 finals = how often a top-5-strength club "
    md += "makes the top %d. Distinct premiers = distinct premier clubs / seasons within a league.\n\n" % FINALISTS
    md += "| Model | Seasons (leagues) | Stronger side wins | Higher-OVR side wins | Skill share | Skill SD (wins) | r(strength, wins) | r(OVR, wins) | Premier top-3 | Mean premier rank | Spoon bottom-3 | Top-5 make finals | Distinct premiers | 60+ margins |\n"
    md += "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
    for v, p, label in rows:
        m = sm.get((v, p))
        if not m:
            continue
        md += "| %s | %d (%d) | %s (%s-%s) | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n" % (
            label, m["seasons"], m["leagues"], pct(m["fav"]), f(m["fav_ci"][0] * 100, "%.1f"),
            f(m["fav_ci"][1] * 100, "%.1f"), pct(m["fav_ovr"]),
            pct(m["skill_share"]) + ("" if m["share_se"] != m["share_se"] else " ±" + f(m["share_se"] * 100, "%.0f")),
            f(m["skill_sd"]), f(m["r_str"]), f(m["r_ovr"]), pct(m["prem_top3"]),
            f(m["prem_rank"], "%.1f"), pct(m["spoon_bot3"]), pct(m["fin_top5"]),
            pct(m["distinct_prem"]), pct(m["m60"]))

    e = explain(sm) if sm else None
    if e and e["n"] > 0:
        md += "\n## What the preseason measures explain (question D)\n\n"
        md += ("Every drafted league pooled (%d club-leagues), centred within league. y = the club's mean "
               "wins over its replayed seasons (mostly skill). R^2 of an OLS fit:\n\n") % e["n"]
        md += "| Predictor | R^2 |\n|---|---|\n"
        md += "| Selected-22 mean OVR | %s |\n" % f(e["ovr22"], "%.3f")
        md += "| Squad.strength | %s |\n" % f(e["strength"], "%.3f")
        md += "| Contest, attack, defence (3 lines) | %s |\n" % f(e["units3"], "%.3f")
        md += "| The %d line aggregates | %s |\n" % (len(SUBUNITS), f(e["sub"], "%.3f"))
        md += "| OVR + the line aggregates | %s |\n" % f(e["ovr_plus_sub"], "%.3f")
        md += "| *Ceiling: share of the target's variance that is skill, not luck* | *%s* |\n\n" % f(e["ceiling"], "%.3f")

    md += "## Real AFL benchmark (final home-and-away ladders)\n\n"
    md += "Luck = coin-flip binomial SD for the season length (an upper bound on luck). Skill = observed variance net of luck.\n\n"
    md += "| Season | Games | SD of wins | Luck SD | Noll-Scully | Skill SD | Skill share |\n|---|---|---|---|---|---|---|\n"
    tv, tl = [], []
    for y, g, sdw, lsd, var, luck in afl_benchmark():
        skill = max(0.0, var - luck)
        tv.append(var)
        tl.append(luck)
        md += "| %s | %.0f | %.2f | %.2f | %.2f | %.2f | %s |\n" % (y, g, sdw, lsd, sdw / lsd, math.sqrt(skill), pct(skill / var))
    v, l = mean(tv), mean(tl)
    md += "| **Pooled** | | %.2f | %.2f | %.2f | %.2f | %s |\n\n" % (math.sqrt(v), math.sqrt(l), math.sqrt(v / l), math.sqrt(v - l), pct(1 - l / v))
    return md


def main():
    args = sys.argv[1:]
    md = build(args[0])
    print(md)
    if "--md" in args:
        with open(args[args.index("--md") + 1], "w") as fh:
            fh.write(md)


if __name__ == "__main__":
    main()
