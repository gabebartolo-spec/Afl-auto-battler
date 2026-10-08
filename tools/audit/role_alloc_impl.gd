extends RefCounted
## Role allocation against the clubs' own listings (ROADMAP "Player
## role-allocation / draft-position distribution audit - REOPEN"). Every
## player on every 2027 list: his listed position (real_pos) against the
## first and second positions the season numbers give him, the player types
## each role produces, the named cases the director raised, and each club's
## coverage by line. Reads; changes nothing. No arguments.

const NAMED := ["Gryan Miers", "Bodhi Uwland", "Harvey Langford", "Maurice Rioli",
		"Cody Weightman", "Nick Daicos", "Isaac Heeney", "Jeremy Cameron"]


func run() -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	var all := []
	var by_club := {}
	for club in GameDB.active_clubs(2027):
		var list: Array = GameDB.club_list(str(club))
		by_club[str(club)] = list
		all.append_array(list)
	print("PLAYERS %d on %d lists" % [all.size(), by_club.size()])

	# Listed position x derived first position.
	var cross := {}
	var listed_set := {}
	for p in all:
		var listed := str(p.get("real_pos", ""))
		if listed == "":
			listed = "(none)"
		listed_set[listed] = true
		var k := "%s>%s" % [listed, str(p.get("role", ""))]
		cross[k] = int(cross.get(k, 0)) + 1
	print("\nLISTED x FIRST POSITION (rows listed, columns derived)")
	print("  %-7s %5s %5s %5s %5s" % ["", "FWD", "MID", "DEF", "RUCK"])
	var ls := listed_set.keys()
	ls.sort()
	for l in ls:
		print("  %-7s %5d %5d %5d %5d" % [l, int(cross.get(l + ">FWD", 0)), int(cross.get(l + ">MID", 0)),
				int(cross.get(l + ">DEF", 0)), int(cross.get(l + ">RUCK", 0))])

	# Listed forwards/defenders the numbers make midfielders, with what they
	# keep as a second position and the type they show as.
	for line in ["FWD", "DEF"]:
		var rows := []
		for p in all:
			if str(p.get("real_pos", "")) == line and str(p.get("role", "")) == "MID":
				rows.append(p)
		rows.sort_custom(func(a, b): return int(a.get("overall", 0)) > int(b.get("overall", 0)))
		var kept := 0
		for p in rows:
			if str(p.get("role2", "")) == line:
				kept += 1
		print("\nLISTED %s, FIRST POSITION MID: %d (%d keep %s second)" % [line, rows.size(), kept, line])
		for p in rows:
			print("  %-24s %s  OVR %2d  %3.0fcm  %2d gm  2nd %-4s  %s" % [GameDB.player_display_name(p),
					str(p.get("club", "")), int(p.get("overall", 0)), float(p.get("height_cm", 0.0)),
					int(p.get("gm", 0)), str(p.get("role2", "")) if str(p.get("role2", "")) != "" else "-",
					PlayerProfile.player_type(p)])

	# Listed midfielders the numbers move to a line (the other direction).
	var out_of_mid := {}
	for p in all:
		if str(p.get("real_pos", "")) == "MID" and str(p.get("role", "")) != "MID":
			var r := str(p.get("role", ""))
			out_of_mid[r] = int(out_of_mid.get(r, 0)) + 1
	print("\nLISTED MID, FIRST POSITION ELSEWHERE: %s" % str(out_of_mid))

	# Types each first position produces, with the height spread of each.
	var types := {}
	for p in all:
		var t := "%s: %s" % [str(p.get("role", "")), PlayerProfile.player_type(p)]
		if not types.has(t):
			types[t] = []
		(types[t] as Array).append(float(p.get("height_cm", 0.0)))
	print("\nPLAYER TYPES (count, height min / median / max)")
	var tk := types.keys()
	tk.sort()
	for t in tk:
		var hs: Array = (types[t] as Array).filter(func(h): return h > 0.0)
		hs.sort()
		var mid_h: float = hs[hs.size() / 2] if not hs.is_empty() else 0.0
		print("  %-32s %4d   %3.0f / %3.0f / %3.0f" % [t, (types[t] as Array).size(),
				hs[0] if not hs.is_empty() else 0.0, mid_h, hs[hs.size() - 1] if not hs.is_empty() else 0.0])

	# Wings that are listed forwards or defenders.
	var wing_listed := {}
	for p in all:
		if PlayerProfile.player_type(p) == "Wing":
			var l := str(p.get("real_pos", ""))
			wing_listed[l] = int(wing_listed.get(l, 0)) + 1
	print("\nWINGS BY LISTED POSITION: %s" % str(wing_listed))

	print("\nNAMED CASES")
	for n in NAMED:
		var found := false
		for p in all:
			if GameDB.player_display_name(p) == n or "%s %s" % [str(p.get("first", "")), str(p.get("last", ""))] == n:
				found = true
				print("  %-18s %s listed %-4s first %-4s second %-4s %3.0fcm  type %s  wing %s" % [n,
						str(p.get("club", "")), str(p.get("real_pos", "")), str(p.get("role", "")),
						str(p.get("role2", "")) if str(p.get("role2", "")) != "" else "-",
						float(p.get("height_cm", 0.0)), PlayerProfile.player_type(p), str(Roles.is_wing(p))])
				break
		if not found:
			print("  %-18s not on a 2027 list" % n)

	# Each club's coverage by first position (a side needs six of each line).
	print("\nCLUB COVERAGE BY FIRST POSITION (FWD / MID / DEF / RUCK)")
	var thin := []
	var clubs := by_club.keys()
	clubs.sort()
	for c in clubs:
		var n := {"FWD": 0, "MID": 0, "DEF": 0, "RUCK": 0}
		for p in by_club[c]:
			var r := str(p.get("role", ""))
			n[r] = int(n.get(r, 0)) + 1
		print("  %s  %2d / %2d / %2d / %d" % [c, n["FWD"], n["MID"], n["DEF"], n["RUCK"]])
		if int(n["FWD"]) < 8 or int(n["DEF"]) < 8:
			thin.append(c)
	print("  clubs under 8 forwards or 8 defenders: %s" % str(thin))
	GameState.reset()
