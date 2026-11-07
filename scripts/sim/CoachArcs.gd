class_name CoachArcs
extends RefCounted
## The coach's career arcs (director, 2026-11-03, plan
## step 1a; docs/research/COACH_ARC_CATALOGUE_2026-11-03.md). Arcs sit beside
## the random story deck and do not replace it: a beat of an active arc comes
## to the Hub as one more event card, on the deck's card UI and effect ops.
##
## An arc (data/arcs/coach_arcs.json) has a trigger read from real game state
## (ClubArcs), a list of beats, closing rules read at each season's start and
## endings. It lives for up to `max_seasons` seasons and, unless it says
## `cooldown_seasons`, runs once per career. A beat is due when the arc's
## previous beat is `gap` weeks behind (or, with `next_season`, a season
## behind) and its conditions hold; a beat whose conditions never come within
## `skip_after` weeks passes unplayed, so no arc stalls.
##
## Pure rules over the state ClubArcs hands in. The state, saved on GameState
## as `coach_arcs`:
##   coach   the player's coach record: seasons, games, flags, last_flag, start,
##           seen (last season counted), coached {player id: true}, club (code
##           now), clubs [{code, name, from, to, why, chairman}] (every club
##           coached, oldest first), sackings, moved {year, why, from, to},
##           reprieves (second chances left: a sacking with one left offers
##           jobs elsewhere; with none the coaching career is over), retired
##           (the year he retired, 0 while coaching)
##   move    a club change decided at a season's close, made at the rollover
##   offers  the clubs with a job open for him after a sacking, until he takes
##           one or retires: [{code, name, finish, list, goal, why_open}]
##   sack    the sacking those offers follow: {from, year, heir}
##   people  named people who are not players: chairman, journalist
##   active  {arc id: {start, start_w, beat, last_w, last_year, wait_from, who,
##           mem {remembered names}, flags {arc flag: week}}}
##   done    {arc id: {ending, year, times}}
##   counts  this season's counters: year, refusals, statements
##   log     [[year, week label, arc id, line]], oldest first

const FILE := "res://data/arcs/coach_arcs.json"
## Active arcs at once, and arc beats a week (one beat beside the deck's cards).
const MAX_ACTIVE := 3
const DEFAULT_GAP := 3
const DEFAULT_SKIP := 30
const LOG_KEEP := 400
const KINDS := ["club", "player"]
## Facts an arc's text may name beyond the deck's own (ClubArcs.arc_facts).
const ARC_FACTS := ["chairman", "journalist", "rival_club", "father", "seasons_coached",
		"coach_games", "coach_flags", "drought", "arc_year", "arc_seasons", "opp_is_rival",
		"old_club", "old_chairman", "former", "suitor", "suitor_president", "assistant", "assistant_to", "opp_is_old",
		"arc_times", "flag_year", "flag_years_on", "flag_reunion",
		# From the match stories (plan step 1b; MatchStory.arc_facts), this season:
		"hero_streak", "hero_count", "last_hero_mine", "hero_is_arc_player", "close_losses", "turned_against"]
## Facts a closing rule reads at a season's start (ClubArcs.close_facts).
const CLOSE_FACTS := ["sacked", "warned", "premiers", "met", "board", "here", "morale", "ladder_last"]

static var _cache: Array = []


static func all() -> Array:
	if _cache.is_empty():
		_cache = load_file(FILE)
	return _cache


static func load_file(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Array).filter(func(a): return a is Dictionary) if parsed is Array else []


static func by_id(defs: Array, id: String) -> Dictionary:
	for d in defs:
		if str(d.get("id", "")) == id:
			return d
	return {}


static func new_state() -> Dictionary:
	return {"coach": {"seasons": 0, "games": 0, "flags": 0, "last_flag": 0, "start": 0, "seen": 0, "coached": {},
			"club": "", "clubs": [], "sackings": 0, "moved": {}, "reprieves": 1, "retired": 0},
			"people": {}, "active": {}, "done": {}, "counts": {"year": 0, "refusals": 0, "statements": 0}, "log": [], "move": {},
			"offers": [], "sack": {}, "letter": {}}


## An older or partial state: every key present.
static func ensure(st: Dictionary) -> Dictionary:
	var fresh := new_state()
	for k in fresh:
		if not st.has(k) or typeof(st[k]) != typeof(fresh[k]):
			st[k] = fresh[k]
	var pre_reprieves := not (st["coach"] as Dictionary).has("reprieves")
	for k in fresh["coach"]:
		if not (st["coach"] as Dictionary).has(k):
			st["coach"][k] = fresh["coach"][k]
	# A save from before second chances: a coach already sacked once has had
	# his (he went straight on to another club), so the next sacking ends it.
	# The board's warning card says so plainly before it can happen (rule 60).
	if pre_reprieves and int(st["coach"]["sackings"]) >= 1:
		st["coach"]["reprieves"] = 0
	return st


## An old save's arc weeks onto the new story calendar (StoryEngine.from_old_week).
static func migrate_calendar(st: Dictionary) -> void:
	var active: Variant = st.get("active")
	if not (active is Dictionary):
		return
	for id in (active as Dictionary).keys():
		var rec: Variant = active[id]
		if not (rec is Dictionary):
			continue
		for f in ["start_w", "last_w", "wait_from"]:
			if (rec as Dictionary).has(f):
				rec[f] = StoryEngine.from_old_week(int(rec[f]))
		var fl: Variant = (rec as Dictionary).get("flags")
		if fl is Dictionary:
			for k in (fl as Dictionary).keys():
				fl[k] = StoryEngine.from_old_week(int(fl[k]))


## Can this arc start now? Not while it runs, not when MAX_ACTIVE run, and
## after it ended only once its cooldown (in seasons) has passed.
static func can_start(def: Dictionary, st: Dictionary, year: int) -> bool:
	var id := str(def["id"])
	if (st["active"] as Dictionary).has(id) or (st["active"] as Dictionary).size() >= MAX_ACTIVE:
		return false
	if not (st["done"] as Dictionary).has(id):
		return true
	var cd := int(def.get("cooldown_seasons", 0))
	return cd > 0 and year - int(st["done"][id].get("year", 0)) >= cd


static func start(st: Dictionary, def: Dictionary, year: int, w: int, who: String, mem: Dictionary) -> Dictionary:
	var rec := {"id": str(def["id"]), "start": year, "start_w": w, "beat": 0, "last_w": w, "last_year": year, "wait_from": w,
			"who": who, "mem": mem.duplicate(), "flags": {}}
	st["active"][str(def["id"])] = rec
	return rec


## The beat due for this arc this week, or {} (none, or not yet). Marks a beat
## that waited past its `skip_after` as passed, and moves on (once per call).
## `facts`: club facts merged with the arc's own (and its player's, if any).
static func due_beat(def: Dictionary, rec: Dictionary, w: int, year: int, phase: String, facts: Dictionary) -> Dictionary:
	var beats: Array = def.get("beats", [])
	var i := int(rec.get("beat", 0))
	if i >= beats.size():
		return {}
	var b: Dictionary = beats[i]
	var skip := false
	if bool(b.get("next_season", false)):
		if year <= int(rec.get("last_year", year)):
			return {}
		skip = year - int(rec.get("last_year", year)) > 1
	else:
		if w - int(rec.get("last_w", w)) < int(b.get("gap", DEFAULT_GAP)):
			return {}
		skip = w - int(rec.get("wait_from", w)) > int(b.get("gap", DEFAULT_GAP)) + int(b.get("skip_after", DEFAULT_SKIP))
	if skip:
		rec["beat"] = i + 1
		rec["wait_from"] = w
		rec["last_w"] = w
		rec["last_year"] = year
		rec["skipped"] = int(rec.get("skipped", 0)) + 1
		return {"_skipped": str(b.get("id", ""))}
	if not (b.get("phase", ["regular"]) as Array).has(phase):
		return {}
	if not meets(facts, b.get("when", {}), rec.get("flags", {})):
		return {}
	if not meets(facts, b.get("subject_where", {}), rec.get("flags", {})):
		return {}
	return b


## The deck's conditions (StoryEngine.meets), plus arc_flag / no_arc_flag on the arc's own flags.
static func meets(facts: Dictionary, cond: Dictionary, flags: Dictionary) -> bool:
	var rest := {}
	for k in cond:
		if str(k) == "arc_flag":
			if not flags.has(str(cond[k])):
				return false
		elif str(k) == "no_arc_flag":
			if flags.has(str(cond[k])):
				return false
		else:
			rest[k] = cond[k]
	return StoryEngine.meets(facts, rest, {})


## A beat answered: its arc flag, its ending (if it names one), the next beat.
## Returns the ending key the choice names, or "".
static func answer(def: Dictionary, rec: Dictionary, beat_id: String, key: String, w: int, year: int) -> String:
	var beats: Array = def.get("beats", [])
	var i := int(rec.get("beat", 0))
	if i >= beats.size() or str(beats[i].get("id", "")) != beat_id:
		return ""
	var arc := {}
	for c in beats[i].get("choices", []):
		if str(c.get("key", "")) == key:
			arc = c.get("arc", {})
	if str(arc.get("flag", "")) != "":
		rec["flags"][str(arc["flag"])] = w
	if key == "":
		rec["flags"]["silent_" + str(i)] = w
	rec["beat"] = i + 1
	rec["last_w"] = w
	rec["last_year"] = year
	rec["wait_from"] = w
	return str(arc.get("end", ""))


## Which ending this arc reaches at a season's start, or "" to run on. Rules
## marked beats_done wait for the last beat, until the arc has run its seasons.
static func closing(def: Dictionary, rec: Dictionary, facts: Dictionary, year: int) -> String:
	var all_done := int(rec.get("beat", 0)) >= (def.get("beats", []) as Array).size()
	var expired := year - int(rec.get("start", year)) >= int(def.get("max_seasons", 1))
	for r in def.get("close", []):
		if bool(r.get("beats_done", false)) and not all_done and not expired:
			continue
		# An arc that runs on ends only by a rule with conditions (or by
		# running its seasons), never by the always-rule.
		if bool(def.get("runs_on", false)) and not expired and (r.get("when", {}) as Dictionary).is_empty():
			continue
		if meets(facts, r.get("when", {}), rec.get("flags", {})):
			return str(r.get("ending", ""))
	return "faded" if expired else ""


static func finish(st: Dictionary, id: String, ending: String, year: int) -> void:
	var times := int((st["done"].get(id, {}) as Dictionary).get("times", 0)) + 1
	st["done"][id] = {"ending": ending, "year": year, "times": times}
	st["active"].erase(id)


static func log_line(st: Dictionary, year: int, label: String, id: String, line: String) -> void:
	(st["log"] as Array).append([year, label, id, line])
	while (st["log"] as Array).size() > LOG_KEEP:
		(st["log"] as Array).pop_front()


## Everything wrong with the arcs, one line each ([] when fit to play): each
## beat is checked as a deck card would be (StoryDeck), with the arc's names.
static func validate(defs: Array) -> Array:
	var errs := []
	var ids := {}
	var beat_ids := {}
	var deck_ids := {}
	for t in StoryDeck.all():
		deck_ids[str(t["id"])] = true
	for d in defs:
		var id := str(d.get("id", ""))
		if id == "" or ids.has(id):
			errs.append("an arc has no id, or its id is used twice: '%s'" % id)
		ids[id] = true
		var kind := str(d.get("kind", ""))
		if not KINDS.has(kind):
			errs.append("%s: kind must be club or player" % id)
		if str((d.get("trigger", {}) as Dictionary).get("kind", "")) == "":
			errs.append("%s: no trigger" % id)
		var player := kind == "player"
		var beats: Array = d.get("beats", [])
		if beats.is_empty():
			errs.append("%s: no beats" % id)
		var endings: Dictionary = d.get("endings", {})
		var close: Array = d.get("close", [])
		if close.is_empty() or not (close[-1].get("when", {}) as Dictionary).is_empty():
			errs.append("%s: the last closing rule must hold always" % id)
		for r in close:
			if not endings.has(str(r.get("ending", ""))):
				errs.append("%s: closing rule names an ending '%s' it does not have" % [id, str(r.get("ending", ""))])
		for e in endings:
			errs.append_array(_text(id + "/" + str(e), str(endings[e].get("line", "")), player))
			if absi(int(endings[e].get("board", 0))) > int(StoryDeck.CAPS["board"]):
				errs.append("%s/%s: an ending's board change is past the cap" % [id, str(e)])
		errs.append_array(_text(id, JSON.stringify(d.get("start_line", "")), player))
		errs.append_array(_text(id, str(d.get("season_line", "")), player))
		for b in beats:
			var bid := str(b.get("id", ""))
			if bid == "" or beat_ids.has(bid) or deck_ids.has(bid):
				errs.append("%s: beat id '%s' is missing or used twice" % [id, bid])
			beat_ids[bid] = true
			var bplayer: bool = player or b.has("subject")
			var card: Dictionary = b.duplicate(true)
			card["subject"] = {"kind": "player" if bplayer else "club"}
			if b.has("subject"):
				card["subject"].merge(b["subject"], true)
			var keys := {}
			for c in card.get("choices", []):
				keys[str(c.get("key", ""))] = true
				c.erase("arc")
			card.erase("gap"); card.erase("next_season"); card.erase("skip_after"); card.erase("subject_where")
			card.erase("when")
			_strip_arc_conds(card)
			for line in StoryDeck._check_card(_untokened(card)):
				errs.append("%s: %s" % [id, line])
			for k in (b.get("when", {}) as Dictionary):
				if not _known(str(k), StoryDeck.CLUB_FACTS + ARC_FACTS):
					errs.append("%s: unknown condition '%s'" % [bid, str(k)])
			for k in (b.get("subject_where", {}) as Dictionary):
				if not _known(str(k), StoryDeck.PLAYER_FACTS):
					errs.append("%s: unknown player condition '%s'" % [bid, str(k)])
			for c in b.get("choices", []):
				var end := str((c.get("arc", {}) as Dictionary).get("end", ""))
				if end != "" and not endings.has(end):
					errs.append("%s/%s: names an ending '%s' the arc does not have" % [bid, str(c.get("key", "")), end])
	return errs


## Takes the arc's own facts out of a beat's title, text and choice cases (the
## deck's checks do not know them).
static func _strip_arc_conds(card: Dictionary) -> void:
	var conds: Array = []
	for field in ["title", "text"]:
		for v in card.get(field, []):
			if v is Dictionary and (v as Dictionary).get("when") is Dictionary:
				conds.append(v["when"])
	for c in card.get("choices", []):
		if (c as Dictionary).get("when") is Dictionary:
			conds.append(c["when"])
	for cond in conds:
		for k in (cond as Dictionary).keys():
			var base := str(k)
			for suffix in ["_min", "_max", "_every"]:
				base = base.trim_suffix(suffix)
			if ARC_FACTS.has(base):
				(cond as Dictionary).erase(k)


## A beat with the arc's own names swapped for a club fact, so the deck's checks read it.
static func _untokened(card: Dictionary) -> Dictionary:
	var s := JSON.stringify(card)
	for f in ARC_FACTS:
		s = s.replace("{%s}" % f, "{club}")
	return JSON.parse_string(s)


static func _text(where: String, s: String, player: bool) -> Array:
	var errs := []
	var re := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for m in re.search_all(s):
		var f: String = m.get_string(1)
		if not (StoryDeck.CLUB_FACTS.has(f) or ARC_FACTS.has(f) or (player and StoryDeck.PLAYER_FACTS.has(f))):
			errs.append("%s: '{%s}' is not a fact this arc has" % [where, f])
	return errs


static func _known(k: String, facts: Array) -> bool:
	if k == "arc_flag" or k == "no_arc_flag":
		return true
	for suffix in ["_min", "_max", "_every"]:
		if k.ends_with(suffix):
			return facts.has(k.trim_suffix(suffix))
	return facts.has(k)
