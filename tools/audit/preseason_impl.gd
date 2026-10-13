extends SceneTree
## Pre-season audit: training injuries and AI loads over N seeded pre-seasons.
##   godot --headless --path . --script tools/audit/preseason_impl.gd -- [--runs 20] [--club FRE]
## Each run is a new career at `club` whose coach trains Heavy in all three
## blocks (the most a coach can push); AI clubs train by their own situation.
## Prints, for the director's playtest (sizes are his call):
##   - the coach's training injuries per Heavy block, and how many are still
##     out at Round 1;
##   - AI clubs: how many push (a Heavy block), their injuries per Heavy block
##     and per club, how many are out at Round 1, and the spread of bases.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var runs := 20
	var club := "FRE"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--runs":
			runs = int(a[i + 1])
		if str(a[i]) == "--club":
			club = str(a[i + 1])
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var pre = load("res://scripts/sim/PreSeason.gd")
	var cond = load("res://scripts/sim/Conditioning.gd")
	gs.autosave_enabled = false
	gs.save_path = "user://audit_preseason.save"
	gs.settings_path = "user://audit_preseason.cfg"
	var my_by_block := [0, 0, 0]
	var my_out := 0
	var my_list_size := 0
	var ai_clubs := 0
	var ai_pushers := 0
	var ai_heavy_blocks := 0
	var ai_inj := 0
	var ai_out := 0
	var ai_most := 0
	var bases := {"thin": 0, "sound": 0, "strong": 0}
	var my_bases := {"thin": 0, "sound": 0, "strong": 0}
	for r in range(runs):
		var s := 1000 + r
		gs.reset()
		gs.career_seed = s
		gs.replay_seed = s
		gs.start_season(club, db.club_list(club))
		gs.open_preseason()
		gs.set_preseason_block(0, "heavy", "running")
		gs.set_preseason_block(1, "heavy", "skills")
		gs.set_preseason_block(2, "heavy", "skills")
		gs.preseason_sim_to_round1()
		my_list_size += (gs.my_list as Array).size()
		var per_club := {}
		for inj in gs.preseason_injuries():
			var c := str(inj["club"])
			if c == club:
				my_by_block[pre.block_of_week(int(inj["week"]))] += 1
			else:
				per_club[c] = int(per_club.get(c, 0)) + 1
				ai_inj += 1
		for code in gs.season.clubs:
			var out := 0
			for p in gs.season.lists[code]:
				out += 1 if int(p.get("injury_weeks", 0)) > 0 else 0
			var base: String = cond.base_of(gs.fitness_record(str(code)))
			if str(code) == club:
				my_out += out
				my_bases[base] += 1
				continue
			ai_clubs += 1
			ai_out += out
			bases[base] += 1
			ai_most = maxi(ai_most, int(per_club.get(str(code), 0)))
			var heavy := 0
			for b in gs.preseason_blocks(str(code)):
				heavy += 1 if str(b[0]) == "heavy" else 0
			ai_heavy_blocks += heavy
			ai_pushers += 1 if heavy > 0 else 0
	var n := float(runs)
	print("Pre-season audit: %d runs, coach at %s on Heavy in all three blocks, heavy_week_injury %s" % [
			runs, club, str(pre.tune("heavy_week_injury"))])
	print("COACH  list %.1f; training injuries a pre-season %.2f (weeks 1-3: %.2f, weeks 4-5: %.2f, weeks 6-7: %.2f); per Heavy block %.2f; out at Round 1 %.2f; bases %s" % [
			float(my_list_size) / n, float(my_by_block[0] + my_by_block[1] + my_by_block[2]) / n,
			float(my_by_block[0]) / n, float(my_by_block[1]) / n, float(my_by_block[2]) / n,
			float(my_by_block[0] + my_by_block[1] + my_by_block[2]) / (3.0 * n), float(my_out) / n, str(my_bases)])
	print("AI     %d club-pre-seasons; %d pushed (a Heavy block), %d did not; training injuries %d: %.2f per Heavy block, %.2f a club a pre-season, most at one club %d; out at Round 1 %.2f a club; bases %s" % [
			ai_clubs, ai_pushers, ai_clubs - ai_pushers, ai_inj,
			float(ai_inj) / float(maxi(1, ai_heavy_blocks)), float(ai_inj) / float(maxi(1, ai_clubs)), ai_most,
			float(ai_out) / float(maxi(1, ai_clubs)), str(bases)])
	quit(0)
