extends SceneTree
## The Settings sheet from the hub, scrolled to the Vignettes row (ROADMAP §1.11),
## for the director's look. Needs a real renderer; capture.yml runs it:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_options \
##       -f args="--size 390x844"
## Writes <out>.png (the sheet as it opens) and <out>_vignettes.png (scrolled
## so the Vignettes row is in view, set to Off).
##   --size WxH   window size (default 390x844)    --light   light appearance

var _w := 390
var _h := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "options"
	var mode := "dark"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
			"--light":
				mode = "light"
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_options.save"
	state.settings_path = "user://capture_options.cfg"
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	state.set_vignettes_on(false)
	load("res://scripts/ui/UiKit.gd").apply_appearance(mode)
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	state.start_season("COL", db.club_list("COL"))
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _frames(10)
	var sheet: Control = load("res://scripts/ui/OptionsSheet.gd").open(hub, true)
	await _frames(10)
	_save(out + ".png")
	var row: Control = sheet.find_child("SettingsVignettes", true, false)
	var p := row.get_parent() if row != null else null
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p != null:
		(p as ScrollContainer).ensure_control_visible(row)
		await _frames(6)
	_save(out + "_vignettes.png")
	state.set_vignettes_on(true)
	quit()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(path) != OK:
		push_error("could not save " + path)
	print("wrote ", path)
