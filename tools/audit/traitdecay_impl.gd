extends RefCounted
## League-wide synergy traits season by season in one eight-season career,
## real and generated players apart, and synergies on across the league
## (medium, synergy reachability; one line per season, prefixed DECAY).
## The career seed is AUDIT_SEED (default 301), so paired runs match.
var dyn = load("res://tools/balance/dynasty.gd").new()
func run() -> void:
	var gs := GameDB.get_tree().root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	var env := OS.get_environment("AUDIT_SEED")
	var s := int(env) if env != "" else 301
	gs.career_seed = s
	gs.replay_seed = s
	var d: Draft = dyn.make_upside_draft(s, 5)
	var user := d.user_club if d.user_club != "" else str(d.draft_order[0])
	gs.draft = d
	gs.start_season(user, [])
	for y in range(8):
		var real := {}
		var gen := {}
		var nr := 0
		var ng := 0
		var syn := 0
		for c in gs.season.lists:
			syn += Traits.active(Ratings.select_22(gs.season.lists[c])["ground"]).size()
			for p in gs.season.lists[c]:
				var bucket: Dictionary = gen if bool(p.get("generated", false)) else real
				if bool(p.get("generated", false)):
					ng += 1
				else:
					nr += 1
				for t in Traits.of(p):
					bucket[t] = int(bucket.get(t, 0)) + 1
		print("DECAY %d | synergies on across the league %d | real %d: %s | generated %d: %s" % [gs.season_year, syn, nr, str(real), ng, str(gen)])
		while not gs.season.is_season_over():
			dyn._play_week(gs, user, true)
		var mgmt: Dictionary = dyn._manage(gs, user, "full")
		gs.set_selection({})
		if not dyn._offseason(gs, user, mgmt):
			break
