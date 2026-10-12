"""Aggregate draft_strategy_impl logs (roadmap row 37). Measurement only.

usage: python -I tools/audit/draft_strategy_agg.py <dir or file with run logs> [more dirs/files]

Reads every file under the paths, keeps the LIST / POOL / DP / DC / AGE / DA lines,
and prints the markdown tables used in docs/research/draft_strategy_audit_2026-10-12.md.
The user's own club (left unmanaged in an autopilot career) is dropped from every
end-of-season table; start-of-season tables keep all clubs.
"""
import math
import os
import re
import sys
from collections import defaultdict

LINE = re.compile(r"(?:^|\s)(LIST|POOL|DP|DC|AGE|DA)\|(.*)$")
M = ["best", "depth", "u23", "mid", "old", "potu", "ovru", "sq"]


def mean(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else float("nan")


def sd(xs):
    xs = list(xs)
    if len(xs) < 2:
        return float("nan")
    m = mean(xs)
    return math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1))


def se(xs):
    xs = list(xs)
    return sd(xs) / math.sqrt(len(xs)) if len(xs) > 1 else float("nan")


def load(paths):
    rec = defaultdict(list)
    seen = set()
    for root in paths:
        files = [root] if os.path.isfile(root) else [
            os.path.join(d, f) for d, _, fs in os.walk(root) for f in fs]
        for fp in files:
            with open(fp, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    m = LINE.search(line.rstrip("\n"))
                    if m:
                        key = (m.group(1), m.group(2))
                        # a line repeated in two logs of the same run (the baseline
                        # re-run of a seed) is counted once
                        if m.group(1) in ("LIST", "DP", "DC", "AGE") and key in seen:
                            continue
                        seen.add(key)
                        rec[m.group(1)].append(m.group(2).split("|"))
    return rec


def rank_corr(x, y):
    def rk(v):
        o = sorted(range(len(v)), key=lambda i: v[i])
        r = [0] * len(v)
        for i, j in enumerate(o):
            r[j] = i
        return r
    a, b = rk(x), rk(y)
    ma, mb = mean(a), mean(b)
    num = sum((i - ma) * (j - mb) for i, j in zip(a, b))
    den = math.sqrt(sum((i - ma) ** 2 for i in a) * sum((j - mb) ** 2 for j in b))
    return num / den if den else float("nan")


def main():
    rec = load(sys.argv[1:])
    users = {}
    for r in rec["DA"]:
        users[(r[0], int(r[1]))] = r[2].split()[1]
    rows = defaultdict(dict)  # (mode, tag, year) -> {(seed, code): metrics}
    for r in rec["LIST"]:
        mode, seed, tag, year, code = r[0], int(r[1]), r[2], int(r[3]), r[4]
        vals = dict(zip(["size"] + M, [float(x) for x in r[5:]]))
        rows[(mode, tag, year)][(seed, code)] = vals

    def league(mode, tag, year, drop_user):
        by_seed = defaultdict(list)
        for (seed, code), v in rows[(mode, tag, year)].items():
            if drop_user and users.get((mode, seed)) == code:
                continue
            by_seed[seed].append(v)
        out = {}
        for seed, vs in by_seed.items():
            d = {k: mean(v[k] for v in vs) for k in ["size"] + M}
            d["sd_best"] = sd(v["best"] for v in vs)
            d["range_best"] = max(v["best"] for v in vs) - min(v["best"] for v in vs)
            out[seed] = d
        return out

    def ms(lg, key):
        xs = [d[key] for d in lg.values()]
        return mean(xs), se(xs)

    print("## Seeds and user clubs")
    print(", ".join("%s %d: %s" % (m, s, c) for (m, s), c in sorted(users.items())))
    print()

    for tag, year, label in (("pre", 2026, "pre-draft 2026 lists"), ("start", 2027, "season-1 start")):
        key = ("real", tag, year)
        if key not in rows:
            continue
        clubs = defaultdict(list)
        for (seed, code), v in rows[key].items():
            clubs[code].append(v)
        print("### A. Real lists, %s (mean over %d run(s))" % (label, len({s for s, _ in rows[key]})))
        print("| Club | List | Best 23 | Depth 24-38 | Under 23 | 23-29 | 30+ | U23 POT | Squad strength |")
        print("|---|---|---|---|---|---|---|---|---|")
        for code in sorted(clubs):
            c = clubs[code]
            print("| %s | %.0f | %.1f | %.1f | %.0f | %.0f | %.0f | %.1f | %.1f |" % (
                code, mean(v["size"] for v in c), mean(v["best"] for v in c), mean(v["depth"] for v in c),
                mean(v["u23"] for v in c), mean(v["mid"] for v in c), mean(v["old"] for v in c),
                mean(v["potu"] for v in c), mean(v["sq"] for v in c)))
        cm = {code: {k: mean(v[k] for v in c) for k in ["size"] + M} for code, c in clubs.items()}
        print("| **League mean** | %.0f | %.1f | %.1f | %.0f | %.0f | %.0f | %.1f | %.1f |" % (
            mean(x["size"] for x in cm.values()), mean(x["best"] for x in cm.values()), mean(x["depth"] for x in cm.values()),
            mean(x["u23"] for x in cm.values()), mean(x["mid"] for x in cm.values()), mean(x["old"] for x in cm.values()),
            mean(x["potu"] for x in cm.values()), mean(x["sq"] for x in cm.values())))
        print("| **Spread (SD across clubs)** | %.1f | %.2f | %.2f | %.1f | %.1f | %.1f | %.2f | %.2f |" % (
            sd(x["size"] for x in cm.values()), sd(x["best"] for x in cm.values()), sd(x["depth"] for x in cm.values()),
            sd(x["u23"] for x in cm.values()), sd(x["mid"] for x in cm.values()), sd(x["old"] for x in cm.values()),
            sd(x["potu"] for x in cm.values()), sd(x["sq"] for x in cm.values())))
        print()

    base_key = ("real", "pre", 2026) if ("real", "pre", 2026) in rows else ("real", "start", 2027)
    bl = league(*base_key, drop_user=False)
    base = {k: mean(d[k] for d in bl.values()) for k in ["size"] + M + ["sd_best", "range_best"]}
    print("Baseline used for the gaps: %s %s %s. Best 23 %.2f, depth %.2f, U23 POT %.2f, squad strength %.2f; SD of best 23 across clubs %.2f; best-worst club %.1f." % (
        base_key + (base["best"], base["depth"], base["potu"], base["sq"], base["sd_best"], base["range_best"])))
    print()

    snaps = [("start", 2027, "S1 start")] + [("end", 2026 + n, "end S%d" % n) for n in range(1, 11)]
    for mode, title in (("redraft", "B. Redraft careers"), ("real", "C. Real-list careers")):
        print("### %s: AI clubs, league mean over seeds (+/- standard error), gap to the real 2026 lists (A)" % title)
        print("| Moment | Seeds | Best 23 | Gap to A | Depth 24-38 | Gap to A | U23 POT | Gap to A | Squad strength | Gap to A | U23 count | 30+ count | SD of best 23 across clubs | Best-worst club |")
        print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        for tag, year, lab in snaps:
            if (mode, tag, year) not in rows:
                continue
            lg = league(mode, tag, year, drop_user=(tag == "end"))
            if not lg:
                continue
            c = {}
            for k in ("best", "depth", "potu", "sq", "u23", "old"):
                m, e = ms(lg, k)
                c[k] = "%.2f ± %.2f" % (m, e)
                c["g_" + k] = "%+.2f" % (m - base[k]) if k in base else ""
            sdm, sde = ms(lg, "sd_best")
            rg, _ = ms(lg, "range_best")
            print("| %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %.2f ± %.2f | %.1f |" % (
                lab, len(lg), c["best"], c["g_best"], c["depth"], c["g_depth"], c["potu"], c["g_potu"], c["sq"], c["g_sq"],
                c["u23"], c["old"], sdm, sde, rg))
        print()

    print("### B minus C, paired by seed (redraft minus real-list career, same seed, same user club), +/- standard error")
    print("| Moment | Best 23 | Depth 24-38 | U23 POT | Squad strength | U23 count | 30+ count |")
    print("|---|---|---|---|---|---|---|")
    for tag, year, lab in snaps:
        if ("redraft", tag, year) not in rows or ("real", tag, year) not in rows:
            continue
        a = league("redraft", tag, year, tag == "end")
        b = league("real", tag, year, tag == "end")
        seeds = sorted(set(a) & set(b))
        if not seeds:
            continue
        cells = []
        for k in ("best", "depth", "potu", "sq", "u23", "old"):
            d = [a[s][k] - b[s][k] for s in seeds]
            cells.append("%+.2f ± %.2f" % (mean(d), se(d)))
        print("| %s | %s |" % (lab, " | ".join(cells)))
    print()

    if ("real", "start", 2027) in rows:
        print("### C. Per-club drift of AI management from the real lists (best 23, mean over non-user seeds)")
        print("| Club | A (S1 start) | S3 end | S5 end | S10 end | drift S5 | drift S10 |")
        print("|---|---|---|---|---|---|---|")
        per = defaultdict(lambda: defaultdict(list))
        for tag, year in (("start", 2027), ("end", 2029), ("end", 2031), ("end", 2036)):
            for (seed, code), v in rows.get(("real", tag, year), {}).items():
                if tag == "end" and users.get(("real", seed)) == code:
                    continue
                per[code][year].append(v["best"])
        ra, r5, r10 = [], [], []
        for code in sorted(per):
            p = per[code]
            if not (p[2027] and p[2031]):
                continue
            a0, s3, s5 = mean(p[2027]), mean(p[2029]), mean(p[2031])
            s10 = mean(p[2036]) if p[2036] else float("nan")
            print("| %s | %.1f | %.1f | %.1f | %.1f | %+.1f | %+.1f |" % (code, a0, s3, s5, s10, s5 - a0, s10 - a0))
            ra.append(a0)
            r5.append(s5)
            r10.append(s10)
        ok10 = [i for i, v in enumerate(r10) if v == v]
        print()
        if ok10:
            print("Club order held: rank correlation of best 23 with the start, S5 %.2f, S10 %.2f. Mean absolute drift S5 %.2f, S10 %.2f." % (
                rank_corr(ra, r5), rank_corr([ra[i] for i in ok10], [r10[i] for i in ok10]),
                mean(abs(r5[i] - ra[i]) for i in range(len(ra))), mean(abs(r10[i] - ra[i]) for i in ok10)))
        print()

    print("### Pools the two starts draw on (mean OVR of the best 414 players, and of all)")
    for r in sorted({tuple(x) for x in rec["POOL"]}):
        print("- %s seed %s: %s players, best 414 mean %s, all mean %s" % (r[0], r[1], r[2], r[3], r[4]))
    print()

    dp = []
    for r in rec["DP"]:
        dp.append(dict(mode=r[0], seed=int(r[1]), tag=r[2], year=int(r[3]), pick=int(r[4]), rnd=int(r[5]), club=r[6],
                       age=float(r[7]), ovr=int(r[8]), pot=int(r[9]), cw=float(r[10]), bw=float(r[11]), bo=int(r[12]),
                       bp=int(r[13]), better=int(r[14]), role=r[15], ngap=float(r[16]) if len(r) > 16 else -1.0, ngap2=float(r[17]) if len(r) > 17 else -1.0))
    bands = [(1, 10), (11, 30), (31, 60), (61, 999)]
    print("### D1. AI picks against the best player on the board (worth = 35% OVR + 65% POT from true values, no scouting noise; League Draft: the draft's own worth)")
    print("| Draft | Pick band | Picks | Gap to best (mean) | of which scouting noise alone | noise + position need | Gap 3+ | Gap 5+ | Gap 8+ | Higher-worth players left (mean) | Pick OVR | Best OVR left | Pick POT | Best POT left |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for tag, label in (("national", "National, all careers"), ("open", "2026 class (real-list start)"), ("league", "League Draft (redraft)")):
        for lo, hi in bands:
            xs = [d for d in dp if d["tag"] == tag and lo <= d["pick"] <= hi]
            if not xs:
                continue
            gap = [d["bw"] - d["cw"] for d in xs]
            n = len(xs)
            ng = [d["ngap"] for d in xs if d["ngap"] >= 0]
            ng2 = [d["ngap2"] for d in xs if d["ngap2"] >= 0]
            print("| %s | %d-%s | %d | %.2f | %s | %s | %.0f%% | %.0f%% | %.0f%% | %.1f | %.1f | %.1f | %.1f | %.1f |" % (
                label, lo, hi if hi < 999 else "end", n, mean(gap), "%.2f" % mean(ng) if ng else "-", "%.2f" % mean(ng2) if ng2 else "-", 100 * sum(g >= 3 for g in gap) / n,
                100 * sum(g >= 5 for g in gap) / n, 100 * sum(g >= 8 for g in gap) / n, mean(d["better"] for d in xs),
                mean(d["ovr"] for d in xs), mean(d["bo"] for d in xs), mean(d["pot"] for d in xs), mean(d["bp"] for d in xs)))
    print()
    print("### D2. Class strength by draft year (picks per career; redraft and real-list careers pooled)")
    print("| Draft year | Picks | Top 10 picks: OVR / POT | All picks: OVR / POT | Mean age |")
    print("|---|---|---|---|---|")
    for tag in ("open", "national"):
        for y in sorted({d["year"] for d in dp if d["tag"] == tag}):
            xs = [d for d in dp if d["tag"] == tag and d["year"] == y]
            top = [d for d in xs if d["pick"] <= 10]
            seeds = len({(d["mode"], d["seed"]) for d in xs})
            print("| %d%s | %.0f | %.1f / %.1f | %.1f / %.1f | %.1f |" % (
                y, " (real class)" if tag == "open" else "", len(xs) / max(1, seeds), mean(d["ovr"] for d in top),
                mean(d["pot"] for d in top), mean(d["ovr"] for d in xs), mean(d["pot"] for d in xs), mean(d["age"] for d in xs)))
    print()

    bench_start, bench_pre = {}, {}
    for r in rec["AGE"]:
        if r[0] == "real" and r[2] in ("start", "pre"):
            (bench_start if r[2] == "start" else bench_pre)[int(r[4])] = (int(r[5]), float(r[6]), float(r[7]))
    bench = bench_pre or bench_start
    dc = []
    for r in rec["DC"]:
        if r[-1] == "gone":
            dc.append(dict(mode=r[0], seed=int(r[1]), year=int(r[2]), off=int(r[3]), found=0, age=None, ovr=None,
                           age0=float(r[8]), ovr0=int(r[9]), pot0=int(r[10]), pick=int(r[11])))
        else:
            dc.append(dict(mode=r[0], seed=int(r[1]), year=int(r[2]), off=int(r[3]), found=1, age=float(r[6]), ovr=int(r[7]),
                           age0=float(r[8]), ovr0=int(r[9]), pot0=int(r[10]), pick=int(r[11])))
    print("### D3. Drafted players three seasons on, against the real 2026 lists' players of the same age")
    print("| Age three seasons on | Drafted | Still on a list | OVR of those still listed | Real 2026 lists, same age: players | Real OVR | Gap |")
    print("|---|---|---|---|---|---|---|")
    for a in range(19, 26):
        xs = [d for d in dc if d["off"] == 3 and d["found"] and int(d["age"]) == a]
        ys = [d for d in dc if d["off"] == 3 and not d["found"] and int(d["age0"]) + 4 == a]
        if not xs:
            continue
        tot = len(xs) + len(ys)
        b = bench.get(a)
        print("| %d | %d | %.0f%% | %.1f | %s | %s | %s |" % (
            a, tot, 100 * len(xs) / tot, mean(d["ovr"] for d in xs),
            b[0] if b else "-", "%.1f" % b[1] if b else "-", "%+.1f" % (mean(d["ovr"] for d in xs) - b[1]) if b else "-"))
    print()
    print("Same cohort by class (three seasons on, those still listed):")
    print("| Class | Drafted | OVR at the pick | Age at the pick | OVR three seasons on | Age then | Rise |")
    print("|---|---|---|---|---|---|---|")
    for lab, test in (("2026 (the real class)", lambda y: y == 2026), ("2027 (first generated)", lambda y: y == 2027),
                      ("2028 and later (generated)", lambda y: y >= 2028)):
        on = [d for d in dc if d["off"] == 3 and d["found"] and test(d["year"])]
        if on:
            print("| %s | %d | %.1f | %.1f | %.1f | %.1f | %+.1f |" % (lab, len(on), mean(d["ovr0"] for d in on), mean(d["age0"] for d in on),
                  mean(d["ovr"] for d in on), mean(d["age"] for d in on), mean(d["ovr"] - d["ovr0"] for d in on)))
    print()
    print("Same cohort by pick band (three seasons on; OVR/POT at the pick are for those still listed):")
    print("| Pick band | Drafted | Still listed | OVR at the pick | OVR three seasons on | POT at the pick | Rise |")
    print("|---|---|---|---|---|---|---|")
    for lo, hi in bands:
        xs = [d for d in dc if d["off"] == 3 and lo <= d["pick"] <= hi]
        if not xs:
            continue
        on = [d for d in xs if d["found"]]
        if not on:
            continue
        print("| %d-%s | %d | %.0f%% | %.1f | %.1f | %.1f | %+.1f |" % (
            lo, hi if hi < 999 else "end", len(xs), 100 * len(on) / len(xs), mean(d["ovr0"] for d in on),
            mean(d["ovr"] for d in on), mean(d["pot0"] for d in on), mean(d["ovr"] - d["ovr0"] for d in on)))
    print()
    if bench:
        print("Real 2026 lists by age (players, OVR, POT): " + "; ".join("%d: %d, %.1f, %.1f" % ((a,) + bench[a]) for a in sorted(bench)))


if __name__ == "__main__":
    main()
