extends SceneTree
## Visual review of the award walk-on (AwardWinnerVignette) in the awards ceremony, on a
## phone. Real renderer, e.g.:
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --script tools/visual/capture_awards.gd ##       -- --out /tmp/ard-awards [--width 360]
## Writes <out>_<width>.png: the winner's scene, as laid out in the ceremony at that phone
## width, at the walk-on's beats (walking on, turned to us, medal on, arms up), side by side.
## Illustrative fixture only; never touches a real save.

const BEATS := [0.4, 1.0, 1.5, 2.0, 2.4]


func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "/tmp/ard-awards"
	var width := 360
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--width": width = int(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	var p: Dictionary = state.my_list[0]
	var row := {"id": str(p["id"]), "club": "COL", "votes": 24, "bf": 118, "goals": 71, "slot": "MID"}
	state.season_awards = {"year": 2027, "brownlow": [row], "coleman": [row], "all_australian": [row], "best_and_fairest": {"COL": [row]}}
	var h := int(round(width * 2.2))
	root.size = Vector2i(width, h)
	DisplayServer.window_set_size(Vector2i(width, h))
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ceremony: Control = load("res://scripts/ui/SeasonAwards.gd").open(host)
	for i in range(5):
		await process_frame
	ceremony.find_child("AwardsNext", true, false).emit_signal("pressed")
	for i in range(5):
		await process_frame
	var scene: Control = ceremony.find_child("AwardWinner", true, false)
	for i in range(90):          # the card fades in
		await process_frame
	scene.set_process(false)
	var r := Rect2i(scene.get_global_rect())
	var sheet := Image.create(r.size.x * BEATS.size(), r.size.y, false, Image.FORMAT_RGBA8)
	for c in range(BEATS.size()):
		scene.set("_t", float(BEATS[c]))
		scene.queue_redraw()
		for i in range(3):
			await process_frame
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, r, Vector2i(c * r.size.x, 0))
	var path := "%s_%d.png" % [out, width]
	print("scene ", r)
	sheet.save_png(path)
	print("wrote ", path)
	quit()
