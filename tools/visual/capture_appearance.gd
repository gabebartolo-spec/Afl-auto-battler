extends SceneTree
## Review sheet for player appearance (data/player_appearance.csv): every player
## of a club as he looks on the vignette figures, with his real name, skin tone
## (1-6), hair colour and the row's status. "unsure" rows are marked; real
## players without a row show "default" (Appearance.UNCURATED). The top strip
## is the tone and hair palette.
##   godot --path . --rendering-driver opengl3 --script tools/visual/capture_appearance.gd \
##       -- --club ADE --out /tmp/appearance_ADE
## Writes <out>.png.

const COLS := 8
const CELL := Vector2(118, 186)
const SCALE := 0.5
const TOP := 150.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/appearance"
	var club := "ADE"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		elif str(a[i]) == "--club":
			club = str(a[i + 1])
	await process_frame
	var db = root.get_node("GameDB")
	var appearance: GDScript = load("res://scripts/core/Appearance.gd")
	var vignette: GDScript = load("res://scripts/ui/match/StoppageVignette.gd")
	var layout: GDScript = load("res://scripts/ui/match/VignetteFigures.gd")
	var list: Array = db.club_list(club).duplicate()
	list.sort_custom(func(x, y): return int(x["num"]) < int(y["num"]))
	var rows := int(ceil(list.size() / float(COLS)))
	root.size = Vector2i(int(CELL.x * COLS), int(TOP + CELL.y * rows))
	DisplayServer.window_set_size(root.size)
	var bg := ColorRect.new()
	bg.color = Color(0.17, 0.41, 0.18)
	bg.size = Vector2(root.size)
	root.add_child(bg)
	var kit: Dictionary = db.club_guernsey(club)
	var c := Control.new()
	c.size = Vector2(root.size)
	c.material = vignette.figure_material([kit])
	root.add_child(c)
	var font: Font = ThemeDB.fallback_font
	var src: Rect2 = layout.source(layout.strip("average", "idle", "front"), 0)
	c.draw.connect(func():
		c.draw_string(font, Vector2(8, 16), "%s - skin tones 1-6 and hair colours" % club,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		for t in range(6):
			var at := Vector2(10 + t * 72, 20)
			c.draw_texture_rect_region(vignette.FIGURE_SHADE, Rect2(at, src.size * 0.42), src,
					Color(0.0, t / 8.0, 1 / 8.0, 1.0))
			c.draw_string(font, at + Vector2(22, 128), str(t + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		for h in range(appearance.HAIR.size()):
			var at := Vector2(470 + (h % 3) * 160, 30 + (h / 3) * 40)
			c.draw_rect(Rect2(at, Vector2(24, 24)), appearance.HAIR[h])
			c.draw_string(font, at + Vector2(30, 17), appearance.HAIR_KEYS[h], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		for n in range(list.size()):
			var p: Dictionary = list[n]
			var cell := Vector2((n % COLS) * CELL.x, TOP + (n / COLS) * CELL.y)
			var look: Dictionary = db.player_looks(p)
			var row: Dictionary = db.appearance.get(db._look_key(p), {})
			var status := str(row.get("status", "generated" if bool(p.get("generated", false)) else "default"))
			c.draw_texture_rect_region(vignette.FIGURE_SHADE, Rect2(cell + Vector2(26, 0), src.size * SCALE), src,
					Color(0.0, int(look["skin"]) / 8.0, int(look["hair"]) / 8.0, 1.0))
			var ink := Color(1, 0.55, 0.45) if status == "unsure" else (Color(0.75, 0.75, 0.75) if status in ["generated", "default"] else Color.WHITE)
			c.draw_string(font, cell + Vector2(4, 150), "%d %s" % [int(p["num"]), str(p["last"])],
					HORIZONTAL_ALIGNMENT_LEFT, CELL.x - 6, 12, Color.WHITE)
			c.draw_string(font, cell + Vector2(4, 165), "skin %d  %s" % [int(look["skin"]) + 1, appearance.HAIR_KEYS[int(look["hair"])]],
					HORIZONTAL_ALIGNMENT_LEFT, CELL.x - 6, 11, ink)
			c.draw_string(font, cell + Vector2(4, 179), status, HORIZONTAL_ALIGNMENT_LEFT, CELL.x - 6, 11, ink))
	c.queue_redraw()
	for i in range(6):
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + ".png")
	print("wrote ", out + ".png")
	quit(0)
