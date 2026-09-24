extends SceneTree
## godot --headless --path . --script tests/run_awards_tests.gd
## Run a headless editor import first on a fresh clone to register global classes.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_isolate_saves()
	# A suite that fails to compile must fail the run, not hang it.
	var script = load("res://tests/test_awards.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_awards.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	quit(0 if suite.failures.is_empty() else 1)


## Never touch a real career save or settings file from a test run.
func _isolate_saves() -> void:
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_career.save"
	gs.settings_path = "user://test_settings.cfg"
	gs.show_real_names = false
