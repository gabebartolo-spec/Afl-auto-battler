extends RefCounted
## Lever-truth audit, part 2: contracts, trades, the draft and scouting
## (docs/research/LEVER_TRUTH_AUDIT_2.md). Measurement only: nothing here
## changes a rule.
##
## One League Draft career per seed (dynasty.gd's upside draft, your club on
## autopilot at matches). Every season prints what the levers need:
##   SEASON  your ladder, list-strength rank, payroll and cap room;
##   CAP     every club's payroll against the cap, and how many players
##           clubs let go because the cap had no room for them;
##   PICK    every National Draft pick: slot, the AI's price for that slot
##           (TradeValue.pick_value, a building club), the player's rating
##           and POT on draft night; TRACK lines follow him each season;
##   PROBE   trade offers asked of every rival and never made
##           (evaluate_trade only): quantity for quality, an old star for
##           their best kid (both then tracked, to judge in hindsight), and
##           the best player each of your picks buys on its own.
## Arms (paired on seeds; one changes, everything else is the same):
##   L2_TRADE   list (default) | full | exploit: dynasty.gd's off-season;
##   L2_TERM    ask (default) | short | long: the term your club gives a kid
##              (23 or under) it re-signs - one season, or four;
##   L2_RECRUIT -1 (default, Standard) | 0..3: your recruiting budget level,
##              set directly so no other department pays for it.
## Args after the impl name: seeds (comma-separated) seasons.

var dyn = load("res://tools/balance/dynasty.gd").new()
var trade_mode := "list"
var term_mode := "ask"
var recruit := -1
## id -> true: players followed every season (draftees, probe pairs, kids).
var tracked := {}


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := str(args[1]) if args.size() > 1 else "301"
	var seasons := int(args[2]) if args.size() > 2 else 4
	trade_mode = OS.get_environment("L2_TRADE") if OS.get_environment("L2_TRADE") != "" else "list"
	term_mode = OS.get_environment("L2_TERM") if OS.get_environment("L2_TERM") != "" else "ask"
	recruit = int(OS.get_environment("L2_RECRUIT")) if OS.get_environment("L2_RECRUIT") != "" else -1
	print("ARMS trade %s term %s recruit %d" % [trade_mode, term_mode, recruit])
	for sd in seeds.split(",", false):
		_career(int(sd), seasons)


func _career(seed: int, seasons: int) -> void:
	var gs := GameDB.get_tree().root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	gs.career_seed = seed
	gs.replay_seed = seed
	tracked = {}
	var d: Draft = dyn.make_upside_draft(seed, 5)
	var user := d.user_club if d.user_club != "" else str(d.draft_order[0])
	gs.draft = d
	gs.start_season(user, [])
	var totals := {"ladder": 0, "rank": 0, "seasons": 0, "fa": 0, "trades": 0, "resigned": 0, "asked_out": 0}
	for y in range(seasons):
		_set_recruit(gs)
		_track(gs, seed, "start")
		var strength_rank := _rank(gs, user)
		while not gs.season.is_season_over():
			dyn._play_week(gs, user, false)
		var ladder := _ladder_pos(gs, user)
		_track(gs, seed, "end")
		print("SEASON seed %d year %d club %s ladder %d rank %d payroll %d cap %d room %d list %d" % [
				seed, gs.season_year, user, ladder, strength_rank, gs.my_payroll(), gs.salary_cap,
				gs.cap_room(), (gs.my_list as Array).size()])
		totals["ladder"] += ladder
		totals["rank"] += strength_rank
		totals["seasons"] += 1
		if y == seasons - 1:
			break
		gs.open_offseason()
		_set_recruit(gs)
		_cap_lines(gs, seed)
		var asked := 0
		for id in gs.trade_requests:
			if str(gs.trade_requests[id]["club"]) == user:
				asked += 1
		totals["asked_out"] += asked
		_probes(gs, seed, user)
		var mgmt := _manage(gs, user)
		totals["trades"] += int(mgmt["trades"])
		totals["resigned"] += int(mgmt["resigned"])
		gs.set_selection({})
		if not _offseason(gs, seed, user, mgmt):
			push_error("levers2: off-season %d of seed %d did not complete" % [y, seed])
			break
		totals["fa"] += int(mgmt["signed"])
		print("OFFSEASON seed %d year %d resigned %d released %d signed %d trades %d asked_out %d kids %s" % [
				seed, gs.season_year - 1, int(mgmt["resigned"]), int(mgmt["released"]), int(mgmt["signed"]),
				int(mgmt["trades"]), asked, str(mgmt.get("kid_terms", []))])
	var n := float(maxi(1, int(totals["seasons"])))
	print("SUMMARY seed %d club %s trade %s term %s recruit %d ladder %.2f rank %.2f trades %d fa %d resigned %d asked_out %d" % [
			seed, user, trade_mode, term_mode, recruit, float(totals["ladder"]) / n, float(totals["rank"]) / n,
			int(totals["trades"]), int(totals["fa"]), int(totals["resigned"]), int(totals["asked_out"])])


func _set_recruit(gs) -> void:
	if recruit >= 0:
		gs.department_budget["recruiting"] = recruit


func _ladder_pos(gs, user: String) -> int:
	var rows: Array = gs.season.ladder_sorted()
	for i in range(rows.size()):
		if str(rows[i]["code"]) == user:
			return i + 1
	return 0


## Your list's strength rank among the league's (Squad.strength, 1 = best).
func _rank(gs, user: String) -> int:
	var mine := 0.0
	var vals := []
	for c in GameDB.active_clubs(gs.season_year):
		var v := Squad.new(str(c), gs.season.lists.get(c, []), true, str(c)).strength()
		vals.append(v)
		if str(c) == user:
			mine = v
	var r := 1
	for v in vals:
		if float(v) > mine:
			r += 1
	return r


# ---------------------------------------------------------------------------
# Contracts and the cap
# ---------------------------------------------------------------------------
func _cap_lines(gs, seed: int) -> void:
	var cap: int = gs.salary_cap
	var rooms := []
	for c in GameDB.active_clubs(gs.season_year):
		rooms.append(cap - Contracts.payroll(gs.season.lists.get(c, [])))
	rooms.sort()
	var cap_out := 0
	var wanted_out := 0
	for e in gs.offseason_log:
		if str(e.get("kind", "")) != "released":
			continue
		if bool(e.get("wanted", false)):
			wanted_out += 1
	# Expiring players a rival would keep but cannot afford (the "cap" reason).
	for c in GameDB.active_clubs(gs.season_year):
		if str(c) == gs.my_club:
			continue
		var list: Array = gs.season.lists.get(c, [])
		for p in Contracts.expiring(list):
			if Contracts.ai_release_reason(p, list, cap) == "cap":
				cap_out += 1
	print("CAP seed %d year %d cap %d room_min %d room_med %d room_max %d my_room %d wanted_released %d cap_blocked_now %d" % [
			seed, gs.season_year, cap, int(rooms[0]), int(rooms[rooms.size() / 2]), int(rooms[rooms.size() - 1]),
			gs.cap_room(), wanted_out, cap_out])


## dynasty.gd's attentive human, with one change: the term a kid (23 or
## under) is offered when he is re-signed (L2_TERM).
func _manage(gs, user: String) -> Dictionary:
	var mgmt := {"resigned": 0, "released": 0, "signed": 0, "trades": 0, "trade_in": [], "trade_out": 0}
	if not gs.offseason_open():
		return mgmt
	var line: float = dyn.nth_value(gs.my_list, 25)
	var kid_terms := []
	for p in Contracts.expiring(gs.my_list).duplicate():
		if bool(p.get("resigned", false)):
			continue
		var id := str(p["id"])
		if dyn.expected_overall(p, 1) >= line or dyn._kid(p):
			var years := int(Contracts.wants(p)["years"])
			var kid := float(p.get("age", 30.0)) <= 23.0
			if kid and term_mode == "short":
				years = 1
			elif kid and term_mode == "long":
				years = Contracts.MAX_YEARS
			var r: Dictionary = gs.resign_player(id, years)
			if str(r.get("answer", "")) == "counter":
				r = gs.offer_contract(id, int(r.get("salary", 0)), years)
			if bool(r.get("ok", false)):
				mgmt["resigned"] += 1
				if kid:
					tracked[id] = true
					kid_terms.append("%s:%d@%d/%d" % [id, years, int(p.get("salary", 0)), int(p["overall"])])
		elif (gs.my_list as Array).size() > Contracts.MIN_LIST:
			if bool(gs.release_player(id).get("ok", false)):
				mgmt["released"] += 1
	mgmt["kid_terms"] = kid_terms
	if trade_mode == "full":
		dyn._trade_up(gs, user, mgmt)
	elif trade_mode == "exploit":
		dyn._exploit(gs, user, mgmt)
	dyn._free_agency(gs, mgmt)
	return mgmt


# ---------------------------------------------------------------------------
# The draft
# ---------------------------------------------------------------------------
## dynasty.gd's off-season close (free agency settles, the National Draft
## with your picks made as the AI makes them, the rollover), printing every
## pick on draft night, before the rollover develops anyone.
func _offseason(gs, seed: int, user: String, mgmt: Dictionary) -> bool:
	var drafting: bool = gs.begin_intake_draft()
	for e in gs.offseason_log:
		if str(e.get("kind", "")) == "signed" and str(e.get("club", "")) == user:
			mgmt["signed"] += 1
	if not drafting:
		return gs.start_next_season()
	var d: Draft = gs.draft
	var prices := {}
	var ranked := TradeValue.rank_prospects(d.pool)
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var code := d.current_club()
		var c: Dictionary = d._best_ai_pick(code)
		if c.is_empty() or not d._draft_pick(code, c):
			d._skip_current_pick()
	var rows := []
	for code in d.club_lists:
		for p in d.club_lists[code]:
			var det := d.pick_details(str(p["id"]))
			if int(det.get("pick", 0)) > 0:
				rows.append([int(det["pick"]), int(det.get("round", 0)), str(code), p])
	rows.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for r in rows:
		var p: Dictionary = r[3]
		var id := str(p["id"])
		tracked[id] = true
		var spot := int(r[0])
		if not prices.has(spot):
			prices[spot] = TradeValue.pick_value([[spot, 1.0]], ranked, "building")
		print("PICK seed %d year %d pick %d round %d club %s mine %d id %s age %.1f ovr %d pot %d role %s price %.3f" % [
				seed, gs.season_year, spot, int(r[1]), str(r[2]), 1 if str(r[2]) == user else 0, id,
				float(p.get("age", 0.0)), int(p["overall"]), int(p.get("potential", 0)), str(p.get("role", "")),
				float(prices[spot])])
	return gs.start_next_season()


## Every tracked player: where he is, his rating and POT, and at season's
## end the games he played and whether his club picks him in its 22.
func _track(gs, seed: int, when: String) -> void:
	if tracked.is_empty():
		return
	var in22 := {}
	if when == "start":
		for c in GameDB.active_clubs(gs.season_year):
			var side := Ratings.select_22(gs.season.lists.get(c, []))
			for q in (side["ground"] as Array) + (side["bench"] as Array):
				in22[str(q["id"])] = true
	var ids := tracked.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = gs._find_player(str(id))
		if p.is_empty():
			if when == "start":
				print("TRACK seed %d year %d %s id %s gone" % [seed, gs.season_year, when, str(id)])
			continue
		var games := int((gs.season_tally.get(str(id), {}) as Dictionary).get("games", 0)) if when == "end" else -1
		print("TRACK seed %d year %d %s id %s club %s age %.1f ovr %d pot %d salary %d years %d in22 %d games %d" % [
				seed, gs.season_year, when, str(id), str(p.get("club", "")), float(p.get("age", 0.0)),
				int(p["overall"]), int(p.get("potential", 0)), int(p.get("salary", 0)),
				int(p.get("contract_years", 0)), 1 if in22.has(str(id)) else 0, games])


# ---------------------------------------------------------------------------
# Trade probes: asked, never made
# ---------------------------------------------------------------------------
func _probes(gs, seed: int, user: String) -> void:
	var line26: float = dyn.nth_value(gs.my_list, 25)
	var spares: Array = (gs.my_list as Array).filter(func(q): return dyn._spare(q, line26))
	spares.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var vets: Array = (gs.my_list as Array).filter(func(q): return float(q.get("age", 0.0)) >= 30.0)
	vets.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var picks: Array = gs.club_picks(user)
	var this_year: Array = picks.filter(func(pk): return int(pk["year"]) == int(gs.season_year))
	for club in GameDB.active_clubs(gs.season_year):
		if str(club) == user:
			continue
		var phase: String = gs.club_phase(str(club))
		var list: Array = gs.season.lists.get(club, [])
		var by_ovr := list.duplicate()
		by_ovr.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
		# 1. Quantity for quality: their best player for 2..5 of your best spares.
		var star: Dictionary = by_ovr[0]
		var bought := 0
		for n in range(2, mini(5, spares.size()) + 1):
			var pkg: Array = spares.slice(0, n).map(func(q): return str(q["id"]))
			if bool(gs.evaluate_trade(str(club), pkg, [str(star["id"])]).get("ok", false)):
				bought = n
				break
		var spare_ovr := 0.0
		for q in spares.slice(0, 5):
			spare_ovr += float(q["overall"])
		print("PROBE qty seed %d year %d club %s phase %s star %d/%d age %.0f spares_mean %.1f accepted_at %d" % [
				seed, gs.season_year, str(club), phase, int(star["overall"]), int(star.get("potential", 0)),
				float(star.get("age", 0.0)), spare_ovr / float(maxi(1, mini(5, spares.size()))), bought])
		# 2. An old star for their best kid (22 or under, the most POT), and
		# the same kid for your best spare; both sides then tracked.
		var kids: Array = list.filter(func(q): return float(q.get("age", 30.0)) <= 22.0 \
				and int(q.get("potential", 0)) - int(q["overall"]) >= 6)
		kids.sort_custom(func(a, b): return int(a.get("potential", 0)) > int(b.get("potential", 0)))
		if not kids.is_empty() and not vets.is_empty():
			var kid: Dictionary = kids[0]
			for v in vets.slice(0, 2):
				var r: Dictionary = gs.evaluate_trade(str(club), [str(v["id"])], [str(kid["id"])])
				tracked[str(kid["id"])] = true
				tracked[str(v["id"])] = true
				print("PROBE vet seed %d year %d club %s phase %s kid %s %d/%d age %.1f vet %s %d/%d age %.1f ok %d reason %s" % [
						seed, gs.season_year, str(club), phase, str(kid["id"]), int(kid["overall"]),
						int(kid.get("potential", 0)), float(kid.get("age", 0.0)), str(v["id"]), int(v["overall"]),
						int(v.get("potential", 0)), float(v.get("age", 0.0)), 1 if bool(r.get("ok", false)) else 0,
						_short(str(r.get("reason", ""))).replace(" ", "_")])
		# 3. What each of this year's picks buys alone: their best player
		# (by rating, any age) the club would give for it.
		for pk in this_year:
			var spot := int(pk["positions"][0][0])
			var got := {}
			for q in by_ovr.slice(0, 20):
				if bool(gs.evaluate_trade(str(club), [str(pk["id"])], [str(q["id"])]).get("ok", false)):
					got = q
					break
			print("PROBE pick seed %d year %d club %s phase %s round %d spot %d buys %s" % [
					seed, gs.season_year, str(club), phase, int(pk["round"]), spot,
					"none" if got.is_empty() else "%d/%d age %.1f" % [int(got["overall"]),
					int(got.get("potential", 0)), float(got.get("age", 0.0))]])


func _short(reason: String) -> String:
	if reason == "They accept.":
		return "yes"
	if reason.contains("well short"):
		return "well short"
	if reason.contains("a little short"):
		return "a little short"
	if reason.contains("rebuilding"):
		return "rebuilding cornerstone"
	if reason.contains("get a game"):
		return "benchwarmer"
	if reason.contains("cap"):
		return "cap"
	if reason.contains("list"):
		return "list size"
	return reason.left(24)
