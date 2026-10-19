extends SceneTree
## godot --headless --path . --script tests/run_calls_tests.gd
## The match calls (director, 2026-10-14): the main ruck is always named (the
## assistant's pick unless the coach changes it), Play through reads forward,
## midfield, back, the coach's tagger stays on the ground while his tag is on,
## and anyone who can play midfield can be tagged. Split from the matchday suite
## to keep it under its time limit.

const Tap := preload("res://tests/tap.gd")
const SUITE_SEED := 2027

var _state: Node
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
	_state.show_real_names = false
	_state.replay_seed = SUITE_SEED
	await _t("_test_main_ruck_default_and_sticks")
	await _t("_test_play_through_order")
	await _t("_test_tag_is_permanent")
	_state.autosave_enabled = true
	print(Ran.line("Match calls", self))
	for f in _failures:
		print("ERROR: " + f)
	quit(0 if _failures.is_empty() else 1)


func _settle() -> void:
	for i in range(6):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


## Old calls with main_ruck "" load and get the assistant's pick, which Start
## takes to the engine; a coach's change sticks into the next quarter.

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)
func _test_main_ruck_default_and_sticks() -> void:
	var db = root.get_node("GameDB")
	var Ms = load("res://scripts/sim/MatchSim.gd")
	root.size = Vector2i(420, 860)
	for c in ["BRL", "HAW", "GWS", "WCE", "STK", "COL", "GEE", "CAR", "SYD", "MEL"]:
		_state.reset()
		_state.start_season(c, db.club_list(c))
		if not _state.prepare_interactive_match():
			continue
		var sim = _state.pending_sim
		var me := int(sim.moment_side)
		var n := 0
		for p in sim.squads[me].ground:
			if Ms._is_ruckman(p):
				n += 1
		if n < 2:
			continue
		var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
		root.add_child(m)
		await _settle()
		m.set("_last_tactics", {"main_ruck": ""})
		var box: Node = m.find_child("CoachBox", true, false)
		var rucks: Array = m.call("_my_rucks", sim)
		var gw: String = await Tap.tap(box.find_child("StartQuarter", true, false))
		await _settle()
		_check(gw == "" and str((sim.tactics[me] as Dictionary).get("main_ruck", "")) == str(rucks[0]["id"]),
				"Old calls with no main ruck get the assistant's pick at the bounce (%s)" % c)
		m.queue_free()
		await _settle()
		return
	_check(false, "(setup) a club with two rucks for the default check")


## "Play through (forward, midfield, back)": the value lists the same order,
## with "no one" holding an empty slot's place, for every combination.
func _test_play_through_order() -> void:
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("MEL", db.club_list("MEL"))
	var players: Array = db.club_list("MEL")
	var ids := [str(players[0]["id"]), str(players[1]["id"]), str(players[2]["id"])]
	var surnames := []
	for i in 3:
		surnames.append(" ".join(str(db.player_display_name_by_id(ids[i], "")).split(" ").slice(1)))
	var m = load("res://scripts/ui/MatchScene.gd").new()
	var slots: Array = (load("res://scripts/ui/match/MatchNotes.gd").FOCUS_ORDER as Array)
	_check(slots == ["focus_fwd", "focus_mid", "focus_def"], "Play through lists forward, midfield, back")
	var bad := []
	for mask in range(8):
		var calls := {}
		for i in 3:
			calls[slots[i]] = ids[i] if (mask >> i) & 1 == 1 else ""
		var got: String = m.call("_call_answer", "pt", calls, {"sim": null})
		if mask == 0:
			if got != "No one":
				bad.append(got)
			continue
		var parts := got.split(", ")
		if parts.size() != 3:
			bad.append(got)
			continue
		for i in 3:
			var want_empty := (mask >> i) & 1 == 0
			if want_empty != (parts[i] == "no one") or (not want_empty and not parts[i].ends_with(surnames[i])):
				bad.append(got)
	_check(bad.is_empty(), "The Play through row reads in its label's order for all 8 combinations, empties held as \"no one\" (%s)" % str(bad))
	m.free()


## True when any button or label under a node says the text.
func _any_text(node: Node, text: String) -> bool:
	for n in node.find_children("*", "Control", true, false):
		if (n is Button or n is Label) and str(n.text).contains(text):
			return true
	return false


## The tag is the coach's call all match (director, 2026-10-14): a named
## tagger is not rotated off while his tag is on, and a mid/forward can be tagged.
func _test_tag_is_permanent() -> void:
	var db = root.get_node("GameDB")
	var Ms = load("res://scripts/sim/MatchSim.gd")
	_state.reset()
	_state.start_season("MEL", db.club_list("MEL"))
	_check(_state.prepare_interactive_match(), "A match is prepared for the tagger check")
	var sim = _state.pending_sim
	var me := int(sim.moment_side)
	var mids: Array = (sim.squads[me].ground as Array).filter(func(p): return Ms.midfielder_on_ground(p))
	var theirs := ""
	for p in sim.squads[1 - me].ground:
		if sim.tag_target_ok(1 - me, str(p["id"])):
			theirs = str(p["id"])
			break
	_check(mids.size() >= 2 and theirs != "", "(setup) midfielders to tag with and a target")
	if mids.size() < 2 or theirs == "":
		return
	var tagger_id := str(mids[0]["id"])
	var t: Dictionary = (sim.tactics[me] as Dictionary).duplicate()
	t["tag_id"] = theirs
	t["tagger_id"] = tagger_id
	sim.set_tactics(me, t)
	sim.energy[tagger_id] = 5.0
	for i in 40:
		sim._auto_rotate(me)
	var still := false
	for p in sim.squads[me].ground:
		if str(p["id"]) == tagger_id:
			still = true
	_check(still, "The named tagger stays on the ground with the tag on, however tired")
	var t2: Dictionary = (sim.tactics[me] as Dictionary).duplicate()
	t2["tag_id"] = ""
	sim.set_tactics(me, t2)
	for i in 3:
		sim._auto_rotate(me)
	var off := true
	for p in sim.squads[me].ground:
		if str(p["id"]) == tagger_id:
			off = false
	_check(off, "With no tag, the tired man is rotated off as before")
	# A mid/forward is a valid tag target; a pure forward or ruck is not.
	var mf := {}
	var plain := {}
	# Loaded, not named: the autoloads are not there when this script compiles.
	var Rt = load("res://scripts/sim/Ratings.gd")
	for p in sim.squads[1 - me].ground:
		var pos: Array = Rt.positions(p)
		if pos.has("MID") and str(p["role"]) != "MID":
			mf = p
		elif not pos.has("MID"):
			plain = p
	if not mf.is_empty():
		_check(sim.tag_target_ok(1 - me, str(mf["id"])), "A player who can play midfield is a tag target in a forward slot")
	if not plain.is_empty():
		_check(not sim.tag_target_ok(1 - me, str(plain["id"])), "A player with no midfield position is not a tag target")
	var fake := {"role": "FWD", "own_role": "FWD", "role2": "MID", "id": "x", "attr": {}}
	_check(Ms.can_be_tagged(fake) and not Ms.can_be_tagged({"role": "MID", "own_role": "RUCK", "role2": ""}),
			"Mid/forward can be tagged; a ruck in a midfield slot cannot")


