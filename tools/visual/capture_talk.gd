extends SceneTree
## The week's sit-down card on the hub (RPG-003 slice 1), on a phone, for the
## director's look: it opens on what happened to him. Seeded; never touches a
## real save.
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_talk.gd -- \
##       --out PREFIX [--case dropped|waiting] [--club COL] [--seed 2031] [--scale 3]
## Writes <prefix>_card.png (the card) and <prefix>_answered.png (after
## "Explain it, in his numbers"), at 390 x 844 points times --scale.

func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	var out := "talk"
	var case := "dropped"
	var club := "COL"
	var seed := 2031
	var scale := 3.0
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		match str(cli[i]):
			"--out": out = str(cli[i + 1])
			"--case": case = str(cli[i + 1])
			"--club": club = str(cli[i + 1])
			"--seed": seed = int(cli[i + 1])
			"--scale": scale = float(cli[i + 1])
	await process_frame
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	gs.autosave_enabled = false
	gs.save_path = "user://capture_talk.save"
	gs.settings_path = "user://capture_talk.cfg"
	gs.show_real_names = false
	# Every seed set (tools/audit/README.md), so a rerun is the same picture.
	seed(seed)
	gs.reset()
	gs.career_seed = seed
	gs.replay_seed = seed
	gs.set_setting("seen_training_intro", true)
	gs.set_setting("seen_season_stats_intro", true)
	gs.set_setting("seen_weekly_loop_intro", true)
	gs.start_season(club, db.club_list(club))
	var rounds := 3 if case == "dropped" else 6
	for i in range(rounds):
		gs.advance()
	# The player the card is about, and this week's side without him.
	var who := {}
	for p in gs.my_list:
		if int(p.get("injury_weeks", 0)) > 0:
			continue
		var id := str(p["id"])
		if case == "dropped" and gs.last_side.has(id) and gs.games_played(p) >= 100:
			who = p
			break
		if case == "waiting" and float(p.get("age", 30.0)) <= 21.0 and gs.weeks_without_game(p) >= 5:
			who = p
			break
	if who.is_empty():
		push_error("capture_talk: nobody fits the %s case in this career" % case)
		quit(1)
		return
	# A pending press question opens over the hub; clear it so the card shows.
	gs.media_conference = {}
	var wid := str(who["id"])
	var side: Dictionary = gs.current_side()
	for k in side:
		(side[k] as Array).erase(wid)
	side["OUT"] = [wid]
	gs.set_selection(side)
	var e: Dictionary = load("res://scripts/sim/ClubLife.gd")._unhappy(who, case, gs.talk_info({})[wid])
	e["round"] = gs.season.round_index + 1
	gs.week_event = e
	var px := Vector2i(roundi(390 * scale), roundi(844 * scale))
	DisplayServer.window_set_size(px)
	root.size = px
	await process_frame
	root.content_scale_size = Vector2i(390, 844)
	var scene: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(scene)
	root.content_scale_size = Vector2i(390, 844)
	await _frames(8)
	await _show_card(scene)
	root.get_viewport().get_texture().get_image().save_png(out + "_card.png")
	var b = scene.find_child("Event_0", true, false)
	if b != null:
		b.emit_signal("pressed")
	await _frames(8)
	await _show_card(scene)
	root.get_viewport().get_texture().get_image().save_png(out + "_answered.png")
	quit()


func _show_card(scene: Control) -> void:
	var card = scene.find_child("WeekEvent", true, false)
	if card == null:
		return
	var n: Node = card.get_parent()
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	if n != null:
		(n as ScrollContainer).ensure_control_visible(card)
	await _frames(6)
