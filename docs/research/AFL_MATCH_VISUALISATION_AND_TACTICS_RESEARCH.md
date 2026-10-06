# Making the ARD match view show recognisable, truthful football

Research for Claude • 6 October 2026 • Source checkout inspected at `d2ec68f`

## Recommendation

Make the match view explain **where the next advantage comes from, who creates it, and what the team sacrifices to create it**. A corridor attack should expose support runners and the space left behind them. A flood should visibly put bodies behind the ball and remove forward outlets. A tag should follow the nominated opponent. Those differences matter more than making every token run faster or adding more animation.

ARD already has a substantial football simulation, coaching controls, player identities, event logs and a match director. Its principal gap is the connection between those systems: the simulation often changes probabilities while the director independently reconstructs sideways ball movement and off-ball shape. The same generic arrangement can therefore accompany materially different coaching decisions.

Recommended direction: retain the authoritative simulation and add a modest **recorded tactical context and movement-intent layer**. Use it to guide presentation. Do not immediately replace the game with a fully spatial 36-player physics simulation. If geometry is eventually to decide possession and scoring, that is a separate simulation project with substantial balance consequences.

This document contains research and proposed implementation approaches. It changes no roadmap, game code or balance settings. The existing **ARD-M8-003 — Match visualisation authenticity pass**, including its 6 October expansion, already owns much of this work.

## 1. What the current code can and cannot establish

These are source findings, not a report of running the latest build. The checkout is shared with active development; Claude should recheck the relevant functions before implementing.

| Area inspected | Present behaviour | Consequence |
|---|---|---|
| `scripts/sim/MatchSim.gd`, `_emit` | Records event kind, player identity, side, quarter/time, longitudinal field position, score and some contest-specific metadata. | There is a trustworthy event sequence to preserve. Most events do not describe a complete 2D tactical situation. |
| `scripts/ui/match/MatchDirector.gd`, `_loc`, around line 777 | Reconstructs lateral position using actor location, event type, later participants and presentation randomness. A wide source sometimes generates a visual switch through a random branch. | A visible switch is not necessarily a deliberate switch chosen by the football simulation. Corridor versus boundary use is not fully established by the log. |
| Director `_structure_spot`, around line 1416 | Uses generic role anchors, possession-dependent width, ball attraction and slot-based opponent relationships. | Some credible movement exists already, but a plan-specific shape is not consistently connected to the current coaching call. |
| Director `_is_loose`, around line 1457 | Selects a loose half-back according to slot/ball relationships. | The visible spare is not reliably the named roaming interceptor selected in MatchSim. |
| Director opponent pairs | Uses positional slot relationships. | These cannot be assumed to represent a nominated tag or the coach's actual forward/defender matchup. |
| Director handball handling, around lines 456, 760 and 987 | Distance thresholds can select kick presentation for a handball. | A motion/layout problem can change the apparent disposal type. Preserve the recorded disposal and fix its staging instead. |
| `MatchSim._resolve_shot`, around line 3631 | The play-on option credits a pass and changes the shooter when successful, but does not emit separate successful pass/receive events; the final shot retains the original field position. The bomb option uses an aggregate scoring outcome rather than logging a new pack winner. | The visible sequence needs the selected branch and already-resolved action details. Do not invent an extra forward mark or goal attribution to make a bomb look realistic. |
| Director collection and `roll_to`, around lines 1246 and 1383 | A loose ball can move toward the receiver's changing position. | This directly warrants investigation of the existing receiver-seeking-ball roadmap concern. Plan a believable trajectory, rather than correcting ownership by steering the ball. |
| `MatchSim.bounce_attendees()` | Exposes the actual ruck and inside midfielders deterministically. | Reuse these identities in the live view. Do not select a separate visually convenient centre group. Snapshot them for replay rather than querying a later squad. |
| `scripts/ui/match/MatchMotion.gd` | Already provides acceleration, braking, arrival, separation and reaction delay. | Improve role goals and priorities first. Replacing the locomotion layer with a new flocking framework would duplicate existing capabilities. |
| `scripts/ui/match/MatchRings.gd` | Coaching actors can be highlighted. | Identification is useful, but rings alone do not demonstrate that the actors execute their jobs. |
| Director `focus()` / `zoom_hint()` and `scripts/ui/PitchView.gd` | Follows the ball, leads toward the flight destination and uses event-mode zoom hints; whole-oval viewing exists. | Camera framing has no equivalent semantic awareness of a switch outlet, defensive spare or transition vulnerability. |
| `tools/visual/capture_match.gd` | Existing reproducible frame/contact-sheet/trail capture harness. | Extend this for tactical fixtures; do not build another capture tool unless necessary. |

The current match documentation explicitly separates presentation randomness from football outcomes. Preserve this contract. Animation must not reroll a contest, create an extra possession, change the score, or silently substitute a more convenient actor.

## 2. What other games offer

These are developer descriptions and release notes, not independent measurements of their quality. Soccer, basketball and American football offer useful mechanisms; their formations and rules should not be transplanted into AFL.

| Reference | Concrete lesson | Application to ARD |
|---|---|---|
| **Football Manager 2024** | Positional rotations require teammates to compensate for vacated roles; its developers also describe motion matching and improved foot placement. [S1] | If a half-back advances, allocate replacement coverage. Begin with role compensation; a richer animation system cannot repair missing football jobs. |
| **Football Manager 2026** | Separates in-possession and out-of-possession behaviour and offers a visualiser for positions across phases. [S2] | Describe each ARD plan in several phases. A preview could show attack, defence and transition without making the user maintain several formations. |
| **FC 25 FC IQ** | Distinguishes starting formation from role-dependent movement and returning to defensive positions. [S3] | “Half-back” is a starting identity, not a permanent coordinate. Support, recover and cover are different jobs. |
| **FC 26** | Developer notes address attacking support and runs into space, including situations where restrictive role behaviour previously limited movement. [S4] | Avoid making off-ball players wait indefinitely for their nominal role. Give them a useful fallback job when their preferred action is unavailable. |
| **Madden NFL 26** | Coverage updates explicitly discuss zone handovers, leverage and defenders' awareness of the ball. [S5] | Zone defence needs responsibility transfer and sensible body orientation. Do not make every defender track every receiver or anticipate every kick perfectly. |
| **NBA 2K22** | Its developers describe rebuilding defensive rotations. [S6] | The important transferable idea is collective response: one defender helping should trigger another covering. The announcement does not disclose a complete algorithm. |
| **AFL 26 official patch notes** | Updates address tactical settings applying correctly, tactics-board representation and interchange behaviour. [S7] | Test the entire chain from menu choice to simulation state to visible arrangement. A correct-looking tactical menu is insufficient. |
| **FC 25 Rush presentation** | Describes alternative cameras and optional tactical visual assistance. [S8] | Offer an optional coaching view that exposes outlets and coverage. Keep ordinary viewing readable without permanent arrows everywhere. |

Craig Reynolds' steering framework distinguishes choosing an action, steering toward its goal and locomotion. ARD's motion code already handles much of the bottom layer. The missing football-specific work belongs primarily in choosing meaningful goals and resolving conflicting responsibilities. [S9]

**Avoid:** expensive motion-capture dependencies, reinforcement learning, elaborate pathfinding on an open oval, perfect future knowledge, and hundreds of handcrafted NFL-style routes. None is necessary for the first useful improvement.

## 3. Football concepts the view should distinguish

### Phase, position and plan are separate

Use these presentation contexts: settled possession; attacking transition; settled opposition possession; defensive transition; disputed ball; centre restart; other stoppage; kick-in; mark/free-kick restart. Add location modifiers such as defensive 50, midfield, forward 50 and boundary side.

“Neutral” describes a disputed football, not the Balanced coaching plan. A team running an attacking plan still needs a defensive transition after losing the ball. A flood call should not produce the same coordinates during a centre restart as during an opposition forward entry.

Changing phase should change jobs with a short, understandable reaction delay. Retain commitments long enough to avoid constant target flipping. A player cannot instantly abandon a contest, reverse direction, and appear at a new defensive anchor.

### Man defence, zone defence, press and flood

| Behaviour | What viewers should see | What it costs |
|---|---|---|
| Man accountability | A defender keeps a particular opponent on the dangerous side, adjusts as that opponent leads, and pursues after release. | Decoy movement can take the defender away from useful space. |
| Zone coverage | Defenders occupy threatening lanes/depth, adjust to the ball, then hand a runner between responsibilities. | Slow communication or a well-timed switch exposes a seam. |
| Forward press | Pressure near the ball plus players guarding the next exits; a rear layer anticipates the forced long kick. | A successful escape leaves space behind the press. |
| Flood | Extra bodies protect the scoring area and interceptable entry lanes. | Fewer forward targets and poorer attacking exits. |
| Hybrid | Accountability tightens near a dangerous forward or imminent contest while other players guard space. | Requires clear priorities when man and space obligations conflict. |

Historical AFL analysis of West Coast's web illustrates guarding space while the immediate defender pressures the ball. It is a useful example, not a universal radius to hardcode. Coaching discussion of making an interceptor accountable also shows why a spare defender cannot be free of opportunity cost. [S10][S11]

Proposed implementation: give a defender one primary job, one secondary cover obligation and a limited awareness state. Use explicit handover conditions: receiver crossing a responsibility boundary, closer teammate available, or ball movement invalidating the old coverage. Add hysteresis so two defenders do not repeatedly swap the same opponent every frame.

### Wings are especially important

A 2024 AFL feature drawing on player and assistant-coach explanations distinguishes the wing closer to the contest from the far-side wing. One can support the contest and recovery; the other maintains width and supplies an outlet. Individual wing profiles also vary. [S12]

For ARD, determine near/far side from the current ball position and direction of attack. Do not send both wings into congestion. Show the far-side player remaining available, then reacting when the switch begins. This makes the user's switch vignette and corridor-versus-boundary decisions intelligible.

### Legal setup matters

For a 2026 start, centre restarts should use a ball-up. The AFL's 2026 changes retain 6-6-6 while removing the requirement for a player in each goal square. Ruck restrictions and restart timing also need the contemporary rules rather than historical video conventions. [S13][S14]

The current Laws define shepherding around proximity to the football; they also prohibit holding/blocking in relevant contests and specify the protected area after a mark/free kick. Consequently, a generic off-ball “screen” cannot be treated as automatically legal, especially at a restart. [S15]

**Stack the stoppage must not put extra players illegally inside the centre square before the restart.** Represent additional numbers arriving after release, appropriate positioning outside the square, and the resulting loss of coverage elsewhere. A risky hip-and-shoulder outcome must come from the authoritative decision resolution, including a free/report where applicable, rather than animation independently deciding contact legality.

## 4. Explicit mapping of existing gameplan levers

The numerical effects below are **base implementation modifiers**, not promised final percentage changes in results. Plan fit, execution, opponent choices, selection and other modifiers alter their effective impact. Visual speed should not simply equal a fatigue/pace multiplier.

### The six match plans

| Existing plan | What MatchSim currently changes | Proposed observable behaviour | Visible drawback and required connection |
|---|---|---|---|
| **Balanced** | Baseline plan modifiers. | Normal support behind and beside the carrier; at least one useful outlet; credible forward targets and defensive insurance. | This is the reference shape, not “no movement.” Record phase and possession so the baseline responds correctly to turnovers. |
| **Attack corridor** | Base gain ×1.06, goal ×1.05, clangers ×1.12, pace ×1.12, exposure ×1.07. | More central advancement attempts, runners moving through or beside the carrier, diagonal inward leads and quicker support after release. | Turnovers reveal more open central counterattack space. The current log needs chosen lane/intent; randomly drawing central kicks cannot establish that the plan caused them. |
| **Defensive press** | Pressure ×1.09; opponent goal ×0.965; own goal ×0.96; gain ×0.95; pace ×1.12. | Near-ball pressure, second defenders guarding short exits, forwards closing likely escape lanes and a covering layer behind. | Less attacking freedom and vulnerability when the press is bypassed. Do not render it as a deep flood. Pressure actors and cover jobs need explicit assignment. |
| **Win contest** | Contest advantage +0.025; gain ×0.95; exposure ×1.04. | Stronger nearby support around the contested ball: extraction receiver, cover player and someone at the spill. | Less spread and a vulnerable outside outlet. It does not license every player to chase the same football. Distinguish contested-phase roles from settled possession. |
| **Controlled tempo** | Taken ×0.96; gain ×0.94; goal ×1.01; clangers ×0.93; pace ×0.95. | Shorter support spacing, safe backward/lateral options, more credible mark-and-reset moments, then acceleration when a lane opens. | Less territory per action; pressure can close the safe options. Avoid slow-motion playback as the only difference. Record disposal intent and a genuine reset versus play-on. |
| **Through stars** | Star ball weighting ×1.30; star goal ×1.18; clangers ×0.92; taken ×1.04. | Chosen stars become identifiable outlets and targets; teammates make supporting runs that create their opportunity. | Opponents can concentrate attention on them; alternative options receive less use. Use actual selected identities/events, not a star teleporting beside every possession. |

Current `PlanFit.gd` implementation includes a Controlled tempo fit based on disposal and discipline despite an older header comment suggesting otherwise. Follow the implementation. More generally, plan fit and tactics execution affect benefit strength; rendering a nominal plan at maximum effectiveness regardless of execution would misrepresent it.

**Important distinction:** these proposed shapes can initially explain the existing abstract effects. If lane selection or coverage is to alter the outcome calculation, MatchSim must own that additional logic. Do not add a second corridor bonus merely because the director now depicts a corridor run.

### Live calls and assignments

| Lever already available | Present simulation meaning | What must visibly change |
|---|---|---|
| **Run it through him / focus player** | Increases the chosen player's possession selection weight, with usage management. | The actual player shows as an outlet or receives a lead opportunity before the logged involvement. Not every disposal goes through him. Show defensive attention and bypass options. |
| **Tag their player** | Selects a tagger and suppresses the target's contribution, with costs to the tagging player's own involvement. | That named tagger stays accountable to that named opponent, including between possessions. After substitution, use the real updated assignment. Do not confuse a generic midfield opponent with the target. |
| **Forward/defender matchup** | Named duel assignments affect relevant contests. | Use those identities for accountability and marking contests; positional-slot pairing is only a fallback when no explicit assignment exists. |
| **Roaming interceptor** | A named defender receives roaming opportunities, with matchup redistribution. Some contest events already identify the roaming interceptor. | Show that defender leaving a direct matchup, protecting the dangerous lane and attacking the logged intercept/spoil. Another defender assumes accountability rather than the opponent becoming invisible. |
| **Make their spare accountable / ignore** | Changes the trade-off surrounding the opposition spare. | Accountability should occupy the spare through a threatening lead/position, not make him stand still artificially. If the simulation lacks the assigned attacker's identity, record it before claiming a specific visible duel. Ignoring preserves attacking freedom but leaves the spare dangerous. |
| **Stack the stoppage** | A temporary contest advantage; increased opponent scoring risk; lasts 12 chains in the inspected implementation. | More support arriving around the stoppage after a legal setup; clearly fewer players covering the escape. Do not translate the UI description into an independent real-time expiry. |
| **Flood the backline** | Own gain ×0.85, own goal ×0.90, opponent goal ×0.80; different workload factors; lasts 45 chains or ends at the break. | More midfield/support bodies behind the ball, compact dangerous-space coverage and noticeably fewer forward outlets. Current numerical/GPS effects do not themselves establish these positions. |
| **Surge** | Temporary contest/scoring uplift and a larger opponent scoring uplift; lasts 15 chains. | More committed forward support, earlier attacking leads, reduced rear insurance. Its failed version should show an exposed counterattack, not merely an unlucky shot. |
| **Hold** | Reduced pressure, gain and scoring opportunity on both sides, plus reduced workload; lasts 15 chains. | Conservative outlets and retained coverage; fewer speculative attacking commitments. This should differ from both deep flooding and the ordinary Controlled tempo plan. |
| **Fire up / calm / steady** | Quarter pep effects alter contest/error/workload/gain factors; Fire up's contest benefit is conditional on being behind. | Primarily differences in involvement, decision urgency and mistakes over a sequence. Avoid cartoon speed changes or presenting a conditional benefit as permanent. Steady need not produce a cosmetic change. |
| **Rotation policy / rest or keep a tired star** | Determines fatigue exposure and actual substitutions/retention. | Show the correct on-field identities and continuity of assignments. Fatigue-related presentation requires a recorded fatigue state or profile; current token movement speed is not a full live-fatigue model. Audit movement-profile refresh after interchange. |

The exact current burst labels are **Stack the stoppage**, **Flood behind the ball**, **Throw numbers at it** (surge), and **Slow it down** (hold). “Play it straight” and “Ride it out” preserve the current situation; they should not silently apply the Balanced plan or reset assignments.

Burst duration currently counts simulation chains, while descriptions can refer to passages or minutes. Record the actual activation and expiry interval. Replays must not apply the final surviving call to the entire match; skipping and speeding up must not extend a call.

### Existing set-shot decisions are also gameplay levers

| Choice | Current resolution | Required visual distinction |
|---|---|---|
| **Take the shot** | Uses the offered shot's scoring chances and the original shooter. | A legal mark/restart, preparation and direct shot from the offered location. Its failed branch must show the authoritative behind/rebound outcome. |
| **Play on to a named teammate** | Resolves pass success, then the teammate's scoring chance. In the inspected code, successful pass/receipt is not a separate event and the final shot retains the original `fp`. | Original player releases; named teammate receives in an explicitly staged or simulated receiving location, then shoots. A failed pass goes to the recorded opposition outcome. Record these already-resolved actions without counting their disposals twice. Do not portray a closer shot while pretending the log contains its new spatial position. |
| **Bomb it to the goal square** | Uses aggregate goal/behind/rebound probabilities; it does not select a new pack winner in this branch. | A recognisably longer kick to a goal-square contest region, consistent with the credited final actor/outcome. A forward marking and kicking a second goal is not supported by this shortcut. If that is the desired behaviour, expand authoritative resolution first. |

This is a particularly useful early audit: three different decisions can produce final score events marked `set`, which alone cannot explain the intervening football. The resolved moment records the choice, but replay needs those details associated with the action timeline. The live call to change a hot forward's opponent and the call to tag a hot midfielder should similarly update the named assignments already covered above, rather than create a second visual-only mechanic.

### Selection, traits and synergies

Some inputs affect who wins or is selected rather than adding a distinct tactical control. Keep that distinction clear.

- **Wings and lineup roles:** the current director already distinguishes wings from inside midfielders. Preserve this, then give near/far wings phase-specific jobs.
- **Ruck king / contested rucks:** show the actual ruck participant and appropriate post-contest involvement. A ruck winning the tap is not necessarily the player or team winning the clearance. Aggregate hit-out statistics must not be invented as extra visible contests.
- **Bull, ball magnet and crumber effects:** make the logged participant recognisable in the relevant situation. A crumber waiting at a pack's spill is useful staging; inventing a second gather to showcase the trait changes the match.
- **Lockdown:** current midfield minder selection can identify a trait-based opponent independently of the user's nominated tag. Preserve that distinction and expose the actual minder when relevant; do not label every defensive midfield pairing as a coach-selected tag.
- **Tall/small combinations, supply and intercept synergies:** present complementary jobs—lead, contest, spill support, intercept coverage—where the actual sequence supports them. Do not assume every numerical synergy already has a spatial simulation underneath it.
- **Plan fit and coaching execution:** weaker execution can eventually appear as later support or imperfect spacing, but only through bounded, recorded parameters. Do not secretly change football outcomes with presentation noise.

## 5. Concrete AFL play and setup library

The following **14 recipes are proposed ARD staging/behaviour designs**, informed by the cited football sources. Coordinates, timing and role thresholds need local prototyping; they are not measured tracking data or universal AFL formations. Each should work automatically during ordinary play. Use existing decision gates where appropriate, rather than making the user approve every possession.

The accompanying `[AFL tactical shape examples](AFL_TACTICAL_SHAPE_EXAMPLES.png)` illustrates six contrasts: attacking/defensive centre support, a switch outlet, forward press, deep flood and accountability for a named spare. These are local extracts, not complete team formations.

### 1. Balanced centre extraction

**Jobs:** actual ruck, ball-winning midfielder, release receiver and defensive cover midfielder. Place wings outside the square and retain the broader legal restart structure. On release, the winner attacks the fall; the receiver holds a separate exit rather than colliding with him; cover protects the opposition's first clean break. Display the actual tap winner separately from the clearance winner where the log supports both. Failure can be a tackled gather, opposition extraction or secondary ball-up. Madden/Flanigan coaching describes distinct ruck-support jobs; modern analysis demonstrates that centre arrangements differ. [S16][S17]

### 2. Aggressive centre exit

**Jobs:** attacking receiver ahead/diagonal, inside winner, supporting midfielder and arriving wing. Once the ball is live, the receiver advances into the chosen exit and the wing joins the next possession. Leave visibly less cover behind the contest. A lost clearance should expose that space; do not instantly restore all midfielders to defensive anchors. Requires authoritative clearance direction/recipient and current burst state. The illustrative diagram contrasts this with defensive cover without pretending to reproduce a particular club's complete setup.

### 3. Defensive centre cover

**Jobs:** contest participant, defensive cover midfielder and a release option at a separate angle. On an opposition win, cover moves to obstruct the dangerous route while the nearest player pressures. On an own win, the release player offers a less exposed exit. Failure is a successful opposition bypass or a pressured disposal, not a frozen line of players facing the ball. Modern centre analysis includes arrangements with differing numbers ahead/behind the contest and illustrates backward release handballs. [S17]

### 4. Defensive-50 stoppage escape

**Jobs:** extractor, rear/diagonal receiver, outside release and a defensive insurance player. The first handball can travel backward to create room for the next action. Then the receiver exits away from congestion rather than all players turning straight toward goal simultaneously. Failure: receiver closed down, rushed kick or repeat stoppage. Lions Academy material explicitly trains exit angles, separation and using outside support; an academy drill is evidence for a coaching concept, not a professional success-rate estimate. [S18]

### 5. Forward-50 stoppage scoring chain

**Jobs:** ruck, inside winner, forward-facing release option, small forward near the likely spill and opposition cover. A grounded ruck can remain useful in the chain when the recorded sequence selects him. Success can be extraction into a snap or a feed to a moving teammate. Failure can be tackle, rushed shot or defensive escape. Keep tap, possession and shot identities separate. This provides a natural presentation for the user's extra-midfielder ruck idea without manufacturing touches.

### 6. Boundary stoppage with two exits

**Jobs:** contest group, boundary-side outlet, inside outlet and cover. The boundary constrains useful escape angles; do not draw half the formation outside the oval. The inside exit offers territory but greater interception exposure. The safer outlet can still lead to another contest. Youth curriculum small-sided exercises are useful inspiration for controlled test scenarios, not a prescription to reduce the actual on-field team. [S19]

### 7. Kick-in: short outlet into a switch

**Sequence:** kicker → available pocket/flank outlet → opposite-side receiver → advancing wing or overlap player. The defending team shifts toward the early option, while the far-side receiver remains available. Failure: the second link is closed and the team resets or selects a bailout, rather than a kick to nobody. A CoachAFL switch drill explicitly links opposite-side reception, wing progression and a handball overlap; the youth manual discusses designing more than the first kick. [S20][S21]

### 8. Kick-in: wing overload with retained escape

**Jobs:** multiple plausible options on one side, a pack target farther upfield, a spill player and a far-side escape. An overload should produce a local numerical appearance, not a whole-team heap beside the ball. The defence either follows the concentration or holds a zone. Show the resulting trade-off. A second disposal may exploit the spare lane, or the ball may be trapped against the line. Record which plan was actually selected; do not infer it only from a random wide coordinate.

### 9. Torpedo down the middle

**Jobs:** kicker, intended central contest, spill runners and defensive cover for the long ball. Show a distinct long launch and an actual destination contest. The chance of a mark, spoil, gather or turnover belongs to MatchSim. Failure should leave an understandable central opposition opportunity. This is particularly suitable for the user's proposed kick-out decision gate, with success/failure endings where appropriate. Its distance and risk require simulation support; a dramatic camera effect does not establish a torpedo.

### 10. Corridor overlap: draw and release

**Sequence:** carrier advances toward a presser; support arrives beside/behind; handball releases the support runner; another target leads diagonally ahead. The presser commits to an actual player, revealing why the release works. Failure: support arrives late, the handball is pressured or the next lane is intercepted. Keep the handball a handball. Historical West Perth academy coaching stresses support and two-way work; AFL analysis of changing team styles illustrates that territory/pressure and rebound-running approaches can differ. [S22][S23]

### 11. Controlled possession: shift, then accelerate

**Jobs:** marked ball carrier, backward safety outlet, lateral option, patient forward target and opposing zone. Hold credible legal restart spacing; move the ball to change the zone, then accelerate if the logged next action breaks a line. Failure is an opponent closing the safe option or a pressured turnover. Lions Academy drills distinguish maintaining possession from exploiting an opening. [S18] Do not turn this into a universal mandatory three-pass routine or put all players on slow playback.

### 12. Forward lead into space, with decoy

**Jobs:** intended forward, another forward moving a defender away, spill support and an interceptor/defender reacting to the actual entry. Vacate the target's running lane, then launch into the agreed receiving space before the gather/mark. Success may lead to a shot; failure may be a beaten lead, spoil or interception. Player accounts from Fevola and Petrie demonstrate the utility of decoy work; they do not establish one fixed running pattern. [S24][S25] This fits the user's space-entry gate.

### 13. Down-the-line bailout and spill

**Jobs:** pressured carrier, genuine tall contest up the boundary, small support at likely spill and an opposition interceptor. The long kick trades possession certainty for territory. On a spoil, players react to a fixed deflection/fall zone; the ball must not steer toward the nominated collector. Failure can be an intercept, opponent gather or stoppage. Historical AFL tactical analysis explains why pressure can encourage long kicks into a defended zone. [S10] The exact outcome remains authoritative.

### 14. Forward press against a deep defensive exit

**Jobs:** immediate presser, exit guards, rear intercept layer; defending carrier, safe release, far-side outlet and possible long target. Show one player applying pressure while others block useful routes. A successful escape bypasses the press and reveals open space; a failed escape produces the logged turnover/contest. Under a flood, reverse the emphasis: more defenders in dangerous scoring space but fewer useful forward exits after recovery. This recipe makes the two defensive concepts visibly different rather than merely changing a label.

### Countering the named spare

Apply this as a variation across recipes, especially forward entries. Keep a forward dangerous enough that the interceptor must choose between his man and the incoming ball. A decoy leading harmlessly to an irrelevant corner should not magically neutralise a spare. Coaching accounts of making key defenders accountable provide useful examples, including Leigh Matthews' discussion of dangerous positioning and support defence. [S11][S26]

## 6. The smallest useful simulation-to-view contract

Reuse fields that already exist. Add only what is needed to distinguish and stage an action truthfully. Suggested fields below are **proposals, not existing API guarantees**:

```text
event or chain context
  phase and possession/disputed state
  plan for each team at this point in the timeline
  active burst and its authoritative expiry
  focus/tagger/tag target/duel/spare assignments
  legal restart participants

action intent, where supported
  disposal type and intended lane or purpose
  selected receiver or selected contest, not an invented visual winner
  primary pressure actor and relevant support/cover actors
  authoritative coarse launch/target region, if the simulation selects it

presentation reconstruction
  staging coordinates consistent with that intent and existing outcome
  planned flight/deflection and arrival schedule
  versioned fallback for old logs lacking these fields
```

Two valid levels must be distinguished:

1. **Semantic reconstruction:** MatchSim says who acted and what tactical intent applied; the director finds plausible coordinates consistent with the existing event. These coordinates explain, but do not newly decide, the outcome.
2. **Spatial simulation:** MatchSim evaluates actual lanes, reach and coverage before resolving the action. Geometry then affects football results. This requires new simulation rules and balance validation.

Start with level 1 where the game already knows the relevant information. Do not describe reconstructed coordinates as measured or fully simulated spatial truth. Escalate to level 2 selectively for a genuinely missing mechanic, rather than silently putting outcome logic in the director.

For old saves/replays, provide a conservative generic fallback. Lack of historical context is preferable to showing a tag, flood or switch that never happened. Snapshot actual assignments at the event/chain boundary, not by reading mutable final state during replay.

### Ownership and timing rules

- One authoritative football; one explicit carrier or loose state. No unlogged disposal to repair an animation.
- Establish flight destination before launch. Do not home toward a moving receiver after launch; logged deflections can legitimately create a new segment.
- Start necessary receiver movement early enough to reach plausible receiving space. Do not make the entire team predict future winners perfectly. Restrict staging lookahead to necessary participants.
- If a handball target cannot be reached, fix support placement/timing or report an incompatible reconstruction. Do not substitute a kick.
- Avoid a blanket wait for every nearby player to arrive before releasing a restart. Wait for participants required by the actual event and apply a bounded setup policy consistent with current rules.
- Keep legitimate unsuccessful plays. A failed disposal needs an intended option, pressure or explainable error; it must not be polished into a successful pass.
- Switching quarter direction changes attacking coordinates and near/far-side interpretation consistently. Assignment identities survive the end swap; their world-space jobs change.

## 7. Camera, animation and clarity

The director currently leads its focus toward the ball's flight destination. Extend that idea to a temporary **action envelope** containing the ball, intended contest/outlet and the most important cover player. This is a framing proposal, not another outcome predictor.

Recommended framing priorities:

1. At centre restarts, show the four-per-team contest, outside arrivals and enough space to understand the exit.
2. At a switch, widen before the long cross-ground kick so viewers can see the outlet the kick is exploiting.
3. At an inside-50 lead, include kicker, target running lane and defending coverage; avoid a tight shot that conceals the reason for the outcome.
4. At a forward press/flood, provide a brief wider view or optional tactical frame so numbers and missing outlets are visible.
5. Keep whole-oval mode useful and maintain phone/fullscreen readability. Tactical sophistication should not shrink everything to unreadable dots.

Animation should communicate commitment: turn and accelerate toward a lead; decelerate for a mark; plant before a kick; look/face toward the relevant contest; recover after being bypassed. Separate visual urgency from time-compression speed. At 8×, favour clear silhouettes, an intelligible ball trail and limited actor labels over more tiny movements.

Use optional overlays sparingly: named tag pair, named interceptor, intended outlet, or coverage outline during a selected coaching view. Mark **intended** routes distinctly from completed ball paths. Do not show a guaranteed success arrow before a rolled outcome. Rings and labels should follow actual identities across interchange.

## 8. Verification that proves a lever is visible

Use the existing capture harness and match-visual tests. Source analysis here did not run these checks; this is a proposed validation plan.

### Presentation fixtures

Build small valid event sequences with explicit tactical context. Their outcomes are fixed so the visual contract can be checked independently of balance. A fixture must not imply that an arbitrary unchanged match would remain identical after a genuinely different tactical decision.

| Fixture | Observe/assert |
|---|---|
| Tag assignment, then interchange | Correct identities before and after the change; accountability visible between touches. |
| Named interceptor takes mark/spoils | Named defender performs the event; former matchup gets coverage or a visible, intended vulnerability. |
| Legal centre setup with stack active | Legal pre-restart numbers; extra arrival after release; weaker coverage elsewhere. |
| Flood versus baseline during opposition entry | Greater behind-ball occupation and fewer forward outlets, rather than cosmetic labels alone. |
| Switch versus down-the-line intent | Different lateral ball/receiver movement and defensive shifting, with an explainable destination. |
| Handball into release | No kick substitution; feasible spacing and recipient arrival. |
| Shoot / pass / bomb from the same offered mark | Distinct resolved branches and correct scorers; pass/receipt shown when supported; no invented second scorer/mark or duplicate statistics. |
| Spoil into loose-ball gather | Deflection path fixed until another authoritative contact; no receiver-seeking correction. |
| Burst expires, then replay/skip | Tactical state changes at the same simulation point regardless of playback speed or review mode. |
| Quarter end swap | Correct attack direction, far-side wing and defensive coverage after the swap. |
| 1×, 4×, 8× and whole-oval/phone view | Same event ownership and order; important cause remains visible at different viewing speeds. |

Measure interpretable geometry: number behind the ball, available outlets, team width/depth, tagger-to-target distance, spare-to-dangerous-space relationship and coverage after turnovers. Thresholds should be scenario-specific; no universal rule that every AFL zone is a fixed circle or every tagger stands exactly two metres away.

### Simulation checks

After any outcome-affecting change, compare paired seeded batches with equivalent squads and conditions. Assess distributions of corridor/boundary use, possessions, entries, errors, clearances, scoring, workload and counterattack exposure. A tactic can fail in one match; validation should not require every attacking call to produce a goal.

Retain invariants: unchanged football RNG from view construction; no duplicate events/stats; actors on the field when acting; no identity loss through interchange; plausible bounded movement; correct replay/append behaviour; no score alteration from animation. Add narrowly targeted tests for the new contract rather than broad tests that merely mirror constants.

For human inspection, use matched screenshots/trail sheets and ask: **can a viewer identify the plan's benefit and vulnerability without reading its name?** If not, more movement is not necessarily the answer; better assignments or framing may be.

## 9. Suggested implementation sequence for Claude to assess

1. **Audit truth and actor continuity first:** named assignments, handball presentation, set-shot branch continuity, ball collection/flight, restart participants, repeated/distant waits and interchange profile refresh. Coordinate with the existing M8-003 scope.
2. **Record tactical context in the timeline:** plans, bursts and assignment changes; legal restart participants; selective action intent. Make live/replay/skip use the same state.
3. **Prototype two unmistakable contrasts:** attacking versus defensive centre support; flood versus ordinary defensive coverage. Include their vulnerabilities. These test the architecture better than implementing fourteen recipes at once.
4. **Connect corridor/switch/controlled intent to destinations:** use actual simulation decisions; add missing semantic decisions explicitly if required. Keep disposal types and outcomes authoritative.
5. **Introduce limited hybrid coverage and handovers:** named matchups override slot defaults, then add zone responsibilities and recovery.
6. **Expand the play library and camera envelopes:** support the user's existing vignettes and success/failure branches, without duplicating their decision resolution.
7. **Consider selective spatial outcome modelling only after these prototypes:** assess cost, save compatibility and balance before committing.

Do not demote the existing extreme-priority fullscreen/readability issue while doing this work. A recognisable football shape still needs a readable display.

## 10. Research coverage and limits

The research spans 26 linked sources below: game-developer material, official AFL rules, AFL interviews/coaching material, historical coaching manuals and original tactical journalism. Relevant sections were read rather than claiming every page of large manuals was exhaustively studied. Two Lions Academy stoppage-training pages were visually inspected. Video links encountered during research were not watched or independently annotated; this document therefore makes no claim to frame-by-frame video analysis.

Historical club examples are dated examples of a mechanism, not claims about those clubs' 2026 systems. Academy/junior exercises help explain jobs and provide test scenarios; they are not elite success-rate datasets. No proprietary tracking data was acquired. No live-game test, implementation or roadmap update was performed for this research.

### Source register

Sources are linked at their point of use. This register gives provenance and intended relevance; implementation recipes and diagram coordinates are original proposals.

- **S1:** [Football Manager: motion and positional play](https://www.footballmanager.com/features/truer-football-motion-match-authenticity-positional-play) — FM24-era developer feature, 2023; role compensation and animation.
- **S2:** [FM26 tactical evolution](https://www.footballmanager.com/fm26/features/possession-out-possession-fm26s-new-tactical-evolution) — developer description; possession-phase roles and preview.
- **S3:** [FC 25 FC IQ](https://www.ea.com/games/ea-sports-fc/fc-25/news/pitch-notes-fc-25-fc-iq-deep-dive) — developer deep dive; starting positions versus role movement.
- **S4:** [FC 26 gameplay deep dive](https://www.ea.com/games/ea-sports-fc/fc-26/news/pitch-notes-fc26-gameplay-deep-dive) — developer material; support movement and role limitations.
- **S5:** [Madden NFL 26 gameplay deep dive](https://www.ea.com/games/madden-nfl/madden-nfl-26/news/madden-26-gridiron-notes-gameplay-deep-dive) — developer material; coverage responsibilities and handovers.
- **S6:** [NBA 2K22 gameplay innovations](https://newsroom.2k.com/news/nbar-2k22-unveils-new-gameplay-innovations) — official announcement; defensive rotations, limited algorithmic detail.
- **S7:** [AFL 26 official Steam announcements](https://steamcommunity.com/app/3468640/allnews/) — developer patch notes; tactical and interchange integration.
- **S8:** [FC 25 Rush deep dive](https://www.ea.com/games/ea-sports-fc/fc-25/news/pitch-notes-fc-25-rush-deep-dive) — developer presentation description; camera and tactical assistance.
- **S9:** [Reynolds: Steering Behaviors for Autonomous Characters](https://www.red3d.com/cwr/steer/gdc99/) — original 1999 technical paper; behavioural hierarchy.
- **S10:** [ABC: West Coast–Hawthorn grand-final tactics](https://www.abc.net.au/news/2015-10-02/afl-grand-final-west-coast-eagles-hawthorn-tactics/6822532) — original 2015 tactical analysis, including Champion Data input.
- **S11:** [AFL: stopping McGovern and the Eagles zone](https://www.afl.com.au/news/196874/stopping-mcgovern-the-key-to-unlocking-eagles-zone-defence) — historical coaching discussion; interceptor accountability.
- **S12:** [AFL: judging the wing role](https://www.afl.com.au/news/1145478/how-to-judge-one-of-footys-most-unheralded-roles) — 2024 player/coach explanations; near/far wing responsibilities.
- **S13:** [AFL: centre-bounce and substitute changes](https://www.afl.com.au/news/1435386/league-scraps-sup-rule-and-centre-bounce-in-major-shake-up) — official 2026 change announcement.
- **S14:** [AFL: seven changes for 2026](https://www.afl.com.au/news/1464391/explainer-the-seven-afl-rule-changes-coming-in-for-2026) — official contemporary rule explainer.
- **S15:** [Laws of Australian Football, 13 February 2026](https://resources.afl.com.au/afl/document/2026/02/13/8676d880-481a-4211-a479-305f138ce8b6/Laws-of-Australian-Football-Final-13-February-2026-.pdf) — primary rules; contact, rucks and protected area.
- **S16:** [AFL: ruck strategy at the centre bounce](https://www.afl.com.au/news/538341/ruck-strategy-the-centre-bounce) — historical Madden/Flanigan coaching; distinct midfield support jobs. Interpret with contemporary rules.
- **S17:** [ABC: mysteries of centre bounces](https://www.abc.net.au/news/2024-04-13/unpacking-the-mysteries-of-afl-centre-bounces/103700434) — original 2024 analysis; differentiated centre arrangements.
- **S18:** [Lions Academy regional coaches presentation, 2015](https://s.afl.com.au/staticfile/AFL%20Tenant/BrisbaneLions/Lions%20Academy/2014%20Website/Regional%20Coaches%20Presentation%202015.pdf) — academy coaching slides; exits, width and possession drills. Relevant stoppage diagrams visually inspected.
- **S19:** [AFL Youth Coaching Curriculum, March 2024](https://play.afl/sites/default/files/2024-03/Youth_Coaching_Curriculum_March24.pdf) — primary youth-coaching material; constrained scenario practice.
- **S20:** [CoachAFL switch drill, Muddy Waterman](https://websites.mygameday.app/get_file.cgi?id=864036) — historical coached sequence; switch and overlap.
- **S21:** [2017 AFL Youth Coaching Manual](https://www.magpiesjuniors.com/wp-content/uploads/2017/04/2017-AFL-Youth-Coaching-Manual.pdf) — AFL-authored manual on a club mirror; kick-in and defensive structures. Indexed text accessible during research; direct file retrieval failed.
- **S22:** [West Perth 14s Academy training handbook](https://wafooty.com.au/download/d/wx9hz3e-M37m_XsOrEDdhLI-MgzYeU3pdzL8NdJT8yI) — historical academy resource; support, switching and two-way work.
- **S23:** [AFL: changing club styles in 2024](https://www.afl.com.au/news/1079582/chasing-the-pies-how-clubs-are-changing-their-game-in-2024) — original interviews/analysis; contrasting routes to advantage.
- **S24:** [AFL: Fevola's decoy work](https://www.afl.com.au/news/79574/im-just-a-decoy-fevola) — historical player account; vacating space for other forwards.
- **S25:** [AFL: Petrie happy to play decoy](https://www.afl.com.au/news/100103/drew-happy-to-play-decoy) — historical player account; complementary forward roles.
- **S26:** [Leigh Matthews: Coaching 101](https://www.afl.com.au/news/92370/coaching-101) — 2011 first-person coaching analysis; positioning, accountability and support defence.

[S1]: https://www.footballmanager.com/features/truer-football-motion-match-authenticity-positional-play
[S2]: https://www.footballmanager.com/fm26/features/possession-out-possession-fm26s-new-tactical-evolution
[S3]: https://www.ea.com/games/ea-sports-fc/fc-25/news/pitch-notes-fc-25-fc-iq-deep-dive
[S4]: https://www.ea.com/games/ea-sports-fc/fc-26/news/pitch-notes-fc26-gameplay-deep-dive
[S5]: https://www.ea.com/games/madden-nfl/madden-nfl-26/news/madden-26-gridiron-notes-gameplay-deep-dive
[S6]: https://newsroom.2k.com/news/nbar-2k22-unveils-new-gameplay-innovations
[S7]: https://steamcommunity.com/app/3468640/allnews/
[S8]: https://www.ea.com/games/ea-sports-fc/fc-25/news/pitch-notes-fc-25-rush-deep-dive
[S9]: https://www.red3d.com/cwr/steer/gdc99/
[S10]: https://www.abc.net.au/news/2015-10-02/afl-grand-final-west-coast-eagles-hawthorn-tactics/6822532
[S11]: https://www.afl.com.au/news/196874/stopping-mcgovern-the-key-to-unlocking-eagles-zone-defence
[S12]: https://www.afl.com.au/news/1145478/how-to-judge-one-of-footys-most-unheralded-roles
[S13]: https://www.afl.com.au/news/1435386/league-scraps-sup-rule-and-centre-bounce-in-major-shake-up
[S14]: https://www.afl.com.au/news/1464391/explainer-the-seven-afl-rule-changes-coming-in-for-2026
[S15]: https://resources.afl.com.au/afl/document/2026/02/13/8676d880-481a-4211-a479-305f138ce8b6/Laws-of-Australian-Football-Final-13-February-2026-.pdf
[S16]: https://www.afl.com.au/news/538341/ruck-strategy-the-centre-bounce
[S17]: https://www.abc.net.au/news/2024-04-13/unpacking-the-mysteries-of-afl-centre-bounces/103700434
[S18]: https://s.afl.com.au/staticfile/AFL%20Tenant/BrisbaneLions/Lions%20Academy/2014%20Website/Regional%20Coaches%20Presentation%202015.pdf
[S19]: https://play.afl/sites/default/files/2024-03/Youth_Coaching_Curriculum_March24.pdf
[S20]: https://websites.mygameday.app/get_file.cgi?id=864036
[S21]: https://www.magpiesjuniors.com/wp-content/uploads/2017/04/2017-AFL-Youth-Coaching-Manual.pdf
[S22]: https://wafooty.com.au/download/d/wx9hz3e-M37m_XsOrEDdhLI-MgzYeU3pdzL8NdJT8yI
[S23]: https://www.afl.com.au/news/1079582/chasing-the-pies-how-clubs-are-changing-their-game-in-2024
[S24]: https://www.afl.com.au/news/79574/im-just-a-decoy-fevola
[S25]: https://www.afl.com.au/news/100103/drew-happy-to-play-decoy
[S26]: https://www.afl.com.au/news/92370/coaching-101
