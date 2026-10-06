#!/usr/bin/env python3
"""Real 2026 per-team-per-match averages, written to tools/balance/afl_team_rates.json.

A club's match average is the sum of its players' 2026 totals (data/players_2026.csv,
AFL Tables, finals included) divided by the club's games: the most games any of its
players played (home-and-away plus finals). The standings (data/raw/standings_2026.json,
home-and-away only) cross-check goals for clubs that missed the finals.
The league figure is the mean of the club averages; min and max are the lowest and
highest club. Goals and behinds are checked against the standings' own totals.

    python3 tools/balance/build_team_rates.py
"""
import csv, json, os, statistics

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STATS = {"disposals": "di", "kicks": "ki", "handballs": "hb", "marks": "mk",
         "contested_marks": "cm", "tackles": "tk", "inside_50s": "if50",
         "clearances": "cl", "hitouts": "ho", "frees_for": "ff", "goals": "gl",
         "behinds": "bh", "rebound_50s": "rb"}


def main() -> None:
    clubs = {}
    with open(os.path.join(ROOT, "data", "clubs.csv"), encoding="utf-8") as f:
        for r in csv.DictReader(f):
            clubs[r["name"]] = r["code"]
            clubs[r["name"] + " " + r["short"]] = r["code"]
            clubs[r["short"]] = r["code"]
    played = {}
    check = {}
    with open(os.path.join(ROOT, "data", "raw", "standings_2026.json"), encoding="utf-8") as f:
        for r in json.load(f)["standings"]:
            code = clubs.get(r["name"]) or {"Greater Western Sydney": "GWS", "GWS Giants": "GWS", "Sydney Swans": "SYD", "Geelong Cats": "GEE", "Adelaide Crows": "ADE", "Gold Coast Suns": "GCS", "West Coast Eagles": "WCE", "Hawthorn Hawks": "HAW", "Melbourne Demons": "MEL", "Carlton Blues": "CAR", "Essendon Bombers": "ESS", "Fremantle Dockers": "FRE", "Collingwood Magpies": "COL", "Richmond Tigers": "RIC", "St Kilda Saints": "STK", "Port Adelaide Power": "PAD", "North Melbourne Kangaroos": "NTH", "Western Bulldogs": "WBD"}[r["name"]]
            played[code] = int(r["played"])
            check[code] = (int(r["goals_for"]), int(r["behinds_for"]))
    totals = {c: {k: 0 for k in STATS} for c in played}
    games = {c: 0 for c in played}
    with open(os.path.join(ROOT, "data", "players_2026.csv"), encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r["club"] not in totals:
                continue
            games[r["club"]] = max(games[r["club"]], int(r["gm"]))
            for k, col in STATS.items():
                totals[r["club"]][k] += int(r[col] or 0)
    for c, (g, b) in check.items():
        if games[c] == played[c]:
            assert totals[c]["goals"] == g, f"{c} goals differ from the standings"
        else:
            assert totals[c]["goals"] > g, f"{c} finals goals should exceed the standings"
        # Player behinds leave out rushed behinds, so a club's behinds here sit
        # below its team total in the standings.
        assert totals[c]["behinds"] <= b or games[c] > played[c], f"{c} behinds above the standings"
    per_club = {c: {k: totals[c][k] / games[c] for k in STATS} for c in played}
    league = {}
    for k in STATS:
        vals = [per_club[c][k] for c in per_club]
        league[k] = {"mean": round(statistics.mean(vals), 2), "min": round(min(vals), 2),
                     "max": round(max(vals), 2), "sd": round(statistics.pstdev(vals), 2)}
    doc = {
        "source": "data/players_2026.csv (AFL Tables 2026 totals) summed per club (finals included) and divided by the club's games (the most games any of its players played, home-and-away plus finals); for clubs that missed the finals goals match data/raw/standings_2026.json exactly. Behinds are player-credited and leave out rushed behinds (about 2 a game below a team's own total). Per team per match; mean, lowest, highest and spread across the %d clubs. 2025 is not included: no 2025 per-player cache is in the repo. Regenerate with tools/balance/build_team_rates.py." % len(played),
        "clubs": len(played),
        "team_games": sum(games.values()),
        "per_team_match": league,
    }
    with open(os.path.join(ROOT, "tools", "balance", "afl_team_rates.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")
    for k, v in league.items():
        print("%-16s %6.2f  (%.2f-%.2f)" % (k, v["mean"], v["min"], v["max"]))


if __name__ == "__main__":
    main()
