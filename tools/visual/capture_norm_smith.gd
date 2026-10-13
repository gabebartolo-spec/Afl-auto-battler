extends SceneTree
## The season review after a Grand Final, with the Norm Smith Medal line. Real renderer; capture.yml:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_norm_smith -f args="--club MEL --size 390x844"
## Plays a seeded season out and writes <out>.png of the review scene. Never touches a real save.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/norm_smith"
	var club := "MEL"
	var w := 390
	var h := 844
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var v := str(a[i + 1]) if i + 1 < a.size() else ""
		match str(a[i]):
			"--out": out = v
			"--club": club = v
			"--size":
				w = int(v.split("x")[0])
				h = int(v.split("x")[1])
	await process_frame
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	gs.autosave_enabled = false
	gs.save_path = "user://capture_ns.save"
	gs.settings_path = "user://capture_ns.cfg"
	gs.reset()
	gs.career_seed = 7
	gs.replay_seed = 7
	gs.start_season(club, db.club_list(club))
	var guard := 0
	while not gs.season.is_season_over() and guard < 60:
		gs.advance()
		guard += 1
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var scene: Control = load("res://scenes/SeasonReviewScene.tscn").instantiate()
	root.add_child(scene)
	for i in range(12):
		await process_frame
	var sc := scene.find_children("*", "ScrollContainer", true, false)
	var ns := scene.find_child("NormSmithMedal", true, false)
	if ns != null and not sc.is_empty():
		(sc[0] as ScrollContainer).ensure_control_visible(ns)
		for i in range(6):
			await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + ".png")
	print("wrote ", out, ".png norm smith: ", gs.season_awards.get("norm_smith", {}))
	quit()
