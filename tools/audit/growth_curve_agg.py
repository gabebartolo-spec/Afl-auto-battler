"""Tables from growth_curve_impl logs: python -X utf8 -I tools/audit/growth_curve_agg.py <log> [<log> ...]
Percentiles are pooled across snapshots and seeds as n-weighted means of the per-snapshot figures."""
import sys, collections, math

arm = None
curve = collections.defaultdict(list)   # (arm, group, age) -> [(n, mean, med, p90, ge70, ge80)]
league = collections.defaultdict(list)  # (arm, season_no) -> [(mean, best23)]
band = collections.defaultdict(list)    # (arm, band) -> [(n, ovr0, ovr3)]
user = collections.defaultdict(list)    # (arm, season_no) -> [rank]
first_year = {}
for path in sys.argv[1:]:
    for line in open(path, encoding="utf-8", errors="replace"):
        f = line.strip().split("|")
        if f[0] == "GA":
            arm = "1.00:1.00" if len(f) < 6 else f[4].replace("step ", "") + ":" + f[5].replace("gap ", "")
        elif f[0] == "CURVE" and f[2] in ("start", "pre"):
            tag, year, grp, age, n = f[2], int(f[3]), f[4], int(f[5]), int(f[6])
            key = ("real" if tag == "pre" else arm, grp, age)
            if tag == "start" and (grp == "GEN" and year < 2029):
                continue
            if tag == "start" and grp == "ALL" and year < 2029:
                continue
            curve[key].append((n, float(f[7]), float(f[9]), float(f[11]), float(f[12]), float(f[13])))
        elif f[0] == "LEAGUE" and f[2] == "start":
            league[(arm, int(f[3]) - 2026)].append((float(f[5]), float(f[6])))
        elif f[0] == "BAND":
            band[(arm, f[3])].append((int(f[4]), float(f[5]), float(f[6])))
        elif f[0] == "USER":
            user[(arm, int(f[2]) - 2026)].append(int(f[3]))


def wavg(rows, i):
    n = sum(r[0] for r in rows)
    return sum(r[0] * r[i] for r in rows) / n if n else float("nan")


arms = sorted({k[0] for k in curve if k[0] != "real"})
print("age | real n med p90 >=70 >=80 | " + " | ".join("%s med p90 >=70 >=80" % a for a in arms) + "   (GEN = drafted classes 2027 on)")
for age in range(18, 31):
    r = curve.get(("real", "ALL", age))
    row = "%d | " % age
    row += ("%d %.0f %.1f %.2f %.2f" % (r[0][0], r[0][2], r[0][3], r[0][4], r[0][5])) if r else "-"
    for a in arms:
        g = curve.get((a, "GEN", age))
        al = curve.get((a, "ALL", age))
        if g and sum(x[0] for x in g) >= 20:
            row += " | GEN n%d %.1f %.1f %.2f %.2f" % (sum(x[0] for x in g), wavg(g, 2), wavg(g, 3), wavg(g, 4), wavg(g, 5))
        elif al:
            row += " | ALL n%d %.1f %.1f %.2f %.2f" % (sum(x[0] for x in al), wavg(al, 2), wavg(al, 3), wavg(al, 4), wavg(al, 5))
        else:
            row += " | -"
    print(row)
print("\nLeague mean OVR (all) / best-23 mean at start of season N; +/- is the SE over careers")
for a in arms:
    out = []
    for s in (1, 5, 10):
        v = league.get((a, s), [])
        if v:
            m = [x[0] for x in v]; b = [x[1] for x in v]
            se = lambda xs: (math.sqrt(sum((x - sum(xs) / len(xs)) ** 2 for x in xs) / max(1, len(xs) - 1)) / math.sqrt(len(xs)))
            out.append("S%d %.2f+/-%.2f best23 %.2f+/-%.2f (n=%d)" % (s, sum(m) / len(m), se(m), sum(b) / len(b), se(b), len(v)))
    print(a, "; ".join(out))
print("\nDraft pick value: OVR at pick -> 3 seasons on (generated classes, those still listed)")
for a in arms:
    out = []
    for b in ("1-10", "11-30", "31+"):
        v = band.get((a, b), [])
        if v:
            out.append("%s %.1f->%.1f (n=%d)" % (b, wavg(v, 1), wavg(v, 2), sum(x[0] for x in v)))
    print(a, "; ".join(out))
print("\nAutopilot user club mean ladder rank (AI v coach proxy, unmanaged)")
for a in arms:
    allr = [x for (aa, s), v in user.items() if aa == a for x in v]
    print(a, "%.1f (n=%d)" % (sum(allr) / max(1, len(allr)), len(allr)))
