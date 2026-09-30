extends SceneTree
## Visual review tool for the pre-match scene (PreMatchVignette). Needs a real
## renderer, so run it under a virtual display, e.g.:
##   xvfb-run -a -s "-screen 0 1280x900x24" godot --path . --rendering-driver opengl3 \
##       --script tools/visual/capture_prematch.gd -- --out /tmp/prematch
## Writes <out>_sheet.png: warm-up, final instructions and the banner on a phone.

const W := 390
const H := 844
## [phase to be in, seconds into the scene]
const BEATS := [["warm", 0.2], ["warm", 1.0], ["warm", 1.8], ["huddle", 2.9], ["run", 3.3], ["run", 3.55]]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/prematch"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
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
	var opp := "ESS"
	var opp_ground: Array = load("res://scripts/sim/Squad.gd").new(opp, state.season.lists[opp], false, opp).ground
	var vig = load("res://scripts/ui/match/PreMatchVignette.gd").open(root, "COL", opp, state.my_squad().ground, opp_ground,
			"Round 1  ·  Collingwood v Essendon")
	vig.set_process(false)
	var shots := []
	for beat in BEATS:
		var t: float = beat[1]
		if beat[0] == "huddle" and vig.phase() == "warm":
			vig.set("_t", 2.0)
			vig.set_progress(0.6)
		if beat[0] == "run" and vig.phase() != "run":
			vig.set("_t", 3.05)
			vig.run_out()
		vig.set("_t", t)
		vig.queue_redraw()
		for i in range(3):
			await process_frame
		shots.append(root.get_viewport().get_texture().get_image())
	var sheet := Image.create(W * 3, H * 2, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		var img: Image = shots[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((i % 3) * W, (i / 3) * H))
	sheet.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	quit(0)
