extends SceneTree
## Visual review tool for the milestone farewell (FarewellVignette, FL-007): the guard
## of honour and chaired off, on a phone. Needs a real renderer (capture.yml runs it).
##   godot --path . --script tools/visual/capture_farewell.gd -- --out /tmp/farewell
## Writes <out>_sheet.png (six beats). --movie: also <out>_fNNNN.png, the whole scene at
## 30 frames a second, which capture.yml turns into an MP4.
## --games N: his Nth game (200 by default); --farewell: his last game instead.
## --home CODE / --opp CODE: the clubs (Collingwood v Geelong by default).
## --scale N: render the same 390x844-point phone at N times the pixels (3 = a real phone's
## 1170x2532), so a review sees what the device shows, not a third of it.
## Prints ART lines: the figure sheet's size and, for every move the scene drew, its
## strip and the frames asked for - proof the new moves came from the sheet.

const W := 390
const H := 844
const BEATS := [0.4, 1.4, 2.6, 3.6, 4.6, 5.8]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/farewell"
	var a := OS.get_cmdline_user_args()
	var movie := a.has("--movie")
	var me := "COL"
	var opp := "GEE"
	var games := 200
	var scale := 1
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--home":
			me = str(a[i + 1])
		if str(a[i]) == "--opp":
			opp = str(a[i + 1])
		if str(a[i]) == "--games":
			games = int(a[i + 1])
		if str(a[i]) == "--scale":
			scale = maxi(1, int(a[i + 1]))
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.start_season(me, db.club_list(me))
	root.size = Vector2i(W * scale, H * scale)
	DisplayServer.window_set_size(Vector2i(W * scale, H * scale))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(W, H)
	var mine: Array = state.my_squad().ground + state.my_squad().bench
	var osq = load("res://scripts/sim/Squad.gd").new(opp, state.season.lists[opp], false, opp)
	var theirs: Array = osq.ground + osq.bench
	var man: Dictionary = mine[0]
	var name: String = db.player_display_name(man)
	var ms := {"player": name.split(" ")[-1], "name": name, "id": str(man.get("id", "")),
			"games": "farewell" if a.has("--farewell") else games}
	var Farewell = load("res://scripts/ui/match/FarewellVignette.gd")
	print("ART sheet ", load("res://scripts/ui/match/VignetteFigures.gd").SHEET_SIZE, " caption: ", Farewell.caption(ms))
	var Stoppage = load("res://scripts/ui/match/StoppageVignette.gd")
	Stoppage.log_frames = true
	Stoppage.frame_log.clear()
	var vig = Farewell.open(root, ms, man, me, opp, mine, theirs, "Full time")
	vig.set_process(false)
	var shots := []
	for t in BEATS:
		vig.set("_t", t)
		vig.queue_redraw()
		for i in range(3):
			await process_frame
		shots.append(root.get_viewport().get_texture().get_image())
	var sw := W * scale
	var shh := H * scale
	var sheet := Image.create(sw * 3, shh * 2, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		var img: Image = shots[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, sw, shh), Vector2i((i % 3) * sw, (i / 3) * shh))
	sheet.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	# Every move it drew, from the sheet: the strip's frame count and the frames wanted.
	var seen := {}
	for e in Stoppage.frame_log:
		var k := "%s/%s" % [e["anim"], e["facing"]]
		if not seen.has(k):
			seen[k] = {"frames": int(e["frames"]), "max_wanted": 0}
		seen[k]["max_wanted"] = maxi(int(seen[k]["max_wanted"]), int(e["wanted"]))
	for k in seen:
		print("ART ", k, " frames ", seen[k]["frames"], " max wanted ", seen[k]["max_wanted"])
	if movie:
		var n := 0
		var t := 0.0
		while t < Farewell.END:
			vig.set("_t", t)
			vig.queue_redraw()
			for i in range(2):
				await process_frame
			var img: Image = root.get_viewport().get_texture().get_image()
			img.save_png("%s_f%04d.png" % [out, n])
			n += 1
			t += 1.0 / 30.0
		print("filmed ", n)
	quit(0)
