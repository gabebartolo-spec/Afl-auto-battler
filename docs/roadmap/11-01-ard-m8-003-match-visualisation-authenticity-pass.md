## ARD-M8-003 — Match visualisation authenticity pass
**Status:** `PARTIAL`  
**Progress (2026-10-06):** step 1 of the visualisation sequence, the truth fixes (handballs stay handballs, the ball never steers), merged in #438 on the director's go ("Merge on green"). Presentation only; the sim, scores and event order are untouched.
**Progress (2026-10-06, step 2):** the tactical timeline merged in #445: the match records each side's calls (plan, bursts, tagger, loose defender, named match-ups) and the view puts the match's named players on each other. Presentation only; it reads the sim and draws no dice. Step 3, the two demonstrations, follows.  
**Progress (reconciled 2026-10-07, step 3):** #475 is merged on main: flood/centre setup demonstrations and shape regressions are present. #480 adds persistent tagger/target/loose-defender labels; #467 brings the #471 set-shot choice staging onto main. **Remaining:** recorded/effective lanes (M4-014), full decision/vignette coverage, the held 14-play library and recent collection/disposal/identity readability defects. Broader hot-player/equivalent-actor labels require verification; do not claim all umbrella scope DONE.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Umbrella for presentation problems after their simulation causes are understood.

Includes:
- correct attacking-end swaps,
- no wrong-way kicks,
- open-play shots remain live,
- believable winger width/work rate,
- correct kick-ins/stoppages/boundary restarts,
- camera/pacing improvements where they improve football readability,
- **tactical shape must be visibly truthful:** choices such as **Flood the backline** must materially change where the relevant players set up and move on the visualiser. Verify the underlying MatchSim/tactical effect first; if the tactic is not actually changing occupation/shape, fix the football behaviour rather than faking a presentation-only formation shift. Other structural calls should obey the same rule,
- **no self-propelled / receiver-seeking ball:** investigate cases where a loose/bouncing ball appears to change course or travel implausibly into the hands of a player some distance away. Ball motion must follow the authoritative event and a believable kick/handball/deflection/bounce path; ownership changes must not look like teleportation,
- **no unexplained disposals into empty space:** investigate why players frequently kick/handball toward no plausible teammate, contest or tactical target. Empty-space disposals are acceptable only when the event has a football reason (e.g. territory, pressure, hacked clearance, deliberate leading space, spoil/deflection); presentation must not invent a receiver that the simulation did not select,
- **remove distant-contest wait states:** play still pauses too often while a far-away player runs to the contest before action resumes. Audit which event/participant requirement is causing the hold, explicitly including whether the visualiser is waiting for the designated ruckman to reach a stoppage. Localise the fix rather than hiding the pause with faster animation,
- **persistent identity for important live roles:** players who are currently tactically or narratively important — at minimum taggers and their targets, hot/in-form players, roaming interceptors/spares, and equivalent special matchup actors — should keep their names visible on the visualiser rather than requiring the viewer to infer who matters from anonymous tokens. Keep this restrained: persistent labels are for meaningful actors, not all 36 players.

Acceptance additions:
- a structural coaching call that should alter team shape is recognisably visible within the next relevant phase of play and agrees with the authoritative simulation state;
- sampled ball movements have an explainable origin, target/contest and path, with no unexplained receiver-seeking bounce or snap-to-player behaviour;
- sampled disposals into space can be traced to a legitimate event reason or are fixed;
- stoppages do not routinely freeze while an unnecessarily distant participant crosses the ground; required ruck/contest participants arrive through believable positioning/pacing rather than a dead wait;
- named special-role/hot-player labels remain readable on phone without creating name-vomit or obscuring the ball/contest.

Guardrail:
Do not perform a movement-engine rewrite without evidence that local fixes are insufficient. Do not paper over authoritative simulation defects with presentation-only fakery.


**Interview of 2026-10-06 (the director, on the visualisation and tactics research in docs/research/AFL_MATCH_VISUALISATION_AND_TACTICS_RESEARCH.md):** the agreed sequence, in order.

1. **Truth fixes, confirmed in code:**
   - handballs over 18 m are drawn as kicks (MatchDirector.gd:454, 760, 987); stage a short handball and then the carry;
   - the ball steers toward the collector within 8 m (`roll_to`, l.1243 and l.1383); fix the deflection or bounce destination at release;
   - collect waits of up to 6 s, and flights stretched to wait for receivers; start receivers earlier and cap the wait;
   - stage the set-shot choices from ARD-M4-013's events.
2. **A tactical timeline:**
   - record plans, bursts (with their real start and expiry) and named assignments per chain: the tagger and target, key-forward matchups, the loose interceptor, and the spare made accountable;
   - the director uses the named players instead of slot pairs and its own half-back spare;
   - snapshot them for replay and skip.
3. **Two demonstrations first:**
   - Flood behind the ball against ordinary coverage on an opposition entry;
   - attacking against defensive centre setups at the **2026 centre ball-up**. The director chose "ball-up from 2026"; the copy is in #414.
4. **Then corridor, switch and down-the-line** from ARD-M4-014's recorded lanes.
5. **The 14-play library is held** until the demonstrations land; the director chose "only after the demos land".
6. **No coaching-view overlay or route arrows.** The director chose "labels only"; the approved persistent labels for key players stand.

Verify with `capture_match.gd` fixtures at 1×, 4× and 8×, on phone and fullscreen, and check that scores, stats and the event order are unchanged.

**Approved flavour extension:** FL-003 (§9.3) adds sourced, readable atmosphere for existing venues. Ground dress changes no geometry, weather, home advantage or football outcome.

---

