#!/usr/bin/env python3
"""
Build what a Legacy career brings in at each rollover, 1990 to 2026 (TODO
row 142, phase L8): every year's real draft class, and each new club's real
first list.

Inputs (data/legacy/, gathered by tools/legacy_<decade>s; data/draftees_2026.csv):
  <decade>s/drafts.csv          every draft, 1989-2025
  <decade>s/lists.csv           every club's list, 1990-2025
  <decade>s/season_stats.csv    AFL Tables season totals, rated per season as
                                build_start.py rates them
  1990s/lists_1990_opening.csv  the players a 1990 career already has

Outputs (data/legacy/):
  classes.csv      year,rank,kind,club,first,last,dob,height_cm,role,origin,tie,peak,last_season
                   One row per prospect in the class drafted at the end of
                   `year`: the National Draft in pick order, then that year's
                   Rookie Draft. `club` is the club that really took him
                   (shown nowhere: the sim's clubs pick, an alternative
                   history; director 2026-11-10). `tie` is father-son.
                   `peak` is his best real season (8+ games), the "Informed"
                   potential (director 2026-11-11); blank if he never had one.
                   `last_season` is his last year on a real list (blank if
                   still listed in 2025 or never listed): he retires about then.
  entry_lists.csv  year,club,num,first,last,dob,height_cm,list,role,peak,known,src,ovr + stats
                   A new club's real list in its first season (Adelaide 1991,
                   Fremantle 1995, Port Adelaide 1997, Gold Coast 2011, GWS
                   2012). `src` is the season his stats come from (his latest
                   AFL season before the club entered), blank for a player
                   with none; `ovr` is his rating that season, on that
                   season's own scale (the game fits his attributes to it).

A real player enters a 1990 career once: a player already on the 1990 lists,
or in an earlier class, never comes again in a later class (a redraft). A new
club's real list is its real list: `known` marks a player the career already
has (on the 1990 lists or in an earlier class), whom the game moves to the new
club from wherever the sim has him, unless the sim has retired him. A new
club's own picks before it entered (Adelaide's foundation, Gold Coast's 2010
concessions) come with its list, not the class: the clubs drafting that year
could not have taken them.

    python3 tools/legacy_1990s/build_rollovers.py
Stdlib only.
"""
from __future__ import annotations

import csv
import os
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_start as B  # noqa: E402
import last_seasons as LS  # noqa: E402

LEG = B.LEG
ROOT = B.ROOT
DECADES = ("1990s", "2000s", "2010s", "2020s")
FIRST_CLASS = 1990
LAST_DATA = 2025
REAL_2026 = os.path.join(ROOT, "data", "draftees_2026.csv")
# A club's first season: its real list that year is the list it fields.
ENTRIES = {"ADE": 1991, "FRE": 1995, "PAD": 1997, "GCS": 2011, "GWS": 2012}
CLASS_COLS = ["year", "rank", "kind", "club", "first", "last", "dob", "height_cm", "role", "origin", "tie", "peak",
              "last_season"]
ENTRY_COLS = ["year", "club", "num", "first", "last", "dob", "height_cm", "list", "role", "peak", "known", "src", "ovr"] + B.ADD_STATS[4:28]


def read(path):
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def all_rows(name):
    out = []
    for dec in DECADES:
        p = os.path.join(LEG, dec, name)
        if os.path.exists(p):
            out += read(p)
    return out


def entered(club):
    return ENTRIES.get(B.code(club), 0)


def role_of(pid, rated, height):
    """His position at his best rated season (most games if none had 8), or
    a ruck by height; '' leaves it to the game."""
    best = None
    for y in rated:
        got = rated[y].get(pid) if pid else None
        if got and got[1] > 0:
            k = (got[1] >= B.PEAK_GAMES, got[0], got[1])
            if best is None or k > best[0]:
                best = (k, got[3])
    if best:
        return best[1]
    h = B.num(height) or 0
    return "RUCK" if h >= 199 else ""


# A swept player enters the open draft like any other: the sim's clubs pick
# him, never the club that really listed him (director, 2026-11-13: "the sim
# will not replicate historical draftee clubs"). Father-son is the one tie,
# because it is a rule the save applies, not a historical outcome.
def tie_of(r):
    return "FS" if r["joined_how"] == "father_son" else ""


def peak_of(pid, rated, from_year):
    peak = 0
    for y in rated:
        if y >= from_year and pid:
            got = rated[y].get(pid)
            if got and got[1] >= B.PEAK_GAMES:
                peak = max(peak, got[0])
    return str(peak) if peak else ""


def main():
    by_year = B.load_seasons()
    model = B.fit_model(by_year)
    rated = B.rate_seasons(by_year, model)
    lists = all_rows("lists.csv")
    # draftguru id -> the latest list row we know (dob, height, AFL Tables id)
    bio = {}
    for r in sorted(lists, key=lambda r: int(r["year"])):
        if r["draftguru_id"]:
            bio[r["draftguru_id"]] = r
    seen = set(r["draftguru_id"] for r in read(os.path.join(LEG, "1990s", "lists_1990_opening.csv"))
               if r["draftguru_id"])
    seen_names = set()
    # His last season on a real list, as the start lists carry it
    # (last_seasons.py): a drafted real player retires about when he did
    # (director, 2026-11-13: "make all historical players retirement start
    # roughly when it did irl"). Blank before his class or once the lists end.
    by_slug, by_dob, by_full, top = LS.last_years()

    def last_of(pid, first, last, dob, year):
        slug = os.path.basename(pid or "").replace(".html", "")
        hit = by_slug.get(slug, 0) if slug else 0
        if not hit and dob:
            hit = by_dob.get("%s|%s" % (LS._norm(last), dob), 0)                 or by_full.get("%s|%s|%s" % (LS._norm(first), LS._norm(last), dob), 0)
        return str(hit) if year < hit < top else ""
    # Who a career already has, by name: the 1990 lists, then each class as
    # it is added. A redraft the source gives no draftguru id or date of
    # birth (Andrew Peck, 1990 pre-season pick redrafted in 1991) is that
    # same man, not a second prospect who could never be listed.
    known_names = set((r["first"], r["last"]) for r in read(os.path.join(LEG, "1990s", "lists_1990_opening.csv")))

    drafts = [r for r in all_rows("drafts.csv")
              if r["draft"] in ("national", "rookie", "preseason") and r["pick"] and FIRST_CLASS <= int(r["year"]) <= LAST_DATA]
    by_class = defaultdict(list)
    for r in drafts:
        by_class[int(r["year"])].append(r)

    # year -> the list rows of players first listed that year (after 1990)
    first_list = defaultdict(list)
    firsts = {}
    for r in sorted(lists, key=lambda r: int(r["year"])):
        k = r["draftguru_id"] or "%s|%s|%s" % (r["first"], r["last"], r["dob"])
        if k not in firsts:
            firsts[k] = r
            # A player first listed during 1990 but not on its opening lists
            # (a 1990 mid-season pick) joins the 1990 class too.
            first_list[max(int(r["year"]), FIRST_CLASS + 1)].append(r)
    classes = []
    taken_before = {}   # year -> set of draftguru ids in classes before that year
    for year in range(FIRST_CLASS, LAST_DATA + 1):
        taken_before[year] = set(seen)
        rows = by_class.get(year, [])
        nat = sorted((r for r in rows if r["draft"] == "national"), key=lambda r: int(r["pick"]))
        rook = sorted((r for r in rows if r["draft"] == "rookie"), key=lambda r: (int(r["round"] or 0), int(r["pick"])))
        # The pre-season draft (December) after the rookies: its first-time
        # players only (a redrafted player is already seen), Liam Jurrah's
        # 2008 among them (the director's Jurrah storyline, 2026-11-13).
        pre = sorted((r for r in rows if r["draft"] == "preseason"), key=lambda r: int(r["pick"]))
        for r in nat + rook + pre:
            dg = r["draftguru_id"]
            key = dg or "%s|%s|%s" % (r["first"], r["last"], year)
            if key in seen:
                continue
            seen.add(key)
            b = bio.get(dg, {})
            if not b.get("dob", "") and (r["first"], r["last"]) in known_names:
                continue
            pid = b.get("afltables_id", "")
            # A running index: the class's order, unique and with no gaps
            # (skipped pre-entry picks and redrafts leave none).
            rank = sum(1 for c in classes if c["year"] == year) + 1
            dob = b.get("dob", "")
            classes.append({
                "year": year, "rank": rank, "kind": r["draft"], "club": B.code(r["club"]),
                "first": r["first"], "last": r["last"], "dob": dob,
                "height_cm": b.get("height_cm", ""), "role": role_of(pid, rated, b.get("height_cm", "")),
                "origin": r["origin"], "tie": "FS" if r["flag"] == "father_son" else "",
                "peak": peak_of(pid, rated, year + 1),
                "last_season": last_of(pid, r["first"], r["last"], dob, year),
            })
            seen_names.add((r["first"], r["last"], dob))
            known_names.add((r["first"], r["last"]))
        # Every real player reaches a list (director, 2026-11-13: "there must
        # be 0 missing players"). One the drafts above never bring in (a zone
        # selection, mid-season or supplemental pick, a father-son the source
        # missed, a pre-entry pick traded on) joins this class's open draft.
        for r in first_list.get(year + 1, []):
            k = r["draftguru_id"] or "%s|%s|%s" % (r["first"], r["last"], r["dob"])
            club = B.code(r["club"])
            if k in seen or (r["draftguru_id"] and r["draftguru_id"] in seen) or entered(club) == year + 1:
                continue
            seen.add(k)
            pid = r["afltables_id"]
            rank = sum(1 for c in classes if c["year"] == year) + 1
            classes.append({
                "year": year, "rank": rank, "kind": "signing", "club": club,
                "first": r["first"], "last": r["last"], "dob": r["dob"],
                "height_cm": r["height_cm"], "role": role_of(pid, rated, r["height_cm"]),
                "origin": r["origin"], "tie": tie_of(r),
                "peak": peak_of(pid, rated, year + 1),
                "last_season": last_of(pid, r["first"], r["last"], r["dob"], year),
            })
            seen_names.add((r["first"], r["last"], r["dob"]))
            known_names.add((r["first"], r["last"]))
    # The real 2026 class (the 2026 start's draft class) closes a campaign's run.
    n26 = 0
    for r in read(REAL_2026):
        if (r["first"], r["last"], r["dob"]) in seen_names:
            continue
        n26 += 1
        pos = {"RUC": "RUCK"}.get(r["pos"], r["pos"])
        classes.append({"year": 2026, "rank": n26, "kind": "national", "club": r["tied_club"],
                        "first": r["first"], "last": r["last"], "dob": r["dob"], "height_cm": r["height_cm"],
                        "role": pos, "origin": "%s (%s)" % (r["team"], r["league"]),
                        "tie": r["tied_type"] if r["tied_club"] else "", "peak": "", "last_season": ""})

    entries = []
    for club, year in sorted(ENTRIES.items(), key=lambda kv: kv[1]):
        before = taken_before.get(year, seen)
        rows = [r for r in lists if int(r["year"]) == year and B.code(r["club"]) == club]
        for r in rows:
            # A player the career already has stays wherever the save has
            # him: the new club gets nobody from history (director,
            # 2026-11-13). Only the players no class brings in remain, its
            # state-league foundation.
            if r["draftguru_id"] and r["draftguru_id"] in before:
                continue
            if "%s|%s|%s" % (r["first"], r["last"], r["dob"]) in before:
                continue
            known = ""
            pid = r["afltables_id"]
            latest = None
            for y in range(year - 1, 1986, -1):
                got = rated.get(y, {}).get(pid) if pid else None
                if got and got[1] > 0:
                    latest = (y, got)
                    break
            row = {"year": year, "club": club, "num": r["num"], "first": r["first"], "last": r["last"],
                   "dob": r["dob"], "height_cm": r["height_cm"], "list": r["list"],
                   "role": latest[1][3] if latest else role_of(pid, rated, r["height_cm"]),
                   "peak": peak_of(pid, rated, year), "known": known, "src": latest[0] if latest and not known else "",
                   "ovr": latest[1][0] if latest and not known else ""}
            if latest and not known:
                row.update(B.stat_cells(latest[1][2]))
            entries.append(row)

    B.write(os.path.join(LEG, "classes.csv"), CLASS_COLS, classes)
    B.write(os.path.join(LEG, "entry_lists.csv"), ENTRY_COLS, entries)
    per = defaultdict(int)
    for c in classes:
        per[c["year"]] += 1
    print("classes: %d prospects, %d-%d (%d to %d a year; 2026: %d)" % (
        len(classes), min(per), max(per), min(per.values()), max(per.values()), n26))
    per_e = defaultdict(int)
    for e in entries:
        per_e["%s %s" % (e["club"], e["year"])] += 1
    print("entry lists:", ", ".join("%s %d" % kv for kv in per_e.items()))


if __name__ == "__main__":
    main()
