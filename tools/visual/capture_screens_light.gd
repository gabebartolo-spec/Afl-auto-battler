extends SceneTree
## Visual review tool for the main screens in light mode, on a phone (390x844),
## one sheet per theme so a light defect can be seen against the dark original.
## Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_screens_light.gd
## `--out PREFIX` and `--mode light|dark` after `--` (capture.yml passes them) beat the environment. Environment: CAP_OUT (path prefix, default "screens"), CAP_MODE ("light" default or "dark").
## --size WxH: the window (default 390x844; 3840x2160 is a 1280x720 PC canvas at 300%).
## Writes <prefix>_<mode>_<screen>.png for the hub, selection, training,
## list and coaching screens of a fresh Melbourne career, then the offseason (the
## season fast-forwarded to its end) and the League Draft. Never touches a real save.

var W := 390
var H := 844
const SCREENS := {"hub": "HubScene", "selection": "SelectionScene",
		"training": "TrainingScene", "list": "ListScene", "coaching": "CoachingScene",
		"staff": "StaffScene", "stats": "StatsHubScene"}


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(6):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Text that does not fit (visual audit Phase 6.2: names never cut). Walks a
## screen and lists every visible Label or Button whose text is wider than its
## box while the control trims or clips it, and every one that reaches past the
## window. Information for the reviewer, never a gate; the sheet still has to be
## looked at, because this cannot see a wrapped line that is simply too long.
func _clips(node: Node, screen: String, found: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label or node is Button:
		var c := node as Control
		var text := str(node.get("text"))
		if text != "" and c.size.x > 1.0:
			var font: Font = c.get_theme_font("font")
			var fs := int(c.get_theme_font_size("font_size"))
			var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var wraps: bool = (node is Label and (node as Label).autowrap_mode != TextServer.AUTOWRAP_OFF) 					or (node is Button and (node as Button).autowrap_mode != TextServer.AUTOWRAP_OFF)
			var trims: bool = bool(node.get("clip_text")) or int(node.get("text_overrun_behavior")) != TextServer.OVERRUN_NO_TRIMMING
			var room := c.size.x
			if node is Button:
				var sb := c.get_theme_stylebox("normal")
				room -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
			if not wraps and trims and wide > room + 0.5:
				found.append("CUT %s %s \"%s\" needs %d has %d" % [screen, c.name, text.left(40), int(wide), int(room)])
			var r := c.get_global_rect()
			if r.position.x < -0.5 or r.end.x > float(W) + 0.5:
				found.append("OUT %s %s \"%s\" spans %d..%d of %d" % [screen, c.name, text.left(40), int(r.position.x), int(r.end.x), W])
	for ch in node.get_children():
		_clips(ch, screen, found)


func _run() -> void:
	var out := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "screens"
	var mode := OS.get_environment("CAP_MODE") if OS.get_environment("CAP_MODE") != "" else "light"
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		if str(cli[i]) == "--out":
			out = str(cli[i + 1])
		if str(cli[i]) == "--mode":
			mode = str(cli[i + 1])
		if str(cli[i]) == "--size":
			var wh := str(cli[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_screens.save"
	state.settings_path = "user://capture_screens.cfg"
	state.reset()
	# Seeded, so a before/after pair shows the same career (same opponent and
	# hub cards); unseeded, every run drew a different one.
	state.career_seed = 2031
	state.replay_seed = 2031
	state.set_setting("seen_training_intro", true)
	state.set_setting("seen_weekly_loop_intro", true)
	state.set_setting("seen_season_stats_intro", true)
	state.start_season("MEL", db.club_list("MEL"))
	# CAP_WEATHER=wet (or windy, hot): start at the first round whose forecast
	# for your match is that, so the hub shows it.
	var want_wx := OS.get_environment("CAP_WEATHER")
	if want_wx != "":
		var found := -1
		for r in range(state.season.fixture.size()):
			for m in state.season.fixture[r]:
				if found < 0 and (m["home"] == "MEL" or m["away"] == "MEL") and state.season.weather_for(str(m["home"]), str(m["away"]), r) == want_wx:
					found = r
		if found >= 0:
			state.season.round_index = found
	UK.apply_appearance(mode)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var clips := []
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	for key in SCREENS:
		var scene = load("res://scenes/%s.tscn" % SCREENS[key]).instantiate()
		root.add_child(scene)
		var img := await _shot()
		_clips(scene, key, clips)
		var path := "%s_%s_%s.png" % [out, mode, key]
		if img.save_png(path) != OK:
			push_error("could not save " + path)
		print("wrote ", path)
		# The hub below the fold: the ladder and its heading link, where a
		# phone's thumb scrolls to (audit §8 Phase 1.1).
		if key == "hub":
			var ladder: Control = scene.find_child("LadderSection", true, false)
			var sc: Node = ladder.get_parent() if ladder != null else null
			while sc != null and not (sc is ScrollContainer):
				sc = sc.get_parent()
			if sc != null:
				(sc as ScrollContainer).ensure_control_visible(ladder)
				var img2 := await _shot()
				img2.save_png("%s_%s_hub_ladder.png" % [out, mode])
				print("wrote hub ladder")
		scene.queue_free()
		await process_frame
	# The offseason: the home-and-away season is done, the draft is next.
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	var off = load("res://scenes/OffseasonScene.tscn").instantiate()
	root.add_child(off)
	(await _shot()).save_png("%s_%s_offseason.png" % [out, mode])
	_clips(off, "offseason", clips)
	print("wrote offseason")
	off.queue_free()
	await process_frame
	# The League Draft, on a fresh career.
	state.reset()
	state.set_setting("seen_training_intro", true)
	state.draft = load("res://scripts/sim/Draft.gd").new(db.all_players_sorted(), db.active_clubs(2026).duplicate(), 12345)
	var draft = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(draft)
	draft.call("_on_club_chosen", "MEL")
	(await _shot()).save_png("%s_%s_draft.png" % [out, mode])
	_clips(draft, "draft", clips)
	print("wrote draft")
	var clip_file := FileAccess.open("%s_%s_clips.txt" % [out, mode], FileAccess.WRITE)
	if clip_file != null:
		clip_file.store_string("
".join(clips) + "
")
	print("CLIPS %d" % clips.size())
	for line in clips:
		print(line)
	quit(0)
