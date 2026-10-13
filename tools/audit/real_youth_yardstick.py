"""Real-AFL yardstick for youth growth, from data/player_history_2026.csv (draft pedigree + the game's own rating
for each 2021-25 season with 8+ games; built from AFL Tables). Run: python -X utf8 -I tools/audit/real_youth_yardstick.py
By draft range and k = seasons since the draft (k=1 is the first season after the national draft):
n draftees with that season in range, share with a rated season (8+ games), mean rating of those who have one.
Bias to name: only players still listed in 2026 are in the file, and only 2021-25 seasons are rated."""
import csv, collections
rows = list(csv.DictReader(open("data/player_history_2026.csv", encoding="utf-8")))
rng = lambda p: "1-10" if p <= 10 else "11-30" if p <= 30 else "31+"
acc = collections.defaultdict(lambda: [0, 0, 0.0])
for r in rows:
    if r["draft_type"] != "national" or not r["draft_pick"]:
        continue
    dy, pk = int(r["draft_year"]), int(r["draft_pick"])
    rated = {int(s.split(":")[0]): (int(s.split(":")[1]), int(s.split(":")[2])) for s in r["seasons"].split(";") if s}
    for k in range(1, 8):
        y = dy + k
        if y < 2021 or y > 2025:
            continue
        a = acc[(rng(pk), k)]
        a[0] += 1
        if y in rated:
            a[1] += 1
            a[2] += rated[y][0]
print("range k n  share_rated  mean_rating_of_rated")
for R in ("1-10", "11-30", "31+"):
    for k in range(1, 8):
        n, m, t = acc[(R, k)]
        if n >= 8:
            print("%-5s %d %3d  %3.0f%%  %s" % (R, k, n, 100 * m / n, "%.1f" % (t / m) if m else "-"))
