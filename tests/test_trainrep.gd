extends RefCounted
## Run by tests/run_trainrep_tests.gd (suite "trainrep").
## The monthly training report (TrainingReport.gd, TrainingReportSheet.gd;
## director, 2026-10-14: "A report every 4 rounds"): the block snapshot, a
## known riser and his stats, the retraining list against the Training menu's
## own, the switch off, an old save, and real taps on a phone and a PC.

var _tree: SceneTree
var checks := 0
var failures: Array[String] = []

const Tap := preload("res://tests/tap.gd")
const SUITE_SEED := 2027
const SIZES := [Vector2i(390, 844), Vector2i(1280, 720)]


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _settle(n := 6) -> void:
	for i in range(n):
		await _tree.process_frame


func _fresh() -> void:
	GameState.reset()
	GameState.start_season("FRE", GameDB.club_list("FRE"))
	GameState.replay_seed = SUITE_SEED
	GameState.tutorials = false
	Router.stack = []


func _rounds(n: int) -> void:
	for i in range(n):
		GameState.advance()


func _boost_potential(n: int) -> void:
	var made := 0
	for p in GameState.my_list:
		if made < n and int(p.get("potential", 0)) < 95:
			p["potential"] = 95
			made += 1


func run(tree: SceneTree) -> void:
	_tree = tree
	await _tree.process_frame
	GameState.autosave_enabled = false
	GameState.save_path = "user://test_trainrep.save"
	GameState.settings_path = "user://test_trainrep.cfg"
	GameState.delete_saved_career()
	await _t("_test_switch_off")
	Features.set_on("training_report", true)
	_t("_test_snapshot_and_report")
	_t("_test_retrain_list")
	_t("_test_old_save")
	for size in SIZES:
		_tree.root.size = size
		await _settle()
		await _t("_test_taps", [size])
	Features.clear("training_report")
	GameState.delete_saved_career()
	print(Ran.line("Training report", self))
	for f in failures:
		print("  FAIL: " + f)


func _test_switch_off() -> void:
	_check(not Features.on("training_report"), "the switch ships off")
	_fresh()
	_rounds(4)
	_check(GameState.training_block.is_empty() and GameState.training_report.is_empty(), "off: no block or report is kept")
	_check(TrainingReport.current(GameState).is_empty() and not TrainingReport.hub_due(GameState), "off: nothing is due")
	_tree.root.size = Vector2i(390, 844)
	await _settle()
	Router.stack = []
	Router.go("hub")
	await _settle(8)
	_check(_tree.current_scene.find_child("TrainingReportCard", true, false) == null, "off: the hub has no report card")
	Router.go("training")
	await _settle(8)
	_check(_tree.current_scene.find_child("TrainingReportLink", true, false) == null, "off: Training has no report link")
	_check(GameState.save_career(), "off: saves")
	var raw := FileAccess.get_file_as_bytes("user://test_trainrep.save")
	_check(raw.size() > 0, "off: the save is written")
	GameState.delete_saved_career()


func _test_snapshot_and_report() -> void:
	_fresh()
	var before := {}
	for p in GameState.my_list:
		before[str(p["id"])] = {"ovr": int(p["overall"]), "attr": (p["attr"] as Dictionary).duplicate()}
	_rounds(1)
	_check(not GameState.training_block.is_empty(), "the block begins with the first game")
	_check(int(GameState.training_block.get("from", 0)) == 1, "the block starts at round 1")
	var snap: Dictionary = GameState.training_block["players"]
	var same := true
	for id in before:
		if not snap.has(id) or int(snap[id]["ovr"]) != int(before[id]["ovr"]):
			same = false
	_check(same, "the block holds every player's rating from before the first game")
	_check(GameState.training_report.is_empty(), "no report before round 4")
	_rounds(3)
	var r: Dictionary = GameState.training_report
	_check(not r.is_empty(), "a report exists after round 4")
	_check(str(r.get("label", "")) == "Rounds 1-4", "it is Rounds 1-4, not %s" % str(r.get("label")))
	_check(GameState.training_block.is_empty(), "the block closes with the report")
	_check(TrainingReport.hub_due(GameState), "the hub card is due")
	# The biggest riser by points, worked out here from the raw before and after.
	var best_id := ""
	var best_pts := 0
	for p in GameState.my_list:
		var id := str(p["id"])
		if not before.has(id):
			continue
		var pts := 0
		for row in GameState.TRAIN_STATS:
			var k := str(row[0])
			pts += maxi(0, int(round(float(p["attr"][k]))) - int(round(float(before[id]["attr"][k]))))
		if pts > best_pts:
			best_pts = pts
			best_id = id
	_check(best_id != "", "somebody improved in four rounds")
	var found := {}
	for e in r["risers"]:
		if str(e["id"]) == best_id:
			found = e
	_check(not found.is_empty() or (r["risers"] as Array).size() == TrainingReport.MAX_RISERS, "the biggest riser is in the report")
	if not found.is_empty():
		var ok := true
		for s in found["stats"]:
			var key := ""
			for row in GameState.TRAIN_STATS:
				if str(row[1]) == str(s[0]):
					key = str(row[0])
			var p: Dictionary = GameState.list_player(best_id)
			ok = ok and int(s[1]) == int(round(float(before[best_id]["attr"][key]))) and int(s[2]) == int(round(float(p["attr"][key])))
		_check(ok, "his stats read before to after exactly")
		_check(int(found["ovr0"]) == int(before[best_id]["ovr"]), "his rating before is the block's start")
	_check((r["risers"] as Array).size() <= TrainingReport.MAX_RISERS, "at most eight risers")
	var sorted_ok := true
	for i in range((r["risers"] as Array).size() - 1):
		var a: Dictionary = r["risers"][i]
		var b: Dictionary = r["risers"][i + 1]
		if int(a["ovr1"]) - int(a["ovr0"]) < int(b["ovr1"]) - int(b["ovr0"]):
			sorted_ok = false
	_check(sorted_ok, "most improved first")
	_rounds(1)
	_check(int(GameState.training_block.get("from", 0)) == 5, "the next block starts at round 5")
	_rounds(3)
	_check(str(GameState.training_report.get("label", "")) == "Rounds 5-8", "round 8 brings the next report")
	_check(not bool(GameState.training_report.get("dismissed", true)), "the new report is not dismissed")


func _test_retrain_list() -> void:
	_fresh()
	_boost_potential(3)
	_rounds(4)
	var r: Dictionary = GameState.training_report
	var rt := TrainingReport.retrain_list(GameState, r)
	var menu_ids := []
	for p in GameState.my_list:
		for k in GameState.plans_for(p):
			if str(k).begins_with(GameState.LEARN_PREFIX):
				menu_ids.append(str(p["id"]))
				break
	var ids := []
	for e in rt["entries"]:
		ids.append(str(e["id"]))
	_check(not ids.is_empty(), "somebody can learn a position")
	_check(GameState.active_projects() < GameState.PROJECT_MAX, "the club has a free project")
	var a := ids.duplicate()
	var b := menu_ids.duplicate()
	a.sort()
	b.sort()
	_check(a == b, "the report's list is the Training menu's own: %s vs %s" % [str(a), str(b)])
	_check(not bool(rt["full"]), "a free project: no limit note")
	for e in rt["entries"]:
		var p: Dictionary = GameState.list_player(str(e["id"]))
		var words := []
		for k in GameState.plans_for(p):
			if str(k).begins_with(GameState.LEARN_PREFIX):
				words.append(str(GameState.LEARN_JOBS[str(k).trim_prefix(GameState.LEARN_PREFIX)]["word"]))
		words.sort()
		var mine: Array = (e["jobs"] as Array).duplicate()
		mine.sort()
		_check(words == mine, "his jobs are the menu's: %s vs %s" % [str(mine), str(words)])
	# At the club's limit the menu offers nothing; the report still lists who could, and says why.
	var started := 0
	for p in GameState.my_list:
		if started < 2 and ids.has(str(p["id"])):
			GameState._start_project(p, str(GameState.open_jobs(p)[0]))
			started += 1
	_check(started == 2, "two projects started")
	var capped := TrainingReport.retrain_list(GameState, r)
	_check(bool(capped["full"]), "at the limit the report says so")
	var menu_any := false
	for p in GameState.my_list:
		for k in GameState.plans_for(p):
			if str(k).begins_with(GameState.LEARN_PREFIX) and GameState.project_job(p) == "":
				menu_any = true
	_check(not menu_any, "at the limit the menu offers no new project")
	var left := 0
	for e in capped["entries"]:
		var p: Dictionary = GameState.list_player(str(e["id"]))
		_check(GameState.project_job(p) == "", "nobody already learning is listed")
		left += 1
	_check(left == ids.size() - 2, "everyone else who could is still listed (%d of %d)" % [left, ids.size() - 2])
	var fresh_ok := true
	var seen_old := false
	for e in rt["entries"]:
		if bool(e["new"]) and seen_old:
			fresh_ok = false
		if not bool(e["new"]):
			seen_old = true
	_check(fresh_ok, "those who became available this month come first")


func _test_old_save() -> void:
	# A save from before the report has neither key: it loads with safe defaults.
	_fresh()
	_rounds(2)
	Features.set_on("training_report", false)
	_check(GameState.save_career(), "an old-style save is written")
	Features.set_on("training_report", true)
	GameState.training_block = {"junk": 1}
	GameState.training_report = {"junk": 1}
	_check(GameState.load_career(), "an old save loads")
	_check(GameState.training_block.is_empty() and GameState.training_report.is_empty(), "absent keys load as empty")
	_rounds(2)
	_check(not GameState.training_report.is_empty(), "and the report carries on from it")
	_check(GameState.save_career(), "a new save is written")
	GameState.training_block = {}
	GameState.training_report = {}
	_check(GameState.load_career(), "the new save loads")
	_check(str(GameState.training_report.get("label", "")) == "Rounds 3-4", "the report round-trips (a save from mid-block starts its first block where it was loaded)")
	GameState.delete_saved_career()


func _on_screen(c: Control, size: Vector2i) -> bool:
	var r := c.get_global_rect()
	return r.position.x >= -0.5 and r.end.x <= size.x + 0.5


func _test_taps(size: Vector2i) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	_fresh()
	_boost_potential(2)
	_rounds(4)
	GameState.skip_media_conference()
	Router.stack = ["main"]
	Router.go("hub")
	await _settle(10)
	var hub := _tree.current_scene
	var card := hub.find_child("TrainingReportCard", true, false)
	_check(card != null, "%s: the hub shows the report card" % tag)
	if card == null:
		return
	var opener: Control = hub.find_child("TrainingReportOpen", true, false)
	var why: String = await Tap.tap(opener)
	_check(why == "", "%s: a finger opens the report (%s)" % [tag, why])
	await _settle(4)
	var sheet := hub.find_child("TrainingReportSheet", true, false)
	_check(sheet != null, "%s: the report is open" % tag)
	if sheet == null:
		return
	var risers: Array = GameState.training_report["risers"]
	var rid := str(risers[0]["id"]) if not risers.is_empty() else ""
	var name_b: Control = sheet.find_child("Name_" + rid, true, false) if rid != "" else null
	_check(name_b != null, "%s: the top riser is on the sheet" % tag)
	if name_b != null:
		_check(_on_screen(name_b, size), "%s: his name is on screen" % tag)
		_check(await Tap.tap(name_b) == "", "%s: a finger taps his name" % tag)
		await _settle(4)
		_check(hub.find_child("PlayerProfile", true, false) != null, "%s: his profile opens" % tag)
		Router.handle_back()
		await _settle(3)
		_check(hub.find_child("PlayerProfile", true, false) == null, "%s: Back closes the profile" % tag)
		_check(hub.find_child("TrainingReportSheet", true, false) != null, "%s: and leaves the report" % tag)
	_check(await Tap.tap(hub.find_child("TrainingReportClose", true, false)) == "", "%s: a finger taps Close" % tag)
	await _settle(3)
	_check(hub.find_child("TrainingReportSheet", true, false) == null, "%s: Close closes it" % tag)
	_check(hub.find_child("TrainingReportCard", true, false) != null, "%s: the card stays after Close" % tag)
	await Tap.tap(hub.find_child("TrainingReportOpen", true, false))
	await _settle(4)
	Router.handle_back()
	await _settle(3)
	_check(hub.find_child("TrainingReportSheet", true, false) == null and _tree.current_scene == hub, "%s: Android Back closes the report and stays on the hub" % tag)
	await Tap.tap(hub.find_child("TrainingReportOpen", true, false))
	await _settle(4)
	sheet = hub.find_child("TrainingReportSheet", true, false)
	var rt := TrainingReport.retrain_list(GameState, GameState.training_report)
	var entries: Array = rt["entries"]
	_check(not entries.is_empty(), "%s: somebody can retrain" % tag)
	if not entries.is_empty():
		var id0 := str(entries[0]["id"])
		var row: Control = sheet.find_child("Retrain_" + id0, true, false)
		var rb: Control = row.find_child("Name_" + id0, true, false) if row != null else null
		_check(rb != null, "%s: the retraining entry is there" % tag)
		if rb != null:
			var scrolls := sheet.find_children("*", "ScrollContainer", true, false)
			if not scrolls.is_empty():
				(scrolls[0] as ScrollContainer).ensure_control_visible(rb)
			await _settle(2)
			_check(await Tap.tap(rb) == "", "%s: a finger taps the retraining entry" % tag)
			for i in range(60):
				await _tree.process_frame
			await _settle(6)
			_check(Router.current() == "training", "%s: it opens Training" % tag)
			_check(_tree.current_scene.find_child("PlayerPlan", true, false) != null, "%s: on his plan choices" % tag)
			var want := "Learn " + str(entries[0]["jobs"][0])
			var has := false
			for b in _tree.current_scene.find_children("*", "Button", true, false):
				if (b as Button).text == want:
					has = true
			_check(has, "%s: his \"%s\" choice is there" % [tag, want])
	# From Training: Back to the list, then the link reopens the report.
	var link := _tree.current_scene.find_child("TrainingReportLink", true, false)
	if link == null:
		Router.handle_back()
		await _settle(6)
		link = _tree.current_scene.find_child("TrainingReportLink", true, false)
	_check(link != null, "%s: Training keeps a link to the report" % tag)
	if link != null:
		await Tap.tap(link)
		await _settle(4)
		_check(_tree.current_scene.find_child("TrainingReportSheet", true, false) != null, "%s: the link opens the report" % tag)
		Router.handle_back()
		await _settle(3)
		_check(_tree.current_scene.find_child("TrainingReportSheet", true, false) == null, "%s: Back closes it in Training" % tag)
	Router.stack = ["main"]
	Router.go("hub")
	await _settle(8)
	var hide: Control = _tree.current_scene.find_child("TrainingReportHide", true, false)
	_check(await Tap.tap(hide) == "", "%s: a finger taps Hide" % tag)
	await _settle(3)
	_check(not TrainingReport.hub_due(GameState), "%s: dismissed" % tag)
	Router.go("training")
	await _settle(8)
	_check(_tree.current_scene.find_child("TrainingReportLink", true, false) != null, "%s: still reachable from Training" % tag)
