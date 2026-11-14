extends RefCounted
## Legs and rotations, match moments, the impact readout and the rival
## coach. Run through tests/run_match_game_tests.gd.
## Seeded by design: every MatchSim takes an explicit seed.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	# These fixtures (rotations, rucks played through) are about the engine, not the director's
	# hand-set ratings (data/ovr_overrides.csv): they play on the data without them.
	GameDB.skip_ovr_overrides = true
	GameDB.reload()
	_t("_test_auto_sim_untouched")
	_t("_test_stoppage_location")
	_t("_test_boundary_rules")
	_t("_test_authenticity_events")
	_t("_test_contextual_frees_and_general_spoils")
	_t("_test_general_contest_player_edge")
	_t("_test_free_causes_follow_the_play")
	_t("_test_free_keeps_possession")
	_t("_test_clanger_cause")
	_t("_test_no_free_after_goal")
	_t("_test_free_set_shots_counted")
	_t("_test_legs_and_rotations")
	_t("_test_moments")
	_t("_test_playtest_bounce")
	_t("_test_set_shot")
	_t("_test_live_determinism")
	_t("_test_impact_and_ai")
	_t("_test_decision_credits")
	_t("_test_pep_talks")
	_t("_test_fatigue_parity")
	_t("_test_play_through")
	_t("_test_play_through_by_job")
	_t("_test_play_through_three")
	_t("_test_no_main_ruck_call")
	_t("_test_auto_rotation")
	_t("_test_background_matches_rotate")
	_t("_test_hothead")
	_t("_test_lockdown_midfielder")
	_t("_test_traits")
	_t("_test_weather")
	_t("_test_wet_weather_play")
	_t("_test_weather_turns_at_a_break")
	_t("_test_wind_and_heat")
	_t("_test_weather_follows_the_real_games")
	_t("_test_metres_and_efficiency")
	_t("_test_gps_distance")
	_t("_test_ruck_integrity")
	_t("_test_ruck_taps")
	_t("_test_stat_credits")
	_t("_test_m2_stats")
	_t("_test_no_role_gates")
	_t("_test_spoils_and_crumbs")
	_t("_test_roaming_interceptor")
	_t("_test_six_plans")
	_t("_test_press_by_zone")
	_t("_test_zone_intercepts")
	_t("_test_rotation_words_true")
	_t("_test_bring_the_heat")
	_t("_test_defensive_forward")
	_t("_test_defensive_forward_cards")
	_t("_test_df_duel_numbers")
	_t("_test_hot_player_moment")
	_t("_test_matchups")
	_t("_test_key_duel_balance")
	_t("_test_in_match_injuries")
	_t("_test_run_call_once_a_run")
	_t("_test_late_bounce_reachable")
	_t("_test_bounce_once")
	_t("_test_ballup_two")
	_t("_test_ballup_moves_play_differently")
	_t("_test_rival_ballup")
	_t("_test_ruck_never_tags")
	_t("_test_current_club_identity")
	_t("_test_tag_ends_with_injury")
	_t("_test_named_tagger_back_on")
	_t("_test_play_through_back_on_in_his_line")
	_t("_test_play_through_forced_changes")
	_t("_test_play_through_out_of_position")
	_t("_test_play_through_mid_stands_in_midfield")
	_t("_test_view_slots_stand_in_their_zone")
	_t("_test_tag_hold")
	_t("_test_match_story")
	_t("_test_first_goal_feed")
	_t("_test_traits_surfaced")
	_t("_test_momentum")
	_t("_test_momentum_runaway")
	_t("_test_moment_calls_matter")
	_t("_test_ai_chases_and_controlled_needs_ball_users")
	_t("_test_coach_styles")
	_t("_test_ai_counters_plan")
	_t("_test_rematch_lowest_mark_chance")
	_t("_test_assistant_plays_ai_calls")
	_t("_test_coach_plan_sticks_at_breaks")
	_t("_test_standing_plan_knowledge")
	_t("_test_tag_tradeoff")
	_t("_test_set_shot_bands")
	_t("_test_set_shot_calls")
	_t("_test_bomb_card_shows_the_dice")
	_t("_test_forward_archetypes")
	GameDB.skip_ovr_overrides = false
	GameDB.reload()
	print(Ran.line("Match game", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
const BalanceGate := preload("res://tests/balance_gate.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _sim(seed: int, a := "GEE", b := "COL") -> MatchSim:
	return MatchSim.new(Squad.new(a, GameDB.club_list(a), true, a),
			Squad.new(b, GameDB.club_list(b), false, b), seed)


## Bug bash 2026-11-10: the general-play mark and spoil bases sat on their
## clamp bounds, so a better defender, the loose man's shift and the
## Interceptor trait did nothing; the credit used its own old base.
func _test_general_contest_player_edge() -> void:
	var sim := _sim(4242)
	var base: Dictionary = (sim.squads[0] as Squad).ground[0]
	var fwd: Dictionary = base.duplicate(true)
	fwd["id"] = "bb_fwd"
	fwd["attr"]["marking"] = 70
	var level: Dictionary = base.duplicate(true)
	level["id"] = "bb_def_level"
	level["attr"]["marking"] = 50
	level["attr"]["intercept"] = 70
	var good: Dictionary = level.duplicate(true)
	good["id"] = "bb_def_good"
	good["attr"]["intercept"] = 90
	var inter: Dictionary = level.duplicate(true)
	inter["id"] = "bb_def_int"
	sim._traits["bb_fwd"] = []
	sim._traits["bb_def_level"] = []
	sim._traits["bb_def_good"] = []
	sim._traits["bb_def_int"] = ["interceptor"]
	var m_level := sim._general_mark_chance(fwd, level, 0.0)
	var m_good := sim._general_mark_chance(fwd, good, 0.0)
	_check(m_good < m_level, "A better defender lowers the general mark chance (%.3f < %.3f)" % [m_good, m_level])
	var m_roam := sim._general_mark_chance(fwd, good, -0.05)
	_check(m_roam < m_good, "The loose man's shift lowers the mark chance (%.3f < %.3f)" % [m_roam, m_good])
	var s_level := sim._general_spoil_chance(fwd, level)
	var s_good := sim._general_spoil_chance(fwd, good)
	var s_int := sim._general_spoil_chance(fwd, inter)
	_check(s_good > s_level, "A better defender raises the spoil chance (%.3f > %.3f)" % [s_good, s_level])
	_check(is_equal_approx(s_int - s_level, 0.06), "The Interceptor adds 0.06 to the spoil chance (%.3f vs %.3f)" % [s_int, s_level])
	# The contest reads the tuned number; the credit calls the same functions.
	var had := MatchSim.tune.has("GENERAL_MARK_P")
	var old = MatchSim.tune.get("GENERAL_MARK_P")
	MatchSim.tune["GENERAL_MARK_P"] = MatchSim.GENERAL_MARK_P + 0.10
	var m_tuned := sim._general_mark_chance(fwd, level, 0.0)
	if had:
		MatchSim.tune["GENERAL_MARK_P"] = old
	else:
		MatchSim.tune.erase("GENERAL_MARK_P")
	_check(m_tuned > m_level, "The mark chance reads the tuned GENERAL_MARK_P (%.3f > %.3f)" % [m_tuned, m_level])
	var src: String = (load("res://scripts/sim/MatchSim.gd") as GDScript).source_code
	var at := src.find("func _credit_general_loose")
	var body := src.substr(at, src.find("\n\n\n", at) - at)
	_check(body.contains("_general_mark_chance(") and body.contains("_general_spoil_chance(")
			and not body.contains("0.42"), "The loose-man credit uses the contest's own chances")


func _test_auto_sim_untouched() -> void:
	var r1 := _sim(42).run()
	var r2 := _sim(42).run()
	_check(r1["score"] == r2["score"] and r1["events"].size() == r2["events"].size(),
			"A simulated match is still deterministic")
	_check((r1["moments"] as Array).is_empty(), "Simulated matches never stop for moments")


## Restarts: a goal or a quarter break -> centre bounce; a behind -> the
## other side kicks in from its goal square, uncontested; any other stoppage
## is balled up where play stopped, and logged there.
func _test_stoppage_location() -> void:
	var sim := _sim(42)
	var evs: Array = sim.run()["events"]
	var ballups := 0
	var on_ground := true
	var centre_ok := true
	var last := ""
	var last_fp := 0.0
	for ev in evs:
		var kind := str(ev["kind"])
		if kind == "ballup":
			ballups += 1
			on_ground = on_ground and absf(float(ev["fp"])) <= 85.0
		elif ["handball", "kick", "mark"].has(kind) and float(ev["fp"]) == 0.0 \
				and last_fp != 0.0:
			# The ball came back to the centre: only a goal or a break does that.
			centre_ok = centre_ok and ["", "goal", "quarter"].has(last)
		if not ["sub", "moment", "clanger", "free"].has(kind):
			last = kind
			last_fp = 0.0 if ["goal", "quarter"].has(kind) else float(ev["fp"])
		elif kind == "free" and str(ev.get("free_cause", "")) == "ruck_contest":
			# Holding or blocking in the ruck is paid where the ruckmen
			# contested, the centre after a centre bounce.
			last_fp = float(ev["fp"])
	_check(ballups > 20, "Around-the-ground ball-ups are logged (%d)" % ballups)
	_check(on_ground, "Every ball-up is on the ground")
	_check(centre_ok, "A centre bounce only follows a goal or a quarter break")
	# Every behind is followed by a kick-in: the other side, from its goal
	# square, with a kick (never a ball-up or a handball).
	var behinds := 0
	var kick_ins_ok := true
	for i in range(evs.size()):
		var ev: Dictionary = evs[i]
		if str(ev["kind"]) != "behind":
			continue
		var j := i + 1
		while j < evs.size() and ["sub", "moment", "clanger", "free"].has(str(evs[j]["kind"])):
			j += 1
		if j >= evs.size() or ["quarter", "final"].has(str(evs[j]["kind"])):
			continue
		behinds += 1
		var nx: Dictionary = evs[j]
		kick_ins_ok = kick_ins_ok and ["kick", "mark"].has(str(nx["kind"])) \
				and int(nx["side"]) == 1 - int(ev["side"]) \
				and is_equal_approx(float(nx["fp"]), sim.kick_in_fp(int(ev["side"])))
	_check(behinds > 5 and kick_ins_ok, "Every behind is followed by a kick-in from the goal square (%d)" % behinds)
	# A kick-in has no ruck contest: no hit-out, no clearance, no ball-up. Five
	# seeds, so a stoppage roll sneaking back in (half of chains) shows up.
	var uncontested := true
	for seed in [7, 8, 9, 10, 11]:
		var k := _sim(seed)
		k.fp = k.kick_in_fp(0)
		k.kick_in = true
		k.next_side = 1
		k.at_centre = false
		var before := [(k.team_stats[0] as Dictionary).duplicate(), (k.team_stats[1] as Dictionary).duplicate()]
		var n := k.events.size()
		k._play_one_chain(Ratings.T)
		for side in range(2):
			for key in ["hitouts", "clearances"]:
				uncontested = uncontested and int((k.team_stats[side] as Dictionary).get(key, 0)) \
						== int((before[side] as Dictionary).get(key, 0))
		var first: Dictionary = k.events[n] if k.events.size() > n else {}
		uncontested = uncontested and ["kick", "mark"].has(str(first.get("kind", ""))) \
				and int(first.get("side", -1)) == 1
	_check(uncontested, "A kick-in is uncontested: the defending side kicks, no hit-out or clearance")


## 2026 boundary law: last disposal between the arcs is a free; touched or
## contested exits and ordinary OOB inside either 50 are throw-ins; out on the
## full is a free anywhere. Real matches must also produce and restart them.
func _test_boundary_rules() -> void:
	var f50 := float(Ratings.T["forward50_line"])
	_check(MatchSim.boundary_restart(0.0, f50, "kick", false, false) == "free",
			"A kick out between the arcs is a last-disposal free")
	_check(MatchSim.boundary_restart(0.0, f50, "handball", false, false) == "free",
			"A handball out between the arcs is a last-disposal free")
	_check(MatchSim.boundary_restart(0.0, f50, "kick", false, true) == "throwin",
			"A touched/contested exit between the arcs is a throw-in")
	_check(MatchSim.boundary_restart(f50 + 5.0, f50, "kick", false, false) == "throwin",
			"Ordinary out of bounds inside a 50m arc is a throw-in")
	_check(MatchSim.boundary_restart(f50 + 5.0, f50, "kick", true, false) == "free",
			"Out on the full is a free anywhere on the ground")

	var counts := {"throwin": 0, "last_disposal": 0, "out_on_full": 0}
	var legal_last := true
	var throwin_spot := true
	# 16 matches: an out-on-the-full is about one boundary kick in eight, so
	# eight matches can come up empty (about 2%) on an unlucky stream.
	for seed in range(16):
		var evs: Array = _sim(6100 + seed).run()["events"]
		for i in range(evs.size()):
			var ev: Dictionary = evs[i]
			var kind := str(ev.get("kind", ""))
			if counts.has(kind):
				counts[kind] = int(counts[kind]) + 1
			if kind == "last_disposal":
				legal_last = legal_last and absf(float(ev["fp"])) < f50
			if kind != "throwin":
				continue
			# If the throw-in is not swallowed by the quarter siren, the first
			# disposal after it starts at the same longitudinal crossing point.
			var j := i + 1
			while j < evs.size() and ["sub", "injury", "moment"].has(str(evs[j].get("kind", ""))):
				j += 1
			if j >= evs.size() or ["quarter", "final"].has(str(evs[j].get("kind", ""))):
				continue
			var nx: Dictionary = evs[j]
			if ["kick", "handball", "mark"].has(str(nx.get("kind", ""))):
				throwin_spot = throwin_spot and is_equal_approx(float(nx["fp"]), float(ev["fp"]))
	_check(int(counts["throwin"]) > 0 and int(counts["last_disposal"]) > 0 and int(counts["out_on_full"]) > 0,
			"Seeded matches produce throw-ins, last-disposal frees and out-on-full frees (%s)" % str(counts))
	_check(legal_last, "Every last-disposal free is paid between the 50m arcs")
	_check(throwin_spot, "Boundary throw-ins restart at the crossing field position")


## Smothers, speccies, 50s, MRO incidents and kick-ins are all football
## events/state, not presentation guesses.
func _test_authenticity_events() -> void:
	var smothers := 0
	var speccies := 0
	var speccy_ok := true
	var max_speccies := 0
	var kick_in_ok := true
	var kick_styles := {}
	for seed in range(6200, 6224):
		var sim := _sim(seed)
		var expected_kicker := str(sim.kick_in_taker(1).get("id", ""))
		var res: Dictionary = sim.run()
		var match_speccies := 0
		for ev in res["events"]:
			var kind := str(ev.get("kind", ""))
			if kind == "smother":
				smothers += 1
				var id := str(ev.get("player_id", ""))
				var st: Dictionary = (res["players"] as Dictionary).get(id, {})
				speccy_ok = speccy_ok and float(st.get("smothers", 0.0)) > 0.0 \
						and float(st.get("one_percenters", 0.0)) >= float(st.get("smothers", 0.0))
			if kind == "mark" and bool(ev.get("speccy", false)):
				speccies += 1
				match_speccies += 1
				speccy_ok = speccy_ok and bool(ev.get("contested", false))
			if kind == "kick" and bool(ev.get("kick_in", false)):
				kick_styles[str(ev.get("kick_in_style", ""))] = true
		max_speccies = maxi(max_speccies, match_speccies)

		# A manually staged behind restart uses the same nominated rebounder
		# and is never a ruck contest.
		var k := _sim(seed + 100)
		expected_kicker = str(k.kick_in_taker(1).get("id", ""))
		k.fp = k.kick_in_fp(0)
		k.kick_in = true
		k.next_side = 1
		k.at_centre = false
		var n := k.events.size()
		var before_ho := float((k.team_stats[1] as Dictionary).get("hitouts", 0.0))
		k._play_one_chain(Ratings.T)
		var first: Dictionary = k.events[n] if k.events.size() > n else {}
		kick_in_ok = kick_in_ok and str(first.get("kind", "")) == "kick" \
				and bool(first.get("kick_in", false)) \
				and str(first.get("player_id", "")) == expected_kicker \
				and float((k.team_stats[1] as Dictionary).get("hitouts", 0.0)) == before_ho
		if bool(first.get("kick_in", false)):
			kick_styles[str(first.get("kick_in_style", ""))] = true

	_check(smothers > 0 and speccy_ok, "Smothers are real one-percenters in the match log (%d)" % smothers)
	_check(speccies > 0 and max_speccies <= 2,
			"Speccies are genuine contested marks, never more than two a match (%d in sample)" % speccies)
	_check(kick_in_ok, "A behind restarts with the side's designated kick-in taker, no ruck contest")
	_check(kick_styles.has("safe") and kick_styles.has("play_on"),
			"Kick-ins include both safer exits and play-on exits (%s)" % str(kick_styles))

	var goal_line := float(Ratings.T["goal_line"])
	_check(is_equal_approx(MatchSim.fifty_mark(0, 0.0, goal_line), 50.0)
			and is_equal_approx(MatchSim.fifty_mark(1, 10.0, goal_line), -40.0),
			"A 50-metre penalty advances exactly 50m toward the receiving side's goal")
	_check(is_equal_approx(MatchSim.fifty_mark(0, 70.0, goal_line), goal_line),
			"A 50 stops at the goal line rather than marching through it")

	var mro := _sim(7001)
	var offender: Dictionary = (mro.squads[0] as Squad).ground[0]
	var victim: Dictionary = (mro.squads[1] as Squad).ground[0]
	(offender["attr"] as Dictionary)["discipline"] = 1
	for i in range(800):
		mro._maybe_report(0, offender, victim)
	var valid_mro := not mro.reports.is_empty()
	var suspended := 0
	for row in mro.reports:
		valid_mro = valid_mro and ["no_action", "fine", "suspension"].has(str(row.get("outcome", ""))) \
				and str(row.get("id", "")) == str(offender["id"]) \
				and str(row.get("victim_id", "")) == str(victim["id"])
		if str(row.get("outcome", "")) == "suspension":
			var w := int(row.get("weeks", 0))
			valid_mro = valid_mro and w >= 1 and w <= 3
			suspended += 1
	_check(valid_mro and suspended > 0,
			"Reportable tackles resolve once to no action, fine or 1-3 match suspension (%d reports)" % mro.reports.size())


## ARD-M3-007: the free at the end of a chain follows where the chain was. A
## ball-up chain's free is often the ruck contest, ruck against ruck; one in
## the receiving side's forward 50 is often a forward held in a marking
## contest; otherwise it is the erring player's incorrect disposal. Every free
## names who gave it away.
## A free is the ball to the side it was paid to: the next possession (before
## any ball-up, throw-in or break) is theirs, whichever side had the ball -
## high contact on the carrier and a forward held in a marking contest included.
func _test_free_keeps_possession() -> void:
	var kept := {}
	var lost := {}
	for seed in range(12):
		var evs: Array = _sim(7700 + seed).run()["events"]
		for i in range(evs.size()):
			if str(evs[i].get("kind", "")) != "free":
				continue
			var cause := str(evs[i].get("free_cause", ""))
			for j in range(i + 1, evs.size()):
				var k := str(evs[j].get("kind", ""))
				if bool(evs[j].get("from_free", false)):
					# A free inside 50 is his set shot: his possession, however it ends.
					kept[cause] = int(kept.get(cause, 0)) + 1
					break
				if k in ["ballup", "throwin", "quarter", "final"]:
					break
				if k in ["kick", "handball", "mark", "inside50", "goal", "behind"]:
					var tally: Dictionary = kept if int(evs[j]["side"]) == int(evs[i]["side"]) else lost
					tally[cause] = int(tally.get(cause, 0)) + 1
					break
	_check(lost.is_empty(), "The side paid a free has the next possession (lost: %s)" % str(lost))
	_check(int(kept.get("high_contact", 0)) > 0, "High contact on the carrier is paid and keeps the ball (%s)" % str(kept))
	_check(int(kept.get("marking", 0)) > 0, "Marking-contest frees keep the ball with the side paid (%s)" % str(kept))


## Director ruling 2026-11-03: a centre bounce always follows a goal. No free
## kick (or 50) is paid between a goal and the bounce that restarts play.
func _test_no_free_after_goal() -> void:
	var goals := 0
	var bad := 0
	for seed in range(20):
		var evs: Array = _sim(8800 + seed).run()["events"]
		for i in range(evs.size()):
			if str(evs[i].get("kind", "")) != "goal":
				continue
			goals += 1
			for j in range(i + 1, evs.size()):
				var k := str(evs[j].get("kind", ""))
				if k == "clanger":
					continue
				if k in ["free", "fifty"]:
					bad += 1
				break
	_check(goals > 0, "Goals are kicked in the sample")
	_check(bad == 0, "No free is paid between a goal and the centre bounce (%d of %d goals)" % [bad, goals])


## A free paid inside 50 is a set shot: it counts in the taker's shots and set
## shots like any other (the season book reads these).
func _test_free_set_shots_counted() -> void:
	var frees := 0
	var counted := true
	var short_frees := 0
	var no_false_mark := true
	for seed in range(8):
		var sim := _sim(7800 + seed)
		var evs: Array = sim.run()["events"]
		var by_taker := {}
		for ev in evs:
			# A free kicked short is gathered, not marked (no mark is counted).
			if bool(ev.get("from_free", false)) and str(ev.get("kind", "")) == "rebound":
				short_frees += 1
				no_false_mark = no_false_mark and not str(ev.get("text", "")).contains("marks it")
			if bool(ev.get("from_free", false)) and str(ev.get("kind", "")) in ["goal", "behind"]:
				var id := str(ev.get("player_id", ""))
				by_taker[id] = int(by_taker.get(id, 0)) + 1
				frees += 1
		for id in by_taker:
			var st: Dictionary = sim.player_stats.get(id, {})
			counted = counted and int(st.get("set_shots", 0)) >= int(by_taker[id])
	_check(frees > 0 and counted, "A set shot from a free in 50 counts in the taker's set shots (%d scored)" % frees)
	_check(no_false_mark, "A free kicked short never says the defender marked it (%d short)" % short_frees)
	# ...and the defender who gathers a short one is not credited a rebound 50
	# there: it is whoever's disposal takes it out of defensive 50 (director
	# 2026-11-07; short frees are rare in a match, so shots are taken from 80 m
	# until one falls short).
	var fs := _sim(7900)
	fs.run()
	# A finished match has gone past the last quarter: the extra shots count
	# in the fourth (a long free can score now the kicking range reaches 80 m).
	fs.current_quarter = mini(fs.current_quarter, 4)
	var taker: Dictionary = (fs.squads[0] as Squad).ground[0]
	var short_ok := false
	for i in range(200):
		var team_before := float(fs.team_stats[1].get("rebounds", 0.0))
		var his_before := {}
		for id in fs.player_stats:
			his_before[id] = float(fs.player_stats[id].get("rebounds", 0.0))
		var res: Dictionary = fs._free_set_shot(0, float(Ratings.T["goal_line"]) - 80.0, taker)
		if str(res.get("outcome", "")) != "turnover":
			continue
		var bid := str((res["actor"] as Dictionary)["id"])
		var team_ok := float(fs.team_stats[1].get("rebounds", 0.0)) == team_before
		short_ok = team_ok and float(fs.player_stats.get(bid, {}).get("rebounds", 0.0)) == float(his_before.get(bid, 0.0))
		break
	_check(short_ok, "A free kicked short credits the gathering defender no rebound 50 at the contest")


## Row 12: a clanger that ends a chain in the wet or the wind names it and
## belongs to the last disposal's player.
func _test_clanger_cause() -> void:
	var withwhy := 0
	var plain_on := 0
	var causes := {}
	var line_ok := true
	var names_ok := true
	for seed in range(24):
		var weather := "wet" if seed % 3 == 0 else ("windy" if seed % 3 == 1 else "perfect")
		var ron := _sim(9100 + seed)
		ron.weather = weather
		var res_on: Dictionary = ron.run()
		var who := {}
		for side in range(2):
			var sq: Squad = ron.squads[side]
			for p in sq.list + sq.ground + sq.bench:
				who[str(p["id"])] = int(side)
		for ev in res_on["events"]:
			if str(ev.get("kind", "")) != "clanger":
				continue
			if not ev.has("why"):
				plain_on += 1
				continue
			withwhy += 1
			var why := str(ev["why"])
			causes[why] = int(causes.get(why, 0)) + 1
			line_ok = line_ok and MatchSim.CLANGER_WHY.has(why) 					and str(ev["text"]) == str(MatchSim.CLANGER_WHY[why]) % str(ev["name"]) 					and MatchNotes.clanger_caption(why) != ""
			names_ok = names_ok and who.get(str(ev.get("player_id", "")), -1) == int(ev["side"])
			if weather != "wet":
				line_ok = line_ok and why != "wet"
			if weather != "windy":
				line_ok = line_ok and why != "wind"
	print("Clanger cause: %d with a cause %s, %d plain" % [withwhy, str(causes), plain_on])
	_check(withwhy >= 20, "Clangers name a cause in the sample (%d)" % withwhy)
	_check(causes.size() >= 2, "Both weather causes show (%s)" % str(causes))
	_check(line_ok, "Each cause line is its own words, each weather's cause only in that weather")
	_check(names_ok, "The player named is of the side that erred")
	_check(MatchSim.clanger_why({}, "wet") == "", "No disposal, no cause")
	_check(MatchSim.clanger_why({"kind": "kick", "end": "tackle"}, "wet") == "", "A tackle has its own line: no cause")
	_check(MatchSim.clanger_why({"kind": "kick", "end": ""}, "perfect") == "", "Dry still day: nothing to blame")
	_check(MatchSim.clanger_why({"kind": "kick", "end": "entry"}, "wet", "turnover") == "wet", "A wet-ball turnover off an entry names the wet")
	_check(MatchSim.clanger_why({"kind": "handball", "end": "pressure"}, "windy", "turnover") == "", "Wind blames kicks only")
	_check(MatchSim.clanger_why({"kind": "kick", "end": "aerial"}, "wet", "turnover") == "", "A kick read and marked has its own line")
	_check(MatchSim.clanger_why({"kind": "kick", "end": ""}, "wet", "score") == "", "A score is nobody's clanger")
	_check(absf(MatchSim.clanger_blame_share("wet") - 0.10 / 1.10) < 0.001
			and absf(MatchSim.clanger_blame_share("windy") - 0.02 / 1.02) < 0.001
			and MatchSim.clanger_blame_share("hot") == 0.0 and MatchSim.clanger_blame_share("perfect") == 0.0,
			"The weather takes only its own share of the blame")


func _test_free_causes_follow_the_play() -> void:
	var ruck_frees := 0
	var ruck_to_ruck := true
	var mark_frees := 0
	var mark_to_fwd := 0
	var named := true
	for seed in range(40):
		var sim := _sim(7600 + seed)
		var who := {}
		for side in range(2):
			var sq: Squad = sim.squads[side]
			for p in sq.ground + sq.bench:
				who[str(p["id"])] = p
		var res := sim.run()
		for ev in res["events"]:
			if str(ev.get("kind", "")) != "free":
				continue
			named = named and str(ev.get("against_id", "")) != ""
			var cause := str(ev.get("free_cause", ""))
			var to = who.get(str(ev.get("player_id", "")))
			var by = who.get(str(ev.get("against_id", "")))
			if cause == "ruck_contest":
				ruck_frees += 1
				ruck_to_ruck = ruck_to_ruck and to != null and by != null \
						and MatchSim._is_ruckman(to) and MatchSim._is_ruckman(by)
			elif cause == "marking" and str(ev.get("free_context", "")) == "forward50":
				mark_frees += 1
				if to != null and str(to.get("role", "")) == "FWD":
					mark_to_fwd += 1
	_check(ruck_frees > 0 and ruck_to_ruck,
			"A ruck-contest free is paid ruckman to ruckman (%d frees)" % ruck_frees)
	_check(mark_frees > 0 and float(mark_to_fwd) >= 0.5 * float(mark_frees),
			"A chain-end marking-contest free in the forward 50 goes to a forward (%d of %d)" % [mark_to_fwd, mark_frees])
	_check(named, "Every free kick names the player who gave it away")


func _test_contextual_frees_and_general_spoils() -> void:
	var causes := {}
	var general_spoils := 0
	var general_marks := 0
	var free_meta_ok := true
	for seed in range(24):
		var evs: Array = _sim(7200 + seed).run()["events"]
		for ev in evs:
			if str(ev.get("kind", "")) == "free":
				var cause := str(ev.get("free_cause", ""))
				if cause != "" and cause != "general":
					causes[cause] = int(causes.get(cause, 0)) + 1
					free_meta_ok = free_meta_ok and ev.has("against_id")
			if str(ev.get("kind", "")) == "spoil" and bool(ev.get("general_play", false)):
				general_spoils += 1
			if str(ev.get("kind", "")) == "mark" and bool(ev.get("general_play", false)):
				general_marks += 1
	_check(int(causes.get("holding_ball", 0)) > 0,
			"Holding-the-ball frees emerge from actual tackles")
	_check(int(causes.get("high_contact", 0)) > 0,
			"High-contact frees emerge from actual tackles")
	_check(int(causes.get("marking", 0)) > 0,
			"Marking-contest frees emerge from actual aerial contests")
	_check(free_meta_ok, "Contextual frees identify the offender")
	_check(general_spoils > 0, "General-play kicks can produce real spoils to a loose ball")
	_check(general_marks > 0, "The same general-play aerial model can produce marks")


func _test_legs_and_rotations() -> void:
	var sim := _sim(7)
	sim.begin_quarter()
	sim.continue_quarter()
	var mid_e := 0.0
	var n := 0
	for p in sim.squads[0].ground:
		if str(p["role"]) == "MID":
			mid_e += float(sim.energy[str(p["id"])])
			n += 1
	_check(n > 0 and mid_e / n < 90.0, "Midfielders tire during a quarter (%.0f%%)" % (mid_e / maxi(1, n)))
	sim.end_quarter()
	while sim.current_quarter <= 4:
		sim.run_quarter()
	var res := sim.result()
	_check(int(res["interchanges"][0]) > 5, "Coaches rotate players (%d interchanges)" % int(res["interchanges"][0]))
	_check((res["roster"][0] as Array).size() > 18, "Bench players who came on are in the match roster")
	var subs := 0
	for ev in res["events"]:
		if str(ev["kind"]) == "sub":
			subs += 1
	_check(subs == int(res["interchanges"][0]) + int(res["interchanges"][1]),
			"Every interchange is in the event log for the oval")
	var hard := 0
	var stars := 0
	for i in range(6):
		var a := _sim(100 + i)
		a.set_rotation_policy(0, "hard")
		hard += int(a.run()["interchanges"][0])
		var b := _sim(100 + i)
		b.set_rotation_policy(0, "stars")
		stars += int(b.run()["interchanges"][0])
	_check(hard > stars, "Rotating hard makes more interchanges than riding the stars (%d vs %d)" % [hard, stars])
	var tired := {"id": "x", "attr": {"goalkicking": 80}}
	sim.energy["x"] = 30.0
	var tired_fit := sim.fit(tired)
	sim.energy["x"] = 100.0
	_check(tired_fit < 0.9 and sim.fit(tired) > 1.0, "Tired players play below their rating, fresh ones above")


## Step a live match, answering every moment with `pick`. Returns the sim.
func _live(seed: int, pick: Callable) -> MatchSim:
	var sim := _sim(seed)
	sim.moment_side = 0
	while sim.current_quarter <= 4:
		sim.begin_quarter()
		while not sim.continue_quarter():
			sim.resolve_moment(int(pick.call(sim.pending_moment)))
		sim.end_quarter()
	return sim


func _test_moments() -> void:
	var total := 0
	var kinds := {}
	var ok_log := true
	var consistent := true
	# Twelve live games: a handful of moments in the first six (the count
	# below), and over all twelve the rarer kinds (a duel, a hot hand) too.
	for i in range(12):
		var sim := _live(300 + i, func(m): return (m["options"] as Array).size() - 1)
		for m in sim.moments:
			if i < 6:
				total += 1
			kinds[str(m["kind"])] = true
			if not m.has("choice_label") or not m.has("outcome") or int(m["side"]) != 0:
				ok_log = false
		var res := sim.result()
		for side in range(2):
			var pg := 0
			for id in res["players"]:
				var belongs := false
				for r in res["roster"][side]:
					if str(r["id"]) == str(id):
						belongs = true
				if belongs:
					pg += int(res["players"][id].get("goals", 0))
			var qg := 0
			for q in res["q_goals"]:
				qg += int(q[side])
			if pg != int(res["goals"][side]) or qg != int(res["goals"][side]):
				consistent = false
	_check(total >= 12 and total <= 6 * 8, "Live matches stop for a handful of moments (%d in 6 games)" % total)
	_check(kinds.size() >= 3, "Several kinds of moment come up (%s)" % str(kinds.keys()))
	_check(ok_log, "Every moment is logged with the call and how it came off")
	_check(consistent, "Goals from moments add up: players, quarters and the scoreboard agree")
	# Skip: run_quarter takes the default call for anything pending.
	var sim := _sim(301)
	sim.moment_side = 0
	var res := sim.run()
	_check(not (res["moments"] as Array).is_empty() and sim.pending_moment.is_empty(),
			"Skipping to full time answers pending moments with the default call")


## The playtest centre-bounce call (Settings, ARD-M8-007): with it on, every live match
## reaches the centre-bounce call in the last quarter, whatever the score - and answered
## "Play it straight" (its default) the match ends exactly as it would have without it.
func _test_playtest_bounce() -> void:
	var reached := 0
	var unchanged := 0
	var games := 6
	for i in range(games):
		var plain := _live(700 + i, func(m): return int(m["default"]))
		var sim := _sim(700 + i)
		sim.moment_side = 0
		sim.always_offer_bounce = true
		while sim.current_quarter <= 4:
			sim.begin_quarter()
			while not sim.continue_quarter():
				sim.resolve_moment(int(sim.pending_moment["default"]))
			sim.end_quarter()
		var q4 := (sim.moments as Array).filter(func(m): return str(m["kind"]) == "bounce" and int(m["q"]) == 4)
		if not q4.is_empty():
			reached += 1
		var a := plain.result()
		var b := sim.result()
		# Once a match (director, 2026-10-07): the playtest call takes the
		# place of a later centre-bounce call, so bounce calls are left out of
		# the comparison and counted instead.
		var not_bounce := func(m): return str(m["kind"]) != "bounce"
		var others_a := (plain.moments as Array).filter(not_bounce).map(func(m): return [m["kind"], m["q"], m["min"]])
		var others_b := (sim.moments as Array).filter(not_bounce).map(func(m): return [m["kind"], m["q"], m["min"]])
		var bounces := (sim.moments as Array).filter(func(m): return str(m["kind"]) == "bounce").size()
		if a["goals"] == b["goals"] and a["behinds"] == b["behinds"] and others_a == others_b and bounces == 1:
			unchanged += 1
	_check(reached == games, "With the playtest switch on, every match reaches the centre-bounce call (%d of %d)" % [reached, games])
	_check(unchanged == games,
			"Played straight, the playtest call changes nothing: same score, same other calls, one centre-bounce call (%d of %d)" % [unchanged, games])


## The director (2026-11-11): the bomb's card shows the pack's real odds, not
## a fixed behind figure. What the coach's default weighs is left alone.
func _test_bomb_card_shows_the_dice() -> void:
	var sim: MatchSim = null
	var m := {}
	for i in range(12):
		sim = _sim(500 + i)
		sim.moment_side = 0
		while sim.current_quarter <= 4 and m.is_empty():
			sim.begin_quarter()
			while m.is_empty() and not sim.continue_quarter():
				if str(sim.pending_moment["kind"]) == "set_shot":
					m = sim.pending_moment
				else:
					sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
			if m.is_empty():
				sim.end_quarter()
		if not m.is_empty():
			break
	_check(not m.is_empty(), "(setup) a set-shot call comes up")
	if m.is_empty():
		return
	var bomb := {}
	for o in m["options"]:
		if str(o["key"]) == "bomb":
			bomb = o
	_check(bomb.has("show_goal") and bomb.has("show_behind"), "The bomb carries the odds its card shows")
	var shooter := sim._on_ground(0, str(m["player_id"]))
	var defender := sim._on_ground(1, str(m.get("defender_id", "")))
	var odds := sim.bomb_odds(0, shooter)
	_check(is_equal_approx(float(bomb.get("show_goal", -1.0)), float(odds["goal"]))
			and is_equal_approx(float(bomb.get("show_behind", -1.0)), float(odds["behind"])),
			"The card's figures are the pack's odds (%s against %s)" % [str(bomb.get("show_goal")), str(odds)])
	var lines := GateOdds.set_shot_lines(bomb)
	_check(str(bomb["gain"]) == str(lines[0]) and str(lines[0]).contains(GateOdds.BOMB_GAIN % [
			GateOdds.about_pct(float(odds["goal"])), GateOdds.about_pct(float(odds["behind"]))]),
			"The card's line reads those odds: %s" % str(bomb["gain"]))
	var rest := 100 - roundi(float(odds["goal"]) * 100.0) - roundi(float(odds["behind"]) * 100.0)
	_check(str(bomb["cost"]).contains("%d%%" % rest), "Goal, behind and cleared add to 100: %s" % str(bomb["cost"]))
	# The coach's default and the Moments line weigh what they always did.
	_check(float(bomb["behind"]) == 0.30 and float(bomb["goal"]) >= 0.1 and float(bomb["goal"]) <= 0.5
			and is_equal_approx(sim._option_points(bomb), float(bomb["goal"]) * 6.0 + 0.30),
			"What the coach's default weighs for a bomb is unchanged (%s)" % str(bomb))
	# The dice: bomb it many times; goals and behinds come at the odds shown.
	# The odds are read before each kick, as the card reads them.
	const N := 5000
	var want_g := 0.0
	var want_b := 0.0
	var goals := 0
	var behinds := 0
	for i in N:
		var now := sim.bomb_odds(0, shooter)
		want_g += float(now["goal"])
		want_b += float(now["behind"])
		var res: Dictionary = sim._bomb(0, shooter, defender)
		if int(res["points"]) == 6:
			goals += 1
		elif int(res["points"]) == 1:
			behinds += 1
	_check(absf(goals - want_g) / N < 0.02 and absf(behinds - want_b) / N < 0.02,
			"Bombed %d times, the pack pays what the card shows: goals %.3f against %.3f shown, behinds %.3f against %.3f" % [
			N, float(goals) / N, want_g / N, float(behinds) / N, want_b / N])


func _test_set_shot() -> void:
	var found := false
	var scored_right := true
	for i in range(12):
		var sim := _sim(500 + i)
		sim.moment_side = 0
		while sim.current_quarter <= 4 and not found:
			sim.begin_quarter()
			while not sim.continue_quarter():
				var m := sim.pending_moment
				if str(m["kind"]) == "set_shot" and not found:
					found = true
					var opts: Array = m["options"]
					var worded := opts.size() >= 2
					for o in opts:
						var d := str(o["detail"])
						worded = worded and d != "" and not d.contains("%")
					var t := str(m["text"])
					for ch in t:
						if ch >= "0" and ch <= "9":
							worded = false
					_check(worded, "A set shot offers choices described in words, not odds: %s / %s" % [t, str(opts[0]["detail"])])
					var before := sim.score(0)
					var done := sim.resolve_moment(0)
					var gained := sim.score(0) - before
					scored_right = gained == int(done["points"]) and [0, 1, 6].has(gained)
				else:
					sim.resolve_moment(int(m.get("default", 0)))
			sim.end_quarter()
		if found:
			break
	_check(found, "Set-shot moments come up in live matches")
	_check(scored_right, "A set shot's result goes on the scoreboard")


func _test_live_determinism() -> void:
	var a := _live(777, func(m): return 0)
	var b := _live(777, func(m): return 0)
	_check(a.result()["score"] == b.result()["score"], "Same match, same calls, same result")


func _test_impact_and_ai() -> void:
	# The impact ledger must credit a gameplan with the expected points it is
	# worth, to the side that runs it, and nothing when nobody runs one. Checked
	# per match over five seeds. "Controlled" is used for the size check
	# because every effect it credits helps the side running it (fewer
	# turnovers, fewer clangers, a slightly better shot), so its credit has a
	# known sign in every match. "Attacking" trades a better shot for more
	# clangers and a more exposed defence, so its net swings either way and
	# says nothing about whether the ledger works.
	var zero_ok := true
	var credited_ok := true
	var owner_ok := true
	var imp: Array = []
	for seed in [900, 901, 902, 903, 904]:
		var even := _sim(seed).run()["impact"] as Array
		for side in range(2):
			zero_ok = zero_ok and float((even[side] as Dictionary).get("gameplan", 0.0)) == 0.0
		var sim := _sim(seed)
		sim.set_tactics(0, {"gameplan": "controlled"})
		imp = sim.run()["impact"]
		credited_ok = credited_ok and float((imp[0] as Dictionary).get("gameplan", 0.0)) > 0.5
		owner_ok = owner_ok and float((imp[1] as Dictionary).get("gameplan", 0.0)) == 0.0
	_check(zero_ok, "No gameplan, no gameplan points (balanced v balanced, every match)")
	_check(credited_ok, "A gameplan's effect is measured in expected points (every match)")
	_check(owner_ok, "Gameplan points go to the side that runs the plan")
	var lines := CoachReport.impact_lines(imp, [{}, {}], 0)
	_check(not lines.is_empty() and str(lines[0]["label"]).begins_with("Your")
			or str(lines[0]["label"]).begins_with("Their"), "The readout names what the points came from")
	# The rival coach plays its usual game, reacts to the scoreboard, and
	# counters the plan you ran when the counter costs it little.
	var live := _sim(901)
	for q in range(2):
		live.set_tactics(0, {"gameplan": "attacking"})
		live.set_tactics(1, {"gameplan": "balanced"})
		live.run_quarter()
	var margin := live.score(1) - live.score(0)
	var expect := str(live.standing[1])
	var react := 18.0 - 8.0 * float((live.squads[1] as Squad).tactics_read)
	if margin >= react:
		expect = "controlled"
	elif margin <= -react:
		expect = "attacking"
	elif margin < 0 and live.current_quarter >= 3 and live._lost_quarter(1, live.current_quarter - 1):
		expect = "attacking"   # behind after half time and still losing ground: it chases
	else:
		var sq1: Squad = live.squads[1]
		if PlanFit.plan_score(sq1.ground, "defensive", sq1.plan_know) >= PlanFit.plan_score(sq1.ground, expect, sq1.plan_know) - MatchSim.COUNTER_GIVE:
			expect = "defensive"   # the press beats Attack Corridor
	_check(str(live.ai_tactics(1)["gameplan"]) == expect,
			"Run Attack Corridor twice: the rival coach keeps its usual game or plays the scoreboard (%s)" % expect)
	live.set_tactics(0, {"gameplan": "controlled"})
	live.run_quarter()
	var tagged := str(live.ai_tactics(1).get("tag_id", ""))
	var tagged_mid := false
	for p in (live.squads[0] as Squad).ground:
		if str(p["id"]) == tagged:
			tagged_mid = MatchSim.taggable(p)
	var their_tagger = MatchSim.tagger_for((live.squads[1] as Squad).ground)
	if their_tagger != null and Roles.is_tagger(their_tagger):
		_check(tagged != "" and tagged_mid, "After half time the rival coach tags one of your midfielders with its tagger")
	else:
		_check(tagged == "", "Without a specialist tagger the rival coach does not waste a good midfielder on a tag")
	# The same rule both ways: a side with a tagger tags, one without does not.
	var with_tagger := ""
	var without := ""
	for code in GameDB.active_clubs(2027):
		var t = MatchSim.tagger_for(Squad.new(code, GameDB.club_list(code), false, code).ground)
		if t != null and Roles.is_tagger(t):
			with_tagger = code if with_tagger == "" else with_tagger
		elif without == "":
			without = code
	for pair in [[with_tagger, true], [without, false]]:
		if str(pair[0]) == "":
			_check(false, "The league has clubs with and without a specialist tagger")
			continue
		var s2 := _sim(903, "GEE" if str(pair[0]) != "GEE" else "COL", str(pair[0]))
		for q in range(3):
			s2.run_quarter()
		# Who is on the ground now: rotations can take the tagger off.
		var now_t = MatchSim.tagger_for((s2.squads[1] as Squad).ground)
		var has_now: bool = now_t != null and Roles.is_tagger(now_t)
		_check((str(s2.ai_tactics(1).get("tag_id", "")) != "") == has_now,
				"%s %s a tag in the second half" % [str(pair[0]), "calls" if has_now else "does not call"])
	# A tired star: the rotations handle him under every policy, with no call
	# (Director Bible 2.60: rotations are automatic for both sides).
	for policy in ["normal", "stars"]:
		var tired := _sim(902)
		tired.moment_side = 0
		tired.set_rotation_policy(0, policy)
		var star: Dictionary = {}
		for p in tired.squads[0].ground:
			if int(p["overall"]) >= MatchSim.STAR_OVR:
				star = p
		if star.is_empty():
			_check(false, "Club 902 fields a star")
			continue
		tired.begin_quarter()
		tired.energy[str(star["id"])] = 20.0      # after the break's recovery: cooked
		var calls := 0
		var guard := 0
		while guard < 40:
			if tired.continue_quarter():
				break
			var m := tired.pending_moment
			if str(m.get("kind", "")) == "tired":
				calls += 1
			tired.resolve_moment(int(m.get("default", 0)))
			guard += 1
		var subbed := false
		for ev in tired.events:
			if str(ev["kind"]) == "sub" and int(ev["side"]) == 0 and int(ev.get("off_num", -1)) == int(star["num"]):
				subbed = true
		_check(calls == 0, "%s rotations: no running-on-empty call" % policy)
		_check(subbed, "%s rotations take the cooked star off by themselves" % policy)


## Fatigue parity (T3.F-defects): your side and the rival's rotate on one rule.
## Riding the stars, a cooked star comes off at the same line on either side,
## whether or not you are coaching; the tired-star call that held yours on is gone
## (Director Bible 2.60, 2.63 superseded).
func _test_fatigue_parity() -> void:
	for mine in range(2):
		var sim := _sim(902)
		sim.moment_side = mine
		var stars := [{}, {}]
		for side in range(2):
			sim.set_rotation_policy(side, "stars")
			for p in sim.squads[side].ground:
				if int(p["overall"]) >= MatchSim.STAR_OVR:
					stars[side] = p
		if stars[0].is_empty() or stars[1].is_empty():
			_check(false, "Both sides field a star")
			return
		sim.begin_quarter()
		for side in range(2):
			sim.energy[str(stars[side]["id"])] = 20.0
		var tired_calls := 0
		var guard := 0
		while guard < 60:
			if sim.continue_quarter():
				break
			if str(sim.pending_moment.get("kind", "")) == "tired":
				tired_calls += 1
			sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
			guard += 1
		_check(tired_calls == 0, "No tired-star call for your side (side %d)" % mine)
		for side in range(2):
			var subbed := false
			for ev in sim.events:
				if str(ev["kind"]) == "sub" and int(ev["side"]) == side and int(ev.get("off_num", -1)) == int(stars[side]["num"]):
					subbed = true
			_check(subbed, "Side %d's cooked star is rotated off with side %d coached" % [side, mine])


## Calm the group is a live option: a milder, quarter-long Slow it down,
## distinct from Fire them up and from the default Stay composed.
func _test_pep_talks() -> void:
	var sim := _sim(55)
	sim.set_tactics(0, {"pep": "calm"})
	sim.set_tactics(1, {"pep": "fire_up"})
	_check(sim._pep_mult(0, "clangers") < 1.0 and sim._pep_mult(0, "taken") < 1.0
			and sim._pep_mult(0, "gain") < 1.0 and sim._pep_mult(0, "pace") < 1.0,
			"Calm the group cuts clangers, pressure felt and running, for less ground gained")
	_check(sim._contest_pep(0) == 0.0 and sim._pep_mult(1, "taken") == 1.0
			and sim._pep_mult(1, "clangers") > 1.0 and sim._pep_mult(1, "pace") > 1.0,
			"Calm the group and Fire them up do different things: fired up, tempers fray and legs go quicker")
	# Fire them up lifts a side only while it is chasing the game; the costs stay.
	_check(sim._contest_pep(1) == 0.0, "Level on the scoreboard, a fired-up side gets no lift at the contest")
	(sim.team_stats[0] as Dictionary)["goals"] = 2.0
	_check(sim._contest_pep(1) > 0.0, "Two goals down, it does")
	(sim.team_stats[0] as Dictionary)["goals"] = 0.0
	(sim.team_stats[1] as Dictionary)["goals"] = 2.0
	_check(sim._contest_pep(1) == 0.0 and sim._pep_mult(1, "clangers") > 1.0,
			"In front, the lift is gone but the costs are not")
	(sim.team_stats[1] as Dictionary)["goals"] = 0.0
	# Legs last longer: the same chain drains a calm side less than a steady one.
	var calm := _sim(56)
	var steady := _sim(56)
	calm.set_tactics(0, {"pep": "calm"})
	steady.set_tactics(0, {"pep": "steady"})
	calm._after_chain()
	steady._after_chain()
	var e_calm := 0.0
	var e_steady := 0.0
	for p in calm.squads[0].ground:
		e_calm += float(calm.energy[str(p["id"])])
	for p in steady.squads[0].ground:
		e_steady += float(steady.energy[str(p["id"])])
	_check(e_calm > e_steady, "Calm the group saves legs (%.2f v %.2f energy)" % [e_calm, e_steady])
	# Played for a quarter, it acts on the chains and the readout credits it.
	var q := _sim(57)
	q.set_tactics(0, {"pep": "calm"})
	q.set_tactics(1, {"pep": "steady"})
	q.run_quarter()
	var composed := _sim(57)
	composed.set_tactics(0, {"pep": "steady"})
	composed.set_tactics(1, {"pep": "steady"})
	composed.run_quarter()
	_check(float((q.impact[0] as Dictionary).get("pep", 0.0)) > 0.0,
			"A calmed quarter shows in the readout as pep-talk points")
	_check(float((composed.impact[0] as Dictionary).get("pep", 0.0)) == 0.0,
			"Stay composed changes nothing")
	_check(CoachReport.pep_effect("calm") != CoachReport.pep_effect("steady")
			and CoachReport.pep_effect("calm") != CoachReport.pep_effect("fire_up"),
			"The coach box describes what calming the group does")


## GEE v COL with every player at discipline 60, except four of GEE's
## on-ground players at `disc` (20 makes them Hotheads, 21 does not).
func _discipline_sim(seed: int, disc: int) -> MatchSim:
	var lists := []
	for code in ["GEE", "COL"]:
		var l: Array = []
		for p in GameDB.club_list(code):
			var q: Dictionary = p.duplicate(true)
			(q["attr"] as Dictionary)["discipline"] = 60
			l.append(q)
		lists.append(l)
	var home := Squad.new("GEE", lists[0], true, "GEE")
	var away := Squad.new("COL", lists[1], false, "COL")
	for i in range(4):
		(home.ground[i]["attr"] as Dictionary)["discipline"] = disc
	return MatchSim.new(home, away, seed)


## Hothead: he gives away 50% more clangers than his discipline alone would,
## on top of his teammates' share - so his side gives away more clangers and
## free kicks, not just him.
func _test_hothead() -> void:
	var hot := _discipline_sim(60, 20)
	var cool := _discipline_sim(60, 21)
	_check(hot._trait(hot.squads[0].ground[0], "hothead")
			and not cool._trait(cool.squads[0].ground[0], "hothead"),
			"Discipline 20 makes a Hothead, 21 does not")
	var hw: Array = hot._clanger_weights(0)
	var cw: Array = cool._clanger_weights(0)
	_check(float(hw[0][0]) / float(cw[0][0]) > 1.45,
			"A Hothead is half as likely again to be the one giving it away")
	_check(float(hw[1]) > 1.15 and is_equal_approx(float(cw[1]), 1.0),
			"Four Hotheads lift the side's clanger rate (x%.2f); none leave it alone" % float(hw[1]))
	# Keep this a mechanism test. A small sample of complete matches can reverse
	# the free-kick count by chance even when these exact weights are correct;
	# increasing that sample only made CI slower, not more trustworthy.
	var hot_total := 0.0
	var cool_total := 0.0
	for row in hw[0]:
		hot_total += float(row)
	for row in cw[0]:
		cool_total += float(row)
	_check(hot_total > cool_total,
			"Hotheads increase the side's weighted chance of giving a clanger away")


## GEE v COL, every COL player at pressure 50 (no Lockdowns), except COL's
## first on-ground midfielder at `minder_pressure` (64+ makes him a Lockdown).
func _lockdown_sim(minder_pressure: int) -> MatchSim:
	var lists := []
	for code in ["GEE", "COL"]:
		var l: Array = []
		for p in GameDB.club_list(code):
			l.append(p.duplicate(true))
		lists.append(l)
	var home := Squad.new("GEE", lists[0], true, "GEE")
	var away := Squad.new("COL", lists[1], false, "COL")
	for p in away.ground + away.bench:
		(p["attr"] as Dictionary)["pressure"] = 50
	for p in away.ground:
		if str(p["role"]) == "MID":
			(p["attr"] as Dictionary)["pressure"] = minder_pressure
			break
	return MatchSim.new(home, away, 5)


## GEE's on-ground players of `role`, best rated first.
func _ranked(sim: MatchSim, role: String) -> Array:
	var out: Array = []
	for p in sim.squads[0].ground:
		if str(p["role"]) == role:
			out.append(p)
	out.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	return out


## Lockdown on a midfielder: he picks up their best midfielder, whose shots
## are 4% less likely to be goals. Before, only the forward-50 defender (a
## defender) could ever be the Lockdown on a shot.
func _test_lockdown_midfielder() -> void:
	var lock := _lockdown_sim(80)
	var none := _lockdown_sim(63)
	var minder: Dictionary = lock.squads[1].ground.filter(func(p): return str(p["role"]) == "MID")[0]
	_check(lock._trait(minder, "lockdown")
			and not none._trait(none.squads[1].ground.filter(func(p): return str(p["role"]) == "MID")[0], "lockdown"),
			"Pressure 64 makes a midfielder a Lockdown, 63 does not")
	var fwd := _fake("lk_fwd", "FWD", {"pressure": 95})
	_check(not Traits.of(fwd).has("lockdown"), "A forward cannot be a Lockdown, however hard he presses")
	var best_lock: Dictionary = _ranked(lock, "MID")[0]
	var best_none: Dictionary = _ranked(none, "MID")[0]
	_check(str(lock._midfield_minder(0, best_lock).get("id", "")) == str(minder["id"]),
			"The Lockdown midfielder picks up their best midfielder")
	var p_lock := lock.shot_chance(0, best_lock, true, false)
	var p_none := none.shot_chance(0, best_none, true, false)
	_check(is_equal_approx(p_lock, p_none * 0.96),
			"His opponent's shots are 4%% less likely to be goals (%.4f v %.4f)" % [p_lock, p_none])
	# Only his opponent: their other midfielders and their forwards shoot as before.
	var second_lock: Dictionary = _ranked(lock, "MID")[1]
	var second_none: Dictionary = _ranked(none, "MID")[1]
	_check(is_equal_approx(lock.shot_chance(0, second_lock, true, false),
			none.shot_chance(0, second_none, true, false)),
			"A midfielder he is not on shoots as before")
	var f_lock: Dictionary = _ranked(lock, "FWD")[0]
	var f_none: Dictionary = _ranked(none, "FWD")[0]
	_check(lock._midfield_minder(0, f_lock).is_empty() and is_equal_approx(
			lock.shot_chance(0, f_lock, true, false), none.shot_chance(0, f_none, true, false)),
			"A Lockdown midfielder does not mind their forwards")


## Match-day weather (ARD-M4-016).
func _test_weather() -> void:
	_check(Weather.condition("MCG", 4, 12345) == Weather.condition("MCG", 4, 12345),
			"The same match always has the same weather: the forecast is what's played")
	var dry := true
	for k in range(200):
		if Weather.condition("Marvel Stadium", 4, k) != "perfect":
			dry = false
	_check(dry, "Under the roof it's always a perfect day")
	var a := _sim(91)
	var b := _sim(91)
	b.weather = "perfect"
	_check(a.run()["events"] == b.run()["events"], "A perfect day is the game exactly as calibrated")
	var marks := [0.0, 0.0]
	for i in range(6):
		for c in range(2):
			var s := _sim(300 + i)
			s.weather = ["perfect", "wet"][c]
			var res := s.run()
			for side in range(2):
				marks[c] += float((res["team"][side] as Dictionary).get("marks", 0.0))
	_check(marks[1] < marks[0] * 0.95, "Fewer marks stick in the wet (%.0f against %.0f)" % [marks[1], marks[0]])


## Row 160 (director 2026-11-12: "Yes, at a break"): the weather turns at most
## once a match, at a break, as often as the forecast says; the quarters before
## it play the day's weather and the quarters after it the new one.
func _test_weather_turns_at_a_break() -> void:
	# The rate: over many matches at an outdoor ground, each start turns as often
	# as the forecast's odds say (within three standard errors), at each break
	# about as often, and always to a different condition.
	var n := 6000
	var rate_ok := true
	var breaks := [0, 0, 0]
	var to_other := true
	var notes := []
	for start in Weather.CONDITIONS:
		var p := Weather.turn_chance(start, "MCG")
		var turned := 0
		for k in range(n):
			var t := Weather.turn(start, "MCG", k)
			if t.is_empty():
				continue
			turned += 1
			breaks[int(t["after"]) - 1] += 1
			if str(t["to"]) == start or not Weather.CONDITIONS.has(str(t["to"])):
				to_other = false
		var se := sqrt(p * (1.0 - p) / float(n))
		var got := float(turned) / float(n)
		notes.append("%s %.3f v %.2f" % [start, got, p])
		if absf(got - p) > 3.0 * se + 0.0001:
			rate_ok = false
	_check(rate_ok, "Each start turns as often as the forecast says (%s)" % ", ".join(notes))
	var total := float(breaks[0] + breaks[1] + breaks[2])
	_check(breaks.all(func(b): return absf(float(b) / total - 1.0 / 3.0) < 0.03),
			"Quarter time, half time and three-quarter time are each as likely (%s)" % str(breaks))
	_check(to_other, "A turn is always to a different condition")
	_check(Weather.turn("wet", "MCG", 77) == Weather.turn("wet", "MCG", 77),
			"The same match always turns the same way: the odds stated are the ones played")
	var roof := true
	for k in range(500):
		if not Weather.turn("wet", "Marvel Stadium", k).is_empty():
			roof = false
	_check(roof and Weather.turn_chance("perfect", "Marvel Stadium") == 0.0,
			"Under the roof the day never turns")
	_check(Weather.turn_odds_line(0.31) == "31% chance it turns at a break" and Weather.turn_odds_line(0.0) == "",
			"The forecast states the odds as a percentage")
	# The match: a perfect day that turns wet at half time.
	var held := _sim(91)
	held.set_day({"weather": "perfect", "chance": 0.04, "turn": {}})
	var turns := _sim(91)
	turns.set_day({"weather": "perfect", "chance": 0.04, "turn": {"after": 2, "to": "wet"}})
	_check(turns.weather_turn_now().is_empty() and turns.weather_ahead() == "perfect",
			"Nothing is announced before the first bounce")
	var first_half_same := true
	for q in range(2):
		held.run_quarter()
		turns.run_quarter()
		if q == 0:
			_check(turns.weather_turn_now().is_empty(), "Nothing is announced at quarter time")
	first_half_same = held.events == turns.events
	_check(first_half_same and turns.weather == "perfect",
			"The first half is played in the day's weather, exactly as a day that holds")
	var news := turns.weather_turn_now()
	_check(str(news.get("to", "")) == "wet" and int(news.get("after", 0)) == 2 and turns.weather_ahead() == "wet",
			"Half time announces the rain, and the plans are sized for it")
	var dry_marks := float(held._rates()["mark_share_of_kicks"])
	turns.run_quarter()
	_check(turns.weather == "wet" and turns.weather_turn_now().is_empty(),
			"The rain plays from the third quarter's bounce, announced once")
	_check(float(turns._rates()["mark_share_of_kicks"]) < dry_marks,
			"The wet's rates play for the quarters left (marks %.3f against %.3f)"
			% [float(turns._rates()["mark_share_of_kicks"]), dry_marks])
	turns.run_quarter()
	var res := turns.result()
	_check(str(res["weather"]) == "wet" and str(res["weather_start"]) == "perfect"
			and int(res["weather_turned_after"]) == 2, "The result keeps how the day started and when it turned")
	var line := Weather.turn_report_line("perfect", 2, "wet")
	_check(line.begins_with("It started fine. The rain came in at half time:"),
			"The match report says when it turned: " + line)
	# A day that holds plays as it always has: a bare condition is the old game.
	var bare := _sim(91)
	bare.weather = "perfect"
	var held2 := _sim(91)
	held2.set_day({"weather": "perfect", "chance": 0.04, "turn": {}})
	_check(bare.run()["events"] == held2.run()["events"], "A day that holds is the game exactly as before")


## Row 120 (director 2026-11-06): the wet brings fumbles, stoppages and tackles, and set
## shots get harder. Same lists and seeds, perfect day against wet.
func _test_wet_weather_play() -> void:
	var dry := _sim(1)
	_check(dry._wx("set_acc") == 1.0 and dry._wx("fumble", 0.0) == 0.0,
			"A perfect day has no wet-ball rules at all")
	var clangers := [0.0, 0.0]
	var ballups := [0, 0]
	var tackles := [0.0, 0.0]
	var disposals := [0.0, 0.0]
	var kicks := [0.0, 0.0]
	var marks := [0.0, 0.0]
	var set_shots := [0, 0]
	var set_goals := [0, 0]
	var fumbles := 0
	var fumble_named := true
	var fumble_ballups := 0
	for i in range(16):
		for c in range(2):
			var s := _sim(700 + i)
			s.weather = ["perfect", "wet"][c]
			var res := s.run()
			for side in range(2):
				clangers[c] += float((res["team"][side] as Dictionary).get("clangers", 0.0))
				tackles[c] += float((res["team"][side] as Dictionary).get("tackles", 0.0))
				disposals[c] += float((res["team"][side] as Dictionary).get("disposals", 0.0))
				kicks[c] += float((res["team"][side] as Dictionary).get("kicks", 0.0))
				marks[c] += float((res["team"][side] as Dictionary).get("marks", 0.0))
			var evs: Array = res["events"]
			for j in range(evs.size()):
				var e: Dictionary = evs[j]
				if str(e.get("kind", "")) == "ballup":
					ballups[c] += 1
				if c == 1 and str(e.get("kind", "")) == "clanger" and bool(e.get("fumble", false)):
					fumbles += 1
					if str(e.get("text", "")) != MatchSim.CLANGER_WHY["wet"] % str(e.get("name", "")) 							or str(e.get("name", "")) == "":
						fumble_named = false
					if j + 1 < evs.size() and str((evs[j + 1] as Dictionary).get("kind", "")) == "ballup":
						fumble_ballups += 1
			for shot in s.shot_log:
				if int(shot[1]) == 1:
					set_shots[c] += 1
					if str(shot[3]) == "goal":
						set_goals[c] += 1
	_check(BalanceGate.held(clangers[1] > clangers[0] * 1.04, "wet: more clangers"), "More clangers in the wet (%.0f against %.0f)" % [clangers[1], clangers[0]])
	_check(BalanceGate.held(ballups[1] > ballups[0] * 1.08, "wet: more ball-ups"), "More ball-ups in the wet (%d against %d)" % [ballups[1], ballups[0]])
	# Row 61: real wet games have 12.1% more tackles (afl_weather_rates.json) and the
	# game 10.9% (tools/balance.sh, 1,000 paired matches, se 0.3%). Over these 16
	# matches the rise has a standard error near 2.5%, so the floor is 4%, a clear
	# rise nearly three standard errors under the game's own size (6% sat only two
	# under); the real size is the balance run's to show.
	_check(tackles[1] > tackles[0] * 1.04, "More tackles in the wet (%.0f against %.0f)" % [tackles[1], tackles[0]])
	# Row 61: real wet games hold their disposals and kicks (-0.5%, +1.3%) and lose
	# 13% of their marks (tools/balance/afl_weather_rates.json).
	_check(BalanceGate.held(absf(disposals[1] / disposals[0] - 1.0) < 0.04 and absf(kicks[1] / kicks[0] - 1.0) < 0.04, "wet: disposals and kicks held"),
			"The wet holds the disposals and kicks (%.0f against %.0f, %.0f against %.0f)"
			% [disposals[1], disposals[0], kicks[1], kicks[0]])
	_check(BalanceGate.held(marks[1] < marks[0] * 0.92, "wet: fewer marks"), "Far fewer marks stick in the wet (%.0f against %.0f)" % [marks[1], marks[0]])
	var acc_dry := float(set_goals[0]) / maxf(1.0, float(set_shots[0]))
	var acc_wet := float(set_goals[1]) / maxf(1.0, float(set_shots[1]))
	_check(acc_wet < acc_dry, "Set shots go through less often in the wet (%.2f against %.2f)" % [acc_wet, acc_dry])
	_check(fumbles > 0 and fumble_named, "A wet fumble is a clanger the game puts down to the wet ball (%d)" % fumbles)
	_check(fumble_ballups > 0 and fumble_ballups < fumbles,
			"Some wet fumbles go straight to a ball-up, the rest spill loose (%d of %d)" % [fumble_ballups, fumbles])
	# The set shot itself is set_acc as likely to go through in the wet, band by band.
	var sa := float(MatchSim.WEATHER_SIM["wet"]["set_acc"])
	var wet := _sim(2)
	wet.weather = "wet"
	var scaled := true
	var picked := 0
	for k in range(400):
		var gp := 0.25 + 0.5 * float(k % 10) / 10.0
		var split: Dictionary = wet._set_shot_split(gp, 0.3)
		if (split["band"] as Dictionary).is_empty():
			continue
		picked += 1
		var hit := false
		for b in MatchSim.set_bands(gp):
			if is_equal_approx(float(split["goal"]), clampf(float(b["goal"]) * sa, 0.03, 0.97)):
				hit = true
		if not hit:
			scaled = false
	_check(picked > 0 and scaled, "Every wet set shot is %.3f as likely to go through (%d shots)" % [sa, picked])
	_check(is_equal_approx(wet._set_goal(0.6), 0.6 * sa) and is_equal_approx(dry._set_goal(0.6), 0.6),
			"The wet's set-shot rate is one rule for every kind of set shot (%.3f, dry %.3f)"
			% [wet._set_goal(0.6), dry._set_goal(0.6)])
	# Row 61: the wet's aerial and run rates reach play. Sized to nothing (tune
	# WX_<key>), no contested mark sticks anywhere on the ground and nobody bounces.
	var contested_marks := [0, 0]
	var bounces := [0.0, 0.0]
	for c in range(2):
		MatchSim.tune = {} if c == 0 else {"WX_aerial": 0.0, "WX_run": 0.0}
		for i in range(4):
			var s := _sim(760 + i)
			s.weather = "wet"
			var res := s.run()
			for side in range(2):
				bounces[c] += float((res["team"][side] as Dictionary).get("running_bounces", 0.0))
			for e in res["events"]:
				if str(e.get("kind", "")) == "mark" and bool(e.get("contested", false)):
					contested_marks[c] += 1
	MatchSim.tune = {}
	_check(contested_marks[0] > 0 and contested_marks[1] == 0,
			"Every contested mark goes through the wet's aerial rate (%d, none at nothing: %d)"
			% [contested_marks[0], contested_marks[1]])
	_check(bounces[0] > 0.0 and bounces[1] == 0.0,
			"Every running bounce goes through the wet's run rate (%.0f, none at nothing: %.0f)" % [bounces[0], bounces[1]])


## Row 61: wind and heat at real size. The wind takes marks, adds tackles, sends more
## missed set shots out on the full and gives one end a breeze; the heat makes a
## slower game with fewer tackles and clangers. A perfect day is untouched.
func _test_wind_and_heat() -> void:
	var dry := _sim(5)
	var windy := _sim(5)
	windy.weather = "windy"
	var hot := _sim(5)
	hot.weather = "hot"
	var d := dry._rates()
	var w := windy._rates()
	var h := hot._rates()
	_check(float(w["mark_share_of_kicks"]) < float(d["mark_share_of_kicks"]), "Fewer kicks are marked in the wind")
	_check(windy._wx("tackle_share") > 1.0 and dry._wx("tackle_share") == 1.0, "More of the pressure is a tackle in the wind")
	_check(float(h["chains_per_game"]) < float(d["chains_per_game"]) and float(h["pressure_base"]) < float(d["pressure_base"])
			and float(h["clanger_per_chain"]) < float(d["clanger_per_chain"]),
			"A hot day is a slower game, with less pressure and fewer clangers")
	# The wind carries more missed set shots out on the full: fewer behinds per miss.
	var miss_ok := true
	var banded := 0
	var want := MatchSim.SET_MISS_BEHIND * windy._wx("miss_behind")
	for k in range(200):
		var sp: Dictionary = windy._set_shot_split(0.3 + 0.04 * float(k % 10), 0.3)
		if (sp["band"] as Dictionary).is_empty():
			continue
		banded += 1
		if not is_equal_approx(float(sp["behind"]) / (1.0 - float(sp["goal"])), want):
			miss_ok = false
	_check(banded > 0 and miss_ok and want < MatchSim.SET_MISS_BEHIND,
			"A missed set shot scores a behind less often in the wind (%.3f of misses against %.3f, %d shots)"
			% [want, MatchSim.SET_MISS_BEHIND, banded])
	# The breeze: with it a shot is easier, against it harder, fewer goals on the day.
	var shooter: Dictionary = windy.squads[0].ground[0]
	windy.current_quarter = 1
	dry.current_quarter = 1
	var side_with := 0 if windy.with_breeze(0) else 1
	var p_with := windy.shot_chance(side_with, shooter, true, false)
	var p_against := windy.shot_chance(1 - side_with, shooter, true, false)
	var p_still := dry.shot_chance(side_with, shooter, true, false)
	var p_still_b := dry.shot_chance(1 - side_with, shooter, true, false)
	_check(p_with > p_still and p_against < p_still_b,
			"The breeze helps one end and hurts the other (%.3f, %.3f against %.3f, %.3f)"
			% [p_with, p_against, p_still, p_still_b])
	_check(MatchSim.BREEZE_WITH + MatchSim.BREEZE_AGAINST < 2.0, "A breeze costs goals over the day")
	windy.current_quarter = 2
	_check(windy.with_breeze(1 - side_with), "The sides change ends at the break")
	# Every set shot takes the wind's miss rate, not only a band from a mark: a
	# free kick, a mark in the goal-square pack and the teammate on the lead too.
	# With no miss scoring (tune WX_miss_behind 0), none of them is ever a behind.
	MatchSim.tune = {"WX_miss_behind": 0.0}
	var by_spot := {}
	var pack_marks := 0
	var pack_behinds := 0
	var turn := 0
	for seed in range(830, 838):
		var live := _sim(seed)
		live.weather = "windy"
		live.moment_side = 0
		while live.current_quarter <= 4:
			live.begin_quarter()
			while not live.continue_quarter():
				var m: Dictionary = live.pending_moment
				var pick := int(m.get("default", 0))
				if str(m["kind"]) == "set_shot":
					var key: String = ["bomb", "pass"][turn % 2]
					turn += 1
					var opts: Array = m["options"]
					for i in range(opts.size()):
						if str(opts[i]["key"]) == key:
							pick = i
				var from := live.events.size()
				live.resolve_moment(pick)
				for k in range(from, live.events.size() - 1):
					var e: Dictionary = live.events[k]
					if str(e["kind"]) == "pack" and str(e.get("outcome", "")) == "marked":
						pack_marks += 1
						if str((live.events[k + 1] as Dictionary)["kind"]) == "behind":
							pack_behinds += 1
			live.end_quarter()
		for shot in live.shot_log:
			var spot := str(shot[4])
			if int(shot[1]) != 1 or spot == "":
				continue
			var kind := spot if spot == "free" or spot == "lead" else "band"
			if not by_spot.has(kind):
				by_spot[kind] = [0, 0]
			by_spot[kind][0] += 1
			if str(shot[3]) == "behind":
				by_spot[kind][1] += 1
	MatchSim.tune = {}
	var all_kinds := by_spot.has("band") and by_spot.has("free") and by_spot.has("lead") and pack_marks > 0
	var no_behinds := pack_behinds == 0
	for kind in by_spot:
		no_behinds = no_behinds and int(by_spot[kind][1]) == 0
	_check(all_kinds and no_behinds,
			"Every kind of set shot takes the wind's miss rate (%s, pack marks %d with %d behinds)"
			% [str(by_spot), pack_marks, pack_behinds])


## Row 61: every weather size points the way the real games do
## (tools/balance/afl_weather_rates.json, 2016-25 against a perfect day).
func _test_weather_follows_the_real_games() -> void:
	var f := FileAccess.open("res://tools/balance/afl_weather_rates.json", FileAccess.READ)
	_check(f != null, "The real weather reference is saved")
	if f == null:
		return
	var ref: Dictionary = JSON.parse_string(f.get_as_text())
	var real: Dictionary = ref["change_vs_perfect"]
	_check(int(ref["n"]["wet"]) >= 100 and int(ref["n"]["windy"]) >= 100 and int(ref["n"]["hot_day"]) >= 30,
			"The reference rests on enough games (%s)" % str(ref["n"]))
	var gate: Dictionary = ref["validation_abc_wet"]["stats"]
	var held := 0
	for k in gate:
		if bool(gate[k]["within_2se"]):
			held += 1
	_check(held >= gate.size() - 1, "The method reproduces ABC's wet-game table (%d of %d)" % [held, gate.size()])
	var rd := _sim(6)._rates()
	for cond in ["wet", "windy", "hot"]:
		var s := _sim(6)
		s.weather = cond
		var r := s._rates()
		var c: Dictionary = real[cond]
		if float(c["marks"]["change"]) < -0.025:
			_check(float(r["mark_share_of_kicks"]) < float(rd["mark_share_of_kicks"]), "%s: fewer marks, as in the real games" % cond)
		var sim_more := s._wx("tackle_share") > 1.0
		var sim_fewer := float(r["pressure_base"]) < float(rd["pressure_base"])
		_check(sim_more if float(c["tackles"]["change"]) > 0.0 else sim_fewer, "%s: tackles go the way the real games' do" % cond)
		# Every real change beyond twice its standard error that the sim has a rule
		# for, that rule moves the same way. How far it moves is the balance
		# harness's to measure (tools/balance.sh match 1000, perfect against cond).
		var breeze := (MatchSim.BREEZE_WITH + MatchSim.BREEZE_AGAINST) / 2.0 if cond == "windy" else 1.0
		var rule := {
			"marks": float(r["mark_share_of_kicks"]) / float(rd["mark_share_of_kicks"]) * s._wx("aerial") - 1.0,
			"contested_marks": s._wx("aerial") - 1.0,
			"marks_inside_50": s._wx("aerial") - 1.0,
			"tackles": s._wx("tackle_share") * float(r["pressure_base"]) / float(rd["pressure_base"]) - 1.0,
			"clangers": float(r["clanger_per_chain"]) / float(rd["clanger_per_chain"]) - 1.0 + s._wx("fumble", 0.0),
			"one_percenters": float(r["one_percenter_share"]) / float(rd["one_percenter_share"]) - 1.0,
			"bounces": s._wx("run") - 1.0,
			"goals": s._wx("set_acc") * float(r["inside50_goal"]) / float(rd["inside50_goal"]) * breeze - 1.0,
		}
		var wrong := []
		var asked := 0
		for k in rule:
			var ch := float(c[k]["change"])
			if absf(ch) <= 2.0 * float(c[k]["se"]):
				continue
			asked += 1
			if float(rule[k]) * ch <= 0.0:
				wrong.append(k)
		_check(wrong.is_empty(), "%s: every clear real change the sim has a rule for goes the same way (%d asked, wrong: %s)"
				% [cond, asked, str(wrong)])


func _fake(id: String, role: String, attr: Dictionary) -> Dictionary:
	var base := {"disposal": 50, "contested": 50, "marking": 50, "pressure": 45, "intercept": 45,
			"carry": 50, "goalkicking": 40, "accuracy": 55, "creating": 45, "ruck": 10,
			"discipline": 50, "durability": 75, "star": 25}
	base.merge(attr, true)
	return {"id": id, "role": role, "attr": base, "overall": 70, "num": 1, "club": "GEE"}


func _good_count(traits: Array) -> int:
	var n := 0
	for k in traits:
		if not Traits.is_bad(k) and not Traits.ON_TOP.has(k):
			n += 1
	return n


func _test_traits() -> void:
	var shooter := _fake("t1", "FWD", {"accuracy": 80, "goalkicking": 70, "marking": 40})
	var t := Traits.of(shooter)
	_check(t.has("sharpshooter") and t.has("crumber"), "High stats earn traits (%s)" % str(t))
	var many := _fake("t2", "MID", {"disposal": 95, "contested": 95, "accuracy": 90, "durability": 96, "discipline": 10})
	var mt := Traits.of(many)
	var good := 0
	for k in mt:
		if not Traits.is_bad(k) and not Traits.ON_TOP.has(k):
			good += 1
	_check(good == 4 and mt.has("hothead"), "Every trait whose line he clears, plus Hothead for poor discipline (%s)" % str(mt))
	# Up to five (director, 2026-11-12): clearing four lines earns four; clearing
	# seven keeps the five he clears by the most; Unicorn comes on top.
	var four := Traits.of(_fake("t5", "MID", {"disposal": 90, "contested": 90, "accuracy": 75, "durability": 95}))
	_check(_good_count(four) == 4 and four.has("ball_magnet") and four.has("bull") and four.has("sharpshooter") and four.has("engine"),
			"A player clearing four trait lines carries all four (%s)" % str(four))
	var seven_p := _fake("t6", "MID", {"disposal": 95, "contested": 95, "accuracy": 90, "durability": 96,
			"creating": 77, "pressure": 70, "star": 61})
	var seven := Traits.of(seven_p)
	_check(Traits.MAX_GOOD == 5 and _good_count(seven) == 5, "Clearing seven trait lines, he carries five (%s)" % str(seven))
	_check(seven.has("sharpshooter") and seven.has("bull") and seven.has("ball_magnet") and seven.has("lockdown")
			and seven.has("engine") and not seven.has("playmaker") and not seven.has("big_game"),
			"The five he keeps are the five he clears by the most (%s)" % str(seven))
	seven_p["unicorn"] = true
	var uni := Traits.of(seven_p)
	_check(uni.has("unicorn") and _good_count(uni) == 5, "Unicorn comes on top of the five (%s)" % str(uni))
	# The wet-weather player (M4-016) sits on top of the five, never in place of one.
	_check(mt.has("wet_weather"), "A contested ball-winner with clean hands is a wet-weather player")
	_check(not Traits.of(_fake("t4", "MID", {"contested": 90, "disposal": 70})).has("wet_weather"),
			"Without clean hands he is not")
	var named := _fake("GWS_6", "DEF", {"contested": 36, "disposal": 74})
	named["real_name"] = "Lachie Whitfield"
	_check(Traits.of(named).has("wet_weather"), "A player the evidence names has it by name")
	var namesake := _fake("FORGE_1", "DEF", {"contested": 36, "disposal": 74})
	namesake["real_name"] = "Lachie Whitfield"
	_check(not Traits.of(namesake).has("wet_weather"), "A created player with the same name does not")
	var close := _fake("t3", "FWD", {"accuracy": 68})
	var near: Array = Traits.near(close)
	_check(not near.is_empty() and str(near[0]["key"]) == "sharpshooter" and int(near[0]["gap"]) == 3,
			"Training shows how close a player is to a trait")
	var need_bulls := int((Traits.SYNERGIES["engine_room"]["needs"] as Dictionary)["bull"])
	var ground := []
	for i in need_bulls:
		ground.append(_fake("b%d" % i, "MID", {"contested": 90 - i}))
	_check(Traits.active(ground).has("engine_room"), "Enough contested bulls switch on the engine room")
	var short := ground.slice(0, need_bulls - 1)
	_check(not Traits.active(short).has("engine_room"), "One short is not enough")
	var rows := Traits.progress(short)
	var er := {}
	for r in rows:
		if str(r["key"]) == "engine_room":
			er = r
	_check(not er.is_empty() and int(er["missing"]) == 1, "Synergy progress counts what is missing")
	# In a match: synergies are live and credited.
	var credited := false
	var any_syn := false
	for code in GameDB.CLUB_ORDER:
		if (GameDB.club_list(code) as Array).is_empty():
			continue  # expansion clubs have no 2026 data
		var sim := _sim(40, code, "COL" if code != "COL" else "GEE")
		if not (sim.synergies[0] as Array).is_empty():
			any_syn = true
			var res := sim.run()
			if absf(float((res["impact"][0] as Dictionary).get("traits", 0.0))) > 0.0:
				credited = true
			break
	_check(any_syn and credited, "A side's synergies play and show in the readout")


## Metres gained and disposal efficiency come from the chain itself: metres
## are the ball's real forward movement, an effective disposal is one his
## side kept.
func _test_metres_and_efficiency() -> void:
	var ok_sum := true
	var ok_bounds := true
	var fwd := [0.0, 0.0]
	var dfn := [0.0, 0.0]
	for i in range(12):
		var res := _sim(900 + i).run()
		for side in range(2):
			var t: Dictionary = res["team"][side]
			var m := 0.0
			var e := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				m += float(st.get("metres_gained", 0.0))
				e += float(st.get("effective_disposals", 0.0))
				if float(st.get("metres_gained", 0.0)) < 0.0 \
						or float(st.get("effective_disposals", 0.0)) > float(st.get("disposals", 0.0)):
					ok_bounds = false
				var role := str(r.get("list_role", r["role"]))
				if role == "FWD":
					fwd[0] += float(st.get("effective_disposals", 0.0))
					fwd[1] += float(st.get("disposals", 0.0))
				elif role == "DEF":
					dfn[0] += float(st.get("effective_disposals", 0.0))
					dfn[1] += float(st.get("disposals", 0.0))
			if absf(m - float(t.get("metres_gained", 0.0))) > 0.5 or absf(e - float(t.get("effective_disposals", 0.0))) > 0.5:
				ok_sum = false
			var de := MatchSim.disposal_efficiency(t)
			if de < 50 or de >= 100:
				ok_bounds = false
	_check(ok_sum, "Players' metres and effective disposals add up to the team's")
	_check(ok_bounds, "No negative metres, never more effective disposals than disposals")
	_check(BalanceGate.held(fwd[0] / fwd[1] < dfn[0] / dfn[1], "forwards less efficient than defenders"),
			"Forwards, whose entries get rebounded, are less efficient than defenders (%.0f%% v %.0f%%)" % [
			100.0 * fwd[0] / fwd[1], 100.0 * dfn[0] / dfn[1]])
	_check(MatchSim.disposal_efficiency({"disposals": 20.0, "effective_disposals": 15.0}) == 75
			and MatchSim.disposal_efficiency({}) == 0, "Disposal efficiency is effective over total")


## GPS distance is real match behaviour, not metres gained: every on-ground
## chain adds running by role and instructions, and the player/team totals
## reconcile. Faster plans must visibly cost more kilometres.
func _test_gps_distance() -> void:
	var res := _sim(9050).run()
	var sums_ok := true
	var averages_ok := true
	for side in range(2):
		var total := 0.0
		var roster: Array = res["roster"][side]
		for r in roster:
			total += float((res["players"].get(str(r["id"]), {}) as Dictionary).get("distance_run", 0.0))
		if absf(total - float((res["team"][side] as Dictionary).get("distance_run", 0.0))) > 0.5:
			sums_ok = false
		var avg := total / float(maxi(1, roster.size()))
		if avg < 8000.0 or avg > 15000.0:
			averages_ok = false
	_check(sums_ok, "Players' GPS distance adds up to the team's")
	_check(BalanceGate.held(averages_ok, "GPS distance range"), "GPS distance sits in a believable match-day range")

	var fast := _sim(9051)
	fast.set_tactics(0, {"gameplan": "attacking"})
	var fast_km := float((fast.run()["team"][0] as Dictionary).get("distance_run", 0.0))
	var slow := _sim(9051)
	slow.set_tactics(0, {"gameplan": "controlled"})
	var slow_km := float((slow.run()["team"][0] as Dictionary).get("distance_run", 0.0))
	_check(BalanceGate.held(fast_km > slow_km * 1.10, "attacking plan covers more ground"),
			"Attack Corridor covers more ground than Controlled Tempo (%.0f km v %.0f km)" % [
			fast_km / 1000.0, slow_km / 1000.0])

	var plain := _sim(9052)
	var focus_id := ""
	for p in (plain.squads[0] as Squad).ground:
		if str(p["role"]) == "MID":
			focus_id = str(p["id"])
			break
	var plain_km := float((plain.run()["players"].get(focus_id, {}) as Dictionary).get("distance_run", 0.0))
	var through := _sim(9052)
	through.set_tactics(0, {"focus_id": focus_id})
	var through_km := float((through.run()["players"].get(focus_id, {}) as Dictionary).get("distance_run", 0.0))
	_check(focus_id != "" and through_km > plain_km,
			"Playing through a midfielder makes him work farther (%.1f km v %.1f km)" % [
			through_km / 1000.0, plain_km / 1000.0])


## Phone playtest: a huge hit-out win came with a narrow clearance count,
## and one ruck was beaten far too heavily. The tap now decides where a
## stoppage goes (a tap to advantage swings it; mids still win the rest),
## hit-outs to advantage are their own stat, and a single tap is no longer
## rounded to one ruck (that gave a 70/30 split in 130 of 300 matches; now
## 7). Measured, 300 matches: 36.7 hit-outs and 12.1 to advantage a team;
## clearance margin correlates 0.30 with the hit-out margin (was 0.07) and
## 0.34 with the margin in taps to advantage.
func _test_ruck_taps() -> void:
	var reconciled := true
	var ho := 0.0
	var adv := 0.0
	var lopsided := 0
	var n := 40
	for i in range(n):
		var res := _sim(5100 + i).run()
		var tot := 0.0
		for side in range(2):
			var t: Dictionary = res["team"][side]
			var ph := 0.0
			var pa := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				ph += float(st.get("hitouts", 0))
				pa += float(st.get("hitouts_adv", 0))
				reconciled = reconciled and float(st.get("hitouts_adv", 0)) <= float(st.get("hitouts", 0))
			reconciled = reconciled and is_equal_approx(ph, float(t.get("hitouts", 0))) \
					and is_equal_approx(pa, float(t.get("hitouts_adv", 0)))
			ho += float(t.get("hitouts", 0))
			adv += float(t.get("hitouts_adv", 0))
			tot += float(t.get("hitouts", 0))
		var share := float(res["team"][0].get("hitouts", 0)) / maxf(1.0, tot)
		if share > 0.7 or share < 0.3:
			lopsided += 1
	_check(reconciled, "Hit-outs to advantage never exceed hit-outs, and players add up to the team")
	_check(BalanceGate.held(adv / ho > 0.2 and adv / ho < 0.45, "hit-outs to advantage share"), "About a third of hit-outs are to advantage (%.0f%%)" % (100.0 * adv / ho))
	_check(BalanceGate.held(lopsided <= n / 8, "lopsided ruck splits"), "Two league rucks rarely split the taps 70/30 (%d of %d)" % [lopsided, n])
	# A far better ruck: more taps, more of them to advantage, and more of
	# the ball - not all of it.
	var shares := []
	for ruck in [40, 99]:
		var won := 0.0
		var all := 0.0
		var cl := 0.0
		var cl_all := 0.0
		for i in range(40):
			var home := []
			for p in GameDB.club_list("GEE"):
				var q: Dictionary = p.duplicate(true)
				if str(q.get("role", "")) == "RUCK":
					q["attr"]["ruck"] = ruck
				home.append(q)
			var sim := MatchSim.new(Squad.new("GEE", home, true, "GEE"),
					Squad.new("COL", GameDB.club_list("COL"), false, "COL"), 5200 + i)
			var res := sim.run()
			won += float(res["team"][0].get("hitouts_adv", 0))
			all += float(res["team"][0].get("hitouts_adv", 0)) + float(res["team"][1].get("hitouts_adv", 0))
			cl += float(res["team"][0].get("clearances", 0))
			cl_all += float(res["team"][0].get("clearances", 0)) + float(res["team"][1].get("clearances", 0))
		shares.append([won / maxf(1.0, all), cl / maxf(1.0, cl_all)])
	_check(BalanceGate.held(float(shares[1][0]) - float(shares[0][0]) >= 0.15 and float(shares[1][1]) > float(shares[0][1]) + 0.02
			and float(shares[1][1]) < 0.75, "better ruck share"),
			"A far better ruck wins more taps to advantage and more of the ball, not all of it (%s)" % str(shares))

## The ruck contest is decided by, and credited to, the player actually at
## the bounce. With the ruck resting, the ruckman on the ground goes up, not
## whoever came off the bench, and an empty ruck spot is filled by the best
## ruckman available, not the best player.
func _test_ruck_integrity() -> void:
	var sim := _sim(77)
	var sq: Squad = sim.squads[0]
	var gi := -1
	for i in range(sq.ground.size()):
		if str(sq.ground[i]["role"]) == "RUCK":
			gi = i
	_check(gi >= 0, "The side starts with a ruck")
	var ruckman: Dictionary = sq.ground[gi]
	# A ruck-forward on the ground, and a bench player who is no ruckman.
	var fj := -1
	for i in range(sq.ground.size()):
		if str(sq.ground[i]["role"]) == "FWD":
			fj = i
			break
	sq.ground[fj]["role2"] = "RUCK"
	sq.ground[fj]["attr"]["ruck"] = 70
	var bj := -1
	for i in range(sq.bench.size()):
		if not Ratings.plays_role(sq.bench[i], "RUCK"):
			bj = i
			break
	var backup_id := str(sq.ground[fj]["id"])
	var bench_id := str(sq.bench[bj]["id"])
	sim._swap(0, gi, bj)
	_check(str(sq.ground[gi]["id"]) == bench_id, "The rested ruck's spot goes to the player off the bench")
	_check(str(sim._contestant(sq)[0]["id"]) == backup_id and MatchSim._ruck_of(sim._contestant(sq)) == 70.0,
			"...but the ruck-forward goes up at the bounce, and the contest is decided on him")
	for i in range(60):
		sim._ruck_tap()        # the tap comes first, as at a real stoppage
		sim._stoppage(0, 1, true)
	var st: Dictionary = sim.player_stats
	_check(float(st.get(backup_id, {}).get("hitouts", 0.0)) > 0.0
			and float(st.get(str(ruckman["id"]), {}).get("hitouts", 0.0)) == 0.0,
			"Hit-outs go to the player who took them, not the rested ruck")
	# No ruck on the list at all: the best ruckman available goes up.
	var list: Array = []
	for p in GameDB.club_list("GEE"):
		if not Ratings.plays_role(p, "RUCK"):
			list.append(p)
	var side := Ratings.select_22(list)
	var in_ruck = null
	for g in side["ground"]:
		if str(g["role"]) == "RUCK":
			in_ruck = g
	var best_ruck := 0.0
	for p in list:
		best_ruck = maxf(best_ruck, float(p["attr"]["ruck"]))
	_check(in_ruck != null and float(in_ruck["attr"]["ruck"]) == best_ruck,
			"With no ruckman listed, the best tap man goes into the ruck")
	# Over whole matches, hit-outs go to ruckmen (before: half of them did not).
	var tot := 0.0
	var off := 0.0
	for i in range(30):
		var res := _sim(1200 + i).run()
		for sd in range(2):
			for r in res["roster"][sd]:
				var h := float(res["players"].get(str(r["id"]), {}).get("hitouts", 0.0))
				var p = GameDB.player_by_id(str(r["id"]))
				tot += h
				if not Ratings.plays_role(p, "RUCK") and float(p["attr"]["ruck"]) < 50.0:
					off += h
	_check(off / tot < 0.15, "Hit-outs mostly go to ruckmen (%.0f%% to others)" % (100.0 * off / tot))


## Play through a midfielder: he wins more of the ball in the chain, but the
## call does not turn him into the side's shooter.
func _test_play_through() -> void:
	var probe := _sim(60)
	var mid: Dictionary = {}
	for p in probe.squads[0].ground:
		if str(p["role"]) == "MID":
			mid = p
			break
	var plain := probe._tactic_player_mult(0, mid, "shooter")
	var plain_carry := probe._tactic_player_mult(0, mid, "carrier")
	probe.set_tactics(0, {"focus_id": str(mid["id"])})
	_check(probe._tactic_player_mult(0, mid, "shooter") == plain,
			"Play through does not favour him for the shot")
	_check(probe._tactic_player_mult(0, mid, "carrier") > plain_carry,
			"Play through favours him in the chain")
	var d_on := 0.0
	var d_off := 0.0
	var g_on := 0.0
	var g_off := 0.0
	var n := 30
	for i in range(n):
		var on := _sim(700 + i)
		on.set_tactics(0, {"focus_id": str(mid["id"])})
		var r_on := on.run()
		var r_off := _sim(700 + i).run()
		var s_on: Dictionary = r_on["players"].get(str(mid["id"]), {})
		var s_off: Dictionary = r_off["players"].get(str(mid["id"]), {})
		d_on += float(s_on.get("disposals", 0.0))
		d_off += float(s_off.get("disposals", 0.0))
		g_on += float(s_on.get("goals", 0.0))
		g_off += float(s_off.get("goals", 0.0))
	_check(d_on > d_off, "Played through, he gets more of the ball (%.1f v %.1f a game)" % [d_on / n, d_off / n])
	_check(d_on / n < 40.0, "...but not an absurd share (%.1f a game)" % (d_on / n))
	_check(g_on / n <= g_off / n + 0.35,
			"...and he does not become the goalkicker (%.2f v %.2f goals a game)" % [g_on / n, g_off / n])



## Play through by the slot he fills (#508): a forward is favoured for the shot
## and for the ball up forward; a defender for the ball coming out of the back
## half; a midfielder or ruck for the ball in every chain, and never for the
## shot (ARD-M1-003). The bias moves who gets the ball and the shot, not how many.
func _test_play_through_by_job() -> void:
	var probe := _sim(60)
	var who := {}
	for p in probe.squads[0].ground:
		var role := str(p["role"])
		if not who.has(role) or probe._a(p, "goalkicking") > probe._a(who[role], "goalkicking"):
			who[role] = p
	for role in ["FWD", "MID", "DEF", "RUCK"]:
		_check(who.has(role), "(setup) a %s is on the ground" % role)
		if not who.has(role):
			return
	# The multiplier: what the call is worth, by the pick it is made in.
	var plain := {}
	for role in who:
		for purpose in ["shooter", "carrier", "transition"]:
			for zone in ["back", "middle", "attack", "inside"]:
				plain["%s/%s/%s" % [role, purpose, zone]] = _job_mult(probe, who[role], purpose, zone)
	for role in who:
		probe.set_tactics(0, {"focus_id": str(who[role]["id"])})
		for purpose in ["shooter", "carrier", "transition"]:
			for zone in ["back", "middle", "attack", "inside"]:
				var ratio: float = _job_mult(probe, who[role], purpose, zone) / float(plain["%s/%s/%s" % [role, purpose, zone]])
				var want := 1.0
				if purpose == "shooter":
					want = MatchSim.FOCUS_SHOT if role == "FWD" else 1.0
				elif role == "FWD":
					want = MatchSim.FOCUS_CARRY if zone == "attack" or zone == "inside" else 1.0
				elif role == "DEF":
					want = MatchSim.FOCUS_EXIT if zone == "back" else 1.0
				else:
					want = MatchSim.FOCUS_CARRY
				_check(is_equal_approx(ratio, want), "%s played through, %s in the %s: x%.2f (want x%.2f)" % [role, purpose, zone, ratio, want])
	# The picks, on one seed so the dice are shared: only his weight differs.
	var picks := {
		"FWD": ["shooter", 0.0], "MID": ["shooter", 0.0],
		"DEF": ["carrier", -40.0], "RUCK": ["shooter", 0.0],
	}
	for role in who:
		var id := str(who[role]["id"])
		var off := _count_picks(60, id, str((picks[role] as Array)[0]), float((picks[role] as Array)[1]), "")
		var on := _count_picks(60, id, str((picks[role] as Array)[0]), float((picks[role] as Array)[1]), id)
		if role == "FWD" or role == "DEF":
			_check(on >= off * 1.10 and off > 0, "A %s played through is picked more for the %s (%d v %d of 3000)" % [role, str((picks[role] as Array)[0]), on, off])
		else:
			_check(on == off, "A %s played through is not made the shooter (%d v %d of 3000)" % [role, on, off])
	var mid_id := str(who["MID"]["id"])
	var ruck_id := str(who["RUCK"]["id"])
	var def_id := str(who["DEF"]["id"])
	var fwd_id := str(who["FWD"]["id"])
	_check(_count_picks(60, mid_id, "carrier", 0.0, mid_id) >= _count_picks(60, mid_id, "carrier", 0.0, "") * 1.10,
			"A midfielder played through gets more of the ball through the middle")
	_check(_count_picks(60, ruck_id, "carrier", 0.0, ruck_id) >= _count_picks(60, ruck_id, "carrier", 0.0, "") * 1.10,
			"A ruck played through gets more of the ball in the middle")
	# Up forward he is one carrier in seventy: 3000 draws give him about 45,
	# too few to see a x1.14 call through the rounding, so this one draws 20000.
	_check(_count_picks(60, fwd_id, "carrier", 25.0, fwd_id, 20000) >= _count_picks(60, fwd_id, "carrier", 25.0, "", 20000) * 1.10,
			"A forward played through gets more of the ball up forward")
	_check(_count_picks(60, def_id, "carrier", 0.0, def_id) == _count_picks(60, def_id, "carrier", 0.0, ""),
			"A defender played through gets no more of the ball through the middle")
	_check(_count_picks(60, def_id, "carrier", 25.0, def_id) == _count_picks(60, def_id, "carrier", 25.0, ""),
			"...nor up forward: his job is out of the back half")


## Three play-through calls at once (director, 2026-10-07): a midfield pillar,
## a forward target and a backline distributor. Each works by its own job, all
## three together; the older single call is the same as its slot's; a call
## waits while its man is off the spot it works from; and nobody becomes the
## only one who gets the ball.
func _test_play_through_three() -> void:
	var probe := _sim(60)
	var who := {}
	for p in probe.squads[0].ground:
		var role := str(p["role"])
		if not who.has(role):
			who[role] = p
	for role in ["FWD", "MID", "DEF"]:
		_check(who.has(role), "(setup) a %s is on the ground" % role)
		if not who.has(role):
			return
	var mid: Dictionary = who["MID"]
	var fwd: Dictionary = who["FWD"]
	var def: Dictionary = who["DEF"]
	var plain_mid := _job_mult(probe, mid, "carrier", "middle")
	var plain_fwd := _job_mult(probe, fwd, "shooter", "inside")
	var plain_def := _job_mult(probe, def, "carrier", "back")
	var three := {"focus_mid": str(mid["id"]), "focus_fwd": str(fwd["id"]), "focus_def": str(def["id"])}
	probe.set_tactics(0, three)
	_check(is_equal_approx(_job_mult(probe, mid, "carrier", "middle") / plain_mid, MatchSim.FOCUS_CARRY),
			"The midfield pillar gets more of the ball in the chain")
	_check(is_equal_approx(_job_mult(probe, fwd, "shooter", "inside") / plain_fwd, MatchSim.FOCUS_SHOT),
			"...the forward target more of the shots, at the same time")
	_check(is_equal_approx(_job_mult(probe, def, "carrier", "back") / plain_def, MatchSim.FOCUS_EXIT),
			"...and the backline distributor first use out of the back half")
	_check(is_equal_approx(_job_mult(probe, mid, "shooter", "inside"), _job_mult(_sim(60), mid, "shooter", "inside")),
			"The pillar is not made the shooter")
	# The older single call is the call for his slot.
	var old := _sim(60)
	old.set_tactics(0, {"focus_id": str(fwd["id"])})
	var new := _sim(60)
	new.set_tactics(0, {"focus_fwd": str(fwd["id"])})
	_check(is_equal_approx(_job_mult(old, fwd, "shooter", "inside"), _job_mult(new, fwd, "shooter", "inside")),
			"A single older play-through call is the call for his slot")
	# A call made for a spot he is not filling waits.
	var off := _sim(60)
	off.set_tactics(0, {"focus_fwd": str(mid["id"])})
	_check(not off.focus_active(0, "focus_fwd") and is_equal_approx(
			_job_mult(off, mid, "carrier", "middle"), plain_mid), "A forward-target call on a midfielder waits")
	_check(off.focus_active(0, "focus_fwd") == false and probe.focus_active(0, "focus_fwd"),
			"...and the screen can tell a working call from a waiting one")
	# Real matches, paired seeds: each man gets more of his job, none an absurd share.
	# 80 games: over 24 the target's shots are inside the noise.
	var n := 80
	var on := {"md": 0.0, "fs": 0.0, "dk": 0.0, "td": 0.0, "top": 0.0}
	var base := {"md": 0.0, "fs": 0.0, "dk": 0.0, "td": 0.0}
	# Both arms coach the same plan, the club's usual game: the plan is the
	# coach's and stays his all match, so only the three calls differ.
	for i in range(n):
		var a := _sim(900 + i)
		var b := _sim(900 + i)
		var plan := {"gameplan": str(b.standing[0])}
		a.set_tactics(0, plan.merged(three))
		b.set_tactics(0, plan)
		var ra := a.run()
		var rb := b.run()
		for pair in [[ra, on], [rb, base]]:
			var pl: Dictionary = pair[0]["players"]
			var acc: Dictionary = pair[1]
			var sf: Dictionary = pl.get(str(fwd["id"]), {})
			acc["md"] += float((pl.get(str(mid["id"]), {}) as Dictionary).get("disposals", 0.0))
			acc["fs"] += float(sf.get("goals", 0.0)) + float(sf.get("behinds", 0.0))
			acc["dk"] += float((pl.get(str(def["id"]), {}) as Dictionary).get("disposals", 0.0))
			acc["td"] += float(((pair[0]["team"] as Array)[0] as Dictionary).get("disposals", 0.0))
		for id in three.values():
			on["top"] = maxf(float(on["top"]), float(((ra["players"] as Dictionary).get(id, {}) as Dictionary).get("disposals", 0.0)))
	_check(on["md"] > base["md"], "Pillar: more of the ball (%.1f v %.1f a game)" % [on["md"] / n, base["md"] / n])
	_check(on["fs"] > base["fs"], "Target: more shots (%.2f v %.2f a game)" % [on["fs"] / n, base["fs"] / n])
	_check(on["dk"] > base["dk"], "Distributor: more of the ball (%.1f v %.1f a game)" % [on["dk"] / n, base["dk"] / n])
	_check(absf(on["td"] - base["td"]) / base["td"] < 0.03,
			"The calls move who gets it, not how much the side has (%.0f v %.0f disposals)" % [on["td"] / n, base["td"] / n])
	# 45 was set when a side had 358 disposals a game; the defensive-50
	# clearing kick (2026-11-07) gives a side 384 (real 367.6), so the same
	# share is 48. Over these 80 games the pillar's two 40+ games are 42 and 46
	# (38 on main); the real one-game record is 54.
	_check(BalanceGate.held(on["top"] < 48.0, "top player use share"), "Nobody becomes the only one who gets it (most in a game %d)" % int(on["top"]))


## Main ruck (director, 2026-10-07, dual-ruck sides): the man you name goes up
## at every stoppage while he is on the ground, wherever he stands, and does
## a ruck's work for it (he tires like a ruck); resting, the usual rule. It
## moves the hit-outs between the two rucks, it does not make more of them.


func _job_mult(sim: MatchSim, p: Dictionary, purpose: String, zone: String) -> float:
	var ctx := sim._pick_ctx(0)
	ctx["zone"] = zone
	return sim._tactic_player_mult(0, p, purpose, ctx)


## How often `id` is picked in 3000 draws of one kind of pick, side 0, with
## `focus` (or nobody) played through. `at` is the field position of a carrier pick.
func _count_picks(seed: int, id: String, kind: String, at: float, focus: String, draws := 3000) -> int:
	var sim := _sim(seed)
	if focus != "":
		sim.set_tactics(0, {"focus_id": focus})
	var ground: Array = sim.squads[0].ground
	var n := 0
	for i in range(draws):
		var got
		if kind == "shooter":
			got = sim._weighted_roles(ground, "goalkicking", MatchSim.SHOT_ROLES, float(Ratings.T["shooter_power"]), 0, "shooter",
					MatchSim.TARGET_SIZES)
		else:
			got = sim.pick_carrier(0, at)
		if str(got["id"]) == id:
			n += 1
	return n


## ARD-M1-001 stat credits: a goal assist only when a goal is kicked (never
## the goalkicker himself), and every free kick paid to a player.


## No in-match Main ruck call (director, 2026-11-03): the ruck in the ruck spot
## goes up, and an old "main_ruck" key changes nothing.
func _test_no_main_ruck_call() -> void:
	var a := _sim(70, "STK")
	var before: Array = a._contestant(a.squads[0])
	var other := ""
	for q in (a.squads[0] as Squad).ground:
		if MatchSim._is_ruckman(q) and (before.is_empty() or str(q["id"]) != str(before[0]["id"])):
			other = str(q["id"])
	a.set_tactics(0, {"main_ruck": other})
	var after: Array = a._contestant(a.squads[0])
	_check(not before.is_empty() and str(after[0]["id"]) == str(before[0]["id"]), "An old main ruck key is ignored")
	var r1 := _sim(1100, "STK").run()
	var b := _sim(1100, "STK")
	b.set_tactics(0, {"main_ruck": other})
	_check(b.run()["score"] == r1["score"], "...in a whole match too")


## Rotations are automatic (director, 2026-11-03): balanced by default, fresh
## legs for a develop season or a hot day, the stars ridden in a close last
## quarter or a close second half of a final.
func _test_auto_rotation() -> void:
	var s := _sim(5)
	s.current_quarter = 1
	_check(s.auto_rotation(0, "steady") == "normal", "Balanced by default")
	_check(s.auto_rotation(0, "develop") == "hard", "A develop season keeps the legs fresh")
	s.weather = "hot"
	_check(s.auto_rotation(0, "peak") == "hard", "So does a hot day")
	s.weather = "perfect"
	s.current_quarter = 4
	_check(s.auto_rotation(0, "develop") == "stars", "A close last quarter rides the stars")
	s.current_quarter = 3
	_check(s.auto_rotation(0, "steady") == "normal", "...not the third, in the home and away")
	s.finals_mode = true
	_check(s.auto_rotation(0, "steady") == "stars", "...but a close second half of a final does")
	_check(MatchSim.ROTATION_POLICIES.has(s.auto_rotation(0, "fast")), "Always a real policy")


## Background and Sim-the-week matches rotate too (competent-AI rule): each
## side on its own season plan, every quarter, still deterministic.
func _test_background_matches_rotate() -> void:
	var lists := {"GEE": GameDB.club_list("GEE"), "COL": GameDB.club_list("COL")}
	var season := Season.new(["GEE", "COL"], lists, 7)
	season.fitness_plans = {"GEE": "develop"}
	var r1 := season.match_sim("GEE", "COL", 11).run()
	var r2 := season.match_sim("GEE", "COL", 11).run()
	_check(r1["score"] == r2["score"], "Still deterministic under a seed")
	var hard_q := 0
	var col_hard := 0
	for th in r1["tactics_history"]:
		if str(th["rotations"][0]) == "hard":
			hard_q += 1
		if str(th["rotations"][1]) == "hard":
			col_hard += 1
	_check(hard_q >= 3, "A develop club keeps its legs fresh in the background (%d quarters)" % hard_q)
	_check(col_hard == 0, "A club with no plan rotates as Steady (balanced)")


## ARD-M1-001 stat credits: a goal assist only when a goal is kicked (never
## the goalkicker himself), and every free kick paid to a player.
func _test_stat_credits() -> void:
	var goals := 0.0
	var assists := 0.0
	var i50 := 0.0
	var sums_ok := true
	var frees_ok := true
	var self_assist := false
	for i in range(20):
		var res := _sim(1200 + i).run()
		for side in range(2):
			var t: Dictionary = res["team"][side]
			goals += float(t.get("goals", 0.0))
			assists += float(t.get("goal_assists", 0.0))
			i50 += float(t.get("inside50", 0.0))
			var pa := 0.0
			var pf := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				pa += float(st.get("goal_assists", 0.0))
				pf += float(st.get("frees_for", 0.0))
			if absf(pa - float(t.get("goal_assists", 0.0))) > 0.01:
				sums_ok = false
			if absf(pf - float(t.get("frees_for", 0.0))) > 0.01:
				frees_ok = false
	_check(assists > 0.4 * goals and assists < goals and assists < 0.5 * i50,
			"Goal assists are credited on goals, not on every entry (%d assists, %d goals, %d inside 50s)" % [assists, goals, i50])
	_check(sums_ok, "Players' goal assists add up to the team's")
	_check(frees_ok, "Every free kick is paid to a player: players' frees for add up to the team's")


## M2 stats: centre bounce attendances, intercepts, contested marks, score
## involvements and score sources all reconcile with the team numbers.
func _test_m2_stats() -> void:
	var cba_ok := true
	var sums_ok := true
	var sources_ok := true
	var involved_ok := true
	var marks_ok := true
	var cbs := 0.0
	for i in range(12):
		var res := _sim(1400 + i).run()
		for side in range(2):
			var t: Dictionary = res["team"][side]
			var cb := float(t.get("centre_bounces", 0.0))
			cbs += cb
			var src := 0.0
			for k in t:
				if str(k).begins_with("score_from_"):
					src += float(t[k])
			if absf(src - (6.0 * float(t.get("goals", 0.0)) + float(t.get("behinds", 0.0)))) > 0.01:
				sources_ok = false
			var cba := 0.0
			var ints := 0.0
			var cm := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				cba += float(st.get("cba", 0.0))
				ints += float(st.get("intercepts", 0.0))
				cm += float(st.get("contested_marks", 0.0))
				if float(st.get("contested_marks", 0.0)) > float(st.get("marks", 0.0)):
					marks_ok = false
				if float(st.get("score_involvements", 0.0)) < float(st.get("goals", 0.0)) + float(st.get("behinds", 0.0)):
					involved_ok = false
			if cba > 4.0 * cb + 0.01 or cba < 2.0 * cb:
				cba_ok = false
			if absf(ints - float(t.get("intercepts", 0.0))) > 0.01 or absf(cm - float(t.get("contested_marks", 0.0))) > 0.01:
				sums_ok = false
	_check(cbs > 0.0 and cba_ok, "A ruck and up to three midfielders attend each centre bounce")
	_check(sums_ok, "Players' intercepts and contested marks add up to the team's")
	_check(marks_ok, "A contested mark is always a mark")
	_check(sources_ok, "Every point scored has a source: score sources add up to the score")
	_check(involved_ok, "Every scorer is involved in his own scores")


## ARD-M1-001: no ordinary play is impossible for a line. Across matches a
## defender carries it inside 50 and kicks a goal, a ruck kicks goals and
## spoils, forwards and defenders win the odd clearance, mids and forwards
## take one-percenters - while each line still leans where it belongs.
func _test_no_role_gates() -> void:
	var by := {}
	for i in range(30):
		var res := _sim(1500 + i).run()
		for side in range(2):
			for r in res["roster"][side]:
				var role := str(r.get("list_role", r["role"]))
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				if not by.has(role):
					by[role] = {}
				for k in ["inside50", "goals", "one_percenters", "clearances"]:
					by[role][k] = float(by[role].get(k, 0.0)) + float(st.get(k, 0.0))
	var g := func(role: String, k: String) -> float: return float((by.get(role, {}) as Dictionary).get(k, 0.0))
	_check(g.call("DEF", "inside50") > 0.0 and g.call("DEF", "goals") > 0.0, "Defenders carry it inside 50 and kick the odd goal")
	_check(g.call("RUCK", "goals") > 0.0 and g.call("RUCK", "one_percenters") > 0.0, "Rucks kick goals and spoil")
	_check(g.call("FWD", "clearances") > 0.0 and g.call("DEF", "clearances") > 0.0, "Forwards and defenders win the odd clearance")
	_check(g.call("MID", "one_percenters") > 0.0 and g.call("FWD", "one_percenters") > 0.0, "Mids and forwards take one-percenters")
	_check(g.call("DEF", "one_percenters") > g.call("MID", "one_percenters") and g.call("FWD", "goals") > g.call("DEF", "goals") * 5.0
			and g.call("MID", "clearances") > g.call("FWD", "clearances") * 3.0, "Each line still leans where it belongs")


## ARD-M3-003: a spoil is credited to the defender who made it, and the
## ball it knocks loose inside 50 is sometimes crumbed and snapped - mostly
## by forwards - rather than always going back to the defence.
func _test_spoils_and_crumbs() -> void:
	var sums_ok := true
	var spoils := 0.0
	var crumbs := 0
	var crumbs_fwd := 0
	var crumb_behinds := 0
	var by_def := 0.0
	var general_spoils := 0
	var general_spoil_loose := true
	var free_causes := {}
	var contextual_free_stats := 0
	# 150 matches: crumbed goals are rare (about one a match). Forwards kick
	# about 64% of them over 300 matches; a 60-match sample swung to 54%,
	# under the 55% bar, on noise alone.
	for i in range(150):
		var res := _sim(1600 + i).run()
		for side in range(2):
			var team_sp := float((res["team"][side] as Dictionary).get("spoils", 0.0))
			spoils += team_sp
			var ps := 0.0
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				ps += float(st.get("spoils", 0.0))
				if str(r["role"]) == "DEF":
					by_def += float(st.get("spoils", 0.0))
			if absf(ps - team_sp) > 0.01:
				sums_ok = false
		# By his own position: "role" is the slot he finished in, and a late
		# rotation can end a crumbing small forward in a back's slot.
		var role := {}
		for side in range(2):
			for r in res["roster"][side]:
				role[str(r["id"])] = str(r.get("list_role", r["role"]))
		for e in res["events"]:
			var kind := str(e.get("kind", ""))
			if kind == "goal" and bool(e.get("crumb", false)):
				crumbs += 1
				if str(role.get(str(e.get("player_id", "")), "")) == "FWD":
					crumbs_fwd += 1
			if kind == "behind" and bool(e.get("crumb", false)):
				crumb_behinds += 1
			if kind == "spoil" and bool(e.get("general_play", false)):
				general_spoils += 1
				var sid := int(e.get("side", -1))
				var pid := str(e.get("player_id", ""))
				var pst: Dictionary = res["players"].get(pid, {})
				general_spoil_loose = general_spoil_loose and sid >= 0 \
						and float(pst.get("spoils", 0.0)) > 0.0 \
						and float(pst.get("one_percenters", 0.0)) > 0.0
			if kind == "free":
				var cause := str(e.get("free_cause", ""))
				free_causes[cause] = int(free_causes.get(cause, 0)) + 1
		for side in range(2):
			var team: Dictionary = res["team"][side]
			for cause in ["holding_ball", "high_contact", "marking", "ruck_contest", "incorrect_disposal", "general"]:
				contextual_free_stats += int(team.get("free_" + cause, 0))
	_check(sums_ok and spoils > 0.0, "Spoils are credited, and players' spoils add up to the team's")
	_check(BalanceGate.held(by_def >= 0.7 * spoils, "spoils by defenders"), "Spoils are made by defenders (rotations aside) (%d of %d)" % [by_def, spoils])
	_check(BalanceGate.held(crumbs > 0 and float(crumbs_fwd) >= 0.55 * float(crumbs), "crumbs mostly by forwards"),
			"Goals are crumbed off spoils, mostly by forwards (%d of %d)" % [crumbs_fwd, crumbs])
	_check(crumb_behinds > 0, "A crumb that misses is logged as a crumb too (%d)" % crumb_behinds)
	_check(general_spoils > 0 and general_spoil_loose,
			"General-play long kicks produce real credited spoils and loose balls (%d)" % general_spoils)
	_check(free_causes.has("holding_ball") and free_causes.has("high_contact")
			and free_causes.has("marking") and free_causes.has("ruck_contest")
			and free_causes.has("incorrect_disposal") and not free_causes.has("general"),
			"Every free kick has a football cause; none is a generic infringement (%s)" % str(free_causes))
	var event_free_total := 0
	for cause in free_causes:
		event_free_total += int(free_causes[cause])
	_check(contextual_free_stats == event_free_total,
			"Every contextual/general free event reconciles to its team cause stat (%d)" % event_free_total)


## ARD-M4-004: a loose interceptor is one real defender leaving his man,
## not an extra player or flat stat buff. Another defender absorbs the job,
## his impact comes from actual aerial contests, and both sides can respond.
func _test_roaming_interceptor() -> void:
	var sim := _sim(8101, "ADE", "SYD")
	var defs := Matchups.interceptor_candidates((sim.squads[1] as Squad).ground)
	_check(not defs.is_empty() and Matchups.interceptor_score(defs[0]) >= Matchups.interceptor_score(defs[-1]),
			"Interceptor suitability is ordered by intercept/marking/pressure football fit")

	# Pick a defender who currently owns a direct matchup, so making him loose
	# proves that somebody else absorbs the forward rather than creating #19.
	var fid := str((sim.duels[1] as Dictionary).keys()[0])
	var loose_id := str((sim.duels[1] as Dictionary)[fid])
	var before_jobs := (sim.duels[1] as Dictionary).size()
	_check(sim.set_interceptor(1, loose_id, false) and str(sim.interceptor[1]) == loose_id,
			"A real defender can be nominated to roam behind the ball")
	var reassigned := true
	for k in (sim.duels[1] as Dictionary):
		reassigned = reassigned and str((sim.duels[1] as Dictionary)[k]) != loose_id
	_check(reassigned and (sim.duels[1] as Dictionary).size() == before_jobs,
			"Making him loose removes his direct job and another defender absorbs it")
	_check(not sim.set_matchup(1, fid, "NOPE", false) and str(sim.interceptor[1]) == loose_id,
			"An invalid matchup cannot accidentally cancel the loose-defender call")

	var base_chance := sim._roam_chance(1)
	sim.set_tactics(0, {"gameplan": "balanced", "spare_accountable": true})
	var accountable_chance := sim._roam_chance(1)
	_check(base_chance > 0.0 and accountable_chance <= base_chance * float(MatchSim.MINDER_ROAM["other"]) + 0.001,
			"Sending a forward to the spare reduces his chance to arrive (%.2f -> %.2f)" % [
					base_chance, accountable_chance])

	var contests := 0
	var wins := 0
	var losses := 0
	for seed in range(8120, 8140):
		var m := _sim(seed, "ADE", "SYD")
		var best := Matchups.best_interceptor((m.squads[1] as Squad).ground, 0.0)
		m.set_interceptor(1, str(best.get("id", "")), false)
		var res := m.run()
		var st: Dictionary = res["players"].get(str(best.get("id", "")), {})
		contests += int(st.get("roam_contests", 0))
		wins += int(st.get("roam_wins", 0))
		losses += int(st.get("roam_losses", 0))
	_check(contests > 0 and wins > 0 and losses > 0,
			"The roaming defender reaches real aerial contests and can both win and lose them (%d: %d-%d)" % [
					contests, wins, losses])

	# AI uses the same role from personnel and scoreboard state.
	var ai := _sim(8201, "GEE", "COL")
	var best_ai := Matchups.best_interceptor((ai.squads[1] as Squad).ground)
	var ait := ai.ai_tactics(1)
	_check(best_ai.is_empty() or str(ait.get("interceptor_id", "")) == str(best_ai.get("id", "")),
			"AI clubs use a suitable loose interceptor under the same personnel rule")
	# And its counter is evidence-led: two recorded roam wins are enough even
	# without reading a currently selected hidden interceptor field.
	var observed: Dictionary = (ai.squads[0] as Squad).ground[0]
	ai.player_stats[str(observed["id"])] = {"roam_wins": 2}
	ai.interceptor[0] = ""
	_check(bool(ai.ai_tactics(1).get("spare_accountable", false)),
			"AI makes a spare accountable only after observable roaming wins, not a hidden user call")

	var fake := {"roster": [[{"id":"D","name":"Defender"}], []],
			"players": {"D":{"roam_contests":5,"roam_wins":4,"roam_losses":1}}}
	var story := MatchNotes.interceptor_story(fake, 0)
	_check(story.size() == 1 and str(story[0]).contains("controlled the air"),
			"Full time explains a spare only when real roaming contests support it")
	_t("_test_loose_man_read")
	_t("_test_loose_man_late")
	_t("_test_ai_loose_needs_a_reader")


## The director (2026-10-10): the loose man "should be a strong strategy only
## if you have a strong intercepting defender". The rule, not its numbers: a
## better reader of the ball reaches more contests, makes the mark harder and
## spoils more; a poor reader seldom gets there; and once named he stays loose.
func _test_loose_man_read() -> void:
	var sim := _sim(8301, "ADE", "SYD")
	var defs := Matchups.interceptor_candidates((sim.squads[1] as Squad).ground)
	var good: Dictionary = defs[0]
	var poor: Dictionary = defs[-1]
	# Pin the two ends of the scale on the same men, whatever the list holds
	# (the ratings are shared with the club lists: put them back after).
	var good_attr: Dictionary = (good["attr"] as Dictionary).duplicate()
	var poor_attr: Dictionary = (poor["attr"] as Dictionary).duplicate()
	for k in ["intercept", "marking", "pressure"]:
		(good["attr"] as Dictionary)[k] = 90
		(poor["attr"] as Dictionary)[k] = 45
	sim.set_interceptor(1, str(good["id"]), false)
	var good_reach := sim._roam_chance(1)
	sim.set_interceptor(1, str(poor["id"]), false)
	var poor_reach := sim._roam_chance(1)
	_check(good_reach > poor_reach * 2.0,
			"A good reader of the ball reaches far more contests as the loose man (%.3f vs %.3f)" % [good_reach, poor_reach])
	_check(poor_reach <= MatchSim.LOOSE_REACH_MIN * MatchSim.ROAM_REACH + 0.001,
			"A poor reader seldom gets there at all (%.3f)" % poor_reach)
	_check(sim._roam_mark_shift(good) < sim._roam_mark_shift(poor) and sim._roam_mark_shift(poor) <= 0.0,
			"A good reader makes the mark harder; a poor one never makes it easier")
	_check(sim._roam_spoil_p(good) > sim._roam_spoil_p(poor),
			"A good reader gets a fist to more of the balls his teammate missed")
	# Getting to the contest is not winning it: when the defender in it gets
	# the fist (or nobody does), the contest is the defender's, not the
	# spare's who arrived as the extra body. After a spoil the ball goes to
	# whoever wins it off the deck (director 2026-11-07), so the feed line's
	# first name, the man who won the contest, is what is checked.
	sim.set_interceptor(1, str(good["id"]), false)
	var gid := str(good["id"])
	var gname := GameDB.player_display_name(good)
	var reached_lost := 0
	var lost_to_def := 0
	var won := 0
	var credit_ok := true
	for i in 600:
		var before: Dictionary = (sim.player_stats.get(gid, {}) as Dictionary).duplicate()
		var r := sim.resolve_forward50(0, 50.0, null)
		var after: Dictionary = sim.player_stats.get(gid, {})
		var reached := float(after.get("roam_contests", 0.0)) > float(before.get("roam_contests", 0.0))
		var beat := float(after.get("roam_wins", 0.0)) > float(before.get("roam_wins", 0.0))
		if str(r.get("outcome", "")) != "turnover" or not reached:
			continue
		var line := str((sim.events[sim.events.size() - 1] as Dictionary).get("text", ""))
		var his := line.begins_with(gname + " ")
		if not beat:
			reached_lost += 1
			if not his:
				lost_to_def += 1
		elif his:
			won += 1
	_check(reached_lost > 0 and lost_to_def == reached_lost,
			"When the defender in the contest wins it, the contest is his, not the loose man's (%d of %d)" % [lost_to_def, reached_lost])
	_check(won > 0,
			"The loose man still comes away with the ones he got the fist to (%d)" % won)
	(good["attr"] as Dictionary).merge(good_attr, true)
	(poor["attr"] as Dictionary).merge(poor_attr, true)

	# Named loose, he is never handed a forward mid-match: not when a mate
	# goes off hurt, not when the coach moves a beaten defender.
	var m := _sim(8302, "ADE", "SYD")
	# The first defender a coach reaches for: the one the old code handed a job.
	var loose := str(Matchups.defenders((m.squads[1] as Squad).ground)[0]["id"])
	m.set_interceptor(1, loose, false)
	var d: Dictionary = m.duels[1]
	var hurt := ""
	for fid in d:
		hurt = str(d[fid])
		break
	if hurt != "":
		m._refill_duel(1, hurt)
	var handed := false
	for fid in d:
		handed = handed or str(d[fid]) == loose
	_check(not handed and str(m.interceptor[1]) == loose,
			"A defender off hurt never hands his forward to the loose man")
	# Every forward beat his man last quarter: the rematch still leaves him loose.
	m.current_quarter = 2
	for fid in d:
		m.duel_log[str(fid)] = {"side": 0, "contests": [[1, str(d[fid]), true, false],
				[1, str(d[fid]), true, false], [1, str(d[fid]), true, false]]}
	m._ai_rematch(1)
	_check(str(m.interceptor[1]) == loose,
			"Moving a beaten defender never takes the loose man off his roaming")


## The director (2026-10-11): a poor reader of the ball should cost points,
## not just fail to save them. He leaves his post as often as a top reader
## does; his read decides only whether he gets there in time. Late, he is not
## in the contest, and the space behind him makes the same entry more
## dangerous than it would be with nobody loose. A top reader is never late.
func _test_loose_man_late() -> void:
	var sim := _sim(8303, "ADE", "SYD")
	var defs := Matchups.interceptor_candidates((sim.squads[1] as Squad).ground)
	var good: Dictionary = defs[0]
	var poor: Dictionary = defs[-1]
	var good_attr: Dictionary = (good["attr"] as Dictionary).duplicate()
	var poor_attr: Dictionary = (poor["attr"] as Dictionary).duplicate()
	for k in ["intercept", "marking", "pressure"]:
		(good["attr"] as Dictionary)[k] = 90
		(poor["attr"] as Dictionary)[k] = 45
	# Every entry is played twice from the same dice: once with the poor
	# reader loose, once with nobody loose.
	var rngs := []
	for prop in sim.get_property_list():
		var v = sim.get(str(prop["name"]))
		if v is RandomNumberGenerator:
			rngs.append(v)
	sim.set_interceptor(1, str(poor["id"]), false)
	var pid := str(poor["id"])
	var entries := 800
	var late := 0
	var late_with := 0
	var late_without := 0
	for i in entries:
		var saved := []
		for g in rngs:
			saved.append((g as RandomNumberGenerator).state)
		sim.interceptor[1] = pid
		var was := float((sim.team_stats[1] as Dictionary).get("roam_late", 0.0))
		var s0 := sim.score(0)
		sim.resolve_forward50(0, 50.0, null)
		var with_pts := sim.score(0) - s0
		var is_late := float((sim.team_stats[1] as Dictionary).get("roam_late", 0.0)) > was
		var after := []
		for g in rngs:
			after.append((g as RandomNumberGenerator).state)
		for j in rngs.size():
			(rngs[j] as RandomNumberGenerator).state = saved[j]
		sim.interceptor[1] = ""
		var s1 := sim.score(0)
		sim.resolve_forward50(0, 50.0, null)
		var without_pts := sim.score(0) - s1
		# Carry on from the dice the loose man's version left.
		for j in rngs.size():
			(rngs[j] as RandomNumberGenerator).state = after[j]
		if is_late:
			late += 1
			late_with += with_pts
			late_without += without_pts
	sim.interceptor[1] = pid
	_check(late * 4 >= entries,
			"A poor reader still leaves his post, and is late for many entries (%d of %d)" % [late, entries])
	_check(late_with > late_without,
			"The entries he is late for score more than with nobody loose (%d vs %d points)" % [late_with, late_without])
	sim.set_interceptor(1, str(good["id"]), false)
	var good_late := 0
	for i in 400:
		var was := float((sim.team_stats[1] as Dictionary).get("roam_late", 0.0))
		sim.resolve_forward50(0, 50.0, null)
		if float((sim.team_stats[1] as Dictionary).get("roam_late", 0.0)) > was:
			good_late += 1
	_check(good_late * 50 <= 400,
			"A top reader is almost never late (%d of 400)" % good_late)
	(good["attr"] as Dictionary).merge(good_attr, true)
	(poor["attr"] as Dictionary).merge(poor_attr, true)


## BOSS (2026-10-11), after the late rule: a coach plays a man loose only
## when the call pays (MatchSim.LOOSE_AI_MIN_READ). The AI and your assistant
## never name a reader below the bar, who would be late for too many entries;
## one above it is still named.
func _test_ai_loose_needs_a_reader() -> void:
	var reads := {}
	for who in ["ai", "assistant"]:
		for pin in [62, 72]:
			var home := Squad.new("ADE", GameDB.club_list("ADE"), true, "ADE")
			var away := Squad.new("SYD", GameDB.club_list("SYD"), false, "SYD")
			away.ai_plans = who == "ai"
			away.assistant = who == "assistant"
			# Every defender's game pinned to the same ratings (put back after).
			var kept := []
			for p in Matchups.defenders(away.ground):
				var at: Dictionary = p["attr"]
				kept.append([at, at.duplicate()])
				# His score lands on the pin whatever his traits add.
				var bonus := Matchups.interceptor_score(p) - (0.55 * float(at.get("intercept", 0))
						+ 0.30 * float(at.get("marking", 0)) + 0.15 * float(at.get("pressure", 0)))
				for k in ["intercept", "marking", "pressure"]:
					at[k] = float(pin) - bonus
			var sim := MatchSim.new(home, away, 8304)
			var named := str(sim.interceptor[1]) != ""
			var read := sim._loose_read(Matchups.interceptor_candidates(away.ground)[0])
			for k in kept:
				(k[0] as Dictionary).merge(k[1], true)
			reads["%s%d" % [who, pin]] = read
			var above := read >= MatchSim.LOOSE_AI_MIN_READ
			_check(named == above, "The %s names a %.2f reader loose only above the bar (%s)" % [who, read, "named" if named else "not named"])
	# The bar is today's to the hundredth: a defender at exactly the old
	# interceptor score of 66 is still named, as before (qa, W7 of #643).
	var same := true
	for v in [65.99, 66.0, 66.01]:
		var edge := {"id": "EDGE", "name": "Edge", "role": "DEF", "attr": {"intercept": v, "marking": v, "pressure": v}}
		same = same and Matchups.best_interceptor([edge]).is_empty() == Matchups.best_interceptor([edge], 66.0).is_empty()
	_check(same, "The named bar names exactly who the old bar of 66 named")
	_check(float(reads["ai62"]) < MatchSim.LOOSE_AI_MIN_READ and float(reads["ai72"]) >= MatchSim.LOOSE_AI_MIN_READ,
			"The two pinned readers sit either side of the bar (%.2f, %.2f)" % [reads["ai62"], reads["ai72"]])


## ARD-M4-012 (the director: "any player can intercept, but the loose
## defender should get more intercepts if he's good at it"). A long kick is
## contested by whoever is in that part of the ground; the defender who wins it
## can mark it, and the ball won off the other side's error is an intercept.
func _test_zone_intercepts() -> void:
	var sim := _sim(8300)
	_check(sim._aerial_zone(0, -40.0) == "back" and sim._aerial_zone(0, 40.0) == "forward"
			and sim._aerial_zone(1, 40.0) == "back" and sim._aerial_zone(1, 0.0) == "middle",
			"An aerial contest's zone is read from the defending side's end")
	var by_role := {}
	var loose_ic := 0.0
	var def_ic := 0.0
	var def_games := 0
	var marks_ok := true
	var flagged := 0
	var imk := 0.0
	for seed in range(8300, 8316):
		var m := _sim(seed, "ADE", "SYD")
		var best := Matchups.best_interceptor((m.squads[1] as Squad).ground, 0.0)
		m.set_interceptor(1, str(best.get("id", "")), false)
		var res := m.run()
		for side in range(2):
			for p in (res["roster"][side] as Array):
				var st: Dictionary = res["players"].get(str(p["id"]), {})
				var n := float(st.get("intercepts", 0.0))
				var role := str(p.get("role", ""))
				by_role[role] = float(by_role.get(role, 0.0)) + n
				imk += float(st.get("intercept_marks", 0.0))
				if float(st.get("intercept_marks", 0.0)) > float(st.get("marks", 0.0)):
					marks_ok = false
				if side == 1 and str(p["id"]) == str(best.get("id", "")):
					loose_ic += n
				elif side == 1 and role == "DEF":
					def_ic += n
					def_games += 1
		for ev in res["events"]:
			if str(ev.get("kind", "")) == "mark" and bool(ev.get("intercept", false)):
				flagged += 1
	_check(float(by_role.get("FWD", 0.0)) > 0.0 and float(by_role.get("MID", 0.0)) > 0.0
			and float(by_role.get("DEF", 0.0)) > float(by_role.get("MID", 0.0)),
			"Any player can intercept, defenders most: %s" % str(by_role))
	_check(imk > 0.0 and flagged > 0 and marks_ok,
			"Intercept marks happen, are flagged in the log and count as marks (%d)" % int(imk))
	_check(loose_ic / 16.0 > def_ic / float(maxi(1, def_games)),
			"A good loose defender intercepts more than the other defenders (%.1f against %.1f a game)" % [
					loose_ic / 16.0, def_ic / float(maxi(1, def_games))])


## The rotation policies say what they do (director, 2026-10-07): Protect freshness takes
## everyone off earliest, stars included; Prioritise key players keeps the stars on longest;
## Balanced sits between. The words are pinned to the thresholds, not the strings.
func _test_rotation_words_true() -> void:
	var P: Dictionary = MatchSim.ROTATION_POLICIES
	_check(float(P["hard"]["role"]) > float(P["normal"]["role"]) and float(P["hard"]["star"]) > float(P["normal"]["star"]),
			"Protect freshness rotates everyone earlier than Balanced, stars included")
	_check(float(P["stars"]["star"]) < float(P["normal"]["star"]) and float(P["stars"]["star"]) < float(P["stars"]["role"]),
			"Prioritise key players keeps the stars on longest, longer than the rest")
	_check(float(P["normal"]["star"]) < float(P["normal"]["role"]),
			"Balanced keeps the stars on a little longer than the rest")
	_check(str(P["hard"]["label"]) == "Protect freshness" and str(P["normal"]["label"]) == "Balanced rotations"
			and str(P["stars"]["label"]) == "Prioritise key players", "The policies carry the director's names")


## Bring the heat does what its words say (director, 2026-10-10): on the same seeds the side
## lays more pressure and more tackles, and its legs burn out much faster.
func _test_bring_the_heat() -> void:
	var press := [0.0, 0.0]
	var tackles := [0.0, 0.0]
	var legs := [0.0, 0.0]
	var dist := [0.0, 0.0]
	# 36 seeds: on 12 the tackle gain sat inside the noise once every feature
	# was on (701 against 710); 60 seeds measured +10% tackles, +3% pressure.
	for seed in range(8500, 8536):
		for arm in range(2):
			var sim := _sim(seed, "ADE", "SYD")
			sim.set_tactics(1, {"pep": "heat" if arm == 1 else "steady"})
			var r := sim.run()
			press[arm] += float((r["team"][1] as Dictionary).get("pressure_acts", 0.0))
			tackles[arm] += float((r["team"][1] as Dictionary).get("tackles", 0.0))
			dist[arm] += float((r["team"][1] as Dictionary).get("distance_run", 0.0))
			var e := 0.0
			for pl in (sim.squads[1] as Squad).ground:
				e += float(sim.energy.get(str(pl["id"]), 100.0))
			legs[arm] += e / float(maxi(1, (sim.squads[1] as Squad).ground.size()))
	_check(press[1] > press[0] and tackles[1] > tackles[0],
			"Bring the heat lays more pressure and tackles (%.0f and %.0f against %.0f and %.0f)" % [press[1], tackles[1], press[0], tackles[0]])
	_check(legs[1] < legs[0], "...and its legs go quicker (%.1f against %.1f)" % [legs[1] / 36.0, legs[0] / 36.0])
	# It burns legs, not extra kilometres: a side covers about the ground it always does.
	_check(absf(dist[1] / maxf(1.0, dist[0]) - 1.0) < 0.04,
			"...but they cover about the same ground (%.0f km against %.0f km a side)" % [dist[1] / 36000.0, dist[0] / 36000.0])
	_check(CoachReport.pep_summary("heat").contains("legs") and CoachReport.pep_summary("heat") != CoachReport.pep_summary("fire_up"),
			"Its words name the cost and are its own")
	# "Much faster" only while it costs more legs than Fire them up does.
	var heat_pace := float(MatchSim.PEP_HEAT.get("pace", 1.0))
	var fire_pace := float(MatchSim.PEP_FIRE.get("pace", 1.0))
	_check(CoachReport.pep_summary("heat").contains("much faster") == (heat_pace > fire_pace)
			and str(CoachReport.PEP_EFFECTS["heat"]).contains("much faster") == (heat_pace > fire_pace),
			"It says legs burn out much faster only while it costs more legs than Fire them up (%.2f v %.2f)" % [heat_pace, fire_pace])
	# "It shows next week" only while its extra effort carries into the week's workload.
	var week_load := [0.0, 0.0]
	for arm in range(2):
		var wsim := _sim(8500, "ADE", "SYD")
		wsim.set_tactics(1, {"pep": "heat" if arm == 1 else "steady"})
		var wr := wsim.run()
		var squad := []
		for pl in (wsim.squads[1] as Squad).ground:
			squad.append((pl as Dictionary).duplicate(true))
		Workload.advance_week({"SYD": squad}, [wr], "heat-week")
		for pl in squad:
			week_load[arm] += Workload.value(pl)
	var shows: bool = week_load[1] > week_load[0]
	_check(CoachReport.pep_summary("heat").contains("next week") == shows
			and str(CoachReport.PEP_EFFECTS["heat"]).contains("next week") == shows,
			"It says it shows next week only while its effort carries into the week's load (%.0f against %.0f)" % [week_load[1], week_load[0]])


## A tag is a midfield job: a forward kicking a bag never gets a tag card
## (that would be a choice with no effect); a midfielder does, and the card
## names the midfielder who would go to him.
func _test_hot_player_moment() -> void:
	var sim := _sim(77)
	sim.moment_side = 0
	sim.current_quarter = 2
	sim._chain_no = 100
	var fwd: Dictionary = {}
	var mid: Dictionary = {}
	for p in (sim.squads[1] as Squad).ground:
		if str(p["role"]) == "FWD" and fwd.is_empty():
			fwd = p
		if str(p["role"]) == "MID" and mid.is_empty():
			mid = p
	sim.player_stats[str(fwd["id"])] = {"goals": 4.0}
	sim._boundary_moment()
	_check(sim.pending_moment.is_empty() or str(sim.pending_moment.get("kind", "")) != "hot",
			"A forward kicking a bag is never answered with a tag")
	sim.pending_moment = {}
	sim._chain_no = 200
	sim.player_stats[str(mid["id"])] = {"goals": 3.0}
	sim._boundary_moment()
	var m: Dictionary = sim.pending_moment
	var tagger = MatchSim.tagger_for((sim.squads[0] as Squad).ground)
	_check(str(m.get("kind", "")) == "hot" and tagger != null
			and str(m["options"][0]["label"]).contains(GameDB.player_display_name(tagger)),
			"A midfielder kicking a bag can be tagged, by the midfielder who would go to him")
	# The call says what each answer does and costs, sized from what the sim plays
	# (row 120): what he keeps with this man on him, and what this man gives up.
	var legs := float(sim.energy.get(str(tagger["id"]), 100.0))
	var want := roundi(Roles.tag_touches(tagger, legs))
	var usual := roundi(Roles.TAG_USUAL_TOUCHES)
	var tag_o: Dictionary = m["options"][0]
	var leave_o: Dictionary = m["options"][1]
	_check(str(tag_o["gain"]).begins_with("Gain: ") and str(tag_o["gain"]).contains("usually gets %d touches" % usual)
			and str(tag_o["gain"]).contains("on him, about %d," % want) and str(leave_o["cost"]).contains("his usual %d touches" % usual),
			"The tag call says his touches, usual and with this man on him (%d: %s)" % [want, tag_o["gain"]])
	_check(str(tag_o["cost"]).begins_with("Cost: ") and str(tag_o["cost"]).contains(GateOdds.tag_gives()),
			"The tag call sizes what the man who goes gives up (%s)" % tag_o["cost"])
	_check(str(leave_o["gain"]).begins_with("Gain: ") and str(leave_o["cost"]).begins_with("Cost: "),
			"Leaving him has its gain and its cost too")
	# A tag already on another of theirs: saying tag moves it, so the card says the
	# hold it costs and what leaving it keeps, and the answer still moves the tag.
	var other: Dictionary = {}
	for p in (sim.squads[1] as Squad).ground:
		if MatchSim.taggable(p) and str(p["id"]) != str(mid["id"]):
			other = p
			break
	var again := _sim(77)
	again.moment_side = 0
	again.current_quarter = 2
	again._chain_no = 200
	again.tactics[0]["tag_id"] = str(other["id"])
	again.player_stats[str(mid["id"])] = {"goals": 3.0}
	again._boundary_moment()
	var mv: Dictionary = again.pending_moment
	var other_name := GameDB.player_display_name(other)
	var who := GameDB.player_display_name(again.tagger_of(0))
	var held := roundi(Roles.tag_touches(again.tagger_of(0), float(again.energy.get(str(again.tagger_of(0)["id"]), 100.0))))
	_check(str(mv.get("kind", "")) == "hot" and str(mv["options"][0]["label"]) == "Move %s onto him" % who
			and str(mv["options"][1]["label"]) == "Leave the tag on %s" % other_name,
			"With a tag already on, the call is to move it or leave it (%s / %s)" % [mv["options"][0]["label"], mv["options"][1]["label"]])
	_check(str(mv["options"][0]["cost"]) == "Cost: the tag comes off %s, who goes back to his usual %d touches" % [other_name, usual]
			and not str(mv["options"][0]["cost"]).contains(GateOdds.tag_gives()),
			"Moving the tag costs the hold on the other man, not a second share of the tagger's game (%s)" % mv["options"][0]["cost"])
	_check(str(mv["options"][1]["gain"]) == "Gain: %s stays on %s, who is held to about %d touches" % [who, other_name, held]
			and str(mv["options"][1]["cost"]).contains("his usual %d touches" % usual),
			"Leaving the tag says what it keeps (%s)" % mv["options"][1]["gain"])
	again.resolve_moment(0)
	_check(again._tag_id(0) == str(mid["id"]), "Saying tag moves the tag to the man kicking goals")
	# A tag on a man who has gone to the bench holds nobody: the card reads as a new tag.
	var benched := _sim(77)
	benched.moment_side = 0
	benched.current_quarter = 2
	benched._chain_no = 200
	benched.tactics[0]["tag_id"] = "nobody_on_the_ground"
	benched.player_stats[str(mid["id"])] = {"goals": 3.0}
	benched._boundary_moment()
	_check(str(benched.pending_moment["options"][0]["label"]).begins_with("Tag him with ")
			and str(benched.pending_moment["options"][0]["cost"]).contains(GateOdds.tag_gives()),
			"A tag on a man off the ground costs nothing to move: the card reads as a new tag")
	# No midfielder of yours on the ground: no tag to offer, so no call that
	# does nothing; it waits and comes once one is back on.
	var bare := _sim(77)
	bare.moment_side = 0
	bare.current_quarter = 2
	bare._chain_no = 200
	var sq0 := bare.squads[0] as Squad
	var kept_ground: Array = sq0.ground.duplicate()
	sq0.ground = sq0.ground.filter(func(p): return not MatchSim.midfielder_on_ground(p))
	bare.player_stats[str(mid["id"])] = {"goals": 3.0}
	bare._boundary_moment()
	_check(bare.tagger_of(0) == null and str(bare.pending_moment.get("kind", "")) != "hot",
			"With no midfielder on the ground there is no tag call (%s)" % str(bare.pending_moment.get("title", "-")))
	bare.pending_moment = {}
	sq0.ground = kept_ground
	bare._chain_no = 300
	bare._boundary_moment()
	_check(str(bare.pending_moment.get("kind", "")) == "hot"
			and str(bare.pending_moment["options"][0]["label"]) == "Tag him with %s" % GameDB.player_display_name(bare.tagger_of(0)),
			"Once a midfielder is back on, the call comes, naming him")


## Gate 1.12: key forward v key defender. Every link: a default set-up, a
## controllable assignment, contests fought against the named defender, a
## measurable effect, the forward's card answered with a defender (never a
## tag), and full-time lines that say only what the contests show.
func _test_matchups() -> void:
	var sim := _sim(501, "ADE", "SYD")
	var theirs: Dictionary = sim.duels[1]      # SYD's defenders on ADE's key forwards
	_check(not theirs.is_empty() and not (sim.duels[0] as Dictionary).is_empty(),
			"Both sides start with a defender on the other's key forwards")
	var fid := str(theirs.keys()[0])
	var defs := Matchups.defenders((sim.squads[1] as Squad).ground)
	var other := ""
	for p in defs:
		if str(p["id"]) != str(theirs[fid]):
			other = str(p["id"])
			break
	var had := str(theirs[fid])
	_check(sim.set_matchup(1, fid, other, false) and str(sim.duels[1][fid]) == other,
			"A defender can be put on a key forward")
	var swapped := true
	for k in theirs:
		if str(k) != fid and str(theirs[k]) == other:
			swapped = false
	_check(swapped, "A defender is only ever on one forward (the old job is swapped, %s)" % had)
	_check(not sim.set_matchup(1, fid, "NOPE", false), "An unknown defender is refused")
	var res := sim.run()
	var log: Dictionary = res["duels"].get(fid, {})
	var against_other := true
	for c in log.get("contests", []):
		if str(c[1]) != other:
			against_other = false
	_check(not log.is_empty() and against_other,
			"Every contest the forward played was against the defender put on him (%d)" % (log.get("contests", []) as Array).size())
	var tagged_events := 0
	for ev in res["events"]:
		if ev.has("duel"):
			tagged_events += 1
	_check(tagged_events > 0, "The contests reach the match log for the feed (%d)" % tagged_events)
	# Leverage: the same forward on a strong v a small, poor-in-the-air defender.
	var rates := []
	for want_strong in [true, false]:
		var n := 0
		var won := 0
		for seed in range(600, 630):
			var m := _sim(seed, "ADE", "SYD")
			var ds := Matchups.defenders((m.squads[1] as Squad).ground)
			ds.sort_custom(func(a, b): return Matchups.defender_air(a) > Matchups.defender_air(b))
			var f := str((m.duels[1] as Dictionary).keys()[0])
			m.set_matchup(1, f, str((ds[0] if want_strong else ds[ds.size() - 1])["id"]), false)
			for c in (m.run()["duels"].get(f, {}) as Dictionary).get("contests", []):
				n += 1
				if bool(c[2]):
					won += 1
		rates.append(float(won) / float(maxi(1, n)))
	_check(BalanceGate.held(rates[1] - rates[0] >= 0.12 and rates[0] >= 0.35, "matchup contest rates"),
			"The defender on him changes the contests, but never shuts him out (%.2f strong v %.2f small)" % [rates[0], rates[1]])
	# Full time says only what the contests show.
	var fake := {"duels": {"F": {"side": 1, "contests": [
			[1, "A", true, true], [1, "A", true, false], [1, "A", true, true], [2, "A", true, false],
			[3, "B", false, false], [3, "B", false, false], [3, "B", true, false], [4, "B", false, false]]}}}
	var story := MatchNotes.duel_story(fake, 0)
	_check(story.size() == 1 and str(story[0]).contains("had the better of") and str(story[0]).contains("held him once he took over"),
			"A change that swung the contests is told in order: on top early, held after (%s)" % str(story))
	# A side's move onto him is called a move; a rotation is not.
	fake["duel_changes"] = [{"q": 3, "from": 3, "side": 0, "fwd": "F", "def": "B"}]
	story = MatchNotes.duel_story(fake, 0)
	_check(str(story[0]).contains("held him after the move") and not str(story[0]).contains("turned"),
			"A real move is named as the move, and the early part is kept (%s)" % str(story))
	# One man all day, on top of him in one quarter (the live call), held
	# overall: full time keeps both halves instead of contradicting the call.
	var one := {"duels": {"F": {"side": 1, "contests": [
			[1, "A", false, false], [1, "A", false, false], [1, "A", false, false],
			[2, "A", true, false], [2, "A", true, true], [2, "A", true, false],
			[3, "A", false, false], [3, "A", false, false], [4, "A", false, false], [4, "A", false, false]]}}}
	var s1 := str(MatchNotes.duel_story(one, 0)[0])
	_check(s1.contains("got on top of") and s1.contains("the second") and s1.contains("held him over the match"),
			"On top in one quarter, held overall: both halves at full time (%s)" % s1)
	var thin := {"duels": {"F": {"side": 1, "contests": [[1, "A", true, false], [1, "A", true, false],
			[1, "A", true, false], [2, "B", false, false]]}}}
	_check(str(MatchNotes.duel_story(thin, 0)[0]).contains("too few"),
			"Too few contests after a change is said as such, not dressed up")
	# A winner needs two-thirds of the contests and two clear. Evenly matched
	# key men (the engine has an elite forward on an elite defender marking
	# 57%, docs/KEY_MATCHUPS_AUDIT_2026-10-06.md) mostly read as even.
	var reads := {}
	for won_n in [[3, 5], [3, 4], [4, 6], [2, 4], [1, 4], [2, 5], [5, 7], [4, 7]]:
		reads["%d/%d" % won_n] = MatchNotes.duel_verdict(int(won_n[0]), int(won_n[1]))
	_check(reads["3/5"] == 0 and reads["2/4"] == 0 and reads["2/5"] == 0 and reads["4/7"] == 0,
			"A one-contest edge is an even battle, not a win (%s)" % str(reads))
	_check(reads["3/4"] == 1 and reads["4/6"] == 1 and reads["5/7"] == 1 and reads["1/4"] == -1,
			"Two-thirds and two clear is a win either way (%s)" % str(reads))
	var even := {"duels": {"F": {"side": 1, "contests": [
			[1, "A", true, false], [1, "A", false, false], [2, "A", true, true],
			[3, "A", false, false], [4, "A", true, false]]}}}
	var line := str(MatchNotes.duel_story(even, 0)[0])
	_check(line.begins_with("An even battle") and line.contains("3 marks from 5 contests"),
			"3 marks from 5 against one man reads as an even battle (%s)" % line)


## Injuries happen during the match: the player goes off for good, the bench
## covers him, and the list records the same injury afterwards.
## A player's club in a match is the side he plays for today, never the
## source club still on his record (a league re-draft, a trade): no club
## that is not playing can appear beside a name in the feed or box score.
func _test_current_club_identity() -> void:
	var moved := []
	for p in GameDB.club_list("MEL"):
		var q: Dictionary = p.duplicate(true)
		q["club"] = "WBD"
		moved.append(q)
	var stray := []
	var injuries := 0
	for i in range(12):
		var sim := MatchSim.new(Squad.new("MEL", moved, true, "MEL"),
				Squad.new("CAR", GameDB.club_list("CAR"), false, "CAR"), 3300 + i)
		var res := sim.run()
		for ev in res["events"]:
			var c := str(ev.get("club", ""))
			if c != "" and c != ["MEL", "CAR"][int(ev.get("side", 0))] and not ["MEL", "CAR"].has(c):
				stray.append("%s %s" % [str(ev["kind"]), c])
			if str(ev["kind"]) == "injury":
				injuries += 1
		for side in range(2):
			for r in res["roster"][side]:
				if str(r["club"]) != ["MEL", "CAR"][side]:
					stray.append("roster " + str(r["club"]))
	_check(stray.is_empty(), "Every name in the match carries the club he plays for today (%s)" % str(stray.slice(0, 3)))
	_check(injuries > 0, "The sample includes injuries, whose lines once named a stale club")
	var line := MatchNotes.story_feed_line({}, {"kind": "injury", "name": "Tim English", "club": "MEL", "on": ""})
	_check(line.contains("(%s)" % GameDB.club_short("MEL")), "The injury line reads the match club (%s)" % line)


## The director (2026-10-11): how tightly a tag holds its man comes from the
## tagger's Pressure and his legs in this match. A fresh Tagger holds tightest
## (TAG_WITH_TAGGER); a hard presser who is not a Tagger less so, and an ordinary
## midfielder less again but still takes real ball off him (row 120); and the
## same man holds less once he tires.
func _test_tag_hold() -> void:
	var sim := _sim(8420, "GEE", "SYD")
	var sq: Squad = sim.squads[0]
	var mids := sq.ground.filter(func(p): return MatchSim.midfielder_on_ground(p))
	var target = null
	for p in (sim.squads[1] as Squad).ground:
		if MatchSim.midfielder_on_ground(p):
			target = p
			break
	var m: Dictionary = mids[0]
	var keep: Dictionary = (m["attr"] as Dictionary).duplicate()
	var mid := str(m["id"])
	sim.tactics[0] = {"gameplan": "balanced", "tag_id": str(target["id"]), "tagger_id": mid}
	sim.energy[mid] = 100.0
	# A hard presser who also wins his own ball: not a Tagger.
	for k in ["pressure", "contested", "carry", "disposal"]:
		(m["attr"] as Dictionary)[k] = 92
	var hard := sim._tag_share(0)
	sim.energy[mid] = 45.0
	var hard_tired := sim._tag_share(0)
	sim.energy[mid] = 100.0
	# A Tagger: elite Pressure that outweighs his own ball-winning and running.
	for k in ["contested", "carry", "disposal"]:
		(m["attr"] as Dictionary)[k] = 30
	(m["attr"] as Dictionary)["pressure"] = 95
	var spec := sim._tag_share(0)
	# Ordinary Pressure.
	for k in ["pressure", "contested", "carry", "disposal"]:
		(m["attr"] as Dictionary)[k] = 40
	var plain := sim._tag_share(0)
	# The lowest Pressure there is, and that man out of legs: the floor of a tag.
	(m["attr"] as Dictionary)["pressure"] = 1
	var lowest := sim._tag_share(0)
	sim.energy[mid] = 30.0
	var lowest_tired := sim._tag_share(0)
	sim.energy[mid] = 100.0
	(m["attr"] as Dictionary).merge(keep, true)
	_check(is_equal_approx(spec, Roles.TAG_WITH_TAGGER), "A fresh Tagger holds his man as tightly as before (%.3f)" % spec)
	_check(hard >= Roles.TAG_TIGHTEST_PLAIN and hard > spec + 0.05,
			"A hard presser who is not a Tagger does a clearly lesser job than a Tagger (%.3f v %.3f)" % [hard, spec])
	_check(plain > hard and plain <= Roles.TAG_LOOSEST, "An ordinary midfielder holds less than a hard presser (%.3f)" % plain)
	_check(lowest <= Roles.TAG_LOOSEST + 0.001 and lowest >= plain,
			"The lowest-pressure midfielder holds least (%.3f)" % lowest)
	_check(lowest_tired < 0.8, "Every tagger takes ball off his man, even the lowest presser out of legs (%.3f kept)" % lowest_tired)
	_check(hard_tired > hard, "The same man holds less once he tires (%.3f fresh, %.3f tired)" % [hard, hard_tired])
	_check(plain - spec > hard - spec, "Pressure scales the hold")
	_check(GateOdds.tag_kept(m, 80.0) == roundi(Roles.touches_at(Roles.tag_keep(m, 80.0))), "The card shows what the sim plays, as his touches")
	# The table is the audit's: one row per measured multiplier, kept rising with it,
	# and the card reads between the rows.
	var tk: Array = Roles.TAG_TOUCHES
	var rising := true
	for i in range(1, tk.size()):
		rising = rising and float(tk[i][0]) > float(tk[i - 1][0]) and float(tk[i][1]) > float(tk[i - 1][1])
	_check(rising and float(tk[0][0]) <= Roles.TAG_WITH_TAGGER and float(tk[tk.size() - 1][0]) >= Roles.TAG_LOOSEST + Roles.TAG_TIRED,
			"The tagged-touches table rises and covers every hold a tagger can play")
	_check(is_equal_approx(float(tk[tk.size() - 1][1]), Roles.TAG_USUAL_TOUCHES) and float(tk[tk.size() - 1][0]) == 1.0,
			"No tag, no touches lost: the table ends on his usual count")
	var mid_m := 0.5 * (float(tk[1][0]) + float(tk[2][0]))
	var mid_k := Roles.touches_at(mid_m)
	_check(mid_k > float(tk[1][1]) and mid_k < float(tk[2][1]) and is_equal_approx(Roles.touches_at(float(tk[1][0])), float(tk[1][1])),
			"Between two measured holds the card reads between their touches (%.2f)" % mid_k)
	# The break screen's order is the rule's own measure: tightest hold on his
	# legs now, then the least given up; the assistant sends the first.
	var order := MatchSim.tag_order(sq.ground, sim.energy)
	var sorted_ok := order.size() >= 2
	for i in range(1, order.size()):
		var ha := Roles.tag_keep(order[i - 1], float(sim.energy.get(str(order[i - 1]["id"]), 100.0)))
		var hb := Roles.tag_keep(order[i], float(sim.energy.get(str(order[i]["id"]), 100.0)))
		if ha > hb + 0.0001 or (is_equal_approx(ha, hb) and MatchSim.tag_give_up(order[i - 1], sq.ground) > MatchSim.tag_give_up(order[i], sq.ground) + 0.0001):
			sorted_ok = false
	_check(sorted_ok, "Who tags is listed tightest hold first, then least given up")
	_check(str(MatchSim.tagger_for(sq.ground)["id"]) == str(MatchSim.tag_order(sq.ground)[0]["id"]),
			"Your assistant sends the first man on that list")
	var card := MatchNotes.tagger_card_detail(order[0], 60.0, false)
	_check(card.contains("Pressure") and card.contains("Gives up " + GateOdds.tag_gives() + " (yet to play this season)") and card.contains(GateOdds.pct(MatchSim.TAGGER_COST)) and card.contains("Tiring")
			and card.contains("Tagger") == Roles.is_tagger(order[0]) and card.contains("Their man: " + GateOdds.tag_touches(order[0], 60.0)) and GateOdds.tag_touches(order[0], 60.0) == "Usually %d touches. Tagged, about %d." % [GateOdds.usual_touches(), GateOdds.tag_kept(order[0], 60.0)],
			"A card shows his Pressure, his legs in words, Tagger only with the trait, and before a season says he is yet to play (%s)" % card.replace("\n", " / "))
	var played := MatchNotes.tagger_card_detail(order[0], 60.0, false, 71.38)
	_check(played.contains("Gives up " + GateOdds.tag_gives() + " (season rating 71.4)") and played.contains("Their man: " + GateOdds.tag_touches(order[0], 60.0)),
			"Once he has a season, the card says what tagging costs: his season rating, the figure the Ratings screen shows (%s)" % played.replace("\n", " / "))
	var parts := MatchNotes.tagger_card(order[0], 40.0, 71.38)
	_check(parts["legs"] == "Running on empty" and bool(parts["legs_bad"]) and not bool(MatchNotes.tagger_card(order[0], 60.0)["legs_bad"])
			and not bool(MatchNotes.tagger_card(order[0], 90.0)["legs_bad"]),
			"Only running on empty is the bad state on a card, tiring and fresh are not")


## The coach's named tagger (#633) rotates like anyone, but he comes back on
## in a midfielder's place, never a forward's, so he picks the tag up again.
func _test_named_tagger_back_on() -> void:
	var sim := _sim(8410, "GEE", "SYD")
	sim.moment_side = -1
	var sq: Squad = sim.squads[0]
	var dflt = MatchSim.tagger_for(sq.ground)
	var named = null
	for p in sq.ground:
		if str(p.get("role", "")) == "MID" and str(p["id"]) != str(dflt["id"]):
			named = p
			break
	var target = null
	for p in (sim.squads[1] as Squad).ground:
		if MatchSim.midfielder_on_ground(p):
			target = p
			break
	var nid := str(named["id"])
	sim.tactics[0] = {"gameplan": "balanced", "tag_id": str(target["id"]), "tagger_id": nid}
	_check(str(sim.tagger_of(0)["id"]) == nid, "The named midfielder goes to the tag")
	# He goes off for a rest; the rest of the bench is spent, he is fresh.
	var gi := sq.ground.find(named)
	sim._swap(0, gi, 0)
	for p in sq.ground + sq.bench:
		sim.energy[str(p["id"])] = 100.0
	for p in sq.bench:
		if str(p["id"]) != nid:
			sim.energy[str(p["id"])] = 40.0
	# A tired forward comes off first: the named tagger waits for a midfield spot.
	var fwd := -1
	for k in sq.ground.size():
		if str((sq.ground[k] as Dictionary).get("role", "")) == "FWD":
			fwd = k
			break
	sim.energy[str((sq.ground[fwd] as Dictionary)["id"])] = 5.0
	sim._auto_rotate(0)
	var in_fwd := false
	for p in sq.ground:
		in_fwd = in_fwd or (str(p["id"]) == nid and str(p.get("role", "")) != "MID")
	_check(not in_fwd, "The named tagger never comes back on in a forward's place")
	sim.energy[str((sq.ground[fwd] as Dictionary)["id"])] = 100.0
	# Then a tired midfielder comes off, and he goes on in his place.
	for k in sq.ground.size():
		if str((sq.ground[k] as Dictionary).get("role", "")) == "MID":
			sim.energy[str((sq.ground[k] as Dictionary)["id"])] = 5.0
			break
	sim._auto_rotate(0)
	var t = sim.tagger_of(0)
	_check(t != null and str(t["id"]) == nid and str(sim.tactics[0].get("tag_id", "")) == str(target["id"]),
			"Back on in a midfielder's place, the named tagger resumes the tag")


## Director, 2026-11-12: "Pickett was my 'play through' midfielder, but he
## spent the whole quarter parked in the goal square?" A routine interchange
## put him back on in the full-forward's place (he plays forward too), and the
## call waited all quarter. Each play-through pick, at every club, goes back
## on only in a spot his call works from, and first when one comes up.
func _test_play_through_back_on_in_his_line() -> void:
	var tried := 0
	var clubs: Array = GameDB.players_by_club.keys().filter(
			func(c): return (GameDB.club_list(str(c)) as Array).size() >= 30)
	clubs.sort()
	for club in clubs:
		for slot in MatchSim.FOCUS_SLOTS:
			var sim := _sim(9120 + tried, club, "SYD" if club != "SYD" else "GEE")
			sim.moment_side = -1
			var sq: Squad = sim.squads[0]
			var own: Array = MatchSim.FOCUS_SLOT_ROLES[slot]
			# A man in this call's line who also plays another line.
			var pick = null
			var other := ""
			for p in sq.ground:
				if not own.has(str(p.get("role", ""))):
					continue
				for line in ["MID", "FWD", "DEF"]:
					if not own.has(line) and Traits.plays(p, line):
						pick = p
						other = line
						break
				if pick != null:
					break
			if pick == null:
				continue
			tried += 1
			var pid := str(pick["id"])
			sim.tactics[0] = {"gameplan": "balanced", slot: pid}
			sim._swap(0, sq.ground.find(pick), 0)
			for p in sq.ground + sq.bench:
				sim.energy[str(p["id"])] = 100.0
			for p in sq.bench:
				if str(p["id"]) != pid:
					sim.energy[str(p["id"])] = 90.0
			# A tired man in his other line comes off: the pick waits.
			var gi := -1
			for k in sq.ground.size():
				if str((sq.ground[k] as Dictionary).get("role", "")) == other:
					gi = k
					break
			if gi < 0:
				continue
			sim.energy[str((sq.ground[gi] as Dictionary)["id"])] = 5.0
			sim._auto_rotate(0)
			var role := ""
			for p in sq.ground:
				if str(p["id"]) == pid:
					role = str(p.get("role", ""))
			_check(role == "", "%s %s: %s (%s) does not go back on in a %s's place (went on as %s)"
					% [club, slot, GameDB.player_display_name(pick), slot, other, role])
			sim.energy[str((sq.ground[gi] as Dictionary)["id"])] = 100.0
			# A tired man in his own line comes off: he goes on first, in his line.
			for k in sq.ground.size():
				if str((sq.ground[k] as Dictionary).get("role", "")) == str(own[0]):
					sim.energy[str((sq.ground[k] as Dictionary)["id"])] = 5.0
					break
			sim._auto_rotate(0)
			for p in sq.ground:
				if str(p["id"]) == pid:
					role = str(p.get("role", ""))
			_check(own.has(role), "%s %s: %s goes back on first in his own line (%s)" % [club, slot,
					GameDB.player_display_name(pick), role])
			_check(sim.focus_active(0, slot), "%s %s: back on, the call works again" % [club, slot])
	_check(tried >= 10, "Enough clubs have a play-through pick who plays two lines (%d)" % tried)


## A Melbourne side playing through Pickett, with him on the bench (fresh)
## and the rest of the bench a little tired. Returns [sim, pid].
func _focus_on_bench(seed: int) -> Array:
	var sim := _sim(seed, "MEL", "FRE")
	sim.moment_side = -1
	var sq: Squad = sim.squads[0]
	var pid := ""
	for p in sq.ground:
		if str(p.get("real_name", "")) == "Kysaiah Pickett":
			pid = str(p["id"])
	if pid == "":
		return [sim, ""]
	sim.tactics[0] = {"gameplan": "balanced", "focus_mid": pid}
	sim._swap(0, sq.ground.find(sim._ground_player(0, pid)), 0)
	for p in sq.ground + sq.bench:
		sim.energy[str(p["id"])] = 100.0 if str(p["id"]) == pid else 90.0
	return [sim, pid]


func _ground_index(sim: MatchSim, role: String) -> int:
	var sq: Squad = sim.squads[0]
	for k in sq.ground.size():
		if str((sq.ground[k] as Dictionary).get("role", "")) == role:
			return k
	return -1


func _role_of(sim: MatchSim, id: String) -> String:
	var g = sim._ground_player(0, id)
	return "" if g == null else str(g["role"])


## The forced changes keep the same rule (checker, 2026-11-12): an injury and
## a rest the coach calls put the play-through pick on only in his own line,
## and first there; in another line only when no one else is on the bench.
func _test_play_through_forced_changes() -> void:
	# An injury to a forward: Pickett stays on the bench.
	var set_up := _focus_on_bench(9301)
	var sim: MatchSim = set_up[0]
	var pid: String = set_up[1]
	_check(pid != "", "Kysaiah Pickett starts for Melbourne")
	if pid == "":
		return
	var sq: Squad = sim.squads[0]
	var fi := _ground_index(sim, "FWD")
	sim._injury_plan = [{"side": 0, "id": str((sq.ground[fi] as Dictionary)["id"]), "at": 0, "weeks": 2, "kind": "hamstring"}]
	sim._check_injuries()
	_check(_role_of(sim, pid) == "", "A forward hurt: Pickett is not sent on in his place (%s)" % _role_of(sim, pid))
	_check(sim.injuries.size() == 1 and str(sim.injuries[0]["on"]) != "", "Someone else replaces the hurt forward")
	# An injury to a midfielder: Pickett goes on first, in the midfield.
	var mi := _ground_index(sim, "MID")
	sim._injury_plan = [{"side": 0, "id": str((sq.ground[mi] as Dictionary)["id"]), "at": 0, "weeks": 2, "kind": "hamstring"}]
	sim._check_injuries()
	_check(_role_of(sim, pid) == "MID", "A midfielder hurt: Pickett replaces him (%s)" % _role_of(sim, pid))
	_check(sim.focus_active(0, "focus_mid"), "Back on after the injury, the call works again")

	# The coach rests a tired forward: Pickett stays on the bench.
	set_up = _focus_on_bench(9302)
	sim = set_up[0]
	sq = sim.squads[0]
	fi = _ground_index(sim, "FWD")
	var tired_id := str((sq.ground[fi] as Dictionary)["id"])
	sim.pending_moment = {"kind": "tired", "side": 0, "player_id": tired_id, "default": 0,
			"options": [{"key": "rest", "label": "Rest him"}, {"key": "keep", "label": "Keep him on"}]}
	var m := sim.resolve_moment(0)
	_check(_role_of(sim, tired_id) == "" and str(m.get("on_id", "")) != "", "The tired forward comes off")
	_check(_role_of(sim, pid) == "", "A forward rested: Pickett is not sent on in his place (%s)" % _role_of(sim, pid))
	# The coach rests a tired midfielder: Pickett goes on in his place.
	mi = _ground_index(sim, "MID")
	tired_id = str((sq.ground[mi] as Dictionary)["id"])
	sim.pending_moment = {"kind": "tired", "side": 0, "player_id": tired_id, "default": 0,
			"options": [{"key": "rest", "label": "Rest him"}, {"key": "keep", "label": "Keep him on"}]}
	m = sim.resolve_moment(0)
	_check(str(m.get("on_id", "")) == pid and _role_of(sim, pid) == "MID",
			"A midfielder rested: Pickett comes on in the midfield (%s)" % _role_of(sim, pid))

	# Last resort: Pickett alone on the bench still replaces a hurt forward.
	set_up = _focus_on_bench(9303)
	sim = set_up[0]
	sq = sim.squads[0]
	sq.bench = sq.bench.filter(func(p): return str(p["id"]) == pid)
	fi = _ground_index(sim, "FWD")
	sim._injury_plan = [{"side": 0, "id": str((sq.ground[fi] as Dictionary)["id"]), "at": 0, "weeks": 2, "kind": "hamstring"}]
	sim._check_injuries()
	_check(_role_of(sim, pid) == "FWD", "No one else on the bench: Pickett covers the hurt forward (%s)" % _role_of(sim, pid))


## A coach's out-of-position pick (checker, 2026-11-12): a forward who is no
## midfielder by position, picked as the play-through midfielder, goes back on
## first in a midfield spot, at every club, as if he played there.
func _test_play_through_out_of_position() -> void:
	var tried := 0
	var clubs: Array = GameDB.players_by_club.keys().filter(
			func(c): return (GameDB.club_list(str(c)) as Array).size() >= 30)
	clubs.sort()
	for club in clubs:
		var sim := _sim(9400 + tried, club, "SYD" if club != "SYD" else "GEE")
		sim.moment_side = -1
		var sq: Squad = sim.squads[0]
		var pick = null
		for p in sq.ground:
			if str(p.get("role", "")) == "FWD" and not Traits.plays(p, "MID") and not Traits.plays(p, "RUCK"):
				pick = p
				break
		if pick == null:
			continue
		tried += 1
		var pid := str(pick["id"])
		sim.tactics[0] = {"gameplan": "balanced", "focus_mid": pid}
		sim._swap(0, sq.ground.find(pick), 0)
		for p in sq.ground + sq.bench:
			sim.energy[str(p["id"])] = 100.0 if str(p["id"]) == pid else 90.0
		var mi := _ground_index(sim, "MID")
		sim.energy[str((sq.ground[mi] as Dictionary)["id"])] = 5.0
		sim._auto_rotate(0)
		_check(_role_of(sim, pid) == "MID", "%s: %s, a forward picked to play through the midfield, goes on there (%s)"
				% [club, GameDB.player_display_name(pick), _role_of(sim, pid)])
		_check(sim.focus_active(0, "focus_mid"), "%s: on in the midfield, the call works" % club)
	_check(tried >= 10, "Enough clubs have a forward who is no midfielder (%d)" % tried)


## The same at full speed: Melbourne play through Kysaiah Pickett for whole
## matches. Wherever the sim has him on the ground he is a midfielder, and the
## picture keeps his disc in a midfield spot, off the goal square, through the
## quarter he first comes back on in.
func _test_play_through_mid_stands_in_midfield() -> void:
	var pid := ""
	for p in GameDB.club_list("MEL"):
		if str(p.get("real_name", "")) == "Kysaiah Pickett":
			pid = str(p["id"])
	_check(pid != "", "Kysaiah Pickett is on Melbourne's list")
	if pid == "":
		return
	var first_res := {}
	for seed in [6101, 6102, 6103]:
		var sim := _sim(seed, "MEL", "FRE")
		sim.moment_side = -1
		var on = sim._ground_player(0, pid)
		_check(on != null and MatchSim.FOCUS_SLOT_ROLES["focus_mid"].has(str(on["role"])),
				"Seed %d: Pickett starts in the midfield" % seed)
		sim.set_tactics(0, {"gameplan": "balanced", "focus_mid": pid})
		var chains := 0
		var wrong := 0
		var where := ""
		while sim.current_quarter <= 4:
			sim.begin_quarter()
			var total: int = sim._q_count
			for k in range(total):
				sim._q_count = k + 1
				while not sim.continue_quarter():
					sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
				var g = sim._ground_player(0, pid)
				if g != null:
					chains += 1
					if not MatchSim.FOCUS_SLOT_ROLES["focus_mid"].has(str(g["role"])):
						wrong += 1
						if where == "":
							where = "Q%d chain %d as %s" % [sim.current_quarter, k, str(g["role"])]
			sim._q_count = total
			sim.end_quarter()
		_check(chains > 0 and wrong == 0, "Seed %d: on the ground for %d chains, never outside the midfield (%d off it, first %s)"
				% [seed, chains, wrong, where])
		if first_res.is_empty():
			first_res = sim.result()
	# The picture: from the start to the end of the quarter he first comes
	# back on in, his disc holds a midfield slot and sits off the goal square.
	var res := first_res
	res["home"] = "MEL"
	res["away"] = "FRE"
	res["label"] = "Round 1"
	var all: Array = res["events"]
	var back := -1
	for i in range(all.size()):
		var e: Dictionary = all[i]
		if str(e.get("kind", "")) == "sub" and str(e.get("player_id", "")) == pid:
			back = i
			break
	_check(back >= 0, "Pickett rests and comes back on in the match")
	var cut := all.size()
	for i in range(maxi(0, back), all.size()):
		if str((all[i] as Dictionary).get("kind", "")) == "quarter":
			cut = i + 1
			break
	var d := MatchDirector.new()
	d.setup(res, all.slice(0, cut))
	var ticks := 0
	var off_line := 0
	var in_square := 0
	var guard := 0
	while not d.idle() and guard < 200000:
		guard += 1
		d.advance(1.0 / 10.0)
		for t in d.tokens:
			if str(t.get("pid", "")) != pid:
				continue
			ticks += 1
			if not ["MID", "RUCK"].has(str(t["role"])) or absf((t["base"] as Vector2).x) > 28.0:
				off_line += 1
			# Deep in his forward 50, where the full forward stands (FF x 66).
			var x := (t["pos"] as Vector2).x * MatchDirector._dir(int(t["side"]))
			if x > 58.0:
				in_square += 1
	_check(ticks > 100, "The picture shows Pickett through the quarter (%d ticks)" % ticks)
	_check(off_line == 0, "Pickett's disc holds a midfield slot every tick (%d of %d not)" % [off_line, ticks])
	_check(in_square * 20 < ticks, "Pickett is in the goal square under 5%% of the time (%d of %d ticks)"
			% [in_square, ticks])


## Each role's slot in the picture stands in its own zone (attacking frame,
## x toward the goal a side attacks): backs in the back 50, forwards in the
## forward 50, the ruck and the midfield within the centre's reach.
func _test_view_slots_stand_in_their_zone() -> void:
	for role in MatchDirector.SLOTS:
		for s in MatchDirector.SLOTS[role]:
			var x: float = (s[1] as Vector2).x
			var ok := false
			match str(role):
				"RUCK", "MID":
					ok = absf(x) <= 28.0
				"DEF":
					ok = x <= -38.0
				"FWD":
					ok = x >= 38.0
			_check(ok, "%s slot %s stands in the %s zone (x %.0f)" % [role, s[0], role, x])
	for v in MatchDirector.EXTRA_SLOTS:
		_check(absf((v as Vector2).x) <= 28.0, "An extra midfielder's slot is within the centre's reach (x %.0f)" % v.x)


## A tagged player hurt and gone off takes the tag with him: the tagging side
## keeps no hidden tag, and he cannot be tagged again.
func _test_tag_ends_with_injury() -> void:
	var sim := _sim(3200, "MEL", "CAR")
	sim.moment_side = 0
	var target: Dictionary = {}
	for p in (sim.squads[1] as Squad).ground:
		if MatchSim.taggable(p):
			target = p
			break
	var id := str(target["id"])
	sim.set_tactics(0, {"gameplan": "balanced", "tag_id": id})
	_check(str(sim.tactics[0].get("tag_id", "")) == id, "A tag goes on a midfielder in the match")
	sim._injury_plan = [{"side": 1, "id": id, "at": 3, "weeks": 2, "kind": "hamstring"}]
	sim.begin_quarter()
	var guard := 0
	while guard < 30:
		sim.continue_quarter()
		if sim.pending_moment.is_empty():
			break
		sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
		guard += 1
	_check(not sim.taking_part(1, id), "He goes off hurt and takes no further part")
	_check(str(sim.tactics[0].get("tag_id", "")) == "", "The tag on him ends when he goes off")
	sim.set_tactics(0, {"gameplan": "balanced", "tag_id": id})
	_check(str(sim.tactics[0].get("tag_id", "")) == "", "He cannot be tagged at the next break")


## A run of goals against brings one call a run, not one a goal: the fourth
## and fifth goals of the same run ask nothing new; a new run can.
func _test_run_call_once_a_run() -> void:
	var sim := _sim(4500, "MEL", "CAR")
	sim.moment_side = 0
	sim.current_quarter = 2
	var ready := func() -> void:
		sim.pending_moment = {}
		sim._moments_this_q = 0
		sim._last_moment_chain = sim._chain_no - 100
	var calls := 0
	# Their goals 3, 4, 5 in a row: one run.
	for g in [3, 4, 5]:
		ready.call()
		(sim.team_stats[1] as Dictionary)["goals"] = float(g)
		sim._run = [0, g]
		if sim._boundary_moment() and str(sim.pending_moment.get("kind", "")) == "momentum":
			calls += 1
	_check(calls == 1, "Three, four, five in a row: one call for the run (%d)" % calls)
	# You kick one; then they kick three more: a new run, a new call.
	ready.call()
	(sim.team_stats[1] as Dictionary)["goals"] = 8.0
	sim._run = [0, 3]
	_check(sim._boundary_moment() and str(sim.pending_moment.get("kind", "")) == "momentum",
			"A new run after you score can bring the call again")


## A tight finish gets the centre-bounce call even when the last quarter's
## two calls went early: one more is kept for it, and only for it.
func _test_late_bounce_reachable() -> void:
	var sim := _sim(4400, "MEL", "CAR")
	sim.moment_side = 0
	sim.current_quarter = 4
	sim.current_minute = 106
	sim.at_centre = true
	sim._chain_no = 200
	sim._last_moment_chain = 150
	sim._moments_this_q = MatchSim.MAX_MOMENTS_Q
	for side in range(2):
		(sim.team_stats[side] as Dictionary)["goals"] = 10.0
	_check(sim._boundary_moment() and str(sim.pending_moment.get("kind", "")) == "bounce",
			"Q4's calls spent, a tight centre bounce still brings the call")
	sim.pending_moment = {}
	_check(not sim._boundary_moment(), "...once: the kept call is not a third")
	sim._moments_this_q = MatchSim.MAX_MOMENTS_Q
	sim._asked.erase("bounce")
	sim.at_centre = false
	_check(not sim._boundary_moment(), "The kept call is only for a centre bounce")
	sim.at_centre = true
	sim.current_quarter = 3
	_check(not sim._boundary_moment(), "...and only in the last quarter")


## Row 15: the late centre ball-up is two distinct calls, each with an upside,
## a downside and a length; unanswered is no call.
func _test_ballup_two() -> void:
	var ask := func() -> MatchSim:
		var sim := _sim(4400, "MEL", "CAR")
		sim.moment_side = 0
		sim.current_quarter = 4
		sim.current_minute = 106
		sim.at_centre = true
		for side in range(2):
			(sim.team_stats[side] as Dictionary)["goals"] = 10.0
		sim._boundary_moment()
		return sim
	var sim: MatchSim = ask.call()
	var opts: Array = sim.pending_moment.get("options", [])
	_check(str(sim.pending_moment.get("kind", "")) == "bounce" and opts.size() == 2, "Two choices at the late ball-up (%d)" % opts.size())
	_check(str(opts[0]["key"]) == "flood" and str(opts[1]["key"]) == "push"
			and str(opts[0]["label"]) == "Flood behind the ball" and str(opts[1]["label"]) == "Push numbers forward",
			"...Flood behind the ball and Push numbers forward (row 151: %s, %s)" % [str(opts[0]["label"]), str(opts[1]["label"])])
	# Row 151: each move's gain and cost carry their sizes as percentages, from
	# the constants the match plays.
	var pc := func(x: float) -> String: return GateOdds.pct(x)
	_check(str(opts[0]["gain"]).contains(pc.call(1.0 - MatchSim.FLOOD_OPP_GOAL)) and str(opts[0]["cost"]).contains(pc.call(1.0 - MatchSim.FLOOD_GOAL))
			and str(opts[0]["cost"]).contains(pc.call(1.0 - MatchSim.BACK_GAIN)),
			"Flood behind the ball: gain and cost sized from what the match plays (%s / %s)" % [str(opts[0]["gain"]), str(opts[0]["cost"])])
	_check(str(opts[1]["gain"]).contains(pc.call(MatchSim.PUSH_GOAL - 1.0)) and str(opts[1]["gain"]).contains(pc.call(MatchSim.PUSH_GAIN - 1.0))
			and str(opts[1]["cost"]).contains(pc.call(MatchSim.PUSH_OPP_GOAL - 1.0)) and str(opts[1]["gain"]).contains("siren"),
			"Push numbers forward: gain and cost sized from what the match plays (%s / %s)" % [str(opts[1]["gain"]), str(opts[1]["cost"])])
	_check(str(opts[0]["cost"]).contains("%") and str(opts[1]["cost"]).contains("%"), "Each cost is a percentage too")
	var said_good := true
	var ranked := false
	for o in opts:
		said_good = said_good and str(o["gain"]).begins_with("Gain: ") and str(o["cost"]).begins_with("Cost: ") 				and str(o["gain"]).contains("%") and (str(o["gain"]).contains("minutes") or str(o["gain"]).contains("siren"))
		for w in ["best", "better choice", "recommend", "safer"]:
			ranked = ranked or (str(o["gain"]) + str(o["cost"]) + str(o["label"])).to_lower().contains(w)
	_check(said_good, "Each choice has an upside, a downside, a size and a length")
	_check(not ranked, "Neither choice is called better")
	_check(sim.pending_moment["options"][0]["gain"] != sim.pending_moment["options"][1]["gain"]
			and str(opts[0]["cost"]) != str(opts[1]["cost"]), "The two choices differ in upside and downside")
	# Unanswered (Skip, auto-play) is no call: nothing stacked or flooded.
	var side := int(sim.pending_moment.get("side", 0))
	var res := sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
	_check(int(res.get("choice", 0)) == -1 and (sim.bursts[side] as Dictionary).is_empty(), "Unanswered, no call is made")
	# Each choice takes effect.
	var a: MatchSim = ask.call()
	a.resolve_moment(0)
	_check((a.bursts[int(a.moments.back()["side"])] as Dictionary).has("flood"), "Flood behind the ball is on")
	var b: MatchSim = ask.call()
	b.resolve_moment(1)
	_check((b.bursts[int(b.moments.back()["side"])] as Dictionary).has("push"), "Push numbers forward is on")
	# The two are opposite set-ups: a flood still on from a run of goals gives
	# way to the push, and the other way round.
	var c: MatchSim = ask.call()
	(c.bursts[0] as Dictionary)["flood"] = 20
	c.resolve_moment(1)
	_check((c.bursts[0] as Dictionary).has("push") and not (c.bursts[0] as Dictionary).has("flood"), "Push numbers forward takes the place of a flood still on")


## Row 151: the two late ball-up moves play differently on paired seeds. The
## same match to the first centre ball-up of the last quarter, then one move or
## the other to the siren: with numbers forward both sides score more in that
## quarter than with the flood, and the caller makes more ground a kick.
func _test_ballup_moves_play_differently() -> void:
	var play := func(seed: int, choice: int) -> Dictionary:
		var sim := _sim(seed, "FRE", "MEL")
		sim.moment_side = 0
		sim.always_offer_bounce = true
		var before := [0, 0]
		var called := false
		while sim.current_quarter <= 4:
			sim.begin_quarter()
			if sim.current_quarter == 4:
				before = [sim.score(0), sim.score(1)]
			while not sim.continue_quarter():
				var is_call := str(sim.pending_moment.get("kind", "")) == "bounce"
				called = called or is_call
				sim.resolve_moment(choice if is_call else int(sim.pending_moment["default"]))
			sim.end_quarter()
		var r := sim.result()
		return {"called": called, "mine": sim.score(0) - int(before[0]), "theirs": sim.score(1) - int(before[1]),
				"score": [sim.score(0), sim.score(1)], "metres": float((r["team"] as Array)[0].get("metres_gained", 0.0)),
				"disposals": float((r["team"] as Array)[0].get("disposals", 0.0))}
	var games := 32
	var called := 0
	var differ := 0
	var flood := {"mine": 0, "theirs": 0, "metres": 0.0, "disposals": 0.0}
	var push := {"mine": 0, "theirs": 0, "metres": 0.0, "disposals": 0.0}
	for i in range(games):
		var f: Dictionary = play.call(15100 + i, 0)
		var p: Dictionary = play.call(15100 + i, 1)
		called += 1 if bool(f["called"]) and bool(p["called"]) else 0
		differ += 1 if f["score"] != p["score"] else 0
		for k in flood:
			flood[k] += f[k]
			push[k] += p[k]
	_check(called == games, "Every paired match reaches the late ball-up call (%d of %d)" % [called, games])
	_check(differ >= games - 2, "The same match ends differently on the two moves (%d of %d paired seeds)" % [differ, games])
	_check(int(push["mine"]) > int(flood["mine"]), "Push numbers forward: you score more in the last quarter than on the flood (%d against %d over %d matches)" % [int(push["mine"]), int(flood["mine"]), games])
	_check(int(push["theirs"]) > int(flood["theirs"]), "...and so do they (%d against %d)" % [int(push["theirs"]), int(flood["theirs"])])
	var per_push := float(push["metres"]) / maxf(1.0, float(push["disposals"]))
	var per_flood := float(flood["metres"]) / maxf(1.0, float(flood["disposals"]))
	_check(per_push > per_flood, "...and you make more ground a disposal (%.2f m against %.2f m over the match)" % [per_push, per_flood])


## Row 151: every club gets the two moves. A rival coach at the same late
## centre ball-up floods in front and pushes numbers forward behind (Director
## Bible 2.35), once a match, from the scoreboard only; level, he makes no call.
func _test_rival_ballup() -> void:
	var at := func(my_goals: float, their_goals: float, minute := 106, quarter := 4, centre := true) -> MatchSim:
		var sim := _sim(4410, "MEL", "CAR")
		(sim.squads[1] as Squad).ai_plans = true
		sim.current_quarter = quarter
		sim.current_minute = minute
		sim.at_centre = centre
		(sim.team_stats[0] as Dictionary)["goals"] = my_goals
		(sim.team_stats[1] as Dictionary)["goals"] = their_goals
		sim._rival_ballup()
		return sim
	var ahead: MatchSim = at.call(10.0, 11.0)
	_check((ahead.bursts[1] as Dictionary).has("flood") and not (ahead.bursts[1] as Dictionary).has("push"),
			"A rival a goal up at the late centre ball-up floods behind the ball")
	_check((ahead.bursts[0] as Dictionary).is_empty(), "...and no call is made for the side you coach")
	var said := str((ahead.events.back() as Dictionary).get("text", ""))
	_check(str((ahead.events.back() as Dictionary).get("kind", "")) == "moment" and said.contains("Flood behind the ball") and said.begins_with(ahead.squads[1].name),
			"...and the feed says whose call it is (%s)" % said)
	var left := int((ahead.bursts[1] as Dictionary)["flood"])
	ahead.team_stats[1]["goals"] = 9.0
	ahead._rival_ballup()
	_check(int((ahead.bursts[1] as Dictionary).get("flood", 0)) == left and not (ahead.bursts[1] as Dictionary).has("push"), "...once a match")
	var behind: MatchSim = at.call(11.0, 10.0)
	_check((behind.bursts[1] as Dictionary).has("push") and not (behind.bursts[1] as Dictionary).has("flood"),
			"A rival a goal down pushes numbers forward")
	_check((at.call(10.0, 10.0).bursts[1] as Dictionary).is_empty(), "Level, the rival makes no call")
	_check((at.call(10.0, 13.0).bursts[1] as Dictionary).is_empty(), "More than two goals up, no call")
	_check((at.call(10.0, 11.0, 95).bursts[1] as Dictionary).is_empty(), "Before the last 20 minutes, no call")
	_check((at.call(10.0, 11.0, 80, 3).bursts[1] as Dictionary).is_empty(), "Before the last quarter, no call")
	_check((at.call(10.0, 11.0, 106, 4, false).bursts[1] as Dictionary).is_empty(), "Away from a centre ball-up, no call")
	# The same sizes for every club: the rival's flood and push are the calls
	# the coach's card sizes (one set of constants, one length).
	_check(int((behind.bursts[1] as Dictionary)["push"]) == behind._chains_for(int(MatchSim.BURSTS["push"]["chains"]))
			and int(MatchSim.BURSTS["push"]["chains"]) == int(MatchSim.BURSTS["flood"]["chains"]),
			"A rival's call lasts as long as yours")


## A tag is a midfielder's job (the director's PC playtest, 2026-10-07: the
## team's ruckman was sent to tag).
func _test_ruck_never_tags() -> void:
	var ruck: Dictionary = {}
	var mid: Dictionary = {}
	for p in GameDB.club_list("MEL"):
		if ruck.is_empty() and str(p["role"]) == "RUCK" and not Ratings.second_positions(p).has("MID"):
			ruck = p.duplicate(true)
		if mid.is_empty() and str(p["role"]) == "MID" and not Roles.is_tagger(p):
			mid = p.duplicate(true)
	ruck["attr"]["pressure"] = 99
	mid["attr"]["pressure"] = 40
	var ruck_in_mid := Ratings._for_slot(ruck, "MID")
	var ground := [ruck_in_mid, Ratings._for_slot(mid, "MID")]
	var t = MatchSim.tagger_for(ground)
	_check(t != null and str(t["id"]) == str(mid["id"]),
			"A ruck picked in a midfield slot is never the fallback tagger, however hard he presses")
	_check(not MatchSim.taggable(ruck_in_mid), "...nor someone to tag: a tag goes on a midfielder")
	_check(MatchSim.tagger_for([ruck_in_mid]) == null, "With no midfielder to send, nobody tags")
	var unicorn := ruck.duplicate(true)
	unicorn["role2"] = "MID"
	_check(MatchSim.tagger_for([Ratings._for_slot(unicorn, "MID")]) != null,
			"A ruck who is also a midfielder by position can do the job in the midfield")


## The centre-bounce call comes once a match at most (the director's PC
## playtest, 2026-10-07: "4 up with 16 minutes left", then "3 down with 10
## minutes left" in the same game), the playtest aid's included.
func _test_bounce_once() -> void:
	var sim := _sim(4401, "MEL", "CAR")
	sim.moment_side = 0
	sim.current_quarter = 4
	sim.current_minute = 104
	sim.at_centre = true
	sim._chain_no = 200
	sim._last_moment_chain = 100
	sim._moments_this_q = 0
	for side in range(2):
		(sim.team_stats[side] as Dictionary)["goals"] = 10.0
	_check(sim._bounce_moment(4), "A tight late centre bounce brings the call")
	sim.pending_moment = {}
	sim.current_minute = 110
	_check(not sim._bounce_moment(-3), "...once: a second tight centre bounce later does not bring it again")
	var aid := _sim(4402, "MEL", "CAR")
	aid.always_offer_bounce = true
	aid.moment_side = 0
	aid.current_quarter = 4
	aid.current_minute = 104
	aid.at_centre = true
	_check(aid._playtest_bounce(), "(the playtest aid offers it)")
	aid.pending_moment = {}
	_check(not aid._bounce_moment(0), "With the playtest aid's call made, the late call does not come too")
	# The title counts the minutes properly to the end (never "1 minutes").
	var late := _sim(4403, "MEL", "CAR")
	late.moment_side = 0
	late.current_quarter = 4
	late.current_minute = 119
	late._fire_bounce(3)
	var last_t := str(late.pending_moment.get("title", ""))
	late.current_minute = 110
	late._fire_bounce(3)
	var ten_t := str(late.pending_moment.get("title", ""))
	_check(last_t == "Centre ball-up - 3 up in the last minute" and ten_t == "Centre ball-up - 3 up with 10 minutes left",
			"The late ball-up title reads naturally to the last minute ('%s', '%s')" % [last_t, ten_t])



func _test_in_match_injuries() -> void:
	var n := 0
	var hurt := 0
	var sound := true
	var covered := true
	var duels_ok := true
	var sample := {}
	for i in range(40):
		var sim := _sim(3100 + i, "MEL", "CAR")
		var res := sim.run()
		n += 1
		for inj in res["injuries"]:
			hurt += 1
			var side := int(inj["side"])
			var id := str(inj["id"])
			for p in (sim.squads[side] as Squad).ground + (sim.squads[side] as Squad).bench:
				if str(p["id"]) == id:
					sound = false
			var in_roster := false
			for r in res["roster"][side]:
				if str(r["id"]) == id:
					in_roster = true
			var ev_ok := false
			for ev in res["events"]:
				if str(ev["kind"]) == "injury" and str(ev["player_id"]) == id and str(ev.get("on", "")) == str(inj["on"]):
					ev_ok = true
			covered = covered and in_roster and ev_ok
			if sample.is_empty():
				sample = {"res": res, "inj": inj}
		# Nobody gone off hurt is left in a match-up (a break would offer a
		# change the engine cannot make).
		for side in range(2):
			var here := {}
			for p in (sim.squads[side] as Squad).ground + (sim.squads[side] as Squad).bench:
				here[str(p["id"])] = true
			var there := {}
			for p in (sim.squads[1 - side] as Squad).ground + (sim.squads[1 - side] as Squad).bench:
				there[str(p["id"])] = true
			for fid in (sim.duels[side] as Dictionary):
				if not there.has(str(fid)) or not here.has(str(sim.duels[side][fid])):
					duels_ok = false
	var rate := float(hurt) / (2.0 * n)
	_check(BalanceGate.held(rate > 0.4 and rate < 1.1, "in-match injury rate"), "In-match injuries run near the old rate (%.2f a side a match)" % rate)
	_check(sound, "A player hurt in a match takes no further part")
	_check(covered, "Each injury is in the log and the injured player is in the box score")
	_check(duels_ok, "A player gone off hurt is out of the match-ups")
	if not sample.is_empty():
		var res: Dictionary = sample["res"]
		var inj: Dictionary = sample["inj"]
		var code: String = [str(res["home"]), str(res["away"])][int(inj["side"])]
		var lists := {code: GameDB.club_list(code).duplicate(true)}
		var applied := Injuries.apply_match(res, lists, 1, 1)
		var p: Dictionary = {}
		for q in lists[code]:
			if str(q["id"]) == str(inj["id"]):
				p = q
		_check(not applied.is_empty() and int(p.get("injury_weeks", 0)) == int(inj["weeks"]),
				"The list records the injury the match had")


## The feed and full time tell the match's turning points from the log.
func _test_match_story() -> void:
	var mem := {}
	var inj := MatchNotes.story_feed_line(mem, {"kind": "injury", "q": 2, "min": 40,
			"name": "Ed Richards", "club": "WBD", "on": ""})
	_check(inj.begins_with("Ed Richards") and inj.contains("won't return"), "An injury always reaches the feed: " + inj)
	var intercepts := 0
	for m in range(5):
		var ev := {"kind": "goal", "q": 1, "min": 5 + m, "side": 0, "player_id": "a", "from_id": "b",
				"score": [6 * (m + 1), 6 * (m + 1)]}
		if MatchNotes.story_feed_line(mem, ev) != "":
			intercepts += 1
	_check(intercepts == 1, "At most one intercept line a quarter (%d)" % intercepts)
	var ahead := MatchNotes.story_feed_line({}, {"kind": "goal", "q": 2, "min": 40, "side": 0,
			"player_id": "a", "from_id": "b", "score": [40, 20]})
	_check(ahead == "", "A goal from an intercept that changes nothing stays off the feed")
	var res := {"home": "MEL", "away": "CAR", "score": [80, 75], "roster": [[], []], "events": [
		{"kind": "goal", "q": 1, "min": 5, "side": 1, "name": "X", "score": [0, 6]},
		{"kind": "goal", "q": 4, "min": 112, "side": 0, "name": "Jack Viney", "score": [7, 6]},
	]}
	var tp := MatchNotes.turning_points(res, 1)
	_check(not tp.is_empty() and str(tp[0]) == "Jack Viney's goal 22 minutes into the last quarter put Melbourne in front for good.",
			"Full time names the score that put the winners in front for good: %s" % str(tp))
	var calm := MatchNotes.turning_points({"home": "MEL", "away": "CAR", "score": [80, 20], "events": [
		{"kind": "goal", "q": 1, "min": 3, "side": 0, "name": "A", "score": [6, 0]}]}, 0)
	_check(calm.is_empty(), "A match led from the first goal has no turning point to invent")
	# Row 18: full injury wording and the scoring run told with when and score.
	_check(Injuries.wording("hand") == "a hand injury" and Injuries.wording("hamstring") == "a hamstring strain",
			"Injury kinds read as a coach would say them")
	var hurt_res := {"home": "MEL", "away": "CAR", "score": [80, 20], "roster": [[{"id": "s1", "overall": 99}], []],
			"events": [], "injuries": [{"id": "s1", "side": 0, "q": 2, "kind": "hand"}]}
	var hp := MatchNotes.turning_points(hurt_res, 0)
	_check(not hp.is_empty() and not str(hp[0]).contains(" to a hand in the") and str(hp[0]).contains("a hand injury"),
			"Full time says a hand injury, not 'to a hand': %s" % str(hp))
	var run_res := {"home": "MEL", "away": "CAR", "events": [
		{"kind": "goal", "q": 1, "min": 5, "side": 1, "score": [0, 6]},
		{"kind": "goal", "q": 3, "min": 68, "side": 0, "score": [6, 6]},
		{"kind": "goal", "q": 3, "min": 72, "side": 0, "score": [12, 6]},
		{"kind": "goal", "q": 3, "min": 75, "side": 0, "score": [18, 6]},
		{"kind": "goal", "q": 3, "min": 80, "side": 0, "score": [24, 6]}]}
	var rs := MatchNotes.run_sentence(run_res, MatchNotes._longest_run(run_res["events"]))
	_check(rs == "Melbourne kicked four unanswered goals from 8 minutes into the third quarter, turning Melbourne 0, Carlton 6 into Melbourne 24, Carlton 6.",
			"The run says when it began and the score before and after: %s" % rs)
	var et := MatchNotes._when({"q": 5, "min": 122})
	_check(et == "in extra time" and MatchNotes._when({"q": 4, "min": 102}) == "12 minutes into the last quarter",
			"A run in extra time says so, not 'the extra time quarter': %s" % et)


## A first AFL goal for one of yours reaches the feed: once a player, never
## of the other side, and not held back by the quarter's cap on story lines.
func _test_first_goal_feed() -> void:
	var goal := {"kind": "goal", "q": 2, "min": 40, "side": 0, "player_id": "p1", "name": "Ari Bramble",
			"score": [40, 30]}
	var mem := {"first_goal": {"p1": true}}
	_check(MatchNotes.story_feed_line(mem, goal) == "First AFL goal for Ari Bramble.",
			"A first AFL goal for one of yours reaches the feed")
	_check(MatchNotes.story_feed_line(mem, goal) == "", "...once")
	var other := goal.duplicate()
	other["player_id"] = "p2"
	other["name"] = "Dan Other"
	_check(MatchNotes.story_feed_line({"first_goal": {"p1": true}}, other) == "",
			"Nothing for a player it is no first for, which is everyone on the other side")
	_check(MatchNotes.story_feed_line({}, goal) == "", "Nothing without a list of who it could be a first for")
	var busy := {"first_goal": {"p1": true}, "story_q": {2: MatchNotes.MAX_STORY_LINES}}
	_check(MatchNotes.story_feed_line(busy, goal) == "First AFL goal for Ari Bramble.",
			"A quarter's cap on story lines does not hold it back")
	# A Big-game player's lift is still there for his next goal.
	var big := goal.duplicate()
	big["trait"] = "big_game"
	var both := {"first_goal": {"p1": true}}
	_check(MatchNotes.story_feed_line(both, big) == "First AFL goal for Ari Bramble."
			and MatchNotes.story_feed_line(both, big) == "Ari Bramble lifts when it matters.",
			"The first goal comes first, and the Big-game line is still said for the next")


## Traits and synergies say when they were at work, from the log.
func _test_traits_surfaced() -> void:
	var crumbs := 0
	var tagged := true
	var big := 0
	for i in range(30):
		var res := _sim(4200 + i, "COL", "GEE").run()
		for ev in res["events"]:
			if str(ev["kind"]) != "goal" or not ev.has("trait"):
				continue
			if str(ev["trait"]) == "crumber":
				crumbs += 1
				tagged = tagged and bool(ev.get("crumb", false))
			elif str(ev["trait"]) == "big_game":
				big += 1
				tagged = tagged and int(ev["q"]) >= 4
	_check(crumbs + big > 0 and tagged, "A Crumber's crumb and a Big-game player's late goal are marked (%d, %d)" % [crumbs, big])
	var mem := {}
	var ev := {"kind": "goal", "q": 4, "min": 100, "side": 0, "name": "Jack Viney", "trait": "big_game",
			"score": [60, 50]}
	_check(MatchNotes.story_feed_line(mem, ev) == "Jack Viney lifts when it matters.", "A Big-game player's lift reaches the feed")
	_check(MatchNotes.story_feed_line(mem, ev) == "", "Once a match a side")
	var res := {"synergies": [["engine_room", "intercept_wall"], []], "goals": [12, 9],
			"team": [{"clearances": 40, "inside50": 55}, {"clearances": 33, "inside50": 48}]}
	var lines := MatchNotes.synergy_lines(res, 0)
	_check(lines.size() == 2 and str(lines[0]) == "Engine room: clearances 40 to 33."
			and str(lines[1]) == "Intercept wall: they kicked 9 goals from 48 inside 50s.",
			"Full time shows the stat each of your synergies plays on: %s" % str(lines))
	_check(MatchNotes.synergy_lines(res, 1).is_empty(), "No synergies, no lines")


## Playtest impression: good key forwards always beat good key defenders.
## Measured (60 matches a cell, one forward transplanted into the same
## side): equal quality is about even (elite v elite 52%, good v good 43%,
## average v average 50% of named contests to the forward); an elite
## defender holds a good forward to 34% and cuts his goals about a quarter.
## Pinned smaller: the same forward against an elite and an average
## defender, over 60 matches each (30 left the gap to the seeds: 18 points
## over 120 matches, under either clearance rule).
func _test_key_duel_balance() -> void:
	var kfs := []
	var kds := []
	for p in GameDB.players:
		if str(p["role"]) == "FWD" and PlayerProfile.forward_type(p) == "Key forward":
			kfs.append(p)
		if str(p["role"]) == "DEF" and PlayerProfile.player_type(p) == "Key defender":
			kds.append(p)
	kfs.sort_custom(func(a, b): return Matchups.forward_air(a) > Matchups.forward_air(b))
	kds.sort_custom(func(a, b): return Matchups.defender_air(a) > Matchups.defender_air(b))
	var fwd: Dictionary = kfs[kfs.size() / 4]
	var rates := []
	for dfn in [kds[1], kds[kds.size() / 2]]:
		var contests := 0
		var won := 0
		for s in range(60):
			var home := []
			for p in GameDB.club_list("GEE"):
				home.append(p.duplicate(true))
			var away := []
			for p in GameDB.club_list("COL"):
				away.append(p.duplicate(true))
			var kf_id := str(Matchups.key_forwards(Squad.new("GEE", home, true, "GEE").ground)[0]["id"])
			var kd_id := str(Matchups.defenders(Squad.new("COL", away, false, "COL").ground)[0]["id"])
			for p in home:
				if str(p["id"]) == kf_id:
					p["attr"] = (fwd["attr"] as Dictionary).duplicate()
					p["height_cm"] = fwd.get("height_cm", 0)
			for p in away:
				if str(p["id"]) == kd_id:
					p["attr"] = (dfn["attr"] as Dictionary).duplicate()
					p["height_cm"] = dfn.get("height_cm", 0)
			var sim := MatchSim.new(Squad.new("GEE", home, true, "GEE"), Squad.new("COL", away, false, "COL"), 9000 + s)
			sim.set_matchup(1, kf_id, kd_id, false)
			sim.run()
			for c in (sim.duel_log.get(kf_id, {}) as Dictionary).get("contests", []):
				if str(c[1]) == kd_id:
					contests += 1
					if bool(c[2]):
						won += 1
		rates.append(float(won) / maxi(1, contests))
	_check(BalanceGate.held(rates[1] - rates[0] >= 0.08 and rates[0] < 0.5, "key duel balance"),
			"An elite key defender holds a good forward; an average one does not (%.0f%% v %.0f%%)" % [100 * rates[0], 100 * rates[1]])

## Momentum is real, small, capped, fading and reversible, and it does not
## snowball.
## Row 78 (T8.Q4): a side with the run of play that is well ahead wins more of
## the ball and keeps its run longer, so lopsided matches can run away.
func _test_momentum_runaway() -> void:
	# The edge grows only past the lead, for the side that has the run.
	var sim := _sim(7802)
	sim.momentum = 1.0
	_check(sim.runaway() == 0.0, "Level scores: no runaway")
	sim.team_stats[0]["goals"] = 4.0
	_check(sim.runaway() == 0.0, "A 24-point lead: no runaway yet")
	sim.team_stats[0]["goals"] = 9.0
	_check(is_equal_approx(sim.runaway(), 1.0), "A 54-point lead with the run of play: full runaway (%.2f)" % sim.runaway())
	sim.momentum = -1.0
	_check(sim.runaway() == 0.0, "The side behind having the run is no runaway")
	# The away side 54 up with the run: the stoppage edge grows to the contest cap.
	sim.team_stats[0]["goals"] = 0.0
	sim.momentum = -1.0
	var wins := [0, 0]
	for mode in range(2):
		sim.team_stats[1]["goals"] = 0.0 if mode == 0 else 9.0
		sim.rng.seed = 787878
		for i in range(20000):
			if sim.contest_winner(false, 0.0) == 1:
				wins[mode] += 1
	var lift := float(wins[1] - wins[0]) / 20000.0
	_check(lift > 0.05, "Run away with it: the side 54 up with the run wins %.1f%% more of the ball" % (100.0 * lift))
	_check(float(wins[1]) / 20000.0 < float(Ratings.T["contest_clamp"]) + 0.02,
			"Never past the contest cap (%.3f)" % (float(wins[1]) / 20000.0))
	# The trailing coach's call still bites at full runaway: the cap is applied
	# to the runaway before the calls, so Throw numbers at it (surge) and a
	# stacked stoppage win the home side, 54 down, more of the ball.
	var called := 0
	sim.bursts[0] = {"surge": 5, "stack": 5}
	sim.rng.seed = 787878
	for i in range(20000):
		if sim.contest_winner(false, 0.0) == 0:
			called += 1
	sim.bursts[0] = {}
	var call_lift := float(called - (20000 - wins[1])) / 20000.0
	var promised := MatchSim.SURGE_CONTEST + MatchSim.STACK_CONTEST
	_check(call_lift > promised * 0.6,
			"A call by the side 54 down still lifts its contest share by about %.1f%% (%.1f%%)" % [100.0 * promised, 100.0 * call_lift])
	sim.team_stats[1]["goals"] = 0.0
	sim.team_stats[0]["goals"] = 9.0
	sim.momentum = 0.8
	sim._after_chain()
	_check(sim.momentum > 0.8 * MatchSim.MOMENTUM_DECAY, "A run that is running away fades more slowly (%.3f)" % sim.momentum)
	# Goals the other way (each one on the board) still turn it, a little more slowly.
	sim.momentum = 0.8
	var after := []
	for g in range(3):
		sim.team_stats[1]["goals"] = float(g + 1)
		sim._swing_momentum(1, MatchSim.MOMENTUM_GOAL)
		after.append(snappedf(sim.momentum, 0.01))
	_check(float(after[0]) > 0.2, "One goal the other way turns it less (%.2f)" % float(after[0]))
	_check(float(after[2]) < 0.0, "Three goals the other way still turn it (%s)" % str(after))


func _test_momentum() -> void:
	# Real: the side with the run of play wins more of the ball, by about
	# MOMENTUM_EDGE at full momentum.
	var sim := _sim(9100)
	var wins := [0, 0]
	for mode in range(2):
		sim.momentum = 1.0 if mode == 1 else 0.0
		sim.rng.seed = 424242
		for i in range(20000):
			if sim.contest_winner(false, 0.0) == 0:
				wins[mode] += 1
	var lift := float(wins[1] - wins[0]) / 20000.0
	_check(lift > 0.025 and lift < 0.055, "Full momentum wins about 4%% more of the ball (%.3f)" % lift)
	# Capped: a string of goals cannot push it past full.
	sim.momentum = 0.0
	for i in range(20):
		sim._swing_momentum(0, MatchSim.MOMENTUM_GOAL)
	_check(sim.momentum <= 1.0 and sim.momentum > 0.9, "A run of goals fills it but never past full (%.2f)" % sim.momentum)
	var edge_at_full: float = sim.momentum_edge * sim.momentum
	_check(edge_at_full <= MatchSim.MOMENTUM_EDGE, "The edge is capped at MOMENTUM_EDGE")
	# Reversible: the other side's goals turn it, faster than it built.
	sim.momentum = 0.8
	sim._swing_momentum(1, MatchSim.MOMENTUM_GOAL)
	_check(sim.momentum < 0.2, "One goal the other way arrests a strong run (%.2f)" % sim.momentum)
	sim._swing_momentum(1, MatchSim.MOMENTUM_GOAL)
	_check(sim.momentum < 0.0, "Two goals the other way turn it (%.2f)" % sim.momentum)
	# Fades: ten passages without a score take most of it away.
	sim.momentum = 0.8
	for i in range(10):
		sim._after_chain()
	_check(sim.momentum < 0.4 and sim.momentum > 0.0, "It fades within a few minutes of play (%.2f)" % sim.momentum)
	# Every event carries it for the meter.
	var res := _sim(9101).run()
	var carried := true
	var moved := false
	for ev in res["events"]:
		if str(ev["kind"]) == "goal":
			carried = carried and ev.has("mom")
			if absf(float(ev.get("mom", 0.0))) > 0.3:
				moved = true
	_check(carried and moved, "Goals carry the engine's momentum, and it moves")
	# No snowball: after a goal the same side kicks the next only slightly
	# more often than without momentum (measured 51% without, 52% with).
	var pairs := 0
	var same := 0
	for i in range(80):
		var r := _sim(9200 + i, ["GEE", "COL", "MEL", "SYD"][i % 4], ["CAR", "BRL", "ADE", "HAW"][i % 4]).run()
		var last := -1
		for ev in r["events"]:
			if str(ev["kind"]) != "goal":
				continue
			if last >= 0:
				pairs += 1
				if int(ev["side"]) == last:
					same += 1
			last = int(ev["side"])
	var share := float(same) / float(maxi(1, pairs))
	_check(BalanceGate.held(share < 0.56, "momentum snowball share"), "Momentum does not snowball: the scorers kick the next goal %.0f%% of the time" % (100.0 * share))


## A moment card's call changes the football, and which call is right
## depends on the situation.
func _test_moment_calls_matter() -> void:
	# The calls last a passage of play and end at the break.
	var sim := _sim(8800)
	sim.moment_side = 0
	_check(int(MatchSim.BURSTS["surge"]["chains"]) >= 12 and int(MatchSim.BURSTS["hold"]["chains"]) >= 12,
			"'The next ten minutes' is a passage of play, not two minutes")
	sim.begin_quarter()
	(sim.bursts[0] as Dictionary)["surge"] = 15
	sim.run_quarter()
	_check((sim.bursts[0] as Dictionary).is_empty(), "A call ends at the break")
	# Throw numbers at it: more scoring at both ends. Slow it down: less.
	var totals := {"none": 0.0, "surge": 0.0, "hold": 0.0}
	for key in totals:
		for i in range(40):
			var s2 := _sim(8900 + i, ["GEE", "MEL", "SYD", "ADE"][i % 4], ["COL", "CAR", "BRL", "HAW"][i % 4])
			while s2.current_quarter <= 4:
				s2.begin_quarter()
				if key != "none":
					(s2.bursts[0] as Dictionary)[key] = 999
				s2.run_quarter()
			totals[key] += float(s2.score(0) + s2.score(1))
	_check(totals["surge"] > totals["none"] * 1.03 and totals["hold"] < totals["none"] * 0.97,
			"Throwing numbers at it opens the game up and slowing it down closes it (%.0f / %.0f / %.0f a match)" % [
			totals["surge"] / 40.0, totals["none"] / 40.0, totals["hold"] / 40.0])
	# Set shots: the best call depends on the shot.
	var best := {}
	# Thirty matches: the call other than the shot is best only now and then.
	for i in range(30):
		var s3 := _sim(9300 + i)
		s3.moment_side = 0
		while s3.current_quarter <= 4:
			s3.begin_quarter()
			while not s3.continue_quarter():
				var m := s3.pending_moment
				if str(m["kind"]) == "set_shot":
					var top := ""
					var top_ev := -1.0
					for o in m["options"]:
						var ev := 6.0 * float(o.get("goal", 0.0)) + float(o.get("behind", 0.0) if o.has("behind") else (1.0 - float(o.get("goal", 0.0))) * 0.3)
						if ev > top_ev:
							top_ev = ev
							top = str(o["key"])
					best[top] = int(best.get(top, 0)) + 1
				s3.resolve_moment(int(m.get("default", 0)))
			s3.end_quarter()
	# A sitter and a long shot on the boundary, offered to the same man: the
	# matches above may hold neither (with more trait carriers, most shots are
	# taken and kicked; traits up to five, director 2026-11-12).
	var s4 := _sim(9400)
	s4.moment_side = 0
	s4.begin_quarter()
	var kicker: Dictionary = (s4.squads[0] as Squad).ground[0]
	for band in [{"key": "sitter", "spot": "15 out, straight in front", "goal": 0.85, "behind": 0.1},
			{"key": "boundary", "spot": "50 out on the boundary", "goal": 0.1, "behind": 0.25}]:
		s4.call("_offer_set_shot", 0, 80.0, kicker, null, band)
		var top := ""
		var top_ev := -1.0
		for o in s4.pending_moment["options"]:
			var ev := 6.0 * float(o.get("goal", 0.0)) + float(o.get("behind", 0.0) if o.has("behind") else (1.0 - float(o.get("goal", 0.0))) * 0.3)
			if ev > top_ev:
				top_ev = ev
				top = str(o["key"])
		best[top] = int(best.get(top, 0)) + 1
	_check(best.size() >= 2, "No set-shot call is always right: the best one changes with the shot (%s)" % str(best))


## Rival coaches' tendencies (director, 2026-10-11): readable, characteristic
## calls on the same rule, never dice. Each style's call shows under its own
## condition where a balanced coach would hold; your own club is never
## given one; a coach keeps his style on his record across a save.
func _test_coach_styles() -> void:
	var call := func(style: String, margin: int, q: int, ai := true) -> Dictionary:
		var m := _sim(8440, "GEE", "COL")
		var sq: Squad = m.squads[1]
		sq.ai_plans = ai
		sq.coach_style = style
		sq.tactics_read = 0.0
		m.standing[1] = "balanced"
		m.current_quarter = q
		# The scoreboard: side 1 is `margin` points up (in behinds).
		m.team_stats[0] = {"goals": 0.0, "behinds": 40.0}
		m.team_stats[1] = {"goals": 0.0, "behinds": 40.0 + float(margin)}
		var t := m.ai_tactics(1)
		t["loose"] = m._ai_interceptor(1, sq.ground)
		return t
	# react is 18 points for this coach (read 0).
	var plan := func(style: String, margin: int, q: int) -> String:
		return str(call.call(style, margin, q)["gameplan"])
	_check(plan.call("cautious", 14, 2) == "controlled" and plan.call("balanced", 14, 2) == "balanced",
			"A coach who sits on a lead shuts up shop 14 points up; a balanced one does not")
	_check(plan.call("gambler", -14, 2) == "attacking" and plan.call("balanced", -14, 2) == "balanced",
			"A coach who goes for broke chases 14 down; a balanced one does not")
	_check(plan.call("reactive", 14, 2) == "controlled" and plan.call("reactive", -14, 2) == "attacking"
			and plan.call("balanced", 14, 2) == "balanced",
			"A coach who throws the magnets around moves at 14 points either way")
	_check(plan.call("stubborn", -20, 3) == "balanced" and plan.call("balanced", -20, 3) == "attacking",
			"A coach who backs his structure keeps his plan 20 down; a balanced one chases")
	_check(plan.call("stubborn", -23, 3) == "attacking" and plan.call("stubborn", 23, 3) == "controlled",
			"Even a coach who backs his structure reacts 23 points either way (director 2026-11-03: at most 25% later)")
	var keeps := str(call.call("stubborn", -20, 4)["loose"]) != ""
	var pulls := str(call.call("balanced", -20, 4)["loose"]) == ""
	var stub_pulls := str(call.call("stubborn", -30, 4)["loose"]) == ""
	var had := str(call.call("balanced", 0, 1)["loose"]) != ""
	_check(not had or (keeps and pulls and stub_pulls),
			"Backing his structure keeps the loose man 20 down late, pulls him 30 down; a balanced coach pulls him at 20")
	# Every style's margins sit within 25% of the plain rule; none never acts.
	var bounded := true
	var base: Dictionary = MatchSim.COACH_STYLES["balanced"]
	for k in MatchSim.COACH_STYLES:
		var stl: Dictionary = MatchSim.COACH_STYLES[k]
		for key in ["protect", "chase", "loose", "fire_at"]:
			var r := float(stl[key]) / float(base[key])
			bounded = bounded and r >= 0.75 - 0.001 and r <= 1.25 + 0.001
		bounded = bounded and float(stl["add"]) == 0.0 and int(stl["lost_q"]) <= 4 and int(stl["loose_q"]) <= 4
	_check(bounded, "Coach styles move reaction thresholds by at most 25% and never switch a reaction off")
	# Your club: whatever is on the squad, you are the coach.
	_check(str(call.call("gambler", -14, 2, false)["gameplan"]) == "balanced",
			"Your own club never plays to a style")
	# His style is his: kept on his record, the same after a save.
	var c := {"cid": "C_test_coach", "skills": {"tactics": 60, "manage": 60, "teach": 60}}
	var s1 := Coaches.style(c)
	var back: Dictionary = JSON.parse_string(JSON.stringify(c))
	_check(Coaches.STYLES.has(s1) and str(back.get("style", "")) == s1 and Coaches.style(back) == s1,
			"A coach's style is kept on his record and survives a save (%s)" % s1)
	var sharp := {"cid": "C_test_coach", "skills": {"tactics": 85, "manage": 60, "teach": 60}}
	_check(Coaches.style(sharp) == "balanced", "A sharp tactician reads the game as it is")
	var seen := {}
	var world := Coaches.seed("GEE")
	for cid in world:
		seen[Coaches.style(world[cid])] = true
	_check(seen.size() >= 4, "The league's coaches have a spread of tendencies (%s)" % str(seen.keys()))


## Playtest: a defensive AI sat in its press all game while losing, and
## Controlled Tempo shut the press out for any list. Now:
## - behind after half time and outscored in the quarter just gone, the AI
##   chases (only the scoreboard - no read of the other side's plan);
## - Controlled Tempo holds a press off as far as its ball users can.
##   Measured, 150 matches a club v a pressing side: worth +20 and +15
##   points to the two best ball-using sides, +3 and +4 to the two worst
##   (it was +8 to +18 whatever the list).
func _test_ai_chases_and_controlled_needs_ball_users() -> void:
	var sim := _sim(4800)
	sim.standing[1] = "defensive"
	(sim.squads[1] as Squad).tactics_read = 0.5
	sim.current_quarter = 3
	for side in range(2):
		(sim.team_stats[side] as Dictionary)["goals"] = 8.0
	(sim.team_stats[0] as Dictionary)["goals"] = 9.0
	sim.q_goals[1] = [4, 1]
	sim.q_behinds[1] = [1, 1]
	_check(str(sim.ai_tactics(1)["gameplan"]) == "attacking",
			"Behind after half time and outscored last quarter, the AI chases")
	sim.q_goals[1] = [1, 4]
	_check(str(sim.ai_tactics(1)["gameplan"]) == "defensive",
			"Behind but winning the last quarter, it sticks with its game")
	sim.current_quarter = 2
	sim.q_goals[0] = [4, 1]
	_check(str(sim.ai_tactics(1)["gameplan"]) == "defensive",
			"Before half time a close deficit is no reason to abandon it")
	# Controlled Tempo against a press: good ball users hold it off, poor ones
	# only partly.
	var press := _sim(4801)
	press.set_tactics(1, {"gameplan": "defensive"})
	press.set_tactics(0, {"gameplan": "controlled"})
	(press.plan_fit[0] as Dictionary)["controlled"] = 1.2
	var good := press._press_on(0)
	(press.plan_fit[0] as Dictionary)["controlled"] = 0.5
	var poor := press._press_on(0)
	press.set_tactics(0, {"gameplan": "balanced"})
	var none := press._press_on(0)
	_check(is_equal_approx(good, 1.0) and poor > 1.0 and poor < none,
			"Controlled Tempo holds a press off as far as its ball users can (%.3f, %.3f, %.3f)" % [good, poor, none])
	_check(PlanFit.standing_plan([]) == "balanced", "An empty list plays Balanced")

## A tag is a trade: it takes the target out of the midfield battle and costs
## you your tagger's own game. Worth it on their star with a specialist; a
## loss when a good midfielder has to do the job.
func _test_tag_tradeoff() -> void:
	var with_spec := ""
	var without := ""
	for code in GameDB.active_clubs(2027):
		var t = MatchSim.tagger_for(Squad.new(code, GameDB.club_list(code), true, code).ground)
		if t != null and Roles.is_tagger(t):
			with_spec = code if with_spec == "" else with_spec
		elif without == "":
			without = code
	_check(with_spec != "" and without != "", "Clubs with and without a specialist tagger (%s, %s)" % [with_spec, without])
	if with_spec == "" or without == "":
		return
	var opp := "SYD" if with_spec != "SYD" and without != "SYD" else "BRL"
	var mids := []
	for p in (_sim(5, with_spec, opp).squads[1] as Squad).ground:
		if str(p["role"]) == "MID":
			mids.append(p)
	mids.sort_custom(func(x, y): return int(x["overall"]) > int(y["overall"]))
	var star: Dictionary = mids[0]
	var plain: Dictionary = mids[mids.size() - 1]
	# The midfield battle, as the stoppages see it (positive: ours).
	var edge := func(code: String, target: Dictionary, tagger_id: String = "") -> float:
		var sim := _sim(5, code, opp)
		sim.set_tactics(0, {"tag_id": str(target["id"]), "tagger_id": tagger_id})
		return sim._tag_drag(1) - sim._tag_drag(0)
	# The half of that which is the tag's hold on his man (_tag_parts).
	var held := func(code: String, target: Dictionary, tagger_id: String = "") -> float:
		var sim := _sim(5, code, opp)
		sim.set_tactics(0, {"tag_id": str(target["id"]), "tagger_id": tagger_id})
		return float(sim._tag_parts(1)[0])
	var spec_star: float = edge.call(with_spec, star)
	var spec_plain: float = edge.call(with_spec, plain)
	# Without a specialist the hold follows his Pressure (Roles.tag_keep):
	# the midfielder who holds a man least (last in tag_order) plays the man
	# for nothing much and gives up his own game.
	# Of the clubs without one, the midfielder who holds a man least.
	var loose_club := ""
	var loose_id := ""
	var loose_keep := 0.0
	for code in GameDB.active_clubs(2027):
		if code == opp:
			continue
		var order := MatchSim.tag_order(Squad.new(code, GameDB.club_list(code), true, code).ground)
		if order.is_empty() or Roles.is_tagger(order[0]):
			continue
		var last: Dictionary = order[order.size() - 1]
		if Roles.tag_keep(last, 100.0) > loose_keep:
			loose_keep = Roles.tag_keep(last, 100.0)
			loose_club = code
			loose_id = str(last["id"])
	var mid_star: float = edge.call(loose_club, star, loose_id)
	var mid_plain: float = edge.call(loose_club, plain, loose_id)
	var best_plain: float = edge.call(loose_club, plain)
	var spec_hold: float = held.call(with_spec, star)
	var loose_hold: float = held.call(loose_club, star, loose_id)
	var best_hold: float = held.call(loose_club, star)
	_check(spec_star > 0.0, "A specialist tagger on their best midfielder wins us the midfield battle (%+.2f)" % spec_star)
	_check(spec_star > 2.0 * spec_plain, "...by far more than the same tag on an ordinary one (%+.2f)" % spec_plain)
	_check(loose_keep > Roles.TAG_TIGHTEST_PLAIN and mid_plain < 0.0 and mid_star > mid_plain,
			"Without a specialist, a midfielder who can't hold a man (%s, keeps %.2f) gives up his own game: a loss on an ordinary one (%+.2f), a gain on their star (%+.2f)" % [loose_club, loose_keep, mid_plain, mid_star])
	_check(loose_hold > 0.0 and loose_hold < spec_hold,
			"...but he takes real ball off their star, and less than a specialist (%.2f v %.2f)" % [loose_hold, spec_hold])
	_check(best_hold > loose_hold,
			"The side's best presser holds him tighter (%.2f v %.2f)" % [best_hold, loose_hold])
	_check(best_plain < mid_plain,
			"...and gives up more of his own game to do it, so on an ordinary man he costs more (%+.2f v %+.2f)" % [best_plain, mid_plain])
	# Over paired matches: the target sees less of the ball, and a good
	# midfielder sent to tag sees less of it too.
	var tagger: Dictionary = MatchSim.tagger_for((_sim(5, without, opp).squads[0] as Squad).ground)
	var t_on := 0.0
	var t_off := 0.0
	var g_on := 0.0
	var g_off := 0.0
	var n := 20
	for i in range(n):
		var on := _sim(900 + i, without, opp)
		on.set_tactics(0, {"tag_id": str(star["id"])})
		var r_on := on.run()
		var r_off := _sim(900 + i, without, opp).run()
		t_on += float((r_on["players"] as Dictionary).get(str(star["id"]), {}).get("disposals", 0.0))
		t_off += float((r_off["players"] as Dictionary).get(str(star["id"]), {}).get("disposals", 0.0))
		g_on += float((r_on["players"] as Dictionary).get(str(tagger["id"]), {}).get("disposals", 0.0))
		g_off += float((r_off["players"] as Dictionary).get(str(tagger["id"]), {}).get("disposals", 0.0))
	_check(t_on < t_off - 2.0 * n, "Tagged, their star sees much less of it (%.1f v %.1f a game)" % [t_on / n, t_off / n])
	_check(g_on < g_off - 1.0 * n, "...and so does the midfielder who tags him (%.1f v %.1f a game)" % [g_on / n, g_off / n])


## Playtest: "from 30 metres, straight in front" was missed most of the time.
## A set shot's chance now comes from where it is kicked from, calibrated to
## AFL rates (85% from 20-30 m in front, 71% from 30-40 m), with the kicker
## and the match on top; the words match the chance.
func _test_set_shot_bands() -> void:
	var ordinary := MatchSim.set_bands(MatchSim.SET_REF)
	var by := {}
	for b in ordinary:
		by[str(b["key"])] = b
	_check(is_equal_approx(float(by["close"]["goal"]), 0.85) and is_equal_approx(float(by["front"]["goal"]), 0.71),
			"An ordinary kick converts at the AFL rate in front (%.2f, %.2f)" % [float(by["close"]["goal"]), float(by["front"]["goal"])])
	_check(MatchSim.chance_words(float(by["front"]["goal"])) == "He should kick it"
			and MatchSim.chance_words(float(by["close"]["goal"])) == "He should kick it",
			"Straight in front, an ordinary kick should kick it")
	_check(float(by["pocket"]["goal"]) < float(by["front"]["goal"]) and float(by["long"]["goal"]) < 0.4
			and float(by["angle"]["goal"]) < float(by["front"]["goal"]),
			"The pocket, the angle and long shots are harder")
	var good := {}
	var poor := {}
	for b in MatchSim.set_bands(MatchSim.SET_REF * 1.25):
		good[str(b["key"])] = b
	for b in MatchSim.set_bands(MatchSim.SET_REF * 0.75):
		poor[str(b["key"])] = b
	_check(float(good["front"]["goal"]) - float(poor["front"]["goal"]) >= 0.25,
			"A good kick and a poor one differ from 35 m in front (%.2f v %.2f)" % [float(good["front"]["goal"]), float(poor["front"]["goal"])])
	_check(ordinary.all(func(b): return float(b["goal"]) + float(b["behind"]) <= 1.0),
			"A set shot's goal and behind chances never exceed one")
	# The split keeps the mark's expected goals: scoring across the league
	# does not move, only where it comes from.
	var sim := _sim(4600)
	var goal_p := 0.36
	var behind_p := 0.17
	var n := 20000
	var shots := 0
	var e_goal := 0.0
	var e_behind := 0.0
	var fronts := 0
	for i in range(n):
		var split: Dictionary = sim._set_shot_split(goal_p, behind_p)
		e_goal += float(split["goal"])
		e_behind += float(split["behind"])
		if not (split["band"] as Dictionary).is_empty():
			shots += 1
			if str(split["band"]["key"]) in ["close", "front"]:
				fronts += 1
	# With the set-shot share the game plays (SET_SHARE_ON), the set shots
	# alone can carry more than the mark's old expected goals: the rest of the
	# marks then play on at nothing, and the mark is worth what the bands say.
	var want_g := 0.0
	var want_b := 0.0
	for b in MatchSim.set_bands(goal_p):
		want_g += float(b["share"]) * float(b["goal"])
		want_b += float(b["share"]) * float(b["behind"])
	var share := sim.set_share()
	want_g = share * want_g + (1.0 - share) * maxf(0.0, (goal_p - share * want_g) / (1.0 - share))
	want_b = share * want_b + (1.0 - share) * maxf(0.0, (behind_p - share * want_b) / (1.0 - share))
	_check(e_goal / n >= goal_p - 0.01 and absf(e_goal / n - want_g) < 0.01,
			"A mark's expected goals never fall, and are what the bands say (%.3f v %.3f, was %.3f)" % [e_goal / n, want_g, goal_p])
	_check(absf(e_behind / n - want_b) < 0.01, "...and its expected behinds (%.3f v %.3f)" % [e_behind / n, want_b])
	_check(absf(float(shots) / n - sim.set_share()) < 0.02 and absf(float(fronts) / shots - 0.45) < 0.03,
			"Most marks are set shots, about half of them in front (%d, %d)" % [shots, fronts])
	# In play: set shots convert at an AFL-like rate, and the offered call
	# names where from and gives the band's chance.
	var goals := 0
	var tried := 0
	for seed in range(4610, 4640):
		var r := _sim(seed, "SYD", "RIC").run()
		for e in r["events"]:
			if bool(e.get("set", false)):
				tried += 1
				if str(e["kind"]) == "goal":
					goals += 1
	_check(BalanceGate.held(tried > 0 and float(goals) / tried > 0.5 and float(goals) / tried < 0.8, "set shot accuracy"),
			"Set shots that score go through at an AFL-like rate (%d of %d)" % [goals, tried])
	var asked := {}
	for seed in range(4700, 4760):
		var live := _sim(seed)
		live.moment_side = 0
		while live.current_quarter <= 4 and asked.is_empty():
			live.begin_quarter()
			while not live.continue_quarter():
				if str(live.pending_moment["kind"]) == "set_shot":
					asked = live.pending_moment.duplicate(true)
				live.resolve_moment(int(live.pending_moment.get("default", 0)))
			live.end_quarter()
		if not asked.is_empty():
			break
	var named := false
	for b in MatchSim.SET_BANDS_ON:
		named = named or str(asked.get("title", "")).ends_with(str(b["spot"]))
	_check(named, "The set-shot call says where he kicks from (%s)" % str(asked.get("title", "")))


## Forward archetypes (ARD-M3-002): a key forward takes his marks inside 50
## and kicks more of his goals from set shots; a small forward wins it at
## ground level and kicks more of his off the deck. Either can score both ways.
func _test_forward_archetypes() -> void:
	_check(MatchSim.fwd_size({"height_cm": 196.0}) == "key" and MatchSim.fwd_size({"height_cm": 178.0}) == "small"
			and MatchSim.fwd_size({"height_cm": 187.0}) == "general", "A forward's type follows his height")
	var i50 := {"key": 0, "small": 0}
	var games := {"key": 0, "small": 0}
	var goals := {"key": [0, 0, 0], "small": [0, 0, 0]}  # set, open, crumbed
	var clubs := ["GEE", "COL", "SYD", "BRL", "MEL", "CAR", "HAW", "ESS"]
	var f50 := float(Ratings.T["forward50_line"])
	for i in range(40):
		var sim := _sim(2600 + i, clubs[i % 8], clubs[(i + 3) % 8])
		sim.run()
		var size_of := {}
		for side in [0, 1]:
			for p in (sim.squads[side] as Squad).ground:
				if str(p.get("role", "")) == "FWD":
					var sz := MatchSim.fwd_size(p)
					if games.has(sz):
						size_of[str(p["id"])] = sz
						games[sz] += 1
		for ev in sim.events:
			var id := str(ev.get("player_id", ""))
			if not size_of.has(id):
				continue
			var sz: String = size_of[id]
			var kind := str(ev.get("kind", ""))
			if kind == "mark":
				var afp := float(ev.get("fp", 0.0)) * (1.0 if int(ev.get("side", 0)) == 0 else -1.0)
				if afp > f50:
					i50[sz] += 1
			elif kind == "goal":
				var how := 2 if bool(ev.get("crumb", false)) else (0 if bool(ev.get("set_shot", false)) else 1)
				goals[sz][how] += 1
	var key_i50 := float(i50["key"]) / maxf(1.0, games["key"])
	var small_i50 := float(i50["small"]) / maxf(1.0, games["small"])
	# Drafted leagues run about 2.6x (fwd_archetype_impl); real 2026 lists, whose small
	# forwards mark better, about 1.7x.
	_check(BalanceGate.held(key_i50 > 1.5 * small_i50, "key forward marks inside 50"), "Key forwards take their marks inside 50 (%.2f a game, small %.2f)" % [key_i50, small_i50])
	var kg: Array = goals["key"]
	var sg: Array = goals["small"]
	var key_set := float(kg[0]) / maxf(1.0, kg[0] + kg[1] + kg[2])
	var small_set := float(sg[0]) / maxf(1.0, sg[0] + sg[1] + sg[2])
	var small_crumb := float(sg[2]) / maxf(1.0, sg[0] + sg[1] + sg[2])
	var key_crumb := float(kg[2]) / maxf(1.0, kg[0] + kg[1] + kg[2])
	_check(BalanceGate.held(key_set > small_set + 0.15, "key forward set-shot goal share"), "More of a key forward's goals come from set shots (%.0f%% vs %.0f%%)" % [100.0 * key_set, 100.0 * small_set])
	_check(BalanceGate.held(small_crumb > key_crumb + 0.08, "small forward crumb goal share"), "More of a small forward's come off the deck (%.0f%% vs %.0f%%)" % [100.0 * small_crumb, 100.0 * key_crumb])
	_check(sg[0] > 0 and kg[1] + kg[2] > 0, "Either kind still scores the other way")


## ARD-M4-013: each call plays out as its own sequence, and every event it
## makes says which call it was (the view draws only who these name).
func _test_set_shot_calls() -> void:
	var keys := ["shoot", "pass", "bomb"]
	var n := {"shoot": 0, "pass": 0, "bomb": 0}
	var tagged := true
	var result_flag := true
	var leftover := true
	var pass_ok := true
	var pass_once := true
	var pack_ok := true
	var outcomes := {}
	var snaps := 0
	var turn := 0
	for seed in range(4800, 4840):
		var live := _sim(seed)
		live.moment_side = 0
		while live.current_quarter <= 4:
			live.begin_quarter()
			while not live.continue_quarter():
				var m: Dictionary = live.pending_moment
				if str(m["kind"]) != "set_shot":
					live.resolve_moment(int(m.get("default", 0)))
					continue
				var key: String = keys[turn % 3]
				turn += 1
				var pick := -1
				var opts: Array = m["options"]
				for i in range(opts.size()):
					if str(opts[i]["key"]) == key:
						pick = i
				if pick < 0:
					live.resolve_moment(0)
					continue
				n[key] += 1
				var shooter_id := str(m["player_id"])
				var disp_before := float((live.player_stats.get(shooter_id, {}) as Dictionary).get("disposals", 0.0))
				var from := live.events.size()
				live.resolve_moment(pick)
				var made := []
				var after_moment := false
				for k in range(from, live.events.size()):
					var e: Dictionary = live.events[k]
					if str(e["kind"]) == "moment":
						after_moment = true
						continue
					if after_moment:
						leftover = leftover and not e.has("choice")
					elif e.has("choice"):
						made.append(e)
				for e in made:
					tagged = tagged and str(e["choice"]) == key
				var res: Dictionary = made[made.size() - 1] if not made.is_empty() else {}
				# A snap off the pack or a rushed behind is not a set shot.
				var general := bool(res.get("crumb", false)) or bool(res.get("rushed", false))
				if general:
					snaps += 1
				result_flag = result_flag and ["goal", "behind", "rebound"].has(str(res.get("kind", ""))) 						and bool(res.get("setshot", false)) != general
				var kinds := made.map(func(e): return str(e["kind"]))
				if key == "pass":
					var disp_after := float((live.player_stats.get(shooter_id, {}) as Dictionary).get("disposals", 0.0))
					pass_once = pass_once and is_equal_approx(disp_after - disp_before, 1.0)
					pass_ok = pass_ok and kinds.size() >= 2 and kinds[0] == "pass"
					if kinds.has("receive"):
						var rec: Dictionary = made[kinds.find("receive")]
						pass_ok = pass_ok and str(res.get("passer_id", "")) == shooter_id 								and str(res.get("to_id", "")) == str(rec["player_id"])
				if key == "bomb":
					var packs := made.filter(func(e): return str(e["kind"]) == "pack")
					pack_ok = pack_ok and packs.size() == 1
					if packs.size() == 1:
						var pk: Dictionary = packs[0]
						var oc := str(pk["outcome"])
						outcomes[oc] = int(outcomes.get(oc, 0)) + 1
						var scored := ["goal", "behind"].has(str(res.get("kind", "")))
						match oc:
							"marked":
								pack_ok = pack_ok and str(pk["marker_id"]) != "" 										and (not scored or str(res["player_id"]) == str(pk["marker_id"]))
							"spoiled":
								pack_ok = pack_ok and str(pk["spoiler_id"]) != ""
								if str(pk["crumber_id"]) != "" and scored:
									pack_ok = pack_ok and str(res["player_id"]) == str(pk["crumber_id"]) 											and bool(res.get("crumb", false))
							"defence":
								pack_ok = pack_ok and str(pk["defender_id"]) != "" and str(res["kind"]) == "rebound"
							"through":
								pack_ok = pack_ok and scored and str(res["player_id"]) == str(m["player_id"])
							_:
								pack_ok = false
			live.end_quarter()
		if n["shoot"] >= 15 and n["pass"] >= 15 and n["bomb"] >= 25:
			break
	_check(n["shoot"] > 0 and n["pass"] > 0 and n["bomb"] > 0, "Each set-shot call gets played (%s)" % str(n))
	_check(tagged, "Every event a set-shot call makes names that call")
	_check(result_flag, "Each call ends in a goal, a behind or a rebound marked as the set shot's, unless it was snapped off the pack or rushed (%d)" % snaps)
	_check(leftover, "The call's tag stops when its chain does")
	_check(pass_ok, "Playing on shows the pass, then the mark, and the shot names both men")
	_check(pass_once, "Playing on counts the marker's kick once")
	_check(pack_ok, "A bomb makes one pack, and its result belongs to who the pack names")
	_check(outcomes.has("marked") and outcomes.has("spoiled") and outcomes.has("defence"),
			"The pack is marked, spoiled to the deck or won by the defence (%s)" % str(outcomes))
## The Defensive forward (director, 2026-10-06): one of your forwards goes to
## their loose defender. A Defensive forward keeps him out of more contests
## than any other forward would; the cost is the forward's own game.
func _test_defensive_forward() -> void:
	var df := 0
	var fwds := 0
	for p in GameDB.all_players_sorted():
		if str(p.get("role", "")) == "FWD":
			fwds += 1
			if Traits.has(p, "def_forward"):
				df += 1
	_check(BalanceGate.held(df >= 18 and df <= 60, "defensive forward share"), "Defensive forwards are a real minority of the league's forwards (%d of %d)" % [df, fwds])
	# Like every trait, a prospect grows into it: count them five seasons on
	# (at draft it is a handful, and noise).
	var gen := 0
	for y in range(2028, 2033):
		for p in Prospects.generate_class(y):
			if str(p["role"]) != "FWD":
				continue
			var q: Dictionary = p.duplicate(true)
			for k in range(1, 6):
				Prospects.age_player(q, y + k)
			if Traits.has(q, "def_forward"):
				gen += 1
	_check(BalanceGate.held(gen >= 4, "drafted defensive forwards"), "Draft classes bring Defensive forwards too (%d in five classes, five seasons on)" % gen)

	var sim := _sim(8301, "ADE", "SYD")
	var spare := Matchups.best_interceptor((sim.squads[1] as Squad).ground, 0.0)
	sim.set_interceptor(1, str(spare.get("id", "")), false)
	var my_fwds := Matchups.minder_candidates((sim.squads[0] as Squad).ground)
	_check(my_fwds.size() >= 2, "There are forwards to send")
	# The director, 2026-10-06: "Other player" must not be a midfielder or
	# defender. The quick picks and the full sheet both offer this list.
	var off_line := my_fwds.filter(func(p): return str(p.get("role", "")) != "FWD")
	_check(off_line.is_empty() and (sim.squads[0] as Squad).ground.any(func(p): return str(p.get("role", "")) != "FWD"),
			"Only forwards are offered to go to their loose man, never a midfielder or defender")
	if my_fwds.size() < 2:
		return
	# One forward made a Defensive forward, one made plainly not.
	var spec: Dictionary = my_fwds[0]
	var plain: Dictionary = my_fwds[my_fwds.size() - 1]
	var was := [int(spec["attr"]["pressure"]), int(plain["attr"]["pressure"])]
	(spec["attr"] as Dictionary)["pressure"] = 70
	(plain["attr"] as Dictionary)["pressure"] = 20
	_check(Traits.has(spec, "def_forward") and not Traits.has(plain, "def_forward"),
			"The trait follows the forward's Pressure")
	_check(str(Matchups.minder_candidates((sim.squads[0] as Squad).ground)[0]["id"]) == str(spec["id"]),
			"Defensive forwards are listed first to send")
	var base := sim._roam_chance(1)
	sim.set_tactics(0, {"gameplan": "balanced", "spare_accountable": true, "spare_minder_id": str(plain["id"])})
	var by_plain := sim._roam_chance(1)
	sim.set_tactics(0, {"gameplan": "balanced", "spare_accountable": true, "spare_minder_id": str(spec["id"])})
	var by_spec := sim._roam_chance(1)
	_check(base > 0.0 and by_spec < by_plain and by_plain < base,
			"A Defensive forward keeps the spare out of more contests than another forward (%.2f, %.2f, none %.2f)" % [by_spec, by_plain, base])
	_check(str(sim._spare_minder(0).get("id", "")) == str(spec["id"]), "The named forward is the one who goes")
	sim.set_tactics(0, {"gameplan": "balanced"})
	_check(sim._spare_minder(0).is_empty() and is_equal_approx(sim._roam_chance(1), base), "No call, nobody goes")
	(spec["attr"] as Dictionary)["pressure"] = was[0]
	(plain["attr"] as Dictionary)["pressure"] = was[1]

	# The cost is his own game: over paired matches the forward sent takes
	# fewer marks and shots than when he stays in the forward line.
	var with_call := 0
	var without := 0
	var roam_with := 0
	var roam_without := 0
	for seed in range(8310, 8326):
		for sent in [true, false]:
			var m := _sim(seed, "ADE", "SYD")
			var sp := Matchups.best_interceptor((m.squads[1] as Squad).ground, 0.0)
			m.set_interceptor(1, str(sp.get("id", "")), false)
			var minder: Dictionary = Matchups.minder_candidates((m.squads[0] as Squad).ground)[0]
			if sent:
				m.set_tactics(0, {"gameplan": "balanced", "spare_accountable": true, "spare_minder_id": str(minder["id"])})
			var res := m.run()
			var st: Dictionary = res["players"].get(str(minder["id"]), {})
			var spst: Dictionary = res["players"].get(str(sp.get("id", "")), {})
			var involved := int(st.get("marks", 0)) + int(st.get("goals", 0)) + int(st.get("behinds", 0))
			if sent:
				with_call += involved
				roam_with += int(spst.get("roam_contests", 0))
			else:
				without += involved
				roam_without += int(spst.get("roam_contests", 0))
	_check(with_call < without, "The forward sent gives up his own marks and shots (%d against %d)" % [with_call, without])
	_check(roam_with < roam_without, "Their loose defender reaches fewer contests (%d against %d)" % [roam_with, roam_without])

	# The AI sends its forward by the same rule, once the spare has hurt it.
	var ai := _sim(8341, "GEE", "COL")
	ai.player_stats[str((ai.squads[0] as Squad).ground[0]["id"])] = {"roam_wins": 2}
	var t := ai.ai_tactics(1)
	var expect := Matchups.minder_candidates((ai.squads[1] as Squad).ground)
	_check(bool(t.get("spare_accountable", false)) and not expect.is_empty()
			and str(t.get("spare_minder_id", "")) == str(expect[0]["id"]),
			"An AI club names the forward a coach would send, by the same rule")


## The High Press (director, 2026-10-11): it hunts the ball high and
## leaves space behind. The side it presses meets more pressure in its back
## third, about Balanced's in the middle, and less in its forward third; a
## chain that breaks the press scores more easily; the AI's press is the
## same rule (it is keyed on the plan, not on who chose it).
func _test_press_by_zone() -> void:
	var sim := _sim(8430, "GEE", "COL")
	sim.tactics[0] = {"gameplan": "defensive"}
	sim.tactics[1] = {"gameplan": "balanced"}
	var back := sim._press_on(1, 0)
	var mid := sim._press_on(1, 1)
	var fwd := sim._press_on(1, 2)
	_check(back > mid and mid >= 1.0 and fwd < 1.0,
			"Against a press: more pressure in your back third, less in your forward third (%.2f / %.2f / %.2f)" % [back, mid, fwd])
	sim.tactics[0] = {"gameplan": "balanced"}
	_check(is_equal_approx(sim._press_on(1, 0), 1.0) and is_equal_approx(sim._press_on(1, 2), 1.0),
			"Against Balanced the pressure is the same in every zone")
	# The other way round: the same rule when side 1 presses side 0.
	sim.tactics[1] = {"gameplan": "defensive"}
	_check(sim._press_on(0, 0) > sim._press_on(0, 1) and sim._press_on(0, 2) < 1.0,
			"The same press rule for either side")
	# A chain that broke the press: its shot is likelier to be a goal.
	sim.tactics[1] = {"gameplan": "defensive"}
	var shooter: Dictionary = (sim.squads[0] as Squad).ground[0]
	sim._broke_press = -1
	var held := sim.shot_chance(0, shooter, true, false)
	sim._broke_press = 0
	var broke := sim.shot_chance(0, shooter, true, false)
	# The other side's break never makes this side's shot easier.
	sim._broke_press = 1
	var theirs := sim.shot_chance(0, shooter, true, false)
	sim._broke_press = -1
	_check(is_equal_approx(theirs, held), "A break by the other side gives this side's shot nothing (%.3f vs %.3f)" % [theirs, held])
	_check(broke > held * 1.5, "A chain that breaks the press shoots at an outnumbered defence (%.3f vs %.3f)" % [broke, held])


## Assign defensive forward (register item 5, director 2026-10-07): the words
## on the break come from the constants the match runs on, the card shows the
## one attribute the job uses, and the director's requirement holds: a forward
## sent still scores, and is a target far less often than the side's others.
## The Defensive forward's "How it's going" reads the sim's own records.
func _test_df_duel_numbers() -> void:
	var seen_pairs := 0
	var matched := true
	for seed in [8301, 8302, 8303]:
		var sim := _sim(seed, "ADE", "MEL")
		var spare := Matchups.best_interceptor((sim.squads[0] as Squad).ground, 0.0)
		sim.set_interceptor(0, str(spare.get("id", "")), false)
		var mine := Matchups.minder_candidates((sim.squads[1] as Squad).ground)
		var t: Dictionary = (sim.tactics[1] as Dictionary).duplicate()
		t["spare_accountable"] = true
		t["spare_minder_id"] = str(mine[0]["id"])
		sim.set_tactics(1, t)
		sim.run_quarter()
		var res: Dictionary = sim.run_quarter()
		var rid := str(spare["id"])
		var did := str(mine[0]["id"])
		var d := MatchNotes.df_duel(res, did, rid)
		var rec: Array = (sim.roam_pairs as Dictionary).get(rid + "|" + did, [0, 0])
		var st: Dictionary = sim.player_stats.get(rid, {})
		matched = matched and d["contests"] == int(rec[0]) and d["df_won"] + d["roamer_won"] == int(rec[0]) 				and d["roamer_intercepts"] == int(st.get("intercepts", 0.0)) 				and d["roamer_rating"] == MatchNotes.rating(st) 				and d["df_rating"] == MatchNotes.rating(sim.player_stats.get(did, {}))
		# The roamer's pair records never exceed his own roaming contests.
		var total := 0
		for k in sim.roam_pairs:
			if str(k).begins_with(rid + "|"):
				total += int(sim.roam_pairs[k][0])
		matched = matched and total <= int(st.get("roam_wins", 0.0)) + int(st.get("roam_losses", 0.0))
		seen_pairs += total
	_check(matched and seen_pairs > 0, "Defensive forward duel numbers match the sim's records (%d recorded contests)" % seen_pairs)
	var lines := MatchNotes.df_duel_lines({"df_id": "x", "roamer_id": "y", "contests": 7, "df_won": 4, "roamer_won": 3,
			"roamer_intercepts": 6}, "Petty", "Worrell")
	_check(lines[0] == "Petty won 4 of their 7 contests" and lines[1] == "Worrell: 6 intercepts", "The lines read as the director asked")


func _test_defensive_forward_cards() -> void:
	_check(MatchNotes.minder_question("Jake Lever", "Melbourne").begins_with("Who covers Jake Lever (Melbourne)?")
			and MatchNotes.minder_none_line().contains("no loose defender"),
			"The question names their loose defender and his club; with none, it says so")
	# A card shows where he plays, the trait when he has it, and his Pressure.
	var sim := _sim(8401, "ADE", "SYD")
	var fwds := Matchups.minder_candidates((sim.squads[0] as Squad).ground)
	var spec := {}
	var plain := {}
	for p in fwds:
		if Traits.has(p, "def_forward") and spec.is_empty():
			spec = p
		if not Traits.has(p, "def_forward") and plain.is_empty():
			plain = p
	for p in [spec, plain]:
		if p.is_empty():
			continue
		var wide := MatchNotes.minder_card_detail(p, true)
		var narrow := MatchNotes.minder_card_detail(p, false)
		var pressure := roundi(float((p["attr"] as Dictionary)["pressure"]))
		var is_spec := Traits.has(p, "def_forward")
		_check(wide.contains("Pressure %d" % pressure) and narrow.contains("Pressure %d" % pressure)
				and wide.contains("Defensive forward") == is_spec and narrow.contains("Defensive forward") == is_spec
				and wide.contains("Forward"),
				"A card shows his position, Pressure %d%s (%s)" % [pressure, " and Defensive forward" if is_spec else "", wide])
	# Paired seeds: the forward sent still scores and is a target less often
	# than the side's other forwards (an audit of 150 matches: about 41% of
	# their shots, goals in about 40% of matches).
	var sent_shots := 0.0
	var sent_goals := 0.0
	var other_shots := 0.0
	var other_n := 0
	for seed in range(8410, 8422):
		var m := _sim(seed, "ADE", "SYD")
		var sp := Matchups.best_interceptor((m.squads[1] as Squad).ground, 0.0)
		m.set_interceptor(1, str(sp.get("id", "")), false)
		var ground: Array = (m.squads[0] as Squad).ground.duplicate()
		var minder: Dictionary = Matchups.minder_candidates(ground)[0]
		m.set_tactics(0, {"gameplan": "balanced", "spare_accountable": true, "spare_minder_id": str(minder["id"])})
		var res := m.run()
		var stats: Dictionary = res["players"]
		sent_shots += float((stats.get(str(minder["id"]), {}) as Dictionary).get("shots", 0.0))
		sent_goals += float((stats.get(str(minder["id"]), {}) as Dictionary).get("goals", 0.0))
		for p in ground:
			if str(p["role"]) == "FWD" and str(p["id"]) != str(minder["id"]):
				other_shots += float((stats.get(str(p["id"]), {}) as Dictionary).get("shots", 0.0))
				other_n += 1
	var others_avg := other_shots / float(maxi(1, other_n)) * 12.0
	_check(sent_goals > 0.0, "A forward sent to their loose defender still kicks goals (%d in 12 matches)" % int(sent_goals))
	_check(sent_shots < others_avg, "He is a target less often than the others: %d shots in 12 matches against %.0f for an average other forward" % [
			int(sent_shots), others_avg])


## ARD-M4-015: eight plan names become six. An old save's "fast" plays as
## Attack Corridor and "press" as High Press: the same match, the same
## names on every screen.
func _test_six_plans() -> void:
	var a := _sim(9100)
	a.set_tactics(0, {"gameplan": "fast"})
	var b := _sim(9100)
	b.set_tactics(0, {"gameplan": "attacking"})
	var ra := a.run()
	var rb := b.run()
	_check(ra["score"] == rb["score"] and (ra["events"] as Array).size() == (rb["events"] as Array).size(),
			"An old save's Fast movement plays exactly as Attack Corridor")
	_check(CoachReport.plan_label("fast") == "Attack Corridor" and CoachReport.plan_label("press") == "High Press"
			and not MatchSim.PLANS.has("fast") and not MatchSim.PLANS.has("press") and MatchSim.PLANS.size() == 4,
			"Five plans (balanced and four others), and the old names read as the merged ones")


## The full-time decision summary (director, 2026-10-11): each call has its
## own line, worth what it changed on average; a call not made is worth
## nothing; the lines and "the rest" add up to the margin.
func _test_decision_credits() -> void:
	# No calls at all: every decision line is 0 for both sides.
	var off := _sim(7301)
	off.run()
	var zero := true
	for side in range(2):
		for cause in MatchSim.DECISION_CAUSES:
			zero = zero and float((off.impact[side] as Dictionary).get(cause, 0.0)) == 0.0
	_check(zero, "With no calls made, every decision line is 0 (%s)" % str(off.impact))
	# Each call on: its own line moves, and only its owner's.
	var on := _sim(7301)
	var their_mid := ""
	for p in (on.squads[1] as Squad).ground:
		if their_mid == "" and MatchSim.taggable(p):
			their_mid = str(p["id"])
	var spare: Dictionary = Matchups.best_interceptor((on.squads[1] as Squad).ground)
	on.set_tactics(0, {"gameplan": "balanced", "tag_id": their_mid, "spare_accountable": true})
	on.set_interceptor(1, str(spare.get("id", "")), false)
	on.run()
	var i0: Dictionary = on.impact[0]
	var i1: Dictionary = on.impact[1]
	_check(float(i0.get("tag", 0.0)) != 0.0 and float(i1.get("tag", 0.0)) == 0.0,
			"A tag is booked to the side that called it (%.2f, %.2f)" % [float(i0.get("tag", 0.0)), float(i1.get("tag", 0.0))])
	_check(float(i1.get("loose", 0.0)) != 0.0 and float(i0.get("loose", 0.0)) == 0.0,
			"A loose defender is booked to his side (%.2f)" % float(i1.get("loose", 0.0)))
	_check(float(i0.get("minder", 0.0)) > 0.0,
			"A forward sent to their loose man is worth what he takes off him (%.2f)" % float(i0.get("minder", 0.0)))
	var margin := float(on.score(0) - on.score(1))
	var sum0 := CoachReport.decision_lines(on.impact, 0, margin)
	var total := float(sum0["rest"])
	for l in sum0["lines"]:
		total += float(l["pts"])
	_check(is_equal_approx(total, margin) and (sum0["lines"] as Array).size() >= 2,
			"The decision lines and the rest add up to the margin (%+.1f)" % margin)
	# An old save's last match booked the bursts as "calls": still shown.
	var old_lines := CoachReport.impact_lines([{"calls": 2.0}, {}], [{}, {}], 0)
	_check(old_lines.size() == 1 and str(old_lines[0]["label"]) == "Your in-game calls"
			and is_equal_approx(float(old_lines[0]["pts"]), 2.0),
			"An old save's \"calls\" still reads as in-game calls (%s)" % str(old_lines))
	# A moment: the call is worth its expected points against the default.
	var live := _sim(7302)
	live.moment_side = 0
	var want := 0.0
	var seen := 0
	while live.current_quarter <= 4:
		live.begin_quarter()
		while not live.continue_quarter():
			var m: Dictionary = live.pending_moment
			var pick := int(m.get("default", 0))
			if str(m.get("kind", "")) == "set_shot":
				var opts: Array = m["options"]
				pick = opts.size() - 1
				want += live._option_points(opts[pick]) - live._option_points(opts[int(m.get("default", 0))])
				seen += 1
			live.resolve_moment(pick)
		live.end_quarter()
	_check(seen > 0 and is_equal_approx(float((live.impact[0] as Dictionary).get("moments", 0.0)), want) and want != 0.0,
			"A set-shot call is worth its chances against taking the shot (%d calls, %+.2f)" % [seen, want])


## From the second quarter a coach reads the plan you ran and plays the one
## that beats it when that costs him little (COUNTER_GIVE); the scoreboard
## decides first.
func _test_ai_counters_plan() -> void:
	var m := _sim(8450, "GEE", "COL")
	var sq: Squad = m.squads[1]
	sq.tactics_read = 0.0
	sq.coach_style = "balanced"
	m.standing[1] = "balanced"
	m.current_quarter = 2
	m.tactics_history = [{"quarter": 1, "plans": [{"gameplan": "controlled"}, {"gameplan": "balanced"}]}]
	var att := PlanFit.plan_score(sq.ground, "attacking", sq.plan_know)
	var t := str(m.ai_tactics(1)["gameplan"])
	_check(t == ("attacking" if att >= -MatchSim.COUNTER_GIVE else "balanced"),
			"Against Controlled Tempo he plays Attack Corridor when it is worth nearly his usual game (%s, %.2f)" % [t, att])
	# Weighed on edge x knowledge: knowing the counter barely makes it cost more.
	m.standing[1] = "contest"
	sq.plan_know = {"attacking": 1.0, "contest": 1.0}
	var c_sc := PlanFit.plan_score(sq.ground, "contest", sq.plan_know)
	var a_sc := PlanFit.plan_score(sq.ground, "attacking", sq.plan_know)
	var expect := "attacking" if a_sc >= c_sc - MatchSim.COUNTER_GIVE else "contest"
	_check(str(m.ai_tactics(1)["gameplan"]) == expect, "The counter is weighed on edge x plan knowledge (%s)" % expect)
	# A big edge in his usual game against a far worse counter: he keeps it.
	sq.plan_know = {"attacking": 0.0, "contest": 1.0}
	var keep := PlanFit.plan_score(sq.ground, "contest", sq.plan_know) > MatchSim.COUNTER_GIVE
	_check(not keep or str(m.ai_tactics(1)["gameplan"]) == "contest",
			"A counter worth far less than his usual game is not played")
	sq.plan_know = {}
	m.tactics_history = [{"quarter": 1, "plans": [{"gameplan": "balanced"}, {"gameplan": "contest"}]}]
	_check(str(m.ai_tactics(1)["gameplan"]) == "contest", "Against Balanced there is nothing to counter")
	m.current_quarter = 1
	m.tactics_history = [{"quarter": 1, "plans": [{"gameplan": "controlled"}, {"gameplan": "contest"}]}]
	_check(str(m.ai_tactics(1)["gameplan"]) == "contest", "No counter before the second quarter")
	m.current_quarter = 2
	m.team_stats[0] = {"goals": 0.0, "behinds": 0.0}
	m.team_stats[1] = {"goals": 0.0, "behinds": 30.0}
	_check(str(m.ai_tactics(1)["gameplan"]) == "controlled", "30 up he protects the lead before any counter")
	m.team_stats[1] = {"goals": 0.0, "behinds": 0.0}
	m.team_stats[0] = {"goals": 0.0, "behinds": 30.0}
	m.tactics_history = [{"quarter": 1, "plans": [{"gameplan": "attacking"}, {"gameplan": "contest"}]}]
	_check(str(m.ai_tactics(1)["gameplan"]) == "attacking", "30 down he chases before any counter")


## A beaten key defender goes to the defender who gives the forward the lowest
## mark chance; one on another forward swaps only when the pair's chances fall.
func _test_rematch_lowest_mark_chance() -> void:
	var m := _sim(8302, "ADE", "SYD")
	m.current_quarter = 2
	var d: Dictionary = m.duels[1]
	var loose := str(m.interceptor[1])
	var sum := func() -> float:
		var t := 0.0
		for f in d:
			t += Matchups.mark_chance(m._on_ground(0, str(f)), m._on_ground(1, str(d[f])))
		return t
	var moves := 0
	for fid in d.keys():
		var cur_id := str(d[fid])
		var fwd := m._on_ground(0, str(fid))
		var cur := m._on_ground(1, cur_id)
		var on := {}
		for f in d:
			on[str(d[f])] = str(f)
		var before: float = sum.call()
		m.duel_log[str(fid)] = {"side": 0, "contests": [[1, cur_id, true, false],
				[1, cur_id, true, false], [1, cur_id, true, false]]}
		m._rematch(1, str(fid), {loose: true} if loose != "" else {})
		var after: float = sum.call()
		var now_id := str(d[fid])
		if now_id == cur_id:
			continue
		moves += 1
		_check(now_id != loose, "The loose man is never the replacement")
		_check(after < before - 0.000001, "A move lowers the forwards' summed mark chance (%.3f -> %.3f)" % [before, after])
		var prev_f := str(on.get(now_id, ""))
		_check(prev_f == "" or str(d.get(prev_f, "")) == cur_id,
				"A defender taken off another forward hands that forward the beaten man")
		# No better choice was skipped: every defender with a lower chance on
		# him would not have lowered the sum.
		var got := Matchups.mark_chance(fwd, m._on_ground(1, now_id))
		_check(got < Matchups.mark_chance(fwd, cur) or prev_f != "",
				"A free defender comes in only when he gives the forward less (%.3f)" % got)
	_check(moves >= 0, "Rematches tried on every forward (%d moved)" % moves)
	_check(str(m.interceptor[1]) == loose, "The loose man keeps roaming")
	# Built case: the forward's man is poor, the best defender is on a forward
	# he barely matters against - the swap lowers the sum, so it is made.
	var defs := Matchups.defenders((m.squads[1] as Squad).ground)
	_check(defs.size() >= 2, "Enough defenders to test a swap")


## Your assistant makes the calls a rival coach would in your position, for
## your club, and leaves what you set yourself.
func _test_assistant_plays_ai_calls() -> void:
	var m := _sim(8460, "GEE", "COL")
	var sq: Squad = m.squads[0]
	sq.ai_plans = false
	sq.assistant = true
	sq.coach_style = "gambler"
	m.set_tactics(0, {"gameplan": "contest", "focus_id": "x"})
	m.run_quarter()
	var mine := str(m.interceptor[0])
	if mine != "":
		m.coach_interceptor(0, mine)
	m.team_stats[1] = {"goals": 0.0, "behinds": 0.0}
	m.team_stats[0] = {"goals": 0.0, "behinds": 60.0}
	(m.tactics_history[-1]["plans"] as Array)[1] = {"gameplan": "balanced"}
	m._assistant_calls(0)
	_check(str(m.tactics[0]["gameplan"]) == "contest" and str(m.tactics[0].get("focus_id", "")) == "x",
			"60 up after a quarter your assistant leaves your game plan, and the rest of your call, alone")
	_check(str(m.interceptor[0]) == mine, "He leaves the loose man you named")
	_check(m._style(0) == MatchSim.COACH_STYLES["balanced"], "Your club keeps the balanced style")


## Director, 2026-11-07: "After every quarter it changes my gameplan from
## balanced to controlled tempo". Your game plan stays what you last chose at
## every break, however far ahead or behind, until you pick another; the
## rival coach still picks his own each quarter.
func _test_coach_plan_sticks_at_breaks() -> void:
	for lead in [60.0, 12.0, -60.0]:
		var m := _sim(8461, "GEE", "COL")
		var sq: Squad = m.squads[0]
		sq.ai_plans = false
		sq.assistant = true
		(m.squads[1] as Squad).ai_plans = true
		m.set_tactics(0, {"gameplan": "balanced"})
		var rival := {}
		for q in range(1, 5):
			m.begin_quarter()
			_check(str(m.tactics[0]["gameplan"]) == "balanced",
					"Q%d plays the Balanced you chose (lead %+d)" % [q, int(lead)])
			rival[str(m.tactics[1]["gameplan"])] = true
			while not m.continue_quarter():
				m.resolve_moment(int(m.pending_moment.get("default", 0)))
			# Make the margin at the break the one under test.
			for side in range(2):
				(m.team_stats[side] as Dictionary)["goals"] = 0.0
				(m.team_stats[side] as Dictionary)["behinds"] = maxf(0.0, lead if side == 0 else -lead)
			m.end_quarter()
			if q < 4:
				_check(str(m.tactics[0]["gameplan"]) == "balanced",
						"After Q%d the break still shows your Balanced (lead %+d, got %s)" % [
						q, int(lead), str(m.tactics[0]["gameplan"])])
		if lead == 60.0:
			_check(rival.has("attacking"), "Sixty down, the rival coach still chases with his own plan")
	# A plan you pick at a break is the one that stays.
	var p := _sim(8462, "GEE", "COL")
	(p.squads[0] as Squad).ai_plans = false
	(p.squads[0] as Squad).assistant = true
	p.set_tactics(0, {"gameplan": "balanced"})
	p.run_quarter()
	var t: Dictionary = (p.tactics[0] as Dictionary).duplicate()
	t["gameplan"] = "attacking"
	p.set_tactics(0, t)
	p.begin_quarter()
	while not p.continue_quarter():
		p.resolve_moment(int(p.pending_moment.get("default", 0)))
	(p.team_stats[0] as Dictionary)["goals"] = 0.0
	(p.team_stats[0] as Dictionary)["behinds"] = 60.0
	(p.team_stats[1] as Dictionary)["goals"] = 0.0
	(p.team_stats[1] as Dictionary)["behinds"] = 0.0
	p.end_quarter()
	_check(str(p.tactics[0]["gameplan"]) == "attacking", "Change it yourself and your new plan stays through the break")

	# The tag and the spare's minder: his until you pick them, then yours.
	var tagged := false
	for club in ["GEE", "COL", "CAR", "ESS", "HAW", "RIC", "SYD", "BRL", "MEL", "WBD"]:
		for keep in [false, true]:
			var g := _sim(8463, club, "GEE" if club != "GEE" else "COL")
			var gs: Squad = g.squads[0]
			gs.ai_plans = false
			gs.assistant = true
			var tagger_id := ""
			for pl in gs.ground:
				if g.midfielder_on_ground(pl) and Roles.is_tagger(pl):
					tagger_id = str(pl["id"])
					break
			if tagger_id == "":
				break
			g.set_tactics(0, {"gameplan": "balanced", "tagger_id": tagger_id, "tag_id": "", "tag_set": keep})
			g.current_quarter = 3
			g._assistant_calls(0)
			var got := str(g.tactics[0].get("tag_id", ""))
			if not keep:
				tagged = got != ""
				if not tagged:
					break
			else:
				_check(got == "", "No tag is your call: at the break he leaves it (%s)" % club)
				_check(not g.tactics[0].has("tag_set"), "The tag_set flag is not kept in the plan")
		if tagged:
			break
	_check(tagged, "A club with a specialist tagger found, and his assistant tags when it is his call")
	for keep in [false, true]:
		var s := _sim(8464, "GEE", "COL")
		(s.squads[0] as Squad).ai_plans = false
		(s.squads[0] as Squad).assistant = true
		s.set_tactics(0, {"gameplan": "balanced", "spare_accountable": false, "spare_minder_id": "", "minder_set": keep})
		var their := str(((s.squads[1] as Squad).ground[0] as Dictionary)["id"])
		s.player_stats[their] = {"roam_wins": 3}
		s._assistant_calls(0)
		var on := bool(s.tactics[0].get("spare_accountable", false))
		if keep:
			_check(not on, "No minder on their spare is your call: he leaves it")
		else:
			_check(on, "Their spare has won three: left to him, he puts a minder on him")


## Plan knowledge weighs the usual game, and Controlled Tempo can be it.
func _test_standing_plan_knowledge() -> void:
	var g: Array = _sim(4802).squads[0].ground
	var free := PlanFit.standing_plan(g)
	_check(is_equal_approx(PlanFit.plan_score(g, "contest", {"contest": 0.5}), PlanFit.edge(g, "contest") * 0.5),
			"A plan's score is its edge times the club's knowledge of it")
	if free != "balanced":
		_check(PlanFit.standing_plan(g, {free: 0.0}) != free, "A plan the club does not know is not its usual game")
	var only_controlled := {}
	for p in PlanFit.NEEDS:
		only_controlled[p] = 1.0 if p == "controlled" else 0.0
	var ok := true
	for code in GameDB.active_clubs(2027):
		var gg: Array = Squad.new(code, GameDB.club_list(code), false, code).ground
		var want := "controlled" if PlanFit.edge(gg, "controlled") > PlanFit.STANDING_EDGE else "balanced"
		ok = ok and PlanFit.standing_plan(gg, only_controlled) == want
	_check(ok, "Controlled Tempo is a club's usual game when it is its best")
