extends SceneTree
## Visual review tool for the live match view (PitchView). Needs a real
## renderer, so run it under a virtual display, e.g.:
##   xvfb-run -a -s "-screen 0 1280x900x24" godot --path . --rendering-driver opengl3 \
##       --script tools/visual/capture_match.gd -- --seed 42 --from 0 --out /tmp/cap
## Writes <out>_sheet.png (consecutive frames) and <out>_trails.png (every
## token's path and the ball's path over the same window). Presentation only:
## it plays a MatchSim result through PitchView and never touches the sim.
##
##   --seed N        MatchSim seed (default 42)          --home/--away CODE (GEE v COL)
##   --from N        start at event index N (skipped instantly)
##   --secs S        window length in 1x seconds (default 3)
##   --frames N      frames in the sheet (default 12)    --speed S (default 1)
##   --kind K [--nth N] [--lead L]  start L events before the N-th event of kind K
##   --nocam         whole oval, no camera (trails are in screen space)

const W := 900
const H := 700


func _initialize() -> void:
	_run.call_deferred()


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := str(a[i])
		if k.begins_with("--"):
			var v := ""
			if i + 1 < a.size() and not str(a[i + 1]).begins_with("--"):
				v = str(a[i + 1])
				i += 1
			out[k.substr(2)] = v
		i += 1
	return out


func _run() -> void:
	await process_frame
	var args := _args()
	var db = root.get_node("GameDB")
	var home_code := str(args.get("home", "GEE"))
	var away_code := str(args.get("away", "COL"))
	var squad_script = load("res://scripts/sim/Squad.gd")
	var sim_script = load("res://scripts/sim/MatchSim.gd")
	var sim = sim_script.new(squad_script.new(home_code, db.club_list(home_code), true, home_code),
			squad_script.new(away_code, db.club_list(away_code), false, away_code),
			int(args.get("seed", "42")))
	var res: Dictionary = sim.run()
	res["home"] = home_code
	res["away"] = away_code

	root.size = Vector2i(W, H)
	var pitch = load("res://scripts/ui/PitchView.gd").new()
	pitch.position = Vector2.ZERO
	pitch.size = Vector2(W, H)
	root.add_child(pitch)
	var overlay = load("res://tools/visual/trail_overlay.gd").new()
	overlay.size = Vector2(W, H)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	await process_frame
	pitch.camera_enabled = not args.has("nocam")
	pitch.setup(res)
	pitch.set_speed(float(args.get("speed", "1")))
	pitch.play()
	pitch.set_process(false)

	var dt := 1.0 / 60.0
	var from := int(args.get("from", "0"))
	if args.has("kind"):
		# Start a few events before the n-th event of this kind.
		var seen := 0
		for i in range(res["events"].size()):
			if str(res["events"][i]["kind"]) == str(args["kind"]):
				seen += 1
				if seen == int(args.get("nth", "1")):
					from = maxi(0, i - int(args.get("lead", "3")))
					break
	var guard := 0
	while pitch.current_index() < from and guard < 200000:
		pitch._process(dt)
		guard += 1
	var secs := float(args.get("secs", "3"))
	var frames := int(args.get("frames", "12"))
	var steps := int(round(secs / dt / float(pitch.speed)))
	var every := maxi(1, steps / maxi(1, frames))
	var out := str(args.get("out", "/tmp/cap"))

	var tiles: Array = []
	var paths := {}       # key -> Array of Vector2
	var colours := {}
	var events_seen: Array = []
	var start_idx: int = pitch.current_index()
	for s in range(steps):
		pitch._process(dt)
		var snap: Dictionary = _snapshot(pitch)
		for p in snap["players"]:
			var key := "%d_%d" % [int(p["side"]), int(p["i"])]
			if not paths.has(key):
				paths[key] = []
				colours[key] = Color(1.0, 0.85, 0.2, 0.9) if int(p["side"]) == 0 else Color(0.4, 0.8, 1.0, 0.9)
			(paths[key] as Array).append(p["pos"])
		if not paths.has("ball"):
			paths["ball"] = []
			colours["ball"] = Color(1, 1, 1, 1)
		(paths["ball"] as Array).append(snap["ball"])
		if s % every == 0 and tiles.size() < frames:
			pitch.queue_redraw()
			await process_frame
			await process_frame
			var img: Image = root.get_viewport().get_texture().get_image()
			img.resize(W / 3, H / 3, Image.INTERPOLATE_BILINEAR)
			tiles.append(img)
	for i in range(start_idx, pitch.current_index()):
		var ev: Dictionary = pitch.events[i]
		events_seen.append("%s:%s" % [str(ev.get("kind", "")), str(ev.get("name", ""))])

	# Contact sheet: 4 columns.
	var cols := 4
	var rows := int(ceil(float(tiles.size()) / float(cols)))
	var sheet := Image.create(cols * (W / 3), rows * (H / 3), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0))
	for i in range(tiles.size()):
		var t: Image = tiles[i]
		t.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()),
				Vector2i((i % cols) * (W / 3), (i / cols) * (H / 3)))
	sheet.save_png(out + "_sheet.png")

	# Trails over the final frame.
	var trails: Array = []
	for key in paths:
		trails.append({"points": PackedVector2Array(paths[key]), "colour": colours[key],
				"width": 2.5 if key == "ball" else 1.4})
	overlay.trails = trails
	overlay.queue_redraw()
	pitch.queue_redraw()
	await process_frame
	await process_frame
	var trail_img: Image = root.get_viewport().get_texture().get_image()
	trail_img.save_png(out + "_trails.png")
	print("CAPTURE events %d..%d: %s" % [start_idx, pitch.current_index(), ", ".join(events_seen)])
	quit(0)


## Token and ball positions in pixels.
func _snapshot(pitch) -> Dictionary:
	var snap: Dictionary = pitch.debug_snapshot()
	var players := []
	var screen: Array = snap["screen"]
	for i in range(screen.size()):
		players.append({"side": int(snap["tokens"][i]["side"]), "i": i, "pos": screen[i]})
	return {"players": players, "ball": snap["ball_screen"]}
