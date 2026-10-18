extends SceneTree
## The family line in the bio: Benji van Rooyen's draft card and Jacob van
## Rooyen's profile (Melbourne). Needs a real renderer:
##   godot --path . --script tools/visual/capture_family.gd -- --out /tmp/family --size 390x844 --kind card|profile
## Writes <out>_<kind>.png.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/family"
	var kind := "card"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--kind":
			kind = str(a[i + 1])
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
	state.show_real_names = true
	state.replay_seed = 2027
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	if kind == "card":
		state.begin_real_lists()
		var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
		root.add_child(ui)
		for i in range(6):
			await process_frame
		ui.call("_on_club_chosen", "MEL")
		for i in range(6):
			await process_frame
		ui.call("_open_player", "D2026_50")
	else:
		state.start_season("MEL", db.club_list("MEL"))
		var jacob := {}
		for p in state.my_list:
			if str(p.get("first", "")) == "Jacob" and str(p.get("last", "")) == "van Rooyen":
				jacob = p
		var host := Control.new()
		host.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(host)
		load("res://scripts/ui/PlayerSheet.gd").open(host, jacob)
	for i in range(14):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png("%s_%s_%d.png" % [out, kind, W])
	print("wrote ", out)
	quit(0)
