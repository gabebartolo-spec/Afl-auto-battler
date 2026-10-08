extends RefCounted
## League Draft horizon (director's PC playtest, 2026-10-07, P0): who goes
## where, with the AI valuing the seasons a player will give (Draft
## horizon_value) against the old blend of today's rating and POT.
## Env: HZ_SEEDS (default 101,202,303), HZ_OFF=1 for the old valuation.
## Every club, yours included, is picked by the AI, so the board is the AI's.

const NAMES := ["Cody Walker", "Sam Darcy", "Jagga Smith", "Noah Anderson", "Max Gawn", "Tom Stewart",
		"Max Hall", "Cal Wilkie", "Josh Worrell", "Jake Waterman", "Daniel McStay", "Patrick Voss",
		"Luke Jackson", "Jack Viney", "Nick Daicos", "Harley Reid", "Colby McKercher", "Patrick Dangerfield"]


func run() -> void:
	Draft.horizon_value = OS.get_environment("HZ_OFF") != "1"
	var seeds := [101, 202, 303]
	if OS.get_environment("HZ_SEEDS") != "":
		seeds = []
		for s in OS.get_environment("HZ_SEEDS").split(","):
			seeds.append(int(s))
	print("horizon_value ", Draft.horizon_value, " seeds ", seeds)
	var where := {}
	var agg := {"r1_age": 0.0, "r1_n": 0, "top30_31plus": 0, "top30_under23": 0,
			"young_ceiling_late": 0, "first_kpf_11": 0, "value_rank_gap": 0.0, "n_seeds": 0}
	for sd in seeds:
		var players: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
		var draft := Draft.new(players, GameDB.active_clubs(2027).duplicate(), int(sd))
		draft.start_for_user("COL")
		var guard := 0
		var order := []
		while not draft.is_finished() and guard < 5000:
			guard += 1
			var club := draft.current_club()
			var cand := draft._best_ai_pick(club)
			if cand.is_empty() or not draft._draft_pick(club, cand):
				if not cand.is_empty():
					print("horizon: skip at pick %d, %s could not take %s %s" % [order.size() + 1, club, str(cand.get("first", "")), str(cand.get("last", ""))])
				draft._skip_current_pick()
			else:
				order.append([cand, club])
		agg["n_seeds"] += 1
		var nclubs := draft.clubs.size()
		for i in range(order.size()):
			var p: Dictionary = order[i][0]
			var age := float(p.get("age", 25))
			if i < nclubs:
				agg["r1_age"] += age
				agg["r1_n"] += 1
			if i < 30:
				if age >= 31.0:
					agg["top30_31plus"] += 1
				if age <= 23.0:
					agg["top30_under23"] += 1
			if i < 11 and str(p.get("role", "")) == "FWD" and float(p.get("height_cm", 0)) >= 192.0:
				agg["first_kpf_11"] += 1
			if i >= 60 and age <= 23.0 and int(p.get("potential", 0)) >= 88:
				agg["young_ceiling_late"] += 1
			var nm := "%s %s" % [str(p.get("first", "")), str(p.get("last", ""))]
			if NAMES.has(nm):
				if not where.has(nm):
					where[nm] = []
				(where[nm] as Array).append("%d %s(%s)" % [i + 1, str(order[i][1]), draft.club_horizon(str(order[i][1]))])
		# How far the order strays from six-season worth (a builder's view).
		var by_value := order.duplicate()
		by_value.sort_custom(func(a, b): return draft.horizon_worth(a[0], "build") > draft.horizon_worth(b[0], "build"))
		var rank := {}
		for i in range(by_value.size()):
			rank[str(by_value[i][0]["id"])] = i
		var gap := 0.0
		for i in range(mini(60, order.size())):
			gap += absf(float(i) - float(rank[str(order[i][0]["id"])]))
		agg["value_rank_gap"] += gap / 60.0
	var n := float(agg["n_seeds"])
	print("horizon: first round mean age %.1f" % (float(agg["r1_age"]) / maxf(1.0, float(agg["r1_n"]))))
	print("horizon: top 30 picks aged 31+ %.1f, aged 23 or under %.1f (per draft)" % [agg["top30_31plus"] / n, agg["top30_under23"] / n])
	print("horizon: tall forwards (192 cm+) in the first 11 picks %.1f" % (agg["first_kpf_11"] / n))
	print("horizon: 23-or-under with POT 88+ still there after pick 60: %.1f per draft" % (agg["young_ceiling_late"] / n))
	print("horizon: first 60 picks, mean distance from six-season-worth order %.1f places" % (agg["value_rank_gap"] / n))
	var names := where.keys()
	names.sort()
	for nm in names:
		print("horizon: %-20s %s" % [nm, ", ".join(PackedStringArray(where[nm]))])
	Draft.horizon_value = true
