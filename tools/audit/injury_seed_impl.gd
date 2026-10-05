extends RefCounted
## Is the injury plan's rate independent of how the match seed is made?
## Builds (does not play) many matches per seed scheme; the plan is drawn at
## construction. Companion to injury_parity_impl.
##
## godot --headless --path . --script tools/audit/run_audit.gd -- injury_seed_impl

const SCHEMES := ["fixture", "watched", "x31+99", "x7+3"]


func _seed(scheme: String, base: int) -> int:
	match scheme:
		"watched": return base + 99 * 7919 - 7 * 7919   # next_seed(99) vs next_seed(7)
		"x31+99": return base * 31 + 99
		"x7+3": return base * 7 + 3
	return base


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var lists: Dictionary = lb.drafted_lists(31)["lists"]
	var codes: Array = lb.clubs()
	var n := {}
	var planned := {}
	for s in SCHEMES:
		n[s] = 0
		planned[s] = 0
	for k in range(3000):
		var h := str(codes[(2 * k) % codes.size()])
		var w := str(codes[(2 * k + 1) % codes.size()])
		var base := 31 * 1000003 + (k % 24) * 9176 + 7 * 7919 + 13 + (k / 24) * 104729
		for s in SCHEMES:
			var sim := MatchSim.new(Squad.new(h, lists[h], true, h), Squad.new(w, lists[w], false, w), _seed(s, base))
			n[s] += 2
			planned[s] += sim._injury_plan.size()
	for s in SCHEMES:
		print("%-8s %d team-games, %.4f planned per team-game" % [s, n[s], float(planned[s]) / n[s]])
