extends SceneTree
## Light-mode capture of the Club Forge screens on a phone (390x844): the home screen,
## the Create a player form and the Create a club form. Needs a real renderer:
##   godot --path . --rendering-method gl_compatibility --script tools/visual/capture_forge_light.gd
## `--out PREFIX` and `--mode light|dark` after `--` (capture.yml passes them) beat the environment. Environment: CAP_OUT (path prefix, default "forge"), CAP_MODE ("light" default or "dark").
## Writes <prefix>_<mode>_{home,player,club}.png. Never touches a real save.
## Needs a branch that has scenes/ClubForgeScene.tscn and the Create a club screen (#360).

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(frames: int = 8) -> Image:
	for i in range(frames):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "forge"
	var mode := OS.get_environment("CAP_MODE") if OS.get_environment("CAP_MODE") != "" else "light"
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		if str(cli[i]) == "--out":
			out = str(cli[i + 1])
		if str(cli[i]) == "--mode":
			mode = str(cli[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_forge.save"
	state.settings_path = "user://capture_forge.cfg"
	state.reset()
	state.set_setting("seen_training_intro", true)
	UK.apply_appearance(mode)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var scene = load("res://scenes/ClubForgeScene.tscn").instantiate()
	root.add_child(scene)
	(await _shot()).save_png("%s_%s_home.png" % [out, mode])
	print("wrote home")
	for pair in [["ForgeCreatePlayer", "player"], ["ForgeCreateClub", "club"]]:
		if scene.has_method("handle_back"):
			scene.call("handle_back")
			await _shot(4)
		var b: Button = scene.find_child(pair[0], true, false)
		if b == null:
			push_warning("no " + pair[0])
			continue
		b.emit_signal("pressed")
		(await _shot()).save_png("%s_%s_%s.png" % [out, mode, pair[1]])
		print("wrote ", pair[1])
	quit(0)
