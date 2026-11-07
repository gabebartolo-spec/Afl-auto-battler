extends SceneTree
## Review capture for row 116 (T5.Q23b): awards night's count on a phone, dark.
## Needs a real renderer and a window (windowed, through C:/kt/gpu_slot.sh, off
## screen via override.cfg):
##   godot --path . --script tools/visual/capture_awards_count.gd -- --size 390x844 --out <prefix> [--club GEE]
## A season really played from Round 1 (fixed seed), so the names and the spread
## of votes are a real count's. Drives the controls by their handlers (the real
## taps are proven in tests/run_awards_count_tests.gd). Writes <out>_<shot>.png:
## opening, live (part way through Round 7), paused, break (the Rising Star at the
## halfway mark), last_round and last_round_lower (the last round read over the
## final count), skipped (Skip to the result), winner, club_mid and club_end
## (your club's count part way, and at the end with its finals). Never touches a
## real save.

var _w := 390
var _h := 844
var _club := "GEE"
var _out := "awards_count"
var _gs: Node
var _host: Control


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _secs(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func _shot(shot: String) -> void:
	await _frames(4)
	var img := root.get_viewport().get_texture().get_image()
	if img == null:
		print("no renderer: ", shot)
		return
	img.convert(Image.FORMAT_RGBA8)
	img.save_png("%s_%s.png" % [_out, shot])
	print("wrote ", _out, "_", shot, ".png")


func _press(c: Node, name: String) -> void:
	var b := c.find_child(name, true, false) as Button
	if b == null:
		print("missing button ", name)
		return
	b.emit_signal("pressed")
	await _frames(3)


func _view(c: Node) -> Node:
	return c.find_child("AwardsCount", true, false)


func _scroll(c: Node, to: int) -> void:
	for n in c.find_children("*", "ScrollContainer", true, false):
		(n as ScrollContainer).scroll_vertical = to
	await _frames(6)


func _open() -> Control:
	for n in _host.get_children():
		n.free()
	var c: Control = load("res://scripts/ui/SeasonAwards.gd").open(_host)
	await _frames(8)
	return c


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out":
				_out = str(a[i + 1])
			"--club":
				_club = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
	await process_frame
	_gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	load("res://scripts/ui/UiKit.gd").apply_appearance("dark")
	_gs.autosave_enabled = false
	_gs.save_path = "user://capture_awards_count.save"
	_gs.settings_path = "user://capture_awards_count.cfg"
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	_gs.reset()
	_gs.career_seed = 2026
	_gs.replay_seed = 2026
	_gs.start_season(_club, db.club_list(_club))
	var guard := 0
	while not _gs.season.is_season_over() and guard < 40:
		_gs.advance()
		guard += 1
	var rec: Dictionary = _gs.award_counts
	var finals := 0
	for r in rec.get("rounds", []):
		finals += 1 if bool(r.get("final", false)) else 0
	print("season ", _gs.season_year, " rounds recorded ", (rec.get("rounds", []) as Array).size(),
			" your finals ", finals, " winner ", _gs.award_name(_gs.season_awards.get("brownlow_winner", {})))
	_host = Control.new()
	root.add_child(_host)
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The Brownlow, watched live to Round 7, paused, then a round at a time.
	var c := await _open()
	await _shot("opening")
	await _press(c, "CountWatch")
	Engine.time_scale = 6.0
	while int(_view(c).current()) < 6 or int(_view(c).get("matches")) < 4:
		await process_frame
	Engine.time_scale = 1.0
	await _secs(0.15)
	await _shot("live")
	await _press(c, "CountWatch")
	await _secs(1.0)
	await _shot("paused")
	while not bool(_view(c).get("at_break")) and not _view(c).done():
		await _press(c, "AwardsNext")
	await _secs(1.0)
	await _shot("break")
	while not _view(c).done():
		await _press(c, "AwardsNext")
	await _secs(1.0)
	await _shot("last_round")
	await _scroll(c, 100000)
	await _shot("last_round_lower")

	# Skip to the result, then the winner.
	_gs.season_awards.erase("count_at")
	c = await _open()
	await _press(c, "CountSkipAll")
	await _secs(1.0)
	await _shot("skipped")
	await _press(c, "AwardsNext")
	await _secs(3.0)
	await _shot("winner")

	# On to your club's count: past the awards between, then part way and the end.
	var guard2 := 0
	while _view(c) == null and guard2 < 20:
		await _press(c, "AwardsNext")
		guard2 += 1
	for i in range(11):
		await _press(c, "AwardsNext")
	await _secs(1.0)
	await _shot("club_mid")
	while _view(c) != null and not _view(c).done():
		await _press(c, "AwardsNext")
	await _secs(1.0)
	await _shot("club_end")
	quit()
