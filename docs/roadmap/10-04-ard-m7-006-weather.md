## ARD-M7-006 — Weather
**Status:** `PARTIAL` — shared implementation is owned by ARD-M4-016; #449/#473 already provide match conditions, wet/wind effects, breeze-end accuracy and visuals. Do not implement duplicate weather  
**Priority:** `P3`  
**Autonomy:** `BALANCE-GATED`

**Remaining scope check:** verify whether continuous wind direction/strength affecting actual kick distance and the requested ground-ball/disposal-efficiency/stoppage consequences are genuinely modelled, beyond condition-based accuracy/mark/turnover effects. Preserve any absent requirement here as a follow-up under M4-016; keep native-phone and long-sleeve obligations there.

### Wind
- direction/strength affect kick distance/accuracy,
- teams changing ends each quarter changes the effect.

### Wet weather
- fewer clean marks,
- more ground balls,
- lower disposal efficiency,
- more stoppages.

Keep the system compact and legible.

---

## ARD-M7-007 — Ground dimensions & home familiarity
**Status:** `TODO`  
**Priority:** `P3`  
**Autonomy:** `BALANCE-GATED`

Ground dimensions can subtly influence:
- corridor use,
- width/wing play,
- defensive structure.

Home-ground familiarity can provide only a **small** contextual edge.

Do not overpower player/team quality.

---

## ARD-M7-008 — Create a custom draft prospect

### Director playtest follow-up — strengths and weaknesses (2026-10-07)

- **Tattoo and bandaging creator controls — required director correction (`P0` usability follow-up, 2026-10-07):** the shipped None/Light/Heavy controls expose only density, not the requested tattoo library. Reconcile creator controls with the existing rose, snake, barbed wire, bird, 666, love heart, Southern Cross and verified Asian-script lettering requirements. Audit which designs are actually rendered versus persistence/UI placeholders; report incomplete asset work honestly rather than presenting unsupported selections as finished. Provide visual design/placement choices and clear/remove controls, reflected immediately in the live character preview and preserved on save/reopen. Bandaging must allow head, knee, shoulder, elbow and broken-nose tape choices independently, with left/right where relevant and sensible combinations. These replace the Light/Heavy-only bandaging selector; all remain cosmetic. Coordinate renderer/assets with the Art Agent and verify preview-to-match consistency.

- **Live character visualisation — required director usability fix, `P0`, ASAP playtest:** show the complete character throughout creation, using the game's actual player rendering and available appearance options. Update the preview immediately as appearance choices change (including body/height proportions where supported, skin, hair and kit), with enough detail to assess the result. Keep the preview visible alongside active controls on desktop and usable without losing editing context on phone. Display entered name and selected football profile alongside the character, without revealing hidden OVR/POT or implying strengths/weaknesses change physical appearance. The saved character's in-game appearance must match the preview. Verify repeated edits and save/reopen in a runnable playtest build; static screenshots alone are insufficient. Coordinate ARD-M7-008, Club Forge and existing art/UI ownership so both creation flows provide immediate visual feedback rather than walls of controls.

- **Required UI fix (`PARTIAL`):** `Prospects.custom_problem` and the form handlers already reject strength/weakness overlap, but opposite-list choices remain visible; hiding/disabling and clearly refreshing those choices still requires the requested UI completion. Exclude attributes already selected as strengths from the weakness choices, and vice versa. Update both lists immediately as selections change; deselecting an attribute makes it available in the opposite list again. Validate at save/creation too so an attribute cannot be both a strength and weakness. Preserve valid selections and verify repeated select/deselect interactions rather than relying on screenshots.
- **Balance investigation, not an approved rule change:** consider requiring at least one weakness, with a second optional (currently "Weaknesses (up to two)"). Assess whether this creates meaningful tradeoffs across roles/archetypes and the existing hidden talent budget, without granting extra overall power or allowing inconsequential weaknesses to evade the cost. Bring the recommendation and evidence to the director before making a compulsory weakness the default. If adopted, explain the requirement clearly and validate creation with no weakness selected.

**Status:** `PARTIAL` — custom-player creation/generation/draft insertion is on main (#309); cosmetic/preview and specific director follow-ups below remain open.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Director first named use case — Alastair McNeil (2026-10-06)
**Status:** `TODO` for the exact named Alastair McNeil use case and inherited-start verification. The generic feature **is implemented** in #309 (`Prospects.make_custom`, `GameState.add_custom_prospect`/first-class insertion and Club Forge form, with intake/career UI checks). The name is not present in main's stored data/tests; do not invent his profile or treat the whole generic feature as absent.

Include the director's custom **Alastair McNeil** prospect through this feature, with that exact entered name preserved through draft, club moves and career/history screens. Prioritise a minimal functioning named-prospect path rather than waiting for the entire cosmetic library. Use the established custom-prospect generation, one-time hidden POT roll and ordinary National Draft rules; no guaranteed user-club access or special development buffs. Do not substitute the real Lachlan McNeil, fabricate Alastair as a sourced real AFL player, or insert him into official inherited 2026 club lists. Reuse any director-supplied profile details if recorded; where bio/position/appearance choices are unspecified, obtain them through the existing setup choices rather than invent a fixed elite profile.

Ensure the named prospect works in both League-redraft and inherited-list starts, using each mode's proper first National Draft cohort (including the opening 2026 intake for inherited lists). Verify exact-name preservation, single creation, normal AI evaluation and save/resume without duplicate entry.

### Intent
Let the player create a self-insert or fictional prospect who enters the normal AFL draft ecosystem, creating a personal long-term story without turning the feature into a cheat-character creator.

The fantasy is not "build a 99 OVR player". It is:
- create someone you care about,
- watch where they are drafted,
- follow whether they become a star, journeyman, role player or bust,
- see their career interact naturally with clubs, trades, finals, records and retirement.

### V1 scope
At New Career setup, optionally create **one custom prospect** for that career.

Player-facing choices should stay concise:
- name,
- **optional nickname / commentary short name**,
- basic bio fields already supported by the player model,
- height,
- primary position,
- optional secondary position where valid,
- archetype / play style,
- a small set of strengths and weaknesses,
- **dominant foot: Left / Right**,
- **preferred guernsey number**,
- **hair style** from a substantially expanded library, including **Bald**,
- **hair colour**,
- **facial hair** from a dedicated beard/moustache library,
- **facial-hair colour** independently selectable from hair colour,
- **skin tone**,
- **boots** with a small set of silhouettes/colour treatments (black, white and restrained club-colour accents),
- **sock height: Tall socks / Short socks**,
- **headband: On / Off**,
- **bandaging: selectable head, knee, shoulder, elbow and broken-nose tape**, with clear/remove controls and individual placement choices (supersedes the Light/Heavy-only UI, director 2026-10-07),
- **tattoos: selectable original designs and placements from the director-requested motif library below**, with None/remove controls; Light/Heavy density alone does not fulfil the design selector requirement.

All appearance choices are cosmetic only **except dominant foot**, which may affect football behaviour as described below. Cosmetic options must not affect ratings, role suitability, stamina, injuries, aggression, personality or any other football outcome.

### Draft integration
- The custom player enters the **first national draft class** of the career, not the opening League Draft of established AFL players.
- They go through the same draft order and AI evaluation as every other prospect.
- The user's club gets no priority access unless a future explicit father-son / academy mechanic genuinely applies.
- No guaranteed draft position.
- No guaranteed selection by the user's club.
- If undrafted, normal undrafted/carry-over rules apply.

### Generation / balance
The user's choices shape **attribute distribution**, not a guaranteed ceiling.

- Generate the player's starting football ability inside a believable draft-prospect band, with a floor high enough that the created player is at least a genuinely usable AFL role-player prospect rather than a novelty dud.
- Archetype, position, height, strengths and weaknesses redistribute that talent into a coherent football profile.
- **Potential is hidden and randomly rolled once when the career is created.** The player cannot choose it, see it exactly, or reroll it.
- Use a bounded distribution: most custom prospects should project somewhere from useful role player through good AFL player; strong/star outcomes should be uncommon; an **S-tier / generational ceiling is deliberately rare but possible**.
- The rare elite outcome must still require normal development and opportunity. High POT is not guaranteed realised ability.
- Do not grant special development speed, durability, consistency, personality, longevity or career outcomes because the player is custom.
- Preserve the roll in the save so reloads cannot fish for a better ceiling.

A user-created key forward, winger or rebounding defender should feel meaningfully different without one archetype being an exploit.

### Narrative / tracking
Because the point is emotional attachment:
- mark the player as user-created in persistent data,
- preserve the entered name regardless of real-name / fictional-name display mode,
- automatically make their profile easy to find from the draft and career-history flows,
- retain their full career history after retirement,
- surface meaningful milestones through the normal milestone/history systems rather than creating a separate "custom player" ruleset.

A lightweight **Follow / Watch** affordance is preferred over extra bespoke dashboards.

### Guardrails
- Do not let the user assign a club, draft pick, OVR or potential.
- Do not quietly bias AI clubs toward or away from the custom player.
- Do not create a second player-generation pipeline if the existing prospect generator can be parameterised.
- Do not add multiplayer/share-code complexity in V1.
- Do not allow repeated custom-player creation to flood a draft class in V1.
- Preserve save compatibility and deterministic draft-class generation.

### Tests
- custom prospect is created once and persists through save/load,
- enters the correct national draft class,
- uses valid role / secondary-role combinations,
- strengths/weaknesses reshape attributes without escaping normal class power bands,
- AI evaluates/drafts them normally,
- user's club receives no hidden preference,
- undrafted path remains valid,
- career stats/history/milestones work after drafting,
- real-name/fantasy-name setting does not replace the user-entered custom name,
- old saves without custom-prospect data load safely,
- POT is rolled once, survives save/load, cannot be rerolled by reload, respects the usable-role-player floor and can very rarely reach the S-tier ceiling.

---

