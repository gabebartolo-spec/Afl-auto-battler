extends SceneTree
## The line under each club on the hub ("Wildcard. Team rating 68. On this list, 65 in three years."),
## for a chosen club against a chosen opponent:
##   godot --path . --script tools/visual/capture_rating_line.gd -- --out /tmp/rl --club FRE --opp MEL --size 390x844
## Plays rounds until the club's next opponent is --opp, then writes <out>_hub.png (the top, the
## opponent's line under the poster) and <out>_hub_bottom.png (scrolled to the end: your own line).
## Prints the two lines. Needs a real renderer (capture.yml).

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in range(10):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _run() -> void:
	var out := "/tmp/rl"
	var club := "FRE"
	var opp := "MEL"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--club":
				club = str(a[i + 1])
			"--opp":
				opp = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				W = int(wh[0])
				H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_rl.save"
	state.settings_path = "user://capture_rl_settings.cfg"
	state.set_vignettes_on(false)
	state.set_reduced_motion(true)
	state.reset()
	state.replay_seed = 2027
	state.set_setting("seen_weekly_loop_intro", true)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season(club, db.club_list(club))
	state.tutorials = false
	var guard := 0
	while str(state.my_next_opponent().get("code", "")) != opp and guard < 30:
		state.advance()
		guard += 1
	state.media_conference = {}
	state.backing_talk = {}
	print("RATING_LINE %s v %s after %d rounds" % [club, opp, guard])
	print("RATING_LINE own: ", state.team_outlook(club)["line"])
	print("RATING_LINE opp: ", state.team_outlook(opp)["line"])
	root.get_node("Router").go("hub")
	for i in range(10):
		await process_frame
	await _shot(out + "_hub.png")
	for sc in current_scene.find_children("*", "ScrollContainer", true, false):
		(sc as ScrollContainer).scroll_vertical = 100000
	await _shot(out + "_hub_bottom.png")
	var clipped := 0
	for n in current_scene.find_children("*", "Label", true, false):
		var l := n as Label
		if l.is_visible_in_tree() and l.name in ["MyTeamOutlook", "OppTeamOutlook"]:
			print("RATING_LINE label %s: [%s] lines %d, clipped %s" % [l.name, l.text, l.get_line_count(), str(l.get_line_count() > l.get_visible_line_count())])
			if l.get_line_count() > l.get_visible_line_count() or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and l.get_minimum_size().x > l.size.x + 1:
				clipped += 1
	print("RATING_LINE clipped %d" % clipped)
	quit(0)
