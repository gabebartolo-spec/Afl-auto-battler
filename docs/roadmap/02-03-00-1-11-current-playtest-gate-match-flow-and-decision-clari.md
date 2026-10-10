## 1.11 Current playtest gate — match flow and decision clarity

### Match stats layout wastes space and requires tedious scrolling — PC playtest (2026-10-07)

**Status (reconciled 2026-10-07): `DONE` for the shared compact match-stats layout in #507.** Current `MatchStatsView` has grouped team comparisons, a player tab, quarter/match scope and shared break/full-time entry points, with real-tap/layout regression checks. The original requirements below remain the acceptance record. This does **not** complete the separate all-metric, competition-wide Season stats patch; those additions remain under its owner. Native-phone review remains where not exercised.

- The director rejects the pictured match-stats page: team totals stretch across the full width with huge gaps between values and metric names, while sparse player rows and oversized section spacing require annoying scrolling. Rework the desktop layout into compact, readable team comparison groups and dense sortable player tables, keeping values close to their labels. Use available width purposefully rather than spreading a three-column comparison across the entire screen.
- Give team totals and player stats direct navigation (for example compact tabs or adjacent panels) rather than forcing users through all team totals to reach the player list. Keep team selection, column headers and sort controls accessible, show clear metric definitions where abbreviations need help, and retain player inspection and all recorded contributions. Reduce padding and row height without sacrificing readability. Apply friendly/opposition identification consistently. This same shared stats design should support the already requested full stats at every quarter break and post-match review.
- Desktop is the platform of this screenshot and playtest. Mobile may require bounded scrolling or responsive column groups, but avoid wasted space and tedious navigation there too. Verify the actual exported PC page at relevant window sizes and scaling. Roadmap comments only; Claude to implement.


