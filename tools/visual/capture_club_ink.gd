extends SceneTree
## Swatch board of every club's ink on the dark ground: guernsey marker, the
## club's name in club_ink, its 4 px bar, the contrast ratio, and the raw
## primary colour beside it for comparison. One image, <out>.png:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_club_ink
##   --light   the light ground

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "club_ink"
	var mode := "dark"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--light":
				mode = "light"
	await process_frame
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	UK.apply_appearance(mode)
	root.size = Vector2i(1100, 640)
	DisplayServer.window_set_size(Vector2i(1100, 640))
	var bg := ColorRect.new()
	bg.color = UK.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(24, 20)
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	root.add_child(grid)
	var codes: Array = db.clubs.keys()
	codes.sort()
	for code in codes:
		var c := str(code)
		var ink: Color = UK.club_ink(c)
		var wrap := UK.hbox(8)
		wrap.custom_minimum_size = Vector2(500, 52)
		var bar := ColorRect.new()
		bar.color = ink
		bar.custom_minimum_size = Vector2(4, 0)
		wrap.add_child(bar)
		var mk: Control = UK.club_marker(c, 30.0)
		wrap.add_child(mk)
		var nm := UK.ellipsis(db.club_name(c), 18, ink, true)
		nm.custom_minimum_size.x = 220
		wrap.add_child(nm)
		wrap.add_child(UK.lbl("%.1f:1" % UK.contrast(ink, UK.PANEL), 14, UK.TEXT))
		var raw: Color = db.club_colours(c)[int(UK.INK_SLOT.get(c, 0))] if int(UK.INK_SLOT.get(c, 0)) >= 0 else UK.TEXT
		var sw := ColorRect.new()
		sw.color = raw
		sw.custom_minimum_size = Vector2(22, 22)
		var sw_box := UK.vbox(0)
		sw_box.alignment = BoxContainer.ALIGNMENT_CENTER
		sw_box.add_child(sw)
		wrap.add_child(sw_box)
		wrap.add_child(UK.lbl("primary #%s" % raw.to_html(false), 12, UK.MUTED))
		grid.add_child(wrap)
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + ".png")
	print("wrote ", out, ".png")
	quit()
