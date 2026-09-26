class_name Squad
extends RefCounted
## A match-day side: the best 18 of a drafted list plus four on the bench,
## rolled up into the handful of team strengths the match engine actually uses.
##
## Port of tools/sim_harness.py::Squad. The aggregate weights below were tuned
## there against real 2026 team totals - change them in both places.

var name := ""
var code := ""
var list: Array = []
var home := false
var ground: Array = []
var bench: Array = []
## Team form, -1..1, from recent results (Season.club_form). Set by whoever
## builds the match; 0 is neutral.
var form := 0.0

## Role-group strengths
var ruck := 45.0
var mid_contest := 45.0
var mid_disposal := 45.0
var mid_carry := 45.0
var def_pressure := 45.0
var def_intercept := 45.0
var fwd_goal := 45.0
var fwd_mark := 45.0
var fwd_create := 45.0

## Whole-team strengths
var team_discipline := 45.0
var team_pressure := 45.0
var team_disposal := 45.0
var team_intercept := 45.0
var team_star := 45.0

## The three numbers the engine actually rolls against.
var contest := 45.0
var attack := 45.0
var defence := 45.0


func _init(p_name: String, p_list: Array, p_home := false, p_code := "",
		p_selection: Dictionary = {}) -> void:
	name = p_name
	code = p_code
	list = p_list
	home = p_home
	# Injured players sit out; a club's chosen side is used when it has one.
	var sel := Ratings.select_side(p_list, p_selection)
	ground = sel["ground"]
	bench = sel["bench"]
	_aggregate()


func _aggregate() -> void:
	var by_role := {"RUCK": [], "MID": [], "DEF": [], "FWD": []}
	for p in ground:
		by_role[p["role"]].append(p)

	var mids: Array = by_role["MID"]
	var defs: Array = by_role["DEF"]
	var fwds: Array = by_role["FWD"]
	var rucks: Array = by_role["RUCK"]

	ruck = _mean(rucks, "ruck")
	mid_contest = _mean(mids, "contested")
	mid_disposal = _mean(mids, "disposal")
	mid_carry = _mean(mids, "carry")
	def_pressure = _mean(defs, "pressure")
	def_intercept = _mean(defs, "intercept")
	fwd_goal = _mean(fwds, "goalkicking")
	fwd_mark = _mean(fwds, "marking")
	fwd_create = _mean(fwds, "creating")

	team_discipline = _mean(ground, "discipline")
	team_pressure = _mean(ground, "pressure")
	team_disposal = _mean(ground, "disposal")
	team_intercept = _mean(ground, "intercept")
	team_star = _top(ground, "star", 5)

	contest = (0.42 * mid_contest + 0.24 * ruck + 0.22 * mid_disposal
			+ 0.12 * team_star)
	attack = (0.40 * fwd_goal + 0.26 * mid_carry + 0.20 * fwd_create
			+ 0.14 * fwd_mark)
	defence = (0.50 * def_pressure + 0.32 * def_intercept
			+ 0.18 * team_discipline)


## Average attribute across a role group. Falls back to 45 (league-average) when
## a list has nobody in that group, so a malformed list still fields a side.
static func _mean(group: Array, key: String, fallback := 45.0) -> float:
	if group.is_empty():
		return fallback
	var total := 0.0
	for p in group:
		total += float(p["attr"][key])
	return total / float(group.size())


## Mean of the top n - used for "star power", where a handful of elite players
## matter more than the group average.
static func _top(group: Array, key: String, n: int, fallback := 45.0) -> float:
	if group.is_empty():
		return fallback
	var vals := []
	for p in group:
		vals.append(float(p["attr"][key]))
	vals.sort()
	vals.reverse()
	var take := mini(n, vals.size())
	var total := 0.0
	for i in range(take):
		total += vals[i]
	return total / float(take)


func best_on_ground() -> Array:
	var out := ground.duplicate()
	out.sort_custom(func(a, b): return a["overall"] > b["overall"])
	return out


## Estimated list strength, 0-100, for AI difficulty scaling and ladder seeding.
func strength() -> float:
	return clampf(0.45 * contest + 0.30 * attack + 0.25 * defence, 0.0, 100.0)
