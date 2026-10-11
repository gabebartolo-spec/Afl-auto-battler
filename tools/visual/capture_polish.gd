extends SceneTree
## The hub and a player profile at phone size, for the hub/profile polish look:
##   godot --path . --script tools/visual/capture_polish.gd -- --out /tmp/polish [--club BRL] [--size 390x844]
## Writes <out>_hub.png (the top), <out>_hub_bottom.png (scrolled to the end:
## league news and the ladder) and <out>_profile.png (a forward on My list).
## Needs a real renderer (capture.yml).

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
	var out := "/tmp/polish"
	var club := "BRL"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--club":
			club = str(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_polish.save"
	state.settings_path = "user://capture_polish_settings.cfg"
	state.set_vignettes_on(false)
	state.set_reduced_motion(true)   # still frames: no slide or fades
	state.reset()
	state.replay_seed = 2027
	state.set_setting("seen_weekly_loop_intro", true)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season(club, db.club_list(club))
	state.tutorials = false
	state.media_conference = {}
	state.backing_talk = {}
	state.advance()
	state.media_conference = {}
	state.backing_talk = {}
	root.get_node("Router").go("hub")
	for i in range(10):
		await process_frame
	await _shot(out + "_hub.png")
	for sc in current_scene.find_children("*", "ScrollContainer", true, false):
		var s := sc as ScrollContainer
		s.scroll_vertical = 100000
	await _shot(out + "_hub_bottom.png")
	root.get_node("Router").go("list")
	for i in range(8):
		await process_frame
	var fwd: Dictionary = state.my_list[0]
	for q in state.my_list:
		if str(q.get("role", "")) == "FWD":
			fwd = q
			break
	current_scene.call("_open_profile", str(fwd["id"]))
	for l in current_scene.find_children("*", "Label", true, false):
		var t := (l as Label).text
		if t.begins_with("#") or l.name == "ProfileType":
			print("POLISH label %s: [%s]" % [l.name, t])
	await _shot(out + "_profile.png")
	quit(0)
