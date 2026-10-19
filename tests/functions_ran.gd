extends RefCounted
## Every test function ran and made at least one check (test suite audit
## 2026-10-18 section 4; this replaced the check-count floors).
##
## A suite calls each test through `_t`, a two-line method it keeps beside its
## own _check:
##
##   const Ran := preload("res://tests/functions_ran.gd")
##   func _t(test: String, args := []) -> Variant:
##       return await Ran.one(self, test, args)
##
##   _t("_test_rules")                  # in a run() with no awaits
##   await _t("_test_screen", [size])   # in one that awaits
##   var hb: Array = await _t("_test_truth", [res])   # what it returns
##
## and ends with `print(Ran.line("Draft", self))` instead of counting by
## hand. The line fails, by name, every `_test_*` method the suite defines but
## never called, and reads "Draft tests: 20 of 20 functions, 7901 checks,
## 0 failures". tools/run_tests.sh fails a suite whose line is short of
## functions or carries no function count at all.
##
## The suite keeps its checks and failures in `checks`/`failures` or
## `_checks`/`_failures`; both are read.

const _CALLED := "_tests_called"
const _LINED := "_tests_lined"


## Runs suite.test(args...), records that it ran, and fails it by name when it
## made no check: an empty loop or an early return no longer passes quietly.
## `owner` is the object holding the checks and failures when the suite hands
## its checks to another (test_finals_cards.gd checks through the story suite).
static func one(suite: Object, test: String, args: Array = [], owner: Object = null) -> Variant:
	if owner == null:
		owner = suite
	var called: Array = suite.get_meta(_CALLED, [])
	called.append(test)
	suite.set_meta(_CALLED, called)
	if not suite.has_method(test):
		_fail(owner, "%s is called but not defined" % test)
		return null
	var before := _checks(owner)
	var result = await suite.callv(test, args)
	if _checks(owner) == before:
		_fail(owner, "%s made no checks" % test)
	return result


## The suite's summary line. Every `_test_*` method the suite defines and never
## ran through one() fails here, by name, first. `also` lists the sub-suites
## whose checks and failures the suite has already added to its own: their
## functions join the count, and their uncalled ones fail here unless the
## sub-suite printed its own line (which failed them already).
static func line(label: String, suite: Object, also: Array = []) -> String:
	var ran := 0
	var defined := 0
	for s in [suite] + also:
		var called: Array = s.get_meta(_CALLED, [])
		var reported: bool = s != suite and s.get_meta(_LINED, false)
		for test in defined_tests(s):
			defined += 1
			if called.has(test):
				ran += 1
			elif not reported:
				_fail(suite, "%s is never called: add _t(\"%s\") to run()" % [test, test])
	suite.set_meta(_LINED, true)
	return "%s tests: %d of %d functions, %d checks, %d failures" % [
			label, ran, defined, _checks(suite), _failures(suite).size()]


## Every `_test_*` method on the suite's script, its base scripts included.
static func defined_tests(suite: Object) -> Array:
	var names := []
	var script: Script = suite.get_script()
	if script == null:
		return names
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("_test_") and not names.has(n):
			names.append(n)
	return names


static func _checks(suite: Object) -> int:
	var v = suite.get("checks")
	if v == null:
		v = suite.get("_checks")
	return int(v) if v != null else 0


static func _failures(suite: Object) -> Array:
	var v = suite.get("failures")
	if v == null:
		v = suite.get("_failures")
	return v if v != null else []


static func _fail(suite: Object, message: String) -> void:
	_failures(suite).append(message)
	push_error(message)
