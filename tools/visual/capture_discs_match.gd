extends SceneTree
## godot --render --path . --script tools/visual/capture_discs_match.gd -- OUTDIR
## The oval at phone (390x844) and PC (1280x720) size for the pairs the director
## looked at (2026-10-14): a seeded match played on to a busy frame, every
## player ringed so every name is up, saved as discs_<home>_<away>_<size>.png.

const PAIRS := [["ADE", "MEL"], ["MEL", "ADE"], ["HAW", "WCE"], ["RIC", "GCS"], ["SYD", "STK"]]
const SIZES := {"phone": Vector2i(390, 640), "pc": Vector2i(1280, 720)}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var PV = load("res://scripts/ui/PitchView.gd")
	var Squad_ = load("res://scripts/sim/Squad.gd")
	var Sim = load("res://scripts/sim/MatchSim.gd")
	var gdb = root.get_node("GameDB")
	for pair in PAIRS:
		var h: String = pair[0]
		var a: String = pair[1]
		var res: Dictionary = Sim.new(Squad_.new(h, gdb.club_list(h), true, h), Squad_.new(a, gdb.club_list(a), false, a), 31).run()
		res["home"] = h
		res["away"] = a
		for sz in SIZES:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			root.size = SIZES[sz]
			var pv = PV.new()
			pv.size = Vector2(SIZES[sz])
			root.add_child(pv)
			pv.setup(res)
			var ringed := {}
			# As a real match: three of your players ringed (a call or a promised run).
			for t in pv.director.tokens:
				if ringed.size() < 3:
					ringed[str(t.get("pid", ""))] = true
			pv.rings = ringed
			pv.set_speed(4.0)
			pv.play()
			for i in range(500):
				pv._process(1.0 / 30.0)
			for i in range(5):
				pv.queue_redraw()
				await process_frame
			var img := root.get_viewport().get_texture().get_image()
			var path: String = out.path_join("discs_%s_%s_%s.png" % [h, a, sz])
			print("saved ", path, " ", img.save_png(path))
			pv.queue_free()
	quit(0)
