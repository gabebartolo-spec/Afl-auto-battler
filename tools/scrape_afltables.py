#!/usr/bin/env python3
"""
Scrape per-player season stats from AFL Tables and emit data/players_2026.csv
in the exact schema the game's GameDB autoload expects.

Why this exists
---------------
The shipped CSV is hand-harvested from afltables.com/afl/stats/2026.html. That
page only gives 2026 numbers. The design rule is:

    If a player played < MIN_GAMES games in 2026, use their 2025 season stats
    instead (provenance recorded in the `src` column).

Roughly a third of every list falls under that threshold (debutants, late
injuries, VFL-level depth), so the 2025 backfill has to be done by machine.
Run this script and it rebuilds the CSV with the rule applied to every player.

Usage
-----
    python3 tools/scrape_afltables.py                 # fetch live, write CSV
    python3 tools/scrape_afltables.py --dry-run       # fetch, report, don't write
    python3 tools/scrape_afltables.py --from-cache    # reuse data/cache/*.html
    python3 tools/scrape_afltables.py --min-games 6   # change the threshold

No third-party dependencies: stdlib urllib + regex only.
"""

from __future__ import annotations

import argparse
import csv
import html
import os
import re
import sys
import time
import urllib.request
from typing import Dict, List, Optional, Tuple

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "data")
CACHE_DIR = os.path.join(DATA_DIR, "cache")
OUT_CSV = os.path.join(DATA_DIR, "players_2026.csv")

BASE = "https://afltables.com/afl/stats/{year}.html"
PRIMARY_YEAR = 2026
FALLBACK_YEAR = 2025
MIN_GAMES = 6
USER_AGENT = (
    "Mozilla/5.0 (compatible; AflAutoBattler/1.0; "
    "+https://github.com/gabebartolo-spec/Afl-auto-battler)"
)

# CSV schema. Order matters -- GameDB.gd reads columns positionally.
FIELDS = [
    "club", "num", "last", "first", "gm", "ki", "mk", "hb", "di",
    "gl", "bh", "ho", "tk", "rb", "if50", "cl", "cg", "ff", "fa",
    "br", "cp", "up", "cm", "mi", "onepct", "bo", "ga", "pctp", "src",
]

# Numeric columns as they appear on afltables, after "#" and "Player".
# DA (disposal average) is intentionally dropped: it is derived from DI/GM.
STAT_COLS = [
    "gm", "ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "rb",
    "if50", "cl", "cg", "ff", "fa", "br", "cp", "up", "cm", "mi",
    "onepct", "bo", "ga", "pctp",
]

# afltables club slug -> our club code (matches data/clubs.csv)
SLUG_TO_CODE = {
    "adelaide": "ADE",
    "brisbane": "BRL",
    "carlton": "CAR",
    "collingwood": "COL",
    "essendon": "ESS",
    "fremantle": "FRE",
    "geelong": "GEE",
    "goldcoast": "GCS",
    "gws": "GWS",
    "giants": "GWS",
    "gwsydney": "GWS",
    "hawthorn": "HAW",
    "melbourne": "MEL",
    "kangaroos": "NTH",
    "northmelbourne": "NTH",
    "padelaide": "PAD",
    "portadelaide": "PAD",
    "richmond": "RIC",
    "stkilda": "SKN",
    "st.kilda": "SKN",
    "sydney": "SYD",
    "swans": "SYD",
    "southmelbourne": "SYD",
    "westcoast": "WCE",
    "west": "WCE",
    "bullldogs": "WBD",
    "bulldogs": "WBD",
    "westernbulldogs": "WBD",
    "footscray": "WBD",
}

CLUB_ORDER = [
    "ADE", "BRL", "CAR", "COL", "ESS", "FRE", "GEE", "GCS", "GWS",
    "HAW", "MEL", "NTH", "PAD", "RIC", "SKN", "SYD", "WCE", "WBD",
]

# afltables renders some surnames with punctuation stripped from the anchor
# text ("DAmbrosio, Massimo", "OHalloran, Xavier"). Keep them as-is so the
# CSV stays stable; the game never matches on names.

CLUB_LINK_RE = re.compile(
    r'href="[^"]*?/afl/teams/([A-Za-z_.]+)_idx\.html"', re.IGNORECASE
)
PLAYER_LINK_RE = re.compile(
    r'href="([^"]*?/afl/stats/players/[^"]+)"[^>]*>(.*?)</a>',
    re.IGNORECASE | re.DOTALL,
)
ROW_RE = re.compile(r"<tr[^>]*>(.*?)</tr>", re.IGNORECASE | re.DOTALL)
CELL_RE = re.compile(r"<t[dh][^>]*>(.*?)</t[dh]>", re.IGNORECASE | re.DOTALL)
TAG_RE = re.compile(r"<[^>]+>")


class Player:
    """One player-season of stats."""

    __slots__ = ("club", "num", "last", "first", "slug", "stats", "src")

    def __init__(self, club: str, num: str, last: str, first: str,
                 slug: str, stats: Dict[str, float], src: int):
        self.club = club
        self.num = num
        self.last = last
        self.first = first
        self.slug = slug
        self.stats = stats
        self.src = src

    @property
    def key(self) -> str:
        """Stable identity across seasons (slug is unique per person)."""
        return self.slug or f"{self.last},{self.first}".lower()

    @property
    def games(self) -> float:
        return self.stats.get("gm", 0.0)

    def as_row(self) -> List[str]:
        row = [self.club, self.num, self.last, self.first]
        for col in STAT_COLS:
            v = self.stats.get(col, 0.0)
            if col == "pctp":
                row.append(f"{v:.1f}")
            else:
                row.append(str(int(round(v))))
        row.append(str(self.src))
        return row


def clean(cell: str) -> str:
    """Strip tags/entities/whitespace from one HTML cell."""
    txt = TAG_RE.sub(" ", cell)
    txt = html.unescape(txt)
    return re.sub(r"\s+", " ", txt).strip()


def to_number(cell: str) -> float:
    """AFL Tables leaves cells blank for zero. '1%' and '%P' come through plain."""
    txt = clean(cell).replace(",", "").replace("%", "").strip()
    if txt in ("", "-", "\u00a0"):
        return 0.0
    try:
        return float(txt)
    except ValueError:
        return 0.0


def split_name(raw: str) -> Tuple[str, str]:
    """'Impey, Jarman' -> ('Impey', 'Jarman'). Tolerates 'Jarman Impey' too."""
    name = clean(raw)
    if "," in name:
        last, _, first = name.partition(",")
        return last.strip(), first.strip()
    parts = name.split()
    if len(parts) >= 2:
        return parts[-1], " ".join(parts[:-1])
    return name, ""


def fetch(year: int, use_cache: bool) -> str:
    """Return the raw HTML for one season page, caching to data/cache/."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, f"{year}.html")
    if use_cache and os.path.exists(path):
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            print(f"  cache hit: {path}", file=sys.stderr)
            return fh.read()

    url = BASE.format(year=year)
    print(f"  fetching {url}", file=sys.stderr)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = resp.read().decode("utf-8", errors="replace")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(body)
    return body


def parse_season(body: str, year: int) -> Dict[str, List[Player]]:
    """
    Walk the page in document order. Every club section is introduced by a
    link to /afl/teams/<slug>_idx.html; every player row contains a link to
    /afl/stats/players/<L>/<Name>.html. Tracking "most recent club link" is
    enough to bucket rows, and it is robust to table nesting.
    """
    by_club: Dict[str, List[Player]] = {c: [] for c in CLUB_ORDER}
    current: Optional[str] = None
    pos = 0
    n_rows = 0

    # Merge club links and player links into one ordered token stream.
    tokens: List[Tuple[int, str, re.Match]] = []
    for m in CLUB_LINK_RE.finditer(body):
        tokens.append((m.start(), "club", m))
    for m in PLAYER_LINK_RE.finditer(body):
        tokens.append((m.start(), "player", m))
    tokens.sort(key=lambda t: t[0])

    # For each player link we need its enclosing <tr> to read the stat cells.
    rows = [(m.start(), m.end(), m.group(0)) for m in ROW_RE.finditer(body)]

    for _, kind, m in tokens:
        if kind == "club":
            slug = re.sub(r"[^a-z]", "", m.group(1).lower())
            code = SLUG_TO_CODE.get(slug)
            if code:
                current = code
            continue

        if current is None:
            continue

        href, label = m.group(1), m.group(2)
        # The club header row itself links to a "Players G..." index page;
        # player rows link into /stats/players/. Guard both ways.
        if "/stats/players/" not in href:
            continue

        link_at = m.start()
        row_html = None
        for rstart, rend, rhtml in rows[pos:]:
            if rstart > link_at:
                break
            if rstart <= link_at < rend:
                row_html = rhtml
                break
        if row_html is None:
            continue

        cells = [c for c in CELL_RE.findall(row_html)]
        if len(cells) < 5:
            continue

        # Cell 0 = guernsey number, cell 1 = player name, then the stats.
        num = clean(cells[0])
        if not num.isdigit():
            continue  # header row or a totals row
        last, first = split_name(cells[1])

        vals = cells[2:]
        if len(vals) < len(STAT_COLS):
            # Trailing sub/blank columns can be missing on short rows.
            vals = vals + [""] * (len(STAT_COLS) - len(vals))
        stats = {col: to_number(vals[i]) for i, col in enumerate(STAT_COLS)}

        slug = os.path.splitext(os.path.basename(href))[0]
        by_club[current].append(
            Player(current, num, last, first, slug, stats, year)
        )
        n_rows += 1

    print(f"  {year}: parsed {n_rows} player rows", file=sys.stderr)
    return by_club


def merge(primary: Dict[str, List[Player]],
          fallback: Dict[str, List[Player]],
          min_games: int) -> Tuple[List[Player], Dict[str, int]]:
    """
    Roster = the PRIMARY_YEAR list (that is who the club actually fielded).
    Stats  = PRIMARY_YEAR row, unless games < min_games and the player has a
             FALLBACK_YEAR row, in which case the fallback row wins and
             src is set to FALLBACK_YEAR.
    """
    fb_by_key: Dict[str, Player] = {}
    for club_players in fallback.values():
        for p in club_players:
            # Later clubs overwrite earlier ones; a player only appears once
            # per season in practice, and we want their 2025 numbers wherever
            # they played them (trades are common between seasons).
            fb_by_key[p.key] = p

    out: List[Player] = []
    stats_out = {"kept": 0, "backfilled": 0, "no_fallback": 0}

    for code in CLUB_ORDER:
        for p in primary.get(code, []):
            if p.games >= min_games:
                p.src = PRIMARY_YEAR
                stats_out["kept"] += 1
                out.append(p)
                continue

            alt = fb_by_key.get(p.key)
            if alt is not None and alt.games >= p.games:
                merged = Player(p.club, p.num, p.last, p.first, p.slug,
                                dict(alt.stats), FALLBACK_YEAR)
                out.append(merged)
                stats_out["backfilled"] += 1
            else:
                # Rookie with no prior AFL season -- keep the thin 2026 line.
                p.src = PRIMARY_YEAR
                out.append(p)
                stats_out["no_fallback"] += 1

    return out, stats_out


def write_csv(players: List[Player], path: str = OUT_CSV) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(FIELDS)
        for p in players:
            w.writerow(p.as_row())


def report(players: List[Player]) -> None:
    counts: Dict[str, int] = {}
    srcs: Dict[str, int] = {}
    for p in players:
        counts[p.club] = counts.get(p.club, 0) + 1
        srcs[str(p.src)] = srcs.get(str(p.src), 0) + 1
    print("\nPlayers per club:")
    for code in CLUB_ORDER:
        print(f"  {code}: {counts.get(code, 0):>3}")
    print(f"  TOTAL: {len(players)}")
    print("\nProvenance (src column):")
    for s in sorted(srcs):
        print(f"  {s}: {srcs[s]}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--min-games", type=int, default=MIN_GAMES,
                    help=f"2026 games below which 2025 stats are used "
                         f"(default {MIN_GAMES})")
    ap.add_argument("--dry-run", action="store_true",
                    help="report only; do not overwrite the CSV")
    ap.add_argument("--from-cache", action="store_true",
                    help="reuse data/cache/<year>.html if present")
    ap.add_argument("--out", default=OUT_CSV, help="output CSV path")
    args = ap.parse_args()

    print("Scraping AFL Tables...", file=sys.stderr)
    primary_body = fetch(PRIMARY_YEAR, args.from_cache)
    time.sleep(1.0)  # be polite
    fallback_body = fetch(FALLBACK_YEAR, args.from_cache)

    primary = parse_season(primary_body, PRIMARY_YEAR)
    fallback = parse_season(fallback_body, FALLBACK_YEAR)

    players, merge_stats = merge(primary, fallback, args.min_games)
    if not players:
        print("ERROR: parsed zero players. Page layout may have changed; "
              "inspect data/cache/%d.html." % PRIMARY_YEAR, file=sys.stderr)
        return 1

    report(players)
    print("\nMerge summary:")
    print(f"  used {PRIMARY_YEAR} stats : {merge_stats['kept']}")
    print(f"  backfilled from {FALLBACK_YEAR}: {merge_stats['backfilled']}")
    print(f"  thin, no prior season  : {merge_stats['no_fallback']}")

    if args.dry_run:
        print("\n--dry-run: CSV not written.")
        return 0

    write_csv(players, args.out)
    print(f"\nWrote {len(players)} players to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
