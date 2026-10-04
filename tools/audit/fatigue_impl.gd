extends RefCounted
## Fatigue parity: how loaded each club's match-day players are, the user's
## club against the AI clubs, on auto-pick and with a side fixed at Round 1.

func _played_load(code: String, res: Dictionary, lists: Dictionary) -> Array:
	var ex: Dictionary = res.get("exertion", {})
	var tot := 0.0
	var cap := 0.0
	var n := 0
	for p in lists[code]:
		if ex.has(str(p["id"])) and float(ex[str(p["id"])]) > 0.0:
			tot += Workload.value(p)
			cap += Workload.energy_cap(p)
			n += 1
	return [tot, cap, n]

func _season(label: String, fixed: bool, club: String) -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.start_season(club, GameDB.club_list(club))
	if fixed:
		GameState.set_selection(GameState.current_side())
	var mine := [0.0, 0.0, 0]
	var ai := [0.0, 0.0, 0]
	var heavy_mine := 0
	var heavy_ai := 0
	var rounds := 0
	while not GameState.season.is_regular_done() and rounds < 23:
		# Load going INTO this round, for the players who then play it.
		var before := {}
		for code in GameState.season.lists:
			for p in GameState.season.lists[code]:
				before[str(p["id"])] = Workload.value(p)
		GameState.advance()
		rounds += 1
		if rounds < 4:
			continue   # let loads build up first
		for res in GameState.last_results:
			for code in [str(res["home"]), str(res["away"])]:
				var ex: Dictionary = res.get("exertion", {})
				for p in GameState.season.lists[code]:
					var id := str(p["id"])
					if not ex.has(id) or float(ex[id]) <= 0.0:
						continue
					var w := float(before.get(id, 0.0))
					var bucket: Array = mine if code == club else ai
					bucket[0] += w
					bucket[1] += maxf(70.0, 100.0 - w * 0.4)
					bucket[2] += 1
					if w >= Workload.NEEDS_BREAK:
						if code == club: heavy_mine += 1
						else: heavy_ai += 1
	var ai_clubs := float(GameState.season.lists.size() - 1)
	print("%s %s: rounds=%d | YOU mean load into games %.1f, mean energy cap %.1f, needs-a-break appearances %.1f/round | AI mean load %.1f, cap %.1f, needs-a-break %.1f/club/round" % [
		label, club, rounds, mine[0] / maxf(1, mine[2]), mine[1] / maxf(1, mine[2]), float(heavy_mine) / maxf(1, rounds - 3),
		ai[0] / maxf(1, ai[2]), ai[1] / maxf(1, ai[2]), float(heavy_ai) / maxf(1, (rounds - 3) * ai_clubs)])

func run() -> void:
	for club in ["COL", "MEL"]:
		_season("AUTO-PICK ", false, club)
		_season("FIXED SIDE", true, club)
	GameState.reset()
