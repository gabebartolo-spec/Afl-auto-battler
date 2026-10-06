extends RefCounted
## Trade volume against the real AFL (director, 2026-10-06: "increase trades").
## One League Draft career per seed; your club works its list ("full": the
## dynasty bot's contracts, free agency and trading up). Per off-season it
## prints the league's trades with each other (ai_trade), the offers rivals
## make to you, the trades your club completes, and - for each rival's best
## fit, offered your most expendable pick - the rival's answer, so the
## reasons trades die can be counted.
## Real 2024: about 33 trades, 13 moving a player, every club in at least one.
## Args after the impl name: seeds (comma-separated) seasons.

var dyn = load("res://tools/balance/dynasty.gd").new()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := str(args[1]) if args.size() > 1 else "301"
	var seasons := int(args[2]) if args.size() > 2 else 4
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
	for y in range(seasons):
		while not gs.season.is_season_over():
			dyn._play_week(gs, user, true)
		if y == seasons - 1:
			break
		gs.open_offseason()
		var ai: Array = gs.offseason_log.filter(func(e): return str(e.get("kind", "")) == "ai_trade")
		var ai_players := 0
		var clubs_in := {}
		for e in ai:
			clubs_in[str(e["club"])] = true
			clubs_in[str(e["with"])] = true
			ai_players += (e.get("in", []) as Array).size()
		var asked := {"home": 0, "games": 0}
		var asked_mine := 0
		for id in gs.trade_requests:
			var r: Dictionary = gs.trade_requests[id]
			asked[str(r["why"])] = int(asked[str(r["why"])]) + 1
			asked_mine += 1 if str(r["club"]) == user else 0
		var met := {"home": 0, "games": 0}
		for e in ai:
			if e.has("request"):
				met[str(e["request"])] = int(met[str(e["request"])]) + 1
				asked[str(e["request"])] = int(asked[str(e["request"])]) + 1
		var offers: int = gs.open_trade_offers().size()
		var reasons := _probe(gs, user)
		var mgmt: Dictionary = dyn._manage(gs, user, "full")
		print("trades seed %d %d %s | ai trades %d (players %d, clubs in one %d) | asked %s, yours %d, met %s | offers to you %d | yours %d | probe %s" % [
				seed, gs.season_year, user, ai.size(), ai_players, clubs_in.size(), str(asked), asked_mine, str(met),
				offers, int(mgmt["trades"]), str(reasons)])
		gs.set_selection({})
		if not dyn._offseason(gs, user, mgmt):
			push_error("trades: off-season %d of seed %d did not complete" % [y, seed])
			break


## For every rival: its player who'd walk into your side (the dynasty bot's
## rule), offered your latest-round pick alone; then pick + a spare player.
## Counts the answers by reason.
func _probe(gs, user: String) -> Dictionary:
	var out := {}
	var line22: float = dyn.nth_value(gs.my_list, 21)
	var picks: Array = gs.club_picks(user)
	picks.sort_custom(func(a, b): return int(a["round"]) > int(b["round"]))
	if picks.is_empty():
		return {"no picks": 1}
	var first_round := picks.filter(func(pk): return int(pk["round"]) == 1)
	for club in GameDB.active_clubs(gs.season_year):
		if str(club) == user:
			continue
		var target := {}
		for q in gs.season.lists.get(club, []):
			var v: float = dyn.expected_overall(q, 1)
			if v >= line22 + 3.0 and float(q.get("age", 30.0)) <= 30.0 \
					and (target.is_empty() or v > dyn.expected_overall(target, 1)):
				target = q
		if target.is_empty():
			out["no target"] = int(out.get("no target", 0)) + 1
			continue
		var tid := str(target["id"])
		for tier in [["late pick", [str(picks[0]["id"])]],
				["first-round pick", [str(first_round[0]["id"])] if not first_round.is_empty() else []]]:
			if (tier[1] as Array).is_empty():
				continue
			var r: Dictionary = gs.evaluate_trade(str(club), tier[1], [tid])
			var key := "%s: %s" % [tier[0], "yes" if bool(r.get("ok", false)) else _short(str(r.get("reason", "")))]
			out[key] = int(out.get(key, 0)) + 1
	return out


func _short(reason: String) -> String:
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
	return reason.left(30)
