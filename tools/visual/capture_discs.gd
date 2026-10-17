extends SceneTree
## godot --path . --script tools/visual/capture_discs.gd -- OUTDIR
## Boards of the oval's discs: every club at game size and 2x (the three-colour
## clubs show their ring), and the 10 closest home/away pairs after the clash
## rule, each on the turf green.

const GREEN := Color(0.2, 0.42, 0.2)


class Board extends Control:
	var kits: Array = []        # [{name, kit}]
	var pairs: Array = []       # [{label, h, a, score}]
	var pv

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), GREEN)
		var font := ThemeDB.fallback_font
		for i in range(kits.size()):
			var col := i % 6
			var row := i / 6
			var x: float = 20.0 + col * 150.0
			var y: float = 20.0 + row * 90.0
			draw_string(font, Vector2(x, y + 4), str(kits[i]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			pv.paint_disc(self, Vector2(x + 10, y + 36), 9.0, kits[i]["kit"], "7", 11, true)
			pv.paint_disc(self, Vector2(x + 70, y + 40), 18.0, kits[i]["kit"], "7", 15, true)
		var base: float = 20.0 + ceil(kits.size() / 6.0) * 90.0 + 20.0
		draw_string(font, Vector2(20, base), "10 closest pairs after the clash rule (home | away), game size and 2x", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		for i in range(pairs.size()):
			var col2 := i % 2
			var row2 := i / 2
			var x2: float = 20.0 + col2 * 440.0
			var y2: float = base + 40.0 + row2 * 60.0
			draw_string(font, Vector2(x2, y2 - 18), str(pairs[i]["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			pv.paint_disc(self, Vector2(x2 + 12, y2 + 8), 9.0, pairs[i]["h"], "7", 11, true)
			pv.paint_disc(self, Vector2(x2 + 40, y2 + 8), 9.0, pairs[i]["a"], "7", 11, true)
			pv.paint_disc(self, Vector2(x2 + 100, y2 + 8), 18.0, pairs[i]["h"], "7", 15, true)
			pv.paint_disc(self, Vector2(x2 + 150, y2 + 8), 18.0, pairs[i]["a"], "7", 15, true)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var out := "user://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var PV = load("res://scripts/ui/PitchView.gd")
	var gdb = root.get_node("GameDB")
	var order: Array = gdb.CLUB_ORDER.slice(0, 18)
	var b := Board.new()
	b.pv = PV
	b.size = Vector2(900, 1000)
	for c in order:
		b.kits.append({"name": gdb.club_short(str(c)), "kit": PV.with_trim(str(c), gdb.club_guernsey(str(c)))})
	var rows := []
	for h in order:
		for a in order:
			if h != a:
				var k: Array = PV.kits_for(str(h), str(a))
				rows.append([PV.disc_distance(k[0], k[1]), "%s v %s%s" % [h, a, " (clash)" if bool(k[1].get("clash", false)) else ""], k])
	rows.sort_custom(func(x, y): return x[0] < y[0])
	for i in range(10):
		b.pairs.append({"label": "%s  %.0f" % [rows[i][1], rows[i][0]], "h": rows[i][2][0], "a": rows[i][2][1]})
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(900, 1000)
	root.add_child(b)
	for i in range(5):
		b.queue_redraw()
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path: String = out.path_join("board_discs.png")
	print("saved ", path, " ", img.save_png(path))
	quit(0)
