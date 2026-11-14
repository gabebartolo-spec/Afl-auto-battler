#!/usr/bin/env python3
"""
Build the 1990 start's rated lists (Legacy mode, TODO row 142, phase L1).

Inputs (all in data/legacy/, gathered by tools/legacy_<decade>s):
  1990s/lists_1990_opening.csv   every club's real list at the start of 1990
  <decade>s/season_stats.csv     AFL Tables season totals, 1987-2025
  1990s/careers_before_1990.csv  each player's seasons before 1990
  1990s/drafts.csv               draft pedigree (1989 on)
  honours/club_bf.csv            club best-and-fairests, 1987-2025 (Wikipedia)
  honours/all_australian.csv     All-Australian teams: 1987-88 carnivals, 1991 on
  honours/team_of_the_year.csv   the VFL/AFL Team of the Year 1989-90, which the
                                 AFL counts as All-Australian

Outputs (data/legacy/1990/):
  players_1990.csv          players_enriched schema: the opening lists rated on
                            their 1989 season (the data season)
  history_1990.csv          player_history schema: rated 1987-89 seasons,
                            career stints before 1990, draft pedigree, and
                            peak = his best real season from 1989 on (the
                            director's "Informed" potential, 2026-11-11), and
                            honours = his honours score (below)
  list_additions_1990.csv,  listed players with no 1989 game: their latest
  list_addition_stats_1990.csv  season, or none for a new player

Stats the game rates on but that were not recorded before the 2000s (rb,
if50, cl, cg, cp, up, cm, mi, one_pct, bo, ga, pct_played) are estimated
from the recorded ones (director 2026-11-13, "Estimate the gaps"): a least-
squares fit, per game, on 2003-07 (the first full seasons), of each missing
stat on kicks, marks, handballs, goals, behinds, hitouts, tackles and frees.
A season's stat counts as unrecorded when most of its rows are blank; a
blank in a recorded season is zero.

Honours (director 2026-11-13, "Add honours"): the stats miss what made some
players great (Roos, Fitzroy's captain, rated 71), so each honour in the three
seasons before the start scores a point - a club best-and-fairest, an All-
Australian or Team of the Year pick, a Brownlow top 3 (4th-10th score half) -
weighted by how recent (the last season in full, then 0.75, 0.5). The game
lifts an honoured player's rating to a floor on that score (Ratings.HONOURS_*).

Every season is rated against its own season's players (tools/sim_harness.py
derive_ratings, the Python mirror of Ratings.gd), each position scaled on
its own season (fit_era_anchors), so ratings are per era (director
2026-11-10, "A: per era"; 2026-11-13, "Scale each position per season").

    python3 tools/legacy_1990s/build_start.py            # write the files
    python3 tools/legacy_1990s/build_start.py --report   # also the era report
Stdlib only.
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
import zlib
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LEG = os.path.join(ROOT, "data", "legacy")
OUT_DIR = os.path.join(LEG, "1990")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import sim_harness as H  # noqa: E402

DATA_SEASON = 1989
START_DATE = "1990-03-01"
# The historical data's codes for clubs that are one club across eras
# (GameDB.CLUB_CODE_ALIASES).
CODE = {"BRB": "BRL", "FOO": "WBD"}
FEATURES = ["ki", "mk", "hb", "gl", "bh", "ho", "tk", "ff", "fa"]
TARGETS = ["rb", "if50", "cl", "cg", "cp", "up", "cm", "mi", "one_pct", "bo", "ga"]
FIT_YEARS = range(2003, 2008)
PEAK_GAMES = 8
HONOURS_W = {DATA_SEASON: 1.0, DATA_SEASON - 1: 0.75, DATA_SEASON - 2: 0.5}
HONOURS_FILES = ["club_bf.csv", "all_australian.csv", "team_of_the_year.csv"]
ENRICHED = ["club", "num", "last", "first", "gm", "ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "rb",
            "if50", "cl", "cg", "ff", "fa", "br", "cp", "up", "cm", "mi", "onepct", "bo", "ga", "pctp",
            "src", "real_pos", "dob", "age", "height_cm", "weight_kg", "debut", "height_source"]
ADD_STATS = ENRICHED[:29]


def code(c):
    return CODE.get(c, c)


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


# ---------------------------------------------------------------- seasons --
def load_seasons():
    rows = []
    for dec in ("1990s", "2000s", "2010s", "2020s"):
        with open(os.path.join(LEG, dec, "season_stats.csv"), newline="", encoding="utf-8") as fh:
            rows += list(csv.DictReader(fh))
    by_year = defaultdict(list)
    for r in rows:
        by_year[int(r["year"])].append(r)
    return by_year


def unrecorded(year_rows):
    """Stats most of a season's rows leave blank: not kept that season.
    Hitouts are blank for anyone without one, so they are always kept."""
    out = set()
    for k in TARGETS + ["pct_played"]:
        if sum(1 for r in year_rows if r[k] == "") > len(year_rows) * 0.5:
            out.add(k)
    return out


# ---------------------------------------------------------- least squares --
def solve(a, b):
    n = len(b)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for c in range(n):
        piv = max(range(c, n), key=lambda r: abs(m[r][c]))
        m[c], m[piv] = m[piv], m[c]
        if abs(m[c][c]) < 1e-12:
            continue
        for r in range(n):
            if r != c:
                f = m[r][c] / m[c][c]
                for k in range(c, n + 1):
                    m[r][k] -= f * m[c][k]
    return [m[i][n] / m[i][i] if abs(m[i][i]) > 1e-12 else 0.0 for i in range(n)]


def per_game_x(r):
    g = max(1.0, num(r["gm"]) or 0.0)
    return [1.0] + [(num(r[k]) or 0.0) / g for k in FEATURES]


def fit_model(by_year):
    """Coefficients per target (per game), and pct_played (a share)."""
    train = [r for y in FIT_YEARS for r in by_year[y] if (num(r["gm"]) or 0) >= 5]
    model = {}
    for t in TARGETS + ["pct_played"]:
        xs, ys = [], []
        for r in train:
            v = num(r[t])
            if v is None:
                continue
            xs.append(per_game_x(r))
            ys.append(v if t == "pct_played" else v / max(1.0, num(r["gm"])))
        k = len(xs[0])
        ata = [[sum(x[i] * x[j] for x in xs) for j in range(k)] for i in range(k)]
        aty = [sum(x[i] * y for x, y in zip(xs, ys)) for i in range(k)]
        # A light ridge keeps rare features (hitouts) from swinging the fit.
        for i in range(1, k):
            ata[i][i] += 1.0
        model[t] = solve(ata, aty)
    # What the fit leaves unexplained, per stat (estimate adds a seeded draw of
    # it, so estimated stats follow the recorded ones only as loosely as real
    # ones do), and the real spread of each stat (spread_like_real).
    model["_resid"] = {}
    for t in TARGETS + ["pct_played"]:
        res = []
        for r in train:
            v = num(r[t])
            if v is None:
                continue
            y = v if t == "pct_played" else v / max(1.0, num(r["gm"]))
            res.append(y - sum(c * xi for c, xi in zip(model[t], per_game_x(r))))
        model["_resid"][t] = sorted(res)
    model["_dist"] = {}
    for t in TARGETS + ["pct_played"]:
        vals = [num(r[t]) if t == "pct_played" else num(r[t]) / max(1.0, num(r["gm"]))
                for r in train if num(r[t]) is not None]
        model["_dist"][t] = sorted(vals)
    return model


def draw(sorted_vals, r, key):
    """One value from a list, the same for a player's season on every build."""
    h = zlib.crc32(("%s|%s|%s" % (r.get("afltables_id", ""), r.get("year", ""), key)).encode())
    return sorted_vals[h % len(sorted_vals)]


def estimate(r, model, missing):
    """The row with every unrecorded stat estimated, blanks elsewhere 0."""
    out = dict(r)
    g = max(1.0, num(r["gm"]) or 0.0)
    x = per_game_x(r)
    for k in TARGETS + ["pct_played"]:
        if k in missing:
            v = sum(c * xi for c, xi in zip(model[k], x)) + draw(model["_resid"][k], r, k)
            v = max(0.0, v)
            out[k] = min(100.0, v) if k == "pct_played" else v * g
        else:
            out[k] = num(r[k]) or 0.0
    for k in FEATURES + ["gm", "di", "br"]:
        out[k] = num(r[k]) or 0.0
    # Contested and uncontested possessions share the disposals.
    if "cp" in missing or "up" in missing:
        s = out["cp"] + out["up"]
        if s > 0:
            out["cp"], out["up"] = out["cp"] * out["di"] / s, out["up"] * out["di"] / s
    if "pct_played" in missing:
        out["pct_played"] = max(30.0, min(95.0, out["pct_played"]))
    out["_estimated"] = sorted(missing)
    return out


def spread_like_real(est, missing, model):
    """A fit pulls every player toward the average, and ratings scale each
    stat against the season's 98th percentile, so a bunched estimate lifts
    nearly everyone. Keep the fit's order of players, but give each estimated
    stat the spread it really had in the fit years, at the season's own level
    (the fit's mean)."""
    rows = [e for e in est.values() if e["gm"] > 0]
    for k in missing:
        real = model["_dist"][k]
        if not real or not rows:
            continue
        rate = (lambda e: e[k]) if k == "pct_played" else (lambda e: e[k] / e["gm"])
        level = sum(rate(e) for e in rows) / len(rows)
        real_mean = sum(real) / len(real)
        scale = level / real_mean if real_mean else 1.0
        order = sorted(rows, key=rate)
        for i, e in enumerate(order):
            q = real[int(round(i / max(1, len(order) - 1) * (len(real) - 1)))] * scale
            e[k] = min(100.0, q) if k == "pct_played" else q * e["gm"]
    for e in rows:
        if "cp" in missing or "up" in missing:
            s = e["cp"] + e["up"]
            if s > 0:
                e["cp"], e["up"] = e["cp"] * e["di"] / s, e["up"] * e["di"] / s


def harness_player(r, club, num_):
    p = {"club": club, "num": num_, "name": "%s %s" % (r["first"], r["last"]),
         "surname": r["last"], "real_pos": "", "id": "%s_%s" % (club, num_)}
    for k in H.STAT_KEYS:
        src = {"onepct": "one_pct", "pctp": "pct_played"}.get(k, k)
        p[k] = float(r.get(src) or 0.0)
    return p


def rate_seasons(by_year, model):
    """{year: {afltables_id: (overall, games, estimated row, role)}}."""
    rated = {}
    for y in sorted(by_year):
        missing = unrecorded(by_year[y])
        # A player traded mid-season has a row per club: one season, summed.
        merged = {}
        for r in by_year[y]:
            pid = r["afltables_id"]
            if pid in merged:
                m = merged[pid]
                for k in ["gm", "ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "ff", "fa", "br"] + TARGETS:
                    a, b = num(m[k]), num(r[k])
                    m[k] = "" if a is None and b is None else str((a or 0) + (b or 0))
                if "pct_played" not in missing:
                    m["pct_played"] = r["pct_played"] or m["pct_played"]
                m["club"] = r["club"]
            else:
                merged[pid] = dict(r)
        est = {pid: estimate(r, model, missing) for pid, r in merged.items()}
        spread_like_real(est, missing, model)
        players = [harness_player(e, code(e["club"]), i) for i, e in enumerate(est.values())]
        H.ERA_ANCHORS.clear()
        H.derive_ratings(players)
        H.fit_era_anchors(players)
        rated[y] = {pid: (p["overall"], int(e["gm"]), e, p["role"])
                    for (pid, e), p in zip(est.items(), players)}
    return rated


# ---------------------------------------------------------------- honours --
def honours(by_year, rated):
    """{afltables_id: score} over HONOURS_W's seasons. A named honour finds its
    player by the season's own rows: name and club, else a name unique that
    season, else a surname unique at that club (Steve / Stephen Malaxos). An
    honour with no match is printed."""
    def plain(last):
        return "".join(ch for ch in last.lower().replace(" sr.", "").replace(" jr.", "") if ch.isalpha())
    score = defaultdict(float)
    for y, w in HONOURS_W.items():
        by_name = defaultdict(set)
        by_name_club = {}
        by_last_club = defaultdict(set)
        for r in by_year.get(y, []):
            k = (r["first"].strip().lower(), plain(r["last"]))
            by_name[k].add(r["afltables_id"])
            by_name_club[k + (code(r["club"]),)] = r["afltables_id"]
            by_last_club[(k[1], code(r["club"]))].add(r["afltables_id"])
        for fn in HONOURS_FILES:
            with open(os.path.join(LEG, "honours", fn), newline="", encoding="utf-8") as fh:
                for r in csv.DictReader(fh):
                    if int(r["year"]) != y or r["club"] == "OTHER":
                        continue
                    k = (r["first"].strip().lower(), plain(r["last"]))
                    pid = by_name_club.get(k + (code(r["club"]),))
                    if pid is None and len(by_name[k]) == 1:
                        pid = next(iter(by_name[k]))
                    if pid is None and len(by_last_club[(k[1], code(r["club"]))]) == 1:
                        pid = next(iter(by_last_club[(k[1], code(r["club"]))]))
                    if pid is None:
                        print("honours: no %d player for %s %s (%s, %s)" % (y, r["first"], r["last"], r["club"], fn))
                        continue
                    score[pid] += w
        # Brownlow placings on the season's votes (a mid-season move is one season).
        votes = sorted(((float(e[2]["br"] or 0), pid) for pid, e in rated.get(y, {}).items()), reverse=True)
        for v, pid in votes:
            if v <= 0:
                break
            place = 1 + sum(1 for o, _ in votes if o > v)
            if place <= 3:
                score[pid] += w
            elif place <= 10:
                score[pid] += 0.5 * w
    return score


# ------------------------------------------------------------------ lists --
def stints(career_rows):
    """club:first:last:games:goals, oldest first, a stint per unbroken run."""
    out = []
    for r in sorted(career_rows, key=lambda r: int(r["year"])):
        c, y = code(r["club"]), int(r["year"])
        g, gl = int(num(r["games"]) or 0), int(num(r["goals"]) or 0)
        if out and out[-1][0] == c and out[-1][2] == y - 1:
            out[-1][2] = y
            out[-1][3] += g
            out[-1][4] += gl
        else:
            out.append([c, y, y, g, gl])
    return ";".join("%s:%d:%d:%d:%d" % tuple(s) for s in out)


def fmt(v):
    return str(int(round(v)))


def stat_cells(e):
    vals = {}
    for k in ["gm", "ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "rb", "if50", "cl", "cg", "ff", "fa",
              "br", "cp", "up", "cm", "mi", "bo", "ga"]:
        vals[k] = fmt(e[k])
    vals["onepct"] = fmt(e["one_pct"])
    vals["pctp"] = "%.1f" % float(e["pct_played"])
    return vals


def age_at(dob):
    if not dob:
        return ""
    y, m, d = (int(x) for x in dob.split("-"))
    sy, sm, sd = (int(x) for x in START_DATE.split("-"))
    return str(sy - y - ((sm, sd) < (m, d)))


def build(by_year, model, rated):
    hon = honours(by_year, rated)
    with open(os.path.join(LEG, "1990s", "lists_1990_opening.csv"), newline="", encoding="utf-8") as fh:
        lists = list(csv.DictReader(fh))
    with open(os.path.join(LEG, "1990s", "careers_before_1990.csv"), newline="", encoding="utf-8") as fh:
        careers = defaultdict(list)
        for r in csv.DictReader(fh):
            careers[r["afltables_id"]].append(r)
    with open(os.path.join(LEG, "1990s", "drafts.csv"), newline="", encoding="utf-8") as fh:
        drafts = {}
        for r in csv.DictReader(fh):
            if r["draft"] in ("national", "pre_season", "mid_season") and r["pick"] and r["draftguru_id"]:
                drafts.setdefault(r["draftguru_id"], r)

    # A player with no 1990 number (most never played that year) takes a free
    # one from 60 up: the game keys a player on club + number.
    used = defaultdict(set)
    for L in lists:
        if L["num"]:
            used[code(L["club"])].add(int(L["num"]))
    for L in lists:
        if not L["num"]:
            c, n = code(L["club"]), 60
            while n in used[c]:
                n += 1
            used[c].add(n)
            L["num"] = str(n)

    players, history, additions, add_stats = [], [], [], []
    for L in lists:
        club, pid = code(L["club"]), L["afltables_id"]
        row89 = rated.get(DATA_SEASON, {}).get(pid) if pid else None
        seasons = []
        for y in (1987, 1988, 1989):
            got = rated.get(y, {}).get(pid) if pid else None
            if got and got[1] >= PEAK_GAMES:
                seasons.append("%d:%d:%d" % (y, got[0], got[1]))
        peak = 0
        for y in rated:
            if y >= DATA_SEASON and pid:
                got = rated[y].get(pid)
                if got and got[1] >= PEAK_GAMES:
                    peak = max(peak, got[0])
        first_year = min((int(r["year"]) for r in careers.get(pid, [])), default=None)
        debut = "01-04-%d" % first_year if first_year else ""
        d = drafts.get(L["draftguru_id"]) if L["draftguru_id"] else None
        if row89 and row89[1] > 0:
            cells = stat_cells(row89[2])
            players.append(dict(cells, club=club, num=L["num"], last=L["last"], first=L["first"],
                                src=str(DATA_SEASON), real_pos="", dob=L["dob"], age=age_at(L["dob"]),
                                height_cm=L["height_cm"], weight_kg=L["weight_kg"], debut=debut,
                                height_source="draftguru" if L["height_cm"] else ""))
            history.append({"club": club, "num": L["num"], "slug": pid.rsplit("/", 1)[-1].replace(".html", ""),
                            "draft_year": d["year"] if d else "", "draft_type": "national" if d and d["draft"] == "national" else (d["draft"] if d else ""),
                            "draft_pick": d["pick"] if d else "", "seasons": ";".join(seasons),
                            "career": stints(careers.get(pid, [])), "peak": peak or "",
                            "honours": "%.3g" % hon[pid] if hon.get(pid) else ""})
        else:
            additions.append({"first": L["first"], "last": L["last"], "dob": L["dob"], "club": club,
                              "position": "", "height_cm": L["height_cm"], "list": L["list"],
                              "peak": peak or "", "source_url": L["source_url"], "checked": L["checked"]})
            latest = None
            for y in (1988, 1987):
                got = rated.get(y, {}).get(pid) if pid else None
                if got and got[1] > 0:
                    latest = (y, got)
                    break
            if latest:
                cells = stat_cells(latest[1][2])
                add_stats.append(dict(cells, club=club, num="0", last=L["last"], first=L["first"],
                                      src=str(latest[0])))
    fill_heights_by_position(additions, lists, rated)
    return players, history, additions, add_stats


def godot_hash(s):
    """GDScript hash() of a String (Godot's String::hash, djb2 over code points)."""
    v = 5381
    for ch in s:
        v = ((v << 5) + v + ord(ch)) & 0xFFFFFFFF
    return v


def game_role(club, n, height):
    """The position the game gives list addition n (1-based, file order) of a
    club: GameDB._load_list_additions's id and GameDB.listed_role."""
    if height >= 200:
        return "RUCK"
    roll = godot_hash("role|L%d_%s_%03d" % (DATA_SEASON, club, n)) % 100
    if height >= 192:
        return "DEF" if roll < 50 else "FWD"
    if roll < 45:
        return "MID"
    return "DEF" if roll < 72 else "FWD"


def fill_heights_by_position(additions, lists, rated):
    """A listed player whose height neither Draftguru nor AFL Tables records (he
    never played a senior game) takes the average height of the 1990 lists'
    players at the position the game gives him (director 2026-11-13: "if you
    cant find the height for a player anywhere just pick the average for a
    player of his position"). Positions are the 1989 season's rated roles."""
    by_role = defaultdict(list)
    for L in lists:
        got = rated.get(DATA_SEASON, {}).get(L["afltables_id"]) if L["afltables_id"] else None
        if got and got[1] > 0 and L["height_cm"]:
            by_role[got[3]].append(int(L["height_cm"]))
    avg = {r: round(sum(v) / len(v)) for r, v in by_role.items()}
    for n, A in enumerate(additions, 1):
        A["height_from"] = "club list" if A["height_cm"] else ""
        if A["height_cm"]:
            continue
        role = game_role(A["club"], n, 0)
        h = avg[role]
        # The game re-derives his position from the filled height: it must land
        # on the same one.
        assert game_role(A["club"], n, h) == role, (A["first"], A["last"], role, h)
        A["height_cm"] = str(h)
        A["height_from"] = "average %s" % role


def write(path, cols, rows):
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, extrasaction="ignore", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


# ------------------------------------------------------------- era report --
def era_report(by_year, rated, players):
    """Markdown: each decade's per-game averages and rating spread vs 2025."""
    stats = ["di", "ki", "hb", "mk", "tk", "gl", "cl", "cp", "if50", "rb"]
    lines = ["# Era averages against today (Legacy mode, row 142)", "",
             "Built by `tools/legacy_1990s/build_start.py --report`. Per player per game, every player "
             "with a game; * marks a stat estimated from the recorded ones for most of that era. "
             "Ratings are each season against its own players, each position scaled on its own season (director 2026-11-13, 'Scale each position per season').", "",
             "| Seasons | " + " | ".join(stats) + " | rated 80+ per season | median OVR |",
             "|" + "---|" * (len(stats) + 3)]
    for label, years in (("1987-89", range(1987, 1990)), ("1990-99", range(1990, 2000)),
                         ("2000-09", range(2000, 2010)), ("2010-19", range(2010, 2020)),
                         ("2020-25", range(2020, 2026))):
        tot, gm, n80, ovrs, est = defaultdict(float), 0.0, 0, [], set()
        for y in years:
            est |= unrecorded(by_year[y])
            for pid, (ovr, g, e, _role) in rated[y].items():
                gm += g
                for k in stats:
                    tot[k] += e[k]
                if g >= PEAK_GAMES:
                    ovrs.append(ovr)
                    n80 += ovr >= 80
        ovrs.sort()
        cells = ["%.1f%s" % (tot[k] / gm, "*" if k in est else "") for k in stats]
        lines.append("| %s | %s | %.1f | %d |" % (label, " | ".join(cells), n80 / len(list(years)),
                                                  ovrs[len(ovrs) // 2]))
    lines += ["", "## The 1990 lists as the game loads them", "",
              "Rated on 1989 by `tools/sim_harness.py` (the game rates again at load, the same model).", ""]
    hp = []
    for r in players:
        e = {k: float(r[k]) for k in ENRICHED[4:28]}
        p = harness_player({**{("one_pct" if k == "onepct" else "pct_played" if k == "pctp" else k): v
                               for k, v in e.items()}, "first": r["first"], "last": r["last"]},
                           r["club"], r["num"])
        hp.append(p)
    H.ERA_ANCHORS.clear()
    H.derive_ratings(hp)
    H.fit_era_anchors(hp)
    by_club = defaultdict(list)
    for p in hp:
        by_club[p["club"]].append(p["overall"])
    lines.append("| Club | players | median OVR | best | 80+ |")
    lines.append("|---|---|---|---|---|")
    for c in sorted(by_club):
        v = sorted(by_club[c])
        lines.append("| %s | %d | %d | %d | %d |" % (c, len(v), v[len(v) // 2], v[-1], sum(x >= 80 for x in v)))
    top = sorted(hp, key=lambda p: -p["overall"])[:15]
    lines += ["", "Top 15 in 1990: " + ", ".join("%s (%s) %d" % (p["name"], p["club"], p["overall"]) for p in top)]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    by_year = load_seasons()
    model = fit_model(by_year)
    rated = rate_seasons(by_year, model)
    players, history, additions, add_stats = build(by_year, model, rated)
    os.makedirs(OUT_DIR, exist_ok=True)
    write(os.path.join(OUT_DIR, "players_1990.csv"), ENRICHED, players)
    write(os.path.join(OUT_DIR, "history_1990.csv"),
          ["club", "num", "slug", "draft_year", "draft_type", "draft_pick", "seasons", "career", "peak", "honours"], history)
    write(os.path.join(OUT_DIR, "list_additions_1990.csv"),
          ["first", "last", "dob", "club", "position", "height_cm", "height_from", "list", "peak", "source_url",
           "checked"], additions)
    write(os.path.join(OUT_DIR, "list_addition_stats_1990.csv"), ADD_STATS, add_stats)
    print("players %d, additions %d (%d with an earlier season)" % (len(players), len(additions), len(add_stats)))
    if a.report:
        path = os.path.join(ROOT, "docs", "research", "LEGACY_ERA_REPORT.md")
        with open(path, "w", newline="\n", encoding="utf-8") as fh:
            fh.write(era_report(by_year, rated, players))
        print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
