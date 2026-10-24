class_name FactOptions
extends RefCounted
## Every opposition fact comes with your options beside it (P-13, director
## 2026-10-14, A9: "why tell me Rankine is their best player if i cant do
## anything about it?"). One place says which responses bear on which kind of
## fact (Matchup's "key": danger, interceptor, midfield, ruck, attack,
## defence, missing, form), in a fixed order that is not an order of merit:
## tag, key match-up, defensive forward, main ruck, loose interceptor, plan.
##
## A layout rule over the controls the rules already have. Nothing here is a
## new lever, a grade or a recommendation: every response that bears on a
## fact is listed, a suitable one enabled, an unsuitable one disabled with the
## reason, and none is marked best. The cost of each is in the words the
## pre-bounce pane already uses (see COST_*).

## The responses, in the order they are always shown.
const ORDER := ["tag", "matchup", "minder", "ruck", "loose", "plan"]

## What each is called: the heading of the call it opens on the pre-bounce pane.
const NAMES := {"tag": "Tag", "matchup": "Key match-up", "minder": "Defensive forward",
		"ruck": "Main ruck", "loose": "Loose interceptor"}

## The cost of each, from the words the pane already uses:
## tag: "He gives up his own game." (MatchScene tag note);
## matchup: the swap a Change makes, the defender moved leaves his man;
## minder: "Whoever goes is a target less often himself." (MatchNotes.minder_cost_line);
## ruck: "... and tires like a ruck for it." (MatchScene._main_ruck_note);
## loose: "if he flies and loses, space opens behind him." (the loose interceptor's note).
## A plan's cost is the first clause of its own cost line (CoachReport.PLAN_PARTS).
const COST := {
	"tag": "Your tagger gives up his own game",
	"matchup": "The defender you move leaves his man",
	"ruck": "He tires like a ruck for it",
	"loose": "Space opens behind him if he loses",
}

## fact key -> the responses that bear on it, as [call] or ["plan", plan key].
const TABLE := {
	"danger": [["tag"], ["matchup"], ["minder"], ["ruck"]],
	"interceptor": [["minder"], ["plan", "attacking"], ["plan", "controlled"]],
	"midfield": [["tag"], ["plan", "contest"], ["plan", "controlled"]],
	"ruck": [["ruck"]],
	"attack": [["matchup"], ["loose"], ["plan", "defensive"], ["plan", "controlled"]],
	"defence": [["plan", "attacking"], ["plan", "controlled"]],
	# Who is missing and a run of results are facts to know, not to answer.
	"missing": [],
	"form": [],
}

const WHERE := {"RUCK": "ruck", "DEF": "in defence", "FWD": "forward", "MID": "midfield"}


## The responses beside `fact` (a Matchup fact), in ORDER. `theirs` and `mine`
## are the two sides' players on the ground; `opp_list` is their whole list
## (the fact's player is looked up there). Each: {"call", "plan", "label",
## "cost", "enabled", "reason", "player_id"}; `cost` is "" for a disabled one
## (its reason stands in its place). `gain` is what it does for you: both are
## sized from the sim's constants (GateOdds, bible §4). `lines` is [their
## fwd_mark, your def_intercept] when the Squads are known.
static func options(fact: Dictionary, theirs: Array, mine: Array, opp_list: Array, lines := [0.0, 0.0]) -> Array:
	var rows: Array = TABLE.get(str(fact.get("key", "")), [])
	var who := {}
	for p in opp_list:
		if str(p.get("id", "")) == str(fact.get("player_id", "")) and str(fact.get("player_id", "")) != "":
			who = p
			break
	var out := []
	for call in ORDER:
		for row in rows:
			if str(row[0]) != call:
				continue
			var o := _option(str(fact.get("key", "")), row, who, theirs, mine, lines)
			o["player_id"] = str(fact.get("player_id", ""))
			out.append(o)
	return out


## Only the responses the coach can take: what the hub shows (no greyed cards).
static func takeable(options_for_fact: Array) -> Array:
	return options_for_fact.filter(func(o): return bool(o["enabled"]))


static func _option(key: String, row: Array, who: Dictionary, theirs: Array, mine: Array, lines := [0.0, 0.0]) -> Dictionary:
	var call := str(row[0])
	var o := {"call": call, "plan": "", "label": str(NAMES.get(call, "")), "cost": "", "gain": "",
			"enabled": true, "reason": ""}
	var reason := ""
	match call:
		"tag":
			if not who.is_empty():
				if not _tag_candidate(who):
					reason = "He plays %s: a tag needs a midfielder." % _where(who)
			elif theirs.filter(func(p): return _tag_candidate(p)).is_empty():
				reason = "None of their midfielders is on the ground."
		"matchup":
			var keys := Matchups.key_forwards(theirs)
			if not who.is_empty():
				if not keys.any(func(p): return str(p.get("id", "")) == str(who.get("id", ""))):
					reason = "He is not one of their key forwards."
			elif keys.is_empty():
				reason = "They have no key forward."
			elif Matchups.defenders(mine).is_empty():
				reason = "You have no defender to put on him."
		"minder":
			var spare := Matchups.best_interceptor(theirs)
			if spare.is_empty() or (not who.is_empty() and str(spare.get("id", "")) != str(who.get("id", ""))):
				reason = "He is not their loose defender." if not who.is_empty() else "They have no loose defender."
			elif Matchups.minder_candidates(mine).is_empty():
				reason = "You have no forward to send."
		"ruck":
			if not who.is_empty() and not MatchSim._is_ruckman(who):
				reason = "He is not a ruck."
			elif mine.filter(func(p): return MatchSim._is_ruckman(p)).size() < 2:
				reason = "You have one ruck: this call is for two."
		"loose":
			if Matchups.defenders(mine).is_empty():
				reason = "You have no defender to send loose."
		"plan":
			var plan := str(row[1])
			o["plan"] = plan
			o["label"] = "%s plan" % CoachReport.plan_label(plan)
	var two := _sides(call, str(o["plan"]), who, theirs, mine, lines)
	o["gain"] = GateOdds.gain(str(two[0]))
	o["cost"] = GateOdds.cost(str(two[1]))
	if reason != "":
		o["enabled"] = false
		o["reason"] = reason
		o["cost"] = ""
		o["gain"] = ""
	return o


## [gain, cost] of a response, sized from the sim's constants (GateOdds).
static func _sides(call: String, plan: String, who: Dictionary, theirs: Array, mine: Array, lines: Array) -> Array:
	match call:
		"tag":
			return GateOdds.tag_lines()
		"minder":
			return GateOdds.minder_lines()
		"ruck":
			return GateOdds.ruck_lines()
		"loose":
			return GateOdds.loose_lines()
		"plan":
			return GateOdds.plan_lines(plan)
		"matchup":
			var keys := Matchups.key_forwards(theirs)
			var fwd: Dictionary = who if not who.is_empty() else (keys[0] if not keys.is_empty() else {})
			var best := {}
			var best_p := 2.0
			for d in Matchups.defenders(mine):
				var pr := Matchups.mark_chance(fwd, d, float(lines[0]), float(lines[1]))
				if pr < best_p:
					best_p = pr
					best = d
			if best.is_empty() or fwd.is_empty():
				return ["", ""]
			var nm := GameDB.player_display_name(best)
			return [GateOdds.MATCHUP_GAIN % [nm, GateOdds.pct(best_p)],
					(GateOdds.MATCHUP_COST_NEXT if keys.size() > 1 else GateOdds.MATCHUP_COST_LOOSE) % nm]
	return ["", ""]


## The defensive forward's cost: the last sentence of the pane's own cost line
## ("Whoever goes is a target less often himself."), said of your forward.
static func minder_cost() -> String:
	var line: String = load("res://scripts/ui/match/MatchNotes.gd").minder_cost_line()
	var at := line.find("Whoever goes is")
	return "Your forward is" + line.substr(at + "Whoever goes is".length()).trim_suffix(".").replace(" himself", "")


## A plan's cost in a short phrase: the first clause of its own cost line.
static func plan_cost(plan: String) -> String:
	var c := str(CoachReport.plan_parts(plan).get("cost", ""))
	var cut := c.length()
	for sep in [",", " and ", "."]:
		var i := c.find(sep)
		if i > 0:
			cut = mini(cut, i)
	return c.left(cut)


## Mid or forward with a midfield position, never a ruckman (director, 2026-10-14, A9; lead, 2026-10-18):
## a ruck who also lists MID is the Main ruck call's business here, not a tag's.
static func _tag_candidate(p: Dictionary) -> bool:
	return MatchSim.can_be_tagged(p) and str(Ratings.positions(p)[0]) != "RUCK"


static func _where(p: Dictionary) -> String:
	return str(WHERE.get(str(Ratings.positions(p)[0]), "elsewhere"))
