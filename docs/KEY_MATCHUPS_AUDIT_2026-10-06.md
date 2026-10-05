# Key forward v key defender (2026-10-06)

Roadmap §1.11, "Key-forward vs key-defender balance audit". The phone
impression was that good key forwards consistently get the better of good key
defenders.

**Defenders matter, and elite defenders do contain elite forwards. But at
equal quality the forward wins slightly more than half the contests, and the
full-time verdict turns that small edge into a two-way call ("beat" or "held")
on four or five contests. That's why the impression is one-sided.** Nothing is
changed here.

## Method

`tools/audit/kf_kd_impl.gd`: four drafted leagues (seeds 61–64), strength
neighbours paired, 12 seeds a pairing, both home orientations: 864 Sim-round
matches with AI plans on both sides and the default match-ups (each coach's
best key defender on the other side's best key forward). The script reads
`MatchSim.duel_log`, which records every named marking contest: who was on
whom, whether the forward marked, and whether a goal came of it.

Tiers use the engine's own aerial scores (`Matchups.forward_air` = 0.7
marking + 0.3 height; `defender_air` = 0.45 intercept + 0.30 marking + 0.25
height). They're split into thirds over everyone who appeared in a duel: 52
forwards and 140 defenders, 16,899 contests.

## Results

Overall the forward marks 50.2% of named contests (the engine centres the
default match-up there via `DUEL_CENTRE`), and 26.0% of contests produce a
goal.

**Forward mark rate in the named contest** (contests), forward tier down,
defender tier across:

| forward \ defender | elite | good | average |
|---|---|---|---|
| elite | 56.8% (4,816) | 65.3% (2,478) | 76.4% (487) |
| good | 44.4% (3,575) | 53.6% (1,298) | 62.2% (217) |
| average | 25.6% (2,391) | 44.4% (1,158) | 45.7% (479) |

**A key forward's whole match by the defender on him:** goals a match (named
contests a match):

| forward \ defender | elite | good | average |
|---|---|---|---|
| elite | 2.15 (4.6) | 2.28 (4.7) | 2.79 (4.1) |
| good | 1.68 (4.6) | 1.86 (4.6) | 2.12 (3.7) |
| average | 1.29 (4.7) | 1.47 (4.4) | 1.37 (3.7) |

**What the full-time line says** (one defender all match): forward beat /
even / defender held, % of matches:

| forward \ defender | elite | good | average |
|---|---|---|---|
| elite | 51 / 21 / 28 | 64 / 21 / 15 | 80 / 8 / 12 |
| good | 29 / 25 / 46 | 46 / 25 / 29 | 54 / 29 / 17 |
| average | 12 / 13 / 75 | 28 / 27 / 45 | 39 / 17 / 44 |

## Reading

- **Elite defenders genuinely contain.** Against an elite defender, an elite
  forward's mark rate falls from 76% (against an average defender) to 57%,
  and his goals from 2.79 to 2.15 a match (−23%). Down the elite-defender
  column, forward quality still tells (57% / 44% / 26%). Both acceptance
  points hold: elite forwards can still win games, and elite defenders can
  contain them.
- **Equal quality tilts slightly to the forward at the top:** elite v elite
  56.8%, good v good 53.6%, average v average 45.7%. The two scales are not
  the same shape. Forward air runs higher (median 74, top 94) than defender air
  (median 59, top 84), and the `DUEL_CENTRE` of 8 points centres the
  *default* pairing, not the best-v-best one. So the elite forwards (Thilthorpe
  94, McKay 90, Treacy 88) outscore the elite defenders (Andrews 84, Mac
  Andrew 83) by more than the centre allows for.
- **The match-up is not too infrequent to matter.** Named contests are about
  4.6 a match per key forward, or **18.8% of a side's inside 50s**. The
  roadmap's concern, from `KEY_TARGET = 0.06`, is out of date: entries that
  reach the forward in his contest are logged too, not only the targeted 6%.
- **Why it feels one-sided.** The full-time line
  (`MatchNotes._duel_line`) says the forward "beat" his man at 60%+ marked,
  "held" at 40% or less, and "an even battle" in between. With about 4–5
  contests, 3 of 5 already reads "beat" and 2 of 5 "held", so only 21–25% of
  equal match-ups read "even". At elite v elite the forward "beat" his man in
  51% of matches and the defender "held" him in 28%, nearly two to one, from a
  57/43 split of contests. That matches the playtest impression exactly.

## Options (not started; the second and third are director calls)

1. **Presentation only:** require a minimum number of contests before a
   verdict (say 6), and widen the even band for small samples. This would cut
   the overstated "beat" lines without touching the engine. `MatchNotes` was
   being edited in #233, so do this after that lands.
2. **Engine (BALANCE-GATED):** centre the best-v-best duel instead of the
   default pairing, for example by scaling `defender_air` to the forward scale
   or raising `DUEL_CENTRE` for elite pairs, so elite v elite sits near 50%.
   This moves key-forward goals and needs the usual scoring and Coleman checks.
3. **Leave the engine:** a small attacking edge in the air at the top is
   defensible football. If kept, option 1 alone addresses the impression.
