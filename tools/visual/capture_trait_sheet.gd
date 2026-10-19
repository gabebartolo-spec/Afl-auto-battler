extends SceneTree
## The trait sheet (TraitLink), for the director's look. Needs a real renderer:
##   godot --path . --windowed --script tools/visual/capture_trait_sheet.gd -- --out /tmp/tr
##       [--size 390x844] [--club FRE] [--mode player|synergy|selection]
## player: a player's sheet with one of his traits opened over it; synergy: a synergy
## sheet over the selection screen; selection: the selection screen's synergy line.
## Writes <out>.png.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/tr"
	var club := "FRE"
	var mode := "player"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var v := str(a[i + 1]) if i + 1 < a.size() else ""
		match str(a[i]):
			"--out": out = v
			"--club": club = v
			"--mode": mode = v
			"--size":
				W = int(v.split("x")[0])
				H = int(v.split("x")[1])
	await process_frame
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	gs.autosave_enabled = false
	gs.save_path = "user://cap_trait.save"
	gs.settings_path = "user://cap_trait.cfg"
	gs.show_real_names = false
	gs.reset()
	gs.set_setting("seen_training_intro", true)
	gs.start_season(club, db.club_list(club))
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var tl = load("res://scripts/ui/TraitLink.gd")
	var traits = load("res://scripts/sim/Traits.gd")
	var host: Control
	if mode == "player":
		var kit = load("res://scripts/ui/UiKit.gd")
		host = ColorRect.new()
		(host as ColorRect).color = kit.BG
		root.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pick: Dictionary = {}
		for q in gs.my_list:
			if traits.of(q).size() >= 2:
				pick = q
				break
		load("res://scripts/ui/PlayerSheet.gd").open(host, pick)
		for i in range(6):
			await process_frame
		var line = host.find_child("Trait_" + str(traits.of(pick)[0]), true, false)
		tl.open(line, str(traits.of(pick)[0]))
	else:
		host = load("res://scenes/SelectionScene.tscn").instantiate()
		root.add_child(host)
		for i in range(8):
			await process_frame
		if mode == "synergy":
			tl.open(host, "engine_room")
	for i in range(10):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + ".png")
	print("wrote ", out + ".png")
	quit()
