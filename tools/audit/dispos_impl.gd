extends RefCounted
## Disposals by kind of player (director, 2026-10-10: "abnormally high disposal
## count for a KPD like Lever"). Drafted leagues, strength neighbours paired,
## autosim with the AI plans; reads each player's disposals from the result.
## Kinds are by listed position and height: key defender and key forward from
## 192 cm (MatchSim.FWD_KEY_CM), the rest of each line, ruck, midfield.
## Real AFL, for reference (Champion Data, recent seasons): a key defender
## averages about 11-13 a game and 25 is a career-high night; a key forward
## about 9-11; a midfielder 20-30; a ruck 10-14.
##
## godot --headless --path . --script tools/audit/run_audit.gd -- dispos_impl

const DRAFTS := [61, 62, 63, 64]
const SEEDS_PER_PAIR := 6
const KEY_CM := 192.0

var rows := {}        # kind -> Array of per-game disposals
var team := []        # team disposals per side per match


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var t0 := Time.get_ticks_msec()
	for d in DRAFTS:
		var lists: Dictionary = lb.drafted_lists(d)["lists"]
		var codes: Array = lb.clubs()
		var kind_of := {}
		for c in codes:
			for p in lists[c]:
				kind_of[str(p["id"])] = _kind(p)
		var ratings: Dictionary = lb.club_ratings(lists, codes)
		codes.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		for i in range(0, codes.size() - 1, 2):
			var h := str(codes[i])
			var w := str(codes[i + 1])
			for k in range(SEEDS_PER_PAIR):
				var seed: int = int(d) * 100003 + i * 1009 + k * 7919 + 31
				var sa := Squad.new(h, lists[h], true, h)
				var sb := Squad.new(w, lists[w], false, w)
				sa.ai_plans = true
				sb.ai_plans = true
				var res := MatchSim.new(sa, sb, seed).run()
				var stats: Dictionary = res.get("players", {})
				for id in stats:
					var st: Dictionary = stats[id]
					if not kind_of.has(str(id)) or not st.has("disposals"):
						continue
					var kind: String = kind_of[str(id)]
					if not rows.has(kind):
						rows[kind] = []
					(rows[kind] as Array).append(float(st["disposals"]))
				for t in res.get("team", []):
					team.append(float((t as Dictionary).get("disposals", 0.0)))
		print("draft %d done (%d s)" % [d, (Time.get_ticks_msec() - t0) / 1000])
	_report()


func _kind(p: Dictionary) -> String:
	var role := str(p.get("own_role", p.get("role", "")))
	var tall := float(p.get("height_cm", 0.0)) >= KEY_CM
	match role:
		"DEF":
			return "key defender" if tall else "other defender"
		"FWD":
			return "key forward" if tall else "other forward"
		"RUCK":
			return "ruck"
	return "midfielder"


func _report() -> void:
	var t := 0.0
	for x in team:
		t += x
	print("")
	print("team disposals per match: %.0f (real AFL about 350-380)" % (t / maxf(1.0, team.size())))
	print("")
	print("| kind | player-games | mean | p90 | max | 25+ | 30+ |")
	print("|---|---|---|---|---|---|---|")
	for kind in ["key defender", "other defender", "midfielder", "ruck", "other forward", "key forward"]:
		var v: Array = rows.get(kind, [])
		if v.is_empty():
			continue
		v.sort()
		var sum := 0.0
		var n25 := 0
		var n30 := 0
		for x in v:
			sum += x
			n25 += 1 if x >= 25.0 else 0
			n30 += 1 if x >= 30.0 else 0
		print("| %s | %d | %.1f | %.0f | %.0f | %.1f%% | %.2f%% |" % [kind, v.size(), sum / v.size(),
				v[int(v.size() * 0.9)], v[-1], 100.0 * n25 / v.size(), 100.0 * n30 / v.size()])
