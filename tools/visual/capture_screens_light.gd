extends SceneTree
## Visual review tool for the main screens in light mode, on a phone (390x844),
## one sheet per theme so a light defect can be seen against the dark original.
## Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_screens_light.gd
## Environment: CAP_OUT (path prefix, default "screens"), CAP_MODE ("light" default or "dark").
## Writes <prefix>_<mode>_<screen>.png for the hub, ladder, selection, training,
## list and coaching screens of a fresh Melbourne career. Never touches a real save.

const W := 390
const H := 844
const SCREENS := {"hub": "HubScene", "ladder": "LadderScene", "selection": "SelectionScene",
		"training": "TrainingScene", "list": "ListScene", "coaching": "CoachingScene"}


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(6):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "screens"
	var mode := OS.get_environment("CAP_MODE") if OS.get_environment("CAP_MODE") != "" else "light"
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_screens.save"
	state.settings_path = "user://capture_screens.cfg"
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
	for key in SCREENS:
		var scene = load("res://scenes/%s.tscn" % SCREENS[key]).instantiate()
		root.add_child(scene)
		var img := await _shot()
		var path := "%s_%s_%s.png" % [out, mode, key]
		if img.save_png(path) != OK:
			push_error("could not save " + path)
		print("wrote ", path)
		scene.queue_free()
		await process_frame
	quit(0)
