class_name Firsts
extends RefCounted
## What a player did first for your club, kept on him so a later line can say
## it: p["firsts"] = {"debut": {"year", "label"}, "goal": {"year", "label"}}.
##   debut   his first senior game
##   goal    his first senior goal
## Each is written once, by GameState after your match, with the match's own
## label ("Round 7", "Grand Final"). Nothing is guessed: only a career on record
## in full gets one, and only a player of yours in a match of yours.
##
## Pure rules and wording. The player sheet's "With us" line and the full-time
## summary read them; nothing here touches the match.

## The most lines full time says about one match.
const MAX_LINES := 3


static func get_one(p: Dictionary, key: String) -> Dictionary:
	var all = p.get("firsts")
	if all is Dictionary and (all as Dictionary).get(key) is Dictionary:
		return (all as Dictionary)[key]
	return {}


static func has(p: Dictionary, key: String) -> bool:
	return not get_one(p, key).is_empty()


## Write it, once. False when it was already there.
static func note(p: Dictionary, key: String, year: int, label: String) -> bool:
	if has(p, key):
		return false
	if not (p.get("firsts") is Dictionary):
		p["firsts"] = {}
	(p["firsts"] as Dictionary)[key] = {"year": year, "label": label}
	return true


## Whether it happened in the match `label` played in `year`.
static func in_match(p: Dictionary, key: String, year: int, label: String) -> bool:
	var f := get_one(p, key)
	return not f.is_empty() and int(f.get("year", 0)) == year and str(f.get("label", "")) == label


## Where it happened: "in Round 7, 2028", "in the Grand Final, 2028", "in a Semi
## Final, 2028". A finals label carries a number only to tell the week's matches
## apart, so it goes.
static func when_text(f: Dictionary) -> String:
	var label := str(f.get("label", ""))
	var year := int(f.get("year", 0))
	if label == "":
		return "in %d" % year
	if label.begins_with("Round"):
		return "in %s, %d" % [label, year]
	var stage := label.rstrip("0123456789 ")
	if stage == "Grand Final":
		return "in the Grand Final, %d" % year
	var article := "an" if stage.substr(0, 1) in ["A", "E", "I", "O", "U"] else "a"
	return "in %s %s, %d" % [article, stage, year]


## The "With us" sentences, in the order they happened: "Debuted in Round 7,
## 2028, on your say-so." and "First goal in Round 9, 2028." Nothing for a
## player with neither on record.
static func with_us_bits(p: Dictionary) -> Array:
	var out := []
	var d := get_one(p, "debut")
	var g := get_one(p, "goal")
	if not d.is_empty():
		out.append("Debuted %s%s." % [when_text(d), ", on your say-so" if Backing.debuted_on_run(p) else ""])
	if not g.is_empty():
		var same := not d.is_empty() and int(d.get("year", 0)) == int(g.get("year", 0)) \
				and str(d.get("label", "")) == str(g.get("label", ""))
		out.append("First goal on debut." if same else "First goal %s." % when_text(g))
	return out


## "Calder debuted.", "Calder kicked a goal on debut.", "Calder kicked two on debut."
static func debut_line(who: String, goals: int) -> String:
	if goals <= 0:
		return "%s debuted." % who
	if goals == 1:
		return "%s kicked a goal on debut." % who
	return "%s kicked %s on debut." % [who, MatchNotes.count_word(goals)]


## What a match of yours settled, for full time: a debut, a first goal, a promised
## run that is done. Said only when the facts kept on the players say it, in
## this order: a debut on your promise, a run done, any other debut, a first goal.
## At most MAX_LINES; none for a match that settled nothing. `me` is your side,
## `year` the season, `find` looks one of your players up by id.
static func match_lines(res: Dictionary, me: int, year: int, find: Callable) -> Array:
	var roster: Array = res.get("roster", [])
	if me < 0 or roster.size() <= me:
		return []
	var label := str(res.get("label", ""))
	var stats_all: Dictionary = res.get("players", {})
	var ranked := []
	for r in roster[me]:
		var id := str(r.get("id", ""))
		var p: Dictionary = find.call(id)
		if p.is_empty():
			continue
		var who := GameDB.player_display_name(p)
		var goals := int((stats_all.get(id, {}) as Dictionary).get("goals", 0))
		if in_match(p, "debut", year, label):
			ranked.append([0 if Backing.debuted_on_run(p) else 2, debut_line(who, goals)])
		elif in_match(p, "goal", year, label):
			ranked.append([3, "First AFL goal for %s." % who])
		var run := Backing.finished_in(p, year, label)
		if not run.is_empty():
			ranked.append([1, "%s's %s-game run is done." % [who, MatchNotes.count_word(int(run["games"]))]])
	# Stable: the roster's order breaks a tie.
	var order := range(ranked.size())
	order.sort_custom(func(a, b):
		var ra: int = ranked[a][0]
		var rb: int = ranked[b][0]
		return ra < rb or (ra == rb and a < b))
	var out := []
	for i in order:
		out.append(str(ranked[i][1]))
		if out.size() >= MAX_LINES:
			break
	return out
