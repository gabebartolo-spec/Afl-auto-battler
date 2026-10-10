## ARD-M6-002 — Coaching staff gameplay
**Status:** `DONE`  
**Merged:** Phase 3 PR #62, former-player pathway PR #74, gameplay-effects PR #77, plus the ARD-M6-002 coaching-movement visibility/frequency audit direct-landed on 2026-10-01; teaching, tactics and man-management effects are all live.  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`
**Current state (2026-09-28):** Phase 2 (data model, Round 1 2026 seed, read-only Staff UI) is merged. Phase 3 (the living coaching market: sackings, contracts, retirement, promotions, poaching, your vacancies and releases, development, reputation, generated coaches, expansion staffing, archive) is merged: PR #62 as `bf8bd0a`, `coach_market` suite, 50-season probe with every job filled. **Phases 4 and 5 are DONE** via #74/#77, as recorded above; the newly requested opportunity-retention hierarchy below remains TODO.  

Core design:
- Teaching → development,
- Tactics → match performance,
- Man-management → morale/selection response.

### Phase 4 — former-player coaching pathway

Implementation direction:

- capture a player before retirement/delisting removes them from the active lists;
- one deterministic career-seeded roll decides whether they pursue coaching;
- preserve the same player name/alias and link the coach record back to the playing career;
- pathway period: roughly 1–3 seasons before entering the normal coaching market;
- **playing ability must not determine coaching skill**;
- playing fame may raise starting reputation only, and that advantage should fade over roughly a decade;
- former clubs may provide a small, bounded hiring-link advantage;
- once in the market, former players obey the same hiring, promotion, retirement and vacancy rules as other coaches;
- profile/history should show the playing career without creating a separate former-player coaching ruleset.

### Phase 4 balance guidance

A real 32-season career exposed an upstream constraint: the current game ends only about **19 playing careers per season**, heavily skewed toward long-tenured veterans. At the original 8% coaching-entry rate, former players reached only about 10% of coaching jobs after 32 seasons.

Do **not** solve that by forcing an extreme conversion rate simply to hit a headline percentage.

Use this order:

1. Test a former-player coaching-entry rate in roughly the **20–30%** range, with **25% as the first baseline**.
2. Make generated external coaches a **top-up/fallback supply**, not a fixed source that permanently crowds former players out as the ex-player pipeline matures.
3. Keep the long-run design target of roughly **60–80% of coaching jobs eventually being held by former players** as a mature-world aspiration, not a hard Phase 4 pass/fail if the current player-retirement pipeline cannot supply enough candidates.
4. Record the observed ~19 career endings per season as a separate player-lifecycle/list-turnover issue. Do not hide it inside coaching by inflating conversion rates.
5. Compare 30–50+ season runs for:
   - former-player share of all coaching jobs,
   - former-player share of new appointments,
   - generated-coach pool size,
   - vacancy fill rate,
   - internal promotion share,
   - coaching skill distribution / Elite share,
   - churn and repeat moves.

If 20–30% entry plus adaptive generated-coach supply still cannot produce a believable coaching ecosystem, report the limiting factor rather than tuning blindly.

### Phase 4 merge authority

The older Phase 4 brief saying **"do not merge"** is superseded by the roadmap's standing development authority. Once Phase 4:
- passes its targeted suites,
- passes the full suite,
- has acceptable long-run balance evidence,
- preserves save compatibility,
- and CI is green,

Claude should **merge it and proceed to Phase 5** without waiting for another permission message.

Requirements:
- modest/capped effects,
- role fit where sensible,
- coach career histories,
- replacement/succession over long saves,
- save compatibility,
- avoid generic "+10% everything" staff bonuses.

Validate with targeted multi-season simulations.

### Phase 4 implementation record (2026-09-28, branch `claude/coaching-phase4`)
- **Capture:** a playing career ends (retired in `Prospects.age_league`, or delisted and unsigned at the close of free agency) and `GameState._career_over` captures him before he leaves the lists. The `played` snapshot holds games, goals, club stints, draft, listed position, retirement year and in-save Brownlows and Colemans. No ratings, contract, training, injury or stat tables are kept.
- **Decision:** one career-seeded roll per player, decided once: 19%, 22% at 150+ games, 25% at 250+, +1 point per major award, capped at 30%. He becomes `C_P_<player id>` with his real name and the same alias, then has 1-3 pathway seasons (+1 if the market is flooded, never more than 3 extra) before the ordinary market.
- **Fame is not ability:** skills come from the coach id alone (52-72, centred 62). Across 3,000 retirees, games correlate with skill at r ~0.03 and with starting reputation at r ~0.7. The fame part of reputation fades over nine coaching seasons. A former club rates him +2.5% (half of the 5% club link).
- **Market change (Phase 3 tuning):**
  - Generated external coaches are now top-up supply: fewer as the pathway fills, pool floor 20, top 40.
  - They get the same newcomer starting skills as a former player.
  - The population anchor is now 70, which keeps Elite at 1-4%.
- **Evidence:**
  - Real 32-season career: about 19 career endings a season, median about 280 games, 593 retired, 2 unsigned. Generated draftees reached AFL coaching jobs; for example, a 2031 draftee (253 games) became development coach at Tasmania in 2049 and midfield coach at Essendon in 2053.
  - Synthetic 50-season market at that volume: 23% of endings go into coaching, 36% of those are hired (almost all first as development coaches), then 91% reach a line job, 44% senior assistant and 25% senior coach (about 25 years after retiring). Former players hold 38% of jobs at year 50 and make 33% of new appointments after year 20. Emergencies 0; generated pool 16-22; coach records plus archive about 180 KB at year 50.
- **Real 32-season career (authoritative):** 615 career endings (602 retired, 13 unsigned), 23.4% into coaching (144). By 2058 former players held 102 of 119 jobs (86%), just above the 60-80% aim. Several reached senior coach by the normal path; for example, Ben Long went forwards coach 2040, senior assistant 2044, senior coach West Coast 2058. Coach records 106 KB and archive 66 KB after 32 seasons. The synthetic market probe (38% at year 50) under-predicts because it cannot reproduce real results and churn. If the share keeps climbing past 80%, lower `BASE_INTEREST` first.
- **Upstream issue:** about 19 playing careers end a season, almost all veterans. That is a list-turnover question for the player lifecycle, not coaching.
- **UI:** the coach profile shows the playing career (clubs, games, goals, draft, medals), then the coaching career, wrapped for 360 px. News covers notable former players joining the coaching ranks and their first appointment.
- **Tests:** new `coach_pathway` suite, plus the coaches and coach_market suites.


### Phase 5 implementation record (2026-09-28, branch `claude/coaching-phase5`)
- **Design:** `CoachEffects.gd` holds three capped modifiers read from the coach records; nothing is saved. A skill counts from a Good coach: level = (skill - 70) / 20, clamped -0.75..1. A vacant job counts as a weak coach.
- **Teaching:** scales match XP in the one place it is paid (`GameState._grant_xp`, your club and rivals alike).
  - Weights: 6% x the player's line coach's fit for the job, 5% x the development coach's fit for a player aged 22 or under or not on the ground (2% otherwise), and 2% x the senior assistant's teaching.
  - Capped at -5% to +10%. The reserves keep their half rate.
  - Probe, the same career with coaches set to 60 / 72 / 90: match XP 126.9k / 133.6k / 148.7k; starting list after 3 seasons +1.10 / +1.21 / +1.52 OVR.
- **Tactics:**
  - The tactical brain is the senior coach 60% and senior assistant 40%; at your club it is your assistant.
  - Plan effects, costs included, execute at 1 +/- 15% x level through `MatchSim._pv`.
  - `ai_tactics` reacts to a margin of 18 - 8 x level, counters after one quarter at level 0.4+ (two otherwise, never below -0.5), and tags from half time when sharp.
  - AI clubs now pick their plan each quarter in every match; before, only in the match you watched.
  - With no plan in play, tactics change nothing: a hash test confirms identical results.
  - Identical lists: 72 v 72 wins 50.4%; 90 v 72 wins 53.2% (+2.8 points a game).
  - AI plans league-wide (1,000 matches): plans used in about 18% of quarters, mean score 86.9 to 88.5, home win 59.6% to 57.1%, stronger side wins 63.1% to 64.6%.
- **Man-management:** spares part of the morale a fit player loses when left out, and part of a broken promise of a game.
  - The senior assistant counts 60% and his line coach 40%, up to 40% spared; a poor man-manager spares nothing.
  - A star dropped eight weeks from 70 ends at 22 / 30 / 38 with weak / Good / elite: he still slides.
- **UI:** one plain line on the coach profile says what each skill does. No numbers.
- **Tests:** new `coach_effects` suite (24 checks).

---


### Coach-market movement visibility / frequency audit

#### Final audit record (2026-10-01)
- Measured synthetic market: about **3.1 senior-coach changes** and **~17 total job moves per season** across 90 simulated seasons; only 1 season in 30 had no senior-coach change.
- First real 2027 offseasons checked produced 1 senior-coach change and 8–9 total job moves, confirming the underlying market was moving at a plausible rate rather than being stuck.
- The main problem was visibility: coaching items were easy to lose in the wider news feed, and user-staff departures could amount to little more than a tab badge.
- The hub now explicitly surfaces staff departures/vacancies with a path to appoint a replacement, and the off-season wrap names staff departures plus new senior coaches and whom they replaced.
- No churn-rate inflation was added merely to guarantee drama every offseason.

**Claude audit required.** Phone playtesting through a complete season/offseason produced no obvious sense that coaches moved clubs at all.

The coaching market **is implemented**: `GameState._close_season_awards()` calls `_coaching_offseason()`, which runs `CoachMarket.offseason()`; the market supports senior-coach sackings/contract expiry, promotions, retirements, poaching from the user's staff, vacancy chains and appointments. Existing automated tests also prove movement can occur over long runs. That does **not** prove the live player experience is working.

Claude must run the final audit and report:
- whether any coach movement actually occurred in the user's first 2027 offseason under normal career conditions;
- league-wide counts per offseason for senior-coach changes, promotions, retirements, contract non-renewals, internal promotions and assistants poached;
- how often an entire offseason legitimately has little/no visible movement;
- whether the movement rate is football-plausible over 10–30 seasons;
- whether movement happens but is effectively invisible because it is buried in the news feed / staff screen;
- whether the user's own staff can realistically be poached often enough to matter without becoming churny;
- whether senior-coach turnover is too conservative in early seasons because of first-season/tenure protections.

Do not tune merely to guarantee a coaching carousel every year. Some quiet offseasons are believable. The requirement is that the system produces credible movement over time **and the player can actually notice important changes**.

If the underlying rate is healthy, improve presentation rather than forcing extra churn:
- include notable coaching ins/outs in the post-draft offseason summary;
- surface major senior-coach appointments/sackings clearly;
- surface any coach poached from the user's club as an explicit event requiring a response.

Acceptance:
- Claude provides measured movement distributions before changing rates;
- a multi-season career produces a believable coaching market with neither stasis nor constant churn;
- significant coaching changes are visible to the player;
- the user's first offseason being quiet is explainable by the measured system rather than assumed correct because tests pass.

### Coaching hierarchy and rival approaches — opportunity-based retention (director request/clarification, 2026-10-07)
**Status:** `TODO` — extend the existing coaching market and assistant-contract layer; their merged foundations remain complete. **Priority:** `P1`.

**Required coaching hierarchy: Head coach → Head assistant → other assistants.** Head assistant is a distinct senior appointment above the remaining assistant roles, not merely a cosmetic title. Keep the existing specialist responsibilities beneath this hierarchy; do not invent additional ranks. Represent the hierarchy consistently in staff profiles/screens, appointments, vacancies, promotions and the AI coaching market. Each club has one head coach and at most one head assistant; handle an unfilled head-assistant position explicitly. Reuse existing senior-coach terminology/data where appropriate and display the hierarchy clearly.

When a rival approaches one of the user's coaches, the user must have a meaningful opportunity to **make an opportunity-based counter-offer and try to retain them before departure is finalised**. **This retention negotiation is not a monetary bidding system.** The director's examples are promotion to **Head assistant** or a **Head coach succession plan**. Extend this existing owner and off-season staff flow rather than creating another coaching market.

- Present the rival approach as an actionable decision showing the coach, rival club, offered role/opportunity and the coach's ambitions where supported. Offer **Make counter-offer** and **Allow departure**, with a clear response deadline or decision stage.
- Offer genuine career opportunities supported by the hierarchy: an immediate Head assistant promotion when that position is legitimately available, or a credible Head coach succession plan with an explicit timeframe or condition. These are examples of the intended opportunity vocabulary, not permission to manufacture unrelated negotiation currencies. Show what the user is committing to before confirmation.
- A promotion must change the coach's authoritative role/responsibilities and staff structure. If Head assistant is occupied, explain why that offer is unavailable or require an explicit, valid staff reorganisation that names the incumbent and consequences; never silently demote/displace them or appoint two Head assistants.
- A succession plan must identify the future role, agreed timing/condition and current incumbent, including the user's own head-coach position where applicable. Make any eventual step-aside/role consequence explicit and obtain the user's deliberate commitment through the offer flow. Do not automatically replace the user, promise a job outside their authority or leave an empty promise with no fulfilment path. If succession cannot function under current career rules, implementing a coherent supported path or resolving that specific design constraint is required before offering it.
- Resolve retention using actual ambition, hierarchy advancement, responsibility, credibility/timing of the promised opportunity, competing role and club situation/loyalty where modelled. An opportunity can improve the chance of staying without guaranteeing it; a coach offered an immediate rival head-coach job may reject a delayed succession promise. Give a concise football-readable explanation, with grounded flavour copy encouraged. Do not add salary sliders, cash counter-offers or financial bidding to this retention feature.
- Persist accepted promotions and succession commitments, track when conditions become due, and provide a clear fulfilment/reconsideration decision. Unfulfilled promises must have legible consequences for trust and willingness to remain rather than silently disappearing. Preserve commitments across seasons, save/load, relevant club/coach movement and the user's tenure under consistent rules.
- Hold the rival move pending the response. On acceptance, apply the agreed opportunity and cancel that move; on rejection or allowed departure, complete the existing move/vacancy/replacement chain exactly once. Preserve the no-sideways-poaching design using the explicit hierarchy: Head assistant and Head coach offers are genuine upward opportunities for eligible assistants. Apply consistent hierarchy/eligibility to AI clubs without giving them hidden advantages. Avoid repetitive bidding loops and negotiations for every staff member.
- Save/load must preserve pending approaches, offered opportunities and resolved outcomes. Prevent duplicate decisions/appointments and off-season advancement bypassing an unresolved retention decision; make any timeout/default departure rule explicit before it applies.
- Add meaningful regression checks for hierarchy/role eligibility, successful Head assistant retention, occupied-role conflicts, rejected offers and allowed departures, immediate rival promotion versus delayed succession, succession due/fulfilled/unfulfilled, user-head-coach safeguards, multi-season/save-load persistence and exactly-once market/vacancy resolution. Verify the full approach → opportunity offer → decision → retained/departed staff flow and subsequent commitment fulfilment in a runnable desktop/phone playtest.

### RC-004 verification — the former player on his coach profile (2026-10-06)
**Verified, one repair (merged in PR #234).** The existing pathway already keeps the same person: `CoachPathway.snapshot` captures his clubs, games, goals, draft and position at retirement under his own name and alias, and the coach profile (`CoachSheet`) shows a "Playing career" section above his coaching stints; appointment news names his old club. **Missing link repaired:** only Brownlows and Colemans were carried over, though the save's honour roll also names the Rising Star, the Coaches Award winner and your club's best and fairest. The profile now lists those too ("Coaches Award", "Rising Star", "3 Adelaide best and fairests"). Other clubs' best and fairests and All-Australian selections are not kept season to season, so they are not claimed. The chance he goes into coaching still counts Brownlows and Colemans only (no balance change). Checked at 360 px; `coach_pathway` 57 checks.

