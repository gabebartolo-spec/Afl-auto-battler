extends SceneTree
## PitchView's edges with antialiasing off and on (ARD backlog item 22), in
## one build: the same match frame both ways, a 3x crop of the same corner,
## and the render time of each. Presentation only; the sim is untouched.
##   godot --path . --rendering-driver opengl3 --script tools/visual/capture_pitch_aa.gd -- --out /tmp/aa
## Writes <out>_off.png, <out>_on.png and <out>_crops.png, and prints
## AA_TIME lines (mean CPU and GPU render ms over --frames, default 300).
##   --seed N (default 42)   --kind K (default goal): the frame is just before it
##   --w W --h H (default 412 x 915, a phone in portrait)

func _initialize() -> void:
	_run.call_deferred()


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var k := str(a[i])
		if k.begins_with("--"):
			out[k.substr(2)] = str(a[i + 1]) if i + 1 < a.size() and not str(a[i + 1]).begins_with("--") else ""
	return out


func _run() -> void:
	await process_frame
	var args := _args()
	var w := int(args.get("w", "412"))
	var h := int(args.get("h", "915"))
	var db = root.get_node("GameDB")
	var squad_script = load("res://scripts/sim/Squad.gd")
	var sim = load("res://scripts/sim/MatchSim.gd").new(
			squad_script.new("GEE", db.club_list("GEE"), true, "GEE"),
			squad_script.new("COL", db.club_list("COL"), false, "COL"), int(args.get("seed", "42")))
	var res: Dictionary = sim.run()
	res["home"] = "GEE"
	res["away"] = "COL"
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(root.size)
	var pitch = load("res://scripts/ui/PitchView.gd").new()
	pitch.size = Vector2(w, h)
	root.add_child(pitch)
	await process_frame
	pitch.setup(res)
	pitch.play()
	pitch.set_process(false)
	var target := 0
	for i in range(res["events"].size()):
		if str(res["events"][i]["kind"]) == str(args.get("kind", "goal")):
			target = maxi(0, i - 2)
			break
	var guard := 0
	while pitch.current_index() < target and guard < 200000:
		pitch._process(1.0 / 60.0)
		guard += 1
	var out := str(args.get("out", "/tmp/aa"))
	var frames := int(args.get("frames", "300"))
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var shots := {}
	for mode in ["off", "on"]:
		pitch.antialias = mode == "on"
		pitch.queue_redraw()
		await process_frame
		await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [out, mode])
		shots[mode] = img
		var cpu := 0.0
		var gpu := 0.0
		for f in range(frames):
			pitch.queue_redraw()
			await process_frame
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		print("AA_TIME %s | cpu %.3f ms gpu %.3f ms (mean of %d frames, %dx%d)" % [mode, cpu / frames, gpu / frames, frames, w, h])
	# The same corner of each, 3x with nearest-neighbour, side by side.
	var cw := w / 3
	var ch := h / 4
	var crops := Image.create(cw * 3 * 2 + 8, ch * 3, false, Image.FORMAT_RGBA8)
	crops.fill(Color(0, 0, 0))
	var x := 0
	for mode in ["off", "on"]:
		var src: Image = shots[mode]
		src.convert(Image.FORMAT_RGBA8)
		var c := src.get_region(Rect2i(w / 3, h / 3, cw, ch))
		c.resize(cw * 3, ch * 3, Image.INTERPOLATE_NEAREST)
		crops.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i(x, 0))
		x += cw * 3 + 8
	crops.save_png(out + "_crops.png")
	quit(0)
