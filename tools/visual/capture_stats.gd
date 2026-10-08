extends SceneTree
## The match stats view (MatchStatsView), for the director's look. Needs a
## real renderer:
##   godot --path . --script tools/visual/capture_stats.gd -- --out /tmp/st [--size 1280x720]
##       [--quarters 2] [--view team|players] [--scope all|1..4]
## --quarters N: the break after N quarters (4 = full time). Writes <out>_sheet.png.

var W := 1280
var H := 720


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/st"
	var quarters := 2
	var view := "team"
	var scope := "all"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var v := str(a[i + 1]) if i + 1 < a.size() else ""
		match str(a[i]):
			"--out": out = v
			"--size":
				W = int(v.split("x")[0])
				H = int(v.split("x")[1])
			"--quarters": quarters = int(v)
			"--view": view = v
			"--scope": scope = v
	await process_frame
	var db = root.get_node("GameDB")
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	# Loaded, not named: a --script tool compiles before the autoloads exist.
	var squad_script = load("res://scripts/sim/Squad.gd")
	var sim = load("res://scripts/sim/MatchSim.gd").new(
			squad_script.new("GEE", db.club_list("GEE"), true, "GEE"),
			squad_script.new("COL", db.club_list("COL"), false, "COL"), 42)
	var res: Dictionary = {}
	for q in range(quarters):
		res = sim.run_quarter()
	var bg := ColorRect.new()
	bg.color = load("res://scripts/ui/UiKit.gd").BG
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: Dictionary = load("res://scripts/ui/UiKit.gd").modal_box(bg, 1100.0, 0.0)
	var body: VBoxContainer = box["body"]
	var stats = load("res://scripts/ui/match/MatchStatsView.gd").new()
	body.add_child(stats)
	stats.setup(res, 1, quarters < 4)
	for i in range(4):
		await process_frame
	if scope != "all":
		var b = stats.find_child("StatsScope_" + scope, true, false)
		if b != null:
			b.emit_signal("pressed")
	for i in range(4):
		await process_frame
	if view == "players":
		var t = stats.find_child("StatsView_players", true, false)
		if t != null:
			t.emit_signal("pressed")
	for i in range(10):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
