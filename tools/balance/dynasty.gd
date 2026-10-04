extends RefCounted
## Multi-season careers through the shipped code, to measure how a league's
## strength moves over seasons (docs/COMPETITIVE_BALANCE.md). Measurement
## only: nothing here simulates football or changes a rule.
##
## A career is the real career draft (your club's picks by `policy`, as in
## league_balance.gd), then for every season: GameState.advance() through
## every round and final, the off-season (rivals' contracts, trades and free
## agency; your club does nothing - undecided contracts roll over the default
## way), the National Draft (your club picks exactly as an AI club would), and
## the rollover (ageing, development, retirement). Your club is on autopilot
## throughout: default training plans, the auto-selected side, no trades, no
## free agents, no contract talks. That is the "barely engaging" playtest
## career. With `coach` your club also coaches on match day the way every AI
## club does (see _play_week): engaged with matches, not with the list.

var lb = load("res://tools/balance/league_balance.gd").new()


## One career of `seasons` seasons. Returns one record per season (see
## `_snapshot`), each with the season's results attached.
func run_career(draft_seed: int, policy: String, seasons: int, top_n := 5, coach := false) -> Array:
	var gs := GameDB.get_tree().root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	var d: Draft = make_upside_draft(draft_seed, top_n) if policy == "upside" else lb.make_draft(draft_seed, policy, top_n)
	var user := d.user_club if d.user_club != "" else str(d.draft_order[0])
	gs.draft = d
	gs.start_season(user, [])
	gs.season.seed = draft_seed * 1000 + 1
	gs._next_week_event()
	var out := []
	for y in range(seasons):
		var snap := _snapshot(gs, user)
		var coached := 0
		while not gs.season.is_season_over():
			coached += 1 if _play_week(gs, user, coach) else 0
		var rows: Array = gs.season.ladder_sorted()
		var ladder := {}
		for i in range(rows.size()):
			ladder[str(rows[i]["code"])] = i + 1
		snap["ladder"] = ladder
		snap["premier"] = str(gs.season.finals.get("premier", ""))
		snap["user_ladder"] = int(ladder.get(user, 0))
		snap["coached"] = coached
		# The end of the season, every club: its selected side's morale, and
		# what training added to its list this season.
		var end_morale := {}
		var gain := {}
		for c in snap["clubs"]:
			var list: Array = gs.season.lists.get(c, [])
			end_morale[c] = morale22(Squad.new(str(c), list, true, str(c)))
			var g := 0.0
			for p in list:
				g += float(p["overall"]) - float(p.get("season_start_ov", p["overall"]))
			gain[c] = g / float(maxi(1, list.size()))
		snap["morale_end"] = end_morale
		snap["train_gain"] = gain
		out.append(snap)
		if y == seasons - 1:
			break
		if not _offseason(gs, user):
			push_error("dynasty: off-season %d of seed %d did not complete" % [y, draft_seed])
			break
		gs.season.seed = draft_seed * 1000 + y + 2
	return out


## One round or finals week. With `coach`, your match is played through the
## live-match path with your side coached as MatchSim coaches an AI club: a
## loose interceptor from the first bounce, then a plan picked each quarter
## from the score and what it has seen, and match-ups re-set at the breaks.
## Moment cards take their default call (MatchSim.run). Everything else is
## exactly advance(). True when your match was coached.
func _play_week(gs, user: String, coach: bool) -> bool:
	if not coach or not _has_match(gs, user) or not gs.prepare_interactive_match():
		gs.advance()
		return false
	var sim: MatchSim = gs.pending_sim
	var side: int = sim.moment_side
	var sq: Squad = sim.squads[side]
	sq.ai_plans = true
	var best := Matchups.best_interceptor(sq.ground)
	if not best.is_empty():
		sim.set_interceptor(side, str(best["id"]), false)
	gs.finish_interactive_match(sim.run())
	return true


## Whether your club plays this round or finals week.
func _has_match(gs, user: String) -> bool:
	var season: Season = gs.season
	var matches: Array = []
	if not season.is_regular_done():
		matches = season.fixture[season.round_index]
	else:
		gs.ensure_finals()
		matches = season.finals_week_matches()
	for m in matches:
		if (str(m["home"]) == user and str(m["away"]) != "") or (str(m["away"]) == user and str(m["home"]) != ""):
			return true
	return false


## The off-season with your club on autopilot: the National Draft (your
## picks as the AI would make them), then the rollover.
func _offseason(gs, user: String) -> bool:
	if not gs.begin_intake_draft():
		return gs.start_next_season()
	var d: Draft = gs.draft
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var code := d.current_club()
		var c: Dictionary = d._best_ai_pick(code)
		if c.is_empty() or not d._draft_pick(code, c):
			d._skip_current_pick()
	return gs.start_next_season()


## Every club at the start of a season (before round 1): its auto-selected
## side's strength, ages, synergies, List Profile words, payroll.
func _snapshot(gs, user: String) -> Dictionary:
	var codes: Array = GameDB.active_clubs(gs.season_year)
	var grounds := {}
	var clubs := {}
	for c in codes:
		var list: Array = gs.season.lists.get(c, [])
		var sq := Squad.new(str(c), list, true, str(c))
		grounds[c] = sq.ground
		var age22 := 0.0
		var ovr22 := 0.0
		var n := 0
		for p in sq.ground + sq.bench:
			age22 += float(p.get("age", 25.0))
			ovr22 += float(p["overall"])
			n += 1
		var ovrs := list.map(func(p): return float(p["overall"]))
		ovrs.sort()
		ovrs.reverse()
		clubs[c] = {
			"strength": sq.strength(),
			"ovr22": ovr22 / float(maxi(1, n)),
			"age22": age22 / float(maxi(1, n)),
			"top5": lb.mean(ovrs.slice(0, 5)),
			"size": list.size(),
			"payroll": Contracts.payroll(list),
			"synergies": Traits.active(sq.ground),
			"stars": ovrs.filter(func(v): return v >= 80.0).size(),
			"morale22": morale22(sq),
		}
	var by_strength := codes.duplicate()
	by_strength.sort_custom(func(a, b): return float(clubs[a]["strength"]) > float(clubs[b]["strength"]))
	for i in range(by_strength.size()):
		clubs[by_strength[i]]["rank"] = i + 1
	for c in codes:
		var elite := 0
		var strong := 0
		for row in ListProfile.profile(grounds, str(c)):
			if str(row["word"]) == "Elite":
				elite += 1
			elif str(row["word"]) == "Strong":
				strong += 1
		clubs[c]["elite"] = elite
		clubs[c]["strong"] = strong
	return {"year": gs.season_year, "user": user, "cap": gs.salary_cap, "clubs": clubs}


## Mean morale of a selected side (ground and bench).
static func morale22(sq: Squad) -> float:
	var total := 0.0
	var n := 0
	for p in sq.ground + sq.bench:
		total += float(ClubLife.morale(p))
		n += 1
	return total / float(maxi(1, n))


## The rating a player can be expected to have `years` seasons on, from the
## game's own development bands (Prospects.age_player: mean of each age band)
## and growth toward his POT, never past it. Public information only.
static func expected_overall(p: Dictionary, years: int) -> float:
	var ov := float(p["overall"])
	var pot := maxf(ov, float(p.get("potential", ov)))
	var age := float(p.get("age", 25.0))
	for y in range(years):
		age += 1.0
		var d := 0.0
		if age <= 20.0:
			d = 4.25
		elif age <= 23.0:
			d = 2.5
		elif age <= 27.0:
			d = 1.0
		elif age <= 30.0:
			d = 0.0
		elif age <= 33.0:
			d = -1.5
		else:
			d = -3.75
		if d > 0.0:
			d = minf(d, maxf(0.0, pot - ov))
		ov += d
	return ov


## A human who drafts for the next three seasons rather than this one: at
## each of your turns, a seeded pick among the `top_n` legal players with the
## best expected rating averaged over this season and the next two.
func make_upside_draft(seed: int, top_n := 3) -> Draft:
	var d := Draft.new(GameDB.all_players_sorted(), lb.clubs(), seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + 7
	var user := str(d.draft_order[rng.randi_range(0, d.draft_order.size() - 1)])
	d.start_for_user(user)
	while not d.is_finished():
		var legal := []
		for p in d.board("", "", "", "overall", true):
			if d.can_pick_player(p):
				legal.append(p)
		legal.sort_custom(func(a, b):
			return (expected_overall(a, 0) + expected_overall(a, 1) + expected_overall(a, 2)) \
					> (expected_overall(b, 0) + expected_overall(b, 1) + expected_overall(b, 2)))
		var options := legal.slice(0, top_n)
		if options.is_empty() or not d.pick(options[rng.randi_range(0, options.size() - 1)]):
			d._skip_current_pick()
			d.auto_until_user_turn()
	return d
