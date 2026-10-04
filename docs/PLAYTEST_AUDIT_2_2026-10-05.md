# Playtest audits, part 2 — 2026-10-05

Three VERIFY findings from the 2026-10-04 multi-season phone playtest (roadmap §9.1), measured on `main` at `abbfe94`. Reproduce with `godot --headless --path . --script tools/audit/run_audit.gd -- <name>`, where `<name>` is `style_drafted_impl`, `roles_impl` or `staff_impl`.

---

## 1. "How we get beaten" not learning

**Finding:** halfway through a season the Coaching panel could still say "Nothing stands out yet."

### How it works

`GameState._style_found` reports a stat only when the club's per-game difference from the league average, shrunk by games / (games + 4), clears a per-stat minimum (`STYLE_MIN`, documented as about one club-to-club spread). Points-source lines are never set under a goal (the materiality fix in #146).

### Measurement: four career-style drafted leagues (`tools/balance`), all clubs

| Round | Top 6 with a "beaten" line | Mid-table | Bottom 6 |
|---|---|---|---|
| 6 | 5/24 | 7/24 | 21/24 |
| 12 | 4/24 | 10/24 | 18/24 |
| 18 | 8/24 | 7/24 | 19/24 |
| 24 | 5/24 | 11/24 | 16/24 |

Club-to-club spread at Round 12 against each minimum (MIN/SD; about 1 is the documented intent):

| Stat | MIN / SD |
|---|---|
| for, against, clearances, inside 50s, stoppage points both ways | 0.7–1.0 |
| pressure acts, marks, clangers | 1.2–1.3 |
| hit-outs | 1.6 |
| points from turnovers | 4.0 |
| points conceded on turnovers | 2.9 |

### Conclusion

The panel does learn: weak sides are named most of the time, and the read changes through the season. A dominant side, like the playtest's three-time premier, usually has no material weakness, so an empty panel is honest. The fault was the copy: "Nothing stands out **yet**" promised a read that would never come.

**Fix (this PR):** after 10 games an empty part says so plainly, "No part of your game is costing you regularly." (or "No one part of your game stands above the league."). Before 10 games it still says "yet". No thresholds changed.

**Decided and done (this PR):** the two points-from-turnover lines (scored from, and conceded on, turnovers) are removed, for both your side and opponents. The club spread is only 1.5–2 points a game against the deliberate 6-point floor, so they almost never fired; territory, clangers and pressure describe turnover play in more actionable terms. The season totals are still tracked. Hit-outs (1.6 spreads) is left as is.

---

## 2. Training turns a small defender into a "Key defender"

### Measurement

Every player at every 2027 club, on every training plan his position allows, given 12 heavy training rounds (1,292 player-and-plan runs):

- Position or second position changed: **0**.
- A defender under 191 cm typed Key defender: **0** (the height gate `PlayerProfile.KEY_DEF_CM`, on `main` since 2026-10-01).
- A forward under 188 cm typed Key forward: **0**.
- Type changes that do happen fit the body: Inside midfielder → Wing on the outside plan (61), Key defender → Rebounding defender on the rebounding plan (41), Defender → Rebounding defender (26), Small forward → Forward on the key-forward plan (22), Wing → Inside midfielder (12), Forward → Key forward (7, all 188 cm+).

### Cause

The Training list showed the **training plan** under the player's name as a bare label ("Key defender · Developing"), in the spot where a type would sit. A medium defender put on the Key defender plan therefore read as a key defender.

**Fix (this PR):** the list row now names the plan as a plan: "Training as a key defender", "Training as an inside midfielder" ("Position plan" unchanged). The player sheet already said "Training plan: …".

**Open question (design):** should the Key defender plan be offered to sub-191 cm defenders at all? It builds intercept and pressure, which a medium lockdown defender can use, so it's left available.

---

## 3. Coaching staff look static

### What exists

A full off-season market (`CoachMarket`): development and ageing, retirements (64–70), AI senior-coach contracts and sackings, upward-only promotions (the no-sideways-poaching design), up to two of your assistants poached a year, former players entering through pathways, and a generated pool.

### Measurement: ten off-seasons, no action from the user

| | Per off-season |
|---|---|
| AI senior coach changes | 1.8 (18 in 10 years) |
| AI assistant jobs changing hands | ~7% (67 moves over ~950 job-seasons) |
| Your assistants poached | 2 in the first off-season, then 1 in nine years |
| Your original 5 assistants still in the same job | 3 for the whole decade |

### Cause

**Assistants have no contracts.** `CoachMarket._appoint` erases `contract_to` for every job except senior coach. An assistant only leaves by promotion elsewhere, retirement, or a new senior coach bringing his own. Your staff therefore never come up for a decision.

### Conclusion

This is not a bug: the intended second off-season layer (retain / release / promote / recruit under simple contracts) has not been built. It needs design decisions first: contract length, how many decisions per off-season, and what an expiring assistant asks for. **No change in this PR.**
