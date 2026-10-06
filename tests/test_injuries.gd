extends RefCounted
## Injuries: a realistic rate over a season, durability lowers the chance,
## an injured player misses his club's matches and comes back when healed,
## and everyone heals over the off-season. Run through tests/run_injuries_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	_test_durability_matters()
	_test_season_rate_and_absence()
	_test_heal_at_rollover()
	_test_concussion()
	_test_suspension()
	_test_tribunal_challenge()
	_test_played_and_simulated_alike()
	_test_no_second_roll()
	GameState.replay_seed = 0
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


## A suspension is match-based availability just like the fixture needs:
## same rule for AI/human selection, survives save/load, and counts down only
## when the club plays.
func _test_suspension() -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.save_path = "user://test_suspension.save"
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var p: Dictionary = GameState.my_list[0]
	var id := str(p["id"])
	var report := {"side": 0, "id": id, "name": GameDB.player_display_name(p),
			"victim_id": "v", "victim_name": "Victim", "reason": "rough conduct",
			"outcome": "suspension", "weeks": 2}
	GameState._process_discipline([{"home": "GEE", "away": "COL", "reports": [report]}])
	_check(int(p.get("suspension_weeks", 0)) == 2 and not Ratings.available(p),
			"A two-match MRO suspension makes the player unavailable immediately")
	var named := {"MID": [id]}
	var side := Ratings.select_side(GameState.my_list, named)
	var selected := false
	for q in (side["ground"] as Array) + (side["bench"] as Array):
		selected = selected or str(q["id"]) == id
	_check(not selected, "Naming a suspended player cannot bypass the suspension")
	var lines := GameState.my_mro_lines()
	_check(not lines.is_empty() and str(lines[0]).contains("2 matches"),
			"The round review reports the MRO suspension in football language")
	_check(GameState.save_career() and GameState.load_career(),
			"A career with a suspension saves and reloads")
	var back := GameState.list_player(id)
	_check(int(back.get("suspension_weeks", 0)) == 2 and not Ratings.available(back),
			"The suspension survives save/load with its matches remaining")
	GameState._process_discipline([{"home": "GEE", "away": "COL", "reports": []}])
	_check(int(back.get("suspension_weeks", 0)) == 1 and not Ratings.available(back),
			"After one club match, one match of the suspension remains")
	GameState._process_discipline([{"home": "GEE", "away": "COL", "reports": []}])
	_check(Ratings.available(back) and int(back.get("suspension_weeks", 0)) == 0,
			"After the second club match the player is available again")
	GameState.delete_saved_career()


## Tribunal challenges are one-shot and deterministic. An MRO sanction
## makes the player Brownlow-ineligible while votes remain elsewhere; a
## successful challenge clears both the sanction and that ineligibility.
func _test_tribunal_challenge() -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var cleared: Dictionary = GameState.my_list[0]
	var cleared_id := str(cleared["id"])
	var success_report := {"side": 0, "id": cleared_id, "name": GameDB.player_display_name(cleared),
			"victim_id": "v1", "victim_name": "Victim", "reason": "rough conduct",
			"outcome": "suspension", "weeks": 1, "tribunal_roll": 0.0, "challenged": false}
	GameState._process_discipline([{"home": "GEE", "away": "COL", "reports": [success_report]}])
	_check(bool(cleared.get("brownlow_ineligible", false)) and not Ratings.available(cleared),
			"An MRO suspension immediately makes the player unavailable and Brownlow-ineligible")
	var pending := GameState.pending_mro_challenges()
	_check(pending.size() == 1 and str(pending[0].get("case", "")) != "",
			"A live MRO sanction exposes one Tribunal challenge with a case assessment")
	var win := GameState.challenge_mro(cleared_id)
	_check(bool(win.get("success", false)) and Ratings.available(cleared)
			and not bool(cleared.get("brownlow_ineligible", false)),
			"A successful Tribunal challenge clears the ban and restores Brownlow eligibility")
	_check(GameState.pending_mro_challenges().is_empty(),
			"A Tribunal sanction cannot be challenged twice")

	var upheld: Dictionary = GameState.my_list[1]
	var upheld_id := str(upheld["id"])
	var fail_report := {"side": 0, "id": upheld_id, "name": GameDB.player_display_name(upheld),
			"victim_id": "v2", "victim_name": "Victim", "reason": "rough conduct",
			"outcome": "suspension", "weeks": 2, "tribunal_roll": 0.99, "appeal_roll": 0.0,
			"challenged": false, "appealed": false}
	GameState._process_discipline([{"home": "GEE", "away": "COL", "reports": [fail_report]}])
	var loss := GameState.challenge_mro(upheld_id)
	_check(not bool(loss.get("success", true)) and int(upheld.get("suspension_weeks", 0)) == 2
			and bool(upheld.get("brownlow_ineligible", false)),
			"A failed Tribunal challenge leaves the original ban and Brownlow ineligibility intact")
	var appeal_pending := GameState.pending_mro_challenges()
	_check(appeal_pending.size() == 1 and str(appeal_pending[0].get("stage", "")) == "appeal",
			"A failed Tribunal suspension can be taken once to the Appeals Board")
	var appeal := GameState.appeal_mro(upheld_id)
	_check(bool(appeal.get("success", false)) and Ratings.available(upheld)
			and not bool(upheld.get("brownlow_ineligible", false)),
			"A successful appeal overturns the suspension and restores Brownlow eligibility")
	_check(GameState.pending_mro_challenges().is_empty(),
			"A resolved Appeals Board case cannot be appealed twice")


	var prior: Dictionary = GameState.my_list[2]
	var prior_id := str(prior["id"])
	prior["brownlow_ineligible_cases"] = ["earlier-case"]
	prior["brownlow_ineligible"] = true
	var later_report := {"side": 0, "id": prior_id, "name": GameDB.player_display_name(prior),
			"victim_id": "v3", "victim_name": "Victim", "reason": "rough conduct",
			"outcome": "suspension", "weeks": 1, "tribunal_roll": 0.0, "appeal_roll": 0.0,
			"challenged": false, "appealed": false}
	GameState._process_discipline([{"home": "GEE", "away": "COL", "reports": [later_report]}])
	GameState.challenge_mro(prior_id)
	_check(bool(prior.get("brownlow_ineligible", false))
			and (prior.get("brownlow_ineligible_cases", []) as Array).has("earlier-case"),
			"Winning a later case does not erase Brownlow ineligibility from an earlier upheld case")


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


## The other half of that impression: nothing between the match and the
## list rolls again. Over real Sim-round weeks of a career, every injury that
## lands on a list is one MatchSim recorded in that round's results, and
## none is added on top (Injuries.apply_match falls back to the old
## after-the-siren roll only for a result with no injury record at all).
func _test_no_second_roll() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var recorded := 0
	var landed := 0
	var only_recorded := true
	for _week in range(6):
		if not GameState.week_event.is_empty():
			GameState.resolve_week_event(0)
		GameState.advance()
		var ids := {}
		for res in GameState.last_results:
			for inj in res.get("injuries", []):
				ids[str(inj["id"])] = true
				recorded += 1
		for got in GameState.last_injuries:
			landed += 1
			only_recorded = only_recorded and ids.has(str(got["id"]))
	_check(landed > 0 and landed <= recorded and only_recorded,
			"Every injury on a list after a simulated round is one the match recorded (%d of %d)" % [landed, recorded])
	var fragile := {"id": "x", "attr": {"durability": 1}, "sore": true, "heavy_legs": true}
	var lists := {"GEE": [fragile], "COL": []}
	var clean := {"home": "GEE", "away": "COL", "injuries": [], "roster": [[{"id": "x"}], []]}
	var hurt := 0
	for round_no in range(1, 200):
		hurt += Injuries.apply_match(clean, lists, 7, round_no).size()
	_check(hurt == 0 and int(fragile.get("injury_weeks", 0)) == 0,
			"A match that recorded no injuries hurts nobody afterwards, however fragile")
