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

## Not exercised

- The managed-list bots settle contracts, chase free agents and trade. They
  don't set training plans, run development projects, choose matchups or
  backings, or select a side the way a person does. A real coach may already
  do better than the bots. These are the next things to measure.
- Expansion seasons (Tasmania 2028, Canberra 2030) are inside these careers
  but not reported separately.
- Real finals before 2026 were a top-8 bracket; the sim uses the 2026 wildcard
  top-10 bracket.
