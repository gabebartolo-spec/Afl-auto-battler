#!/usr/bin/env python3
"""Builds tools/balance/afl_trade_volume.json: real AFL trade volume per trade
period, 2019 to 2025, from DraftGuru's per-year trade pages
(https://www.draftguru.com.au/trades/year/<year>).

  python tools/balance/build_trade_volume.py

Each trade is one header row on the page; each club row lists what that club
received, joined by " + ". An item starting with "#" is a draft pick (a pick
already used shows the player taken in brackets, which is not a player moved);
anything else is a player. Counted per year:
  total_trades, player_trades (at least one player), pick_only_trades,
  players_moved, clubs_in_a_trade.
The year is DraftGuru's label for the trade period. Player-initiated moves
(a trade request: going home, more opportunity, out of contract) are not on
these pages and no single source states them per year, so that field is null
rather than guessed.
"""
import html
import json
import os
import re
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "tools", "balance", "afl_trade_volume.json")
YEARS = range(2019, 2026)


def fetch(year: int) -> str:
    url = f"https://www.draftguru.com.au/trades/year/{year}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (data check)"})
    return urllib.request.urlopen(req, timeout=30).read().decode("utf8", "ignore")


def count(page: str) -> dict:
    body = page[page.index('<table class="all-trades">'):]
    trades = re.split(r'<tr class="trade-header', body)[1:]
    clubs = set()
    player_trades = players = 0
    for t in trades:
        n = 0
        for club, desc in re.findall(r'<td class="club-name">(.*?)</td>\s*<td class="description">(.*?)</td>', t, re.S):
            clubs.add(html.unescape(club).strip())
            d = re.sub(r'<span class="extra">.*?</span>', "", desc, flags=re.S)
            d = html.unescape(d).replace("\xa0", " ")
            n += sum(1 for item in d.split(" + ") if item.strip() and not item.strip().startswith("#"))
        players += n
        player_trades += 1 if n else 0
    return {"total_trades": len(trades), "player_trades": player_trades,
            "pick_only_trades": len(trades) - player_trades, "players_moved": players,
            "clubs_in_a_trade": len(clubs), "player_initiated": None}


def main() -> None:
    years = {}
    for y in YEARS:
        years[str(y)] = count(fetch(y))
        time.sleep(2)
    doc = {
        "_about": "Real AFL trade volume per trade period, counted from DraftGuru's per-year trade pages by tools/balance/build_trade_volume.py. player_trades = trades that moved at least one player; pick_only_trades = the rest. players_moved counts players, not draft picks. player_initiated (trade requests: going home, opportunity, out of contract) is null: it is not stated per year on these pages or by one source, so it is not guessed.",
        "sources": ["https://www.draftguru.com.au/trades/year/" + str(y) for y in YEARS],
        "years": years,
    }
    with open(OUT, "w", encoding="utf8", newline="\n") as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
