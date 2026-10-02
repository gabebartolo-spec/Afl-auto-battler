extends RefCounted
## Contracts, free agency and trades. Run through tests/run_contracts_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_initial_contracts()
	_test_real_money_scale()
	_test_offseason_flow()
	_test_negotiation_rules()
	_test_negotiation()
	_test_free_agent_terms()
	_test_free_agents()
	_test_compensation_rules()
	_test_compensation_draft_order()
	_test_compensation_flow()
	_test_trade_value()
	_test_trade_packages_and_needs()
	_test_phase_cache()
	_test_trade_picks()
	_test_future_picks()
	GameState.delete_saved_career()
	print("Contracts tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _new_season() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))


func _to_offseason() -> void:
	GameState.season.round_index = GameState.season.fixture.size()
	GameState.ensure_finals()
	while not GameState.season.is_season_over():
		GameState.advance()


func _test_real_money_scale() -> void:
	_new_season()
	_check(GameState.salary_cap == Contracts.CAP_2027,
			"A 2027 career uses the real $18.44m AFL cap (%d)" % GameState.salary_cap)
	_check(Ratings.salary_value(40) == Contracts.SENIOR_MIN_2027
			and Ratings.salary_value(90) >= 1000000,
			"The salary curve runs from the senior floor to $1m+ stars")
	_check(Contracts.money(155000) == "$155k" and Contracts.money(1200000) == "$1.2m"
			and Contracts.money(Contracts.CAP_2027).begins_with("$18.44m"),
			"Money is compact enough for a phone")
	for row in [[1, 150000], [11, 140000], [21, 130000], [51, 125000]]:
		var p := {"draft_pick": int(row[0])}
		Contracts.rookie_deal(p, 2027)
		_check(int(p["salary"]) == int(row[1]),
				"Pick %d gets the 2027 first-year base (%d)" % [int(row[0]), int(p["salary"])])
	_check(Contracts.old_points_to_salary(1) == 155000
			and Contracts.old_points_to_salary(10) == 1250000,
			"Old 1-10 salary points have a deterministic dollar migration")


func _test_initial_contracts() -> void:
	_new_season()
	var all_have := true
	var under := true
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			if not p.has("contract_years") or not p.has("salary"):
				all_have = false
		if Contracts.payroll(GameState.season.lists[code]) > GameState.salary_cap:
			under = false
	_check(all_have, "Every player starts on a contract")
	_check(GameState.salary_cap > 0 and under, "Every club starts under the cap")
	_check(not GameState.offseason_open(), "Trades are closed during the season")
	_check(not bool(GameState.release_player(str(GameState.my_list[0]["id"]))["ok"]),
			"Nobody can be released mid-season")


func _test_offseason_flow() -> void:
	_new_season()
	_to_offseason()
	_check(GameState.offseason_open(), "The off-season opens after the Grand Final")
	var ai_settled := true
	for code in GameState.season.lists:
		if code == GameState.my_club:
			continue
		for p in Contracts.expiring(GameState.season.lists[code]):
			if not bool(p.get("resigned", false)):
				ai_settled = false
	_check(ai_settled, "Rivals settle every expiring contract at once")
	_check(GameState.free_agents.size() > 0, "Rivals let some players go to free agency")

	# Re-sign one of yours, release another.
	var mine := Contracts.expiring(GameState.my_list)
	_check(mine.size() > 0, "Some of your players are out of contract")
	var keep: Dictionary = mine[0]
	var r := GameState.resign_player(str(keep["id"]), 3)
	_check(bool(r["ok"]) and int(keep["contract_years"]) == 4 and int(keep["salary"]) == Contracts.asking_salary(keep),
			"Re-signing sets the new term and price")
	var saved_cap := GameState.salary_cap
	GameState.salary_cap = GameState.my_payroll()
	var dear: Dictionary = mine[mine.size() - 1] if mine.size() > 1 else keep
	if not bool(dear.get("resigned", false)) and Contracts.asking_salary(dear) > int(dear.get("salary", 0)):
		_check(not bool(GameState.resign_player(str(dear["id"]), 2)["ok"]),
				"A raise past the cap is refused")
	GameState.salary_cap = saved_cap
	# Sign the best free agent we can afford.
	var signed := false
	GameState.salary_cap += 5000000
	# A free agent no other club has offered for signs at his asking price;
	# where rivals have offered, your offer goes on the table instead.
	for fa in GameState.free_agents.duplicate():
		if str(fa.get("released_by", "")) != GameState.my_club and (fa.get("offers", []) as Array).is_empty() \
				and not bool(GameState.free_agent_terms(str(fa["id"]))["refuse"]):
			var res := GameState.sign_free_agent(str(fa["id"]), int(Contracts.wants(fa)["years"]))
			signed = bool(res["ok"]) and GameState.list_player(str(fa["id"])) == fa \
					and str(fa["club"]) == GameState.my_club
			break
	_check(signed, "A free agent can be signed onto your list")
	# (The 2026 Geelong list is at the 32 minimum, so release after signing.)
	var size_before := GameState.my_list.size()
	var gone: Dictionary = GameState.my_list[GameState.my_list.size() - 1]
	var rel := GameState.release_player(str(gone["id"]))
	_check(bool(rel["ok"]) and GameState.my_list.size() == size_before - 1
			and GameState.free_agents.has(gone), "A released player goes to free agency")


	# Trades: two middling players never buy a star; a fair swap does.
	var rival := "COL"
	var their_best: Dictionary = {}
	for p in GameState.season.lists[rival]:
		if their_best.is_empty() or int(p["overall"]) > int(their_best["overall"]):
			their_best = p
	var sorted_mine := GameState.my_list.duplicate()
	sorted_mine.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	var two_weak := [str(sorted_mine[0]["id"]), str(sorted_mine[1]["id"])]
	_check(not bool(GameState.evaluate_trade(rival, two_weak, [str(their_best["id"])])["ok"]),
			"Two fringe players do not buy a star")
	var my_best: Dictionary = sorted_mine[sorted_mine.size() - 1]
	var their_weak: Dictionary = {}
	for p in GameState.season.lists[rival]:
		if their_weak.is_empty() or int(p["overall"]) < int(their_weak["overall"]):
			their_weak = p
	GameState.set_selection(GameState.current_side())
	var t := GameState.make_trade(rival, [str(my_best["id"])], [str(their_weak["id"])])
	_check(bool(t["ok"]), "Overpaying gets a trade done (%s)" % str(t["reason"]))
	_check(str(my_best["club"]) == rival and str(their_weak["club"]) == GameState.my_club
			and GameState.season.lists[rival].has(my_best) and GameState.my_list.has(their_weak),
			"Traded players change lists and clubs")
	var still_named := false
	for key in GameState.my_selection():
		if (GameState.my_selection()[key] as Array).has(str(my_best["id"])):
			still_named = true
	_check(not still_named, "A traded player leaves your selection")

	GameState.save_career()
	GameState.load_career()
	_check(GameState.offseason_open() and GameState.salary_cap > 0,
			"The off-season, cap and free agents survive a save")

	GameState.start_next_season()
	var ticked := true
	var sizes_ok := true
	for code in GameState.season.lists:
		if GameDB.enter_year(code) > GameState.season_year:
			# Not an active club yet - its debut list arrives at entry.
			continue
		var list: Array = GameState.season.lists[code]
		if list.size() < Contracts.MIN_LIST or list.size() > Contracts.MAX_LIST:
			sizes_ok = false
		for p in list:
			if int(p.get("contract_years", 0)) < 1 or p.has("resigned"):
				ticked = false
	_check(ticked, "Every contract ticks down at the rollover")
	_check(sizes_ok, "Every list stays between %d and %d" % [Contracts.MIN_LIST, Contracts.MAX_LIST])
	_check(GameState.free_agents.is_empty(), "Unsigned free agents leave at the rollover")
	_check(is_same(GameState.my_list, GameState.season.lists[GameState.my_club]),
			"Your list is the season's list after the rollover")


## ARD-M6-004: what a player wants is shown; how far he bends follows his
## leverage and the term; the same offer always gets the same answer.
func _test_negotiation_rules() -> void:
	var star := {"id": "n_star", "overall": 84, "potential": 86, "age": 26.0, "morale": 70}
	var regular := {"id": "n_reg", "overall": 70, "potential": 72, "age": 27.0, "morale": 70}
	var fringe := {"id": "n_fringe", "overall": 52, "potential": 55, "age": 31.0, "morale": 70}
	var kid := {"id": "n_kid", "overall": 66, "potential": 85, "age": 21.0, "morale": 70}
	_check(int(Contracts.wants(regular)["years"]) == 3 and int(Contracts.wants(fringe)["years"]) == 2
			and int(Contracts.wants(regular)["salary"]) == Contracts.asking_salary(regular),
			"He asks his price over three seasons, or two once he is 30")
	_check(Contracts.leverage(star) > Contracts.leverage(kid) and Contracts.leverage(kid) > Contracts.leverage(fringe)
			and Contracts.stance(star).contains("won't take less") and Contracts.stance(fringe).contains("fighting"),
			"Better and younger players have more leverage, and he says so")
	var ask := Contracts.asking_salary(regular)
	_check(Contracts.lowest(star, 3) == Contracts.asking_salary(star) and Contracts.lowest(regular, 3) < ask
			and Contracts.lowest(regular, 4) == Contracts.lowest(regular, 3)
			and Contracts.lowest(regular, 1) == ask + Contracts.SALARY_STEP
			and Contracts.lowest(fringe, 2) < Contracts.asking_salary(fringe),
			"A star won't take less; others give a little for security; a short deal costs one $25k step")
	# No cliff: leverage moves smoothly with rating, and one rating point never
	# moves his lowest price by more than a point.
	var smooth := true
	var prev := {}
	for ovr in range(55, 92):
		var q := {"id": "n_s", "overall": ovr, "potential": ovr, "age": 26.0, "morale": 70}
		if not prev.is_empty():
			if Contracts.leverage(q) - Contracts.leverage(prev) > 0.05 or absi(Contracts.lowest(q, 3) - Contracts.lowest(prev, 3)) > 200000:
				smooth = false
		prev = q
	_check(smooth, "Leverage and price scale smoothly with rating: no threshold where the rules change")
	_check(str(Contracts.respond(regular, Contracts.lowest(regular, 3), 3)["answer"]) == "accept"
			and str(Contracts.respond(regular, Contracts.lowest(regular, 3) - Contracts.SALARY_STEP, 3)["answer"]) == "counter"
			and int(Contracts.respond(regular, Contracts.lowest(regular, 3) - Contracts.SALARY_STEP, 3)["salary"]) == Contracts.lowest(regular, 3),
			"An offer at his lowest is accepted; below it he counts with his lowest")
	_check(str(Contracts.respond(regular, ask, 1)["answer"]) == "counter",
			"His asking price over a shorter term than he wants gets a counter")
	_check(bool(Contracts.respond(regular, Contracts.SENIOR_MIN_2027, 3)["insult"])
			and str(Contracts.respond(regular, Contracts.SENIOR_MIN_2027, 3, 1)["answer"]) == "walk"
			and str(Contracts.respond(regular, Contracts.lowest(regular, 3) - Contracts.SALARY_STEP, 3, Contracts.MAX_OFFERS - 1)["answer"]) == "walk",
			"An insulting offer counts double, and too many failed offers end the talks")
	_check(str(Contracts.respond(regular, Contracts.lowest(regular, 3) - Contracts.SALARY_STEP, 3)) == str(Contracts.respond(regular, Contracts.lowest(regular, 3) - Contracts.SALARY_STEP, 3)),
			"No dice: the same offer gets the same answer")


func _test_negotiation() -> void:
	_new_season()
	_to_offseason()
	# Rivals bargain under the same rules.
	var ai_fair := true
	for code in GameState.season.lists:
		if code == GameState.my_club:
			continue
		for p in Contracts.expiring(GameState.season.lists[code]):
			if bool(p.get("resigned", false)):
				var years := int(p["contract_years"]) - 1
				if int(p["salary"]) != Contracts.lowest(p, years):
					ai_fair = false
	_check(ai_fair, "Rivals re-sign at the least each player takes for that term")
	GameState.salary_cap += 5000000
	var talkers := []
	for p in Contracts.expiring(GameState.my_list):
		var w := Contracts.wants(p)
		if Contracts.lowest(p, int(w["years"])) < int(w["salary"]) and int(w["salary"]) >= Contracts.SENIOR_MIN_2027:
			talkers.append(p)
	_check(talkers.size() >= 2, "Two of your out-of-contract players can be negotiated with (%d)" % talkers.size())
	if talkers.size() < 2:
		return
	var a: Dictionary = talkers[0]
	var id := str(a["id"])
	var years := int(Contracts.wants(a)["years"])
	var floor_price := Contracts.lowest(a, years)
	var before := int(a["salary"])
	var r := GameState.offer_contract(id, floor_price - Contracts.SALARY_STEP, years)
	_check(str(r["answer"]) == "counter" and int(r["salary"]) == floor_price
			and int(a["salary"]) == before and not bool(a.get("resigned", false)),
			"An offer under his lowest gets a counter and signs nothing")
	_check(GameState.save_career() and GameState.load_career(), "Talks survive a save")
	a = GameState.list_player(id)
	_check(int(GameState.contract_talks(id).get("counter", 0)) == floor_price and not bool(a.get("resigned", false)),
			"After a load the counter stands and nothing has been signed")
	r = GameState.offer_contract(id, floor_price, years)
	_check(bool(r["ok"]) and int(a["salary"]) == floor_price and int(a["contract_years"]) == years + 1
			and not a.has("talks"), "Meeting his counter signs the deal at that price and term")
	_check(not bool(GameState.offer_contract(id, floor_price, years)["ok"]), "A signed player cannot be signed twice")
	var b: Dictionary = GameState.list_player(str(talkers[1]["id"]))
	var bid := str(b["id"])
	var morale_before := ClubLife.morale(b)
	r = GameState.offer_contract(bid, Contracts.SENIOR_MIN_2027, 3)
	_check(ClubLife.morale(b) < morale_before and str(r["reason"]).begins_with("He's insulted"),
			"An insulting offer costs morale and he says so")
	r = GameState.offer_contract(bid, Contracts.SENIOR_MIN_2027, 3)
	_check(str(r["answer"]) == "walk" and bool(GameState.contract_talks(bid).get("walked", false)),
			"Too many failed offers and he walks")
	_check(not bool(GameState.offer_contract(bid, Contracts.asking_salary(b), 3)["ok"]), "No more offers once talks break down")
	var size_before := GameState.my_list.size()
	GameState._close_contracts()
	if size_before > Contracts.MIN_LIST:
		_check(GameState.list_player(bid).is_empty(), "A player whose talks broke down leaves at the rollover")
	else:
		_check(int(b["contract_years"]) >= 1 and GameState.my_list.has(b),
				"At the list minimum he stays a season")


## Part 2: a free agent weighs your club against his options, from facts the
## player can see. Cap room alone never signs anyone.
func _test_free_agent_terms() -> void:
	var p := {"id": "fa_t", "overall": 70, "potential": 72, "age": 27.0, "morale": 70}
	var bench := Contracts.free_agent_terms(p, {"in_best22": false, "rivals": 1})
	_check(bool(bench["refuse"]) and str(bench["reasons"]).contains("best 22"),
			"He won't sit outside your best 22 while a club that would play him has an offer")
	var nowhere := Contracts.free_agent_terms(p, {"in_best22": false, "rivals": 0})
	_check(not bool(nowhere["refuse"]), "With nowhere else to play, he'll come and fight for a spot")
	# How he weighs offers: close decisions turn on each factor.
	var ask := Contracts.asking_salary(p)
	var o := func(salary: int, years: int, role: String, t: float) -> Dictionary:
		return {"salary": salary, "years": years, "role": role, "finish_t": t}
	_check(Contracts.prefers(p, o.call(ask + Contracts.SALARY_STEP, 3, "bench", 0.5), o.call(ask, 3, "bench", 0.5))
			and Contracts.offer_view(p, o.call(ask + Contracts.SALARY_STEP, 3, "bench", 0.5), o.call(ask, 3, "bench", 0.5), "X") == "Best financial offer.",
			"Salary matters in a close decision, and he says so")
	_check(Contracts.prefers(p, o.call(ask, 3, "bench", 0.5), o.call(ask, 1, "bench", 0.5))
			and Contracts.offer_view(p, o.call(ask, 3, "bench", 0.5), o.call(ask, 1, "bench", 0.5), "X") == "More contract security.",
			"Contract security matters in a close decision")
	_check(Contracts.prefers(p, o.call(ask, 3, "ground", 0.5), o.call(ask + Contracts.SALARY_STEP, 3, "depth", 0.5))
			and Contracts.offer_view(p, o.call(ask, 3, "ground", 0.5), o.call(ask + Contracts.SALARY_STEP, 3, "depth", 0.5), "X") == "Clearer path into the best 22.",
			"A spot in the best 22 beats one more salary point to sit in the twos")
	_check(Contracts.prefers(p, o.call(ask, 3, "bench", 0.0), o.call(ask, 3, "bench", 1.0))
			and Contracts.offer_view(p, o.call(ask, 3, "bench", 0.0), o.call(ask, 3, "bench", 1.0), "Carlton").contains("Carlton's offer after their stronger season"),
			"The club's last season counts when all else is level")
	_check(Contracts.prefers(p, o.call(ask + 3 * Contracts.SALARY_STEP, 3, "depth", 0.5), o.call(ask, 3, "ground", 0.5)),
			"Enough money still wins: nothing is absolute")
	# Equal in his eyes: more money first, never a list position.
	var a: Dictionary = o.call(ask + Contracts.SALARY_STEP, 3, "depth", 0.5)
	var b: Dictionary = o.call(ask, 3, "bench", 0.1875)
	_check(Contracts.prefers(p, a, b) and not Contracts.prefers(p, b, a), "A dead heat goes to the bigger salary")
	# Club valuations come from his role there, and stop at the cap.
	_check(Contracts.club_max(p, "ground", ask + 10 * Contracts.SALARY_STEP) == ask + 2 * Contracts.SALARY_STEP
			and Contracts.club_max(p, "bench", ask + 10 * Contracts.SALARY_STEP) == ask + Contracts.SALARY_STEP
			and Contracts.club_max(p, "depth", ask + 10 * Contracts.SALARY_STEP) == Contracts.lowest(p, Contracts.ai_years(p))
			and Contracts.club_max(p, "ground", ask + Contracts.SALARY_STEP) == ask + Contracts.SALARY_STEP, "A club pays a starter more than a depth player, never past its cap room")
	# Rival answers.
	var match_r := Contracts.rival_response(p, o.call(ask, 3, "ground", 0.5), o.call(ask + 2 * Contracts.SALARY_STEP, 3, "ground", 0.6), ask + 3 * Contracts.SALARY_STEP)
	_check(str(match_r["action"]) == "match" and int(match_r["salary"]) == ask + 2 * Contracts.SALARY_STEP, "A rival can match the leading salary")
	var up := Contracts.rival_response(p, o.call(ask, 3, "bench", 0.5), o.call(ask + Contracts.SALARY_STEP, 3, "bench", 0.5), ask + 3)
	_check(str(up["action"]) == "improve" and int(up["salary"]) == ask + 2 * Contracts.SALARY_STEP, "A rival improves just enough to lead")
	var out := Contracts.rival_response(p, o.call(ask, 3, "ground", 0.5), o.call(ask + 4 * Contracts.SALARY_STEP, 3, "ground", 0.5), ask + 2 * Contracts.SALARY_STEP)
	_check(str(out["action"]) == "withdraw", "A rival withdraws once the price passes what he's worth to it")
	var stay := Contracts.rival_response(p, o.call(ask - Contracts.SALARY_STEP, 1, "depth", 1.0), o.call(ask - Contracts.SALARY_STEP, 3, "ground", 0.0), ask - Contracts.SALARY_STEP)
	_check(str(stay["action"]) == "hold" and int(stay["salary"]) == ask - Contracts.SALARY_STEP, "A rival that can't win but isn't priced out holds")


func _test_free_agents() -> void:
	_new_season()
	_to_offseason()
	var me := GameState.my_club
	# Offers on the table: real contracts, from clubs that want him.
	var multi := {}
	var total := 0
	var honest := true
	var notes := []
	for fa in GameState.free_agents:
		var seen := {}
		for o in fa.get("offers", []):
			total += 1
			var code := str(o["club"])
			var list: Array = GameState.season.lists[code]
			if seen.has(code) or code == str(fa.get("released_by", "")) or code == me \
					or int(o["salary"]) < 1 or int(o["years"]) < 1 or int(o["years"]) > Contracts.MAX_YEARS \
					or int(o["salary"]) > GameState._cap_room_of(code) \
					or int(o["salary"]) > GameState.offer_max(fa, o) \
					or GameState.fa_role(fa, code) != str(o["role"]) \
					or (bool(o.get("filler", false)) and list.size() >= Contracts.AI_FILL) \
					or (not bool(o.get("filler", false)) and str(o["role"]) == "depth"):
				honest = false
				notes.append("%s %s" % [code, str(o)])
			seen[code] = true
		if seen.size() >= 2 and multi.is_empty():
			multi = fa
	_check(not multi.is_empty(), "A free agent can hold offers from several clubs")
	_check(honest, "Every offer is a real contract from a club with the need, the cap room and the valuation %s" % str(notes.slice(0, 3)))
	_check(total < GameState.free_agents.size() * GameState.season.lists.size() / 3,
			"Clubs don't bid on everyone (%d offers for %d free agents)" % [total, GameState.free_agents.size()])
	# No list-order priority: the same market opens whatever order the clubs
	# are stored in.
	var before := _offer_book()
	var lists: Dictionary = GameState.season.lists
	var keys := lists.keys()
	keys.reverse()
	var flipped := {}
	for k in keys:
		flipped[k] = lists[k]
	GameState.season.lists = flipped
	for fa in GameState.free_agents:
		fa.erase("offers")
	GameState._open_market(GameState.free_agents)
	_check(_offer_book() == before, "The offers don't depend on the order clubs are listed in")
	# A generated player goes through exactly the same market.
	var gen: Dictionary = (GameDB.draftees[0] as Dictionary).duplicate(true)
	gen["id"] = "fa_generated"
	gen["overall"] = 84
	gen["age"] = 24.0
	gen["contract_years"] = 0
	gen["released_by"] = str(keys[0])
	GameState.free_agents.append(gen)
	for fa in GameState.free_agents:
		fa.erase("offers")
	GameState._open_market(GameState.free_agents)
	_check((gen.get("offers", []) as Array).size() >= 2, "A generated player draws offers like anyone (%d)" % (gen.get("offers", []) as Array).size())
	GameState.free_agents.erase(gen)
	for fa in GameState.free_agents:
		fa.erase("offers")
	GameState._open_market(GameState.free_agents)
	# The best-22 test is positional: with your rucks weak, a ruckman rated
	# below your top 22 still has a place.
	var saved := {}
	for q in GameState.my_list:
		if str(q["role"]) == "RUCK":
			saved[str(q["id"])] = int(q["overall"])
			q["overall"] = 40
	var all_ovr := []
	for q in GameState.my_list:
		all_ovr.append(int(q["overall"]))
	all_ovr.sort()
	all_ovr.reverse()
	var cut := int(all_ovr[21])
	var big := {}
	for q in GameState.my_list:
		if str(q["role"]) == "RUCK":
			big = q.duplicate(true)
			break
	if not big.is_empty():
		big["id"] = "fa_ruck"
		big["overall"] = cut - 5
		big.erase("role2")
		GameState._bars = {}
		_check(GameState.fa_role(big, me) == "ground",
				"A ruckman rated below your top 22 starts when your rucks are weak (%d v cut %d)" % [int(big["overall"]), cut])
	for q in GameState.my_list:
		if saved.has(str(q["id"])):
			q["overall"] = saved[str(q["id"])]
	GameState._bars = {}
	# Refusal: he won't sit outside your best 22 while a club that would play
	# him has an offer.
	var refused := {}
	for fa in GameState.free_agents:
		if bool(GameState.free_agent_terms(str(fa["id"]))["refuse"]):
			refused = fa
			break
	if not refused.is_empty():
		var r0 := GameState.offer_free_agent(str(refused["id"]), Contracts.asking_salary(refused) + 1000000, 3)
		_check(not bool(r0["ok"]) and str(r0["answer"]) == "reject" and GameState.free_agents.has(refused),
				"A player who won't come turns down even a big offer, and says why")
	# Bidding against rivals for a player who would start for you.
	GameState.salary_cap += 10000000
	var target := {}
	for fa in GameState.free_agents:
		if GameState.fa_role(fa, me) == "ground" and (fa.get("offers", []) as Array).size() >= 1:
			var ok := true
			for o in fa["offers"]:
				ok = ok and not bool(o.get("filler", false))
			if ok and (target.is_empty() or int(fa["overall"]) > int(target["overall"])):
				target = fa
	_check(not target.is_empty(), "A starter for you has rival offers to beat")
	if target.is_empty():
		return
	var id := str(target["id"])
	var years := int(Contracts.wants(target)["years"])
	var low := Contracts.lowest(target, years)
	var r := GameState.offer_free_agent(id, low - Contracts.SALARY_STEP, years)
	_check(str(r["answer"]) == "counter" and GameState.fa_offers(id).filter(func(x): return bool(x["mine"])).is_empty(),
			"Under his lowest price he counters, and nothing goes on the table")
	var top: Dictionary = GameState.fa_offers(id)[0]
	var bid := int(top["salary"]) + Contracts.SALARY_STEP
	r = GameState.offer_free_agent(id, bid, years)
	_check(str(r["answer"]) == "table" and not (r["responses"] as Array).is_empty(),
			"Your offer goes on the table and the rivals you overtook answer it (%s)" % str(r["responses"]))
	var within := true
	for o in GameState.free_agent(id).get("offers", []):
		if str(o["club"]) != me and int(o["salary"]) > GameState.offer_max(target, o):
			within = false
	_check(within, "No rival goes past its valuation or its cap room")
	_check(GameState.fa_market_stage(id) == "final", "Your second offer will be your last")
	var book := str(GameState.fa_offers(id))
	_check(GameState.save_career() and GameState.load_career() and str(GameState.fa_offers(id)) == book
			and GameState.fa_market_stage(id) == "final", "A save keeps every offer and where the talks stand")
	var lead: Dictionary = GameState.fa_offers(id)[0]
	var final_salary := int(lead["salary"]) + (0 if bool(lead["mine"]) else Contracts.SALARY_STEP)
	var r1 := GameState.offer_free_agent(id, final_salary, years)
	var won := str(r1["answer"])
	var where := ""
	var contract := []
	for code in GameState.season.lists:
		for q in GameState.season.lists[code]:
			if str(q["id"]) == id:
				where = code
				contract = [int(q["salary"]), int(q["contract_years"])]
	_check(won == "signed" or won == "lost", "After your final offer he chooses (%s)" % won)
	_check(where != "" and GameState.free_agent(id).is_empty(), "He signs with the club he chose")
	_check(GameState.load_career() and str(GameState.offer_free_agent(id, final_salary, years)["answer"]) == won,
			"Reloading before he chooses cannot change his choice")
	var again := ""
	var contract2 := []
	for code in GameState.season.lists:
		for q in GameState.season.lists[code]:
			if str(q["id"]) == id:
				again = code
				contract2 = [int(q["salary"]), int(q["contract_years"])]
	_check(again == where and contract2 == contract, "Same club, same contract, every time")
	# He signs the contract he chose, and his old club's compensation reads it.
	var a_club := ""
	var star := {}
	for code in GameState.season.lists:
		if code == me:
			continue
		for q in GameState.season.lists[code]:
			if not q.has("joined") and (star.is_empty() or int(q["overall"]) > int(star["overall"])):
				star = q
				a_club = code
	GameState._release(a_club, star, true)
	GameState._open_market([star])
	var sid := str(star["id"])
	var offers_now := GameState.fa_offers(sid)
	if not offers_now.is_empty():
		var lead2: Dictionary = offers_now[0]
		GameState.offer_free_agent(sid, int(lead2["salary"]) + Contracts.SALARY_STEP, int(Contracts.wants(star)["years"]))
		var lead3: Dictionary = GameState.fa_offers(sid)[0]
		GameState.offer_free_agent(sid, int(lead3["salary"]) + (0 if bool(lead3["mine"]) else Contracts.SALARY_STEP), int(Contracts.wants(star)["years"]))
	var signed_for := []
	var signed_with := ""
	for code in GameState.season.lists:
		for q in GameState.season.lists[code]:
			if str(q["id"]) == sid:
				signed_with = code
				signed_for = [int(q["salary"]), int(q["contract_years"]) - 1]
	var comp_ok := false
	for c in GameState.compensation:
		if str(c["player"]) == sid:
			comp_ok = str(c["club"]) == a_club and str(c["to"]) == signed_with \
					and [int(c["salary"]), int(c["years"])] == signed_for
	_check(signed_with != "" and comp_ok, "Compensation is worked out from the contract he actually signed")
	# Free agency closes: rivals settle the rest by the same rules.
	GameState._close_contracts()
	var fair := true
	var seen_n := 0
	for entry in GameState.offseason_log:
		if str(entry.get("kind", "")) == "signed" and str(entry["club"]) != me:
			seen_n += 1
			var code := str(entry["club"])
			if Contracts.payroll(GameState.season.lists[code]) > GameState.salary_cap:
				fair = false
	_check(fair and seen_n > 0, "Every rival signing fits under the cap (%d signings)" % seen_n)


## The market as a comparable book: player -> sorted club offers.
func _offer_book() -> String:
	var rows := []
	for fa in GameState.free_agents:
		var offers := []
		for o in fa.get("offers", []):
			offers.append("%s:%d:%d:%s:%s" % [o["club"], int(o["salary"]), int(o["years"]), o["role"], str(o.get("filler", false))])
		offers.sort()
		rows.append("%s=%s" % [fa["id"], ",".join(PackedStringArray(offers))])
	rows.sort()
	return "|".join(PackedStringArray(rows))


## Part 3: free-agency compensation. Losing a better, younger player on a
## bigger deal earns an earlier pick; nothing jumps between neighbours.
func _test_compensation_rules() -> void:
	var clubs := 18
	var star := {"id": "c_star", "overall": 86, "age": 25.0}
	var fringe := {"id": "c_fringe", "overall": 56, "age": 30.0}
	var v_star := Contracts.compensation_value(star, Contracts.old_points_to_salary(9), 3)
	var v_fringe := Contracts.compensation_value(fringe, Contracts.old_points_to_salary(3), 1)
	var a_star := Contracts.compensation_after(v_star, clubs)
	var a_fringe := Contracts.compensation_after(v_fringe, clubs)
	_check(a_star > 0 and (a_fringe == 0 or a_fringe > a_star),
			"Losing a star earns a far better pick than losing a fringe player (after %d v %d)" % [a_star, a_fringe])
	var mid := {"id": "c_mid", "overall": 72, "age": 27.0}
	var base := Contracts.compensation_value(mid, Contracts.old_points_to_salary(6), 2)
	var young := mid.duplicate()
	young["age"] = 23.0
	_check(Contracts.compensation_value(young, Contracts.old_points_to_salary(6), 2) > base and Contracts.compensation_value(mid, Contracts.old_points_to_salary(7), 2) > base
			and Contracts.compensation_value(mid, Contracts.old_points_to_salary(6), 4) > base,
			"A younger player, a bigger salary and a longer deal each earn more")
	# No cliffs: walk the ratings with the salary the market would pay; the
	# pick never moves more than three spots for one rating point, never gets
	# worse as the player gets better, and only fades out near the end of
	# the second round.
	var smooth := true
	var prev := -1
	var notes := []
	for ovr in range(55, 93):
		var q := {"id": "c_s", "overall": ovr, "age": 26.0}
		var after := Contracts.compensation_after(Contracts.compensation_value(q, Ratings.salary_value(ovr), 3), clubs)
		if prev > 0 and after > 0 and (absi(after - prev) > 3 or after > prev):
			smooth = false
			notes.append("%d:%d->%d" % [ovr, prev, after])
		if prev > 0 and after == 0:
			smooth = false
		if prev == 0 and after > 0 and after < clubs * 2 - 3:
			smooth = false
			notes.append("%d: none->%d" % [ovr, after])
		prev = after
	_check(smooth, "Compensation slides with the player's value, no cliffs %s" % str(notes))
	_check(Contracts.compensation_after(99.0, clubs) >= clubs / 2,
			"Even the best departure lands no earlier than mid first round")
	_check(Contracts.pick_words(18, 18) == "after pick 18, at the end of the first round"
			and Contracts.pick_words(22, 18).contains("early in the second round"),
			"The pick is described in draft language")


## Compensation picks slot into the national draft order: right after the
## named pick, in the round they fall in, once each, for the right club.
func _test_compensation_draft_order() -> void:
	var pool: Array = GameDB.draftees.duplicate()
	for year in [2027, 2028]:
		var active := GameDB.active_clubs(year)
		var order := active.duplicate()
		order.reverse()
		var d := Draft.build_intake(pool, active.duplicate(), order, 7, {}, {}, {})
		var regular := d.pick_sequence.size()
		var n := active.size()
		var a: String = str(order[3])
		var b: String = str(order[0])
		d.add_compensation([{"club": a, "after": n, "value": 9.0, "name": "A"},
				{"club": b, "after": n, "value": 10.0, "name": "B"},
				{"club": a, "after": n + 4, "value": 7.0, "name": "C"}])
		var idx := []
		for c in d.comp_picks:
			idx.append(int(c["index"]))
		var unique: bool = idx.size() == 3 and idx[0] != idx[1] and idx[1] != idx[2]
		_check(unique and str(d.pick_sequence[n]) == b and str(d.pick_sequence[n + 1]) == a
				and str(d.pick_sequence[n + 6]) == a and d.comp_at(n).get("name", "") == "B",
				"%d: picks after pick %d go best first, each once, to the club that lost the player" % [year, n])
		_check(int(d.pick_rounds[n]) == 1 and int(d.pick_rounds[n + 2]) == 2
				and d.pick_rounds.size() == d.pick_sequence.size(),
				"%d: a pick after the last of round one is a round-one pick" % year)
		var per_round_ok := true
		for r in range(1, d.target_size + 1):
			var seen := {}
			for k in range(d.pick_sequence.size()):
				if int(d.pick_rounds[k]) == r and d.comp_at(k).is_empty():
					var code := str(d.pick_sequence[k])
					if seen.has(code):
						per_round_ok = false
					seen[code] = true
			if r <= 2 and seen.size() != n:
				per_round_ok = false
		_check(per_round_ok and d.pick_limit(a) == d.target_size + 2 and d.pick_limit(str(order[1])) == d.target_size,
				"%d: every one of the %d clubs still picks once a round; only the compensated clubs get extra picks" % [year, n])
		_check(d.pick_sequence.size() <= d.pool.size(), "%d: compensation never adds picks past the pool" % year)
		# A short pool: the earned picks survive, the last regular picks go.
		var small := Draft.build_intake(pool.slice(0, n * 2), active.duplicate(), order, 7, {}, {}, {})
		small.add_compensation([{"club": a, "after": n * 2 - 1, "value": 6.0}, {"club": b, "after": n * 3, "value": 6.0}])
		var kept := 0
		for c in small.comp_picks:
			if str(small.pick_sequence[int(c["index"])]) == str(c["club"]):
				kept += 1
		_check(kept == 2 and small.pick_sequence.size() == n * 2,
				"%d: when the pool runs short the earned picks stay and the last regular picks drop off" % year)


func _test_compensation_flow() -> void:
	_new_season()
	_to_offseason()
	GameState.salary_cap += 10000000
	var me := GameState.my_club
	var rivals := []
	for code in GameState.season.lists:
		if code != me:
			rivals.append(code)
	var a := str(rivals[0])
	var b := str(rivals[1])
	var best := func(code: String, skip: Array) -> Dictionary:
		var top := {}
		for q in GameState.season.lists[code]:
			if not skip.has(q) and not q.has("joined") and (top.is_empty() or int(q["overall"]) > int(top["overall"])):
				top = q
		return top
	var star: Dictionary = best.call(a, [])
	var b1: Dictionary = best.call(b, [])
	var b2: Dictionary = best.call(b, [b1])
	var delisted: Dictionary = best.call(a, [star])
	var newcomer: Dictionary = best.call(b, [b1, b2])
	GameState._release(a, star, true)
	GameState._release(b, b1, true)
	GameState._release(b, b2, true)
	GameState._release(a, delisted, false)
	newcomer["joined"] = GameState.season_year
	GameState._release(b, newcomer, true)
	_check(not bool(newcomer["comp_eligible"]) and not bool(delisted["comp_eligible"]) and bool(star["comp_eligible"]),
			"A delisted player, or one at the club under two seasons, earns no pick")
	var sign := func(p: Dictionary) -> bool:
		var id := str(p["id"])
		var y := int(Contracts.wants(p)["years"])
		var price := Contracts.lowest(p, y) + int(GameState.free_agent_terms(id)["premium"])
		return bool(GameState.offer_free_agent(id, price, y)["ok"])
	var all_signed: bool = sign.call(star) and sign.call(b1) and sign.call(b2) and sign.call(delisted) and sign.call(newcomer)
	_check(all_signed, "The test signs all five free agents")
	var got := {}
	for c in GameState.compensation:
		got[str(c["player"])] = str(c["club"])
	_check(got.get(str(star["id"]), "") == a and got.get(str(b1["id"]), "") == b and got.get(str(b2["id"]), "") == b,
			"The club that lost each wanted player gets the pick, AI clubs included, two for two departures")
	_check(not got.has(str(delisted["id"])) and not got.has(str(newcomer["id"])) and got.size() == GameState.compensation.size(),
			"No pick for a delisted player or a short stay, and no duplicates")
	GameState._record_departure(star, me, 9, 3)
	_check(GameState.compensation.size() == got.size(), "One departure never earns two picks")
	var news_ok := false
	for n in GameState.news:
		if str(n.get("text", "")).contains("receive a draft pick after pick"):
			news_ok = true
	_check(news_ok, "The league news reports the compensation pick in draft language")
	# Your own player who walks: the projection is in words, and if a rival
	# signs him at the draft you get the pick under the same rule.
	var mine := {}
	for p in Contracts.expiring(GameState.my_list):
		if not p.has("joined") and (mine.is_empty() or int(p["overall"]) > int(mine["overall"])):
			mine = p
	if not mine.is_empty():
		var proj := GameState.projected_compensation(mine)
		_check(str(proj["reason"]) != "" and (int(proj["after"]) == 0 or str(proj["reason"]).contains("after pick")),
				"Your walked player shows what losing him would bring: %s" % str(proj["reason"]))
		mine["talks"] = {"walked": true, "failed": 3}
	_check(GameState.save_career() and GameState.load_career()
			and GameState.compensation.size() == got.size(), "Compensation survives a save and load")
	_check(GameState.begin_intake_draft(), "The national draft opens")
	if not mine.is_empty() and str(mine.get("club", "")) != me:
		var mine_comp := false
		for c in GameState.compensation:
			if str(c["player"]) == str(mine["id"]):
				mine_comp = str(c["club"]) == me
		_check(mine_comp or not GameState.list_player(str(mine["id"])).is_empty() or GameState.free_agent(str(mine["id"])).is_empty(),
				"Your walked player's departure is judged by the same rule")
	var d: Draft = GameState.draft
	var placed := true
	for c in GameState.compensation:
		var found := false
		for e in d.comp_picks:
			if str(e["player"]) == str(c["player"]):
				found = str(d.pick_sequence[int(e["index"])]) == str(c["club"])
		if not found:
			placed = false
	_check(placed and d.pick_rounds.size() == d.pick_sequence.size(),
			"Each compensation pick sits in the draft order under the club that lost the player")
	_check(GameState.save_career() and GameState.load_career() and GameState.draft != null
			and GameState.draft.comp_picks.size() == d.comp_picks.size(), "The draft keeps its compensation picks through a save")
	d = GameState.draft
	while not d.is_finished():
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()
	var used := 0
	var owners_ok := true
	for e in d.comp_picks:
		for h in d.pick_history:
			if int(h["pick"]) == int(e["index"]) + 1:
				used += 1
				owners_ok = owners_ok and str(h["club"]) == str(e["club"])
	_check(used > 0 and owners_ok, "Compensation picks are used by the clubs that earned them (%d)" % used)
	_check(GameState.finish_intake_draft(), "The draft completes and the season rolls over")
	_check(GameState.compensation.is_empty() or GameState.offseason_year != GameState.season_year,
			"Last year's compensation does not carry into the new season")


## Trade valuation: what a club gets is judged against its own side and
## cycle; a package of lesser players never adds up to a cornerstone.
func _by_name(list: Array, last: String, first: String) -> Dictionary:
	for p in list:
		if str(p.get("last", "")) == last and str(p.get("first", "")).begins_with(first):
			return p
	return {}


func _with(p: Dictionary, changes: Dictionary) -> Dictionary:
	var q := p.duplicate(true)
	for k in changes:
		q[k] = changes[k]
	return q


## Room on both lists so the valuation decides; returns the verdict.
func _trade(ai_list: Array, give: Array, take: Array, phase: String, margin := 0.0) -> Dictionary:
	var ai := ai_list.duplicate()
	var spare := ai.filter(func(q): return not give.has(q))
	spare.sort_custom(func(x, y): return int(x["overall"]) < int(y["overall"]))
	while ai.size() - give.size() + take.size() > 40 and not spare.is_empty():
		ai.erase(spare.pop_front())
	var mine: Array = GameDB.club_list("GEE").duplicate()
	mine.append_array(take)
	return Contracts.evaluate_trade(ai, give, take, 99999999, mine, 99999999, margin, {"phase": phase})


func _test_trade_value() -> void:
	GameDB.reload()
	# The phone-playtest case: Adelaide gave Arki Butler (72 OVR / 92 POT, 19)
	# for Jordon Sweet and Ryan Lester. Rebuilt as it was then: Sweet a 72
	# ruck, Adelaide down to two rucks, the easiest trade margin.
	var ade: Array = GameDB.club_list("ADE").duplicate()
	var butler := _with(_by_name(GameDB.draftees, "Butler", "Arki"),
			{"overall": 72, "potential": 92, "age": 19.0, "salary": Contracts.old_points_to_salary(2), "contract_years": 2, "club": "ADE"})
	ade.append(butler)
	var rucks := ade.filter(func(q): return str(q["role"]) == "RUCK")
	rucks.sort_custom(func(x, y): return int(x["overall"]) < int(y["overall"]))
	ade.erase(rucks[0])
	var sweet := _with(_by_name(GameDB.club_list("PAD"), "Sweet", "Jord"), {"overall": 72})
	var lester := _by_name(GameDB.club_list("BRL"), "Lester", "Ryan")
	_check(not butler.is_empty() and not sweet.is_empty() and not lester.is_empty(), "The playtest players are in the data")
	var all_no := true
	var worst := 0.0
	for ph in TradeValue.PHASES:
		for m in [0.0, Contracts.TRADE_MARGIN, 0.12]:
			all_no = all_no and not bool(_trade(ade, [butler], [sweet, lester], ph, m)["ok"])
		var r := _trade(ade, [butler], [sweet, lester], ph, 0.0)
		worst = maxf(worst, float(r.get("in", 0.0)) / maxf(0.01, float(r.get("out", 1.0))))
	_check(all_no and worst < 0.7, "Sweet and Lester no longer buy Arki Butler, whatever Adelaide's phase (best ratio %.2f)" % worst)
	# Packages: lesser pieces count for less, so four 0.5s don't buy a 2.0.
	_check(TradeValue.package([0.5, 0.5, 0.5, 0.5]) < 1.2 and is_equal_approx(TradeValue.package([2.0]), 2.0),
			"A package of four ordinary players is worth about one good one")
	# Bundles of ordinary or older players for a club's best young player.
	var gee: Array = GameDB.club_list("GEE")
	var ordinary := gee.filter(func(q): return int(q["overall"]) >= 58 and int(q["overall"]) <= 68 and float(q["age"]) >= 26.0)
	var bundles_refused := true
	var tried := 0
	for code in GameDB.CLUB_ORDER:
		var list: Array = GameDB.club_list(code)
		var young := list.filter(func(q): return float(q["age"]) <= 22.0)
		young.sort_custom(func(x, y): return TradeValue.future_rating(x) > TradeValue.future_rating(y))
		# Elite young talent only: a solid package can fairly buy a lesser one.
		if young.is_empty() or ordinary.size() < 4 or TradeValue.future_rating(young[0]) < 78.0:
			continue
		tried += 1
		for k in [2, 3, 4]:
			for ph in TradeValue.PHASES:
				if bool(_trade(list, [young[0]], ordinary.slice(0, k), ph, 0.0)["ok"]):
					bundles_refused = false
	_check(bundles_refused and tried >= 4,
			"Bundles of two to four ordinary or older players never buy a club's elite young player (%d clubs)" % tried)
	# Quality-aware needs: a club with a poor ruckman pays more for a good one;
	# a club whose ruck is better than him barely wants him.
	var base: Array = GameDB.club_list("COL")
	var ruck := _with(base.filter(func(q): return str(q["role"]) == "RUCK")[0], {"id": "t_ruck", "overall": 76, "age": 26.0, "role2": ""})
	var weakest := ""
	var strongest := ""
	for code in GameDB.CLUB_ORDER:
		var list: Array = GameDB.club_list(code)
		if list.is_empty():
			continue
		var bar := int(TradeValue.selection_bars(list).get("RUCK", 0))
		if weakest == "" or bar < int(TradeValue.selection_bars(GameDB.club_list(weakest)).get("RUCK", 0)):
			weakest = code
		if strongest == "" or bar > int(TradeValue.selection_bars(GameDB.club_list(strongest)).get("RUCK", 0)):
			strongest = code
	var needy := TradeValue.fit(ruck, TradeValue.selection_bars(GameDB.club_list(weakest)))
	var full := TradeValue.fit(ruck, TradeValue.selection_bars(GameDB.club_list(strongest)))
	_check(needy >= 1.2 and full <= 0.65, "A club short of a ruckman values a good one far more than a club with a better one (%.2f v %.2f)" % [needy, full])
	# A strong, young forward line: another forward wouldn't get a game.
	var fwd_bar := int(TradeValue.selection_bars(base).get("FWD", 60))
	var forward := _with(base.filter(func(q): return str(q["role"]) == "FWD")[0], {"id": "t_fwd", "overall": fwd_bar + 3, "age": 28.0, "role2": ""})
	var young_line := base.map(func(q): return _with(q, {"age": 21.0, "potential": int(q["overall"]) + 15}) if str(q["role"]) == "FWD" else q)
	_check(TradeValue.cover(forward, TradeValue.selection_bars(base, true)) == 1.0
			and TradeValue.cover(forward, TradeValue.selection_bars(young_line, true)) < 1.0,
			"A forward with a future at an ordinary forward line is covered by a strong young one")
	# Rational trades still happen.
	var vet := _with(base[0], {"id": "t_vet", "overall": 80, "potential": 80, "age": 30.0})
	var kid := _with(base[1], {"id": "t_kid", "overall": 70, "potential": 88, "age": 20.0})
	var club_vet: Array = base.duplicate()
	club_vet.append(vet)
	var sensible := true
	for m in [0.0, Contracts.TRADE_MARGIN, 0.12]:
		sensible = sensible and bool(_trade(club_vet, [vet], [kid], "rebuilding", m)["ok"]) \
				and not bool(_trade(club_vet, [vet], [kid], "contending", m)["ok"])
	_check(sensible, "On every difficulty a rebuilder moves a 30-year-old star for a young talent; a contender keeps him")
	var prospect := _with(base[2], {"id": "t_prospect", "overall": 66, "potential": 90, "age": 20.0})
	var starter := _with(base[3], {"id": "t_starter", "overall": 80, "potential": 80, "age": 27.0})
	var club_kid: Array = base.duplicate()
	club_kid.append(prospect)
	var paying := true
	for m in [0.0, Contracts.TRADE_MARGIN, 0.12]:
		paying = paying and bool(_trade(club_kid, [prospect], [starter], "contending", m)["ok"]) \
				and not bool(_trade(club_kid, [prospect], [starter], "rebuilding", m)["ok"])
	_check(paying, "On every difficulty a contender pays future value for an established starter; a rebuilder protects its prospect")
	var twin := _with(base[4], {"id": "t_twin"})
	_check(bool(_trade(base, [base[4]], [twin], "building", 0.0)["ok"]), "Like for like goes through")
	# The cycle comes from what anyone can see.
	_check(TradeValue.phase(0.0, 0.0, 27.0) == "contending" and TradeValue.phase(1.0, 1.0, 26.0) == "rebuilding"
			and TradeValue.phase(0.55, 0.6, 23.5) == "rebuilding" and TradeValue.phase(0.55, 0.6, 27.0) == "building"
			and TradeValue.phase(-1.0, 0.1, 27.0) == "contending",
			"Clubs contend, build or rebuild by their finish, list strength and age")
	# Older players lose value; a long-serving 34-year-old is no longer half
	# a starter.
	var old := _with(base[5], {"overall": 66, "potential": 66, "age": 34.5})
	var prime := _with(base[5], {"overall": 66, "potential": 66, "age": 27.0})
	var ctx := {"phase": "building", "bars": TradeValue.selection_bars(base)}
	_check(float(TradeValue.value(old, ctx)["total"]) < 0.6 * float(TradeValue.value(prime, ctx)["total"]),
			"A 34-year-old is worth well under a player in his prime of the same rating")


## Packages are order-free and fit one newcomer at a time; current need and
## projected cover stay separate.
func _test_trade_packages_and_needs() -> void:
	GameDB.reload()
	var base: Array = GameDB.club_list("COL").duplicate()
	var gee: Array = GameDB.club_list("GEE")
	var ordinary := gee.filter(func(q): return int(q["overall"]) >= 58 and int(q["overall"]) <= 68 and float(q["age"]) >= 26.0)
	var young := base.filter(func(q): return float(q["age"]) <= 23.0)
	young.sort_custom(func(x, y): return TradeValue.future_rating(x) > TradeValue.future_rating(y))
	var same := true
	for ph in TradeValue.PHASES:
		var a := _trade(base, [young[0]], ordinary.slice(0, 3), ph, 0.0)
		var rev := ordinary.slice(0, 3)
		rev.reverse()
		var b := _trade(base, [young[0]], rev, ph, 0.0)
		same = same and bool(a["ok"]) == bool(b["ok"]) and is_equal_approx(float(a["in"]), float(b["in"]))
	_check(same, "The order you pick players in never changes the valuation")
	# Two players for one gap don't both fill it: a second ruck adds less
	# than the first.
	var bars := TradeValue.selection_bars(base)
	var r1 := _with(base.filter(func(q): return str(q["role"]) == "RUCK")[0], {"id": "t_r1", "overall": int(bars.get("RUCK", 60)) + 8, "age": 26.0, "role2": ""})
	var r2 := _with(r1, {"id": "t_r2"})
	var one := _trade(base, [base[6]], [r1], "building", 0.0)
	var two := _trade(base, [base[6]], [r1, r2], "building", 0.0)
	_check(float(two["in"]) < float(one["in"]) * 1.45, "A second ruck for the same spot adds little (%.2f v %.2f)" % [float(two["in"]), float(one["in"])])
	# Two starters filling separate weak spots are worth close to their sum.
	var roles := ["RUCK", "MID", "DEF", "FWD"]
	roles.sort_custom(func(x, y): return int(bars.get(x, 99)) < int(bars.get(y, 99)))
	var s1 := _with(base[7], {"id": "t_s1", "role": roles[0], "role2": "", "overall": int(bars[roles[0]]) + 6, "potential": int(bars[roles[0]]) + 6, "age": 26.0})
	var s2 := _with(base[8], {"id": "t_s2", "role": roles[1], "role2": "", "overall": int(bars[roles[1]]) + 6, "potential": int(bars[roles[1]]) + 6, "age": 26.0})
	var solo := float(_trade(base, [base[6]], [s1], "building", 0.0)["in"])
	var pair := float(_trade(base, [base[6]], [s1, s2], "building", 0.0)["in"])
	_check(pair > solo * 1.4, "Two starters at separate weak spots both count (%.2f v %.2f alone)" % [pair, solo])
	# A promising young forward line that is weak now.
	var kids := base.map(func(q): return _with(q, {"overall": 58, "potential": 86, "age": 20.0}) if str(q["role"]) == "FWD" else q)
	var vet := _with(base.filter(func(q): return str(q["role"]) == "FWD")[0], {"id": "t_vetfwd", "overall": 72, "potential": 72, "age": 27.0, "role2": ""})
	var now_bars := TradeValue.selection_bars(kids)
	var proj_bars := TradeValue.selection_bars(kids, true)
	var c_ctx := {"phase": "contending", "bars": now_bars, "proj": proj_bars}
	var r_ctx := {"phase": "rebuilding", "bars": now_bars, "proj": proj_bars}
	var vc := TradeValue.value(vet, c_ctx)
	var vr := TradeValue.value(vet, r_ctx)
	_check(TradeValue.fit(vet, now_bars) >= 1.2, "Weak forwards now: an established forward is a big upgrade this season")
	_check(TradeValue.cover(vet, proj_bars) < 1.0 and float(vc["total"]) > float(vr["total"]) * 1.2,
			"A contender values him for now; a rebuilder sees its young forwards coming (%.2f v %.2f)" % [float(vc["total"]), float(vr["total"])])
	_check(TradeValue.future_rating(kids.filter(func(q): return str(q["role"]) == "FWD")[0]) < 86.0 - 5.0,
			"A prospect is projected part of the way to his potential, not all of it")


## A club's phase from the cache always matches a fresh calculation: after a
## trade, a save and load, and the rollover.
func _phases_fresh() -> bool:
	for code in GameState.season.lists:
		if GameState.club_phase(code) != GameState._club_phase(code):
			return false
	return true


func _test_phase_cache() -> void:
	_new_season()
	_to_offseason()
	_check(_phases_fresh(), "Phases match a fresh calculation after the season")
	var rival := "COL"
	var their_weak: Dictionary = {}
	for p in GameState.season.lists[rival]:
		if their_weak.is_empty() or int(p["overall"]) < int(their_weak["overall"]):
			their_weak = p
	var sorted_mine := GameState.my_list.duplicate()
	sorted_mine.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	for code in GameState.season.lists:
		GameState.club_phase(code)
	var before_key := str(GameState._phase_cache.get("key", ""))
	var t := GameState.make_trade(rival, [str(sorted_mine[0]["id"])], [str(their_weak["id"])])
	_check(bool(t["ok"]) and str(GameState._league_fingerprint()) != before_key and _phases_fresh(),
			"A completed trade changes the league's fingerprint and the phases follow")
	var ctx := GameState.trade_context(rival)
	var fresh := ctx.duplicate()
	fresh["phase"] = GameState._club_phase(rival)
	var give := [GameState.season.lists[rival][0]]
	var take := [GameState.my_list[GameState.my_list.size() - 1]]
	var a := Contracts.evaluate_trade(GameState.season.lists[rival], give, take, GameState.salary_cap, GameState.my_list, GameState.salary_cap, 0.0, ctx)
	var b := Contracts.evaluate_trade(GameState.season.lists[rival], give, take, GameState.salary_cap, GameState.my_list, GameState.salary_cap, 0.0, fresh)
	_check(str(a) == str(b), "A trade is valued the same with the cached phase as with a fresh one")
	var phases := {}
	for code in GameState.season.lists:
		phases[code] = GameState.club_phase(code)
	_check(GameState.save_career() and GameState.load_career() and _phases_fresh(), "After a load the phases match a fresh calculation")
	var same := true
	for code in phases:
		same = same and GameState.club_phase(code) == str(phases[code])
	_check(same, "A save and load doesn't change any club's phase")
	GameState.start_next_season()
	_check(_phases_fresh(), "After the rollover (ageing and development) the phases match a fresh calculation")


## Draft picks as trade assets: who owns them, what they're worth to whom,
## the rules a trade with them keeps, and the draft honouring a traded pick.
func _test_trade_picks() -> void:
	_new_season()
	_check(GameState.club_picks(GameState.my_club).is_empty(), "No picks can be traded during the season")
	_to_offseason()
	var me := GameState.my_club
	var year := GameState.season_year
	var rounds := GameState.trade_pick_rounds(year)
	var mine := GameState.club_picks(me)
	_check(rounds >= 1 and mine.size() == 2 * rounds, "Each club has one pick a round to trade, this year and next (%d rounds)" % rounds)
	var all_own := true
	for pk in mine:
		all_own = all_own and str(pk["owner"]) == me and str(pk["origin"]) == me
	_check(all_own, "Untraded picks belong to their own club")
	# What a pick is worth: earlier is worth more, a rebuilder values it more.
	var prospects: Array = GameState.trade_prospects()[str(year)]
	var n := GameDB.active_clubs(year).size()
	var first := TradeValue.pick_value([[1, 1.0]], prospects, "building")
	var mid := TradeValue.pick_value([[n / 2, 1.0]], prospects, "building")
	var late := TradeValue.pick_value([[2 * n, 1.0]], prospects, "building")
	_check(first > mid and mid > late and late > 0.0, "An earlier pick is worth more (%.2f, %.2f, %.2f)" % [first, mid, late])
	_check(TradeValue.pick_value([[3, 1.0]], prospects, "rebuilding") > TradeValue.pick_value([[3, 1.0]], prospects, "contending") * 1.3,
			"A rebuilding club values a high pick well above a contender")
	_check(TradeValue.pick_value([[prospects.size() + 1, 1.0]], prospects, "building") == 0.0,
			"A pick past the end of the class is worth nothing")

	var rival := "COL"
	var their_first := GameState.pick_id(year, 1, rival)
	var my_first := GameState.pick_id(year, 1, me)
	var my_last := GameState.pick_id(year, rounds, me)
	var sorted_mine := GameState.my_list.duplicate()
	sorted_mine.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	var my_weak := str(sorted_mine[0]["id"])
	var theirs := (GameState.season.lists[rival] as Array).duplicate()
	theirs.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	var their_weak := str(theirs[0]["id"])
	var their_star := str(theirs[theirs.size() - 1]["id"])
	_check(not bool(GameState.evaluate_trade(rival, [their_first], [their_weak])["ok"]),
			"You can't trade a pick that isn't yours")
	_check(not bool(GameState.evaluate_trade(rival, [my_weak], [my_first])["ok"]),
			"You can't ask a club for a pick it doesn't own")
	_check(not bool(GameState.evaluate_trade(rival, [my_first, my_first], [their_weak])["ok"]),
			"The same pick can't go in twice")
	_check(not bool(GameState.evaluate_trade(rival, [GameState.pick_id(year, 9, me)], [their_weak])["ok"])
			and not bool(GameState.evaluate_trade(rival, [GameState.pick_id(year + 3, 1, me)], [their_weak])["ok"]),
			"Only the rounds and years on offer can be traded")
	# The Butler regression holds with a late pick thrown in, in any order.
	var a := GameState.evaluate_trade(rival, [my_weak, my_last], [their_star])
	var b := GameState.evaluate_trade(rival, [my_last, my_weak], [their_star])
	_check(not bool(a["ok"]) and str(a) == str(b), "A fringe player and a late pick don't buy their best player, whatever the order")

	# A pick changes hands; lists and payrolls move only for the players.
	var my_size := GameState.my_list.size()
	var their_size := (GameState.season.lists[rival] as Array).size()
	var my_pay := GameState.my_payroll()
	var their_player: Dictionary = GameState.list_player(their_weak)
	var t := GameState.make_trade(rival, [my_first], [their_weak])
	if not bool(t["ok"]):
		t = GameState.make_trade(rival, [my_first, my_weak], [their_weak])
	_check(bool(t["ok"]), "A first-round pick buys a fringe player (%s)" % str(t["reason"]))
	var gave_player := GameState.my_list.size() == my_size
	_check(GameState.pick_owner_of(year, 1, me) == rival and GameState.club_picks(rival).any(func(pk): return str(pk["id"]) == my_first)
			and not GameState.club_picks(me).any(func(pk): return str(pk["id"]) == my_first),
			"The traded pick belongs to its new club")
	_check(GameState.my_list.size() == (my_size if gave_player else my_size + 1)
			and (GameState.season.lists[rival] as Array).size() == (their_size if gave_player else their_size - 1)
			and (gave_player or GameState.my_payroll() == my_pay + int(their_player.get("salary", 0))),
			"A pick takes no list spot and no salary")
	_check(not bool(GameState.evaluate_trade(rival, [my_first], [str(theirs[1]["id"])])["ok"]),
			"A pick you traded away can't be spent again")
	_check(GameState.save_career() and GameState.load_career() and GameState.pick_owner_of(year, 1, me) == rival,
			"Pick ownership survives a save and load")

	# The draft gives the pick to its new owner.
	_check(GameState.begin_intake_draft(), "The national draft opens")
	var d: Draft = GameState.draft
	var at := -1
	for k in range(d.pick_sequence.size()):
		if str(d.pick_origin[k]) == me and int(d.pick_rounds[k]) == 1 and d.comp_at(k).is_empty():
			at = k
	_check(at >= 0 and str(d.pick_sequence[at]) == rival, "Your traded first-round pick is theirs in the draft order")
	var my_comps := d.comp_picks.filter(func(c): return str(c["club"]) == me).size()
	var their_comps := d.comp_picks.filter(func(c): return str(c["club"]) == rival).size()
	_check(d.pick_limit(me) == d.target_size - 1 + my_comps and d.pick_limit(rival) == d.target_size + 1 + their_comps,
			"You make one pick fewer; they make one more")
	_check(GameState.save_career() and GameState.load_career() and str(GameState.draft.pick_sequence[at]) == rival
			and str(GameState.draft.pick_origin[at]) == me, "The draft keeps the traded pick through a save")
	d = GameState.draft
	while not d.is_finished():
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()
	var used_by := ""
	for id in d.picked:
		if int(d.pick_details(str(id)).get("pick", 0)) == at + 1:
			used_by = d.drafted_by(str(id))
	_check(used_by == rival, "The player taken with the traded pick goes to its new owner")
	_check(GameState.finish_intake_draft() and GameState.pick_owner.is_empty(), "Spent picks leave the ownership record")


func _run_draft() -> void:
	var d: Draft = GameState.draft
	while not d.is_finished():
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


## Next year's picks: valued with honest uncertainty about where a club will
## finish, owned once, and honoured a year later at the draft.
func _test_future_picks() -> void:
	_new_season()
	_to_offseason()
	var me := GameState.my_club
	var year := GameState.season_year
	var next := year + 1
	var clubs := GameDB.active_clubs(year)
	var n := clubs.size()
	var prospects: Array = GameState.trade_prospects()[str(next)]
	# The weakest and strongest clubs by what anyone can see.
	var by_standing := clubs.duplicate()
	by_standing.sort_custom(func(a, b):
		var sa: Array = GameState._standing(str(a))
		var sb: Array = GameState._standing(str(b))
		return float(sa[0]) + float(sa[1]) > float(sb[0]) + float(sb[1]))
	var weak := str(by_standing[0])
	var strong := str(by_standing[n - 1])
	var weak_pick := GameState.pick_asset(GameState.pick_id(next, 1, weak))
	var strong_pick := GameState.pick_asset(GameState.pick_id(next, 1, strong))
	_check(not weak_pick.is_empty() and not strong_pick.is_empty() and str(weak_pick["name"]).ends_with("%d first-round pick" % next),
			"Next year's picks can be traded, named without a number yet")
	var wv := TradeValue.pick_value(weak_pick["positions"], prospects, "building")
	var sv := TradeValue.pick_value(strong_pick["positions"], prospects, "building")
	var top := TradeValue.pick_value([[1, 1.0]], prospects, "building")
	var bottom := TradeValue.pick_value([[n, 1.0]], prospects, "building")
	_check(wv > sv, "A weak club's future first is worth more than a strong club's (%.2f v %.2f)" % [wv, sv])
	_check(wv < top and sv > bottom, "Nobody knows where a club will finish: a future first is never valued as the very first or last pick (%.2f..%.2f within %.2f..%.2f)" % [sv, wv, bottom, top])
	var spread := 0
	for pw in weak_pick["positions"]:
		if float(pw[1]) >= 0.3:
			spread += 1
	_check(spread >= 5, "A future pick spreads over several possible spots (%d)" % spread)

	# Trade your next-year first; it can't be traded again.
	var rival := "COL"
	var my_future := GameState.pick_id(next, 1, me)
	var sorted_mine := GameState.my_list.duplicate()
	sorted_mine.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	var theirs := (GameState.season.lists[rival] as Array).duplicate()
	theirs.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	var t := GameState.make_trade(rival, [my_future], [str(theirs[0]["id"])])
	if not bool(t["ok"]):
		t = GameState.make_trade(rival, [my_future, str(sorted_mine[0]["id"])], [str(theirs[0]["id"])])
	_check(bool(t["ok"]) and GameState.pick_owner_of(next, 1, me) == rival,
			"Your next-year first can be traded (%s)" % str(t["reason"]))
	_check(not bool(GameState.evaluate_trade(rival, [my_future], [str(theirs[1]["id"])])["ok"]),
			"A future pick you traded can't be spent again")
	_check(GameState.save_career() and GameState.load_career() and GameState.pick_owner_of(next, 1, me) == rival,
			"Future-pick ownership survives a save and load")

	# This year's draft leaves it alone; a year on it is theirs at the draft.
	_check(GameState.begin_intake_draft(), "This year's draft opens")
	var d: Draft = GameState.draft
	var mine_now := 0
	for k in range(d.pick_sequence.size()):
		if str(d.pick_origin[k]) == me and int(d.pick_rounds[k]) == 1 and d.comp_at(k).is_empty():
			mine_now = 1 if str(d.pick_sequence[k]) == me else 0
	_check(mine_now == 1, "Trading next year's pick leaves this year's with you")
	_run_draft()
	_check(GameState.finish_intake_draft() and GameState.season_year == next
			and GameState.pick_owner_of(next, 1, me) == rival, "The future pick carries over the rollover")
	_to_offseason()
	var now := GameState.pick_asset(GameState.pick_id(next, 1, me))
	_check(not now.is_empty() and str(now["owner"]) == rival and (now["positions"] as Array).size() == 1
			and str(now["name"]).contains("(No. "), "A year on it is this year's pick, at its exact spot, still theirs")
	_check(not GameState.pick_asset(GameState.pick_id(next + 1, 1, me)).is_empty()
			and GameState.pick_asset(GameState.pick_id(next + 2, 1, me)).is_empty(),
			"The next year opens for trading; the one after doesn't")
	_check(GameState.begin_intake_draft(), "Next year's draft opens")
	d = GameState.draft
	var at := -1
	for k in range(d.pick_sequence.size()):
		if str(d.pick_origin[k]) == me and int(d.pick_rounds[k]) == 1 and d.comp_at(k).is_empty():
			at = k
	_check(at >= 0 and str(d.pick_sequence[at]) == rival, "At that draft the pick is theirs")
