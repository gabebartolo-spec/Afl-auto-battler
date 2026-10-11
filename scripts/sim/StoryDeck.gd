class_name StoryDeck
extends RefCounted
## The week's story cards, as data (data/stories/<category>.json), and the
## checks every card must pass before the game will use it.
##
## A card marked "private" invents something about a player's private life,
## health of mind, family or misconduct: StoryEngine never picks a player
## shown under his real name for it.
##
## A card names: its category; who it is about (a player picked by conditions on
## saved facts, or the club); when it can come up; title and text variants;
## two or more choices, each with effects through levers the game already has
## (morale, development, the board, trust, selection, contracts) and flags that
## make later cards eligible (arcs). Effect sizes are capped here, so no card
## can carry a bigger swing than the game allows. StoryEngine picks and plays
## them; GameState applies the effects.

const DIR := "res://data/stories/"
const CATEGORIES := ["training", "health", "family", "media", "contracts", "leadership",
		"community", "rivals", "board", "members", "selection"]
const PHASES := ["regular", "finals"]
const BEATS := ["start", "middle", "end"]

## The biggest effect one choice may carry, per lever.
const CAPS := {"morale": 15, "xp": 26, "board": 8, "trust": Trust.STEP_MAX}
## Who a group effect reaches: the card's player, this week's side, the whole
## list, or everyone but him.
const WHO := ["subject", "side", "all", "others"]
## Every effect a card can carry. Ops marked true need a player subject.
const OPS := {
	"morale": false, "xp": false, "board": false, "trust": true, "rest": true, "sore": true,
	"fresh": false, "heavy_legs": false, "expects_game": true, "start_backing": true,
	"extend_early": true, "promise_win": false, "flag": false, "explain": true, "talk_note": true,
}

## Facts a player card can test and print (GameState._story_player_facts).
const PLAYER_FACTS := ["name", "first", "age", "games", "fit", "selected", "overall", "potential",
		"pot_gap", "contract_years", "morale", "trust", "trust_band", "discipline", "backed",
		"fit_rank", "talk_case", "kpi", "kpi_or_need", "explain_label", "talk_text", "sore_odds",
		"ask", "early_price", "more_seasons", "extension_ok", "job", "real_named"]
## Facts about the club and the week (GameState._story_club_facts).
const CLUB_FACTS := ["club", "opp", "round", "year", "losing_run", "winning_run", "ladder",
		"board", "fit_count", "run_games", "finals_week"]

const DEFAULTS := {"weight": 1, "cooldown": 40, "subject_cooldown": 8, "per_season": 0,
		"phase": ["regular"], "default": -1}

static var _cache: Array = []


## Every card in the game, loaded once.
static func all() -> Array:
	if _cache.is_empty():
		_cache = load_dir(DIR)
	return _cache


static func reload() -> void:
	_cache = []


## The cards in one folder, one file per category, with defaults filled in.
## A file that is missing or does not parse adds nothing (validate() says so).
static func load_dir(dir: String) -> Array:
	var out := []
	for cat in CATEGORIES:
		var path := "%s%s.json" % [dir, cat]
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array:
			for t in parsed:
				if t is Dictionary:
					out.append(normalise(t))
	return out


static func normalise(t: Dictionary) -> Dictionary:
	var n := t.duplicate(true)
	for k in DEFAULTS:
		if not n.has(k):
			n[k] = DEFAULTS[k] if not (DEFAULTS[k] is Array) else (DEFAULTS[k] as Array).duplicate()
	if not n.has("subject"):
		n["subject"] = {"kind": "club"}
	return n


static func by_id(deck: Array, id: String) -> Dictionary:
	for t in deck:
		if str(t.get("id", "")) == id:
			return t
	return {}


## Everything wrong with a deck, one line each ([] when it is fit to play).
static func validate(deck: Array) -> Array:
	var errs := []
	var ids := {}
	var flags_set := {}
	var flags_needed := {}
	var arc_ends := {}
	var arc_starts := {}
	for t in deck:
		var id := str(t.get("id", ""))
		if id == "":
			errs.append("A card has no id")
			continue
		if ids.has(id):
			errs.append("%s: the id is used twice" % id)
		ids[id] = true
		errs.append_array(_check_card(t))
		for c in t.get("choices", []):
			for e in (c as Dictionary).get("effects", []):
				if str((e as Dictionary).get("op", "")) == "flag":
					flags_set[str(e.get("name", ""))] = id
		var needs: Dictionary = t.get("needs", {})
		if not needs.is_empty():
			flags_needed[str(needs.get("flag", ""))] = id
		var arc := str(t.get("arc", ""))
		if arc != "":
			if str(t.get("beat", "")) == "end":
				arc_ends[arc] = true
			if str(t.get("beat", "")) == "start":
				arc_starts[arc] = id
	for f in flags_needed:
		if not flags_set.has(f):
			errs.append("%s: needs the flag '%s', which no card sets" % [flags_needed[f], f])
	for arc in arc_starts:
		if not arc_ends.has(arc):
			errs.append("%s: the arc '%s' has no ending" % [arc_starts[arc], arc])
	return errs


static func _check_card(t: Dictionary) -> Array:
	var errs := []
	var id := str(t["id"])
	if not CATEGORIES.has(str(t.get("category", ""))):
		errs.append("%s: unknown category '%s'" % [id, str(t.get("category", ""))])
	var subject: Dictionary = t.get("subject", {})
	var kind := str(subject.get("kind", "club"))
	if kind != "player" and kind != "club":
		errs.append("%s: subject kind must be player or club" % id)
	var player := kind == "player"
	if bool(t.get("private", false)) and not player:
		errs.append("%s: a private card must be about a player" % id)
	for ph in t.get("phase", []):
		if not PHASES.has(str(ph)):
			errs.append("%s: unknown phase '%s'" % [id, str(ph)])
	for k in (subject.get("where", {}) as Dictionary):
		if not _known_condition(str(k), PLAYER_FACTS):
			errs.append("%s: unknown player condition '%s'" % [id, str(k)])
	for k in (t.get("when", {}) as Dictionary):
		if not _known_condition(str(k), CLUB_FACTS):
			errs.append("%s: unknown club condition '%s'" % [id, str(k)])
	var pick := str(subject.get("pick", "random"))
	if not _known_pick(pick):
		errs.append("%s: unknown subject pick '%s'" % [id, pick])
	var arc := str(t.get("arc", ""))
	if arc != "" and not BEATS.has(str(t.get("beat", ""))):
		errs.append("%s: an arc card needs a beat (start, middle or end)" % id)
	if arc != "" and str(t.get("beat", "")) != "start" and (t.get("needs", {}) as Dictionary).is_empty():
		errs.append("%s: a follow-up needs a flag to follow" % id)
	for field in ["title", "text"]:
		var v = t.get(field, [])
		if not (v is Array) or (v as Array).is_empty():
			errs.append("%s: %s needs at least one variant" % [id, field])
			continue
		for s in v:
			errs.append_array(_check_text(id, str(s), player))
	var choices: Array = t.get("choices", [])
	if choices.size() < 2:
		errs.append("%s: a card needs at least two choices" % id)
	var d := int(t.get("default", -1))
	if d < -1 or d >= choices.size():
		errs.append("%s: the default choice does not exist" % id)
	var keys := {}
	for c in choices:
		var ck := str((c as Dictionary).get("key", ""))
		if ck == "" or keys.has(ck):
			errs.append("%s: every choice needs its own key" % id)
		keys[ck] = true
		if str(c.get("label", "")) == "":
			errs.append("%s/%s: the choice has no label" % [id, ck])
		for field in ["label", "note", "result"]:
			errs.append_array(_check_text("%s/%s" % [id, ck], str(c.get(field, "")), player))
		for e in c.get("effects", []):
			errs.append_array(_check_effect("%s/%s" % [id, ck], e, player))
	var un: Dictionary = t.get("unanswered", {})
	if absi(int(un.get("board", 0))) > int(CAPS["board"]):
		errs.append("%s: saying nothing costs more than the board cap" % id)
	return errs


static func _check_effect(where: String, e, player: bool) -> Array:
	var errs := []
	if not (e is Dictionary):
		return ["%s: an effect must be an object" % where]
	var op := str(e.get("op", ""))
	if not OPS.has(op):
		return ["%s: unknown effect '%s'" % [where, op]]
	var who := str(e.get("who", "subject"))
	if not WHO.has(who):
		errs.append("%s: unknown target '%s'" % [where, who])
	if (bool(OPS[op]) or ((op == "morale" or op == "xp") and (who == "subject" or who == "others"))) and not player:
		errs.append("%s: '%s' needs a player card" % [where, op])
	if CAPS.has(op):
		var dv := int(e.get("d", 0))
		if dv == 0 or absi(dv) > int(CAPS[op]):
			errs.append("%s: %s of %d is outside 1..%d" % [where, op, dv, int(CAPS[op])])
	if op == "trust" and str(e.get("why", "")) == "":
		errs.append("%s: a trust change needs its reason" % where)
	if op == "trust":
		errs.append_array(_check_text(where, str(e.get("why", "")), player))
	if op == "flag" and str(e.get("name", "")) == "":
		errs.append("%s: a flag needs a name" % where)
	return errs


## Placeholders must be facts the game supplies: {name} only on a player card.
static func _check_text(where: String, s: String, player: bool) -> Array:
	var errs := []
	var re := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for m in re.search_all(s):
		var f: String = m.get_string(1)
		if CLUB_FACTS.has(f):
			continue
		if player and PLAYER_FACTS.has(f):
			continue
		errs.append("%s: '{%s}' is not a fact this card has" % [where, f])
	return errs


static func _known_condition(k: String, facts: Array) -> bool:
	if k == "flag" or k == "no_flag":
		return true
	for suffix in ["_min", "_max", "_every"]:
		if k.ends_with(suffix):
			return facts.has(k.trim_suffix(suffix))
	return facts.has(k)


static func _known_pick(pick: String) -> bool:
	if pick == "random":
		return true
	var parts := pick.split(":")
	if parts.size() == 2 and (parts[0] == "highest" or parts[0] == "lowest"):
		return PLAYER_FACTS.has(parts[1])
	if parts.size() == 3 and parts[0] == "random_top":
		return parts[1].is_valid_int() and PLAYER_FACTS.has(parts[2])
	return false
