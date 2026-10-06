extends SceneTree
## Review sheet for the kit options: long sleeves (a player's own) and sock hoops (a
## kit's), on the same figures through the game's own draw - each row plain then with
## the option, from the front, side-on running and from behind; close up, and at a
## phone's size underneath.
##   godot --path . --script tools/visual/capture_kit_options.gd -- --out /tmp/kit_options
## Writes <out>.png. Needs a real renderer and a window (keep it off screen with an
## override.cfg).

## [label, club, long sleeves, sock hoops]
const ROWS := [["Collingwood", "COL", false, 0], ["Collingwood, long sleeves", "COL", true, 0],
		["Carlton", "CAR", false, 0], ["Carlton, two hoops", "CAR", false, 2],
		["Brisbane, long sleeves, three hoops", "BRL", true, 3]]
const POSES := [["idle", "front", 0], ["jog", "side_l", 2], ["jog", "back", 4]]
const ROW := 230.0
const CELL := 120.0
const LEFT := 230.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/kit_options"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var db = root.get_node("GameDB")
	var SV: GDScript = load("res://scripts/ui/match/StoppageVignette.gd")
	var w := int(LEFT + CELL * POSES.size() + 20)
	var h := int(ROW * ROWS.size() + 20)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor = 1.0
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var bg := ColorRect.new()
	bg.color = Color(0.29, 0.44, 0.25)
	bg.size = Vector2(w, h)
	root.add_child(bg)
	var kits := []
	for r in ROWS:
		var k: Dictionary = (db.club_guernsey(str(r[1])) as Dictionary).duplicate()
		k["sock_hoops"] = int(r[3])
		kits.append(k)
	# Four kits a material: one canvas item per row keeps every row's kit.
	var rows := []
	for r in range(ROWS.size()):
		var ci := Control.new()
		ci.size = Vector2(w, h)
		ci.material = SV.figure_material([kits[r]])
		var row: int = r
		ci.draw.connect(func():
			var y := 10.0 + row * ROW
			for mode in ["close", "phone"]:
				if mode == "phone":
					ci.draw_rect(Rect2(0, y + 150.0, w, 125.0), Color(0.29, 0.44, 0.25))
				var x := LEFT
				for pose in POSES:
					var info := VignetteFigures.strip("average", pose[0], pose[1])
					var look := {"skin": 1, "hair": 2, "hair_style": "short_crop", "long_sleeves": bool(ROWS[row][2])}
					var col: Color = SV.look_colour(0, look)
					var feet := Vector2(x + CELL * 0.5, y + 222.0) if mode == "phone" else Vector2(x + CELL * 0.5, y + 246.0)
					SV.draw_frame(ci, feet, info, int(pose[2]), 0.32 if mode == "phone" else 1.2, col, false,
							Color(0, 0, 0, 0), Transform2D.IDENTITY, "short_crop")
					x += CELL
			ci.draw_string(ThemeDB.fallback_font, Vector2(8, y + 24), str(ROWS[row][0]), HORIZONTAL_ALIGNMENT_LEFT,
					LEFT - 12, 14, Color.WHITE)
		)
		rows.append(ci)
	# Top row first: each row's backdrop for its phone-size figures covers the legs of its
	# close-ups, and the row below draws over what's left.
	for ci in rows:
		root.add_child(ci)
	for i in range(4):
		for ci in rows:
			ci.queue_redraw()
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out + ".png")
	print("wrote ", out + ".png")
	quit()
