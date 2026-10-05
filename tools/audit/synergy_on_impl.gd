extends RefCounted
## One synergy's effect, forced on (companion to synergy_impl). Neighbours in
## strength, paired seeds, Sim round (moment_side -1). Each match twice from
## the same seed: side 0 with synergy SYN_ON removed from its natural set, and
## with it added. Everything else (its other synergies, the opponent's) is
## untouched, so the difference is that synergy alone, whatever its natural
## activation rate. Env: SYN_ON (key), SYN_DRAFTS, SYN_REPS.
##
## SYN_ON=supply_line godot --headless --path . --script tools/audit/run_audit.gd -- synergy_on_impl

const STATS := ["clearances", "metres_gained", "inside50", "pressure_acts", "tackles", "disposals", "goals"]

var DRAFTS: Array = _env_ints("SYN_DRAFTS", [21, 22, 23, 24])
var SEEDS_PER_PAIR: int = int(OS.get_environment("SYN_REPS")) if OS.get_environment("SYN_REPS") != "" else 8


static func _env_ints(key: String, fallback: Array) -> Array:
	var v := OS.get_environment(key)
	if v == "":
		return fallback
	var out := []
	for part in v.split(","):
		out.append(int(part))
	return out


func _play(lists: Dictionary, a: String, b: String, seed: int, key: String, on: bool) -> Dictionary:
	var sim := MatchSim.new(Squad.new(a, lists[a], true, a), Squad.new(b, lists[b], false, b), seed)
	var syn: Array = (sim.synergies[0] as Array).duplicate()
	syn.erase(key)
	if on:
		syn.append(key)
	sim.synergies[0] = syn
	return sim.run()


func run() -> void:
	var key := OS.get_environment("SYN_ON")
	if not Traits.SYNERGIES.has(key):
		print("SYN_ON must be one of %s" % str(Traits.SYNERGIES.keys()))
		return
	var lb = load("res://tools/balance/league_balance.gd").new()
	var dw := []
	var dm := []
	var dstat := {}
	var dq4 := []
	var base_stat := {}
	for s in STATS:
		dstat[s] = 0.0
		base_stat[s] = 0.0
	for d in DRAFTS:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var codes: Array = lb.clubs()
		var ratings: Dictionary = lb.club_ratings(lists, codes)
		codes.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		for i in range(0, codes.size() - 1, 2):
			for flip in [false, true]:
				var a := str(codes[i + (1 if flip else 0)])
				var b := str(codes[i + (0 if flip else 1)])
				for k in range(SEEDS_PER_PAIR):
					var seed: int = int(d) * 100003 + i * 1009 + k * 7919 + (31 if flip else 0)
					var off := _play(lists, a, b, seed, key, false)
					var on := _play(lists, a, b, seed, key, true)
					var mo := int(off["score"][0]) - int(off["score"][1])
					var mn := int(on["score"][0]) - int(on["score"][1])
					var wo := 1.0 if mo > 0 else (0.5 if mo == 0 else 0.0)
					var wn := 1.0 if mn > 0 else (0.5 if mn == 0 else 0.0)
					dw.append(wn - wo)
					dm.append(float(mn - mo))
					for s in STATS:
						var vo := float((off["team"][0] as Dictionary).get(s, 0.0))
						var vn := float((on["team"][0] as Dictionary).get(s, 0.0))
						dstat[s] += vn - vo
						base_stat[s] += vo
					var q4o: int = 6 * int(off["q_goals"][3][0]) + int(off["q_behinds"][3][0]) - 6 * int(off["q_goals"][3][1]) - int(off["q_behinds"][3][1])
					var q4n: int = 6 * int(on["q_goals"][3][0]) + int(on["q_behinds"][3][0]) - 6 * int(on["q_goals"][3][1]) - int(on["q_behinds"][3][1])
					dq4.append(float(q4n - q4o))
		print("draft %d done" % int(d))
	var n := dw.size()
	print("")
	print("## %s forced on: %d paired matches (side 0 without vs with it, same seed)" % [Traits.label(key), n])
	print("win %% change %+.1f ± %.1f (95%%)" % [100.0 * _mean(dw), 196.0 * _se(dw)])
	print("margin change %+.2f ± %.2f points" % [_mean(dm), 1.96 * _se(dm)])
	print("last-quarter margin change %+.2f ± %.2f points" % [_mean(dq4), 1.96 * _se(dq4)])
	for s in STATS:
		print("  %s: %+.2f a match (%+.1f%% on %.1f)" % [s, dstat[s] / n, 100.0 * dstat[s] / maxf(1.0, base_stat[s]), base_stat[s] / n])


func _mean(xs: Array) -> float:
	var t := 0.0
	for x in xs:
		t += x
	return t / maxf(1.0, xs.size())


func _se(xs: Array) -> float:
	var m := _mean(xs)
	var v := 0.0
	for x in xs:
		v += (x - m) * (x - m)
	return sqrt(v / maxf(1.0, xs.size() - 1)) / sqrt(maxf(1.0, xs.size()))
