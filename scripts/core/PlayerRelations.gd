class_name PlayerRelations
extends RefCounted
## Family ties between players, said in the bio: "Brother of Jacob van Rooyen
## (Melbourne)". Static, sourced facts from data/player_relations.csv (one
## direction per row; the other direction is made here). Nothing is saved and
## nothing here touches the simulation. Real players only: a generated player
## has no family (yet), and with fictional names on the real names stay hidden.

const PATH := "res://data/player_relations.csv"
## What the same row says from the other person's side.
const REVERSE := {
	"brother": "brother", "twin brother": "twin brother", "cousin": "cousin",
	"son of": "father of", "grandson of": "grandfather of", "nephew of": "uncle of",
}
const PHRASE := {
	"brother": "Brother of", "twin brother": "Twin brother of", "cousin": "Cousin of",
	"son of": "Son of", "grandson of": "Grandson of", "nephew of": "Nephew of",
	"father of": "Father of", "grandfather of": "Grandfather of", "uncle of": "Uncle of",
}

static var _by_key := {}
static var _loaded := false


static func key(first: String, last: String, dob: String) -> String:
	return "%s|%s|%s" % [first.strip_edges().to_lower().replace("'", ""),
			last.strip_edges().to_lower().replace("'", ""), dob.strip_edges()]


static func _player_key(p: Dictionary) -> String:
	return key(str(p.get("first", "")), str(p.get("last", "")), str(p.get("dob", "")))


## Tests feed rows directly: an Array of row Dictionaries (the CSV's columns).
## null goes back to the file.
static func set_rows_for_test(rows) -> void:
	_by_key = {}
	_loaded = rows == null
	if rows != null:
		_index(rows)
		_loaded = true
	else:
		_loaded = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var header := f.get_csv_line()
	var rows: Array = []
	while not f.eof_reached():
		var cells := f.get_csv_line()
		if cells.size() < header.size() or str(cells[0]).strip_edges() == "":
			continue
		var r := {}
		for i in range(header.size()):
			r[header[i].strip_edges()] = cells[i].strip_edges()
		rows.append(r)
	_index(rows)


static func _index(rows: Array) -> void:
	for r in rows:
		var rel := str(r.get("relation", ""))
		if not REVERSE.has(rel):
			continue
		var games_text := str(r.get("other_games", ""))
		var tie := {"relation": rel, "first": str(r["other_first"]), "last": str(r["other_last"]),
				"dob": str(r.get("other_dob", "")), "club": str(r.get("other_club", "")),
				"games": int(games_text) if games_text != "" else 0}
		_add(key(str(r["first"]), str(r["last"]), str(r.get("dob", ""))), tie)
		# The other side hears it back, when he is a known person.
		if str(r.get("other_dob", "")) != "":
			_add(key(tie["first"], tie["last"], tie["dob"]), {"relation": REVERSE[rel],
					"first": str(r["first"]), "last": str(r["last"]), "dob": str(r.get("dob", "")),
					"club": str(r.get("club", "")), "games": 0})


static func _add(k: String, tie: Dictionary) -> void:
	if not _by_key.has(k):
		_by_key[k] = []
	(_by_key[k] as Array).append(tie)


## The player in the game with this name and birthday, as
## {"p", "club", "prospect"}; {} when he is not in the game. `club` is where he
## is listed now (a career's trades count); a draft prospect has none yet.
static func find(first: String, last: String, dob: String) -> Dictionary:
	if dob == "":
		return {}
	var k := key(first, last, dob)
	var groups: Array = [GameState.my_list, GameState.free_agents]
	if GameState.season != null:
		for code in GameState.season.lists:
			groups.append(GameState.season.lists[code])
	for code in GameState.league_lists:
		groups.append(GameState.league_lists[code])
	for arr in groups:
		for q in arr:
			if q is Dictionary and not bool(q.get("generated", false)) and _player_key(q) == k:
				return {"p": q, "club": str(q.get("club", "")), "prospect": false}
	for q in GameDB.players:
		if _player_key(q) == k:
			return {"p": q, "club": str(q.get("club", "")), "prospect": false}
	for q in GameDB.draftees:
		if _player_key(q) == k:
			return {"p": q, "club": "", "prospect": true}
	return {}


## His ties, each {"phrase", "name", "found" (in the game), "player", "club"
## (code, or ""), "note" (the words in brackets, "" if none)}.
static func ties(p: Dictionary) -> Array:
	var out: Array = []
	# Sourced ties name real people, so only with real names on; a generated
	# family (FamilyTies) is fictional either way and follows the display names.
	if not bool(p.get("generated", false)) and GameState.show_real_names:
		out = _sourced_ties(p)
	out.append_array(_generated_ties(p))
	return out


static func _sourced_ties(p: Dictionary) -> Array:
	var out: Array = []
	_load()
	var mine := find(str(p.get("first", "")), str(p.get("last", "")), str(p.get("dob", "")))
	var my_club := str(mine.get("club", ""))
	if mine.is_empty() or bool(mine.get("prospect", false)):
		my_club = ""
	for t in _by_key.get(_player_key(p), []):
		var o := find(str(t["first"]), str(t["last"]), str(t["dob"]))
		var tie := {"phrase": PHRASE[t["relation"]], "name": "%s %s" % [t["first"], t["last"]],
				"found": not o.is_empty(), "player": o.get("p", {}), "club": "", "note": ""}
		if not o.is_empty():
			tie["name"] = GameDB.player_display_name(o["p"])
			if bool(o["prospect"]):
				tie["note"] = "%d draft prospect" % int(o["p"].get("draft_year", 2026))
			else:
				tie["club"] = str(o["club"])
				if my_club != "" and my_club == tie["club"]:
					tie["club"] = ""
					tie["note"] = "teammate"
		elif str(t["club"]) != "":
			tie["club"] = str(t["club"])
			tie["former"] = true
		if int(t["games"]) > 0:
			tie["games"] = int(t["games"])
		out.append(tie)
	return out


## The words in a tie's brackets: "former Collingwood", "86 games, Collingwood".
static func note_text(tie: Dictionary) -> String:
	if str(tie.get("note", "")) != "":
		return str(tie["note"])
	var club := ""
	if str(tie.get("club", "")) != "":
		club = GameDB.club_name(str(tie["club"]))
	if int(tie.get("games", 0)) > 0:
		var g := "%d %s" % [int(tie["games"]), "game" if int(tie["games"]) == 1 else "games"]
		return "%s, %s" % [g, club] if club != "" else g
	if club != "" and bool(tie.get("former", false)):
		return "former " + club
	return club


## The whole line as plain words (tests, and anything that cannot hold a button).
static func line(p: Dictionary) -> String:
	var bits: PackedStringArray = []
	for t in ties(p):
		var n := note_text(t)
		bits.append("%s %s%s" % [t["phrase"], t["name"], " (%s)" % n if n != "" else ""])
	return " · ".join(bits)


# ---------------------------------------------------------------------------
# Generated families: p["family"] on the draftee, and the other side found by
# scanning (nothing is stored on the older man).
# ---------------------------------------------------------------------------
const REVERSE_PHRASE := {"brother": "Brother of", "son of": "Father of"}


## Every player held in the game right now, each as {"p", "club", "prospect"}
## (a prospect is in a draft pool and on no list yet).
static func _everyone() -> Array:
	var out: Array = []
	var groups: Array = [GameState.my_list, GameState.free_agents]
	for code in GameState.league_lists:
		groups.append(GameState.league_lists[code])
	if GameState.season != null:
		for code in GameState.season.lists:
			groups.append(GameState.season.lists[code])
	var seen := {}
	for arr in groups:
		for q in arr:
			if q is Dictionary and not seen.has(str(q.get("id", ""))):
				seen[str(q.get("id", ""))] = true
				out.append({"p": q, "club": str(q.get("club", "")), "prospect": false})
	for arr in [GameState.draftee_pool, GameDB.late_draftees]:
		for q in arr:
			if q is Dictionary and not seen.has(str(q.get("id", ""))):
				seen[str(q.get("id", ""))] = true
				out.append({"p": q, "club": "", "prospect": true})
	return out


static func _generated_ties(p: Dictionary) -> Array:
	var out: Array = []
	var id := str(p.get("id", ""))
	var everyone := _everyone()
	var by_id := {}
	for e in everyone:
		by_id[str(e["p"].get("id", ""))] = e
	var mine: Dictionary = by_id.get(id, {})
	var my_club := "" if mine.is_empty() or bool(mine["prospect"]) else str(mine["club"])
	for f in p.get("family", []):
		var oid := str(f.get("id", ""))
		var o: Dictionary = by_id.get(oid, {})
		var tie := {"phrase": PHRASE[str(f["relation"])], "found": not o.is_empty(),
				"player": o.get("p", {}), "club": "", "note": "",
				"name": GameDB.player_display_name_by_id(oid, "a former player")}
		if o.is_empty():
			# Retired: kept by name only.
			if str(f.get("club", "")) != "":
				tie["club"] = str(f["club"])
				tie["former"] = true
		else:
			_place(tie, o, my_club)
		out.append(tie)
	if id == "":
		return out
	for e in everyone:
		for f in e["p"].get("family", []):
			if str(f.get("id", "")) == id and REVERSE_PHRASE.has(str(f["relation"])):
				var tie := {"phrase": REVERSE_PHRASE[str(f["relation"])], "found": true, "player": e["p"],
						"club": "", "note": "", "name": GameDB.player_display_name(e["p"])}
				_place(tie, e, my_club)
				out.append(tie)
	return out


static func _place(tie: Dictionary, o: Dictionary, my_club: String) -> void:
	if bool(o["prospect"]):
		tie["note"] = "%d draft prospect" % int(o["p"].get("draft_year", 2026))
	else:
		tie["club"] = str(o["club"])
		if my_club != "" and my_club == tie["club"]:
			tie["club"] = ""
			tie["note"] = "teammate"
