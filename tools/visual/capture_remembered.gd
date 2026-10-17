extends SceneTree
## Visual review tool for P-37, the club remembers him (390x844, Fremantle):
##   godot --path . --script tools/visual/capture_remembered.gd -- --out /tmp/rem
## Writes <out>_sheet.png (a player's sheet scrolled to "With us") and
## <out>_confirm.png (the release confirm for the same player).

const W := 390
const H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot() -> Image:
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	var out := "/tmp/rem"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var Facts = load("res://scripts/sim/CareerFacts.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.career_seed = 7737
	state.replay_seed = 7737
	state.reset()
	state.start_season("FRE", db.club_list("FRE"))
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	var year: int = state.season_year
	var star: Dictionary = state.my_list.filter(func(q): return float(q.get("age", 30.0)) < 26.0)[0]
	var id := str(star["id"])
	star["career"] = {"games": 12, "goals": 14, "through": year - 1, "unknown": [],
			"stints": [["FRE", year - 2, year - 1, 12, 14]]}
	star["firsts"] = {"debut": {"year": year - 2, "label": "Round 7"}, "goal": {"year": year - 2, "label": "Round 7"}}
	state.honour_roll = [{"year": year - 1, "my_club": "FRE", "premier": "", "my_bf": [{"id": id}]},
			{"year": year - 2, "my_club": "FRE", "premier": "FRE", "my_bf": []}]
	Facts.add(state.career_facts, id, Facts.row(year - 1, "Round 3", "injury", "FRE", "", "hamstring"))
	for key in ["injury_weeks", "injury_kind", "suspension_weeks"]:
		star.erase(key)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var sheet: Control = load("res://scripts/ui/PlayerSheet.gd").open(host, star)
	await _shot()
	var block := sheet.find_child("ProfileWithUs", true, false)
	var p := block.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p != null:
		(p as ScrollContainer).scroll_vertical = int(block.global_position.y - (p as Control).global_position.y) + (p as ScrollContainer).scroll_vertical - 120
	(await _shot()).save_png(out + "_sheet.png")
	host.queue_free()
	await process_frame
	state.season.round_index = state.season.fixture.size()
	state.open_offseason()
	star["contract_years"] = 1
	var scene: Control = load("res://scenes/OffseasonScene.tscn").instantiate()
	root.add_child(scene)
	await _shot()
	var row: Node = scene.find_child("Contract_" + id, true, false)
	(row.find_child("Release", true, false) as Button).pressed.emit()
	(await _shot()).save_png(out + "_confirm.png")
	quit(0)
