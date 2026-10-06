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
	_test_fifth_interchange()
	_test_dual_ruck()
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

## 18 + 5 (ARD-M5-001): the fifth interchange player is a full member of the
## 23 - he rotates on, piles up stats, is credited with the game and earns a
## selected player's XP - and a side saved with four on the bench gets five.
func _test_fifth_interchange() -> void:
	for code in ["GEE", "COL"]:
		var sq := Squad.new(code, GameDB.club_list(code), true, code)
		_check(sq.ground.size() == 18 and sq.bench.size() == Ratings.INTERCHANGE and Ratings.INTERCHANGE == 5,
				"%s picks 18 plus 5 (%d + %d)" % [code, sq.ground.size(), sq.bench.size()])
	var played_all := true
	var stats_all := true
	var quiet := []
	var stints := 0
	for seed in [701, 702, 703]:
		var sim := MatchSim.new(Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE"),
				Squad.new("COL", GameDB.club_list("COL"), false, "COL"), seed)
		var bench_ids := [[], []]
		for side in 2:
			for p in (sim.squads[side] as Squad).bench:
				bench_ids[side].append(str(p["id"]))
		var res := sim.run()
		for side in 2:
			for id in bench_ids[side]:
				played_all = played_all and (sim._played[side] as Dictionary).has(id)
				var st: Dictionary = (res["players"] as Dictionary).get(id, {})
				stints += 1
				stats_all = stats_all and float(st.get("distance_run", 0.0)) > 0.0
				if int(st.get("disposals", 0)) + int(st.get("hitouts", 0)) + int(st.get("tackles", 0)) + int(st.get("marks", 0)) == 0:
					quiet.append("%s %s %s" % [seed, id, str(st)])
	_check(played_all, "All five on the bench come on during a match")
	_check(stats_all and quiet.size() * 10 <= stints, "All five on the bench take the field, and almost all get involved (quiet: %s)" % str(quiet))

	# XP and the game count: a round through the real season.
	_new_season()
	var side := GameState.current_side()
	var fifth := str(side["BENCH"][4])
	var out := ""
	for p in GameState.my_list:
		var id := str(p["id"])
		var named := false
		for k in side:
			named = named or (side[k] as Array).has(id)
		if not named and Ratings.available(p):
			out = id
			break
	var mine := {}
	for r in GameState.season.lists["GEE"]:
		mine[str(r["id"])] = r
	var res2 := {"home": "GEE", "away": "COL", "players": {fifth: {"disposals": 8}}}
	var rep := GameState._grant_xp("GEE", GameState.season.lists["GEE"], res2)
	var row5 := {}
	var row_out := {}
	for r in rep["rows"]:
		if str(r["id"]) == fifth:
			row5 = r
		elif str(r["id"]) == out:
			row_out = r
	_check(bool(row5.get("on_bench", false)) and not bool(row5.get("reserves", true))
			and int(row5.get("xp", 0)) == GameState._xp_amount({"disposals": 8}, false, true),
			"The fifth interchange is credited as selected and paid for his own game (%s)" % str(row5))

	# An older save named four on the bench: the fifth is filled on match day.
	var four := GameState.current_side()
	(four["BENCH"] as Array).resize(4)
	GameState.set_selection(four)
	var sq2 := GameState.my_squad()
	var kept := true
	for id in four["BENCH"]:
		kept = kept and _ids(sq2.bench).has(str(id))
	_check(sq2.bench.size() == 5 and kept, "A side saved with four on the bench keeps them and gets a fifth")

## Dual ruck (director, 2026-10-06): when you run it, your second ruck takes
## the fifth interchange spot; it is off until you choose it, kept across a
## reload; AI clubs run it by their own rule (a spare ruck close to the player
## he would replace).
func _test_dual_ruck() -> void:
	_new_season()
	_check(not GameState.dual_ruck(), "Dual ruck is off until you choose it")
	var rucks_on_bench := func() -> int:
		var n := 0
		for p in GameState.my_squad().bench:
			if str(p.get("role", "")) == "RUCK":
				n += 1
		return n
	var spare := 0
	for p in GameState.my_list:
		if str(p.get("role", "")) == "RUCK" and Ratings.available(p):
			spare += 1
	GameState.set_dual_ruck(true)
	var sq := GameState.my_squad()
	_check(spare < 2 or (str((sq.bench[0] as Dictionary).get("role", "")) == "RUCK" and sq.bench.size() == 5),
			"With dual ruck, your second ruck takes a bench spot and the bench is still five")
	_check(GameState.my_selection().is_empty(), "Dual ruck on its own is still the auto-pick")
	GameState.save_career()
	GameState.load_career()
	_check(GameState.dual_ruck() and (spare < 2 or int(rucks_on_bench.call()) >= 1), "Dual ruck survives a reload")
	GameState.set_dual_ruck(false)
	_check(not GameState.dual_ruck(), "Dual ruck can be switched off")

	# The AI's rule: a spare ruck within the margin of the last bench player.
	var list: Array = GameDB.club_list("GEE").duplicate(true)
	var r := []
	for p in list:
		if str(p.get("role", "")) == "RUCK":
			r.append(p)
	if r.size() >= 2:
		var auto_sel := Ratings.select_22(list)
		var forced := Ratings.select_22(list, 1)
		var off := Ratings.select_22(list, 0)
		var has_ruck := func(b: Array) -> bool:
			for p in b:
				if str(p.get("role", "")) == "RUCK":
					return true
			return false
		_check(has_ruck.call(forced["bench"]) and (forced["bench"] as Array).size() == 5, "A dual-ruck call always benches the second ruck")
		var last_ovr := 99.0
		for p in off["bench"]:
			last_ovr = minf(last_ovr, float(p["overall"]))
		var spare_ovr := 0.0
		for p in Ratings.by_ruck(r):
			if not _ids(off["ground"]).has(str(p["id"])):
				spare_ovr = float(p["overall"])
				break
		_check(has_ruck.call(auto_sel["bench"]) == (spare_ovr >= last_ovr - Ratings.DUAL_RUCK_MARGIN) or has_ruck.call(off["bench"]),
				"An AI club runs dual ruck when its spare ruck is close enough (spare %.0f, last on the bench %.0f)" % [spare_ovr, last_ovr])
