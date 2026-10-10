## ARD-M7-004 — Captaincy / leadership
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `BALANCE-GATED`

Give captaincy modest football meaning:
- composure during swings,
- late-game stability,
- morale/leadership context.

Avoid blanket attribute boosts.

### Director consideration — Leadership as a player stat
Consider adding **Leadership as a numerical player stat, not a trait**, as part of this captaincy design. Claude should refine the concept and assess the smallest useful implementation before committing to exact values or effects.

Represent football leadership independently of playing ability, OVR, age and captain appointment: a strong leader need not be the best player, and appointing a captain should not automatically grant high Leadership. Explore how the stat can support the bounded composure, late-game stability and morale contexts above, with credible costs/limits and equal rules for AI clubs. Avoid blanket team/attribute buffs, guaranteed comebacks, or making the highest Leadership an automatic optimal captain in every context.

Define what the stat measures, how real and generated players receive credible values, whether/how it develops, and how it is shown on player profiles and captain selection. Be honest about uncertain real-player assessments rather than inventing precise evidence. Inspect the existing captaincy/player-stat foundations first; design appointment, replacement/absence and historical continuity together so the stat is not an isolated decorative number. If persisted, specify backward-compatible defaults for existing saves.

**Director leadership ideas — concepts for Claude to refine, not fixed mechanics:**
- **On-field coach:** a strong leader could increase gameplan potency through better organisation/execution. Tie any measured benefit to the actual chosen plan, relevant personnel and the leader's participation, rather than an unconditional team-wide boost.
- **Leads by example:** leadership could support a captain's goal in a clutch moment or last-quarter heroics. Preserve the player's genuine football ability, opportunity and match events; influence tendencies/composure where justified, never script a guaranteed goal, win or comeback. Report a leadership moment only when it actually occurs.
- **Club culture and appeal:** leadership could improve teammate morale, willingness to **re-sign** with the club, and the club's attractiveness to free agents or players considering a trade. Integrate with existing morale, contracts and recruitment decisions; leadership should be one bounded factor alongside money, opportunity, club direction and player preferences, never forced loyalty or guaranteed recruitment.

These are possible expressions of the numerical Leadership stat, not a request to create three mandatory traits or parallel systems. Claude should assess overlap with coaches, existing composure/clutch behaviour, morale and club reputation before choosing the smallest useful design. Recruitment/retention effects must respect player agency, existing trade rules and AI parity; measure balance and long-save effects as well as match effects.

**Director leadership-trait ideas — alongside the Leadership stat:**
- **Tough:** teammates are slightly more effective while fatigued; modestly soften the existing fatigue penalty rather than erase fatigue, improve fresh-player performance or encourage unsafe injury behaviour.
- **Drives Standards:** teammates gain a small amount of additional XP from actual training, through the existing training/development system and within normal potential/development limits.
- **Unders Culture:** players may be slightly more willing to sign cheaper deals, through existing contract willingness/valuation. Preserve player choice, salary rules and other contract factors; no automatic discounts or forced acceptance.

**All leadership buffs must be small**, including the gameplan, clutch, morale, retention and recruitment ideas above. These trait names/effects are design suggestions for Claude to refine, not immediate stat adjustments. Define who can carry a leadership trait and when its influence applies (captain/leadership role, active participation and absences); distinguish the quantitative Leadership stat from the style of influence. Keep effects transparent and bounded, avoid double-counting existing traits/coaches/culture, and cap stacking from multiple leaders or co-captains so several small bonuses cannot become a large team advantage. Validate fatigue curves, training progression and contract/long-save economy with AI parity before rollout.

Acceptance for any eventual implementation: Leadership is a distinct readable stat; any claimed effect is modest, observable and measured in relevant match/morale contexts; captain assignment and transitions are understandable; invalid/absent captains and older saves are handled safely. Keep this a design follow-up, not an instruction to apply immediate ratings changes.

### Research refinement — 2026-10-05

**Dependencies:** current player identity/morale and trustworthy match-state events.

**Smallest scope:** one modest football leadership context with an observable effect.

**Exclusions:** blanket attribute boosts, automatic captain-superstar status, forced comeback stories or a new relationship subsystem.

**Acceptance:** the player understands the captain's role and its bounded limits; age/playing quality does not silently determine all leadership value; the same mechanics apply to AI clubs; captaincy transitions preserve earlier career facts.

**Validation:** equal-personnel/seed comparisons, leading/chasing/quiet contexts, persistence and Android explanation. Distinguish a measured leadership effect from a coincidental late win.

---

