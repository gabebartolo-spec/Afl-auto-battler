extends RefCounted
## Youth growth pace audit (director 2026-10-13: "slow the kids down to match real AFL").
## Measurement only. An autopilot career from the real 2026 lists (every draft run by the AI),
## printing the OVR distribution by age so the sim's curve can be set against the real lists.
##   CURVE|seed|tag|year|group|age|n|mean|p25|median|p75|p90|share>=70|share>=80
##     group  ALL = every listed player; GEN = players drafted in the generated classes (2027 on)
##     tag    pre (the real 2026 lists), start (list after the intake draft, ages as of that season)
##   LEAGUE|seed|tag|year|players|mean OVR (all)|mean best-23 over clubs
##   BAND|seed|year|pick band|players|OVR at pick|OVR 3 seasons on|still listed (generated classes)
##   USER|seed|year|wins|games   (the autopilot user club, for AI v coach)
## Args after the impl name: seed club seasons.
## godot --headless --path . --script tools/audit/run_audit.gd -- growth_curve_impl 11 MEL 10

var seed_n := 1
var gen_ids := {}
var cohort: Array = []


static func _q(xs: Array, f: float) -> float:
	if xs.is_empty():
		return 0.0
	var i := f * float(xs.size() - 1)
	var lo := int(floor(i))
	var hi := mini(lo + 1, xs.size() - 1)
	return float(xs[lo]) * (1.0 - (i - lo)) + float(xs[hi]) * (i - lo)


func _snapshot(tag: String, year: int, lists: Dictionary) -> void:
	var by := {"ALL": {}, "GEN": {}}
	var all_ov: Array = []
	var best_sum := 0.0
	var nclubs := 0
	for code in GameDB.active_clubs(GameState.season_year):
		if not lists.has(code):
			continue
		var ovs: Array = []
		for p in lists[code]:
			var o := float(p["overall"])
			ovs.append(o)
			all_ov.append(o)
			var a := clampi(int(float(p.get("age", 25.0))), 17, 34)
			for g in ["ALL", "GEN"]:
				if g == "GEN" and not gen_ids.has(str(p["id"])):
					continue
				if not by[g].has(a):
					by[g][a] = []
				by[g][a].append(o)
		ovs.sort()
		ovs.reverse()
		var t := 0.0
		for i in range(mini(23, ovs.size())):
			t += ovs[i]
		best_sum += t / float(mini(23, ovs.size()))
		nclubs += 1
	var m := 0.0
	for o in all_ov:
		m += o
	print("LEAGUE|%d|%s|%d|%d|%.2f|%.2f" % [seed_n, tag, year, all_ov.size(), m / maxf(1.0, all_ov.size()), best_sum / maxf(1.0, nclubs)])
	for g in ["ALL", "GEN"]:
		for a in range(17, 35):
			var xs: Array = by[g].get(a, [])
			if xs.is_empty():
				continue
			xs.sort()
			var n70 := 0
			var n80 := 0
			var mean := 0.0
			for x in xs:
				mean += x
				if x >= 70.0:
					n70 += 1
				if x >= 80.0:
					n80 += 1
			print("CURVE|%d|%s|%d|%s|%d|%d|%.2f|%.1f|%.1f|%.1f|%.1f|%.3f|%.3f" % [seed_n, tag, year, g, a, xs.size(),
					mean / xs.size(), _q(xs, 0.25), _q(xs, 0.5), _q(xs, 0.75), _q(xs, 0.9),
					float(n70) / xs.size(), float(n80) / xs.size()])


func _run_draft(d: Draft, national: bool, year: int) -> void:
	var guard := 0
	for e in d.pick_history:
		_note(d.picked[str(e["player_id"])], int(e["pick"]), national, year)
	while not d.is_finished() and guard < 5000:
		guard += 1
		var code := d.current_club()
		var c := d._best_ai_pick(code)
		if c.is_empty():
			d._skip_current_pick()
			continue
		var n_before := d.pick_history.size()
		if d._draft_pick(code, c):
			_note(c, n_before + 1, national, year)
		else:
			d._skip_current_pick()


func _note(p: Dictionary, pick: int, national: bool, year: int) -> void:
	if national:
		gen_ids[str(p["id"])] = true
		cohort.append({"id": str(p["id"]), "year": year, "pick": pick, "ovr0": int(p["overall"])})


func _track(lists: Dictionary, year: int) -> void:
	var by_id := {}
	for code in lists:
		for p in lists[code]:
			by_id[str(p["id"])] = p
	var bands := {}
	for e in cohort:
		if year - int(e["year"]) != 3:
			continue
		var b := "1-10" if int(e["pick"]) <= 10 else ("11-30" if int(e["pick"]) <= 30 else "31+")
		if not bands.has(b):
			bands[b] = [0, 0.0, 0.0, 0]
		bands[b][0] += 1
		bands[b][1] += float(e["ovr0"])
		var p = by_id.get(str(e["id"]))
		if p != null:
			bands[b][2] += float(p["overall"])
			bands[b][3] += 1
	for b in bands:
		var v: Array = bands[b]
		print("BAND|%d|%d|%s|%d|%.2f|%.2f|%d" % [seed_n, year, b, v[0], v[1] / v[0], v[2] / maxf(1.0, v[3]), v[3]])


func run() -> void:
	var args := OS.get_cmdline_user_args()
	seed_n = int(args[1]) if args.size() > 1 else 1
	var club := str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 10
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.career_seed = seed_n
	GameState.replay_seed = seed_n
	print("GA|%d|%s|%d" % [seed_n, club, seasons])
	GameState.begin_real_lists()
	_snapshot("pre", GameDB.DATA_SEASON, GameState.league_lists)
	GameState.choose_real_club(club)
	_run_draft(GameState.draft, false, GameDB.DATA_SEASON)
	GameState.finish_intake_draft()
	_snapshot("start", GameState.season_year, GameState.season.lists)
	for s in range(seasons):
		var year := GameState.season_year
		while not GameState.season.is_season_over():
			GameState.advance()
		_track(GameState.season.lists, year)
		var rank := 0
		var lad: Array = GameState.season.ladder_sorted()
		for i in range(lad.size()):
			if str(lad[i].get("code", lad[i].get("club", ""))) == club:
				rank = i + 1
		print("USER|%d|%d|%d" % [seed_n, year, rank])
		print("SEASON|%d|%d|done" % [seed_n, year])
		if s == seasons - 1:
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft, true, year)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
		_snapshot("start", GameState.season_year, GameState.season.lists)
