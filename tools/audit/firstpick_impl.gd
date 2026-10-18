extends RefCounted
## Measurement only: how often the career draft's first AI pick is one of the
## consensus top eight (the tests/test_draft.gd check). Args after the impl
## name: n (number of draft seeds, default 400).
## godot --headless --path . --script tools/audit/run_audit.gd -- firstpick_impl 400


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[1]) if args.size() > 1 else 400
	var real := Draft.new(GameDB.all_players_sorted() + GameDB.all_draftees_sorted(),
			GameDB.active_clubs(2027).duplicate(), 4242)
	var by_worth: Array = real.pool.duplicate()
	by_worth.sort_custom(func(a, b): return real._worth(a) > real._worth(b))
	var top := {}
	for i in range(12):
		var q: Dictionary = by_worth[i]
		print("RANK %d %s %s %s ov=%s pot=%s age=%s worth=%.2f" % [i + 1, q.get("club", ""),
				q.get("first", q.get("name", "")), q.get("last", ""), q.get("overall"),
				q.get("potential"), q.get("age", "?"), real._worth(q)])
		if i < 8:
			top[str(q["id"])] = true
	var floor_w: float = real._worth(by_worth[7]) - 4.0
	var near := 0
	var near12 := 0
	var hits := 0
	var hits12 := 0
	var outside := {}
	for s in range(n):
		var d := Draft.new(real.pool, GameDB.active_clubs(2027).duplicate(), 9001 + s * 31)
		var first: Dictionary = d._best_ai_pick(d.current_club())
		if real._worth(first) >= floor_w:
			near += 1
			if s < 12:
				near12 += 1
		var ok := top.has(str(first["id"]))
		if ok:
			hits += 1
			if s < 12:
				hits12 += 1
		else:
			var k := "%s" % first.get("last", first["id"])
			outside[k] = int(outside.get(k, 0)) + 1
	print("NEAR within4=%d rate=%.4f first12=%d" % [near, float(near) / n, near12])
	print("SUMMARY n=%d credible=%d rate=%.4f first12=%d outside=%s" % [n, hits, float(hits) / n, hits12, str(outside)])
