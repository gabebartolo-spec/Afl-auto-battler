class_name Prospects
extends RefCounted
## End-of-season intake support: draft-class projections, generated future
## classes, and season-over-season development (growth, decline, retirement).
##
## Draftees have no AFL season stats, so their ratings are PROJECTED rather
## than derived: a consensus-rank band sets a target overall, a role template
## and the prospect's reported U18 numbers shape the attribute profile, and a
## bisection fits those attributes to the target through the shipped
## Ratings model. From there the match engine treats prospects exactly like
## real players - same attributes, roles, salary bands and maths.
##
## The 2026 class ships from data/draftees_2026.csv; every later class is
## generated deterministically from its year so careers can loop forever.

const MIN_LIST := 32
const MAX_RETIRE_PER_CLUB := 8

const ATTR_KEYS := ["disposal", "contested", "marking", "pressure", "intercept",
		"carry", "goalkicking", "accuracy", "creating", "ruck", "discipline",
		"durability", "star"]

## Consensus-rank taper: pick 1 projects as an impact rookie, the back half of
## the draft as fringe/development talent. Deliberately below the best 2026
## pros (90s) - a top pick should enter the list around a solid rotation
## player, and the training/development loop carries them up from there.
const RANK_BANDS := [[1, 70.0], [10, 64.0], [20, 61.0], [30, 58.0],
		[40, 55.0], [50, 52.0], [64, 47.0]]

const ROLE_DELTAS := {
	"MID": {"disposal": 6.0, "contested": 5.0, "pressure": 3.0, "carry": 4.0,
			"creating": 2.0, "marking": -1.0, "goalkicking": -3.0, "intercept": 0.0,
			"accuracy": -4.0, "discipline": -1.0, "star": 0.0, "durability": 0.0,
			"ruck": -30.0},
	"DEF": {"intercept": 8.0, "pressure": 6.0, "marking": 4.0, "disposal": 1.0,
			"accuracy": -5.0, "goalkicking": -8.0, "creating": -4.0, "carry": -3.0,
			"contested": 1.0, "discipline": 0.0, "star": 0.0, "durability": 0.0,
			"ruck": -30.0},
	"FWD": {"goalkicking": 8.0, "marking": 5.0, "accuracy": 3.0, "creating": 4.0,
			"disposal": -1.0, "intercept": -4.0, "pressure": 2.0, "carry": 1.0,
			"contested": 0.0, "discipline": 0.0, "star": 0.0, "durability": 0.0,
			"ruck": -24.0},
	"RUCK": {"ruck": 26.0, "contested": 8.0, "marking": 3.0, "disposal": -5.0,
			"goalkicking": -1.0, "intercept": -3.0, "pressure": 0.0, "carry": -5.0,
			"accuracy": -5.0, "creating": -2.0, "discipline": -2.0, "star": 0.0,
			"durability": 1.0},
}

const JUNIOR_TEAMS := [
	["Sandringham Dragons", "Talent League", "VICM"],
	["Northern Knights", "Talent League", "VICM"],
	["Dandenong Stingrays", "Talent League", "VICC"],
	["Gippsland Power", "Talent League", "VICC"],
	["Eastern Ranges", "Talent League", "VICM"],
	["Calder Cannons", "Talent League", "VICM"],
	["Oakleigh Chargers", "Talent League", "VICM"],
	["GWV Rebels", "Talent League", "VICC"],
	["Bendigo Pioneers", "Talent League", "VICC"],
	["Geelong Falcons", "Talent League", "VICC"],
	["Murray Bushrangers", "Talent League", "VICM"],
	["Swan Districts", "WAFL", "WA"],
	["Claremont", "WAFL", "WA"],
	["East Perth", "WAFL", "WA"],
	["Subiaco", "WAFL", "WA"],
	["South Adelaide", "SANFL", "SA"],
	["North Adelaide", "SANFL", "SA"],
	["Woodville-West Torrens", "SANFL", "SA"],
	["Central District", "SANFL", "SA"],
	["Glenelg", "SANFL", "SA"],
	["West Adelaide", "SANFL", "SA"],
	["Lions Academy", "Talent League", "QLD"],
	["Suns Academy", "Talent League", "QLD"],
	["GIANTS Academy", "Talent League", "NSW"],
	["AS Academies", "Talent League", "NSW"],
	["Tasmania Devils", "Talent League", "TAS"],
]


# ---------------------------------------------------------------------------
# Projection
# ---------------------------------------------------------------------------
## Piecewise-linear rank taper with a floor; ranks beyond the list keep
## sliding down so generated classes and bubble names use the same curve.
static func rank_base_overall(rank: int) -> float:
	if rank <= 1:
		return float(RANK_BANDS[0][1])
	var prev_r := int(RANK_BANDS[0][0])
	var prev_v := float(RANK_BANDS[0][1])
	for band in RANK_BANDS.slice(1):
		var r := int(band[0])
		var v := float(band[1])
		if rank <= r:
			return prev_v + (v - prev_v) * float(rank - prev_r) / float(r - prev_r)
		prev_r = r
		prev_v = v
	return maxf(42.0, prev_v - float(rank - prev_r) * 0.18)


## Mutates a prospect dict with projected attr / role / overall / value.
static func project(p: Dictionary) -> void:
	var rng := _rng_for("%s|%s" % [str(p.get("id", "")), str(p.get("draft_year", 2026))])
	var rank := int(p.get("draft_rank", 0))
	var role := str(p.get("role", "MID"))
	var target := rank_base_overall(rank)

	# Reported U18 production lifts the floor, capped so a stat-stuffing
	# Talent League season can never out-project a 20-game AFL pro.
	var gm := float(p.get("u18_gm", 0.0))
	var di := float(p.get("u18_di", 0.0))
	var gl := float(p.get("u18_gl", 0.0))
	var ho := float(p.get("u18_ho", 0.0))
	var tk := float(p.get("u18_tk", 0.0))
	var mk := float(p.get("u18_mk", 0.0))
	if di >= 18.0:
		target += minf(3.0, (di - 18.0) * 0.25)
	if role == "FWD" and gl >= 1.5:
		target += minf(3.0, (gl - 1.5) * 0.8)
	if role == "RUCK" and ho >= 15.0:
		target += minf(3.0, (ho - 15.0) * 0.15)
	if tk >= 5.0:
		target += minf(2.0, (tk - 5.0) * 0.3)
	if (role == "DEF" or role == "FWD") and mk >= 5.0:
		target += minf(2.0, (mk - 5.0) * 0.25)
	var height := float(p.get("height_cm", 0.0))
	if role == "RUCK":
		if height >= 200.0:
			target += 1.5
		elif height > 0.0 and height < 192.0:
			target -= 1.5
	elif height >= 190.0 and (role == "FWD" or role == "DEF"):
		target += 1.0
	var age := float(p.get("age", 18.0))
	if age >= 19.0:
		target += 1.0  # over-age means proven, at a small trade-off in ceiling
	target += rng.randf_range(-1.5, 1.5)
	target = clampf(target, 38.0, 74.0)

	# Attributes: centre on the target, apply the role template, then let the
	# raw season numbers nudge the parts the projection actually claims.
	var a := {}
	for key in ATTR_KEYS:
		a[key] = target
	var deltas: Dictionary = ROLE_DELTAS.get(role, ROLE_DELTAS["MID"])
	for key in deltas:
		a[key] = float(a[key]) + float(deltas[key])
	if di > 0.0:
		a["disposal"] = float(a["disposal"]) + clampf((di - 16.0) * 0.8, -4.0, 10.0)
	if gl > 0.0:
		a["goalkicking"] = float(a["goalkicking"]) + clampf((gl - 1.2) * 2.2, -3.0, 12.0)
	if mk > 0.0:
		a["marking"] = float(a["marking"]) + clampf((mk - 3.0) * 1.5, -2.0, 8.0)
	if ho > 0.0 and role == "RUCK":
		a["ruck"] = float(a["ruck"]) + clampf((ho - 10.0) * 0.8, 0.0, 14.0)
	if tk > 0.0:
		a["pressure"] = float(a["pressure"]) + clampf((tk - 3.0) * 1.0, 0.0, 8.0)
	# No Brownlow votes yet: star stays below the pack, durability is
	# unproven by definition. Both are set before the fit, then rebalanced.
	a["star"] = clampf(target - 10.0 + rng.randf_range(-4.0, 4.0), 20.0, 74.0)
	a["durability"] = clampf(24.0 + gm * 1.8, 24.0, 62.0)

	a = fit_attributes(a, role, target)
	for key in a:
		a[key] = int(a[key])
	p["attr"] = a
	p["projected"] = true
	p["sample"] = 14.0  # projections skip the low-games confidence shrink
	p["overall"] = Ratings.rate_overall(a, role, 14.0)
	p["value"] = Ratings.salary_value(int(p["overall"]))


## Shift every attribute by a uniform offset so rate_overall lands on target.
## Bisection over a monotone function - at most ~14 cheap evaluations.
static func fit_attributes(a: Dictionary, role: String, target: float,
		games: float = 14.0) -> Dictionary:
	var lo := -40.0
	var hi := 40.0
	for i in range(14):
		var mid := (lo + hi) * 0.5
		if _shifted_overall(a, role, mid, games) < target:
			lo = mid
		else:
			hi = mid
	var offset := (lo + hi) * 0.5
	var out := {}
	for key in a:
		out[key] = clampi(int(round(float(a[key]) + offset)), 1, 99)
	return out


static func _shifted_overall(a: Dictionary, role: String, offset: float,
		games: float) -> float:
	var shifted := {}
	for key in a:
		shifted[key] = clampf(float(a[key]) + offset, 1.0, 99.0)
	return float(Ratings.rate_overall(shifted, role, games))


# ---------------------------------------------------------------------------
# Season rollover: growth, decline, retirement
# ---------------------------------------------------------------------------
## Ages and redevelops every player on every list in place. Mutates the
## player dicts (they are shared with GameDB; a New Career resets via
## GameDB.reload()). Returns {"retired": [...], "developed": n, "declined": n}.
static func age_league(lists: Dictionary, year: int) -> Dictionary:
	var retired := []
	var developed := 0
	var declined := 0
	for code in lists:
		var arr: Array = lists[code]
		for p in arr:
			var delta := age_player(p, year)
			if delta > 0.0:
				developed += 1
			elif delta < 0.0:
				declined += 1
		# Retire/trim pass, original order so it is deterministic.
		var keep: Array = []
		var dropped := 0
		for p in arr:
			if should_retire(p, year) and arr.size() - dropped > MIN_LIST and dropped < MAX_RETIRE_PER_CLUB:
				dropped += 1
				retired.append({"id": str(p["id"]), "name": str(p.get("generic_name", p.get("name", "Player"))),
						"club": str(code), "age": float(p.get("age", 26.0)),
						"overall": int(p.get("overall", 40))})
				p["retired"] = true
			else:
				keep.append(p)
		lists[code] = keep
	return {"retired": retired, "developed": developed, "declined": declined}


static func should_retire(p: Dictionary, year: int) -> bool:
	var age := float(p.get("age", 26.0))
	var ov := int(p.get("overall", 50))
	if ov <= 32:
		return true
	if age >= 37.0:
		return true
	if age >= 35.0:
		return _rng_for("%s|r%d" % [str(p["id"]), year]).randf() < 0.70
	if age >= 33.0 and ov < 42:
		return _rng_for("%s|r%d" % [str(p["id"]), year]).randf() < 0.30
	return false


## Age one player by a year and apply the development band. Returns the
## intended overall delta (for stats). Everyone on a list has now played a
## full simulated season, so the 2026 small-sample confidence shrink lifts.
static func age_player(p: Dictionary, year: int) -> float:
	var rng := _rng_for("%s|%d" % [str(p.get("id", "")), year])
	var age := float(p.get("age", 26.0)) + 1.0
	p["age"] = age
	if bool(p.get("projected", false)):
		p["sample"] = 16.0
	else:
		p["sample"] = maxf(18.0, float(p.get("gm", 0.0)))

	var d := 0.0
	if age <= 20.0:
		d = rng.randf_range(2.5, 6.0)
	elif age <= 23.0:
		d = rng.randf_range(1.0, 4.0)
	elif age <= 27.0:
		d = rng.randf_range(0.0, 2.0)
	elif age <= 30.0:
		d = rng.randf_range(-1.0, 1.0)
	elif age <= 33.0:
		d = rng.randf_range(-3.0, 0.0)
	else:
		d = rng.randf_range(-6.0, -1.5)
	var ov := int(p.get("overall", 50))
	if age <= 25.0 and ov < 55:
		d += 1.0  # late bloomers keep climbing
	if age <= 23.0 and ov >= 80:
		d += 1.0  # the young stars' ceilings stretch too
	var target := clampf(float(ov) + d, 25.0, 93.0)

	var role := str(p.get("role", "MID"))
	var a: Dictionary = p.get("attr", {})
	if not a.is_empty():
		p["attr"] = fit_attributes(a, role, target, Ratings.effective_games(p))
		p["overall"] = Ratings.rate_overall(p["attr"], role, Ratings.effective_games(p))
		p["value"] = Ratings.salary_value(int(p["overall"]))
	return float(int(p["overall"]) - ov)


## Age the undrafted pool between seasons. Prospects re-enter next year's
## draft a year older; past draft age they drop out of the pool.
static func age_pool(pool: Array, year: int, drafted: Dictionary) -> Array:
	var out := []
	for p in pool:
		var id := str(p["id"])
		if drafted.has(id):
			continue
		age_player(p, year)
		if float(p.get("age", 18.0)) >= 22.0:
			continue  # aged out of draft eligibility
		out.append(p)
	return out


# ---------------------------------------------------------------------------
# Future draft classes
# ---------------------------------------------------------------------------
## Deterministic fictional intake for years after the shipped data ends.
## Same projection pipeline as the real class, so a 2031 career keeps getting
## plausible rookies without inventing anyone real.
static func generate_class(year: int) -> Array:
	var rng := _rng_for("class-%d" % year)
	var size := 46 + int(rng.randi_range(0, 10))
	var role_bag := ["MID", "MID", "MID", "FWD", "FWD", "DEF", "DEF", "RUCK"]
	var out := []
	var rucks := 0
	for r in range(1, size + 1):
		var p := {}
		var role: String = str(role_bag[rng.randi_range(0, role_bag.size() - 1)])
		if r % 12 == 8:
			role = "RUCK"
		if role == "RUCK":
			rucks += 1
		p["role"] = role
		p["role2"] = _generated_secondary(role, rng)
		var height := 0.0
		match role:
			"RUCK": height = float(rng.randi_range(197, 208))
			"FWD": height = float(rng.randi_range(184, 203))
			"DEF": height = float(rng.randi_range(182, 198))
			_: height = float(rng.randi_range(173, 192))
		p["height_cm"] = height
		var over_age := rng.randf() < 0.15
		var birth_year := year - (19 if over_age else 18)
		var m := rng.randi_range(1, 12)
		var dd := rng.randi_range(1, 28)
		p["dob"] = "%04d-%02d-%02d" % [birth_year, m, dd]
		p["age"] = float(days_between(str(p["dob"]), "%d-11-20" % year)) / 365.25
		# ^ drafted mid-November; the whole class shares one reference date.
		var team: Array = JUNIOR_TEAMS[rng.randi_range(0, JUNIOR_TEAMS.size() - 1)]
		p["club"] = str(team[0])
		p["draft_team"] = str(team[0])
		p["draft_league"] = str(team[1])
		p["draft_state"] = str(team[2])
		p["state"] = str(team[2])
		p["tied_club"] = ""
		p["tied_type"] = ""
		p["u18_gm"] = float(rng.randi_range(6, 16))
		p["u18_di"] = float(rng.randi_range(10, 26)) if role != "RUCK" else float(rng.randi_range(8, 18))
		p["u18_gl"] = float(rng.randi_range(3, 26)) / 10.0 if role == "FWD" \
				else float(rng.randi_range(0, 8)) / 10.0
		p["u18_mk"] = float(rng.randi_range(1, 7)) if role != "FWD" else float(rng.randi_range(3, 7))
		p["u18_tk"] = float(rng.randi_range(1, 7))
		p["u18_if50"] = float(rng.randi_range(1, 6))
		p["u18_ho"] = float(rng.randi_range(12, 28)) if role == "RUCK" else 0.0
		p["note"] = ""
		p["id"] = "D%d_%02d" % [year, r]
		p["real_name"] = ""
		p["generic_name"] = ""
		p["name"] = ""
		p["first"] = ""
		p["last"] = ""
		p["src"] = "U18"
		p["data_src"] = "generated"
		p["draft_year"] = year
		p["draft_rank"] = r
		p["generated"] = true
		p["num"] = r
		for key in Ratings.STATS_ZERO_KEYS:
			p[key] = 0.0
		p["weight_kg"] = 0.0
		p["real_pos"] = Ratings.ROLE_SHORT_TO_POS.get(str(p["role"]), "MID")
		project(p)
		out.append(p)
	# Guarantee the pool carries a few rucks without renumbering the class.
	if rucks < 3:
		for p in out:
			if rucks >= 3:
				break
			if float(p.get("height_cm", 0.0)) >= 198.0 and str(p["role"]) != "RUCK":
				p["role"] = "RUCK"
				p["role2"] = "FWD"
				p["u18_ho"] = 18.0
				project(p)
				rucks += 1
	GameDB.assign_aliases(out)
	return out


static func _generated_secondary(role: String, rng: RandomNumberGenerator) -> String:
	if rng.randf() > 0.30:
		return ""
	match role:
		"MID": return "FWD" if rng.randf() < 0.6 else "DEF"
		"DEF": return "MID"
		"FWD": return "MID" if rng.randf() < 0.7 else "RUCK"
		"RUCK": return "FWD"
	return ""


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
static func _rng_for(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(key.hash()) * 2654435761 + 1013904223
	return rng


## Days between two ISO dates (Howard Hinnant's algorithm) - integer-exact,
## no Time API, no timezones.
static func days_between(from_iso: String, to_iso: String) -> int:
	return _days_from_civil(_parse_dto(to_iso)) - _days_from_civil(_parse_dto(from_iso))


static func _parse_dto(iso: String) -> Vector3i:
	if iso.length() < 10:
		return Vector3i(2026, 1, 1)
	return Vector3i(int(iso.substr(0, 4)), int(iso.substr(5, 2)), int(iso.substr(8, 2)))


static func _days_from_civil(d: Vector3i) -> int:
	var y := d.x
	if d.y <= 2:
		y -= 1
	var era := int(floor(float(y) / 400.0))
	var yoe := y - era * 400
	var doy := int(floor((153.0 * float(d.y + (9 if d.y <= 2 else -3)) + 2.0) / 5.0)) + d.z - 1
	var doe := yoe * 365 + int(floor(float(yoe) / 4.0)) - int(floor(float(yoe) / 100.0)) + doy
	return era * 146097 + doe - 719468
