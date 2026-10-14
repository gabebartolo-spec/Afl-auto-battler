extends SceneTree
## The finals and Grand Final cards on the hub, one image each, at phone size. Needs a real renderer:
##   godot --path . --script tools/visual/capture_finals_cards.gd -- --out /tmp/finals --club FRE [--only id,id]
## Writes <out>_<card id>[_wk3].png. Each card is built from the facts the game would give it in that
## week (a finals game is fabricated: the ladder, the bracket and the honour roll are set, nothing else).

var CS = null
var SD = null
var SE = null
var CAP = null
var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in range(30):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _finals_game(state, db, club: String, seed: int, rank: int) -> void:
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	state.career_seed = seed
	state.replay_seed = seed
	state.start_season(club, db.club_list(club))
	var sea = state.season
	var codes: Array = sea.ladder.keys()
	codes.sort()
	codes.erase(club)
	codes.insert(rank, club)
	for i in range(codes.size()):
		var row: Dictionary = sea.ladder[codes[i]]
		row["w"] = 20 - i
		row["l"] = 4 + i
		row["d"] = 0
		row["p"] = 24
		row["pf"] = 2400 - i * 20
		row["pa"] = 2000
	sea.round_index = sea.fixture.size()
	sea.recalc_ladder()
	sea.start_finals()


## The card as the hub would build it for these facts.
func _card(state, id: String, p: Dictionary, over: Dictionary, subj_over: Dictionary) -> Dictionary:
	var ctx: Dictionary = CS.context(state)
	var club: Dictionary = (ctx["club"] as Dictionary).duplicate()
	club.merge(over, true)
	var t: Dictionary = SD.by_id(SD.all(), id)
	var subj := {"kind": "club"}
	if str((t["subject"] as Dictionary).get("kind", "")) == "player":
		subj = {}
		for f in ctx["players"]:
			if str(f["id"]) == str(p["id"]):
				subj = (f as Dictionary).duplicate()
		subj.merge(subj_over, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	print("DEBUG3 ", id, " t empty ", t.is_empty(), " subj keys ", subj.size(), " p id ", p.get("id", "-"), " players ", (ctx["players"] as Array).size())
	var built: Dictionary = SE.build(SD.all(), t, subj, club, rng, state.story_week())
	print("DEBUG3 built keys ", built.keys())
	return built


func _run() -> void:
	var out := "/tmp/finals"
	var club := "FRE"
	var only := []
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--club":
			club = str(a[i + 1])
		if str(a[i]) == "--only":
			only = str(a[i + 1]).split(",")
	await process_frame
	CS = load("res://scripts/state/ClubStories.gd")
	SD = load("res://scripts/sim/StoryDeck.gd")
	SE = load("res://scripts/sim/StoryEngine.gd")
	CAP = load("res://scripts/sim/Captaincy.gd")
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_finals.save"
	state.settings_path = "user://capture_finals_settings.cfg"
	state.show_real_names = false
	DisplayServer.window_set_size(Vector2i(W, H))
	root.size = Vector2i(W, H)
	for i in range(3):
		await process_frame
	var shots := [
		# id, a player-picker, facts over the club, facts over the player, name suffix, week to set
		["finals_in", "", {"finals_math": "in", "finals_week": 0}, {}, "", 0],
		["finals_gone", "kid", {"finals_math": "out", "finals_week": 0}, {}, "", 0],
		["finals_last_season", "vet", {}, {"last_season": true}, "", 2],
		["finals_first_final", "kid", {}, {}, "", 2],
		["finals_week_off", "", {"finals_bye": true}, {}, "", 1],
		["finals_week_off", "", {"finals_bye": true, "finals_week": 3}, {}, "_wk3", 3],
		["finals_second_chance", "captain", {"finals_week": 3, "lost_last_final": true}, {"delegate_holds": true}, "", 3],
		["finals_second_chance", "captain", {"finals_week": 3, "lost_last_final": true}, {"delegate_holds": false}, "_wouldnt", 3],
		["finals_fitness_test", "star", {}, {}, "", 2],
		["finals_family_tickets", "", {}, {}, "", 2],
		["finals_club_greats", "", {}, {}, "", 2],
		["finals_captain_last_word", "captain", {}, {"delegate_holds": true}, "", 2],
		["gf_the_opponent", "", {"finals_week": 5, "gf_run": 3, "gf_run_word": "third", "gf_again": "won", "rival": true, "opp": "Collingwood"}, {}, "", 5],
		["gf_the_opponent", "", {"finals_week": 5, "gf_run": 1, "gf_again": "", "rival": false, "opp": "Sydney"}, {}, "_plain", 5],
		["gf_last_game", "captain", {"finals_week": 5}, {"told_players": true}, "", 5],
		["gf_debut_year", "kid", {"finals_week": 5}, {}, "", 5],
		["gf_racing_the_clock", "star", {"finals_week": 5}, {}, "", 5],
		["gf_milestone", "vet", {"finals_week": 5}, {"milestone_next": 200}, "", 5],
		["gf_week", "", {"finals_week": 5}, {}, "", 5],
	]
	for sh in shots:
		var id := str(sh[0])
		if not only.is_empty() and not only.has(id):
			continue
		_finals_game(state, db, club, 21, 0)
		var sea = state.season
		var wk := int(sh[5])
		if wk >= 2:
			sea.finals["week"] = wk
			sea.finals["weeks"] = []
			for k in range(wk - 1):
				(sea.finals["weeks"] as Array).append([])
			if wk == 3:
				sea.finals["slots"] = {"W_QF1": club} if bool((sh[2] as Dictionary).get("finals_bye", false)) else {"L_QF1": club}
			elif wk >= 4:
				sea.finals["slots"] = {}
		var rec: Dictionary = state.captaincy_record(club)
		var by_fit: Array = state.my_list.duplicate()
		by_fit.sort_custom(func(x, y): return int(x["overall"]) > int(y["overall"]))
		var p: Dictionary = {}
		match str(sh[1]):
			"captain":
				for q in state.my_list:
					if CAP.role_of(rec, str(q["id"])) == "captain":
						p = q
			"star":
				p = by_fit[0]
			"vet":
				p = by_fit[3]
				p["career"] = {"games": 199, "goals": 40, "stints": [[club, 2017, 2026, 199, 40]], "through": 2026, "unknown": []}
				if id == "finals_last_season":
					p["career"]["games"] = 250
			"kid":
				var youngest: Dictionary = by_fit[10]
				for q in by_fit:
					if float(q["age"]) < float(youngest["age"]) and int(q["overall"]) > 55:
						youngest = q
				p = youngest
		if id == "gf_racing_the_clock":
			p["injury_weeks"] = 2
			p["injury_kind"] = "hamstring"
		var card := _card(state, id, p, sh[2], sh[3])
		if id == "finals_week_off" and wk == 3:
			card = _card(state, id, p, {"finals_bye": true, "finals_week": 3}, {})
		if id == "gf_racing_the_clock":
			card["facts"]["injury_weeks"] = 2
		state.media_conference = {}
		state.week_events = [card]
		root.get_node("Router").go("hub")
		for i in range(8):
			await process_frame
		var node: Control = root.get_tree().current_scene.find_child("WeekEvent", true, false)
		var sc := node.get_parent() if node != null else null
		var chain := []
		while sc != null and not (sc is ScrollContainer):
			chain.append(sc.name)
			sc = sc.get_parent()
		print("DEBUG ", id, " node ", node != null, " rect ", node.get_global_rect() if node != null else "-", " visible ", node.is_visible_in_tree() if node != null else "-",
				" modulate ", node.modulate if node != null else "-", " children ", node.get_child_count() if node != null else 0, " chain ", chain,
				" sc ", (sc as Control).get_global_rect() if sc != null else "-", " scroll ", (sc as ScrollContainer).scroll_vertical if sc != null else "-")
		var texts := []
		if node != null:
			for l in node.find_children("*", "Label", true, false):
				texts.append(str((l as Label).text).left(40) + "|" + str((l as Label).size))
		print("DEBUG2 card resolved ", card.get("resolved", "-"), " title ", str(card.get("title", "")).left(40), " events ", state.week_events.size(),
				" first ", str((state.week_events[0] as Dictionary).get("title", "")).left(40) if state.week_events.size() > 0 else "-", " labels ", texts)
		if sc != null and node != null:
			(sc as ScrollContainer).ensure_control_visible(node)
			for i in range(6):
				await process_frame
		await _shot("%s_%s%s_%s.png" % [out, id, str(sh[4]), club])
		if p.has("injury_weeks"):
			p["injury_weeks"] = 0
			p.erase("injury_kind")
	quit(0)
