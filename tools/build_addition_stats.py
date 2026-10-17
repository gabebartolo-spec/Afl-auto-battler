#!/usr/bin/env python3
"""
Build data/list_additions_stats.csv: senior numbers for the 2026 list
additions (data/list_additions_2026.csv) who have played AFL before, so GameDB
rates them from their record the way it rates every listed player, not as
draft prospects.

Each addition is matched by name to AFL Tables season pages (2025 back to
2021, via tools/scrape_afltables.py). His most recent season of MIN_GAMES or
more is used; if he never reached it, his most recent season with any game.
Output columns are players_2026.csv's (club,num,last,first,gm..pctp,src) with
src = the season used. Anyone with no AFL game in those years is left out and
stays a prospect.

    python3 tools/build_addition_stats.py            # fetch (cached) and write
"""
import csv
import time
import urllib.request
import re
import os
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import scrape_afltables as S  # noqa: E402

YEARS = [2025, 2024, 2023, 2022, 2021]
MIN_GAMES = 6
ALIASES = {"thomas": "tom", "nicholas": "nic", "nick": "nic", "joshua": "josh", "samuel": "sam", "matthew": "matt"}


ROW_LINK_RE = re.compile(r'href="players/[A-Z]/[^"]+"')
# AFL Tables' season page columns after "#" and "Player" (DA is the disposal average).
PAGE_COLS = ["gm", "ki", "mk", "hb", "di", "da", "gl", "bh", "ho", "tk", "rb", "if50", "cl", "cg", "ff",
             "fa", "br", "cp", "up", "cm", "mi", "onepct", "bo", "ga", "pctp"]


class Season:
    def __init__(self, first, last, stats, src, href=""):
        self.first, self.last, self.stats, self.src, self.href = first, last, stats, src, href
        self.games = stats["gm"]

    def as_row(self):
        row = ["", "0", self.last, self.first]
        for col in S.STAT_COLS:
            v = self.stats.get(col, 0.0)
            row.append("%.1f" % v if col == "pctp" else str(int(round(v))))
        row.append(str(self.src))
        return row


MONTHS = {m: i + 1 for i, m in enumerate("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split())}
_born = {}


def born(href):
    """His date of birth (ISO) from his AFL Tables page, cached."""
    if href in _born:
        return _born[href]
    path = os.path.join(S.CACHE_DIR, "players_" + href.replace("/", "_"))
    if os.path.exists(path):
        body = open(path, encoding="utf-8", errors="replace").read()
    else:
        req = urllib.request.Request("https://afltables.com/afl/stats/" + href, headers={"User-Agent": S.USER_AGENT})
        body = urllib.request.urlopen(req, timeout=60).read().decode("latin1")
        open(path, "w", encoding="utf-8").write(body)
        time.sleep(0.5)
    body = S.TAG_RE.sub(" ", body)
    m = re.search(r"Born:\s*(\d+)-(\w{3})-(\d{4})", body)
    iso = "%s-%02d-%02d" % (m.group(3), MONTHS[m.group(2)], int(m.group(1))) if m else ""
    _born[href] = iso
    return iso


def norm(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return "".join(c for c in s if c.isalpha())


def first_norm(f):
    f = norm(f)
    return ALIASES.get(f, f)


def main():
    seasons = {}
    for y in YEARS:
        body = S.fetch(y, True)
        idx = {}
        n = 0
        for row in S.ROW_RE.findall(body):
            m = ROW_LINK_RE.search(row)
            if not m:
                continue
            cells = S.CELL_RE.findall(row)
            if len(cells) < 2 + len(PAGE_COLS) or not S.clean(cells[0]).isdigit():
                continue
            last, first = S.split_name(cells[1])
            stats = {c: S.to_number(cells[2 + i]) for i, c in enumerate(PAGE_COLS)}
            idx.setdefault((first_norm(first), norm(last)), []).append(Season(first, last, stats, y, ROW_LINK_RE.search(row).group(0)[6:-1]))
            n += 1
        print("  %d: %d rows" % (y, n), file=sys.stderr)
        seasons[y] = idx
    adds = list(csv.DictReader(open(os.path.join(ROOT, "data", "list_additions_2026.csv"), encoding="utf-8")))
    out = []
    for a in adds:
        key = (first_norm(a["first"]), norm(a["last"]))
        best = None
        for y in YEARS:
            hits = [h for h in seasons[y].get(key, []) if born(h.href)[:4] == a["dob"][:4]]
            if hits and hits[0].games >= MIN_GAMES:
                best = hits[0]
                break
            if hits and best is None:
                best = hits[0]
        if best is None:
            print("NOGAME", a["club"], a["first"], a["last"], a["dob"], file=sys.stderr)
            continue
        row = best.as_row()
        row[0] = a["club"]
        row[2] = a["last"]
        row[3] = a["first"]
        out.append(row)
        print("RATED", a["club"], a["first"], a["last"], "src", best.src, "gm", int(best.games), file=sys.stderr)
    path = os.path.join(ROOT, "data", "list_additions_stats.csv")
    with open(path, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(S.FIELDS)
        w.writerows(out)
    print("wrote", len(out), "of", len(adds))


main()
