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
## is GameState.list_profile() ([] when there is no season to read it from);
## `plan` your standing game plan (GameState.club_plan).
static func notes(draft: Draft, list_players: Array, profile: Array, plan := "") -> Dictionary:
	return {"list": list_lines(draft.position_status(), list_players, profile),
			"names": prospect_lines(draft, plan)}


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
static func prospect_lines(draft: Draft, plan := "") -> Array:
	var picks := draft.upcoming_picks(draft.user_club, 1)
	if picks.is_empty():
		return []
	var first := int(picks[0])
	var avail := []
	for p in draft.pool:
		if not draft.picked.has(str(p["id"])):
			avail.append(p)
	avail.sort_custom(func(a, b):
		var aw := DraftScouting.scouted_worth(a, draft.user_club, draft.seed,
				Draft.AI_POT_WEIGHT_INTAKE, draft.scouting_mult_for(draft.user_club))
		var bw := DraftScouting.scouted_worth(b, draft.user_club, draft.seed,
				Draft.AI_POT_WEIGHT_INTAKE, draft.scouting_mult_for(draft.user_club))
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
	var status := draft.position_status()
	var mult := draft.scouting_mult_for(draft.user_club)
	var out := []
	for p in chosen:
		var line := reason(p)
		var fit := fit_line(p, status, plan)
		if fit != "":
			# The fit goes straight after the reason, before any doubt.
			var cut := line.find(" We only saw him")
			line = (line + " " + fit) if cut < 0 else (line.left(cut) + " " + fit + line.substr(cut))
		if split(p, draft.user_club, draft.seed, mult):
			line += " The panel is split on him."
		out.append({"id": str(p["id"]), "line": line})
	return out


# --- How he fits the list (RPG-007, director 2026-10-09: "Yes, as facts") ---
# One sentence at most, and only a true one: a hole he plays into, then depth
# he adds, then the game you play when his football is up to it. Never an
# order, never "best": the facts, and the choice stays yours.

## Key position: a back or forward this tall goes to a key opponent (the same
## bar reason() uses for "strong enough to go to a key forward").
const KEY_CM := 192
## Depth this light at his position is worth saying (as list_lines says it).
const LIGHT_SAY := 2


## The fit sentence for `p` against your list's `status` (Draft.position_status)
## and your standing `plan`, or "" when nothing true can be said.
static func fit_line(p: Dictionary, status: Dictionary, plan: String) -> String:
	var roles := [str(p.get("role", "MID"))]
	if str(p.get("role2", "")) != "" and not roles.has(str(p["role2"])):
		roles.append(str(p["role2"]))
	# A hole: the match-day side cannot be fielded at a position he plays.
	for role in roles:
		var short := int((status.get(role, {}) as Dictionary).get("short", 0))
		if short <= 0:
			continue
		if role == "RUCK":
			return "%s: we have none we'd trust." % _who(p, role) if short >= 2 					else "%s: we only have one we'd trust." % _who(p, role)
		return "%s: we can't field a full %s." % [_who(p, role), LINE_WORD[role]]
	# Depth: light at his position.
	for role in roles:
		if int((status.get(role, {}) as Dictionary).get("light", 0)) >= LIGHT_SAY:
			return "%s, where we're light for depth." % _who(p, role)
	return style_line(p, plan)


## "A key back", "A forward", "A midfielder", "A ruck" - or "Also a
## midfielder" when it is his second position, so a tall forward is never
## called a midfielder outright.
static func _who(p: Dictionary, role: String) -> String:
	var key := int(p.get("height_cm", 0)) >= KEY_CM
	var word := "a midfielder"
	match role:
		"DEF":
			word = "a key back" if key else "a back"
		"FWD":
			word = "a key forward" if key else "a forward"
		"RUCK":
			word = "a ruck"
	if role != str(p.get("role", "")):
		return "Also " + word
	return word.left(1).to_upper() + word.substr(1)


## The game your plan plays, in words, keyed like PlanFit.NEEDS.
const STYLE_WORD := {"defensive": "pressure", "attacking": "running", "contest": "contested",
		"controlled": "controlled"}


## "Suits our pressure game." when your plan leans on a kind of player
## (PlanFit.NEEDS, the attributes List Profile's Pressure, Running power,
## Contest and Control rows rate) and his football is at least an average
## AFL carrier's on them (PlanFit.LEAGUE's mean). Balanced and Through stars
## lean on no kind of player, so they say nothing.
static func style_line(p: Dictionary, plan: String) -> String:
	if not PlanFit.NEEDS.has(plan) or not STYLE_WORD.has(plan):
		return ""
	var need: Dictionary = PlanFit.NEEDS[plan]
	var role := str(p.get("role", "MID"))
	# Only the lines that carry the plan (a ruck's tap work is rated on its own
	# scale, so a ruck gets no style line).
	if not (need["lines"] as Array).has(role) or (p.get("attr", {}) as Dictionary).is_empty():
		return ""
	if PlanFit._value(p, need["attr"]) < float((PlanFit.LEAGUE[plan] as Array)[0]):
		return ""
	return "Suits our %s game." % STYLE_WORD[plan]


# --- When the panel is split ---
## The scouts' read of an ability (DraftScouting.combine_seen) against what he
## measured at the Combine on the same scale (Combine.measured): this far
## apart on any of movement, repeat effort or aerial and the room disagrees
## about him. Set from the data (tools/audit/panelsplit_impl.gd, the 2026
## class read by every club under 40 seeds): 17 points flags 12.9% of reads,
## about one prospect in eight (15 would flag 21.7%, 20 only 5.0%).
const SPLIT_GAP := 17.0


static func split(p: Dictionary, club: String, seed: int, mult := 1.0) -> bool:
	if not Combine.tested(p, seed):
		return false
	var seen := DraftScouting.combine_seen(p, club, seed, mult)
	for k in seen:
		var m := Combine.measured(p, str(k), seed)
		if m >= 0.0 and absf(float(seen[k]) - m) >= SPLIT_GAP:
			return true
	return false


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
