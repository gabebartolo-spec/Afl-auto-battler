#!/usr/bin/env python3
"""Intercept possessions by position from Wheelo Ratings' Champion Data download
(docs/research/wheelo/afl_player_stats_<year>.json, fetched 2026-10-06).

    python tools/balance/intercept_by_position.py [year ...]

Prints the markdown tables used in docs/research/INTERCEPT_EVIDENCE.md. The
fields are per-game averages; players under MIN_GAMES are left out of the
averages. Weights are games played, so a 20-game season counts for more than a 10.
"""
import json
import os
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MIN_GAMES = 10
ORDER = ["Key Defender", "Gen. Defender", "Midfielder", "Mid-Forward", "Gen. Forward", "Key Forward", "Ruck"]


def load(year):
    path = os.path.join(ROOT, "docs", "research", "wheelo", f"afl_player_stats_{year}.json")
    with open(path, encoding="utf-8") as f:
        d = json.load(f)["Data"]
    keys = list(d)
    n = len(d["PlayerId"])
    return [{k: d[k][i] for k in keys} for i in range(n)]


def wmean(rows, key):
    w = sum(r["Matches"] for r in rows)
    return sum((r[key] or 0) * r["Matches"] for r in rows) / w


def pct(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(p * len(xs)))]


def report(year):
    rows = [r for r in load(year) if (r["Matches"] or 0) >= MIN_GAMES]
    print(f"### {year} ({len(rows)} players with {MIN_GAMES}+ games)\n")
    total_int = sum((r["Intercepts"] or 0) * r["Matches"] for r in rows)
    print("| Position | Players | Intercepts a game (average) | Median | Top 10% | Best | Intercept marks a game | Share of all intercepts |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|")
    for pos in ORDER:
        g = [r for r in rows if r["Position"] == pos]
        if not g:
            continue
        vals = [r["Intercepts"] or 0 for r in g]
        share = sum((r["Intercepts"] or 0) * r["Matches"] for r in g) / total_int
        print(f"| {pos} | {len(g)} | {wmean(g, 'Intercepts'):.1f} | {statistics.median(vals):.1f} | {pct(vals, 0.9):.1f} | {max(vals):.1f} | {wmean(g, 'InterceptMarks'):.2f} | {share:.0%} |")
    print("\nWhere each position wins its possessions (all possessions, not intercepts; share of the position's possessions):\n")
    print("| Position | Own defensive 50 | Defensive midfield | Attacking midfield | Forward 50 | Intercepts per 100 possessions |")
    print("|---|---:|---:|---:|---:|---:|")
    for pos in ORDER:
        g = [r for r in rows if r["Position"] == pos]
        if not g:
            continue
        z = [wmean(g, k) for k in ("Defensive50Possessions", "DefensiveMidfieldPossessions", "AttackingMidfieldPossessions", "Forward50Possessions")]
        s = sum(z)
        print(f"| {pos} | " + " | ".join(f"{v / s:.0%}" for v in z) + f" | {100 * wmean(g, 'Intercepts') / wmean(g, 'TotalPossessions'):.0f} |")
    print("\nTop ten interceptors:\n")
    print("| Player | Club | Position | Games | Intercepts a game |")
    print("|---|---|---|---:|---:|")
    for r in sorted(rows, key=lambda r: -(r["Intercepts"] or 0))[:10]:
        print(f"| {r['Player']} | {r['Team']} | {r['Position']} | {r['Matches']} | {r['Intercepts']:.1f} |")
    print()


if __name__ == "__main__":
    for y in (sys.argv[1:] or ["2025", "2026"]):
        report(y)
