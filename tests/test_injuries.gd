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
	_test_concussion()
	_test_played_and_simulated_alike()
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
	var concussions := 0
	var concussion_ok := true
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
			if str(inj["kind"]) == "concussion":
				concussions += 1
				if int(inj["weeks"]) < Injuries.CONCUSSION_MIN:
					concussion_ok = false
	var rate := float(total) / float(maxi(1, games))
	_check(rate > 0.35 and rate < 1.3,
			"About one new injury per side per game (%.2f)" % rate)
	_check(missed_ok, "An injured player misses his club's matches")
	_check(concussions > 0 and concussion_ok,
			"Every concussion in a season is at least two matches (%d concussions)" % concussions)
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


## A concussion keeps him out for two matches: no early return, no naming
## him in the side, the same rule for every club, and it survives a save.
func _test_concussion() -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.save_path = "user://test_concussion.save"
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var p: Dictionary = GameState.my_list[0]
	p["injury_weeks"] = 2
	p["injury_kind"] = "concussion"
	_check(Injuries.concussion_text(p) == "Concussion — 2 matches", "Out two matches reads as a concussion")
	# Named in the centre square, he still does not play.
	var named := {"MID": [str(p["id"])]}
	var side := Ratings.select_side(GameState.my_list, named)
	var plays := false
	for g in (side["ground"] as Array) + (side["bench"] as Array):
		if str(g["id"]) == str(p["id"]):
			plays = true
	_check(not plays, "Naming a concussed player does not get him on the ground")
	_check(GameState.save_career() and GameState.load_career(), "The career saves and loads")
	var back := GameState.list_player(str(p["id"]))
	_check(int(back.get("injury_weeks", 0)) == 2 and str(back.get("injury_kind", "")) == "concussion",
			"A concussion survives a save, matches to miss and all")
	Injuries.tick([back])
	_check(not Ratings.available(back) and Injuries.concussion_text(back) == "Concussion — 1 match",
			"After one match he still has one to miss")
	Injuries.tick([back])
	_check(Ratings.available(back) and Injuries.concussion_text(back) == "",
			"After two matches he is available again")
	GameState.delete_saved_career()


## Playtest impression: players get hurt more when the round is simulated
## than when it is played. Measured over 600 paired matches: the same players
## were hurt either way in every one (0.685 a team a game, 2.64 weeks,
## 40 concussions each). Injuries are planned at the bounce from their own
## stream; playing the match changes who takes the field, never the plan.
func _test_played_and_simulated_alike() -> void:
	var same := true
	var any := false
	for seed in range(7000, 7030):
		var hurt := []
		for live in [false, true]:
			var sim := MatchSim.new(Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE"),
					Squad.new("COL", GameDB.club_list("COL"), false, "COL"), seed)
			var res: Dictionary
			if live:
				sim.moment_side = 0
				while sim.current_quarter <= 4:
					sim.run_quarter()
				res = sim.result()
			else:
				res = sim.run()
			var ids := []
			for inj in res["injuries"]:
				ids.append("%s:%d:%s" % [str(inj["id"]), int(inj["weeks"]), str(inj["kind"])])
			ids.sort()
			hurt.append(ids)
		any = any or not (hurt[0] as Array).is_empty()
		same = same and hurt[0] == hurt[1]
	_check(any and same, "A match played and the same match simulated hurt the same players")
