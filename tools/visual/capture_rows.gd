extends SceneTree
## Rows with a label and a figure (readability: the figure sits next to its name), as a PC, a
## wide screen and a phone show them. Needs a real renderer:
##   godot --path . --script tools/visual/capture_rows.gd -- --out /tmp/rows --size 1280x720 [--club MEL]
## Writes <out>_<screen>.png for the hub, season review, coaching and team selection. Each is drawn in
## its own viewport of exactly the size asked for. Seeded; never touches a real save.

const SCREENS := {"hub": "HubScene", "review": "SeasonReviewScene", "coaching": "CoachingScene",
		"selection": "SelectionScene"}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "rows"
	var club := "MEL"
	var w := 390
	var h := 844
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--club": club = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				w = int(wh[0])
				h = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_rows.save"
	state.settings_path = "user://capture_rows.cfg"
	load("res://scripts/ui/UiKit.gd").apply_appearance("dark")
	for key in SCREENS:
		state.reset()
		state.career_seed = 2026
		state.replay_seed = 2026
		state.set_setting("seen_training_intro", true)
		state.tutorials = false
		state.start_season(club, db.club_list(club))
		for i in range(6):
			state.advance()
		var vp := SubViewport.new()
		vp.size = Vector2i(w, h)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var scene: Node = load("res://scenes/%s.tscn" % SCREENS[key]).instantiate()
		vp.add_child(scene)
		for i in range(24):
			await process_frame
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png("%s_%s.png" % [out, key])
		print("wrote ", out, "_", key, ".png")
		vp.queue_free()
		await process_frame
	quit()
