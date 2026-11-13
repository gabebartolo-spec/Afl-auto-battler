extends SceneTree
## godot --headless --path . --script tests/run_legacy_rollover_tests.gd
## Run a headless editor import first on a fresh clone to register global classes.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_isolate_saves()
	# A suite that fails to compile must fail the run, not hang it.
	var script = load("res://tests/test_legacy_rollover.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_legacy_rollover.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	var tap_fail := await _tap_brand_card()
	if tap_fail != "":
		push_error(tap_fail)
	else:
		print("Legacy rollover: a real tap on the Bears-or-Lions card makes the Lions")
	quit(0 if suite.failures.is_empty() and tap_fail == "" else 1)


const Tap := preload("res://tests/tap.gd")


## The Bears-or-Lions card on the hub, answered with a real tap (CLAUDE.md:
## a touch flow is proven with a tap at the control's place on screen).
func _tap_brand_card() -> String:
	var LegacyRollover = load("res://scripts/state/LegacyRollover.gd")
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	gs.reset("1990")
	gs.start_season("BRL", db.club_list("BRL"))
	gs.legacy = {"fitzroy": "stays"}
	LegacyRollover.keep_fitzroy()
	gs.set_setting("seen_weekly_loop_intro", true)
	gs.media_conference = {}
	db.apply_era(1997)
	gs.week_events = []
	LegacyRollover.week(gs)
	router.go("hub")
	# The hub loads on the Router's thread: wait for the card's sheet.
	var sheet: Node = null
	for i in range(900):
		await process_frame
		if current_scene != null:
			sheet = current_scene.find_child("EventSheet", true, false)
		if sheet != null:
			break
	for i in range(10):
		await process_frame
	if sheet == null:
		return "The Bears-or-Lions card does not open on the hub (scene %s, %d cards)" % [str(current_scene), gs.week_events.size()]
	var lions: Button = sheet.find_child("Event_0", true, false)
	var why: String = (await Tap.tap(lions)) if lions != null else "missing"
	for i in range(4):
		await process_frame
	db.apply_era(1997)
	var ok: bool = why == "" and bool(gs.week_events[0].get("resolved", false)) 			and str(gs.legacy.get("brand", "")) == "lions" and db.club_short("BRL") == "Lions"
	var out := "" if ok else "A real tap on Become the Lions did not make the Lions (tap: %s, brand %s, %s)" % [
			why, str(gs.legacy.get("brand", "")), db.club_short("BRL")]
	db.reload()
	return out


## Never touch a real career save or settings file from a test run.
func _isolate_saves() -> void:
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_career.save"
	gs.settings_path = "user://test_settings.cfg"
