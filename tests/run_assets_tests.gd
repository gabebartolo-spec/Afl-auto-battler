extends SceneTree
## godot --headless --path . --script tests/run_assets_tests.gd
## The art and music the game ships, checked as files and as the game uses
## them. These checks can say an asset is whole and wired up; only a person
## can say it looks or sounds right.
##   - Figure sheets: every frame of every move in VignetteFigures.gd has a
##     figure on the sheet, and the colour masks belong to the same render as
##     the shading (a sheet rebuilt without the others shows up here).
##   - Vignettes in motion: each scene plays its moves through - no frame
##     asked for past the end of a move (it would freeze without a word).
##   - Music: every track loads and is in the playlist, nothing clips, the
##     tracks sit at one level, and the player pauses for a match, resumes,
##     moves on and honours Mute.
##   - Honours (the Trophy room's art): honours.json lists all nine, each file
##     whole at its size, base_y on the art's foot, masks and the year box sound.

const SHEETS := "res://assets/vignette/figures_%s.png"
const MUSIC_DIR := "res://assets/audio/music"
## A frame with less figure than this share of its rect is empty (strips are cropped
## to their figures, so a real frame fills far more).
const MIN_COVER := 0.01
## Same render (the art agent's rule, 2026-10-06): every guernsey-mask pixel
## (mask A >= 0.05) lies on the figure (shade A > 0.05) or within 1 px of it.
## Blender's straight alpha leaves full-strength mask on edge pixels whose
## coverage rounds to nothing - padding the shader never draws - but nothing
## further out. Backstop: at most this share of a frame's mask off the figure
## (thin side-on frames run to 7% of edge padding; a mask 16 px out is 15%+).
const MASK_ON := 0.05
const BODY_ON := 0.05
const MASK_SPILL := 0.10
const PEAK_LIMIT_DB := -1.0
const LEVEL_SPREAD_DB := 3.0
const MAX_LEAD_SILENCE := 0.5

## Loaded at run time: the vignettes need the autoloads, which a script
## compiled before they exist can't name.
var SV: GDScript
var _state: Node
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	_state.show_real_names = false
	_state.replay_seed = 2027
	SV = load("res://scripts/ui/match/StoppageVignette.gd")
	_figure_sheets()
	_figure_contacts()
	_figure_markers()
	_hair_atlases()
	_ball()
	_honours()
	await _vignettes_play_through()
	_music_files()
	_music_player()
	_banners()
	print("Assets tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(1 if not _failures.is_empty() else 0)


# ---------------------------------------------------------------------------
# Figure sheets
# ---------------------------------------------------------------------------
func _figure_sheets() -> void:
	var shade := _source_image("shade")
	var mask := _source_image("mask")
	var design := _source_image("design")
	_check(shade != null and mask != null and design != null and _source_image("digits") != null,
			"The four figure sheets are in the project")
	if shade == null or mask == null or design == null:
		return
	_check(shade.get_size() == VignetteFigures.SHEET_SIZE and mask.get_size() == VignetteFigures.SHEET_SIZE
			and design.get_size() == VignetteFigures.SHEET_SIZE / VignetteFigures.DESIGN_SCALE,
			"The sheets are the size the layout says (%s, %s, %s)" % [shade.get_size(), mask.get_size(), design.get_size()])
	var rects := []          # [rect, "anim facing"] for every frame
	var empty := []
	var clash := []
	var outside := []
	var spill := []
	var strips := 0
	for body in VignetteFigures.BODIES:
		var anims: Dictionary = VignetteFigures.BODIES[body]["anims"]
		for anim in anims:
			for facing in anims[anim]:
				strips += 1
				var s := VignetteFigures.strip(body, anim, facing)
				for i in int(s["frames"]):
					var r := Rect2i(VignetteFigures.source(s, i))
					var where := "%s %s %s #%d" % [body, anim, facing, i]
					if not Rect2i(Vector2i.ZERO, VignetteFigures.SHEET_SIZE).encloses(r):
						outside.append(where)
						continue
					for other in rects:
						if (other[0] as Rect2i).intersects(r):
							clash.append("%s / %s" % [where, other[1]])
					rects.append([r, where])
					var c := _coverage(shade, mask, r)
					if c[0] < MIN_COVER:
						empty.append(where)
					elif int(c[2]) > 0 or float(c[1]) > MASK_SPILL:
						spill.append("%s: %d px beyond the edge, %.1f%% off" % [where, int(c[2]), float(c[1]) * 100.0])
	_check(strips > 0, "The layout lists the moves (%d strips)" % strips)
	_check(outside.is_empty(), "Every frame sits inside the sheet: %s" % str(outside.slice(0, 5)))
	_check(clash.is_empty(), "No two frames overlap on the sheet: %s" % str(clash.slice(0, 5)))
	_check(empty.is_empty(), "Every frame of every move has a figure in it (%d empty: %s)"
			% [empty.size(), str(empty.slice(0, 5))])
	_check(spill.is_empty(), "The colour mask lies on the figure, to the pixel, in every frame (same render): %s"
			% str(spill.slice(0, 5)))
	# The club-design sheet (half or full size, DESIGN_SCALE) must sit on the figure too: its
	# alpha (the long-sleeve cover, the arms and shoulders) lies on the body.
	var off := 0
	var on := 0
	for e in rects:
		var r: Rect2i = e[0]
		for y in range(r.position.y, r.end.y, 4):
			for x in range(r.position.x, r.end.x, 4):
				if design.get_pixel(x / VignetteFigures.DESIGN_SCALE, y / VignetteFigures.DESIGN_SCALE).a > 0.5:
					on += 1
					if shade.get_pixel(x, y).a < 0.05:
						off += 1
	_check(on > 0 and float(off) / on < 0.02,
			"The club-design sheet matches the figures (%d of %d samples off the body)" % [off, on])
	# The tool itself: a blank frame and a mask from another frame must fail.
	var blank := Image.create(VignetteFigures.SHEET_SIZE.x, VignetteFigures.SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	var any_cell: Rect2i = rects[0][0]
	_check(_coverage(blank, mask, any_cell)[0] < MIN_COVER, "A blank frame counts as empty")
	var step := 16 if any_cell.end.x + 16 <= VignetteFigures.SHEET_SIZE.x else -16
	var shifted := Rect2i(any_cell.position + Vector2i(step, 0), any_cell.size)
	var moved := Image.create(VignetteFigures.SHEET_SIZE.x, VignetteFigures.SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	moved.blit_rect(mask, shifted, any_cell.position)
	_check(int(_coverage(shade, moved, any_cell)[2]) > 0, "A mask 16 px out of register counts as a mismatch")


## [share of the cell with figure, share of the mask off the figure, mask
## samples more than 1 px from the figure] (every second pixel each way; the
## 1 px test looks at the 3x3 around each sample).
## Where each strip's shadow centres (VignetteFigures.contact): the middle of the boots'
## contact with the turf, not the pivot under the ankles, so a figure's boots sit on his
## shadow (the floating-feet fix). Moves he makes carried or seated keep the pivot.
const CARRIED := ["chaired", "coach_sit", "coach_seated"]


func _figure_contacts() -> void:
	var missing := []
	var odd := []
	for body in VignetteFigures.BODIES:
		for anim in VignetteFigures.BODIES[body]["anims"]:
			for facing in VignetteFigures.BODIES[body]["anims"][anim]:
				var s: Dictionary = VignetteFigures.strip(body, anim, facing)
				var where := "%s %s %s" % [body, anim, facing]
				if not s.has("contact"):
					missing.append(where)
					continue
				var off := VignetteFigures.contact(s)
				if CARRIED.has(anim.trim_suffix("_near")) and off != Vector2.ZERO:
					odd.append("%s off its pivot" % where)
				elif off.length() > 0.4 * VignetteFigures.PX_PER_M:
					odd.append("%s %.0f px from its pivot" % [where, off.length()])
	_check(missing.is_empty(), "Every strip says where its boots meet the turf: %s" % str(missing.slice(0, 5)))
	_check(odd.is_empty(), "Contacts sit within 40 cm of the pivot, carried and seated moves on it: %s" % str(odd.slice(0, 5)))
	# Standing ready, his boots reach forward of his ankles: from behind they are further
	# from the camera (higher on screen) than the pivot, from the front nearer (lower).
	var back := VignetteFigures.contact(VignetteFigures.strip("average", "ready", "back"))
	var front := VignetteFigures.contact(VignetteFigures.strip("average", "ready", "front"))
	_check(back.y < -4.0 and front.y > 4.0 and absf(back.x) < 1.0,
			"The ready stance's shadow centres on his boots, ahead of his ankles (back %s, front %s)" % [back, front])


## The frames where something happens in a strip (VignetteFigures.marker): measured from the rig
## (motion phase A), so a scene can wait for the boot to meet the ball instead of guessing a frame.
func _figure_markers() -> void:
	var outside := []
	var count := 0
	for body in VignetteFigures.BODIES:
		for anim in VignetteFigures.BODIES[body]["anims"]:
			for facing in VignetteFigures.BODIES[body]["anims"][anim]:
				var s: Dictionary = VignetteFigures.strip(body, anim, facing)
				for name in s.get("markers", {}):
					count += 1
					var f := VignetteFigures.marker(s, name)
					if f < 0 or f >= int(s["frames"]):
						outside.append("%s %s %s %s=%d" % [body, anim, facing, name, f])
	_check(count > 0 and outside.is_empty(), "Every marker (%d) is a frame of its strip: %s" % [count, str(outside.slice(0, 5))])
	var kick := VignetteFigures.strip("average", "kick", "back_r")
	var gather := VignetteFigures.strip("average", "gather", "back_r")
	_check(VignetteFigures.marker(kick, "ball_contact") == 4 and VignetteFigures.marker(kick, "ball_release") == 2
			and int(kick["frames"]) == 7
			and VignetteFigures.marker(gather, "gather_contact") == 1 and VignetteFigures.marker(kick, "none") == -1,
			"The seven-frame drop punt lets the ball go on frame 2 and meets it on 4; the crumb gathers on 1")


func _coverage(shade: Image, mask: Image, r: Rect2i) -> Array:
	var cover := 0
	var masked := 0
	var off := 0
	var far := 0
	var n := 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			n += 1
			var body := shade.get_pixel(x, y).a > BODY_ON
			if body:
				cover += 1
			# A is the guernsey alone (R/G/B are padded past the edges).
			if mask.get_pixel(x, y).a >= MASK_ON:
				masked += 1
				if not body:
					off += 1
					if not _body_near(shade, x, y, r):
						far += 1
	return [float(cover) / maxi(1, n), float(off) / maxi(1, masked), far]


func _body_near(shade: Image, x: int, y: int, r: Rect2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var p := Vector2i(x + dx, y + dy)
			if r.has_point(p) and shade.get_pixelv(p).a > BODY_ON:
				return true
	return false


# ---------------------------------------------------------------------------
# Hair overlays: the bald figures' hair, one atlas per style (VignetteFigures)
# ---------------------------------------------------------------------------
func _hair_atlases() -> void:
	var files: Array = VignetteFigures.HAIR_FILES
	var index: Dictionary = VignetteFigures.HAIR_STYLE_INDEX
	_check(files.size() > 0 and files.size() == index.size() and files.size() == VignetteFigures.HAIR_TEXTURES.size()
			and index.has(VignetteFigures.HAIR_BASE),
			"The hair overlays list their atlases, with the base look (%s)" % str(index.keys()))
	var bad_ids := index.keys().filter(func(id): return not Appearance.HAIR_STYLES.has(id))
	var odd := (VignetteFigures.HAIR_NONE + VignetteFigures.HAIR_TINT_SKIN).filter(func(id): return not Appearance.HAIR_STYLES.has(id))
	_check(bad_ids.is_empty() and odd.is_empty(), "Every hair id is a style a player can have: %s" % str(bad_ids + odd))
	# The right art loaded (director's rule, 2026-10-06): each atlas is the file it names,
	# imported VRAM compressed like the figure sheets, and the size the layout was made for.
	var images := []
	var wrong := []
	for i in files.size():
		var tex: Texture2D = VignetteFigures.HAIR_TEXTURES[i]
		var path := "res://assets/vignette/%s" % files[i]
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var cfg := ConfigFile.new()
		var vram := cfg.load(path + ".import") == OK and int(cfg.get_value("params", "compress/mode", -1)) == 2 				and not bool(cfg.get_value("params", "mipmaps/generate", true))
		if tex == null or tex.resource_path != path or img == null or Vector2i(tex.get_size()) != img.get_size() or not vram:
			wrong.append(files[i])
			img = null
		else:
			img.convert(Image.FORMAT_RGBA8)
		images.append(img)
	_check(wrong.is_empty(), "Every hair atlas is loaded from its own file, VRAM compressed, no mipmaps: %s" % str(wrong))
	# Every move of every body has the base look's hair; every cell lies in its atlas and has hair.
	var missing := []
	var outside := []
	var empty := []
	var cells := 0
	for body in VignetteFigures.BODIES:
		var anims: Dictionary = VignetteFigures.BODIES[body]["anims"]
		for anim in anims:
			for facing in anims[anim]:
				var s := VignetteFigures.strip(body, anim, facing)
				# An overlay (a near hand drawn over another figure) has no hair of its own
				# (combine_sheets.py); every other move needs the base look's.
				if not bool(s.get("overlay", false)) and VignetteFigures.hair_for(s, VignetteFigures.HAIR_BASE).is_empty():
					missing.append("%s %s %s" % [body, anim, facing])
				for id in (s.get("hair", {}) as Dictionary):
					var h: Dictionary = s["hair"][id]
					var img: Image = images[int(h["atlas"])]
					if int(h["frames"]) != int(s["frames"]):
						outside.append("%s %s %s %s: frames" % [id, body, anim, facing])
					for i in int(h["frames"]):
						cells += 1
						var r := Rect2i(VignetteFigures.hair_source(h, i))
						if img == null or not Rect2i(Vector2i.ZERO, img.get_size()).encloses(r):
							outside.append("%s %s %s %s #%d" % [id, body, anim, facing, i])
							continue
						var any := false
						for y in range(r.position.y, r.end.y, 2):
							for x in range(r.position.x, r.end.x, 2):
								if img.get_pixel(x, y).a > 0.5:
									any = true
									break
							if any:
								break
						if not any:
							empty.append("%s %s %s %s #%d" % [id, body, anim, facing, i])
	_check(missing.is_empty(), "Every move of every body has the base look's hair: %s" % str(missing.slice(0, 5)))
	_check(cells > 0 and outside.is_empty(), "Every hair cell (%d) sits inside its atlas: %s" % [cells, str(outside.slice(0, 5))])
	_check(empty.is_empty(), "Every hair cell has hair in it: %s" % str(empty.slice(0, 5)))
	# Fallbacks: a style with no art draws the base look; buzz draws none (the bald base's stubble).
	var probe := VignetteFigures.strip("average", "idle", "front")
	_check(VignetteFigures.hair_for(probe, "afro") == VignetteFigures.hair_for(probe, VignetteFigures.HAIR_BASE)
			and VignetteFigures.hair_for(probe, "buzz").is_empty()
			and VignetteFigures.hair_for(probe, "dreadlocks") != VignetteFigures.hair_for(probe, VignetteFigures.HAIR_BASE),
			"A style without art draws the base look; buzz draws only the stubble; dreadlocks its own")


func _source_image(which: String) -> Image:
	var path := ProjectSettings.globalize_path(SHEETS % which)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


# ---------------------------------------------------------------------------
# The football: a Sherrin spinning end over end (VignetteBall), red by day, yellow at night
# ---------------------------------------------------------------------------
func _ball() -> void:
	var path := "res://assets/vignette/ball.png"
	var tex: Texture2D = VignetteBall.TEX
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var cfg := ConfigFile.new()
	# Lossless with mipmaps: it's drawn far smaller than its cells, and a compressed
	# ball loses its seams and laces.
	var lossless := cfg.load(path + ".import") == OK and int(cfg.get_value("params", "compress/mode", -1)) == 0 \
			and bool(cfg.get_value("params", "mipmaps/generate", false))
	var size := Vector2i(VignetteBall.FRAMES * int(VignetteBall.CELL), 2 * int(VignetteBall.CELL))
	_check(tex != null and tex.resource_path == path and img != null and img.get_size() == size and lossless,
			"The ball is loaded from its own file, lossless with mipmaps, %s (%s)" % [str(size), path])
	if img == null or img.get_size() != size:
		return
	img.convert(Image.FORMAT_RGBA8)
	# Every frame of both balls has the ball in it, the length the draw scales by, and its
	# colour: row 0 red, row 1 yellow.
	var bad := []
	var c := int(VignetteBall.CELL)
	for row in 2:
		for f in VignetteBall.FRAMES:
			var lo := c
			var hi := -1
			var sum := Color(0, 0, 0)
			var n := 0
			for y in range(row * c, row * c + c):
				for x in range(f * c, f * c + c):
					var p := img.get_pixel(x, y)
					if p.a > 0.5:
						lo = mini(lo, x - f * c)
						hi = maxi(hi, x - f * c)
						sum += p
						n += 1
			var colour_ok := n > 0 and (sum.g < 0.5 * sum.r if row == 0 else sum.g > 0.7 * sum.r)
			if n < 200 or hi - lo + 1 > c or not colour_ok:
				bad.append("%s %d" % [["red", "yellow"][row], f])
	_check(bad.is_empty(), "Every frame of the red and the yellow ball has the ball in it, in its colour: %s" % str(bad))


# ---------------------------------------------------------------------------
# The Trophy room's honours (assets/honours, read through honours.json)
# ---------------------------------------------------------------------------
const HONOURS_DIR := "res://assets/honours/"
const HONOUR_IDS := ["premiership_cup", "premiership_flag", "league_bnf_medal", "leading_goalkicker_medal",
		"rising_star", "coaches_award", "club_bnf", "all_australian", "minor_premiership"]


func _honours() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(HONOURS_DIR + "honours.json"))
	var honours: Dictionary = manifest.get("honours", {}) if manifest is Dictionary else {}
	var ids := honours.keys()
	ids.sort()
	var want := HONOUR_IDS.duplicate()
	want.sort()
	_check(manifest is Dictionary and int(manifest.get("version", 0)) == 1 and ids == want,
			"honours.json lists the nine honours (%s)" % str(ids))
	var shader_file := str(manifest.get("shader", "")) if manifest is Dictionary else ""
	var shader := ResourceLoader.load(HONOURS_DIR + shader_file, "", ResourceLoader.CACHE_MODE_IGNORE) as Shader \
			if shader_file != "" else null
	var uniforms := []
	if shader != null:
		for u in shader.get_shader_uniform_list():
			uniforms.append(u["name"])
	_check(shader != null and uniforms.has("mask_tex") and uniforms.has("primary") and uniforms.has("secondary"),
			"The honours' tint shader loads, with mask_tex, primary and secondary (%s)" % str(uniforms))
	for id in HONOUR_IDS:
		if honours.has(id):
			var bad := _honour_problems(honours[id])
			_check(bad.is_empty(), "The %s art is whole and as honours.json says: %s" % [id, str(bad)])


## What's wrong with one honour's files: its own lossless, mipmapped texture at the listed size
## (drawn far smaller than it is), clear corners, base_y on the art's lowest solid row (the
## shelf line), a mask that has both colours and stays on the art, and the year box clear on
## the primary colour.
func _honour_problems(e: Dictionary) -> Array:
	var bad := []
	var path := HONOURS_DIR + str(e.get("png", ""))
	var listed: Array = e.get("size", [0, 0])
	var size := Vector2i(int(listed[0]), int(listed[1]))
	var tex := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if tex == null or img == null or img.get_size() != size or Vector2i(tex.get_size()) != size:
		return ["%s missing or not %s" % [path, str(size)]]
	if not _lossless_mipmapped(path):
		bad.append("not lossless with mipmaps")
	img.convert(Image.FORMAT_RGBA8)
	for c in [Vector2i(0, 0), Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), size - Vector2i.ONE]:
		if img.get_pixelv(c).a > 0.02:
			bad.append("corner %s not clear" % str(c))
	var lowest := -1
	for y in range(size.y - 1, -1, -1):
		for x in size.x:
			if img.get_pixel(x, y).a > 0.5:
				lowest = y
				break
		if lowest >= 0:
			break
	if e.has("base_y") and absi(int(e["base_y"]) - lowest) > 2:
		bad.append("base_y %d but the art ends at row %d" % [int(e["base_y"]), lowest])
	if not e.has("mask"):
		return bad
	var mpath := HONOURS_DIR + str(e["mask"])
	var mask := Image.load_from_file(ProjectSettings.globalize_path(mpath))
	if mask == null or mask.get_size() != size or not _lossless_mipmapped(mpath):
		bad.append("%s missing, not %s or not lossless with mipmaps" % [mpath, str(size)])
		return bad
	mask.convert(Image.FORMAT_RGBA8)
	var primary := 0
	var secondary := 0
	var off := 0
	for y in range(0, size.y, 2):
		for x in range(0, size.x, 2):
			var m := mask.get_pixel(x, y)
			primary += 1 if m.r > 0.5 else 0
			secondary += 1 if m.g > 0.5 else 0
			off += 1 if (m.r > 0.5 or m.g > 0.5) and img.get_pixel(x, y).a < 0.05 else 0
	if primary < 500 or secondary < 200:
		bad.append("the mask has too little primary (%d) or secondary (%d)" % [primary, secondary])
	# Blender's straight alpha leaves mask on edge pixels whose coverage rounds to nothing.
	if off > 0.02 * (primary + secondary):
		bad.append("%d mask pixels off the art" % off)
	if e.has("year_box"):
		var b: Array = e["year_box"]
		var box := Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
		var on := 0
		var n := 0
		for y in range(box.position.y, box.end.y, 2):
			for x in range(box.position.x, box.end.x, 2):
				n += 1
				on += 1 if mask.get_pixel(x, y).r > 0.5 else 0
		if not Rect2i(Vector2i.ZERO, size).encloses(box) or box.size.x < 64 or on < 0.95 * n:
			bad.append("the year box %s is not clear on the primary colour (%d of %d)" % [str(box), on, n])
	return bad


func _lossless_mipmapped(path: String) -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(path + ".import") == OK and int(cfg.get_value("params", "compress/mode", -1)) == 0 \
			and bool(cfg.get_value("params", "mipmaps/generate", false))


# ---------------------------------------------------------------------------
# Vignettes in motion
# ---------------------------------------------------------------------------
func _vignettes_play_through() -> void:
	root.size = Vector2i(390, 844)
	SV.log_frames = true
	# The tool itself: a frame past the end of a move is caught.
	SV.frame_log.clear()
	var probe := VignetteFigures.strip("average", "idle", "front")
	var held: int = SV.figure_frame(probe, int(probe["frames"]) + 3, "idle", "front")
	_check(held == int(probe["frames"]) - 1 and _overruns().size() == 1,
			"A frame past the end of a move is held on the last and noticed")
	var db = root.get_node("GameDB")
	var star: Dictionary = db.club_list("COL")[0]
	for kind in ["speccy_front", "speccy_side", "speccy_defensive", "after_siren", "goal_line", "boundary_snap"]:
		var ev := {"kind": "mark" if kind.begins_with("speccy") else "goal", "side": 0,
				"num": int(star.get("num", 7)), "player_id": str(star["id"]), "club": "COL", "q": 4,
				"set_shot": kind == "after_siren", "crumb": kind == "goal_line"}
		var vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
		root.add_child(vig)
		vig.size = Vector2(390, 844)
		vig.setup(kind, ev, {}, {"home": "COL", "away": "CAR"})
		await _play(vig, "broadcast " + kind, 6.0)
	var press = load("res://scripts/ui/MediaConferenceVignette.gd").new()
	press.club = "COL"
	root.add_child(press)
	press.size = Vector2(390, 300)
	await _play(press, "press conference", 3.0)
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	if _state.prepare_interactive_match():
		var bounce = load("res://scripts/ui/match/StoppageVignette.gd").new()
		root.add_child(bounce)
		bounce.size = Vector2(390, 844)
		bounce.setup(_state.pending_sim, 0, "Centre bounce")
		await _play(bounce, "centre bounce", 6.0)
	else:
		_check(false, "A match is ready for the centre-bounce scene")
	SV.log_frames = false


## Run a vignette for `seconds` of its own time, drawing every step, and check
## its figures: they were drawn, no move ran past its end, and every move with
## several frames showed more than one.
func _play(vig: Control, what: String, seconds: float) -> void:
	SV.frame_log.clear()
	SV.hair_log.clear()
	vig.set_process(false)
	var t := 0.0
	while t <= seconds:
		vig.set("_t", t)
		vig.queue_redraw()
		await process_frame
		t += 1.0 / 30.0
	vig.queue_free()
	await process_frame
	var log: Array = SV.frame_log
	_check(not log.is_empty(), "The %s draws its footballers" % what)
	# Their hair is drawn from the hair atlases (the right art, not a fallback).
	var hair: Array = SV.hair_log
	var stray := hair.filter(func(e): return not VignetteFigures.HAIR_TEXTURES.has(e["texture"]))
	_check(not hair.is_empty() and stray.is_empty(),
			"The %s draws its footballers' hair from the hair atlases (%d draws)" % [what, hair.size()])
	var over := _overruns()
	_check(over.is_empty(), "The %s never asks for a frame past the end of a move: %s" % [what, str(over.slice(0, 4))])
	var seen := {}
	for e in log:
		var k := "%s %s" % [e["anim"], e["facing"]]
		if int(e["frames"]) > 1:
			if not seen.has(k):
				seen[k] = {}
			seen[k][int(e["wanted"])] = true
	var frozen := []
	for k in seen:
		if (seen[k] as Dictionary).size() < 2:
			frozen.append(k)
	_check(frozen.is_empty(), "Every move in the %s plays, none stuck on one frame: %s" % [what, str(frozen)])


func _overruns() -> Array:
	var out := []
	for e in SV.frame_log:
		if int(e["wanted"]) < 0 or int(e["wanted"]) >= int(e["frames"]):
			out.append("%s %s %d/%d" % [e["anim"], e["facing"], int(e["wanted"]), int(e["frames"])])
	return out


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------
func _music_files() -> void:
	var mm = root.get_node("MusicManager")
	var listed: Array = mm.TRACK_PATHS
	var files := []
	for f in DirAccess.get_files_at(MUSIC_DIR):
		if f.get_extension() in ["wav", "ogg", "mp3"]:
			files.append("%s/%s" % [MUSIC_DIR, f])
	var unlisted := files.filter(func(f): return not listed.has(f))
	var missing := listed.filter(func(p): return not ResourceLoader.exists(p))
	_check(missing.is_empty(), "Every track in the playlist is in the game: %s" % str(missing))
	_check(unlisted.is_empty(), "Every music file is in the playlist: %s" % str(unlisted))
	_check((mm.get("_tracks") as Array).size() == listed.size(),
			"Every track loads - none dropped without a word (%d of %d)" % [(mm.get("_tracks") as Array).size(), listed.size()])
	var levels := []
	for p in listed:
		var w := _wav_levels(p)
		if w.is_empty():
			_check(false, "%s reads as a 16-bit WAV" % p.get_file())
			continue
		levels.append(float(w["rms"]))
		_check(float(w["peak"]) <= PEAK_LIMIT_DB, "%s doesn't clip (peak %.1f dBFS)" % [p.get_file(), w["peak"]])
		_check(float(w["lead"]) <= MAX_LEAD_SILENCE, "%s starts without a gap (%.2f s)" % [p.get_file(), w["lead"]])
		_check(float(w["seconds"]) >= 20.0, "%s is a track, not a sting (%.0f s)" % [p.get_file(), w["seconds"]])
	if levels.size() > 1:
		_check(levels.max() - levels.min() <= LEVEL_SPREAD_DB,
				"The tracks sit at one level (%.1f dB apart)" % (levels.max() - levels.min()))
	# The tool itself: a clipped, late-starting tone fails.
	var bad := PackedByteArray()
	bad.resize(2 * 11025)
	for i in range(11025):
		var v := 0 if i < 8000 else (32767 if i % 2 == 0 else -32768)
		bad.encode_s16(i * 2, v)
	var bw := _levels_of(bad, 11025, 1)
	_check(float(bw["peak"]) > PEAK_LIMIT_DB and float(bw["lead"]) > MAX_LEAD_SILENCE,
			"A clipped track with a gap at the start is caught")


## Peak and RMS (dBFS), leading silence and length of a 16-bit PCM WAV, read
## from the source file (what the importer was given).
func _wav_levels(res_path: String) -> Dictionary:
	var f := FileAccess.open(ProjectSettings.globalize_path(res_path), FileAccess.READ)
	if f == null:
		return {}
	var b := f.get_buffer(f.get_length())
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
		return {}
	var at := 12
	var rate := 0
	var channels := 0
	var bits := 0
	while at + 8 <= b.size():
		var id := b.slice(at, at + 4).get_string_from_ascii()
		var n := b.decode_u32(at + 4)
		if id == "fmt ":
			channels = b.decode_u16(at + 10)
			rate = b.decode_u32(at + 12)
			bits = b.decode_u16(at + 22)
		elif id == "data":
			if bits != 16 or rate == 0:
				return {}
			return _levels_of(b.slice(at + 8, at + 8 + n), rate, channels)
		at += 8 + n + (n % 2)
	return {}


func _levels_of(pcm: PackedByteArray, rate: int, channels: int) -> Dictionary:
	var count := pcm.size() / 2
	var peak := 1
	var sum := 0.0
	var lead := -1
	var quiet := int(32768.0 * pow(10.0, -50.0 / 20.0))
	for i in range(count):
		var v := absi(pcm.decode_s16(i * 2))
		peak = maxi(peak, v)
		sum += float(v) * v
		if lead < 0 and v > quiet:
			lead = i
	var rms := sqrt(sum / maxi(1, count))
	return {"peak": 20.0 * log(peak / 32768.0) / log(10.0),
			"rms": 20.0 * log(maxf(rms, 1.0) / 32768.0) / log(10.0),
			"lead": float(maxi(lead, 0)) / (rate * channels),
			"seconds": float(count) / (rate * channels)}


func _music_player() -> void:
	var mm = root.get_node("MusicManager")
	var player: AudioStreamPlayer = mm.find_child("BackgroundMusic", true, false)
	_check(player != null and player.volume_db < -6.0, "Menu music plays quietly")
	if player == null:
		return
	mm.set_context("hub")
	var first := player.stream
	mm.set_context("match")
	_check(player.stream_paused or not player.playing, "The music stops for a match")
	mm.set_context("hub")
	_check(player.stream == first and not player.stream_paused, "After the match the same track carries on")
	player.emit_signal("finished")
	_check(player.stream != first or (mm.get("_tracks") as Array).size() == 1, "When a track ends the next one starts")
	_state.set_sounds_muted(true)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Mute silences the music")
	_state.set_sounds_muted(false)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Sound back on brings it back")
	# FL-004: music and crowd levels, each on its own bus under Master, saved.
	_check(player.bus == "Music" and AudioServer.get_bus_send(AudioServer.get_bus_index("Music")) == "Master",
			"The music has its own level, under Mute sounds")
	var crowd := AudioServer.get_bus_index(AudioLevels.bus(AudioLevels.CROWD))
	_state.set_crowd_level("quiet")
	_check(_state.crowd_level() == "quiet" and is_equal_approx(AudioServer.get_bus_volume_db(crowd), AudioLevels.QUIET_DB)
			and not AudioServer.is_bus_mute(crowd), "Crowd: quiet turns it down and is remembered")
	_state.set_crowd_level("off")
	_check(AudioServer.is_bus_mute(crowd), "Crowd: off silences it")
	_state.set_music_level("off")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and _state.music_level() == "off", "Music: off silences it")
	_state.set_crowd_level("nonsense")
	_check(_state.crowd_level() == "normal" and not AudioServer.is_bus_mute(crowd)
			and is_equal_approx(AudioServer.get_bus_volume_db(crowd), 0.0), "A level it doesn't know is normal")
	_state.set_music_level("normal")
	# The crowd says each thing once, and a behind doesn't cut off a roar.
	var cs := CrowdSound.new()
	root.add_child(cs)
	cs.event("goal")
	var roar := cs.cue()
	cs.event("behind")
	_check(roar == "crowd_goal.wav" and cs.cue() == "crowd_goal.wav", "A goal roars, and a behind doesn't cut the roar off (%s, %s)" % [roar, cs.cue()])
	cs.event("mark")
	_check(cs.cue() == "crowd_goal.wav", "Only goals, behinds and the siren are cues")
	cs.full_time()
	var siren := cs.cue()
	cs.event("goal")
	cs.full_time()
	_check(siren == "crowd_siren.wav", "The siren at full time (%s)" % siren)
	var bed: AudioStreamPlayer = cs.get_child(0)
	_check(bed.bus == "Crowd" and bed.stream != null and (bed.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"The murmur under it all loops on the crowd's level")
	cs.queue_free()


# ---------------------------------------------------------------------------
# Run-through banners (data/banners.json, Banners.pick)
# ---------------------------------------------------------------------------
## The longest fill-ins: a nickname, a 12-letter surname, a full name, a 300-game
## milestone and a year.
const BANNER_LONGEST := {"{us}": "Kangaroos", "{them}": "Kangaroos", "{player}": "Wwwwwwwwwwww", "{display_name}": "Wwwwwwwwwww Wwwwwwwwwwww",
		"{games}": "300", "{year}": "2031"}


func _banners() -> void:
	var B: GDScript = load("res://scripts/core/Banners.gd")
	var d: Dictionary = B.data()
	_check(not d.is_empty(), "The banner rhymes load")
	if d.is_empty():
		return
	# Every text in the file, wherever it sits.
	var all := []
	for k in d:
		var v = d[k]
		if v is Array:
			for x in v:
				if x is String:
					all.append(x)
				elif x is Dictionary:
					all.append_array(x.get("texts", []))
		elif v is Dictionary:
			for kk in v:
				all.append_array(v[kk])
	var bad_lines := []
	var too_long := []
	var unknown := []
	var re := RegEx.new()
	re.compile("\\{[a-z_]+\\}")
	for t in all:
		var lines := str(t).split("\n")
		if lines.size() < 2 or lines.size() > 4:
			bad_lines.append(t)
		for m in re.search_all(str(t)):
			if not BANNER_LONGEST.has(m.get_string()):
				unknown.append(m.get_string())
		var filled := str(t)
		for ph in BANNER_LONGEST:
			filled = filled.replace(ph, BANNER_LONGEST[ph])
		for line in filled.split("\n"):
			if line.length() > 28:
				too_long.append(line)
	_check(all.size() >= 140, "The banner file holds its rhymes (%d)" % all.size())
	_check(bad_lines.is_empty(), "Every banner is 2 to 4 lines (%s)" % str(bad_lines.slice(0, 3)))
	_check(too_long.is_empty(), "Every line fits 28 characters with the longest names filled in (%s)" % str(too_long.slice(0, 3)))
	_check(unknown.is_empty(), "Banners use only the known fill-ins (%s)" % str(unknown))
	var missing := []
	for code in root.get_node("GameDB").clubs:
		if not (d.get("club", {}) as Dictionary).has(code) or (d["club"][code] as Array).is_empty():
			missing.append(code)
	for r in d.get("rivalry", []):
		if (r.get("pair", []) as Array).size() != 2 or (r.get("texts", []) as Array).is_empty():
			missing.append(str(r.get("pair", [])))
	for week in ["wildcard", "elimination", "qualifying", "semi", "preliminary", "grand"]:
		if (d.get("final", {}) as Dictionary).get(week, []).is_empty():
			missing.append(week)
	for key in ["debut", "50", "100", "150", "200", "250", "300", "350", "farewell"]:
		if (d.get("milestone", {}) as Dictionary).get(key, []).is_empty():
			missing.append(key)
	for t in MarqueeGames.TRADITIONS:
		if B._marquee(d, str(t["name"])).is_empty():
			missing.append(str(t["name"]))
	_check(missing.is_empty(), "Every club, rivalry, final week, milestone and marquee game has its banners (%s)" % str(missing))
	# The days of remembrance honour the day: no taunt at the opponent.
	var taunts := []
	for name in B.RESPECTFUL:
		for t in B._marquee(d, name):
			if str(t).contains("{them}"):
				taunts.append(t)
	_check(taunts.is_empty(), "ANZAC and Dreamtime banners name no opponent to taunt (%s)" % str(taunts))
	# Which set, in order: each occasion beats everything below it.
	var full := {"home": "TAS", "away": "NTH", "round": "Round 1", "final": "grand", "must_win": true,
			"spoon": true, "first_game": "TAS", "premiers": "NTH", "milestone": {"player": "Smith", "games": 100},
			"year": 2028, "seed": 7}
	var order := []
	var ctx := full.duplicate(true)
	for drop in ["first_game", "milestone", "final", "must_win", "premiers", "spoon"]:
		order.append(str(B.texts_for(ctx)[0]))
		ctx.erase(drop)
	order.append(str(B.texts_for(ctx)[0]))
	_check(order == ["first_game", "milestone", "final", "must_win", "premiers_opposition", "spoon", "club"],
			"Banners follow the occasion's priority (%s)" % str(order))
	var riv := {"home": "CAR", "away": "COL", "round": "Round 3", "seed": 3}
	_check(str(B.texts_for(riv)[0]) == "rivalry" and str(B.texts_for({"home": "COL", "away": "CAR", "seed": 3})[0]) == "rivalry",
			"A rivalry is a rivalry in either order")
	_check(str(B.texts_for({"home": "HAW", "away": "GEE", "us": "GEE"})[0]) == "marquee",
			"A marquee game gets its own banner")
	var anzac := {"home": "ESS", "away": "COL", "round": "Round 7", "must_win": true, "premiers": "COL",
			"milestone": {"player": "Smith", "games": 200}, "seed": 1}
	var anzac_texts: Array = B._marquee(d, "ANZAC Day")
	_check(anzac_texts.has(str(B.texts_for(anzac)[1][0])) and str(B.texts_for(anzac)[0]) == "marquee",
			"ANZAC Day only ever gets its own banner")
	var a: String = B.pick(riv)
	_check(a != "" and a == B.pick(riv), "The same match always gets the same banner")
	var ms: String = B.pick({"home": "COL", "away": "ESS", "milestone": {"player": "Smith", "games": 100}, "seed": 2})
	_check(not ms.contains("{") and ms.split("\n").size() >= 2, "A picked banner is filled in, in lines (%s)" % ms)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
