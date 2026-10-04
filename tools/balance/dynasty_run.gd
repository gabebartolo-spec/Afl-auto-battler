extends SceneTree
## CLI for tools/balance/dynasty.gd: runs seeded careers and writes JSON.
##   godot --headless --path . --script tools/balance/dynasty_run.gd -- \
##       --seeds 301,302 --policy board --seasons 5 --out /tmp/dyn.json [--coach]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var seeds := [301]
	var policy := "board"
	var seasons := 5
	var out_path := "user://dynasty.json"
	var coach := args.has("--coach")
	for i in range(args.size() - 1):
		match str(args[i]):
			"--seeds":
				seeds = Array(str(args[i + 1]).split(",")).map(func(s): return int(s))
			"--policy":
				policy = str(args[i + 1])
			"--seasons":
				seasons = int(args[i + 1])
			"--out":
				out_path = str(args[i + 1])
	root.get_node("GameDB").reload()
	var dyn = load("res://tools/balance/dynasty.gd").new()
	var careers := []
	for s in seeds:
		var t := Time.get_ticks_msec()
		var rec: Array = dyn.run_career(int(s), policy, seasons, 5, coach)
		careers.append({"seed": int(s), "policy": policy, "coach": coach, "seasons": rec})
		var line := []
		for snap in rec:
			var u := str(snap["user"])
			line.append("%d:r%d/l%d%s" % [int(snap["year"]), int(snap["clubs"][u]["rank"]),
					int(snap["user_ladder"]), "P" if str(snap["premier"]) == u else ""])
		print("seed %d (%s) %s  [%ds]" % [int(s), str(rec[0]["user"]) if not rec.is_empty() else "-",
				" ".join(line), (Time.get_ticks_msec() - t) / 1000])
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(careers))
		f.close()
	quit(0)
