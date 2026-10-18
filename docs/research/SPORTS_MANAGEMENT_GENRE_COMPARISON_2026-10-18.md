# Make the oval answer the coach, then ship the baseline

_Research report for the director, 2026-10-18. Repo `C:\Users\DANTE\Documents\GitHub\Afl-auto-battler`, branch `sim-the-week-and-scroll-fixes`, main plus `e517d1d9`. Evidence labels on every claim: **[player]** player account, **[dev]** developer statement, **[critic]** critic review, **[aggregate]** review-summary site, **[mechanic]** observed mechanic or store listing, **[repo]** a path in our repo. Earlier research (`docs/GENRE_ENJOYMENT_RESEARCH.md`, 171 sources) is built on, not repeated; its RC-003..007 are cited as existing where a proposal depends on them._

**Bottom line.** Players and critics locate the fun of this genre in three places: people they backed over time, consequences that visibly change the world, and a match where their calls pay off or break their heart. Our game already has the hard part that most indie sims lack: a deterministic, calibrated match engine with a real AFL world and roleplay systems written in football words (`scripts/sim/MatchSim.gd`, `data/`, `scripts/sim/MediaConference.gd`). What it lacks is what the bible already names as the single biggest improvement: the oval does not yet visibly answer a coaching move, so the decision-to-consequence chain the genre's fans describe is thin at exactly the point our bible says is the core pillar. Around that gap sit professional-baseline defects the genre punishes hardest and that reviewers test first: a save format that silently drops a career on a version bump (`scripts/state/CareerSave.gd:16,146`), no text-size setting, no onboarding walkthrough, no phone performance numbers, and text and spacing defects the director has already named. FM26's collapse to 21% positive came from interface and polish failures, not from its match engine ([aggregate, Vaporlens](https://vaporlens.app/app/3551340/football_manager_26)); Hoop Land's 96% positive came from a one-register game with a feedback loop and a price promise ([mechanic, Steam](https://store.steampowered.com/app/2453660/Hoop_Land/)). The recommended order is: fix the baseline (Tier A, 11 items, mostly S/M), then make the fun land on match day and in the people (Tier B, 9 items), then the optional extras (Tier C, 4 items). The AFL phone niche is effectively empty: the only AFL career game on the App Store has 20 ratings and control complaints ([player, App Store](https://apps.apple.com/app/id6475203537)).

---

## 1. One-page summary and scorecard

Scores are maturity 0-3 (0 missing, 1 stub, 2 works but rough, 3 polished), taken from the read-only audit of the repo on 2026-10-18. "Genre bar" names who sets the standard and the evidence.

| # | Reviewer criterion | Genre bar (evidence) | Us | Our evidence [repo] |
|---|---|---|---|---|
| 1 | Match view: watchable, TV-framed, score always visible, data beside the picture | Motorsport Manager "TV-style coverage with a track map and in-depth data" [critic, Stuff.tv](https://www.stuff.tv/game-reviews/motorsport-manager/review); ZenGM live score always at top [dev changelog](https://zengm.com/changelog/) | 2 | Engine 2-3, look 1-2: `MatchSim.gd` -> `MatchDirector.gd` -> `PitchView.gd` (`docs/MATCH_VIEW.md`); director "looks like PowerPoint" (`memory/match-view-is-the-centrepiece.md`); figures still a "prototype" setting (`scripts/ui/OptionsSheet.gd:92`) |
| 2 | In-match agency with visible consequence | FM25 cancelled partly because shouts had no visible start or duration [dev](https://www.footballmanager.com/news/development-update-football-manager-25); players say watching is how they learn what works [player, FM Scout](https://www.fmscout.com/q-3820-How-people-finish-their-seasons-so-quickly-.html) | 1-2 | Moments pause for a call (`MatchSim.gd:143 DECISION_CAUSES`), tags, defensive forward duel (#760), "What your calls did" (#762 open); bible Current focus: players "really react" is unbuilt |
| 3 | Navigation economy: any fact in 1-2 taps, no modal stacking, stable Back | FM26 "everything is a pop up", "buried under too many clicks" [critic, Use a Potion](https://www.useapotion.com/2025/11/football-manager-26-review-a-promising-rebuild-thats-not-quite-match-fit/) | 2 | `core/Router.gd` Back on 15 screens, `back_nav` floor 370; director A12/A14 "numbers divorced from labels", scrolling to reach stats (ch. 27) |
| 4 | Readability: text size, no tiny type, one visual register | FM26 "Text is smaller", Golden Lap tiny on Deck [critic, Traxion](https://traxion.gg/golden-lap-review-a-different-take-on-f1-management-from-the-art-of-rally-devs/); Steam lists adjustable text size as a tested feature [mechanic](https://partner.steamgames.com/doc/accessibility_features) | 1 | No text-size setting (grep `font_scale|text size`: none); only whole-UI Screen size on desktop (`OptionsSheet.gd:61`); director E5 "wasted space and tiny text"; visual audit "a template sitting on top of" a real identity |
| 5 | Onboarding: guided first steps, prompts never re-show | OOTP 25 tutorial praised, F1M24 re-appearing tips dinged [critic, GameCritics](https://gamecritics.com/brad-bortone/out-of-the-park-baseball-25-review/), [critic, Shacknews](https://shacknews.com/article/140757/f1-manager-2024-review-we-think-it-might-be-plan-a) | 1 | Menu tips + stat guide (#757); M8-004 three walkthroughs TODO; hidden gestures (long press, swap) unexplained |
| 6 | Saves: reliable autosave, backups, survives updates, exportable | F1M24 "autosave system is reliable" counted as polish [critic, Shacknews]; Basketball GM warns browser saves vanish and offers Export [dev FAQ](https://basketball-gm.com/faq/); Soccer Manager moved to a continuous app so saves persist [dev FAQ](https://invinciblesstudio.com/?p=4269) | 1 | Autosave on every screen change (`GameState.gd:264`), temp+backup swap (`CareerSave.gd:86`); but `VERSION := 1` and any other version returns `{}` (`CareerSave.gd:146`): a bump drops the career to the menu with no message; no export/import; web IndexedDB reload unproven |
| 7 | Performance and long-save health | ZenGM treats speed as a feature, 10x then 2x [dev](https://zengm.com/blog/17); PCM 25 "faster simulations" praised [aggregate](https://vaporlens.app/app/2511310/pro_cycling_manager_25) | 1 | "No Android device was measured" (`docs/research/PERF_BASELINE.md`); no season-20 timings or save-size numbers; `match_game` suite timed out at 900 s on main |
| 8 | Season pacing: time passes when asked, no interruption stacks | PC Gamer on FM26: "refuses to let time pass with any rapidity" [critic via OpenCritic](https://opencritic.com/game/19479/-/reviews); Retro Bowl scenarios "repeat themselves" [critic](https://opencritic.com/game/12714/retro-bowl/reviews) | 2 | Sim the week + play-ahead menu (`HubScene.gd`), speeds to 8x and Skip (`MatchScene.gd:8`); never-skip-a-mandatory-stop untested (release plan Task 1.5); card audit for dead choices open (row 34) |
| 9 | People and persistence: the kid you backed, history that survives | FM "intensely personal" alternate histories [critic, Game Informer](https://gameinformer.com/b/features/archive/2016/11/25/letting-players-tell-the-story-simulation-games-as-narrative-machines); ZenGM Hall of Fame with MVP and title columns [dev changelog] | 2 | `Backing.gd`, `CareerFacts.gd`, `Firsts.gd`, awards from tallies (`Awards.gd`), real family ties (#713); figures "look like clones" (5 of 16 hair sheets, no faces); no alumni or legends surface |
| 10 | League believability and release practice | OOTP 26's sticking complaints: exploitable AI, roster churn [player, OOTP forums](https://forums.ootpdevelopments.com/showthread.php?p=5218294); Hoop Land EA page states duration, price promise, feedback channels [mechanic, Steam] | 2 | AI shares scouting uncertainty and cap (`DraftScouting.gd`); 0 flags in 35 autopilot seasons (`docs/DIFFICULTY_EVIDENCE_2026-10-05.md`); 48 suites with floors, itch devlog rule; no semver bumps, no in-game changelog, store presence unexamined |

**Where we beat the genre's indie tier already:** a seeded engine calibrated to real 2026 totals (`tests/run_calibration_tests.gd`); 700+ real players with provenance (`docs/DATA_SOURCES.md`); journalists who quote you back (#559); honours art and Tripo props; 48 test suites with floors. No praised indie in the notes has all five.

**Where we sit below it:** criteria 4, 5, 6, 7 are at 1. Every one of them is named by critics as the line between "professional" and "amateur". None of them needs a design decision; they need engineering time.

---

## 2. What makes the genre fun: seven themes

### Theme 1. Owning people over time

**Evidence.** FM players call the annual youth intake "the most anticipated day of the year" [player, FM Scout](https://www.fmscout.com/q-8880-FM-Challenge--Youth-Development-and-Producing-own-talents.html). An OOTP reviewer says the game gives "a sense of ownership over your players" and that he keeps checking on former teams after leaving them [critic, Game Chronicles](https://gamechronicles.com/out-of-the-park-baseball-20-review-pc/). ZenGM added fathers, sons and brothers on player pages purely as a narrative hook [dev](https://zengm.com/blog/17). When PCM 25 improved its graphics, the next complaint was "cyclists look too similar" [aggregate](https://vaporlens.app/app/2511310/pro_cycling_manager_25).

**Where we stand.** Strong on the ledger side: backing promises, firsts, career facts that outlive a trade (`scripts/sim/Backing.gd`, `CareerFacts.gd`), real family ties (#713). Weak on the face side: 5 of 16 hair sheets, no facial features, director "they look like clones" (open-req row 6, art briefed). The draft class arrives as a list, not as a day.

### Theme 2. Decisions that visibly change the world

**Evidence.** Game Informer: because decisions are "reflected throughout the world, the resulting stories feel intensely personal" [critic](https://gameinformer.com/b/features/archive/2016/11/25/letting-players-tell-the-story-simulation-games-as-narrative-machines). FM26 lost its social feed and club pages and players immediately called the loss "immersion" [critic, Blast.tv](https://blast.tv/gaming/news/football-manager-2026-the-good-the-bad-and-the-ugly); SI's own post-mortem: "Immersion is the main element we're focused on" [dev, FM Scout](https://www.fmscout.com/a-miles-admits-fm26-missed-the-mark.html). Sports Interactive cut touchline shouts because a shout had no visible start or duration [dev](https://www.footballmanager.com/news/development-update-football-manager-25).

**Where we stand.** The bible makes this the single biggest improvement and it is unbuilt: coaching moves do not yet change what the oval shows (`docs/DESIGN_BIBLE.md` Current focus; release plan Phase 3). The feed and quarter-break notes tell the consequence in words (`match/MatchNotes.gd`, #760's "how it's going" block for the defensive forward); the picture does not.

### Theme 3. The match as the place where bets pay off

**Evidence.** Motorsport Manager's praised centrepiece is a real-time race with "split-second decisions" over a TV-style map [critic, Stuff.tv](https://www.stuff.tv/game-reviews/motorsport-manager/review). FM players prefer 2D for reading shape and 3D "for goal replays" [player, FM Scout](https://www.fmscout.com/q-1084-3D-Match-Engine.html). Abstract dots are tolerated but called "dull" and "looks like it would run on a crisp packet" [critic, Traxion](https://traxion.gg/golden-lap-review-a-different-take-on-f1-management-from-the-art-of-rally-devs/). Hoop Land, the one indie with a fully alive on-court view, sits at 96% positive [mechanic, Steam](https://store.steampowered.com/app/2453660/Hoop_Land/).

**Where we stand.** The engine is the asset (deterministic, calibrated, truth/interpretation/draw split in `docs/MATCH_VIEW.md`). The look is the liability: visual audit 3.7 "the live match view has no identity"; director "looks like PowerPoint". Discs now distinct in all 306 pairings (#763), upright oval on a phone (#724), the worm praised (`BoxScore.gd`).

### Theme 4. Trade-offs with a real cost, not a checklist

**Evidence.** Basketball GM's own pitch is "re-sign a veteran or keep cap space... make the wrong choices and you'll get fired" [dev copy](https://apps.microsoft.com/detail/9nfsvdx024hv?hl=en-US). Golden Lap's finances "never feel overwhelming" because every system is one visible trade-off [critic, Traxion]. Astonishing Baseball's contract negotiation "doesn't make sense" and "confuses me too much" [player, App Store](https://apps.apple.com/app/id1611390483). FM26's tactical split was the most-praised feature (49 mentions) but one critic found a single gegenpress "still the most reliable approach" [critic, Soccer Gaming](https://soccergaming.com/football-manager-26-review-a-disastrous-start-but-signs-of-promise/).

**Where we stand.** Costs are said up front in captaincy, story cards, tags (`Captaincy.gd`, #688, `TAGGER_COST`). Unknown whether one plan or recruit dominates: rows 28, 29, 37 audits are open and 0 flags in 35 autopilot seasons says difficulty is one-sided somewhere. Trade period is instant-accept (`docs/roadmap/09-03...md` line 120).

### Theme 5. Short, consequential off-field beats; repetition kills them

**Evidence.** FM players "skip these interviews or have the assistant handle them" [player via FM Projects](https://fmprojects.substack.com/p/the-most-annoying-aspect-of-football); "the press-conferences are also extremely repetitive" [player, Steam](https://steamcommunity.com/app/482730/discussions/0/135512931347683702). FM24 Mobile replaced pressers with a Pre-Match Hub and Match Expectations page and a critic said that made it "feel more alive" [critic, iMore](https://www.imore.com/gaming/ios-games/football-manager-2024-mobile-first-impressions). Retro Bowl's text scenarios are praised until they "repeat themselves after a while" [critic, OpenCritic](https://opencritic.com/game/12714/retro-bowl/reviews).

**Where we stand.** Ahead on character: five journalists with personalities who quote you back (#559), effects shown under each answer. Behind on cadence: press repetition was the director's own first complaint (`02-03-01`), variety across long saves unaudited (row 19), ~101 story cards with a dead-choice audit open (row 34).

### Theme 6. The player sets the pace

**Evidence.** Experienced FM players build "sim the week" by hand: assistant, holiday, instant result, and accept it only when skipping does not punish them with hidden drift ("the assistant usually manages to get the whole squad to rebel") [player, FM Scout](https://www.fmscout.com/q-3820-How-people-finish-their-seasons-so-quickly-.html). ZenGM: "Making a game 10x faster changes how people play it" [dev](https://zengm.com/blog/17). OOTP's "Drive for the Pennant" plays only pivotal moments and is praised [critic, GameCritics](https://gamecritics.com/brad-bortone/out-of-the-park-baseball-25-review/).

**Where we stand.** Sim the week, play-ahead, 1x to 8x, Skip to full time, Ask before simming all exist (`HubScene.gd`, `MatchScene.gd`, `OptionsSheet.gd`). What is missing is the middle setting between watching and skipping, and proof that Sim the week never skips a mandatory stop.

### Theme 7. Restraint protected by the developer

**Evidence.** Simon Read refuses most Retro Bowl feature requests because they "risk upsetting the balance of the game and the simplicity that has brought it success" [dev, PocketGamer.biz](https://www.pocketgamer.biz/interview/77507/new-star-games-simon-read-retro-bowl-making-of/). Pocket Tactics praises Football Chairman Pro for seasons that pass "in minutes" [critic](https://www.pockettactics.com/best-mobile-sports-manager-games). PC Gamer gave OOTP 17 89/100 partly because it was "predictably" like the prior year [critic](https://www.pcgamer.com/au/out-of-the-park-baseball-17-review).

**Where we stand.** The written philosophy matches ("Restraint is a feature", one job per screen). The repo does not fully: `GameState.gd` is 10,093 lines, 23 open PRs, seven of eight STYLE packages TODO, and the director's ch. 27 list is mostly "too much, too small".

---

## 3. Professional versus amateur: the checklist

Each line traces to a cited finding. Pass/fail is against the repo today.

| Mark of a professional game | Evidence | Us |
|---|---|---|
| Every fact in one or two taps, no stacked pop-ups | FM26 critics [Use a Potion], Jacobson "couldn't find things in my own game" [dev, FM Scout](https://www.fmscout.com/a-miles-jacobson-explains-fm25-cancellation-and-fm26-plans.html) | **Partial.** Router Back is solid; director A12/A14 scrolling to reach stats, league news buried on the hub |
| Text sized for the smallest supported phone, with a user setting | FM24 Mobile icons "too small" on a 15 Pro Max [critic, iMore]; Golden Lap tiny text [critic, Traxion] | **Fail.** No text-size setting; director E5 |
| Colour and logo coding plus help one tap away | Motorsport Manager "everything is coded... help text is always a click away" [critic, OSFTW](https://www.osftw.com/reviews/847/motorsport-manager) | **Partial.** Names in club ink (#743/#751), guernsey markers; rule lookups exist in the stat guide but it is "3 pages of text" (A17) |
| Matchday glance test: who is tired or injured without opening anything | FM26 "unable to tell who needed subbing off" [critic via FRVR](https://frvr.com/blog/news/football-manager-26-alpha-reviews-reveal-the-good-the-bad-and-the-ugly-for-the-first-step-towards-the-future-of-fm) | **Unverified.** Workload and injuries exist (`Workload.gd`, `Injuries.gd`); no test that the bench strip shows them at a glance |
| One visual register; nothing off-register | Motorsport Manager "cartoonish driver portraits" are "jarringly silly" [critic, OSFTW]; OOTP 25 "janky animations" [critic, GameCritics] | **Partial.** ARD Signwriter, warm-black, club colour; but props in team tint "look like random shapes" (A15), figures a prototype |
| Reliable autosave with rolling backups the player can see | F1M24 [critic, Shacknews]; FM players recover from automatic backups [player, FM Scout](https://www.fmscout.com/q-3142-Save-game-cant-be-loaded.html) | **Partial.** Autosave and one backup exist; no visible slot, no "restore the backup" path, no export |
| Saves survive updates; a newer save is explained, not dropped | Soccer Manager continuous app [dev FAQ]; Basketball GM Export [dev FAQ] | **Fail.** `CareerSave.gd:146` returns `{}` on any version mismatch |
| Tutorial prompts never re-appear after dismissal | F1M24 complaint [critic, Shacknews] | **Unverified.** `GameState.tutorials` first-visit flags exist; no test |
| Lighter "pivotal moments only" way to play | OOTP Drive for the Pennant [critic, GameCritics]; FM key highlights majority [player, Steam](https://steamcommunity.com/app/872790/discussions/0/1742227264187754385) | **Fail.** Watch or Skip; no key-moments mode |
| No "Please Wait" dead time; sim speed to about 8x | Jimmy's Super League 1980s complaint [critic, EveryGameGoing](https://everygamegoing.com/larticle/Jimmys-Super-League-000/34228); Golden Lap 8x [critic] | **Pass** for speed (8x, Skip); **unverified** for dead time (no phone frame times) |
| Undo on roster actions | ZenGM Jul 2026 undo on sign/release [dev changelog](https://zengm.com/changelog/) | **Partial.** Undo exists only for Auto-pick in `SelectionScene.gd:24` |
| Draft night: live board, ceremony beat, status always visible | Madden 25 Draft Night [publisher](https://ea.com/games/madden-nfl/madden-nfl-25/news/gridiron-notes-madden-25-franchise-and-presentation); ZenGM draft status always visible [dev changelog] | **Partial.** Draft order, Pass, Pick for me, recruiting meeting (#732, `RecruitMeeting.gd`); no ceremony, no live board beat |
| AI behaviour explained in plain prose, not exploitable | ZenGM blog on why AI keeps picks [dev](https://zengm.com/blog/20); OOTP 26 "too easy to exploit" [player, OOTP forums] | **Partial.** AI parity audits exist (`docs/PLAYTEST_AUDIT_2026-10-05.md`); the other club never says why it refused |
| Dated changelog, version bumps, feedback channel stated | ZenGM changelog [dev]; Hoop Land EA Q&A [mechanic, Steam] | **Partial.** itch devlog per upload is a rule; builds are `0.1.0-<sha>`, no in-game What's new, no report channel |
| Accessibility labels for screen readers | Pocket GM 3 "quite accessible" for a blind reviewer [player, App Store](https://apps.apple.com/app/id1645791169) | **Fail.** None found (grep) |
| No monetisation pressure, no server dependency | Top Eleven token complaints [player, Sikayetvar](https://www.sikayetvar.com/en/top-eleven-us/top-eleven-exploits-players-with-unfair-token-system); Tap Sports shutdown [critic, ReadWrite](https://readwrite.com/ea-announces-shutdown-of-four-games-with-more-to-come/) | **Pass.** Premium, offline, zero MTX (bible) |

---

## 4. Proposals

Twenty-four proposals in three tiers, in recommended order: **A. Professional baseline before 1.0**, **B. Makes the fun land**, **C. Later or optional**. Each names the bible intent it serves (feature test), its evidence, what exists today, size (S under a day, M a few days, L a week or more), and what it deliberately leaves out. Nothing here duplicates an open PR (#636-#774), RC-003..007, or a shipped feature; where a proposal gives concrete shape to an unbuilt roadmap item, the item is named. Proposals that conflict with a written rule say which.

### Tier A. Professional baseline before 1.0

**P-01. A save that explains itself.** Give `CareerSave` a version chain: each bump carries a migration step, an older save is upgraded in place, a newer save shows "This career was saved by a newer version of the game; update to continue" instead of a silent return to the menu. Keep the existing backup visible as "Restore last good save" on the main menu.
- Bible intent: understandable, not obtuse; the risk belongs to the player, not to the update.
- Evidence: F1M24's reliable autosave counted as polish [critic, Shacknews]; FM players recovering corrupted saves from backups [player, FM Scout]; Soccer Manager's continuous app so saves persist [dev FAQ].
- Exists: `scripts/state/CareerSave.gd:16 VERSION := 1`, `:146` returns `{}` on mismatch; temp+backup swap at `:86`; save-format-2 list ownership migration (#684) shows the pattern once. Release plan Task 1.1 names this, unbuilt.
- Size: M. Test: load a v1 blob under v2, load a v3 blob under v2, restore the backup after a forced `fail_at`.
- Does not: add cloud sync or multiple slots.

**P-02. Export and import a career.** One button in Settings writes the career blob to a file the phone can share; one button reads it back. On web it downloads a file.
- Bible intent: immersion over decades needs the decades to survive a phone change.
- Evidence: Basketball GM FAQ: iOS "is especially aggressive about removing data from unused web apps", mitigation is Export [dev](https://basketball-gm.com/faq/); Retro Bowl Android's top complaint is progress loss switching devices [aggregate, marlvel.ai](https://marlvel.ai/apps/com-newstargames-retrobowl); Soccer Manager cloud saves only work within one OS [dev FAQ].
- Exists: no export path (grep `export_save|import_save`: none); web `user://` in IndexedDB reload safety unproven (release plan Review Focus 2). Row 32 asks what "synchronised" means; this is the cheap half of that answer.
- Size: S-M. Depends on P-01 (an imported file must pass the version check).
- Does not: build accounts, servers or automatic sync.

**P-03. The first week in ninety seconds.** Three guided walkthroughs on a fresh save (the opening draft, the weekly loop, the first post-season), each a sequence of one-line pointers at the real control, plus a one-time pointer the first time a hidden gesture matters (long press, swap). Each pointer is shown once, written to the save, never again; a test asserts that.
- Bible intent: readability and intuitive interfaces; understandable.
- Evidence: FM24 Mobile onboarding "walks new players through their first tactics and the menus" [critic, iMore]; OOTP 25 tutorial "revealing actions that longtime players had missed" [critic, GameCritics]; F1M24 tips that "reappear even after being dismissed" dinged [critic, Shacknews].
- Exists: `GameState.tutorials` first-visit flags, How to play, stat guide (#757); M8-004 lists the three walkthroughs as TODO. This is their concrete shape and the never-re-show test.
- Size: M.
- Does not: add a tutorial career, a mascot, or explain simulation mechanics.

**P-04. Text size the coach can set, and a floor the build enforces.** A Settings row "Text size: Standard / Larger / Largest" that scales UiKit's type roles, and a CI check that no type role renders under a minimum on the reference phone.
- Bible intent: readability pillar, "no text becomes overlooked".
- Evidence: FM26 "Text is smaller" [critic, Use a Potion]; Golden Lap tiny on Deck [critic, Traxion]; FM24 Mobile icons too small on a large iPhone [critic, iMore]; text size is one of the four most-complained accessibility items [mechanic, GAG](https://gameaccessibilityguidelines.com/basic/).
- Exists: `scripts/ui/UiKit.gd` type scale; `ScreenLayout` density and Screen size for desktop only (`OptionsSheet.gd:61`); director E5 and A18 ("press screen so small").
- Size: M (the kit already centralises type; the risk is clipped layouts at Largest, which the screen-critic agent can sweep).
- Does not: add a colour-blind palette or a whole-UI zoom.

**P-05. Numbers for the phone: a performance and long-save gate.** Measure on the director's phone: frame time on the match view at 1x and 8x, hub load, season rollover time, save size at seasons 1, 5, 10 and 20; publish the numbers in `PERF_BASELINE.md`; make the 20-season soak a CI extras job with a save-size ceiling.
- Bible intent: it should feel "clean and crisp like a great app does".
- Evidence: ZenGM treats speed as a design lever, 10x then 2x [dev](https://zengm.com/blog/17); PCM 25 "faster simulations" praised [aggregate]; "Please Wait" is a decades-old complaint [critic, EveryGameGoing].
- Exists: `tools/perf/`, `docs/research/PERF_BASELINE.md` ("No Android device was measured"), row 31 waiting on his phone, M8-005 soak TODO, `match_game` timed out at 900 s on main.
- Size: M (measurement) then unknown (fixes).
- Does not: optimise anything before the numbers exist.

**P-06. The glance test on match day.** On the live view and the bench strip, a tired or injured player is identifiable without a tap: a short fatigue mark and an injury mark on his disc or row, in words on long press. Add one real-tap test and one screenshot test for it.
- Bible intent: reading the game is the skill; decisions move the odds.
- Evidence: FM26 critic "unable to tell who needed subbing off from the tactics screen when a player was injured" [critic via FRVR]; the FM24 "big and bold player tiles" being compacted was read as regression.
- Exists: `Workload.gd`, `Injuries.gd`, rotation policies (#624), bench strip (#717); whether fatigue shows at a glance is unverified.
- Size: S-M.
- Does not: show a fatigue percentage (no number vomit) or recommend a rotation.

**P-07. An interruption budget for the week.** Count every stop between full time and the next bounce in a seeded ten-season run (cards, press, notes, confirmations); set a cap per quiet week; prove Sim the week stops at every mandatory stop and nowhere else; collapse any two stops that answer the same question.
- Bible intent: "The player should not feel they will develop arthritis from clicking"; playing hands-off is the gamer's call.
- Evidence: PC Gamer on FM26: the off-pitch game "refuses to let time pass with any rapidity" [critic via OpenCritic]; Use a Potion: pop-ups make it "tough to build momentum"; FM players accept skipping only when it does not cause hidden drift [player, FM Scout].
- Exists: Sim the week and play-ahead (`HubScene.gd`, `e517d1d9`), `StoryEngine.gd` cooldowns, "Ask before simming"; release plan Task 1.5 (never skip a mandatory stop) untested; row 34 card audit open (this proposal supplies its cadence numbers).
- Size: M (audit as code in `tools/audit/`, then cuts).
- Does not: remove any stop that carries a real decision.

**P-08. A version the player can read, and What's new.** Bump semver with each itch upload (0.2.0 Pre-season and so on as the release plan already names), show the version on the main menu, and show the devlog's patch notes once on first launch after an update.
- Bible intent: immersion is a believable world; trust in the maker is part of it.
- Evidence: Pocket GM 3 notes name salary caps and draft AI per version beside a 4.9 rating; Footy Mayhem's "stability increase" one-liner sits beside 3.6 [mechanic, App Store]; ZenGM's dated changelog with blog links [dev](https://zengm.com/changelog/).
- Exists: itch devlog per upload is a rule (`memory/itch-builds-devlog-and-saves.md`); builds are `0.1.0-<sha>`, `project.godot config/version="0.1.0"`; no in-game notes.
- Size: S.
- Does not: add an in-game news feed or telemetry.

**P-09. Undo where a thumb can slip.** Undo for the roster actions a phone can mis-tap: delisting, a free-agent signing, a contract offer, until the week advances. Trades keep their confirm step.
- Bible intent: the risk belongs to the player, not to a mis-tap.
- Evidence: ZenGM shipped undo for signing and releasing in Jul 2026 [dev changelog]; FM players report assistant deals they could not reverse [player, FM Scout].
- Exists: Undo only for Auto-pick (`scripts/ui/SelectionScene.gd:24,206`); `OffseasonScene.gd` has no undo.
- Size: S-M.
- Does not: allow undoing after the next week has been simmed, or undoing a trade the AI has acted on.

**P-10. State never carried by colour alone.** A pass over GOOD/BAD and club-colour uses: every state colour has a word or glyph beside it; a CI lint lists UiKit calls that set a state colour without a label.
- Bible intent: readability; "club colour must not be mistaken for GOOD/BAD" (CLAUDE.md).
- Evidence: Steam's tested feature "gameplay doesn't rely on colors to communicate important information" [mechanic](https://partner.steamgames.com/doc/accessibility_features); colour-blind modes that just swap pairs are criticised, "use shapes, symbols, or text cues" [critic, Wayline](https://www.wayline.io/blog/accessibility-illusion-indie-games-gone-wrong).
- Exists: the rule in CLAUDE.md; `UiKit.gd` GOOD/BAD tokens; director A13 press tint flicker shows tint is already doing state work.
- Size: S.
- Does not: add a colour-blind mode.

**P-11. Report a problem, one tap.** A Settings row that copies the build, seed, round, screen name and the last twenty feed lines to the clipboard with a line "paste this in the itch comments". Nothing is sent anywhere.
- Bible intent: polish is the gap; the director's own tester found the 52-point swing (row 42) and had no way to hand over the seed.
- Evidence: visible developer replies on store reviews recur in praised indies (Pocket GM, Astonishing) [player, App Store]; Hoop Land names its feedback channels on the store page [mechanic, Steam].
- Exists: seeded engine so a seed reproduces a match (`MatchSim.gd`), `tools/audit` consumes seeds; no player-facing path.
- Size: S.
- Does not: send telemetry or require an account.

### Tier B. Makes the fun land

**P-12. The oval answers the call.** When a structural call is made (press, flood, corridor, controlled tempo, loose man), within one passage the discs or figures visibly take the new shape, the feed says "Press is on" with the quarter it runs to, and the end of the call is marked. One seeded test per plan asserts the drawn positions differ from the pre-call positions by a stated amount.
- Bible intent: Current focus, "the single biggest improvement to game feel"; structural moves "the visual sim changes greatly".
- Evidence: SI cut shouts because they lacked a visible start and duration [dev]; FM players say watching is "how they learn what works" [player, FM Scout]; Hoop Land's alive view at 96% versus Golden Lap's dots "dull" [critic, Traxion].
- Exists: `PlanFit.gd`, `MatchDirector.gd` beats, `MatchMotion.gd` steering, `PitchView.gd`; `docs/MATCH_VIEW.md` says the view only interprets truth, so the shape must come from the engine's own positional state. Release plan Phase 3 names this; it is the concrete acceptance test.
- Size: L.
- Does not: add decorative movement the engine did not apply; does not change the result model.

**P-13. Every opposition fact comes with your options beside it.** On the pre-match sheet, each stated opponent fact ("Rankine is their best player", "they win it at the stoppages") sits next to the responses the rules allow (tag, defensive forward, main ruck, loose man), all shown, none marked best, with the cost each carries.
- Bible intent: "Reading the game is the skill"; make the rules transparent, don't make the decision.
- Evidence: FM24 Mobile's Pre-Match Hub (opponent strengths, predicted line-up) made it "feel more alive" [critic, iMore]; director A9: "why tell me Rankine is their best player if i cant do anything about it?"
- Exists: tags (#633, #729), defensive forward (#760), main ruck (PR #758 open), `MatchPoster.gd`, opponent prep. This proposal is a layout rule, not a new control.
- Size: M. Rule check: no "best" label, every option shown even when unsuitable (with the reason), satisfies CLAUDE.md's no-recommendation rule.
- Does not: add new in-match levers or a matchup grade.

**P-14. Key moments: the setting between Watch and Skip.** A third way to take a match: it runs at top speed and stops only for the coach's moments, quarter breaks and goals, each shown as a short vignette or feed beat, then runs on. Chosen per match from the poster, remembered as the default.
- Bible intent: "designed for a player who plays most matches and sims the odd one"; agency at the decisive moments.
- Evidence: most FM players watch key or extended highlights [player, Steam]; OOTP's Drive for the Pennant "only pivotal moments" praised [critic, GameCritics]; Footy Mayhem offers PLAY/COACH/SIM before every match [mechanic, App Store]; praised indies show a slice and text the rest [critic, OpenCritic].
- Exists: speeds and Skip (`MatchScene.gd:8,446`), moments that pause (`MatchSim.gd:143`), vignettes for breaks and goals (`BroadcastVignette.gd`, `StoppageVignette.gd`). The engine is untouched; this is a playback policy.
- Size: M.
- Does not: change the sim, remove 1x watching, or auto-answer any moment.

**P-15. Draft night as a night.** The national draft becomes three layers on one screen: the live board that fills pick by pick, a beat when it is your pick and when your name is read (the recruit on the award stage, his hometown and position in words), and the recruiter's one line of what he is, in football words, never a grade.
- Bible intent: the defining moment is "a player you took with a risky draft pick wins the Brownlow"; the night the risk is taken deserves a stage. Immersion, roleplay.
- Evidence: Madden 25 rebuilt Draft Night as ceremony, live board and immediate reaction [publisher, EA](https://ea.com/games/madden-nfl/madden-nfl-25/news/gridiron-notes-madden-25-franchise-and-presentation); ZenGM made draft status and advance buttons always visible [dev changelog]; FM's youth intake is "the most anticipated day of the year" [player, FM Scout].
- Exists: `Draft.gd` (#732), `RecruitMeeting.gd` (no best pick), `Prospects.gd`, `AwardWinnerVignette.gd` stage, `FictionalIdentity.gd` hometowns. Draft class identity is on the wishlist as an idea; this is the screen.
- Size: M-L.
- Does not: add draft grades, a recommended pick, or a mock draft.

**P-16. The one who got away.** When a player you delisted, traded or let walk lines up against you, the poster says so in one line from stored facts ("Sam Walsh, 142 games for you, now Carlton's captain"), and the match report says what he did to you. Quiet if there is no such player.
- Bible intent: a simulation that feels like a story and a legacy; immersion.
- Evidence: FM diaries name "a departed star tormenting your side afterwards" as a best moment [critic, Softpedia](https://games.softpedia.com/blog/Football-Manager-2015-Diary-This-Is-a-Game-About-Stories-467215.shtml); OOTP reviewer keeps checking on former teams [critic, Game Chronicles]; Retro Bowl criticised because stats stop when a player leaves your team [critic, OpenCritic].
- Exists: `CareerFacts.gd` keyed by id outliving trades, `departed_names` in `FamilyTies.gd`, `MarqueeGames.gd`, `Headlines.gd`. Distinct from RC-004 (a former player entering coaching) and RC-007 (a rival club's identity); this is a former player of yours on the field.
- Size: S-M.
- Does not: invent a grudge or a private motive; does not change his performance.

**P-17. Press when it matters, silence when it does not.** The press conference fires after finals, a loss by ten goals, a selection controversy, a milestone or a card that promised press; an ordinary win gets one line, "nothing much asked this week". Effects unchanged when it does fire.
- Bible intent: press tests media literacy and compliance; a test taken every week stops being one. Restraint.
- Evidence: FM players skip pressers for "relatively meaningless games" and answer "mechanically" [player, FM Scout](https://www.fmscout.com/q-18007-Opinions-on-press-conferences-wanted.html); when a system is universally delegated it has failed as content; FM Mobile dropped pressers for hubs and gained "alive" [critic, iMore].
- Exists: `MediaConference.gd` with five journalists (#559), effects shown (9.2 decision), vignette; director's first complaint was repetition (`02-03-01`); row 19 variety audit open.
- Size: S-M. This is a design change: the director decides (Decision 3).
- Does not: remove any effect, journalist or answer.

**P-18. The other club says why.** When an AI club refuses a trade, passes on a prospect you wanted, or outbids you, one line in football words states its reason from its real state ("Carlton passed: two rucks under 24 already"), and the reason is the one the AI code used.
- Bible intent: make the rules transparent; "a readable opponent" (GENRE §5).
- Evidence: ZenGM explains in plain prose why AI teams keep picks [dev](https://zengm.com/blog/20); OOTP 26's sticking complaint is AI "too easy to exploit" and churn [player, OOTP forums]; Pocket GM reviewers doubt whether OVR matters when the AI looks dumb [player, App Store].
- Exists: `TradeValue.gd` need/value, `Draft.gd` win-now valuation and two-ruck rule, `TradeRequests.gd`; row 37 AI list audit open. Distinct from RC-006 (comparing two of your options).
- Size: S-M.
- Does not: reveal hidden POT or scouting reads the AI has not made public.

**P-19. Both benches, quarter by quarter.** One strip at each break and at full time: four columns, your calls above, theirs below, in words, with the quarter's score. "What your calls did" reads against it.
- Bible intent: "The game shows what each decision led to"; individual moves explained in post-quarter copy.
- Evidence: FM players value seeing "if your tactical orders work properly" [player, Steam]; Motorsport Manager praised for data "layed out very naturally" beside the picture [critic, Stuff.tv]; director A5 asked for a per-quarter record of both clubs' calls, A4 for less wall-of-text.
- Exists: call log and "What your calls did" at full time (#762 open fixes its layout), AI plan choices by observable state (M4-006), `MatchNotes.gd`. #762 is layout; this is the two-sided quarter strip.
- Size: M.
- Does not: say the call won the match (no unprovable counterfactual).

**P-20. Difficulty said in football words.** Replace "trade margin only" with two named dials the player sees at career start: board patience (how many poor seasons before you are warned) and rival recruiting (how sharp the other clubs draft and trade). Each in one sentence.
- Bible intent: the risk belongs to the player, so he should know what the game is doing to him; understandable.
- Evidence: Golden Lap balance "swings from struggling to dominating" [critic, Traxion]; OOTP 26 humans "win 100+ games" against exploitable AI [player, OOTP forums]; 0 flags in 35 autopilot seasons here (`docs/DIFFICULTY_EVIDENCE_2026-10-05.md`).
- Exists: `GameState.gd:8202 DIFFICULTIES` easy/normal/hard = trade margin; board confidence (`ClubLife.gd`); row 37 AI audit.
- Size: M. **Conflicts with a written rule:** "Balance is the director's to call" (CLAUDE.md, bible). The dials can be built; their sizes wait for his playtest.
- Does not: give the AI hidden information or boost its ratings.

### Tier C. Later or optional

**P-21. Screen-reader labels.** Give UiKit controls accessible names so TalkBack reads buttons, rows and the score.
- Bible intent: readability for everyone.
- Evidence: a blind reviewer called Pocket GM 3 "quite accessible" because almost everything is labelled [player, App Store]; the four most-complained accessibility items [mechanic, GAG].
- Exists: nothing (grep). Godot's accessibility support depends on the engine version in use (4.7 here); feasibility check first.
- Size: M-L. Does not: build an audio-only mode.

**P-22. Coaches' votes.** After each match both coaches cast 5-4-3-2-1 from recorded stats and roles; the tally is a season leaderboard and feeds a Coaches' award.
- Bible intent: immersion; role-aware recognition of non-stars (GENRE §5).
- Evidence: director ch. 27 B6 asked for them; ZenGM's hall of fame columns show headline honours are expected as tables [dev changelog].
- Exists: `Awards.gd` Brownlow 3-2-1 from tallies, `Leadership.gd` from facts; B6 is unassigned.
- Size: S-M. Does not: let the player cast the votes (the AI coaches vote; he reads).

**P-23. A public page with a demo season.** A Steam or itch page that states what the game is, what is in and out, the price promise, and a demo of one season; feedback channel named.
- Bible intent: none directly; this is release practice. Commercial choice, director's.
- Evidence: FM26 players advise "Try the demo first" (21 mentions) [aggregate, Vaporlens]; Hoop Land's EA page states duration, "no price change", free future content and where feedback is read [mechanic, Steam]; Golden Lap ran a Next Fest demo [critic, GodIsAGeek](https://godisageek.com/2024/06/golden-lap-demo-out-now-as-part-of-steam-next-fest/).
- Exists: private itch HTML5 channel `0.1.0-24aeb49`; real names and licensing unexamined (release plan Q4).
- Size: M. Does not: set a price or propose any monetisation; licensing of real names must be settled first.

**P-24. Share a Forge club.** Export a created club (kit, name, place, list) to a file another player can import.
- Bible intent: roleplay; "the look of Forge creations" is the coach's.
- Evidence: Hoop Land's shareable custom leagues and ZenGM's customisable awards are praised features [mechanic, Steam], [dev changelog].
- Exists: `ClubForge.gd`, `ClubForgeScene.gd` (M7-009 PARTIAL, usability P0s still open); depends on P-02's file path.
- Size: M. Does not: add online sharing or a gallery.

### What this report does not propose, and why

Spoken commentary: F1 Manager's licensed voices earn praise once and then "monotonous" and "odd delays" [critic, Shacknews]; written, varied feed lines are the safer register for this team. A 3D match view: 2D is preferred for reading shape [player, FM Scout], and the bible's own route is the 2.5D vignette plus the live-3D probe already on the register (row 38). More story cards before the cadence audit: repetition, not count, is the failure mode [critic, OpenCritic]. Any light theme, monetisation or cosmetic that touches the sim: excluded by the director and the bible.

---

## Decisions for the director

1. **Do we hold 1.0 until Tier A (P-01 to P-11) is green on a phone?** Recommended: yes. Impact: the first review of the game is written about saves, text size and onboarding before it is written about football; FM26's 21% positive came from exactly these.
2. **Is P-12 (the oval visibly answers a structural call) the first Tier B job, before any new lever?** Recommended: yes. Impact: every existing call becomes watchable evidence; without it "What your calls did" stays a text claim.
3. **Should the press conference fire only when something happened (P-17)?** Recommended: yes. Impact: fewer pressers, each one carrying weight; the journalists you built get remembered instead of skipped.
4. **Do we add a Key moments way to take a match (P-14) alongside Watch and Skip?** Recommended: yes. Impact: a coach can take every match in a season on a train without skipping his own decisions; the sim is unchanged.
5. **Should difficulty be two named dials (P-20) whose sizes you set in your playtest?** Recommended: yes, build the dials, you set the numbers. Impact: a player knows what "hard" does to him; today it only changes what trades the AI accepts.
6. **Do we pursue a public page with a demo season (P-23) before 1.0?** Recommended: not yet. Impact: a demo invites the comparison to Pocket GM and Hoop Land while Tier A is open; after Tier A it becomes the cheapest trust signal the genre has.

---

## Notes on evidence

Reddit threads were not retrievable in this pass; community sentiment reaches this report through store reviews, FM Scout and Steam forums, aggregator sites (marked, indicative only) and critics. No player accounts were found for AFCM or Footy Redraft under those names; the director's own accounts in `GENRE_ENJOYMENT_RESEARCH.md` §3.1-3.2 stand as the AFL comparison. Nothing in the repo was run for this report; every repo claim is a read of a file or a document, and "unverified" means exactly that.

## Director's decisions, 2026-10-18

Asked one at a time after the report was delivered. His words are in quotes. Recorded in
[roadmap chapter 28](../roadmap/28-director-decisions-2026-10-18.md); nothing here edits the bible and nothing is assigned yet.

1. Hold 1.0 for Tier A? **"No. Start with Tier B (P-12, the oval answers a structural call) and fold Tier A into the 1.0 plan."**
2. P-12 first in Tier B? **Yes** (settled by decision 1).
3. Press conferences only when something happened (P-17)? **"Yes, press conferences only when something happened."**
4. Key moments beside Watch and Skip (P-14)? **"Yes, add Key moments beside Watch and Skip."**
5. Two named difficulty dials (P-20)? **"Yes, two named difficulty dials; I set the sizes in playtest."**
6. Public demo page before 1.0 (P-23)? **"Yes, pursue the public demo page before 1.0."** (Against the report's "not yet"; his call.)
