extends RefCounted
## How much the merit pass (Ratings.merit_lines) changes auto-picked sides,
## league-wide (measurement only). Drafted leagues, one home-and-away season
## each; before every round each club's side is picked with and without the
## pass. Per club-round: players changed on the ground, and by line who came in
## on a second position. Env: SM_DRAFTS (default 21,22,23,24).

func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var drafts := [21, 22, 23, 24]
	if OS.get_environment("SM_DRAFTS") != "":
		drafts = []
		for s in OS.get_environment("SM_DRAFTS").split(","):
			drafts.append(int(s))
	var club_rounds := 0
	var changed_rounds := 0
	var changed_players := 0
	var by_line := {}
	var in_ovr := 0.0
	var out_ovr := 0.0
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		while not season.is_regular_done():
			for c in codes:
				var list: Array = season.lists[c]
				var pool := []
				for p in list:
					if Ratings.available(p):
						pool.append(p)
				Ratings.merit_lines = false
				var a: Dictionary = Ratings.select_22(pool)
				Ratings.merit_lines = true
				var b: Dictionary = Ratings.select_22(pool)
				var ids_a := {}
				for g in a["ground"]:
					ids_a[str(g["id"])] = g
				var n := 0
				for g in b["ground"]:
					if not ids_a.has(str(g["id"])):
						n += 1
						var line := str(g["role"])
						by_line[line] = int(by_line.get(line, 0)) + 1
						in_ovr += _slot_rating(g, line)
				var ids_b := {}
				for g in b["ground"]:
					ids_b[str(g["id"])] = true
				for g in a["ground"]:
					if not ids_b.has(str(g["id"])):
						out_ovr += _slot_rating(g, str(g["role"]))
				club_rounds += 1
				changed_players += n
				if n > 0:
					changed_rounds += 1
			season.play_round()
		print("league %d done" % int(d))
	print("SELMERIT club-rounds %d | sides changed %d (%.0f%%) | players changed per club-round %.2f | in by line %s | rating in the slot: in %.1f vs out %.1f" % [
			club_rounds, changed_rounds, 100.0 * changed_rounds / maxf(1, club_rounds),
			float(changed_players) / maxf(1, club_rounds), str(by_line),
			in_ovr / maxf(1, changed_players), out_ovr / maxf(1, changed_players)])


## His rating in the slot he was picked for (slot copies carry own_role).
func _slot_rating(g: Dictionary, line: String) -> float:
	if str(g.get("own_role", g.get("role", ""))) == line or (g.get("attr", {}) as Dictionary).is_empty():
		return float(g.get("overall", 0))
	return float(Ratings.rate_overall(g["attr"], line, Ratings.effective_games(g)))
