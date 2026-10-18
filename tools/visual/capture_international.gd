extends SceneTree
## An international prospect in the National Draft pool and on his profile.
## Needs a real renderer (godot_quiet.sh --render):
##   godot --path . --script tools/visual/capture_international.gd -- --out /tmp/intl --size 390x844 [--club FRE] [--country IRL]
## Writes <out>_pool.png and <out>_profile.png.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/intl"
	var club := "FRE"
	var country := ""
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		if str(a[i]) == "--out" and i + 1 < a.size():
			out = str(a[i + 1])
		if str(a[i]) == "--club" and i + 1 < a.size():
			club = str(a[i + 1])
		if str(a[i]) == "--country" and i + 1 < a.size():
			country = str(a[i + 1])
		if str(a[i]) == "--size" and i + 1 < a.size():
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var features = load("res://scripts/core/Features.gd")
	features.set_on("international_prospects", true)
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.show_real_names = false
	state.replay_seed = 2027
	state.reset()
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season(club, db.club_list(club))
	var who := {}
	for p in state.draftee_pool:
		if p.has("intl") and (country == "" or str(p["intl"]) == country):
			who = p
	if who.is_empty() and country != "":
		# The first class has only some countries: borrow one from a later class
		# (a capture aid; he is dressed as a 2027 prospect, not a drafted one).
		for y in range(2028, 2090):
			for q in load("res://scripts/sim/Prospects.gd").generate_class(y, 2027):
				if str(q.get("intl", "")) == country and who.is_empty():
					who = q
		if not who.is_empty():
			who["draft_year"] = 2027
			who["id"] = "D2027_X1"
			who["draft_rank"] = 22
			state.draftee_pool.append(who)
			db.register_draftees([who])
	if who.is_empty():
		print("no international of that country")
		quit(1)
		return
	state.season.round_index = state.season.fixture.size()
	state.begin_intake_draft()
	var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
	root.add_child(ui)
	for i in range(8):
		await process_frame
	var done: Button = ui.find_child("MeetingDone", true, false)
	if done != null:
		done.pressed.emit()
	for i in range(4):
		await process_frame
	var tab_pool: Button = ui.find_child("Tab_pool", true, false)
	if tab_pool != null:
		tab_pool.pressed.emit()
	for i in range(4):
		await process_frame
	var field: LineEdit = ui.find_child("PlayerSearch", true, false)
	var shown: String = db.player_display_name(who)
	field.text = shown
	field.text_changed.emit(shown)
	for i in range(40):
		await process_frame
	var row: Control = ui.find_child("Player_" + str(who["id"]), true, false)
	if row != null:
		var n: Node = row.get_parent()
		while n != null and not (n is ScrollContainer):
			n = n.get_parent()
		if n != null:
			(n as ScrollContainer).ensure_control_visible(row)
		for i in range(6):
			await process_frame
	print("INTL ", shown, " ", who["intl"], " ", who["role"], " ", who["draft_rank"])
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + "_pool.png")
	ui.call("_open_player", str(who["id"]))
	for i in range(10):
		await process_frame
	img = root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + "_profile.png")
	print("wrote ", out)
	quit(0)
