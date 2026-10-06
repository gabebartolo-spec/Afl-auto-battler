extends SceneTree
## Hair prototype review (the director's hair research, 2026-10-06): a prototype
## mini sheet from ard-asset-pipeline, drawn through the game's own figure
## shader at the size the game draws figures, beside today's look. What
## Blender shows is not what a phone shows; this is the phone's half.
##   godot --path . --rendering-driver opengl3 --script tools/visual/capture_hair_review.gd \
##       -- --proto ../ard-asset-pipeline/out/hair_proto/fritsch --out /tmp/hair_fritsch [--club MEL]
## --proto holds figures_shade.png, figures_mask.png, figures_design.png and the
## VignetteFigures.gd that combine_sheets.py wrote with them (body "average").
## Writes <out>.png:
##   1. game scale: each hair colour on a skin tone that contrasts with it,
##      prototype above today's look;
##   2. every facing the prototype has, at game scale;
##   3. the same facings head and shoulders at CLOSE (a broadcast close-up and
##      then some);
##   4. the moving strip, frame by frame at game scale;
## and <out>_frames/NN.png, the moving strip at 2x one frame a file, for a GIF.

const BG := Color(0.17, 0.41, 0.18)          # vignette grass
const INK := Color(0.95, 0.95, 0.92)
const CLOSE := 2.5
const FACINGS := ["front", "front_r", "side_l", "back_r", "back"]
## The still for a facing: the first of these the body has from that side.
const STILLS := ["idle", "ready", "jog", "walk"]
## The moving strip: the first of these with more than one frame.
const MOVING := [["jog", "side_l"], ["jog", "back_r"], ["walk", "front_r"]]
## Skin tone for each hair colour (Appearance.HAIR_KEYS order): light hair on
## dark skin and dark on light, as well as the usual pairings.
const SKIN_FOR := [0, 5, 1, 4, 2, 3]
const W := 1500


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/hair_review"
	var proto_dir := ""
	var club := "MEL"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--proto": proto_dir = str(a[i + 1])
			"--club": club = str(a[i + 1])
	if proto_dir == "":
		push_error("hair review: --proto <dir> is required")
		quit(1)
		return
	await process_frame
	var proto := _load_proto(proto_dir)
	if proto.is_empty():
		quit(1)
		return
	var db = root.get_node("GameDB")
	var appearance: GDScript = load("res://scripts/core/Appearance.gd")
	var vignette: GDScript = load("res://scripts/ui/match/StoppageVignette.gd")
	var game_layout: GDScript = load("res://scripts/ui/match/VignetteFigures.gd")
	var kit: Dictionary = db.club_guernsey(club)
	var sides := {
		"proto": {"tex": proto["shade"], "layout": proto["layout"],
				"mat": _proto_material(vignette.figure_material([kit]), proto)},
		"today": {"tex": vignette.FIGURE_SHADE, "layout": game_layout, "mat": vignette.figure_material([kit])},
	}
	var shots := []          # [side, strip, frame, at, scale, crop, skin, hair, label]
	var labels := []         # [at, text, size]
	var y := 8.0
	labels.append([Vector2(10, y + 14), "Hair prototype: %s  (%s guernsey)" % [proto_dir.get_file(), club], 16])
	y += 30.0
	# 1. Game scale, every hair colour.
	var still := _still(proto["layout"], "front_r")
	if still.is_empty():
		still = _still(proto["layout"], "front")
	var hairs: int = appearance.HAIR.size()
	for row in [["proto", "prototype"], ["today", "today"]]:
		labels.append([Vector2(10, y + 14), "Game scale, %s: each hair colour (%s)" % [row[1], ", ".join(appearance.HAIR_KEYS)], 13])
		y += 20.0
		var s := still if row[0] == "proto" else _still(game_layout, str(still.get("facing", "front")))
		var h := _frame_h(s)
		for k in range(hairs):
			shots.append([row[0], s, 0, Vector2(20 + k * 120, y), 1.0, false, SKIN_FOR[k % SKIN_FOR.size()], k])
		y += h + 10.0
	# 2 and 3. Every facing, at game scale and close.
	var facings := FACINGS.filter(func(f): return not _still(proto["layout"], f).is_empty())
	for scale in [1.0, CLOSE]:
		for row in [["proto", "prototype"], ["today", "today"]]:
			labels.append([Vector2(10, y + 14), "%s, %s: %s" % ["Game scale" if scale == 1.0 else "Close (%.1fx)" % CLOSE,
					row[1], ", ".join(facings)], 13])
			y += 20.0
			var tallest := 0.0
			var x := 20.0
			for f in facings:
				var s := _still(sides[row[0]]["layout"], f)
				if s.is_empty():
					x += 140.0 * scale
					continue
				var crop: bool = scale > 1.0
				shots.append([row[0], s, 0, Vector2(x, y), scale, crop, 1, 0])
				var r := _src(s, 0, crop)
				x += r.size.x * scale + 14.0
				tallest = maxf(tallest, r.size.y * scale)
			y += tallest + 10.0
	# 4. The moving strip.
	var moving := _moving(proto["layout"])
	var strip_y := y
	if not moving.is_empty():
		labels.append([Vector2(10, y + 14), "Moving, prototype: %s %s, %d frames (dark hair, then blond)" % [
				moving["anim"], moving["facing"], int(moving["frames"])], 13])
		y += 20.0
		strip_y = y
		for pass_i in range(2):
			for i in range(int(moving["frames"])):
				shots.append(["proto", moving, i, Vector2(20 + i * (moving["size"][0] + 6), y), 1.0, false,
						1 if pass_i == 0 else 4, 0 if pass_i == 0 else 4])
			y += _frame_h(moving) + 8.0
	var height := int(y + 10.0)
	root.size = Vector2i(W, height)
	DisplayServer.window_set_size(root.size)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(root.size)
	root.add_child(bg)
	for side in sides:
		var c := Control.new()
		c.size = Vector2(root.size)
		c.material = sides[side]["mat"]
		root.add_child(c)
		var mine := shots.filter(func(s): return s[0] == side)
		var tex: Texture2D = sides[side]["tex"]
		c.draw.connect(func():
			for s in mine:
				var src := _src(s[1], int(s[2]), bool(s[5]))
				c.draw_texture_rect_region(tex, Rect2(s[3], src.size * float(s[4])), src,
						Color(0.0, int(s[6]) / 8.0, int(s[7]) / 8.0, 1.0)))
		c.queue_redraw()
	var text := Control.new()
	text.size = Vector2(root.size)
	root.add_child(text)
	var font: Font = ThemeDB.fallback_font
	text.draw.connect(func():
		for l in labels:
			text.draw_string(font, l[0], str(l[1]), HORIZONTAL_ALIGNMENT_LEFT, W - 20, int(l[2]), INK))
	text.queue_redraw()
	for i in range(6):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out + ".png")
	print("wrote ", out + ".png")
	if not moving.is_empty():
		DirAccess.make_dir_recursive_absolute(out + "_frames")
		var fw := int(moving["size"][0])
		var fh := int(_frame_h(moving))
		for i in range(int(moving["frames"])):
			var f := img.get_region(Rect2i(20 + i * (fw + 6), int(strip_y), fw, fh))
			f.resize(fw * 2, fh * 2, Image.INTERPOLATE_NEAREST)
			f.save_png("%s_frames/%02d.png" % [out, i])
		print("wrote ", out + "_frames/")
	quit(0)


## The prototype's three sheets and its layout script, loaded from outside the
## project. {} (with an error) if anything is missing.
func _load_proto(dir: String) -> Dictionary:
	var out := {}
	for k in ["shade", "mask", "design"]:
		var img := Image.load_from_file(dir.path_join("figures_%s.png" % k))
		if img == null or img.is_empty():
			push_error("hair review: no figures_%s.png in %s" % [k, dir])
			return {}
		out[k] = ImageTexture.create_from_image(img)
	var path := dir.path_join("VignetteFigures.gd")
	if not FileAccess.file_exists(path):
		push_error("hair review: no VignetteFigures.gd in %s" % dir)
		return {}
	# The generated layout names itself VignetteFigures, as the game's does: load
	# it without the class name so the two don't clash.
	var src := FileAccess.get_file_as_string(path)
	var kept := PackedStringArray()
	for l in src.split("\n"):
		if not l.strip_edges().begins_with("class_name"):
			kept.append(l)
	var script := GDScript.new()
	script.source_code = "\n".join(kept)
	if script.reload() != OK:
		push_error("hair review: %s does not compile" % path)
		return {}
	var consts := script.get_script_constant_map()
	if not consts.has("BODIES") or not (consts["BODIES"] as Dictionary).has("average"):
		push_error("hair review: %s has no average body" % path)
		return {}
	out["layout"] = script
	out["sheet_size"] = consts["SHEET_SIZE"]
	return out


## The game's figure material, pointed at the prototype's sheets. The shader
## knows a figure draw by its texture size, so sheet_size must be the
## prototype's.
func _proto_material(mat: ShaderMaterial, proto: Dictionary) -> ShaderMaterial:
	var m := mat.duplicate() as ShaderMaterial
	m.set_shader_parameter("mask_tex", proto["mask"])
	m.set_shader_parameter("design_tex", proto["design"])
	m.set_shader_parameter("sheet_size", proto["sheet_size"])
	return m


## The still for a facing (see STILLS), with "facing" and "height" added; {} if
## the body has none from that side.
func _still(layout: Script, facing: String) -> Dictionary:
	var bodies: Dictionary = layout.get_script_constant_map()["BODIES"]
	var anims: Dictionary = bodies["average"]["anims"]
	for anim in STILLS:
		if anims.has(anim) and (anims[anim] as Dictionary).has(facing):
			var s: Dictionary = (anims[anim][facing] as Dictionary).duplicate()
			s["facing"] = facing
			s["anim"] = anim
			s["height"] = float(bodies["average"]["height_m"])
			s["ppm"] = float(layout.get_script_constant_map()["PX_PER_M"])
			return s
	return {}


func _moving(layout: Script) -> Dictionary:
	var bodies: Dictionary = layout.get_script_constant_map()["BODIES"]
	var anims: Dictionary = bodies["average"]["anims"]
	for m in MOVING:
		if anims.has(m[0]) and (anims[m[0]] as Dictionary).has(m[1]) and int(anims[m[0]][m[1]]["frames"]) > 1:
			var s: Dictionary = (anims[m[0]][m[1]] as Dictionary).duplicate()
			s["facing"] = m[1]
			s["anim"] = m[0]
			s["height"] = float(bodies["average"]["height_m"])
			s["ppm"] = float(layout.get_script_constant_map()["PX_PER_M"])
			return s
	return {}


func _frame_h(s: Dictionary) -> float:
	return float(s["size"][1]) if not s.is_empty() else 0.0


## Frame i of a strip in its sheet; `crop`: only the head and shoulders (from a
## little above his height to 55 cm below it).
func _src(s: Dictionary, i: int, crop: bool) -> Rect2:
	var f := clampi(i, 0, int(s["frames"]) - 1)
	var w := float(s["size"][0])
	var h := float(s["size"][1])
	var r := Rect2(float(s["x"]) + f * w, float(s["y"]), w, h)
	if not crop:
		return r
	var ppm := float(s.get("ppm", 100.0))
	var top := float(s["pivot"][1]) - (float(s.get("height", 1.88)) + 0.08) * ppm
	var bottom := float(s["pivot"][1]) - (float(s.get("height", 1.88)) - 0.55) * ppm
	top = clampf(top, 0.0, h)
	bottom = clampf(bottom, top + 1.0, h)
	return Rect2(r.position.x, r.position.y + top, w, bottom - top)
