extends SceneTree
## Review sheet for club marker A (GuernseyCrest): all 13 guernsey designs in
## a few clubs' colours at 24, 40 and 96 px, on the game's dark background,
## then the shipped clubs' own markers at list size and with their codes.
##   godot --path . --rendering-driver opengl3 --script tools/visual/capture_markers.gd -- --out /tmp/markers
## Writes <out>.png.

const DESIGNS := ["plain", "stripes", "hoops", "sash", "yoke", "band", "chevrons", "panels",
		"chevron", "sides", "tiers", "shoulders", "map"]
## name, code, primary, secondary, accent (the art agent's review clubs).
const CLUBS := [
	["Port Melbourne", "PMB", "#1f4fb8", "#c8102e", "#f2f2f2"],
	["Werribee", "WER", "#0e1a3a", "#f2c230", "#c8102e"],
	["Frankston", "FRA", "#5a2d82", "#f2f2f2", "#f2c230"],
	["Darwin", "NT", "#e8731c", "#16110e", "#f2f2f2"],
]
const SIZES := [24.0, 40.0, 96.0]
const ROW_H := 112.0
const LABEL_W := 110.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/markers"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var db = root.get_node("GameDB")
	var kit: GDScript = load("res://scripts/ui/UiKit.gd")
	var crest: GDScript = load("res://scripts/ui/GuernseyCrest.gd")
	var cell_w := 24.0 + 40.0 + 96.0 + 40.0
	var codes: Array = db.club_order
	var w := maxf(LABEL_W + cell_w * CLUBS.size(), 20.0 + 46.0 * codes.size())
	var h := 40.0 + ROW_H * DESIGNS.size() + 150.0
	root.size = Vector2i(int(w), int(h))
	DisplayServer.window_set_size(root.size)
	var bg := ColorRect.new()
	bg.color = kit.BG
	bg.size = Vector2(root.size)
	root.add_child(bg)
	var font: Font = kit.FONT
	var labels := Control.new()
	labels.size = Vector2(root.size)
	root.add_child(labels)
	labels.draw.connect(func():
		for j in range(CLUBS.size()):
			labels.draw_string(font, Vector2(LABEL_W + j * cell_w, 24), "%s (%s)" % [CLUBS[j][0], CLUBS[j][1]],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, kit.MUTED)
		for i in range(DESIGNS.size()):
			labels.draw_string(font, Vector2(10, 40 + i * ROW_H + 56), DESIGNS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, kit.TEXT)
		labels.draw_string(font, Vector2(10, 40 + DESIGNS.size() * ROW_H + 20), "The clubs, at 24 and 40 px",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, kit.TEXT))
	for i in range(DESIGNS.size()):
		for j in range(CLUBS.size()):
			var c: Array = CLUBS[j]
			var x := LABEL_W + j * cell_w
			for sz in SIZES:
				var m: Control = crest.make(Color(c[2]), Color(c[3]), Color(c[4]), DESIGNS[i], c[1], sz)
				m.position = Vector2(x, 40 + i * ROW_H + (96.0 - sz) / 2.0)
				m.size = Vector2(sz, sz)
				root.add_child(m)
				x += sz + 12.0
	var y := 40 + DESIGNS.size() * ROW_H + 34
	for k in range(codes.size()):
		for sz in [24.0, 40.0]:
			var m: Control = kit.club_marker(str(codes[k]), sz)
			m.position = Vector2(10 + k * 46, y + (0.0 if sz == 24.0 else 34.0))
			m.size = Vector2(sz, sz)
			root.add_child(m)
	for i in range(6):
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + ".png")
	print("wrote ", out, ".png")
	quit(0)
