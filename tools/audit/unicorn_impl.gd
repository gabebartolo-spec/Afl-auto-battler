extends RefCounted
## Can anyone become a Unicorn? At the career start: who already is one, and
## who could get there - POT 90+ (the gate for a third position, GameState
## PROJECT_POT) with forward, midfield and back within reach. Counts the
## opening pool (every 2027 list) and the 2026 National Draft class. Reads;
## changes nothing. No arguments.

func run() -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	var pool := []
	for club in GameDB.active_clubs(2027):
		pool.append_array(GameDB.club_list(str(club)))
	var third_pot := int(GameState.PROJECT_POT[2])
	var second_pot := int(GameState.PROJECT_POT[1])
	var unicorns := 0
	var pot_hist := {}
	var two_lines_ready := []
	var one_line_ready := []
	for p in pool:
		if Traits.is_unicorn(p):
			unicorns += 1
		var pot := int(p.get("potential", 0))
		var band := "90+" if pot >= 90 else ("85-89" if pot >= 85 else ("80-84" if pot >= 80 else ("70-79" if pot >= 70 else "<70")))
		pot_hist[band] = int(pot_hist.get(band, 0)) + 1
		if pot < third_pot:
			continue
		var lines := 0
		for l in Traits.UNICORN_LINES:
			if Traits.plays(p, l):
				lines += 1
		# How far each missing line sits below his own rating: a project
		# needs it within PROJECT_REACH.
		var gaps: PackedStringArray = []
		for l in Traits.UNICORN_LINES:
			if not Traits.plays(p, l):
				var g := int(p.get("overall", 0)) - int(GameState.rating_as(p, l))
				gaps.append("%s -%d%s" % [l, g, " ok" if g <= GameState.PROJECT_REACH else " too far"])
		var s := "%s %s %d/%d %s%s   %s" % [GameDB.player_display_name(p), str(p.get("club", "")),
				int(p.get("overall", 0)), pot, str(p.get("role", "")),
				("/" + str(p.get("role2", ""))) if str(p.get("role2", "")) != "" else "", ", ".join(gaps)]
		if lines >= 2:
			two_lines_ready.append(s)
		else:
			one_line_ready.append(s)
	print("OPENING POOL %d players; Unicorns now: %d" % [pool.size(), unicorns])
	print("POT bands: %s" % str(pot_hist))
	print("POT %d+ with two of forward/midfield/back already (one project from a Unicorn): %d" % [third_pot, two_lines_ready.size()])
	for s in two_lines_ready:
		print("  " + s)
	print("POT %d+ with one line (two projects, POT %d then %d): %d" % [third_pot, second_pot, third_pot, one_line_ready.size()])
	for s in one_line_ready.slice(0, 20):
		print("  " + s)
	# The 2026 National Draft class.
	var cls: Array = GameDB.all_draftees_sorted()
	var hi := 0
	for p in cls:
		if int(p.get("potential", 0)) >= third_pot:
			hi += 1
	print("2026 draft class: %d prospects, %d at POT %d+" % [cls.size(), hi, third_pot])
	GameState.reset()
