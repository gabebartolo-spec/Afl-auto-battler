class_name TeamRating
extends RefCounted
## A club's list as one number, and where it is in its cycle (director,
## 2026-10-11): "teams should also have a numerical rating based on their list
## only, and have categories like contender, rebuilding, wildcard".
##
## - Rating: the side the selector would pick today (Ratings.select_side: 18
##   on the ground and the interchange, the match-day 23, injured players
##   out), as its mean OVR.
## - Forecast: the same list in three seasons, from the game's own
##   development outlook (Potential.outlook: age bands, growth toward POT and
##   retirement at their expected values). Only players already on the list:
##   nobody is drafted, traded or signed in the forecast, contracts are taken
##   to be renewed, and a player more likely retired than not by then is left
##   out. The best match-day side's worth of what is left, by projected rating.
## - Category: the phase the AI trades on (TradeValue.phase via
##   GameState.club_phase), in football words. One rule: a "Rebuilding" club
##   really does guard its kids in trades.

const FORECAST_YEARS := 3
const CATEGORY := {"contending": "Contender", "building": "Wildcard", "rebuilding": "Rebuilding"}


## The side the selector would pick from `list` today, as their mean OVR.
static func rating(list: Array) -> int:
	var side := Ratings.select_side(list)
	var picked: Array = (side["ground"] as Array) + (side["bench"] as Array)
	if picked.is_empty():
		return 0
	var total := 0.0
	for p in picked:
		total += float(p.get("overall", 0))
	return int(round(total / float(picked.size())))


## The list's best match-day side in `years` seasons (Potential.outlook), as
## their mean projected OVR. Everyone on the list counts, the injured included (they
## heal); a player more likely gone than playing by then does not.
static func forecast(list: Array, years := FORECAST_YEARS) -> int:
	var projected := []
	for p in list:
		var o: Array = Potential.outlook(p, years + 1)
		if o.size() <= years:
			continue
		var at: Array = o[years]
		if float(at[1]) < 0.5:
			continue
		projected.append(float(at[0]))
	if projected.is_empty():
		return 0
	projected.sort()
	projected.reverse()
	var take := mini(18 + Ratings.bench_size, projected.size())
	var total := 0.0
	for i in range(take):
		total += float(projected[i])
	return int(round(total / float(take)))


## The phase as a coach would say it: Contender, Wildcard or Rebuilding.
static func category(phase: String) -> String:
	return str(CATEGORY.get(phase, "Wildcard"))


## "Contender · 78, 81 in three years": the category, the rating and where
## the list is heading.
static func line(phase: String, now: int, later: int) -> String:
	return "%s · %d, %d in three years" % [category(phase), now, later]
