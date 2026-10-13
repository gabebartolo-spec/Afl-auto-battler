# Open requirements register

Read in full at session start. One line per director requirement not DONE on main: owner, status, where the
full wording lives (`docs/roadmap/`). Leaves this file only when its section file records DONE with the PR.
Owner "none" = no plan or branch covers it. "verify" = code not checked this pass; owner checks before scheduling.
Nothing here starts until the boss assigns it. Reconciled 2026-10-10 against main `d0fbaf4d` (hygiene); owners for items 1-9 set by the boss 2026-10-10 (order: 8, then 2-5 as one PR, 1, 9, 7). Items 10-31 unowned go to the director as one scheduling question (boss). Director decisions of 2026-10-13: [chapter 26](26-director-decisions-2026-10-13.md). Next patch milestone: 0.2.0 "Pre-season". Light theme parked by the director 2026-10-13 (ch. 26 s11).

## Director rules on main that the code does not meet

| # | Requirement (director's words in the section file) | Source | Owner | Status |
|---|---|---|---|---|
| 1 | Every player card shows his **top three attributes**; Needs work compares to a positional peer benchmark; retraining adds a position and never degrades old ones | §1.11 positional weaknesses | boss (3rd) | not built (only "Needs work:" exists) |
| 2 | Rotation policies named for intent (Protect freshness / Balanced rotations / Prioritise key players) with a one-line effect each | §1.11 coaching controls | boss | DONE #624 (2026-10-10): Protect freshness / Balanced rotations / Prioritise key players, descriptions pinned to thresholds by test; look gate on the coaching break still the director's |
| 3 | Every pep talk, including the default, shows its effect; a **fourth pep-talk option** | §1.11 coaching controls | boss | DONE #624 (2026-10-10): fourth talk Bring the heat (+12% pressure, pace x1.15, paired-seed test); all four show their effect; balance size unmeasured against the other talks (lever audit) |
| 4 | **Play through** split into three (midfield pillar, forward target, backline distributor); **Main ruck** for dual-ruck sides | §1.11 coaching controls | boss | not built (not in #624) |
| 5 | Defensive forward: "Assign defensive forward" label, explicit none, suitability cards, still scores | §1.11 coaching controls | boss (2nd, coaching-controls PR) | verify |
| 6 | **Player figures get faces and distinct hair** (16 styles defined, 5 drawn; no facial features). Director 2026-10-10: "they look like clones" | §1.11 generated player visual identity | art | briefed 2026-10-10 |
| 7 | Haptics and restrained screen shake, with Off | §1.11 haptics | boss (5th) | TODO, nothing in source |
| 8 | A clear turnover cue (TURNOVER label; tackles distinguishable from turnovers) | §1.11 visual simulation | boss | DONE #617 (2026-10-10): "Turnover" over the winner for about a second, underlined in his club's colour; restarts and kept tackles carry no label; match_visual +6. Look gate: the director's |
| 9 | Feed styling: neutral for tactical/score lines; your goals positive, conceded negative, behinds neutral (visual) | §1.11 feed styling, scoring feedback | boss (4th) | verify against #598 |

## Match flow and presentation

| # | Requirement | Source | Owner | Status |
|---|---|---|---|---|
| 10 | Collection pauses / far receiver: "urgent regression"; next approach named (role allocation reads the log ahead) | §1.11 visual simulation, 2026-10-08 record | none | open |
| 11 | Play on after an intercept or a free; stoppages from contests (Step 1), then recalibrate contested ball, spoils, turnovers (Step 2) | #607 audit, director 2026-10-10 | boss (claude/match-flow) | in progress |
| 12 | Disposals to empty space: the feed says the real cause; kicks to space readable | §1.11 visual simulation | none | open |
| 13 | Every in-match decision has a vignette when on: audit all decision types | §1.11 every decision | none | open (toggle #518 DONE) |
| 14 | Opposition goal-run decision rebuilt around two concrete football moves with vignettes | §1.11 goal-run decision | none | open |
| 15 | Late-game centre ball-up: two distinct choices | §1.11 centre ball-up | none | cap and styling DONE; choice redesign open |
| 16 | Centre ball-up vignette recomposed wider; umpire's held ball not floating | §1.11 vignette polish | none | verify after #506/#597 |
| 17 | Live key-matchup block as a compact grid; intercepts **since the call** beside each loose defender; "What your calls did" says what its numbers mean | §1.11 key-matchup, loose defender, calls | none | verify |
| 18 | Match summary: full injury wording; scoring-run context (when, score before and after) | §1.11 match summary | none | open |
| 19 | Coaching notes vary across a season; press questions vary across long saves | §1.11 coaching notes, press | none (journalists #559 DONE) | audit open |
| 20 | Press-conference framing without the black bands | §1.11 press vignette | art (press-room plate) | in progress |

## Lists, draft, development

| # | Requirement | Source | Owner | Status |
|---|---|---|---|---|
| 21 | Role classifier re-audit: Miers a forward, Uwland not key, Langford a wing | §1.11 role allocation (REOPEN) | none | open |
| 22 | Draft AI / potential: five-season youth-strategy evidence, role concentration, named boards; draft scroll in the exported build | §1.11 draft AI, potential, scroll | none | PARTIAL after #494, #489 |
| 23 | This week: both sides' key-position heights and marking side by side | §1.11 matchup comparison | none | open |
| 24 | Development manual-XP grid; Training compact card grid with roles and traits | §1.11 development, training; STYLE-01 | none | open |
| 25 | Team builder: entry points share one side; headers from arranged fit; pre-game setup before Start | §1.11 team builder | none | verify |
| 37 | **Audit the AI clubs' draft strategy**: do clubs that build their list from scratch (the AI drafting, trading and signing over seasons) end up on average weaker than the real 2026 lists, which real AFL professionals built? Measure over seeded 10-season careers: each AI club's list strength (best 23 and depth, by age bracket) against its real 2026 starting list and against the league's spread; where it drifts; and whether drafted players reach the OVR and roles the real list has. If the AI drafts notably worse teams than their real counterparts, buff its draft skill (needs, value, potential reads) until the gap closes, paired seeds, ± errors; balance is the director's call | director 2026-10-12 | dev-sim | open; audit first (tools/audit, CI), then a buff proposal with the numbers; AI-only change, W7 by qa |
| 38 | **Live-3D vignette probe (LOW PRIORITY, explore later)**: one figure, the Tripo ruck rig, animated in real time inside Godot (glTF rig + clips from the existing Blender/Mixamo path) and judged by the same realism and motion critics against the sprite-sheet version at phone scale and frame time. The question: would real-time 3D vignettes (any camera angle, lighting, posture fixes on the rig instead of re-rendered sheets, no sheet growth) beat the approved 2.5D sheets for look, phone performance and pipeline cost? three.js is NOT the route (a playback stage with no authoring; Godot already renders 3D and exports to web) | director 2026-10-13 | none | open, unassigned, 0 credits; not before the current relaxed-arms slice lands |

## Stats, help, onboarding

| # | Requirement | Source | Owner | Status |
|---|---|---|---|---|
| 26 | Season stats hub phone review | §1.11 stats patch | director | waiting |
| 27 | Stat guide as a topic grid; per-menu first-visit tutorials | §1.11 stat guide, tutorials | none | toggle #572 DONE; rest open |

## Audits the roadmap asks for, unowned

| # | Audit | Source | Owner | Status |
|---|---|---|---|---|
| 28 | How-we-play maturity; How-we-win materiality; List Profile vs results | §1.11 observed failures | none | open |
| 29 | Run-of-goals cadence and efficacy; AI plan adaptation; blowout distribution; vignette reachability in close finishes | §1.11 observed failures | none | open |
| 30 | Coleman goalkicking cap (defect found, balance-gated) | §1.11 Coleman | director | awaiting decision |
| 31 | Native phone numbers: frame time, battery, loading | §1.11 performance | director's phone (probe build held) | waiting |

## Story cards (director, 2026-10-12)

| # | Requirement | Source | Owner | Status |
|---|---|---|---|---|
| 34 | **Audit every event card** (the 65 story cards and the older event cards): does any choice do nothing (no effect, no information, no follow-up)? Does any card never appear in a 10-season career? Can any be worded better (scrutable: a card keeps what it promises, football language, stakes true)? Found in play: "The fitness staff want a time trial" promised to tell the coach who is fit and named nobody (fix: claude/story-time-trial) | director 2026-10-12 | story | open; seeded audit over 10-season careers (card appearance counts per id, zero-effect choices listed), then a copy pass to the director as one sheet |
| 35 | **A whole bespoke set of finals events**: cards that only fire in finals week (the elimination/qualifying week, the week after a loss that ends the season, the preliminary final build-up, the bye week, the club's first final in years, a veteran's last final), with real stakes and the finals mood in the copy | director 2026-10-12 | story | all 25 finals and Grand Final cards ruled card by card 2026-10-13; build in two slices (finals week, then Grand Final week); board rule "Yes, swap and tell me": board rewards only where the board is the point; swaps marked for him ([ch. 26 s4](26-director-decisions-2026-10-13.md)) |
| 36 | **A small set of Grand Final events that make each Grand Final feel unique and memorable**: a handful of cards keyed to what is true of this Grand Final (the opponent, a captain's last game, a kid's first season, an injured star's fitness test, the parade, the week's press, the result's aftermath), so no two Grand Final weeks read the same | director 2026-10-12 | story | ruled 2026-10-13 with row 35 (second slice); the aftermath cards handle both the win and the loss |

## Pre-season (director, 2026-10-13)

| # | Requirement | Source | Owner | Status |
|---|---|---|---|---|
| 39 | **A pre-season** (headline of patch 0.2.0 "Pre-season"). Director: "a glaring hole in our game: pre season, a period of development, narratives, media speculation, fitness building, game-plan honing etc". Eight weeks, "but streamline it a touch"; "Plan in blocks, stop at events ... but reduce it to just 1 pre season match"; practice match "Trial players and plans, no ladder"; "Drill a plan, it works better"; papers "Predict, and you answer"; the intra-club match is a real match on the oval with next draft's prospects filling the spare spots. Full rulings: [ch. 26 s2](26-director-decisions-2026-10-13.md) | director 2026-10-13 | lead | in progress. Slices: 1 exists + blocks + time trial + sim to round 1; 2 plan familiarity; 3 practice match and intra-club match; 4 the papers; 5 pre-season story cards. Balance sizes go to his playtest |
| 40 | **Create your own game plan, in the game as is.** Director: "i love the idea of 3 for our club forge, but 1 for our game as is" | director 2026-10-13 | lead | decide after plan drilling (row 39 slice 2) has been played; stretch |
| 41 | **A full game-plan builder for the Club Forge** (create-a-club): the coach builds a plan of his own. Director: "i love the idea of 3 for our club forge" | director 2026-10-13 | none | open, unassigned; design sheet first |
| 42 | **Believable comebacks.** Director: "my tester reported a scenario where he was 2 goals up at 3qt, simmed the last quarter, lost by 40 points. we need to codify realistic comeback rules. I mean a 52 point swing in one quarter is POSSIBLE but very very very unlikely. We need to keep comebacks in the game, maybe even make them a bigger part (Read more narrative/UI elements rather than frequency) of the game, but they need to be believable and not seem like the game hallucinating" | director 2026-10-13 | none | audit running; rules proposed with numbers after it, balance is his call |
| 43 | **Tripo-made emblems and models to beautify the UI**, "just like how we did with our club guernsey logos on the ladder". Starts with three culture-strand icons (Standards, Togetherness, Ambition). Spend: 15,000 credits set aside 2026-10-13, "im not saying you HAVE to spend 15k in one go, im just setting that 15k aside to you to use as you see fit with over the next few hours,days, weeks" ([ch. 26 s10](26-director-decisions-2026-10-13.md)) | director 2026-10-13 | none | open, unassigned; credits used so far: 0; lead keeps the tally; art check before he sees any |

## Platforms and grounds

| # | Requirement | Source | Owner | Status |
|---|---|---|---|---|
| 32 | Fully functional **web build**; the game synchronised across Android, PC and web. Director 2026-10-10. Open question: synchronised = feature/version parity (one codebase, same content, platform-appropriate input and layout) and/or saves carried between devices (cloud or export/import)? Confirm when scheduled | ARD-M8-010 | none: awaiting the director's scheduling | not started |
| 33 | The visual simulation's oval **dimensions and appearance change with the home ground** (AFL clubs' grounds: MCG, Marvel, Optus, Adelaide Oval, Gabba, People First, GMHBA, SCG, Engie; default elsewhere). Director 2026-10-10. Open: presentation only or sim too; fictional clubs' grounds | ARD-M8-011 | none: awaiting the director's scheduling | not started |

## Long-save presentation wishlist (HIGH content, unassigned)

Away/clash and heritage guernseys · coach appearance · finals presentation (bracket prototype #529) · premiership
guernsey history · player card evolution · record-breaker marks · legends wall · Grand Final climax and **season
story recap** · draft class identity · archive gallery · club museum · retirement variants (FL-007 milestones DONE)
· dynamic crowd (MCG crowd tile in progress) · custom typography · season poster · stadium identity · user
guernseys and logos · **Coach of the Year** (director request 2026-10-08, not started, not assigned).

## In a current plan

Match-flow Steps 1–2 (boss; intercept spread #606 DONE) · press-room, awards and MCG plates, crowd tile
(art) · motion B and C, sheet contract v2, BPTC fix (art) · polish pass 1 (boss) · afl-team-pr skill refresh
(support) · roadmap split and this register (hygiene).
