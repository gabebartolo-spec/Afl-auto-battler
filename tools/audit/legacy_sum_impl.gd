extends RefCounted
## QA (W7 of #634): checksum of seeded matches with no call and with one older
## focus_id call, to compare main against the PR branch. Measurement only.

func _sim(codes: Array, i: int, seed: int) -> MatchSim:
	var h := str(codes[i % codes.size()])
	var o := str(codes[(i * 5 + 1 + i / codes.size()) % codes.size()])
	if o == h:
		o = str(codes[(i + 1) % codes.size()])
	return MatchSim.new(Squad.new(h, GameDB.club_list(h), true, h), Squad.new(o, GameDB.club_list(o), false, o), seed)


func run() -> void:
	var codes: Array = load("res://tools/balance/league_balance.gd").new().clubs()
	var lines := []
	for arm in ["none", "MID", "FWD", "DEF", "RUCK"]:
		var sum := 0
		for i in range(60):
			var s := _sim(codes, i, 7000 + i)
			if arm != "none":
				for p in (s.squads[0] as Squad).ground:
					if str(p["role"]) == arm:
						s.set_tactics(0, {"focus_id": str(p["id"])})
						break
			var r := s.run()
			var sc: Array = r["score"]
			sum = (sum * 31 + int(sc[0]) * 1000 + int(sc[1]) + (r["events"] as Array).size()) % 1000000007
		lines.append("%s=%d" % [arm, sum])
	print("LEGACY CHECKSUM " + " ".join(lines))
