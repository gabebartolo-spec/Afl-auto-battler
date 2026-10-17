extends SceneTree
## P-77 "One sweep of every screen" (proposals pass 2, director yes 2026-10-18).
## Opens every screen in Router.SCENES on one seeded career in the dark theme
## and measures it. Per screen it records:
##   min_font     the smallest rendered font size in px (font size in UI units
##                times the window's pixels per unit), with the node that has it
##   offscreen    visible Controls whose rect leaves the viewport (sideways
##                always; up or down only outside a ScrollContainer)
##   clipped      labels and buttons whose text is cut, ellipsised or has lines
##                the box does not show
##   small        buttons and tappable rows under 44 px in either direction
## Measurement only: it never changes a screen, and it never touches a real
## save. The pass/fail against the committed baseline is tools/screen_sweep.py.
##
##   godot --path . --rendering-method gl_compatibility --script tools/visual/sweep_screens.gd -- --size 390x844 --out out/sweep_phone.json
## Needs a real renderer (a virtual display on CI): fonts and layout are the
## ones a player sees. Run it once per size; 390x844 is the Android phone
## reference, 1920x1080 the wide desktop.

const MIN_TARGET := 44.0
const TOL := 1.0
const EXAMPLES := 8
const SEED := 2031
const CLUB := "MEL"

var W := 390
var H := 844
var _factor := 1.0     # window pixels per UI unit
var _vr := Rect2()     # the visible rect, in UI units
var _results := {}
var _state
var _db


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


# --- measuring -------------------------------------------------------------

func _label_of(c: Node) -> String:
	var t := ""
	if c.get("text") != null:
		t = str(c.get("text")).replace("\n", " ").left(28)
	return "%s \"%s\"" % [c.name, t]


func _path(c: Node, scene: Node) -> String:
	var parts := []
	var n: Node = c
	while n != null and n != scene and parts.size() < 3:
		parts.push_front(str(n.name))
		n = n.get_parent()
	return "/".join(parts)


func _font_px(c: Control) -> float:
	var fs := 0
	if c is RichTextLabel:
		fs = c.get_theme_font_size("normal_font_size")
	elif c is Label and (c as Label).label_settings != null:
		fs = (c as Label).label_settings.font_size
	else:
		fs = c.get_theme_font_size("font_size")
	var sc: Vector2 = c.get_global_transform().get_scale()
	return float(fs) * absf(sc.y) * _factor


func _has_text(c: Control) -> bool:
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text().strip_edges() != ""
	if c is Label:
		return (c as Label).text.strip_edges() != ""
	if c is Button:
		return (c as Button).text.strip_edges() != ""
	if c is LineEdit:
		return (c as LineEdit).text != "" or (c as LineEdit).placeholder_text != ""
	return false


## Text the box cannot show: trimmed with an ellipsis or clipped, or lines
## below the box. A line that wraps and fits is fine.
func _clipped(c: Control) -> bool:
	if c.size.x <= 1.0:
		return false
	if c is Label:
		var l := c as Label
		if l.text.strip_edges() == "":
			return false
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return l.get_line_count() > l.get_visible_line_count()
		var trims: bool = l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
		if not trims:
			return false
		var font: Font = l.get_theme_font("font")
		var fs := l.label_settings.font_size if l.label_settings != null else l.get_theme_font_size("font_size")
		if l.label_settings != null and l.label_settings.font != null:
			font = l.label_settings.font
		var wide := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		return wide > l.size.x + 0.5
	if c is Button:
		var b := c as Button
		if b.text.strip_edges() == "" or b.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return false
		var trims_b: bool = b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
		if not trims_b:
			return false
		var sb := b.get_theme_stylebox("normal")
		var room := b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
		if b.icon != null:
			room -= float(b.icon.get_width()) + 4.0
		var wide_b := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
		return wide_b > room + 0.5
	return false


func _tappable(c: Control) -> bool:
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if c is BaseButton:
		return not (c as BaseButton).disabled
	if c is ScrollContainer or c is ScrollBar:
		return false
	return c.gui_input.get_connections().size() > 0


func _walk(node: Node, scene: Node, in_scroll: bool, r: Dictionary) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Window:
		return
	var scrolls := in_scroll or node is ScrollContainer
	if node is Control:
		var c := node as Control
		if c.modulate.a < 0.05 or c.self_modulate.a < 0.05 and not c is Container:
			return
		var gr := c.get_global_rect()
		var visible_size := gr.size.x > 2.0 and gr.size.y > 2.0
		if visible_size and not (c is ScrollContainer):
			var side: bool = gr.position.x < _vr.position.x - TOL or gr.end.x > _vr.end.x + TOL
			var vert: bool = (not in_scroll) and (gr.position.y < _vr.position.y - TOL or gr.end.y > _vr.end.y + TOL)
			if (side or vert) and not (c is Container):
				r["offscreen"].append("%s %s spans x %d..%d y %d..%d of %dx%d" % [_path(c, scene), _label_of(c).left(30),
						int(gr.position.x), int(gr.end.x), int(gr.position.y), int(gr.end.y), int(_vr.size.x), int(_vr.size.y)])
		if _has_text(c) and visible_size:
			var px := _font_px(c)
			if px < float(r["min_font"]):
				r["min_font"] = snappedf(px, 0.01)
				r["min_font_node"] = "%s %s" % [_path(c, scene), _label_of(c).left(36)]
			if _clipped(c):
				r["clipped"].append("%s %s needs more than %d" % [_path(c, scene), _label_of(c).left(36), int(c.size.x)])
		if visible_size and _tappable(c):
			var wpx := gr.size.x * _factor
			var hpx := gr.size.y * _factor
			if minf(wpx, hpx) < MIN_TARGET - 0.5:
				r["small"].append("%s %s is %dx%d px" % [_path(c, scene), _label_of(c).left(30), int(round(wpx)), int(round(hpx))])
	for ch in node.get_children():
		_walk(ch, scene, scrolls, r)


func _measure(scene: Node) -> Dictionary:
	var r := {"built": true, "min_font": 999.0, "min_font_node": "", "offscreen": [], "clipped": [], "small": []}
	_walk(scene, scene, false, r)
	if float(r["min_font"]) > 998.0:
		r["min_font"] = 0.0
	var out := {"built": true, "min_font": r["min_font"], "min_font_node": r["min_font_node"]}
	for k in ["offscreen", "clipped", "small"]:
		var arr: Array = r[k]
		out[k] = arr.size()
		out[k + "_examples"] = arr.slice(0, EXAMPLES)
	return out


func _record(key: String, scene: Node) -> void:
	await _frames(10)
	var m := _measure(scene)
	_results[key] = m
	print("SWEEP %s | min font %.1f px | off screen %d | clipped %d | small targets %d" % [
			key, float(m["min_font"]), int(m["offscreen"]), int(m["clipped"]), int(m["small"])])


func _open(key: String, path: String) -> Node:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	await _record(key, scene)
	return scene


func _close(scene: Node) -> void:
	if scene != null:
		scene.queue_free()
	await _frames(3)


func _fail(key: String, why: String) -> void:
	_results[key] = {"built": false, "error": why}
	print("SWEEP %s | did not build: %s" % [key, why])


# --- the run ---------------------------------------------------------------

func _career(start := true) -> void:
	_state.reset()
	_state.career_seed = SEED
	_state.replay_seed = SEED
	for k in ["seen_training_intro", "seen_weekly_loop_intro", "seen_season_stats_intro"]:
		_state.set_setting(k, true)
	if start:
		_state.start_season(CLUB, _db.club_list(CLUB))


func _run() -> void:
	var out := "sweep.json"
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		if str(cli[i]) == "--out":
			out = str(cli[i + 1])
		if str(cli[i]) == "--size":
			var wh := str(cli[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	_state = root.get_node("GameState")
	_db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	_state.autosave_enabled = false
	_state.save_path = "user://sweep.save"
	_state.settings_path = "user://sweep.cfg"
	UK.apply_appearance("dark")
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	# ScreenLayout sets the logical size from the window on a resize.
	await _frames(10)
	_vr = root.get_visible_rect()
	_factor = float(W) / maxf(1.0, _vr.size.x)
	print("SWEEP window %dx%d, %dx%d UI units, %.3f px per unit" % [W, H, int(_vr.size.x), int(_vr.size.y), _factor])
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Fresh state: the front door and the club forge.
	_career(false)
	var scene: Node = await _open("main", "res://scenes/Main.tscn")
	await _close(scene)
	scene = await _open("forge", "res://scenes/ClubForgeScene.tscn")
	await _close(scene)

	# The League Draft, a club chosen.
	_career(false)
	_state.draft = load("res://scripts/sim/Draft.gd").new(_db.all_players_sorted(), _db.active_clubs(2026).duplicate(), 12345)
	scene = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(scene)
	scene.call("_on_club_chosen", CLUB)
	await _record("draft", scene)
	await _close(scene)

	# The weekly screens on one seeded Melbourne career.
	_career(true)
	for key in ["hub", "selection", "training", "list", "coaching", "staff", "stats"]:
		scene = await _open(key, root.get_node("Router").SCENES[key])
		await _close(scene)

	# The live match, at the pre-bounce box.
	if _state.prepare_interactive_match():
		scene = await _open("match", "res://scenes/MatchScene.tscn")
		await _close(scene)
	else:
		_fail("match", "no match to prepare")

	# The pre-season stops (behind a switch that ships off).
	load("res://scripts/core/Features.gd").set_on("preseason", true)
	_career(true)
	_state.open_preseason()
	scene = await _open("preseason", "res://scenes/PreSeasonScene.tscn")
	await _close(scene)
	load("res://scripts/core/Features.gd").set_on("preseason", false)

	# The season played out: its review, then the off-season.
	_career(true)
	var guard := 0
	while not _state.season.is_season_over() and guard < 60:
		guard += 1
		_state.advance()
	if _state.season.is_season_over():
		scene = await _open("season_review", "res://scenes/SeasonReviewScene.tscn")
		await _close(scene)
		_state.open_offseason()
		scene = await _open("offseason", "res://scenes/OffseasonScene.tscn")
		await _close(scene)
	else:
		_fail("season_review", "the season did not finish")
		_fail("offseason", "the season did not finish")

	var data := {"size": "%dx%d" % [W, H], "units": "%dx%d" % [int(_vr.size.x), int(_vr.size.y)],
			"px_per_unit": snappedf(_factor, 0.001), "screens": _results}
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		push_error("could not write " + out)
		quit(1)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("wrote ", out)
	quit(0)
