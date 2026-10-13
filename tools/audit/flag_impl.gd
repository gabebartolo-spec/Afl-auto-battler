extends RefCounted
## Who wins the flag, by final ladder position (measurement only).
## godot --headless --path . --script tools/audit/run_audit.gd -- flag_impl <arm> <seed0> <n>
## arm "real": the real 2026 lists every season; arm "draft": a fresh drafted league per season.
## One F| line per season: arm|seed|premier position|runner-up position|ladder codes top 10 in order.

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var arm := str(args[1])
	var seed0 := int(args[2])
	var n := int(args[3])
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var real: Dictionary = lb.real_lists()
	for i in range(n):
		var s := seed0 * 1000 + i
		var lists: Dictionary = real if arm == "real" else lb.drafted_lists(s)["lists"]
		var season := Season.new(codes, lists, s)
		while not season.is_regular_done():
			season.play_round()
		season.start_finals()
		var top: Array = (season.finals["top"] as Array).duplicate()
		while not season.is_season_over():
			season.play_finals_week()
		var rank: Array = []
		for r in season.ladder_sorted():
			rank.append(str(r["code"]))
		print("F|%s|%d|%d|%d|%s|%s" % [arm, s, rank.find(str(season.finals["premier"])) + 1,
				rank.find(str(season.finals["runner_up"])) + 1, ",".join(PackedStringArray(top)),
				str(season.finals["premier"])])
