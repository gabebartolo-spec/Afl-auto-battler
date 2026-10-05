extends "res://tools/balance/dynasty.gd"
## audit.yml wrapper for tools/balance/dynasty.gd (#228's career harness):
## League Draft careers (the scouted board), five seasons, autopilot against a
## managed list. Prints one line per season per career and the season's
## margins (every match in the league), so runs read straight from the log.
## Env: DYN_SEEDS (default 301..308), DYN_POLICY (default upside),
## DYN_MANAGE (none | list | full | exploit; default none), DYN_COACH (1 = coach
## on match day, as #228's comparison did; default 1), DYN_SEASONS (default 5).
## godot --headless --path . --script tools/audit/run_audit.gd -- dynasty_impl

const BANDS := [60, 80, 100, 120, 150]

var _margins := {}
var _matches := 0


func _play_week(gs, user: String, coach: bool) -> bool:
	var r: bool = super(gs, user, coach)
	for res in gs.last_results:
		var m := absi(int(res["score"][0]) - int(res["score"][1]))
		_matches += 1
		for b in BANDS:
			if m >= b:
				_margins[b] = int(_margins.get(b, 0)) + 1
	return r


static func _env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback


func run() -> void:
	var seeds := []
	for s in _env("DYN_SEEDS", "301,302,303,304,305,306,307,308").split(","):
		seeds.append(int(s))
	var policy := _env("DYN_POLICY", "upside")
	var manage := _env("DYN_MANAGE", "none")
	var coach := _env("DYN_COACH", "1") == "1"
	var seasons := int(_env("DYN_SEASONS", "5"))
	for s in seeds:
		var t := Time.get_ticks_msec()
		var rec: Array = run_career(int(s), policy, seasons, 5, coach, manage)
		for snap in rec:
			var u := str(snap["user"])
			var mg: Dictionary = snap.get("mgmt", {})
			print("DYN manage %s | seed %d | %s | year %d | rank %d | ladder %d | premier %s | mgmt %s" % [
					manage, int(s), u, int(snap["year"]), int(snap["clubs"][u]["rank"]), int(snap["user_ladder"]),
					"yes" if str(snap["premier"]) == u else "no", JSON.stringify(mg)])
		print("seed %d done (%d s)" % [int(s), (Time.get_ticks_msec() - t) / 1000])
	var line := []
	for b in BANDS:
		line.append("%d+ %.2f%% (%d)" % [b, 100.0 * int(_margins.get(b, 0)) / maxf(1, _matches), int(_margins.get(b, 0))])
	print("DYNMARGINS manage %s | %d matches | %s" % [manage, _matches, ", ".join(line)])
