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
##   AFL players current rating plus age headroom (younger = more room)
##   overrides   data/potential_overrides.csv, matched on club + real name.
##               This is how an injured star gets his ceiling back: one short
##               season's stats cannot tell him apart from a fringe player
##               who was not picked (both are shrunk toward the average), so
##               only a hand-set POT can. A big gap also earns a rehab year.
##
## Every roll is seeded by player id, so a player's POT is the same on every
## launch and every career.

const MAX_POT := 97
## Ratings run on different scales by position: the best 2026 midfielder
## rates 92, the best key defender 72. Generated ceilings stop a few points
## above each position's best, so a prospect never outgrows his position.
## Hand-set overrides are not capped.
const ROLE_CAP := {"MID": 95, "RUCK": 89, "FWD": 80, "DEF": 77}
## An override this far above the current rating marks a rehab case.
const REHAB_GAP := 15

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
	p["potential"] = clampi(int(round(pot)), ov, maxi(ov, cap))


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
