### 2026-09-30 full-season phone playtest handoff

This playtest reached the end of the 2027 season, finals, off-season and National Draft. The findings in this section are now the canonical player-observed evidence for the next work. **Do not treat every bullet as an immediate implementation request:** bugs/UX defects can be fixed directly when scoped; anything labelled audit/investigate must be measured by Claude first under the audit-ownership convention above. Prefer coherent batches and keep the P0 match-flow gate ahead of lower-risk presentation/features.

### Product goal
The core loop must support:
**understand the side → identify a football problem/opportunity → make an informed choice → observe the consequence → learn for the next decision.**

Do **not** solve this by revealing an objectively best choice, adding recommendation arrows, or dumping more numbers onto primary screens. Preserve uncertainty and trade-offs while making the underlying football logic scrutable.

### Hard gates before unrelated feature expansion
1. **Match flow:** watched matches run without freezes/stalls or obviously artificial waits for predetermined receivers. Loose-ball possession must look locally contestable and believable.
2. **Decision inputs:** before a meaningful selection/tactical choice, the player can see enough relevant football information to form a reasoned expectation.
3. **Synergy clarity:** list/line/role synergies can be understood in football language; the player can explain broadly what a combination is good/bad at without reverse-engineering hidden formulas.
4. **Decision feedback:** after a choice, the game gives enough concise evidence to judge broadly whether the intended effect occurred and why the match developed as it did.
5. **No number vomit:** clarity comes from better framing, comparisons, football language and causal feedback—not exposing raw internal weights or adding dense dashboards.

