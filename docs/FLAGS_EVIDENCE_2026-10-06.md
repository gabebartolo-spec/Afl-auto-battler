# Where flags come from, against real AFL (2026-10-06)

The director decided to make flags "a bit more reachable" (target from the
levers work: about one flag in 8–10 seasons for a club that works its list).
Before changing anything: is the league too random, so management can't turn
into flags, or is a managed club simply not strong enough? Measurement only.

## Method

- **Real AFL:** AFL Tables season pages, 2000–2025 (2020 left out: a
  17-round season). The premier's home-and-away ladder position, and how often
  the side that finished higher won a home-and-away game or a final (draws
  count half). Spread of season wins from `tools/balance/afl_ladders.json`
  (2013–2025).
- **Sim:** `tools/audit/flags_impl.gd`, run on GitHub (`audit.yml`, branch
  `claude/flags-evidence`, runs 37385419314–37385459433). There are 12 careers
  of 8 seasons each, 96 seasons in all, with seeds 1–12.
  - **The careers:** a League Draft, then real rollovers and National Drafts.
  - **The clubs:** every club, yours included, drafts and lists as the AI does.
  - **What it measures:** the same quantities as the real AFL column, plus the
    premier's preseason strength rank.

## Results

| | Real AFL | Sim |
|---|---|---|
| Premier finished 1st | 36% | 34% |
| Premier in the top 2 | 64% | 61% |
| Premier in the top 4 | 92% | 90% |
| Premier 5th or lower | 8% (worst 7th) | 10% (worst 10th, once) |
| Premier's mean ladder position | 2.24 | 2.44 |
| Side placed higher wins, home and away | 73% | 72.3% |
| Side placed higher wins, finals | 66.6% (226 finals) | 65.5% (1,056 finals) |
| SD of season wins across clubs | 4.34 | 4.43 |

**The league isn't too random.** Over a career, the clubs spread out as much
as real clubs do, and the ladder decides matches as reliably as it does in real
football. Finals convert ladder position into flags at real rates: a minor
premier wins it about a third of the time, and premiers come from the top four
nine times in ten.

The one gap is premiers from 3rd. The sim's top three win 77% of flags, real
AFL's 92%. But real AFL had no 4th-placed premier in those 25 seasons, and the
sim's top four match real at 90% vs 92%. That looks like small-sample shape,
not a mechanism.

The earlier finding that "24% of premiers come from 9th or lower" was about
**list strength rank before the season**, not ladder position. A club's
best-22 rating predicts its season less well than the ladder does.

## What this means for "more reachable"

From the sim's own conversion rates, flags per season by ladder finish are:
1st 34%, 2nd 27%, 3rd 16%, 4th 12%, 5th 8%, and 6th–10th about 2% between them.

- **Today:** a club that works contracts and free agency averages about
  6th–7th on the ladder ([managed vs autopilot](MANAGED_VS_AUTOPILOT_2026-10-06.md)).
  That's worth roughly 2–3% a season, or one flag in 30–40 seasons, as
  measured (0–3 in 40).
- **To reach one flag in 8–10 seasons** (10–12% a season), a well-run club has
  to average about **3rd–4th**.

So the lever is how high good management can lift a club, not finals or match
randomness. Changing finals or match variance would move the game away from
real football and would help every club equally.

## The coaching levers the bots don't pull (2026-10-06)

The managed-list bots don't select for synergies or run development projects,
so the first question was whether a coach who does those wins more.
`tools/audit/levers_coach_impl.gd` ran on GitHub (`audit.yml`, branch
`claude/flags-evidence`). It used eight League Draft careers (seeds 301–308)
of six seasons each, with your club coached on match day and working its
list. Each lever was switched on alone and then both together. This was
measured before 18 + 5.

| levers | mean ladder | top-four finishes (of 48) | flags (of 48) | paired change in ladder, ± standard error |
|---|---|---|---|---|
| none | 7.71 | 13 | 1 | – |
| synergy selection | 7.38 | 19 | 4 | −0.33 ± 1.20 |
| development projects | 7.67 | 15 | 0 | −0.04 ± 1.03 |
| both | 8.42 | 13 | 3 | +0.71 ± 0.97 |

**Neither lever lifts a club.** Every change is inside its error. To reach
about one flag in 8–10 seasons, a well-run club has to average 3rd–4th, about
four places better than today. A lever that strong would stand out clearly
here. A 16-career rerun on 18 + 5 (seeds 301–316) is running; its table will
replace this one.

## Options for the director: what could make management pay

The goal is that good management, not luck, gets a club to about 3rd–4th on
average. Each option below is a real football mechanism, not a hidden buff,
and each one would be measured with the same harness before it ships.

1. **Trade period at real volume (recommended).**
   - **Real AFL:** in 2024 there were about 33 trades. All 18 clubs made at
     least one, and 13 moved a player
     ([DraftGuru](https://www.draftguru.com.au/trades/year/2024)). That's
     roughly 1.4 player trades per club a year.
   - **The sim:** the trading bot completes about 0.1 a season, down from
     0.6 before #224's discount and #228's trade fixes
     ([managed v autopilot](MANAGED_VS_AUTOPILOT_2026-10-06.md)).
   - **The effect on flags:** at 0.6 trades a season, full management won 11
     flags in 40 seasons. Now it wins 3.
   - **The change:** the AI accepts fair deals often enough that a club
     working the trade period lands one or two a year. The aim is a club
     that trades well reaching about 3rd–4th, not 11 flags in 40.
   - **Why first:** it's the most realistic of the four, and the lever that
     has moved flags before.
2. **The recruiters' edge in the draft.**
   - **The change:** the AI drafts on the same noisy read of potential that
     your recruiters give you (#313). Investing in scouting narrows your read
     and not theirs.
   - **The effect:** rewards judgement, and pays off over three to five
     years.
   - **Caveat:** slow, so it does little for a coach's first flag.
3. **Development projects that change a career.**
   - **The change:** a player on a project grows more within his potential.
   - **The effect:** fits "the kid you backed".
   - **Risk:** it adds OVR to the league, which interacts with #315's OVR
     economy. Measure the two together.
4. **AI clubs that make real list mistakes.**
   - **The change:** AI clubs sometimes hold ageing stars too long or
     overpay, as real clubs do.
   - **The effect:** a club that manages well gains relative to the field.
   - **Risk:** it changes the whole league's shape, not just yours.

**Not recommended:**
- **Weighting synergies more.** That's a hidden coefficient, and selecting
  for synergies measured as no lift.
- **Making finals or matches more random.** The ladder already converts to
  flags at real rates (see above), so this would help every club equally and
  move the game away from real football.

## Not exercised

- The managed-list bots settle contracts, chase free agents and trade. They
  don't set training plans, run development projects, choose matchups or
  backings, or select a side the way a person does. A real coach may already
  do better than the bots. These are the next things to measure.
- Expansion seasons (Tasmania 2028, Canberra 2030) are inside these careers
  but not reported separately.
- Real finals before 2026 were a top-8 bracket; the sim uses the 2026 wildcard
  top-10 bracket.
