extends SceneTree
## Visual review tool for the pre-match scene (PreMatchVignette). Needs a real
## renderer, so run it under a virtual display, e.g.:
##   xvfb-run -a -s "-screen 0 1280x900x24" godot --path . --rendering-driver opengl3 \
##       --script tools/visual/capture_prematch.gd -- --out /tmp/prematch
## --window WxH: a desktop window of that many pixels (e.g. 1920x1080) instead of the phone.
## Writes <out>_sheet.png: warm-up, final instructions and the banner on a phone.
## --film: also writes <out>_film_NNN.png, the whole scene at 12 frames a second (the
## run through the banner included), for checking motion.
## --milestone N: the banner for a player's Nth game (FL-002; 200 is the director's
## line), --club: games for this club rather than his career; --opp CODE: the
## opponent (Essendon by default, whose ANZAC banner outranks any milestone).
## --flags 2031,2029,2028: premiership pennants for those years (FL-008); --home CODE:
## the home club (Collingwood by default). --venue MCG: that ground's own treatment (FL-003).

var W := 390
var H := 844
## [phase to be in, seconds into the scene]: the warm-up, gathering in, gathered, the run.
const BEATS := [["warm", 0.2], ["warm", 0.7], ["huddle", 1.8], ["huddle", 3.6], ["run", 4.3], ["run", 5.2]]
## As the game plays it (HubScene.PRE_MATCH_SECONDS): they gather in, then go.
const GATHER_AT := 0.76
const RUN_AT := 3.8


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/prematch"
	var a := OS.get_cmdline_user_args()
	var film := a.has("--film")
	var ctx := {}
	var me := "COL"
	var ms_games := 0
	var opp_arg := "ESS"
	for i in range(a.size() - 1):
		if str(a[i]) == "--window":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--home":
			me = str(a[i + 1])
		if str(a[i]) == "--flags":
			ctx["flags"] = Array(str(a[i + 1]).split(",")).map(func(y): return int(y))
		if str(a[i]) == "--milestone":
			ms_games = int(a[i + 1])
		if str(a[i]) == "--opp":
			opp_arg = str(a[i + 1])
		if str(a[i]) == "--venue":
			VignetteGround.venue = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.start_season(me, db.club_list(me))
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var opp := opp_arg
	# Everyone named, as the game passes them: the 18 and the interchange.
	var opp_squad = load("res://scripts/sim/Squad.gd").new(opp, state.season.lists[opp], false, opp)
	var opp_ground: Array = opp_squad.ground + opp_squad.bench
	if ms_games > 0:
		var p: Dictionary = state.my_squad().ground[0]
		ctx["milestone"] = {"games": ms_games, "player": str(p.get("last", "")),
				"name": db.player_display_name(p), "club": a.has("--club")}
	var vig = load("res://scripts/ui/match/PreMatchVignette.gd").open(root, me, opp,
			state.my_squad().ground + state.my_squad().bench, opp_ground,
			"Round 1  ·  %s v %s" % [db.club_name(me), db.club_name(opp)], false, ctx)
	vig.set_process(false)
	var shots := []
	for beat in BEATS:
		var t: float = beat[1]
		if beat[0] == "huddle" and vig.phase() == "warm":
			vig.set("_t", GATHER_AT)
			vig.set_progress(0.6)
		if beat[0] == "run" and vig.phase() != "run":
			vig.set("_t", RUN_AT)
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
	if film:
		# A fresh scene: the stills above have already sent this one through the banner.
		vig.get_parent().queue_free()
		await process_frame
		vig = load("res://scripts/ui/match/PreMatchVignette.gd").open(root, "COL", opp,
				state.my_squad().ground + state.my_squad().bench, opp_ground, "Round 1  ·  Collingwood v Essendon")
		vig.set_process(false)
		var t := 0.0
		var n := 0
		while t < RUN_AT + 2.4:
			if t >= GATHER_AT and vig.phase() == "warm":
				vig.set_progress(0.6)
			if t >= RUN_AT and vig.phase() != "run":
				vig.run_out()
			vig.set("_t", t)
			vig.queue_redraw()
			for i in range(2):
				await process_frame
			var img: Image = root.get_viewport().get_texture().get_image()
			img.save_png("%s_film_%03d.png" % [out, n])
			n += 1
			t += 1.0 / 12.0
		print("filmed ", n)
	quit(0)
