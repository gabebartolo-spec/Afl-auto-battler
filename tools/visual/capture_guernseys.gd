extends SceneTree
## Visual review of every club's guernsey on the vignette figures: front and back
## (with a number), through the real figure shader. Needs a real renderer, e.g.:
##   xvfb-run -a -s "-screen 0 1280x900x24" godot --path . --rendering-driver opengl3 \
##       --script tools/visual/capture_guernseys.gd -- --out /tmp/guernseys [--scale 1.2] [--clubs PAD,WCE]
## Writes <out>.png. The designs come from data/clubs.csv ("guernsey").

const COLS := 5
const SCALE := 0.62
var scale := SCALE
var cell_size := Vector2(168, 236)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/guernseys"
	var a := OS.get_cmdline_user_args()
	var only := []
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		elif str(a[i]) == "--scale":
			scale = float(a[i + 1])
		elif str(a[i]) == "--clubs":
			only = str(a[i + 1]).split(",")
	cell_size = Vector2(168, 236) * scale / SCALE
	await process_frame
	var db = root.get_node("GameDB")
	# Loaded now, not named: the vignette needs the autoloads to compile.
	var vignette: GDScript = load("res://scripts/ui/match/StoppageVignette.gd")
	var layout: GDScript = load("res://scripts/ui/match/VignetteFigures.gd")
	var codes: Array = db.clubs.keys() if only.is_empty() else only
	var rows := int(ceil(codes.size() / float(COLS)))
	root.size = Vector2i(int(cell_size.x * COLS), int(cell_size.y * rows))
	DisplayServer.window_set_size(root.size)
	var bg := ColorRect.new()
	bg.color = Color(0.17, 0.41, 0.18)
	bg.size = Vector2(root.size)
	root.add_child(bg)
	var font: Font = ThemeDB.fallback_font
	# The shader holds four kits at a time: one Control per four clubs.
	for start in range(0, codes.size(), 4):
		var group: Array = codes.slice(start, start + 4)
		var kits := []
		for code in group:
			var kit: Dictionary = db.club_guernsey(str(code))
			kits.append(kit)
		var c := Control.new()
		c.size = Vector2(root.size)
		c.material = vignette.figure_material(kits)
		root.add_child(c)
		c.draw.connect(func():
			for k in range(group.size()):
				var n := start + k
				var cell := Vector2((n % COLS) * cell_size.x, (n / COLS) * cell_size.y)
				var body: Dictionary = layout.BODIES["average"]
				for f in range(2):
					var facing := "front" if f == 0 else "back"
					var info: Dictionary = body["anims"]["idle"][facing]
					var src := Rect2(float(body["x"]), int(info["row"]) * layout.FRAME.y, layout.FRAME.x, layout.FRAME.y)
					var at := cell + Vector2(4 + f * 80 * scale / SCALE, 18)
					c.draw_texture_rect_region(vignette.FIGURE_SHADE, Rect2(at, layout.FRAME * scale), src,
							Color(k / 4.0, 0.0, 0.0, 1.0))
					if facing == "back":
						var r: Array = info["number_rects"][0]
						var fs := int(r[3] * scale * 0.42)
						var base: Color = kits[k]["base"]
						var ink := Color(0.08, 0.08, 0.1) if base.get_luminance() > 0.55 else Color.WHITE
						var pos := at + Vector2(r[0], r[1] + r[3] * 0.62) * scale
						c.draw_string_outline(font, pos, str(n + 1), HORIZONTAL_ALIGNMENT_CENTER, r[2] * scale,
								fs, maxi(2, fs / 6), base)
						c.draw_string(font, pos, str(n + 1), HORIZONTAL_ALIGNMENT_CENTER, r[2] * scale, fs, ink)
				var label := "%s  %s" % [codes[n], kits[k]["design"]]
				c.draw_string(font, cell + Vector2(6, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE))
		c.queue_redraw()
	for i in range(6):
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + ".png")
	print("wrote ", out + ".png")
	quit(0)
