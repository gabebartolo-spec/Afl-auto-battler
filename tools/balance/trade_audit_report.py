#!/usr/bin/env python3
"""Long-save trade audit (Trade E) from dynasty_run JSON.

    python3 tools/balance/trade_audit_report.py careers.json [more.json ...]

Reads each off-season's `market` record (tools/balance/dynasty.gd, _market)
and the season snapshots, and answers the long-save questions: how much the
market trades, who buys from whom, whether stars go for junk, whether
contenders sell stars or rebuilders spend premium picks on veterans, pick
hoarding, repeat winners, list and cap limits, and whether the National
Draft gives every pick to its owner. "Value" is the neutral trade value the
harness records (a building club's TradeValue, no list fit), the same for
every club.
"""
import json
import statistics as st
import sys
from collections import Counter, defaultdict


def side_value(assets):
    return sum(float(a.get("value", 0.0)) for a in assets)


def describe(a):
    if a.get("pick"):
        return "%d R%d pick (No. %d)" % (a["year"], a["round"], a["spot"])
    if a.get("missing"):
        return "player (gone)"
    return "%d/%d age %.0f%s" % (a["ovr"], a["pot"], a["age"], " starter" if a.get("starter") else "")


def premium_young(a):
    return not a.get("pick") and not a.get("missing") and a["age"] <= 24.0 and (a["ovr"] >= 80 or a["pot"] >= 86)


def star(a):
    return not a.get("pick") and not a.get("missing") and a["ovr"] >= 80


def main(paths):
    careers = []
    for path in paths:
        with open(path) as f:
            careers.extend(json.load(f))
    if not careers:
        print("no careers")
        return
    manages = sorted({c.get("manage", "none") for c in careers})
    offseasons = 0
    per_off = []
    user_per_off = []
    phase_pairs = Counter()
    junk = []
    contender_sells = []
    rebuilder_dumps = []
    net = defaultdict(float)
    wins = Counter()
    losses = Counter()
    max_picks = []
    max_firsts = 0
    zero_firsts = 0
    club_years = 0
    sizes = []
    over_cap = 0
    cap_ratio = []
    draft_wrong = 0
    draft_traded = 0
    draft_slots = 0
    all_trades = []
    for c in careers:
        seasons = c["seasons"]
        for i, s in enumerate(seasons):
            for code, row in s["clubs"].items():
                sizes.append(int(row["size"]))
                ratio = float(row["payroll"]) / float(s["cap"])
                cap_ratio.append(ratio)
                if ratio > 1.0:
                    over_cap += 1
            m = s.get("market")
            if m is None:
                continue
            offseasons += 1
            trades = m["trades"]
            per_off.append(sum(1 for t in trades if t["kind"] == "rivals"))
            user_per_off.append(sum(1 for t in trades if t["kind"] == "user"))
            for t in trades:
                t = dict(t, seed=c["seed"], year=s["year"])
                all_trades.append(t)
                phase_pairs[(t["kind"], t["buyer_phase"], t["seller_phase"])] += 1
                got = side_value(t["got"])
                gave = side_value(t["gave"])
                d = got - gave
                net[(c["seed"], t["buyer"])] += d
                net[(c["seed"], t["seller"])] -= d
                if d > 0.5:
                    wins[t["buyer"]] += 1
                    losses[t["seller"]] += 1
                elif d < -0.5:
                    wins[t["seller"]] += 1
                    losses[t["buyer"]] += 1
                if any(premium_young(a) or star(a) for a in t["got"]) and gave < 0.6 * got:
                    junk.append(t)
                if t["seller_phase"] == "contending" and any(star(a) and a.get("starter") for a in t["got"]):
                    contender_sells.append(t)
                if t["buyer_phase"] == "rebuilding" and any(a.get("pick") and a["round"] == 1 and a["spot"] <= 9
                                                            for a in t["gave"]) \
                        and any(not a.get("pick") and not a.get("missing") and a["age"] >= 28.5 for a in t["got"]):
                    rebuilder_dumps.append(t)
            for code, held in m["picks"].items():
                club_years += 1
                max_picks.append(sum(held.values()))
                by_year = defaultdict(int)
                for k, n in held.items():
                    year, rnd = k.split(":")
                    if rnd == "1":
                        by_year[year] += n
                max_firsts = max([max_firsts] + list(by_year.values()))
                years = {k.split(":")[0] for k in held} | set(by_year)
                if str(s["year"]) not in by_year:
                    zero_firsts += 1
            chk = s.get("mgmt", {}).get("draft_check")
            if chk:
                draft_wrong += int(chk["wrong"])
                draft_traded += int(chk["traded"])
                draft_slots += int(chk["slots"])

    print("## Trade audit: %d careers (%s), %d off-seasons\n" % (len(careers), ", ".join(manages), offseasons))
    print("| Measure | Value |")
    print("|---|---|")
    print("| Rival trades per off-season (mean, range) | %.1f (%d-%d) |" % (st.mean(per_off), min(per_off), max(per_off)))
    print("| Off-seasons with no rival trade | %d of %d |" % (sum(1 for n in per_off if n == 0), offseasons))
    print("| Your trades per off-season | %.2f |" % st.mean(user_per_off))
    print("| Tradeable picks held by one club (mean, max) | %.1f, %d |" % (st.mean(max_picks), max(max_picks)))
    print("| Most first-round picks one club holds in one draft | %d |" % max_firsts)
    print("| Clubs without their own year's first-round pick | %d of %d club-years |" % (zero_firsts, club_years))
    print("| List sizes at season start (min-max) | %d-%d |" % (min(sizes), max(sizes)))
    print("| Payroll / cap (max), lists over the cap | %.2f, %d |" % (max(cap_ratio), over_cap))
    print("| National Draft slots checked; with the wrong club; traded picks used | %d; %d; %d |" % (
        draft_slots, draft_wrong, draft_traded))
    print()
    print("**Who trades with whom** (buyer phase -> seller phase):\n")
    for (kind, b, sl), n in sorted(phase_pairs.items(), key=lambda kv: -kv[1]):
        print("- %s: %s -> %s: %d" % (kind, b or "?", sl or "?", n))
    print()

    def show(title, rows):
        print("**%s**: %d\n" % (title, len(rows)))
        for t in rows[:12]:
            print("- seed %d, %d, %s: %s (%s) get %s from %s (%s) for %s" % (
                t["seed"], t["year"], t["kind"], t["buyer"], t["buyer_phase"],
                ", ".join(describe(a) for a in t["got"]), t["seller"], t["seller_phase"],
                ", ".join(describe(a) for a in t["gave"])))
        print()

    show("Stars or premium youth for under 60% of their value", junk)
    show("Contenders selling a starting star", contender_sells)
    show("Rebuilders spending a top-nine pick on a player 28.5 or older", rebuilder_dumps)
    print("**Repeat winners** (neutral value, over each career):\n")
    ranked = sorted(net.items(), key=lambda kv: -kv[1])
    for (seed, code), v in ranked[:5]:
        print("- seed %d %s: %+.2f" % (seed, code, v))
    print("- ...")
    for (seed, code), v in ranked[-3:]:
        print("- seed %d %s: %+.2f" % (seed, code, v))
    print("\nClubs on the winning side of a clearly uneven deal (value gap > 0.5) most often: %s" % (
        ", ".join("%s %d (lost %d)" % (k, n, losses[k]) for k, n in wins.most_common(5))))
    print()
    user = [t for t in all_trades if t["kind"] == "user"]
    if user:
        show("Your trades", user)


if __name__ == "__main__":
    main(sys.argv[1:])
