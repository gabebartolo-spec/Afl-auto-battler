extends SceneTree
## Key moments (P-14) for the director's look: the hub's poster with its three
## ways to take the match, and your match part-way through in Key moments.
## Needs a real renderer:
##   godot --path . --script tools/visual/capture_key_moments.gd -- --out /tmp/km [--size 390x844] [--club FRE] [--opp MEL] [--way key]
## Writes <out>_poster.png (the hub, the poster and its choices) and <out>_match.png
## (the match screen in Key moments, the first quarter under way).

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	await _frames(10)
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if W >= 760 and img.get_width() != W:
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("wrote ", path, " ", img.get_size())


func _run() -> void:
	var out := "/tmp/km"
	var club := "FRE"
	var opp := "MEL"
	var way := "key"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--club":
				club = str(a[i + 1])
			"--opp":
				opp = str(a[i + 1])
			"--way":
				way = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				W = int(wh[0])
				H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_km.save"
	state.settings_path = "user://capture_km_settings.cfg"
	state.show_real_names = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(W, H))
	await _frames(10)
	var layout = root.get_node("ScreenLayout")
	var base: float = layout.desktop_density(Vector2(root.size), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0)
	layout.ui_scale = 1.0 / maxf(1.0, base)
	layout._update_scale()
	await _frames(10)
	# A season whose first match is against `opp`.
	var found := false
	for tries in range(120):
		state.reset()
		state.career_seed = 2050 + tries
		state.replay_seed = 2050 + tries
		state.set_setting("seen_weekly_loop_intro", true)
		state.set_setting("seen_training_intro", true)
		state.start_season(club, db.club_list(club))
		var m: Dictionary = {}
		for f in state.season.fixture[state.season.round_index]:
			if str(f["home"]) == club or str(f["away"]) == club:
				m = f
		if str(m.get("home", "")) == opp or str(m.get("away", "")) == opp:
			found = true
			break
	print("opponent ", opp, " found ", found)
	state.set_match_way(way)
	var router = root.get_node("Router")
	router.go("hub")
	await _frames(20)
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == "Got it" and (b as Button).is_visible_in_tree():
			(b as Button).emit_signal("pressed")
	await _frames(40)
	await _shot(out + "_poster.png")
	# Your match in Key moments, the first quarter under way.
	state.set_match_way("key")
	state.set_vignettes_on(false)
	state.prepare_interactive_match()
	router.go("match")
	await _frames(30)
	var scene := current_scene
	var start = scene.find_child("StartQuarter", true, false)
	if start != null:
		start.emit_signal("pressed")
	await _frames(20)
	var pitch = scene.get("_pitch")
	for i in range(400):
		if pitch != null and pitch.playing and float(pitch.speed) >= 8.0 and int(pitch.current_index()) > 60:
			break
		await process_frame
	print("speed ", pitch.speed if pitch != null else -1, " events ", pitch.current_index() if pitch != null else -1)
	await _shot(out + "_match.png")
	quit(0)
