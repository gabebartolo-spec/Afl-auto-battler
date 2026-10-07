extends SceneTree
## Team selection (the team builder), for the director's look. Needs a real
## renderer:
##   godot --path . --script tools/visual/capture_selection.gd -- --out /tmp/sel [--size 1280x720] [--picked]
## --picked: one player tapped, waiting for the second tap. --opp: the oval
## flipped to this week's opponent. --guide: the synergy guide with Complete.
## Writes <out>_sheet.png.

var W := 1280
var H := 720


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/sel"
	var picked := false
	var mode := ""
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]) == "--out" and i + 1 < a.size():
			out = str(a[i + 1])
		if str(a[i]) == "--size" and i + 1 < a.size():
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
		if str(a[i]) == "--picked":
			picked = true
		if str(a[i]) in ["--opp", "--guide"]:
			mode = str(a[i]).trim_prefix("--")
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season("COL", db.club_list("COL"))
	var ui: Control = load("res://scenes/SelectionScene.tscn").instantiate()
	root.add_child(ui)
	for i in range(8):
		await process_frame
	if picked:
		var c: Button = ui.find_child("Spot_C", true, false)
		if c != null:
			c.emit_signal("pressed")
	match mode:
		"opp":
			ui.set("_view", "opp")
			ui.call("_build")
		"guide":
			ui.call("_show_synergies")
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
