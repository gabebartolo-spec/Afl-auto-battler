# Extreme margins: how often, and what compounds them (2026-10-06)

Roadmap §9.1, "Extreme-margin calibration — BALANCE-GATED". Measurement only;
**no tuning is indicated.**

**Headline.** Blowouts are rarer than in real AFL. 100+ margins come in 0.55%
of drafted-league home-and-away matches against a real-AFL reference of about
1.9% (§1.11), and none reached 150. Momentum is the main compounder of the
tail: with it switched off, 100+ margins fall by about 60%, and the strongest
list's 100+ wins disappear. Synergies trim the tail a little; club form adds
nothing.

## Method

`tools/audit/extreme_margins_impl.gd` (branch `claude/extreme-margins`, run
on GitHub via `audit.yml`). It plays 16 drafted leagues (seeds 21–36), one
home-and-away season each, as `Season.play_round` plays it: 3,456 matches per
run. `EXM_VARIANT` switches one factor off in **every** match, on identical
seeds:

- `syn`: both sides' synergies
- `momentum`: `momentum_edge` 0
- `form`: both sides' club form 0
- `all`: all three
- `base`: nothing

The variants' tails are then compared.

Why not replay only the biggest wins with a factor switched off? Any change
re-rolls the match, so selected blowouts regress to an ordinary margin
whatever is removed. A smoke test showed it: the one no-op variant
(`plans`, which changes nothing outside a career) kept every blowout, while
every real change "removed" 40–60 points. The paired all-matches design
avoids that selection bias.

## Results

| variant | 80+ | 100+ | 120+ | 150+ | mean margin | p99 | max | strongest list's 100+ |
|---|---|---|---|---|---|---|---|---|
| base | 1.88% (65) | 0.55% (19) | 0.06% (2) | 0 | 27.4 | 92 | 132 | 1.56% (6 of 384) |
| synergies off | 1.74% (60) | 0.43% (15) | 0.03% (1) | 0 | 25.9 | 87 | 126 | 0.78% (3) |
| momentum off | 1.82% (63) | 0.20% (7) | 0.03% (1) | 0 | 26.6 | 86 | 122 | 0 |
| form off | 2.17% (75) | 0.49% (17) | 0.06% (2) | 0 | 27.2 | 91 | 125 | 1.30% (5) |
| all off | 1.22% (42) | 0.12% (4) | 0 | 0 | 24.9 | 81 | 119 | 0 |

Base, by the strength-rank gap between the sides: gap 0–4 had 100+ in 0.50%
of matches, gap 5–9 in 0.24%, and gap 10–17 in 1.10%. Mismatches produce more
of the tail, as they should. The biggest team score was 176, the most goals by
one player 10, and the most disposals 37.

**Careers drift wider.** Across managed and autopilot five-season careers
(9,464 matches per policy, `MANAGED_VS_AUTOPILOT_2026-10-06.md`), 100+ was
0.48–0.63% and 150+ appeared once or twice in 9,000+ matches. The autopilot
#217 rerun saw a 158. Lists drift apart over years, but the tail stays thin.

## Reading

- **Frequency:** 100+ margins sit at roughly a third of the real-AFL rate,
  and 150+ is near-absent. The roadmap asks to preserve rare massacres and
  prevent routine runaway percentage farming. Farming isn't happening; if
  anything the massacre end is underweight.
- **Compounding:** momentum is the factor that turns a big win into a
  blowout. That's by design: a capped, fading run-on edge, real AFL
  behaviour. Synergies contribute a little (they're now rarer, after #263).
  Form doesn't contribute.
- **Sample:** 7–19 matches at 100+ per variant, so these are directional. A
  larger run is cheap on `audit.yml` (`EXM_DRAFTS`) if the director wants
  firmer rates.
- **No change recommended.** If the director wants more massacres for
  realism, momentum's edge is the lever, and that would be its own
  balance-gated item.
