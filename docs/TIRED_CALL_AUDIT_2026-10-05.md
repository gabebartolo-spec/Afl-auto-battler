# The tired-star call, end to end — 2026-10-05

Roadmap M4-001's smallest slice: take one existing match decision and check its whole chain (trigger, options, what is applied, how long it lasts, what follows and what the break reports). **Evidence only: nothing is tuned.**

Reproduce:

```
TIRED_REPS=8 godot --headless --path . --script tools/audit/run_audit.gd -- tired_impl
```

`tools/audit/tired_impl.gd`: 288 matches between neighbours in strength on four drafted leagues. You are at home riding the stars (the only rotation policy the call fires under); the opposition is an AI club picking its own plans. Every match is played twice from the same seed and sides: once resting the star, once keeping him on. Other moments take their default.

## The chain

| Step | What the code does | Verdict |
|---|---|---|
| Trigger | Under Ride the stars only, a star (OVR 80+) on the ground below 45 energy; once a match | Works as written. Fired in **88%** of matches, two in three of them in the second quarter, at 44 energy on average. |
| Options | "Rest him now" or "Keep him out there" (default) | Both are always feasible: rest never found an empty bench in 252 calls. |
| Application | Rest swaps him for a bench player at once; keep changes nothing | Applied exactly once. The paired runs are identical up to the call, and the same seed and answer replay exactly. |
| Duration | Not stated. A rested star comes back on through normal rotations once he is back to 85 energy; a kept star comes off anyway when he reaches 25 | Not explained on the card. |
| Consequence | Tiredness lowers his effective attributes | See below: the two answers barely differ. |
| Reflection | At the break: "*X* is running on empty: Rest him now. Rested. He will be back fresher." | Restates the choice and its outcome text; reports nothing that happened after it. |

## What follows each answer (252 matches where it fired)

| Answer | Win % | Margin from the call to the siren | His disposals after | His goals after | On at the siren |
|---|---|---|---|---|---|
| Rest him now | 59.9% | +4.2 | 8.3 | 0.33 | 91% |
| Keep him out there | 59.3% | +3.4 | 8.0 | 0.27 | 96% |

- **The call barely matters.** Resting is worth about 0.6 points of win rate and 0.8 points of margin: well inside noise at this sample. His own output after the call is almost the same either way.
- **Why:** both answers converge. Kept on, he comes off by himself at 25 energy; rested, he is back on once he recovers. Either way he spends a similar share of the rest of the match on the ground (91% vs 96% on at the siren).
- **It is routine, not a moment.** Riding the stars brings the call in nearly nine matches in ten, mostly in the second quarter.

## Copy against the engine

- "The freshest bench player takes his spot" — the engine prefers a bench player who fits his position, then the freshest. Close, but not exact.
- "He stays on and keeps tiring" — true until 25 energy, when rotations take him off anyway; the card does not say so.
- Neither answer says he will be back. The rested star nearly always returns.

## Findings for the director (nothing changed)

1. **A near-fake choice.** Under current rules Rest and Keep produce almost the same match. The research contract asks for "a football trade-off" with visible consequences. Options: make the trade-off real (a tired star costs more, or a rested one is gone for longer), drop the call, or keep it as flavour. **Your call.**
2. **No follow-through.** The break line should say what happened after the call (his disposals since, or who came on and what he did), not restate it. This is the M4-009 report's job, so it fits there rather than adding another panel.
3. **Copy corrections** above: small, factual, no rule change.
4. **Harness note.** Moments only fire when `moment_side` is set, which `MatchSim` leaves at −1 for simulated matches. Audits that want moment cards must set it (this one does).
