## ARD-M8-009 — Plausible fictional player names
**Status:** `DONE` — implemented in #149.  
**Priority:** `P1`  
**Autonomy:** `SAFE`

### Trigger
The first generated National Draft immediately breaks immersion with names such as **Fia Drift, Sora Jumble, Gavi Cobble, Hani Orbit, Gilo Orbit and Ivo Orbit**. Several obviously invented surnames repeat within a tiny class.

### Current implementation reality
This is not random bad luck. `GameDB.gd` currently uses a deliberately fantastical alias pool of only **49 first names and 50 surnames**, including `Orbit`, `Jumble`, `Fizz`, `Puddle`, `Gossamer`, `Cobble`, etc. Every first/last combination is shuffled deterministically, so full-name collisions are avoided initially, but the very small surname pool makes repeated surnames unavoidable and the vocabulary itself does not resemble Australian footballers. Generated future prospects have no real-name fallback, so this problem becomes more visible with every long save.

### Direction
Replace the fantasy-word alias system with a large, plausible contemporary Australian player-name generator.

Requirements:
- names should read like believable human names in an Australian national competition;
- use a broad contemporary Australian mix of first names and surnames rather than a narrow Anglo-only list or fantasy syllables;
- greatly expand the pools so a 50-player draft class does not visibly recycle surnames;
- avoid repeated full names across an active career;
- avoid more than an occasional repeated surname within one draft class unless it is intentionally linked to a future family-lineage mechanic;
- generation remains deterministic for a career/seed and stable through save/reload;
- real current players can still use the player's chosen real-name/fictive-name setting, but **generated future players must always receive plausible names**;
- do not use numbered placeholders or artificial sci-fi/fantasy vocabulary;
- future father-son/family systems may intentionally reuse a surname and should be able to bypass the ordinary duplicate-avoidance rule.

### Validation
Generate at least 20 full draft classes and inspect:
- surname repetition per class;
- full-name collisions across decades;
- obviously non-human/novelty combinations;
- name-length/wrapping on 360–390 px screens.

Acceptance: a draft list should look like a plausible list of Australian football prospects at a glance; repeated surnames are uncommon enough to feel notable rather than procedural; long saves do not devolve into obvious recycled-name patterns.

