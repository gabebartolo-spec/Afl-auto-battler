class_name Potential
extends RefCounted
## Potential (POT): the overall rating a player can grow into.
##
## The dataset is one season of stats, so a star who missed most of 2026 is
## rated on two or three games and shrunk toward the league average. POT is
## what the development loop pulls toward, so those players - and high draft
## picks - climb quickly, while a player already at his ceiling stays put.
##
##   draftees    from draft rank: the top pick projects near 90
##   AFL players the highest of:
##                 current rating plus age headroom (younger = more room)
##                 recent peak: best 2023-25 rating (8+ games, rated with the
##                   same model), eased for players past 29
##                 draft pedigree: a high national-draft pick pulls a young
##                   player's ceiling up (pick 1 ~90), fading by 25
##   injured     under 12 games in 2026 but 12+ below his recent peak: the
##               2026 rating is a small-sample artefact, so he gets a rehab
##               year (Rozee, Moore, Sam Darcy in the shipped data)
##   overrides   data/potential_overrides.csv, matched on club + real name
##
## History and pedigree come from data/player_history_2026.csv, built by
## tools/build_history.py from AFL Tables and Wikipedia.
##
## Every roll is seeded by player id, so a player's POT is the same on every
## launch and every career.

const MAX_POT := 97
## Generated ceilings stop a few points above each position's best 2026
## rating (MID 92; DEF, FWD and RUCK 87-88 after the key position stretch
## in Ratings.position_stretch), so nobody outgrows his position. History,
## draft pedigree and hand-set overrides are not capped.
const ROLE_CAP := {"MID": 95, "RUCK": 92, "FWD": 92, "DEF": 92}
## An override this far above the current rating marks a rehab case.
const REHAB_GAP := 15
## Automatic rehab: a short 2026 and a recent peak this far above it.
const REHAB_GAMES := 12
const REHAB_PEAK_GAP := 12
## Seasons that count as "recent" for the peak.
const PEAK_FROM_YEAR := 2023
## A 30-year-old's peak is not all coming back: ease it per year past 29.
const PEAK_AGE_EASE := 1.5

## Growth room above the current rating, by age.
const AGE_HEADROOM := [[20.0, 16.0], [22.0, 12.0], [24.0, 8.0], [26.0, 4.0], [28.0, 2.0]]

## Share of the gap to POT closed in one off-season, by age. Young players
## close ground fastest; past 28 the age curve (decline) takes over again,
## except in a rehab year.
const GAP_PULL := [[21.0, 0.30], [24.0, 0.22], [28.0, 0.15]]
## The rehab year: a star back from an injury season closes most of the gap
## at the next rollover, whatever his age.
const REHAB_PULL := 0.9
const MIN_STEP := 2.0


## Set p["potential"] unless an earlier call or a save already did.
static func assign(p: Dictionary) -> void:
	if p.has("potential"):
		return
	var ov := int(p.get("overall", 50))
	var rng := _rng(p)
	var pot: float
	if bool(p.get("projected", false)):
		pot = _draftee_potential(p, rng)
	else:
		pot = float(ov) + _headroom(float(p.get("age", 26.0))) + rng.randf_range(-2.0, 3.0)
	var cap := mini(MAX_POT, int(ROLE_CAP.get(str(p.get("role", "MID")), MAX_POT)))
	pot = clampf(pot, float(ov), float(maxi(ov, cap)))
	# Real history and pedigree are not capped by position.
	var peak := recent_peak(p)
	if peak > 0.0:
		pot = maxf(pot, peak)
		var gm := float(p.get("gm", 0.0))
		if gm > 0.0 and gm < REHAB_GAMES and peak - float(ov) >= REHAB_PEAK_GAP:
			p["rehab"] = true
	pot = maxf(pot, pedigree_potential(p, pot))
	p["potential"] = clampi(int(round(pot)), ov, MAX_POT)


## Best recent season (8+ games), eased for age. 0 when there is none.
static func recent_peak(p: Dictionary) -> float:
	var best := 0.0
	for season in p.get("history", []):
		if int(season[0]) >= PEAK_FROM_YEAR:
			best = maxf(best, float(season[1]))
	if best <= 0.0:
		return 0.0
	var age := float(p.get("age", 26.0))
	return best - PEAK_AGE_EASE * maxf(0.0, age - 29.0)


## A young player's national-draft pick pulls his ceiling toward what that
## pick is expected to become: pick 1 ~90, pick 30 ~81, pick 60 ~72. The
## pull is full at 19 and gone by 25; rookie listings and undrafted players
## get none.
static func pedigree_potential(p: Dictionary, pot: float) -> float:
	if str(p.get("drafted_type", "")) != "national":
		return pot
	var age := float(p.get("age", 26.0))
	var pull := clampf((25.0 - age) / 6.0, 0.0, 1.0) * 0.5
	if pull <= 0.0:
		return pot
	var ceiling := 90.0 - 0.3 * float(maxi(1, int(p.get("drafted_pick", 60))) - 1)
	return pot + (ceiling - pot) * pull if ceiling > pot else pot


## A hand-set POT (data/potential_overrides.csv). Also flags the rehab year
## when the rating sits well below it, so the jump happens next rollover.
static func set_override(p: Dictionary, pot: int) -> void:
	p["potential"] = clampi(pot, int(p.get("overall", 1)), MAX_POT)
	if int(p["potential"]) - int(p.get("overall", 0)) >= REHAB_GAP:
		p["rehab"] = true


## How far a player's rating moves toward POT in one off-season. Positive
## only; decline with age is handled by the caller. Consumes the rehab flag.
static func growth(p: Dictionary, age: float) -> float:
	var gap := float(int(p.get("potential", p.get("overall", 0))) - int(p.get("overall", 0)))
	if gap <= 0.0:
		return 0.0
	var pull := 0.0
	for band in GAP_PULL:
		if age <= float(band[0]):
			pull = float(band[1])
			break
	if bool(p.get("rehab", false)):
		pull = maxf(pull, REHAB_PULL)
		p.erase("rehab")
	if pull <= 0.0:
		return 0.0
	# Ratings are rebuilt from whole-number attributes, which lands about a
	# point under the target, so a sub-2 step would never show. Move at
	# least 2 (or the whole gap) while a player is still growing.
	return maxf(gap * pull, minf(gap, MIN_STEP))


## Training discount: stats come cheaper the further a player sits below his
## POT (down to half price), and cost 50% more once he is past it.
static func training_multiplier(p: Dictionary) -> float:
	var gap := float(int(p.get("potential", p.get("overall", 0))) - int(p.get("overall", 0)))
	if gap <= 0.0:
		return 1.5
	return clampf(1.0 - gap / 50.0, 0.5, 1.0)


static func _headroom(age: float) -> float:
	for band in AGE_HEADROOM:
		if age <= float(band[0]):
			return float(band[1])
	return 0.0


## Room above the projection by draft rank: +22 for the top pick, about +8
## at the end of a 56-player class (a late pick can still be a gem).
static func _draftee_potential(p: Dictionary, rng: RandomNumberGenerator) -> float:
	var rank := clampi(int(p.get("draft_rank", 40)), 1, 80)
	var room := maxf(6.0, 22.0 - 0.25 * float(rank - 1))
	return float(int(p.get("overall", 50))) + room + rng.randf_range(-3.0, 3.0)


static func _rng(p: Dictionary) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pot|%s|%s" % [str(p.get("id", "")), str(p.get("draft_year", ""))])
	return rng
