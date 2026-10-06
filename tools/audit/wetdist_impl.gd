extends RefCounted
## The wet-weather player's reach (medium, for #449): who earns it among the
## real 2026 lists by position, whether the sourced names (docs/research/
## WET_WEATHER_PLAYERS.md) do, the share at nearby thresholds, then one
## eight-season career's real and generated holders by season. Lines WET.
## The career seed is AUDIT_SEED (default 301).
var dyn = load("res://tools/balance/dynasty.gd").new()
const SOURCED := [["GWS", "Lachie", "Whitfield"], ["GEE", "Patrick", "Dangerfield"]]


func run() -> void:
	var db := GameDB
	var all := []
	for code in db.club_order:
		for p in db.club_list(code):
			all.append(p)
	var by := {}
	var n_by := {}
	var held := 0
	for p in all:
		var r := str(p.get("role", "MID"))
		n_by[r] = int(n_by.get(r, 0)) + 1
		if Traits.wet_weather(p):
			held += 1
			by[r] = int(by.get(r, 0)) + 1
	print("WET real 2026: %d of %d (%.1f%%); by role %s of %s" % [held, all.size(), 100.0 * held / all.size(), str(by), str(n_by)])
	for s in SOURCED:
		for p in db.club_list(str(s[0])):
			if str(p.get("first", "")) == s[1] and str(p.get("last", "")) == s[2]:
				var at: Dictionary = p.get("attr", {})
				print("WET sourced %s %s (%s, %s): contested %d, disposal %d -> %s" % [s[1], s[2], s[0],
						str(p.get("role", "")), int(at.get("contested", 0)), int(at.get("disposal", 0)),
						"earns it" if Traits.wet_weather(p) else "does not"])
	# Share at nearby thresholds (contested, disposal).
	var grid := []
	for c in range(70, 86, 2):
		var row := PackedStringArray()
		for d in range(64, 80, 2):
			var k := 0
			for p in all:
				var at: Dictionary = p.get("attr", {})
				if int(at.get("contested", 0)) >= c and int(at.get("disposal", 0)) >= d:
					k += 1
			row.append("%4.1f" % (100.0 * k / all.size()))
		grid.append("WET share%% contested>=%d | disposal>=64..78 step 2: %s" % [c, " ".join(row)])
	for g in grid:
		print(g)
	# One career, eight seasons.
	var gs := GameDB.get_tree().root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	var env := OS.get_environment("AUDIT_SEED")
	var seed_v := int(env) if env != "" else 301
	gs.career_seed = seed_v
	gs.replay_seed = seed_v
	var d: Draft = dyn.make_upside_draft(seed_v, 5)
	var user := d.user_club if d.user_club != "" else str(d.draft_order[0])
	gs.draft = d
	gs.start_season(user, [])
	for y in range(8):
		var rn := 0
		var gn := 0
		var rw := 0
		var gw := 0
		for c in gs.season.lists:
			for p in gs.season.lists[c]:
				var gen := bool(p.get("generated", false))
				var w := Traits.wet_weather(p)
				if gen:
					gn += 1
					gw += int(w)
				else:
					rn += 1
					rw += int(w)
		print("WET %d | real %d of %d | generated %d of %d" % [gs.season_year, rw, rn, gw, gn])
		while not gs.season.is_season_over():
			dyn._play_week(gs, user, true)
		var mgmt: Dictionary = dyn._manage(gs, user, "full")
		gs.set_selection({})
		if not dyn._offseason(gs, user, mgmt):
			break
