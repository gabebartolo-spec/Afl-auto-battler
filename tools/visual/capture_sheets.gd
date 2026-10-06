extends SceneTree
## The "Your week" first-visit sheet on the hub, for the director's look at
## sheet sizing (PC playtest, 2026-10-07). Needs a real renderer:
##   godot --path . --script tools/visual/capture_sheets.gd -- --out /tmp/sheets [--size 1280x720]
## Writes <out>_sheet.png.

var W := 1280
var H := 720


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/sheets"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.set_setting("seen_weekly_loop_intro", false)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season("COL", db.club_list("COL"))
	root.get_node("Router").go("hub")
	for i in range(12):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
