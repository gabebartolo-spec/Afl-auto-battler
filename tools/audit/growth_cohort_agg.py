"""Cohort tables from growth_curve_impl logs (COH / MED / GA lines):
   python -X utf8 -I tools/audit/growth_cohort_agg.py <log> [<log> ...]
Drafted players (generated classes) by draft range: mean OVR by age at season end, seasons to reach the
league median best-22 OVR, and the share who ever do (classes with >= MIN_FOLLOW seasons of follow-up)."""
import sys, collections

MIN_FOLLOW = 5
arm = None
coh = collections.defaultdict(list)    # (arm, rng) -> [(draft_year, year, age, ovr, thr, seed)]
last_year = collections.defaultdict(int)
seen = collections.defaultdict(set)    # (arm, rng) -> {(seed, draft_year, pick)}


def rng_of(pick):
    return "1-10" if pick <= 10 else ("11-30" if pick <= 30 else "31+")


for path in sys.argv[1:]:
    for line in open(path, encoding="utf-8", errors="replace"):
        f = line.strip().split("|")
        if f[0] == "GA":
            arm = f[6].replace("night ", "n") + ("r" if len(f) > 7 and f[7] == "ready 1" else "") + " " + f[4].replace("step ", "") + ":" + f[5].replace("gap ", "") if len(f) > 6 else f[4].replace("step ", "") + ":" + f[5].replace("gap ", "")
        elif f[0] == "COH":
            seed, dy, y, pick, o0, age, ov, thr = int(f[1]), int(f[2]), int(f[3]), int(f[4]), int(f[5]), int(f[6]), int(f[7]), float(f[8])
            t22 = int(f[9]) if len(f) > 9 else -1
            lab = f[10] if len(f) > 10 else '-'
            o0, p0, a0 = (int(f[5]), int(f[11]), int(f[12])) if len(f) > 12 else (0, 0, 0)
            coh[(arm, rng_of(pick))].append((dy, y, age, ov, thr, seed, pick, t22, lab, o0, p0, a0))
            last_year[(arm, seed)] = max(last_year[(arm, seed)], y)

arms = sorted({k[0] for k in coh}, reverse=True)
ranges = ["1-10", "11-30", "31+"]
print("Mean OVR by age (drafted players still listed at season end; n in brackets for the 1-10 range)")
print("age | " + " | ".join("%s %s" % (a, r) for a in arms for r in ranges))
for age in range(18, 31):
    row = ["%d" % age]
    for a in arms:
        for r in ranges:
            xs = [x[3] for x in coh[(a, r)] if x[2] == age]
            row.append("%.1f (%d)" % (sum(xs) / len(xs), len(xs)) if len(xs) >= 8 else "-")
    print(" | ".join(row))
print("\nMean OVR by k = seasons since the draft (k=1 is the first season after the draft), listed drafted players")
print("k | " + " | ".join("%s %s" % (a, r) for a in arms for r in ranges))
for k in range(1, 8):
    row = ["%d" % k]
    for a in arms:
        for r in ranges:
            xs = [x[3] for x in coh[(a, r)] if x[1] - x[0] == k]
            row.append("%.1f (%d)" % (sum(xs) / len(xs), len(xs)) if len(xs) >= 8 else "-")
    print(" | ".join(row))
print("\nSeasons after the draft to first reach the league median best-22 OVR; share who ever do within %d seasons" % MIN_FOLLOW)
for a in arms:
    for r in ranges:
        by = collections.defaultdict(list)
        for dy, y, age, ov, thr, seed, pick, t22, lab, o0, p0, a0 in coh[(a, r)]:
            by[(seed, dy, pick)].append((y - dy, ov >= thr))
        n = ok = 0
        times = []
        for (seed, dy, pick), v in by.items():
            if last_year[(a, seed)] - dy < MIN_FOLLOW:
                continue
            n += 1
            hit = [t for t, h in v if h and t <= MIN_FOLLOW]
            if hit:
                ok += 1
                times.append(min(hit))
        times.sort()
        med = times[len(times) // 2] if times else float("nan")
        mean = sum(times) / len(times) if times else float("nan")
        print("%s %-5s n=%d ever %.0f%% median %s mean %.1f seasons" % (a, r, n, 100.0 * ok / max(1, n), med, mean))

print("\nShare of draftees in their own club's top 22 by OVR (a stand-in for 8+ games), seasons 1, 2, 3 after the draft; denominator = listed at season 1")
for a in arms:
    for r in ranges:
        rows = coh[(a, r)]
        n1 = sum(1 for x in rows if x[1] - x[0] == 1)
        out = []
        for k in (1, 2, 3):
            out.append("k%d %.0f%%" % (k, 100.0 * sum(1 for x in rows if x[1] - x[0] == k and x[7] == 1) / max(1, n1)))
        print("%s %-5s %s (n1=%d)" % (a, r, ", ".join(out), n1))

print("\nReadiness (draft-night label): share of class / of top 10, draft-night OVR and POT, age, OVR at k=1,2,3, share in own top 22 at k=1")
for a in arms:
    allrows = [x for r in ranges for x in coh[(a, r)]]
    if not any(x[8] != "-" for x in allrows):
        continue
    for lab in ("ready", "typical", "project"):
        seen = {}
        for x in allrows:
            if x[1] - x[0] == 1:
                seen[(x[5], x[0], x[6])] = x
        mine = [x for x in seen.values() if x[8] == lab]
        top = [x for x in seen.values() if x[6] <= 10]
        mt = [x for x in top if x[8] == lab]
        def m(k, f=3):
            xs = [x[f] for x in allrows if x[8] == lab and x[1] - x[0] == k]
            return sum(xs) / len(xs) if xs else float("nan")
        t1 = [x[7] for x in allrows if x[8] == lab and x[1] - x[0] == 1]
        print("%s %-8s class %.0f%% top10 %.0f%% | night OVR %.1f POT %.1f age %.1f | k1 %.1f k2 %.1f k3 %.1f | top22 at k1 %.0f%% (n=%d)" % (
            a, lab, 100.0 * len(mine) / max(1, len(seen)), 100.0 * len(mt) / max(1, len(top)),
            sum(x[9] for x in mine) / max(1, len(mine)), sum(x[10] for x in mine) / max(1, len(mine)), sum(x[11] for x in mine) / max(1, len(mine)),
            m(1), m(2), m(3), 100.0 * sum(t1) / max(1, len(t1)), len(mine)))
