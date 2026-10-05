extends SceneTree
## godot --headless --path . --script tools/audit/run_audit.gd -- <impl>
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var path := "res://tools/audit/%s.gd" % OS.get_cmdline_user_args()[0]
	var s = load(path).new()
	s.run()
	quit(0)
