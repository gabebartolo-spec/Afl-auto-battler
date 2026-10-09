extends RefCounted
## What a coaching staff's character does over a career (ROADMAP §9.4 RPG-006:
## inspect the live teaching / tactics / man-management effects before changing
## anything). Paired autopilot careers: the same seed, your club's staff given
## one character each season, every other club untouched.
## Args after the impl name: arm seed club seasons (STAFF_SEEDS=a,b,c: one career each)
##   arm "base"    - the staff as the world made it
##   arm "teach"   - every coach at your club an elite teacher (90)
##   arm "tactics" - every coach an elite tactician (90)
##   arm "manage"  - every coach an elite man-manager (90)
##   arm "fair"    - every coach Fair in all three (60)
## Per season: young players' (22 and under) rating gain, the whole list's,
## ladder finish, mean margin, and the list's mean morale at the end.

var club := "MEL"
var arm := "base"

func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()

## Your club's staff given the arm's character, before the season is played.
func _shape_staff() -> void:
	if arm == "base":
		return
	for cid in GameState.coaches:
		var c: Dictionary = GameState.coaches[cid]
		if str(c.get("club", "")) != club or str(c.get("status", "")) != "club":
			continue
		var sk: Dictionary = c["skills"]
		if arm == "fair":
			for k in Coaches.SKILLS:
				sk[k] = 60
		else:
			sk[arm] = 90

func run() -> void:
	var args := OS.get_cmdline_user_args()
	arm = str(args[1]) if args.size() > 1 else "base"
	var seed := int(args[2]) if args.size() > 2 else 1
	club = str(args[3]) if args.size() > 3 else "MEL"
	var seasons := int(args[4]) if args.size() > 4 else 5
	# STAFF_SEEDS=301,302,... plays one career per seed in this run.
	var many := OS.get_environment("STAFF_SEEDS")
	if many == "":
		_career(seed, seasons)
		return
	for s in many.split(","):
		_career(int(s), seasons)

func _career(seed: int, seasons: int) -> void:
	GameState.reset()
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.autosave_enabled = false
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	var tot := {"young": 0.0, "all": 0.0, "ladder": 0.0, "margin": 0.0, "morale": 0.0}
	for s in range(seasons):
		_shape_staff()
		var year := GameState.season_year
		var start := {}
		for p in GameState.my_list:
			start[str(p["id"])] = [int(p["overall"]), float(p.get("age", 25.0))]
		var margin := 0
		var games := 0
		while not GameState.season.is_season_over():
			GameState.advance()
			for res in GameState.last_results:
				var h := str(res["home"])
				var a := str(res["away"])
				if club != h and club != a:
					continue
				var sc: Array = res["score"]
				margin += (int(sc[0]) - int(sc[1])) * (1 if club == h else -1)
				games += 1
		var young := []
		var all := []
		var mor := 0.0
		for p in GameState.my_list:
			mor += float(ClubLife.morale(p))
			var st = start.get(str(p["id"]))
			if st == null:
				continue
			var d := float(int(p["overall"]) - int(st[0]))
			all.append(d)
			if float(st[1]) <= 22.0:
				young.append(d)
		var ym := 0.0
		for d in young:
			ym += d
		ym /= maxf(1.0, young.size())
		var am := 0.0
		for d in all:
			am += d
		am /= maxf(1.0, all.size())
		mor /= maxf(1.0, GameState.my_list.size())
		var pos := GameState.club_position(club)
		var mm := float(margin) / maxf(1.0, games)
		tot["young"] += ym
		tot["all"] += am
		tot["ladder"] += pos
		tot["margin"] += mm
		tot["morale"] += mor
		print("%s seed %d %s %d | young gain %+.2f (n %d) | list gain %+.2f | finished %d | margin %+.1f | morale %.1f" % [
				arm, seed, club, year, ym, young.size(), am, pos, mm, mor])
		if s == seasons - 1:
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
	var n := float(seasons)
	print("SUMMARY %s seed %d %s | young gain %+.2f | list gain %+.2f | ladder %.2f | margin %+.1f | morale %.1f" % [
			arm, seed, club, tot["young"] / n, tot["all"] / n, tot["ladder"] / n, tot["margin"] / n, tot["morale"] / n])
