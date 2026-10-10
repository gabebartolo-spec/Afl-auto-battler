## ARD-M8-004 — Main menu / onboarding
**Status:** `PARTIAL` — main menu/onboarding foundation is DONE (#208); the newly requested Exit game button below is TODO (director, 2026-10-07).  
**Priority:** `P2`  
**Autonomy:** `SAFE`

Main menu should remain minimal:
- title/logo,
- optional exact tagline: **Build your dynasty.**
- Continue only when save exists,
- New Career,
- quiet How to Play / Settings,
- **Exit game** — a clearly labelled, reachable main-menu button (director request, 2026-10-07; `TODO`). Close the native application cleanly using the existing shutdown/save path; preserve the current career and settings, without starting a new career or deleting a save. Keep the action visually secondary and consistent with the compact menu on desktop and Android. If the browser export cannot close its own tab, provide a truthful supported fallback rather than a non-working button. Verify button activation, normal shutdown and successful relaunch/Continue with saved state; do not mark this new follow-up DONE because the older main menu is complete.

### Selective onboarding — essential and alternative interactions (director clarification, 2026-10-07)
**Status:** `TODO` for coverage verification and missing explanations. This clarification supersedes the earlier requirement to introduce every individual button/interaction. Extend the existing tutorial system and apply this rule to new UI work.

**Avoid onboarding bombardment for CLEARLY obvious UI functionality.** Ordinary labelled navigation, Back/Close and self-explanatory buttons do not each need a popup or walkthrough. Keep accessible contextual Help, but do not interrupt play merely to explain a control whose purpose and operation are already apparent.

**All alternative, hidden or essential interactions must have explicit explanations**, including **multi-select, long press**, tap-to-swap/drag alternatives where discovery is unclear, and **important gameplay levers**. Essential decision workflows must explain what the player needs to do, why it matters and the consequences of advancing. A familiar-looking button does not make its football mechanic self-explanatory.

Introduce these interactions briefly at the first relevant point of use, anchored to the actual control. State how to perform the action, what it changes, relevant conditions/tradeoffs and how to undo/cancel where needed, using plain concrete football language and accurate current labels. Group related explanations, defer them until relevant and avoid repeated interruptions or a huge first-launch tutorial. The **Play round long press** remains an explicit required introduction; players must not have to guess that hidden quick-sim gesture.

Preserve Tutorials On/Off, skip/dismiss and replayable contextual Help. Track per-career introductions safely across save/reload; verify first encounter, later revisit, disabled/re-enabled tutorials, desktop/phone alternatives and new features on older saves. Maintain a coverage map separating **obvious controls needing no interruption** from **essential/alternative interactions requiring an explicit explanation**, with evidence and any remaining gaps. Do not use “obvious” to omit a hidden gesture or an important gameplay lever.

### First postseason after finals — cadence, recruitment and Combine literacy (director, 2026-10-07)
**Status:** `TODO` — extend the existing M8-004 onboarding and M6-007 postseason flow, with M5-014 Combine and M6-004 trade/contract owners. Apply selective onboarding: explain essential decisions without introducing every obvious button.

On a **fresh career's first postseason, once the finals are over**, introduce the postseason cadence and order before the player begins its management decisions. A club eliminated early must not receive a misleading “finals are over” introduction while the competition finals are still running. Explain the actual implemented sequence, what is available now versus later, which decisions are mandatory/optional, relevant deadlines and what each advancement action closes or unlocks. Show a compact stage overview and contextual introductions as each complex stage opens; preserve position/progress and provide replayable Help. Read the current state machine first: do not teach an assumed AFL calendar or a stale menu order.

**Combine interpretation:** at the first relevant Combine encounter, explain the measured tests/results, units and relative comparisons that actually exist, how they connect to football roles and strengths/limitations, and how to inspect/sort/filter prospects. Distinguish athletic testing, recorded football production and uncertain scouting/OVR/POT projections. Use concise grounded examples to help the player judge role/list fit and development uncertainty; an athletic standout is not automatically a better footballer or a guaranteed high-upside pick. Explain how to carry those observations into draft choices without prescribing the best prospect, revealing hidden talent or presenting unsupported results. Coordinate the complete navigable Combine menu rather than tutorialising an absent screen as if it shipped.

**Trade and contract tutorials must be concise, accurate and specific — never vague.** Walk through each menu's real decision structure in small contextual steps:
- **Contracts:** explain the current offer terms, salary/cap commitment and contract length, negotiating versus confirming, rejection/counter-offer behaviour where implemented, expiry/re-sign/release choices and the consequence of advancing. Use the actual displayed values and authoritative rules; do not imply acceptance before agreement or invent an option.
- **Trades:** explain selecting the partner, incoming/outgoing players and current/future picks, ownership/eligibility, any current salary/list constraints, proposing versus accepting/finalising, and what the displayed valuation/scouting information means and does not guarantee. State the real reason an offer is invalid or rejected where available; avoid generic “manage your list” or “get a better deal” filler.
- Explain free agency/compensation and related recruitment stages when actually encountered, using implemented eligibility and commitment rules. Keep coach opportunity-retention distinct from monetary player contract talks.
- Give each step a concrete action and consequence, with an optional worked example and deeper Help for complex rules. Do not bury the user in formulas, dense paragraphs or repeated popups; brevity must not omit material costs, deadlines or commitments.

Verify a fresh-save first-postseason walkthrough from finals completion through recruitment/Combine/draft to the next season, using the actual order and full onboarding enabled. Check early elimination, first-year flags, save/reload mid-stage, tutorial skip/off/replay, actual offer/trade confirmations and desktop/phone readability. Provide stage/copy coverage and record unimplemented paths honestly. Do not mark complete from a welcome popup or copy review without checking the real flow.

### Full fresh-save onboarding — initial draft, weekly loop and postseason (director, 2026-10-07)
**Status:** `TODO` — audit and complete missing coverage, extending the existing onboarding/tutorial system and §1.11 first-visit menu tutorials. The older Hub onboarding foundation remains DONE.

Walk through genuinely **fresh saves with full onboarding enabled**, not a mature save with tutorial flags already set. Verify all three complete flows:
- **Initial draft:** career/setup choices and entry, pool navigation/scouting/filters, list needs, selection, cap/list completion and the transition into the first week. Cover each implemented career-start mode and record modes not yet available rather than inventing their onboarding.
- **Weekly flow:** Hub → opposition/preparation → lineup/roles/synergies → training/development → match or sim → result/review → next week. Explain relevant actions when first encountered, including new menus and real constraints, without prescribing winning choices.
- **Postseason flow:** home-and-away finish/finals → season review/awards → staff/list/contracts/trades/free agency and draft preparation/Combine → National Draft → next season, following the actual implemented order. Explain deadlines, mandatory decisions, navigation and the consequences of advancing; avoid unexplained jumps or missing handoffs.

Audit **all onboarding copy** for clear, informative, concrete football language: what is happening, what the user can do, what they must resolve, and what happens next. Check it against current controls/mechanics and the gameplay-lever copy audit; remove stale labels, vague instructions, contradictions, repetitive filler and unsupported promises. Keep steps short and contextual, with optional deeper detail and grounded flavour, rather than a wall of text.

Verify the Tutorials On/Off preference, skip/dismiss/replay Help behaviour, once-only/per-career flags, save/reload/resume, navigation back, desktop/phone fit and taps. Skipping help must not skip football decisions or progression requirements. Produce a flow/step coverage record and evidence of a complete first-career walkthrough; repair genuine missing/misleading steps and record unavailable/unexercised paths honestly. Do not declare full onboarding complete because one Hub popup exists. Preserve existing M5-014/M6-007 flow ownership; no duplicate onboarding engine.

Onboarding should explain the weekly loop contextually, be skippable, and avoid a giant tutorial.

---

