## ARD-M7-005 — History, records, leaders & recognition
**Status:** `PARTIAL` — History & records (closed PR #187, via #208), the coaches-award/season-honours program (#189, merged) and the awards ceremony (closed PR #185, via #208) are on `main`; the rest of this umbrella remains open. _(reconciled 2026-10-05)_ **Continuity check (2026-10-06, verify only; no code changed):** a 12-season career on autopilot (2027–2038) with save and reload at three points, driven through `GameState.start_season`, `advance` and `start_next_season`, found no break in the stored history. Player ids stay unique across the lists and never return after retirement; career totals equal the sum of club stints, and every listed player is counted through the season just played; honour-roll and record rows name their winner by id and still resolve after the winner retires; a retiree who goes into coaching carries a playing record equal to his last career line, and its honours match the honour roll; saving and reloading, once and twice, leaves careers, honours, records and coach playing records identical; the two real Bailey Williams (WCE_32, WBD_34) stay separate. Not covered by that run: National Draft intake (the harness called `start_next_season` without `begin_intake_draft`), the generated-prospect classes, the real-name toggle mid-career, and phone retrieval of an earlier contribution after a player loses his starting role. Those remain open for the acceptance line below.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Canonical umbrella for:
- career games/goals,
- club stints,
- league leaders,
- club records,
- league records,
- biggest wins/highest scores,
- season/career records,
- player of the match,
- coaches' votes,
- honours,
- Hall of Fame / legends where justified,
- famous finals/dynasties/droughts.

### Awards ceremony implementation — 2026-10-02
**Status:** `VERIFY` — awards ceremony foundation merged via #208; native phone pacing/touch/Back verification remains. _(reconciled 2026-10-05)_
- Brownlow, Coleman, All-Australian and club best and fairest are presented over the existing Season Review, with B&F last.
- One reusable stage walk-on/medal vignette reads the actual winner and all 20 clubs' genuine colour bands; it currently reuses BroadcastVignette's silhouette figures. **These legacy figures must be replaced with the new pre-rendered 2.5D style under ARD-M8-007's complete art-style replacement requirement.** No separate scenes per club, fabricated likeness, votes or outcomes.
- All-Australian is scrollable; controls reveal immediately, finish animation, advance, or skip to the review. Replay is read-only; viewed state lives in the already-saved season_awards dictionary.
- **Historical foundation limitation:** uses existing stored placings (including existing tiebreak order), not a round-by-round count. This does not prohibit or fulfil the newer authorised progressive count below; that count must use retained genuine round votes rather than invent them. Preserve recorded ties/medals under the actual award rules. B&F currently stores three placings; does not invent fifth/fourth.
- Validation: career_ui 178 checks, save 57 checks, awards 17 checks; zero failures. Actual Godot/OpenGL portrait capture inspected at 360×800. UI regressions cover 320/360/430 widths. Phone check still required for pacing, touch and Android Back.

### End-of-season awards presentation — fanfare, not summary cards
**Status:** `TODO` for the bespoke progressive counts/unveiling below; existing awards/ceremony foundations remain implemented. The older implementation note above describes a final-placings reveal, not completion of the round-by-round Brownlow requirement.

The current Season Review collapses Brownlow, Coleman, Rising Star, club best & fairest and All-Australian into a single static awards panel. That is too flat for awards that should feel like major season payoffs. Keep the **season story/campaign recap separate** from awards night.

- **Brownlow Medal:** give it a bespoke **staggered, round-by-round awards-night count**, watchable continuously in real time or advanced one round at a time. Reveal that round's actual match votes before updating the running leaderboard, preserve season round order and build a readable progression to the final winner reveal. The running count must show only votes revealed so far, not final totals that spoil the event. Clearly distinguish award eligibility from votes accumulated where the actual rules require it, and preserve recorded ties/winners. The underlying Brownlow already accrues 3-2-1 votes from home-and-away matches in `Awards.tally_match()`; presentation should reveal those existing votes rather than re-roll or invent anything. Allow sensible pacing/skip controls so repeat long careers do not become tedious, but the default first-time experience should have ceremony and escalation rather than immediately exposing the final totals.

  **Required viewing controls:** **Watch / Pause / Resume**, **Next round**, **Skip current round** (finish that round's reveal and show its completed running standings) and **Skip remaining count** (go straight to the final result/season review). Continuous playback progresses at deliberate readable ceremony pacing without repeated clicks; manual mode stays at the current round until advanced. Advancing/skipping a round must still account for all its actual votes exactly once. Make the current round, revealed votes and running leaders clear without number vomit. Skipping is always optional and changes presentation only, never votes or winners.

  **Awards-season cadence:** enter awards night at the appropriate implemented post-finals stage, distinct from the season-story recap and the user's club B&F ceremony. Give a concise first-use introduction explaining the round count and playback/skip controls. Preserve the specified Coleman/Rising Star acknowledgements within Brownlow night and the separate progressive All-Australian unveiling, without turning every honour into another long countdown. No real-world waiting days are required.

  **Persistence and verification:** retain genuine round/match vote records if the current aggregate-only store lacks them; do not reconstruct or fabricate a count from final totals. Save/resume or read-only replay must preserve reveal position/leaderboard without awarding again. Verify continuous watch, pause/resume, repeated next/skip-round actions, skip-all at the start/middle/end, empty/bye rounds, ties/eligibility, final totals reconciling with authoritative awards, no premature winner reveal, and desktop/phone controls and pacing. Do not mark complete from a winner walk-on or a sequence of static final-result cards.

- **Club best & fairest:** give the user's club its own bespoke count/ceremony, again progressing through the season rather than dumping the final `bf` totals. The current model already accrues 5-4-3-2-1 within each side every match, finals included. Reveal those existing votes progressively, with the club winner feeling like a genuine end-of-year moment. This is a club event, distinct from the Brownlow night.
- **All-Australian:** give the final team a bespoke unveiling at season's end instead of a compact list. Reveal the side in stages/lines (e.g. defence, midfield/ruck, forwards, interchange) with enough pause and presentation that selections feel prestigious. Do not expose the internal selection formula or turn it into a number dump.
- **Coaches' votes:** implement as an in-season accumulating recognition system, visible through appropriate leader/record surfaces as the year progresses. **Do not** give coaches' votes another bespoke end-of-season countdown; by season's end the winner can be acknowledged briefly because the interest came from watching the race accrue during the season.
- **Coleman Medal:** the race should also accumulate visibly throughout the season, just like coaches' votes and the existing ladder Coleman panel. It does **not** need its own bespoke countdown ceremony at season's end because the user has already watched the race develop week by week. Give the final Coleman winner a short, prestigious presentation/mention during the Brownlow ceremony.
- **Rising Star:** no separate ceremony required. Award/present the Rising Star during the Brownlow ceremony as part of the broader league awards night, with enough prominence to feel meaningful but without interrupting the Brownlow count's pacing.
- Do not force every honour into its own ceremony: the distinct marquee experiences are the Brownlow count, the user's club B&F count, and the All-Australian unveiling; Coleman and Rising Star live naturally within the Brownlow awards-night presentation.

### Director addition — Danny Frawley Golden Fist award
**Status:** `TODO` — new season award.

Add the **Danny Frawley Golden Fist** award for the **best defender of the season**. Give defensive excellence a distinct season honour, rather than relying on the Brownlow or general player ratings to recognise it.

Claude should refine a transparent, role-aware selection rule using actual season defensive contributions and the existing award/recognition systems. Consider intercept marks, spoils, one-percenters, defensive contests/accountability and other reliably tracked defensive work; do not reduce "best defender" to the most spoils or generic disposal volume, or invent untracked statistics. Both lockdown and intercept defenders should have credible paths to winning.

Define eligibility, home-and-away versus finals scope, and deterministic tie-breaking consistently with existing awards. Present the winner with a concise season-end reveal, and persist the honour in player/club career history and annual award records. Validate seeded contrasting defender profiles, repeat processing and save/reload so the award cannot duplicate or change its winner.

Presentation guardrails:
- fanfare should come from pacing, reveal, hierarchy and football context, not particle spam or UI clutter;
- no fake suspense: reveal deterministic stored results only;
- skippable/acceleratable for experienced players while preserving a satisfying default flow;
- save/reload must not double-award, re-roll votes, or change winners;
- each ceremony should work cleanly on a phone and should not require dense tables.

Acceptance: Brownlow and the user's B&F can be watched as progressive counts with evolving leaders and a final winner reveal; All-Australian is unveiled progressively by line/position; coaches' votes accrue through the actual season and need no separate countdown; the ordinary Season Review no longer substitutes a single static card for these major moments.

### Guardrails
- count each season/event once,
- no duplicate career aggregation on reload,
- generated-player careers remain coherent over decades,
- build from stored facts, not fabricated retrospective text.

### Research refinement — 2026-10-05

**Dependencies:** Career/Season stored facts, existing milestone/award systems and M6-002 former-player links. Keep #226 backed-player payoff as its current implementation owner.

**Smallest scope:** verify continuity of one player's existing history from recruit to changed playing role, club movement, retirement and any actual coaching entry; repair a missing link/fact before adding presentation.

**Exclusions:** a second archive, generic story cards, guaranteed career arcs, fabricated relationships, duplicate praise or the unselected alumni/bookmark candidates.

**Acceptance:** stable IDs and genuine stints/honours survive decades and reload; an ageing contributor can remain remembered after losing a starting role; records never confuse another player with the same name or new guernsey. Recognise event-supported finals/dynasties without rewriting quiet seasons as dramatic ones. Where context is missing, make an earlier contribution and actual present role inspectable through existing facts, without inventing relationships.

**Validation:** transferred/retired/generated players, imported 2026 history once, repeated reload, real/fictional-name preference and existing coach-player linkage; phone retrieval and multi-season recall. Broader narrative presentation remains review-only unless already accepted elsewhere.


**Approved flavour extensions:** FL-005/006/007/008 (§9.3) cover harmless fictional profile identity, truthful headlines, rituals/farewells and factual visual club memories. Reuse the existing nickname/history/awards/alumni foundations.

---

