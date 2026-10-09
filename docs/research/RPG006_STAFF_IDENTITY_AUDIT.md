# RPG-006 audit: what a coaching staff's character does today

ROADMAP §9.4 RPG-006 asks to express coaching identity through existing staff
choices, and to "inspect live teaching/tactics/man-management effects and refine
demonstrated gaps only". This is the inspection, on `main` at `fa84f7be`
(2026-10-09). No game code changed.

## What the staff skills do (CoachEffects.gd)

| Skill | Effect | Range |
|---|---|---|
| Teaching | match XP for the players each coach teaches | x0.95 to x1.10 |
| Tactics | how much of a game plan's upside the side gets (`tactics_exec`); how sharply an AI club reads the match (`read`) | exec x0.81 to x1.25 |
| Man-management | how much of a dropped player's morale loss is spared | 0 to 40% |

## 1. Careers (tools/audit/staff_identity_impl.gd)

Eight League Draft careers (seeds 301 to 308), five seasons each, Melbourne on
autopilot. Each season your club's staff is given one character, and every other
club is left alone. Runs 37913506821 (base), 37913515051 (teach), 37913521303
(tactics), 37913530382 (manage), 37913536420 (fair).

| Staff | Young players' rating gain a season | List gain | Mean ladder | Mean margin | Morale at season end |
|---|---|---|---|---|---|
| As the world made it | +2.72 | +2.14 | 12.7 | -7.6 | 61.0 |
| Every coach an elite teacher (90) | +2.73 | +2.18 | 12.4 | -8.5 | 61.8 |
| Every coach an elite tactician (90) | +2.73 | +2.15 | 14.2 | -10.2 | 61.3 |
| Every coach an elite man-manager (90) | +2.72 | +2.15 | 12.8 | -7.6 | 65.2 |
| Every coach Fair in all three (60) | +2.71 | +2.13 | 13.2 | -8.5 | 61.8 |

Careers diverge after the first changed match, so ladder and margin differences
of a position or two are noise at eight seeds (a season's finish varies by about
four places). Development and morale are measured on the same players and are
much steadier.

## 2. One match, paired (tools/audit/tactics_pair_impl.gd)

Careers are too noisy to see a tactician, so the same matches were played twice
with the same seeds: the home side's tactics at the top of their range (exec 1.25,
read 1.0) and at the bottom (a vacant job: exec 0.81, read -0.75). Both sides pick
their own plans. Six pairings, 100 seeds each, run 37917514546.

| Pairing | Elite: home margin | Vacant: home margin | Paired difference |
|---|---|---|---|
| MEL v CAR | +38.3 | +36.0 | +2.4 ± 3.9 |
| GEE v COL | +5.5 | -0.9 | +6.4 ± 3.9 |
| SYD v WCE | +27.4 | +24.6 | +2.9 ± 4.4 |
| BRL v ADE | -30.9 | -26.9 | -4.0 ± 3.1 |
| HAW v ESS | +33.9 | +30.1 | +3.8 ± 3.4 |
| FRE v STK | +24.3 | +26.1 | -1.8 ± 3.9 |
| **All 600** | | | **+1.6 ± 1.6 points a match** |

Even a single changed number reshuffles the match after the first bounce, so pairs
are far from identical; 600 of them bound the effect at about two points a match.

## Findings

1. **Man-management is the only skill a coach would notice:** about four points
   of list morale. It is real and small, which suits a soft skill.
2. **Teaching is invisible.** An all-elite teaching staff develops young players
   by +0.01 a season more than the staff the world gives you, and +0.02 more than an
   all-Fair staff. A coach who hires teachers gets nothing he can see.
   **Cause:** training can add at most `SEASON_TRAIN_GAIN` = 3 rating points a
   season (`GameState.season_ceiling`), and young players already average +2.7
   in-season. Nearly every kid reaches the ceiling with or without good teachers,
   so the extra XP an elite staff gives (up to x1.10) has nowhere to go. Teaching
   only matters for players who would fall short of the ceiling.
3. **Tactics is nearly invisible too.** The best tactician against an empty job is
   worth about 1.6 points a match (± 1.6): a few percent of a win over a season,
   lost under everything else. A plan's upside is a small part of a match, and
   tactics only scales that part.
4. **No identity reaches the player.** Nothing tells you what kind of staff you
   have assembled, and the results would not bear it out if it did.

## Proposal (balance-gated: the director decides)

**Director decision, 2026-10-09:** teaching moves the training ceiling (the first
proposal below), same rule for AI clubs. Being built as RPG-006 slice 1.

- **Teaching:** let the staff move the ceiling, not the XP. For example, the
  season's training ceiling for a player becomes 3 plus up to 1 from his teachers
  (elite line and development coaches), and down to 2 with a vacant or poor staff.
  An elite teaching staff is then worth up to about a point a season per young
  player, which a coach can see in three seasons. AI clubs get the same rule. Re-run
  this audit to confirm, and the OVR-economy audit (#315), since it adds rating to
  the league.
- **Tactics:** not changed yet. If tactics should matter, the lever is the plan's
  upside itself (how much a well-run plan gives), which is a match-balance change
  needing its own calibration run; a director decision on its own.
- **Identity:** once the effects are real, the Coaching screen can name the staff's
  leaning in one line from the skills that are actually strongest ("A teaching
  staff: young players come on faster here."), a fact, not a rating.
- Re-run both audits on any change, with AI parity checked (rival clubs keep their
  own staff and the same rules).
