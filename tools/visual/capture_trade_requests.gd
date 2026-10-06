extends SceneTree
## Visual review tool for the off-season Trade tab's "Asked to be traded"
## section, on a phone (390x844), dark. Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_trade_requests.gd
## Environment: CAP_OUT (the png path, default "trade_requests_section.png"),
## CAP_MODE ("dark" default or "light").
## A fresh Melbourne career fast-forwarded to the off-season. When fewer than
## two requests concern Melbourne, one of each kind is added (a Melbourne player
## asking to go home, another club's player asking Melbourne for a game), so
## the section always shows both lines. Never touches a real save.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "trade_requests_section.png"
	var mode := OS.get_environment("CAP_MODE") if OS.get_environment("CAP_MODE") != "" else "dark"
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_trade_requests.save"
	state.settings_path = "user://capture_trade_requests.cfg"
	state.reset()
	state.career_seed = 2026
	state.replay_seed = 2026
	state.set_setting("seen_training_intro", true)
	state.start_season("MEL", db.club_list("MEL"))
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	if state.my_trade_requests().size() < 2:
		var mine: Dictionary = state.season.lists["MEL"][state.season.lists["MEL"].size() - 3]
		state.trade_requests[str(mine["id"])] = {"club": "MEL", "why": "home", "to": ["ADE", "PTA"]}
		var theirs: Dictionary = state.season.lists["COL"][state.season.lists["COL"].size() - 3]
		state.trade_requests[str(theirs["id"])] = {"club": "COL", "why": "games", "to": ["MEL", "NM"]}
	print("requests: ", state.my_trade_requests())
	UK.apply_appearance(mode)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var off = load("res://scenes/OffseasonScene.tscn").instantiate()
	off.set("_tab", "trade")
	root.add_child(off)
	off.call("_build")
	for i in range(8):
		await process_frame
	# Bring the section to the top of the screen.
	var head: Control = off.find_child("Request_*", true, false)
	var box: ScrollContainer = off.find_children("*", "ScrollContainer", true, false)[0]
	if head != null:
		box.scroll_vertical = int(head.global_position.y - box.global_position.y) - 60
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(out) != OK:
		push_error("could not save " + out)
	print("wrote ", out)
	quit()
