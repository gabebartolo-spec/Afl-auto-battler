class_name Captaincy
extends RefCounted
## Who leads a club: a captain and up to two vice-captains (three leaders in
## all; co-captains are two or three captains), for every club by the same
## rules. Pure rules: GameState holds the records and applies the costs.
##
## A club's record, saved under GameState.captaincy[code]:
##   slots    [{"id", "role"}] in order, role "captain" or "vice"
##   since    the year it was last named
##   changes  {"<year>": n} captains taken off mid-season (one a year for you)
##   passed   {"<id>": year} players already passed over once
##   log      [{"y", "w", "text"}] the last few changes, newest last
## A club with nothing named has no slots. An older save has no record at all,
## which reads the same.
##
## Costs, all of them said before the pick (preview, rules_text) and none hidden:
##   - passing over a senior player stings once,
##   - taking the armband off mid-season costs him, one change a season.
## There is no suggested captain anywhere: the list shows Leadership plainly.

const MAX_LEADERS := 3
const SENIOR_AGE := 28
const SENIOR_GAMES := 150
const PASSED_MORALE := -3
const PASSED_TRUST := -2
const STRIPPED_MORALE := -6
const STRIPPED_TRUST := -4
## Captains you may take the armband off after round 1 in a season.
const MID_SEASON_CHANGES := 1
## A rival club's chance, each week, of stripping an invented captain.
const AI_STRIP_CHANCE := 0.0025
## A rival captain out this long with injury stands down.
## A tunable so a test can force the roll.
static var strip_chance := AI_STRIP_CHANCE
const LONG_INJURY_WEEKS := 10
const LOG_KEEP := 8

const ROLE_WORDS := {"captain": "Captain", "vice": "Vice-captain"}


static func fresh(year: int) -> Dictionary:
	return {"slots": [], "since": year, "changes": {}, "passed": {}, "log": []}


static func slots(rec: Dictionary) -> Array:
	return rec.get("slots", []) if rec.get("slots") is Array else []


## Ids named, optionally only one role ("captain" or "vice").
static func ids(rec: Dictionary, role := "") -> Array:
	var out := []
	for s in slots(rec):
		if role == "" or str((s as Dictionary).get("role", "")) == role:
			out.append(str((s as Dictionary).get("id", "")))
	return out


static func is_named(rec: Dictionary, id: String) -> bool:
	return ids(rec).has(id)


static func role_of(rec: Dictionary, id: String) -> String:
	for s in slots(rec):
		if str((s as Dictionary).get("id", "")) == id:
			return str((s as Dictionary).get("role", ""))
	return ""


## The profile word for a named player ("Captain", "Vice-captain"), else "".
static func role_word(rec: Dictionary, id: String) -> String:
	return str(ROLE_WORDS.get(role_of(rec, id), ""))


static func _before(a: Dictionary, b: Dictionary) -> bool:
	var la := Leadership.of(a)
	var lb := Leadership.of(b)
	if la != lb:
		return la > lb
	var ga := Leadership.games(a)
	var gb := Leadership.games(b)
	if ga != gb:
		return ga > gb
	return str(a.get("id", "")) < str(b.get("id", ""))


## The rule every club without a record follows: the highest Leadership on the
## list is captain, the next two are vice-captains (ties: more games, then id).
static func by_rule(roster: Array, skip: Array = []) -> Array:
	var pool := []
	for p in roster:
		if p is Dictionary and not skip.has(str((p as Dictionary).get("id", ""))):
			pool.append(p)
	pool.sort_custom(_before)
	var out := []
	for i in range(mini(MAX_LEADERS, pool.size())):
		out.append({"id": str((pool[i] as Dictionary)["id"]), "role": "captain" if i == 0 else "vice"})
	return out


## The 2026 public record for a club: captains first, then vice-captains,
## best Leadership first, at most three. Empty when none of them is on the list.
static func from_record(club: String, roster: Array) -> Array:
	var caps := []
	var vices := []
	for p in roster:
		if not (p is Dictionary) or Leadership.role_club(p) != club:
			continue
		var r := Leadership.role_2026(p)
		if r == "captain":
			caps.append(p)
		elif r == "vice":
			vices.append(p)
	caps.sort_custom(_before)
	vices.sort_custom(_before)
	var out := []
	for p in caps:
		if out.size() < MAX_LEADERS:
			out.append({"id": str(p["id"]), "role": "captain"})
	for p in vices:
		if out.size() < MAX_LEADERS:
			out.append({"id": str(p["id"]), "role": "vice"})
	return out


## Keep what is named; a club with nothing is appointed by the rule, and one
## with no captain makes its best-rated vice captain (else the best player not
## yet named). Returns the new captain's id, or "" when nobody was made one.
static func fill(rec: Dictionary, roster: Array) -> String:
	if slots(rec).is_empty():
		rec["slots"] = by_rule(roster)
		var first := ids(rec, "captain")
		return str(first[0]) if not first.is_empty() else ""
	if not ids(rec, "captain").is_empty():
		return ""
	var by_id := {}
	for p in roster:
		by_id[str((p as Dictionary).get("id", ""))] = p
	var best := ""
	var best_p := {}
	for id in ids(rec, "vice"):
		var q: Dictionary = by_id.get(id, {})
		if not q.is_empty() and (best == "" or _before(q, best_p)):
			best = id
			best_p = q
	var out := []
	for s in slots(rec):
		out.append(s)
	if best == "":
		var extra := by_rule(roster, ids(rec))
		if extra.is_empty():
			return ""
		best = str(extra[0]["id"])
		out.insert(0, {"id": best, "role": "captain"})
		while out.size() > MAX_LEADERS:
			out.pop_back()
	else:
		for s in out:
			if str((s as Dictionary)["id"]) == best:
				s["role"] = "captain"
	rec["slots"] = out
	return best


## Drop everyone no longer on the list. Returns the ids dropped.
static func prune(rec: Dictionary, roster: Array) -> Array:
	var here := {}
	for p in roster:
		here[str((p as Dictionary).get("id", ""))] = true
	var keep := []
	var gone := []
	for s in slots(rec):
		if here.has(str((s as Dictionary).get("id", ""))):
			keep.append(s)
		else:
			gone.append(str((s as Dictionary).get("id", "")))
	rec["slots"] = keep
	return gone


static func changes_used(rec: Dictionary, year: int) -> int:
	return int((rec.get("changes", {}) as Dictionary).get(str(year), 0))


static func add_log(rec: Dictionary, year: int, when: String, text: String) -> void:
	var log: Array = rec.get("log", [])
	log.append({"y": year, "w": when, "text": text})
	while log.size() > LOG_KEEP:
		log.pop_front()
	rec["log"] = log


## The costs of replacing the current leaders with `new_slots`, worked out
## before anything changes, in words a coach would use. `roster` is the
## list; `mid_season` is true once the season has begun; `name_of` turns an
## id into the name shown. Returns {"ok", "why_not", "lines", "morale" {id: d},
## "trust" {id: d}, "used_change", "passed" [ids]}.
static func preview(rec: Dictionary, new_slots: Array, roster: Array, year: int, mid_season: bool,
		name_of: Callable) -> Dictionary:
	var out := {"ok": true, "why_not": "", "lines": [], "morale": {}, "trust": {}, "used_change": false, "passed": []}
	var by_id := {}
	for p in roster:
		by_id[str((p as Dictionary).get("id", ""))] = p
	var new_ids := []
	var new_caps := []
	for s in new_slots:
		new_ids.append(str((s as Dictionary)["id"]))
		if str((s as Dictionary)["role"]) == "captain":
			new_caps.append(str((s as Dictionary)["id"]))
	if new_slots.size() > MAX_LEADERS or (new_caps.is_empty() and not new_slots.is_empty()):
		out["ok"] = false
		out["why_not"] = "A club names a captain and up to two vice-captains."
		return out
	# Captains taken off the armband (still named as a vice does not matter).
	var removed := []
	for id in ids(rec, "captain"):
		if not new_caps.has(id) and by_id.has(id):
			removed.append(id)
	if mid_season and not removed.is_empty():
		if changes_used(rec, year) >= MID_SEASON_CHANGES:
			out["ok"] = false
			out["why_not"] = "You have already taken the armband off a captain this season."
			return out
		out["used_change"] = true
		for id in removed:
			out["morale"][id] = STRIPPED_MORALE
			out["trust"][id] = STRIPPED_TRUST
			(out["lines"] as Array).append("Taking the armband off %s mid-season costs him: his mood drops and he trusts you less. It is your one change this season." % name_of.call(id))
	# A senior player passed over: stings once.
	var added := []
	for id in new_caps:
		if not ids(rec, "captain").has(id):
			added.append(id)
	if not added.is_empty():
		var floor_lead := 99
		for id in added:
			floor_lead = mini(floor_lead, Leadership.of(by_id.get(id, {})))
		var pass_p := {}
		for p in roster:
			var q: Dictionary = p
			var qid := str(q.get("id", ""))
			if new_ids.has(qid) or (rec.get("passed", {}) as Dictionary).has(qid):
				continue
			if float(q.get("age", 0.0)) < float(SENIOR_AGE) or Leadership.games(q) < SENIOR_GAMES:
				continue
			if Leadership.of(q) <= floor_lead:
				continue
			if pass_p.is_empty() or _before(q, pass_p):
				pass_p = q
		if not pass_p.is_empty():
			var pid := str(pass_p["id"])
			out["morale"][pid] = PASSED_MORALE
			out["trust"][pid] = PASSED_TRUST
			(out["passed"] as Array).append(pid)
			(out["lines"] as Array).append("Passing over %s stings once: he is a senior player and rates higher on Leadership, so his mood and trust dip a little, one time." % name_of.call(pid))
	return out


## The rules, in football words, for the page to show before any pick.
static func rules_text() -> Array:
	return [
		"A captain and up to two vice-captains. Two or three captains can share the job.",
		"Passing over a senior player stings once: a player of %d or more with %d senior games who rates higher on Leadership loses a little mood and trust, one time." % [SENIOR_AGE, SENIOR_GAMES],
		"Taking the armband off a captain mid-season costs him, and you only get one change a season. Before round 1 changes are free.",
		"A captain who retires or leaves the club leaves the spot open.",
	]
