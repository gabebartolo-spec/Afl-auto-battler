extends RefCounted
## screen_lint.gd --setup: opens the post-match press conference over the hub (a heavy loss, so
## the Muckraker asks), vignette skipped, so the lint walks the answers and their odds lines:
##   godot --headless --path . --script tools/visual/screen_lint.gd -- --screen hub --size 390x844 \
##         --club FRE --setup res://tools/visual/lint_setup_press.gd


static func lint_setup(tree: SceneTree, _scene: Node) -> void:
	var root := tree.root
	var state = root.get_node("GameState")
	state.media_conference = load("res://scripts/sim/MediaConference.gd").pick({"club": state.my_club,
			"opponent_name": "Carlton", "round": 8, "year": int(state.season_year),
			"result": {"home": state.my_club, "away": "CAR", "score": [55, 101]}}, {})
	var hub = root.find_child("HubScene", true, false)
	if hub == null:
		for n in root.find_children("*", "Control", true, false):
			if n.has_method("_show_media_conference"):
				hub = n
				break
	if hub != null:
		hub.call("_show_media_conference")
	for i in range(6):
		await tree.process_frame
	var v = root.find_child("MediaConferenceVignette", true, false)
	if v != null:
		v.call("finish_now")
	await tree.process_frame
	var line = root.find_child("MediaAnswerLine_0", true, false)
	print("PRESS SHEET open=%s line=%s" % [str(line != null and line.is_visible_in_tree()), "" if line == null else line.text])
