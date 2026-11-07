extends SceneTree
## Real 2026 per-player-game averages by game role, from data/players_2026.csv.
## Regenerate afl_role_rates.json with:
##   godot --headless --path . --script tools/balance/build_role_rates.gd -- tools/balance/afl_role_rates.json
## Roles are the game's own (Ratings.derive_all: primary role). Only players
## with at least MIN_GAMES games; a rate is a pooled total over pooled games.

const MIN_GAMES := 5
const STATS := {"disposals": "di", "kicks": "ki", "handballs": "hb", "marks": "mk",
		"tackles": "tk", "goals": "gl", "hitouts": "ho", "inside_50s": "if50",
		"clearances": "cl", "rebound_50s": "rb", "frees_for": "ff", "frees_against": "fa"}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var db = root.get_node("GameDB")
	db.reload()
	var acc := {}
	for p in db.players:
		var g := int(p.get("gm", 0))
		if g < MIN_GAMES:
			continue
		var role := str(p.get("role", ""))
		if not acc.has(role):
			acc[role] = {"players": 0, "games": 0, "sum": {}}
		var a: Dictionary = acc[role]
		a["players"] += 1
		a["games"] += g
		for k in STATS:
			a["sum"][k] = float(a["sum"].get(k, 0.0)) + float(p.get(STATS[k], 0))
	var roles := {}
	for role in ["DEF", "MID", "FWD", "RUCK"]:
		var a: Dictionary = acc.get(role, {"players": 0, "games": 0, "sum": {}})
		var rates := {}
		for k in STATS:
			rates[k] = snappedf(float(a["sum"].get(k, 0.0)) / maxf(1.0, float(a["games"])), 0.01)
		roles[role] = {"players": a["players"], "player_games": a["games"], "per_game": rates}
	# The same by each man's type as the game names it (Roles.label: "Key defender",
	# "Defender", "Small defender", "Wing", "Key forward", ...), with the spread of
	# the type's disposals a player-game across the 18 clubs (each club's pooled
	# rate) so the report can mark the sim IN / NEAR / OUT as it does team stats.
	# Roles is loaded by path: naming the class here would compile its
	# autoload chain before the autoloads exist (preflight).
	var roles_lib = load("res://scripts/sim/Roles.gd")
	var tacc := {}
	for p in db.players:
		var g := int(p.get("gm", 0))
		if g < MIN_GAMES:
			continue
		var ty := str(roles_lib.label(p))
		if not tacc.has(ty):
			tacc[ty] = {"players": 0, "games": 0, "sum": {}, "club": {}}
		var a: Dictionary = tacc[ty]
		a["players"] += 1
		a["games"] += g
		for k in STATS:
			a["sum"][k] = float(a["sum"].get(k, 0.0)) + float(p.get(STATS[k], 0))
		var c := str(p.get("club", ""))
		var cr: Array = a["club"].get(c, [0.0, 0])
		a["club"][c] = [float(cr[0]) + float(p.get("di", 0)), int(cr[1]) + g]
	var types := {}
	for ty in tacc:
		var a: Dictionary = tacc[ty]
		var rates := {}
		for k in STATS:
			rates[k] = snappedf(float(a["sum"].get(k, 0.0)) / maxf(1.0, float(a["games"])), 0.01)
		var per_club := []
		for c in a["club"]:
			per_club.append(float(a["club"][c][0]) / maxf(1.0, float(a["club"][c][1])))
		var m := 0.0
		for v in per_club:
			m += v
		m /= maxf(1.0, per_club.size())
		var sd := 0.0
		for v in per_club:
			sd += (v - m) * (v - m)
		sd = sqrt(sd / maxf(1.0, per_club.size() - 1))
		types[ty] = {"players": a["players"], "player_games": a["games"], "per_game": rates,
				"disposals_clubs": {"n": per_club.size(), "min": snappedf(per_club.min(), 0.01),
				"max": snappedf(per_club.max(), 0.01), "sd": snappedf(sd, 0.01)}}
	var doc := {
		"source": "data/players_2026.csv (AFL Tables 2026 season totals), players with at least %d games, grouped by the game's primary role (Ratings.derive_all). Each rate is the pooled total divided by pooled games for that role. Regenerate with tools/balance/build_role_rates.gd." % MIN_GAMES,
		"min_games": MIN_GAMES,
		"roles": roles,
		"types": types}
	var out := "tools/balance/afl_role_rates.json"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, " "))
	f.close()
	print("ROLE_RATES saved ", out)
	quit(0)
