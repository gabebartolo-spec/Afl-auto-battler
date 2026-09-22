extends SceneTree
## godot --headless --path . --script tests/run_intake_tests.gd
## Run a headless editor import first on a fresh clone to register global classes.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var suite = load("res://tests/test_intake.gd").new()
	suite.run()
	quit(0 if suite.failures.is_empty() else 1)
