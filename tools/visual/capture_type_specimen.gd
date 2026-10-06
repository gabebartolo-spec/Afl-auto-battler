extends SceneTree
## Launcher for the type specimen (tools/visual/type_specimen.gd, which says
## what it shows and takes the arguments). The specimen uses the game's
## autoloads, which a --script main loop can't name at compile time, so it is
## loaded once they exist.
##   godot --path . --rendering-driver opengl3 --script tools/visual/capture_type_specimen.gd \
##       -- --out /tmp/type_390 [--col 390] [--scale 1] [--text 1.0] [--fonts DIR]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var specimen: Node = load("res://tools/visual/type_specimen.gd").new()
	root.add_child(specimen)
	specimen.run()
