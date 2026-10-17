#!/usr/bin/env python3
"""P-81 "List churn stays real": read the CHURN lines of tools/audit/list_churn_impl.gd
runs and write docs/research/LIST_CHURN_AUDIT_<date>.md.

  gh run download <run-id> -n audit-list_churn_impl -D run_<run-id>     (one per dispatch)
  python3 tools/audit/list_churn_agg.py --date 2026-10-18 --runs 123,124 \
      --out docs/research/LIST_CHURN_AUDIT_2026-10-18.md run_*/audit.log

Your own club is on autopilot too and is left out (user=1): the audit is about
the AI clubs. Measurement only: it flags, it does not tune anything.
"""
import argparse
import re
import statistics
import sys
from collections import defaultdict

LOW, HIGH = 8, 12   # the real yardstick, list changes a club a year
PARTS = ["delisted", "walked", "retired", "traded_out", "drafted", "traded_in", "signed"]
LINE = re.compile(r"^CHURN seed (\d+) year (\d+) club (\w+) user (\d) \| before (\d+) after (\d+) \| "
                  r"delisted (\d+) walked (\d+) retired (\d+) traded_out (\d+) \| "
                  r"drafted (\d+) traded_in (\d+) signed (\d+) \| out (\d+) in (\d+)(?: \| kept (\d+))?")


def pct(vals, p):
    v = sorted(vals)
    if not v:
        return 0.0
    k = (len(v) - 1) * p
    lo = int(k)
    hi = min(lo + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (k - lo)


def read(paths):
    rows = []
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                m = LINE.match(line.strip())
                if not m:
                    continue
                g = m.groups()
                rows.append({"seed": int(g[0]), "year": int(g[1]), "club": g[2], "user": int(g[3]),
                             "before": int(g[4]), "after": int(g[5]),
                             "delisted": int(g[6]), "walked": int(g[7]), "retired": int(g[8]), "traded_out": int(g[9]),
                             "drafted": int(g[10]), "traded_in": int(g[11]), "signed": int(g[12]),
                             "out": int(g[13]), "in": int(g[14]), "kept": int(g[15] or 0)})
    return rows


def stats_row(vals):
    return "%.1f | %d | %.1f | %.1f | %.1f | %d" % (statistics.mean(vals), min(vals), pct(vals, 0.1),
                                                     statistics.median(vals), pct(vals, 0.9), max(vals))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logs", nargs="+")
    ap.add_argument("--out", required=True)
    ap.add_argument("--date", required=True)
    ap.add_argument("--runs", default="", help="CI run ids the logs came from, for the doc")
    a = ap.parse_args()

    rows = [r for r in read(a.logs) if r["user"] == 0]
    if not rows:
        print("no CHURN lines")
        return 1
    seeds = sorted({r["seed"] for r in rows})
    years = sorted({r["year"] for r in rows})
    clubs = sorted({r["club"] for r in rows})
    n = len(rows)

    inside = sum(1 for r in rows if LOW <= r["out"] <= HIGH)
    below = sum(1 for r in rows if r["out"] < LOW)
    above = sum(1 for r in rows if r["out"] > HIGH)

    L = []
    L.append("# List churn audit, %s" % a.date)
    L.append("")
    L.append("P-81 \"List churn stays real\" (proposals pass 2, director yes 2026-10-18). Does an AI club move on and bring in about as many "
             "players a year as a real AFL club? Measurement only: the audit reports, the director decides (design bible: balance is his call).")
    L.append("")
    L.append("## Method")
    L.append("")
    L.append("- `tools/audit/list_churn_impl.gd` run through `audit.yml` (CI run%s %s). %d seeded careers (seeds %s), %d off-seasons each (%d to %d), "
             "on autopilot: the League Draft, each season played with `advance()`, each off-season run by the calls the game makes "
             "(contracts, free agency, trades between rivals, the national draft, the rollover), no management of any list."
             % ("s" if "," in a.runs else "", a.runs or "see the PR", len(seeds), ", ".join(str(s) for s in seeds),
                len(years), years[0], years[-1]))
    L.append("- Each club's list is compared from the last week of the season to the new season's list. A player who left is a retirement, "
             "a trade (named in the off-season log), a walk (the club wanted him but could not fit him) or a delisting; one who arrived is a "
             "draftee, a trade or a free-agent signing. A player released into the market and back on the same club's list is not a change "
             "and is left out of both columns.")
    L.append("- Your own club is on autopilot like the others, but it is left out. Counted: %d AI club-years (%d clubs)." % (n, len(clubs)))
    L.append("")
    L.append("## The yardstick")
    L.append("")
    L.append("**Real AFL: roughly %d to %d list changes a club a year** (the brief for this audit, from the director's pass-2 candidate C-PC-23). "
             "The audit compares **players leaving a club in a year** (retired + delisted + walked + traded out) with that range, and shows "
             "players arriving (drafted + traded in + signed) beside it." % (LOW, HIGH))
    L.append("")
    L.append("Cross-check from the Wikipedia draft pages for 2021 to 2025 (`<year> AFL draft`, \"List changes\" and \"Trades\" tables), "
             "counted by table rows on 2026-10-18; the pages are uneven (the 2023 delistings table is not a table, 2025 has no free-agency table), so "
             "these are rough:")
    L.append("")
    L.append("| Year | Delistings | Retirements | Trades (deals) | National draft picks | Exits a club from delistings and retirements alone |")
    L.append("|---|---|---|---|---|---|")
    L.append("| 2021 | 94 | 9 | 10 | not counted | %.1f |" % ((94 + 9) / 18))
    L.append("| 2022 | 89 | 36 | 19 | 61 | %.1f |" % ((89 + 36) / 18))
    L.append("| 2024 | 62 | 31 | 32 | 73 | %.1f |" % ((62 + 31) / 18))
    L.append("| 2025 | 48 | 26 | 29 | 62 | %.1f |" % ((48 + 26) / 18))
    L.append("")
    L.append("So a real club loses about 5 to 7 players a year to delisting and retirement, plus 1 to 3 to trades, which is how the "
             "8 to 12 comes about. Players arriving are a similar number (about 4 draft picks, 1 to 3 trades, a few free agents and rookies). "
             "The page counts leave out the rookie list and mid-season changes. The 8 to 12 range is the lead's figure; this table is only a "
             "check that it is the right size, not a second yardstick.")
    L.append("")
    L.append("## Result")
    L.append("")
    L.append("Players leaving, per AI club per year (%d club-years):" % n)
    L.append("")
    L.append("| | Mean | Min | 10th pct | Median | 90th pct | Max |")
    L.append("|---|---|---|---|---|---|---|")
    L.append("| **Leaving (out)** | " + stats_row([r["out"] for r in rows]) + " |")
    L.append("| **Arriving (in)** | " + stats_row([r["in"] for r in rows]) + " |")
    for k in PARTS:
        L.append("| %s | " % k.replace("_", " ") + stats_row([r[k] for r in rows]) + " |")
    L.append("| list size after | " + stats_row([r["after"] for r in rows]) + " |")
    L.append("")
    L.append("Club-years with players leaving inside %d to %d: **%d of %d (%.0f%%)**; below %d: %d (%.0f%%); above %d: %d (%.0f%%)."
             % (LOW, HIGH, inside, n, 100.0 * inside / n, LOW, below, 100.0 * below / n, HIGH, above, 100.0 * above / n))
    L.append("")
    L.append("### By off-season (mean over the AI clubs and seeds)")
    L.append("")
    L.append("| Year | Out | In | Delisted | Walked | Retired | Traded out | Drafted | Traded in | Signed |")
    L.append("|---|---|---|---|---|---|---|---|---|---|")
    for y in years:
        sub = [r for r in rows if r["year"] == y]
        L.append("| %d | %.1f | %.1f | %s |" % (y, statistics.mean(r["out"] for r in sub), statistics.mean(r["in"] for r in sub),
                                               " | ".join("%.1f" % statistics.mean(r[k] for r in sub)
                                                          for k in ["delisted", "walked", "retired", "traded_out", "drafted", "traded_in", "signed"])))
    L.append("")
    L.append("### By club (mean over seeds and years)")
    L.append("")
    L.append("| Club | Years | Out | In | Out 10th..90th pct | Flag |")
    L.append("|---|---|---|---|---|---|")
    flagged = []
    for c in clubs:
        sub = [r for r in rows if r["club"] == c]
        mo = statistics.mean(r["out"] for r in sub)
        mi = statistics.mean(r["in"] for r in sub)
        flag = "below %d" % LOW if mo < LOW else ("above %d" % HIGH if mo > HIGH else "")
        if flag:
            flagged.append((c, mo, flag))
        outs = [r["out"] for r in sub]
        L.append("| %s | %d | %.1f | %.1f | %.0f..%.0f | %s |" % (c, len(sub), mo, mi, pct(outs, 0.1), pct(outs, 0.9), flag))
    L.append("")
    L.append("## Flags")
    L.append("")
    if flagged:
        L.append("%d of %d AI clubs have a mean of players leaving outside %d to %d a year: %s."
                 % (len(flagged), len(clubs), LOW, HIGH, ", ".join("%s (%.1f, %s)" % f for f in flagged)))
    else:
        L.append("No AI club's mean of players leaving is outside %d to %d." % (LOW, HIGH))
    L.append("")
    L.append("Seeds that ran: %s." % ", ".join(str(s) for s in seeds))
    L.append("")
    L.append("## Not exercised")
    L.append("")
    L.append("- A coach who works the list: your club is on autopilot like the others and is excluded, so trades you start, offers you accept and "
             "players you re-sign or let go are not in these numbers.")
    L.append("- Only the off-season list moves: the rookie and pre-season drafts, the mid-season draft, Category B rookies and in-season signings do not exist in the game, "
             "so the real figures above are bigger than the comparable part.")
    L.append("- The real yardstick is a range from the brief and rough page counts, not a season-by-season table for every club; one real club's year "
             "(a rebuild, a premiership list) can sit well outside it.")
    L.append("- Careers of 10 seasons from the real 2026 lists: how churn changes over 20 or more seasons is not measured here (see `long_career_impl`).")
    L.append("- Nothing here says what the right amount is for the game: that is the director's call.")
    L.append("")
    with open(a.out, "w", encoding="utf-8") as f:
        f.write("\n".join(L))
    print("wrote", a.out, "club-years", n, "mean out %.1f in %.1f" % (statistics.mean(r["out"] for r in rows), statistics.mean(r["in"] for r in rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
