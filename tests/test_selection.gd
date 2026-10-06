extends RefCounted
## Team selection: auto-pick is unchanged, a named side is what takes the
## field (out of position too), gaps and over-full slots are handled, a player
## you leave out really does not play, and the selection is saved.
## Run through tests/run_selection_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_auto_matches_select_22()
	_test_ruck_selection_integrity()
	_test_named_side()
	_test_formation_layout()
	_test_gaps_and_overflow()
	_test_left_out_player_sits_out()
	_test_selection_saved()
	_test_with_us_and_milestones()
	GameState.delete_saved_career()
	print("Selection tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _ids(arr: Array) -> Array:
	var out := []
	for p in arr:
		out.append(str(p["id"]))
	return out


func _new_season() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))


func _test_auto_matches_select_22() -> void:
	var list: Array = GameDB.club_list("COL")
	var a := Ratings.select_22(list)
	var b := Ratings.select_side(list, {})
	_check(_ids(a["ground"]) == _ids(b["ground"]) and _ids(a["bench"]) == _ids(b["bench"]),
			"With no selection the side is exactly the automatic best 22")


## Automatic selection treats ruck as a specialist position. A higher-OVR
## recognised ruck must not start ahead of a clearly better tap player.
func _test_ruck_selection_integrity() -> void:
	var list: Array = []
	var ruck_ids := []
	for src in GameDB.players:
		var p: Dictionary = src.duplicate(true)
		list.append(p)
		if Ratings.plays_role(p, "RUCK"):
			ruck_ids.append(str(p["id"]))
			p["attr"]["ruck"] = 40
	_check(ruck_ids.size() >= 2, "The league pool contains two recognised rucks for the selection test")
	if ruck_ids.size() < 2:
		return
	var high_ovr: String = str(ruck_ids[0])
	var tapper: String = str(ruck_ids[1])
	for p in list:
		if str(p["id"]) == high_ovr:
			p["overall"] = 99
			p["attr"]["ruck"] = 55
		elif str(p["id"]) == tapper:
			p["overall"] = 50
			p["attr"]["ruck"] = 90
	var side := Ratings.select_22(list)
	var starter := ""
	for p in side["ground"]:
		if str(p["role"]) == "RUCK":
			starter = str(p["id"])
			break
	_check(starter == tapper,
			"Auto-pick starts the best tap ruck, not the highest-OVR recognised ruck")


## The selection screen lays the 18 out as football lines rather than a
## serial list. The centre square keeps the two wings outside three mids
## with the ruck in the middle.
func _test_formation_layout() -> void:
	_new_season()
	var side := GameState.current_side()
	var scene = load("res://scripts/ui/SelectionScene.gd").new()
	var layout: Dictionary = scene._formation_layout(side)
	_check((layout["forwards"] as Array).size() == 6
			and (layout["defence"] as Array).size() == 6
			and (layout["midfield"] as Array).size() == 6,
			"The formation is two six-player lines around a six-player midfield")
	var mid: Array = layout["midfield"]
	_check(str(mid[0]) == str(side["WING"][0]) and str(mid[2]) == str(side["WING"][1])
			and str(mid[4]) == str(side["RUCK"][0]),
			"The centre shape puts the wings outside and the ruck in the middle")
	var field := []
	field.append_array(layout["forwards"])
	field.append_array(layout["midfield"])
	field.append_array(layout["defence"])
	var unique := {}
	for id in field:
		if str(id) != "":
			unique[str(id)] = true
	_check(field.size() == 18 and unique.size() == 18,
			"Every on-field player appears once in the formation")
	_check((layout["bench"] as Array).size() == 5,
			"The five-player interchange sits below the oval")
	scene.free()


func _test_named_side() -> void:
	_new_season()
	var side := GameState.current_side()
	# Swap a forward into the midfield and a midfielder forward.
	var fwd := str(side["FWD"][0])
	var mid := str(side["MID"][0])
	side["FWD"][0] = mid
	side["MID"][0] = fwd
	GameState.set_selection(side)
	var squad := GameState.my_squad()
	var roles := {}
	for p in squad.ground:
		roles[str(p["id"])] = str(p["role"])
	_check(roles.get(fwd, "") == "MID" and roles.get(mid, "") == "FWD",
			"Named players play where you put them, out of position too")
	_check(squad.ground.size() == 18 and squad.bench.size() == 5, "It is 18 plus 5")


func _test_gaps_and_overflow() -> void:
	_new_season()
	var side := GameState.current_side()
	var gone := str(side["DEF"][0])
	GameState.list_player(gone)["injury_weeks"] = 3
	# Overfill the forwards with two extra names from the bench.
	(side["FWD"] as Array).append(side["BENCH"][0])
	(side["FWD"] as Array).append(side["BENCH"][1])
	GameState.set_selection(side)
	var squad := GameState.my_squad()
	var ground := _ids(squad.ground)
	var counts := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
	for p in squad.ground:
		counts[str(p["role"])] = int(counts[str(p["role"])]) + 1
	_check(not ground.has(gone) and not _ids(squad.bench).has(gone),
			"An unavailable named player sits out")
	_check(counts == {"RUCK": 1, "MID": 5, "DEF": 6, "FWD": 6},
			"Every slot is filled exactly, gap filled and overflow capped (%s)" % str(counts))
	GameState.list_player(gone)["injury_weeks"] = 0


func _test_left_out_player_sits_out() -> void:
	_new_season()
	var side := GameState.current_side()
	var star := str(side["MID"][0])
	(side["MID"] as Array).erase(star)
	side["OUT"] = [star]
	GameState.set_selection(side)
	GameState.advance()
	var res: Dictionary = GameState.last_match
	_check(not (res.get("players", {}) as Dictionary).has(star),
			"A player you leave out records no stats")
	_check(GameState.last_duty(star) == "Reserves", "Left out fit, his XP report says reserves")


func _test_selection_saved() -> void:
	_new_season()
	var side := GameState.current_side()
	(side["MID"] as Array).remove_at(0)
	GameState.set_selection(side)
	GameState.save_career()
	GameState.load_career()
	_check(GameState.my_selection() == side, "The selection survives a save")
	GameState.set_selection({})
	_check(GameState.my_selection().is_empty(), "Auto-pick clears it")


## The profile remembers what a player did for you; a milestone is marked the
## week he reaches it.
func _test_with_us_and_milestones() -> void:
	_new_season()
	var year: int = GameState.season_year
	var id := str(GameState.current_side()["MID"][0])
	var p := GameState.list_player(id)
	p["career"] = {"games": 99, "goals": 30, "through": year - 1, "unknown": [],
			"stints": [["COL", year - 8, year - 6, 40, 10], ["GEE", year - 5, year - 1, 59, 20]]}
	GameState.honour_roll = [
		{"year": year - 3, "my_club": "GEE", "premier": "GEE", "my_bf": [{"id": id}]},
		{"year": year - 2, "my_club": "GEE", "premier": "SYD", "my_bf": [{"id": "someone"}]},
	]
	var w := GameState.with_us(p)
	_check(int(w["games"]) == 59 and int(w["goals"]) == 20 and int(w["since"]) == year - 5,
			"With us counts only his games for your club: %s" % str(w))
	_check(GameState.with_us_text(p) == "With us since %d: 59 games, 20 goals. Best and fairest %d. Premiership %d." % [
			year - 5, year - 3, year - 3], "With us in words: " + GameState.with_us_text(p))
	var notes := GameState.milestone_notes()
	var found := false
	for n in notes:
		if str(n["player_id"]) == id and str(n["text"]).ends_with("plays his 100th game."):
			found = true
	_check(found, "A player in the side on 99 games has his 100th marked: %s" % str(notes))
	p["career"]["games"] = 97
	var none := true
	for n in GameState.milestone_notes():
		if str(n["player_id"]) == id:
			none = false
	_check(none, "No milestone note on an ordinary week")
	var stranger := {"id": "x", "career": {"games": 10, "goals": 1, "through": year - 1, "unknown": [],
			"stints": [["SYD", year - 2, year - 1, 10, 1]]}}
	_check(GameState.with_us_text(stranger) == "", "Nothing for someone who never played for you")
