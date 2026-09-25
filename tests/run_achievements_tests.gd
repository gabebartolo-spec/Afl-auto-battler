extends SceneTree
## godot --headless --path . --script tests/run_achievements_tests.gd
## Runs the achievements suite headless (one club-specific achievement per
## club, all detectable from stats the game already tracks).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_isolate_saves()
	var script = load("res://tests/test_achievements.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_achievements.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	quit(0 if suite.failures.is_empty() else 1)


## Never touch a real career save or settings file from a test run.
func _isolate_saves() -> void:
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_achievements_career.save"
	gs.settings_path = "user://test_achievements_settings.cfg"
	gs.show_real_names = false
	gs.delete_saved_career()
