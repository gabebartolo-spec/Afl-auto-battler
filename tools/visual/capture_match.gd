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
##   --skip S        then play on S more 1x seconds before the window opens
##   --nocam         whole oval, no camera (trails are in screen space)
##   --upright       the phone's view (#724): the ground upright, goals at the top
##                   and bottom, the whole oval in frame, no camera; size the window
##                   390x844 and place it with --rect as the match screen does
##   --rect X,Y,W,H  the oval's rect in the window's UI units (default: all of it)
##   --call KEY      shoot, pass or bomb at every home set shot (live match)

##   --movie         also write every frame at 30 fps (<out>_f0000.png ...),
##                   for capture.yml to make <out>.mp4
##   --loose SIDE    that side plays its best interceptor loose
##   --tag SIDE      that side tags the other side's best midfielder
##   --flood SIDE    that side floods behind the ball all match (0 home, 1 away)
##   --press SIDE    that side plays the Defensive press all match (--balanced SIDE: Balanced)
##   --noshape       the sim keeps every call, the oval draws none of their shapes
##   --stack SIDE    that side stacks every centre ball-up
##   --plan SIDE:KEY that side plays the plan KEY all match (attacking, contest,
##                   controlled, through_stars, defensive, balanced)
##   --surge SIDE / --hold SIDE  that side throws numbers at it / slows it down
##                   (held on until the first break, as --flood)
##   --kside S       with --kind, only events by side S
##   --shake F       the turnover shake's size as a share of the oval's height
##   --movie also prints each frame's largest disc move (MOTION lines, metres,
##                   as drawn) and, over the window, the home side's shape from
##                   the drawn discs: its centroid and median player up the ground
##                   from the ball and from the away side's centroid, its spread
##                   across, and the most of its discs within 6 m of the ball
##                   (SHAPE lines; in possession, without it, at a stoppage)

## --size WxH: the window (default 900x700; 390x330 is the oval's share of a phone).
var W := 900
var H := 700


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
	if args.has("loose"):
		# --loose SIDE: that side plays its best interceptor loose.
		# Loaded, not named: a --script tool compiles before the autoloads exist.
		var ls := int(args["loose"])
		var best: Dictionary = load("res://scripts/sim/Matchups.gd").best_interceptor(sim.squads[ls].ground, 0.0)
		if not best.is_empty():
			sim.set_interceptor(ls, str(best["id"]), false)
	if args.has("tag"):
		# --tag SIDE: that side tags the other side's best midfielder.
		var ts := int(args["tag"])
		var mids: Array = (sim.squads[1 - ts].ground as Array).filter(func(p): return str(p["role"]) == "MID")
		mids.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
		if not mids.is_empty():
			sim.set_tactics(ts, {"gameplan": "balanced", "tag_id": str(mids[0]["id"])})

	if args.has("press") or args.has("balanced"):
		# --press SIDE / --balanced SIDE: that side plays the Defensive press
		# (or Balanced) all match, its plan held (no AI re-pick), for the
		# press pilot's before/after on the same seed.
		# --press both: both sides press (each side's line shows once).
		var press_arg := str(args.get("press", args.get("balanced", "0")))
		for ps in ([0, 1] if press_arg == "both" else [int(press_arg)]):
			(sim.squads[ps] as RefCounted).set("ai_plans", false)
			sim.set_tactics(ps, {"gameplan": "defensive" if args.has("press") else "balanced"})
	if args.has("flood"):
		# --flood SIDE: that side floods behind the ball all match (the
		# coach's "Flood behind the ball" call, held on), for the ARD-M8-003
		# demonstration against ordinary coverage on the same seed.
		(sim.bursts[int(args["flood"])] as Dictionary)["flood"] = 100000
	if args.has("plan"):
		# --plan SIDE:KEY: that side plays the plan all match, held (no AI re-pick).
		var pk := str(args["plan"]).split(":")
		if pk.size() == 2:
			(sim.squads[int(pk[0])] as RefCounted).set("ai_plans", false)
			sim.set_tactics(int(pk[0]), {"gameplan": str(pk[1])})
	for burst in ["surge", "hold"]:
		if args.has(burst):
			(sim.bursts[int(args[burst])] as Dictionary)[burst] = 100000
	if args.has("stack"):
		# --stack SIDE: that side stacks every centre ball-up (the attacking
		# setup, for the second demonstration).
		(sim.bursts[int(args["stack"])] as Dictionary)["stack"] = 100000
	load("res://scripts/ui/match/MatchDirector.gd").set("debug_no_press_shape", args.has("noshape"))
	var res: Dictionary
	var call := str(args.get("call", ""))
	if call == "":
		res = sim.run()
	else:
		# --call shoot|pass|bomb: the home coach makes that call at every
		# set shot (ARD-M4-013), so --kind pack / pass finds one.
		sim.moment_side = 0
		var guard := 0
		while sim.current_quarter <= 4 and guard < 8:
			guard += 1
			sim.begin_quarter()
			while not sim.continue_quarter():
				var m: Dictionary = sim.pending_moment
				var c := int(m.get("default", 0))
				if str(m["kind"]) == "set_shot":
					var opts: Array = m["options"]
					for j in range(opts.size()):
						if str((opts[j] as Dictionary).get("key", "")) == call:
							c = j
				sim.resolve_moment(c)
			sim.end_quarter()
		res = sim.result()
	res["home"] = home_code
	res["away"] = away_code

	if args.has("size"):
		var wh := str(args["size"]).split("x")
		W = int(wh[0])
		H = int(wh[1])
	root.size = Vector2i(W, H)
	await process_frame
	# The project stretches canvas items (base 1280x720), so the window's
	# canvas is not W x H units: fill what is actually visible.
	var vis: Vector2 = root.get_visible_rect().size
	var pitch = load("res://scripts/ui/PitchView.gd").new()
	pitch.position = Vector2.ZERO
	pitch.size = vis
	if args.has("rect"):
		# --rect X,Y,W,H: the oval where the match screen puts it, in the
		# window's UI units (390x844 phone: 10,112,300,387 of 320x693).
		var r := str(args["rect"]).split(",")
		pitch.position = Vector2(float(r[0]), float(r[1]))
		pitch.size = Vector2(float(r[2]), float(r[3]))
		print("CAPTURE oval in pixels %s" % str(Rect2(pitch.position, pitch.size).size * (Vector2(W, H) / vis)))
	root.add_child(pitch)
	var overlay = load("res://tools/visual/trail_overlay.gd").new()
	overlay.size = vis
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	await process_frame
	pitch.camera_enabled = not args.has("nocam") and not args.has("upright")
	pitch.upright = args.has("upright")
	if args.has("shake"):
		pitch.shake_share = float(args["shake"])
	pitch.setup(res)
	# --figures: the mini-figure prototype on (Settings > Match view), whatever the setting.
	pitch.mini_figures = args.has("figures")
	pitch.set_speed(float(args.get("speed", "1")))
	pitch.play()
	pitch.set_process(false)

	var dt := 1.0 / 60.0
	var from := int(args.get("from", "0"))
	if args.has("kind"):
		# Start a few events before the n-th event of this kind.
		var seen := 0
		for i in range(res["events"].size()):
			if str(res["events"][i]["kind"]) == str(args["kind"]) 					and (not args.has("kside") or int(res["events"][i].get("side", -1)) == int(args["kside"])):
				seen += 1
				if seen == int(args.get("nth", "1")):
					from = maxi(0, i - int(args.get("lead", "3")))
					break
	var guard := 0
	while pitch.current_index() < from and guard < 200000:
		pitch._process(dt)
		guard += 1
	# --skip S: play on S more 1x seconds before the window opens (into a beat,
	# say from a centre bounce's set-up to the bounce).
	for _s in range(int(round(float(args.get("skip", "0")) / dt / float(pitch.speed)))):
		pitch._process(dt)
	var secs := float(args.get("secs", "3"))
	var frames := int(args.get("frames", "12"))
	var steps := int(round(secs / dt / float(pitch.speed)))
	var every := maxi(1, steps / maxi(1, frames))
	var out := str(args.get("out", "/tmp/cap"))

	var movie := args.has("movie")
	var movie_every := maxi(1, int(round((1.0 / 30.0) / dt / float(pitch.speed))))
	var movie_n := 0
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
		if movie and s % movie_every == 0:
			# --movie: every frame of the window at 30 fps, full size, for the
			# capture workflow to stitch into a clip (the director judges
			# motion from clips, not sheets).
			pitch.queue_redraw()
			await process_frame
			await process_frame
			var mf: Image = root.get_viewport().get_texture().get_image()
			mf.save_png("%s_f%04d.png" % [out, movie_n])
			_motion_frame(pitch, movie_n)
			movie_n += 1
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
	if movie:
		# A movie frame is movie_every steps of dt, at the playback speed, in match time.
		var frame_h := float(movie_every) * dt * float(pitch.speed) * float(load("res://scripts/ui/match/MatchDirector.gd").TEMPO)
		print("MOTION max %.2f m in one frame (frame %d), %.1f m/s of match time (a frame is %.3f s of it)" % [_max_move, _max_move_at,
				_max_move / maxf(0.0001, frame_h), frame_h])
		for tag in ["has", "not", "stop"]:
			var a: Dictionary = _shape.get(tag, {})
			var n := float(a.get("n", 0))
			if n > 0.0:
				print("SHAPE %s frames %d: centroid up the ground from the ball %.1f m, median player %.1f m, centroid from the away side's %.1f m, spread across %.1f m, front to back %.1f m, median distance from the ball %.1f m, most within 6 m of the ball %d" % [
						tag, int(n), float(a["cen"]) / n, float(a["med"]) / n, float(a["opp"]) / n, float(a["sd"]) / n,
						float(a["span"]) / n, float(a["rad"]) / n, int(a["near"])])
	quit(0)


var _prev_disc := PackedVector2Array()
var _prev_period := -1
var _max_move := 0.0
var _max_move_at := -1
var _shape := {}


## One movie frame as drawn: the largest disc move since the last frame (not
## across a change of ends, where the picture mirrors), and the home side's shape.
func _motion_frame(pitch, n: int) -> void:
	var drawn: PackedVector2Array = pitch.disc_positions_drawn()
	var s: float = pitch._scale()
	var most := 0.0
	if _prev_disc.size() == drawn.size() and pitch.period == _prev_period:
		for i in range(drawn.size()):
			most = maxf(most, drawn[i].distance_to(_prev_disc[i]) / s)
		if most > _max_move:
			_max_move = most
			_max_move_at = n
	print("MOTION frame %d %.2f m" % [n, most])
	_prev_disc = drawn.duplicate()
	_prev_period = pitch.period
	var d = pitch.director
	if d.mode == "break" or drawn.size() != d.tokens.size():
		return
	var o0: Vector2 = pitch._w2s(Vector2.ZERO)
	var ex: Vector2 = pitch._w2s(Vector2(1, 0)) - o0
	var ey: Vector2 = pitch._w2s(Vector2(0, 1)) - o0
	var det := ex.x * ey.y - ex.y * ey.x
	var b: Vector2 = d.ball["pos"]
	var xs := []
	var ys := []
	var opp := 0.0
	var near := 0
	var rads := []
	for i in range(drawn.size()):
		var v := drawn[i] - o0
		var w := Vector2((v.x * ey.y - v.y * ey.x) / det, (ex.x * v.y - ex.y * v.x) / det)
		if int(d.tokens[i]["side"]) == 1:
			opp += w.x / 18.0
			continue
		xs.append(w.x)
		ys.append(w.y)
		rads.append(w.distance_to(b))
		if w.distance_to(b) < 6.0:
			near += 1
	var cx := 0.0
	var cy := 0.0
	for k in range(xs.size()):
		cx += float(xs[k]) / xs.size()
		cy += float(ys[k]) / ys.size()
	var sd := 0.0
	var span := 0.0
	for k in range(ys.size()):
		sd += pow(float(ys[k]) - cy, 2.0) / ys.size()
		span += absf(float(xs[k]) - cx) / xs.size()
	xs.sort()
	rads.sort()
	var tag := "stop" if d._stoppage_on() else ("has" if d._poss == 0 else "not")
	if not _shape.has(tag):
		_shape[tag] = {"n": 0, "cen": 0.0, "med": 0.0, "opp": 0.0, "sd": 0.0, "span": 0.0, "rad": 0.0, "near": 0}
	var a: Dictionary = _shape[tag]
	a["n"] = int(a["n"]) + 1
	a["cen"] = float(a["cen"]) + cx - b.x
	a["med"] = float(a["med"]) + 0.5 * (float(xs[8]) + float(xs[9])) - b.x
	a["opp"] = float(a["opp"]) + cx - opp
	a["sd"] = float(a["sd"]) + sqrt(sd)
	a["span"] = float(a["span"]) + span
	a["rad"] = float(a["rad"]) + 0.5 * (float(rads[8]) + float(rads[9]))
	a["near"] = maxi(int(a["near"]), near)


## Token and ball positions in pixels.
func _snapshot(pitch) -> Dictionary:
	var snap: Dictionary = pitch.debug_snapshot()
	var players := []
	var screen: Array = snap["screen"]
	for i in range(screen.size()):
		players.append({"side": int(snap["tokens"][i]["side"]), "i": i, "pos": screen[i]})
	return {"players": players, "ball": snap["ball_screen"]}
