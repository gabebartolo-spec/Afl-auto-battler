#!/usr/bin/env python3
"""Summarise tools/balance/dynasty_run.gd JSON (docs/COMPETITIVE_BALANCE.md).

    python3 tools/balance/dynasty_report.py run_a.json [run_b.json ...]
"""
import json
import statistics as st
import sys
from collections import Counter, defaultdict


def spearman(a, b):
    def ranks(xs):
        order = sorted(range(len(xs)), key=lambda i: xs[i])
        r = [0] * len(xs)
        for k, i in enumerate(order):
            r[i] = k
        return r
    ra, rb = ranks(a), ranks(b)
    n = len(a)
    if n < 3:
        return float("nan")
    d2 = sum((x - y) ** 2 for x, y in zip(ra, rb))
    return 1 - 6 * d2 / (n * (n * n - 1))


def report(careers):
    by_year = defaultdict(list)
    user_rows = []
    repeat = Counter()
    ai_repeat = Counter()
    persist = []
    prem_by_rank = Counter()
    seasons_total = 0
    for car in careers:
        seasons = car["seasons"]
        prev_prem = None
        streak = 0
        for i, snap in enumerate(seasons):
            u = snap["user"]
            clubs = snap["clubs"]
            seasons_total += 1
            by_year[i].append(snap)
            prem = snap["premier"]
            if prem:
                prem_by_rank[clubs[prem]["rank"]] += 1
            user_rows.append((car["seed"], i, u, clubs[u]["rank"], snap["user_ladder"], prem == u,
                              clubs[u]["elite"], len(clubs[u]["synergies"]), round(clubs[u]["age22"], 1)))
            if prem and prem == prev_prem:
                streak += 1
                (repeat if prem == u else ai_repeat)[streak + 1] += 1
            else:
                streak = 0
            prev_prem = prem
            if i > 0:
                prev = seasons[i - 1]["clubs"]
                codes = [c for c in clubs if c in prev]
                persist.append(spearman([prev[c]["strength"] for c in codes],
                                        [clubs[c]["strength"] for c in codes]))
    print(f"careers: {len(careers)}, seasons: {seasons_total}")
    print("\nUser club by season index (rank = preseason strength rank, 1 strongest):")
    print("season | mean rank | mean ladder | premierships | top-4 | mean Elite dims | mean synergies | age22")
    for i in sorted(by_year):
        rows = [r for r in user_rows if r[1] == i]
        print(f"{i + 1:>6} | {st.mean(r[3] for r in rows):9.1f} | {st.mean(r[4] for r in rows):11.1f} | "
              f"{sum(r[5] for r in rows):>4}/{len(rows):<7} | {sum(r[4] <= 4 for r in rows):>5} | "
              f"{st.mean(r[6] for r in rows):15.2f} | {st.mean(r[7] for r in rows):14.2f} | {st.mean(r[8] for r in rows):.1f}")
    print("\nWhole league by season index:")
    print("season | strength SD | strongest-weakest | mean synergies/club | clubs with >=4 synergies | mean Elite dims (all) | mean age22")
    for i in sorted(by_year):
        sds, spans, syn, syn4, ages, elite = [], [], [], 0, [], []
        for snap in by_year[i]:
            s = [c["strength"] for c in snap["clubs"].values()]
            sds.append(st.pstdev(s))
            spans.append(max(s) - min(s))
            for c in snap["clubs"].values():
                syn.append(len(c["synergies"]))
                syn4 += len(c["synergies"]) >= 4
                ages.append(c["age22"])
                elite.append(c["elite"])
        n_clubs = sum(len(s["clubs"]) for s in by_year[i])
        print(f"{i + 1:>6} | {st.mean(sds):11.2f} | {st.mean(spans):17.2f} | {st.mean(syn):19.2f} | "
              f"{syn4:>4}/{n_clubs:<19} | {st.mean(elite):21.2f} | {st.mean(ages):.1f}")
    # Does a club finish where its list says it should? Fit ladder position on
    # preseason strength rank over the rival clubs, then see how far your club
    # lands from that line (negative: higher on the ladder than its list).
    pairs = [(snap["clubs"][c]["rank"], snap["ladder"][c], c == snap["user"], i)
             for car in careers for i, snap in enumerate(car["seasons"])
             for c in snap["clubs"] if c in snap["ladder"]]
    ai_pairs = [(r, l) for r, l, mine, _ in pairs if not mine]
    mx = st.mean(r for r, _ in ai_pairs)
    my = st.mean(l for _, l in ai_pairs)
    beta = sum((r - mx) * (l - my) for r, l in ai_pairs) / sum((r - mx) ** 2 for r, _ in ai_pairs)
    alpha = my - beta * mx
    ai_sd = st.pstdev([l - (alpha + beta * r) for r, l in ai_pairs])
    print(f"\nLadder against list (rival clubs): ladder = {alpha:.2f} + {beta:.3f} x strength rank, "
          f"residual SD {ai_sd:.2f}")
    print("Your club's ladder residual (negative = finishes higher than its list):")
    for i in sorted(by_year):
        res = [l - (alpha + beta * r) for r, l, mine, k in pairs if mine and k == i]
        print(f"  season {i + 1}: {st.mean(res):+.2f} (n={len(res)}, se ~{ai_sd / len(res) ** 0.5:.2f})")
    res = [l - (alpha + beta * r) for r, l, mine, _ in pairs if mine]
    print(f"  all: {st.mean(res):+.2f} (n={len(res)}, se ~{ai_sd / len(res) ** 0.5:.2f})")
    if any("morale22" in c for snap in by_year[0] for c in snap["clubs"].values()):
        print("Selected-side morale (preseason -> season's end), your club vs rivals:")
        for i in sorted(by_year):
            mine_pre = [snap["clubs"][snap["user"]]["morale22"] for snap in by_year[i]]
            mine_end = [snap["morale_end"][snap["user"]] for snap in by_year[i] if "morale_end" in snap]
            ai_pre = [c["morale22"] for snap in by_year[i] for k, c in snap["clubs"].items() if k != snap["user"]]
            ai_end = [v for snap in by_year[i] if "morale_end" in snap
                      for k, v in snap["morale_end"].items() if k != snap["user"]]
            print(f"  season {i + 1}: yours {st.mean(mine_pre):.0f} -> {st.mean(mine_end):.0f}, "
                  f"rivals {st.mean(ai_pre):.0f} -> {st.mean(ai_end):.0f}")
    print(f"\nYear-to-year strength-rank persistence (Spearman, all clubs): "
          f"mean {st.mean(persist):.2f}, min {min(persist):.2f}, max {max(persist):.2f}")
    print("\nPremierships by preseason strength rank:", dict(sorted(prem_by_rank.items())))
    print("Back-to-back (or longer) premierships - user:", dict(repeat), " AI clubs:", dict(ai_repeat))
    print("\nUser rows: seed, season, club, rank, ladder, premier, elite, synergies, age22")
    for r in user_rows:
        print("  ", r)


def main():
    careers = []
    for path in sys.argv[1:]:
        with open(path) as f:
            careers.extend(json.load(f))
    report(careers)


if __name__ == "__main__":
    main()
