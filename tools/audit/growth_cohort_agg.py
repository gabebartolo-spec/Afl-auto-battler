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
            arm = f[6].replace("night ", "n") + " " + f[4].replace("step ", "") + ":" + f[5].replace("gap ", "") if len(f) > 6 else f[4].replace("step ", "") + ":" + f[5].replace("gap ", "")
        elif f[0] == "COH":
            seed, dy, y, pick, o0, age, ov, thr = int(f[1]), int(f[2]), int(f[3]), int(f[4]), int(f[5]), int(f[6]), int(f[7]), float(f[8])
            coh[(arm, rng_of(pick))].append((dy, y, age, ov, thr, seed, pick))
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
        for dy, y, age, ov, thr, seed, pick in coh[(a, r)]:
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
