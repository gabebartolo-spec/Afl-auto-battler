# Play through, by job: audit evidence (2026-10-07)

PR #508. Measurement by `tools/audit/focus_impl.gd` on `audit.yml`; no rule was tuned from it.

## What changed

"Play through" reads the slot the player fills (the same slot the coach box names):

| Job | In the engine |
|---|---|
| Forward ("our key forward target") | The carrier bias up forward (attack and inside-50 picks, x1.14) and a shooter bias when the shot is taken (x1.25) |
| Midfielder, ruck | The carrier bias in every chain (x1.14); no shooter bias (ARD-M1-003 stands) |
| Defender ("our key distributor") | A carrier bias in the back zone only (x1.25): first use of the ball out of the back half. No quality modifier |

## Method

Real 2026 club lists, the home side rotating through the 18 clubs. Each match is played once with no focus and once per arm with the same seed and one player played through on side 0, so the comparison is that player's own line (and side 0's team line) with and without the call. 1,000 matches per arm (four batches of 250, seeds 1000, 2000, 3000, 4000; best/worst batches 5000 to 8000). A match with no such player on the ground is skipped for that arm (776 of 1,000 had a defender 183 cm or under). Back-half disposals are own-half disposals, counted by an audit subclass watching the carrier pick (a kick-in is always from the back half). The focused match is a different match once a pick changes, so team lines carry match noise: the standard error is shown.

Arms: the best-kicking key forward (192 cm+); the best contested-ball midfielder not on a wing; the best user of the ball (disposal + carry) among defenders 183 cm and under; the same among defenders 190 cm and over; then the best and the weakest user among all defenders.

## Results (a game, no focus to focus)

| | Fwd, key | Mid, inside | Def, small | Def, key |
|---|---|---|---|---|
| Shots | 3.24 to 3.75 (+16%, z 8.5) | 1.00 to 0.98 (flat) | 0.15 to 0.15 | 0.08 to 0.09 |
| Goals | 1.98 to 2.29 | 0.54 to 0.54 | 0.09 to 0.09 | 0.05 to 0.06 |
| Disposals | 7.4 to 8.0 (+8%) | 28.4 to 30.3 (+7%, z 19) | 23.7 to 26.1 (+10%) | 20.5 to 23.3 (+13%) |
| Back-half disposals | 1.85 to 1.81 | 15.4 to 16.0 | 19.5 to 21.8 (+12%) | 18.7 to 21.5 (+15%) |
| Own metres gained | 54 to 59 | 301 to 321 | 244 to 267 | 166 to 189 |
| Team score | 88.3 to 88.3 (se 0.7) | 88.3 to 87.6 | 87.6 to 87.6 | 88.3 to 87.6 |
| Team metres gained | 3375 to 3372 | 3375 to 3365 | 3362 to 3369 | 3375 to 3369 |
| Team clangers | 54.5 to 54.4 | 54.5 to 54.3 | 54.0 to 54.1 | 54.5 to 54.2 |
| Team ineffective disposals | 78.0 to 78.0 | 78.0 to 77.9 | 78.1 to 77.9 | 78.0 to 78.1 |

What it shows:

- **Forward:** shots up 16% (z 8.5), goals up in step, team score unchanged (se 0.7): the shots are redistributed to him, not added.
- **Midfielder:** disposals up 7%, inside 50s up 5%, shots flat. He is not made the shooter.
- **Both defenders:** back-half disposals up (+12% small, +15% key). Each extra disposal gains about the metres he usually gains (small 9.5 m, key 8.3 m).
- **Small against key:** the small defender gains more ground per disposal (10.3 m against 8.1 m before the call) and the team gain is a little better (+7 m against -5 m), but that is inside the noise (se about 9 m), and the key defender is the cleaner user (85.5% effective against 84.3%). The sim does not show a team-level difference from the defender's size.

## Does a clean user make the most of it?

Best and weakest defender on the ground, same call (1,000 matches each):

| | Best user | Weakest user |
|---|---|---|
| Back-half disposals | 20.9 to 23.4 | 17.8 to 20.6 |
| Effective disposal rate | 84.4% to 84.0% | 85.8% to 85.7% |
| Own metres per disposal | 10.75 to 10.59 | 6.86 to 6.88 |
| Team metres gained | 3395 to 3394 | 3395 to 3378 (z -2.2) |
| Team inside 50s | 55.9 to 55.1 (z -3.1) | 55.9 to 55.7 |

Giving first use to a poor user costs the side a little ground (about 17 m, 0.5%); giving it to a good user costs nothing but does not add either (and takes about 0.7 inside 50s from the midfielders who would have delivered). The audit does not show a gain from a clean user, so the coach box does not say one.

## Not exercised

- Only the focus on side 0 against the club AI's own plans; no tags, pep or plans of mine.
- One focused player at a time. Two playing-through calls in a match are not a call.
- Quarter-by-quarter changes of focus: the focus is set before the match and held.
- A forward's shot bias also applies to the pack-mark pick in a bomb (`_bomb`), by design; its share of shots is small.
