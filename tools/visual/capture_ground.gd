extends SceneTree
## The live match view at a window size, to see whether the whole ground fits
## beside the side panel:
##   godot --path . --script tools/visual/capture_ground.gd -- --out /tmp/ground [--size 1280x720] [--club GEE]
## Writes <out>_match.png (the match a few seconds in) and prints the pitch
## control's rect, the drawn ground's rect (pitch_rect) and the side panel's.
## Needs a real renderer (capture.yml).

var W := 1280
var H := 720


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	var out := "/tmp/ground"
	var club := "GEE"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--club":
			club = str(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_ground.save"
	state.settings_path = "user://capture_ground.cfg"
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.set_setting("seen_training_intro", true)
	state.set_setting("seen_weekly_loop_intro", true)
	state.set_vignettes_on(false)
	state.start_season(club, db.club_list(club))
	state.tutorials = false
	if not state.prepare_interactive_match():
		push_error("no match to prepare")
		quit(1)
		return
	if a.has("--webish"):
		# The web build: is_desktop() is false there, whatever the window size.
		load("res://scripts/core/ScreenLayout.gd").force_phone = true
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var scene = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(30)
	var start: Button = scene.find_child("StartQuarter", true, false)
	if start != null:
		start.emit_signal("pressed")
	await _frames(300)   # play runs on
	var pitch: Control = scene.find_child("*", true, false) if false else scene.get("_pitch")
	var panel: Control = scene.get("_side_panel")
	var pr: Rect2 = pitch.call("pitch_rect")
	print("GROUND camera %s, zoom %.2f, stacked %s" % [str(pitch.get("camera_enabled")), float(pitch.get("_zoom")), str(scene.get("_stacked"))])
	print("GROUND window %s, pitch control %s, ground rect %s, side panel %s" % [
			str(root.size), str(pitch.get_global_rect()), str(Rect2(pitch.get_global_rect().position + pr.position, pr.size)),
			str(panel.get_global_rect())])
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + "_match.png")
	print("wrote ", out, "_match.png")
	quit(0)
