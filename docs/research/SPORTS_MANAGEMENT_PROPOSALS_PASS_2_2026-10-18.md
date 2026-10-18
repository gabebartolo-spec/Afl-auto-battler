# Second pass: 57 more proposals from the genre research

_For the director, 2026-10-18, after he said of [the first report](SPORTS_MANAGEMENT_GENRE_COMPARISON_2026-10-18.md): "im interested in more proposals from the research i dont feel like we got everything we could out of it". Two miners re-read the evidence folder (`genre_evidence_2026-10-18/`): `pass2_candidates_pc.md` (C-PC-01..34) and `pass2_candidates_mobile_genre.md` (C-MG-01..31). This document merges, dedupes, ranks and presents them. Decisions 1-6 of 2026-10-18 ([roadmap ch. 28](../roadmap/28-director-decisions-2026-10-18.md)) are made and not re-asked. Labels: [player] [dev] [critic] [aggregate] [mechanic] [director]. A source the first report already links is cited by name only; a source new to this pass carries its URL. GENRE §n is `docs/GENRE_ENJOYMENT_RESEARCH.md`. Size S under a day, M a few days, L a week or more. Tier A professional baseline (folds into the 1.0 plan per decision 1), B makes the fun land, C later. Nothing here is assigned; nothing here edits the bible._

## Summary

Sixty-five candidates came in (34 PC, 31 mobile). Fifty-seven survive as P-25 to P-81. Nine were the same idea found by both miners and are merged, marked "from C-PC-NN and C-MG-NN" (the two-tap map, the per-frame picture check, the term and mark lookup, the every-screen sweep, the patch-note rules, the public voice, the coach's job letter, the club remembering a player, saves surviving the phone and the browser); C-PC-31 is split in two because one half touches the sim and the other does not. The miners had already dropped five that exist today (father-son and NGA landings, the board's goal on the hub, the ball's shadow, the All-Australian oval, home grounds at their own size). No survivor duplicates P-01..P-24, RC-003..007 or an open PR (#636-#774); where one gives shape to an unassigned wishlist line, the line is named. Two leaned on evidence from the pass-1 declines (3D, spoken commentary) and are kept in the form that avoids the decline; section 2 restates the declines.

Five repo findings the director should know before deciding. First, `scripts/sim/CareerFacts.gd` is written by `GameState.gd` and read only by `Retirement.gd`: no UI file reads it, so the facts the game remembers about a player reach no screen (P-37, P-39, P-41). Second, the engine already picks a breeze end on windy days (`MatchSim.gd:236-248 breeze_side, with_breeze()`) and swaps it each quarter, and nothing in `scripts/ui` says which end has it (P-31). Third, the board's season goal is already set from the pre-season list rank (`ClubLife.board_goal(rank)`, `ClubLife.gd:39`), so the Footy Redraft "relative to your start" benchmark is half built and only needs the rank said aloud (P-38). Fourth, `export_presets.cfg` carries no Android user-data backup line (line 36 is the only permission), so the system's own device backup does not carry a career to a new phone (P-71). Fifth, press conferences already fire only on a notable factual trigger with a cooldown per question (`MediaConference.gd:95` "Not every ordinary match earns a conference", `COOLDOWN_ROUNDS`), so decision 3 (P-17) is mostly built; what remains is question variety over long saves (row 19) and the trigger rate, which P-07 would measure.

## 1. The proposals

### Theme 1. Match day on a phone

**P-25. One thumb on match day.** Every control a coach touches during live play (speed, skip, a moment's choices, the break sheet's actions) sits in the lower part of the portrait screen; nothing needs a scroll while the ball is in play. A real-tap test at 360x740 and 420x860 asserts each control is within thumb reach and uncovered. From C-MG-01.
- Bible intent: player agency in the match; readability and intuitive interfaces.
- Evidence: FM24 Mobile "In-match control is much improved", the critic made more mid-game changes because mentality was one tap away [critic, iMore].
- Exists today: upright oval (#724); side panel 120 or 168 px on a phone (`scripts/ui/MatchScene.gd:213-224`); the break sheet's choices are "a mouse, not a thumb" (`:71-73`); `tests/tap.gd`. No thumb-reach test.
- Size: M. Tier: A.
- Does not: change what any call does or redesign the oval.
- Conflicts: none.

**P-26. The score never leaves the screen.** On the live match screen both scores and the clock stay in view through a moment call, a quarter-break panel, the stats view and any vignette. A screenshot test at phone size asserts the scoreboard face is visible and current in each state. From C-PC-01.
- Bible intent: "no text becomes overlooked"; reading the game is the skill.
- Evidence: ZenGM Jul 2025 "current score is always visible at the top" [dev, changelog].
- Exists today: scoreboard repainted on events (`MatchScene.gd:230,3014,3035`); `tests/run_matchday_tests.gd:294` checks the lead line; nothing checks it stays visible under panels and vignettes.
- Size: S. Tier: A.
- Does not: add a second scoreboard or move the existing one.
- Conflicts: none.

**P-27. Full time ends on the next poster.** The last thing on the full-time screen is the next match in one line (opponent, ground, forecast) and one button that lands on the hub with that poster already up. Measure siren-to-next-bounce on the reference phone and publish it beside P-05's numbers. From C-MG-02.
- Bible intent: designed for a player who plays most matches; no arthritis from clicking.
- Evidence: Retro Bowl "a game to play regularly in short bursts" [critic, OpenCritic].
- Exists today: full-time overlay with Continue and Training (`MatchScene.gd:3226-3254`), hub poster (`MatchPoster.gd`). No next-match line at full time. P-07 counts stops; this is the hook at the end.
- Size: S. Tier: B.
- Does not: auto-start the next match or skip any stop.
- Conflicts: none.

**P-28. The call's own counter beside the oval.** While a structural call is running, one live line beside the oval counts the thing the call is for, since it was made ("Press on since Q2: six turnovers forced in their half"). The line ends when the call ends; no call, no line. From C-MG-03.
- Bible intent: the game shows what each decision led to.
- Evidence: Pocket GM 3 "added real-time tracking of passes, runs, and kicks" beside play-by-play [mechanic, App Store].
- Exists today: "How it's going" block for the defensive forward only (`MatchScene.gd:1131-1140`), loose-man tally (`:935`). P-12 is the picture, P-19 the quarter strip; this is the live readout.
- Size: M. Tier: B.
- Does not: show a percentage or claim the call won anything; one count per active call.
- Conflicts: none (one count tied to a call, gone when it ends; the odds stay on the call's own gate, bible §4).

**P-29. What is expected of you this week.** One line on the poster, from the board's season goal, both ladder spots and the venue: "A game the board expects you to win", "An even game", "Nobody expects much here". The post-match summary says in one word whether it was met. From C-MG-04.
- Bible intent: the risk belongs to the player, so he should know what a loss costs.
- Evidence: FM24 Mobile's Match Expectations page makes it "feel more alive" [critic, iMore]; director A9: facts he can act on, not facts for their own sake [director, ch. 27].
- Exists today: board goal from pre-season list rank (`scripts/sim/ClubLife.gd:21-55`); poster shows round, ground and forecast; no expectation words.
- Size: S. Tier: B.
- Does not: change board effect sizes; no probability, no odds.
- Conflicts: none.

**P-30. A moment is a window, not a stop.** In Watch, a moment opens a short window at live speed with its choices and a visible countdown; one tap takes a choice, and when the window closes the coach has kept the current approach. A setting keeps today's full pause. From C-MG-31.
- Bible intent: agency at decisive moments without breaking the match being watched.
- Evidence: "frequent pauses can destroy the flow being watched" [critic, GENRE §3.6].
- Exists today: a moment pauses the pitch (`MatchScene.gd:572,2060,2915`); no moments setting. P-14 (decided) is a mode; this is how a moment presents inside Watch.
- Size: M. Tier: C.
- Does not: answer a moment for the coach.
- Conflicts: the director's "every decision needs a vignette" (open-requirements rows 13-16); a live-speed window may fight the vignette beat.

### Theme 2. The oval and the broadcast

**P-31. Show the breeze end.** On windy days the engine already picks a breeze end that swaps each quarter. Draw it (an arrow at the goals it favours), say it at the bounce and at every break ("You kick with the breeze this quarter"), and let the tempo call's copy read against it. From C-MG-19.
- Bible intent: weather is the one cosmetic exception and should matter; reading the game is the skill.
- Evidence: Motorsport Manager links changing conditions to watched tactical calls [mechanic, GENRE §3.6].
- Exists today: `MatchSim.gd:236-248 breeze_side, with_breeze()`; flags stream in the wind (`VignetteGround.gd:361-387`); nothing in `scripts/ui` names the end.
- Size: S. Tier: B.
- Does not: change the sim.
- Conflicts: none.

**P-32. The crowd knows the score, and the siren is on the tick.** The crowd bed rises with a run of goals and goes flat for the side six goals down; the home crowd is louder than the travelling one; the roar lands on the frame the goal is scored and the siren on the frame the clock reaches zero at every quarter. A test measures the offset between event and sound. From C-PC-20.
- Bible intent: immersion; how the club sounds never affects the sim.
- Evidence: F1M22 triggers audio early so it syncs with the picture [dev, Game Developer](https://www.gamedeveloper.com/production/deep-dive-f1-manager-2022).
- Exists today: `scripts/ui/match/CrowdSound.gd`: one bed at a fixed level, a roar for a goal, a lift for a behind, the siren at full time only.
- Size: M. Tier: B.
- Does not: add spoken commentary (section 2), club songs or a PA announcer.
- Conflicts: none.

**P-33. Watch the goals again.** After full time, "The goals" replays each goal from the event log as a short beat on the oval or as the existing broadcast vignette, in order, skippable, with the scorer and the score at that moment. The engine is deterministic, so nothing new is stored. From C-PC-19.
- Bible intent: match day is the culmination; beautiful and fun to play.
- Evidence: FM players prefer 2D for shape and 3D "for goal replays" [player, FM Scout].
- Exists today: `MatchDirector.gd` beats, `BroadcastVignette.gd`, `replay_seed` (`GameState.gd:272-274`), replay snapshots (`CareerSave.gd:26`); no highlights reel.
- Size: M. Tier: B.
- Does not: replay non-scoring passages, add a free camera or a 3D view.
- Conflicts: none.

**P-34. Kit clash checked for colour-blind eyes.** The disc pairing test that keeps all 306 club pairings distinct also runs each pairing through deuteranopia and protanopia simulation, and fails when the two sides' discs or strips fall under a contrast floor for either. From C-PC-06.
- Bible intent: "a player's allegiance is obvious"; club colour must stay readable (CLAUDE.md).
- Evidence: colour-blindness is one of the four most-complained accessibility items [mechanic, GAG].
- Exists today: 306 pairings distinct (#763, `tests/test_match_visual.gd:2009`); no colour-vision simulation anywhere.
- Size: S. Tier: A.
- Does not: add a colour-blind mode or recolour kits; it changes which clash strip is chosen when a pairing fails.
- Conflicts: none.

**P-35. He gets older on the stage.** A player's look ages with him: a draftee clean-faced and slighter, stubble or a receding line near 30, grey at 34. Drawn from the same sheets, saved as his look, never read by the sim. From C-MG-22.
- Bible intent: immersion; the art standard; "they look like clones" [director].
- Evidence: PCM 25 fans' next complaint after better graphics: "cyclists look too similar" [aggregate, Vaporlens].
- Exists today: `scripts/core/Appearance.gd` hair, beard and skin per player, no age term; row 6 (faces and hair) is the art brief.
- Size: M, after row 6. Tier: C.
- Does not: add sheets beyond row 6's.
- Conflicts: the `afl-art-pipeline` save contract for looks applies.

**P-36. Rain that arrives at a break.** A match's weather can change once, at a break, when the week's forecast says so ("Showers after half time" on the poster). The break sheet flags it and the rates switch from that quarter. From C-MG-20.
- Bible intent: weather should matter and "the system is not designed" (bible open question).
- Evidence: Motorsport Manager changing conditions mid-race [mechanic, GENRE §3.6].
- Exists today: one condition per match, fixed in the week (`scripts/sim/Weather.gd`, `Season.gd:489`); `WEATHER_RATES` per condition.
- Size: M (sim, calibration check, W7). Tier: C.
- Does not: roll weather every quarter; does not touch the look.
- Conflicts: "Balance is the director's to call" and "What can affect the sim": a mid-match rate switch is a sim change and needs his weather design and playtest.

### Theme 3. People remembered, and the voices around the club

**P-37. The club remembers him: on his sheet and at the drop.** The player sheet gets a "With us" block of at most three remembered facts chosen by significance and recency (debut, a final he won, the injury he came back from, the promise you kept); routine facts fade from the sheet but stay stored. The release confirm and the selection drop say one of them ("142 games with you; four goals in the 2028 elimination final"), then the same two buttons; quiet when there is none. From C-MG-16 and C-MG-17.
- Bible intent: a legacy; the risk belongs to the player; three lines, not a table.
- Evidence: CK3 memories, "some memories fade while important ones persist" [dev, diary 105, GENRE §3.11].
- Exists today: `CareerFacts.gd` read only by `Retirement.gd:63`; `Firsts.with_us_bits` (`GameState.gd:3945`); `PlayerSheet.gd:149-181` shows totals, clubs, honours; release copy is generic (`OffseasonScene.gd:274`). Distinct from RC-004.
- Size: S-M. Tier: B.
- Does not: delete any fact; no guilt copy; no hall of fame (P-41).
- Conflicts: none.

**P-38. Ahead of your list, or behind it.** The board's goal is already set from your list's pre-season rank; say that rank in words at season start ("The board rates this a bottom-six list"), show it in the season review beside where you finished, and keep a career line ("Five seasons: ahead of your list four times"). From C-MG-14.
- Bible intent: the game is objective about risk; a legacy.
- Evidence: Footy Redraft's club-specific benchmarks "frame achievement relative to starting circumstances" [director, GENRE §3.1].
- Exists today: `ClubLife.board_goal(rank)`; review shows "Goal: ... met/missed" (`SeasonReviewScene.gd:155-167`); the rank itself is never shown.
- Size: S. Tier: B.
- Does not: score or medal the career; no difficulty change (P-20 is decided).
- Conflicts: none.

**P-39. Your own record.** A coach's ledger on the stats hub: seasons in charge, wins and losses, finals, flags, the players you drafted who became B&F or All-Australian, the board's verdict each season. Plain words and plain counts; the dynasty's own page. From C-MG-29.
- Bible intent: "a story, a legacy, a dynasty".
- Evidence: "the resulting stories feel intensely personal" [critic, Game Informer].
- Exists today: this season's record (`StatsHubScene.gd:153-168`), board history (`GameState.gd:8500`); no multi-season coach ledger. P-42 would give it a club-to-club chapter.
- Size: S-M. Tier: B.
- Does not: Coach of the Year (an owned TODO).
- Conflicts: none.

**P-40. The club annual.** One page per season, oldest to newest: ladder finish, finals result, B&F, leading goalkicker, first draft pick, coach, one line the game writes about the year from its own facts. A Share button writes the whole career as plain text the phone can send. From C-PC-13.
- Bible intent: "a simulation that feels like a story, a legacy, a dynasty".
- Evidence: FM players write their saves up as stories [player, FM Scout](https://www.fmscout.com/q-13357-An-English-manager-lost-in-Scotland.html).
- Exists today: trophies by year (`stats/StatsTrophies.gd`), board history, `CareerFacts.gd`, `Firsts.gd`; no season page; "season story recap" is on the unassigned wishlist (open-requirements line 94).
- Size: M. Tier: B.
- Does not: export a save (P-02) or write prose beyond one line a year.
- Conflicts: none.

**P-41. The club's honour board.** A table of every player who left your club with 150 games, a B&F, a Brownlow or a flag for you: games, goals, B&Fs, flags, All-Australian jumpers as columns, newest first, each name a link to his career facts. A league version lists every retired Brownlow medallist and premiership captain. From C-PC-14.
- Bible intent: legacy; "the kid you backed" is still there after he has gone.
- Evidence: ZenGM Jun 2026 added MVP and championship columns to the Hall of Fame and keeps it fast in 3,000-season leagues [dev, changelog].
- Exists today: honours art and trophy room (`StatsTrophies.gd`, `assets/honours/`), `CareerFacts.gd`, `departed_names` in `FamilyTies.gd`; no honour board; "legends wall" and "club museum" are unassigned wishlist words (line 94).
- Size: M. Tier: B.
- Does not: retire jumper numbers (not an AFL convention) or add a museum scene.
- Conflicts: none.

**P-42. Another club's job: offered after a good year, open after a sacking.** After a strong season a rival board offers you its job in one letter: the club, its list in words, its goal, the risk stated; take it and your old club keeps living without you (its results in your news, your old players keeping their facts about you); decline and nothing changes. When the board sacks you, the same screen lists the jobs open that off-season, usually near the bottom; take one or retire with your record read out. From C-PC-11 and C-PC-12.
- Bible intent: the risk belongs to the player; a dynasty can have a second act.
- Evidence: OOTP "choosing whether to leave a team you've built is hard" [critic, Game Chronicles].
- Exists today: a coach market for AI coaches with sacked cooldowns (`scripts/sim/CoachMarket.gd`); `HubScene._sacked_card()` offers only Season review and Main menu (`:511-522`); nothing moves the human coach.
- Size: M-L. Tier: B.
- Does not: let you coach two clubs, carry your staff, soften the sacking or let you stay.
- Conflicts: none; `my_club` changes in the save, so the W7 lifecycle review applies.

**P-43. The Stats Geek has your numbers.** When a press answer claims something your record contradicts ("we back our kids" with no under-21 debut this year), the Stats Geek quotes the number back and the board and press effect follows the fact, not the claim. When the record supports you, the same answer lands harder. From C-MG-18.
- Bible intent: the press conference tests media literacy; an answer is a dice roll based on logic.
- Evidence: Esoteric Ebb's stat-dependent choices and remembered answers (GENRE §3.12); FM players answer pressers "mechanically" when nothing checks them [player, FM Scout].
- Exists today: `MediaConference.gd:106` the Stats Geek asks from a number that was true; no answer is checked against `CareerFacts` or the season record. RC-005 remembers an answer later; this checks it now.
- Size: M. Tier: B.
- Does not: add a journalist, an effect type or a new answer set.
- Conflicts: ch. 28 decision 2 says "the answer-to-effect rules are unchanged"; this changes which effect an answer earns, so it is his call.

**P-44. Drama words only when the facts say so.** Extend the Headlines rule (a line only when the match's facts support it) to story cards and comeback telling: a seeded ten-season run flags any card or note whose intensity words (collapse, crisis, miracle) fire on an ordinary match or a quiet week. From C-MG-30.
- Bible intent: a quiet professional win needs no fabricated turning point (GENRE §3.10).
- Evidence: RimWorld's story generator called "formulaic" when events repeat [player, GENRE §3.10].
- Exists today: `core/Headlines.gd` facts-gated; `core/ComebackTelling.gd`; `tools/audit/cards_impl.gd` audits reachability and dead choices (row 34), not register.
- Size: S. Tier: B.
- Does not: cut cards or add any.
- Conflicts: none.

**P-45. What the members are saying.** After a match, two lines from a stable cast of named members (the old timer, the family in the outer, the cheer squad) about the result and one call you made, written from match facts, no effect on the sim. The cast carries across seasons like the five journalists. From C-PC-27.
- Bible intent: "a believable world that responds to the coach".
- Evidence: FM26 lost its social feed and players called it a loss of immersion [critic, Blast.tv].
- Exists today: five journalists (#559), 8 members story cards, `Headlines.gd`; no supporter voice. Decision 3 cuts ordinary-week pressers, which leaves the quiet week this fills.
- Size: S-M. Tier: B.
- Does not: become a scrolling feed; two lines on the summary, then gone.
- Conflicts: "Restraint is a feature" (CLAUDE.md) and P-07's budget: it must not be a stop.

### Theme 4. The draft and the off-season

**P-46. Where the pick came from.** The draft board already says "Via Carlton" on a traded pick; add the player who went the other way ("Via Carlton, for Walsh") and keep it on the drafted player's sheet ("Taken with the pick from the Walsh trade"). From C-MG-28.
- Bible intent: the game shows what each decision led to; a risky pick that pays.
- Evidence: Footy Redraft's workflow "makes departures and resulting picks easy to connect" [director, GENRE §3.1].
- Exists today: `Draft.gd:37 pick_origin`; `DraftScene.gd:1697-1698` "Via <club>"; no link from a pick to the trade that brought it.
- Size: S. Tier: B.
- Does not: grade the trade.
- Conflicts: none.

**P-47. Pick order as the ladder settles.** From round 18 the ladder shows beside each club the first pick its position currently earns, and your club's line says which win or loss would move it. After the finals the draft order page shows who finished one game either side of your pick. From C-PC-18.
- Bible intent: make the rules transparent; a late-season choice has a visible price.
- Evidence: ZenGM Apr 2025 lottery page shows non-lottery picks "so you can see how close other teams are" [dev, changelog].
- Exists today: pick order shown only inside the draft (`DraftScene.gd:238`); the ladder (`stats/StatsLadder.gd`) carries no pick column.
- Size: S. Tier: B.
- Does not: add a lottery, a priority pick or any tanking incentive beyond the real order.
- Conflicts: none.

**P-48. This year's list problem in three lines.** The off-season screen opens with the three pressures compounding this year as facts: "Nine out of contract", "Your best six average 29", "Two list spots, three picks". No recommendation follows; the facts are the brief. From C-MG-15.
- Bible intent: reading the game is the skill (bible §4: each option shows its upside, downside, size and odds, never which is better).
- Evidence: AFCM "connects contracts, picks, drafting and club resources across seasons" and makes pressures tangible, while its opacity "erodes confidence" [director, GENRE §3.2].
- Exists today: "Out of contract (n)" list (`OffseasonScene.gd:176-188`), budget summary (`:112`), `ListProfile.gd` strengths in words. No opening brief.
- Size: S. Tier: B.
- Does not: add a dashboard of modifiers.
- Conflicts: none.

**P-49. Mark a player untouchable.** One toggle on your player's bio. Rivals stop asking for him in trade talks and requests, the toggle shows on the trade table, and it costs nothing but the offers you no longer hear. From C-PC-17.
- Bible intent: player agency; fewer repeated refusals.
- Evidence: ZenGM added "untouchable" assets because the AI kept asking for your best player or top pick [dev, blog 17].
- Exists today: nothing (grep `untouchable|not for sale`); rivals' offers to you exist (`tools/audit/trades_impl.gd`).
- Size: S. Tier: B.
- Does not: change his value or stop his own trade request if he asks out.
- Conflicts: none.

**P-50. Put a player on the table.** From his bio, "Ask around" names one of your players and every club answers in one line: not interested, interested and what it would give, or what else it would want, each reason in football words from the AI's real valuation. You then open the usual trade sheet with any club that answered. From C-PC-16.
- Bible intent: make the rules transparent; agency in list management.
- Evidence: OOTP 27 added a sortable "Shop Player" screen [critic, Sports Gamers Online](https://www.sportsgamersonline.com/?p=80069); OOTP players feel "more in control of the team's fate" [player](https://loudpoet.com/?p=33291).
- Exists today: a one-club trade sheet with a "shopping" prompt (`OffseasonScene.gd:611-612`), `TradeValue.gd` need and value; no league-wide ask. Uses P-18's reason text.
- Size: M. Tier: B.
- Does not: build the staggered trade period (M6-004).
- Conflicts: none.

**P-51. Trade a pick on the night.** During the National Draft, when your pick is next, "Trade this pick" offers it to the clubs behind you for their pick plus a later one, each answer in one line with its reason; accept and the board updates live. From C-PC-28.
- Bible intent: agency at the moment of risk.
- Evidence: ZenGM enabled draft-day trades after players asked [dev, blog 17].
- Exists today: traded picks owned and tracked (`Draft.gd:37-38,197`); nothing trades a pick during the draft. M6-004 is the off-season half.
- Size: M. Tier: C until P-15 (draft night) exists, then B.
- Does not: trade players on the night or add pick-value charts.
- Conflicts: none; W7 review.

**P-52. The draft year has more than one day.** Two beats before the November draft: a mid-season week when the under-18 championships are played and the hub names three prospects who starred, by position and state, no grades; and a mid-season rookie draft (a real AFL mechanism) where a club with a list spot takes one state-league player, AI clubs included. From C-PC-10.
- Bible intent: the defining moment is a risky draft pick; immersion.
- Evidence: the youth intake is "the most anticipated day of the year" [player, FM Scout]; a once-a-year intake "isn't how it works in the Real World" [player, Steam](https://steamcommunity.com/app/1904540/eventcomments/3802776070761122828).
- Exists today: `Prospects.gd:122` academy and Talent League origins, `Combine.gd`, `DraftScouting.gd`; no mid-season draft or carnival beat. P-15 stages the November night.
- Size: M. Tier: B.
- Does not: add grades, a recommended pick or a second full draft.
- Conflicts: none written, but the mid-season draft adds a recruitment event to the lifecycle (W7) and changes AI lists, so it touches the sim and is his call.

### Theme 5. The club's history and the league around you

**P-53. Every club has a page.** Tap any club name anywhere and one page opens: its colours, home ground, coach, captain, best 22 in words by line, last five results, flags and the year of the last one, and the players it took from you or you took from it. The same page serves your own club. From C-PC-15.
- Bible intent: "a readable opponent"; immersion.
- Evidence: FM26 removed club pages and tournament histories and players called the loss "immersion" [critic, Blast.tv].
- Exists today: a trade sheet per club (`OffseasonScene.gd:778`), your own honour sheet (`StatsTrophies.gd:518`), `core/ClubHistory.gd`, `Rivalries.gd`; no general club page; club names are not links. RC-007 would feed this page.
- Size: M. Tier: B.
- Does not: show a rival's hidden ratings or private trade intentions (PR #759 closes that leak).
- Conflicts: none.

**P-54. B&F medals by their real names.** The club best and fairest is presented under its real name (Doig Medal, Charles Sutton Medal, Syd Barker Medal and so on), with one line of who it is named for; a Forge club names its own medal when it is created. From C-PC-24.
- Bible intent: immersion; the look of Forge creations is the coach's.
- Evidence: ZenGM "Extremely customizable awards" (Sep 2026) [dev, changelog].
- Exists today: Brownlow, Coleman and Norm Smith named (`Awards.gd:6-12`), club B&F unnamed; honours art `club_bnf.png`; no medal names in `data/`.
- Size: S. Tier: B.
- Does not: change how votes are counted.
- Conflicts: none; real medal names go on the licence register with real club names (release plan Phase 0) before anything public.

**P-55. Announce what already changes.** The cap already grows 3% a year in silence; the off-season news says so in one line with the season it starts, and the same line carries any list-size or expansion toggle the career was started with. From C-PC-31 (the half that changes nothing).
- Bible intent: understandable; a believable world over decades.
- Evidence: year-on-year sameness is the stagnation complaint [aggregate, Vaporlens PCM 25]; ZenGM real-players leagues track real expansion plans [dev, blog](https://zengm.com/blog/).
- Exists today: `Contracts.gd:37-46` cap step, Tasmania and Canberra toggles (M7-009); nothing announces a change.
- Size: S. Tier: A.
- Does not: change any rule.
- Conflicts: none.

**P-56. Challenge starts.** Beside League redraft and Real lists, named starts with one constraint said up front: Youth only (no trades or signings for players over 24), Rebuild (the bottom club with its three best players gone), and a goal you set yourself (a flag with a home-grown 22, 300 games coached) that the annual marks when it is met. From C-PC-26.
- Bible intent: roleplay; the risk belongs to the player.
- Evidence: MyNBA Eras "one of the best features available in sports games today" [critic, Game Informer](https://www.gameinformer.com/review/nba-2k25/best-kept-on-the-court).
- Exists today: two starts, "redraft" and "real" (`scripts/ui/Main.gd:292`); no challenge or goal.
- Size: M. Tier: B.
- Does not: recommend a goal or score it; a goal is met or not.
- Conflicts: none.

**P-57. League rules change over a career.** Over a long career the AFL announces, in the off-season, one change at a time in plain words: a list-size change, an expansion club's entry year, a rule the director has approved. Each is a news line with the season it starts, so a 20-year save is not 20 copies of 2027. From C-PC-31 (the half that changes the sim).
- Bible intent: immersion over decades.
- Evidence: OOTP 25 "Dynamic Evolution" changes league rules and economics over time [critic, GameCritics].
- Exists today: nothing; P-55 carries the announcement.
- Size: L. Tier: C.
- Does not: change a match rule without the director's written yes.
- Conflicts: "What can affect the sim" (CLAUDE.md, bible): every rule change does, so each needs his decision.

**P-58. Fix a player yourself, or load your own list.** An editor in Settings changes one player's role, OVR, POT or age in your save, and his bio says "edited by the coach" forever; the game also reads an optional `players_override.csv` from `user://` so a player can carry his own corrections or a fictional league. From C-PC-29.
- Bible intent: roleplay; the director's own list of about 60 OVR corrections (ch. 27 A23/A25) shows the need.
- Evidence: ZenGM God Mode [dev, blog].
- Exists today: overrides live in the repo (`data/potential_overrides.csv`, PR #761), not in a save or `user://`.
- Size: M. Tier: C.
- Does not: edit the AI's hidden state or the match rules.
- Conflicts: "Balance is the director's to call" for the shipped numbers; an edit is the player's own save.

**P-59. Start in a past season.** A start from an earlier AFL year with that year's lists, so the alternate history begins where the player's memory does. Honest cost: historical list data with provenance and the same licensing question as real names. From C-PC-30.
- Bible intent: "build their own alternate history".
- Evidence: MyNBA Eras praised [critic, Game Informer]; OOTP historical seasons "with accurate statistics, stadiums" [critic, GameCritics].
- Exists today: 2026 lists only (`data/players_2026.csv`, `docs/DATA_SOURCES.md`); League redraft is the alternate start that exists.
- Size: L. Tier: C.
- Does not: propose which year; the data decides.
- Conflicts: none written; licensing (release plan Phase 0) first.

### Theme 6. Fewer taps, nothing hidden

**P-60. Two taps to any fact, enforced.** Name the facts a coach reaches for each week (who is injured, out of contract or in form, their best player, the weather, the ladder, the fixture, a bio, the draft order, the board's goal, your calls at the last break, the cap) and count the real taps from the hub to each in a seeded career. The map is a test with a ceiling of two taps and no scroll past one screen; three taps fails CI. From C-PC-02 and C-MG-23.
- Bible intent: "no excessive UI"; no "arthritis from clicking".
- Evidence: FM26 "information locked away behind a series of different windows" [critic, Soccer Gaming]; director A12/A14 scrolling to reach stats [director, ch. 27].
- Exists today: `core/Router.gd`, `back_nav` suite (floor 370), one-round hub glance (`HubScene.gd:1547-1597`); nothing counts taps forward.
- Size: S-M. Tier: A.
- Does not: redesign any screen; it reports where the ceiling is broken.
- Conflicts: none.

**P-61. Tap any football word or oval mark for its rule.** Every rule word the game uses (Press, Loose man, Tag, Plan fluency, Rising Star, Wildcard week) is a long-press target wherever it appears and opens one paragraph saying what the rule needs and costs; a legend one tap from the match screen names every mark on the oval (disc, ring, clash strip, tag line, loose man, breeze arrow) in one line each, and each mark is taught once the first time it appears, flag saved. One source of text per term, shared with the stat guide. From C-PC-04 and C-MG-24.
- Bible intent: "make the rules transparent, don't make the decision"; understandable, not obtuse.
- Evidence: Motorsport Manager "everything is coded... help text is always a click away" [critic, OSFTW].
- Exists today: stat guide (#757), "3 pages of text" (A17); stats key under the player table (`match/PlayerStatsTable.gd:105`); `GameState.tutorials`; row 27 topic grid open; no inline lookup or oval legend.
- Size: S-M. Tier: A.
- Does not: explain percentages or recommend when to use the rule. P-03 owns the walkthroughs; P-13 lays options beside an opponent fact.
- Conflicts: none; CLAUDE.md already asks for every rule to be lookable up exactly.

**P-62. Intent on the button, with the odds beside it.** Reversed by the director on 2026-10-18, after it was approved as "never odds" (bible §4: "Every decision gate says what each option does for you and what it costs, with the size and the odds, in football words"). Every call button says what it changes in football words ("Push two up the ground; thinner behind the ball") and, for each option, its upside, downside, size and odds as percentages, never which option is better. The CI lint first described here (fail any percent sign or "chance of" outside the stats tables) is the old rule; `tools/check_player_facing_odds.py` still enforces it and needs retiring or turning into a check that every gate names a positive and a negative. From C-MG-21.
- Bible intent: decisions move the odds, never the certainty; reading the game is the skill (bible §4).
- Evidence: Into the Breach's postmortem on readable intent; "reject exact next-play forecasts in stochastic football" [dev, GENRE §3.18].
- Exists today: 19 percent or "chance" hits in UI copy, none of them odds; plan blurb PR #755 open; no lint in `tools/`.
- Size: S. Tier: A.
- Does not: hide the rules; the stat guide stays.
- Conflicts: none.

**P-63. Every system names its one trade-off.** An audit listing each off-field system (budget buckets, season plan, training, culture, captaincy, rotation policy) and the one sentence on its screen that says what it costs. A system with no cost either gets one or leaves the main surfaces until it has one; Culture's header says "They have no effect yet". From C-MG-06.
- Bible intent: understandable; a visible rule which never matters is a trust problem (GENRE §3.2).
- Evidence: Golden Lap's finances "never feel overwhelming" because each is one trade-off [critic, Traxion].
- Exists today: costs said in `Captaincy.gd`, cards (#688), `TAGGER_COST`; `scripts/sim/Culture.gd` header "They have no effect yet"; `ClubBudget.gd` four buckets.
- Size: S (audit), then S per fix. Tier: A.
- Does not: give culture an effect (ch. 26 s5 "small, then measure" owns that).
- Conflicts: none.

**P-64. What the staff's grade does for you.** Each of the three staff grades already shown (Teaching, Tactics, Man-management) gets one line saying what it touches on the ground, in football words, the way ListProfile explains a strength; the hire screen states the trade-off of a vacant job in the same words. No number appears. From C-MG-05.
- Bible intent: make the rules transparent; understandable, not opaquely implemented.
- Evidence: Astonishing's "confuses me too much" when a rule is hidden [player, App Store].
- Exists today: grades in words (`StaffScene.gd:228-230`); the three effects named only in the `CoachEffects.gd` header; `ListProfile.MEANS` is the pattern.
- Size: S. Tier: B.
- Does not: add staff traits, schemes or a fourth effect.
- Conflicts: none.

**P-65. Find anyone from the hub, and keep a shortlist.** A search field reachable from the hub finds any player or club in the league by name and opens his bio or its page; a long-press on any name adds him to your shortlist (prospects, rivals' stars, your own kids), a flat list on one screen with each name a link. From C-PC-09.
- Bible intent: "no excessive UI"; reading the game is the skill in list management.
- Evidence: SI restored "bookmarks and search" after FM25 failed [dev, FM Scout].
- Exists today: search only inside the draft board (`DraftScene.gd:622`); every name a link (PRs #766/#768 open); no league-wide search or shortlist.
- Size: S-M. Tier: A for search, C for the shortlist.
- Does not: rank or filter by rating; a name finds a person.
- Conflicts: none.

**P-66. Standing orders when you sim.** One sheet, "When I sim the week", states what the assistant does in your absence (your standing plan, who he tags and why, who he rests, how he answers the press) and lets you set each line once. Sim the week follows it and stops only for what no line covers. From C-PC-25.
- Bible intent: "Playing hands-off is the gamer's call"; the simpler answer to the bible's pre-timeskip survey question.
- Evidence: FM players skip only when skipping does not cause hidden drift, "the assistant usually manages to get the whole squad to rebel" [player, FM Scout].
- Exists today: a standing plan (`GameState.gd:60 club_plan`), the assistant's tagger pick (`MatchScene.gd:1255`), "Ask before simming" (`OptionsSheet.gd:50`); no sheet showing the lines together.
- Size: M. Tier: B.
- Does not: answer a mandatory stop for you.
- Conflicts: none.

**P-67. What happened while you were away.** After Play ahead (four rounds or to the end of the home and away) one sheet: each result in a line, injuries, contract clocks reached, trust moves with their reasons, cards answered by default; then the hub. From C-MG-27.
- Bible intent: the risk of playing hands-off is his, so he sees the bill.
- Evidence: FM players accept skipping only without hidden drift [player, FM Scout].
- Exists today: one-round hub glance (`HubScene.gd:1547-1597`); play-ahead options (`:1195-1215`); no multi-round ledger.
- Size: S-M. Tier: B.
- Does not: add stops (P-07 owns the budget).
- Conflicts: none.

**P-68. A control you never used, mentioned once.** After a full season in which a control was never touched (a tag, a rotation policy, the long-press group select), one line names it once, in the place it lives, and never again; written to the save like the first-visit tips. From C-PC-33.
- Bible intent: understandable, not obtuse.
- Evidence: OOTP 25's tutorial praised for "revealing actions that longtime players had missed" [critic, GameCritics].
- Exists today: first-visit flags (`GameState.tutorials`); nothing tracks unused controls. P-03 covers fresh saves; this is the veteran's season two.
- Size: S. Tier: C.
- Does not: say the control should be used; it says it exists.
- Conflicts: CLAUDE.md's rule against recommendation prompts; the line names a control, never a decision, and its wording must be checked against that rule.

**P-69. Keyboard shortcuts you can see and change.** On PC a Settings page lists every shortcut (space to sim, 1-4 for speeds, Escape for Back) and lets each be rebound; the keyboard test suite reads the same table. From C-PC-32.
- Bible intent: intuitive interfaces, desktop as the secondary platform.
- Evidence: remapping is one of the four most-complained accessibility items [mechanic, GAG].
- Exists today: `keyboard` suite (floor 445); no shortcut list or remap in Settings.
- Size: S. Tier: C.
- Does not: touch phone input.
- Conflicts: none.

### Theme 7. Trust, saves and the store

**P-70. The promise, printed and enforced.** The main menu's About and the store page say, in one line: "Plays offline. No ads, no purchases, no account. Your career stays on your phone." A CI check reads `export_presets.cfg` and fails if the Android preset ever requests the internet permission or a billing library. From C-MG-07.
- Bible intent: trust in the maker is part of a believable world.
- Evidence: Footy Mayhem's listing leads with "no ads and no pay-to-win" [mechanic, App Store].
- Exists today: bible premium, zero MTX; Android preset requests only vibrate (`export_presets.cfg:36`); no About line, no preset check.
- Size: S. Tier: A.
- Does not: set a price; P-23 (decided) owns the page itself.
- Conflicts: none.

**P-71. Let the phone and the browser keep the save.** Turn on Godot's Android user-data backup so the system's own device backup carries the career to a new phone with no server of ours, and keep the save under the 25 MB ceiling (P-05's numbers prove it). The web build asks for persistent storage on the first save and, when refused, shows one line: "This browser may clear your career; export it from Settings." From C-MG-08 and C-MG-09.
- Bible intent: the decades need to survive a phone change; a risk told before it bites.
- Evidence: Retro Bowl Android's top complaint "progress loss when switching devices" [aggregate, marlvel.ai]; Basketball GM FAQ: "iOS is especially aggressive about removing data from unused web apps", mitigations Persistent Storage and Export [dev, FAQ].
- Exists today: no `user_data_backup/allow` line in `export_presets.cfg`; web preset (`:93`) has no `storage.persist` call; release plan Review Focus 2 calls web save safety unproven. P-02 is the manual export.
- Size: S. Tier: A.
- Does not: sync Android with PC or web; no accounts, no server.
- Conflicts: none.

**P-72. Patch notes that name the football change and what was removed.** A note template: each line says what changed on the ground or the list ("Tagged rucks now lose fewer centre-bounce taps"), who it affects, and whether old saves carry over; "Stability improvements" alone fails a lint. Before each itch upload the review-sheet captures are diffed against the live build's, and any control present live and missing in the candidate is named in the notes or the ship stops. From C-PC-07 and C-MG-12.
- Bible intent: "dont write misleading patch notes" (ch. 26 s8) [director]; trust in the maker.
- Evidence: FM26 "Regression from previous versions" 51 mentions, "Stick with FM24" 20 [aggregate, Vaporlens FM26].
- Exists today: `docs/ITCH_UPLOAD.md` Notes, `ui-review.yml`, `capture.yml`, `tools/ship_main.sh`; no template, lint, diff or "removed" section. P-08 shows notes in-game; this is what they say.
- Size: S. Tier: A.
- Does not: block a deliberate removal; it makes it named.
- Conflicts: none.

**P-73. Answer every review, and explain one rule at a time.** A release rule: every itch comment and store review gets a reply within a week, in football words, naming the build the fix lands in; replies are listed in the next devlog. Beside the devlog, short posts explain one rule each (how the AI drafts, why a club refuses a trade, what weather does), and a public roadmap page says what is in, what is out and where feedback is read. From C-MG-11 and C-PC-34.
- Bible intent: none directly; release practice. P-11 gives the player the seed; this is what we do with it.
- Evidence: visible developer replies recur under praised indies (Pocket GM, Astonishing) [player, App Store].
- Exists today: devlog-per-upload rule (`memory/itch-builds-devlog-and-saves.md`); `docs/ITCH_UPLOAD.md` has no reply rule; balance evidence docs exist but are not written for players.
- Size: S, then S per post. Tier: A for the reply rule, C for the posts.
- Does not: promise a fix or a date; does not promise what is not built.
- Conflicts: none in game (bible §4 and CLAUDE.md: every decision gate shows its odds; a post outside the game is his decision).

**P-74. The list of what we are not building.** A one-page "Not in this game" that the director fills (candidates: playable control, multiplayer, 3D, commentary, light mode, AFLW, microtransactions), printed in About and on the store page. It answers the bible's own open question. From C-MG-26.
- Bible intent: open question "What will this game deliberately not have?"; restraint is a feature.
- Evidence: Simon Read refuses features that "risk upsetting the balance of the game and the simplicity that has brought it success" [dev, PocketGamer.biz].
- Exists today: `DESIGN_BIBLE.md:168` open question; scattered "out of scope" lines in roadmap cards; no one page.
- Size: S. Tier: A.
- Does not: edit the bible; agents draft the candidates, he writes the list.
- Conflicts: "Nobody edits the bible without the director": the list is his to write; the proposal is only the page that prints it.

**P-75. Five screenshots and a thirty-second passage.** Store assets in the order of the fantasy: a passage on the oval, draft night, the kid you backed, the press room, the ladder; each in a colourful club, phone portrait, produced by `capture.yml` and checked by the screen-critic before the director sees them. One 30-second watched passage is the clip. From C-MG-13.
- Bible intent: none directly; release practice, so the director's call.
- Evidence: Hoop Land's page leads with modes and customisation [mechanic, Steam]. No trailer evidence was found; this is store convention, not proof.
- Exists today: `capture.yml` contact sheets, `ui-review.yml` review sheets; P-23 (decided yes) is the home.
- Size: S-M. Tier: C (after P-23).
- Does not: write the description or choose a price.
- Conflicts: none; "no Collingwood in captures" (memory) stands.

### Theme 8. Audits that protect the fun

**P-76. Picture and truth never disagree, and never an empty ground.** A seeded match recorded as drawn positions per tick, with asserts: no disc moves faster than a footballer runs, no disc jumps, the ball is always with a player or in flight, every frame at 8x has 36 discs and the ball inside the oval and a score on screen, and the feed, the scoreboard and the engine agree at every event. Each vignette's first frame is checked against its intended sheet so a fallback never passes. From C-PC-03 and C-MG-10.
- Bible intent: "a ball that hovers, or acts independently of the player using it" must never reach the director.
- Evidence: FM26 defender "seemingly trapped within the goal" [critic, Use a Potion].
- Exists today: goals add up across players, quarters and scoreboard (`tests/test_match_game.gd:505`); no motion plausibility or per-frame disc count. Director rows 10-12 (collection pauses, play-on) are the defects this would catch early.
- Size: M. Tier: A.
- Does not: change `MatchMotion.gd` steering or measure speed (P-05); it measures the picture.
- Conflicts: none.

**P-77. One sweep of every screen: overflow at every text size, every target thumb-sized.** One shared helper builds every registered screen in a seeded career at 360x740 and at each text size P-04 adds, and fails on any label wider than its rect, any control outside the viewport, any clipped line, and any button or tappable row under 44 px, naming the node. From C-PC-05 and C-MG-25.
- Bible intent: readability pillar; thumb-sized targets (CLAUDE.md).
- Evidence: FM26 "text running off tiles or slight misalignments" [critic, FRVR].
- Exists today: per-screen asserts in four suites (`run_matchday_tests.gd:381`, `run_stats_tests.gd:490`, `run_draft_ui_tests.gd:1055`, `run_career_ui_tests.gd:1913`) and thumb checks in `run_career_ui_tests.gd`; `UiKit.gd:1155` 48 px minimum. No shared helper, no larger text sizes.
- Size: S. Tier: A.
- Does not: fix layouts; it finds them. Depends on P-04 for the sizes.
- Conflicts: none.

**P-78. Time budgets per action.** Once P-05's phone numbers exist, each action gets a budget in `PERF_BASELINE.md` (hub opens, Sim the week completes, a simmed match resolves, a season rollover finishes, a 20-season save loads) and the CI extras job fails when a desktop run exceeds its scaled budget. A hands-off season has one headline target the devlog can promise. From C-PC-08.
- Bible intent: "clean and crisp like a great app does"; the player sets the pace.
- Evidence: ZenGM "Making a game 10x faster changes how people play it" [dev, blog 17].
- Exists today: `tools/perf/`, `tools/ci_suite_timings.json` (suite timings only), `match_game` timed out at 900 s on main; no per-action budget.
- Size: M. Tier: A.
- Does not: optimise before the numbers exist; the director sets the budgets once he has seen the phone.
- Conflicts: none.

**P-79. No plan wins everywhere.** A seeded audit plays every game plan against every other across weak, even and strong lists; the pass line is that no plan wins more than a stated share against all comers regardless of list. The result is written into the term sheet in football words ("Press suits a young, fit midfield and tires late"). From C-PC-21.
- Bible intent: "Decisions move the odds, never the certainty".
- Evidence: FM26 tactics praised yet one gegenpress "still seemed the most reliable approach" [critic, Soccer Gaming].
- Exists today: press head to head with each plan (`tools/audit/plan_shape_impl.gd h2h_<plan>`), one lever against a baseline (`levers_pair_impl.gd`); no full round robin across list strengths and no published rule.
- Size: M (runners, `afl-audit-runs`). Tier: B.
- Does not: retune anything; it reports, and the director decides.
- Conflicts: "Balance is the director's to call": the audit measures, he rules.

**P-80. A fun floor beside the realism floor.** Run the dynasty bot (a competent coach, not a perfect one) through 20 seasons on many seeds and report how often it reaches finals within five seasons and wins a flag within fifteen. The calibration suite says the league looks like the AFL; this says a good coach can win in it. From C-PC-22.
- Bible intent: "Perfect coaching with a weaker list maximises your chances but guarantees nothing"; the defining moment must be reachable.
- Evidence: Golden Lap balance "swings from struggling to dominating" [critic, Traxion].
- Exists today: 0 flags in 35 autopilot seasons (`docs/DIFFICULTY_EVIDENCE_2026-10-05.md`; autopilot does not coach); `flags_impl.gd`, `tools/balance/dynasty.gd`; no managed-career win-rate audit.
- Size: M (runners). Tier: B. Feeds the sizes of P-20's dials (decided).
- Does not: declare balance done.
- Conflicts: "Balance is the director's to call": the numbers go to him.

**P-81. List churn stays real.** Per off-season the audit counts, for every AI club, players delisted, signed, traded and retired, against the real AFL yardstick (list changes per club per year), and fails when an AI club turns over far more or far less than real clubs do. From C-PC-23.
- Bible intent: a believable league; immersion breaks when ratings and lists do not reflect reality.
- Evidence: OOTP 26's "biggest problem" named as excessive AI signing and releasing [critic, WASDland](https://www.wasdland.com/game/out-of-the-park-baseball-27-4045750/).
- Exists today: `long_career_impl.gd` prints intake, releases and retirements per rollover; `trades_impl.gd` counts trades against real volume; no per-club churn yardstick. Pairs with row 37.
- Size: S. Tier: B.
- Does not: change list rules.
- Conflicts: none.

## 2. Re-raised and declined again, with the evidence

Neither miner proposed these as features; two candidates leaned on their evidence and are kept in the form that avoids the decline.

- **A 3D match view.** The new evidence is that FM players want 3D "for goal replays" and 2D for reading shape [player, FM Scout]. That argues for replaying goals, not for 3D: P-33 replays them on the oval or in the 2.5D vignette. The live-3D probe stays on the register (row 38).
- **Spoken commentary.** F1M22 triggers audio early to sync with the picture [dev, Game Developer]; F1M24's licensed voices still earned "monotonous" and "odd delays" [critic, Shacknews]. The lesson is timing, not voices: P-32 puts the roar and the siren on the right frame. The written feed stays the register.
- **More story cards before the cadence audit.** Not re-raised. P-44 checks the register of existing cards; P-45 adds two supporter lines from match facts, not cards.

## 3. Index

Themes: 1 Match day on a phone, 2 The oval and the broadcast, 3 People remembered, 4 The draft and the off-season, 5 History and the league, 6 Fewer taps, nothing hidden, 7 Trust, saves and the store, 8 Audits that protect the fun.

| P | Title | Theme | Tier | Size | Conflicts |
|---|---|---|---|---|---|
| P-25 | One thumb on match day | 1 | A | M | N |
| P-26 | The score never leaves the screen | 1 | A | S | N |
| P-27 | Full time ends on the next poster | 1 | B | S | N |
| P-28 | The call's own counter beside the oval | 1 | B | M | N |
| P-29 | What is expected of you this week | 1 | B | S | N |
| P-30 | A moment is a window, not a stop | 1 | C | M | Y |
| P-31 | Show the breeze end | 2 | B | S | N |
| P-32 | The crowd knows the score, siren on the tick | 2 | B | M | N |
| P-33 | Watch the goals again | 2 | B | M | N |
| P-34 | Kit clash checked for colour-blind eyes | 2 | A | S | N |
| P-35 | He gets older on the stage | 2 | C | M | Y |
| P-36 | Rain that arrives at a break | 2 | C | M | Y |
| P-37 | The club remembers him: sheet and drop | 3 | B | S-M | N |
| P-38 | Ahead of your list, or behind it | 3 | B | S | N |
| P-39 | Your own record | 3 | B | S-M | N |
| P-40 | The club annual | 3 | B | M | N |
| P-41 | The club's honour board | 3 | B | M | N |
| P-42 | Another club's job | 3 | B | M-L | N |
| P-43 | The Stats Geek has your numbers | 3 | B | M | Y |
| P-44 | Drama words only when the facts say so | 3 | B | S | N |
| P-45 | What the members are saying | 3 | B | S-M | Y |
| P-46 | Where the pick came from | 4 | B | S | N |
| P-47 | Pick order as the ladder settles | 4 | B | S | N |
| P-48 | This year's list problem in three lines | 4 | B | S | N |
| P-49 | Mark a player untouchable | 4 | B | S | N |
| P-50 | Put a player on the table | 4 | B | M | N |
| P-51 | Trade a pick on the night | 4 | C | M | N |
| P-52 | The draft year has more than one day | 4 | B | M | Y |
| P-53 | Every club has a page | 5 | B | M | N |
| P-54 | B&F medals by their real names | 5 | B | S | N |
| P-55 | Announce what already changes | 5 | A | S | N |
| P-56 | Challenge starts | 5 | B | M | N |
| P-57 | League rules change over a career | 5 | C | L | Y |
| P-58 | Fix a player yourself, or load your own list | 5 | C | M | Y |
| P-59 | Start in a past season | 5 | C | L | N |
| P-60 | Two taps to any fact, enforced | 6 | A | S-M | N |
| P-61 | Tap any football word or oval mark for its rule | 6 | A | S-M | N |
| P-62 | Intent on the button, never odds | 6 | A | S | N |
| P-63 | Every system names its one trade-off | 6 | A | S | N |
| P-64 | What the staff's grade does for you | 6 | B | S | N |
| P-65 | Find anyone from the hub, and keep a shortlist | 6 | A | S-M | N |
| P-66 | Standing orders when you sim | 6 | B | M | N |
| P-67 | What happened while you were away | 6 | B | S-M | N |
| P-68 | A control you never used, mentioned once | 6 | C | S | Y |
| P-69 | Keyboard shortcuts you can see and change | 6 | C | S | N |
| P-70 | The promise, printed and enforced | 7 | A | S | N |
| P-71 | Let the phone and the browser keep the save | 7 | A | S | N |
| P-72 | Patch notes name the change and what was removed | 7 | A | S | N |
| P-73 | Answer every review, explain one rule at a time | 7 | A | S | N |
| P-74 | The list of what we are not building | 7 | A | S | Y |
| P-75 | Five screenshots and a thirty-second passage | 7 | C | S-M | N |
| P-76 | Picture and truth never disagree | 8 | A | M | N |
| P-77 | One sweep of every screen | 8 | A | S | N |
| P-78 | Time budgets per action | 8 | A | M | N |
| P-79 | No plan wins everywhere | 8 | B | M | Y |
| P-80 | A fun floor beside the realism floor | 8 | B | M | Y |
| P-81 | List churn stays real | 8 | B | S | N |

Counts: 57 proposals; Tier A 17, Tier B 30, Tier C 10; a written rule or the sim is named under Conflicts on 12.

## 4. How to decide

Fifty-seven single questions is too many. Eight bundles, one yes/no per theme, cover 53 proposals: "yes" means build that theme's Tier A and B items in the order listed in section 1 and skip its Tier C items; Tier A items join the 1.0 plan as decision 1 does for P-01..P-11. Four proposals touch the sim or a written rule, get their own question and are excluded from their bundle. Twelve questions. Recommended answer first; game impact in one sentence. Nothing starts until he assigns it.

1. **Match day on a phone (P-25 to P-29; skip P-30)?** Recommended: yes. Impact: the score and every live control stay under the thumb, and the poster says what this week is worth before the bounce.
2. **The oval and the broadcast (P-34, P-31, P-32, P-33; skip P-35; P-36 asked below)?** Recommended: yes. Impact: the breeze end, the crowd and the goals replay make the oval read like a broadcast without touching the sim.
3. **People remembered (P-37 to P-42, P-44, P-45; P-43 asked below)?** Recommended: yes. Impact: the facts the game already stores about a player reach his sheet, the drop, your ledger and an honour board, and a sacking stops being the end.
4. **The draft and the off-season (P-46 to P-50; skip P-51; P-52 asked below)?** Recommended: yes. Impact: the off-season opens with the list problem in three lines and every pick and trade says where it came from and who said no.
5. **History and the league (P-55, P-53, P-54, P-56; skip P-57 to P-59)?** Recommended: yes. Impact: every club has a page, the B&F has its real name, the cap step is announced and a career can start as a challenge.
6. **Fewer taps, nothing hidden (P-60 to P-67; skip P-68, P-69)?** Recommended: yes. Impact: any weekly fact is two taps away by test, every rule word opens its rule, and Sim the week follows orders you set once.
7. **Trust, saves and the store (P-70 to P-74; skip P-75)?** Recommended: yes. Impact: the offline promise is printed and enforced, Android and the browser keep the save, and every patch note names the football change.
8. **Audits that protect the fun (P-76 to P-81)?** Recommended: yes. Impact: CI catches a hovering ball, a clipped label, a slow rollover, a plan that beats everything and an AI club that churns; you still make every balance call.
9. **P-52: add the under-18 carnival week and a mid-season rookie draft?** Recommended: yes, carnival first. Impact: the draft year gets two more days and every AI club can take a rookie mid-year; W7 review.
10. **P-43: the Stats Geek checks a press answer against your record?** Recommended: yes. Impact: a boast the record contradicts costs you and one it supports lands harder; the effects stay, which one you earn changes.
11. **P-36: weather can change once at a quarter break?** Recommended: not yet, after your weather design. Impact: a match's conditions can turn at half time, which changes rates mid-match and needs your playtest.
12. **P-57: the league's rules change over a long career?** Recommended: not yet; announce the cap step (P-55) first. Impact: a 20-year save stops being 20 copies of 2027, but each change alters the sim and needs your yes.

## Director's decisions, 2026-10-18

All eight theme bundles: yes. P-52: "Yes, carnival first". P-43: yes. P-36 and P-57: not yet. Recorded with the
authorised proposal list in [roadmap chapter 29](../roadmap/29-director-decisions-2026-10-18-pass2.md).
