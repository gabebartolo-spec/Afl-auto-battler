class_name Potential
extends RefCounted
## Potential (POT): a player's projected natural peak - where his rating is
## expected to settle, not a cap. It is set once, when he enters the game,
## and never moves to match what he later reaches. Development is pulled
## toward it and gets steadily harder near and past it, under the same rules
## for every club; an occasional breakout carries a player beyond it.
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
## Oldest age that still gets a draft-rank ceiling (_draftee_potential).
const MAX_PROSPECT_AGE := 21.0
const AGE_HEADROOM := [[20.0, 16.0], [22.0, 12.0], [24.0, 8.0], [26.0, 4.0], [28.0, 2.0]]

## Share of the gap to POT closed in one off-season, by age. Young players
## close ground fastest; past 28 the age curve (decline) takes over again,
## except in a rehab year.
const GAP_PULL := [[21.0, 0.30], [24.0, 0.22], [28.0, 0.15]]
## The rehab year: a star back from an injury season closes most of the gap
## at the next rollover, whatever his age.
const REHAB_PULL := 0.9
const MIN_STEP := 2.0
## Past 30 a player comes back from an injury season less of the way: the
## rehab pull eases this much per year, never below REHAB_PULL_FLOOR of it.
const REHAB_AGE_EASE := 0.12
const REHAB_PULL_FLOOR := 0.4


static func rehab_pull(age: float) -> float:
	return REHAB_PULL * clampf(1.0 - REHAB_AGE_EASE * maxf(0.0, age - 30.0), REHAB_PULL_FLOOR, 1.0)


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
	# POT is what he can still reach (director, 2026-10-07), not a ceiling
	# from an old season: from 26, when growth is nearly done, it is the
	# best his development can still take him to (a rehab year included).
	# Younger players keep the projection their development pulls toward.
	if float(p.get("age", 26.0)) >= REACHABLE_FROM_AGE:
		p["potential"] = clampi(int(round(reachable_peak(p))), ov, MAX_POT)


## From this age POT is the reachable peak (assign).
const REACHABLE_FROM_AGE := 26.0


## The best rating his development is expected to take him to from now
## (outlook, ten seasons, breakouts aside).
static func reachable_peak(p: Dictionary) -> float:
	var best := float(p.get("overall", 0))
	for season in outlook(p, 10):
		best = maxf(best, float(season[0]))
	return best


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
		pull = maxf(pull, rehab_pull(age))
		p.erase("rehab")
	if pull <= 0.0:
		return 0.0
	# Ratings are rebuilt from whole-number attributes, which lands about a
	# point under the target, so a sub-2 step would never show. Move at
	# least 2 (or the whole gap) while a player is still growing.
	return maxf(gap * pull, minf(gap, MIN_STEP))


## What a player is expected to be worth, season by season, from now: the
## game's own development (Prospects.age_player's age bands and growth toward
## POT, rehab year included) and retirement (Prospects.should_retire), taken
## at their expected values instead of rolled. [[rating, chance he is still
## playing], ...] for `years` seasons, the first the one about to be played.
## Breakouts are left out: nobody can plan on one.
static func outlook(p: Dictionary, years: int) -> Array:
	var r := float(p.get("overall", 50))
	var pot := maxf(r, float(p.get("potential", r)))
	var age := float(p.get("age", 26.0))
	var rehab := bool(p.get("rehab", false))
	var alive := 1.0
	var out := []
	for t in range(years):
		out.append([r, alive])
		age += 1.0
		var d := 0.0
		if age <= 20.0:
			d = 4.25
		elif age <= 23.0:
			d = 2.5
		elif age <= 27.0:
			d = 1.0
		elif age <= 30.0:
			d = 0.0
		elif age <= 33.0:
			d = -1.5
		else:
			d = -3.75
		if age <= 25.0 and r < 55.0:
			d += 1.0
		if age <= 23.0 and r >= 80.0:
			d += 1.0
		var gap := pot - r
		if gap > 0.0:
			var pull := 0.0
			for band in GAP_PULL:
				if age <= float(band[0]):
					pull = float(band[1])
					break
			if rehab:
				pull = maxf(pull, rehab_pull(age))
			if pull > 0.0:
				d = maxf(d, maxf(gap * pull, minf(gap, MIN_STEP)))
		rehab = false
		var next := clampf(r + d, 25.0, 93.0)
		if d > 0.0:
			next = minf(next, maxf(r, pot))
		r = next
		var go := 0.0
		if r <= 32.0 or age >= 37.0:
			go = 1.0
		elif age >= 35.0:
			go = 0.70
		elif age >= 33.0 and r < 42.0:
			go = 0.30
		alive *= 1.0 - go
	return out


## Training price against POT, the same for every club. Well below it a
## stat comes cheaper (down to half price); over the last few points it gets
## dearer; at POT it costs PAST_POT_BASE and every point beyond multiplies
## that by PAST_POT_STEP. No stop: an exceptional player can still be built
## past his projection, but each point costs far more than the last.
const NEAR_POT_GAP := 4
const NEAR_POT_STEP := 0.15
const PAST_POT_BASE := 1.6
const PAST_POT_STEP := 1.7


static func training_multiplier(p: Dictionary) -> float:
	var gap := int(p.get("potential", p.get("overall", 0))) - int(p.get("overall", 0))
	if gap <= 0:
		return PAST_POT_BASE * pow(PAST_POT_STEP, float(-gap))
	if gap < NEAR_POT_GAP:
		return 1.0 + float(NEAR_POT_GAP - gap) * NEAR_POT_STEP
	return clampf(1.0 - float(gap) / 50.0, 0.5, 1.0)


## A breakout: an off-season in which a player jumps well beyond his normal
## development - past his projection if he was near it. Rolled fresh each
## year for every player alike, likelier when young, rare at any age, and
## open-ended: BREAKOUT_MIN plus an exponential tail averaging BREAKOUT_MEAN.
const BREAKOUT_CHANCE := [[22.0, 0.03], [25.0, 0.02], [28.0, 0.01]]
const BREAKOUT_MIN := 2.0
const BREAKOUT_MEAN := 2.5


static func breakout_jump(rng: RandomNumberGenerator) -> float:
	return BREAKOUT_MIN - BREAKOUT_MEAN * log(maxf(1e-6, 1.0 - rng.randf()))


static func breakout_chance(age: float) -> float:
	for band in BREAKOUT_CHANCE:
		if age <= float(band[0]):
			return float(band[1])
	return 0.0


static func _headroom(age: float) -> float:
	for band in AGE_HEADROOM:
		if age <= float(band[0]):
			return float(band[1])
	return 0.0


## Room above the projection by draft rank: +22 for the top pick, about +8
## at the end of a 56-player class (a late pick can still be a gem).
static func _draftee_potential(p: Dictionary, rng: RandomNumberGenerator) -> float:
	# A seasoned player on an expansion list is projected like a draftee but
	# is not an 18-year-old pick: past 21 his ceiling is the one any player
	# his age has. Draft classes are 18-19, so they never reach this.
	var age := float(p.get("age", 18.0))
	if age > MAX_PROSPECT_AGE:
		return float(int(p.get("overall", 50))) + _headroom(age) + rng.randf_range(-2.0, 3.0)
	var rank := clampi(int(p.get("draft_rank", 40)), 1, 80)
	var room := maxf(6.0, 22.0 - 0.25 * float(rank - 1))
	# A strong or weak generated class moves its best prospects' ceilings
	# (Prospects.CLASS_TIERS); the per-player roll still makes busts.
	room += float(p.get("class_ceiling", 0.0))
	return float(int(p.get("overall", 50))) + room + rng.randf_range(-3.0, 3.0)


static func _rng(p: Dictionary) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pot|%s|%s" % [str(p.get("id", "")), str(p.get("draft_year", ""))])
	return rng
