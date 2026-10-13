extends SceneTree
## godot --headless --path . --script tests/run_family_tests.gd
## Family ties in the bio (data/player_relations.csv): the line on the profile
## and the draft card, both directions, a relative outside the game, a real
## tap through to the relative, and no effect on the simulation.
## Seeded by design: the draft is built with an explicit seed (12345).

const Tap := preload("res://tests/tap.gd")
const BENJI_ID := "D2026_50"

var _state: Node
var _rel
var _sheet_script
var _db: Node
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	_state.show_real_names = true
	_db = root.get_node("GameDB")
	_rel = load("res://scripts/core/PlayerRelations.gd")
	_sheet_script = load("res://scripts/ui/PlayerSheet.gd")
	_state.reset()
	root.size = Vector2i(390, 844)
	_rel.set_rows_for_test(null)

	var jacob: Dictionary = _rel.find("Jacob", "van Rooyen", "2003-04-16").get("p", {})
	var benji: Dictionary = _rel.find("Benji", "van Rooyen", "2008-09-17").get("p", {})
	var jack: Dictionary = _rel.find("Jack", "Henry", "1998-08-29").get("p", {})
	var oliver: Dictionary = _rel.find("Oliver", "Henry", "2002-07-29").get("p", {})
	_check(not jacob.is_empty() and not benji.is_empty() and not jack.is_empty() and not oliver.is_empty(),
			"The four shipped players are in the game")

	# Every shipped row finds its players, and its line names the other person:
	# a wrong date of birth would otherwise be ignored without a word.
	var csv := FileAccess.open("res://data/player_relations.csv", FileAccess.READ)
	var head := csv.get_csv_line()
	var shipped := 0
	while not csv.eof_reached():
		var c := csv.get_csv_line()
		if c.size() < head.size() or c[0] == "":
			continue
		shipped += 1
		var who: Dictionary = _rel.find(c[0], c[1], c[2])
		_check(not who.is_empty(), "Row %s %s finds his player (%s)" % [c[0], c[1], c[2]])
		if who.is_empty():
			continue
		var l: String = _rel.line(who["p"])
		_check(l.contains("%s %s" % [c[5], c[6]]), "Row %s %s: his line names %s %s: %s" % [c[0], c[1], c[5], c[6], l])
		if c[7] != "":
			_check(not _rel.find(c[5], c[6], c[7]).is_empty(), "Row %s %s: %s %s is in the game" % [c[0], c[1], c[5], c[6]])
		print("LINE ", c[0], " ", c[1], " | ", l, " | ", c[10])
	_check(shipped >= 28, "The verified rows are in the file (%d)" % shipped)

	# Both ways round: the shipped file.
	_check(_rel.line(benji) == "Brother of Jacob van Rooyen (Melbourne)",
			"Benji's bio: " + _rel.line(benji))
	_check(_rel.line(jacob) == "Brother of Benji van Rooyen (2026 draft prospect)",
			"Jacob's bio: " + _rel.line(jacob))
	_check(_rel.line(jack) == "Brother of Oliver Henry (teammate)",
			"Jack's bio: " + _rel.line(jack))
	_check(_rel.line(oliver) == "Brother of Jack Henry (teammate)",
			"Oliver's bio: " + _rel.line(oliver))

	# Absent otherwise: a player with no row, and a generated one.
	var nobody: Dictionary = _db.players[5]
	_check(_rel.line(nobody) == "", "A player with no row has no family line")
	var gen := jack.duplicate(true)
	gen["generated"] = true
	_check(_rel.line(gen) == "", "A generated player has no family line")
	var fictional := true
	_state.show_real_names = false
	fictional = _rel.line(jack) == ""
	_state.show_real_names = true
	_check(fictional, "With fictional names on, no real name leaks into a bio")

	# Nothing is stored on the player.
	var keys_before := jack.keys().size()
	_rel.ties(jack)
	_check(jack.keys().size() == keys_before, "Reading ties adds nothing to the player (old saves load)")

	# A relative who is not in the game still shows by name; club words.
	_rel.set_rows_for_test([
		{"first": "Jack", "last": "Henry", "dob": "1998-08-29", "club": "GEE", "relation": "son of",
				"other_first": "Fred", "other_last": "Nobody", "other_dob": "", "other_club": "COL",
				"other_games": "212"},
		{"first": "Jack", "last": "Henry", "dob": "1998-08-29", "club": "GEE", "relation": "grandson of",
				"other_first": "Old", "other_last": "Timer", "other_dob": "", "other_club": "HAW",
				"other_games": ""},
		{"first": "Jack", "last": "Henry", "dob": "1998-08-29", "club": "GEE", "relation": "twin brother",
				"other_first": "Tim", "other_last": "Henry", "other_dob": "", "other_club": "",
				"other_games": ""},
	])
	var line: String = _rel.line(jack)
	_check(line == "Son of Fred Nobody (212 games, Collingwood) · Grandson of Old Timer (former Hawthorn)"
			+ " · Twin brother of Tim Henry", "Outside the game, several ties: " + line)
	_check(_rel.line(oliver) == "", "A one-way row about someone outside the game does not touch others")
	_rel.set_rows_for_test(null)

	# No effect on the simulation: nothing in sim or state reads it, and a seeded draft
	# board is the same with the file and with none.
	var board_with := _board_hash()
	_rel.set_rows_for_test([])
	var board_without := _board_hash()
	_rel.set_rows_for_test(null)
	_check(board_with == board_without, "A seeded draft board is identical with and without the file")
	var leaked := ""
	for dir in ["res://scripts/sim", "res://scripts/state"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and FileAccess.get_file_as_string(dir + "/" + f).contains("PlayerRelations"):
				leaked = dir + "/" + f
	_check(leaked == "", "No simulation or state script reads family ties " + leaked)

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	# The profile: line shown, and a real tap on the relative opens his own profile.
	var sheet: Control = _sheet_script.open(host, benji)
	await _settle()
	var tie: Control = sheet.find_child("FamilyTie_0", true, false)
	_check(tie != null, "Benji's profile has the relative as a button")
	if tie != null:
		var why: String = await Tap.tap(tie)
		await _settle()
		_check(why == "", "Real tap on the relative's name: " + why)
		var opened: bool = host.get_child_count() == 2 and _has_text(host.get_child(1), "Benji van Rooyen") 				and _has_text(host.get_child(1), "Brother of")
		_check(opened, "Tapping opens Jacob's profile, which says brother of Benji")
	for s in host.get_children():
		s.queue_free()
	await _settle()
	var plain: Control = _sheet_script.open(host, nobody)
	await _settle()
	_check(plain.find_child("FamilyTies", true, false) == null, "No family line on a profile without a tie")
	plain.queue_free()

	# The draft card, under the Ranked line.
	_state.replay_seed = 2027
	_state.begin_real_lists()
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	await _settle()
	ui.call("_on_club_chosen", "COL")
	await _settle()
	ui.call("_open_player", BENJI_ID)
	await _settle()
	var card: Control = ui.find_child("PlayerDetail", true, false)
	var ft: Control = card.find_child("FamilyTies", true, false) if card != null else null
	_check(ft != null, "Benji's draft card has the family line")
	if ft != null:
		var body := ft.get_parent()
		var ranked := -1
		for i in range(body.get_child_count()):
			var c := body.get_child(i)
			if c is Label and (c as Label).text.begins_with("Ranked #50"):
				ranked = i
		_check(ranked >= 0 and body.get_child(ranked + 1) == ft, "The family line sits under the Ranked line")
		_check(_has_text(ft, "Brother of") and _has_text(ft, "Jacob van Rooyen"), "The card says brother of Jacob van Rooyen")
	ui.call("_close_player")
	await _settle()
	ui.call("_open_player", str(_state.draft.pool[0]["id"]))
	await _settle()
	var card1: Control = ui.find_child("PlayerDetail", true, false)
	_check(card1 != null and card1.find_child("FamilyTies", true, false) == null,
			"A draft card with no tie has no family line")

	# --- Generated families (bio only) ---
	var fties = load("res://scripts/sim/FamilyTies.gd")
	var pros = load("res://scripts/sim/Prospects.gd")
	var seed_ := 777
	var pseudo: Array = []   # {id, age0, year0, club, generic, real_name, last}
	for q in _db.players:
		pseudo.append({"id": str(q["id"]), "age0": float(q["age"]), "year0": 2026, "club": str(q["club"]),
				"generic_name": str(q.get("generic_name", "")), "real_name": str(q.get("real_name", "")),
				"last": str(q.get("last", ""))})
	var cards := {}
	var sons := 0
	var brothers := 0
	var bad := ""
	var same_again := true
	var total_kids := 0
	for y in range(2027, 2047):
		var live: Array = []
		for e in pseudo:
			var d: Dictionary = e.duplicate()
			d["age"] = float(e["age0"]) + float(y - int(e["year0"]))
			live.append(d)
		var entries: Array = fties.listed_entries(live, 0.0)
		for e in live:
			if float(e["age"]) >= 38.0:
				cards[e["id"]] = {"age": e["age"], "year": y, "club": e["club"], "generic_name": e["generic_name"],
						"real_name": e["real_name"], "last": e["last"]}
		for e in live:
			if cards.has(e["id"]):
				pseudo = pseudo.filter(func(z): return z["id"] != e["id"])
		var cls: Array = pros.generate_class(y, seed_)
		var twin: Array = pros.generate_class(y, seed_)
		var ret: Array = fties.retired_entries(cards, y)
		var all_entries := entries.duplicate()
		all_entries.append_array(ret)
		fties.assign(cls, y, seed_, all_entries)
		fties.assign(twin, y, seed_, all_entries)
		var ages := {}
		for e in all_entries:
			ages[e["id"]] = float(e["age"])
		for i in range(cls.size()):
			total_kids += 1
			if JSON.stringify(cls[i].get("family", [])) != JSON.stringify(twin[i].get("family", [])):
				same_again = false
			for f in cls[i].get("family", []):
				var oa: float = ages[f["id"]]
				var ka: float = float(cls[i]["age"])
				if f["relation"] == "son of":
					sons += 1
					if oa < 36.0 or oa - ka < 17.0 or ka < 17.0 or oa > 56.0:
						bad = "son %s father %.1f son %.1f year %d" % [f["id"], oa, ka, y]
				else:
					brothers += 1
					if oa < 18.0 or absf(oa - ka) > 10.0:
						bad = "brother %s other %.1f kid %.1f year %d" % [f["id"], oa, ka, y]
				var surname: String = str(cls[i]["generic_name"]).get_slice(" ", 1)
				if surname == "":
					bad = "no surname"
		for c in cls:
			if int(c["draft_rank"]) <= 12:
				pseudo.append({"id": str(c["id"]), "age0": float(c["age"]), "year0": y, "club": "COL",
						"generic_name": str(c["generic_name"]), "real_name": "", "last": ""})
	print("FAMILY 20 seasons: kids=%d sons=%d brothers=%d" % [total_kids, sons, brothers])
	_check(bad == "", "No impossible ages in 20 generated classes: " + bad)
	_check(sons > 0 and brothers > 0, "Both kinds of tie turn up over 20 classes")
	_check(float(sons + brothers) / float(total_kids) < 0.12, "Ties stay rare")
	_check(same_again, "The same year and seed give the same families")

	# A tie on a generated draftee: bio line both ways, real surname, save round trip.
	_state.reset()
	_state.replay_seed = 2027
	_state.start_season("COL", _db.club_list("COL"))
	var dad: Dictionary = _db.club_list("COL")[0]
	var kid: Dictionary = {}
	for q in _state.draftee_pool:
		if bool(q.get("generated", false)):
			kid = q
			break
	_check(not kid.is_empty(), "A generated draftee is in the pool")
	if not kid.is_empty():
		kid["family"] = [{"relation": "son of", "id": str(dad["id"]), "club": "COL", "former": false}]
		kid["family_real_last"] = str(dad["last"])
		_check(_rel.line(kid).begins_with("Son of "), "The draftee's bio says son of: " + _rel.line(kid))
		_check(_db.player_display_name(kid).ends_with(" " + str(dad["last"])), "He carries his father's real surname")
		_state.show_real_names = false
		_check(not _db.player_display_name(kid).ends_with(" " + str(dad["last"])) or str(dad["last"]) == "",
				"With fictional names on, no real surname shows")
		_state.show_real_names = true
		_check(_rel.line(dad).contains("Father of "), "The father's bio says father of: " + _rel.line(dad))
		var kid_id := str(kid["id"])
		var line_before: String = _rel.line(kid)
		_check(_state.save_career(), "The career saves")
		_state.reset()
		_check(_state.load_career(), "The career loads")
		var back := {}
		for q in _state.draftee_pool:
			if str(q["id"]) == kid_id:
				back = q
		_check(not back.is_empty() and back.get("family", []).size() == 1 and _rel.line(back) == line_before,
				"The tie survives a save and load: " + (_rel.line(back) if not back.is_empty() else "missing"))
	_state.replay_seed = 0
	print("%d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("FAIL: ", f)
	quit(0 if _failures.is_empty() else 1)


func _board_hash() -> int:
	var d = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(),
			_db.active_clubs(2026).duplicate(), 12345)
	var ids: Array = []
	for p in d.board("", "", "", "overall", true):
		ids.append(str(p["id"]))
	return hash(ids)


func _has_text(n: Node, needle: String) -> bool:
	if n is Label and (n as Label).text.contains(needle):
		return true
	if n is Button and (n as Button).text.contains(needle):
		return true
	for c in n.get_children():
		if _has_text(c, needle):
			return true
	return false


func _settle() -> void:
	for i in range(5):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
