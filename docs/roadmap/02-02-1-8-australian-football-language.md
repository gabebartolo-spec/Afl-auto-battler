## 1.8 Australian football language

Use natural AFL terminology in player-facing text.

Avoid exposing implementation jargon such as `DEF`, `MID`, `FWD`, internal enum names, raw multipliers or diagnostic labels.

Use Australian spelling: `metres`, not `meters`.

## 1.9 Current AFL rules

If a task depends on a contemporary AFL law/rule:
- verify the current rule before implementing it where network access is available,
- record the rule assumption in code/test comments where it is easy to misunderstand,
- do not rely on vague memory for changed rules.

The game's intended starting season is **2027**, so rule/data assumptions should make sense for that baseline.

## 1.10 Balance gate

Any change that can materially alter wins, scoring, player production, development, availability or tactical strength is `BALANCE-GATED`.

At minimum:
- use deterministic seeds,
- compare before vs after,
- use the existing sim harness where possible,
- run enough matches for the direction of the effect to stabilise (prefer 1,000+ per condition when cheap),
- inspect mean and distribution, not only one showcase match,
- check positional/archetype side effects,
- check strong-team vs weak-team behaviour,
- check AI and player teams use the same rules.

Do not tune purely until one screenshot "looks right".

**Who calls balance settled (design bible, 2026-10-09):** balance is settled when testing shows numbers similar to real AFL **and** the director's own playtest passes. An agent reports evidence; it never declares balance finished. Ratings that reflect the real footballer are part of this work.

---

