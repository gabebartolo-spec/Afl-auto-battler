class_name Traits
extends RefCounted
## Player traits and line synergies.
##
## A trait is earned from a player's current stats (so training can unlock
## one), and does one specific thing in a match. Players carry at most two
## good traits, plus Hothead if their discipline is poor. Synergies switch on
## when a line of the selected 18 carries the right mix of traits - so who
## you draft, trade for and pick matters beyond the overall rating.

## key -> label, the stat and threshold that earn it, the roles it counts
## for ([] = any), and what it does. "max" marks a bad trait (at or below).
const DEFS := {
	"ball_magnet": {"label": "Ball magnet", "stat": "disposal", "min": 86, "roles": ["MID", "DEF"],
			"text": "Wins 10% more of the ball in general play."},
	"bull": {"label": "Contested bull", "stat": "contested", "min": 84, "roles": ["MID", "RUCK"],
			"text": "Wins 15% more clearances and keeps the ball when tackled more often."},
	"ruck_king": {"label": "Ruck king", "stat": "ruck", "min": 84, "roles": ["RUCK"],
			"text": "Takes 5% more of the hit-outs."},
	"aerial": {"label": "Aerial threat", "stat": "marking", "min": 76, "roles": ["FWD"],
			"text": "Marks 6% more of the forward-50 contests he leads to."},
	"crumber": {"label": "Crumber", "stat": "goalkicking", "min": 55, "roles": ["FWD"], "small": true,
			"text": "A small forward: kicks 12% more goals from ground balls."},
	"sharpshooter": {"label": "Sharpshooter", "stat": "accuracy", "min": 71, "roles": [],
			"text": "+6% goal chance on every shot."},
	"playmaker": {"label": "Playmaker", "stat": "creating", "min": 75, "roles": [],
			"text": "Shots from his inside-50 deliveries are 5% more likely to be goals."},
	"interceptor": {"label": "Interceptor", "stat": "intercept", "min": 80, "roles": ["DEF"],
			"text": "Spoils 5% more of the forward-50 contests he is in."},
	"lockdown": {"label": "Lockdown", "stat": "pressure", "min": 64, "roles": ["DEF", "MID"],
			"text": "His opponent's shots are 4% less likely to be goals."},
	"engine": {"label": "Engine", "stat": "durability", "min": 91, "roles": [],
			"text": "Tires 25% slower."},
	"big_game": {"label": "Big-game player", "stat": "star", "min": 60, "roles": [],
			"text": "Lifts in the last quarter and in finals (+5% on every stat)."},
	"hothead": {"label": "Hothead", "stat": "discipline", "max": 20, "roles": [],
			"text": "Gives away 50% more clangers and free kicks."},
}

## key -> label, the line it needs ("" = the whole 18), the traits needed,
## and the match effect.
const SYNERGIES := {
	"engine_room": {"label": "Engine room", "line": "", "needs": {"bull": 2},
			"text": "+2.5% stoppage wins."},
	"tall_small": {"label": "Tall-small forward line", "line": "FWD", "needs": {"aerial": 1, "crumber": 1},
			"text": "+5% goal chance on every forward-50 shot."},
	"intercept_wall": {"label": "Intercept wall", "line": "DEF", "needs": {"interceptor": 2},
			"text": "-5% on the opposition's goal chance."},
	"lockdown_unit": {"label": "Lockdown unit", "line": "", "needs": {"lockdown": 3},
			"text": "+8% pressure on the opposition."},
	"supply_line": {"label": "Supply line", "line": "", "needs": {"ball_magnet": 2, "playmaker": 1},
			"text": "+6% metres gained per disposal."},
	"running_machine": {"label": "Running machine", "line": "", "needs": {"engine": 3},
			"text": "The whole side tires 15% slower."},
}

const MAX_GOOD := 2
const LINE_NAMES := {"RUCK": "ruck", "MID": "midfield", "DEF": "defence", "FWD": "forward line"}


static func label(key: String) -> String:
	return str((DEFS.get(key, SYNERGIES.get(key, {})) as Dictionary).get("label", key))


static func text(key: String) -> String:
	return str((DEFS.get(key, SYNERGIES.get(key, {})) as Dictionary).get("text", ""))


static func is_bad(key: String) -> bool:
	return (DEFS.get(key, {}) as Dictionary).has("max")


## A player's traits: up to two good ones (the furthest past their line
## first), then Hothead if it applies.
static func of(p: Dictionary) -> Array:
	var attr: Dictionary = p.get("attr", {})
	var roles := [str(p.get("role", "")), str(p.get("role2", "")), str(p.get("list_tag", ""))]
	var good := []
	var bad := []
	for key in DEFS:
		var d: Dictionary = DEFS[key]
		var need_roles: Array = d["roles"]
		if not need_roles.is_empty():
			var ok := false
			for r in roles:
				if need_roles.has(r):
					ok = true
			if not ok:
				continue
		var v := int(attr.get(str(d["stat"]), 0))
		if d.has("max"):
			if v <= int(d["max"]):
				bad.append(key)
			continue
		if v < int(d["min"]):
			continue
		if bool(d.get("small", false)) and int(attr.get("marking", 0)) >= 52:
			continue
		good.append([key, v - int(d["min"])])
	good.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var out := []
	for g in good.slice(0, MAX_GOOD):
		out.append(g[0])
	out.append_array(bad)
	return out


static func has(p: Dictionary, key: String) -> bool:
	return of(p).has(key)


## Trait counts per line for a set of on-ground players:
## {"": {trait: n}, "MID": {...}, ...}
static func _counts(ground: Array) -> Dictionary:
	var out := {"": {}, "RUCK": {}, "MID": {}, "DEF": {}, "FWD": {}}
	for p in ground:
		var line := str(p.get("role", "MID"))
		for t in of(p):
			out[""][t] = int(out[""].get(t, 0)) + 1
			if out.has(line):
				out[line][t] = int(out[line].get(t, 0)) + 1
	return out


## Synergies a side's on-ground players switch on.
static func active(ground: Array) -> Array:
	var counts := _counts(ground)
	var out := []
	for key in SYNERGIES:
		var s: Dictionary = SYNERGIES[key]
		var have: Dictionary = counts[str(s["line"])]
		var ok := true
		for t in s["needs"]:
			if int(have.get(t, 0)) < int(s["needs"][t]):
				ok = false
		if ok:
			out.append(key)
	return out


## Every synergy with how close the side is: [{key, active, have: {t: n},
## needs: {t: n}}], active ones first, then the nearest.
static func progress(ground: Array) -> Array:
	var counts := _counts(ground)
	var out := []
	for key in SYNERGIES:
		var s: Dictionary = SYNERGIES[key]
		var have_line: Dictionary = counts[str(s["line"])]
		var have := {}
		var missing := 0
		for t in s["needs"]:
			have[t] = mini(int(have_line.get(t, 0)), int(s["needs"][t]))
			missing += int(s["needs"][t]) - int(have[t])
		out.append({"key": key, "active": missing == 0, "missing": missing,
				"have": have, "needs": s["needs"]})
	out.sort_custom(func(a, b): return int(a["missing"]) < int(b["missing"]))
	return out


## "2/2 Contested bull (midfield)" style summary for one synergy row.
static func needs_text(row: Dictionary) -> String:
	var s: Dictionary = SYNERGIES[str(row["key"])]
	var bits: PackedStringArray = []
	for t in row["needs"]:
		bits.append("%d/%d %s" % [int(row["have"][t]), int(row["needs"][t]), label(str(t))])
	var line := str(s["line"])
	var where := " in the %s" % str(LINE_NAMES.get(line, line)) if line != "" else ""
	return ", ".join(bits) + where


## How far a player is from each trait he does not have: [{key, gap}] for
## gaps of 1-6 points, nearest first - Training shows these.
static func near(p: Dictionary) -> Array:
	var attr: Dictionary = p.get("attr", {})
	var have := of(p)
	var out := []
	var roles := [str(p.get("role", "")), str(p.get("role2", ""))]
	for key in DEFS:
		var d: Dictionary = DEFS[key]
		if d.has("max") or have.has(key):
			continue
		var need_roles: Array = d["roles"]
		if not need_roles.is_empty() and not (need_roles.has(roles[0]) or need_roles.has(roles[1])):
			continue
		if bool(d.get("small", false)) and int(attr.get("marking", 0)) >= 52:
			continue
		var gap := int(d["min"]) - int(attr.get(str(d["stat"]), 0))
		if gap >= 1 and gap <= 6:
			out.append({"key": key, "gap": gap, "stat": str(d["stat"])})
	out.sort_custom(func(a, b): return int(a["gap"]) < int(b["gap"]))
	return out
