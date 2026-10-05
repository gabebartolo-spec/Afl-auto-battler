# Football choices that stay interesting — agency and team building

_Research: 5 October 2026. Read with the [visual chapter](AFL_VISUAL_DESIGN_RESEARCH.md), [career chapter](AFL_LONG_CAREER_STORY_RESEARCH.md) and [evidence ledger](AFL_RESEARCH_EVIDENCE_LEDGER.md). This chapter refines existing roadmap owners; it does not authorise a new engine._

## 1. The replayability problem

The director's criticism of Footy Redraft is precise: learning the best players makes subsequent drafts feel solved. The criticism of AFCM is different: complexity and unclear numbers erode faith in the simulation. ARD must avoid both without hiding its rules.

The promising direction is **stable rules, changing football problems**. The value of a player depends on the current list, feasible job, contract, age, availability, depth, opponent and club ambition. Learning the game should improve judgement while leaving difficult alternatives.

“More randomness” is an inadequate remedy. It can make decisions less understandable without making them richer. Additional attributes, mandatory rotating bonuses or concealed penalties likewise risk turning creative team building into decoding work.

This is an ARD hypothesis, not an established causal result. The test is whether several resource-matched approaches remain useful across plausible opponents and years, and whether people enjoy choosing among them.

## 2. References that challenge a fixed best build

### Football, Tactics & Glory: a documented universal-player problem

[Update 10](https://creoteam.com/update-10-is-released/) describes an earlier dominant universal-player approach and introduces location-dependent specialisations. The [console review](https://www.operationsports.com/football-tactics-and-glory-review-a-mix-of-civilization-and-football-manager/) values strategic distinction within a comparatively small attribute set.

The transfer is functional variety: a player should solve a football problem. It is not a mandate for seventeen classes, board-game movement or a class badge on every AFL player. A defender who restricts a forward, a forward who creates space and a midfielder who helps control the contest need different useful contributions.

Its [2026 world update](https://creoteam.com/world-championship-dlc-features-list/) also aligns AI development and generation while describing different quick-simulation behaviour. ARD should retain the useful parity lesson and reject biased shortcuts: watched and simmed matches must use the same authoritative engine when decisions are equivalent.

### Teamfight Tactics: specialisation can broaden or collapse choice

Several developer retrospectives describe failures alongside successes:

| Source | Stated problem or lesson | ARD transfer |
|---|---|---|
| [Reckoning](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-reckoning-learnings/) | A new item layer increased complexity | Do not add a modifier layer when clearer jobs would suffice |
| [Dragonlands](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-dragonlands-learnings/) | Restrictions and combinations shaped flexibility | Make committing to an identity a real choice, with useful partial approaches |
| [Magic n' Mayhem](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-magic-n-mayhem-learnings/) | A dominant build escaped testing; role changes could retain too much old strength | Test plausible optimising policies and ensure gaining one strength costs something |
| [Into the Arcane](https://teamfighttactics.leagueoflegends.com/en-ph/news/dev/dev-tft-into-the-arcane-learnings/) | Forcing preferred outcomes reduced variation; random repetition created different frustration | Do not equate variety with inaccessible choices or random surprises |
| [K.O. Coliseum](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-ko-coliseum-learnings/) | Knowledge burden and mandatory combinations narrowed flexibility | Test a few legible football identities before expanding synergy catalogues |

These are developer interpretations of a competitive live game, not controlled proof of enjoyment. ARD should not copy trait thresholds, shop rerolls, collectible-set completion or its release cadence. An AFL list is a continuous, constrained group of people rather than a disposable round composition.

**Existing owner:** the §9.1 synergy reality audit, selection/role work and M4-004. First measure current activation. If a balanced good side effortlessly receives every identity bonus, refine one existing specialisation with a visible roster or selection sacrifice. Do not add another synergy engine.

### Battle Brothers and Basketball GM: value depends on circumstances

A [Battle Brothers discussion](https://www.reddit.com/r/BattleBrothers/comments/1wdgu6r/im_on_day_300_and_now_i_want_to_max_my_team_which/) compares expensive backgrounds with cheaper useful recruits. A [Basketball GM long-career account](https://www.reddit.com/r/BasketballGM/comments/10h63uu) describes repeated archetypes becoming predictable and proposes more attributes.

The complaints and preferences are evidence; the proposed fixes are hypotheses. ARD should test contextual value before adding ratings. A cheaper depth player can matter if the extra cap room and viable role genuinely enable a different side. That cannot be achieved merely by writing “underrated” in his biography.

### Retro Bowl and Motorsport Manager: mastery needs fresh pressures

[Retro Bowl mastery complaints](https://www.reddit.com/r/RetroBowl/comments/1i2iajm) describe familiar names and repeated clock tactics, while [positive simplicity accounts](https://www.reddit.com/r/RetroBowl/comments/1ktupzw) value limited administration. These accounts support changing consequential circumstances rather than adding weekly chores.

A [Motorsport Manager strategy guide](https://www.reddit.com/r/MotorsportManagerPC/comments/1luaox0/spoilery_guide_to_strategy_in_motorsport_manager/) encourages examining expected and actual results and observing rivals. Its [spoiler-free predecessor](https://www.reddit.com/r/MotorsportManagerPC/comments/t84wrb/spoiler_free_guide_to_motorsport_manager/) separates learning from revealing a solution. ARD can explain rules, evidence and consequences without supplying an optimal plan.

## 3. A match decision must have a complete chain

The accepted M4-001 already has context-triggered moments and a resolution log. The research does not propose replacing them. Verify one existing gate end to end before increasing the catalogue.

| Stage | Required truth | Failure to avoid |
|---|---|---|
| Situation | Current score, quarter, personnel or actual events justify the gate | A random story question unrelated to the match |
| Options | Each option is feasible with the current side and understandable in football language | Resting a player without a replacement, or an unavailable role |
| Cost and horizon | Explain the useful benefit, sacrifice and when it ends | A risk-free buff, misleading duration or unexplained return |
| Application | Exactly one authoritative state change occurs | A prettier card whose choice changes nothing |
| Presentation | Named actors and the visible event agree with the engine | Decorative movement presented as a calculated tactical win |
| Follow-through | Show actual relevant changes, including failure or ambiguity | Repeating the choice, predicting a win or claiming certainty from one result |
| Continuity | Save/resume, skip and subsequent play preserve the same resolution | Duplicate effects, dropped decisions or a different result after reload |

The [AFL tagging interviews](https://www.afl.com.au/news/1555931/tag-youre-it-inside-footys-ultimate-tactical-battle) make a useful distinction: restricting a star can sacrifice attacking contribution, and abandoning a tag can improve the group or release the opponent. A low target disposal count does not establish a successful team decision.

ARD need not simulate every real tagging variant. M4-003 owns the attacking cost; M4-002 owns credible key assignments. Show a handful of consequential matchups, not eighteen mandatory assignments.

### The current tired-star audit is a caution, not a completed solution

At the repository checkpoint, [the tired-call audit](../TIRED_CALL_AUDIT_2026-10-05.md) is merged through [PR #230](https://github.com/gabebartolo-spec/Afl-auto-battler/pull/230). It reports 288 paired matches, with the gate firing in 252. Rest and Keep have similar sampled outputs because both paths can rotate and return the star. The break repeats the choice instead of explaining what followed; wording also needs attention.

This is published project evidence, not a simulation run performed by this research. It does not prove the effect is zero in every circumstance. Nor does it establish enjoyment. The director has selected a meaningful Rest/Keep trade-off; measured behaviour and phone validation remain necessary. This records the director's chosen direction without inventing balance coefficients.

**Smallest accepted work:** use this audited gate to verify truthful copy, feasibility, applied duration and follow-through under its existing authority. Tuning under the selected direction still follows the balance gate. M4-009 owns the later explanation, keeping one report rather than another results screen.

## 4. Separate application, observation and causation

A player deserves to know that a tag was applied, that the opponent subsequently won fewer clearances, and that another teammate became important. These are not the same claim.

1. **Applied fact:** the named player took a job for the specified interval.
2. **Observed follow-through:** the relevant period contained a particular output or event.
3. **Comparative evidence:** controlled simulations show how outcomes differ across policies and contexts.
4. **Causal certainty about one match:** usually unavailable, because many simultaneous changes and chance events contribute.

The [ZenGM Four Factors revision](https://zengm.com/blog/2024/10/four-factors-improvements/) distinguishes weighted estimates from the actual score margin. ARD should avoid explaining a win by counting green indicators or assigning an exact number of points to a coaching action without a valid model.

Seeded comparisons are useful, but two branches can consume random numbers differently after a decision. Shared seeds do not guarantee that every subsequent chance event is identical. Record pre-choice equivalence, deterministic replay for the same answer, local application, multiple seeds and output distributions. Do not require both branches to produce the same event sequence.

**Phone acceptance:** after a break, a player can explain what was changed and what they observed, while recognising that the change did not guarantee success. “Nothing decisive followed” is a legitimate outcome.

## 5. Team building should create football possibilities

### Strengths must imply vulnerabilities

Examples below are test compositions, not new bonus systems or approved balance values:

- A pressure-heavy side may sustain contests but give up kicking quality or specialist scoring.
- A strong marking defence may intercept effectively but struggle when the opposition changes entry style or exposes slow coverage.
- Extra tall scoring options may change entries and contests while reducing ground-level pressure or running depth.
- A midfield built around a few stars may dominate a contest yet expose rotation and availability risk.
- Versatile players may protect against injuries but offer less peak impact than committed specialists.

The first task is to find which distinctions are already meaningful in MatchSim, plans, roles and existing synergies. A narrative description must not claim an unsupported advantage. Correct or remove ineffective controls before adding a new playstyle.

Real [backline analysis](https://www.afl.com.au/news/1141258/battle-of-the-backlines-where-the-melbourne-demons-fremantle-dockers-clash-will-be-won) and [Sydney's changed style](https://www.afl.com.au/news/1607266/the-stunning-numbers-behind-sydney-swans-game-style-changes) help frame space, routes and personnel. They do not supply universally valid coefficients or a perfect counter chart.

### Broad ratings are useful summaries, not the answer

The [OOTP ratings documentation](https://wiki.ootpdevelopments.com/index.php?title=OOTP_Baseball%3AScreens_and_Menus%2FPlayer_Profile%2FPlayer_Ratings%2FOVR_and_POT_Ratings) illustrates the importance of role and league context. [Its scouting model](https://wiki.ootpdevelopments.com/index.php?title=OOTP_Baseball%3AImportant_Game_Concepts%2FThe_Scouting_Model) distinguishes assessed information from underlying ability.

Preserve ARD's already merged role-profile and POT corrections. M5-009 and M5-013 are not reopened by this report. The draft should give comprehensible estimates and uncertainty; selecting an already famous name must not reveal a guaranteed future. Neither should inaccurate assessment become an unexplained trap.

M5-008 remains the owner of role-aware form and recognition. A defender's useful contribution must not disappear because he has fewer disposals. Check genuine suppression or other supported evidence; do not fabricate a helpful contribution for every quiet player.

### Growth is a commitment, not a guaranteed reward

[OOTP development documentation](https://wiki.ootpdevelopments.com/index.php?title=OOTP_Baseball%3AScreens_and_Menus%2FPlayer_Profile%2FPlayer_Ratings%2FPlayer_Development) describes several influences, while [development spending](https://wiki.ootpdevelopments.com/index.php?title=OOTP_Baseball%3AScreens_and_Menus%2FTeam_Menu%2FPlayer_Development) improves chances rather than promising success. Its playing-time rules are not ARD's.

M5-003 owns plausible secondary-role learning. An older footballer may gain another useful job, but retraining should respect body, role and time costs. Progress persists separately from form and preserves identity. M5-006 owns passive reserves development; no invented reserves matches or statistics.

The announced [DDS Pro Basketball 27 development system](https://wolverinestudios.com/pro-basketball-27-player-development/) offers another bounded-priority reference. It is forthcoming, not hands-on evidence. The director has accepted RC-003 as a bounded extension of M5-003.

## 6. Market trust and AI parity

The [Super Mega Baseball loyalty complaint](https://www.reddit.com/r/SuperMegaBaseball/comments/1vdaulx/franchise_mode_rant/) shows how a high loyalty number beside low re-sign interest can undermine confidence. Replies supply a possible salary explanation, not independently verified mechanics. The practical question is whether ARD correctly names each concept.

[ZenGM's mood explanation](https://zengm.com/blog/2020/09/player-mood/) explicitly bounds its effect to contract willingness. ARD should similarly distinguish wage satisfaction, club preference, morale, trade valuation and match strength. A UI explanation must describe the actual rule and update with the same state as the number.

M6-004 already owns a substantial market on main. Refine transparent factors and fair reciprocal offers; do not commission a second negotiation engine. Use current and realised value, not only asking price or projection. Check young, unproven, prime, veteran and injured assets, as well as future commitments and cap room.

[FM24's AI squad-building explanation](https://www.footballmanager.com/features/smarter-transfers-squad-building-and-finance) supplies a useful question about replacing real needs. Developer claims still require project evidence. Rival clubs need the same constraints and comparable information; difficulty should not rely on psychic scouting or user-only boosts.

Open [PR #228](https://github.com/gabebartolo-spec/Afl-auto-battler/pull/228) contains competitive-balance and trade work at the recorded checkpoint. Its results are proposed, not main behaviour. Refresh its status before modifying those systems.

## 7. Owner map and validation

| Recommendation / benefit | Existing implementation and owner | Smallest useful scope | Evidence required and exclusion |
|---|---|---|---|
| Honest, consequential gates | MatchSim moments; M4-001 / M4-009 | Finish the audited tired gate's application and explanation chain | Feasibility, duration, single resolution, factual follow-through; no new gate catalogue |
| Credible key matchups | Existing forward/defender assignments; M4-002 / M4-003 | Verify one relevant assignment and its attacking cost | Correct personnel, actual outcomes and AI parity; no 18-player task |
| Useful structural alternatives | Existing spare/accountable choice; M4-004 | Measure one supported benefit and corresponding weakness | Event/visual agreement across opponents; no free intercept boost |
| Distinct useful footballers | Existing roles and statistics; M5-008 | Check one low-disposal role's contribution and recognition | True role, quiet/poor cases, no fabricated success |
| Evolving career roles | Existing training; M5-003 / M5-006 | One plausible secondary role with persistent, uncertain progress | Eligible bodies, omission/usage, interruptions and reload; no universal player |
| Trustworthy list decisions | Existing scouting/draft/market; M5-014 / M6-004 | Clarify actual factors in one existing transaction | Consistent values, reachable cap and context preserved; no best-recruit hint |
| Creative viable identities | Existing synergy audit §9.1 | Compare present activation before refining one sacrifice | Matched resources, counter-opponents and multiple seasons; no second synergy system |
| Lasting challenge | Existing difficulty audits; M8-005 | Compare active policies and low-administration baselines | Realised outcomes and exploit checks; no claim that autopilot measures active dominance |

First audit existing behaviour, then test the smallest change. Use several starting clubs and multiple seeds with comparable talent, age, cap, depth and availability. Compare hold, youth, veteran and trade-heavy management, current-call defaults and context-aware decisions. Inspect complete output distributions and failures rather than one dramatic match.

A stronger policy should sometimes lose, and a weakly matched plan should not become useful through a hidden safety bonus. No policy must be equally strong in every context. The aim is understandable, competing possibilities.

Pair simulations with observed phone sessions and multi-season follow-up. Ask people to explain a team-building sacrifice, a match adjustment and a difficult contract decision. Ask whether they wanted to intervene or felt obliged to repeatedly correct the interface. Simulations assess behaviour and balance; they cannot establish enjoyment.

**Authority:** preserve correctness and §1.11/§9.1 phone gates ahead of unrelated expansion. The bounded comparison and rival-identity extensions are now director-selected within their existing owners. No monetisation, additional gameplay API, save-format change or assignment to Claude is performed by this research.
