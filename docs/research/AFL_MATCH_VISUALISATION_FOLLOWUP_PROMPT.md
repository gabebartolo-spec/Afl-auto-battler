Read `docs/research/AFL_MATCH_VISUALISATION_AND_TACTICS_RESEARCH.md` and the accompanying `docs/research/AFL_TACTICAL_SHAPE_EXAMPLES.png` on main. They are research and proposed designs, not instructions to accept every recommendation or implement everything at once.

Assess them against the current game, `docs/MATCH_VIEW.md` and the existing ARD-M8-003 roadmap item. The inspected source snapshot was d2ec68f, so recheck the code and any subsequent work. Preserve existing information and coordinate with the other agents' current ownership.

Start by verifying the connections between every existing gameplan/live coaching lever and the visualiser. For each, explain its current simulation effect, whether that effect is actually visible, what should change in player positioning/movement/ball use, and what authoritative event context is missing. Cover all six plans, focus player, tagger and target, named matchups, roaming interceptor and accountability, stack/flood/surge/hold, pep choices, rotations and relevant traits/synergies.

Pay particular attention to named actor continuity, handball-to-kick presentation substitution, receiver-seeking loose balls, generic versus named spares, centre participant selection, distant-player waits and tactical state during replay/skip. Include the existing set-shot shoot/pass/bomb choices: show their different resolved sequences without inventing a pack winner, scorer or uncounted/duplicate disposal. Separate confirmed defects from hypotheses that need captures.

Recommend the smallest useful implementation: retain MatchSim authority and deterministic results, record the necessary tactical context/intent, then have the director show the corresponding football jobs and vulnerabilities. Distinguish semantic reconstruction from any proposed new spatial mechanics that would change outcomes. Do not add duplicate balance bonuses or presentation rerolls.

Assess two initial demonstrations: legal centre setups with visibly different attacking/defensive support, and flood versus ordinary defensive coverage. Then consider corridor/switch/controlled movement, hybrid man/zone coverage and the other play recipes. Reuse the existing visual capture harness and tests; explain how you would verify actor identity, ball paths, event order, timeline expiry and tactical readability at 1x/4x/8x and on phone/fullscreen.

Account for 2026 ball-ups and restart rules. Preserve the user's extreme-priority fullscreen readability work. Map proposed work to existing roadmap ownership rather than automatically creating duplicate items.

First return a concise assessment, disagreements, missing dependencies and a proposed sequence. Interview me about new suggestions one at a time, then update the roadmap only with agreed actionable work. Do not launch implementation or a broad simulation rewrite merely because the report discusses one. Coordinate with the existing agent assignments and distinguish work already approved from new concepts.
