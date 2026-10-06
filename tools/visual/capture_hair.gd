extends SceneTree
## Review sheet for the hair overlays (VignetteFigures.HAIR_*): every style with
## art, plus buzz (the bald base's stubble), on a figure through the game's own
## draw (StoppageVignette.draw_frame and figure.gdshader), in three looks, from
## the front, side-on running and from behind - close up and at phone size.
##   godot --path . --script tools/visual/capture_hair.gd -- --out /tmp/hair
## Writes <out>.png. Needs a real renderer and a window (keep it off screen with
## an override.cfg).

const STYLES := ["short_crop", "swept_back", "textured_short", "dreadlocks", "bald", "buzz"]
## [skin, hair]: light skin / brown, deep skin / black, light skin / blond.
const LOOKS := [[1, 2], [4, 0], [0, 4]]
const POSES := [["idle", "front", 0], ["jog", "side_l", 2], ["jog", "back", 4], ["idle", "back", 0]]
const ROW := 230.0
const CELL := 98.0
const LEFT := 120.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/hair"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var SV: GDScript = load("res://scripts/ui/match/StoppageVignette.gd")
	var w := int(LEFT + CELL * POSES.size() * LOOKS.size() + 20)
	var h := int(ROW * STYLES.size() + 20)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED      # one sheet pixel per pixel
	root.content_scale_factor = 1.0
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var bg := ColorRect.new()
	bg.color = Color(0.29, 0.44, 0.25)
	bg.size = Vector2(w, h)
	root.add_child(bg)
	var c := Control.new()
	c.size = Vector2(w, h)
	var kit := {"design": "plain", "base": Color(0.1, 0.1, 0.12), "pattern": Color(1, 1, 1),
			"pattern2": Color(1, 1, 1), "shorts": Color(1, 1, 1)}
	c.material = SV.figure_material([kit])
	c.draw.connect(func():
		var font := ThemeDB.fallback_font
		for r in STYLES.size():
			var y := 10.0 + r * ROW
			c.draw_string(font, Vector2(8, y + 24), STYLES[r], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
			# Close up: the head and shoulders, 1.5 x the sheet (the body below is covered).
			for mode in ["close", "phone"]:
				if mode == "phone":
					c.draw_rect(Rect2(0, y + 150.0, w, ROW), Color(0.29, 0.44, 0.25))
					c.draw_string(font, Vector2(8, y + 24), STYLES[r], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
				var x := LEFT
				for look in LOOKS:
					for pose in POSES:
						var info := VignetteFigures.strip("average", pose[0], pose[1])
						var col: Color = SV.look_colour(0, {"skin": look[0], "hair": look[1]})
						# Phone size: the whole figure about 60 px tall.
						var feet := Vector2(x + CELL * 0.5, y + 222.0) if mode == "phone" else Vector2(x + CELL * 0.5, y + 300.0)
						SV.draw_frame(c, feet, info, int(pose[2]), 0.32 if mode == "phone" else 1.5, col, false,
								Color(0, 0, 0, 0), Transform2D.IDENTITY, STYLES[r])
						x += CELL
	)
	root.add_child(c)
	for i in range(4):
		c.queue_redraw()
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out + ".png")
	print("wrote ", out + ".png")
	quit()
