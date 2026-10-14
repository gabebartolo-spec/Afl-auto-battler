extends SceneTree
## godot --headless --fixed-fps 60 --path . --script tools/audit/disc_tests_only.gd
## Only the disc and name-label checks of tests/test_match_visual.gd (the full suite is a CI shard).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_career.save"
	gs.settings_path = "user://test_settings.cfg"
	var suite = load("res://tests/test_match_visual.gd").new()
	suite._test_clash_kit()
	suite._test_label_overlap()
	suite._test_sides()
	print("checks %d, failures %d" % [suite.checks, suite.failures.size()])
	for f in suite.failures:
		print("FAIL ", f)
	quit(0 if suite.failures.is_empty() else 1)
