extends SceneTree
## Visual review tool for the main screens in light mode, on a phone (390x844),
## one sheet per theme so a light defect can be seen against the dark original.
## Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_screens_light.gd
## `--out PREFIX` and `--mode light|dark` after `--` (capture.yml passes them) beat the environment. Environment: CAP_OUT (path prefix, default "screens"), CAP_MODE ("light" default or "dark").
## Writes <prefix>_<mode>_<screen>.png for the hub, ladder, selection, training,
## list and coaching screens of a fresh Melbourne career, then the offseason (the
## season fast-forwarded to its end) and the League Draft. Never touches a real save.

const W := 390
const H := 844
const SCREENS := {"hub": "HubScene", "ladder": "LadderScene", "selection": "SelectionScene",
		"training": "TrainingScene", "list": "ListScene", "coaching": "CoachingScene"}


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(6):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "screens"
	var mode := OS.get_environment("CAP_MODE") if OS.get_environment("CAP_MODE") != "" else "light"
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		if str(cli[i]) == "--out":
			out = str(cli[i + 1])
		if str(cli[i]) == "--mode":
			mode = str(cli[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_screens.save"
	state.settings_path = "user://capture_screens.cfg"
	state.reset()
	state.set_setting("seen_training_intro", true)
	state.start_season("MEL", db.club_list("MEL"))
	UK.apply_appearance(mode)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	for key in SCREENS:
		var scene = load("res://scenes/%s.tscn" % SCREENS[key]).instantiate()
		root.add_child(scene)
		var img := await _shot()
		var path := "%s_%s_%s.png" % [out, mode, key]
		if img.save_png(path) != OK:
			push_error("could not save " + path)
		print("wrote ", path)
		scene.queue_free()
		await process_frame
	# The offseason: the home-and-away season is done, the draft is next.
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	var off = load("res://scenes/OffseasonScene.tscn").instantiate()
	root.add_child(off)
	(await _shot()).save_png("%s_%s_offseason.png" % [out, mode])
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
	print("wrote draft")
	quit(0)
