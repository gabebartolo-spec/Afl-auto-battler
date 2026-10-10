### Club Forge usability repair — highest director priority, ready to playtest ASAP

**Implementation reconciliation (2026-10-07): `DONE` for the club-creation flow repair (#493/#498).** The director-selected paint flow is on main: choose a design, use one palette, paint body/pattern/trim via preview or explicit part targets. The preview is live; the obsolete slot form has been removed. This does not close the separate Create a player preview, tattoo/bandaging requests, expansion/data-library gaps or unexercised phone checks.

**Status:** `DONE` — club paint-flow repair merged in #493/#498. **Priority:** `P0` (historical escalation; Stats now has the single highest priority). **Scope:** existing ARD-M7-009 Club Forge, coordinated with STYLE-07 desktop scaling and current UI/art owners. Deliver a focused playable fix for the director as soon as possible, before a broad cosmetic redesign.

**Player evidence:** the director's fullscreen Club Forge screenshots show sprawling grids of home/place choices, three colour palettes and text-only guernsey options. Colour blocks cannot be deselected, there is no visible preview while configuring the club, and excessive controls obscure the content being created. The director calls the flow seriously unintuitive and wants to test the repair ASAP.

**Required outcome / acceptance:**
- **Confirmed colour-editing interaction bug (director playtest, 2026-10-07):** after allocating colours, the player must select a different guernsey design before colours can be allocated again. Fix stale selection/control state so colours can be changed repeatedly while retaining the same design. Reproduce and verify the exact flow: choose a design → allocate colours → change each colour repeatedly → clear/reapply optional colours → save/reopen, without switching designs. Add a meaningful regression check for this interaction; a static screenshot or initial successful selection is insufficient.
- Make optional colour slots explicitly clearable (`None`/clear or toggle-off); make selected colours and slot labels obvious. Explain any genuinely required base colour rather than trapping the player in an unexplained selection. Allow changing choices without restarting.
- Keep a live club/guernsey preview visible while editing colours and pattern; update it immediately on each relevant selection. Show the actual selected design with the existing game rendering/assets, not a disconnected placeholder. Include the club name/identity as it is entered.
- Replace the wall of oversized controls with a compact, clearly ordered creation flow. Group identity, colours and kit options; disclose secondary choices when needed. Provide clear Back/Save actions and useful validation while retaining existing creation choices.
- Verify both desktop fullscreen and target phone layouts: readable text, sensible spacing, accessible touch targets, preview and active controls usable together, no excessive scrolling through empty or repetitive UI.
- Prove save/reopen preserves the chosen identity, colours and guernsey and the in-game club matches the preview. Supply a runnable playtest build plus a short before/after walkthrough to the director ASAP; screenshots alone do not establish that selecting, clearing and previewing work.

This is an explicitly requested usability fix, not an optional Art Agent resource. Preserve existing saved clubs and coordinate shared UI files; do not wait for unrelated feature or art polish work.


**Status:** `IN PROGRESS`  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED`

The current phone playtest has exposed a core-loop problem more important than feature expansion. **Pause unrelated new feature work until this gate is addressed.** Existing PRs may finish through CI/merge, but the next development work should focus on the failures below rather than advancing the roadmap for completion's sake.

