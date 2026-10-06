extends SceneTree
## Light-mode capture of the live match screen on a phone (390x844): the pre-bounce
## coach box, then play. Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_match_light.gd
## Environment: CAP_OUT (path prefix, default "match"), CAP_MODE ("light" default or "dark").
## Writes <prefix>_<mode>_prebounce.png and <prefix>_<mode>_play.png. Never touches a real save.

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(frames: int = 6) -> Image:
	for i in range(frames):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "match"
	var mode := OS.get_environment("CAP_MODE") if OS.get_environment("CAP_MODE") != "" else "light"
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_match.save"
	state.settings_path = "user://capture_match.cfg"
	state.reset()
	state.set_setting("seen_training_intro", true)
	state.start_season("MEL", db.club_list("MEL"))
	UK.apply_appearance(mode)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	if not state.prepare_interactive_match():
		push_error("no match to prepare")
		quit(1)
		return
	var m = load("res://scenes/MatchScene.tscn").instantiate()
	root.add_child(m)
	(await _shot(20)).save_png("%s_%s_prebounce.png" % [out, mode])
	print("wrote prebounce")
	var start: Button = m.find_child("StartQuarter", true, false)
	if start != null:
		start.emit_signal("pressed")
	(await _shot(240)).save_png("%s_%s_play.png" % [out, mode])
	print("wrote play")
	quit(0)
