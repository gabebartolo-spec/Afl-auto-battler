extends SceneTree
## Visual review tool for the centre-bounce scene (StoppageVignette). Needs a
## real renderer, so run it under a virtual display, e.g.:
##   xvfb-run -a -s "-screen 0 1280x900x24" godot --path . --rendering-driver opengl3 \
##       --script tools/visual/capture_vignette.gd -- --out /tmp/vignette
## --seed N: seed the random numbers first, so two captures (before and after a change) stage
## the same match - opponent, weather, players.
## --window WxH: a desktop window of that many pixels (e.g. 1920x1080) instead of the phone.
## Writes <out>_sheet.png: the scene at its beats on a phone, then the call.
## --film START END: also writes <out>_film_NNN.png, 12 frames a second from START
## to END seconds, for checking motion (turn them into a GIF to review).
## --kit-options: shows the kit options - long sleeves on every one of your players,
## hooped socks on the other side's kit.
## It stages a tight last-quarter centre bounce on a live match and lets
## MatchSim ask the call; nothing it draws changes the sim.

var W := 390
var H := 844
const BEATS := [0.15, 0.9, 1.8, 2.6, 3.3, 3.8]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/vignette"
	var film := []
	var msaa := false
	var a := OS.get_cmdline_user_args()
	var kit_options := a.has("--kit-options")
	for i in range(a.size() - 1):
		if str(a[i]) == "--seed":
			seed(int(a[i + 1]))
		if str(a[i]) == "--window":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		elif str(a[i]) == "--msaa":
			msaa = true
		elif str(a[i]) == "--film" and i + 2 < a.size():
			film = [float(a[i + 1]), float(a[i + 2])]
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.prepare_interactive_match()
	var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	for i in range(6):
		await process_frame
	m.find_child("StartQuarter", true, false).emit_signal("pressed")
	for i in range(6):
		await process_frame
	m.get("_pitch").pause()
	var sim = state.pending_sim
	var me := int(m.get("_my_side"))
	sim.pending_moment = {}
	sim.moment_side = me
	sim.current_quarter = 4
	sim.current_minute = 106
	sim.at_centre = true
	sim.set("_moments_this_q", 0)
	sim.set("_last_moment_chain", -1000)
	sim.set("_run", [0, 0])
	for side in range(2):
		sim.team_stats[side]["goals"] = 9.0 + side
		sim.team_stats[side]["behinds"] = 8.0
		for p in sim.squads[side].ground:
			sim.energy[str(p["id"])] = 90.0
	sim.team_stats[me]["clearances"] = 5.0
	sim.team_stats[1 - me]["clearances"] = 12.0
	var mids: Array = sim.squads[1 - me].ground.filter(func(p): return str(p["role"]) == "MID")
	sim.energy[str(mids[1]["id"])] = 30.0
	sim.call("_boundary_moment")
	m.call("_show_moment")
	var vig = m.find_child("StoppageVignette", true, false)
	vig.set_process(false)
	if kit_options:
		# Long sleeves are a player's own (his look); hoops are the kit's.
		for t in vig.tokens:
			if bool(t["mine"]):
				t["look"]["long_sleeves"] = true
		var kits: Array = []
		for i in range((vig.get("_kits") as Array).size()):
			var k: Dictionary = (vig.get("_kits")[i] as Dictionary).duplicate()
			if i == 1:
				k["sock_hoops"] = 2
			kits.append(k)
		vig.material = vig.figure_material(kits + [vig.UMPIRE_GEAR], vig.material)
	if not film.is_empty():
		var n := 0
		var ft: float = film[0]
		while ft <= float(film[1]) + 0.001:
			vig.set("_t", ft)
			vig.queue_redraw()
			for i in range(2):
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s_film_%03d.png" % [out, n])
			n += 1
			ft += 1.0 / 12.0
		print("filmed ", n, " frames")
	var shots := []
	if msaa:
		root.msaa_2d = Viewport.MSAA_DISABLED
	for t in BEATS:
		vig.set("_t", t)
		if t >= 3.8:
			vig.set_process(true)
			vig.finish_now()
			for i in range(40):
				await process_frame
		vig.queue_redraw()
		for i in range(3):
			await process_frame
		shots.append(root.get_viewport().get_texture().get_image())
		if msaa:
			# The same frozen frame with 2D MSAA 2x, for an exact A/B.
			vig.set_process(false)
			root.msaa_2d = Viewport.MSAA_2X
			vig.queue_redraw()
			for i in range(3):
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s_beat%d_2x.png" % [out, shots.size() - 1])
			if shots.size() == 2:
				# Render time of this frame, MSAA off against 2x.
				var vp := root.get_viewport_rid()
				RenderingServer.viewport_set_measure_render_time(vp, true)
				for mode in [Viewport.MSAA_DISABLED, Viewport.MSAA_2X]:
					root.msaa_2d = mode
					var gpu := 0.0
					for f in range(200):
						vig.queue_redraw()
						await process_frame
						gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
					print("VIG_TIME msaa %s | gpu %.3f ms (mean of 200 frames)" % ["2x" if mode == Viewport.MSAA_2X else "off", gpu / 200.0])
			(shots[shots.size() - 1] as Image).save_png("%s_beat%d_off.png" % [out, shots.size() - 1])
			root.msaa_2d = Viewport.MSAA_DISABLED
			vig.set_process(t >= 3.8)
	var sheet := Image.create(W * 3, H * 2, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		var img: Image = shots[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((i % 3) * W, (i / 3) * H))
	sheet.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
