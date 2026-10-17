extends SceneTree
## The Finals bracket (FinalsBracket), for the director's look. Needs a real
## renderer:
##   godot --path . --script tools/visual/capture_finals.gd -- --out /tmp/fin
##       [--size 1280x720] [--week 3] [--club COL] [--premier FRE]
## Plays a seeded season to finals week --week (6 = after the Grand Final)
## and writes <out>.png. --premier shows that club as the premier for the
## look: it trades places with the club that won, everywhere in the series
## (this capture only; nothing is saved). On the CI workflow a phone also
## needs -f resolution=390x844.

var W := 1280
var H := 720


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/fin"
	var week := 3
	var club := "COL"
	var premier := ""
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var v := str(a[i + 1]) if i + 1 < a.size() else ""
		match str(a[i]):
			"--out": out = v
			"--size":
				W = int(v.split("x")[0])
				H = int(v.split("x")[1])
			"--week": week = int(v)
			"--club": club = v
			"--premier": premier = v
	await process_frame
	var db = root.get_node("GameDB")
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	gs.career_seed = 7
	gs.replay_seed = 7
	gs.start_season(club, db.club_list(club))
	var guard := 0
	while guard < 400:
		guard += 1
		var f: Dictionary = gs.season.finals
		if gs.season.is_season_over() or (not f.is_empty() and int(f.get("week", 1)) >= week):
			break
		gs.advance()
	var won := str(gs.season.finals.get("premier", ""))
	if premier != "" and won != "" and premier != won:
		gs.season.finals = _swap(gs.season.finals, won, premier)
	# The canvas a player's screen gives the game, whatever this machine's display density.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(W, H))
	for i in range(10):
		await process_frame
	var layout = root.get_node("ScreenLayout")
	var density: float = layout.desktop_density(Vector2(root.size), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0)
	layout.ui_scale = 1.0 / maxf(1.0, density)
	layout._update_scale()
	for i in range(10):
		await process_frame
	print("canvas ", root.get_visible_rect().size)
	var kit = load("res://scripts/ui/UiKit.gd")
	var bg := ColorRect.new()
	bg.color = kit.BG
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := MarginContainer.new()
	for e in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + e, 16)
	bg.add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	m.add_child(v)
	v.add_child(kit.heading("Finals", kit.TITLE))
	var fb = load("res://scripts/ui/FinalsBracket.gd").new()
	v.add_child(fb)
	fb.setup(gs.season, gs.my_club)
	for i in range(12):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + ".png")
	print("wrote ", out + ".png", " finals week ", gs.season.finals.get("week", 0), " done ", gs.season.is_season_over())
	quit()


## `v` with the two club codes trading places wherever they appear.
func _swap(v, a: String, b: String):
	if v is String:
		return b if v == a else (a if v == b else v)
	if v is Array:
		var out := []
		for x in v:
			out.append(_swap(x, a, b))
		return out
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _swap(v[k], a, b)
		return d
	return v
