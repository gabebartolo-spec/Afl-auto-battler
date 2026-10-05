extends RefCounted
## Synergy activation and effect (for the §9.1 "Synergies should be build
## specialisations" rework). Evidence only.
##
## 1. Activation: every club's best side (Squad -> Ratings.select_side, the
##    on-ground 18 MatchSim reads), drafted leagues, at the start and after one
##    simulated career season (GameState, so development and training happen;
##    injuries healed before selecting). Per synergy: share of clubs on; how
##    many are on per club; the top-4 lists by strength; clubs one trait short.
## 2. Traits: carriers per club in the on-ground 18 (mean, max), by line.
## 3. Effect: neighbours in strength, paired seeds, moment_side -1 (Sim
##    round). Each match twice: as is, and with side 0's synergies zeroed after
##    construction. Same seed, so the difference is the synergies alone.
##
## godot --headless --path . --script tools/audit/run_audit.gd -- synergy_impl

## Sample size from the environment, so the same impl runs locally (small)
## and on Actions (large): SYN_DRAFTS="21,22,23,24", SYN_REPS=8 (seeds per
## pairing and orientation; 8 x 2 x 9 pairings x 4 leagues = 576 pairs).
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
const LINES := ["RUCK", "MID", "DEF", "FWD"]

var lb


func _activation(label: String, entries: Array) -> void:
	# entries: [[draft seed, lists]]; top 4 by strength within each league.
	var codes := []
	var sides := {}
	var top4 := {}
	for e in entries:
		var lists: Dictionary = e[1]
		var cs: Array = lb.clubs()
		var ratings: Dictionary = lb.club_ratings(lists, cs)
		cs.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		for i in range(cs.size()):
			var key := "%d|%s" % [int(e[0]), cs[i]]
			codes.append(key)
			sides[key] = Squad.new(str(cs[i]), lists[cs[i]], true, str(cs[i])).ground
			if i < 4:
				top4[key] = true
	var on := {}
	var on_top := {}
	var short := {}
	for k in Traits.SYNERGIES:
		on[k] = 0
		on_top[k] = 0
		short[k] = 0
	var hist := [0, 0, 0, 0]
	var hist_top := [0, 0, 0, 0]
	var carriers := {}   # trait -> line -> [sum, max]
	for c in codes:
		var ground: Array = sides[c]
		var act := Traits.active(ground)
		for k in act:
			on[k] += 1
			if top4.has(c):
				on_top[k] += 1
		hist[mini(3, act.size())] += 1
		if top4.has(c):
			hist_top[mini(3, act.size())] += 1
		for row in Traits.progress(ground):
			if int(row["missing"]) == 1:
				short[row["key"]] += 1
		var counts := Traits._counts(ground)
		for line in ["" ] + LINES:
			for t in Traits.DEFS:
				var n := int((counts[line] as Dictionary).get(t, 0))
				if not carriers.has(t):
					carriers[t] = {}
				if not (carriers[t] as Dictionary).has(line):
					carriers[t][line] = [0, 0]
				carriers[t][line][0] += n
				carriers[t][line][1] = maxi(int(carriers[t][line][1]), n)
	_thresholds(label, codes, sides, top4)
	var n := float(codes.size())
	print("")
	print("### Activation, %s (%d club-lists, top 4 = %d)" % [label, codes.size(), DRAFTS.size() * 4])
	print("| synergy | needs | clubs on | top-4 lists on | one trait short |")
	print("|---|---|---|---|---|")
	for k in Traits.SYNERGIES:
		print("| %s | %s | %.0f%% | %.0f%% | %.0f%% |" % [Traits.label(k), _needs(k),
				100.0 * on[k] / n, 100.0 * on_top[k] / (DRAFTS.size() * 4.0), 100.0 * short[k] / n])
	print("")
	print("Synergies on per club, 0 / 1 / 2 / 3+: all %s; top-4 lists %s" % [_pct(hist), _pct(hist_top)])
	print("")
	print("### Trait carriers in the on-ground 18, %s: mean per club (max)" % label)
	print("| trait | whole 18 | ruck | midfield | defence | forward |")
	print("|---|---|---|---|---|---|")
	for t in Traits.DEFS:
		var line := "| %s |" % Traits.label(t)
		for l in [""] + LINES:
			var c: Array = carriers[t].get(l, [0, 0])
			line += " %.2f (%d) |" % [float(c[0]) / n, int(c[1])]
		print(line)


## Share of clubs with at least k carriers of each trait in the line its
## synergy counts (k = 1..6), all clubs and the top-4 lists.
const THRESHOLD_LINES := {"bull": "", "aerial": "FWD", "crumber": "FWD", "interceptor": "DEF",
		"lockdown": "", "ball_magnet": "", "playmaker": "", "engine": ""}


func _thresholds(label: String, codes: Array, sides: Dictionary, top4: Dictionary) -> void:
	print("")
	print("### Carriers at or above k in the counted line, %s (all clubs | top-4 lists)" % label)
	for t in THRESHOLD_LINES:
		var line := str(THRESHOLD_LINES[t])
		var all_k := [0, 0, 0, 0, 0, 0]
		var top_k := [0, 0, 0, 0, 0, 0]
		for c in codes:
			var n := int((Traits._counts(sides[c])[line] as Dictionary).get(t, 0))
			for k in range(6):
				if n >= k + 1:
					all_k[k] += 1
					if top4.has(c):
						top_k[k] += 1
		var a := []
		var b := []
		for k in range(6):
			a.append(">=%d %.0f%%" % [k + 1, 100.0 * all_k[k] / codes.size()])
			b.append(">=%d %.0f%%" % [k + 1, 100.0 * top_k[k] / maxf(1, top4.size())])
		print("%s (%s): %s | top-4: %s" % [t, "whole 18" if line == "" else str(Traits.LINE_NAMES[line]), ", ".join(a), ", ".join(b)])


func _needs(k: String) -> String:
	var s: Dictionary = Traits.SYNERGIES[k]
	var parts := []
	for t in s["needs"]:
		parts.append("%d %s" % [int(s["needs"][t]), Traits.label(t)])
	var where := "the 18" if str(s["line"]) == "" else str(Traits.LINE_NAMES.get(str(s["line"]), s["line"]))
	return "%s (%s)" % [" + ".join(parts), where]


func _pct(h: Array) -> String:
	var tot := 0
	for x in h:
		tot += x
	var out := []
	for x in h:
		out.append("%.0f%%" % (100.0 * x / maxf(1, tot)))
	return " / ".join(out)


func _effect(all_lists: Array) -> void:
	# synergy key (or "any") -> [n, win delta sum, margin delta sum]
	var eff := {"any": [0, 0.0, 0.0], "none": [0, 0.0, 0.0]}
	for k in Traits.SYNERGIES:
		eff[k] = [0, 0.0, 0.0]
	var pairs := 0
	for entry in all_lists:
		var d: int = entry[0]
		var lists: Dictionary = entry[1]
		var codes: Array = lb.clubs()
		var ratings: Dictionary = lb.club_ratings(lists, codes)
		codes.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		for i in range(0, codes.size() - 1, 2):
			for flip in [false, true]:
				var a := str(codes[i + (1 if flip else 0)])
				var b := str(codes[i + (0 if flip else 1)])
				for k in range(SEEDS_PER_PAIR):
					var seed: int = d * 100003 + i * 1009 + k * 7919 + (31 if flip else 0)
					var res := []
					var act := []
					for off in [false, true]:
						var sim := MatchSim.new(Squad.new(a, lists[a], true, a), Squad.new(b, lists[b], false, b), seed)
						if off:
							sim.synergies[0] = []
						else:
							act = (sim.synergies[0] as Array).duplicate()
						var r := sim.run()
						var m := int(r["score"][0]) - int(r["score"][1])
						res.append([1.0 if m > 0 else (0.5 if m == 0 else 0.0), float(m)])
					pairs += 1
					var dw: float = res[0][0] - res[1][0]
					var dm: float = res[0][1] - res[1][1]
					var keys := act.duplicate()
					keys.append("any" if not act.is_empty() else "none")
					for key in keys:
						eff[key][0] += 1
						eff[key][1] += dw
						eff[key][2] += dm
		print("effect: draft %d done" % d)
	print("")
	print("### Effect: side 0 as is vs its synergies zeroed (same seed), %d paired matches" % pairs)
	print("| side 0 had | matches | win %% change | margin change (points) |")
	print("|---|---|---|---|")
	for key in ["any"] + Traits.SYNERGIES.keys() + ["none"]:
		var e: Array = eff[key]
		if int(e[0]) == 0:
			print("| %s | 0 | - | - |" % key)
			continue
		var name := "any synergy on" if key == "any" else ("no synergy on (control)" if key == "none" else Traits.label(key))
		print("| %s | %d | %+.1f | %+.2f |" % [name, e[0], 100.0 * e[1] / e[0], e[2] / e[0]])
	print("(Rows for single synergies include matches where others were also on.)")


func run() -> void:
	lb = load("res://tools/balance/league_balance.gd").new()
	var start := []
	for d in DRAFTS:
		start.append([d, lb.drafted_lists(d)["lists"]])
	_activation("season start", start)
	# After one career season (development, training, AI list building).
	var after := []
	var gs := GameDB.get_tree().root.get_node("GameState")
	for d in DRAFTS:
		lb.play_career_season(d, d * 7 + 1, "board", 5, {})
		Injuries.heal_all(gs.season.lists)
		after.append([d, gs.season.lists.duplicate(true)])
		print("career season %d done" % d)
	_activation("after one season", after)
	if OS.get_environment("SYN_EFFECT") != "0":
		_effect(start)
