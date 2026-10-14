extends RefCounted
## What a slow start does to a final (the finals cards' "small chance"): the same
## Grand Final played over many seeds, with and without the slow-start flag. Args after
## the impl name: matches home away (`slow_start_impl 500 FRE WBD`). Arms: nobody
## flagged; the whole home side flagged (the side's chance, A6 and B1); the home side's
## best player alone (B3). Prints the home side's win rate, mean margin and first-quarter
## margin for each arm, and the effect of the card's chance on a whole final.
## Measurement only: it never changes a rule.


func _arm(sea: Season, home: String, away: String, matches: int, flag: String) -> Dictionary:
	for p in sea.lists[home]:
		p.erase("slow_start")
	if flag == "side":
		for p in sea.lists[home]:
			p["slow_start"] = true
	elif flag == "star":
		var best: Dictionary = sea.lists[home][0]
		for p in sea.lists[home]:
			if int(p["overall"]) > int(best["overall"]):
				best = p
		best["slow_start"] = true
	var wins := 0
	var draws := 0
	var margin := 0.0
	var q1 := 0.0
	var done := 0
	var batch := 25
	var i := 0
	while i < matches:
		var sims := []
		for k in range(mini(batch, matches - i)):
			sims.append(sea.match_sim(home, away, 900001 + (i + k) * 7919, [false, false], true, "perfect"))
		for res in Season.run_all(sims):
			var sc: Array = res["score"]
			var m: int = int(sc[0]) - int(sc[1])
			wins += 1 if m > 0 else 0
			draws += 1 if m == 0 else 0
			margin += float(m)
			var qs: Array = res["quarters"]
			q1 += float(int(qs[0][0]) - int(qs[0][1]))
			done += 1
		i += batch
	for p in sea.lists[home]:
		p.erase("slow_start")
	return {"win": (wins + 0.5 * draws) / float(done), "margin": margin / float(done), "q1": q1 / float(done), "n": done}


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var matches := int(args[1]) if args.size() > 1 else 500
	var home := str(args[2]) if args.size() > 2 else "FRE"
	var away := str(args[3]) if args.size() > 3 else "WBD"
	GameState.reset()
	GameState.career_seed = 5
	GameState.replay_seed = 5
	GameState.start_season(home, GameDB.club_list(home))
	var sea: Season = GameState.season
	var base := _arm(sea, home, away, matches, "")
	var side := _arm(sea, home, away, matches, "side")
	var star := _arm(sea, home, away, matches, "star")
	print("ARM none  | win %.3f | margin %+.2f | first quarter %+.2f | %d finals" % [base["win"], base["margin"], base["q1"], base["n"]])
	print("ARM side  | win %.3f | margin %+.2f | first quarter %+.2f" % [side["win"], side["margin"], side["q1"]])
	print("ARM star  | win %.3f | margin %+.2f | first quarter %+.2f" % [star["win"], star["margin"], star["q1"]])
	var chance := 0.20
	print("EFFECT of the side's slow start when it happens: win %+.1f points of 100, margin %+.1f points" % [
			100.0 * (float(side["win"]) - float(base["win"])), float(side["margin"]) - float(base["margin"])])
	print("EFFECT averaged over the %d percent chance: win %+.2f points of 100, margin %+.2f points a final" % [
			int(chance * 100.0), 100.0 * chance * (float(side["win"]) - float(base["win"])),
			chance * (float(side["margin"]) - float(base["margin"]))])
	print("EFFECT of the star's slow start when it happens: win %+.1f points of 100, margin %+.1f points" % [
			100.0 * (float(star["win"]) - float(base["win"])), float(star["margin"]) - float(base["margin"])])
