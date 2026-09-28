#!/usr/bin/env python3
"""
Build data/coaches_2026.csv: the Round 1 2026 coaching world the game seeds.

Source: data/research/coaches_round1_2026.csv, the researched staff of every
club at Round 1 2026 plus the external market, with editorial 0-100 ratings
(tactics, development, man management, match-day, standards/culture,
specialist craft) and an evidence confidence. The research stays research:
only the people below reach the game.

  ACTIVE     six jobs per club (senior coach, senior assistant, midfield &
             ruck, forwards, defence, development), assigned by hand from
             the research and checked against club announcements for 2026.
             A job with no defensible Round 1 person gets a generated coach
             rather than someone forced into it (GAPS).
  POOL       coaches outside the six jobs who are credible candidates: the
             clubs' state-league senior coaches, one ruck coach per club,
             and the external market (former senior coaches and the like).
  research   everyone else stays in the research file only.

Ratings: three game skills from the six research ratings, re-spread to a
useful game range and pulled toward the middle when the evidence is thin:
  teaching   line coaches 0.5 development + 0.5 specialist craft;
             everyone else 0.7 development + 0.3 specialist craft
  tactics    0.7 tactics + 0.3 match-day
  manage     0.7 man management + 0.3 standards/culture
  then z-scored across the seeded people to mean 72, sd 7; Low-confidence
  estimates move 40% toward 68, Medium 20%; clamped to 55-92.

Usage: python3 tools/build_coaches.py
"""

from __future__ import annotations

import csv
import os
import random
import re
import statistics

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESEARCH = os.path.join(ROOT, "data", "research", "coaches_round1_2026.csv")
OUT = os.path.join(ROOT, "data", "coaches_2026.csv")

CLUBS = {
    "Adelaide": "ADE", "Brisbane": "BRL", "Carlton": "CAR", "Collingwood": "COL",
    "Essendon": "ESS", "Fremantle": "FRE", "Geelong": "GEE", "Gold Coast": "GCS",
    "GWS": "GWS", "Hawthorn": "HAW", "Melbourne": "MEL", "North Melbourne": "NTH",
    "Port Adelaide": "PAD", "Richmond": "RIC", "St Kilda": "SKN", "Sydney": "SYD",
    "West Coast": "WCE", "Western Bulldogs": "WBD",
}
JOBS = ["SC", "SA", "MID", "FWD", "DEF", "DEV"]
GAP = "GAP"

# Round 1 2026, verified (see docs/DESIGN.md, Coaching staff). Order: SC, SA,
# Midfield & Ruck, Forwards, Defence, Development.
ACTIVE = {
    "ADE": ["Matthew Nicks", "Murray Davis", "Nathan van Berlo", "Scott Burns", "Jack Hombsch", "Michael Godden"],
    "BRL": ["Chris Fagan", GAP, "Cameron Bruce", "Daniel Lloyd", "Dale Morris", "Scott Borlace"],
    "CAR": ["Michael Voss", "Tim Clarke", "Leigh Adams", "Josh Fraser", "Ash Hansen", "Jordan Russell"],
    "COL": ["Craig McRae", "Hayden Skipworth", "Matthew Boyd", "Tyson Goldsack", "Jordan Roughead", "Chloe McMillan"],
    "ESS": ["Brad Scott", "David Rath", "Ben Jacobs", "Cam Roberts", "Dean Solomon", "James Polkinghorne"],
    "FRE": ["Justin Longmuir", "Andrew Sturgess", "Joel Corey", "Jaymie Graham", "Jade Rawlings", "Geoff Valentine"],
    "GEE": ["Chris Scott", "James Kelly", "Nathan Buckley", "James Rahilly", GAP, "Nigel Lappin"],
    "GCS": ["Damien Hardwick", GAP, "Shaun Grigg", "Brad Miller", "Josh Drummond", "Tate Kaesler"],
    "GWS": ["Adam Kingsley", "Craig Jennings", "Wayne Cripps", "Brett Montgomery", "Ben Hart", "Jason Davenport"],
    "HAW": ["Sam Mitchell", "Brett Ratten", "David Mackay", "Adrian Hickmott", "Kade Simpson", "Daniel Giansiracusa"],
    "MEL": ["Steven King", GAP, "Nathan Jones", "Troy Chaplin", "Jared Rivers", "Taylor Whitford"],
    "NTH": ["Alastair Clarkson", "Zane Littlejohn", "Michael Barlow", "Xavier Clarke", "Jed Adcock", "Tom Lynch"],
    "PAD": ["Josh Carr", "Andy Collins", "Stuart Dew", "Darren Reeves", "Luke Webster", "Matthew Lobbe"],
    "RIC": ["Adem Yze", "Blake Caracella", "Sam Lonergan", "Chris Newman", "Jake Batchelor", "Taylor Duryea"],
    "SKN": ["Ross Lyon", "Corey Enright", "Robert Harvey", "Brendon Bolton", "Jimmy Allan", "Damian Carroll"],
    "SYD": ["Dean Cox", "Simon Goodwin", "Ben Mathews", "Jeremy Laidler", "Mark McVeigh", "Adam Kennedy"],
    "WCE": ["Andrew McQualter", GAP, "Sam Radford", "Marco Bello", "Mitch Duncan", "Jamie Maddocks"],
    "WBD": ["Luke Beveridge", "Jarryn Geary", "Brendon Lade", "Ben Reid", "Daniel Pratt", "Luke Power"],
}

# External and background candidates: [name, status, first free year, note].
#   free  available now          away  employed outside an AFL coaching job
#   out   unavailable until the given year
POOL = [
    ["Ken Hinkley", "out", 2027, "Taking 2026 away from clubland"],
    ["Adam Simpson", "away", 0, "Part-time coaching consultant, Carlton"],
    ["James Hird", "free", 0, "Outside an AFL coaching panel"],
    ["David Teague", "free", 0, "Outside an AFL coaching panel"],
    ["Brenton Sanderson", "free", 0, "Outside an AFL coaching panel"],
    ["Nathan Bassett", "away", 0, "SANFL senior coach, West Adelaide"],
    ["Matthew Knights", "away", 0, "Tasmania football program"],
    ["John Longmire", "away", 0, "Executive director of club performance, Sydney"],
    ["Ben Rutten", "away", 0, "General manager of football, Port Adelaide"],
    # The clubs' state-league senior coaches.
    ["Matthew Wright", "away", 0, "SANFL coach, Adelaide"],
    ["Damian Truslove", "away", 0, "VFL senior coach, Carlton"],
    ["Matthew Lokan", "away", 0, "VFL senior coach, Collingwood"],
    ["Cameron Joyce", "away", 0, "VFL senior coach, Essendon"],
    ["Adam Read", "away", 0, "WAFL senior coach, Peel Thunder"],
    ["Mark Corrigan", "away", 0, "VFL coach, Geelong"],
    ["Robbie Chancellor", "away", 0, "VFL head coach, GWS"],
    ["David Mirra", "away", 0, "VFL senior coach, Hawthorn"],
    ["Rhett McLennan", "away", 0, "VFL senior coach, Casey"],
    ["Adam Marcon", "away", 0, "VFL senior coach, North Melbourne"],
    ["Jacob Surjan", "away", 0, "SANFL coach, Port Adelaide"],
    ["Jack Madgen", "away", 0, "VFL coach, Richmond"],
    ["Brendon Goddard", "away", 0, "VFL senior coach, Sandringham"],
    ["Nick Malceski", "away", 0, "VFL head coach, Sydney"],
    ["Kyal Horsley", "away", 0, "WAFL senior coach, West Coast"],
    ["Alex Johnson", "away", 0, "VFL head coach, Footscray"],
    # One ruck coach per club that has one.
    ["Sam Baulderstone", "away", 0, "Ruck coach, Adelaide"],
    ["Ben Hudson", "away", 0, "Ruck development coach, Brisbane"],
    ["Matthew Kreuzer", "away", 0, "Ruck coach, Carlton"],
    ["Greg Stafford", "away", 0, "Ruck coach, Collingwood"],
    ["Todd Goldstein", "away", 0, "Part-time ruck coach, Essendon"],
    ["Sam Naismith", "away", 0, "Ruck coach, Fremantle"],
    ["Shane Mumford", "away", 0, "Ruck coach, GWS"],
    ["Mark Jamar", "away", 0, "Part-time ruck coach, Melbourne"],
    ["Damian Monkhorst", "away", 0, "Ruck coach, North Melbourne"],
    ["Ivan Maric", "away", 0, "Ruck coach, Richmond"],
]

# Senior coaches of AFL clubs before 2026 (caretaker spells aside), for the
# profile line and later hiring. Current senior coaches are implied.
FORMER_SC = {
    "Simon Goodwin", "Brett Ratten", "Stuart Dew", "Nathan Buckley", "Brendon Bolton",
    "Adam Simpson", "James Hird", "David Teague", "Brenton Sanderson", "Matthew Knights",
    "John Longmire", "Ken Hinkley", "Ben Rutten", "Adem Yze",
}

SPEC_WORDS = [
    ("RUCK", r"\bruck"),
    ("DEV", r"development|pathway|learning"),
    ("MID", r"midfield|stoppage|contest"),
    ("FWD", r"forward|goal-kicking"),
    ("DEF", r"defen|back|talls|rebound"),
]


def specialty(text: str) -> str:
    """The first football line the research names, in the order it is named."""
    t = text.lower()
    best = ("", len(t) + 1)
    for tag, pat in SPEC_WORDS:
        m = re.search(pat, t)
        if m and m.start() < best[1]:
            best = (tag, m.start())
    return best[0]


def slug(name: str) -> str:
    return "C_" + re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def num(v: str) -> float:
    return float(v) if v.strip() else 70.0


def main() -> int:
    rows = list(csv.DictReader(open(RESEARCH, encoding="utf-8")))
    by_name: dict[str, dict] = {}
    for r in rows:
        # The market row carries the Round 1 status; it wins for duplicates.
        if r["coach"] not in by_name or r["source_sheet"] == "market":
            by_name[r["coach"]] = r

    people = []   # [name, club, job, status, free_from, note]
    missing = []
    for code, names in ACTIVE.items():
        for job, name in zip(JOBS, names):
            if name == GAP:
                continue
            if name not in by_name:
                missing.append(name)
            people.append([name, code, job, "club", 0, ""])
    for name, status, free_from, note in POOL:
        if name not in by_name:
            missing.append(name)
        people.append([name, "", "", status, free_from, note])
    if missing:
        raise SystemExit("not in the research file: " + ", ".join(missing))

    raw = {}
    for name, _club, job, *_ in people:
        r = by_name[name]
        line = job in ("MID", "FWD", "DEF") or (job == "" and r["role_type"] in
                ("Line Assistant", "Ruck / Specialist"))
        dev, craft = num(r["development"]), num(r["specialist_craft"])
        teach = 0.5 * dev + 0.5 * craft if line else 0.7 * dev + 0.3 * craft
        tactics = 0.7 * num(r["tactics"]) + 0.3 * num(r["match_day"])
        manage = 0.7 * num(r["man_management"]) + 0.3 * num(r["standards_culture"])
        raw[name] = {"teach": teach, "tactics": tactics, "manage": manage}
    stats = {}
    for k in ("teach", "tactics", "manage"):
        vals = [raw[n][k] for n in raw]
        stats[k] = (statistics.mean(vals), statistics.pstdev(vals))
    pull = {"Low": 0.4, "Medium": 0.2}

    out_rows = []
    for name, club, job, status, free_from, note in people:
        r = by_name[name]
        skills = {}
        for k, (mu, sd) in stats.items():
            v = 72.0 + 7.0 * (raw[name][k] - mu) / max(sd, 1e-6)
            v += (68.0 - v) * pull.get(r["confidence"].strip(), 0.0)
            skills[k] = int(round(min(92.0, max(55.0, v))))
        spec = specialty(r["specialty"])
        out_rows.append({
            "cid": slug(name), "name": name, "club": club, "job": job,
            "spec": spec, "teach": skills["teach"], "tactics": skills["tactics"],
            "manage": skills["manage"], "status": status, "free_from": free_from,
            "former_sc": 1 if name in FORMER_SC else 0, "origin": "seed",
            "confidence": r["confidence"].strip(), "note": note,
        })
    # Generated seed coaches for jobs no real Round 1 person defensibly fills.
    n = 0
    for code, names in ACTIVE.items():
        for job, name in zip(JOBS, names):
            if name != GAP:
                continue
            n += 1
            # A fictional coach, rated like a thin-evidence real one: sound,
            # not special (62-72), fixed by his id.
            rng = random.Random("C_G2026_%d" % n)
            out_rows.append({
                "cid": "C_G2026_%d" % n, "name": "", "club": code, "job": job,
                "spec": {"MID": "MID", "FWD": "FWD", "DEF": "DEF", "DEV": "DEV"}.get(job, ""),
                "teach": rng.randint(62, 72), "tactics": rng.randint(62, 72),
                "manage": rng.randint(62, 72), "status": "club", "free_from": 0,
                "former_sc": 0, "origin": "generated", "confidence": "", "note": "",
            })

    cids = [r["cid"] for r in out_rows]
    assert len(cids) == len(set(cids)), "duplicate coach ids"
    with open(OUT, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(out_rows[0].keys()))
        w.writeheader()
        w.writerows(out_rows)
    active = sum(1 for r in out_rows if r["status"] == "club" and r["origin"] == "seed")
    pool = sum(1 for r in out_rows if r["status"] != "club")
    print(f"active real {active}, generated gaps {n}, pool {pool}, "
          f"research only {len(by_name) - active - pool} of {len(by_name)} researched people")
    for k in ("teach", "tactics", "manage"):
        vals = sorted(r[k] for r in out_rows if r["origin"] == "seed")
        print(f"  {k}: min {vals[0]} p25 {vals[len(vals)//4]} median {vals[len(vals)//2]} "
              f"p75 {vals[3*len(vals)//4]} max {vals[-1]}")
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
