extends SceneTree
## godot --headless --path . --script tests/run_trainrep_tests.gd
## The monthly training report (tests/test_trainrep.gd). Run a headless editor
## import first on a fresh clone to register global classes.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var script = load("res://tests/test_trainrep.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_trainrep.gd")
		quit(1)
		return
	var suite = script.new()
	await suite.run(self)
	quit(0 if suite.failures.is_empty() else 1)
