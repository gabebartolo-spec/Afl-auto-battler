extends RefCounted
## Contracts, free agency and trades. Run through tests/run_contracts_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_initial_contracts()
	_test_offseason_flow()
	_test_negotiation_rules()
	_test_negotiation()
	_test_free_agent_terms()
	_test_free_agents()
	_test_compensation_rules()
	_test_compensation_draft_order()
	_test_compensation_flow()
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
	GameState.salary_cap += 40
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
	_check(Contracts.lowest(star, 3) == Contracts.asking_salary(star) and Contracts.lowest(regular, 3) == ask - 1
			and Contracts.lowest(regular, 4) == ask - 1 and Contracts.lowest(regular, 1) == ask + 1
			and Contracts.lowest(fringe, 2) < Contracts.asking_salary(fringe),
			"A star won't take less; others give a little for security; a short deal costs a point")
	# No cliff: leverage moves smoothly with rating, and one rating point never
	# moves his lowest price by more than a point.
	var smooth := true
	var prev := {}
	for ovr in range(55, 92):
		var q := {"id": "n_s", "overall": ovr, "potential": ovr, "age": 26.0, "morale": 70}
		if not prev.is_empty():
			if Contracts.leverage(q) - Contracts.leverage(prev) > 0.05 or absi(Contracts.lowest(q, 3) - Contracts.lowest(prev, 3)) > 1:
				smooth = false
		prev = q
	_check(smooth, "Leverage and price scale smoothly with rating: no threshold where the rules change")
	_check(str(Contracts.respond(regular, ask - 1, 3)["answer"]) == "accept"
			and str(Contracts.respond(regular, ask - 2, 3)["answer"]) == "counter"
			and int(Contracts.respond(regular, ask - 2, 3)["salary"]) == ask - 1,
			"An offer at his lowest is accepted; below it he counts with his lowest")
	_check(str(Contracts.respond(regular, ask, 1)["answer"]) == "counter",
			"His asking price over a shorter term than he wants gets a counter")
	_check(bool(Contracts.respond(regular, 1, 3)["insult"]) and str(Contracts.respond(regular, 1, 3, 1)["answer"]) == "walk"
			and str(Contracts.respond(regular, ask - 2, 3, Contracts.MAX_OFFERS - 1)["answer"]) == "walk",
			"An insulting offer counts double, and too many failed offers end the talks")
	_check(str(Contracts.respond(regular, ask - 2, 3)) == str(Contracts.respond(regular, ask - 2, 3)),
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
	GameState.salary_cap += 40
	var talkers := []
	for p in Contracts.expiring(GameState.my_list):
		var w := Contracts.wants(p)
		if Contracts.lowest(p, int(w["years"])) < int(w["salary"]) and int(w["salary"]) >= 3:
			talkers.append(p)
	_check(talkers.size() >= 2, "Two of your out-of-contract players can be negotiated with (%d)" % talkers.size())
	if talkers.size() < 2:
		return
	var a: Dictionary = talkers[0]
	var id := str(a["id"])
	var years := int(Contracts.wants(a)["years"])
	var floor_price := Contracts.lowest(a, years)
	var before := int(a["salary"])
	var r := GameState.offer_contract(id, floor_price - 1, years)
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
	r = GameState.offer_contract(bid, 1, 3)
	_check(ClubLife.morale(b) < morale_before and str(r["reason"]).begins_with("He's insulted"),
			"An insulting offer costs morale and he says so")
	r = GameState.offer_contract(bid, 1, 3)
	_check(str(r["answer"]) == "walk" and bool(GameState.contract_talks(bid).get("walked", false)),
			"Too many failed offers and he walks")
	_check(not bool(GameState.offer_contract(bid, 99, 3)["ok"]), "No more offers once talks break down")
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
	_check(Contracts.prefers(p, o.call(ask + 1, 3, "bench", 0.5), o.call(ask, 3, "bench", 0.5))
			and Contracts.offer_view(p, o.call(ask + 1, 3, "bench", 0.5), o.call(ask, 3, "bench", 0.5), "X") == "Best financial offer.",
			"Salary matters in a close decision, and he says so")
	_check(Contracts.prefers(p, o.call(ask, 3, "bench", 0.5), o.call(ask, 1, "bench", 0.5))
			and Contracts.offer_view(p, o.call(ask, 3, "bench", 0.5), o.call(ask, 1, "bench", 0.5), "X") == "More contract security.",
			"Contract security matters in a close decision")
	_check(Contracts.prefers(p, o.call(ask, 3, "ground", 0.5), o.call(ask + 1, 3, "depth", 0.5))
			and Contracts.offer_view(p, o.call(ask, 3, "ground", 0.5), o.call(ask + 1, 3, "depth", 0.5), "X") == "Clearer path into the best 22.",
			"A spot in the best 22 beats one more salary point to sit in the twos")
	_check(Contracts.prefers(p, o.call(ask, 3, "bench", 0.0), o.call(ask, 3, "bench", 1.0))
			and Contracts.offer_view(p, o.call(ask, 3, "bench", 0.0), o.call(ask, 3, "bench", 1.0), "Carlton").contains("Carlton's offer after their stronger season"),
			"The club's last season counts when all else is level")
	_check(Contracts.prefers(p, o.call(ask + 3, 3, "depth", 0.5), o.call(ask, 3, "ground", 0.5)),
			"Enough money still wins: nothing is absolute")
	# Equal in his eyes: more money first, never a list position.
	var a: Dictionary = o.call(8, 3, "depth", 0.5)
	var b: Dictionary = o.call(7, 3, "bench", 0.1875)
	_check(Contracts.prefers(p, a, b) and not Contracts.prefers(p, b, a), "A dead heat goes to the bigger salary")
	# Club valuations come from his role there, and stop at the cap.
	_check(Contracts.club_max(p, "ground", 99) == ask + 2 and Contracts.club_max(p, "bench", 99) == ask + 1
			and Contracts.club_max(p, "depth", 99) == Contracts.lowest(p, Contracts.ai_years(p))
			and Contracts.club_max(p, "ground", 3) == 3, "A club pays a starter more than a depth player, never past its cap room")
	# Rival answers.
	var match_r := Contracts.rival_response(p, o.call(ask, 3, "ground", 0.5), o.call(ask + 2, 3, "ground", 0.6), ask + 3)
	_check(str(match_r["action"]) == "match" and int(match_r["salary"]) == ask + 2, "A rival can match the leading salary")
	var up := Contracts.rival_response(p, o.call(ask, 3, "bench", 0.5), o.call(ask + 1, 3, "bench", 0.5), ask + 3)
	_check(str(up["action"]) == "improve" and int(up["salary"]) == ask + 2, "A rival improves just enough to lead")
	var out := Contracts.rival_response(p, o.call(ask, 3, "ground", 0.5), o.call(ask + 4, 3, "ground", 0.5), ask + 2)
	_check(str(out["action"]) == "withdraw", "A rival withdraws once the price passes what he's worth to it")
	var stay := Contracts.rival_response(p, o.call(ask - 1, 1, "depth", 1.0), o.call(ask - 1, 3, "ground", 0.0), ask - 1)
	_check(str(stay["action"]) == "hold" and int(stay["salary"]) == ask - 1, "A rival that can't win but isn't priced out holds")


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
		var r0 := GameState.offer_free_agent(str(refused["id"]), 50, 3)
		_check(not bool(r0["ok"]) and str(r0["answer"]) == "reject" and GameState.free_agents.has(refused),
				"A player who won't come turns down even a big offer, and says why")
	# Bidding against rivals for a player who would start for you.
	GameState.salary_cap += 80
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
	var r := GameState.offer_free_agent(id, low - 1, years)
	_check(str(r["answer"]) == "counter" and GameState.fa_offers(id).filter(func(x): return bool(x["mine"])).is_empty(),
			"Under his lowest price he counters, and nothing goes on the table")
	var top: Dictionary = GameState.fa_offers(id)[0]
	var bid := int(top["salary"]) + 1
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
	var final_salary := int(lead["salary"]) + (0 if bool(lead["mine"]) else 1)
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
		GameState.offer_free_agent(sid, int(lead2["salary"]) + 1, int(Contracts.wants(star)["years"]))
		var lead3: Dictionary = GameState.fa_offers(sid)[0]
		GameState.offer_free_agent(sid, int(lead3["salary"]) + (0 if bool(lead3["mine"]) else 1), int(Contracts.wants(star)["years"]))
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
	var v_star := Contracts.compensation_value(star, 9, 3)
	var v_fringe := Contracts.compensation_value(fringe, 3, 1)
	var a_star := Contracts.compensation_after(v_star, clubs)
	var a_fringe := Contracts.compensation_after(v_fringe, clubs)
	_check(a_star > 0 and (a_fringe == 0 or a_fringe > a_star),
			"Losing a star earns a far better pick than losing a fringe player (after %d v %d)" % [a_star, a_fringe])
	var mid := {"id": "c_mid", "overall": 72, "age": 27.0}
	var base := Contracts.compensation_value(mid, 6, 2)
	var young := mid.duplicate()
	young["age"] = 23.0
	_check(Contracts.compensation_value(young, 6, 2) > base and Contracts.compensation_value(mid, 7, 2) > base
			and Contracts.compensation_value(mid, 6, 4) > base,
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
	GameState.salary_cap += 80
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
