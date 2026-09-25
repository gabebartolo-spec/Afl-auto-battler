#!/usr/bin/env python3
"""Draft-quality inspection for draft shards (tools/balance/draft_experiment.gd
--mode draft). Measurement only.

Every pick is compared with the shared (consensus) ranking of the pool by
Draft._worth, the value every club saw before club-specific evaluation.
A reach is a player taken well before his consensus rank; a fall is a player
taken well after it.

  python3 tools/balance/draft_quality.py d_eval_off_ai.json d_current_ai.json [--md out.md]
"""
import json
import statistics as st
import sys


def quality(path):
    d = json.load(open(path))
    leagues = d["leagues"]
    n_clubs = len(leagues[0]["units"])
    r1_dev, r1_max_reach, r1_max_fall = [], [], []
    top10_ranks = []
    elite_fall = []          # pick at which each consensus top-10 player went
    reach_2rounds = 0        # picks in rounds 1-3 taken 2+ rounds early
    fall_2rounds = 0         # consensus top-54 players falling 2+ rounds
    worst_reach, worst_fall = 0, 0
    undrafted_best = []
    max_rucks = 0
    ovr_top18 = []           # overall of round-one picks
    for lg in leagues:
        picks = lg["picks"]
        for pk, club, pid, role, ovr, rank in picks:
            rnd = (pk - 1) // n_clubs + 1
            if rnd == 1:
                r1_dev.append(abs(rank - pk))
                r1_max_reach.append(rank - pk)
                r1_max_fall.append(pk - rank)
                ovr_top18.append(ovr)
            if pk <= 10:
                top10_ranks.append(rank)
            if rank <= 10:
                elite_fall.append(pk)
            if rnd <= 3 and rank - pk >= 2 * n_clubs:
                reach_2rounds += 1
            if rank <= 3 * n_clubs and pk - rank >= 2 * n_clubs:
                fall_2rounds += 1
            if rnd <= 3:
                worst_reach = max(worst_reach, rank - pk)
            if rank <= 3 * n_clubs:
                worst_fall = max(worst_fall, pk - rank)
        undrafted_best.append(min(lg["undrafted"]) if lg["undrafted"] else 0)
        for c in lg["units"].values():
            max_rucks = max(max_rucks, c["roles"]["RUCK"])
    n = len(leagues)
    return {
        "variant": d["variant"], "leagues": n,
        "r1_mean_dev": st.mean(r1_dev), "r1_reach": max(r1_max_reach), "r1_fall": max(r1_max_fall),
        "top10_rank_mean": st.mean(top10_ranks), "top10_rank_max": max(top10_ranks),
        "elite_pick_mean": st.mean(elite_fall), "elite_pick_max": max(elite_fall),
        "reach_2r": reach_2rounds / n, "fall_2r": fall_2rounds / n,
        "worst_reach": worst_reach, "worst_fall": worst_fall,
        "undrafted_best": min(undrafted_best), "max_rucks": max_rucks,
        "r1_ovr_min": min(ovr_top18),
    }


def main():
    args = sys.argv[1:]
    out_md = None
    if "--md" in args:
        out_md = args[args.index("--md") + 1]
        args = args[:args.index("--md")]
    rows = [quality(p) for p in args]
    md = ("| Draft | Leagues | Round 1: mean abs(rank - pick) | Round 1: biggest reach / fall | "
          "Picks 1-10: mean (max) consensus rank | Consensus top-10: mean (latest) pick | "
          "2-round reaches in rounds 1-3 per draft | 2-round falls of top-54 per draft | "
          "Worst reach (rounds 1-3) / fall (top-54) | Best undrafted rank | Most rucks on a list | "
          "Lowest round-1 OVR |\n|---|---|---|---|---|---|---|---|---|---|---|---|\n")
    for r in rows:
        md += "| %s | %d | %.1f | %d / %d | %.1f (%d) | %.1f (%d) | %.2f | %.2f | %d / %d | %d | %d | %d |\n" % (
            r["variant"], r["leagues"], r["r1_mean_dev"], r["r1_reach"], r["r1_fall"],
            r["top10_rank_mean"], r["top10_rank_max"], r["elite_pick_mean"], r["elite_pick_max"],
            r["reach_2r"], r["fall_2r"], r["worst_reach"], r["worst_fall"], r["undrafted_best"],
            r["max_rucks"], r["r1_ovr_min"])
    print(md)
    if out_md:
        open(out_md, "w").write(md)


if __name__ == "__main__":
    main()
