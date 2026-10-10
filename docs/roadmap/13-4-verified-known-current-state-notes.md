# 4. Verified / Known Current-State Notes

These are here to stop Claude from rebuilding things that already exist. **Verify against the current branch before acting because the repo evolves.**

- Inside 50s are already tracked at player/team level.
- Goal conversion uses the actual shooter rather than a team-wide accuracy average.
- Open-play scoring is structurally possible in MatchSim, and PR #50 made open-play shots remain live in presentation; the broader scoring-model variety under M3-001 is still partial.
- In-match Momentum is now a real capped/fading MatchSim mechanic, and the meter reads engine state directly (PR #102).
- Free kicks exist in simplified form.
- Concussion now enforces a minimum two-match absence with AI parity and save persistence (PR #51).
- Wildcard finals/top-10 finals structure already exists; do not add another wildcard-finals feature.
- Matchday squad was 18 + 4 interchange; migrated to 18 + 5 in #331 (ARD-M5-001).
- "Play through" now favours possession-chain/transition involvement without generic shooter bias (PR #48).
- Player/team metres gained are accumulated from actual forward ball movement (PR #55).
- Effective disposals and Disposal Efficiency are tracked from actual disposal outcomes (PR #55).
- OOB/out-on-full/throw-in/last-disposal have not historically existed as a complete event path.
- Forward-50 spoils are now explicit loose-ball events with player/team credits; general-play spoils remain incomplete (PR #83).
- Coaching staff/career-history work has already begun; inspect current main/active PRs before creating new staff architecture.
- Wildcard finals are **not** backlog work unless the competition rules change.

---

