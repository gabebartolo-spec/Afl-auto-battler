extends RefCounted
## Injuries: a realistic rate over a season, durability lowers the chance,
## an injured player misses his club's matches and comes back when healed,
## and everyone heals over the off-season. Run through tests/run_injuries_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_durability_matters()
	_test_season_rate_and_absence()
	_test_heal_at_rollover()
	print("Injuries tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _test_durability_matters() -> void:
	var tough := {"attr": {"durability": 95}}
	var fragile := {"attr": {"durability": 25}}
	_check(Injuries.chance(tough) < Injuries.chance(fragile) * 0.6,
			"High durability roughly halves the injury chance")


func _test_season_rate_and_absence() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var total := 0
	var games := 0
	var missed_ok := true
	var healed_ok := true
	var watched := {}  # id -> weeks still to miss
	while not GameState.season.is_regular_done():
		GameState.advance()
		games += GameState.last_results.size() * 2
		total += GameState.last_injuries.size()
		# Anyone still injured must not have played this round.
		for res in GameState.last_results:
			for side in range(2):
				var code := str(res["home"] if side == 0 else res["away"])
				var played := {}
				for r in res["roster"][side]:
					played[str(r["id"])] = true
				for id in watched:
					if played.has(id) and int(watched[id]) > 0:
						missed_ok = false
		var next := {}
		for id in watched:
			if int(watched[id]) > 1:
				next[id] = int(watched[id]) - 1
		watched = next
		for inj in GameState.last_injuries:
			watched[str(inj["id"])] = int(inj["weeks"])
	var rate := float(total) / float(maxi(1, games))
	_check(rate > 0.35 and rate < 1.3,
			"About one new injury per side per game (%.2f)" % rate)
	_check(missed_ok, "An injured player misses his club's matches")
	var still_out := 0
	for code in GameState.season.lists:
		still_out += Injuries.injured(GameState.season.lists[code]).size()
	_check(still_out < GameDB.CLUB_ORDER.size() * 6,
			"Injuries heal: the injury lists stay short (%d league-wide)" % still_out)


func _test_heal_at_rollover() -> void:
	GameState.reset()
	GameState.start_season("ADE", GameDB.club_list("ADE"))
	for p in GameState.my_list.slice(0, 5):
		p["injury_weeks"] = 9
		p["injury_kind"] = "knee"
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.ensure_finals()
	while not GameState.season.is_season_over():
		GameState.advance()
	GameState.start_next_season()
	var any := 0
	for code in GameState.season.lists:
		any += Injuries.injured(GameState.season.lists[code]).size()
	_check(any == 0, "Everyone heals over the off-season")
