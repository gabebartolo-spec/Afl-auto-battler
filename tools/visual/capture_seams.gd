extends SceneTree
## Seam review for the vignette figures: the neckline and shoulders of every club's
## guernsey (and any design no club wears) through the real figure shader, close up.
## Rows are kits, each in a different skin tone and hair; columns are poses where the
## collar and armholes are hardest (standing, arms overhead), front and back.
##   godot --path . --script tools/visual/capture_seams.gd -- --out /tmp/seams [--zoom 3]
## --zoom is screen pixels per sheet pixel: about 3 on a phone's centre close-up, 1.5
## for a man further off. Renders in a SubViewport, so the sheet can be any size.
## Writes <out>_z<zoom>.png.

const POSES := [["idle", "front", 0], ["idle", "back", 0], ["leap", "front", 4], ["leap", "back", 4]]
const BODY := "average"
const LABEL_W := 120

var zoom := 3.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/seams"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		elif str(a[i]) == "--zoom":
			zoom = float(a[i + 1])
	await process_frame
	var db = root.get_node("GameDB")
	var vignette: GDScript = load("res://scripts/ui/match/StoppageVignette.gd")
	var layout: GDScript = load("res://scripts/ui/match/VignetteFigures.gd")
	var appearance: GDScript = load("res://scripts/core/Appearance.gd")
	# Every club, then one kit per design nobody wears (orange on charcoal, as a check
	# of a light pattern on a dark base).
	var rows := []
	var worn := {}
	var codes: Array = db.clubs.keys()
	codes.sort()
	for code in codes:
		var kit: Dictionary = db.club_guernsey(str(code))
		rows.append({"label": "%s %s" % [code, kit["design"]], "kit": kit})
		worn[kit["design"]] = true
	for d in db.GUERNSEY_DESIGNS:
		if not worn.has(d):
			rows.append({"label": "-- %s" % d, "kit": {"design": d, "base": Color("#33363b"),
					"pattern": Color("#f47a1f"), "pattern2": Color("#f2f2f2"), "shorts": Color("#33363b")}})
	var height_px: float = float(layout.BODIES[BODY]["height_m"]) * layout.PX_PER_M
	# From the crown to the waist: the collar, shoulders and armholes.
	var crop_top := 1.0 * height_px
	var crop_h := 0.55 * height_px
	var cell := Vector2(0, crop_h * zoom)
	for p in POSES:
		cell.x = maxf(cell.x, layout.frame_size(layout.strip(BODY, p[0], p[1])).x * zoom)
	cell += Vector2(8, 8)
	var size := Vector2i(int(LABEL_W + cell.x * POSES.size()), int(cell.y * rows.size()))
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.17, 0.41, 0.18)
	bg.size = Vector2(size)
	vp.add_child(bg)
	var font: Font = ThemeDB.fallback_font
	var labels := Control.new()
	labels.size = Vector2(size)
	vp.add_child(labels)
	labels.draw.connect(func():
		for r in range(rows.size()):
			labels.draw_rect(Rect2(0, r * cell.y, LABEL_W - 4, cell.y - 8), Color(0.07, 0.07, 0.08))
			labels.draw_string(font, Vector2(6, r * cell.y + 20), rows[r]["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			labels.draw_string(font, Vector2(6, r * cell.y + 40), "skin %d" % (r % appearance.SKIN.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8)))
	for r in range(rows.size()):
		var look := {"skin": r % appearance.SKIN.size(), "hair": (r * 3) % appearance.HAIR.size()}
		for c in range(POSES.size()):
			var p: Array = POSES[c]
			var clip := Control.new()
			clip.clip_contents = true
			clip.position = Vector2(LABEL_W + c * cell.x, r * cell.y)
			clip.size = cell - Vector2(8, 8)
			vp.add_child(clip)
			var fig := Control.new()
			fig.size = clip.size
			fig.material = vignette.figure_material([rows[r]["kit"]])
			clip.add_child(fig)
			var info: Dictionary = layout.strip(BODY, p[0], p[1])
			var f: int = mini(int(p[2]), int(info["frames"]) - 1)
			# Feet placed so the crop runs from the crown down to the waist.
			var feet := Vector2(clip.size.x * 0.5, crop_top * zoom)
			var num: Color = vignette.number_colour(0, 35) if p[1] == "back" else Color(0, 0, 0, 0)
			var colour: Color = vignette.look_colour(0, look)
			fig.draw.connect(func():
				vignette.draw_frame(fig, feet, info, f, zoom, colour, false, num, Transform2D.IDENTITY, layout.HAIR_BASE))
	for i in range(8):
		await process_frame
	var path := "%s_z%s.png" % [out, str(zoom).replace(".", "_")]
	vp.get_texture().get_image().save_png(path)
	print("wrote ", path, " ", size)
	quit(0)
