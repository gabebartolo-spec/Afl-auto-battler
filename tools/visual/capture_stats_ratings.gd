extends SceneTree
## Season stats > Ratings, for the director's look, and how it runs with the
## whole competition in it. Needs a real renderer:
##   godot --path . --script tools/visual/capture_stats_ratings.gd -- --out /tmp/sr [--size 390x844]
##       [--rounds 23]
## Writes <out>_top.png (the top of the list), <out>_mine.png (scrolled to your
## club's first player outside the top ten), <out>_rest.png (where the ranked
## players end) and prints the rows, the time to build the section and the
## frame times while the list is scrolled top to bottom.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/sr"
	var rounds := 23
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var v := str(a[i + 1]) if i + 1 < a.size() else ""
		match str(a[i]):
			"--out": out = v
			"--size":
				W = int(v.split("x")[0])
				H = int(v.split("x")[1])
			"--rounds": rounds = int(v)
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.replay_seed = 2031
	state.reset()
	state.set_setting("seen_season_stats_intro", true)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season("COL", db.club_list("COL"))
	for r in range(rounds):
		state.advance()
	var hub_script = load("res://scripts/ui/StatsHubScene.gd")
	# The same screen on the Ladder tab first: what opening Season stats costs
	# before any list is built.
	hub_script.current = "ladder"
	var tb := Time.get_ticks_usec()
	var base_ui: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(base_ui)
	await process_frame
	print("BASELINE ladder tab first frame %.0f ms" % ((Time.get_ticks_usec() - tb) / 1000.0))
	base_ui.queue_free()
	for i in range(3):
		await process_frame
	var tr0 := Time.get_ticks_usec()
	var data: Array = load("res://scripts/ui/stats/StatsRatings.gd").rows()
	print("RATINGS data for %d players %.0f ms" % [data.size(), (Time.get_ticks_usec() - tr0) / 1000.0])
	hub_script.current = "ratings"
	var t0 := Time.get_ticks_usec()
	var ui: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	var built_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var list_node: Node = ui.find_child("RatingsList", true, false)
	var guard := 0
	var fill_worst := 0.0
	var fl := Time.get_ticks_usec()
	while list_node != null and not bool(list_node.get_meta("filled", true)) and guard < 300:
		await process_frame
		guard += 1
		var fn := Time.get_ticks_usec()
		fill_worst = maxf(fill_worst, (fn - fl) / 1000.0)
		fl = fn
	var filled_ms := (Time.get_ticks_usec() - t0) / 1000.0
	for i in range(8):
		await process_frame
	var rows := ui.find_children("RatingRow_*", "Button", true, false)
	var nodes := ui.find_child("StatsRatings", true, false).find_children("*", "", true, false).size()
	_shot(out + "_top.png")
	var sc: ScrollContainer = ui.find_child("StatsScroll", true, false)
	# Scroll the whole list at a thumb's flick pace (60 px a frame) and time
	# every frame.
	var times := []
	var last := Time.get_ticks_usec()
	var bottom := int(sc.get_v_scroll_bar().max_value)
	var y := 0
	while y < bottom:
		y += 60
		sc.scroll_vertical = y
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	var total := 0.0
	for t in times:
		total += float(t)
	var n := maxi(1, times.size())
	print("RATINGS %dx%d rounds %d: %d rows, %d nodes, first frame %.0f ms, all rows %.0f ms (%d frames, worst %.1f ms); scroll %d frames, mean %.2f ms, p95 %.2f ms, worst %.2f ms" % [
			W, H, rounds, rows.size(), nodes, built_ms, filled_ms, guard, fill_worst, times.size(), total / n,
			float(times[int(n * 0.95) - 1]) if times.size() > 0 else 0.0, float(times[n - 1]) if times.size() > 0 else 0.0])
	# Your club's first player outside the top ten, in the middle of the screen.
	var mine: Control = null
	for i in range(rows.size()):
		if i >= 10 and str((rows[i] as Node).name) != "" and _is_mine(rows[i], state):
			mine = rows[i]
			break
	if mine != null:
		sc.scroll_vertical = int(mine.get_global_rect().position.y - sc.get_global_rect().position.y + sc.scroll_vertical - H / 3)
		for i in range(6):
			await process_frame
		_shot(out + "_mine.png")
	var split: Control = ui.find_child("RatingsUnranked", true, false)
	if split != null:
		sc.scroll_vertical = 0
		await process_frame
		sc.scroll_vertical = int(split.get_global_rect().position.y - sc.get_global_rect().position.y - H / 2)
		for i in range(6):
			await process_frame
		_shot(out + "_rest.png")
	quit(0)


func _is_mine(row: Control, state) -> bool:
	var sb := (row as Button).get_theme_stylebox("normal") as StyleBoxFlat
	return sb != null and sb.bg_color.a > 0.0


func _shot(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)
