extends SceneTree
## A player's trust on his profile (stories phase 1), over My list, for the
## director's look. Needs a real renderer:
##   godot --path . --script tools/visual/capture_trust.gd -- --out /tmp/trust [--size 1280x720]
## Writes <out>_folded.png (the words, reasons folded away), <out>_why.png
## (after Why: his reasons, newest first) and <out>_wary.png (a player who is
## wary of you, reasons open).

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _run() -> void:
	var out := "/tmp/trust"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var TrustS = load("res://scripts/sim/Trust.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.set_setting("seen_weekly_loop_intro", true)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season("GEE", db.club_list("GEE"))
	var y: int = state.season_year
	# A young player you backed, then let down once; a senior player you kept
	# waiting and told to earn his spot.
	var kid: Dictionary = state.my_list[state.my_list.size() - 1]
	var vet: Dictionary = state.my_list[0]
	var kk: String = TrustS.player_key(str(kid["id"]))
	var vk: String = TrustS.player_key(str(vet["id"]))
	TrustS.change(state.relations, kk, 8, "You gave him his chance", y, "Round 2")
	TrustS.change(state.relations, kk, 10, "You talked him through being dropped", y, "Round 5")
	TrustS.change(state.relations, kk, -8, "You promised him a game and left him out", y, "Round 7")
	TrustS.change(state.relations, kk, 12, "You promised him his spot back", y, "Round 9")
	TrustS.change(state.relations, vk, -3, "You made him wait on a new deal", y, "Round 3")
	TrustS.change(state.relations, vk, -10, "You told him to earn his spot", y, "Round 6")
	TrustS.change(state.relations, vk, -10, "You broke your word on his run of games", y, "Round 8")
	TrustS.change(state.relations, vk, -8, "You promised him a game and left him out", y, "Round 10")
	root.get_node("Router").go("list")
	for i in range(8):
		await process_frame
	var list := current_scene
	list.call("_open_profile", str(kid["id"]))
	await _shot(out + "_folded.png")
	var why: Button = current_scene.find_child("TrustWhy", true, false)
	if why != null:
		why.emit_signal("pressed")
	await _shot(out + "_why.png")
	list.call("_open_profile", str(vet["id"]))
	for i in range(2):
		await process_frame
	why = null
	for b in current_scene.find_children("TrustWhy", "Button", true, false):
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			why = b
	if why != null:
		why.emit_signal("pressed")
	await _shot(out + "_wary.png")
	quit(0)
