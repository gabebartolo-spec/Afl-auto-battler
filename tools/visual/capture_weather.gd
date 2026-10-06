extends SceneTree
## Review sheet for the weather look (VignetteWeather; ARD-M4-016): the same moments of
## the existing scenes in each weather - perfect, wet, windy, hot - side by side, on a
## phone. Rows: the centre bounce, the pre-match huddle, a broadcast speccy, the pitch.
##   godot --path . --script tools/visual/capture_weather.gd -- --out /tmp/weather
## Writes <out>.png (and <out>_<weather>.png, one column each). Needs a real renderer
## and a window (keep it off screen with an override.cfg). Nothing here touches a save.

const W := 390
const H := 844
const WEATHERS := ["perfect", "wet", "windy", "hot"]
var SCALE := 0.5


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/weather"
	var film := ""
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		elif str(a[i]) == "--scale":
			SCALE = float(a[i + 1])
		elif str(a[i]) == "--film":
			film = str(a[i + 1])
	await process_frame
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	state.prepare_interactive_match()
	var sim = state.pending_sim
	var opp_squad = load("res://scripts/sim/Squad.gd").new("ESS", state.season.lists["ESS"], false, "ESS")
	var star: Dictionary = db.club_list("COL")[0]
	if film != "":
		await _film(out, film, sim, star)
		quit()
		return
	var cols := []
	for w in WEATHERS:
		var shots := []
		# The centre bounce, just before the ball goes up.
		var bounce = load("res://scripts/ui/match/StoppageVignette.gd").new()
		root.add_child(bounce)
		bounce.size = Vector2(W, H)
		bounce.setup(sim, 0, "Centre bounce")
		bounce.weather = w
		bounce.set_process(false)
		shots.append(await _shot(bounce, 3.3))
		# The pre-match huddle.
		var pre = load("res://scripts/ui/match/PreMatchVignette.gd").open(root, "COL", "ESS",
				state.my_squad().ground + state.my_squad().bench, opp_squad.ground + opp_squad.bench,
				"Round 1", false, {"weather": w})
		pre.set_process(false)
		pre.set("_t", 0.76)
		pre.set_progress(0.6)
		shots.append(await _shot(pre, 3.6))
		pre.get_parent().queue_free()
		# A broadcast speccy, the moment of the mark.
		var vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
		root.add_child(vig)
		vig.size = Vector2(W, H)
		vig.setup("speccy_front", {"kind": "mark", "side": 0, "num": int(star.get("num", 7)),
				"player_id": str(star["id"]), "club": "COL", "q": 4}, {}, {"home": "COL", "away": "CAR", "weather": w})
		vig.set_process(false)
		shots.append(await _shot(vig, 1.3))
		# The match's pitch.
		var pitch = load("res://scripts/ui/PitchView.gd").new()
		pitch.result = {"weather": w}
		pitch.home_code = "COL"
		pitch.away_code = "CAR"
		root.add_child(pitch)
		pitch.size = Vector2(W, H)
		pitch.set_process(false)
		shots.append(await _shot(pitch, -1.0))
		var col := Image.create(int(W * SCALE), int(H * SCALE) * shots.size(), false, Image.FORMAT_RGBA8)
		for i in range(shots.size()):
			var img: Image = shots[i]
			img.convert(Image.FORMAT_RGBA8)
			img.resize(int(W * SCALE), int(H * SCALE), Image.INTERPOLATE_LANCZOS)
			col.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(0, i * int(H * SCALE)))
		col.save_png("%s_%s.png" % [out, w])
		cols.append(col)
	var sheet := Image.create(cols[0].get_width() * cols.size() + 8 * (cols.size() - 1), cols[0].get_height(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.07, 0.07, 0.08))
	for i in range(cols.size()):
		sheet.blit_rect(cols[i], Rect2i(Vector2i.ZERO, cols[i].get_size()), Vector2i(i * (cols[i].get_width() + 8), 0))
	sheet.save_png(out + ".png")
	print("wrote ", out + ".png")
	quit()


## --film WEATHER: two seconds of the centre bounce and of a broadcast speccy in that
## weather, 12 frames a second (<out>_film_<scene>_NNN.png), to see what moves.
func _film(out: String, w: String, sim, star: Dictionary) -> void:
	var bounce = load("res://scripts/ui/match/StoppageVignette.gd").new()
	root.add_child(bounce)
	bounce.size = Vector2(W, H)
	bounce.setup(sim, 0, "Centre bounce")
	bounce.weather = w
	bounce.set_process(false)
	await _frames(bounce, "%s_film_bounce" % out, 1.6)
	var vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
	root.add_child(vig)
	vig.size = Vector2(W, H)
	vig.setup("speccy_front", {"kind": "mark", "side": 0, "num": int(star.get("num", 7)),
			"player_id": str(star["id"]), "club": "COL", "q": 4}, {}, {"home": "COL", "away": "CAR", "weather": w})
	vig.set_process(false)
	await _frames(vig, "%s_film_speccy" % out, 0.3)
	print("wrote ", out, "_film_*")


func _frames(node: Control, prefix: String, t0: float) -> void:
	for n in range(24):
		node.set("_t", t0 + n / 12.0)
		node.queue_redraw()
		await process_frame
		await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%03d.png" % [prefix, n])
	node.queue_free()
	await process_frame


## A still of node at its time t (t < 0: as it is), then removed.
func _shot(node: Control, t: float) -> Image:
	if t >= 0.0:
		node.set("_t", t)
	for i in range(4):
		node.queue_redraw()
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if node.get_parent() == root:
		node.queue_free()
	await process_frame
	return img
