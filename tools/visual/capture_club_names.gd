extends SceneTree
## Player names in running text wear their club's colour (NameInk). Needs a
## real renderer (godot_quiet.sh --render ...):
##   --script tools/visual/capture_club_names.gd -- --size 390x844 --club FRE --vs GWS --out <prefix>
## Plays one live match (every coach's call taken as the first option) and
## writes <out>_feed.png (the log mid-match), <out>_half.png (the half-time
## break), <out>_full.png and <out>_full2.png (full time, top and further down).
## Never touches a real save.

var _w := 390
var _h := 844


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(out: String, shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img == null:
		print("no renderer: ", shot)
		return
	img.convert(Image.FORMAT_RGBA8)
	img.save_png("%s_%s.png" % [out, shot])
	print("wrote ", out, "_", shot, ".png")


func _run() -> void:
	var out := "club_names"
	var club := "FRE"
	var vs := "GWS"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
			"--club":
				club = str(a[i + 1])
			"--vs":
				vs = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_club_names.save"
	state.settings_path = "user://capture_club_names.cfg"
	UK.apply_appearance("dark")
	if _w >= 760:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(_w, _h))
		await _frames(10)
		var factor := float(_w) / maxf(1.0, root.get_visible_rect().size.x)
		if factor > 1.05:
			DisplayServer.window_set_size(Vector2i(int(_w * factor), int(_h * factor)))
			await _frames(10)
	else:
		root.size = Vector2i(_w, _h)
		DisplayServer.window_set_size(Vector2i(_w, _h))
	var tries := 0
	while true:
		state.reset()
		state.career_seed = 2026 + tries
		state.replay_seed = 2026 + tries
		state.set_setting("seen_training_intro", true)
		state.start_season(club, db.club_list(club))
		if not state.prepare_interactive_match():
			push_error("no match to prepare")
			quit(1)
			return
		var s0 = state.pending_sim
		var them := str(s0.squads[1].code) if str(s0.squads[0].code) == club else str(s0.squads[0].code)
		if them == vs or tries > 80:
			break
		tries += 1
	print("match ", state.pending_sim.squads[0].code, " v ", state.pending_sim.squads[1].code, " seed ", state.career_seed)
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(16)
	var pitch = scene.get("_pitch")
	var breaks := 0
	var fed := false
	var guard := 0
	while guard < 40000:
		guard += 1
		var box: Node = scene.find_child("CoachBox", true, false)
		if box != null:
			breaks += 1
			if breaks == 3:
				await _frames(8)
				await _shot(out, "half")
				for key in ["mu", "tag"]:
					var row: Node = scene.find_child("CallRow_" + key, true, false)
					if row is Button:
						(row as Button).emit_signal("pressed")
						await _frames(10)
						if key == "mu":
							var ch: Node = scene.find_child("ChangeMatchup", true, false)
							if ch is Button:
								(ch as Button).emit_signal("pressed")
								await _frames(10)
						await _shot(out, "half_" + key)
						# Back to the break for the next call.
						for o in scene.get_children():
							if o is Control and (str(o.name).begins_with("CallSheet_") or str(o.name) == "MatchupChooser" or str(o.name) == "PlayerSheet"):
								o.queue_free()
						await _frames(6)
			var start: Node = scene.find_child("StartQuarter", true, false)
			if start is Button:
				(start as Button).emit_signal("pressed")
			await _frames(6)
			continue
		if pitch.playing:
			pitch._process(0.25)
		await process_frame
		var card: Node = scene.find_child("MomentCard", true, false)
		if card != null:
			var pick: Node = card.find_child("Moment_0", true, false)
			if pick is Button:
				(pick as Button).emit_signal("pressed")
			await _frames(6)
		var feed: Node = scene.get("_feed")
		if not fed and feed != null and feed.get_child_count() >= 7 and breaks >= 1:
			fed = true
			await _frames(8)
			await _shot(out, "feed")
		if scene.get("_finished") == true:
			break
	await _frames(30)
	await _shot(out, "full")
	for sc in scene.find_children("*", "ScrollContainer", true, false):
		if (sc as ScrollContainer).is_visible_in_tree() and (sc as ScrollContainer).get_v_scroll_bar().max_value > 400.0:
			(sc as ScrollContainer).scroll_vertical = int((sc as ScrollContainer).get_v_scroll_bar().max_value * 0.55)
			break
	await _frames(8)
	await _shot(out, "full2")
	quit()
