extends SceneTree
## Real renderer: xvfb-run -a godot --path . --rendering-method gl_compatibility --script tools/visual/capture_awards.gd
## Illustrative fixture only; never touches a real save.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.reset()
	state.start_season("COL", db.club_list("COL"))
	var p: Dictionary = state.my_list[0]
	var row := {"id": str(p["id"]), "club": "COL", "votes": 24, "bf": 118, "goals": 71, "slot": "MID"}
	state.season_awards = {"year": 2027, "brownlow": [row], "coleman": [row], "all_australian": [row], "best_and_fairest": {"COL": [row]}}
	root.size = Vector2i(360, 800)
	DisplayServer.window_set_size(Vector2i(360, 800))
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ceremony: Control = load("res://scripts/ui/SeasonAwards.gd").open(host)
	for i in range(5):
		await process_frame
	ceremony.find_child("AwardsNext", true, false).emit_signal("pressed")
	for i in range(5):
		await process_frame
	ceremony.find_child("AwardWinner", true, false).finish_now()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/ard-awards.png")
	quit()
