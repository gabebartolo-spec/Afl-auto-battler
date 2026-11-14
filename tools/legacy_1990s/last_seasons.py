"""Write each real player's last AFL season into a Legacy start's files.

Director, 2026-11-13: "make all historical players retirement start roughly
when it did irl (playhers can still convince them to play on with the usual
mechanics)". Prospects.should_retire reads the column (GameDB: real_last).

last_season is the last year he is on an AFL list in
data/legacy/{1990s,2000s,2010s,2020s}/lists.csv (1990-2025). Blank when he is
still listed in the last year the lists cover (he follows the normal sim), or
when he cannot be found. Matched by AFL Tables id, then surname + date of
birth, then first + surname + date of birth.

    python tools/legacy_1990s/last_seasons.py 1990
"""
import csv
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LEGACY = os.path.join(ROOT, "data", "legacy")
DECADES = ["1990s", "2000s", "2010s", "2020s"]


def _norm(s):
    return re.sub(r"[^a-z]", "", (s or "").lower())


def last_years():
    """(by afltables slug, by surname|dob, by first|surname|dob, last year the lists cover)."""
    by_slug, by_dob, by_full = {}, {}, {}
    top = 0
    for dec in DECADES:
        path = os.path.join(LEGACY, dec, "lists.csv")
        if not os.path.exists(path):
            continue
        with open(path, newline="", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                y = int(r["year"])
                top = max(top, y)
                slug = os.path.basename(r.get("afltables_id") or "").replace(".html", "")
                keys = []
                if slug:
                    keys.append((by_slug, slug))
                if r.get("dob"):
                    keys.append((by_dob, "%s|%s" % (_norm(r["last"]), r["dob"])))
                    keys.append((by_full, "%s|%s|%s" % (_norm(r["first"]), _norm(r["last"]), r["dob"])))
                for d, k in keys:
                    d[k] = max(d.get(k, 0), y)
    return by_slug, by_dob, by_full, top


def _slug_from_urls(text):
    m = re.search(r"afltables\.com/afl/stats/players/./([^ |]+?)\.html", text or "")
    return m.group(1) if m else ""


def _write(path, rows, fields):
    if "last_season" not in fields:
        fields = fields + ["last_season"]
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def main(year):
    by_slug, by_dob, by_full, top = last_years()
    folder = os.path.join(LEGACY, str(year))
    players = {}
    with open(os.path.join(folder, "players_%d.csv" % year), newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            players.setdefault("%s_%s" % (r["club"], r["num"]), r)

    def find(slug, first, last, dob):
        hit = by_slug.get(slug, 0) if slug else 0
        if not hit and dob:
            hit = by_dob.get("%s|%s" % (_norm(last), dob), 0) or by_full.get("%s|%s|%s" % (_norm(first), _norm(last), dob), 0)
        if hit < year or hit >= top:
            return ""
        return str(hit)

    stats = {"found": 0, "active": 0, "missing": 0}

    def count(v, matched):
        stats["found" if v else ("active" if matched else "missing")] += 1

    hpath = os.path.join(folder, "history_%d.csv" % year)
    with open(hpath, newline="", encoding="utf-8") as f:
        rd = csv.DictReader(f)
        fields, rows = list(rd.fieldnames), list(rd)
    for r in rows:
        p = players.get("%s_%s" % (r["club"], r["num"]), {})
        v = find(r.get("slug", ""), p.get("first", ""), p.get("last", ""), p.get("dob", ""))
        r["last_season"] = v
        count(v, bool(r.get("slug")) or bool(p.get("dob")))
    _write(hpath, rows, fields)

    apath = os.path.join(folder, "list_additions_%d.csv" % year)
    with open(apath, newline="", encoding="utf-8") as f:
        rd = csv.DictReader(f)
        fields, rows = list(rd.fieldnames), list(rd)
    for r in rows:
        v = find(_slug_from_urls(r.get("source_url", "")), r["first"], r["last"], r.get("dob", ""))
        r["last_season"] = v
        count(v, bool(r.get("dob")))
    _write(apath, rows, fields)
    print("%d: %d with a last season, %d still listed in %d or unmatched, lists cover to %d" % (
        year, stats["found"], stats["active"] + stats["missing"], top, top))


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 1990)
