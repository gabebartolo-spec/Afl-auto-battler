extends RefCounted
## The coaching world (Coaches.gd): six jobs at every club, one record per
## coach, the Round 1 2026 seed, fictional names, save safety, grades and
## role fit, and the Staff screen. Skills have no gameplay effect yet.
## Run through tests/run_coaches_tests.gd.

var failures: Array[String] = []
var checks := 0

const GAPS := {"BRL": "SA", "GEE": "DEF", "GCS": "SA", "MEL": "SA", "WCE": "SA"}


func run() -> void:
	failures.clear()
	checks = 0
	_test_seed_structure()
	_test_seed_integrity()
	_test_names()
	_test_grades_and_fit()
	_test_save_round_trip()
	_test_old_save()
	_test_expansion_structure()
	_test_no_effects_yet()
	await _test_ui()
	GameState.delete_saved_career()
	print("Coaches tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _new_career(club: String) -> void:
	GameState.reset()
	GameState.start_season(club, GameDB.club_list(club))


func _test_seed_structure() -> void:
	_new_career("CAR")
	var cs: Dictionary = GameState.coaches
	var six := true
	var bad := ""
	for code in GameDB.active_clubs(2026):
		var staff := Coaches.staff(cs, code)
		var want := 5 if code == "CAR" else 6
		if staff.size() != want:
			six = false
			bad = "%s has %d" % [code, staff.size()]
		for job in Coaches.JOBS:
			if job == "SC" and code == "CAR":
				continue
			if not staff.has(job):
				six = false
				bad = "%s has no %s" % [code, job]
	_check(six, "Every AI club has six coaches, yours five plus you (%s)" % bad)
	_check(not Coaches.staff(cs, "CAR").has("SC"), "No NPC holds your senior coach job")
	var voss: Dictionary = cs.get("C_michael_voss", {})
	_check(str(voss.get("status", "")) == "free" and str(voss.get("club", "x")) == ""
			and bool(voss.get("former_sc", false)),
			"Your club's real senior coach becomes a free coach (%s)" % str(voss))
	_check(str((voss.get("stints", []) as Array)) == str([["CAR", "SC", 2026, 2026]]),
			"His record keeps the job he held at Round 1")
	var seen := {}
	var dup := ""
	for cid in cs:
		var c: Dictionary = cs[cid]
		_check(str(c["cid"]) == str(cid), "A record's cid is its key")
		if str(c["status"]) == "club":
			var key := "%s|%s" % [c["club"], c["job"]]
			if seen.has(key):
				dup = key
			seen[key] = true
	_check(dup == "", "No two coaches hold one job, no coach holds two (%s)" % dup)
	var again := Coaches.seed("CAR")
	_check(str(again) == str(cs), "Seeding is deterministic")
	var other := Coaches.seed("GEE")
	_check(str((other["C_michael_voss"] as Dictionary)["status"]) == "club"
			and str((other["C_chris_scott"] as Dictionary)["status"]) == "free",
			"Only the chosen club's senior coach steps aside")


func _test_seed_integrity() -> void:
	var cs := Coaches.seed("CAR")
	var gens := {}
	var skills_ok := true
	var status_ok := true
	var spec_ok := true
	var counts := {"club": 0, "free": 0, "away": 0, "out": 0}
	for cid in cs:
		var c: Dictionary = cs[cid]
		counts[str(c["status"])] = int(counts.get(str(c["status"]), 0)) + 1
		for k in Coaches.SKILLS:
			var v := Coaches.skill(c, k)
			if v < 55 or v > 92:
				skills_ok = false
		if not ["club", "free", "away", "out"].has(str(c["status"])):
			status_ok = false
		if not Coaches.SPEC_LABEL.has(str(c["spec"])):
			spec_ok = false
		if str(c["origin"]) == "generated":
			gens[str(c["club"])] = str(c["job"])
			_check(str(c["real_name"]) == "" and str(cid).begins_with("C_G2026_"),
					"A generated coach has no real name and a generated id")
		else:
			_check(str(cid).begins_with("C_") and str(c["real_name"]) != "",
					"A seeded coach has a C_ id and his real name")
		if str(c["status"]) == "out":
			_check(int(c["free_from"]) > 2026, "An unavailable coach says when he is back")
	_check(str(gens) == str(GAPS), "Exactly the verified gaps are generated (%s)" % str(gens))
	_check(skills_ok, "Every skill sits in 55-92")
	_check(status_ok and spec_ok, "Statuses and specialties use the fixed sets")
	_check(int(counts["club"]) == 107 and int(counts["free"]) + int(counts["away"]) + int(counts["out"]) == 36,
			"107 NPC jobs filled plus 36 outside a job (%s)" % str(counts))
	# The skills are spread like the brief: most Good, some Strong, few Elite.
	var elite := 0
	var mid := 0
	var n := 0
	for cid in cs:
		for k in Coaches.SKILLS:
			var v := Coaches.skill(cs[cid], k)
			n += 1
			if v >= 86:
				elite += 1
			if v >= 65 and v <= 82:
				mid += 1
	_check(float(elite) / n < 0.06 and float(mid) / n > 0.6,
			"Elite is rare and most skills sit 65-82 (%d elite, %d of %d mid)" % [elite, mid, n])


func _test_names() -> void:
	var cs := Coaches.seed("CAR")
	var player_firsts := {}
	for f in GameDB.FICTIONAL_FIRST_NAMES:
		player_firsts[str(f)] = true
	var disjoint := true
	for f in Coaches.COACH_FIRST_NAMES:
		if player_firsts.has(str(f)):
			disjoint = false
	_check(disjoint, "No coach first name is one a player can have")
	var names := {}
	var unique := true
	for cid in cs:
		var g := str((cs[cid] as Dictionary)["generic_name"])
		if names.has(g) or g == "":
			unique = false
		names[g] = true
	_check(unique, "Every coach has his own fictional name")
	var clash := ""
	for p in GameDB.players + GameDB.draftees:
		if names.has(str(p.get("generic_name", ""))):
			clash = str(p["generic_name"])
	_check(clash == "", "No coach shares a player's name (%s)" % clash)
	_check(str((Coaches.seed("GEE")["C_josh_fraser"] as Dictionary)["generic_name"])
			== str((cs["C_josh_fraser"] as Dictionary)["generic_name"]),
			"A seeded coach's alias is the same in every career")
	var was := GameState.show_real_names
	GameState.show_real_names = false
	var fraser: Dictionary = cs["C_josh_fraser"]
	_check(GameDB.player_display_name(fraser) == str(fraser["generic_name"]), "Generated names by default")
	GameState.show_real_names = true
	_check(GameDB.player_display_name(fraser) == "Josh Fraser", "Real names show the real coach")
	var gen: Dictionary = cs["C_G2026_1"]
	_check(GameDB.player_display_name(gen) == str(gen["generic_name"]),
			"A generated coach keeps his generated name in real-name mode")
	GameState.show_real_names = was


func _test_grades_and_fit() -> void:
	_check(Coaches.grade(86) == "Elite" and Coaches.grade(85) == "Strong" and Coaches.grade(78) == "Strong"
			and Coaches.grade(77) == "Good" and Coaches.grade(68) == "Good" and Coaches.grade(67) == "Fair",
			"Grades: Elite 86+, Strong 78+, Good 68+, Fair below")
	var c := {"skills": {"teach": 80, "tactics": 70, "manage": 60}, "spec": "FWD"}
	_check(is_equal_approx(Coaches.role_fit(c, "SC"), 0.45 * 70 + 0.35 * 60 + 0.20 * 80),
			"Senior coach fit: 45% tactics, 35% man-management, 20% teaching")
	_check(is_equal_approx(Coaches.role_fit(c, "FWD"), 0.6 * 80 + 0.25 * 70 + 0.15 * 60),
			"A forwards specialist fits the forwards job with no penalty")
	_check(is_equal_approx(Coaches.role_fit(c, "DEF"), Coaches.role_fit(c, "FWD") - 8.0),
			"Coaching outside his line costs 8")
	var ruck := {"skills": c["skills"], "spec": "RUCK"}
	_check(is_equal_approx(Coaches.role_fit(ruck, "MID"), Coaches.role_fit(c, "FWD")),
			"A ruck specialist fits Midfield & ruck")
	_check(is_equal_approx(Coaches.role_fit(c, "DEV"), 0.7 * 80 + 0.3 * 60 - 3.0)
			and is_equal_approx(Coaches.role_fit({"skills": c["skills"], "spec": ""}, "DEV"), 0.7 * 80 + 0.3 * 60 - 6.0),
			"Development: a smaller penalty for a line specialist, more for a whole-game coach")
	_check(Coaches.headline({"job": "SA", "skills": {"manage": 80}}) == "Strong man-manager"
			and Coaches.headline({"job": "FWD", "skills": {"teach": 70}}) == "Good teacher",
			"A staff row names the skill the job leans on, as a grade")


func _test_save_round_trip() -> void:
	_new_career("SYD")
	var before := str(GameState.coaches)
	_check(GameState.save_career(), "A career with coaches saves")
	# No coach may land in the shared player table.
	var f := FileAccess.open(GameState.save_path, FileAccess.READ)
	var blob: Dictionary = f.get_var()
	f.close()
	var leaked := false
	for sid in blob["players"]:
		if (blob["players"][sid] as Dictionary).has("cid"):
			leaked = true
	_check(not leaked, "No coach is written as a player")
	_check(GameState.load_career(), "It loads")
	_check(str(GameState.coaches) == before, "Every coach comes back exactly")
	var still_coaches := true
	for cid in GameState.coaches:
		var c: Dictionary = GameState.coaches[cid]
		if c.has("attr") or c.has("id") or c.has("role") or not c.has("skills"):
			still_coaches = false
	_check(still_coaches, "They are still coach records (cid, skills, job), never player-shaped")
	var staff := GameState.club_staff("SYD")
	var sa: Dictionary = staff.get("SA", {})
	_check(is_same(sa, GameState.coaches[str(sa.get("cid", ""))]),
			"A club's staff is the canonical records, not copies")
	sa["note"] = "probe"
	_check(str((GameState.coach(str(sa["cid"])) as Dictionary)["note"]) == "probe",
			"Changing a coach through his club changes the one record")
	sa["note"] = ""


func _test_old_save() -> void:
	_new_career("ADE")
	GameState.save_career()
	var state := CareerSave.read(GameState.save_path)
	state.erase("coaches")
	CareerSave.write(state, CareerSave.read_meta(GameState.save_path), GameState.save_path)
	_check(GameState.load_career(), "A save from before coaches loads")
	_check(Coaches.staff(GameState.coaches, "ADE").size() == 5
			and str((GameState.coach("C_matthew_nicks") as Dictionary).get("status", "")) == "free",
			"It gets the Round 1 coaching world for its club")


func _test_expansion_structure() -> void:
	var cs := Coaches.seed("CAR")
	_check(Coaches.staff(cs, "TAS").is_empty(), "An expansion club starts with no staff")
	var c: Dictionary = cs["C_ken_hinkley"]
	c["status"] = "club"
	c["club"] = "TAS"
	c["job"] = "SC"
	_check(str(Coaches.staff(cs, "TAS").get("SC", "")) == "C_ken_hinkley",
			"Any club, including a future one, can hold staff the same way")


## Nothing in the game reads a coach's skills yet.
func _test_no_effects_yet() -> void:
	var clean := true
	for path in ["res://scripts/sim/Prospects.gd", "res://scripts/sim/MatchSim.gd",
			"res://scripts/sim/ClubLife.gd", "res://scripts/sim/Potential.gd",
			"res://scripts/sim/Season.gd"]:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("Coaches.") or text.contains("GameState.coaches") or text.contains("club_staff("):
			clean = false
	_check(clean, "Development, matches and morale do not read coaches yet")


func _test_ui() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_new_career("CAR")
	var scene: Control = load("res://scenes/StaffScene.tscn").instantiate()
	tree.root.add_child(scene)
	for i in range(3):
		await tree.process_frame
	_check(scene.find_child("StaffRow_SC", true, false) != null
			and _text(scene).contains("You") and _text(scene).contains("your calls"),
			"Your row says you are the senior coach, with no grades")
	var row: Button = scene.find_child("StaffRow_FWD", true, false)
	_check(row != null and not _text(row).contains("7"), "A coach row carries words, not numbers")
	var digits := false
	for l in scene.find_children("*", "Label", true, false):
		var t := str((l as Label).text)
		for d in "0123456789":
			if t.contains(d):
				digits = true
	_check(not digits, "No numbers anywhere on the Staff screen")
	if row != null:
		row.emit_signal("pressed")
		for i in range(2):
			await tree.process_frame
	var sheet := scene.find_child("CoachProfile", true, false)
	_check(sheet != null and sheet.find_child("CoachSkills", true, false) != null
			and sheet.find_child("CoachCareer", true, false) != null,
			"Tapping a coach opens his profile: grades and coaching career")
	scene.call("handle_back")
	await tree.process_frame
	await tree.process_frame
	_check(scene.find_child("CoachProfile", true, false) == null, "Back closes the profile")
	scene.find_child("OtherClubs", true, false).emit_signal("pressed")
	await tree.process_frame
	var pick: Button = scene.find_child("StaffClubPick_GEE", true, false)
	_check(pick != null, "Another club's staff is one tap away")
	if pick != null:
		pick.emit_signal("pressed")
		await tree.process_frame
	_check(_text(scene).contains("Geelong") and scene.find_child("StaffRow_SC", true, false) is Button,
			"An AI club shows its own senior coach")
	_check(bool(scene.call("handle_back")) and _text(scene).contains("Carlton"),
			"Back returns to your own staff first")
	scene.queue_free()
	# The player profile shows a career line.
	var host := Control.new()
	tree.root.add_child(host)
	var dawson: Dictionary = {}
	for p in GameState.season.lists["ADE"]:
		if str(p.get("real_name", "")) == "Jordan Dawson":
			dawson = p
	if not dawson.is_empty():
		var o := PlayerSheet.open(host, dawson)
		await tree.process_frame
		var cl: Label = o.find_child("ProfileCareer", true, false)
		_check(cl != null and cl.text == "156 games · 78 goals",
				"The player profile shows his career (%s)" % (cl.text if cl != null else "none"))
		_check(_text(o).contains("Sydney 2017–2021") and _text(o).contains("Adelaide 2022–2025"),
				"and the clubs, when there is more than one")
	host.queue_free()


func _text(n: Node) -> String:
	var bits := []
	for l in n.find_children("*", "Label", true, false):
		bits.append(str((l as Label).text))
	if n is Label:
		bits.append(str(n.text))
	return " | ".join(bits)
