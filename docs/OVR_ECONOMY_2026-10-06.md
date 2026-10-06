# Career-stage OVR economy: evidence (2026-10-06)

ROADMAP "Director follow-up: career-stage OVR economy" (ARD-M5-010,
BALANCE-GATED). This is measurement only; no ratings were changed.

- **Harness:** `tools/audit/ovr_economy_impl.gd` on branch `claude/ovr-economy-audit`.
- **Run:** Actions 37390953877, seed 4242.
- **Data:** the real 2026 lists at the start of a career, the real 2026 draft class, and generated classes 2028–2032.

## 1. OVR by career stage (real lists, start of a career)

"Games" means career AFL games, from the history file plus 2026.

| stage | n | OVR p10 | p50 | p90 | POT p50 |
|---|---|---|---|---|---|
| young (under 50 games) | 278 | 48 | 52 | 62 | 66 |
| early pro (under 24, 50+ games) | 50 | 54 | 65 | 85 | 76 |
| established (24–28, 50+ games) | 179 | 51 | **61** | 83 | 71 |
| veteran (29+, 50+ games) | 162 | 52 | 63 | 80 | 73 |

By role, established players have these OVR medians: MID 64, FWD 60, DEF 61, RUCK 65.

## 2. Draft classes, OVR / POT medians by pick

| class | picks 1–5 | picks 6–20 | picks 21–40 | picks 41+ |
|---|---|---|---|---|
| real 2026 | **70** / 92 | **64** / 84 | 59 / 74 | 52 / 62 |
| generated 2028 | 70 / 91 | 65 / 84 | 59 / 75 | 54 / 66 |
| generated 2029 | 66 / 84 | 62 / 79 | 58 / 72 | 54 / 65 |
| generated 2030 | 71 / 92 | 68 / 89 | 61 / 76 | 56 / 66 |
| generated 2031 | 70 / 91 | 65 / 84 | 59 / 74 | 55 / 67 |
| generated 2032 | 68 / 90 | 64 / 83 | 59 / 73 | 55 / 66 |

Generated picks 1–5 run from 66 to 73 (p10–p90), and picks 6–20 from 62 to 68.

## 3. Do new draftees outrank proven players?

This compares each draftee before any development against proven regulars:
established players aged 24–28 with 50+ career games and 15+ games in 2026.

- **Every top-10 pick (60 of 60) starts at or above the median established
  player's OVR (61).** A median pick 1–5 (OVR 70) sits in about the top
  quarter of established players.
- Against regulars of his own role, a top-10 pick is rated above **49%** of
  them on average (p90 60%). **24 of the 60 picks are above more than half.**
- Dropped into a club's list, a top-10 pick is rated above **6** of that club's
  roughly 14 established best-22 players at the median (p90 10).
- Picks 6–20 (median 64–65) also start above the established median.

## 4. Are established players compressed?

This is the rank correlation of OVR with a per-game production index among
established regulars. The index uses 2026 disposals, goals, marks, tackles,
clearances, inside 50s, rebounds, contested possessions and hit-outs.

| role | n | OVR p10–p90 | Spearman (OVR, production) |
|---|---|---|---|
| MID | 68 | 54–85 | 0.96 |
| RUCK | 19 | 52–80 | 0.88 |
| DEF | 96 | 58–79 | 0.57 |
| FWD | 62 | 55–86 | 0.29 |

The established range is wide (p90 83–86), so the top is not compressed. The
low FWD figure partly reflects the index: forwards' value is goals and
pressure, which a disposal-weighted index undercounts. The MID figure is
partly circular, because the index and the rating share their inputs. This
section is weaker evidence than sections 1–3.

## Reading

1. **The distortion is at the draft, not in established players.**
   - Established players' OVR is broad and follows production for midfielders
     and rucks.
   - New top picks start at 64–70 against an established median of 61.
   - This holds for the real 2026 class and for every generated class, so it
     comes from both the real draftee projection and the generated classes'
     starting OVR, which are shaped to match each other.
2. **The headroom is there in POT.** Picks 1–5 carry POT 90+, so their OVR
   can come down a lot without touching their ceiling. The ROADMAP requires
   that POT stays where it is.
3. **Elite ready-made prospects:** with every top-10 pick above the median
   established player, "visibly special" has no meaning today. If most picks
   start lower, the rare true AFL-ready prospect stands out.

## Recommendation (for the director: a balance decision)

- **Lower starting OVR for new draftees** (the real class's projection and
  generated classes alike), keeping POT and the development ceiling:
  - picks 1–5 to a median of about 60–62 (around the established median);
  - picks 6–20 to about 55–58;
  - later picks by less.
  - Keep the class's natural spread, so one or two genuinely ready
    prospects a year still start around 66–70.
- **Don't add a veteran bonus.** The established and veteran ranges aren't
  compressed. Weak veterans are weak because of their production, which is
  the behaviour the roadmap wants.
- **Before tuning, measure development.** Check how fast a lower-OVR pick
  climbs toward POT, so stars still emerge by years 3–5. Development depends
  on the gap between OVR and POT, so that check is needed first. Then re-check
  salary, draft AI, trade value and list turnover in a long-career audit
  (audit.yml).

## Not covered here

- Development curves after the draft (the next step above).
- Late-career decline.
- A better forward production index (goals, score involvements, pressure).
