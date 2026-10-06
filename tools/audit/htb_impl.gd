extends RefCounted
## Holding the ball by role and zone (measurement only): frees against for
## holding the ball per 100 disposals, by the offender's role and where it was
## paid (his defensive 50, the back half, the front half, his forward 50),
## alongside real 2026 frees against and disposals a game.
## Env: HTB_DRAFTS (default 21,22). Drafted leagues, one home-and-away season.

func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var drafts := [21, 22]
	if OS.get_environment("HTB_DRAFTS") != "":
		drafts = []
		for s in OS.get_environment("HTB_DRAFTS").split(","):
			drafts.append(int(s))
	var f50 := float(Ratings.T["forward50_line"])
	var disp := {}   # "role|zone" -> disposals
	var htb := {}    # "role|zone" -> holding-the-ball frees against
	var info := {}
	var pg := {}     # role -> player-games
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		for c in codes:
			for p in lists[c]:
				info[str(p["id"])] = p
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		while not season.is_regular_done():
			for res in season.play_round():
				for side_r in res.get("roster", []):
					for r in side_r:
						var rp = info.get(str(r["id"]))
						if rp != null:
							pg[str(rp.get("role", ""))] = int(pg.get(str(rp.get("role", "")), 0)) + 1
				for e in res.get("events", []):
					var kind := str(e.get("kind", ""))
					var who := ""
					var side := int(e.get("side", 0))
					if kind == "kick" or kind == "handball":
						who = str(e.get("player_id", ""))
					elif kind == "free" and str(e.get("free_cause", "")) == "holding_ball":
						who = str(e.get("against_id", ""))
						side = 1 - side
					else:
						continue
					var p = info.get(who)
					if p == null:
						continue
					# Field position from the player's own side: + is attacking.
					var at := float(e.get("fp", 0.0)) * (1.0 if side == 0 else -1.0)
					var zone := "own 50" if at < -f50 else ("back half" if at < 0.0 else ("front half" if at < f50 else "forward 50"))
					var key := "%s|%s" % [str(p.get("role", "")), zone]
					if kind == "free":
						htb[key] = int(htb.get(key, 0)) + 1
					else:
						disp[key] = int(disp.get(key, 0)) + 1
		print("league %d done" % int(d))
	print("## Holding the ball against per 100 disposals, by role and zone")
	print("| role | own 50 | back half | front half | forward 50 | all |")
	print("|---|---|---|---|---|---|")
	for role in ["DEF", "MID", "FWD", "RUCK"]:
		var cells := PackedStringArray()
		var td := 0
		var th := 0
		for zone in ["own 50", "back half", "front half", "forward 50"]:
			var k := "%s|%s" % [role, zone]
			var dd := int(disp.get(k, 0))
			var hh := int(htb.get(k, 0))
			td += dd
			th += hh
			cells.append("%.2f (%d/%d)" % [100.0 * hh / maxf(1, dd), hh, dd])
		print("| %s | %s | %.2f |" % [role, " | ".join(cells), 100.0 * th / maxf(1, td)])
	print("")
	print("## Disposals per player-game by role: sim vs real 2026")
	var real := {}
	for c in codes:
		for p in GameDB.club_list(str(c)):
			var role := str(p.get("role", ""))
			if not real.has(role):
				real[role] = [0.0, 0.0]
			real[role][0] += float(p.get("di", 0.0))
			real[role][1] += float(p.get("gm", 0.0))
	for role in ["DEF", "MID", "FWD", "RUCK"]:
		var sd := 0
		for zone in ["own 50", "back half", "front half", "forward 50"]:
			sd += int(disp.get("%s|%s" % [role, zone], 0))
		var r: Array = real.get(role, [0.0, 1.0])
		print("| %s | sim %.1f | real %.1f |" % [role, float(sd) / maxf(1, int(pg.get(role, 0))), r[0] / maxf(1.0, r[1])])
