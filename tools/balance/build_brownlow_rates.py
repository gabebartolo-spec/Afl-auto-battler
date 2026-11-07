#!/usr/bin/env python3
"""Real Brownlow, tackle and pressure references, written to tools/balance/afl_brownlow.json.

What the Brownlow audit (tools/audit/brownlow_impl.gd + brownlow_report.py) and the balance
report set the game against. Sources, all free and public:

  - AFL Tables season stats pages, 2015-2026 (afltables.com/afl/stats/<year>.html, fetched and
    cached by tools/scrape_afltables.py into data/cache/<year>.html): games (GM), Brownlow votes
    (BR), tackles (TK) and hit-outs (HO) per player. The season totals include finals; BR counts
    home-and-away games only, as the medal does.
  - AFL Tables match pages, 2023-2025 (afltables.com/afl/stats/games/<year>/<id>.html, listed on
    afltables.com/afl/seas/<year>.html, cached in data/cache/seas and data/cache/games): every
    player's line in every match, with the umpires' 3-2-1 votes that match (BR).
  - Champion Data per-player season averages for 2025 and 2026 as Wheelo serves them
    (docs/research/wheelo/afl_player_stats_<year>.json): position, pressure acts, tackles and the
    AFL Coaches Association votes. AFL Tables has no positions, so the split by position (MID,
    FWD, DEF, RUCK) is given for 2025 and 2026 only; every season gets the ruck split by the
    game's hit-out gate (7+ hit-outs a game, Ratings.derive_all).

Per season:
  - tallies: winner, 2nd, 3rd, 5th and 10th; players who polled, polled 10+ and 20+;
  - vote share: rucks (hit-out gate) for every season; MID / FWD / DEF / RUCK for 2025-26
    (Champion Data position; Mid-Forward counts as a forward, as build_spoil_zones.py has it;
    anyone over the hit-out gate is a ruck);
  - tackles a game per player (players with 12+ games): max, p99, p90, p50, by role;
  - pressure acts a game per player and coaches' votes share by position (2025-26).
The 2020 season was 17 rounds of 16-minute quarters: it is flagged and left out of the pooled
reference ranges.

From the match pages (2023-2025 home-and-away):
  - per player-game tackles (p50 / p90 / p99 / max) and each side's top tackler a match;
  - the share of votes that go to the winning side;
  - vote_fit: a Plackett-Luce fit of the umpires' 3-2-1 order on each player's match line, the
    terms CoachReport.influence uses. The weights are per unit of the stat, scaled so a disposal
    is 1.0 (the influence scale). Pressure acts are not on AFL Tables match lines, so they get no
    fitted weight. "replay" re-votes every real match deterministically (top three by the fitted
    weights) and reports the winning tallies that gives, against the real ones.

    python tools/balance/build_brownlow_rates.py            # fetch what is missing, then build
    python tools/balance/build_brownlow_rates.py --offline  # cached pages only
"""
from __future__ import annotations

import argparse
import html
import json
import math
import os
import re
import statistics
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import scrape_afltables as sa  # noqa: E402

CACHE = os.path.join(ROOT, "data", "cache")
OUT = os.path.join(HERE, "afl_brownlow.json")
SEASONS = list(range(2015, 2027))
MATCH_SEASONS = [2023, 2024, 2025]
SHORT_SEASONS = {2020: "17 rounds of 16-minute quarters (COVID)"}
RUCK_GATE = 7.0          # hit-outs a game: the game's ruck gate (Ratings.derive_all)
MIN_GAMES = 12           # per-player rate distributions
CD_ROLE = {"Midfielder": "MID", "Mid-Forward": "FWD", "Gen. Forward": "FWD", "Key Forward": "FWD",
           "Gen. Defender": "DEF", "Key Defender": "DEF", "Ruck": "RUCK"}
WHEELO_TEAM = {"Adelaide": "ADE", "Brisbane Lions": "BRL", "Brisbane": "BRL", "Carlton": "CAR",
               "Collingwood": "COL", "Essendon": "ESS", "Fremantle": "FRE", "Geelong": "GEE",
               "Geelong Cats": "GEE", "Gold Coast": "GCS", "Gold Coast Suns": "GCS",
               "Greater Western Sydney": "GWS", "GWS Giants": "GWS", "Hawthorn": "HAW",
               "Melbourne": "MEL", "North Melbourne": "NTH", "Port Adelaide": "PAD",
               "Richmond": "RIC", "St Kilda": "STK", "Sydney": "SYD", "Sydney Swans": "SYD",
               "West Coast": "WCE", "West Coast Eagles": "WCE", "Western Bulldogs": "WBD"}
# Match-line columns on an AFL Tables game page, after # and Player.
GAME_COLS = ["ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "rb", "if50", "cl", "cg", "ff", "fa",
             "br", "cp", "up", "cm", "mi", "onepct", "bo", "ga", "pctp"]
# CoachReport.influence terms (sim stat key -> AFL Tables column). Pressure acts have no column.
FIT_TERMS = [("disposals", "di"), ("goals", "gl"), ("marks", "mk"), ("inside50", "if50"),
             ("tackles", "tk"), ("hitouts", "ho"), ("clearances", "cl"),
             ("one_percenters", "onepct"), ("clangers", "cg")]
# A wider fit, reported for reference only (not what the game uses).
WIDE_EXTRA = [("contested_possessions", "cp"), ("behinds", "bh"), ("goal_assists", "ga"),
              ("rebounds", "rb"), ("frees_for", "ff"), ("frees_against", "fa"),
              ("contested_marks", "cm")]


# ---------------------------------------------------------------------------
# Fetching (cached; one request a second)
# ---------------------------------------------------------------------------
def _get(url: str, path: str, offline: bool) -> str | None:
    if os.path.exists(path):
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    if offline:
        return None
    os.makedirs(os.path.dirname(path), exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": sa.USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = resp.read().decode("utf-8", errors="replace")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(body)
    time.sleep(1.0)
    return body


def season_page(year: int, offline: bool) -> str | None:
    return _get(sa.BASE.format(year=year), os.path.join(CACHE, f"{year}.html"), offline)


def game_pages(year: int, offline: bool) -> list[str]:
    seas = _get(f"https://afltables.com/afl/seas/{year}.html",
                os.path.join(CACHE, "seas", f"{year}.html"), offline)
    if seas is None:
        return []
    ids = sorted(set(re.findall(r"stats/games/%d/(\d+)\.html" % year, seas)))
    out = []
    for gid in ids:
        body = _get(f"https://afltables.com/afl/stats/games/{year}/{gid}.html",
                    os.path.join(CACHE, "games", str(year), f"{gid}.html"), offline)
        if body:
            out.append(body)
    return out


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------
TABLE_RE = re.compile(r"<table[^>]*>(.*?)</table>", re.I | re.S)


def parse_game(body: str) -> dict | None:
    """{round, teams: [{name, score, players: [{name, stats}]}]} or None for a page without two
    match-statistics tables."""
    m = re.search(r"Round:\s*</b>\s*([^<&]+)|Round:\s*([^<&]+)", body)
    rnd = (m.group(1) or m.group(2)).strip() if m else ""
    teams = []
    for t in TABLE_RE.findall(body):
        head = sa.clean(t[:600])
        if "Match Statistics" not in head:
            continue
        name = head.split(" Match Statistics")[0].strip()
        players = []
        gl = bh = 0.0
        for row in sa.ROW_RE.findall(t):
            cells = sa.CELL_RE.findall(row)
            if len(cells) < 4:
                continue
            label = sa.clean(cells[1]) if len(cells) > 1 else ""
            first = sa.clean(cells[0])
            if first == "Totals":
                vals = [sa.to_number(c) for c in cells[1:]]
                gl, bh = vals[4], vals[5]
                continue
            if "/players/" not in row:
                continue
            vals = cells[2:] + [""] * max(0, len(GAME_COLS) - len(cells[2:]))
            st = {k: sa.to_number(vals[i]) for i, k in enumerate(GAME_COLS)}
            players.append({"name": label, "stats": st})
        teams.append({"name": name, "score": gl * 6 + bh, "players": players})
    if len(teams) != 2:
        return None
    return {"round": rnd, "teams": teams}


SEASON_COL = {"GM": "gm", "KI": "ki", "MK": "mk", "HB": "hb", "DI": "di", "GL": "gl", "BH": "bh",
              "HO": "ho", "TK": "tk", "RB": "rb", "IF": "if50", "CL": "cl", "CG": "cg", "FF": "ff",
              "FA": "fa", "BR": "br", "CP": "cp", "UP": "up", "CM": "cm", "MI": "mi", "1%": "onepct",
              "BO": "bo", "GA": "ga", "%P": "pctp"}
CLUB_SLUG = dict(sa.SLUG_TO_CODE, brisbanel="BRL")


class SeasonRow:
    __slots__ = ("club", "first", "last", "stats")

    def __init__(self, club: str, first: str, last: str, stats: dict):
        self.club, self.first, self.last, self.stats = club, first, last, stats


def parse_season_page(body: str) -> list[SeasonRow]:
    """Every player row of an AFL Tables season stats page, columns read from each club
    table's own header (the page carries DA and SU columns the game's scraper does not)."""
    out = []
    for t in TABLE_RE.findall(body):
        m = re.search(r"teams/([A-Za-z_.]+)_idx\.html", t[:1500])
        if not m:
            continue
        club = CLUB_SLUG.get(re.sub(r"[^a-z]", "", m.group(1).lower()))
        if club is None:
            continue
        cols = None
        for row in sa.ROW_RE.findall(t):
            cells = sa.CELL_RE.findall(row)
            names = [sa.clean(c) for c in cells]
            if "GM" in names and "TK" in names:
                cols = names
                continue
            if cols is None or "players/" not in row or len(cells) < len(cols) - 2:
                continue
            last, first = sa.split_name(cells[1])
            st = {SEASON_COL[n]: sa.to_number(cells[i]) for i, n in enumerate(cols)
                  if n in SEASON_COL and i < len(cells)}
            out.append(SeasonRow(club, first, last, st))
    return out


def norm(s: str) -> str:
    return re.sub(r"[^a-z]", "", s.lower())


def pct(vals: list[float], q: float) -> float:
    s = sorted(vals)
    if not s:
        return 0.0
    i = q * (len(s) - 1)
    lo = int(math.floor(i))
    hi = min(len(s) - 1, lo + 1)
    return s[lo] + (s[hi] - s[lo]) * (i - lo)


def dist(vals: list[float]) -> dict:
    nd = 4 if vals and max(abs(v) for v in vals) <= 1.0 else 2
    return {"n": len(vals), "max": round(max(vals), nd) if vals else 0.0,
            "p99": round(pct(vals, 0.99), nd), "p90": round(pct(vals, 0.90), nd),
            "p50": round(pct(vals, 0.50), nd), "min": round(min(vals), nd) if vals else 0.0,
            "mean": round(statistics.mean(vals), nd) if vals else 0.0,
            "sd": round(statistics.pstdev(vals), nd) if vals else 0.0}


def num(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def wheelo(year: int) -> list[dict]:
    path = os.path.join(ROOT, "docs", "research", "wheelo", f"afl_player_stats_{year}.json")
    if not os.path.exists(path):
        return []
    d = json.load(open(path, encoding="utf-8"))["Data"]
    return [{k: d[k][i] for k in d} for i in range(len(d["Player"]))]


def cd_lookup(rows: list[dict]) -> dict:
    """(club, normalised full name) and (club, normalised last name) -> Wheelo row."""
    full, last = {}, {}
    for r in rows:
        club = WHEELO_TEAM.get(str(r.get("Team", "")), "")
        name = str(r.get("Player", ""))
        full[(club, norm(name))] = r
        parts = name.split()
        if parts:
            last.setdefault((club, norm(parts[-1])), []).append(r)
    return {"full": full, "last": last}


def cd_row(look: dict, club: str, first: str, lastn: str) -> dict | None:
    r = look["full"].get((club, norm(first + lastn)))
    if r is None:
        cands = look["last"].get((club, norm(lastn)), [])
        if len(cands) == 1:
            r = cands[0]
        else:
            for c in cands:
                if norm(str(c["Player"])).startswith(norm(first)[:3]):
                    r = c
                    break
    return r


# ---------------------------------------------------------------------------
# Season pages: tallies, shares, per-player rates
# ---------------------------------------------------------------------------
def season_block(year: int, offline: bool) -> dict | None:
    body = season_page(year, offline)
    if body is None:
        return None
    rows = parse_season_page(body)
    if not rows:
        return None
    look = cd_lookup(wheelo(year)) if year in (2025, 2026) else None
    votes = sorted((p.stats["br"] for p in rows), reverse=True)
    total = sum(votes)
    tallies = {"winner": votes[0], "2nd": votes[1], "3rd": votes[2], "5th": votes[4], "10th": votes[9]}
    top10 = [{"name": f"{p.first} {p.last}", "club": p.club, "votes": int(p.stats["br"]),
              "games": int(p.stats["gm"]), "hitouts_pg": round(p.stats["ho"] / max(1, p.stats["gm"]), 1)}
             for p in sorted(rows, key=lambda p: -p.stats["br"])[:10]]
    ruck_votes = 0.0
    by_role = {"MID": 0.0, "FWD": 0.0, "DEF": 0.0, "RUCK": 0.0}
    coaches = {"MID": 0.0, "FWD": 0.0, "DEF": 0.0, "RUCK": 0.0}
    matched = unmatched = 0
    tk = {"ALL": [], "RUCK": [], "MID": [], "FWD": [], "DEF": []}
    pa = {"ALL": [], "RUCK": [], "MID": [], "FWD": [], "DEF": []}
    top_tacklers = []
    for p in rows:
        gm = p.stats["gm"]
        ruck = gm > 0 and p.stats["ho"] / gm >= RUCK_GATE
        if ruck:
            ruck_votes += p.stats["br"]
        role = "RUCK" if ruck else ""
        cd = None
        if look is not None:
            cd = cd_row(look, p.club, p.first, p.last)
            if cd is None:
                unmatched += 1
            else:
                matched += 1
                if not role:
                    role = CD_ROLE.get(str(cd.get("Position", "")), "MID")
                    if role == "RUCK":
                        role = "FWD"   # a listed ruck under the gate plays forward
                by_role[role] += p.stats["br"]
                coaches[role] += num(cd.get("CoachesVotes_Total"))
        if gm >= MIN_GAMES:
            r = p.stats["tk"] / gm
            tk["ALL"].append(r)
            top_tacklers.append((r, f"{p.first} {p.last}", p.club))
            if ruck:
                tk["RUCK"].append(r)
            elif role:
                tk[role].append(r)
            if cd is not None and num(cd.get("Matches")) >= MIN_GAMES:
                v = num(cd.get("PressureActs"))
                pa["ALL"].append(v)
                pa["RUCK" if ruck else role].append(v)
    out = {
        "games_each": int(max(p.stats["gm"] for p in rows)),
        "total_votes": int(total),
        "tallies": tallies,
        "top10": top10,
        "polled": sum(1 for v in votes if v > 0),
        "polled_10": sum(1 for v in votes if v >= 10),
        "polled_20": sum(1 for v in votes if v >= 20),
        "ruck_share": round(ruck_votes / total, 4) if total else 0.0,
        "tackles_pg": {k: dist(v) for k, v in tk.items() if v},
        "top_tacklers": [{"name": n, "club": c, "tackles_pg": round(r, 2)}
                         for r, n, c in sorted(top_tacklers, reverse=True)[:5]],
    }
    if year in SHORT_SEASONS:
        out["flag"] = SHORT_SEASONS[year]
    if look is not None:
        cv = sum(coaches.values())
        out["role_share"] = {k: round(v / total, 4) for k, v in by_role.items()}
        out["role_share_votes_matched"] = int(sum(by_role.values()))
        out["coaches_role_share"] = {k: round(v / cv, 4) for k, v in coaches.items()} if cv else {}
        out["cd_matched"] = matched
        out["cd_unmatched"] = unmatched
        out["pressure_acts_pg"] = {k: dist(v) for k, v in pa.items() if v}
    return out


# ---------------------------------------------------------------------------
# Match pages: per-game spread, winners' share, the vote fit
# ---------------------------------------------------------------------------
def load_matches(offline: bool) -> list[dict]:
    out = []
    for y in MATCH_SEASONS:
        for body in game_pages(y, offline):
            g = parse_game(body)
            if g is None:
                continue
            votes = sorted(int(pl["stats"]["br"]) for t in g["teams"] for pl in t["players"]
                           if pl["stats"]["br"] > 0)
            g["year"] = y
            g["voted"] = votes == [1, 2, 3]
            out.append(g)
    return out


def match_block(matches: list[dict]) -> dict:
    tk_pg, top_tk = [], []
    win_votes = all_votes = win3 = n3 = 0
    for g in matches:
        if not g["round"].isdigit():
            continue
        for t in g["teams"]:
            tks = [pl["stats"]["tk"] for pl in t["players"] if pl["stats"]["pctp"] >= 50]
            tk_pg.extend(tks)
            if tks:
                top_tk.append(max(tks))
        if not g["voted"]:
            continue
        a, b = g["teams"]
        if a["score"] == b["score"]:
            continue
        w = 0 if a["score"] > b["score"] else 1
        for side, t in enumerate(g["teams"]):
            for pl in t["players"]:
                v = int(pl["stats"]["br"])
                all_votes += v
                if side == w:
                    win_votes += v
                    win3 += 1 if v == 3 else 0
                n3 += 1 if v == 3 else 0
    by_season = {}
    for y in MATCH_SEASONS:
        pg, top = [], []
        for g in matches:
            if g["year"] != y or not g["round"].isdigit():
                continue
            for t in g["teams"]:
                tks = [pl["stats"]["tk"] for pl in t["players"] if pl["stats"]["pctp"] >= 50]
                pg.extend(tks)
                if tks:
                    top.append(max(tks))
        if top:
            by_season[str(y)] = {"top_tackler_mean": round(statistics.mean(top), 2),
                                 "top_tackler_p90": pct(top, 0.9), "top_tackler_max": max(top),
                                 "player_game_p99": pct(pg, 0.99), "player_game_p90": pct(pg, 0.9),
                                 "player_game_max": max(pg)}
    return {"seasons": MATCH_SEASONS,
            "by_season": by_season,
            "matches": sum(1 for g in matches if g["round"].isdigit()),
            "voted_matches": sum(1 for g in matches if g["voted"]),
            "tackles_player_game": dist(tk_pg),
            "top_tackler_match": dist(top_tk),
            "winners_vote_share": round(win_votes / all_votes, 4) if all_votes else 0.0,
            "winners_3vote_share": round(win3 / n3, 4) if n3 else 0.0}


def _features(matches: list[dict], terms: list[tuple[str, str]], won: bool) -> list[list]:
    """One entry per voted, decided match: [rows, i3, i2, i1], each row the raw term values."""
    out = []
    for g in matches:
        if not g["voted"] or not g["round"].isdigit():
            continue
        a, b = g["teams"]
        rows, idx = [], {}
        for side, t in enumerate(g["teams"]):
            win = 1.0 if (a["score"] > b["score"]) == (side == 0) and a["score"] != b["score"] else 0.0
            for pl in t["players"]:
                x = [pl["stats"][c] for _, c in terms] + ([win] if won else [])
                v = int(pl["stats"]["br"])
                if v:
                    idx[v] = len(rows)
                rows.append(x)
        out.append([rows, idx[3], idx[2], idx[1]])
    return out


def fit_pl(data: list[list], k: int, iters: int = 20) -> list[float]:
    """Plackett-Luce for the top three, by Newton's method on standardised terms. Returns the
    weight per raw unit of each term."""
    flat = [x for rows, *_ in data for x in rows]
    mu = [statistics.mean(x[j] for x in flat) for j in range(k)]
    sd = [statistics.pstdev([x[j] for x in flat]) or 1.0 for j in range(k)]
    z = [([[(x[j] - mu[j]) / sd[j] for j in range(k)] for x in rows], (i3, i2, i1))
         for rows, i3, i2, i1 in data]
    pairs = [(j, l) for j in range(k) for l in range(j, k)]
    beta = [0.0] * k
    for _ in range(iters):
        g = [0.0] * k
        h = [0.0] * len(pairs)
        for rows, picks in z:
            s = [math.exp(sum(beta[j] * r[j] for j in range(k))) for r in rows]
            s0 = sum(s)
            s1 = [sum(s[i] * rows[i][j] for i in range(len(rows))) for j in range(k)]
            s2 = [sum(s[i] * rows[i][j] * rows[i][l] for i in range(len(rows))) for j, l in pairs]
            for pick in picks:
                r = rows[pick]
                ex = [v / s0 for v in s1]
                for j in range(k):
                    g[j] += r[j] - ex[j]
                for q, (j, l) in enumerate(pairs):
                    h[q] -= s2[q] / s0 - ex[j] * ex[l]
                w = s[pick]
                s0 -= w
                s1 = [s1[j] - w * r[j] for j in range(k)]
                s2 = [s2[q] - w * r[j] * r[l] for q, (j, l) in enumerate(pairs)]
        hm = [[0.0] * k for _ in range(k)]
        for q, (j, l) in enumerate(pairs):
            hm[j][l] = hm[l][j] = h[q]
        for j in range(k):
            hm[j][j] -= 1e-6
        step = _solve(hm, [-v for v in g])
        beta = [beta[j] + step[j] for j in range(k)]
        if max(abs(v) for v in step) < 1e-6:
            break
    return [beta[j] / sd[j] for j in range(k)]


def _solve(a: list[list[float]], b: list[float]) -> list[float]:
    n = len(b)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for c in range(n):
        p = max(range(c, n), key=lambda r: abs(m[r][c]))
        m[c], m[p] = m[p], m[c]
        for r in range(n):
            if r != c and m[c][c]:
                f = m[r][c] / m[c][c]
                for q in range(c, n + 1):
                    m[r][q] -= f * m[c][q]
    return [m[i][n] / m[i][i] for i in range(n)]


def replay(matches: list[dict], terms: list[tuple[str, str]], w: list[float]) -> dict:
    """Re-vote every real match deterministically (top three by the weights): the winning
    tally per season that gives, and how often the real 3-vote player tops the weights."""
    tallies, hit3 = {}, 0
    n = 0
    for g in matches:
        if not g["voted"] or not g["round"].isdigit():
            continue
        n += 1
        rows = []
        for t in g["teams"]:
            for pl in t["players"]:
                sc = sum(w[j] * pl["stats"][c] for j, (_, c) in enumerate(terms))
                rows.append((sc, t["name"] + "|" + pl["name"], int(pl["stats"]["br"])))
        rows.sort(reverse=True)
        hit3 += 1 if rows[0][2] == 3 else 0
        tl = tallies.setdefault(g["year"], {})
        for i in range(3):
            tl[rows[i][1]] = tl.get(rows[i][1], 0) + 3 - i
    out = {"top_pick_is_real_3vote": round(hit3 / max(1, n), 4), "winner_by_season": {}}
    for y, tl in sorted(tallies.items()):
        v = sorted(tl.values(), reverse=True)
        out["winner_by_season"][str(y)] = {"winner": v[0], "10th": v[9],
                                           "polled": len(v)}
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--offline", action="store_true", help="use cached pages only")
    ap.add_argument("--out", default=OUT)
    args = ap.parse_args()
    seasons = {}
    for y in SEASONS:
        b = season_block(y, args.offline)
        if b is not None:
            seasons[str(y)] = b
            print(f"{y}: winner {b['tallies']['winner']:.0f}, polled {b['polled']}, ruck share "
                  f"{100 * b['ruck_share']:.1f}%", file=sys.stderr)
    full = [b for y, b in seasons.items() if int(y) not in SHORT_SEASONS]
    pooled = {
        "seasons": [y for y in seasons if int(y) not in SHORT_SEASONS],
        "winner": dist([b["tallies"]["winner"] for b in full]),
        "2nd": dist([b["tallies"]["2nd"] for b in full]),
        "5th": dist([b["tallies"]["5th"] for b in full]),
        "10th": dist([b["tallies"]["10th"] for b in full]),
        "polled": dist([b["polled"] for b in full]),
        "polled_10": dist([b["polled_10"] for b in full]),
        "polled_20": dist([b["polled_20"] for b in full]),
        "ruck_share": dist([b["ruck_share"] for b in full]),
        "tackles_pg_max": dist([b["tackles_pg"]["ALL"]["max"] for b in full]),
        "tackles_pg_p99": dist([b["tackles_pg"]["ALL"]["p99"] for b in full]),
        "tackles_pg_p90": dist([b["tackles_pg"]["ALL"]["p90"] for b in full]),
        "tackles_pg_p50": dist([b["tackles_pg"]["ALL"]["p50"] for b in full]),
    }
    cd_years = [b for y, b in seasons.items() if "role_share" in b]
    if cd_years:
        pooled["role_share"] = {r: dist([b["role_share"][r] for b in cd_years]) for r in ("MID", "FWD", "DEF", "RUCK")}
        pooled["coaches_role_share"] = {r: dist([b["coaches_role_share"][r] for b in cd_years])
                                        for r in ("MID", "FWD", "DEF", "RUCK")}
        qs = ("max", "p99", "p90", "p50")
        pooled["tackles_pg_by_role"] = {r: {q: dist([b["tackles_pg"][r][q] for b in cd_years]) for q in qs}
                                        for r in ("ALL", "MID", "FWD", "DEF", "RUCK")}
        pooled["pressure_acts_pg_by_role"] = {r: {q: dist([b["pressure_acts_pg"][r][q] for b in cd_years])
                                                  for q in qs} for r in ("ALL", "MID", "FWD", "DEF", "RUCK")}
    matches = load_matches(args.offline)
    print(f"match pages: {len(matches)}", file=sys.stderr)
    mb = match_block(matches) if matches else {}
    if matches:
        k = len(FIT_TERMS)
        data = _features(matches, FIT_TERMS, False)
        w = fit_pl(data, k)
        unit = w[0]
        weights = {name: round(w[j] / unit, 3) for j, (name, _) in enumerate(FIT_TERMS)}
        data_w = _features(matches, FIT_TERMS, True)
        ww = fit_pl(data_w, k + 1)
        wide = FIT_TERMS + WIDE_EXTRA
        wv = fit_pl(_features(matches, wide, False), len(wide))
        mb["vote_fit"] = {
            "model": "Plackett-Luce on the umpires' 3-2-1 order, every voted home-and-away match "
                     "%s; weights per unit of the stat, a disposal = 1.0" % "-".join(map(str, (MATCH_SEASONS[0], MATCH_SEASONS[-1]))),
            "matches": len(data),
            "per_disposal_logit": round(unit, 4),
            "weights": weights,
            "with_result": {"weights": {name: round(ww[j] / ww[0], 3) for j, (name, _) in enumerate(FIT_TERMS)},
                            "won_in_disposals": round(ww[k] / ww[0], 2)},
            "wide": {name: round(wv[j] / wv[0], 3) for j, (name, _) in enumerate(wide)},
            "pressure_acts": "no match-level source; not fitted",
            "replay": replay(matches, FIT_TERMS, [weights[n] for n, _ in FIT_TERMS]),
        }
        print("vote fit:", json.dumps(mb["vote_fit"]["weights"]), file=sys.stderr)
    doc = {
        "source": "AFL Tables season and match pages (afltables.com), Champion Data via Wheelo "
                  "(docs/research/wheelo). Built by tools/balance/build_brownlow_rates.py.",
        "ruck_gate_hitouts_pg": RUCK_GATE,
        "min_games": MIN_GAMES,
        "pooled": pooled,
        "matches": mb,
        "seasons": seasons,
    }
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=1, sort_keys=False)
        fh.write("\n")
    print(f"wrote {args.out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
