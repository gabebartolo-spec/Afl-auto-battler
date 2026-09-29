# Aussie Rules Dynasties — Design Audit against the Roadmap Philosophy

*29 September 2026. Audited: `main` at bfc2ea3 (includes #87–#92). Read-only: no game code or roadmap changes were made for this audit.*

*Open, unmerged PRs are noted where they change the picture:*
- *#93: game plans suit a list; the AI plays its own game; tags are for midfielders only.*
- *#94: honest match ratings.*
- *#95: team-sheet ins and outs.*

*While auditing I found that #93 would leave an in-match "tag their hot forward" option that does nothing. I've asked that #93 not be merged yet; see §4.4.*

**Evidence used:**
- The code, read directly (engine, state, every player-facing scene).
- The director's phone playtests: four straight ~40-point losses, "choices feel like clicking and hoping", synergies found opaque, far-receiver pauses.
- Seeded measurements run today (80–150 matches per condition):

| Measurement | Result |
|---|---|
| Plan effect when the opponent never changes plan | +10 to +23 points |
| Plan effect with the AI countering, as on `main` | 0 to −5 points (every plan ≤ Balanced) |
| Gawn v no real ruck | about 14 points a match |
| One hit-out | +0.4 points of margin (r ≈ 0.1) |

---

## 0. The short version

The game you are playing today is **a list-quality simulator with a coaching skin.**

The result of a match is decided mostly before the first bounce: by line averages the engine computes from the 22 you picked, plus the home edge and dice.

What can you do once the ball is bounced?
- **Pick a game plan.** On `main`, the AI answers every plan with its counter at the next break, so no plan beats Balanced (measured).
- **Tag a player.** The tag takes some of the ball off him, but nothing shows you the tag working.
- **Answer up to two moment cards a quarter.** Their effects last a few minutes.
- **Change a pep talk or rotation policy.** Effects are around 2–5%.

Every one of these is real in code. Almost none of them is **perceptible**. The playtest verdict, "nothing I did meaningfully improved my chances", is an accurate reading of the design, not a misunderstanding by the player.

The deeper cause is not "the modifiers are too small". It is structural:

1. **The engine resolves football through team averages, not people.**
   - Who wins a stoppage comes from `Squad.contest`: the mean contested rating of the three centre midfielders, the ruck's rating, and mean disposal.
   - Whether an entry is marked comes from the forward line's mean marking against the defence's mean intercepting.
   - Individual players decide *who gets credited*, not *what happens*.

   So a star is diluted into an average. A tag reduces one man's share of the ball, which the team simply redistributes. And "selection" mostly means nudging line means.

   The single exception is the ruck, a "line of one". That is why losing a star ruck swings a match by about 14 points, and why every playtest loss had the opposition ruckman as best on ground.
2. **Player identity is a label painted on attributes, not a source of different football.**
   - Traits are attribute thresholds (Ball magnet = disposal ≥ 86). Their effects are 4–12% nudges to one probability. Synergies are 2.5–8% nudges.
   - An unusual archetype does not open a different way to play; it adds a slightly different coefficient.
3. **The match does not tell its story while it happens.**
   - The live feed shows only goals, behinds, goal runs, breaks and moment cards.
   - Injuries happen after the siren, off screen.
   - Momentum is a display bar the engine doesn't have.
   - The turning points that would make a story are computed and thrown away: an intercept that led to a goal, a contest won, a player getting on top of his opponent.

What is genuinely strong:
- the league draft as a party-building opening;
- honest, event-based statistics;
- a real career history for every player;
- awards;
- the retired-player-to-coach pathway;
- a restrained, readable visual and writing style;
- the decision-feedback work of the last two days (#88–#90), which gives the right *shape* to decisions even though the decisions underneath are still weak.

The foundations are good. The engine needs to let individuals matter.

---

## 1. System-by-system audit

Each system below covers:
- **Does:** what the player does.
- **Info:** the information they get.
- **Consequence:** what their decision changes.
- **Party:** whether it builds identity for players or the group.
- **Story:** its potential for emergent stories.
- **Realism/fun:** the balance between realism and fun.
- **Scrutable:** whether a fan can reason about it without hidden formulas.
- **Verdict.**

### 1.1 Main menu and starting a career

- **Does:** New career, then player names (real or generated) and difficulty, then "Choose your club", then straight into a **league-wide snake draft**. Every club starts empty and drafts from the whole player pool under a cap (`Draft.gd`). There is no "take over a real list" mode.
- **Info:** Difficulty says what it changes: rival development, trade margins, your XP. It does **not** affect match strength. So "was I on Hard?" doesn't explain the playtest losses.
- **Consequence:** Enormous. The draft sets almost everything that decides your first season.
- **Party:** Potentially the best party-assembly moment in the game (see 1.3).
- **Story:** Strong: "I built this side from nothing".
- **Verdict: strongly supports the philosophy in principle; undermined by the draft's information problem (1.3).** A new player's first hour is a 22-man draft decided on OVR and cost, followed by a first match the engine may already have decided.

### 1.2 Weekly hub and weekly loop

- **Does:**
  - Reads "This week v X" (ground, ladder spot and form, two or three opponent facts).
  - Resolves one event card.
  - Optionally goes to Pick the side, Training, My list or Coaching.
  - Then Play match (watch live) or Sim round.
- **Info:** Clean and restrained. The opponent facts are real (`Matchup.facts`).
- **Consequence:** The loop has one mandatory decision a week, the event card. Everything else defaults sensibly:
  - auto-pick picks the side;
  - the standing plan carries over;
  - training plans persist.

  A player can Sim round from the hub for a whole season and lose little.
- **Party:** Weak. The hub is about the club and the fixture, not *your players*. Nobody is in form, no milestone is near, no rivalry is coming.
- **Story:** Low. Weeks blur together.
- **Verdict: functional but passive.** It is a good container with little inside it. The default path is "press Play". That's fine when the match is where decisions live, but the match isn't delivering (§1.13–1.16).

### 1.3 League draft (career start) and intake draft

- **Does:**
  - Picks players in a snake order under a cap. Position cards show "NEED +2 / COVERED".
  - Must carry two rucks.
  - Can inspect a player (identity, production), draft, or release a pick.
  - End of season: an intake draft from a prospect pool (superdraft classes vary by year).
- **Info:** OVR, position, value/cost, identity line and production. There is no sense of **what a side needs to win**:
  - the need labels count bodies, not quality;
  - nothing says the ruck is the most leveraged single position in the engine (worth about four elite midfielders at the stoppage, from `contest = 0.42·mid_contest + 0.24·ruck + …` with `contest_swing` 360);
  - nothing previews how your forming 22 compares with the league.
- **Consequence:** Decisive, and largely **invisible until round 1**. The AI drafts by value over replacement (`_ai_score`); the human drafts by gut. The director's Demons almost certainly lost the ruck arms race in the draft. (Gawn went to Gold Coast. Every loss featured a 55–61 hit-out opposition ruck, which reflects a stoppage deficit even though hit-outs themselves decide little.)
- **Party:** This is where "assembling complementary pieces" should live. Today it is "assemble high OVR at a price".
- **Story:** Good raw material: your first pick, your steal, the one who got away.
- **Realism/fun:** A fantasy-style league draft isn't AFL-realistic, and that's a good gamification. Keep it.
- **Scrutable:** Weak on the thing that matters most, what makes a side good.
- **Verdict: mechanically interesting but poorly communicated.** The highest-leverage decision in the game is made with the least useful information. The head-to-head words from #90 ("Midfield strong · Ruck among the weakest") would be transformative here, in the draft, while it can still be fixed.

### 1.4 Opponent preview (hub and selection)

- **Does:** Reads.
- **Info:**
  - Hub: two or three facts ("The best ruck in the competition", "X is the danger").
  - Selection (since #90): line against line in the same words, the people who matter, and "How they play" after three games.
  - #93 would add "Their usual game".
- **Consequence:** Preparation responses are selection (moving personnel) and the standing plan. Both have small, averaged effects (1.5, 1.8).
- **Party:** It names their danger player, which is good. You can't answer him with a person; a tag only reduces his share of the ball.
- **Story:** Their danger man can become your nemesis, but nothing tracks it across meetings.
- **Verdict: basically sound, but the problems it poses have no strong answers.** The preview describes an encounter well. What's missing is a meaningful response.

### 1.5 List management and player profiles

- **Does:** Browses the list and opens profiles.
- **Info (profile, `PlayerSheet`):**
  - identity ("Inside midfielder", "Key forward", "Tagger"), number, age, height;
  - availability and mood;
  - OVR/POT and development state;
  - strength grades, one "Needs work";
  - traits with a scout line;
  - this season's production;
  - career games and goals by club.
- **Consequence:** None directly; it's reference material.
- **Party:** Better than most sports managers. The identity line and strengths/weakness read like a scout.

  What's missing is **his story with you**: best games, milestones (M7-003 TODO), records, the finals he played in, the day he kicked seven. Career totals exist, but the moments don't.
- **Story:** Low. The profile is a present-tense card, not a biography.
- **Verdict: basically sound but underexploited.** The data exists (per-match Player Ratings in `form_log`, season tallies, awards). It just isn't remembered or shown as history.

### 1.6 Ratings, attributes, roles and positional identity

- **Does:** Nothing directly. OVR drives auto-pick, draft cost and AI valuation.
- **Info:** OVR and POT are prominent. Attributes sit in a drill-down, and role identity is shown in words. M5-010 made OVR predict strength, which is good.
- **Consequence in the engine:**
  - Attributes feed line means (1.13) and who gets the ball (`_weighted_roles`, power 2).
  - Roles are tendencies (§1.3 of the roadmap).
  - Wings are real: `WING_TRANSITION` ×1.6 transition ball, ×0.4 stoppage.
  - Taggers are real: they bite harder.
- **Party:** The roles vocabulary is good and consistent. But two players with the same OVR in the same line are close to interchangeable in outcome terms. Their *identity* shows up in their stat lines (who gets credited), not in *how the team plays*.
- **Realism/fun:** Realism here is costing fun. The line-average model is statistically sensible, but it makes individuals fungible.
- **Verdict: sound vocabulary on a fungible engine.** It is the root of several problems below.

### 1.7 Selection, formation and bench

- **Does:**
  - Auto-pick (default) or My selection: name players to Ruck, Midfield (centre 3 + wings 2), Defence 6, Forwards 6 and Interchange 4.
  - Any player can play anywhere.
  - Since #90, reads the head-to-head and changes the plan here.
- **Info:** Synergies the side switches on (with effects and carriers since #89), line standing against the opponent, and injuries.
- **Consequence:**
  - Moving a player changes line means. There's no out-of-position penalty beyond attributes.
  - Wings matter.
  - Two Bulls switch on Engine room (+2.5% stoppage).
  - The bench is used by rotations.

  In practice auto-pick is close to optimal almost every week, so manual selection is mostly "the same side, confirmed".
- **Party:** This is where "choose the right party for this encounter" should happen. Today the only encounter-specific moves with leverage are a better ruck, and wings to swing transition ball. Nobody has a *job* against *someone* (no match-ups: M4-002 TODO), so selecting for an opponent is guesswork about averages.
- **Story:** "I brought in the kid for his debut" (#95 marks it), but his debut can't *mean* anything tactically.
- **Verdict: choice without meaningful leverage (outside ruck and wings).** Assembling a 22 today is mostly selecting the highest-rated legal players. Auto-pick does that, and the game quietly agrees.

### 1.8 Traits and synergies

- **Does:** Reads them; selection can switch synergies on.
- **Info:** Excellent since #89. You see what each synergy does in football words and who carries each trait ("Aerial threats in your side: Fenn Quiver"). The director called the synergy screen excellent.
- **Consequence:**
  - Traits: Ball magnet ×1.10 share of the ball; Bull ×1.15 at clearances; Aerial +6% mark chance; Sharpshooter ×1.06 goal chance; Crumber ×1.12 on loose shots; Lockdown −4% opposition goal chance; Big-game +0.05 fitness in Q4 and finals; Engine −25% fatigue.
  - Synergies: Engine room +2.5% stoppage; Supply line +6% metres; Tall-small ×1.05 goals; Intercept wall ×0.95 their goals; Lockdown unit +8% pressure; Running machine −15% fatigue.
  - Each is real, and each is invisible inside one match's variance.
- **Party:** This *should* be the heart of "complementary pieces". The design is right. The leverage and the feedback are not:
  - traits are derived from attribute thresholds, so they add no information the attributes don't already hold;
  - you cannot build around a Tall-small forward line and *see* it working;
  - nothing ever says "that was the crumber at work".
- **Story:** Traits never appear in the match story.
- **Realism/fun:** This is a place to gamify, deliberately:
  - fewer, stronger, situational identities;
  - effects that surface in the feed and at full time;
  - synergies that change what a plan can do (PlanFit, #93, starts on this).
- **Verdict: mechanically interesting but poorly communicated, and too weak to feel.** Refine it; don't replace it.

### 1.9 Game plans (standing and quarter-break)

- **Does:** Picks one of six plans: Balanced, Attack corridor, Defensive press, Win contest, Controlled tempo, Through stars. It's set as a standing plan (Coaching, and selection since #90) and can be changed at every break.
- **Info:**
  - A one-line summary that includes the counter triangle ("Beats Attack corridor; Controlled tempo plays through it").
  - Since #88, "What your calls did" shows the stat each plan is about, against the quarter before.
- **Causal chain on `main`:**
  - choice → `tactics[side].gameplan` → `_pv(key)` multipliers (goal ×1.10, press ×1.18 and so on) scaled by coaching execution;
  - the AI, at every break, reads your last plan and **picks its counter** (`ai_tactics`, `COUNTERS`);
  - net measured effect: 0 to −5 points against Balanced.
- **The chain breaks:**
  - at the AI, which always counters;
  - at personnel, since the plans ignore the list;
  - at feedback, since #88 reports stats but can't separate the plan from the counter.
- **Party:** None on `main`. #93 ties each plan to the players who carry it and names them.
- **Story:** "We pressed and it worked" is only possible if the press is visible. The feed shows goals, not pressure.
- **Realism/fun:**
  - A rock-paper-scissors counter is gamified in the *wrong* way: it's hidden, deterministic, and punishes consistency.
  - #93 moves toward the *right* gamification: plans express your list, and opponents have a legible style.
  - Watch-out: #93 measured the press at +35 for a pressure-rich list. That may be "exaggerated arcade" under §0.2 and should be tuned by playtest.
- **Scrutable:** The summaries are good. The effect sizes and the AI's counter are hidden.
- **Verdict on `main`: actively conflicts with the philosophy (an illusion of agency).** #93 changes this to "basically sound, needs playtest tuning".

### 1.10 Coaching hub and coaching staff

- **Does:**
  - Coaching: standing plan, How we win / How we get beaten, form, list and cap, board, staff.
  - Staff: hire into jobs from a living market.
  - Retired players become coaches (CoachPathway), a lovely long-save touch.
- **Info:** Clear, in football words.
- **Consequence:** Staff effects are three capped modifiers (`CoachEffects`):
  - teaching → XP;
  - tactics → plan execution (±15%) and how fast the AI reads the match;
  - man-management → how much being dropped hurts morale.

  All are real and all are faint.
- **Party:** The coach pathway creates attachment (your old captain as forwards coach). Nothing makes a coach feel like *someone*: no style or philosophy that changes how your side plays.
- **Verdict: functional but passive.** It has good bones and is not a priority. Leave it until the match layer works.

### 1.11 Training, development and reserves

- **Does:**
  - Sets a plan per player: position plan, Inside mid, Wing, Key defender, Rebounding defender, Key/Small forward, Ruck, or Manual.
  - XP comes from senior games (4 + 6 + 3 + up to 24 by performance). The reserves give a share, and events can give a development week.
- **Info:** A decision-first detail and concise results (Training work, earlier).
- **Consequence:** Slow and real. Players move toward an archetype and their POT. This is the one place a player can *shape* an individual over seasons.
- **Party:** Good potential. "I turned him into a wingman" is a real story. But archetype change has little *engine* consequence beyond attributes (1.6), so a reshaped player doesn't unlock anything new.
- **Story:** Development results are shown once (Nav pass 4), then forgotten. There's no arc ("he's added 9 since you drafted him").
- **Verdict: basically sound but underexploited.** Reserves are passive (M5-006 partial), and that's fine for now.

### 1.12 Morale, individual form, team form, momentum, events

- **Morale:**
  - Played: +2 to +4.
  - Left out: −3 (or −6 for 78+).
  - Its engine effect is ±0.03 on fitness (`ClubLife.form`), which is imperceptible.
  - It matters mainly through contracts and events.
- **Individual form:** Player Rating over the last three games against the season. It's shown on Coaching and has no engine effect.
- **Team form:** Five-result weighting giving ±1% at stoppages (`FORM_CONTEST 0.010`). Imperceptible.
- **In-match momentum:** A UI bar (`_track_momentum`) with no engine counterpart. The "they've kicked three in a row" moment is the only momentum mechanic.
- **Events:**
  - young gun, unhappy player, extension, media, fans, extra session, sore star, board pressure;
  - they are real trade-offs since the ClubLife redesign;
  - M1-011 (obvious right answers) is still open;
  - #91 made "give him a game" keep its promise on auto-pick.
- **Party:** Events are the only system that names a player *every week*. That's valuable.
- **Story:** Events are the closest the game gets to authored-feeling emergent story, but they are one-card-and-done, with no follow-through.
- **Realism/fun:** Morale and form are realistic and weightless. This is a place where "game first" argues for either real consequences (a player in form plays like it) or removal from the main surface.
- **Verdict:**
  - morale and form: **functional but passive**;
  - momentum: **display without mechanics**, which is misleading;
  - events: **basically sound, underexploited**.

### 1.13 Injuries, concussion, suspensions

- **Injuries:** Rolled **after** the match for the 18 who took the field (`Injuries.roll_match`). Durability matters. Concussion is a mandatory two-match absence.
- **In-match injuries:** none (M3-010 TODO).
- **Suspensions/MRO:** not implemented (M3-011 TODO).
- **Consequence:** Availability shocks between rounds. Real, and the loudest source of "our list changed" moments.
- **Story:** A lost opportunity. "Our ruck went down in the second quarter and we got smashed at stoppage" is the most natural AFL story there is, and the engine can't produce it. The injury appears on the hub after the game, as a line.
- **Verdict: functional but story-blind.**

### 1.14 Contracts, cap, list turnover, trades and free agency

- **Does:** Off-season Trades & Contracts: re-sign (years), release, sign free agents, trade with any club. Everything is priced against the cap. AI clubs decide immediately.
- **Info:** Cap room, contract years and value.
- **Consequence:** Real, long-term, and mostly about OVR per dollar.
- **Party:** List turnover is where you lose "your guys". Today it's a price calculation. There's no loyalty, legacy or "one-club player" sense.
- **Verdict: functional, not a priority.** It needs attachment (1.5, 1.17) before it needs depth.

### 1.15 Season, ladder, finals, awards, board, history

- **Ladder and finals:** Solid. The Grand Final is always at the MCG. Big-game players get a finals boost, which is tiny.
- **Awards:** Brownlow, Coleman, Rising Star, club best and fairest, All-Australian. Good hero machinery.
- **Achievements:** Club-specific history goals, which are lovely.
- **Board:** Goal and confidence in words; a final warning; sacking.
- **History:** Season review, player career totals. Records and leaders are partial (M7-005).
- **Missing:** rivalries, marquee games, milestones and captaincy (all M7 TODO).
- **Party:** Awards create heroes, but they are league-wide lists. Your club's best and fairest is the most "our guys" moment in the game and deserves more weight.
- **Verdict: basically sound, underexploited.** Long-save identity exists as data far more than as experience.

### 1.16 MatchSim: stoppages, ball movement, individual influence

What the engine does:
- 180 possession chains a match, each starting from a stoppage or restart.
- The stoppage winner comes from `contest_winner`: team `contest` (line means) ± home edge ± form ± plan, pep and synergy bonuses. It's clamped at 60%, with `contest_swing` 360.
- The chain moves through carriers picked by role-weighted attribute draws. Pressure, turnover and gain are multiplied by plan and synergy factors.
- Entries resolve against forward-line and defence-line means (`fwd_mark` against `def_intercept`). Shots resolve with shooter traits and defender lockdown.

What this means for the audit:
- **Individuals are credited, lines decide.** The model is statistically clean and produces believable box scores. It makes stars fungible and tactics abstract.
- **Where individuals are leveraged:**
  - the ruck (a line of one);
  - the shooter at a set shot (a moment card);
  - wings (via share multipliers);
  - taggers (a share of one man's ball);
  - Lockdown minders on midfield shooters.
- **There are no match-ups.** The code has two seeds of them: `_midfield_minder` pairs Lockdown midfielders with their best midfielders, and the "forward-50 defender draw" picks a defender on the shot. Neither is visible or controllable.
- **Uncertainty is healthy.** A 68-strength side beats a 66 about 70–80% of the time at home, and any side can lose.

**Verdict: realistic and statistically honest, but pointed away from party identity.** This is the single most important structural finding.

### 1.17 Match-day decisions: quarter breaks, tag, moments, pep, rotations, legs

**Quarter break (after #88):** What's happening, What your calls did, the plan and tag in view, and "More calls" for play through, pep talk, rotations, legs and synergies.

**Tag:**
- **Chain:** choose a player → `tag_id` → his share of the ball ×0.55 (×0.42 with a tagger on the ground) → less ball.
- **Feedback:** #88 reports "Tag on Walsh: 4 disposals, from 11".
- **What it doesn't do:** it doesn't cost you anything in attack (M4-003 TODO).
- **The consequence is shared out:** his team's line means are unchanged, so the ball simply goes to his teammates. The line "Tag on Luke Jackson: 4 disposals" beside a 45-point loss is the proof: the tag "worked" and did nothing that mattered.
- **On `main`, anyone can be tagged,** including a full-back or a ruck, and "your tagger" is the first tagger found. #93 fixes the position logic.
- **Verdict:** choice without meaningful leverage. Its effect is visible in one stat line, not in the match.

**Moments (at most 2 a quarter):**

| Moment | Options | Verdict |
|---|---|---|
| Set shot | Shoot, play on to a teammate, bomb it long | The best-designed decision in the game: a named player, a real situation, a visible outcome. Its detail line prints probabilities ("Pass sticks 70% … goal 45% overall"), which is the optimisation tooltip §0.2 warns against. |
| Tired star | Rest him or keep him on | Good: a named player and a real trade-off. |
| Hot opposition forward | Tag him or back your defenders | Right problem, wrong tool: you tag a forward. Becomes inert under #93 (§4.4). |
| They've kicked three in a row | Throw numbers at it, slow it down, ride it out | A burst of about 4–8 possession chains. Real, short, and hard to see. |
| Tight last-quarter centre bounce | Stack the stoppage, flood behind the ball, play it straight | Good drama and a clear decision. |

**Pep talk:**
- Fire them up: +1.8% at clearances and faster tiring.
- Calm the group: small reductions.
- The summaries print the percentages.
- **Verdict:** imperceptible, and numbers on the main surface.

**Rotations and legs:** A real energy model that drives fitness. It's buried behind More calls and rarely decisive. **Verdict:** mechanically interesting, rarely felt.

**Overall verdict: quarter breaks ask you to pick modifiers, not to think like a coach.** #88 made the thinking legible ("the problem, what your calls did, the response"). But the responses available are generic multipliers, not personnel moves:
- "Move Petracca to the centre square."
- "Put Moore on their key forward."
- "Swing your spare defender."

### 1.18 Match visualisation, commentary and log

- **Visualisation:** Numbered tokens on a flat oval with the ball in flight. It's credible most of the time. Far-receiver waits remain, because the engine names winners without positions. The Fremantle white-on-white numbers are fixed (#92).
- **Feed (`MatchNotes.FEED_KINDS`):** goal, behind, quarter, final and moment only, plus "three in a row" runs. No intercepts, contests, turnovers, marks, injuries or match-up battles.
- **Momentum bar:** a UI construct, not simulation.
- **Story while watching:** thin. You see dots and a scoreboard. Only goals tell you *who* is playing well. Everything that makes the post-match story ("their intercept defender kept killing us") is inferred later, if at all.
- **Verdict: functional but mute.** It is the least expensive place to add a great deal of emergent story, because the engine already records these events (M2 stats are all event-based).

### 1.19 Half-time, full-time, reports and stats

- **Half-time:** the assistant's report (Match read, best, needs a lift, danger, notes). Restrained.
- **Full time:**
  - Lost by X;
  - ladder move and next fixture;
  - How it went (two or three lines);
  - best players with Player Ratings;
  - needs a lift;
  - coaching notes;
  - Your calls (#88);
  - four key team stats;
  - a Stats tab with the full table and an expected-points "+2.1 pts" readout.
- **Accuracy:** The playtest showed it could mislead:
  - "Your midfield won the stoppages: clearances 39 to 33" in a 42-point loss, with nothing about where their scores came from;
  - rucks were best on ground because hit-outs were weighted 3 (#94 fixes it);
  - "Needs a lift" named busy players (#94 fixes it).
- **Story:** The report lists facts. It doesn't identify turning points. The engine has quarter snapshots, runs, score sources and moment outcomes, and never says "the game turned in the second quarter when …".
- **Verdict: basically sound, too factual, not narrative.** "Why we won or lost" (M4-009) is the right item; it needs a story shape, not more lines.

### 1.20 Not implemented (brief)

- rivalries, marquee games, milestones, captaincy, weather, grounds;
- MRO and suspensions; in-match injuries;
- structural coaching choices, role instructions, match-ups;
- late-game tempo; opponent scouting beyond the preview;
- visual oval selection; secondary-position retraining; selection cohesion.

Several of these (match-ups, in-match injuries, milestones) are not "expansion": they are the missing mechanisms for the philosophy.

---

## 2. Causal-chain traces

Each trace: player information → choice → engine input → simulation effect → visible consequence → player feedback.

**A. Game plan on `main`.**
1. Information: the plan summary and the counter triangle.
2. Choice: Defensive press.
3. Engine input: press ×1.18, their goal chance ×0.93, costs to your own goals and metres.
4. Simulation effect: about +10–20 points **if the opponent stays put**.
5. At the next break the AI reads your press and plays Controlled tempo, which neutralises the press multiplier (`_press_on`).
6. Result: 0 to −5 points against Balanced.
7. Feedback (#88): "Defensive press: they had 13 inside 50s and kicked 6 goals."

**Breaks:** the AI counter makes the choice meaningless; feedback can't show the counter's role; personnel is irrelevant. *(#93 repairs the AI and personnel links; the feedback link stays weak.)*

**B. Tag.**
1. Information: the "is hurting you" fact, or the hot-player card.
2. Choice: tag him.
3. Engine input: his share of the ball ×0.55 or ×0.42.
4. Simulation effect: fewer disposals for him; his line mean and team outcome are unchanged, and the ball is redistributed.
5. Visible consequence: his row in the stats.
6. Feedback: "Tag on X: 4 disposals, from 11."

**Breaks:** the effect is real for him but not for the result. The player sees "it worked" and "we still lost by 45", which teaches that nothing matters.

**C. Selection (swap a 65 centre midfielder for a 90).**
1. Information: OVR, identity, head-to-head words.
2. Choice: the swap.
3. Engine input: the centre `mid_contest` mean rises about 8.
4. Simulation effect: about +1 point of stoppage win probability.
5. Visible consequence: none in the match; he gets more of the ball.
6. Feedback: his stat line, and the head-to-head words may move one step.

**Breaks:** the effect is too diluted to perceive. *(Swapping the ruck is the exception: about +3.7 points a stoppage, visible over a match as a clearance edge.)*

**D. Synergy (switch on Tall-small).**
1. Information: the synergy guide and its carriers (excellent since #89).
2. Choice: select the crumber.
3. Engine input: goal chance ×1.05 on entries.
4. Simulation effect: about +1 goal every two or three matches.
5. Visible consequence: none identifiable.
6. Feedback: "Your side has: Tall-small forward line (more goals from forward-50 entries)."

**Breaks:** the effect is imperceptible and never attributed.

**E. Set-shot moment.**
1. Information: the named shooter, spot and options (with percentages).
2. Choice: play on to X.
3. Engine input: an explicit resolution.
4. Simulation effect: goal or no goal, **now**.
5. Visible consequence: on the oval and in the feed.
6. Feedback: moment line and outcome.

**Intact.** The problem is the opposite one: the percentages make it a calculation, not a judgement.

---

## 3. The twenty questions

**1. What game are we actually playing?**
- A league draft that decides your season.
- A weekly button to play or sim.
- A match you watch as dots, with occasional cards.
- A tidy report of facts.

You are a list manager whose coaching inputs are cosmetic, and on `main` the AI actively cancels them. It feels like assembling a fantasy side and then spectating.

**2. Closest to the "simulation + party CRPG" vision?**
- The league draft (party assembly from scratch).
- The synergy guide (complementary pieces, stated honestly).
- Named-player moment cards (set shot, tired star).
- Player identity labels and career history.
- Awards, the retired-player-to-coach pathway, events that name players.

**3. Most serious contradiction?** The engine resolves football by line averages, so the party's composition barely matters beyond its means, and match-day choices are generic multipliers that the AI cancels.

**4. Genuine agency:**
- the draft;
- ruck selection;
- the set-shot and tired-star moments;
- the last-quarter bounce call;
- event choices;
- long-term training direction;
- contracts and trades (economically).

**5. The illusion of agency:**
- game plans on `main`;
- the tag (it "works" and doesn't matter);
- pep talks;
- a manual selection that mirrors auto-pick;
- synergies (real, too weak to feel);
- morale and form (weightless);
- the momentum bar (display only);
- the hot-forward tag card, which is a tag on a forward and inert under #93;
- the "they've kicked three in a row" burst (too short to see).

**6. Simulating what should be gamified:**
- traits and synergies (make them stronger, situational and visible);
- match-ups (make them explicit and decisive);
- form (let a hot player actually play hot);
- momentum (either model it or remove the bar);
- in-match injuries (a turning point, not a post-match line).

**7. Where more gamification would hurt:**
- scoring rates and possession counts;
- the event-based stats;
- AI parity;
- the clamp that keeps any side beatable;
- the league draft's economics;
- set-shot outcomes (keep them uncertain);
- percentages in UI;
- making plan swings so large that one plan per list is always right.

**8. Are footballers distinct enough?** In description, yes: identity, strengths, traits. In the engine, not much. Two same-line players of similar OVR are near-interchangeable in outcome terms. The ruck is the exception, which proves the rule.

**9. Party or highest-rated legal players?** Mostly the latter. Auto-pick is usually right, and the game has no mechanism that rewards picking a lower-rated player for a specific job against a specific opponent.

**10. Can unusual archetypes change how I play?** Barely. A Tall-small forward line, a pressure-heavy list or a running machine produces a 2–8% nudge. #93 is the first link from archetype to a real plan choice.

**11. Does an opponent feel like a new encounter?** The preview (since #90) describes one. The *response space* is too thin and generic for it to feel like solving a problem. There are no recurring opponents with memory, and no rivalries.

**12. Does the match become a story while I watch?** No. Only goals, runs and cards surface. The story, if any, is assembled from the full-time report.

**13. Quarter breaks: coach or modifier-picker?** A modifier-picker, now with good information around the modifiers. No personnel moves.

**14. When an adjustment works, can I see why?** Only in one stat line (#88). Not on the oval or in the feed, and not attributed to the players who made it work.

**15. Telling bad decision, wrong personnel, opposition response, execution and variance apart?** Not today:
- the AI's counter is invisible (on `main`);
- personnel fit isn't reported (on `main`; #93 names carriers beforehand, not after);
- execution (coaching) is invisible;
- variance is never framed.

The honest answer is "you can't", which is why it feels like dice.

**16. Heroes, villains, cult figures, disappointments?**
- Heroes: yes, via awards, Player Ratings and goals in the feed.
- Villains: sort of ("X is the danger", "hurting you"), but not across seasons.
- Cult figures and disappointments: no. There's no memory of a player's big moments, no nicknames, no "he always kicks five against us".

**17. Reasons to be attached to my list?** The draft gives authorship. Development gives investment. Nothing makes a *specific* player irreplaceable except the ruck, and nothing remembers what they did for you.

**18. Untapped potential (refine, don't replace):**
- the synergy and trait system;
- PlanFit (#93);
- `_midfield_minder` and the forward-50 defender draw (proto match-ups);
- the energy and rotation model;
- moment cards;
- #88's "what your calls did";
- event-based M2 stats (for a story feed);
- `form_log` (for player histories);
- the coach pathway;
- club best and fairest;
- the head-to-head words (for the draft).

**19. Fundamentally wrong direction:**
- The on-`main` AI counter-picking. Replace it: #93 does.
- Percentages in decision UI (set shot, pep talk). Remove them.
- The momentum bar as a display of something the engine doesn't model. Model it or remove it.
- Otherwise the direction is right. What's wrong is the leverage and the surfacing.

**20. Five interventions:** see §5.

---

## 4. Problems and recommended directions

### 4.1 Individuals don't decide contests (the root problem)
- **Experience:** Stars don't feel like stars. Swapping players changes nothing you can feel. Tags "work" and don't matter.
- **Cause:** Line averages decide stoppages, entries and scoring (`Squad._aggregate`, `contest_winner`, entry resolution).
- **Direction: key contests between named players.** Have the engine resolve some of its moments as **one player against one player**, using existing hooks:
  - the ruck against the ruck (already, effectively);
  - the centre-square lead midfielder against his direct opponent at centre bounces;
  - the key forward against the key defender on marking contests inside 50 (the forward-50 draw);
  - a Lockdown or tagger against his assigned man.

  Keep line averages for the rest of the flow. Line averages still set the base, and uncertainty stays.
- **Why:**
  - Selection becomes "who covers their star?";
  - tags and match-ups matter because they change *who wins the contest*, not who gets credited;
  - stories write themselves ("Moore beat Curnow in the air all day").
- **Realism kept:** Scoring rates, possession counts and the clamp.
- **Sacrificed:** Some statistical smoothness. A single match-up can swing a game more than it would in the AFL, and that's worth it.
- **Risks:**
  - a single dominant piece (the ruck already shows this; cap it);
  - balance of long saves;
  - one "right" match-up each week.

  Mitigate with clamps, fatigue, and match-ups that trade off (the defender who beats the tall can't also run off half-back).

### 4.2 Match-day choices are multipliers, not coaching
- **Experience:** "Clicking and hoping."
- **Cause:** Every call is a generic factor. On `main`, the AI cancels plans.
- **Direction:**
  - Keep a *small* number of calls, and make most of them **personnel moves**:
    - put player X on their danger player;
    - move X into the centre square;
    - swing a spare defender back or forward;
    - rest or hold a player.
  - Keep plans (with #93's list fit) as the team's style.
  - Remove pep talks, or fold them into the "three in a row" moment.
  - Every call should name a player and a problem.
- **Why:** You reason about *your* players against *their* players, and the answer depends on who you have.
- **Realism kept:** No direct control of play; uncertainty.
- **Sacrificed:** A dozen minor levers.
- **Risks:** The UI grows. Keep it to at most three calls a break, with detail behind a tap.

### 4.3 The match doesn't tell its story
- **Experience:** Dots and a scoreboard, then a fact sheet.
- **Cause:** `FEED_KINDS` is scoring only. Injuries are post-match. Turning points go uncomputed.
- **Direction:**
  - A feed of *consequential* events drawn from what the engine already logs:
    - an intercept mark that becomes a goal;
    - a contest won by a named match-up;
    - a player's third clearance in a quarter;
    - a set-shot miss that mattered;
    - a star going down.
  - Rate-limit it so it doesn't become noise.
  - At full time, a **three-sentence story** built from real turning points: the biggest scoring swing, the quarter that decided it, and the players who defined it, with their match-up.
  - Move injuries into the match timeline.
- **Why:** This is the direct route to emergent storytelling, and it needs no new football.
- **Kept:** Everything is from real events. Nothing is scripted.
- **Risks:** Narrative vomit, and templated repetition. Use strict rate limits and plain language, and let quiet games be quiet.

### 4.4 Tags and match-ups (and the #93 gap)
- **Experience:** Tag a full-back, or tag a hot forward, and nothing meaningful happens.
- **Cause:** There's no match-up concept.
- **Direction:**
  - A tag is a midfield job: #93, done.
  - A forward kicking a bag is answered by **moving a defender onto him**, a match-up, not a tag. The hot-forward moment should offer "Put Moore on him" or "Back your structure".
  - Tagging should cost something in attack (M4-003).
- **Immediate issue:** #93 currently makes the hot-forward card's tag inert. **Don't merge #93** until that card either offers a defender match-up or only fires for midfielders.

### 4.5 Traits and synergies: fewer, stronger, visible
- **Direction:**
  - Keep the synergy guide. It works.
  - Make traits *situational* and *surfaced*: the crumber's goal is labelled a crumbing goal; the Big-game player lifts in finals *visibly*; the Lockdown's man is named.
  - Raise the effects to perceptible (for example, a synergy is worth about a goal a match) and cap stacking.
  - Tie synergies into PlanFit, so a Supply line makes Controlled tempo stronger.
- **Risks:** One dominant build. Mitigate with synergies that trade off (a Tall-small forward line is weaker at stoppages).

### 4.6 The draft decides everything with poor information
- **Direction:**
  - While drafting, show your forming side against the league in the head-to-head words ("Ruck: among the weakest").
  - Keep the need counts.
  - Maybe show a projected ladder band.
  - No "draft this player" hints.
- **Why:** The biggest decision in the game becomes informed. The director's first season would not have begun with an unfixable ruck hole.
- **Risk:** It becomes solvable. Show the facts only, not the answer.

### 4.7 Form, morale and momentum: make them real or keep them off the main surface
- **Direction:**
  - Let genuine hot or cold form move a player's contest strength noticeably, for a few weeks.
  - Keep morale mostly for contracts and events.
  - Model momentum lightly: a run of goals nudges the next stoppages for a few minutes. Otherwise remove the bar.
- **Risk:** Snowballing. Cap it and let it decay.

### 4.8 Attachment: remember what players did for you
- **Direction:**
  - The profile gains "With us": games, goals, best games (from Player Ratings), finals and awards.
  - Milestones (M7-003) at 50, 100, 150 and 200 games.
  - The club best and fairest gets a moment.
  - All from data that already exists.
- **Why:** "Our guys".
- **Risk:** Almost none. It's cheap.

### 4.9 Remove numbers from decisions
- Set-shot probabilities, pep-talk percentages and "+2.1 pts" belong in drill-downs or nowhere.
- Replace them with football words: "a long set shot from a tight angle", "he's been kicking straight".

---

## 5. Priorities

### Foundational (the core game isn't fun until these land)
1. **Individuals decide key contests (§4.1).** Named match-ups at the ruck, the centre bounce and the forward-50 contests; tags and minders resolve through them. It's measurable and balance-gated. This is the root cause of powerlessness.
2. **Personnel-based match-day calls (§4.2 and §4.4).** Replace generic levers with "put X on Y" and "move X into the centre". Fix the hot-forward card. Finish #93 (the AI plays its style; plans follow the list), then playtest the plan swing size.
3. **A story feed and a turning-point summary (§4.3),** from events the engine already records, including in-match injuries.

### High value once the foundation works
4. Traits and synergies made situational, surfaced and perceptible, tied to PlanFit (§4.5).
5. Draft information: your forming side against the league, in words (§4.6).
6. "With us" player history, milestones and the club best and fairest (§4.8).
7. Form and momentum made real or removed (§4.7).
8. Numbers out of decisions (§4.9).

### Good ideas that should wait
- Tactical vignettes (M8-007): only after decisions are meaningful, as the roadmap already says.
- Weather, grounds, marquee games.
- Captaincy.
- A deeper trades and free-agency model.
- Reserves depth, visual oval selection, structural and role instructions beyond match-ups.
- More stats (M2 is enough).
- The Android identity item (M8-008) is harmless and independent, but it isn't gate work.

### Good enough: leave alone
- The league draft's economics and AI parity.
- The event-based statistics.
- The ladder and finals.
- The awards machinery.
- The coach market and pathway.
- The visual style and writing standard.
- The head-to-head preview and the synergy guide (#89–#90).
- Contracts at their current depth.

---

## 6. Closing

### 1. Current game
A satisfying league draft, then a season where the list you drafted plays itself. You watch dots, read tidy facts, and pick from options that are real in code but too small, too generic, or (on `main`) actively cancelled by the AI to feel. Losses arrive without a lever to pull or a story to remember. It is honest and restrained, but it isn't yet a game about *your players*.

### 2. Biggest philosophy gaps
- The engine is line-averaged, so individuals are credited, not decisive, and the party barely matters beyond its means.
- Match-day agency is illusory: generic multipliers, AI counters (on `main`), tags without team consequence, inert or imperceptible calls.
- The match doesn't narrate itself: scoring-only feed, off-screen injuries, cosmetic momentum, no turning points.
- Attachment isn't remembered: no "with us" history, milestones or moments.
- The decisive draft has no information about what makes a side win.

### 3. Strongest existing foundations
- The league draft as party creation.
- Event-based statistics that can power a story feed.
- The synergy guide and carrier model, player identity labels, and PlanFit (#93).
- Named-player moment cards (the set shot especially).
- #88's "what your calls did" loop.
- Career history, awards, club achievements, the coach pathway.
- A restrained editorial UI and natural AFL language.

### 4. Five highest-leverage design interventions
1. **Named match-ups decide key contests** (ruck, centre bounce, forward-50 marking), with tags and minders running through them. Individuals start to matter.
2. **Personnel-based coaching calls** ("put X on Y", "move X to the centre"), with plans expressing the list (#93) and no hidden counters. Agency becomes reasoning about people.
3. **A story feed and a three-sentence turning-point summary** from real events, with injuries inside the match. You can recount the match.
4. **Traits and synergies made situational, perceptible and attributed,** and linked to plans. Archetypes change how you play.
5. **Remember "our guys"** (a "with us" history, milestones, the club best and fairest), and inform the draft with your forming side against the league. Attachment, and a fair start.

### 5. What not to build yet
Vignettes, weather and grounds, marquee games, captaincy, deeper trades and free agency, more stat categories, more calls or traits of the current weak kind, visual oval selection, and any new UI panel that adds numbers.

### 6. Recommended next design and playtest gate
**Gate 1.12, "Can I feel my decisions?"**

Before anything else:
- Hold #93 until the hot-forward card is sorted, then merge #93 to #95.
- Design and prototype **one** named match-up: key forward against key defender on forward-50 marking contests. Make it controllable at selection and at the break ("put X on Y"), attribute it in the feed and at full time, and measure its leverage (seeded, balance-gated).

The phone playtest passes when, over three matches:
- the player can name at least one decision that changed a contest they could see;
- the player can tell each match's story in three sentences, including a player battle;
- a loss can be explained as personnel, opposition, decision or luck, not "nothing I did mattered".

If a single match-up can't pass that test, no amount of new features will.
