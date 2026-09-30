class_name PlanFit
extends RefCounted
## How well a side's players suit each game plan. Every plan leans on a kind
## of player: a press on its pressure players, corridor footy on its runners,
## winning the contest on its ball-winners and ruck, controlled tempo on its
## good kicks and marks. A plan's upside grows with them; its costs do not
## (MatchSim._pv), so a plan the list does not suit is a real risk.
##
## The same rules pick an AI club's usual plan (standing_plan) and name, for
## the player, who in the side makes each plan work (carriers). Pure rules on
## the match-day ground, no state: deterministic for the same side.

## plan -> the attributes that carry it (weights), which lines can carry it,
## how many players count, and what a coach calls them.
const NEEDS := {
	"attacking": {"attr": {"carry": 0.6, "disposal": 0.4}, "lines": ["MID", "FWD", "DEF"],
			"n": 6, "word": "runners"},
	"defensive": {"attr": {"pressure": 1.0}, "lines": ["MID", "FWD"], "n": 8,
			"word": "pressure players"},
	"contest": {"attr": {"contested": 1.0}, "lines": ["MID"], "n": 4, "ruck": true,
			"word": "ball-winners"},
	"controlled": {"attr": {"disposal": 0.6, "marking": 0.4}, "lines": ["MID", "FWD", "DEF"],
			"n": 8, "word": "good kicks and marks"},
}

## Where the league sits on each plan's score (mean, spread), from the 2027
## match-day sides: 1.0 fit is an average list for that plan.
const LEAGUE := {
	"attacking": [71.3, 3.5],
	"defensive": [49.8, 2.4],
	"contest": [80.3, 3.8],
	"controlled": [62.9, 2.3],
	# Through stars: how far the side's best three stand above its average.
	"through_stars": [15.1, 2.3],
}
## Through stars goes through this many of the side's best players.
const STAR_N := 3
## How far one spread from the league moves a plan's upside, and its limits:
## the best-suited list gets about half as much again, the worst about half.
const PER_SPREAD := 0.32
const FIT_MIN := 0.45
const FIT_MAX := 1.55
## An AI club runs a plan as its usual game only when its list clearly suits
## it (this many spreads above the league); otherwise it plays it straight.
const STANDING_EDGE := 0.4


static func _value(p: Dictionary, weights: Dictionary) -> float:
	var a: Dictionary = p.get("attr", {})
	var v := 0.0
	for k in weights:
		v += float(weights[k]) * float(a.get(k, 0.0))
	return v


## The players who carry `plan` in this side, best first: for Through stars
## the best three by overall ([] for Balanced).
static func carriers(ground: Array, plan: String) -> Array:
	if plan == "through_stars":
		var best := ground.duplicate()
		best.sort_custom(func(a, b):
			if int(a["overall"]) != int(b["overall"]):
				return int(a["overall"]) > int(b["overall"])
			return str(a.get("id", "")) < str(b.get("id", "")))
		return best.slice(0, STAR_N)
	if not NEEDS.has(plan):
		return []
	var need: Dictionary = NEEDS[plan]
	var pool := []
	for p in ground:
		if (need["lines"] as Array).has(str(p.get("role", ""))):
			pool.append(p)
	pool.sort_custom(func(a, b):
		var va := _value(a, need["attr"])
		var vb := _value(b, need["attr"])
		if not is_equal_approx(va, vb):
			return va > vb
		return str(a.get("id", "")) < str(b.get("id", "")))
	var out: Array = pool.slice(0, int(need["n"]))
	if bool(need.get("ruck", false)):
		for p in ground:
			if str(p.get("role", "")) == "RUCK":
				out.append(p)
				break
	return out


## The side's raw score for `plan`: its carriers' average on what the plan
## needs (the ruck's tap work counts for a quarter of a contest).
static func score(ground: Array, plan: String) -> float:
	if plan == "through_stars":
		if ground.is_empty():
			return 0.0
		var all := 0.0
		for p in ground:
			all += float(p["overall"])
		var top := 0.0
		var stars := carriers(ground, plan)
		for p in stars:
			top += float(p["overall"])
		return top / float(stars.size()) - all / float(ground.size())
	if not NEEDS.has(plan):
		return 0.0
	var need: Dictionary = NEEDS[plan]
	var tot := 0.0
	var n := 0
	var ruck := -1.0
	for p in carriers(ground, plan):
		if bool(need.get("ruck", false)) and str(p.get("role", "")) == "RUCK":
			ruck = float((p.get("attr", {}) as Dictionary).get("ruck", 0.0))
			continue
		tot += _value(p, need["attr"])
		n += 1
	var v := tot / float(maxi(1, n))
	if ruck >= 0.0:
		v = 0.75 * v + 0.25 * ruck
	return v


## How far above (+) or below (-) the league the side is for `plan`, in spreads.
static func edge(ground: Array, plan: String) -> float:
	if not LEAGUE.has(plan):
		return 0.0
	var l: Array = LEAGUE[plan]
	return (score(ground, plan) - float(l[0])) / maxf(0.001, float(l[1]))


## The multiplier on `plan`'s upside for this side: 1.0 for an average list.
## Balanced has no needs and is always 1.0.
static func fit(ground: Array, plan: String) -> float:
	if not LEAGUE.has(plan):
		return 1.0
	return clampf(1.0 + PER_SPREAD * edge(ground, plan), FIT_MIN, FIT_MAX)


## The plan an AI club plays as its usual game: the one its list suits best,
## if it clearly suits one; otherwise Balanced.
static func standing_plan(ground: Array) -> String:
	var best := "balanced"
	var best_edge := STANDING_EDGE
	for plan in NEEDS:
		var e := edge(ground, plan)
		if e > best_edge:
			best_edge = e
			best = plan
	return best


## How the side's carriers for `plan` compare with the league, in words.
## How far a side's best three stand above the rest, in words (Through stars).
static func stars_word(ground: Array) -> String:
	var e := edge(ground, "through_stars")
	if e >= 1.2:
		return "far above the rest"
	if e >= 0.4:
		return "well above the rest"
	if e > -0.4:
		return "above the rest, as most sides' are"
	if e > -1.2:
		return "not far above the rest"
	return "barely above the rest"


static func fit_word(ground: Array, plan: String) -> String:
	var e := edge(ground, plan)
	if e >= 1.2:
		return "among the best"
	if e >= 0.4:
		return "strong"
	if e > -0.4:
		return "about average"
	if e > -1.2:
		return "below par"
	return "among the weakest"
