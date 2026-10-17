# Pass 2 candidates from the PC and polish evidence (2026-10-18)

_Second mining of `player_sentiment_pc.md` and `professional_polish_benchmarks.md`, finding by finding, against `docs/DESIGN_BIBLE.md` and `our_game_audit.md`. Nothing here repeats P-01..P-24 of the first report, RC-003..RC-007, an open PR (#636-#774) or a built feature; where a candidate gives shape to an unbuilt wishlist or roadmap item, the item is named under "Exists today". Labels: [player] player account, [dev] developer statement, [critic] critic review, [aggregate] review summary, [mechanic] observed mechanic or store listing. Size: S under a day, M a few days, L a week or more. Tier: A professional baseline, B makes the fun land, C later. Candidates, not assignments: the director decides._

Dropped during checking because they already exist: father-son and NGA pre-draft landings (`GameState.gd:222`, `DraftScene.gd:1288`); the board's goal on the hub (`HubScene.gd:354`); the ball lifted by its height with a shadow on the oval (`PitchView.gd:1326`); the All-Australian team drawn on the oval (`stats/StatsAwards.gd:180`); home grounds at their own size (already director requirement row 33).

## Tier A. Professional baseline

**C-PC-01. The score never leaves the screen.** On the live match screen both scores and the clock stay in view through a moment call, a quarter-break panel, the stats view and any vignette. A screenshot test at phone size asserts the scoreboard face is visible and current in each of those states.
- Bible intent: readability and intuitive interfaces, "no text becomes overlooked"; reading the game is the skill.
- Evidence: ZenGM Jul 2025 "current score is always visible at the top" [dev] https://zengm.com/changelog/ ; F1M24 "UI stopped updating during a race while mouse commands still registered" [critic] https://shacknews.com/article/140757/f1-manager-2024-review-we-think-it-might-be-plan-a
- Exists today: scoreboard built and repainted on events (`scripts/ui/MatchScene.gd:230,3014,3035`); tests check the lead line matches it (`tests/run_matchday_tests.gd:294`) but none checks it stays visible under panels and vignettes.
- Size: S. Tier suggestion: A.
- Does not: add a second scoreboard or move the existing one.
- Conflicts: none.

**C-PC-02. A two-tap map, enforced.** Name the facts a coach reaches for (ladder, fixture, a player's bio, the draft order, the board's goal, your calls at the last break, the cap) and count the taps from the hub to each in a seeded career. The map is a test with a ceiling of two taps per fact; a fact that needs three fails CI.
- Bible intent: "no excessive UI", the player should not "develop arthritis from clicking"; understandable, not obtuse.
- Evidence: FM26 "information locked away behind a series of different windows", features not found after 30 hours [critic] https://soccergaming.com/football-manager-26-review-a-disastrous-start-but-signs-of-promise/ ; Jacobson "couldn't find things in my own game" [dev] https://www.fmscout.com/a-miles-jacobson-explains-fm25-cancellation-and-fm26-plans.html ; FM26 UI flaws 87 mentions [aggregate] https://vaporlens.app/app/3551340/football_manager_26
- Exists today: `core/Router.gd` and the `back_nav` suite (floor 370) prove Back works; nothing counts taps forward (grep `tap_depth|taps_from_hub` tests/: none).
- Size: S-M. Tier suggestion: A.
- Does not: redesign any screen; it reports where the ceiling is broken.
- Conflicts: none.

**C-PC-03. Picture and truth never disagree.** A seeded match recorded as drawn positions per tick, with asserts: no disc moves faster than a footballer can run, no disc jumps, the ball is always with a player or in flight, and the feed line, the scoreboard and the engine's score agree at every event. Run in the `match_visual` suite.
- Bible intent: immersion breaks when "the art is wrong"; "a ball that hovers, or acts independently of the player using it" must never reach the director.
- Evidence: full matches "brutally expose how shallow and arbitrary the algorithms are" [critic, 2009] https://www.gamesradar.com/fifa-manager-2009/ ; FM26 defender "seemingly trapped within the goal", goalkeeper leaving box oddly [critic] https://www.useapotion.com/2025/11/football-manager-26-review-a-promising-rebuild-thats-not-quite-match-fit/ ; "janky animations" as the amateur marker [critic] https://gamecritics.com/brad-bortone/out-of-the-park-baseball-25-review/
- Exists today: goals add up across players, quarters and scoreboard (`tests/test_match_game.gd:505`); no motion plausibility check (grep `teleport|max_speed|plausib` tests/: names only). Director rows 10-12 (collection pauses, play-on) are the defects this would catch early.
- Size: M. Tier suggestion: A.
- Does not: change `MatchMotion.gd` steering; it measures it.
- Conflicts: none.

**C-PC-04. Tap any football term for its rule.** Every rule word the game uses (Press, Loose man, Tag, Plan fluency, Rising Star, Wildcard week) is a long-press target wherever it appears; it opens one paragraph saying exactly what the rule needs and costs, then closes. One source of text per term, shared with the stat guide.
- Bible intent: "make the rules transparent, don't make the decision"; understandable, not obtuse.
- Evidence: Motorsport Manager "help text is always a click away" named as the professional marker [critic] https://www.osftw.com/reviews/847/motorsport-manager ; OOTP "requires at least an intermediate knowledge" as the entry barrier [critic] https://www.osftw.com/reviews/752/out-of-the-park-baseball-15
- Exists today: condensed stat guide (#757) the director called "3 pages of text" (ch. 27 A17); row 27 topic grid open; no inline term lookup (grep `glossary|term_sheet` scripts/ui: none).
- Size: S-M. Tier suggestion: A.
- Does not: explain simulation percentages or recommend when to use the rule. Distinct from P-13, which lays options beside an opponent fact.
- Conflicts: none; CLAUDE.md already asks for every rule to be lookable up exactly.

**C-PC-05. One overflow check for every screen at every text size.** One shared test helper walks every registered screen in a seeded career at the reference phone size and at each text size P-04 adds, and fails on any label whose text is wider than its rect, any control outside the viewport, or any clipped line.
- Bible intent: readability pillar; "no text becomes overlooked".
- Evidence: FM26 "text running off tiles or slight misalignments" [critic] https://frvr.com/blog/news/football-manager-26-alpha-reviews-reveal-the-good-the-bad-and-the-ugly-for-the-first-step-towards-the-future-of-fm ; Golden Lap text "small on a monitor", worse on a 7.4-inch panel [critic] https://traxion.gg/golden-lap-review-a-different-take-on-f1-management-from-the-art-of-rally-devs/
- Exists today: per-screen asserts in four suites (`tests/run_matchday_tests.gd:381,1081`, `run_stats_tests.gd:490`, `run_draft_ui_tests.gd:1055`, `run_career_ui_tests.gd:1913`); no shared helper, no run at larger text sizes.
- Size: S. Tier suggestion: A.
- Does not: fix layouts; it finds them. Depends on P-04 for the sizes.
- Conflicts: none.

**C-PC-06. Kit clash checked for colour-blind eyes.** The disc pairing test that keeps all 306 club pairings distinct also runs each pairing through deuteranopia and protanopia simulation, and fails when the two sides' discs or strips fall under a contrast floor for either.
- Bible intent: readability pillar, "a player's allegiance is obvious"; club colour must stay readable (CLAUDE.md).
- Evidence: colour-blindness is one of the four most-complained accessibility items [mechanic] https://gameaccessibilityguidelines.com/basic/ ; Steam lists "gameplay doesn't rely on colors" as a tested feature [mechanic] https://partner.steamgames.com/doc/accessibility_features ; colour-blind modes that only swap pairs are criticised [critic] https://www.wayline.io/blog/accessibility-illusion-indie-games-gone-wrong
- Exists today: 306 pairings distinct, second strip always a club colour (#763, `tests/test_match_visual.gd:2009`); no colour-vision simulation anywhere (grep `deuteran|protan|colour.?blind` repo: research docs only).
- Size: S. Tier suggestion: A.
- Does not: add a colour-blind mode or recolour kits; it changes which clash strip is chosen when a pairing fails.
- Conflicts: none.

**C-PC-07. A release never loses a feature quietly.** Before each itch upload, the review-sheet capture of the key screens is diffed against the live build's, and the devlog lists what was removed or switched off as well as what was added. Any setting row or control present in the live build and missing in the candidate must be named in the notes or the ship stops.
- Bible intent: immersion is a believable world; trust in the maker is part of it ("dont write misleading patch notes", ch. 26 s8).
- Evidence: FM26 "Regression from previous versions" 51 mentions, "Stick with FM24" 20 [aggregate] https://vaporlens.app/app/3551340/football_manager_26 ; FM26 shipped without touchline shouts and gestures, promised later [critic] https://www.useapotion.com/2025/11/football-manager-26-review-a-promising-rebuild-thats-not-quite-match-fit/
- Exists today: `ui-review.yml` review sheets, `capture.yml`, the itch devlog rule, `tools/ship_main.sh`; no before-and-after diff and no "removed" section in the notes.
- Size: S. Tier suggestion: A.
- Does not: block a deliberate removal; it makes it named.
- Conflicts: none.

**C-PC-08. Time budgets per action.** Extends P-05: once the phone numbers exist, each action gets a budget written in `PERF_BASELINE.md` (hub opens, Sim the week completes, a simmed match resolves, a season rollover finishes, a 20-season save loads) and the CI extras job fails when a desktop run exceeds its scaled budget. A hands-off season has one headline target the devlog can promise.
- Bible intent: "clean and crisp like a great app does"; the player sets the pace.
- Evidence: ZenGM "Making a game 10x faster changes how people play it", then 1.8-2x again [dev] https://zengm.com/blog/17 ; PCM 25 "Faster loading and simulations" 16 mentions [aggregate] https://vaporlens.app/app/2511310/pro_cycling_manager_25 ; "Please Wait" as a decades-old complaint [critic] https://everygamegoing.com/larticle/Jimmys-Super-League-000/34228
- Exists today: `tools/perf/`, `tools/ci_suite_timings.json` (suite timings only), `match_game` timed out at 900 s on main; no per-action budget.
- Size: M. Tier suggestion: A.
- Does not: optimise before P-05's numbers exist; does not set the budgets, the director does once he has seen the phone.
- Conflicts: none.

**C-PC-09. Find anyone from the hub, and keep a shortlist.** A search field reachable from the hub finds any player or club in the league by name and opens his bio or its page; a long-press on any name adds him to your shortlist (prospects, rivals' stars, your own kids), a flat list on one screen with each name a link.
- Bible intent: "no excessive UI"; reading the game is the skill, in list management as in the match.
- Evidence: SI restored "bookmarks and search" after FM25 failed [dev] https://www.fmscout.com/a-miles-jacobson-explains-fm25-cancellation-and-fm26-plans.html ; FM26 bookmark system for pinned pages "useful additions" [critic] https://www.useapotion.com/2025/11/football-manager-26-review-a-promising-rebuild-thats-not-quite-match-fit/ ; OOTP 27 rebuilt player search filtering, implying OOTP 26 shortfalls [critic] https://www.sportsgamersonline.com/?p=80069
- Exists today: search only inside the draft board (`scripts/ui/DraftScene.gd:622`), every name a link (PRs #766/#768 open); no league-wide search or shortlist (grep `watchlist|shortlist` scripts/ui: none).
- Size: S-M. Tier suggestion: A for search, C for the shortlist.
- Does not: rank or filter by rating; a name finds a person.
- Conflicts: none.

## Tier B. Makes the fun land

**C-PC-10. The draft year has more than one day.** Two beats before the November draft: a mid-season week where the under-18 championships are played and the hub names three prospects who starred, by position and state, no grades; and a mid-season rookie draft (a real AFL mechanism) where a club with a list spot can take one state-league player, the AI clubs included.
- Bible intent: the defining moment is a risky draft pick; roleplay; immersion.
- Evidence: the youth intake is "the most anticipated day of the year" [player] https://www.fmscout.com/q-8880-FM-Challenge--Youth-Development-and-Producing-own-talents.html ; a once-a-year intake "isn't how it works in the Real World", players want continuous scouting events [player] https://steamcommunity.com/app/1904540/eventcomments/3802776070761122828 ; Hoop Land links a feeder league so prospects flow in [mechanic] https://store.steampowered.com/app/2453660/Hoop_Land/
- Exists today: prospects with academy and Talent League origins (`scripts/sim/Prospects.gd:122`), combine results (`Combine.gd`), scouting uncertainty (`DraftScouting.gd`); no mid-season draft or carnival beat (grep `mid.?season|rookie.?draft|carnival|under.?18` scripts: captaincy and intake wording only).
- Size: M. Tier suggestion: B. Distinct from P-15 (the staging of the November night itself).
- Does not: add grades, a recommended pick, or a second full draft; the mid-season draft is one pick per club with a spot.
- Conflicts: none, but it touches the lifecycle (W7 review).

**C-PC-11. Other clubs come calling.** After a strong season a rival board offers you its job in one letter: the club, its list in words, its board's goal, the risk stated. Take it and your old club keeps living without you: its results appear in your news and your old players keep their facts about you. Decline and nothing changes.
- Bible intent: the risk belongs to the player; roleplay; a legacy that outlives one club.
- Evidence: OOTP "choosing whether to leave a team you've built is hard", the reviewer keeps checking on former teams [critic] https://gamechronicles.com/out-of-the-park-baseball-20-review-pc/ ; coach market as a hook in Basketball GM's own copy [dev copy] https://apps.microsoft.com/detail/9nfsvdx024hv?hl=en-US
- Exists today: a living coach market for AI coaches (`scripts/sim/CoachMarket.gd`, premiership protection, sacked cooldowns) and `CareerFacts.gd` keyed by id; nothing lets the human coach move club (grep `job offer|another club` scripts/ui: none).
- Size: M-L. Tier suggestion: B.
- Does not: let you coach two clubs, or carry your staff with you.
- Conflicts: none; it touches saves (`my_club` changes) so W7 applies.

**C-PC-12. Sacked is not the end.** When the board sacks you the hub offers the jobs open that off-season, usually at clubs near the bottom; you take one or retire with your record read out. Today the only way on is the main menu.
- Bible intent: "The risk belongs to the player"; the game shows what the decision led to; a dynasty can have a second act.
- Evidence: "make the wrong choices and you'll get fired!" is the genre's own pitch [dev copy] https://apps.microsoft.com/detail/9nfsvdx024hv?hl=en-US ; FHM lists "owner goals/job security" as a selling feature [mechanic] https://gmgames.org/?p=18946 ; OOTP delivers "true joy or desperate heartbreak" [critic] https://gamechronicles.com/out-of-the-park-baseball-20-review-pc/
- Exists today: `HubScene._sacked_card()` says "Start a new career and prove them wrong" with Season review and Main menu only (`scripts/ui/HubScene.gd:511-522`); `CoachMarket.gd` already knows which clubs will not hire a recently sacked coach.
- Size: M (shares the job-letter screen with C-PC-11). Tier suggestion: B.
- Does not: soften the sacking or let you stay.
- Conflicts: none.

**C-PC-13. The club annual.** One page per season, oldest to newest: ladder finish, finals result, B&F, leading goalkicker, first draft pick, coach, one line the game writes about the year from its own facts. A Share button writes the whole career as plain text the phone can send.
- Bible intent: "a simulation that feels like a story, a legacy, a dynasty"; immersion.
- Evidence: FM players write their saves up as stories [player] https://www.fmscout.com/q-13357-An-English-manager-lost-in-Scotland.html ; a Basketball GM player documents every season of his league [player] https://lr.us.psf.lt/r/BasketballGM ; "the resulting stories feel intensely personal" when decisions are reflected back [critic] https://gameinformer.com/b/features/archive/2016/11/25/letting-players-tell-the-story-simulation-games-as-narrative-machines
- Exists today: trophies by year (`scripts/ui/stats/StatsTrophies.gd`), board history, `CareerFacts.gd`, `Firsts.gd`; no season-by-season page (grep `season_history|yearbook|annual` scripts: budget only); "season story recap" sits on the unassigned wishlist (open-requirements line 94).
- Size: M. Tier suggestion: B.
- Does not: export a save (that is P-02) or write prose beyond one line a year.
- Conflicts: none.

**C-PC-14. The club's honour board.** A table of every player who left your club with 150 games, a B&F, a Brownlow or a flag for you: games, goals, B&Fs, flags, All-Australian jumpers as columns, newest first, each name a link to his career facts. A league version lists every retired Brownlow medallist and premiership captain.
- Bible intent: legacy; "the kid you backed" is still there after he has gone; immersion.
- Evidence: ZenGM Jun 2026 added MVP and championship columns to the Hall of Fame table, and keeps that view fast in 3,000-season leagues [dev] https://zengm.com/changelog/ , https://zengm.com/blog/17 ; history pages are judged by whether headline honours are columns [critic inference] https://zengm.com/changelog/
- Exists today: honours art and the trophy room (`StatsTrophies.gd`, `assets/honours/`), `CareerFacts.gd` outliving retirement, `departed_names` in `FamilyTies.gd`; no honour board (grep `hall_of_fame|honour board|legend` scripts: a stats key only). "Legends wall" and "club museum" are unassigned wishlist words (open-requirements line 94).
- Size: M. Tier suggestion: B.
- Does not: retire jumper numbers (not an AFL convention) or add a museum scene.
- Conflicts: none.

**C-PC-15. Every club has a page.** Tap any club name anywhere and one page opens: its colours, home ground, coach, captain, best 22 in words by line, last five results, flags and the year of the last one, and the players it took from you or you took from it. The same page serves your own club.
- Bible intent: "a readable opponent"; reading the game is the skill; immersion.
- Evidence: FM26 removed club city pages and tournament histories and players called the loss "immersion" [critic] https://blast.tv/gaming/news/football-manager-2026-the-good-the-bad-and-the-ugly ; the social feed gave "the sense that what you're doing has consequences" [critic] https://www.digitallydownloaded.net/2018/12/review-football-manager-2019-touch.html
- Exists today: a trade sheet per club (`scripts/ui/OffseasonScene.gd:778`), your own honour sheet (`StatsTrophies.gd:518`), `core/ClubHistory.gd`, `Rivalries.gd`; no general club page and club names are not links (grep `ClubSheet|ClubPage|club_page` scripts/ui: none). RC-007 (rival identity across generations) would feed this page; it is not the page.
- Size: M. Tier suggestion: B.
- Does not: show a rival's hidden ratings or its private trade intentions (PR #759 closes that leak).
- Conflicts: none.

**C-PC-16. Put a player on the table.** From his bio, "Ask around" names one of your players and every club answers in one line: not interested, interested and what it would give, or what else it would want, each reason in football words from the AI's real valuation. You then open the usual trade sheet with any club that answered.
- Bible intent: make the rules transparent; the risk belongs to the player; agency in list management.
- Evidence: OOTP 27 added a sortable "Shop Player" screen, implying OOTP 26 lacked it [critic] https://www.sportsgamersonline.com/?p=80069 ; OOTP players feel "more in control of the team's fate" [player] https://loudpoet.com/?p=33291 ; Pocket GM reviewers doubt OVR when the AI looks dumb [player] https://apps.apple.com/app/id1645791169
- Exists today: a one-club trade sheet with a "shopping" prompt (`OffseasonScene.gd:611-612`), rivals' offers to you counted by `tools/audit/trades_impl.gd`, `TradeValue.gd` need and value; no league-wide ask.
- Size: M. Tier suggestion: B. Reads against P-18 (the other club says why) and uses the same reason text.
- Does not: build the staggered trade period (M6-004) or let the AI initiate deadline drama.
- Conflicts: none.

**C-PC-17. Mark a player untouchable.** One toggle on your player's bio. Rivals stop asking for him in trade talks and requests, the toggle is shown on the trade table, and it costs nothing but the offers you no longer hear.
- Bible intent: player agency; "no excessive UI" (fewer repeated refusals).
- Evidence: ZenGM added "untouchable" assets because the AI kept asking for your best player or top pick [dev] https://zengm.com/blog/17 ; repeated mandatory interactions get delegated or resented [player] https://www.fmscout.com/q-18007-Opinions-on-press-conferences-wanted.html
- Exists today: nothing found (grep `untouchable|off.limits|not for sale` scripts: none); rivals' offers to you exist (`trades_impl.gd` header).
- Size: S. Tier suggestion: B.
- Does not: change his value or stop his own trade request if he asks out.
- Conflicts: none.

**C-PC-18. Pick order as the ladder settles.** From round 18 the ladder shows beside each club the first pick its position currently earns, and your club's line says which win or loss would move it. After the finals the draft order page shows the near misses: who finished one game either side of your pick.
- Bible intent: make the rules transparent; the risk belongs to the player (a late-season choice has a visible price).
- Evidence: ZenGM Apr 2025 lottery page shows non-lottery picks "so you can see how close other teams are" [dev] https://zengm.com/changelog/ ; draft status always visible praised [dev] same source.
- Exists today: pick order shown only inside the draft (`DraftScene.gd:238` "PICK #n"); the ladder (`stats/StatsLadder.gd`) carries no pick column (grep `draft_order|pick_order` scripts/ui: draft scene only).
- Size: S. Tier suggestion: B.
- Does not: add a lottery, a priority pick system or any tanking incentive beyond what the real order already carries.
- Conflicts: none.

**C-PC-19. Watch the goals again.** After full time, "The goals" replays each goal from the event log as a short beat on the oval or as the existing broadcast vignette, in order, skippable, with the scorer and the score at that moment. Deterministic engine, so no new data is stored.
- Bible intent: match day is the culmination; "the game shows what each decision led to"; beautiful and fun to play.
- Evidence: FM players prefer 2D for shape and 3D "for goal replays" [player] https://www.fmscout.com/q-1084-3D-Match-Engine.html ; F1M24 con "no replay of past races" [critic] https://www.ggrecon.com/reviews/f1-manager-2024-review/ ; FM26 goals with "a stylish flair" praised [critic] https://www.useapotion.com/2025/11/football-manager-26-review-a-promising-rebuild-thats-not-quite-match-fit/
- Exists today: `MatchDirector.gd` beats, `BroadcastVignette.gd`, `replay_seed` for exact replays (`GameState.gd:272-274`), snapshots "serve the replay of a match you have just watched" (`CareerSave.gd:26`); no highlights reel (grep `highlight|reel` scripts: none).
- Size: M. Tier suggestion: B. A 3D view was declined in pass 1 because 2D reads shape better; the evidence says 3D earns its keep only on goals, which the 2.5D vignette already covers.
- Does not: replay non-scoring passages or add a free camera.
- Conflicts: none.

**C-PC-20. The crowd knows the score, and the siren is on the tick.** The crowd bed rises with a run of goals and goes flat for the side six goals down; the home crowd is louder than the travelling one; the roar lands on the frame the goal is scored and the siren on the frame the clock reaches zero at every quarter. A test measures the offset between event and sound start.
- Bible intent: immersion; "feel and look beautiful"; how the club sounds never affects the sim.
- Evidence: F1M22 triggers audio early so it syncs with the picture and tags trackside audio to the pass-by [dev] https://www.gamedeveloper.com/production/deep-dive-f1-manager-2022 ; commentary with "odd delays" is "jarring" [critic] https://shacknews.com/article/140757/f1-manager-2024-review-we-think-it-might-be-plan-a ; momentum as feel, score always visible [dev] https://zengm.com/changelog/
- Exists today: `scripts/ui/match/CrowdSound.gd`: one bed at a fixed level, a roar for a goal, a lift for a behind, the siren at full time only; no score awareness, no home and away split, no quarter sirens.
- Size: M. Tier suggestion: B.
- Does not: add spoken commentary (declined in pass 1 because licensed voices turn "monotonous"), club songs or a PA announcer.
- Conflicts: none.

**C-PC-21. No plan wins everywhere.** A seeded audit plays every game plan against every other across weak, even and strong lists; the pass line is that no plan wins more than a stated share against all comers regardless of list. The result is written into the term sheet in football words ("Press suits a young, fit midfield and tires late").
- Bible intent: "Decisions move the odds, never the certainty"; reading the game is the skill; the exact science stays clouded.
- Evidence: FM26 tactics praised (49 mentions) yet one gegenpress "still seemed the most reliable approach", found disappointing [critic] https://soccergaming.com/football-manager-26-review-a-disastrous-start-but-signs-of-promise/ ; exploitable engines turn authorship into meta-following [aggregate] https://vaporlens.app/app/3551340/football_manager_26
- Exists today: press head to head with each plan (`tools/audit/plan_shape_impl.gd` `h2h_<plan>`), one lever against a baseline (`levers_pair_impl.gd`), six fixed pairings; no full round robin across list strengths and no published rule.
- Size: M. Tier suggestion: B.
- Does not: retune anything; it reports, and the director decides.
- Conflicts: "Balance is the director's to call": the audit measures, he rules.

**C-PC-22. A fun floor beside the realism floor.** Run the dynasty bot (a competent coach, not a perfect one) through 20 seasons on many seeds and report how often it reaches finals within five seasons and wins a flag within fifteen. The calibration suite says the league looks like the AFL; this says a good coach can win in it.
- Bible intent: "Perfect coaching with a weaker list maximises your chances but guarantees nothing"; the defining moment must be reachable.
- Evidence: Golden Lap balance "swings from struggling to dominating" [critic] https://traxion.gg/golden-lap-review-a-different-take-on-f1-management-from-the-art-of-rally-devs/ ; OOTP 26 AI "too easy to exploit" so humans win 100+ games [player] https://forums.ootpdevelopments.com/showthread.php?p=5218294 ; Motorsport Manager "addictive and relaxing in equal measure" [critic] https://www.cgmagonline.com/review/game/motorsport-manager-pc-review/
- Exists today: 0 flags in 35 autopilot seasons (`docs/DIFFICULTY_EVIDENCE_2026-10-05.md`, autopilot does not coach); `flags_impl.gd` measures parity, `tools/balance/dynasty.gd` manages a list ("full" policy in `trades_impl.gd`); no managed-career win-rate audit.
- Size: M (audit on runners, `afl-audit-runs`). Tier suggestion: B. Feeds P-20's dial sizes.
- Does not: declare balance done.
- Conflicts: "Balance is the director's to call": the numbers go to him.

**C-PC-23. List churn stays real.** Per off-season the audit counts, for every AI club, players delisted, signed, traded and retired, against the real AFL yardstick (list changes per club per year), and fails when an AI club turns over far more or far less than real clubs do.
- Bible intent: immersion breaks when "player ratings do not reflect reality"; a believable league.
- Evidence: OOTP 26's "biggest problem" named as excessive AI signing and releasing [critic] https://www.wasdland.com/game/out-of-the-park-baseball-27-4045750/ ; roster churn and exploitable AI are the two complaints that stuck [player] https://forums.ootpdevelopments.com/showthread.php?p=5218294
- Exists today: `long_career_impl.gd` prints intake, releases and retirements per rollover; `trades_impl.gd` counts trades against real volume; no per-club churn yardstick or floor (grep `list churn` docs: research notes only).
- Size: S. Tier suggestion: B. Pairs with row 37 (do AI lists end weaker).
- Does not: change list rules.
- Conflicts: none.

**C-PC-24. B&F medals by their real names.** The club best and fairest is presented under its real name (Doig Medal, Charles Sutton Medal, Syd Barker Medal, Keith "Bluey" Truscott Medal and so on), with one line of who it is named for; a Forge club names its own medal when it is created.
- Bible intent: immersion; roleplay; "the look of Forge creations" is the coach's.
- Evidence: ZenGM "Extremely customizable awards" (Sep 2026) [dev] https://zengm.com/changelog/ ; Hoop Land lets players customise awards alongside names and uniforms [mechanic] https://store.steampowered.com/app/2453660/Hoop_Land/ ; register consistency judged on every element [critic] https://www.osftw.com/reviews/847/motorsport-manager
- Exists today: Brownlow, Coleman and Norm Smith named (`scripts/sim/Awards.gd:6-12`), club B&F 5-4-3-2-1 unnamed; honours art `club_bnf.png`; no medal names in data (grep `Doig|Copeland|Truscott` data/: player names only).
- Size: S. Tier suggestion: B.
- Does not: change how votes are counted.
- Conflicts: none; real medal names need the same licensing look as real club names (release plan Q4).

**C-PC-25. Standing orders when you sim.** One sheet, "When I sim the week", states what the assistant does in your absence (your standing plan, who he tags and why, who he rests, how he answers the press) and lets you set each line once. Sim the week follows it and stops only for what no line covers.
- Bible intent: "Playing hands-off is the gamer's call, and the risk of it is theirs"; the bible's open question on the pre-timeskip survey (the simpler version).
- Evidence: FM players skip only when skipping does not cause hidden drift, "the assistant usually manages to get the whole squad to rebel" [player] https://www.fmscout.com/q-3820-How-people-finish-their-seasons-so-quickly-.html ; OOTP felt "more in control" because the AI manager follows the strategy set [player] https://loudpoet.com/?p=33291 ; the assistant still needs a click per match for opposition instructions [player] https://www.fmscout.com/q-22593-How-long-a-season-usually-takes-for-you-in-real-time.html
- Exists today: a standing plan (`GameState.gd:60 club_plan`), the assistant's tagger pick (`MatchScene.gd:1255`), "Ask before simming" (`OptionsSheet.gd:50`); no sheet that shows or sets the lines together.
- Size: M. Tier suggestion: B. Works with P-07's interruption budget.
- Does not: answer a mandatory stop for you.
- Conflicts: none; it is the simpler answer the bible already floats.

**C-PC-26. Challenge starts.** Beside League redraft and Real lists, named starts with one constraint said up front: Youth only (no trades or signings for players over 24), Rebuild (the bottom club with its three best players gone), and a goal you set yourself (a flag with a home-grown 22, 300 games coached) that the annual marks when it is met.
- Bible intent: roleplay; "the risk belongs to the player"; player agency over how the story starts.
- Evidence: the FM youth challenge sets "average age of below 20" as its own goal [player] https://www.fmscout.com/q-8880-FM-Challenge--Youth-Development-and-Producing-own-talents.html ; keeping a decades-long save alive needs "an end goal" and a list of save achievements [player] https://www.passion4fm.com/?p=5308 ; MyNBA Eras called one of the best features in sports games [critic] https://www.gameinformer.com/review/nba-2k25/best-kept-on-the-court
- Exists today: two starts, "redraft" and "real" (`scripts/ui/Main.gd:292`); no challenge or goal (grep `challenge|scenario` Main.gd: none).
- Size: M. Tier suggestion: B.
- Does not: recommend a goal or score it; a goal is met or not.
- Conflicts: none.

**C-PC-27. What the members are saying.** After a match, two lines from a stable cast of named members (the old timer, the family in the outer, the cheer squad) about the result and one call you made, written from match facts, no effect on the sim. The cast carries across seasons like the five journalists.
- Bible intent: immersion, "a believable world that responds to the coach"; the game shows what each decision led to.
- Evidence: FM26 lost its social feed and players called it a loss of immersion [critic] https://blast.tv/gaming/news/football-manager-2026-the-good-the-bad-and-the-ugly ; the feed gave "the sense that what you're doing has consequences and ramifications" [critic] https://www.digitallydownloaded.net/2018/12/review-football-manager-2019-touch.html
- Exists today: five journalists who quote you back (`MediaConference.gd`, #559), 8 members story cards, `Headlines.gd`; no supporter voice (grep `supporter|fans say|members say` scripts: crowd drawing only).
- Size: S-M. Tier suggestion: C unless the press cadence cut (P-17) leaves a gap, then B.
- Does not: become a scrolling feed or a social network; two lines, then gone.
- Conflicts: "Restraint is a feature" and P-07's interruption budget: it must not be a stop.

**C-PC-28. Trade a pick on the night.** During the National Draft, when your pick is next, "Trade this pick" offers it to the clubs behind you for their pick plus a later one, each answer in one line with its reason; accept and the board updates live.
- Bible intent: the risky draft pick is the defining moment; agency at the moment of risk.
- Evidence: ZenGM enabled draft-day trades after fixing an early schema decision and players had asked for it [dev] https://zengm.com/blog/17 ; Madden's live board updating in real time is the convention [publisher] https://ea.com/games/madden-nfl/madden-nfl-25/news/gridiron-notes-madden-25-franchise-and-presentation
- Exists today: traded picks are owned and tracked (`scripts/sim/Draft.gd:37-38,197`); nothing trades a pick during the draft (grep `trade` DraftScene.gd: none). M6-004's future-pick rules are the off-season half.
- Size: M. Tier suggestion: C until P-15 exists, then B.
- Does not: trade players on the night or add pick-value charts.
- Conflicts: none; lifecycle (W7) review.

## Tier C. Later or optional

**C-PC-29. Fix a player yourself, or load your own list.** An editor in Settings changes one player's role, OVR, POT or age in your save, and his bio says "edited by the coach" forever; and the game reads an optional `players_override.csv` from `user://` so a player can carry his own corrections or a full fictional league.
- Bible intent: roleplay; "the look of Forge creations"; the director's own list of ~60 OVR corrections (ch. 27 A23/A25) shows the need.
- Evidence: ZenGM God Mode and real-players leagues [dev] https://zengm.com/blog/ ; Golden Lap "integrated mod support is a nice surprise" [critic] https://www.startmenu.co.uk/home/review-golden-lap ; OOTP works "as a baseball gaming platform rather than a single game" [critic] https://www.osftw.com/reviews/752/out-of-the-park-baseball-15 ; PCM 25 dinged for "Poor modding support" [aggregate] https://vaporlens.app/app/2511310/pro_cycling_manager_25
- Exists today: hand-set overrides live in the repo (`data/potential_overrides.csv`, PR #761 OVR overrides), not in a save or `user://` (grep `user://` GameDB.gd: none).
- Size: M. Tier suggestion: C.
- Does not: edit the AI's hidden state or the match rules.
- Conflicts: "Balance is the director's to call" for the shipped numbers; an edit is the player's own save.

**C-PC-30. Start in a past season.** A start from an earlier AFL year with that year's lists, so the alternate history begins where the player's memory does. Honest cost: historical list data with provenance and the same licensing question as real names.
- Bible intent: "build their own alternate history"; immersion; roleplay.
- Evidence: MyNBA Eras "one of the best features available in sports games today" [critic] https://www.gameinformer.com/review/nba-2k25/best-kept-on-the-court ; OOTP historical seasons "with accurate statistics, stadiums" [critic] https://gamecritics.com/brad-bortone/out-of-the-park-baseball-25-review/ ; Mr Football sells 1980s alt-history [mechanic] https://www.dekudeals.com/items/mr-football
- Exists today: 2026 lists only (`data/players_2026.csv`, `docs/DATA_SOURCES.md`); League redraft is the alternate-history start that exists.
- Size: L. Tier suggestion: C.
- Does not: propose which year; the data decides what is possible.
- Conflicts: none written; licensing (release plan Q4) first.

**C-PC-31. The league changes under you.** Over a long career the AFL announces, in the off-season, one change at a time in plain words: the cap step, a list-size change, an expansion club's entry year, a rule the director has approved. Each is a news line with the season it starts, so a 20-year save is not 20 copies of 2027.
- Bible intent: immersion over decades; a believable world.
- Evidence: OOTP 25 "Dynamic Evolution" changes league rules and economics over time [critic] https://gamecritics.com/brad-bortone/out-of-the-park-baseball-25-review/ ; year-on-year sameness is the stagnation complaint [aggregate] https://vaporlens.app/app/2511310/pro_cycling_manager_25 ; ZenGM real-players leagues track real expansion plans [dev] https://zengm.com/blog/
- Exists today: the cap grows 3% a year silently (`scripts/sim/Contracts.gd:37-46`), Tasmania and Canberra as toggles (M7-009); nothing announces a change (grep `rule change` scripts: none).
- Size: L for rules, S for announcing what already changes. Tier suggestion: C (announce the cap step: S, A).
- Does not: change the match rules without the director's written yes.
- Conflicts: "What can affect the sim": a rule change does, so each needs his decision.

**C-PC-32. Keyboard shortcuts you can see and change.** On PC a Settings page lists every shortcut (space to sim, 1-4 for speeds, Escape for Back) and lets each be rebound; the keyboard test suite reads the same table.
- Bible intent: readability and intuitive interfaces, desktop as the secondary platform.
- Evidence: remapping is one of the four most-complained accessibility items [mechanic] https://gameaccessibilityguidelines.com/basic/ ; OOTP 25 "controls are not remappable" as a negative [critic] https://gamecritics.com/brad-bortone/out-of-the-park-baseball-25-review/ ; ZenGM customisable shortcuts Feb 2026 [dev] https://zengm.com/changelog/
- Exists today: `keyboard` suite (floor 445); no shortcut list or remap in Settings (grep `shortcut|remap` OptionsSheet.gd: none).
- Size: S. Tier suggestion: C.
- Does not: touch phone input.
- Conflicts: none.

**C-PC-33. A control you never used, mentioned once.** After a full season in which a control was never touched (a tag, a rotation policy, the long-press group select), one line names it once, in the place it lives, and never again; written to the save like the first-visit tips.
- Bible intent: understandable, not obtuse; readability.
- Evidence: OOTP 25's tutorial praised for "revealing actions that longtime players had missed" [critic] https://gamecritics.com/brad-bortone/out-of-the-park-baseball-25-review/ ; re-appearing tips dinged [critic] https://shacknews.com/article/140757/f1-manager-2024-review-we-think-it-might-be-plan-a
- Exists today: first-visit flags (`GameState.tutorials`), stat guide; nothing tracks unused controls. P-03 covers fresh saves; this is the veteran's season two.
- Size: S. Tier suggestion: C.
- Does not: say the control should be used; it says it exists.
- Conflicts: CLAUDE.md's rule against recommendation prompts: this names a control, never a decision; the wording must be checked against that line.

**C-PC-34. How the game thinks, in public.** Alongside the itch devlog, short posts that explain one rule each in football words (how the AI drafts, why a club refuses a trade, what weather does), and a public roadmap page with dates, what is in, what is out and where feedback is read.
- Bible intent: none directly; release practice and trust. The director's call.
- Evidence: ZenGM explains why AI teams keep picks and how trade AI works in plain prose [dev] https://zengm.com/blog/20 , https://zengm.com/blog/19 ; Hoop Land's page states duration, plan and feedback channels [mechanic] https://store.steampowered.com/app/2453660/Hoop_Land/ ; Heinsohn asked the community before a costly feature [dev] https://www.osftw.com/features/540/interview-with-ootp-baseball-developer-markus-heinsohn
- Exists today: itch devlog per upload (rule), balance evidence docs in the repo (`docs/COMPETITIVE_BALANCE.md` and others) not written for players; P-23 covers the store page, P-08 the changelog.
- Size: S per post. Tier suggestion: C.
- Does not: print percentages a player would use to game the sim.
- Conflicts: CLAUDE.md "do not explain simulation mechanics" governs in-game copy; a post outside the game is a director decision.
