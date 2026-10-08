extends SceneTree
## The box score (BoxScore), for the director's look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_boxscore.gd -- --out /tmp/bx [--size 390x844]
##       [--quarters 4] [--pick none|q2|goal] [--open] [--bars]
## A seeded GEE v COL match; --quarters N < 4 is a break. Writes <out>.png.

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/bx"
	var quarters := 4
	var pick := "none"
	var open := false
	var bars := false
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var v := str(a[i + 1]) if i + 1 < a.size() else ""
		match str(a[i]):
			"--out": out = v
			"--size":
				W = int(v.split("x")[0])
				H = int(v.split("x")[1])
			"--quarters": quarters = int(v)
			"--pick": pick = v
			"--open": open = true
			"--bars": bars = true
	await process_frame
	var db = root.get_node("GameDB")
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	# Loaded, not named: a --script tool compiles before the autoloads exist.
	var kit = load("res://scripts/ui/UiKit.gd")
	var squad_script = load("res://scripts/sim/Squad.gd")
	var sim = load("res://scripts/sim/MatchSim.gd").new(
			squad_script.new("GEE", db.club_list("GEE"), true, "GEE"),
			squad_script.new("COL", db.club_list("COL"), false, "COL"), 42)
	var res: Dictionary = {}
	for q in range(quarters):
		res = sim.run_quarter()
	if quarters >= 4:
		res = sim.result()
	var bg := ColorRect.new()
	bg.color = kit.BG
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: Dictionary = kit.modal_box(bg, 640.0, 0.0)
	var body: VBoxContainer = box["body"]
	var bx = load("res://scripts/ui/match/BoxScore.gd").new()
	body.add_child(bx)
	bx.setup(res, quarters < 4, bars)
	for i in range(4):
		await process_frame
	if pick == "q2":
		bx.pick_quarter(2)
	elif pick == "goal":
		# A set-shot goal if there is one, else the first goal.
		var scores: Array = bx.get("_scores")
		var at := -1
		for i in range(scores.size()):
			if bool(scores[i]["goal"]) and (at < 0 or bool(scores[i]["set"])):
				at = i
				if bool(scores[i]["set"]):
					break
		if at >= 0:
			bx.pick_score(at)
	if open:
		var row = bx.find_children("BoxPlayer_*", "Button", true, false)
		if not row.is_empty():
			row[0].emit_signal("pressed")
	for i in range(10):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out + ".png")
	print("wrote ", out + ".png")
	quit()
