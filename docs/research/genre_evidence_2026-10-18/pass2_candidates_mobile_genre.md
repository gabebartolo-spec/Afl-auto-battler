# Pass 2 candidates from the mobile and genre evidence

_Second mining pass, 2026-10-18, after the director said the first report had not got everything out of the research. Sources read in full: `SPORTS_MANAGEMENT_GENRE_COMPARISON_2026-10-18.md` (P-01..P-24), `docs/DESIGN_BIBLE.md`, `mobile_sports_management.md`, `docs/GENRE_ENJOYMENT_RESEARCH.md` §3-§7, `our_game_audit.md`. Nothing below repeats P-01..P-24, RC-003..RC-007, an open PR (#636-#774) or an item the audit lists as already proposed. "Exists today" is from a grep or a read of the named file on branch `sim-the-week-and-scroll-fixes`; nothing was run. Labels: [player] [dev] [critic] [aggregate] [mechanic] [director]. Sizes: S under a day, M a few days, L a week or more. Tiers: A professional baseline, B makes the fun land, C later._

## Match day on a phone

**C-MG-01. One thumb on match day.** Every control a coach touches during live play (speed, skip, a moment's choices, the break sheet's actions) sits in the lower part of the portrait screen and nothing needs a scroll while the ball is in play. A real-tap test at 360x740 and 420x860 asserts each control's centre is within thumb reach and that no live control is covered.
- Bible intent: player agency in the match; readability and intuitive interfaces.
- Evidence: FM24 Mobile "In-match control is much improved", the critic made more mid-game changes because mentality was one tap away [critic, iMore, mobile notes Q2]; Footy Mayhem "tiny joystick" [player, App Store, Q1]; FM24 Mobile icons "too small to navigate smoothly" [critic, iMore, Q4].
- Exists today: upright oval (#724); side panel 120 or 168 tall on a phone (`scripts/ui/MatchScene.gd:213-224`); the PC break sheet notes its choices are "a mouse, not a thumb" (`MatchScene.gd:71-73`); `tests/tap.gd`. No thumb-reach test for the match screen.
- Size: M. Tier suggestion: A.
- Does not: change what any call does; does not redesign the oval.
- Conflicts: none.

**C-MG-02. Full time ends on the next poster.** The last thing on the full-time screen is the next match in one line (opponent, ground, forecast) and one button that lands on the hub with that poster already up. Measure the time from the final siren to the next bounce on the reference phone and publish it beside P-05's numbers.
- Bible intent: designed for a player who plays most matches; no arthritis from clicking.
- Evidence: Retro Bowl "a game to play regularly in short bursts" [critic, Nintendo Life via OpenCritic, Q1]; "you can play many games in one sitting" [critic, Pure Nintendo, Q1]; Football Chairman Pro seasons pass "in minutes" [critic, Pocket Tactics, Q1].
- Exists today: full-time overlay with Continue and Training buttons (`MatchScene.gd:3226-3254`), hub poster (`MatchPoster.gd`). No next-match line at full time; no siren-to-bounce measurement. P-07 counts stops; this is the hook at the end of the match.
- Size: S. Tier suggestion: B.
- Does not: auto-start the next match or skip any stop.
- Conflicts: none.

**C-MG-03. The call's own counter beside the oval.** While a structural call is running, one live line beside the oval counts the thing the call is for, since it was made ("Press on since Q2: six turnovers forced in their half"), counting up as it happens. The line ends when the call ends; no call, no line.
- Bible intent: the game shows what each decision led to; reading the game is the skill.
- Evidence: Pocket GM 3 "added real-time tracking of passes, runs, and kicks" beside play-by-play [mechanic, App Store, Q2]; Motorsport Manager data "layed out very naturally" beside the picture [critic, Stuff.tv]; FM players want to see "if your tactical orders work properly" [player, Steam].
- Exists today: "How it's going" block for the defensive forward only (`MatchScene.gd:1131-1140`), loose-man tally line (`:935`), momentum word (`:300-305`). P-12 is the picture, P-19 the quarter strip; this is the live readout.
- Size: M. Tier suggestion: B.
- Does not: show a percentage or claim the call won anything; one number per active call.
- Conflicts: no number vomit; satisfied if it is one count, tied to a call, gone when the call ends.

**C-MG-04. What is expected of you this week.** One line on the poster, from the board's season goal, both ladder spots and the venue: "A game the board expects you to win", "An even game", "Nobody expects much here". The post-match summary says in one word whether it was met.
- Bible intent: the risk belongs to the player, so he should know what a loss costs; roleplay.
- Evidence: FM24 Mobile's Match Expectations page (squad mood, media expectation) makes it "feel more alive" [critic, iMore, Q3]; director A9: facts he can act on, not facts for their own sake [director].
- Exists today: board goal set from pre-season list rank (`scripts/sim/ClubLife.gd:21-55`); poster shows round, ground and forecast (`MatchPoster.gd` header); no expectation words (grep `expect` in `MatchPoster.gd`).
- Size: S. Tier suggestion: B.
- Does not: change board effect sizes; no probability, no odds.
- Conflicts: none.

**C-MG-05. What the staff's grade does for you.** Each of the three staff grades already shown (Teaching, Tactics, Man-management) gets one line saying what it touches on the ground, in football words, the way ListProfile explains a strength; the hire screen states the trade-off of a vacant job in the same words. No number appears.
- Bible intent: make the rules transparent; understandable, not opaquely implemented.
- Evidence: Pocket GM 3 staff "each with traits and schemes" [mechanic, App Store, Q3]; Golden Lap's "crack crew of racing specialists, each with their own unique roles" [critic, Traxion, Q3]; Astonishing's "confuses me too much" when a rule is hidden [player, App Store, Q1].
- Exists today: grades in words (`scripts/ui/StaffScene.gd:228-230`); the three effects named only in a code header (`scripts/sim/CoachEffects.gd` header); `ListProfile.MEANS` is the pattern.
- Size: S. Tier suggestion: B.
- Does not: add staff traits, schemes or a fourth effect.
- Conflicts: none.

**C-MG-19. Show the breeze end.** On windy days the engine already picks a breeze end that swaps each quarter. Draw it (an arrow at the goals it favours), say it at the bounce and at every break ("You kick with the breeze this quarter"), and let the tempo call's copy read against it.
- Bible intent: weather is the one cosmetic exception and should matter; reading the game is the skill.
- Evidence: Motorsport Manager links "changing conditions" to watched tactical interventions [mechanic, Steam, GENRE §3.6]; Circuit Superstars "readable conditions beneath small-scale sport" [critic, GENRE §3.17]; Footy Mayhem lists wind on match day [mechanic, App Store, Q3].
- Exists today: `scripts/sim/MatchSim.gd:236-247` `breeze_side`, `with_breeze()`, windy rates; flags stream in the wind (`VignetteGround.gd:361-387`); nothing in `scripts/ui` says which end has it (grep `breeze`).
- Size: S. Tier suggestion: B.
- Does not: change the sim.
- Conflicts: none.

**C-MG-20. Rain that arrives in the third quarter.** A match's weather can change once, at a break, when the week's forecast says so ("Showers after half time" on the poster). The break sheet flags it and the rates switch from that quarter. Declined in pass 1 only by omission; the sim change is the cost.
- Bible intent: weather should matter and "the system is not designed" (bible open question); decisions move the odds.
- Evidence: Motorsport Manager changing conditions mid-race [mechanic, GENRE §3.6]; Golden Lap's emergent race stories praised over its static look [critic, Traxion, Q2].
- Exists today: one condition per match, fixed in the week (`scripts/sim/Weather.gd`, `Season.gd:489`); forecast on the hub (`HubScene.gd:636-645`); `WEATHER_RATES` per condition.
- Size: M (sim, calibration check, W7 review). Tier suggestion: C.
- Does not: roll weather every quarter; does not touch the look.
- Conflicts: "Balance is the director's to call": the rate switch needs his playtest.

**C-MG-24. What the marks mean, one tap from the oval.** A legend sheet reachable from the match screen names every mark on the oval (disc, ring, clash strip, tag line, loose man, breeze arrow) in one line each. Each mark is also taught once, the first time it appears, and the flag is saved so it never shows again.
- Bible intent: readability; understandable, not obtuse.
- Evidence: Mini Metro's coherent language still needs learning before it reads [critic, GENRE §3.15]; Motorsport Manager "everything is coded... help text is always a click away" [critic, OSFTW].
- Exists today: a stats key under the player table (`scripts/ui/match/PlayerStatsTable.gd:105`); `GameState.tutorials` first-visit flags; no oval legend (grep `legend` in `MatchScene.gd`, `PitchView.gd`).
- Size: S. Tier suggestion: A.
- Does not: explain simulation mechanics; P-03 owns the three walkthroughs.
- Conflicts: none.

**C-MG-31. A moment is a window, not a stop.** In Watch, a moment opens a short window at live speed with its choices and a visible countdown; one tap takes a choice, and when the window closes the coach has kept the current approach. A setting keeps today's full pause for anyone who wants it.
- Bible intent: agency at decisive moments without breaking the match being watched.
- Evidence: GENRE §3.6: "frequent pauses can destroy the flow being watched... test whether reducing interruptions preserves understanding"; most FM players watch key or extended highlights [player, Steam].
- Exists today: a moment pauses the pitch (`MatchScene.gd:572,2060,2915`); no moments setting in `OptionsSheet.gd` (grep). P-14 is a mode; this is how a moment presents inside Watch.
- Size: M. Tier suggestion: C.
- Does not: answer a moment for the coach; keeping the current approach is itself his standing call.
- Conflicts: director's "every decision needs a vignette" (open-req rows 13-16): a live-speed window may fight the vignette beat; he decides.

## Trust, saves and the promise

**C-MG-07. The promise, printed and enforced.** The main menu's About and the store page say, in one line: "Plays offline. No ads, no purchases, no account. Your career stays on your phone." A CI check reads `export_presets.cfg` and fails if the Android preset ever requests the internet permission or a billing library.
- Bible intent: immersion is a believable world; trust in the maker is part of it.
- Evidence: Astonishing praised as "completely for free, with no ads" and "can be played offline" [critic, Pocket Tactics; mechanic, App Store]; Footy Mayhem's listing leads with "no ads and no pay-to-win" [mechanic, App Store]; Top Eleven token complaints [player, Sikayetvar]; Tap Sports shutdown [critic, ReadWrite].
- Exists today: bible premium, zero MTX; Android preset requests only vibrate (`export_presets.cfg:36`); no About line, no preset check (grep).
- Size: S. Tier suggestion: A.
- Does not: set a price; P-23 owns the page itself.
- Conflicts: none.

**C-MG-08. Let Android back the save up itself.** Turn on Godot's Android user-data backup so the system's own device backup carries the career to a new phone with no server of ours. Keep the save under the backup ceiling (25 MB); P-05's save-size numbers prove it.
- Bible intent: immersion over decades needs the decades to survive a phone change.
- Evidence: Retro Bowl Android's top complaint "progress loss when switching devices" [aggregate, marlvel.ai, Q4]; Soccer Manager cloud saves "only work between devices running the same operating system" [dev, Invincibles FAQ]; Basketball GM data loss and Export [dev, FAQ].
- Exists today: no `user_data_backup/allow` line in `export_presets.cfg` (default off); P-02 is the manual export.
- Size: S. Tier suggestion: A.
- Does not: sync Android with PC or web; does not replace P-02.
- Conflicts: none.

**C-MG-09. Ask the browser to keep the save.** The web build asks for persistent storage on the first save and, when the browser refuses, shows one line: "This browser may clear your career; export it from Settings." Nothing else changes.
- Bible intent: understandable risk, told before it bites.
- Evidence: Basketball GM FAQ: "iOS is especially aggressive about removing data from unused web apps"; mitigations are Persistent Storage and Export [dev, Q4].
- Exists today: web preset with a custom head include (`export_presets.cfg:93`), no persist call (grep `storage.persist`); release plan Review Focus 2 says web save safety is unproven.
- Size: S. Tier suggestion: A.
- Does not: add accounts or a server.
- Conflicts: none.

**C-MG-10. Never an empty ground.** A seeded test steps a whole match at 8x and asserts every drawn frame has 36 discs and the ball inside the oval and a score on screen. The same check runs on each vignette's first frame against its intended sheet, so a fallback never passes.
- Bible intent: the art standard; "clean and crisp like a great app does".
- Evidence: Footy Mayhem "freezes on every attempt to play and shows a field with no players" [player, App Store, Q1]; Soccer Manager's own warning of "a few early issues" with its new engine [dev, FAQ, Q2].
- Exists today: `match_game`, `matchday`, `match_visual` suites; no per-frame disc count (grep `disc_count|36` in `tests/*match*`); CLAUDE.md "the right art loaded" rule.
- Size: S. Tier suggestion: A.
- Does not: measure speed (P-05).
- Conflicts: none.

**C-MG-11. Answer every review.** A release rule: every itch comment and store review gets a reply within a week, in football words, naming the build the fix lands in; replies are listed in the next devlog. P-11 gives the player the seed; this is what we do with it.
- Bible intent: polish is the gap; a maker who answers is part of a believable world.
- Evidence: visible developer replies recur under praised indies (Pocket GM, Astonishing) [player, App Store, Q1 Inferences]; Hoop Land names its feedback channels on the page [mechanic, Steam, Q5]; ratings for responsive one-person studios run higher than licensed titles [aggregate, Q6 Inferences].
- Exists today: devlog-per-upload rule (`memory/itch-builds-devlog-and-saves.md`); `docs/ITCH_UPLOAD.md` has no reply rule (grep `reply`).
- Size: S. Tier suggestion: A.
- Does not: promise a fix or a date.
- Conflicts: none.

**C-MG-12. Patch notes name the football change.** A note template: each line says what changed on the ground or the list ("Tagged rucks now lose fewer centre-bounce taps"), who it affects, and whether old saves carry over. "Stability improvements" alone fails a lint in `tools/`.
- Bible intent: understandable; "dont write misleading patch notes" (ch. 26) [director].
- Evidence: Pocket GM 3 notes name "new salary caps, new contract demands, improved AI draft logic" beside 4.9 [mechanic, App Store, Q5]; Footy Mayhem's "back ground clean up and stability increase" sits beside 3.6 [mechanic, App Store, Q5].
- Exists today: `docs/ITCH_UPLOAD.md` Notes section; P-08 shows notes in-game, this is what they say.
- Size: S. Tier suggestion: A.
- Does not: replace P-08.
- Conflicts: none.

**C-MG-13. Five screenshots and a thirty-second passage.** Store assets in the order of the fantasy: a passage on the oval, draft night, the kid you backed, the press room, the ladder; each in a colourful club, phone portrait, produced by `capture.yml` and checked by the screen-critic before the director sees them. One 30-second watched passage is the clip.
- Bible intent: none directly; release practice, so the director's call.
- Evidence: Hoop Land's page leads with modes and customisation [mechanic, Steam, Q5]; Footy Mayhem's leads with "broadcast-style intros, commentary, a crowd that reacts" [mechanic, App Store, Q5]; Gaps: no trailer evidence found, so this is store convention, not proof.
- Exists today: `capture.yml` contact sheets, `ui-review.yml` review sheets; P-23 page is the home; director yes to P-23 on 2026-10-18.
- Size: S-M. Tier suggestion: C (after P-23).
- Does not: write the description or choose a price.
- Conflicts: no Collingwood in captures (memory) stands.

**C-MG-26. The list of what we are not building.** A one-page "Not in this game" that the director fills (candidates: playable control, multiplayer, 3D, commentary, light mode, AFLW, microtransactions), printed in About and on the store page. It answers the bible's own open question.
- Bible intent: open question "What will this game deliberately not have?"; restraint is a feature.
- Evidence: Simon Read refuses features that "risk upsetting the balance of the game and the simplicity that has brought it success" and names what goes to a sequel [dev, PocketGamer.biz, Q1]; Hoop Land's EA page says what is in and out [mechanic, Steam, Q5].
- Exists today: `docs/DESIGN_BIBLE.md:168` open question; scattered "out of scope" lines in roadmap cards; no one page.
- Size: S. Tier suggestion: A.
- Does not: edit the bible; this is a proposal for his consent.
- Conflicts: nobody edits the bible without the director, so he writes the list.

## Fewer taps, nothing hidden

**C-MG-06. Every system names its one trade-off.** An audit listing each off-field system (budget buckets, season plan, training, culture, captaincy, rotation policy) and the one sentence on its screen that says what it costs. A system with no cost either gets one or leaves the main surfaces until it has one; Culture's header says "They have no effect yet".
- Bible intent: understandable; a visible rule which never matters is a trust problem (GENRE §3.2).
- Evidence: Golden Lap's finances "never feel overwhelming" because each is one trade-off [critic, Traxion, Q3]; Retro Goal "decide what to upgrade and what to delay" [critic, Pure Nintendo, Q3]; AFCM: "complexity and inscrutability erode confidence" [director, GENRE §3.2].
- Exists today: costs said in `Captaincy.gd`, cards (#688), `TAGGER_COST`; `scripts/sim/Culture.gd` header "They have no effect yet"; `ClubBudget.gd` four buckets.
- Size: S (audit), then S per fix. Tier suggestion: A.
- Does not: give culture an effect (ch. 26 s5 "small, then measure" owns that).
- Conflicts: none.

**C-MG-15. This year's list problem in three lines.** The off-season screen opens with the three pressures compounding this year as facts: "Nine out of contract", "Your best six average 29", "Two list spots, three picks". No recommendation follows; the facts are the brief.
- Bible intent: reading the game is the skill; no number vomit.
- Evidence: AFCM's onboarding "connects contracts, picks, drafting and club resources across seasons" and that makes pressures tangible [mechanic, GENRE §3.2]; Basketball GM's pitch "re-sign a veteran or keep cap space" [dev copy]; director: list management compelling, opacity erodes confidence [director, §3.2].
- Exists today: "Out of contract (n)" list (`scripts/ui/OffseasonScene.gd:176-188`), budget summary (`:112`); `ListProfile.gd` strengths in words. No opening brief.
- Size: S. Tier suggestion: B.
- Does not: add a dashboard of modifiers (§3.2's warning).
- Conflicts: none.

**C-MG-21. Intent on the button, never odds.** Every call button says what it changes in shape ("Push two up the ground; thinner behind the ball"), never a predicted result. A CI lint fails any player-facing string with a percent sign or "chance of" outside the stats tables.
- Bible intent: decisions move the odds, never the certainty; the exact science stays clouded.
- Evidence: Into the Breach's postmortem: readable intent constrained mechanics; "reject exact next-play forecasts in stochastic football" [dev, GENRE §3.18]; AFCM's preparation screen of quantified bonuses still "demanding to interpret" [mechanic, GENRE §3.2].
- Exists today: 19 percent or "chance" hits in UI copy, none of them odds (grep); plan blurb PR #755 open; no lint in `tools/`.
- Size: S. Tier suggestion: A.
- Does not: hide the rules; the stat guide stays.
- Conflicts: none.

**C-MG-23. Five questions, two taps.** A real-tap suite answers the coach's weekly questions from the hub (who is injured, who is out of contract, who is in form, their best player, next match's weather) and fails if any needs more than two taps or a scroll past one screen.
- Bible intent: readability; no arthritis from clicking.
- Evidence: Super Mega Baseball's comparison facts "scattered across views" so less visible information makes more work [player, GENRE §3.14]; FM26 "buried under too many clicks" [critic, Use a Potion]; director A12/A14 scrolling to reach stats [director].
- Exists today: `core/Router.gd`, `back_nav` floor 370, one-round hub glance (`HubScene.gd:1547-1597`); no tap-count test.
- Size: S-M. Tier suggestion: A.
- Does not: add a dashboard; it measures what exists.
- Conflicts: none.

**C-MG-25. No target smaller than a thumb, on every screen.** Generalise the per-screen thumb checks into one sweep: every scene is built at 360x740, every button and tappable row is measured, and anything under 44 px fails with its node name.
- Bible intent: intuitive interfaces; thumb-sized targets (CLAUDE.md).
- Evidence: FM24 Mobile icons too small on a 15 Pro Max [critic, iMore, Q4]; Footy Mayhem "tiny joystick" [player, App Store]; tap size is one of the most-complained accessibility items [mechanic, GAG].
- Exists today: per-screen checks in `tests/run_career_ui_tests.gd:254,411,472,685,876,1059`; `UiKit.gd:1155` 48 px minimum on buttons. No sweep across every scene.
- Size: S. Tier suggestion: A.
- Does not: text size (P-04).
- Conflicts: none.

**C-MG-27. What happened while you were away.** After Play ahead (four rounds or to the end of the home and away) one sheet: each result in a line, injuries, contract clocks reached, trust moves with their reasons, cards answered by default; then the hub.
- Bible intent: playing hands-off is the gamer's call and the risk is theirs, so he sees the bill.
- Evidence: FM players accept skipping only without hidden drift ("the assistant usually manages to get the whole squad to rebel") [player, FM Scout]; "Making a game 10x faster changes how people play it" [dev, ZenGM].
- Exists today: one-round hub glance (injuries, ladder; `HubScene.gd:1547-1597`); play-ahead options (`:1195-1215`); 53 `add_news` calls. No multi-round ledger.
- Size: S-M. Tier suggestion: B.
- Does not: add stops (P-07 owns the budget).
- Conflicts: none.

## People remembered

**C-MG-14. Ahead of your list, or behind it.** The board's goal is already set from your list's pre-season rank; say that rank in words at season start ("The board rates this a bottom-six list"), show it in the season review beside where you finished, and keep a career line ("Five seasons: ahead of your list four times").
- Bible intent: the game is objective about risk; a legacy.
- Evidence: Footy Redraft's club-specific benchmarks "frame achievement relative to starting circumstances" [mechanic, GENRE §3.1]; Golden Lap balance "swings from struggling to dominating" with no frame [critic, Traxion].
- Exists today: `ClubLife.board_goal(rank)` (`scripts/sim/ClubLife.gd:21-55`); review shows "Goal: ... met/missed" (`SeasonReviewScene.gd:155-167`); the rank itself is never shown.
- Size: S. Tier suggestion: B.
- Does not: score or medal the career; no difficulty change (P-20).
- Conflicts: none.

**C-MG-16. The drop says what he did.** The release confirm and the selection drop say one remembered fact about him from the store ("142 games with you; four goals in the 2028 elimination final"), then the same two buttons. Quiet when there is no fact.
- Bible intent: the risk belongs to the player; a story and a legacy.
- Evidence: Battle Brothers: "a player's old importance should remain remembered when he loses a starting place" [GENRE §3.9]; OOTP "a sense of ownership over your players" [critic, Game Chronicles]; Retro Bowl stats stop when a player leaves [critic, OpenCritic].
- Exists today: `scripts/sim/CareerFacts.gd` store written by GameState, read only by `Retirement.gd:63`; `Firsts.with_us_bits` (`GameState.gd:3945`); release copy is generic (`OffseasonScene.gd:274`).
- Size: S. Tier suggestion: B.
- Does not: dissuade; no guilt copy, no "are you sure".
- Conflicts: none.

**C-MG-17. Three things the club remembers about him.** The player sheet gets a "With us" block of at most three remembered facts chosen by significance and recency (debut, a final he won, the injury he came back from, the promise you kept). Routine facts fade from the sheet but stay stored.
- Bible intent: a legacy; readability (three lines, not a table).
- Evidence: CK3 memories: "some memories fade while important ones persist", the present role is explained by remembered events [dev, diary 105, GENRE §3.11]; FM's "intensely personal" histories [critic, Game Informer].
- Exists today: `PlayerSheet.gd:149-181` career totals, clubs, honours; `CareerFacts` read by no UI file (grep `CareerFacts|Firsts\.` in `scripts/ui`). Distinct from RC-004 (alumni into coaching) and the wishlist legends wall.
- Size: S-M. Tier suggestion: B.
- Does not: delete any fact; no hall of fame.
- Conflicts: none.

**C-MG-22. He gets older on the stage.** A player's look ages with him: a draftee clean-faced and slighter, stubble or a receding line near 30, grey at 34. Drawn from the same sheets, saved as his look, never read by the sim.
- Bible intent: immersion; the art standard; "they look like clones" [director].
- Evidence: PCM 25 fans' next complaint after better graphics: "cyclists look too similar" [aggregate, Vaporlens]; Wildermyth's ageing and later recognition connect a career [GENRE §3.19].
- Exists today: `scripts/core/Appearance.gd` hair, beard and skin per player, no age term (grep); row 6 faces and hair is the art brief.
- Size: M, after row 6. Tier suggestion: C.
- Does not: add sheets beyond row 6's; nothing cosmetic touches the sim.
- Conflicts: `afl-art-pipeline` save contract for looks applies.

**C-MG-28. Where the pick came from.** The draft board already says "Via Carlton" on a traded pick; add the player who went the other way ("Via Carlton, for Walsh") and keep it on the drafted player's sheet ("Taken with the pick from the Walsh trade").
- Bible intent: the game shows what each decision led to; the defining moment is a risky pick that pays.
- Evidence: Footy Redraft's workflow "makes departures and resulting picks easy to connect" [mechanic, GENRE §3.1].
- Exists today: `scripts/sim/Draft.gd:37` `pick_origin`; `DraftScene.gd:1697-1698` "Via <club>"; compensation news (`GameState.gd:6064`); no link from a pick to the trade that brought it.
- Size: S. Tier suggestion: B.
- Does not: grade the trade.
- Conflicts: none.

**C-MG-29. Your own record.** A coach's ledger on the stats hub: seasons in charge, wins and losses, finals, flags, the players you drafted who became B&F or All-Australian, the board's verdict each season. Plain words and plain counts; it is the dynasty's own page.
- Bible intent: "a story, a legacy, a dynasty".
- Evidence: New Star Soccer's career framing carried ten million downloads [mechanic, Wikipedia, Q2]; an OOTP reviewer keeps checking on former teams [critic, Game Chronicles]; Game Informer's alternate histories [critic].
- Exists today: this season's record (`StatsHubScene.gd:153-168`), board history (`GameState.gd:8500`), trophy room; no multi-season coach ledger (grep `tenure|seasons in charge`). A sacking ends the career (`GameState.gd:8772`), so no club-to-club record.
- Size: S-M. Tier suggestion: B.
- Does not: Coach of the Year (owned TODO); coach moves between clubs.
- Conflicts: none.

## Press and story register

**C-MG-18. The Stats Geek has your numbers.** When a press answer claims something your record contradicts ("we back our kids" with no under-21 debut this year), the Stats Geek quotes the number back and the board and press effect follows the fact, not the claim. When the record supports you, the same answer lands harder.
- Bible intent: the press conference tests media literacy; an answer is a dice roll based on logic.
- Evidence: Esoteric Ebb's stat-dependent choices and remembered answers [dev, FAQ, GENRE §3.12]; FM players answer pressers "mechanically" when nothing checks them [player, FM Scout]; journalists have personalities (bible).
- Exists today: `scripts/sim/MediaConference.gd:106` Stats Geek asks from a number that was true; no answer is checked against `CareerFacts` or the season record (grep `fact|contradict`). RC-005 remembers an answer later; this checks it now.
- Size: M. Tier suggestion: B.
- Does not: add a journalist, an effect type or a new answer set.
- Conflicts: none; press is the director's design, so his call.

**C-MG-30. Drama words only when the facts say so.** Extend the Headlines rule (a line only when the match's facts support it) to story cards and comeback telling: a seeded ten-season run flags any card or note whose intensity words (collapse, crisis, miracle) fire on an ordinary match or a quiet week.
- Bible intent: a quiet professional win needs no fabricated turning point (GENRE §3.10); immersion.
- Evidence: RimWorld's story generator called "formulaic" when events repeat [player, GENRE §3.10]; Retro Bowl scenarios "repeat themselves after a while" [critic, OpenCritic]; Pyre: strong prose on a sport does not guarantee attachment [critic, GENRE §3.20].
- Exists today: `scripts/core/Headlines.gd` facts-gated by rule; `core/ComebackTelling.gd`; `tools/audit/cards_impl.gd`. Row 34 audits reachability and dead choices, not register.
- Size: S. Tier suggestion: B.
- Does not: cut cards or add any.
- Conflicts: none.

## Reading order

Tier A here is engineering and release practice with no design decision: C-MG-01, 06, 07, 08, 09, 10, 11, 12, 21, 23, 24, 25, 26. Tier B is where the evidence says the fun lands and the director decides: C-MG-02, 03, 04, 05, 14, 15, 16, 17, 18, 19, 27, 28, 29, 30. Tier C waits on something else: C-MG-13 (P-23), 20 (his playtest), 22 (row 6), 31 (his vignette rule). Numbering is by the order the candidates were found, not by rank.
