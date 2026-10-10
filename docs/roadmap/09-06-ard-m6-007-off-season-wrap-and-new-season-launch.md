## ARD-M6-007 — Off-season wrap and new-season launch
**Status:** `DONE` — implemented in #158.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Trigger
Completing the National Draft currently calls `finish_intake_draft()` → `_start_next_season()` immediately. The game therefore jumps straight from the final draft pick into Round 1 of the new season with no transition, despite a large amount of list-management state having just changed.

### Intent
Give the off-season a proper conclusion and the new season a deliberate beginning.

After the National Draft is completed — and **before** the player is dropped into the normal Round 1 hub — show a concise **Off-season wrap / New season briefing**.

### Ins / Outs summary
Summarise what actually changed at the user's club across the whole off-season, not only the draft:
- **Ins:** traded-in players, free-agent signings, National Draft selections and any other genuine list additions;
- **Outs:** trades out, delistings/releases, free-agent departures, retirements and other permanent list exits;
- show draft pick number next to drafted players where useful;
- include notable staff changes in a separate coaching line/block when they occurred;
- if nothing happened in one category, omit it rather than showing empty furniture.

Reuse persistent transactional state rather than reconstructing it from guesses. `offseason_log` already captures some releases/signings/trades, draft history carries selections, retirement/intake summary contains retirements, and coach records/news capture coaching movement. Extend the smallest durable season-transition ledger needed so the wrap survives save/reload.

### Board expectation reveal
The same transition should reveal the board's **upcoming-season expectation** after the new list has been assembled and the expectation model has run.

Show:
- the actual goal in plain football language;
- a short reason for it, grounded in the expectation-fairness model (e.g. list quality, previous finish/trajectory, rebuild/contending state);
- current job-security state only if materially relevant.

This is the moment the player should learn “the board expects finals/top four/seven wins”, not by stumbling across it later in Coaching.

Do not turn this into another dashboard. The purpose is:
**What changed? What does the club expect now? Then begin the season.**

### Presentation
Give the transition enough ceremony to feel like the end of one management phase and the start of another, while staying phone-friendly:
1. Off-season complete.
2. Ins / Outs.
3. Any notable coaching movement at your club.
4. Board expectation for the new season.
5. **Begin season**.

A one-screen scroll or short staged flow is fine. No forced slideshow.

### Acceptance
- finishing the draft never silently drops the player into Round 1;
- every genuine player addition/removal from that off-season can be accounted for in the wrap;
- draft picks are correctly identified;
- notable staff changes are surfaced if they occurred;
- the board's new-season goal and a concise reason are shown before Round 1 begins;
- save/reload at the transition cannot duplicate transactions or skip the briefing;
- long saves retain a clear year-to-year sense of roster change without number vomit.

