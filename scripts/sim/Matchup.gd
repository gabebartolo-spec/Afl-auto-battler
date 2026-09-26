class_name Matchup
extends RefCounted
## This week's opponent in two or three football facts, for the hub.
##
## Everything comes from what the match engine will actually use: each club's
## match-day side (Squad - injured players already sit out) ranked against the
## rest of the league, the players on their list, and their recent results.
## Nothing is invented and no number is shown: a fact is a sentence a coach
## would say. Read-only and deterministic for the same state.
##
## A fact is {"key", "text", "weight"}; higher weight is more worth knowing.

const MAX_FACTS := 3
## A line of the ground counts as strong or weak when it ranks in the top or
## bottom this many clubs of the league.
const EDGE := 3
## "The danger": their best player on the ground, if he is among this many
## best players in the league.
const DANGER_RANK := 10
## "Without X": an injured player who is among his club's this many best.
const MISSING_TOP := 3
const STREAK := 3

## Lines of the ground and how the engine rolls them (Squad._aggregate).
## [key, best, strong, weak, worst]
const LINES := [
	["midfield", "The best midfield in the competition.",
			"A strong midfield that wins plenty of the ball.",
			"Their midfield can be beaten.",
			"The weakest midfield in the competition."],
	["ruck", "The best ruck in the competition.",
			"A dominant ruck: expect them to win the hit-outs.",
			"Beatable in the ruck.",
			"The weakest ruck in the competition."],
	["attack", "The most dangerous forward line in the competition.",
			"A dangerous forward line.",
			"They struggle to kick a score.",
			"The least potent forward line in the competition."],
	["defence", "The best defence in the competition.",
			"Hard to score against.",
			"Leaky in defence.",
			"The leakiest defence in the competition."],
]
## Order among equally weighted facts: what changes a selection first.
const PRIORITY := ["missing", "danger", "midfield", "ruck", "attack", "defence", "form"]


## The engine's view of a club's line strengths, from its match-day side.
static func line_values(squad: Squad) -> Dictionary:
	return {
		# The midfield share of the engine's contest number.
		"midfield": 0.42 * squad.mid_contest + 0.22 * squad.mid_disposal,
		"ruck": squad.ruck,
		"attack": squad.attack,
		"defence": squad.defence,
	}


## Up to MAX_FACTS facts about `opp`, most useful first.
## lists: club -> player list; selections: club -> selection ({} = auto);
## results: opp's results oldest first, e.g. ["W", "L", "W"].
static func facts(opp: String, lists: Dictionary, selections: Dictionary = {},
		results: Array = []) -> Array:
	if not lists.has(opp) or (lists[opp] as Array).is_empty():
		return []
	var out := []
	var squads := {}
	for code in lists:
		if (lists[code] as Array).is_empty():
			continue
		squads[code] = Squad.new(str(code), lists[code], false, str(code),
				selections.get(code, {}))
	out.append_array(_line_facts(opp, squads))
	var missing := _missing(lists[opp])
	if not missing.is_empty():
		out.append(missing)
	var danger := _danger(opp, squads[opp], lists)
	if not danger.is_empty():
		out.append(danger)
	var form := _form(results)
	if not form.is_empty():
		out.append(form)
	out.sort_custom(func(a, b):
		if int(a["weight"]) != int(b["weight"]):
			return int(a["weight"]) > int(b["weight"])
		return PRIORITY.find(str(a["key"])) < PRIORITY.find(str(b["key"])))
	return out.slice(0, MAX_FACTS)


## Strong or weak lines: top or bottom EDGE of the league. Needs a league of
## at least 2 * EDGE + 1 clubs to say anything.
static func _line_facts(opp: String, squads: Dictionary) -> Array:
	var out := []
	if squads.size() < EDGE * 2 + 1:
		return out
	var n := squads.size()
	for row in LINES:
		var key := str(row[0])
		var ranked := squads.keys()
		ranked.sort_custom(func(a, b):
			var va: float = line_values(squads[a])[key]
			var vb: float = line_values(squads[b])[key]
			if not is_equal_approx(va, vb):
				return va > vb
			return str(a) < str(b))
		var rank := ranked.find(opp) + 1            # 1 = best
		if rank <= EDGE:
			out.append({"key": key, "text": str(row[1] if rank == 1 else row[2]),
					"weight": EDGE + 1 - rank, "tone": "strong"})
		elif rank > n - EDGE:
			var from_bottom := n - rank + 1       # 1 = worst
			out.append({"key": key, "text": str(row[4] if from_bottom == 1 else row[3]),
					"weight": EDGE + 1 - from_bottom, "tone": "weak"})
	return out


## Their best injured player, if he is one of their MISSING_TOP best.
static func _missing(list: Array) -> Dictionary:
	var by_ovr := list.duplicate()
	by_ovr.sort_custom(func(a, b):
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		return str(a["id"]) < str(b["id"]))
	for i in range(mini(MISSING_TOP, by_ovr.size())):
		var p: Dictionary = by_ovr[i]
		if int(p.get("injury_weeks", 0)) > 0:
			return {"key": "missing", "text": "Without %s, one of their best (injured)." %
					GameDB.player_display_name(p), "weight": 3, "tone": "weak",
					"player_id": str(p["id"])}
	return {}


## Their best player on the ground, if he is one of the league's DANGER_RANK
## best available players.
static func _danger(opp: String, squad: Squad, lists: Dictionary) -> Dictionary:
	var best := {}
	for p in squad.ground:
		if best.is_empty() or int(p["overall"]) > int(best["overall"]) \
				or (int(p["overall"]) == int(best["overall"]) and str(p["id"]) < str(best["id"])):
			best = p
	if best.is_empty():
		return {}
	var better := 0
	for code in lists:
		for p in lists[code]:
			if Ratings.available(p) and int(p["overall"]) > int(best["overall"]):
				better += 1
	if better >= DANGER_RANK:
		return {}
	# The listed player, not the match-day copy placed in a slot.
	var original := best
	for p in lists[opp]:
		if str(p["id"]) == str(best["id"]):
			original = p
			break
	var who := GameDB.player_display_name(original)
	var text := "%s is the danger: the best player in the competition." % who if better == 0 \
			else "%s is the danger: an elite %s." % [who, PlayerProfile.player_type(original).to_lower()]
	return {"key": "danger", "text": text,
			"weight": 3 if better < 5 else 2, "tone": "strong",
			"player_id": str(original["id"])}


## A run of STREAK or more wins or losses going into the game.
static func _form(results: Array) -> Dictionary:
	if results.is_empty():
		return {}
	var last := str(results[results.size() - 1])
	if last != "W" and last != "L":
		return {}
	var run := 0
	for i in range(results.size() - 1, -1, -1):
		if str(results[i]) != last:
			break
		run += 1
	if run < STREAK:
		return {}
	return {"key": "form", "text": ("Won their last %d." if last == "W" else "Lost their last %d.") % run,
			"weight": 2, "tone": "strong" if last == "W" else "weak"}


## Your own side's week: your best players who are injured. At most `limit`.
static func own_notes(list: Array, limit := 2) -> Array:
	var out := []
	var by_ovr := list.duplicate()
	by_ovr.sort_custom(func(a, b):
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		return str(a["id"]) < str(b["id"]))
	for i in range(mini(MISSING_TOP, by_ovr.size())):
		var p: Dictionary = by_ovr[i]
		var weeks := int(p.get("injury_weeks", 0))
		if weeks > 0 and out.size() < limit:
			out.append({"key": "own_injury", "text": "%s is out injured (%s)." % [
					GameDB.player_display_name(p), "1 week" if weeks == 1 else "%d weeks" % weeks],
					"player_id": str(p["id"])})
	return out
