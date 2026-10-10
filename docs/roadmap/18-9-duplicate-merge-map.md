# 9. Duplicate / Merge Map

Before adding any new roadmap line, check this table.

| New wording may sound like... | Canonical home |
|---|---|
| Winning streak / season momentum / team confidence streak | ARD-M4-011 Team Form |
| Match momentum / momentum bar matters | ARD-M4-010 In-match Momentum |
| Scouting card / opponent report / weekly opponent insights | ARD-M4-008 Opponent Preparation |
| Full report / why we lost / coaching summary | ARD-M4-009 Match Report |
| Marquee fixtures / special games | ARD-M7-002 Marquee Games |
| Rivals / rivalry system / dynamic rivalry | ARD-M7-001 Rivalries |
| Retrain positions / learn secondary role | ARD-M5-003 Secondary-position learning |
| Defensive assignment / forward matchup | ARD-M4-002 Match-ups |
| Backup ruck / emergency ruck / depth role | ARD-M1-002 + ARD-M5-005 |
| Oval selection / positional team board | ARD-M5-002 Team Selection |
| Flood / spare behind ball / seventh defender | ARD-M4-004 Structural choices |
| Late-game clock / close out game / protect lead | ARD-M4-006/007 |
| Kick-in restart / kick-in player / kick-in possessions | ARD-M3-009 Kick-ins |
| Set shots / snaps / open-play goals / small-forward scoring | ARD-M3-001/002 Forward scoring |
| Spoils / contested marks / speccies | ARD-M2-005 + ARD-M3-003/005 |
| Pressure / smother / tackle pressure | ARD-M2-006 + ARD-M3-004 |
| I50 / metres / DE / CBA / intercepts / score involvements | M2 Match Event & Stat Foundation |
| GPS / distance covered / km per game / running output | ARD-M2-010 GPS distance covered |
| Player form / match rating by position | ARD-M5-008 Role-aware performance |
| Best on ground / coaches votes / honours / league leaders | ARD-M7-005 History & recognition |
| Injury / visible injury / concussion | ARD-M1-006 + ARD-M3-010 |
| Sim confirmation / skip rounds / don't ask again | ARD-M1-007 Simulation controls |
| Settings / options menu | ARD-M6-005 Options |
| Club colours / green UI / game visual style | ARD-M8-001/002 |
| Cross-platform app/executable/launcher icons and installed app identity | ARD-M8-008 |
| End swaps / wrong-way movement / shot freeze | ARD-M1-004/005 + ARD-M8-003 |
| OOB / last disposal / throw-in / OOF / 50m / frees | M3 AFL Rules & Match Authenticity |
| Wind / rain | ARD-M7-006 Weather |
| Ground size / home ground edge | ARD-M7-007 Venues |
| 22-player side / 4 bench / 5 interchange | ARD-M5-001 |
| Career history / records / Hall of Fame / league leaders | ARD-M7-005 |
| Board satisfaction / job security | ARD-M6-003 Board Confidence |
| Salary cap dollars / realistic salaries / contract money scale | ARD-M6-004 Contracts / trades / free agency |
| VFL / reserves development | ARD-M5-006 Passive reserves |
| OVR correlation / rating predicts strength | ARD-M5-010 |
| Wing/inside-mid/forward identity labels | ARD-M5-009 |
| Create-a-player / self-insert / custom draftee / custom prospect | ARD-M7-008 |
| Cinematic decision scene / tactical close-up / detailed match moment | ARD-M8-007 Cinematic tactical vignettes |
| Draft age filter / rookie-prime-veteran / career-stage filter | ARD-M5-011 |


## Design idea — Unicorn as a synergy wildcard

**Status: DECIDED (director, 2026-10-06), merged with ARD-M5-003 in #266.** Forward, midfield and back earn the Unicorn trait, and he fills one missing place in one synergy. Rarity (POT 90 for a third position) keeps it from becoming a universal buff, as the guardrail below asks.

Explore making the **Unicorn** player archetype a wildcard for list synergies: a Unicorn could satisfy a required player/archetype slot for any synergy, reflecting an unusually versatile football skill set and making that player a flexible piece in the club's "party" composition.

Guardrail: this should **not** mean a Unicorn automatically strengthens every synergy at once or becomes a universal best-in-slot player. The intended value is composition flexibility — potentially satisfying one missing synergy requirement — while the player's actual position, attributes and football performance still matter.

This is deliberately not implementation-ready. Revisit it alongside the broader synergy-system assessment arising from the new game-first / party-CRPG design philosophy.

---

## Design idea — “Spin the MRO wheel”

**Status: VERY MAYBE / idea only.**

Explore a tongue-in-cheek MRO presentation called **“Spin the MRO wheel”**, playing on the familiar footy-fan joke that Match Review Officer suspension outcomes can feel unpredictable or inconsistent.

This is primarily flavour/presentation, not a request to make the underlying MRO system genuinely arbitrary. If ever used, the actual disciplinary logic should remain coherent enough for gameplay while the presentation can wink at the perceived randomness familiar to football supporters.

Hold this idea for the eventual MRO/tribunal design work. Do not implement it merely because it is recorded here.

---

## Design idea — GOAT prospect

**Status: TODO / long-save draft feature.**

In any normal draft, independently of the rare super-draft system, there can be an **exceptionally rare generational / GOAT-level prospect**. This is governed by a **hard spawn cooldown**: once a GOAT prospect is generated, **no other GOAT prospect is eligible to spawn for roughly the next 30 seasons**. After that cooldown expires, eligibility returns; this is not a guarantee that one immediately appears. This must feel extraordinary, not like a recurring draft archetype.

The player must **not be explicitly identified before the draft**. Build anticipation through escalating draft whispers and recruiter/media chatter that allude to unusual ability, development ceiling or combine traits without giving away the prospect's name. The player should have to inspect the draft pool and Combine evidence and make an educated guess about who the rumours describe. Avoid copying the reference game's wording/presentation directly.

If the prospect fulfils that potential, his career economics should reflect genuine superstar scarcity: he eventually commands an **extremely high salary** and becomes **nigh-untradeable** because his club values him accordingly. A trade remains possible only for a genuine **godfather offer**, not through an arbitrary hard lock.

Guardrails: this is **not tied to super drafts**; do not guarantee the GOAT is obvious, Pick 1, or successful; preserve scouting uncertainty and normal career variance; enforce the ~30-season hard spawn cooldown rather than using a simple per-draft random chance that can produce clusters.

---

---

