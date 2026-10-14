"""Aggregate draft_bust_impl logs: python -I tools/audit/draft_bust_agg.py <dir of logs>

Per pick band (1-10, 11-30, 31+) and class source (generated, real 2026):
  75+      best OVR within 5 seasons of the draft reached 75+
  short    5 seasons on, still on a list and 10 or more under his draft-day POT
  lost     off every list at the 4th, 5th AND 6th season end after the draft
           (a single season end can catch a rookie between contracts: he is
           off a list when his deal runs out, then signed again; only a player
           who stays off for three season ends in a row is counted as lost)
Only picks with the full follow-up (6 season ends) are used for "lost"; the
other two columns use picks with 5. AI clubs' picks only (the unmanaged user
club is dropped).
"""
import glob
import os
import sys
from collections import defaultdict


def band(pick):
    return "1-10" if pick <= 10 else ("11-30" if pick <= 30 else "31+")


def main(folder):
    picks = {}      # (seed, id) -> dict
    track = {}      # (seed, id, k) -> (on, ovr, best)
    for f in glob.glob(os.path.join(folder, "**", "*"), recursive=True):
        if not os.path.isfile(f):
            continue
        for line in open(f, errors="replace"):
            line = line.strip()
            if line.startswith("BP|"):
                _, seed, dy, pick, pid, club, src, age, o, pot = line.split("|")
                if club == "USER":
                    continue
                picks[(seed, pid)] = dict(year=int(dy), pick=int(pick), src=src, ovr0=int(o), pot0=int(pot), age0=float(age))
            elif line.startswith("BT|"):
                _, seed, dy, k, pid, on, ovr, best = line.split("|")
                track[(seed, pid, int(k))] = (int(on), int(ovr), int(best))
    rows = defaultdict(lambda: defaultdict(int))
    sums = defaultdict(lambda: defaultdict(float))
    for (seed, pid), p in picks.items():
        key = (p["src"], band(p["pick"]))
        t5 = track.get((seed, pid, 5))
        t6 = track.get((seed, pid, 6))
        if t5 is None:
            continue
        r = rows[key]
        r["n"] += 1
        on5, ovr5, best5 = t5
        sums[key]["ovr0"] += p["ovr0"]
        sums[key]["pot0"] += p["pot0"]
        if on5:
            sums[key]["ovr5"] += ovr5
            r["listed5"] += 1
            if ovr5 <= p["pot0"] - 10:
                r["short"] += 1
        if best5 >= 75:
            r["star"] += 1
        if t6 is not None:
            r["n6"] += 1
            if all(track.get((seed, pid, k), (1,))[0] == 0 for k in (4, 5, 6)):
                r["lost"] += 1
    print("| Class | Pick band | Picks followed | OVR at pick | POT at pick | OVR 5 seasons on (listed) | Reached 75+ | 10+ short of POT (of those listed) | Lost to the league (off every list 3 season ends running) |")
    print("|---|---|---|---|---|---|---|---|---|")
    for key in sorted(rows):
        r = rows[key]
        n = r["n"]
        l5 = max(1, r["listed5"])
        lost = "%.0f%% of %d" % (100.0 * r["lost"] / r["n6"], r["n6"]) if r["n6"] else "-"
        print("| %s | %s | %d | %.1f | %.1f | %.1f | %.0f%% | %.0f%% | %s |" % (
            "generated" if key[0] == "gen" else "real 2026", key[1], n, sums[key]["ovr0"] / n, sums[key]["pot0"] / n,
            sums[key]["ovr5"] / l5, 100.0 * r["star"] / n, 100.0 * r["short"] / l5, lost))
    print("\ncareers:", len({s for s, _ in picks}))


if __name__ == "__main__":
    main(sys.argv[1])
