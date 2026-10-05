extends RefCounted
## Synergies over a career (companion to synergy_impl). A real League Draft,
## then seasons with off-seasons and National Drafts, as career_impl runs
## them (AI-style picks for you). At each season start: your active
## synergies and trait carriers by line in your best 18, the league's
## synergies per club (mean, max), and good traits held, yours against the
## AI mean.
##   policy "ai"      - every default left alone (Position plan training)
##   policy "trainer" - an engaged coach: at each season start every player
##                      of yours trains the plan that weights the stat of the
##                      trait he is nearest (Traits.near), else Position plan
## Args after the impl name: policy seed club seasons
## godot --headless --path . --script tools/audit/run_audit.gd -- synergy_career_impl trainer 1 MEL 4

var policy := "ai"
var club := "MEL"
var seed_n := 1


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _good_traits(list: Array) -> int:
	var n := 0
	for p in list:
		for t in Traits.of(p):
			if not Traits.is_bad(t):
				n += 1
	return n


func _ground(code: String) -> Array:
	var list: Array = []
	for p in GameState.season.lists[code]:
		var q: Dictionary = p.duplicate()
		q.erase("injury_weeks")
		q.erase("suspension_weeks")
		list.append(q)
	return Squad.new(code, list, true, code).ground


## The engaged coach: each player onto the plan that weights the stat of
## the trait he is nearest.
func _train() -> int:
	var n_set := 0
	for p in GameState.my_list:
		var near := Traits.near(p)
		var best := ""
		if not near.is_empty():
			var stat := str(near[0]["stat"])
			var w := 0.0
			for key in GameState.plans_for(p):
				var row: Dictionary = {}
				for r in GameState.TRAIN_PLANS:
					if str(r["key"]) == key:
						row = r
				var ww := float((row.get("weights", {}) as Dictionary).get(stat, 0.0))
				if ww > w:
					w = ww
					best = key
		GameState.set_player_plan(str(p["id"]), best)
		if best != "":
			n_set += 1
	return n_set


func _snapshot(year: int, label: String) -> void:
	var mine := _ground(club)
	var my_act := Traits.active(mine)
	var counts := Traits._counts(mine)
	var lines := []
	for l in ["RUCK", "MID", "DEF", "FWD"]:
		var parts := []
		for t in counts[l]:
			if not Traits.is_bad(t):
				parts.append("%s %d" % [Traits.label(t), int(counts[l][t])])
		lines.append("%s: %s" % [l, ", ".join(parts)])
	var sum := 0.0
	var mx := 0
	var n := 0
	var ai_traits := 0.0
	for c in GameState.season.lists:
		var k := Traits.active(_ground(str(c))).size()
		if str(c) != club:
			sum += k
			n += 1
			mx = maxi(mx, k)
			ai_traits += _good_traits(GameState.season.lists[c])
	print("SYN %s seed %d %d %s | yours %d on %s | league AI mean %.2f max %d | good traits on list: yours %d, AI mean %.1f | your 18: %s" % [
			policy, seed_n, year, label, my_act.size(), str(my_act), sum / maxf(1, n), mx,
			_good_traits(GameState.season.lists[club]), ai_traits / maxf(1, n), " | ".join(lines)])


func run() -> void:
	var args := OS.get_cmdline_user_args()
	policy = str(args[1]) if args.size() > 1 else "ai"
	seed_n = int(args[2]) if args.size() > 2 else 1
	club = str(args[3]) if args.size() > 3 else "MEL"
	var seasons := int(args[4]) if args.size() > 4 else 4
	GameState.reset()
	GameState.autosave_enabled = false
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed_n)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	for s in range(seasons):
		var year := GameState.season_year
		if policy == "trainer":
			_train()
		_snapshot(year, "start")
		while not GameState.season.is_season_over():
			GameState.advance()
		if s == seasons - 1:
			_snapshot(year, "end")
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
