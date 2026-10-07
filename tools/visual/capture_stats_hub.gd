extends SceneTree
## Visual review tool for Season stats (the Stats patch, ROADMAP §1.11). Needs a
## real renderer; capture.yml runs it:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_stats_hub \
##       -f args="--section fixture --size 390x844"
## Writes <out>_<section>.png, and for the fixture also <out>_fixture_played.png
## (the round before), <out>_fixture_match.png (a played match opened),
## <out>_fixture_preview.png (a match to come opened) and
## <out>_fixture_picker.png (the round picker). For the ladder also
## <out>_ladder_sorted.png (sorted by W), <out>_ladder_top8.png, <out>_ladder_team.png
## (Team stats) and <out>_ladder_side.png (a club's side opened).
##   --section KEY   ladder, players, awards, fixture or trophies (default fixture)
##   --size WxH      window size (default 390x844)    --light   light appearance
##   --rounds N      rounds played before the capture (default 6)
## A fresh Collingwood career, seeded. Never touches a real save.

var _w := 390
var _h := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "stats_hub"
	var section := "fixture"
	var mode := "dark"
	var rounds := 6
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--section":
				section = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
			"--rounds":
				rounds = int(str(a[i + 1]))
			"--light":
				mode = "light"
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_stats.save"
	state.settings_path = "user://capture_stats.cfg"
	state.reset()
	state.career_seed = 2031
	state.replay_seed = 2031
	state.set_setting("seen_training_intro", true)
	state.start_season("COL", db.club_list("COL"))
	for i in range(rounds):
		state.advance()
	UK.apply_appearance(mode)
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	load("res://scripts/ui/StatsHubScene.gd").current = section
	var scene: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(10)
	_save(out + "_" + section + ".png")
	if section == "fixture":
		await _tap(scene, "PrevRound")
		_save(out + "_fixture_played.png")
		await _tap(scene, "Match_0")
		_save(out + "_fixture_match.png")
		scene.call("handle_back")
		await _frames(6)
		await _tap(scene, "NextRound")
		await _tap(scene, "Match_0")
		_save(out + "_fixture_preview.png")
		scene.call("handle_back")
		await _frames(6)
		await _tap(scene, "RoundPicker")
		_save(out + "_fixture_picker.png")
	if section == "ladder":
		await _tap(scene, "Sort_w")
		_save(out + "_ladder_sorted.png")
		await _tap(scene, "Filter_top8")
		_save(out + "_ladder_top8.png")
		await _tap(scene, "ResetLadder")
		await _tap(scene, "View_team")
		_save(out + "_ladder_team.png")
		await _tap(scene, "View_ladder")
		await _tap(scene, "Club_" + _first_other(state))
		await _frames(10)
		_save(out + "_ladder_side.png")
	quit()


## A club on the ladder other than yours.
func _first_other(state) -> String:
	for r in state.season.ladder_sorted():
		if str(r["code"]) != str(state.my_club):
			return str(r["code"])
	return ""


func _tap(scene: Node, node_name: String) -> void:
	var b: Button = scene.find_child(node_name, true, false)
	if b == null:
		push_error("no " + node_name)
		return
	b.emit_signal("pressed")
	await _frames(10)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(path) != OK:
		push_error("could not save " + path)
	print("wrote ", path)
