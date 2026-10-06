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
	var doc := {
		"source": "data/players_2026.csv (AFL Tables 2026 season totals), players with at least %d games, grouped by the game's primary role (Ratings.derive_all). Each rate is the pooled total divided by pooled games for that role. Regenerate with tools/balance/build_role_rates.gd." % MIN_GAMES,
		"min_games": MIN_GAMES,
		"roles": roles}
	var out := "tools/balance/afl_role_rates.json"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, " "))
	f.close()
	print("ROLE_RATES saved ", out)
	quit(0)
