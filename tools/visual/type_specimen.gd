extends Node
## Type specimen for STYLE-01/02/05 (the director's bespoke-UI and font
## research, 2026-10-06): the same real content set three ways, side by side.
##   current - the game as it is (UiKit's Barlow sizes, as each screen sets them)
##   A       - Barlow, set better: one type scale, tabular figures, a plain
##             numeral for the guernsey number, a left-anchored title, an
##             editorial hierarchy for the report
##   B       - A's roles in Source Sans 3, with Source Serif 4 for the report
##             headline only (needs --fonts; not part of the game)
## Colours, selection and control shapes are held constant: only type changes.
## A comparison for the art agent and the director, never a rollout.
##   godot --path . --rendering-driver opengl3 --script tools/visual/capture_type_specimen.gd \
##       -- --out /tmp/type_390 [--col 390] [--scale 1] [--text 1.0] [--fonts DIR] [--face DIR]...
## --col: logical width of one column (320 and 390 phone, 640 desktop).
## --scale: pixels per logical unit (2 for a 2x phone or a fullscreen 2560
##   desktop under STYLE-07's density). --text: every text size times this, the
##   layout unchanged (larger text). --fonts: a folder holding SourceSans3-
##   Regular/Semibold/Bold.ttf and SourceSerif4-Semibold.ttf (OFL, from
##   github.com/adobe-fonts).
## Writes <out>.png and prints each font's x-height, cap height and whether
## its tabular figures (OpenType tnum) take effect in Godot.

const GUTTER := 24
const CAPTION := Color(0.62, 0.6, 0.55)
const MY := "MEL"
const OPP := "COL"
## Score and clock for the scoreboard and the report: AFL notation.
const GOALS := [12, 9]
const BEHINDS := [8, 17]
const CLOCK := "Q4 27'"
const ROUND := 4

var col_w := 390
var narrow := true
var text_k := 1.0
var ts: TextServer
var db
var state


func run() -> void:
	var out := "/tmp/type_specimen"
	var scale := 1.0
	var fonts_dir := ""
	var faces := []
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--col": col_w = int(a[i + 1])
			"--scale": scale = float(a[i + 1])
			"--text": text_k = float(a[i + 1])
			"--fonts": fonts_dir = str(a[i + 1])
			"--face": faces.append(str(a[i + 1]))
	narrow = col_w < 640
	ts = TextServerManager.get_primary_interface()
	await get_tree().process_frame
	state = GameState
	db = GameDB
	state.autosave_enabled = false
	state.save_path = "user://specimen.save"
	state.settings_path = "user://specimen_settings.cfg"
	state.reset()
	state.start_season(MY, db.club_list(MY))

	# --faces-only: today's game beside our own faces, without the Barlow A.
	var treatments := [_current()] if a.has("--faces-only") else [_current(), _barlow_set()]
	if fonts_dir != "":
		var b := _source(fonts_dir)
		if not b.is_empty():
			treatments.append(b)
	for f in faces:
		var own := _own(str(f))
		if not own.is_empty():
			treatments.append(own)
	for t in treatments:
		_report_font(t)
	_report_contrast()

	var cols := treatments.size()
	var logical_w := cols * col_w + (cols + 1) * GUTTER
	# Drawn offscreen, so the sheet can be taller or denser than the screen:
	# the window would be clamped to the display and the 2x would quietly be 1x.
	var sv := SubViewport.new()
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.size_2d_override_stretch = true
	add_child(sv)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	sv.add_child(bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GUTTER)
	row.position = Vector2(GUTTER, 12)
	sv.add_child(row)
	for t in treatments:
		var c := _column(t)
		c.custom_minimum_size.x = col_w
		row.add_child(c)
	_size_text(row)
	# Lay out at a nominal height, then fit the sheet to the content.
	var logical := Vector2i(logical_w, 2400)
	_set_sheet(sv, logical, scale)
	for i in range(3):
		await get_tree().process_frame
	logical.y = int(row.get_combined_minimum_size().y) + 24
	_set_sheet(sv, logical, scale)
	bg.size = Vector2(logical)
	for i in range(5):
		await get_tree().process_frame
	var img := sv.get_texture().get_image()
	# Wrapped text can claim more height in the first layout than it ends up
	# using: trim the empty background off the bottom.
	var last := img.get_height() - 1
	var bgc := img.get_pixel(0, last)
	while last > 0:
		var empty := true
		for x in range(0, img.get_width(), 2):
			if not img.get_pixel(x, last).is_equal_approx(bgc):
				empty = false
				break
		if not empty:
			break
		last -= 1
	img = img.get_region(Rect2i(0, 0, img.get_width(), mini(img.get_height(), last + roundi(16 * scale))))
	img.save_png(out + ".png")
	print("wrote %s.png (%dx%d px, %d logical columns of %d at %.2fx, text %.2fx)" % [
			out, img.get_width(), img.get_height(), cols, col_w, scale, text_k])
	get_tree().quit(0)


func _set_sheet(sv: SubViewport, logical: Vector2i, scale: float) -> void:
	sv.size_2d_override = logical
	sv.size = Vector2i(roundi(logical.x * scale), roundi(logical.y * scale))


# --- Treatments ------------------------------------------------------------

## The roles a treatment sets: [font key, size]. Fonts: "reg", "bold",
## "display" (scores and the guernsey number), "head" (the report headline).
func _current() -> Dictionary:
	return {
		"name": "Current", "note": "UiKit as the screens set it today",
		"reg": UiKit.FONT, "bold": UiKit.BOLD, "display": UiKit.DISPLAY, "head": UiKit.BOLD,
		"title_left": false, "plain_number": false, "k": 1.0,
		"roles": {
			"title": ["bold", 20], "kicker": ["reg", 13], "opponent": ["bold", 26 if narrow else 30],
			"form": ["reg", 13], "t_name": ["bold", 15], "t_sub": ["reg", 12], "t_tag": ["bold", 11],
			"t_rating": ["bold", 17], "role": ["bold", 12], "l_num": ["bold", 12], "l_name": ["bold", 15],
			"l_sub": ["reg", 13], "l_status": ["bold", 13], "l_rating": ["bold", 20], "l_pot": ["reg", 11],
			"club": ["bold", 13 if narrow else 16], "score": ["display", 30 if narrow else 36],
			"clock": ["bold", 17 if narrow else 20], "lead": ["reg", 13], "btn": ["bold", 16],
			"btn_small": ["bold", 14], "head": ["head", 24], "when": ["bold", 13], "body": ["reg", 13],
			"glyphs": ["reg", 15],
		},
		"spacing": {"head": 0, "body": 0, "opponent": 0},
	}


## Barlow, set better. Same files; the changes are roles, figures and anchors.
func _barlow_set() -> Dictionary:
	var t := _current()
	t["name"] = "A  Barlow, set"
	t["note"] = "one scale, tabular figures, plain numbers"
	t["title_left"] = true
	t["plain_number"] = true
	for k in ["reg", "bold", "display"]:
		t[k] = _tabular(t[k])
	t["head"] = t["bold"]
	t["roles"].merge({
		"opponent": ["bold", 28 if narrow else 32], "t_name": ["bold", 16], "t_sub": ["reg", 13],
		"t_tag": ["bold", 12], "t_rating": ["bold", 20], "l_num": ["display", 18], "l_name": ["bold", 16],
		"l_pot": ["reg", 12], "head": ["head", 26], "when": ["reg", 13], "body": ["reg", 15],
	}, true)
	t["spacing"] = {"head": -3, "body": 4, "opponent": -2}
	return t


## A's roles in Source Sans 3, the headline in Source Serif 4. Sizes are
## scaled so its x-height matches Barlow's: the same nominal size would read
## smaller and the comparison would be about size, not the face.
func _source(dir: String) -> Dictionary:
	var files := {}
	for k in [["reg", "SourceSans3-Regular.ttf"], ["bold", "SourceSans3-Semibold.ttf"],
			["display", "SourceSans3-Bold.ttf"], ["head", "SourceSerif4-Semibold.ttf"]]:
		var f := FontFile.new()
		if f.load_dynamic_font(dir.path_join(k[1])) != OK:
			push_error("specimen: missing %s in %s" % [k[1], dir])
			return {}
		files[k[0]] = f
	var t := _barlow_set()
	t["name"] = "B  Source Sans 3 + Serif 4"
	t["note"] = "A's roles; serif for the headline only"
	for k in files:
		t[k] = _tabular(files[k])
	t["k"] = _x_height(UiKit.FONT) / _x_height(files["reg"])
	# The art agent: the serif a tenth smaller than A's headline, so it reads
	# as the same publication rather than a second one.
	t["roles"]["head"] = ["head", 23]
	return t


## The game's own typeface (the director's decision, 2026-10-06), built by
## tools/typeface/build_font.py into DIR as Regular.ttf, Bold.ttf and
## Display.ttf. A style not built yet falls back to Barlow, and the column
## says which, so an early numerals-only face can already be judged in place.
func _own(dir: String) -> Dictionary:
	var t := _barlow_set()
	var built := []
	for k in [["reg", "Regular.ttf"], ["bold", "Bold.ttf"], ["display", "Display.ttf"]]:
		var path := dir.path_join(k[1])
		if FileAccess.file_exists(path):
			var f := FontFile.new()
			if f.load_dynamic_font(path) == OK:
				# Glyphs it lacks come from Barlow, not the engine's default.
				f.fallbacks = [(t[k[0]] as FontVariation).base_font]
				t[k[0]] = _tabular(f)
				built.append(k[1].get_basename())
	if built.is_empty():
		push_error("specimen: no Regular/Bold/Display.ttf in %s" % dir)
		return {}
	t["head"] = t["bold"]
	# face.json beside the fonts: {"outline": 0.06, "shadow": [0.04, 0.04]} as a
	# share of the font size - a guernsey keyline or a sign-writer's drop shade,
	# drawn by Godot under the letters.
	var hints_path := dir.path_join("face.json")
	if FileAccess.file_exists(hints_path):
		var hints = JSON.parse_string(FileAccess.get_file_as_string(hints_path))
		if hints is Dictionary:
			t["hints"] = hints
	if built.size() == 3:
		# A whole family: the display cut sets the big type - titles, the
		# opponent, headlines and every number a player reads.
		t["head"] = t["display"]
		t["roles"].merge({"title": ["display", 22], "opponent": ["display", 32 if narrow else 36],
				"t_rating": ["display", 22], "l_rating": ["display", 22], "clock": ["display", 19]}, true)
	if built == ["Display"]:
		# A numerals-and-capitals display face so far: it sets every number a
		# player reads (scores, clock, ratings, guernsey numbers); words stay Barlow.
		t["roles"].merge({"t_rating": ["display", 22], "l_rating": ["display", 22], "clock": ["display", 19]}, true)
	t["name"] = "Ours: %s" % dir.trim_suffix("/").get_file()
	t["note"] = "numbers in our face; words Barlow" if built == ["Display"] else "%s ours; the rest Barlow" % "/".join(built)
	return t


## The font with tabular lining figures switched on, so every digit takes the
## same width and a changing score or a column of ratings doesn't shift.
func _tabular(font: Font) -> Font:
	var base: Font = font.base_font if font is FontVariation else font
	var fv := FontVariation.new()
	fv.base_font = base
	fv.opentype_features = {ts.name_to_tag("tnum"): 1}
	return fv


## Ink height of a glyph at 100 px, from the rasteriser's own glyph bitmap.
func _ink(font: Font, ch: String) -> float:
	var base: Font = font.base_font if font is FontVariation else font
	var rid: RID = base.get_rids()[0]
	var sz := Vector2i(100, 0)
	var idx := ts.font_get_glyph_index(rid, 100, ch.unicode_at(0), 0)
	ts.font_render_glyph(rid, sz, idx)
	var tex: int = ts.font_get_glyph_texture_idx(rid, sz, idx)
	var uv: Rect2 = ts.font_get_glyph_uv_rect(rid, sz, idx)
	var img: Image = ts.font_get_texture_image(rid, sz, tex)
	var top := 9999
	var bottom := -1
	for y in range(int(uv.position.y), int(uv.end.y)):
		for x in range(int(uv.position.x), int(uv.end.x)):
			if img.get_pixel(x, y).a > 0.5 or (img.get_format() == Image.FORMAT_L8 and img.get_pixel(x, y).r > 0.5) 					or (img.get_format() == Image.FORMAT_LA8 and img.get_pixel(x, y).a > 0.5):
				top = mini(top, y)
				bottom = maxi(bottom, y)
	return float(bottom - top + 1) if bottom >= 0 else 0.0


var _x_cache := {}

func _x_height(font: Font) -> float:
	if not _x_cache.has(font):
		_x_cache[font] = _ink(font, "x")
	return _x_cache[font]


func _report_font(t: Dictionary) -> void:
	var f: Font = t["reg"]
	var base: Font = f.base_font if f is FontVariation else f
	var feats: Dictionary = base.get_supported_feature_list()
	var tnum := ts.name_to_tag("tnum")
	var w1 := f.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	var w8 := f.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	var b1 := base.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	var b8 := base.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	print("%-28s x-height %.0f  cap %.0f (at 100)  size factor %.3f  tnum in font: %s  '1'/'8' width plain %.0f/%.0f, as set %.0f/%.0f" % [
			t["name"], _x_height(base), _ink(base, "H"), float(t["k"]), feats.has(tnum), b1, b8, w1, w8])


# --- Column ----------------------------------------------------------------

func _column(t: Dictionary) -> VBoxContainer:
	var v := UiKit.vbox(10)
	v.add_child(_caption("%s  -  %s" % [t["name"], t["note"]]))
	v.add_child(_caption("Hub header"))
	v.add_child(_header(t))
	v.add_child(_caption("Training rows: normal, selected, long name, injured"))
	v.add_child(_training_rows(t))
	v.add_child(_caption("Full list rows: guernsey number, long name, out injured"))
	v.add_child(_list_rows(t))
	v.add_child(_caption("Match scoreboard"))
	v.add_child(_scoreboard(t))
	v.add_child(_caption("Controls: primary, secondary, selected, disabled"))
	v.add_child(_controls(t))
	v.add_child(_caption("Report (specimen copy)"))
	v.add_child(_report(t))
	v.add_child(_caption("Figures and look-alikes"))
	v.add_child(_text(t, "glyphs", "Il1 O0 689  12.8 (80)  9.17 (71)  $850k  $1.25m", UiKit.TEXT))
	return v


## A note about the specimen, in the engine's fallback font so it never reads
## as part of either treatment.
func _caption(s: String) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", CAPTION)
	l.set_meta("caption", true)
	return l


func _text(t: Dictionary, role: String, s: String, colour: Color, trim := true) -> Label:
	var r: Array = t["roles"][role]
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", t[r[0]])
	l.add_theme_font_size_override("font_size", roundi(int(r[1]) * float(t["k"])))
	l.add_theme_color_override("font_color", colour)
	var sp := int((t["spacing"] as Dictionary).get(role, 0))
	if sp != 0:
		l.add_theme_constant_override("line_spacing", sp)
	_decorate(t, role, l, colour)
	if trim:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A label that keeps its own width (a rating, a tag).
func _fixed(t: Dictionary, role: String, s: String, colour: Color) -> Label:
	var l := _text(t, role, s, colour)
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	l.size_flags_horizontal = Control.SIZE_FILL
	return l


func _button(t: Dictionary, role: String, s: String, primary := false) -> Button:
	var r: Array = t["roles"][role]
	var b := UiKit.btn(s, 16, primary)
	b.add_theme_font_override("font", t[r[0]])
	b.add_theme_font_size_override("font_size", roundi(int(r[1]) * float(t["k"])))
	return b


# --- Hub header ------------------------------------------------------------

func _header(t: Dictionary) -> Control:
	var v := UiKit.vbox(6)
	var bar := UiKit.hbox(10)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.custom_minimum_size.y = 44
	var title := _text(t, "title", "Round %d of 24" % ROUND, UiKit.TEXT)
	if t["title_left"]:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var settings := _button(t, "btn_small", "Settings")
	settings.flat = true
	settings.custom_minimum_size = Vector2(64, 44)
	settings.add_theme_color_override("font_color", UiKit.MUTED)
	bar.add_child(settings)
	v.add_child(bar)
	if t["title_left"]:
		# A neutral band under the title: the anchor the art agent's header
		# motif would replace. Deliberately plain.
		var band := ColorRect.new()
		band.color = UiKit.LINE
		band.custom_minimum_size.y = 2
		v.add_child(band)
	var ground := str(db.club(MY).get("ground", "MCG"))
	v.add_child(_text(t, "kicker", ground, UiKit.MUTED))
	v.add_child(_text(t, "opponent", "v %s" % db.club_name(OPP), UiKit.TEXT, false))
	v.add_child(_text(t, "form", "5th on the ladder  ·  won 4 of the last 5", UiKit.MUTED))
	return v


# --- Rows ------------------------------------------------------------------

## Four of your players: two ordinary, the league's longest name, and one
## injured (his injury is set for the specimen only).
func _players() -> Array:
	var mine: Array = state.my_list.duplicate()
	mine.sort_custom(func(x, y): return int(x["overall"]) > int(y["overall"]))
	var longest: Dictionary = mine[0]
	for c in (db.clubs as Dictionary).keys():
		for p in db.club_list(c):
			if db.player_display_name(p).length() > db.player_display_name(longest).length():
				longest = p
	var hurt: Dictionary = (mine[5] as Dictionary).duplicate()
	hurt["injury_weeks"] = 3
	return [mine[0], mine[1], longest, hurt]


func _training_rows(t: Dictionary) -> Control:
	var v := UiKit.vbox(6)
	var ps := _players()
	var training: GDScript = load("res://scripts/ui/TrainingScene.gd")
	for i in range(ps.size()):
		var p: Dictionary = ps[i]
		var b := UiKit.btn("", 14)
		b.custom_minimum_size.y = 58
		if i == 1:
			UiKit.set_selected(b, true)
		var h := UiKit.hbox(8)
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 8
		h.offset_right = -8
		b.add_child(h)
		h.add_child(_role(t, Ratings.role_tag(p)))
		var info := UiKit.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(info)
		info.add_child(_text(t, "t_name", db.player_display_name(p), UiKit.TEXT))
		var plan := str(state.plan_for(p))
		info.add_child(_text(t, "t_sub", "%s  ·  %s" % [training._row_plan(plan),
				state.development_state(p)], UiKit.MUTED))
		if int(p.get("injury_weeks", 0)) > 0:
			h.add_child(_fixed(t, "t_tag", "INJ %dw" % int(p["injury_weeks"]), UiKit.BAD))
		elif i == 2:
			h.add_child(_fixed(t, "t_tag", "INT", UiKit.MUTED))
		var rise := i == 0
		var ov := _fixed(t, "t_rating", ("▲ " if rise else "") + str(int(p["overall"])),
				UiKit.GOOD if rise else UiKit.TEXT)
		ov.custom_minimum_size.x = 48
		ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(ov)
		v.add_child(b)
	return v


func _role(t: Dictionary, role: String) -> Control:
	var primary := role.split("/")[0]
	var l := _fixed(t, "role", role, UiKit.ROLE_COLOUR.get(primary, UiKit.MUTED))
	l.custom_minimum_size.x = 72 if role.contains("/") else 40
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _list_rows(t: Dictionary) -> Control:
	var v := UiKit.vbox(0)
	var ps := _players()
	var cols: Array = db.club_colours(MY)
	for i in [0, 2, 3]:
		var p: Dictionary = ps[i]
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.TRANSPARENT
		sb.border_color = UiKit.LINE
		sb.border_width_bottom = 1
		row.add_theme_stylebox_override("panel", sb)
		row.custom_minimum_size.y = 56
		var h := UiKit.hbox(8)
		row.add_child(h)
		var num := str(int(p.get("num", 0)))
		if t["plain_number"]:
			var n := _fixed(t, "l_num", num, UiKit.TEXT)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			n.custom_minimum_size.x = 30
			n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(n)
		else:
			var chip := PanelContainer.new()
			var csb := UiKit.style(cols[0], 4, 4, cols[1])
			csb.set_border_width_all(2)
			chip.add_theme_stylebox_override("panel", csb)
			var n := _fixed(t, "l_num", num, UiKit.readable_on(cols[0]))
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.add_child(n)
			chip.custom_minimum_size.x = 30
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(chip)
		var who := UiKit.vbox(0)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(who)
		who.add_child(_text(t, "l_name", db.player_display_name(p), UiKit.TEXT))
		var bits := PackedStringArray([Roles.label(p)])
		if float(p.get("age", 0.0)) > 0.0:
			bits.append("%d" % int(p["age"]))
		if float(p.get("height_cm", 0.0)) > 0.0:
			bits.append("%d cm" % int(p["height_cm"]))
		who.add_child(_text(t, "l_sub", "  ·  ".join(bits), UiKit.MUTED))
		if int(p.get("injury_weeks", 0)) > 0:
			var st := _fixed(t, "l_status", "Out %d weeks" % int(p["injury_weeks"]), UiKit.BAD)
			st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(st)
		var nums := UiKit.vbox(0)
		nums.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(nums)
		var ov := _fixed(t, "l_rating", str(int(p["overall"])), UiKit.TEXT)
		ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ov.custom_minimum_size.x = 40
		nums.add_child(ov)
		var pot := _fixed(t, "l_pot", "POT %d" % int(p.get("potential", p["overall"])), UiKit.MUTED)
		pot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		nums.add_child(pot)
		v.add_child(row)
	return v


# --- Scoreboard ------------------------------------------------------------

func _scoreboard(t: Dictionary) -> Control:
	var p := UiKit.panel(UiKit.PANEL, 8)
	var v := UiKit.vbox(4)
	p.add_child(v)
	var h := UiKit.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(_score_column(t, MY, true, 0))
	var mid := UiKit.vbox(0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.custom_minimum_size = Vector2(84 if narrow else 132, 0)
	var clock := _fixed(t, "clock", CLOCK, UiKit.TEXT)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(clock)
	var name_of := func(c): return db.club_short(str(c)) if narrow else db.club_name(str(c))
	var lead := _text(t, "lead", MatchNotes.lead_text(MY, OPP, [_total(0), _total(1)], name_of), UiKit.MUTED)
	lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(lead)
	h.add_child(mid)
	h.add_child(_score_column(t, OPP, false, 1))
	var bar := UiKit.hbox(0)
	bar.custom_minimum_size = Vector2(0, 6)
	for c in [MY, OPP]:
		var r := ColorRect.new()
		r.color = (db.club_colours(c) as Array)[0]
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.custom_minimum_size = Vector2(0, 6)
		bar.add_child(r)
	v.add_child(bar)
	return p


func _total(side: int) -> int:
	return int(GOALS[side]) * 6 + int(BEHINDS[side])


func _score_column(t: Dictionary, code: String, home: bool, side: int) -> Control:
	var v := UiKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := _text(t, "club", db.club_short(code) if narrow else db.club_name(code), UiKit.TEXT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if home else HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name)
	var cols: Array = db.club_colours(code)
	var score := _fixed(t, "score", UiKit.scoreline(int(GOALS[side]), int(BEHINDS[side])), cols[2])
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if home else HORIZONTAL_ALIGNMENT_LEFT
	if not narrow:
		score.custom_minimum_size = Vector2(136, 0)
	v.add_child(score)
	return v


# --- Controls --------------------------------------------------------------

func _controls(t: Dictionary) -> Control:
	var v := UiKit.vbox(6)
	var play := _button(t, "btn", "Play Round %d" % ROUND, true)
	play.custom_minimum_size.y = 48
	v.add_child(play)
	var h := UiKit.hbox(6)
	v.add_child(h)
	var choice := _button(t, "btn_small", "Contest")
	UiKit.paint_choice(choice, true)
	var other := _button(t, "btn_small", "Attack")
	UiKit.paint_choice(other, false)
	var off := _button(t, "btn_small", "Sim to finals")
	off.disabled = true
	for b in [choice, other, off]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(b)
	return v


# --- Report ----------------------------------------------------------------

func _report(t: Dictionary) -> Control:
	var v := UiKit.vbox(6)
	var mine: Array = state.my_list.duplicate()
	mine.sort_custom(func(x, y): return int(x["overall"]) > int(y["overall"]))
	var best: String = db.player_display_name(mine[0])
	var theirs: Array = db.club_list(OPP)
	theirs.sort_custom(func(x, y): return int(x["overall"]) > int(y["overall"]))
	var rival: String = db.player_display_name(theirs[0])
	var line := "%s %s d %s %s" % [db.club_name(MY), UiKit.scoreline(GOALS[0], BEHINDS[0]),
			db.club_name(OPP), UiKit.scoreline(GOALS[1], BEHINDS[1])]
	v.add_child(_text(t, "head", "%s hang on as %s kick themselves out of it" % [
			db.club_nickname(MY) if db.has_method("club_nickname") else "The Demons",
			db.club_nickname(OPP) if db.has_method("club_nickname") else "the Magpies"],
			UiKit.TEXT, false))
	v.add_child(_text(t, "when", "Round %d  ·  %s" % [ROUND, str(db.club(MY).get("ground", "MCG"))],
			UiKit.MUTED))
	v.add_child(_text(t, "body", line + ".", UiKit.TEXT, false))
	v.add_child(_text(t, "body", ("%s had the ball on a string through the middle, and %s kicked " +
			"9.17 to keep the margin at a goal and a half all afternoon. A late re-sign for two " +
			"years at $850k looks a bargain tonight.") % [best, db.club_short(OPP)], UiKit.MUTED, false))
	v.add_child(_text(t, "body", "Best: %s.  For %s: %s." % [best, db.club_short(OPP), rival],
			UiKit.TEXT, false))
	return v


## --text: every text size times text_k, the layout unchanged (captions too,
## so they stay in proportion).
func _size_text(node: Node) -> void:
	if text_k == 1.0:
		return
	for c in node.get_children():
		if c is Control and (c as Control).has_theme_font_size_override("font_size"):
			var fs := (c as Control).get_theme_font_size("font_size")
			(c as Control).add_theme_font_size_override("font_size", roundi(fs * text_k))
		_size_text(c)


## WCAG contrast of the specimen's actual text colours on their surfaces,
## and of every club's score colour on the scoreboard panel (supporting
## evidence only: thin strokes and anti-aliasing need the eye too).
func _report_contrast() -> void:
	var pairs := [["TEXT on BG", UiKit.TEXT, UiKit.BG], ["MUTED on BG", UiKit.MUTED, UiKit.BG],
			["MUTED on PANEL", UiKit.MUTED, UiKit.PANEL], ["FAINT (disabled) on BG", UiKit.FAINT, UiKit.BG],
			["BAD on BG", UiKit.BAD, UiKit.BG], ["GOOD on BG", UiKit.GOOD, UiKit.BG],
			["TEXT on ACCENT", UiKit.TEXT, UiKit.ACCENT]]
	for r in UiKit.ROLE_COLOUR:
		pairs.append(["role %s on BG" % r, UiKit.ROLE_COLOUR[r], UiKit.BG])
	for p in pairs:
		print("contrast %-24s %.2f" % [p[0], _ratio(p[1], p[2])])
	var low := []
	var codes: Array = (db.clubs as Dictionary).keys()
	codes.sort()
	for c in codes:
		var r := _ratio((db.club_colours(c) as Array)[2], UiKit.PANEL)
		if r < 4.5:
			low.append("%s %.2f" % [c, r])
	print("contrast score colour on PANEL below 4.5: %s" % (", ".join(low) if not low.is_empty() else "none"))


func _ratio(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _lum(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


## The roles a face's keyline or drop shade applies to: the display jobs, not
## body copy.
const DECORATED := ["title", "opponent", "score", "clock", "head", "l_num", "t_rating", "l_rating"]

func _decorate(t: Dictionary, role: String, l: Label, colour: Color) -> void:
	var hints: Dictionary = t.get("hints", {})
	if hints.is_empty() or not DECORATED.has(role):
		return
	var fs := float(l.get_theme_font_size("font_size"))
	if hints.has("outline"):
		l.add_theme_constant_override("outline_size", maxi(1, roundi(fs * float(hints["outline"]) * 2.0)))
		# The jumper's other colour: red on a light fill, the light ink on a dark one.
		l.add_theme_color_override("font_outline_color",
				Color("c8412b") if colour.get_luminance() > 0.5 else Color("f1eee6"))
	if hints.has("shadow"):
		var sh: Array = hints["shadow"]
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", maxi(1, roundi(fs * float(sh[0]))))
		l.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(fs * float(sh[1]))))
