extends SceneTree
## A fixture for tools/test_run_tests.sh, not a suite: `_test_empty` runs and
## makes no check, so the suite must fail by that name.

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _run() -> void:
	await process_frame
	_t("_test_called")
	_t("_test_empty")
	print(Ran.line("No-check fixture", self))
	quit(0 if _failures.is_empty() else 1)


func _test_called() -> void:
	_check(true, "This one runs")


func _test_empty() -> void:
	for n in []:   # an empty loop: its check never runs
		_check(n != null, "Never reached")
