## ARD-M6-004 — Contracts / trades / free agency
**Progress (2026-10-06):** trades at closer to real AFL volume merged in #383 (director: "increase trades as you say", and "looks good" on the look): players aged 20 to 29 can ask to be traded, to go home or for a game, and rivals trade more. Requests you are involved in show on the trade tab.  
**Status:** `PARTIAL` — contract talks, free agency, compensation, competitive offers, free-agent sorting (#184), the trade redesign (#182 valuation, #191 current picks, #193 future picks) and real-money contracts (#198) are all on `main`; the stack PRs were closed and carried by #208. Open follow-ups include the staggered 3–5 day submission/daily-close trade period below, plus any unresolved §9.1 valuation/acceptance checks; earlier trade-value and contract-talk foundations must not be rebuilt merely because their historical findings remain. _(reconciled 2026-10-05)_  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Build toward a complete AFL list-management ecosystem.

### Real AFL money scale
**Status:** `VERIFY` — the salary/cap migration and trade integration are on `main` via #208; retain phone/save follow-up rather than rebuilding the former stack. _(reconciled 2026-10-05)_

The old 1–10 salary/cap-point economy is being replaced at the underlying system level, not merely reformatted:
- playable 2027 starts from the AFL-scale **$18.44m** club cap;
- annual salaries run from a senior floor around **$155k** through to **$1m+** elite contracts;
- first-year draftee contracts use pick-band salary anchors;
- contract/free-agent bidding moves in football-sized increments;
- trade/free-agency/compensation formulas normalise the larger units so salary does not swamp every other factor;
- old point-based saves, counters/offers and in-progress opening drafts migrate deterministically;
- UI uses compact football money such as **$650k / $1.20m / $18.44m**;
- match payments, ASAs and club profit/loss accounting remain deliberately out of scope.

Do not create a separate economy subsystem for this. It is part of ARD-M6-004; its former trade/currency stack is already merged. “Real AFL money” means simulated club salaries and caps, not real-money purchases. The game has zero microtransactions.


### Contract negotiation — important decisions need ceremony and guardrails
The current off-season UI lets the user tap `1 yr / 2 yr / 3 yr / 4 yr` and immediately executes `GameState.resign_player()` at a fixed `Contracts.asking_salary()`; Release is similarly immediate. That is too abrupt for one of the core dynasty/list-management decisions.

For expiring players, tapping a contract option should open a **dedicated negotiation screen/sheet** rather than instantly resolving the deal. The negotiation should make the decision feel consequential without turning every fringe player into paperwork.

The user must be able to negotiate **salary as well as term** with the player in question. The player's current asking salary is an anchor, not an immutable price.

Design direction:
- show player identity, age, current OVR/POT, current salary, requested salary, requested/available term, cap room after the proposed deal and list context;
- let the user propose a salary + term combination;
- the player can accept, reject, or counter based on understandable factors such as ability/value, age, morale, market demand, role/security and contract length;
- longer security can reasonably trade against salary in some cases; stars/young guns should have more leverage than fringe veterans;
- negotiation must not become a hidden dice casino. If randomness is used at all, keep it bounded and seeded, with the player's expectations legible enough that the user can reason about the offer;
- failed offers should not instantly destroy the relationship unless the offer is genuinely insulting or repeated bargaining warrants a consequence;
- preserve the possibility that a player walks to free agency if agreement cannot be reached;
- AI clubs should negotiate under equivalent cap/value constraints rather than magically signing everyone at fixed prices;
- **Release / delist** actions should have an explicit confirmation step with the consequences stated before execution;
- consider a lightweight "accept asking price" shortcut for routine deals so the system has ceremony where it matters without contract-admin busywork.

Guardrails:
- understandable and streamlined,
- AI follows same core constraints,
- no contract-admin busywork,
- important list decisions must not resolve from a single accidental tap,
- do not attempt all player movement systems in one mega-PR.

Acceptance:
- tapping an expiring player's contract no longer instantly commits the deal;
- salary and term are both negotiable;
- the user can see cap consequences before confirming;
- accepted/rejected/countered offers follow transparent football-list logic;
- Release cannot happen accidentally;
- save/reload preserves an in-progress negotiation or safely returns to the pre-offer state without duplicating the transaction;
- routine deals remain quick enough that managing 40 players does not become tedious.

Split into smaller authorised subphases when started.


### Contract/off-season copy cleanup
Phone playtesting exposed awkward/dehumanising wording at the top of Trades & Contracts: **“Anything you leave undecided is re-signed for two seasons if the cap allows.”** “Anything” appears to refer to players/contracts and reads strangely.

Use human, football-specific language. Preferred direction:
- **“Any out-of-contract players you leave undecided will be re-signed for two seasons if the cap allows.”**
- or a shorter equivalent such as **“Undecided out-of-contract players will be re-signed for two seasons if the cap allows.”**

Audit nearby off-season transactional copy for the same problem: refer to **players, contracts, offers, picks and trades** explicitly rather than vague object-language like “anything”, “done”, or generic system wording where a football term would be clearer.

Acceptance: the screen reads naturally to a footy fan, never describes players as generic objects, and preserves concise mobile copy without becoming wordy.
### Free-agent offers, compensation and browsing
The same negotiation standard applies to **external free agents**, not only the user's own expiring players. The current Free agents tab presents `Sign 1 yr / Sign 2 yr / Sign 3 yr` buttons and immediately executes `GameState.sign_free_agent()` at the fixed asking salary. A free agent cannot reject, counter or compare the offer with any market alternative. That makes a major list acquisition feel like buying an item from a shop.

Required direction:
- tapping a free agent opens the same dedicated offer/negotiation flow used for re-signings;
- salary **and** term are proposed by the user;
- the player may accept, reject or counter based on his value, age, requested security, morale/market situation and competing interest;
- no player is guaranteed to join merely because the club has enough cap room;
- show the cap impact before confirmation;
- allow a quick **meet asking price** path where appropriate, but it is still an offer the player can accept rather than an instant transaction;
- keep negotiation legible and bounded: no hidden slot-machine bargaining.

**Free-agency compensation picks:** there is currently no compensation-pick system in the contract/free-agency code or national-draft order path. Add one as part of the mature free-agency model rather than pretending the current release/sign flow already represents AFL free agency. The compensation band should be driven materially by the contract the departing player actually receives — especially salary and term — with age/value/eligibility context as appropriate. Do not expose an opaque real-world formula verbatim; give the player a clear projected compensation consequence before a qualifying player signs elsewhere, and ensure AI clubs are evaluated under the same rules. Compensation picks must be inserted into the national draft order deterministically and survive save/reload. Delisted/unrestricted pool players who should not attract compensation must be distinguishable from qualifying free agents rather than every released player automatically generating a pick.

### Free-agent list usability
The Free agents list needs lightweight sort controls suitable for phone browsing:
- **OVR**
- **POT**
- **Age**
- optionally the existing composite/value order as the default

Allow reversing the selected sort where useful. Keep the controls compact; do not add a spreadsheet toolbar.

The screen must also **preserve scroll position after an action**. Right now `OffseasonScene._build()` reconstructs the tab after every signing/re-signing and creates a fresh `ScrollContainer`, which sends the user back to the top of a long list. Capture the current tab's vertical scroll before rebuilding and restore it after the UI is rebuilt (clamped if the list shrank). The same principle should apply to other repeated off-season actions that rebuild the current list.

Additional acceptance:
- signing a free agent never happens from a single immediate term tap;
- free agents can reject/counter offers and salary is genuinely negotiable;
- qualifying departures can generate correctly ordered compensation picks based materially on the accepted contract;
- the Free agents tab can be sorted by OVR, POT and Age;
- after signing/rejecting/negotiating with a player midway down the list, the user remains at approximately the same scroll position instead of being thrown back to the top.

### Rival free-agency order — no first refusal by club order
**Status:** `DONE` — competing visible offers replaced the proposed club-order/reverse-ladder shortcut and merged in PR #172.

When free agency closes, rival clubs sign free agents by walking the clubs in list order (`season.lists`, i.e. `CLUB_ORDER`): each club in turn takes the best free agents it can afford until it reaches `Contracts.AI_FILL`. The clubs early in that order therefore get first refusal on the whole market. With negotiated contracts and compensation picks, that is now a fairness problem, not trivia.

Evidence (3 careers × 4 off-seasons, 2027-2030, real seasons and drafts, 816 rival signings):
- signing **counts** are spread (2-8% per club), because the early clubs fill their lists quickly;
- signing **quality** is not: **60% of each off-season's ten best free agents go to the first four clubs** in list order, and clubs from 13th in the order onwards sign **none** of them;
- mean OVR signed: Brisbane 70.2, Carlton 66.4, Collingwood 64.4 against roughly 53-57 for the clubs late in the order.

Direction: free agency must resolve competing rival interest without `CLUB_ORDER` giving any club priority. Deterministic, using only facts every club has (ladder, list, cap). No uncontrolled randomness, no special treatment for the human club, no auction or bidding system.

Proposed small fix (inside the current resolution code): rival clubs take turns in **reverse-ladder order, the national draft's order**, each turn signing the best free agent it can fit (list below `AI_FILL`, cap room for his price), one signing per turn, until no club can sign anyone. Acceptance: no correlation between a club's place in `CLUB_ORDER` and the quality of free agents it signs over a multi-season sample; same total signings as today.

### Staggered multi-day trade period — equal market access and daily closing decisions (director, 2026-10-07)
**Status:** `TODO`. **Priority:** `P1`. **Autonomy:** `BALANCE-GATED`. Extend ARD-M6-004's existing trade engine and M6-007 postseason flow; do not create a parallel trade market.

The trade period must be a **3–5 trade-day staggered event**, with a **three-day default** matching the director's example: a failed day-one proposal leaves **two more days** to work towards a better deal. These are game stages, not real-world waiting days. If a four/five-day configuration is used, show the total from the start; do not secretly extend the deadline after a failed offer.

**Each day has two clear phases:**
1. **Market reading and submission:** the user reviews the market and submits trade requests/proposals, revises or withdraws pending offers and inspects their status. **All opposition clubs have the same mobility and proposal opportunities as the player club**, under the same asset, cap/list, contract, valuation and player-agency rules. Rivals read the day's publicly observable market and their own scouting/needs/horizons, pursue their own targets, negotiate and submit AI-to-AI or user-involved packages. They must not act as passive shops, receive a hidden handicap or use privileged knowledge of concealed user intentions. Submission does **not** immediately transfer players/picks or finalise a deal.
2. **Close trade day:** once the user deliberately closes the day, collect and resolve the full set of user/rival proposals, with the relevant **clubs and players making final decisions**. Apply genuine player consent/preferences where the existing/intended trade rules require them. Report accepted, rejected, countered, withdrawn or invalidated proposals and completed market moves, with concrete reasons where known. Resolve the day once, persist the results, then open the next day or complete the trade period after the last day.

**Fair resolution is essential:** the human cannot acquire the best assets immediately before opposition clubs have had a chance to read/respond to the market. No human-first or `CLUB_ORDER` first-refusal advantage. Competing proposals for the same player/pick, mutually exclusive packages and changing cap/list/ownership commitments must be considered consistently; do not accept the same asset twice or let processing order secretly decide the market. Define a deterministic, explainable competition/conflict policy using the clubs' genuine valuations and player preferences. Revalidate each final package and apply all sides' asset/contract/cap changes atomically; protect current/future pick ownership and normal draft integration. Do not imply submission guarantees acceptance or let an arbitrary last-second submit confer priority.

**Negotiation across days:** a rejected day-one deal may be revised and resubmitted on day two and, if needed, day three. Show what changed and relevant rejection/counter conditions so a better package can be attempted **if possible**; acceptance is never guaranteed and an asset may legitimately be traded elsewhere at a day's close. Carry eligible pending negotiations forward visibly, with clear expiry/withdrawal rules and current ownership/availability. New offers may respond to the **previous day's resolved market**; do not continually reopen a closed day or allow unlimited instantaneous acquisitions between closings.

Integrate the stage/day counter, proposal ledger, market updates and **Close trade day** action into the existing trade menu. Give a concise first-use tutorial explaining “submit during the day; decisions and transfers happen at the close,” remaining days, package revisions, rival participation and the final deadline. Warn about unresolved proposals before advancing to the end of the period; handle an idle/no-offer day sensibly. Persist current day, pending/countered offers, decisions and resolved moves across save/reload, preventing replay/duplicate transfers. Preserve any separate free-agency competition system rather than silently changing its rules.

**Required verification:** day-one rejection → revised day-two/day-three offer; failure through the final deadline; AI-to-AI and rival competition for user targets; no instant finalisation; competing packages/duplicate assets/cap conflicts; ownership and transaction atomicity; day-close/save-load idempotence; expiry/withdrawal; three-day and any supported four/five-day flow. Measure multi-seed market mobility, acquisition quality, trade volume and human-first/club-order advantage before/after; verify full trade-period → draft/next-season continuity and readable desktop/phone interaction. Reuse existing valuation/trade-volume foundations and tests. Do not mark complete from a day label wrapped around the old instant-accept engine.

### Trade market redesign — picks, asset value and club strategy
The current Trade tab is a prototype rather than a credible AFL trade market. Phone playtesting exposed several linked problems:
- only players can be traded; **draft picks and future picks are absent**;
- each side is arbitrarily capped at **two players**;
- tapping any player rebuilds the screen and jumps the user back to the top, making package construction unpleasant;
- the AI can accept implausible consolidation trades. A concrete example: Adelaide accepted **Jordan Sweet + Ryan Lester for Arki Butler (72 OVR / 92 POT)** even though Sweet was a worse ruck than Adelaide's existing option and Lester was an old defender near the end of his career. A rebuilding/neutral real club should not surrender an elite young asset merely because two lesser player values add up;
- the current need bonus only counts how many players of a role remain (`RUCK < 3`, etc.). It does **not** ask whether the incoming ruck is actually better than the club's existing rucks, so a worse player can receive a positional-need premium.

#### Tradable assets
Support AFL-style packages containing:
- players;
- the club's **current-year National Draft selections**;
- tradable **future National Draft selections**;
- combinations of any of the above on either side.

Remove the hard-coded `pick up to 2` asset limit. Do not replace it with another arbitrary two-item cap; allow realistic multi-asset packages while keeping the phone UI manageable.

Every tradable asset must have a **numerical trade value** used consistently by the trade engine and inspectable enough that the player can understand why a deal is close or far apart. This is a decision aid, not salary=value:
- player trade value should include current football ability, age/career runway, POT/upside, recent/previous-season form and production, injury/availability and durability context, role scarcity/list fit, contract salary **and remaining term**, and relevant honours only insofar as they represent football value;
- salary can raise or lower trade attractiveness depending on whether the contract is good or burdensome; it must never be the player's whole value;
- draft-pick value should be based on pick/round and expected draft position, with future picks valued from the originating club's projected range with uncertainty rather than pretending a future first is already an exact number;
- a package of two mediocre/old assets must not automatically equal one elite young cornerstone simply because raw values add. Apply a credible **consolidation/star premium** or equivalent nonlinear rule so the side giving up the best asset needs a reason to do so.

Do not expose a giant spreadsheet. A compact `Trade value` number per selected asset/package is acceptable because the user has explicitly requested numerical asset values, but keep the primary interaction football-readable.

#### Draft-pick ownership and AFL future-pick rules
Implement actual pick ownership as persistent career state: year + round/selection identity + originating club + current owner. Traded picks must flow into the correct National Draft order and remain owned after save/reload.

Research and model the current AFL men's future-pick framework rather than inventing a generic sports rule. **As of the 2025 rule change, clubs may trade selections from the current National Draft and the following two National Drafts.** The official AFL framework also retains protections including the rolling requirement to use at least **two first-round selections in four years**; trading first-round selections requires board approval; and the furthest future year has additional first-vs-second/third-round holding restrictions. Re-verify the current official AFL rules when implementing in case they change, then encode the football rule itself rather than hard-coding a one-season-only approximation. Board approval can be treated as an eligibility rule rather than pointless confirmation busywork.

The current career begins in 2027, so in a 2027 trade period the normal asset horizon should be the 2027, 2028 and 2029 National Drafts if the contemporary rule is unchanged.

#### Club list-management phase / strategy
AI trade value must depend on what the club is trying to do, using only its own public/roster information — never hidden user intent.

Give each club a simple, recalculated list-management phase such as:
- **Rebuilding:** materially values high/current and future draft picks plus elite young/high-POT players; is reluctant to trade premium youth for established older stars; may move veterans for picks/youth.
- **Building/rising:** values a mixture of young core and targeted established needs.
- **In the premiership window / contending:** places less marginal value on future picks and is more willing to trade good picks/youth depth for established players who improve the best side (18 plus five interchange) now.

Derive this from evidence such as recent ladder/expectation, list quality, age profile, elite-young core and competitive trajectory. Do not assign permanent hand-authored personalities. Recalculate as careers evolve.

A club's position need must be **quality-aware**, not only headcount-aware. If a club already owns a better ruck, receiving an inferior ruck should not get a generic need premium just because it has fewer than three players tagged RUCK.

#### Trade fairness / long-save exploit audit
Treat the Sweet + Lester → Arki Butler acceptance as a concrete regression case. Audit repeated attempts to acquire elite young players/high picks using bundles of older/middling players. The long-save game must resist the familiar management-sim exploit where the human consolidates junk into stars every off-season and becomes unbeatable after a few years.

Acceptance:
- the Butler example is rejected absent substantial additional premium value;
- elite young/high-POT players and premium picks are genuinely expensive, especially to rebuilding clubs;
- contenders can rationally pay picks for established stars;
- rebuilders can rationally sell veterans for picks/youth;
- a worse player at an already-strong position does not receive a fake need premium;
- trade difficulty may change how hard a fair deal is to close, but cannot make obviously irrational deals acceptable;
- repeated long-save AI-vs-user trade probes do not let the user turn low-value bundles into a superteam.

#### Trade UI / navigation
Rebuild the trade interaction around **selected packages**, not two enormous full-list dumps:
- compact selected-assets summary for `You give / You get`;
- browse/add players and picks with useful sort/filter controls;
- clear package value and concise acceptance feedback;
- confirmation before committing a completed trade;
- preserve the current club, package selection **and vertical scroll position** whenever the UI rebuilds after adding/removing an asset. The current `_pick_grid()` calls `_build()` on every tap, which recreates the ScrollContainer and repeatedly throws the user back to the top.

The same scroll-preservation rule now applies across Contracts, Free agents and Trade.


### Research refinement — 2026-10-05

**Dependencies:** merged contract/trade/FA foundations and reconciliation of #223/#224 before overlapping valuation edits. Do not wait for unrelated media or presentation work.

**Smallest scope:** one demonstrated market exploit or missing decision pressure, measured across several years; reuse §9.1 ownership rather than opening another trade redesign.

**Exclusions:** club profit/loss expansion, MTX, psychic AI, hidden rival money, blanket harder-AI discounts or six routine negotiations every offseason.

**Acceptance:** age, current ability, realistic remaining development, role need, cap and picks create understandable competing choices; estimated/scouted upside is not guaranteed value; AI cannot be repeatedly stripped through the same exploit. Useful weak-role players can remain worth retaining. Current and future contracts/pick commitments persist.

**Validation:** reciprocal packages, young/unproven/prime/veteran assets, different club needs and cap states, save migration/in-progress offers, multi-season hold/trade-heavy/youth/veteran comparisons and Android flow. Report realised value as well as projected value. Existing autopilot evidence does not answer active-market advantage.

---



