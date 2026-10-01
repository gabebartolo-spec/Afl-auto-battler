class_name RecruitMeeting
extends RefCounted
## The pre-draft meeting (ARD-M5-014): before the National Draft, the
## recruiting panel says what the list does well, where it is genuinely
## short, and names a few prospects who caught its eye - each for a football
## reason. It is a starting point, not an answer: no order of preference, no
## "best pick", no position you must take.

## How many prospects the panel talks about.
const NAMES := 3
## The window of the class they look at: from a couple of places before your
## first pick to this many after it, so the names are still likely to be there.
const WINDOW_BEFORE := 2
const WINDOW_AFTER := 10
## Fewer junior games than this and the panel says it has not seen enough.
const THIN_GAMES := 8


## {"list": [sentence], "names": [{"id", "line"}]} for `draft` (an intake
## draft with your club set). `list_players` is your current list; `profile`
## is GameState.list_profile() ([] when there is no season to read it from).
static func notes(draft: Draft, list_players: Array, profile: Array) -> Dictionary:
	return {"list": list_lines(draft.position_status(), list_players, profile),
			"names": prospect_lines(draft)}


## Up to three sentences about the list, the most pressing first.
static func list_lines(status: Dictionary, list_players: Array, profile: Array) -> Array:
	var out := []
	# Genuine holes: the side cannot be fielded as it stands.
	var rucks := int((status.get("RUCK", {}) as Dictionary).get("short", 0))
	if rucks >= 2:
		out.append("We have no ruck we'd trust on the list.")
	elif rucks == 1:
		out.append("We only have one ruck we'd trust.")
	for role in ["MID", "DEF", "FWD"]:
		if int((status.get(role, {}) as Dictionary).get("short", 0)) > 0:
			out.append("As it stands we can't field a full %s." % LINE_WORD[role])
	# Depth: softer, and only when nothing structural is said.
	if out.is_empty():
		for role in ["MID", "DEF", "FWD", "RUCK"]:
			if int((status.get(role, {}) as Dictionary).get("light", 0)) >= 2:
				out.append("We're light for depth %s." % DEPTH_WORD[role])
				break
	# What the side does well, from the league-relative List Profile.
	for row in profile:
		if str(row.get("word", "")) == "Elite":
			out.push_front("Our %s is as good as anyone's." % str(row["label"]).to_lower())
			break
		if str(row.get("word", "")) == "Strong":
			out.push_front("Our %s is a strength." % str(row["label"]).to_lower())
			break
	var old := _old_core(list_players)
	if old >= 5:
		out.append("Our best players are getting on: %d of the top ten are 29 or older." % old)
	return out.slice(0, 3)


const LINE_WORD := {"MID": "midfield", "DEF": "back line", "FWD": "forward line"}
const DEPTH_WORD := {"MID": "in the midfield", "DEF": "in defence", "FWD": "up forward", "RUCK": "in the ruck"}


static func _old_core(list_players: Array) -> int:
	var best := list_players.duplicate()
	best.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var n := 0
	for p in best.slice(0, 10):
		if float(p.get("age", 0.0)) >= 29.0:
			n += 1
	return n


## A few prospects likely to be around at your first pick, different
## positions where the window allows, each with why the panel liked him.
static func prospect_lines(draft: Draft) -> Array:
	var picks := draft.upcoming_picks(draft.user_club, 1)
	if picks.is_empty():
		return []
	var first := int(picks[0])
	var avail := []
	for p in draft.pool:
		if not draft.picked.has(str(p["id"])):
			avail.append(p)
	avail.sort_custom(func(a, b):
		var aw := DraftScouting.scouted_worth(a, draft.user_club, draft.seed, Draft.AI_POT_WEIGHT_INTAKE)
		var bw := DraftScouting.scouted_worth(b, draft.user_club, draft.seed, Draft.AI_POT_WEIGHT_INTAKE)
		if not is_equal_approx(aw, bw):
			return aw > bw
		return str(a["id"]) < str(b["id"]))
	# Rival picks still to come before yours: the window starts there.
	var ahead := maxi(0, first - 1 - draft.pick_index)
	var lo := clampi(ahead - WINDOW_BEFORE, 0, maxi(0, avail.size() - 1))
	var window := avail.slice(lo, mini(avail.size(), ahead + WINDOW_AFTER + 1))
	var chosen := []
	var roles := {}
	for p in window:
		if chosen.size() >= NAMES:
			break
		if roles.has(str(p["role"])):
			continue
		roles[str(p["role"])] = true
		chosen.append(p)
	for p in window:
		if chosen.size() >= NAMES:
			break
		if not chosen.has(p):
			chosen.append(p)
	# No order of preference: as the board lists them, by name.
	chosen.sort_custom(func(a, b): return GameDB.player_display_name(a) < GameDB.player_display_name(b))
	var out := []
	for p in chosen:
		out.append({"id": str(p["id"]), "line": reason(p)})
	return out


## Why the panel liked him, in a sentence, and its doubt when it has one.
static func reason(p: Dictionary) -> String:
	var name := GameDB.player_display_name(p)
	var where := str(p.get("draft_league", ""))
	var h := int(p.get("height_cm", 0))
	var why := ""
	match str(p.get("role", "MID")):
		"FWD":
			if float(p.get("u18_gl", 0.0)) >= 1.5:
				why = "kicked %.1f goals a game%s" % [float(p["u18_gl"]), _in(where)]
			elif h >= 193:
				why = "a %d cm marking target who presents up the ground" % h
			else:
				why = "dangerous at ground level, %.1f goals a game%s" % [float(p.get("u18_gl", 0.0)), _in(where)]
		"DEF":
			if h >= 192:
				why = "%d cm and strong enough to go to a key forward" % h
			elif float(p.get("u18_mk", 0.0)) >= 5.0:
				why = "reads the ball in the air, %d marks a game%s" % [int(round(float(p["u18_mk"]))), _in(where)]
			else:
				why = "runs it out of defence with %d disposals a game" % int(round(float(p.get("u18_di", 0.0))))
		"RUCK":
			why = "%d cm, %d hit-outs a game%s" % [h, int(round(float(p.get("u18_ho", 0.0)))), _in(where)]
		_:
			if float(p.get("u18_tk", 0.0)) >= 5.0:
				why = "wins his own ball and tackles hard, %d tackles a game" % int(round(float(p["u18_tk"])))
			else:
				why = "finds plenty of it, %d disposals a game%s" % [int(round(float(p.get("u18_di", 0.0)))), _in(where)]
	var line := "%s: %s." % [name, why]
	var gm := int(p.get("u18_gm", 0))
	if gm > 0 and gm < THIN_GAMES:
		line += " We only saw him %d times this year." % gm
	return line


static func _in(where: String) -> String:
	return " in the %s" % where if where != "" else ""
