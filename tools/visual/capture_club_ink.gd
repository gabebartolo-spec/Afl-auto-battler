extends SceneTree
## Swatch board of every club's ink on the dark ground: guernsey marker, the
## club's name in club_ink, its 4 px bar, the two hand-picked inks as
## swatches with hex and contrast. One image, <out>.png:
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
	# Drawn into its own viewport, so the board is the same size whatever the
	# window (or the runner's screen) is: nothing cropped.
	var vp := SubViewport.new()
	vp.size = Vector2i(1360, 500)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = UK.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(24, 20)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	vp.add_child(grid)
	var codes: Array = db.clubs.keys()
	codes.sort()
	for code in codes:
		var c := str(code)
		var ink: Color = UK.club_ink(c)
		var wrap: HBoxContainer = UK.hbox(8)
		wrap.custom_minimum_size = Vector2(620, 40)
		var bar := ColorRect.new()
		bar.color = ink
		bar.custom_minimum_size = Vector2(4, 34)
		wrap.add_child(bar)
		wrap.add_child(UK.club_marker(c, 30.0))
		# The name as the game shows it: the ink, or bold white for a red club.
		var nm: Label = UK.ellipsis(db.club_name(c), 18, UK.club_name_colour(ink), true)
		nm.custom_minimum_size.x = 190
		wrap.add_child(nm)
		for which in [0, 1]:
			var col: Color = UK.club_ink(c) if which == 0 else UK.club_ink_second(c)
			var sw := ColorRect.new()
			sw.color = col
			sw.custom_minimum_size = Vector2(22, 22)
			var sw_box: VBoxContainer = UK.vbox(0)
			sw_box.alignment = BoxContainer.ALIGNMENT_CENTER
			sw_box.add_child(sw)
			wrap.add_child(sw_box)
			var t: Label = UK.lbl("%s #%s  %.1f:1" % ["first" if which == 0 else "second", col.to_html(false), UK.contrast(col, UK.PANEL)], 13, UK.TEXT)
			t.autowrap_mode = TextServer.AUTOWRAP_OFF
			t.custom_minimum_size.x = 135
			wrap.add_child(t)
		grid.add_child(wrap)
	for i in range(8):
		await process_frame
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + ".png")
	print("wrote ", out, ".png")
	quit()
