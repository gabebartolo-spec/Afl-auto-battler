# Genre enjoyment research — Aussie Rules Dynasties

_Initial review and intensive expansion: 5 October 2026. Publication base: main at `6573a8f619c8c00065964314db5fca6eb8364dcc`. The initial checkpoint is retained in historical evidence; refreshed status is below._

## Intensive expansion — reading guide

The director requested at least four times the research, with substantial attention to visual beauty and real player accounts. The earlier report had 12 comparator sections and 42 distinct web sources. This revision adds **129 substantively reviewed sources: 171 cumulative, 4.07 times the prior breadth**. Twenty named comparator sections now connect to focused research chapters. Counting is audited in the ledger; breadth is not a measure of causal certainty.

- [Beautiful, readable football](research/AFL_VISUAL_DESIGN_RESEARCH.md): sports presentation, critical and forum contradictions, existing editorial identity, phone-scale tasks and visual authority.
- [Agency and creative team building](research/AFL_AGENCY_AND_TEAM_BUILDING_RESEARCH.md): replayability after mastery, real costs, truthful consequence feedback, market trust and comparable AI rules.
- [People, clubs and decades](research/AFL_LONG_CAREER_STORY_RESEARCH.md): persistent identity, evolving roles, meaningful season structure and restrained callbacks.
- [Evidence ledger](research/AFL_RESEARCH_EVIDENCE_LEDGER.md): 129 new source cards, previous 42-source provenance, dates, evidence types and coverage limits.

**AFCM is not a visual aspiration.** It supplies list-management questions and the director's experience of opacity. ARD's existing flat editorial design remains the visual foundation; useful principles from other games require adaptation, not copied layouts.

The research proposed seven candidates; after individual director review RC-001/002 are excluded and RC-003–007 are accepted within existing owners. Existing accepted tickets are refined in place. It does not introduce a gameplay API, change a save format, assign implementation to Claude or satisfy Android gates.

## 1. Direction and authority

Strengthen the existing club career around **watching your football ideas play out, building a distinctive side, and remembering the people who made its history**. The director wants Footy Redraft's emergent storytelling and AFCM's compelling list management, developed into a game with its own appeal:

- a legible visual simulation;
- creative team building with competing viable approaches;
- consistent saves lasting decades, with players whose roles change;
- stories grounded in actual matches and career consequences;
- meaningful coaching during matches and throughout the season;
- decision gates caused by the match being played, with observable positive, negative or inconclusive consequences.

**Zero microtransactions. Commercialisation is outside this research objective.** Club salaries and budgets are fictional football resources, not purchases. Revenue, monetised retention and spending incentives are not success measures.

The director's experiences are design inputs, not independent competitor audits: Footy Redraft becomes solved after learning the best recruits; AFCM feels overly complex and inscrutable, undermining trust in its numbers, while long careers lose narrative thrust. We must not generalise those experiences into claims about every player or either game's engine.

[ROADMAP.md](ROADMAP.md) remains the sole execution backlog. This document refines accepted work and supplies evidence. Only the inherited-list start, **ARD-M5-016**, is a newly accepted feature. Research candidates in §7 require director selection before entering Claude's execution queue. No gameplay is implemented by this documentation revision.

## 2. Method and evidence limits

Twelve complementary games were studied: the eight approved cross-genre references, the two AFL games supplied by the director, and the later requested Crusader Kings and Esoteric Ebb references. Sources include official mechanics, developer retrospectives, a published motivation paper and explicitly identified player accounts. Competitor websites were read on 5 October; AFCM and Footy Redraft also received brief public browser walkthroughs. AFCM inspection covered classic-career setup, the opening dashboard, squad, Rating Lab, preparation and one round's displayed result; Footy Redraft covered its rules, data disclosure, run selection and inherited-list screen. These are interface observations, **not sustained playtests, engine inspections or multi-season balance experiments**. No account, payment or leaderboard submission was needed.

Evidence labels used below:

| Label | What it establishes | What it does not establish |
|---|---|---|
| **Observed mechanic / interface** | A documented or inspected rule or screen exists in that version. | Its implementation is correct, or it causes enjoyment. |
| **Developer interpretation** | The creator's rationale, diagnosis or internal method. | An independent causal result or representative player response. |
| **Player account** | A specific person's reported experience. | Prevalence, a confirmed bug or the director's own experience. |
| **Published research** | Findings or a theoretical account within the study's scope. | That importing a mechanic will work in ARD. |
| **ARD hypothesis** | A proposed benefit and a way to test it. | Proven enjoyment or permission to build an unselected feature. |

Website wording and games change. Announced features are not treated as released systems. This pass does not infer revenue, active-player counts or engagement from promotional claims. No new ARD simulation or Android testing was performed; existing repository measurements are identified as such.

The motivational model developed by Przybylski, Rigby and Ryan connects game enjoyment with competence, autonomy and relatedness. It supports asking whether players understand and value their decisions. It does not imply that more buttons produce autonomy, that winning is necessary for enjoyment, or that human relatedness transfers automatically to attachment to simulated footballers. Our observable tests therefore concern understanding, remembered people and voluntary continuation, rather than a supposed universal engagement formula. **Published research:** [A Motivational Model of Video Game Engagement, 2010](https://selfdeterminationtheory.org/SDT/documents/2010_PrzybylskiRigbyRyan_ROGP.pdf).

## 3. Competitor deconstructions

### 3.1 Footy Redraft — a clear alternative history, with hindsight as both appeal and limit

**Observed mechanic/interface:** The rules describe inherited historical lists, optional trading, positional coverage and drafting with knowledge of real careers. Runs end in 2026. The data disclosure says seasonal ratings, breakouts, declines and retirements follow real history; match results use a probability model derived from list strength. Club-specific benchmarks frame achievement relative to starting circumstances. The inspected workflow makes departures and resulting picks easy to connect. These are public rules and UI observations; calibration claims were not independently checked. [Game and How to Play](https://footyredraft.com/).

**Director account:** Emergent storytelling works well, but learning the best players makes repeat runs feel solved. The strength and frustration can coexist: familiar careers give decisions emotional context while known futures narrow discovery.

**ARD hypothesis:** Keep recognisable real beginnings, then let future performance emerge from the same development, selection, roles, injuries, contracts and competition rules used throughout the save. A recruit's value should depend on the side being built, price, timing and deployment. Replayability should survive learning the rules. Randomising ratings behind the player's back, hiding a universal best recruit or adding more draft classes without meaningful differences would postpone the problem rather than resolve it.

**Adapt / reject / test:** Adapt concise causal history and club-relative context through M7-003/M7-005 and the accepted M5-016 start. Reject importing the historical endpoint, predetermined future retirements or its scoring/medal structure. Compare repeat drafts by informed players across contrasting club needs; record whether they deliberately change priorities and can explain why. Their preferred recruits need not be evenly distributed.

### 3.2 Australian Football Club Manager — list pressures that compound, and the risk of excessive explanation

**Observed interface:** The inspected squad exposes age, position, overall, potential, fitness, form, morale and contract status, with filters. Onboarding connects contracts, picks, drafting and club resources across seasons. This makes roster-building pressures tangible. [AFCM](https://aflclubmanager.com/), [Squad](https://aflclubmanager.com/squad).

The Rating Lab decomposes team strength into several factors. Preparation presents many quantified bonuses, penalties, training choices and recommended team talks. The presence of explanations does not prove that values match the engine; we did not inspect that engine. It also shows why adding explanations can still leave a screen demanding to interpret. [Rating Lab](https://aflclubmanager.com/rating), [Match Preparation](https://aflclubmanager.com/match-prep).

**Developer interpretation / player accounts:** The creator described quarterly coaching effects as small but potentially important in close games. Individual comments praised list management and career statistics; others questioned tactical downsides and scrolling. These May–August reports concern evolving versions and are not a current defect list. [Creator's June discussion](https://www.reddit.com/r/AFL/comments/1tvj0et/new_afl_club_manager_simulation_game_made_by_a/), [May feedback](https://www.reddit.com/r/aflfantasy/comments/1t9zwdw/new_afl_team_manager_simulation_game_made_by_a/).

**Director account:** List management is compelling; complexity and inscrutability erode confidence, and long saves lose story momentum.

**ARD hypothesis:** A small number of connected pressures can sustain list decisions without exposing every coefficient. Present the immediate football problem, the player's options and the relevant cost. Put deeper rules behind inspection. Match events, numbers and retrospective explanations must agree. A visible rule which never matters is still a trust problem.

**Adapt / reject / test:** Extend M6-004 and §9.1 selection/management work; verify long-run contracts, AI demand and development together. Reject copying the interface, recommendations, economy or difficulty bonuses. Observe whether players can explain a difficult retention decision, then audit the stated constraints against the save. Do not respond to opacity by adding a second dashboard of modifiers.

### 3.3 Football Manager — make tactical intent visible, then prove execution

**Observed documented mechanic:** FM26 separates in-possession and out-of-possession organisation. Its tactical visualiser shows how roles move in match scenarios, helping coaches connect instructions with space. This is a visibility reference, not a recommendation to import association-football formations. [Official tactical feature](https://www.footballmanager.com/fm26/features/possession-out-possession-fm26s-new-tactical-evolution).

**Developer interpretation / failed approach:** Sports Interactive announced removal of touchline shouts for FM25 because their timing and duration were insufficiently clear: a shout waited for a stoppage and did not communicate how long it applied. FM25 was subsequently cancelled, so this is a design diagnosis from a cancelled release, not a claim about a shipped FM25 solution. [2024 development update](https://www.footballmanager.com/news/development-update-football-manager-25), [cancellation](https://www.footballmanager.com/news/development-update-football-manager-25-1?pubDate=20250720).

**ARD hypothesis:** A coaching action needs a visible start, duration or cancellation rule and football consequence. The oval should help reveal the changed contest. Showing a spare on an illustration while the engine grants an unrelated flat bonus would fail this test.

**Adapt / reject / test:** Refine M4-001 through M4-004 and M4-009's existing reports. Begin with one existing structural call and its observed events. Reject optimal-plan hints, a dense role matrix and additional shouts without evidence of need. Test application timing, expiry, invalid personnel and whether a viewer notices the relevant change without a researcher explaining it. An engine-backed practice preview remains a review candidate, not approved expansion.

### 3.4 Out of the Park Baseball — generations and development commitments

**Observed documented mechanics:** OOTP supports real, historical and fictional franchise careers. Its offseason Development Lab assigns selected players to programmes with different lengths and uncertain outcomes; limited opportunities require choosing where to invest. Programme results and underlying ratings can be obscured by scouting. [Official product](https://www.ootpdevelopments.com/out-of-the-park-baseball-home/), [official Development Lab manual](https://wiki.ootpdevelopments.com/index.php?title=OOTP_Baseball:Screens_and_Menus/Team_Menu/Player_Development/Development_Lab).

**Player account / developer explanation:** A forum player reported disappointing development; a developer explained that natural changes could occur alongside programme improvement. Another player used the editor to probe programme outcomes and acknowledged omitted coaching/relationship conditions. Neither report establishes normal-play success rates. Together they raise a useful question: can players distinguish an intervention from concurrent change? [Developer discussion](https://forums.ootpdevelopments.com/showthread.php?t=354903), [player's version-specific probe](https://forums.ootpdevelopments.com/showpost.php?p=5192351).

**ARD hypothesis:** Development is compelling when it changes whom the coach can use and when. A younger player can move from fringe option to regular, leader and veteran specialist without a straight march toward maximum attributes. Choosing present selection strength over a youngster's opportunity should remain a real football decision.

**Adapt / reject / test:** Refine M5-003, M5-006 and M8-005. Reuse existing training/development and career identity; distinguish training intent, actual growth and other simultaneous influences. Reject extra staffing administration, guaranteed potential fulfilment and copying a lab subsystem into the ready queue. Compare selected, omitted, injured and retrained cohorts across seasons; ask returning players what changed about their player's role and what they did to influence it.

### 3.5 Retro Bowl and Retro Bowl College — compress administration, retain consequence

**Observed documented mechanics:** New Star Games describes Retro Bowl as simple roster management around player egos, press and on-field play. College adds young talent and budget management. Their direct control is a major difference from ARD's coaching simulation. [Retro Bowl](https://www.newstargames.com/retro-bowl), [Retro Bowl College](https://www.newstargames.com/retro-bowl-college).

**Player accounts / tension:** In discussions, some players resisted a larger roster because simplicity was part of the appeal; recruiting accounts describe choosing a star versus covering several positions. These are individual preferences, not proof that small rosters are universally better. [Roster discussion](https://www.reddit.com/r/RetroBowl/comments/va6axh/), [recruiting choices](https://www.reddit.com/r/RetroBowl/comments/173cdob/).

**ARD hypothesis:** Keep the full AFL playing group, but compress the weekly interaction. A few real selection pressures, a nearby OUT → IN action and optional deeper inspection can support attachment without reviewing every player every week. Quiet weeks should remain quick. Reducing taps is not the same as making the decision for the player.

**Adapt / reject / test:** Extend §9.1 weekly selection, Shape and replacement flow; retain M5-015 workload rules and M5-006 reserves. Reject arcade quarterback controls, currency purchases and forced weekly chores. Time a normal selection change on a phone; test scroll recovery, return position, thumb reach and whether a replacement's trade-off is understandable without a “best” label.

### 3.6 Motorsport Manager — the watched contest should explain the strategy

**Observed documented mechanics:** The released 2016 PC game links preparation and personnel decisions to watched competition, including changing conditions and tactical interventions. Its product description connects current racing with development for later seasons. This is a reference for strategy unfolding in front of the player. [Released game description](https://store.steampowered.com/app/415200/Motorsport_Manager/).

**Evidence limit:** The announced PC 2 is scheduled for 2027; its promotional promises are not evidence of released behaviour or enjoyment. [Developer's sequel page](https://www.playsportgames.com/games/motorsport-manager-pc-2/).

**ARD hypothesis / failure risk:** Watching can turn an abstract instruction into an understandable consequence, but frequent pauses can destroy the flow being watched. A scripted decision at a fixed minute cannot replace a problem arising from the actual contest. Merely animating a result does not prove the animation explains its cause.

**Adapt / reject / test:** Refine M4-001 and the existing M8-007 cinematic tactical prototype. Preserve ordinary watching and skipping through the same authoritative simulation. Reject copying motorsport-specific timing mechanics or expanding into 3D. Compare watched sequences, event logs and aggregate statistics for the same seeded decision. Ask viewers what changed, and test whether reducing interruptions preserves understanding.

### 3.7 Football, Tactics & Glory — distinctive pieces, believable world competition

**Observed documented mechanics:** FTG combines squad management with turn-based football tactics. Its Football Stars expansion uses player differentiation and retained histories to enrich team construction. ARD can borrow the principle of distinct pieces without copying classes, turn-taking or direct unit control. [Official game description](https://store.steampowered.com/app/375530/Football_Tactics__Glory/), [developer's Football Stars press kit](https://creoteam.com/press-kit-football-tactics-glory-football-stars-press-kit/).

**Developer interpretation / failed approaches:** Creoteam describes revisions to world simulation as player progression and skills changed AI recruitment needs. Its internal checks extended across multiple decades and exposed trade-offs in processing time. That is a useful testing precedent, not independently verified balance. [World-simulation retrospective](https://creoteam.com/the-evolution-of-world-simulation-in-ftg-series/).

A difficulty discussion explains that reducing randomness can make strong players more consistently superior. The developer also values normal uncertainty. Less randomness therefore need not produce more interesting underdog play. [Difficulty options](https://creoteam.com/difficulty-increasing-options-in-ftgw/).

**ARD hypothesis:** A lower-rated footballer can be worth selecting for a specific job, while a star's cost or fit can make another option preferable. This needs real role effects and capable AI list construction over generations. Different archetype labels on functionally interchangeable players are insufficient.

**Adapt / reject / test:** Refine M5-008, M4-005 and §9.1 specialisations; validate M6-004/M8-005 together. Reject RPG ability furniture and hidden AI resource advantages. Compare competing compositions at similar resources, including weaker clubs and inconvenient personnel. Preserve upsets; demonstrate probabilistic leverage rather than making a good decision guarantee victory.

### 3.8 Teamfight Tactics — specialisation has an opportunity cost

**Developer method:** Riot's Game Analysis Team described representative-board comparisons that isolate variables while checking combinations against player data and expert interpretation. Its retrospective also discusses access to deep traits becoming a balance problem. These are internal development methods, not causal player studies. [Composition analysis](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/talking-tactics-game-analysis-team-gat/), [Monsters Attack learnings](https://teamfighttactics.leagueoflegends.com/en-gb/news/dev/dev-teamfight-tactics-monsters-attack-learnings/).

**ARD hypothesis:** A club identity should require sacrificing something: running power versus aerial coverage, specialist stopping power versus attack, youth opportunities versus immediate consistency. A balanced strong list should not collect every synergy by default. Increasing thresholds and multipliers alone could instead create one dominant build.

**Adapt / reject / test:** Extend the already accepted §9.1 synergy specialisation item, not a second synergy ticket. Compare representative lists with matched value, cap pressure, age and positional coverage, then test against different opponents. Watch both activation and actual football consequences. Reject copying trait thresholds, round-by-round roster resets, shop randomness, seasonal reward economies or cosmetic monetisation. A successful ARD identity is an explainable football approach, not a checklist of activated bonuses.

### 3.9 Battle Brothers — remember what a person can do, not just their rating

**Observed documented mechanics:** Backgrounds distinguish recruits' initial capabilities and flavour. Injury design gives surviving mercenaries persistent consequences and history. These mechanisms are documented by the developer; we have not demonstrated their causal contribution to attachment. [Backgrounds and traits](https://battlebrothersgame.com/dev-blog-18-character-traits-and-backgrounds/), [injury design](https://battlebrothersgame.com/dev-blog-79-progress-update-injury-mechanics/).

**Player account / frustration:** A new-player discussion describes uncertainty about evaluating recruits and finding useful roles for imperfect ones. It illustrates the tension between discovering a person and wanting an optimal rating calculation. [Individual discussion](https://www.reddit.com/r/BattleBrothers/comments/wokpoa/).

**ARD hypothesis:** Attachment can grow from repeatedly relying on a particular footballer's useful contribution, including someone who is not a star. A player's old importance should remain remembered when he loses a starting place, changes job or retires. More traumatic events are not required to create those stakes.

**Adapt / reject / test:** Refine M5-008, M7-003/M7-005 and existing captaincy work. Reuse the “kid you backed” foundation rather than creating another promise system. Reject permadeath, fantasy recruitment and increased injury frequency for drama. In follow-up sessions ask players to name a useful non-star, explain his job, and describe how their relationship with a veteran changed.

### 3.10 RimWorld — stories need consequences and recognition, not scripted drama

**Developer interpretation:** RimWorld presents its characters, backgrounds, relationships and event-directing AI as a story generator. Persistent individual circumstances and world events are central to that stated design. [Developer description](https://rimworldgame.com/).

**Player account / counterexample:** One player argues that repeated events can feel formulaic rather than generate distinctive stories. This is a selected complaint, not an assessment of the whole audience. [Story-generation discussion](https://www.reddit.com/r/RimWorld/comments/1vwo6cw/rimworld_is_a_great_game_but_as_a_story_generator/).

**ARD hypothesis:** Football already supplies opposition, pressure, reversals, injuries, selection, contracts and ageing. Recognise significant events and connect their consequences across time. An archive of numbers alone is not narrative thrust; generic “dramatic” prose detached from those facts is not an improvement.

**Adapt / reject / test:** Extend M4-009 and M7-005 around event-grounded recognition. Reuse career IDs and existing former-player coaching pathways to connect generations where that actually occurs. Reject an AI director that rigs close finishes, creates rubber-banding rivals or inserts disasters to maintain drama. Ask players to recount a match and a multi-season player arc, then check those accounts against the stored events. A quiet professional win needs no fabricated turning point.

### 3.11 Crusader Kings — persistent people, selective memory and generational continuity

**Observed mechanic:** Crusader Kings III's official description presents a continuing dynasty beyond one ruler's death, with traits and lifestyles shaping characters. The relevant parallel is continuity across generations, rather than hereditary football ability or medieval intrigue. [Official CK3 overview](https://www.paradoxinteractive.com/games/crusader-kings-iii/about).

**Developer interpretation:** Development diary 105 describes character memories that record events, timing and participants; later content can refer to those memories. Relationship tooltips explain why a bond formed. Some memories fade while important ones persist. This makes a present character easier to understand through earlier events, without requiring the player to remember every interaction. It is a design rationale, not a controlled enjoyment result. [Official developer diary 105, published on Steam](https://store.steampowered.com/news/posts/?appids=1158310&enddate=1662033633&feed=steam_community_announcements).

**Historical failure/correction:** September 2022 patch notes reduced feud initiation frequency, added a cooldown and corrected a feud trigger involving an undiscovered murder. This is historical evidence of pacing and information-boundary problems, not a claim about today's CK3 build. [Developer patch notes](https://store.steampowered.com/news/posts/?appids=1158310&enddate=1664452457&feed=steam_community_announcements).

**Director input / ARD hypothesis:** Keep the character persistence and connected history, with substantially less administration. A footballer can become a veteran specialist, leave for another club, retire and later enter an already-supported coaching role. A concise factual link should explain who this person was and why his present role matters. Existing stints, honours, milestones and coach-player links are the first material to inspect. Club history continues as squads change; do not replace every generation with a clean narrative slate.

**Adapt / reject:** Refine M7-005's record continuity and M8-005's long-save validation. Keep canonical football records; CK's selective memory is an analogy for restrained presentation, not permission to delete career facts. An added alumni presentation remains RC-004 for review. Reject genealogy management, inherited talent optimisation, routine intrigue, personality spreadsheets and a new relationship graph. Rivals must not react to information they could not know.

**Validation:** At a later-generation checkpoint, can the player recognise an older figure, describe his previous contribution and understand his actual current role? Trace each claim to stored events and stable IDs. Check retirement, transfers, same-name players and reload. Measure retrieval burden and repetition as well as recall; a larger archive alone does not establish a better story.

### 3.12 Esoteric Ebb — simple questions, logical consequences and remembered answers

**Director account:** The director enjoys simple questions whose answers have logical, amusing or insightful gameplay effects. This preference supports concise football decisions with character, rather than a text-heavy RPG layer.

**Developer interpretation:** Creator Christoffer Bodegård explains that agency needs feedback on choices, ranging from a later quip to a larger branch. He explicitly distinguishes authored interactive writing from emergent simulation. His account also describes substantial logic/syntax bug-fixing costs in a highly branching work. [Creator's interactive-writing retrospective](https://activation.unity3d.com/blog/interactive-writing-challenges-for-nonlinear-rpg-design). **Documented mechanic:** The developer FAQ describes stat-dependent dialogue choices and multiple major-quest outcomes. [Developer FAQ](https://steamcommunity.com/app/2057760/discussions/0/759556695324210776/). These sources do not verify a particular opening questionnaire or its exact hidden effects; no hands-on Esoteric Ebb play is claimed.

**ARD hypothesis:** Improve one existing question and its actual consequence before expanding content. An original illustrative coaching question is “Do we keep him out there?” during a genuine tired-player gate: retaining his influence also accepts workload risk; replacing him requires a real available footballer. The existing post-match media conference can ask a pointed question about a real selection or result and apply its established morale/board trade-off. Restrained humour should reveal the situation or the coach's stance while leaving costs understandable.

**Adapt / reject:** M4-001 and M6-008 already own these decisions; M1-011's event trade-off foundation is DONE. Inspect them first. A later factual callback is RC-005, awaiting review. Reject a personality quiz that assigns arbitrary permanent buffs, a separate dialogue engine, mandatory conferences and authored drama that contradicts the simulation. Keep answers short and avoid claiming private motives for real players.

**Validation:** Check that every offered answer applies its promised effect exactly once, unavailable actions disappear, skip stays neutral and quiet contexts stay quiet. On a phone, can players explain what they chose, what changed and why it made football sense? Test changed personnel, thin evidence, repetition, reload and any selected later callback. Amusing copy with an ignored answer fails the agency test.

### 3.13 Golden Lap — attractive abstraction does not guarantee depth

Its official race/garage screenshots make competition and comparison central; critical accounts praise the look while questioning repeated micromanagement and longevity. Useful hierarchy must survive phone scaling. Deliberately withholding information can create guessing rather than meaningful uncertainty. [Visual observations and limits](research/AFL_VISUAL_DESIGN_RESEARCH.md#golden-lap-competition-takes-precedence), [critical account](https://www.overtake.gg/news/golden-lap-review-charming-70s-f1-manager.2458/).

### 3.14 Super Mega Baseball — characterful sport, difficult roster access

Stylised personalities and sporting detail can coexist, but selected player accounts describe comparison facts scattered across views. Less visible information can create more total work. ARD should retain relevant evidence and current context without copying an arcade aesthetic. [Comparison findings](research/AFL_VISUAL_DESIGN_RESEARCH.md#super-mega-baseball-charming-sport-fragmented-comparisons).

### 3.15 Mini Metro — a coherent visual language still needs learning

A network carries the game's information economically, yet a mobile critic describes initial learning before it becomes intelligible. ARD needs recognisable football meaning, not fewer symbols at any cost. Browser screenshot access failed; the chapter distinguishes that from reviewed textual evidence. [Analysis](research/AFL_VISUAL_DESIGN_RESEARCH.md#mini-metro-and-into-the-breach-design-constrained-by-legibility).

### 3.16 art of rally — beautiful composition, real visibility limits

Inspected imagery offers restrained geometry and subject separation; critics also identify camera visibility and hardware compromises. Still-image beauty does not establish playable legibility. Protect ball, actors and timing on Android before decorative atmosphere. [Analysis and platform limits](research/AFL_VISUAL_DESIGN_RESEARCH.md#art-of-rally-restraint-and-subject-separation).

### 3.17 Circuit Superstars — readable conditions beneath small-scale sport

A critical account finds meaningful grip, tyre and fuel decisions under stylised presentation and notes persistence friction. ARD should show the relevant football condition and preserve progress. Its direct driving simulation is not a coaching template. [Transfer](research/AFL_VISUAL_DESIGN_RESEARCH.md#circuit-superstars-the-environment-can-explain-a-condition).

### 3.18 Into the Breach — clarity constrains design

The developer's postmortem describes how readable intent constrained mechanics and led to cuts. Borrow coherent rules and distinct useful functions; reject exact next-play forecasts in stochastic football. [Postmortem application](research/AFL_VISUAL_DESIGN_RESEARCH.md#mini-metro-and-into-the-breach-design-constrained-by-legibility).

### 3.19 Wildermyth — evolving people and conflicting continuity expectations

Choices, capabilities, ageing and later recognition can connect a career. A separate legacy campaign deliberately resets aspects of continuity, which some players dislike. ARD's uninterrupted football timeline must preserve age and identity instead. [Career analysis](research/AFL_LONG_CAREER_STORY_RESEARCH.md#wildermyth-evolving-usefulness-and-continuity-expectations).

### 3.20 Pyre — sport and narrative need to reinforce each other

Opposing professional reviews disagree about the sporting/narrative connection. This counters an assumption that adding strong prose to competition guarantees attachment. ARD should measure whether actual decisions and persistent consequences become remembered stories. [Contradictory evidence](research/AFL_LONG_CAREER_STORY_RESEARCH.md#pyre-sport-and-story-can-reinforce-or-detach).

ZenGM/Basketball GM and the forthcoming DDS Pro Basketball 27 supply additional system-specific comparisons in the agency and visual chapters; their evidence is not padded into whole-game deconstructions.

## 4. What this changes for ARD

### 4.1 A trustworthy decision-to-consequence chain

Treat each existing coaching gate as a contract:

1. **Evidence:** name the actual situation, players and a small relevant observation.
2. **Choice:** show feasible actions and the football trade-off, including keeping the current approach.
3. **Application:** show what changed, when it starts and when it ends; explain an unavailable or failed action.
4. **Observation:** let the following play and events expose the consequence and cost.
5. **Reflection:** report what happened, distinguishing it from an unprovable claim about what would have happened otherwise.

For example, a real sequence of lost aerial contests might support a matchup change. The changed defender's subsequent contests and the forward left elsewhere provide observable evidence. “The change won us the match” is not established by a later victory. Likewise, a tag reducing a target's ball use while costing the stopper his attacking involvement is a deliverable result even if the team still loses.

Current MatchSim already contains set-shot, tired-player, hot-midfielder, duel, momentum and late-bounce moments, together with a moments log, tagging costs, spare/interceptor effects and game-state AI. The work is to validate and improve this chain, not create another decision framework.

**Visual simulation is part of the evidence.** The animation, coach-call record, player statistics and summary must describe the same authoritative football events. Avoid decorative movement that implies a tactical effect the simulation never applied. Do not add a popup to every routine pairing or force a quota into a quiet quarter.

### 4.2 Replayability after learning the rules

Different answers should arise from real constraints and complementary players: personnel, cap, age, role, fixture, opponent, development time and intended identity. Strong knowledge should help, while leaving difficult decisions.

Test whether one recruitment policy or tactical response dominates across contrasting conditions. Check interactions over seasons, not each bonus in isolation. Scouting uncertainty alone cannot rescue a system with one universally superior answer; once players learn the hidden ranking, the same problem returns. Preserve real-data starting identities and reproducible seeds. Do not secretly scramble familiar footballers or make outcomes arbitrary to manufacture novelty.

### 4.3 A player's role can evolve while his identity persists

An illustrative arc is fringe recruit → useful role player → central contributor → leader → veteran specialist → retired club figure. This is a possible history, not a scripted sequence or requirement that everyone reaches each stage.

Selection, development, contracts and competition must permit those changes. Career IDs, club stints, achievements and actual former-player coaching links must survive them. Recognition should use genuine milestones or role changes, including achievements by non-stars, rather than reward all players with the same arc. New authored alumni scenes or relationship systems remain candidates.

Crusader Kings adds a useful presentation test: the reason for a present role should be inspectable through remembered facts. Retain canonical records and show a small relevant connection when existing history needs explanation. This does not authorise a new relationship simulation.

### 4.4 Mobile depth without inscrutability

One screen should answer one football question. Use nearby actions, stable scroll position, natural language and optional inspection of rules. A short observed statement can be more informative than ten unexplained multipliers. But simplification must not erase costs or make a choice seem effective when it is not.

Preserve transparent rules, AI parity and uncertainty. No best-lineup recommendations, optimal recruit highlights or psychic opponent counters. Explain the rule and evidence; leave the football judgement to the player.

## 5. Repository mapping and smallest useful changes

These recommendations refine accepted owners. They do not authorise parallel implementation or reopen completed foundations. Prerequisites and observable checks are recorded in the corresponding roadmap cards.

| Player benefit / recommendation | Current implementation and roadmap owner | Smallest useful change | Evidence needed |
|---|---|---|---|
| Understand and learn from a match call | MatchSim moments, resolution and logs; **M4-001**, reports **M4-009** | Audit one existing gate end to end: trigger, feasible options, applied state, duration, observed consequence | Negative/quiet triggers, invalid personnel, deterministic resolution; phone explanation before/after; paired seeds |
| Respond to a genuine danger | Forward-defender duels already merged #96; **M4-002**, §9.1 danger feedback | One event-supported matchup/structural response, not routine KPF/KPD prompts | Named binding, sacrificed job, feasible response, no invented danger; AI parity |
| Decide whether stopping a star is worth it | TAGGER_COST/TAGGER_BALL and specialist handling; **M4-003** | Verify existing attacking cost and expose relevant target/stopper evidence | Target and stopper involvement, team effect, specialist/non-specialist cohorts; no universal uplift |
| Build and watch a defensive identity | Interceptor/roaming contests and accountable-spare response exist; **M4-004** | Validate one roaming defender's benefit and uncovered responsibility | Event-to-visual consistency; own/opponent consequences; equal AI mechanics |
| Face a readable opponent | Observable score/quarter/influence-based AI exists; **M4-006** | Validate context-dependent reactions and hidden-information isolation | Same visible state gives same response despite altered concealed user choice |
| Use players creatively without universal retraining | Roles/archetypes #147, training/development; **M5-003**, **M4-005** | One plausible secondary role with visible progress and a real time/usage cost | Eligibility, persistence, unsuitable bodies, no unrelated attribute rewrite |
| Give omitted players a future | Passive development foundation; **M5-006** | Verify existing reduced-rate progression before adjusting it | Selected/omitted/injured matched cohorts over several seasons; no guaranteed star conversion |
| Value useful non-stars | Stats, role definitions, Awards/CoachReport; **M5-008** | One role-aware recognition comparison using valid recorded events | Defenders/rucks/forwards/mids; no fabricated stats, disposal bias or new OVR formula by accident |
| Build competing club identities | Synergies, list profile; **§9.1 specialisations** | Compare current activation and outcomes before changing one specialisation | Matched composition/resources, counter-opponents, long-run coexistence; readable opportunity cost |
| Make difficult offseason decisions | Contracts/trades/FA merged #208, follow-ups #223/#224; **M6-004** | Reconcile active valuation work, then test one repeatable asset exploit across years | AI need/cap/age, realised versus projected value, reciprocal offers, save compatibility |
| Remember a player's changing role | Milestones/history/awards; backing #220/#221 and payoff PR #226; **M7-003/M7-005** | Preserve those systems; add only missing event-grounded recognition/continuity | Stable identity across clubs, retirement and existing coaching links; quiet-season behaviour; no duplicate praise |
| Have a captain whose job matters | Accepted captaincy card; **M7-004** | One modest, explainable leadership context | Paired seeds, no blanket stat boost, same AI rule; phone understanding |
| Enjoy decades without data drift | Careers, generated classes, contracts, CoachPathway; **M8-005** | A staged career test matrix checking identity and competing policies | 5/10/20-year runs plus longer integrity soak; no duplicate history, collapsing competition or save growth regression |
| Make weekly changes comfortably | §9.1 selection brief, Shape and OUT → IN work | One nearby replacement flow plus full-list access | Android swipes in both directions, restored scroll, valid selection and no best-player ranking |
| Answer a short, meaningful football question | Existing moments and ClubLife/media; **M4-001/M6-008**, event foundation **M1-011** DONE | Improve one existing prompt, answer-to-effect mapping and follow-through | Logical costs, state/copy agreement, neutral skip, repetition and phone reading; the selected bounded callback follows M6-008's scope |
| Begin from a recognisable inherited club | Current opening League Draft redistributes all clubs; **M5-016** | Verified roster/pick manifest and dedicated opening-draft handoff | Complete registered rosters, no double ageing/history, checkpoint saves and both Android start flows |

### 5.1 Current status and overlap evidence

This research used code reads, GitHub merge records and the existing phone/audit documents. It is not Claude's final measured engineering audit.

- #210's bye, matchup-copy, retrospective plan, training-touch and money repairs are merged. #213's provenance/Langford work and fatigue audit are merged. #214's copy/training/staff audit is merged. Their remaining device checks stay open.
- #217's difficulty report, #220's three-game backing promise, #221's oval rings, #222's scouting estimates and #225's assistant contracts are merged.
- **Refreshed checkpoint, main 6573a8f:** #223 (levers evidence), #224 (trade-value change), #226 (payoff), #230 (reachable break calls and tired-call audit) and #229 (real-crumb goal-line presentation) are merged. #206 (music), #228 (competitive balance/Trade E) and #231 (proposed club palettes) remain open. Do not treat open-proposal results as main behaviour or duplicate merged work. Phone verification remains open; the director has selected a meaningful tired-call trade-off. PR #231 already records palette approval.
- M4-001's moments framework is already present; M4-003 has existing attacking costs; M4-004 and M4-006 contain implemented foundations. Old TODO labels should not cause a second implementation. Their status is reconciled to PARTIAL/VERIFY, leaving actual missing outcomes and validation explicit.
- M6-004's currency-scale subsection and M7-005's ceremony subsection describe merged foundations as still in progress. Reconcile those local records without marking their entire umbrellas complete.

The existing [difficulty evidence](DIFFICULTY_EVIDENCE_2026-10-05.md) covers seven five-season autopilot careers and reports no premierships in 35 seasons. It does **not** reproduce the director's actively managed dynasty, and it predates subsequent scouting changes. Its proposed next measurements are live calls and market advantages. Do not infer from either sample that all careers are too easy or too hard; do not tighten profile bands or boost AI without a demonstrated cause.

## 6. Accepted inherited-list career: data and chronology

**ARD-M5-016** is a distinct start option, not a replacement for the League redraft.

The new career inherits all 18 founding clubs' **complete end-of-season 2026 registered playing groups before subsequent offseason changes**, including players with no senior appearances. The player chooses a club, makes visible pre-draft list-space decisions where required, and prepares for the **2026 National Draft**. The first playable season is **2027**.

As of this research date the real draft is still forthcoming: AFL announced national-draft dates of 19–20 November, with the trade period 5–14 October. A prospect cohort is not completed real draft results. Freeze the roster and pick-ownership provenance to the requested starting snapshot rather than silently importing later transactions. [AFL's official dates](https://www.afl.com.au/news/1523232/afl-locks-in-draft-and-trade-period-dates-for-2026).

Current ARD data contains **669 appearance-based 2026 players**, not a verified complete registered-list manifest. The runtime enriched ratings and existing IDs need reconciliation with full official club/AFL rosters. Record club counts, named omissions, source dates and the rating basis for non-appearance players. No fictional filler or silent cuts. Simulated contracts remain estimates. [Existing data provenance](DATA_SOURCES.md), [AFL's pre-2026 list-change reference](https://www.afl.com.au/news/1442429/ins-and-outs-your-clubs-list-changes-ahead-of-2026-afl-premiership-season/).

Use the researched prospect pool with separately verified pick ownership/order for that snapshot. Existing sources are leads, not a completed manifest: [AFL draft hub](https://www.afl.com.au/draft), [official draft-order resource](https://www.afl.com.au/draft/draft-order), and [Draftguru's 2026 lists](https://www.draftguru.com.au/lists/2026) as a secondary cross-check. Page labels and update dates must be verified when importing; a currently displayed order may concern a different year or later transactions. Where source conflict remains, resolve it before presenting the snapshot as complete.

Reuse the current simplified National Draft rules, including the current order model and club-tie treatment. Full father-son/academy bidding reform remains separate §9.1 work and is not a shipping dependency. Source real pick ownership, but do not silently claim the game's simplified drafting algorithm reproduces every AFL rule.

**Handoff risk:** GameDB already dates player ages to March 2027. The normal intake path expects a season context; finishing it calls the next-season routine that ages/develops/retires players. Calling that path as if 2026 had just been played risks a ghost season, double ageing, repeated 2026 history and duplicate rookie assignments. Create a dedicated opening-intake boundary which starts 2027 once; use the normal lifecycle thereafter.

Persist the start choice and opening progress. Old saves retain their existing interpretation. Preserve real/fictional-name preference. Tests must cover full rosters and unique ownership, list-space decisions, original player IDs, pick ownership, opening save/resume, 2027 ages/history, rookie assignment/contracts exactly once, repeated completion calls, expansion and subsequent normal rollover. Both starts require Android checks.

## 7. Research proposals — director decisions

**Completed director review, 2026-10-05:** RC-001/002 are excluded. RC-003–007 are accepted within their existing owners, with no duplicate player-to-coach pathway. **ARD-RC IDs preserve research provenance, not new milestone tickets.** The canonical roadmap now contains their scope, dependencies, exclusions, acceptance and validation. Historical prototype/evidence descriptions below are subject to these decisions.

### ARD-RC-001 — Optional tactical practice preview

**Director decision, 2026-10-05: EXCLUDED.** Do not implement this mode or prototype. The proposal below is retained only as research provenance. Existing live-match clarity and structural coaching work remain accepted under their original owners.

- **Evidence / benefit:** FM's visualiser suggests a way to learn what a structural instruction means before relying on it in a match.
- **Overlap / owner:** M4-004 and M8-007; existing live calls remain the first priority.
- **Prototype:** One spare/interceptor situation generated by the actual engine, viewed with/without the instruction. Show intended responsibility and the football trade-off; no winning-plan recommendation.
- **Trade-offs / exclusions:** Another screen, runtime cost and possible false certainty. No training stat benefit, replay branching in a live career or second simulation model.
- **Selection evidence:** Players understand the change better than from the existing call alone; visual events agree with engine events; preview uncertainty is clear. Reject if improved live presentation answers the need.

### ARD-RC-002 — A saved match worth remembering

**Director decision: EXCLUDED.** Do not implement saved-match bookmarking or an archive; ordinary reports/history remain accepted. Historical proposal retained below as provenance.

- **Evidence / benefit:** The director values Footy Redraft's stories; RimWorld suggests remembering connected events rather than adding generic narrative.
- **Overlap / owner:** M4-009 reports and M7-005 history.
- **Prototype:** Let the player keep one existing match report with its real call, named moments and relevant career links. First test static event-backed storage; full replay is not part of the prototype.
- **Trade-offs / exclusions:** Save growth, archive clutter and old-event compatibility. No fabricated turning point, new broadcast engine or scripted win story.
- **Selection evidence:** In a later session players use it to recall what happened and why it mattered. Compare against the existing history screen before adding a new destination.

### ARD-RC-003 — A bounded development commitment

**Director decision: ACCEPTED within existing owners.** See the canonical roadmap for build scope and gates.

- **Evidence / benefit:** OOTP's programmes suggest that choosing where to spend development time can create anticipation and sacrifice.
- **Overlap / owner:** M5-003 retraining and existing training; may be unnecessary once those work.
- **Prototype:** One multi-week plausible role project with an explicit opportunity cost, progress and uncertain result, using existing progression rules.
- **Trade-offs / exclusions:** More admin, stacking with training and exaggerated individual control. No guarantee of reaching POT, extra currency or separate development engine.
- **Selection evidence:** Players describe a meaningful choice rather than a compulsory task; multi-season probes show no dominant universal project. Defer if it merely duplicates the existing plan.

### ARD-RC-004 — An alumni link across generations

**Director decision: ACCEPTED within existing owners.** See the canonical roadmap for build scope and gates. This is a refinement of existing player-to-coach history, not a new pathway.

- **Evidence / benefit:** Battle Brothers and RimWorld suggest that persistent individual identity can connect events; Crusader Kings adds inspectable reasons and remembered context. ARD already has former-player coaching pathways.
- **Overlap / owner:** M7-005 history and M6-002's existing coaching/pathway foundation.
- **Prototype:** One factual connection when an actual former player enters coaching: previous club stint and genuine achievement linked to the existing coach profile.
- **Trade-offs / exclusions:** Rare activation and record retention. No mandatory return to the user's club, new relationship simulation, guaranteed coach role or fabricated personality arc.
- **Selection evidence:** Returning players recognise the person and remember his earlier role; linkage survives retirement, club movement and save/load. Baseline continuity checks remain accepted QA even if this presentation is rejected.

### ARD-RC-005 — One football answer remembered later

**Director decision: ACCEPTED within existing owners.** See the canonical roadmap for build scope and gates.

- **Evidence / benefit:** The director's Esoteric Ebb preference and its creator's choice-feedback rationale suggest that a later factual reference can make a small answer feel considered.
- **Overlap / owner:** M6-008 media and M7-005 history, using current ClubLife effects; M4-001 already owns in-match follow-through. Keep #220/#226's backing promise/payoff with its existing owner.
- **Prototype:** One existing media question, its current immediate morale/board effect and one brief later reference when the actual saved context makes it relevant. Remember the answer without fabricating a caused win, a grudge or a player's private motive.
- **Trade-offs / exclusions:** Repetition, save flags and logic/testing cost. No new promise system, dialogue framework, personality score or gameplay bonus for completing a conversation.
- **Selection evidence:** Players remember the answer and understand the callback; skip, changed clubs/personnel, no relevant later event, repeat delivery and reload behave correctly. Reject if the existing immediate response is enough or the callback feels forced.

### ARD-RC-006 — A bounded comparison for one list decision

**Director decision: ACCEPTED within existing owners.** See the canonical roadmap for build scope and gates.

**Status: director-selected; execute only the scoped extension in its existing roadmap owner.** Benefit: compare two plausible football options without remembering several profiles. Evidence: [SMB roster feedback](https://www.reddit.com/r/SuperMegaBaseball/comments/13x6ny1), [ZenGM comparison](https://zengm.com/blog/2024/03/compare-players/) and the [visual chapter](research/AFL_VISUAL_DESIGN_RESEARCH.md).

**Execution owner:** M5-014 or M6-004, within an existing draft/market view. **Dependencies:** correct player sheets, scouting estimates, contracts and originating-state preservation. **Prototype:** one task, two eligible options, aligned role/age/current assessment/cost and only genuinely relevant additional facts. First test whether consistent existing rows already solve it.

**Trade-off:** adjacency reduces memory work but can overcrowd a narrow phone or imply an optimal recruit. **Exclusions:** a universal comparison dashboard, green-best ranking, new rating formula, new ready-queue dependency.

**Review acceptance:** people can explain a football trade-off and act with fewer repeated lookups; neither option is labelled best; uncertain estimates retain their basis; Back restores the list. Test several portrait widths and native Android touch, veteran/prospect/depth choices and missing data. Director selection is recorded; existing implementation and phone/balance gates still apply.

### ARD-RC-007 — One rival club's identity across generations

**Director decision: ACCEPTED within existing owners.** See the canonical roadmap for build scope and gates.

**Status: director-selected; execute only the scoped extension in its existing roadmap owner.** Benefit: the league feels inhabited beyond the user's club. Evidence: [FTG's persistent world](https://creoteam.com/huge-update-11/), [OOTP career accounts](https://www.reddit.com/r/OOTP/comments/1s3l3y5/how_hands_on_are_you_in_longterm_saves/) and the [career chapter](research/AFL_LONG_CAREER_STORY_RESEARCH.md).

**Execution owner:** M7-005, using existing opponent preparation and AI/season records. **Dependencies:** accurate stints/results and actual AI list decisions; M8-005 checks; do not change in-flight #228 balance. **Prototype:** within an existing club surface, one concise comparison between its earlier and current squad or football pattern, only where recorded data supports it.

**Trade-off:** useful context can become stale stereotyping or add browsing work. **Exclusions:** scripted rivals, immutable club bonuses, fictional feuds, a new world-simulation layer, new mandatory notifications or retrospective invented tactics.

**Review acceptance:** the stated change matches the real saved lists/results; quiet or unchanged clubs receive no forced story; a player can describe a rival's changing problem and recognise a real returning individual. Simulated continuity plus observed multi-season recall is required. Broader league storytelling beyond this bounded extension remains unselected.

## 8. Validation: behaviour, understanding and enjoyment

All quantities below are **prototype study assumptions**, not proven pacing requirements or statistical power claims. Claude owns final engineering measurements; the director judges the experience.

### 8.1 Formative phone sessions

Recruit roughly 8–12 players spanning AFL familiarity and management-game experience; include weaker and stronger clubs. Observe ordinary play before offering explanations. Do not force every participant through every feature in one session.

| Question | Observe / ask | Failure signal |
|---|---|---|
| Can I explain a choice? | Before a gate, ask what the player expects and what it might cost | Choosing at random, following a presumed recommendation, inability to name a downside |
| Was a short question meaningful? | Ask why the answer suited the situation, then inspect its actual effect and any selected callback | Amusing wording hides costs, ignored answers, forced repetition or invented consequences |
| Did the choice apply? | Ask what changed during following play and when the instruction ended | Result text says applied while the state, animation or personnel disagree |
| Can I learn from a loss? | Compare the player's account with actual events | Treating every defeat as a bug, or every victory as proof of the call |
| Do I remember people? | Ask for a useful non-star and a player they backed, without first opening their profiles | Only aggregate OVR remembered; praise with no remembered contribution |
| Can I recount a match? | Ask for a turning point and named people, including a quiet match | Only margin/stat leaders; story invented by an unsupported panel |
| Is list management difficult in a good way? | Watch retention, recruitment and selection across club needs | Same recruit every time regardless of context; chores without sacrifice |
| Can I use the phone comfortably? | Swipes both ways, OUT → IN, inspect/return, Android Back and resume | Lost scroll position, accidental selections, distant actions, traps |
| Do I want another season? | Offer a natural stopping point; ask what future event interests them | Continuing only to clear a checklist, or unable to name a future concern |

Follow up after several seasons and later after a second player generation where practical. Ask what changed about the club's identity, a veteran's role and a recruit's place. Document recurring frustrations and contradictory responses, not just favourable quotes. Small formative sessions find problems; they do not establish retention rates or causal enjoyment effects.

### 8.2 Seeded simulation comparisons

Use current authoritative rules and commit/seed records. Start small to diagnose a hypothesis; extend the sample only when uncertainty warrants it. Report distributions and effect sizes, not selected wins.

- **Calls:** compare keep-current, context-informed and deliberately mismatched policies from reproducible states. Measure relevant contests, target/stopper involvement, clearance/entry/shot changes, margin and interruption frequency. A branch can alter random-number consumption: a shared starting seed improves comparison but does not guarantee identical subsequent events.
- **Triggers:** positive, negative and quiet scenarios, including depleted benches and unreachable counters. “No special decision” is valid. Separate intended rule effects from copy-only statements.
- **AI parity:** identical action effects for either side; distinguish observable history from concealed plans/POT. Alter hidden information while preserving the visible state to test isolation.
- **Compositions:** compare different identities at similar talent, cap, age and depth, against several opponent types. Track costs and weaknesses, not just synergy activation.
- **Markets/development:** test current OVR, realistic potential, age, role demand, cap and future picks together. Compare hold, trade-heavy, youth-first, veteran-first and low-admin policies without giving any policy extra hidden information.
- **Careers:** staged 5/10/20-year samples across club strengths, then longer integrity soaks under M8-005. Track player IDs, role/selection histories, contracts, retirement/coaching links, generated-class depth, honours, competition health, save size and rollover failures.
- **Inherited start:** assert sourced roster counts and unique ownership before any cuts; record visible cuts and resulting list space; resume at each opening-draft stage; prove no ghost 2026 season or duplicated 2026 history; complete 2027 and a later normal draft.

A simulation can establish that choices change behaviour, expose an exploit or identify a dead end. It **cannot establish that players enjoy those choices**. Pair it with observation and multi-season follow-up.

### 8.3 Delivery and follow-through

This pass changes documentation only. Verify stable roadmap IDs, dependencies, overlap with active PRs, source links and current status evidence. Preserve the P0 correctness and Android playtest gates. Only director-selected extensions enter existing owners; rejected proposals remain excluded. No implementation task is sent to Claude.

Before implementing a refined card, re-read current code and PR state. Before calling it DONE, require the card's appropriate regression, balance, save and phone evidence. Research supports a testable design hypothesis; it does not replace the director's judgement.

## 9. Intensive-pass conclusions and verification

The evidence changes emphasis more than feature count. Keep **stable rules with changing football problems**, **a watched match that explains supported events**, **nearby decision evidence**, and **the same people across changing jobs and decades**. Beautiful minimal presentation fails if comparison facts are hidden; persistent characters fail if their past is inaccessible; extra choices fail if their effects converge into a no-op.

The visual chapter takes roughly a third of the focused synthesis, with 48 new sources primarily classified as visual/usability. This includes sporting abstraction, critical praise and criticism, specific navigation/comparison complaints, accessibility references and direct screenshot inspection. AFCM remains outside the visual target.

### Evaluation proposal

Use formative Android sessions with football-literate newcomers and experienced sim players, followed by several-season recall. Treat cohort sizes, task durations and any thresholds as prototype assumptions until established. Record build/device/theme, source of confusion, repeated lookups, mistaken taps and observed completion; separately ask about appearance, football understanding, agency, attachment and voluntary desire to continue.

A compact questionnaire can supplement observation. [miniPXI](https://pure.tue.nl/ws/portalfiles/portal/317193176/3549507.pdf) has qualified validity/reliability; it is not a magic enjoyment score. [Motivation research](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf) supports autonomy/competence questions but does not prove any particular ARD feature causes enjoyment. [GameFlow's abstract](https://doi.org/10.1145/1077246.1077253) provides a heuristic frame, not a substitute for measured behaviour.

Validate effects and player interpretation separately. Seeded simulations compare policies, equal-resource compositions and long-career integrity; they do not establish enjoyment. Watch/skip agreement, event/visual authority, saved identity and current-club attribution remain correctness requirements.

### Delivery boundary

This expansion changes Markdown documentation only. Preserve all ticket IDs and the exact accepted M5-016 chronology. Refine existing owners without marking phone gates complete. RC-001/002 are excluded; RC-003–007 are accepted within existing owners and reflected in §0.4.1. Source/relative-link/status/overlap checks are documentation validation; no gameplay test or new Android playtest is claimed.

Before building any refined owner, refresh its code and open PRs. Before publication, refresh main so concurrent roadmap changes are retained. The director has selected a meaningful tired-call trade-off; audit/phone validation still applies. Palette approval is already recorded in #231, independently of this research; do not approve additional visual changes by analogy.
