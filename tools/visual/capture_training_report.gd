extends SceneTree
## Visual review tool for the monthly training report. Needs a real renderer:
##   godot --path . --script tools/visual/capture_training_report.gd -- --club FRE --w 390 --h 844 --out /tmp/tr
## Writes <out>_hub.png (the hub card), <out>_sheet.png (the report),
## <out>_sheet_end.png (its foot: retraining) and <out>_training.png (the link).

var W := 390
var H := 844
var uiscale := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := "/tmp/tr"
	var club := "FRE"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--club": club = str(a[i + 1])
			"--w": W = int(a[i + 1])
			"--h": H = int(a[i + 1])
			"--uiscale": uiscale = float(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.set_setting("seen_training_intro", true)
	state.replay_seed = 2027
	state.tutorials = false
	Features.set_on("training_report", true)
	state.start_season(club, db.club_list(club))
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	if uiscale > 0.0:
		var sl = root.get_node("ScreenLayout")
		sl.ui_scale = uiscale
		sl._update_scale()
	await process_frame
	print("logical ", root.content_scale_size, " window ", root.size)
	var made := 0
	for p in state.my_list:
		if made < 3 and int(p.get("potential", 0)) < 95:
			p["potential"] = 95
			made += 1
	for i in range(4):
		state.advance()
	state.skip_media_conference()
	router.stack = ["main"]
	router.go("hub")
	await _shot()
	(await _shot()).save_png(out + "_hub.png")
	var hub := current_scene
	var opener = hub.find_child("TrainingReportOpen", true, false)
	if opener == null:
		print("no card")
		quit(1)
		return
	opener.emit_signal("pressed")
	(await _shot()).save_png(out + "_sheet.png")
	var sheet = hub.find_child("TrainingReportSheet", true, false)
	if OS.get_environment("TRDEBUG") != "":
		for c in sheet.find_children("*", "Control", true, false):
			var m: Vector2 = c.get_combined_minimum_size()
			if m.x > 500:
				print("WIDE ", c.get_class(), " ", c.name, " ", m)
	var scrolls = sheet.find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		var sc: ScrollContainer = scrolls[0]
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	(await _shot()).save_png(out + "_sheet_end.png")
	sheet.queue_free()
	router.go("training")
	await _shot()
	(await _shot()).save_png(out + "_training.png")
	print("wrote ", out)
	Features.clear("training_report")
	quit(0)
