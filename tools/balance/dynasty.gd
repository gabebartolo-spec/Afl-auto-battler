extends RefCounted
## Multi-season careers through the shipped code, to measure how a league's
## strength moves over seasons (docs/COMPETITIVE_BALANCE.md). Measurement
## only: nothing here simulates football or changes a rule.
##
## A career is the real career draft (your club's picks by `policy`, as in
## league_balance.gd), then for every season: GameState.advance() through
## every round and final, the off-season (rivals' contracts, trades and free
## agency; your club does nothing - undecided contracts settle the default
## way as free agency closes), the National Draft (your club picks exactly as
## an AI club would), and the rollover (ageing, development, retirement). A
## career replays exactly from its draft seed. Your club is on autopilot
## throughout: default training plans, the auto-selected side, no trades, no
## free agents, no contract talks. That is the "barely engaging" playtest
## career. With `coach` your club also coaches on match day the way every AI
## club does (see _play_week): engaged with matches, not with the list.
## With `manage` your club works its list every off-season as an attentive
## human would (see _manage): "list" settles contracts and chases free
## agents, "full" also trades up. "none" is the autopilot above.

var lb = load("res://tools/balance/league_balance.gd").new()


## One career of `seasons` seasons. Returns one record per season (see
## `_snapshot`), each with the season's results attached.
func run_career(draft_seed: int, policy: String, seasons: int, top_n := 5, coach := false,
		manage := "none") -> Array:
	var gs := GameDB.get_tree().root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	# The game seeds generated classes, drafts and seasons from a random draw
	# and the clock; a career here takes them from its draft seed, so it
	# replays exactly.
	gs.career_seed = draft_seed
	gs.replay_seed = draft_seed
	var d: Draft = make_upside_draft(draft_seed, top_n) if policy == "upside" else lb.make_draft(draft_seed, policy, top_n)
	var user := d.user_club if d.user_club != "" else str(d.draft_order[0])
	gs.draft = d
	gs.start_season(user, [])
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
		var mgmt := _manage(gs, user, manage)
		if not _offseason(gs, user, mgmt):
			push_error("dynasty: off-season %d of seed %d did not complete" % [y, draft_seed])
			break
		snap["mgmt"] = mgmt
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


# ---------------------------------------------------------------------------
# The attentive human's off-season (`manage`)
# ---------------------------------------------------------------------------
## What a human who works the list does between the Grand Final and the
## National Draft, through the same GameState calls the screens make and
## judging every player only by what the screens show (age, rating, POT),
## here as his expected rating next season (expected_overall). Simple,
## stated rules, not an optimiser:
##   contracts  keep an expiring player who will be in next season's best 26,
##              or a kid (22 or under) with six points or more to grow;
##              offer his asking price (meet a counter) over the term he
##              asks for; let the rest go;
##   trades     ("full") from each rival, the best player 30 or under who
##              would walk into next season's side (3 points or more above
##              its 22nd best): open with the pick a contender misses least,
##              ask what they would need (trade_counter, the trade screen's
##              question) and agree up to twice if it is spare - a pick, or a
##              player outside next season's 26 who is not a kid; at most
##              two trades an off-season;
##   free agents the best on the market over the next two seasons who would
##              make next season's 22: the term he asks for, 10% over his
##              asking price and 5% over the best offer on the table, a final
##              offer 5% over the leader when outbid; at most four, list kept
##              under 41.
## The National Draft, training plans, selection and the weekly cards stay
## as they are for the autopilot club.
func _manage(gs, user: String, manage: String) -> Dictionary:
	var mgmt := {"resigned": 0, "released": 0, "signed": 0, "trades": 0, "trade_in": [], "trade_out": 0}
	if manage == "none" or not gs.offseason_open():
		return mgmt
	_contracts(gs, mgmt)
	if manage == "full":
		_trade_up(gs, user, mgmt)
	_free_agency(gs, mgmt)
	return mgmt


## The `n`th best expected rating next season on `list` (0 = best).
static func nth_value(list: Array, n: int) -> float:
	var values := list.map(func(p): return expected_overall(p, 1))
	values.sort()
	values.reverse()
	return float(values[clampi(n, 0, values.size() - 1)]) if not values.is_empty() else 0.0


## The term a human offers: the one the player asks for (the contract
## screens show it, Contracts.wants).
static func term_for(p: Dictionary) -> int:
	return int(Contracts.wants(p)["years"])


func _contracts(gs, mgmt: Dictionary) -> void:
	var line := nth_value(gs.my_list, 25)
	for p in Contracts.expiring(gs.my_list).duplicate():
		if bool(p.get("resigned", false)):
			continue
		var id := str(p["id"])
		if expected_overall(p, 1) >= line or _kid(p):
			var years := term_for(p)
			var r: Dictionary = gs.resign_player(id, years)
			if str(r.get("answer", "")) == "counter":
				r = gs.offer_contract(id, int(r.get("salary", 0)), years)
			if bool(r.get("ok", false)):
				mgmt["resigned"] += 1
		elif gs.my_list.size() > Contracts.MIN_LIST:
			if bool(gs.release_player(id).get("ok", false)):
				mgmt["released"] += 1


func _trade_up(gs, user: String, mgmt: Dictionary) -> void:
	for club in GameDB.active_clubs(gs.season_year):
		if str(club) == user or int(mgmt["trades"]) >= 2:
			continue
		var line22 := nth_value(gs.my_list, 21)
		var line26 := nth_value(gs.my_list, 25)
		var target := {}
		for q in gs.season.lists.get(club, []):
			var v := expected_overall(q, 1)
			if v >= line22 + 3.0 and float(q.get("age", 30.0)) <= 30.0 \
					and (target.is_empty() or v > expected_overall(target, 1)):
				target = q
		if target.is_empty():
			continue
		var tid := str(target["id"])
		# Open with the pick a contender misses least, then ask what they'd
		# need (trade_counter, the trade screen's own question) and agree
		# only to spare assets: a pick, or a player outside next season's
		# 26 who is not a kid still growing.
		var picks: Array = gs.club_picks(user)
		picks.sort_custom(func(a, b):
			if int(a["round"]) != int(b["round"]):
				return int(a["round"]) > int(b["round"])
			return int(a["year"]) > int(b["year"]))
		if picks.is_empty():
			continue
		var pkg := [str(picks[0]["id"])]
		# A rival at the list minimum needs a body back.
		if (gs.season.lists.get(club, []) as Array).size() <= Contracts.MIN_LIST:
			var spares: Array = gs.my_list.filter(func(q): return _spare(q, line26))
			if spares.is_empty():
				continue
			spares.sort_custom(func(a, b): return expected_overall(a, 1) < expected_overall(b, 1))
			pkg.push_front(str(spares[0]["id"]))
		var given_starter := false
		for step in range(3):
			if bool(gs.evaluate_trade(str(club), pkg, [tid]).get("ok", false)):
				var gave := []
				for id in pkg:
					var q: Dictionary = gs.list_player(str(id))
					gave.append(str(id) if q.is_empty() else "%d/%d age %d" % [int(q["overall"]),
							int(q.get("potential", 0)), int(float(q.get("age", 0.0)))])
				if bool(gs.make_trade(str(club), pkg, [tid]).get("ok", false)):
					mgmt["trades"] += 1
					mgmt["trade_in"].append(int(target["overall"]))
					mgmt["trade_out"] += pkg.size()
					mgmt["trade_log"] = mgmt.get("trade_log", []) + ["%s: %d/%d age %d for %s (%s)" % [str(club),
							int(target["overall"]), int(target.get("potential", 0)), int(float(target.get("age", 0.0))),
							", ".join(gave), gs.club_phase(str(club))]]
				break
			if step == 2:
				break
			var c: Dictionary = gs.trade_counter(str(club), pkg, [tid])
			if c.is_empty() or not (c.get("theirs", []) as Array).has(tid):
				break
			# Agree if what they add is spare, or one of your starters the
			# target is clearly better than (3 points or more next season):
			# a lesser player and a pick for a better one.
			var agree := true
			for id in c["mine"]:
				if pkg.has(id) or str(id).begins_with("pick:"):
					continue
				var q: Dictionary = gs.list_player(str(id))
				if q.is_empty():
					agree = false
				elif not _spare(q, line26):
					var upgrade := not _kid(q) and not given_starter \
							and expected_overall(q, 1) <= expected_overall(target, 1) - 3.0
					given_starter = given_starter or upgrade
					agree = agree and upgrade
			if not agree:
				break
			pkg = (c["mine"] as Array).duplicate()


## A kid still growing: 22 or under with six points or more to his POT.
static func _kid(q: Dictionary) -> bool:
	return float(q.get("age", 25.0)) <= 22.0 and int(q.get("potential", 0)) - int(q.get("overall", 0)) >= 6


## A player a club can spare: outside next season's best 26, and not a kid.
static func _spare(q: Dictionary, line26: float) -> bool:
	return expected_overall(q, 1) < line26 and not _kid(q)


## A free agent as a human weighs him for the next two seasons.
static func two_year_value(p: Dictionary) -> float:
	return 0.5 * (expected_overall(p, 1) + expected_overall(p, 2))


func _free_agency(gs, mgmt: Dictionary) -> void:
	var offers := 0
	var market: Array = gs.free_agents.duplicate()
	market.sort_custom(func(a, b): return two_year_value(a) > two_year_value(b))
	for p in market:
		if offers >= 4 or gs.my_list.size() >= 41:
			break
		var id := str(p["id"])
		if expected_overall(p, 1) <= nth_value(gs.my_list, 21) or gs.free_agent(id).is_empty() \
				or bool(gs.free_agent_terms(id).get("refuse", false)):
			continue
		var years := term_for(p)
		# Bid to win: over his asking price and over the best offer on the
		# table (the market screen shows both).
		var table: Array = gs.fa_offers(id)
		var lead := int(table[0]["salary"]) if not table.is_empty() else 0
		var bid := mini(gs.cap_room(), maxi(int(float(Contracts.asking_salary(p)) * 1.1), int(float(lead) * 1.05)))
		if bid < Contracts.asking_salary(p):
			continue
		offers += 1
		mgmt["bids"] = int(mgmt.get("bids", 0)) + 1
		var r: Dictionary = gs.offer_free_agent(id, bid, years)
		if str(r.get("answer", "")) == "counter" and int(r.get("salary", 0)) <= gs.cap_room():
			r = gs.offer_free_agent(id, int(r["salary"]), years)
		if str(r.get("answer", "")) == "table":
			table = gs.fa_offers(id)
			if not table.is_empty() and not bool(table[0]["mine"]):
				var final_bid := mini(gs.cap_room(), int(float(table[0]["salary"]) * 1.05))
				if final_bid > bid:
					r = gs.offer_free_agent(id, final_bid, years)
		mgmt["fa_answers"] = mgmt.get("fa_answers", []) + [str(r.get("answer", ""))]


## The off-season's close: free agency settles (begin_intake_draft), the
## National Draft (your picks as the AI would make them), then the rollover.
## Your club's signings are counted into `mgmt` as free agency closes.
func _offseason(gs, user: String, mgmt: Dictionary) -> bool:
	var drafting: bool = gs.begin_intake_draft()
	for e in gs.offseason_log:
		if str(e.get("kind", "")) == "signed" and str(e.get("club", "")) == user:
			mgmt["signed"] += 1
	if not drafting:
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
