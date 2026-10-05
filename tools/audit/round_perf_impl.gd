extends RefCounted
## Sim round / Play match timing by season round (roadmap §1.11, "Round
## simulation / Play match performance regression audit"). One home-and-away
## season through the real GameState flow, twice:
##   sim  - Sim round every week (GameState.advance)
##   live - Play match every week: prepare_interactive_match (what the tap
##          waits for), the match itself stepped with default calls (what
##          MatchScene runs while you watch), finish_interactive_match
##          (full time: collect the round's other matches, record, train,
##          the week's admin)
## Autosave is timed on its own (save_career after each round) and the save's
## size is read back, so growth over the season shows separately.
##
## godot --headless --path . --script tools/audit/run_audit.gd -- round_perf_impl

const CLUB := "GEE"


func _ms(t: int) -> float:
	return float(Time.get_ticks_usec() - t) / 1000.0


func _setup() -> void:
	GameState.autosave_enabled = false
	GameState.save_path = "user://perf_career.save"
	GameState.settings_path = "user://perf_settings.cfg"
	GameState.reset()
	GameState.start_season(CLUB, GameDB.club_list(CLUB))


func _save() -> Array:
	var t := Time.get_ticks_usec()
	GameState.save_career()
	var ms := _ms(t)
	var f := FileAccess.open(GameState.save_path, FileAccess.READ)
	var kb := f.get_length() / 1024.0 if f != null else 0.0
	return [ms, kb]


func _settle_week() -> void:
	if not GameState.week_event.is_empty():
		GameState.resolve_week_event(0)


func run() -> void:
	print("== sim: Sim round every week")
	print("| round | advance ms | save ms | save KB |")
	print("|---|---|---|---|")
	_setup()
	var rnd := 0
	while not GameState.season.is_regular_done():
		rnd += 1
		_settle_week()
		var t := Time.get_ticks_usec()
		GameState.advance()
		var adv := _ms(t)
		var sv := _save()
		print("| %d | %.0f | %.0f | %.0f |" % [rnd, adv, sv[0], sv[1]])
	print("")
	print("== live: Play match every week (byes sim the round)")
	print("| round | prepare ms (the tap) | your match ms (CPU while watching) | full time ms | save ms | save KB |")
	print("|---|---|---|---|---|---|")
	_setup()
	rnd = 0
	while not GameState.season.is_regular_done():
		rnd += 1
		_settle_week()
		var t := Time.get_ticks_usec()
		var mine := GameState.prepare_interactive_match()
		var prep := _ms(t)
		if not mine:
			GameState.advance()
			print("| %d | bye | | | | |" % rnd)
			continue
		var sim: MatchSim = GameState.pending_sim
		t = Time.get_ticks_usec()
		while sim.current_quarter <= 4:
			sim.begin_quarter()
			while not sim.continue_quarter():
				sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
			sim.end_quarter()
		var play := _ms(t)
		t = Time.get_ticks_usec()
		GameState.finish_interactive_match(sim.result())
		var fin := _ms(t)
		var sv := _save()
		print("| %d | %.0f | %.0f | %.0f | %.0f | %.0f |" % [rnd, prep, play, fin, sv[0], sv[1]])
	print("")
	print("cores: %d" % OS.get_processor_count())
