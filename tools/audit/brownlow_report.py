#!/usr/bin/env python3
"""Brownlow realism report: the sim's vote counts against real AFL.

Reads one or two logs from tools/audit/brownlow_impl.gd (A = before, B = after)
and marks each number IN / NEAR / OUT of the real range in
tools/balance/afl_brownlow.json (built by tools/balance/build_brownlow_rates.py):

  IN    inside the real seasons' min..max
  NEAR  outside it by no more than 2 x max(sd, 10% of the mean)
  OUT   further away

Roles follow the real reference: 7+ hit-outs a game is a ruck, otherwise the
player's real position (RUC -> RUCK), otherwise his list role. Per-player
rates count men with 12+ games, as the reference does.

    python tools/audit/brownlow_report.py [--votes old|fitwin|umpire] base_real.log [after_real.log]

--votes counts each tally from the log's alt column instead of the game's own
votes (the same matches, another way to give the 3-2-1: see ALT in the impl);
"votes to the winning side" then reads the WSA lines.
"""
import json
import os
import statistics
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "..", "balance", "afl_brownlow.json")
ROLES = ["MID", "FWD", "DEF", "RUCK"]
WATCH = ["Mark Blicavs", "Max Gawn"]


def load(path, votes=""):
    seasons = defaultdict(list)
    wins, wsh, vrd = {}, {}, defaultdict(lambda: {"n": 0, "sum": 0.0, "sq": 0.0, "bins": [0] * 7})
    mode = ""
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            c = line.rstrip("\n").split("|")
            if c[0] == "ROW" and len(c) >= 19:
                mode = c[1]
                stats = dict(kv.split("=") for kv in c[18].split(",") if "=" in kv) if len(c) > 18 else {}
                alt = dict(kv.split("=") for kv in c[19].split(",") if "=" in kv) if len(c) > 19 else {}
                if votes and votes not in alt:
                    sys.exit("%s has no '%s' votes in its alt column" % (path, votes))
                seasons[int(c[2])].append({
                    "id": c[3], "name": c[4], "club": c[5], "role": c[6], "real_pos": c[8],
                    "overall": int(c[9]), "games": int(c[10]),
                    "votes": int(alt[votes]) if votes else int(c[11]), "polled": int(c[12]),
                    "coaches": int(c[13]), "inf_pg": float(c[14]), "tackles": int(c[15]),
                    "pressure": int(c[16]), "hitouts": int(c[17]),
                    "stats": {k: float(v) for k, v in stats.items()},
                })
            elif c[0] == "WIN":
                wins[int(c[2])] = c[3]
            elif c[0] == "WSH" and not votes:
                wsh[int(c[2])] = (int(c[3]), int(c[4]))
            elif c[0] == "WSA" and votes and c[3] == votes:
                wsh[int(c[2])] = (int(c[4]), int(c[5]))
            elif c[0] == "VRD":
                v = vrd[c[3]]
                v["n"] += int(c[4])
                v["sum"] += float(c[5])
                v["sq"] += float(c[6])
                v["bins"] = [a + int(b) for a, b in zip(v["bins"], c[7].split(","))]
    return {"mode": mode + (" (%s votes)" % votes if votes else ""), "seasons": dict(seasons),
            "wins": wins, "wsh": wsh, "vrd": dict(vrd)}


def role_of(r):
    if r["games"] > 0 and r["hitouts"] / r["games"] >= 7.0:
        return "RUCK"
    rp = r["real_pos"]
    if rp == "RUC":
        return "RUCK"
    if rp in ("MID", "FWD", "DEF"):
        return rp
    return r["role"] if r["role"] in ROLES else "MID"


def mark(v, ref):
    if ref is None or v is None:
        return ""
    lo, hi = ref["min"], ref["max"]
    if lo <= v <= hi:
        return "IN"
    tol = 2 * max(ref.get("sd", 0) or 0, 0.1 * abs(ref.get("mean", 0) or 0))
    return "NEAR" if (lo - tol) <= v <= (hi + tol) else "OUT"


def q(xs, p):
    if not xs:
        return 0.0
    s = sorted(xs)
    k = (len(s) - 1) * p
    i = int(k)
    return s[i] if i + 1 >= len(s) else s[i] + (s[i + 1] - s[i]) * (k - i)


def season_numbers(rows):
    by = sorted(rows, key=lambda r: (-r["votes"], -r["inf_pg"]))
    v = [r["votes"] for r in by]
    tot = sum(v) or 1
    share = defaultdict(float)
    for r in rows:
        share[role_of(r)] += r["votes"] / tot
    out = {
        "winner": v[0] if v else 0, "2nd": v[1] if len(v) > 1 else 0,
        "5th": v[4] if len(v) > 4 else 0, "10th": v[9] if len(v) > 9 else 0,
        "polled": sum(1 for x in v if x > 0), "polled_10": sum(1 for x in v if x >= 10),
        "polled_20": sum(1 for x in v if x >= 20), "ruck_share": share["RUCK"],
        "share": dict(share), "top": by[:10],
        "winner_role": role_of(by[0]) if by else "",
        "games_max": max((r["games"] for r in rows), default=0),
    }
    for key in ("tackles", "pressure"):
        per = defaultdict(list)
        for r in rows:
            if r["games"] >= 12:
                x = r[key] / r["games"]
                per[role_of(r)].append(x)
                per["ALL"].append(x)
        out[key] = {role: {"max": max(xs), "p99": q(xs, 0.99), "p90": q(xs, 0.90), "p50": q(xs, 0.50)}
                    for role, xs in per.items() if xs}
    return out


def mean(xs):
    return statistics.mean(xs) if xs else 0.0


def summarise(log):
    per = {s: season_numbers(rows) for s, rows in sorted(log["seasons"].items())}
    watch = {}
    for name in WATCH:
        w = {"wins": 0, "top5": 0, "votes": [], "rank": []}
        for s, rows in log["seasons"].items():
            by = sorted(rows, key=lambda r: (-r["votes"], -r["inf_pg"]))
            for i, r in enumerate(by):
                if r["name"] == name:
                    w["votes"].append(r["votes"])
                    w["rank"].append(i + 1)
                    if i == 0:
                        w["wins"] += 1
                    if i < 5:
                        w["top5"] += 1
        watch[name] = w
    wsh = [a / b for a, b in log["wsh"].values() if b]
    return {"per": per, "watch": watch, "wsh": mean(wsh), "n": len(per)}


def fmt(x, nd=1):
    return ("%." + str(nd) + "f") % x


def main():
    args = sys.argv[1:]
    votes = ""
    if args[:1] == ["--votes"] and len(args) > 1:
        votes, args = args[1], args[2:]
    paths = args
    if not paths:
        sys.exit(__doc__)
    ref = json.load(open(REF, encoding="utf-8"))
    pooled = ref["pooled"]
    logs = [load(p, votes) for p in paths]
    sums = [summarise(lg) for lg in logs]
    heads = ["A", "B"][: len(sums)]
    print("Brownlow realism: %s" % "  vs  ".join(
        "%s %s (%d seasons, %d games max)" % (h, lg["mode"], s["n"],
                                              max((p["games_max"] for p in s["per"].values()), default=0))
        for h, lg, s in zip(heads, logs, sums)))

    def row(label, vals, refb, nd=1):
        cells = []
        for v in vals:
            cells.append("%s [%s] %s" % (fmt(v[0], nd), "%s-%s" % (fmt(v[1], nd), fmt(v[2], nd)), mark(v[0], refb)))
        rr = "%s (%s-%s)" % (fmt(refb["mean"], nd), fmt(refb["min"], nd), fmt(refb["max"], nd)) if refb else ""
        print("| %s | %s | %s |" % (label, rr, " | ".join(cells)))

    print("\n## Season tallies (sim mean [sim min-max] mark vs real seasons)\n")
    print("| stat | real mean (range) | %s |" % " | ".join(heads))
    print("|---|---|%s" % ("---|" * len(heads)))
    for key in ["winner", "2nd", "5th", "10th", "polled", "polled_10", "polled_20"]:
        vals = []
        for s in sums:
            xs = [p[key] for p in s["per"].values()]
            vals.append((mean(xs), min(xs) if xs else 0, max(xs) if xs else 0))
        row(key, vals, pooled.get(key))
    vals = []
    for s in sums:
        xs = [p["ruck_share"] for p in s["per"].values()]
        vals.append((mean(xs), min(xs) if xs else 0, max(xs) if xs else 0))
    row("ruck vote share", vals, pooled["ruck_share"], 3)
    in_range = []
    for s in sums:
        xs = [p["winner"] for p in s["per"].values()]
        in_range.append("%d/%d" % (sum(1 for x in xs if pooled["winner"]["min"] <= x <= pooled["winner"]["max"]), len(xs)))
    print("| winner inside 28-47 | | %s |" % " | ".join(in_range))
    wv = ref["matches"]["winners_vote_share"]
    print("| votes to the winning side | %.3f (2023-25) | %s |" % (wv, " | ".join("%.3f" % s["wsh"] for s in sums)))

    print("\n## Vote share by role (hit-out gate, then real position; real = 2025-26)\n")
    print("| role | real mean (range) | %s |" % " | ".join(heads))
    print("|---|---|%s" % ("---|" * len(heads)))
    for role in ROLES:
        vals = []
        for s in sums:
            xs = [p["share"].get(role, 0.0) for p in s["per"].values()]
            vals.append((mean(xs), min(xs) if xs else 0, max(xs) if xs else 0))
        row(role, vals, pooled["role_share"].get(role), 3)
    for h, s in zip(heads, sums):
        roles = defaultdict(int)
        for p in s["per"].values():
            roles[p["winner_role"]] += 1
        print("%s winners by role: %s" % (h, ", ".join("%s %d" % (r, roles[r]) for r in ROLES if roles[r])))

    for key, refkey, label in (("tackles", "tackles_pg_by_role", "Tackles a game"),
                               ("pressure", "pressure_acts_pg_by_role", "Pressure acts a game")):
        print("\n## %s, per player (12+ games; sim season mean, real 2025-26 range)\n" % label)
        print("| role | stat | real (range) | %s |" % " | ".join(heads))
        print("|---|---|---|%s" % ("---|" * len(heads)))
        for role in ["ALL"] + ROLES:
            for st in ["max", "p99", "p90", "p50"]:
                refb = pooled[refkey].get(role, {}).get(st)
                cells = []
                for s in sums:
                    xs = [p[key][role][st] for p in s["per"].values() if role in p[key]]
                    v = mean(xs)
                    cells.append("%.2f %s" % (v, mark(v, refb)))
                rr = "%.2f (%.2f-%.2f)" % (refb["mean"], refb["min"], refb["max"]) if refb else ""
                print("| %s | %s | %s | %s |" % (role, st, rr, " | ".join(cells)))

    edges = ["Dominant (8+)", "Influential (4-8)", "Busy (1-4)", "Par (-1-1)", "Down (-3--1)",
             "Quiet (-6--3)", "Very quiet (-6 or less)"]
    for h, lg in zip(heads, logs):
        if not lg["vrd"]:
            continue
        print("\n## %s: the coach's full-time read (influence less expected, every man a match)\n" % h)
        print("| measure | n | mean | sd | %s |" % " | ".join(edges))
        print("|---|---|---|---|%s" % ("---|" * len(edges)))
        for key in sorted(lg["vrd"], key=lambda k: (k != "old", k)):
            v = lg["vrd"][key]
            n = max(1, v["n"])
            m = v["sum"] / n
            sd = max(0.0, v["sq"] / n - m * m) ** 0.5
            print("| %s | %d | %.2f | %.2f | %s |" % (key, v["n"], m, sd,
                                                       " | ".join("%.1f%%" % (100.0 * b / n) for b in v["bins"])))

    print("\n## Watched players\n")
    print("| player | %s |" % " | ".join("%s wins / top 5 / mean votes / median rank" % h for h in heads))
    print("|---|%s" % ("---|" * len(heads)))
    for name in WATCH:
        cells = []
        for s in sums:
            w = s["watch"][name]
            cells.append("%d / %d / %.1f / %s" % (w["wins"], w["top5"], mean(w["votes"]),
                                                  int(statistics.median(w["rank"])) if w["rank"] else "-"))
        print("| %s | %s |" % (name, " | ".join(cells)))

    for h, s in zip(heads, sums):
        print("\n## %s top three each season\n" % h)
        for season, p in s["per"].items():
            print("%3d  %s" % (season, "; ".join(
                "%s (%s %s, %d v, %d g, %.1f ho/g)" % (r["name"], r["club"], role_of(r), r["votes"], r["games"],
                                                     r["hitouts"] / max(1, r["games"])) for r in p["top"][:3])))


if __name__ == "__main__":
    main()
