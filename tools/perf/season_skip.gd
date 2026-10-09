extends SceneTree
## Where "Skip to the end of the home and away" spends its time (ARD-M1-007, the
## director's five-minute report). Headless; isolate the save folder with APPDATA.
##   godot --headless --path . --script tools/perf/season_skip.gd -- [--club GEE] [--mode split|real]
## split: plays every home-and-away round through the same steps as GameState.advance(),
##        timing each one, and prints a PERF line per step (total ms, ms a round).
## real:  times GameState.quick_sim(-1) as the button runs it, end to end.
## Both print the save file's size after the last round. Nothing touches a real save.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var club := "GEE"
	var mode := "split"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--club": club = str(a[i + 1])
			"--mode": mode = str(a[i + 1])
	await process_frame
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	gs.replay_seed = 4242
	var t := Time.get_ticks_usec()
	gs.start_season(club, db.club_list(club))
	gs.autosave_enabled = true
	print("PERF start_season %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	if mode == "real":
		t = Time.get_ticks_usec()
		var r: Dictionary = gs.quick_sim(-1)
		print("PERF quick_sim_all %.0f ms, %d rounds (%s)" % [(Time.get_ticks_usec() - t) / 1000.0, int(r["played"]), str(r["reason"])])
	else:
		var steps := ["prep", "play_round", "post_round", "xp", "train_rivals", "rivalries", "after_round", "autosave"]
		var total := {}
		for s in steps:
			total[s] = 0
		var rounds := 0
		while not gs.season.is_regular_done():
			var t0 := Time.get_ticks_usec()
			gs._settle_week_event()
			gs._sync_club_plan()
			gs._refresh_coach_tactics()
			gs.last_results = []
			gs.last_match = {}
			gs.last_pos_before = gs.my_position()
			var t1 := Time.get_ticks_usec()
			gs.last_results = gs.season.play_round()
			var t2 := Time.get_ticks_usec()
			gs.last_phase = "regular"
			gs.last_label = "Round %d" % gs.season.round_index
			gs.ensure_finals()
			for res in gs.last_results:
				gs.season_log.append(res)
				if gs.is_my_match(res):
					gs.last_match = res
			var t3 := Time.get_ticks_usec()
			gs._grant_match_xp(gs.last_match)
			var t4 := Time.get_ticks_usec()
			gs._train_rivals(gs.last_results)
			var t5 := Time.get_ticks_usec()
			gs._record_rivalries(gs.last_results)
			var t6 := Time.get_ticks_usec()
			gs._after_round(gs.last_results)
			var t7 := Time.get_ticks_usec()
			gs.autosave()
			var t8 := Time.get_ticks_usec()
			var marks := [t0, t1, t2, t3, t4, t5, t6, t7, t8]
			for k in range(steps.size()):
				total[steps[k]] += marks[k + 1] - marks[k]
			rounds += 1
		var all := 0
		for s in steps:
			all += int(total[s])
		for s in steps:
			print("PERF %-12s %8.0f ms total, %6.1f ms a round, %4.1f%%" % [s, total[s] / 1000.0,
					total[s] / 1000.0 / maxi(1, rounds), 100.0 * total[s] / maxi(1, all)])
		print("PERF all %.0f ms for %d rounds" % [all / 1000.0, rounds])
	var save_path: String = gs.SAVE_PATH if "SAVE_PATH" in gs else ""
	if save_path != "" and FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		print("PERF save_file %.2f MB" % (f.get_length() / 1048576.0))
	quit(0)
