extends RefCounted
## Forward archetypes (ARD-M3-002): how key, general and small forwards
## score. Drafted leagues, neighbours in strength, paired seeds (Sim round).
## Per archetype, per forward-game on the ground: goals, behinds, accuracy,
## set-shot / open-play / crumb share, marks and contested marks. Then team
## goals by forward-line make-up (how many key forwards on the ground).
## Archetype by height, as GameState.learn_job_for: key forward 192 cm+,
## small forward 181 cm and under, general otherwise.
## Env: FA_DRAFTS (comma list), FA_REPS (seeds per pair).
##
## godot --headless --path . --script tools/audit/run_audit.gd -- fwd_archetype_impl

const KEY_CM := 192.0
const SMALL_CM := 181.0

var DRAFTS: Array = _env_ints("FA_DRAFTS", [21, 22, 23, 24])
var REPS: int = int(OS.get_environment("FA_REPS")) if OS.get_environment("FA_REPS") != "" else 4

var tally := {}      # archetype -> {games, goals, behinds, set_g, set_b, open_g, open_b, crumb_g, crumb_b, marks, cmarks}
var lines := {}
var i50_total := 0      # key forwards on ground -> [team-games, goals, behinds]


static func _env_ints(key: String, fallback: Array) -> Array:
	var v := OS.get_environment(key)
	if v == "":
		return fallback
	var out := []
	for part in v.split(","):
		out.append(int(part))
	return out


static func archetype(p: Dictionary) -> String:
	var h := float(p.get("height_cm", 0.0))
	if h >= KEY_CM:
		return "key"
	if h > 0.0 and h <= SMALL_CM:
		return "small"
	return "general"


func _row(a: String) -> Dictionary:
	if not tally.has(a):
		tally[a] = {"games": 0, "goals": 0, "behinds": 0, "set_g": 0, "set_b": 0, "open_g": 0, "open_b": 0,
				"crumb_g": 0, "crumb_b": 0, "marks": 0, "cmarks": 0, "i50": 0}
	return tally[a]


func _match(lists: Dictionary, a: String, b: String, seed: int) -> void:
	var sim := MatchSim.new(Squad.new(a, lists[a], true, a), Squad.new(b, lists[b], false, b), seed)
	var res := sim.run()
	var fwd_of := {}
	for side in [0, 1]:
		var keys := 0
		for p in (sim.squads[side] as Squad).ground:
			if str(p.get("role", "")) != "FWD":
				continue
			var arch := archetype(p)
			fwd_of[str(p["id"])] = arch
			if arch == "key":
				keys += 1
			var r := _row(arch)
			r["games"] += 1
			var st: Dictionary = (res.get("players", {}) as Dictionary).get(str(p["id"]), {})
			r["marks"] += int(float(st.get("marks", 0)))
			r["cmarks"] += int(float(st.get("contested_marks", 0)))
		var l: Array = lines.get(keys, [0, 0, 0])
		l[0] += 1
		l[1] += int(res["goals"][side])
		l[2] += int(res["behinds"][side])
		lines[keys] = l
	var f50 := float(Ratings.T["forward50_line"])
	for ev in sim.events:
		var kind := str(ev.get("kind", ""))
		if kind == "mark" and fwd_of.has(str(ev.get("player_id", ""))):
			var afp := float(ev.get("fp", 0.0)) * (1.0 if int(ev.get("side", 0)) == 0 else -1.0)
			if afp > f50:
				_row(str(fwd_of[str(ev["player_id"])]))["i50"] += 1
				i50_total += 1
			continue
		if kind != "goal" and kind != "behind":
			continue
		var id := str(ev.get("player_id", ""))
		if not fwd_of.has(id):
			continue
		var r := _row(str(fwd_of[id]))
		var g := kind == "goal"
		r["goals" if g else "behinds"] += 1
		var how := "crumb" if bool(ev.get("crumb", false)) else ("set" if bool(ev.get("set_shot", ev.get("set", false))) else "open")
		r["%s_%s" % [how, "g" if g else "b"]] += 1


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var n := 0
	for d in DRAFTS:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var codes: Array = lb.clubs()
		var ratings: Dictionary = lb.club_ratings(lists, codes)
		codes.sort_custom(func(x, y): return float(ratings[x]["strength"]) > float(ratings[y]["strength"]))
		for i in range(0, codes.size() - 1, 2):
			for flip in [false, true]:
				var a := str(codes[i + (1 if flip else 0)])
				var b := str(codes[i + (0 if flip else 1)])
				for k in range(REPS):
					_match(lists, a, b, int(d) * 100003 + i * 1009 + k * 7919 + (31 if flip else 0))
					n += 1
		print("draft %d done" % int(d))
	print("")
	print("## Forward archetypes over %d matches (per forward-game on the ground)" % n)
	print("forward marks inside 50: %.2f a team-game" % (float(i50_total) / maxf(1.0, 2.0 * n)))
	print("archetype  games  goals  behinds  acc%   set%  open%  crumb%  marks  cmarks  i50")
	for a in ["key", "general", "small"]:
		var r: Dictionary = _row(a)
		var gm := maxf(1.0, float(r["games"]))
		var shots := maxf(1.0, float(r["goals"] + r["behinds"]))
		var gl := maxf(1.0, float(r["goals"]))
		print("%-9s %6d  %5.2f  %7.2f  %4.0f  %5.0f  %5.0f  %6.0f  %5.2f  %6.2f  %4.2f" % [a, int(r["games"]),
				r["goals"] / gm, r["behinds"] / gm, 100.0 * r["goals"] / shots,
				100.0 * r["set_g"] / gl, 100.0 * r["open_g"] / gl, 100.0 * r["crumb_g"] / gl,
				r["marks"] / gm, r["cmarks"] / gm, r["i50"] / gm])
	print("")
	print("## Team scoring by key forwards on the ground")
	var ks := lines.keys()
	ks.sort()
	for k in ks:
		var l: Array = lines[k]
		print("%d key forwards: %4d team-games, %.2f goals, %.2f behinds a game" % [int(k), int(l[0]),
				float(l[1]) / maxf(1.0, l[0]), float(l[2]) / maxf(1.0, l[0])])
