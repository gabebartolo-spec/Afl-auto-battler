extends RefCounted
## G7 save growth (#554): how big career_facts gets over a long autopilot
## career, and what it costs the save. Every club drafts as the AI does; every
## default is left alone. Measurement only.
##
## Args after the impl name: seed club seasons (defaults 301 MEL 20).
##
## One FACTS line a season, after its rollover: the season, career_facts rows
## (all, and the user club's players'), its encoded bytes, the whole save
## file's bytes and the facts' share of it. At the end, TIMING: save and load
## times (mean of REPS) with the facts as they are and with them emptied, on
## the same career, and SUMMARY.

const REPS := 5


func _rows() -> Array:
	var all := 0
	var mine := 0
	var ids := {}
	for p in GameState.my_list:
		ids[str(p["id"])] = true
	for id in GameState.career_facts:
		var n := (GameState.career_facts[id] as Array).size()
		all += n
		if ids.has(str(id)):
			mine += n
	return [all, mine]


func _save_bytes() -> int:
	GameState.save_career()
	var f := FileAccess.open(CareerSave.DEFAULT_PATH, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


## Mean milliseconds to save, then to load, over REPS.
func _time_io() -> Array:
	var save_us := 0
	var load_us := 0
	for i in range(REPS):
		var t0 := Time.get_ticks_usec()
		GameState.save_career()
		var t1 := Time.get_ticks_usec()
		GameState.load_career()
		var t2 := Time.get_ticks_usec()
		save_us += t1 - t0
		load_us += t2 - t1
	return [save_us / 1000.0 / REPS, load_us / 1000.0 / REPS]


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 301
	var club := str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 20
	GameState.reset()
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.autosave_enabled = false
	GameState.start_season(club, GameDB.club_list(club))
	var first_bytes := 0
	for s in range(seasons):
		while not GameState.season.is_season_over():
			GameState.advance()
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
		var rows := _rows()
		var facts_bytes := var_to_bytes(GameState.career_facts).size()
		var save := _save_bytes()
		if s == 0:
			first_bytes = save
		print("FACTS seed %d season %d (after %d) | rows %d (your players %d) | facts %d bytes | save %d bytes | facts share %.1f%% | departed %d" % [
				seed, s + 1, GameState.season_year - 1, int(rows[0]), int(rows[1]), facts_bytes, save,
				100.0 * facts_bytes / maxf(1.0, save), GameState.departed_names.size()])
	var with_t := _time_io()
	var with_b := _save_bytes()
	var kept: Dictionary = GameState.career_facts.duplicate(true)
	GameState.career_facts = {}
	var without_b := _save_bytes()
	var without_t := _time_io()
	GameState.career_facts = kept
	print("TIMING seed %d year %d | with facts: save %.1f ms, load %.1f ms, %d bytes | facts emptied: save %.1f ms, load %.1f ms, %d bytes" % [
			seed, seasons, float(with_t[0]), float(with_t[1]), with_b, float(without_t[0]), float(without_t[1]), without_b])
	print("SUMMARY seed %d seasons %d | facts add %.1f%% to the save (%d of %d bytes) | load %+.1f%% | save %+.1f%% | season-1 save %d bytes" % [
			seed, seasons, 100.0 * (with_b - without_b) / maxf(1.0, without_b), with_b - without_b, with_b,
			100.0 * (float(with_t[1]) - float(without_t[1])) / maxf(0.001, float(without_t[1])),
			100.0 * (float(with_t[0]) - float(without_t[0])) / maxf(0.001, float(without_t[0])), first_bytes])
