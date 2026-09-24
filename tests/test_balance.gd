extends RefCounted
## Long-career balance guard: three simulated seasons (every round, the
## national draft, rollovers). The league must not inflate - ratings are
## re-anchored to the 2026 league every off-season - and the elite tail must
## survive (no ratcheting ceilings). Run through tests/run_balance_tests.gd.

const SEASONS := 3
const MEAN_TOLERANCE := 1.5
const TOP_TOLERANCE := 3.5

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var start := _league()
	for year in range(SEASONS):
		var season_start := _league()
		while not GameState.season.is_season_over():
			GameState.advance()
		var end_of_season := _league()
		var lift := float(end_of_season["mean"]) - float(season_start["mean"])
		_check(lift < 5.0,
				"In-season training lifts the league by under 5 (%d: %.1f)" % [
				GameState.season_year, lift])
		if GameState.begin_intake_draft():
			var d: Draft = GameState.draft
			while not d.is_finished():
				var c := d._best_ai_pick(d.current_club())
				if c.is_empty() or not d._draft_pick(d.current_club(), c):
					d._skip_current_pick()
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
		var now := _league()
		_check(absf(float(now["mean"]) - float(start["mean"])) <= MEAN_TOLERANCE,
				"%d starts with the league mean where 2026 did (%.1f vs %.1f)" % [
				GameState.season_year, float(now["mean"]), float(start["mean"])])
		_check(absf(float(now["top50"]) - float(start["top50"])) <= TOP_TOLERANCE,
				"%d keeps the elite tail (top-50 mean %.1f vs %.1f)" % [
				GameState.season_year, float(now["top50"]), float(start["top50"])])
		_check(int(now["max"]) >= 85, "%d still has a star rated 85+ (%d)" % [
				GameState.season_year, int(now["max"])])
	print("Balance tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _league() -> Dictionary:
	var all := []
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			all.append(int(p["overall"]))
	all.sort()
	all.reverse()
	var total := 0.0
	for x in all:
		total += float(x)
	var top := 0.0
	for i in range(mini(50, all.size())):
		top += float(all[i])
	return {"mean": total / float(all.size()), "top50": top / 50.0, "max": all[0]}
