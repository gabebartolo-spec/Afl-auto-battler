class_name TradeValue
extends RefCounted
## What a player is worth in a trade, to a particular club.
##
## Two parts, both from facts every club has (ratings, potential, age,
## contract, last season's games, its own list and ladder):
## - now: his football this season - rating, less a decline once he is past
##   30, times how available he is and how well he fits the club's side;
## - future: what he could become (part of the gap to his potential, for
##   the young) times the career he has left.
## A club weights the two by where it is in its cycle: contenders buy now,
## rebuilders protect the future. Value climbs steeply with rating, so two
## ordinary players never add up to a star, and a package of several players
## counts its lesser pieces for less (`package`).

const PHASES := ["rebuilding", "building", "contending"]
## Weight on [now, future] by phase.
const WEIGHTS := {"rebuilding": [0.35, 1.0], "building": [0.8, 0.7], "contending": [1.0, 0.45]}
## The 2nd, 3rd, 4th... players in a package count for this much.
static var package_weights := [1.0, 0.6, 0.35, 0.2, 0.1]


## Value of a rating: steep, so stars are worth far more than the sum of
## ordinary players.
static func curve(rating: float) -> float:
	return pow(maxf(1.0, rating) / 70.0, 5.0)


## His football now: rating less an ageing decline past 30.
static func now_rating(p: Dictionary) -> float:
	return float(p.get("overall", 50)) - 1.0 * maxf(0.0, float(p.get("age", 25.0)) - 30.0)


## What he could become: part of the gap to his potential, the younger the
## more of it (none from 24 and a half), less the same ageing decline. A
## ceiling nobody has seen yet is not banked: with no senior games only half
## of that share counts, all of it once he has played PROVEN_GAMES.
static func future_rating(p: Dictionary) -> float:
	var ovr := float(p.get("overall", 50))
	var pot := maxf(ovr, float(p.get("potential", ovr)))
	var youth := clampf((24.5 - float(p.get("age", 25.0))) / 5.0, 0.0, 1.0)
	return ovr + (pot - ovr) * 0.6 * youth * proven(p) - 1.0 * maxf(0.0, float(p.get("age", 25.0)) - 30.0)


const PROVEN_GAMES := 50.0


## How much of his ceiling a club banks: 0.5 before a senior game, 1 by
## PROVEN_GAMES (career games; the season's games when there is no record).
static func proven(p: Dictionary) -> float:
	var c = p.get("career", null)
	var games := float((c as Dictionary).get("games", 0)) if c is Dictionary else float(p.get("gm", 0.0))
	return 0.5 + 0.5 * clampf(games / PROVEN_GAMES, 0.0, 1.0)


## The share of a full career he has left: 1 under 26, falling to 0.15 at 33.
static func runway(p: Dictionary) -> float:
	return clampf((33.0 - float(p.get("age", 25.0))) / 7.0, 0.15, 1.0)


## How available he is: durability, and last season's games when the club
## has seen him play a season (`games` < 0: no season to go on).
static func availability(p: Dictionary, games: int) -> float:
	var dur := float((p.get("attr", {}) as Dictionary).get("durability", 70))
	var a := 0.9 + 0.15 * clampf(dur / 100.0, 0.0, 1.0)
	if games >= 0 and float(p.get("age", 25.0)) > 20.0:
		a *= 0.85 + 0.15 * clampf(float(games) / 15.0, 0.0, 1.0)
	if int(p.get("injury_weeks", 0)) > 0:
		a *= 0.9
	return a


## A contract that pays him less than his rating is worth adds a little; one
## that overpays takes a little off, more the longer it runs.
static func contract_factor(p: Dictionary) -> float:
	var fair := float(Ratings.salary_value(int(p.get("overall", 50))))
	var paid := float(p.get("salary", fair))
	var years := float(clampi(int(p.get("contract_years", 1)), 1, 4))
	return 1.0 + 0.03 * clampf(fair - paid, -4.0, 4.0) * minf(years, 3.0) / 3.0


## The weakest player a club picks in each position of its side, and on its
## bench: the bar a newcomer has to clear (see `fit`). `projected`: rate the
## side at what its players are expected to become (`future_rating`: part
## of the way to potential, never all of it), for judging future cover.
static func selection_bars(list: Array, projected := false) -> Dictionary:
	var side := Ratings.select_22(list)
	var bars := {}
	for q in side["ground"]:
		var r := str(q["role"])
		bars[r] = mini(int(bars.get(r, 999)), _bar_rating(q, projected))
	var bench := 999
	for q in side["bench"]:
		bench = mini(bench, _bar_rating(q, projected))
	bars["bench"] = bench if bench < 999 else 0
	return bars


static func _bar_rating(q: Dictionary, projected: bool) -> int:
	if not projected:
		return int(q["overall"])
	return maxi(int(q["overall"]), roundi(future_rating(q)))


## Will he still have a place once the club's young players grow? His
## projected rating against the side's projected bars: 1 if he would start,
## 0.85 on the bench, 0.7 if young players already cover his position. Only
## the future part of his value uses this, and it never reaches zero:
## projections are not promises.
static func cover(p: Dictionary, projected_bars: Dictionary) -> float:
	var fut := roundi(future_rating(p))
	for r in [str(p.get("role", "")), str(p.get("role2", ""))]:
		if r != "" and projected_bars.has(r) and fut > int(projected_bars[r]):
			return 1.0
	return 0.85 if fut > int(projected_bars.get("bench", 0)) else 0.7


## How much of his football a club can use this season, from its own side as
## it is now - its own needs, by quality, not a count of position tags. A
## starter counts from 0.8 (barely better than the man he replaces) to 1.3
## (a big upgrade where the club is weakest): a club with a poor ruckman pays
## more for a good one. A bench player counts 0.65; a player who would not
## get a game, 0.4.
static func fit(p: Dictionary, bars: Dictionary) -> float:
	var ovr := int(p.get("overall", 0))
	var gain := -999
	for r in [str(p.get("role", "")), str(p.get("role2", ""))]:
		if r != "" and bars.has(r):
			gain = maxi(gain, ovr - int(bars[r]))
	if gain > 0:
		return 0.8 + 0.5 * clampf(float(gain) / 10.0, 0.0, 1.0)
	if ovr > int(bars.get("bench", 0)):
		return 0.65
	return 0.4


## His value to a club: {"now", "future", "total"}. `ctx` = {"phase",
## "bars" and "proj" (the club's side now and projected - without him for
## its own players, as it would be for a newcomer), "games" (last season's
## games or -1), "own" (true for a player the club would be giving up)}.
## Now and future stay separate: this season's fit judges the now part,
## future cover the future part.
static func value(p: Dictionary, ctx: Dictionary) -> Dictionary:
	var w: Array = WEIGHTS.get(str(ctx.get("phase", "building")), WEIGHTS["building"])
	var now := curve(now_rating(p)) * availability(p, int(ctx.get("games", -1))) * fit(p, ctx.get("bars", {}))
	var future := curve(future_rating(p)) * runway(p)
	if ctx.has("proj"):
		future *= cover(p, ctx["proj"])
	var total := (float(w[0]) * now + float(w[1]) * future) * contract_factor(p)
	# A rebuilding club guards the young talent it already has: giving away
	# a player with real growth ahead of him costs it a quarter more.
	if bool(ctx.get("own", false)) and str(ctx.get("phase", "")) == "rebuilding" \
			and future_rating(p) >= now_rating(p) + 5.0:
		total *= 1.25
	return {"now": now, "future": future, "total": total}


## A package of players, best first: the lesser pieces count for less, so
## four ordinary players never buy a cornerstone by arithmetic.
static func package(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	sorted.reverse()
	var total := 0.0
	for i in range(sorted.size()):
		total += float(sorted[i]) * float(package_weights[mini(i, package_weights.size() - 1)])
	return total


## Where a club is in its cycle, from what anyone can see: `finish_t` (0
## premiers .. 1 wooden spoon, or -1 before a game is played), `strength_t`
## (its list's rank, 0 best .. 1 weakest) and the average age of its best
## 22. High on both and it contends; low on both, or middling with a young
## side, and it rebuilds.
static func phase(finish_t: float, strength_t: float, best22_age: float) -> String:
	var standing := 1.0 - strength_t if finish_t < 0.0 else 0.5 * (1.0 - finish_t) + 0.5 * (1.0 - strength_t)
	if standing >= 0.65:
		return "contending"
	if standing <= 0.35 or (standing <= 0.5 and best22_age <= 24.5):
		return "rebuilding"
	return "building"


## A draft pick, valued as the player a club expects to get with it: the
## prospects around that spot in the class (best first by projected rating,
## the five spots around it - who goes first is never certain), through the club's own phase weights, so a rebuilder values
## good picks more than a contender does. `positions` = [[overall pick,
## weight], ...]: one exact spot for this year's draft, a spread for a pick
## whose spot isn't known yet. A pick past the end of the class is worth
## nothing.
static func pick_value(positions: Array, prospects: Array, phase: String) -> float:
	if prospects.is_empty():
		return 0.0
	var total := 0.0
	var weight := 0.0
	for pw in positions:
		var at := int(pw[0])
		var w := float(pw[1])
		weight += w
		if at < 1 or at > prospects.size():
			continue
		var lo := maxi(0, at - 3)
		var hi := mini(prospects.size() - 1, at + 1)
		var sum := 0.0
		for i in range(lo, hi + 1):
			sum += float(value(prospects[i], {"phase": phase})["total"])
		total += w * sum / float(hi - lo + 1)
	return total / maxf(weight, 0.0001)


## Prospects best first by what a club can see of them (projected rating).
static func rank_prospects(pool: Array) -> Array:
	var ranked := pool.duplicate()
	ranked.sort_custom(func(a, b):
		var fa := future_rating(a)
		var fb := future_rating(b)
		if fa != fb:
			return fa > fb
		return str(a["id"]) < str(b["id"]))
	return ranked