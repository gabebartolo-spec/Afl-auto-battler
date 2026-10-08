extends SceneTree
## Every club's guernsey badge, big, on one sheet for checking against the real
## kits. Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_guernseys.gd -- --out PATH.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "guernseys.png"
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		if str(cli[i]) == "--out":
			out = str(cli[i + 1])
	await process_frame
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	root.size = Vector2i(1200, 760)
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(20, 20)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	root.add_child(grid)
	for code in db.CLUB_ORDER:
		if not db.clubs.has(code):
			continue
		var v := VBoxContainer.new()
		var c := CenterContainer.new()
		c.add_child(UK.club_marker(code, 130.0))
		v.add_child(c)
		var l := Label.new()
		l.text = code
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		grid.add_child(v)
	for i in range(8):
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
