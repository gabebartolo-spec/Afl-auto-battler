class_name Retirement
extends RefCounted
## Talking a veteran out of retirement (director, 2026-10-06). Each
## off-season, every club's retirements are decided by the ageing rules
## (Prospects.should_retire) before anyone is gone, so a club can ask a
## player whose game is still healthy to go around again. His answer follows
## what is on record about him - a current injury, his recent injuries, his
## mood, how much he played - never a coin toss, and the main reason is given
## in football words. One more season, once a career; rival clubs ask by the
## same rules.

## Healthy enough to ask (director, 2026-10-06): in his club's best 22 and
## at or above the weakest player it picks at his position. Being merely above
## the low-OVR retirement floor is not enough. Measured: about 7 a season
## league-wide, one for a club about every other season
## (docs/RETIREMENT_EVIDENCE_2026-10-06.md).
const HEALTHY_RULE := "best 22, at or above his position's bar"

## Recorded injuries across this season and last that tell him it is time.
const INJURY_LIMIT := 3
## Games this season below which he sees no role for himself.
const MIN_GAMES := 8
## Morale below which he is not enjoying his footy (ClubLife.mood "Unhappy").
const LOW_MORALE := 40


## Whether the ageing rules retire him at the coming rollover (`year` is the
## new season): he is aged on a copy by the same seeded rules.
static func intends(p: Dictionary, year: int) -> bool:
	if bool(p.get("projected", false)):
		return false
	var dup := p.duplicate(true)
	Prospects.age_player(dup, year)
	return Prospects.should_retire(dup, year)


## Still good enough to be worth asking: picked in his club's best 22 and
## at or above its bar at his position.
static func healthy(p: Dictionary, list: Array) -> bool:
	var side := Ratings.select_22(list)
	var picked := false
	for q in (side["ground"] as Array) + (side["bench"] as Array):
		if str(q["id"]) == str(p["id"]):
			picked = true
			break
	if not picked:
		return false
	var bars := TradeValue.selection_bars(list)
	return int(p.get("overall", 0)) >= int(bars.get(str(p.get("role", "")), bars.get("bench", 0)))


## Whether a club may ask him: retiring this rollover, healthy, never talked
## round before, and not already asked this off-season.
static func can_ask(p: Dictionary, list: Array, year: int) -> bool:
	return int(p.get("retiring", 0)) == year and not p.has("talked_round") \
			and int((p.get("retire_talk", {}) as Dictionary).get("year", 0)) != year \
			and healthy(p, list)


## Recorded injuries in `season` and the one before.
static func recent_injuries(p: Dictionary, season: int) -> int:
	var n := 0
	for y in p.get("injury_log", []):
		if int(y) >= season - 1:
			n += 1
	return n


## His answer, from what is on record: {"stays": bool, "reason": String}.
## The first reason that applies is the one he gives.
static func answer(p: Dictionary, season: int, games: int) -> Dictionary:
	if int(p.get("injury_weeks", 0)) > 0:
		var kind := str(p.get("injury_kind", "injury")).replace("_", " ")
		return {"stays": false, "reason": "He is still getting over the %s, and his body is telling him it's time." % kind}
	var inj := recent_injuries(p, season)
	if inj >= INJURY_LIMIT:
		return {"stays": false, "reason": "%d injuries in two seasons: he doesn't want another rehab." % inj}
	if ClubLife.morale(p) < LOW_MORALE:
		return {"stays": false, "reason": "He isn't enjoying his footy any more."}
	if games < MIN_GAMES:
		return {"stays": false, "reason": "%d games this year: he doesn't see a role for himself." % games}
	return {"stays": true, "reason": "He's fit, he's enjoying it and he's still in the side: he'll go around again."}


## Record the answer on him; a yes makes the coming season his last-but-one.
static func apply(p: Dictionary, result: Dictionary, year: int) -> void:
	p["retire_talk"] = {"year": year, "stays": bool(result["stays"]), "reason": str(result["reason"])}
	if bool(result["stays"]):
		p["play_on"] = year
		p["talked_round"] = true
