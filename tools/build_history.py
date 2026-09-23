#!/usr/bin/env python3
"""
Build data/player_history_2026.csv: every 2026 player's draft pedigree and
his rating in each recent AFL season, for the potential (POT) model.

Sources
-------
* AFL Tables season pages (afltables.com/afl/stats/<year>.html) for
  2021-2025 season totals, plus 2026 to link each player on our list to his
  AFL Tables page slug (stable across clubs and name changes).
* Wikipedia "<year> AFL draft" pages (raw wikitext) for the
  national, rookie, pre-season and mid-season drafts 2006-2025.

Each past season is rated with the same model as 2026 (tools/sim_harness.py
derive_ratings, the Python mirror of Ratings.gd, including the key position
stretch), against that season's own player pool, so a 2024 rating means the
same as a 2026 one.

Output columns: club,num,slug,draft_year,draft_type,draft_pick,seasons
  seasons = "2023:84:22;2024:86:23" (year:overall:games), 8+ game seasons.

Usage
-----
    python3 tools/build_history.py              # fetch (cached) and write
    python3 tools/build_history.py --offline    # cache only, no network

Pages are cached in data/cache/ (git-ignored). Wikipedia rate-limits shared
addresses hard, so fetches back off patiently and every page is cached.
Stdlib only.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
CACHE = os.path.join(DATA, "cache")
OUT = os.path.join(DATA, "player_history_2026.csv")
sys.path.insert(0, os.path.join(ROOT, "tools"))

import sim_harness as H  # noqa: E402  (ratings mirror)
from scrape_afltables import SLUG_TO_CODE  # noqa: E402

SEASONS = [2021, 2022, 2023, 2024, 2025]
DRAFT_YEARS = list(range(2006, 2026))
MIN_SEASON_GAMES = 8
UA = "AFLAutoBattler/1.0 (https://github.com/gabebartolo-spec/Afl-auto-battler; data tool)"

# AFL Tables column header -> our stat key.
HEADER_KEYS = {
    "GM": "gm", "KI": "ki", "MK": "mk", "HB": "hb", "DI": "di", "GL": "gl",
    "BH": "bh", "HO": "ho", "TK": "tk", "RB": "rb", "IF": "if50", "CL": "cl",
    "CG": "cg", "FF": "ff", "FA": "fa", "BR": "br", "CP": "cp", "UP": "up",
    "CM": "cm", "MI": "mi", "1%": "onepct", "BO": "bo", "GA": "ga", "%P": "pctp",
}
TABLE_RE = re.compile(r"<table[^>]*>(.*?)</table>", re.S | re.I)
ROW_RE = re.compile(r"<tr[^>]*>(.*?)</tr>", re.S | re.I)
CELL_RE = re.compile(r"<t[dh][^>]*>(.*?)(?=<t[dh]|</tr>|$)", re.S | re.I)
CLUB_RE = re.compile(r'href="[^"]*teams/([a-z]+)_idx\.html"', re.I)
PLAYER_RE = re.compile(r'href="[^"]*players/[A-Z]/([^".]+)\.html"', re.I)

WIKI_CLUBS = {
    "ade": "ADE", "bl": "BRL", "bri": "BRL", "car": "CAR", "col": "COL",
    "ess": "ESS", "fre": "FRE", "gee": "GEE", "gc": "GCS", "gcs": "GCS",
    "gws": "GWS", "haw": "HAW", "mel": "MEL", "nm": "NTH", "pa": "PAD",
    "ric": "RIC", "stk": "SKN", "syd": "SYD", "wc": "WCE", "wb": "WBD",
}


# ---------------------------------------------------------------------------
# Fetching
# ---------------------------------------------------------------------------
def fetch(url: str, cache_name: str, offline: bool, patience: int = 12) -> str | None:
    path = os.path.join(CACHE, cache_name)
    if os.path.exists(path) and os.path.getsize(path) > 1000:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    if offline:
        return None
    os.makedirs(CACHE, exist_ok=True)
    wait = 5.0
    for attempt in range(patience):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as resp:
                body = resp.read().decode("utf-8", errors="replace")
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(body)
            time.sleep(1.5)
            return body
        except urllib.error.HTTPError as err:
            if err.code not in (429, 503):
                print(f"  {url}: HTTP {err.code}", file=sys.stderr)
                return None
        except Exception as err:  # network hiccup
            print(f"  {url}: {err}", file=sys.stderr)
        print(f"  rate-limited, waiting {wait:.0f}s ({cache_name})", file=sys.stderr)
        time.sleep(wait)
        wait = min(wait * 1.6, 120.0)
    return None


# ---------------------------------------------------------------------------
# AFL Tables seasons
# ---------------------------------------------------------------------------
def _text(cell: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", cell)).strip()


def _num(cell: str) -> float:
    t = _text(cell).replace("\xa0", "")
    try:
        return float(t)
    except ValueError:
        return 0.0


def parse_season(body: str) -> list[dict]:
    """Rows of {club, num, first, last, slug, <stat keys>} for one season.
    Columns are read by header name, so the DA and SU columns are ignored."""
    out = []
    for table in TABLE_RE.findall(body):
        club_m = CLUB_RE.search(table)
        if not club_m:
            continue
        code = SLUG_TO_CODE.get(club_m.group(1).lower()) or {
            "padelaide": "PAD", "kangaroos": "NTH", "gws": "GWS",
            "goldcoast": "GCS", "brisbanel": "BRL"}.get(club_m.group(1).lower())
        if not code:
            continue
        cols = None
        for row in ROW_RE.findall(table):
            cells = CELL_RE.findall(row)
            labels = [_text(c) for c in cells]
            if "GM" in labels and "Player" in labels:
                cols = labels
                continue
            if cols is None:
                continue
            pm = PLAYER_RE.search(row)
            if not pm or len(cells) < len(cols) - 2:
                continue
            num = _text(cells[0])
            if not num.isdigit():
                continue
            name = _text(cells[1])
            last, _, first = name.partition(",")
            p = {"club": code, "num": int(num), "first": first.strip(),
                 "last": last.strip(), "slug": pm.group(1)}
            for i, label in enumerate(cols):
                key = HEADER_KEYS.get(label)
                if key and i < len(cells):
                    p[key] = _num(cells[i])
            for key in HEADER_KEYS.values():
                p.setdefault(key, 0.0)
            out.append(p)
    return out


def merge_by_slug(rows: list[dict]) -> list[dict]:
    """A player traded mid-season appears once per club: sum his counts."""
    by = {}
    for r in rows:
        s = r["slug"]
        if s not in by:
            by[s] = dict(r)
            continue
        m = by[s]
        g0, g1 = m["gm"], r["gm"]
        for key in HEADER_KEYS.values():
            if key == "pctp":
                m[key] = (m[key] * g0 + r[key] * g1) / max(1.0, g0 + g1)
            else:
                m[key] += r[key]
    return list(by.values())


def rate_season(rows: list[dict]) -> dict:
    """slug -> (overall, games) using the game's rating model on that pool."""
    players = []
    for r in rows:
        if r["gm"] <= 0:
            continue
        p = {"club": r["club"], "num": r["num"], "name": r["first"] + " " + r["last"],
             "surname": r["last"], "id": r["slug"]}
        for k in H.STAT_KEYS:
            p[k] = float(r.get(k, 0.0))
        players.append(p)
    H.derive_ratings(players)
    return {p["id"]: (int(p["overall"]), int(p["gm"])) for p in players}


# ---------------------------------------------------------------------------
# Wikipedia drafts
# ---------------------------------------------------------------------------
HEADING_RE = re.compile(r"^(=+)\s*(.*?)\s*=+\s*$", re.M)
SORTNAME_RE = re.compile(r"\{\{\s*sortname\s*\|([^|}]*)\|([^|}]*)", re.I)
LINK_RE = re.compile(r"\[\[(?:[^|\]]*\|)?([^\]]+)\]\]")
PICK_RE = re.compile(r"^\|\s*(?:[^|\n]*\|)?\s*(\d{1,3})\s*$")
WCLUB_RE = re.compile(r"\{\{\s*AFL\s*\|?\s*([A-Za-z]+)\s*\}\}")


def _draft_type(heading: str) -> str | None:
    h = heading.lower()
    if "national draft" in h:
        return "national"
    if "pre-season draft" in h or "preseason draft" in h:
        return "preseason"
    if "mid-season" in h or "midseason" in h:
        return "midseason"
    if "rookie draft" in h:
        return "rookie"
    return None


def parse_drafts(wikitext: str, year: int) -> list[dict]:
    out = []
    spans = [(m.start(), m.group(2)) for m in HEADING_RE.finditer(wikitext)]
    spans.append((len(wikitext), ""))
    for (start, heading), (end, _) in zip(spans, spans[1:]):
        kind = _draft_type(heading)
        if kind is None:
            continue
        section = wikitext[start:end]
        for row in re.split(r"\n\|-", section):
            lines = [ln.strip() for ln in row.split("\n") if ln.strip()]
            pick = None
            pick_at = -1
            first = last = None
            name_at = -1
            for i, ln in enumerate(lines):
                sm = SORTNAME_RE.search(ln)
                if sm:
                    first, last = sm.group(1).strip(), sm.group(2).strip()
                    name_at = i
                    break
                # Older pages link the player plainly on the line after the
                # pick: |bgcolor="..."|[[Jake Stringer]]
                if pick is not None and i == pick_at + 1 and "[[" in ln:
                    lm = LINK_RE.search(ln)
                    if lm:
                        display = re.sub(r"\s*\(.*?\)", "", lm.group(1)).strip()
                        bits = display.split(" ", 1)
                        if len(bits) == 2:
                            first, last = bits[0], bits[1]
                            name_at = i
                            break
                pm = PICK_RE.match(ln)
                if pm:
                    pick = int(pm.group(1))
                    pick_at = i
            if first is None or pick is None:
                continue
            club = ""
            for ln in lines[name_at + 1:name_at + 5]:
                cm = WCLUB_RE.search(ln)
                if cm:
                    club = WIKI_CLUBS.get(cm.group(1).lower(), "")
                    break
            out.append({"year": year, "type": kind, "pick": pick,
                        "first": first, "last": last, "club": club})
    return out


# ---------------------------------------------------------------------------
# Matching
# ---------------------------------------------------------------------------
def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z]", "", s.lower())


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--offline", action="store_true", help="use cached pages only")
    args = ap.parse_args()

    # Our 2026 list, with the enriched bio (dob / debut) for disambiguation.
    ours = list(csv.DictReader(open(os.path.join(DATA, "players_enriched_2026.csv"),
                                    encoding="utf-8")))

    # 1. AFL Tables: link our players to slugs via the 2026 page.
    body = fetch("https://afltables.com/afl/stats/2026.html", "afltables_2026.html", args.offline)
    if body is None:
        print("no 2026 page", file=sys.stderr)
        return 1
    rows26 = parse_season(body)
    by_club_num = {(r["club"], r["num"]): r for r in rows26}
    by_name = {}
    for r in rows26:
        by_name.setdefault((r["club"], norm(r["last"])), []).append(r)
    slug_of = {}
    unmatched = []
    for p in ours:
        key = (p["club"], int(p["num"]))
        r = by_club_num.get(key)
        if r is None or norm(r["last"]) != norm(p["last"]):
            cands = by_name.get((p["club"], norm(p["last"])), [])
            cands = [c for c in cands if norm(c["first"])[:3] == norm(p["first"])[:3]] or cands
            r = cands[0] if len(cands) == 1 else None
        if r is None:
            unmatched.append("%s %s %s" % (p["club"], p["first"], p["last"]))
            continue
        slug_of[key] = r["slug"]
    print(f"AFL Tables: linked {len(slug_of)}/{len(ours)} players to their pages")
    if unmatched:
        print("  unlinked: " + ", ".join(unmatched[:20]))

    # 2. Rate each past season.
    history = {}  # slug -> [(year, overall, games)]
    for year in SEASONS:
        body = fetch(f"https://afltables.com/afl/stats/{year}.html",
                     f"afltables_{year}.html", args.offline)
        if body is None:
            print(f"  {year}: page unavailable, skipped", file=sys.stderr)
            continue
        rows = merge_by_slug(parse_season(body))
        rated = rate_season(rows)
        for slug, (ov, gm) in rated.items():
            if gm >= MIN_SEASON_GAMES:
                history.setdefault(slug, []).append((year, ov, gm))
        print(f"  {year}: rated {len(rated)} players")

    # 3. Wikipedia drafts.
    picks = []
    missing_years = []
    for year in DRAFT_YEARS:
        # Older runs cached the MediaWiki API's JSON; reuse it if present.
        cached_json = os.path.join(CACHE, f"wiki_{year}.json")
        text = None
        if os.path.exists(cached_json):
            try:
                with open(cached_json, encoding="utf-8") as fh:
                    text = json.load(fh)["parse"]["wikitext"]
            except (ValueError, KeyError):
                text = None
        if text is None:
            # The raw wikitext endpoint is CDN-cached and far less throttled
            # than the parse API.
            raw_url = ("https://en.wikipedia.org/w/index.php?action=raw&title="
                       + urllib.parse.quote(f"{year} AFL draft"))
            text = fetch(raw_url, f"wiki_{year}.txt", args.offline)
        if not text:
            missing_years.append(year)
            continue
        picks += parse_drafts(text, year)
    print(f"Wikipedia: {len(picks)} draft selections from "
          f"{len(DRAFT_YEARS) - len(missing_years)} draft years")
    if missing_years:
        print(f"  missing draft years (re-run later): {missing_years}")

    # A national pick outranks a rookie listing for the same player (a
    # rookie later taken in the national draft, or re-drafted).
    rank = {"national": 0, "preseason": 1, "midseason": 2, "rookie": 3}
    by_pname = {}
    for d in picks:
        by_pname.setdefault((norm(d["first"]), norm(d["last"])), []).append(d)

    rows_out = []
    drafted = 0
    for p in ours:
        key = (p["club"], int(p["num"]))
        slug = slug_of.get(key, "")
        dob_year = int(p["dob"][:4]) if p.get("dob") else 0
        debut = p.get("debut", "")
        debut_year = int(debut[-4:]) if len(debut) >= 4 and debut[-4:].isdigit() else 2026
        cands = by_pname.get((norm(p["first"]), norm(p["last"])), [])
        # Same name, different player: the draft must fall between age 16
        # and the debut season.
        cands = [d for d in cands
                 if (dob_year == 0 or d["year"] >= dob_year + 16)
                 and d["year"] <= max(debut_year, 2025)]
        cands.sort(key=lambda d: (rank[d["type"]], -d["year"]))
        best = cands[0] if cands else None
        if best:
            drafted += 1
        seasons = sorted(history.get(slug, []))
        rows_out.append({
            "club": p["club"], "num": p["num"], "slug": slug,
            "draft_year": best["year"] if best else "",
            "draft_type": best["type"] if best else "",
            "draft_pick": best["pick"] if best else "",
            "seasons": ";".join("%d:%d:%d" % s for s in seasons),
        })
    print(f"Draft pedigree found for {drafted}/{len(ours)} players "
          "(the rest: category B, SSP, international or older drafts)")

    with open(OUT, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["club", "num", "slug", "draft_year",
                                           "draft_type", "draft_pick", "seasons"])
        w.writeheader()
        w.writerows(rows_out)
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
