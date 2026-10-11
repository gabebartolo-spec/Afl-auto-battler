extends SceneTree
## How strong a living-background look is under type: each look and club drawn
## alone on the page (at rest and at the start of its slide), then the
## contrast of TEXT and MUTED against the brightest pixel and the 99th
## percentile of the page. Needs a renderer (capture.yml, no movie).
##   --size WxH  (default 390x844)

func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := str(a[i])
		if k.begins_with("--"):
			var v := ""
			if i + 1 < a.size() and not str(a[i + 1]).begins_with("--"):
				v = str(a[i + 1])
				i += 1
			out[k.substr(2)] = v
		i += 1
	return out


func _lum(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


func _cr(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var W := 390
	var H := 844
	var args := _args()
	if args.has("size"):
		var wh := str(args["size"]).split("x")
		W = int(wh[0])
		H = int(wh[1])
	var ui = load("res://scripts/ui/UiKit.gd")
	var BD = load("res://scripts/ui/ClubBackdrop.gd")
	var text: Color = ui.TEXT
	var muted: Color = ui.MUTED
	print("MEASURE page %dx%d; contrast of TEXT / MUTED type vs the club backdrop, floor 4.5" % [W, H])
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://measure_bd.save"
	state.settings_path = "user://measure_bd_settings.cfg"
	state.set_vignettes_on(false)
	root.size = Vector2i(W, H)
	for club in ["COL", "GCS", "RIC", "ADE", "BRL"]:
		state.reset()
		state.replay_seed = 2027
		state.set_setting("seen_weekly_loop_intro", true)
		state.start_season(club, db.club_list(club))
		state.tutorials = false
		state.media_conference = {}
		state.backing_talk = {}
		# The real hub, then every muted line on it: where grey type sits.
		var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
		root.add_child(hub)
		await process_frame
		await process_frame
		await process_frame
		var rects: Array = []
		for n in hub.find_children("*", "Label", true, false):
			var l := n as Label
			if not l.is_visible_in_tree() or l.text.strip_edges() == "":
				continue
			var fc: Color = l.get_theme_color("font_color")
			if _cr(fc, muted) < 1.05:
				rects.append(l.get_global_rect())
		hub.queue_free()
		await process_frame
		for settle in [1.0, 0.0]:
			var vp := SubViewport.new()
			vp.size = Vector2i(W, H)
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(vp)
			var bd = BD.new().setup(club)
			bd._settle = settle
			vp.add_child(bd)
			await process_frame
			await process_frame
			await process_frame
			var img := vp.get_texture().get_image()
			var worst_page := Color.BLACK
			var wl := -1.0
			for y in range(9, H, 3):   # below the 6 px gold edge at the very top, where no type sits
				for x in range(0, W, 3):
					var c := img.get_pixel(x, y)
					if _lum(c) > wl:
						wl = _lum(c)
						worst_page = c
			var worst_m := Color.BLACK
			var ml := -1.0
			for r in rects:
				var rr: Rect2 = r
				for y in range(int(rr.position.y), int(rr.end.y), 2):
					for x in range(int(rr.position.x), int(rr.end.x), 4):
						if x < 0 or y < 0 or x >= W or y >= H:
							continue
						var c := img.get_pixel(x, y)
						if _lum(c) > ml:
							ml = _lum(c)
							worst_m = c
			print("MEASURE %s %s  brightest page pixel %s TEXT %.1f MUTED %.1f | under %d muted lines: brightest %s MUTED %.1f" % [
					club, "rest " if settle == 1.0 else "start", worst_page.to_html(false),
					_cr(text, worst_page), _cr(muted, worst_page), rects.size(),
					worst_m.to_html(false), _cr(muted, worst_m)])
			if settle == 1.0:
				img.save_png("%s_%s.png" % [str(args.get("out", "/tmp/m")), club])
			vp.queue_free()
			await process_frame
	quit(0)
