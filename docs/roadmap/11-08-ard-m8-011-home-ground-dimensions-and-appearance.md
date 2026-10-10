## ARD-M8-011 — Home ground dimensions and appearance in the visual simulation
**Status:** `TODO` — director request 2026-10-10, not started, not assigned. Scheduling: the director.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED` — presentation first; any change to football outcomes is balance-gated and separate.

### Director's words (2026-10-10)
"I want the dimensions and appearance of the visual simulation to change based on the home ground (only AFL listed grounds will be necessary, aka MCG, Marvel Stadium, Optus Stadium, Adelaide Oval, Metricon, GMHBA, SCG, etc)."

### Requirement
- The match's venue (the fixture's home ground; `data/clubs.csv` `ground`, `Season._assign_venues`, Grand Final at the MCG) sets the oval's dimensions and look in the visual simulation and the vignettes.
- Scope: the grounds the AFL clubs play home games at. Current `ground` column: MCG, Marvel Stadium, Optus Stadium, Adelaide Oval, The Gabba, People First Stadium (Metricon), GMHBA Stadium, SCG, Engie Stadium, plus the fictional clubs' Bellerive Oval and Manuka Oval. Other grounds fall back to a default oval.
- Dimensions: each ground's real playing-surface length and width shape the oval (MCG long and wide, GMHBA long and narrow, Adelaide Oval long, SCG short). The owner verifies the figures against the AFL's published ground dimensions before use.
- Appearance: each ground reads as itself at game scale: roof or open air, stand shape and colour, turf tone, boundary and signage treatment, crowd colour balance (home club). Shared rendered plates and the existing 2.5D art (`memory: rendered-plates-not-drawn-rooms`); no bespoke per-ground UI.
- Extends the "Stadium identity" wishlist item (§1.11 observed failures) and ARD-M8-003/ARD-M8-007 match visualisation; the MCG plate in progress (art) is the first ground.

### Facts
- Today one oval: `VignetteGround` A 68 / L 80 (a 160 x 136 m oval) for every match; `Ratings.T` `goal_line` 85 and `forward50_line` 35 are sim coordinates, not metres.
- Changing the drawn oval alone does not change football outcomes. Letting ground size affect play (scoring, marking, running) is a separate balance-gated decision for the director.

### Open questions (confirm with the director when scheduled)
1. Presentation only, or do ground dimensions also affect the simulation (calibrated against each ground's real scoring)?
2. Fictional clubs' grounds (Tasmania, Canberra): real Bellerive and Manuka, or the default oval?

### Acceptance
- A match at each listed ground shows that ground's proportions and look in the pitch view and the vignettes; a footy fan recognises the MCG, Marvel, Optus, Adelaide Oval, the Gabba, GMHBA and the SCG without the name.
- The home/away venue from the fixture is the one drawn, including finals and the Grand Final at the MCG; a save made before the change loads and draws the right ground.
- Captures of every listed ground at phone and desktop sizes pass the lead's art check and the director's look. Seeded match results unchanged unless question 1 is answered yes and recorded here.

---
