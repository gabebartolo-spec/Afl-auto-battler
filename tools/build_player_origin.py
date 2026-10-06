#!/usr/bin/env python3
"""Builds data/player_origin_2026.csv: a home state for each player on the 2026
AFL lists, from where DraftGuru says he was recruited.

  python tools/build_player_origin.py [--cache DIR]

Source: DraftGuru's per-year pages, https://www.draftguru.com.au/years/<year>
(2007 to 2025). Each row on a page is one pick or signing, with the draft,
the pick number and the clubs the player came from (a local or school club
and, for most, an under-18 program). A player is joined to data/players_2026.csv
by year + draft type + pick number in data/player_history_2026.csv, then by
his full name where DraftGuru lists him under another draft.

State is set only where the recruiting source makes it certain, and is left
blank otherwise (never guessed):
  - an under-18 program: the TAC / Coates Talent League sides (VIC), the
    Tasmania, Queensland and NT programs; the NSW-ACT program covers two
    states, so it decides nothing alone;
  - a SANFL or WAFL club (SA, WA), a QAFL or NEAFL club by its place, the NT
    and Tasmanian state league clubs, ACT and NSW clubs by name;
  - a school or club labelled with its state, e.g. "(SA)";
  - Papua New Guinea, New Zealand, the USA and Irish counties: INT.
A player's sources run from his earliest club to his latest: the first source
that settles a state wins (so a player who moved states later keeps his
first), and the NSW-ACT program before any settled source leaves him blank.
Every other source (a Victorian school, a VFL club, a basketball club) is left
out: it does not settle the state.
Columns: club, num, first, last, state, source (the DraftGuru year page).
"""
import argparse
import csv
import html
import os
import re
import time
import urllib.request
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
YEARS = range(2007, 2026)
TYPES = {"national": "National", "rookie": "Rookie", "midseason": "Mid-Season", "preseason": "Pre-Season"}

U18 = {"Geelong U18": "VIC", "Western U18": "VIC", "Gippsland U18": "VIC", "Sandringham U18": "VIC",
       "Dandenong U18": "VIC", "Murray U18": "VIC", "Oakleigh U18": "VIC", "Northern U18": "VIC",
       "Bendigo U18": "VIC", "Eastern U18": "VIC", "Calder U18": "VIC", "North Ballarat U18": "VIC",
       "Tasmania U18": "TAS", "Queensland U18": "QLD", "NT U18": "NT"}
CLUBS = {
    "SA": "Woodville-West Torrens;Glenelg;North Adelaide;Sturt;Norwood;West Adelaide;Central District;South Adelaide;Port Adelaide (SANFL)",
    "WA": "East Fremantle;Claremont;South Fremantle;Swan Districts;Peel;West Perth;East Perth;Perth;Subiaco",
    "QLD": "Morningside;Redland;Aspley;Southport;Labrador;Broadbeach;Surfers Paradise;Mount Gravatt;Mount Gravatt (NEAFL);Palm Beach Currumbin;Burleigh;Zillmere;Wilston Grange;Yeronga;Uni of Queensland;Gold Coast (NEAFL);Brisbane (NEAFL);Maroochydore;Sherwood;Coorparoo;Western Magpies",
    "NSW": "Greater Western Sydney (NEAFL);Sydney (NEAFL);Sydney University;Pennant Hills;UNSW-Eastern Suburbs;North Shore;Western Sydney University;St George;Manly;Wagga;Albury FC;Lavington;Turvey Park;East Wagga-Kooringal;Collingullie-Glenfield Park;Temora;Narrandera;Deniliquin FC;Leeton-Whitton;Wentworth;North Albury",
    "ACT": "Ainslie;Belconnen;Eastlake;Tuggeranong;Gungahlin;Weston Creek",
    "NT": "NT Thunder;Nightcliff;St Marys;Wanderers;Southern Districts;Palmerston;Darwin FC;Tiwi Bombers",
    "TAS": "Launceston;North Launceston;Burnie;Lauderdale;Clarence;North Hobart;Glenorchy;Devonport;Kingborough;Hobart FC",
    "INT": "Papua New Guinea;New Zealand;USA;County Kerry;County Cork;County Mayo",
}
LABEL_STATE = {u: s for s, names in CLUBS.items() for u in names.split(";")}
LABEL_STATE.update(U18)
SUFFIX = re.compile(r"\((SA|WA|NSW|ACT|QLD|TAS|NT)\)\s*$")


def label_state(label: str) -> str:
    if label == "NSW-ACT U18":
        return "AMBIGUOUS"  # one program, two states: decides nothing, and stops the scan
    if label in LABEL_STATE:
        return LABEL_STATE[label]
    if label.startswith("County "):
        return "INT"  # an Irish county
    if label.endswith("(SANFL)"):
        return "SA"
    if label.endswith("(WAFL)"):
        return "WA"
    m = SUFFIX.search(label)
    return m.group(1) if m else ""


def norm(name: str) -> str:
    return re.sub(r"[^a-z]", "", name.lower())


def fetch(year: int, cache: str) -> str:
    path = os.path.join(cache, f"draft{year}.html") if cache else ""
    if path and os.path.exists(path):
        return open(path, encoding="utf8").read()
    req = urllib.request.Request(f"https://www.draftguru.com.au/years/{year}", headers={"User-Agent": "Mozilla/5.0 (data check)"})
    page = urllib.request.urlopen(req, timeout=40).read().decode("utf8", "ignore")
    if path:
        os.makedirs(cache, exist_ok=True)
        open(path, "w", encoding="utf8").write(page)
    time.sleep(2)
    return page


def parse(page: str, year: int) -> list[dict]:
    out = []
    for tr in re.findall(r'<tr class="outcome-[^"]*">(.*?)</tr>', page, re.S):
        dr = re.search(r'<td class="draft">(.*?)</td>', tr, re.S)
        num = re.search(r'<td class="number">(.*?)</td>', tr, re.S)
        pl = re.search(r'<td class="player"[^>]*><a href="[^"]+">(.*?)</a>', tr, re.S)
        fc = re.search(r'<td class="from-club">(.*?)</td>', tr, re.S)
        if not (dr and pl):
            continue
        clean = lambda s: html.unescape(re.sub(r"<.*?>", "", s)).replace("\xa0", " ").strip()
        labels = [html.unescape(b) for _, b in re.findall(r'<a href="/from/([^"]+)">(.*?)</a>', fc.group(1))] if fc else []
        out.append({"year": year, "draft": clean(dr.group(1)), "num": clean(num.group(1)) if num else "",
                    "name": norm(clean(pl.group(1))), "labels": labels})
    return out


def state_of(labels: list[str]) -> str:
    """The sources run from the earliest club to the latest, so the first one
    that settles a state is where he grew up; a player who moved states later
    keeps his first. An ambiguous program before any settled one leaves him blank."""
    for label in labels:
        st = label_state(label)
        if st:
            return "" if st == "AMBIGUOUS" else st
    return ""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default="")
    args = ap.parse_args()
    rows = []
    for y in YEARS:
        rows += parse(fetch(y, args.cache), y)
    by_pick = defaultdict(list)
    by_name = defaultdict(list)
    for r in rows:
        by_pick[(r["year"], r["draft"], r["num"])].append(r)
        by_name[r["name"]].append(r)
    hist = {(h["club"], h["num"]): h for h in csv.DictReader(open(os.path.join(ROOT, "data", "player_history_2026.csv"), encoding="utf8"))}
    out = []
    for p in csv.DictReader(open(os.path.join(ROOT, "data", "players_2026.csv"), encoding="utf8")):
        name = norm(p["first"] + p["last"])
        h = hist.get((p["club"], p["num"]), {})
        found = []
        if h.get("draft_type") and h.get("draft_year"):
            found = [r for r in by_pick.get((int(h["draft_year"]), TYPES[h["draft_type"]], h["draft_pick"]), []) if r["name"] == name]
        year = int(h["draft_year"]) if found else 0
        if not found:
            found = by_name.get(name, [])
            year = found[0]["year"] if found else 0
        # Same name under several different sources: not certain who he is.
        state = ""
        if found and len({tuple(r["labels"]) for r in found}) == 1:
            state = state_of(found[0]["labels"])
        src = f"https://www.draftguru.com.au/years/{year}" if found else ""
        out.append([p["club"], p["num"], p["first"], p["last"], state, src])
    path = os.path.join(ROOT, "data", "player_origin_2026.csv")
    with open(path, "w", encoding="utf8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["club", "num", "first", "last", "state", "source"])
        w.writerows(out)
    have = sum(1 for r in out if r[4])
    print(f"wrote {path}: {have} of {len(out)} players have a state ({100 * have // len(out)}%)")


if __name__ == "__main__":
    main()
