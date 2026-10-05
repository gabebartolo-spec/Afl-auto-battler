extends RefCounted
## Coaching mobility: how many assistants move each offseason league-wide, and
## how long your own original assistants stay, with no action from you.

func run() -> void:
	var seed := 20270
	var my := "GEE"
	var coaches: Dictionary = Coaches.seed(my)
	var archive := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var original := {}
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) == "club" and str(c["club"]) == my:
			original[cid] = str(c["job"])
	var y0 := 2027
	var tot := {"sc": 0, "assistant_moves": 0, "retired": 0, "poached": 0}
	for y in range(y0, y0 + 10):
		var where := {}
		for cid in coaches:
			var c: Dictionary = coaches[cid]
			where[cid] = "%s|%s|%s" % [c.get("status", ""), c.get("club", ""), c.get("job", "")]
		var res := {}
		for club in GameDB.active_clubs(y):
			res[club] = {"met": rng.randf() < 0.62, "severe": false, "finals": false}
		var out := CoachMarket.offseason({"coaches": coaches, "archive": archive, "year": y, "my_club": my,
				"clubs": GameDB.active_clubs(y + 1), "results": res, "premier": "", "seed": seed})
		var open: Array = []
		for v in out["vacancies"]:
			open.append(str(v["job"]))
		while not open.is_empty():
			var left := CoachMarket.auto_fill(coaches, my, str(open.pop_front()), y, seed)
			if left != "":
				open.append(left)
		var a_moves := 0
		var ai_assist := 0
		for cid in coaches:
			var c: Dictionary = coaches[cid]
			if str(c.get("status", "")) == "club" and str(c["job"]) != "SC" and str(c["club"]) != my:
				ai_assist += 1
				if where.get(cid, "") != "club|%s|%s" % [c["club"], c["job"]]:
					a_moves += 1
		var kept := 0
		for cid in original:
			if coaches.has(cid) and str(coaches[cid].get("status", "")) == "club" \
					and str(coaches[cid]["club"]) == my and str(coaches[cid]["job"]) == original[cid]:
				kept += 1
		tot["sc"] += int(out["log"]["sc_changes"])
		tot["assistant_moves"] += a_moves
		tot["poached"] += int(out["log"].get("poached_from_you", 0))
		print("offseason %d: AI senior coach changes %d | AI assistant jobs changing hands %d of %d (%.0f%%) | yours poached %d | your original %d assistants still in the same job: %d" % [
			y, int(out["log"]["sc_changes"]), a_moves, ai_assist, 100.0 * a_moves / maxf(1, ai_assist),
			int(out["log"].get("poached_from_you", 0)), original.size(), kept])
	print("TOTAL 10 offseasons: SC changes %d, AI assistant moves %d, yours poached %d" % [tot["sc"], tot["assistant_moves"], tot["poached"]])
