#!/usr/bin/env python3
"""
Fill the position column of data/list_additions_2026.csv from Footywire's
team player pages (footywire.com/afl/footy/tp-<club>): the first position
listed for each player (Defender, Midfield, Forward, Ruck). Matched on
club + surname + birth year + first initial. Writes the csv in place and
prints what it changed and who it could not match.
"""
import html, os, re, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = {"ADE": "adelaide-crows", "BRL": "brisbane-lions", "CAR": "carlton-blues", "COL": "collingwood-magpies",
         "ESS": "essendon-bombers", "FRE": "fremantle-dockers", "GCS": "gold-coast-suns", "GEE": "geelong-cats",
         "GWS": "greater-western-sydney-giants", "HAW": "hawthorn-hawks", "MEL": "melbourne-demons",
         "NTH": "kangaroos", "PAD": "port-adelaide-power", "RIC": "richmond-tigers", "STK": "st-kilda-saints",
         "SYD": "sydney-swans", "WBD": "western-bulldogs", "WCE": "west-coast-eagles"}
POS = {"Defender": "DEF", "Midfield": "MID", "Forward": "FWD", "Ruck": "RUCK"}
SRC = "https://www.footywire.com/afl/footy/tp-"


def page(code):
    req = urllib.request.Request(SRC + PAGES[code], headers={"User-Agent": "Mozilla/5.0"})
    b = urllib.request.urlopen(req, timeout=60).read().decode("latin1")
    t = re.sub(r"<[^>]+>", "|", b)
    t = re.sub(r"\|[\s|]*\|", "|", html.unescape(t))
    return t


def players(t):
    out = []
    for m in re.finditer(r"([A-Z][^|\n]*?), ([^|\n]+)\|[^\n]*?(\d{1,2} \w{3} (\d{4}))\|\d+cm\|[^|\n]*\|\s*((?:(?:Defender|Midfield|Forward|Ruck)\s*\|?\s*)+)", t):
        poss = re.findall(r"Defender|Midfield|Forward|Ruck", m.group(5))
        out.append((m.group(1).strip(), m.group(2).strip(), m.group(4), POS[poss[0]]))
    return out


def main():
    path = os.path.join(ROOT, "data", "list_additions_2026.csv")
    lines = open(path, encoding="utf-8").read().split("\n")
    by_club = {}
    for code in PAGES:
        by_club[code] = players(page(code))
        print(code, len(by_club[code]), file=sys.stderr)
        time.sleep(0.5)
    out, changed, missing = [], 0, []
    for l in lines:
        c = l.split(",")
        if len(c) > 6 and c[3] in PAGES and l != lines[0]:
            first, last, dob, club = c[0], c[1], c[2], c[3]
            hits = [p for p in by_club[club] if p[0].lower() == last.lower() and p[2] == dob[:4]
                    and p[1][:1].lower() == first[:1].lower()]
            if len(hits) == 1:
                if c[4] != hits[0][3]:
                    print("SET", club, first, last, c[4] or "-", "->", hits[0][3], file=sys.stderr)
                    changed += 1
                c[4] = hits[0][3]
                if "footywire" not in c[8]:
                    c[8] = c[8] + " | https://www.footywire.com/afl/footy/tp-" + PAGES[club]
                l = ",".join(c)
            else:
                missing.append((club, first, last, len(hits)))
        out.append(l)
    open(path, "w", encoding="utf-8", newline="").write("\n".join(out))
    print("changed", changed, "unmatched", len(missing), missing, file=sys.stderr)


main()
