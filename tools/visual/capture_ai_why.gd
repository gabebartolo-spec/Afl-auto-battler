extends SceneTree
## Review capture for P-18 ("the other club says why"): the trade screen with a
## rival's refusal and its one-line reason, dark. Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_ai_why.gd
## Environment: CAP_DIR (folder for the pngs, default "."), CAP_CLUB (default
## "FRE"), CAP_RIVAL (default "SYD"), CAP_W / CAP_H (default 390 x 844).
## A fresh career fast-forwarded to the off-season; you offer a fringe player
## for the rival's best. Never touches a real save.


func _initialize() -> void:
	_run.call_deferred()


func _frames(n := 8) -> void:
	for i in range(n):
		await process_frame


func _shot(path: String) -> void:
	await _frames()
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(path) != OK:
		push_error("could not save " + path)
	print("wrote ", path)


func _scroll_to(scene: Node, target: Control, above := 70) -> void:
	var boxes := scene.find_children("*", "ScrollContainer", true, false)
	for b in boxes:
		var box := b as ScrollContainer
		if box.is_visible_in_tree() and box.is_ancestor_of(target):
			box.scroll_vertical = maxi(0, int(target.global_position.y - box.global_position.y) - above + box.scroll_vertical)
	await _frames()


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _run() -> void:
	var dir := _env("CAP_DIR", ".")
	var club := _env("CAP_CLUB", "FRE")
	var rival := _env("CAP_RIVAL", "SYD")
	var size := Vector2i(int(_env("CAP_W", "390")), int(_env("CAP_H", "844")))
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_ai_why.save"
	state.settings_path = "user://capture_ai_why.cfg"
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.set_setting("seen_training_intro", true)
	state.start_season(club, db.club_list(club))
	state.set_setting("seen_weekly_loop_intro", true)
	UK.apply_appearance("dark")
	root.size = size
	DisplayServer.window_set_size(size)
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var season = state.season
	while not season.is_regular_done():
		state.advance()
	state.open_offseason()
	state.trade_requests = {}
	state.trade_offers = []
	var mine: Array = state.my_list.duplicate()
	mine.sort_custom(func(a, b): return int(a["overall"]) < int(b["overall"]))
	var theirs: Array = (state.season.lists[rival] as Array).duplicate()
	theirs.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var give := [str(mine[2]["id"])]
	var ask := [str(theirs[0]["id"])]
	var v: Dictionary = state.evaluate_trade(rival, give, ask)
	print("verdict: ", v.get("code", ""), " | ", v.get("reason", ""))
	var off = load("res://scenes/OffseasonScene.tscn").instantiate()
	off.set("_tab", "trade")
	root.add_child(off)
	# _ready picks the first club to trade with: set ours after it.
	off.set("_trade_club", rival)
	off.set("_mine", give)
	off.set("_theirs", ask)
	off.call("_build")
	await _frames(10)
	var line: Control = off.find_child("TradeVerdict", true, false)
	if line != null:
		await _scroll_to(off, line, int(size.y * 0.45))
	await _shot("%s/aiwhy_trade_%dx%d.png" % [dir, size.x, size.y])
	quit()
