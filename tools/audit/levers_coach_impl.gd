extends RefCounted
## The levers a coach pulls that the career bots don't (FLAGS_EVIDENCE):
## selecting for synergies and keeping development projects running. One
## career per run, the dynasty harness's upside League Draft, then seasons with
## your club coached on match day and working its list (contracts and free
## agency, dynasty "list"). LEVERS (env) adds, comma-separated:
##   syn  - each week, swap bench players into the side when that switches on
##          more synergies, giving up at most SYN_MAX_DROP OVR a swap
##   proj - keep both development-project places busy (highest POT first,
##          preferring a job in a line he doesn't have yet)
##   train - each preseason, a player within reach of a trait a synergy
##          needs (Traits.near) trains the plan that builds it (TRAIN_FOR)
## Args after the impl name: seeds (comma-separated) seasons. Prints each
## season and a SUMMARY per career.

const SYN_MAX_DROP := 6
## The training plan that builds each synergy trait (no plan trains durability,
## so Engine is left out).
const TRAIN_FOR := {"bull": "inside_mid", "interceptor": "key_def", "lockdown": "key_def",
		"aerial": "key_fwd", "crumber": "small_fwd", "ball_magnet": "outside_mid", "playmaker": "outside_mid"}
const LINES := ["RUCK", "MID", "WING", "DEF", "FWD"]

var dyn = load("res://tools/balance/dynasty.gd").new()
var levers := {}


func _ground(gs, sel: Dictionary) -> Array:
	return Squad.new(GameDB.club_name(gs.my_club), gs.my_list, true, gs.my_club, sel).ground


func _line_role(line: String) -> String:
	return "MID" if line == "WING" else line


## Swap bench players in while it switches on more synergies.
func _select_for_synergies(gs) -> int:
	gs.set_selection({})
	var sel: Dictionary = gs.current_side()
	var best := Traits.active(_ground(gs, sel)).size()
	var by_id := {}
	for p in gs.my_list:
		by_id[str(p["id"])] = p
	for _round in range(4):
		var improved := false
		for b_id in (sel["BENCH"] as Array).duplicate():
			var b: Dictionary = by_id.get(str(b_id), {})
			if b.is_empty() or not Ratings.available(b) or Traits.of(b).is_empty():
				continue
			var found := false
			for line in LINES:
				if not Ratings.plays_role(b, _line_role(line)):
					continue
				for g_id in (sel[line] as Array).duplicate():
					var g: Dictionary = by_id.get(str(g_id), {})
					if g.is_empty() or int(g["overall"]) - int(b["overall"]) > SYN_MAX_DROP:
						continue
					var trial: Dictionary = sel.duplicate(true)
					var li: Array = trial[line]
					li[li.find(g_id)] = b_id
					var bench: Array = trial["BENCH"]
					bench[bench.find(b_id)] = g_id
					var n := Traits.active(_ground(gs, trial)).size()
					if n > best:
						best = n
						sel = trial
						improved = true
						found = true
						break
				if found:
					break
		if not improved:
			break
	gs.set_selection(sel)
	return best


func _train_for_synergies(gs) -> int:
	var n := 0
	for p in gs.my_list:
		if str(p.get("train_plan", "")).begins_with(gs.LEARN_PREFIX):
			continue
		for t in Traits.near(p):
			var plan := str(TRAIN_FOR.get(str(t["key"]), ""))
			if plan != "" and gs.plan_valid_for(p, plan):
				gs.set_player_plan(str(p["id"]), plan)
				n += 1
				break
	return n


func _fill_projects(gs) -> void:
	while gs.active_projects() < gs.PROJECT_MAX:
		var cands := []
		for p in gs.my_list:
			var jobs: Array = gs.learnable_jobs(p)
			if not jobs.is_empty():
				cands.append([p, jobs])
		if cands.is_empty():
			return
		cands.sort_custom(func(a, b): return int(a[0].get("potential", 0)) > int(b[0].get("potential", 0)))
		var p: Dictionary = cands[0][0]
		var job := str(cands[0][1][0])
		var have := Ratings.positions(p)
		for j in cands[0][1]:
			var role := str(gs.LEARN_JOBS[j]["role"])
			if role in ["FWD", "MID", "DEF"] and not have.has(role):
				job = str(j)
				break
		gs.set_player_plan(str(p["id"]), gs.LEARN_PREFIX + job)


## Args: comma-separated seeds (one career each), then seasons.
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := str(args[1]) if args.size() > 1 else "301"
	var seasons := int(args[2]) if args.size() > 2 else 6
	for k in OS.get_environment("LEVERS").split(",", false):
		levers[k.strip_edges()] = true
	for sd in seeds.split(",", false):
		_career(int(sd), seasons)


func _career(seed: int, seasons: int) -> void:
	var gs := GameDB.get_tree().root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	gs.career_seed = seed
	gs.replay_seed = seed
	var d: Draft = dyn.make_upside_draft(seed, 5)
	var user := d.user_club if d.user_club != "" else str(d.draft_order[0])
	gs.draft = d
	gs.start_season(user, [])
	var tag := ",".join(levers.keys()) if not levers.is_empty() else "base"
	var ladders := []
	var flags := 0
	var top4 := 0
	var syn_weeks := 0.0
	var weeks := 0
	var unicorns := 0
	for y in range(seasons):
		if levers.has("train"):
			_train_for_synergies(gs)
		var season_syn := 0.0
		var season_weeks := 0
		while not gs.season.is_season_over():
			if levers.has("proj"):
				_fill_projects(gs)
			var n := _select_for_synergies(gs) if levers.has("syn") else Traits.active(gs.my_squad().ground).size()
			season_syn += n
			season_weeks += 1
			dyn._play_week(gs, user, true)
		var pos: int = gs.club_position(user)
		var prem: bool = gs.premier() == user
		ladders.append(pos)
		flags += 1 if prem else 0
		top4 += 1 if pos <= 4 else 0
		syn_weeks += season_syn
		weeks += season_weeks
		var u := 0
		for p in gs.my_list:
			if Traits.is_unicorn(p):
				u += 1
		unicorns = u
		print("%s seed %d %d %s | ladder %d%s | synergies on per week %.2f | unicorns %d" % [
				tag, seed, gs.season_year, user, pos, " PREMIERS" if prem else "",
				season_syn / maxi(1, season_weeks), u])
		if y == seasons - 1:
			break
		var mgmt: Dictionary = dyn._manage(gs, user, "list")
		gs.set_selection({})
		if not dyn._offseason(gs, user, mgmt):
			push_error("levers_coach: off-season %d of seed %d did not complete" % [y, seed])
			break
	var mean := 0.0
	for x in ladders:
		mean += float(x) / ladders.size()
	print("SUMMARY %s seed %d seasons %d | mean ladder %.2f | top4 %d | flags %d | synergies per week %.2f | unicorns at end %d | ladders %s" % [
			tag, seed, ladders.size(), mean, top4, flags, syn_weeks / maxi(1, weeks), unicorns, str(ladders)])
