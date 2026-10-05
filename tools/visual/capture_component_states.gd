extends SceneTree
## Real renderer: godot --path . --rendering-method gl_compatibility --script tools/visual/capture_component_states.gd
## Environment: CAP_W, CAP_H (default 390x900), CAP_OUT (file path, default
## "component_states.png"), CAP_MODE ("dark" default, or "light").
## A sheet of the shared controls in each state (normal, hover, pressed,
## disabled, selected), the red primary, danger, tabs, and three fixtures of
## club-coloured scores. Built from UiKit's own styles; illustrative only, it
## never touches a real save. Allow several minutes on a busy machine.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var UK = load("res://scripts/ui/UiKit.gd")
	var db = root.get_node("GameDB")
	var state = root.get_node("GameState")
	state.autosave_enabled = false
	state.save_path = "user://capture_states.save"
	state.settings_path = "user://capture_states.cfg"
	var w := int(OS.get_environment("CAP_W")) if OS.get_environment("CAP_W") != "" else 390
	var h := int(OS.get_environment("CAP_H")) if OS.get_environment("CAP_H") != "" else 900
	var out := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "component_states.png"
	UK.apply_appearance("light" if OS.get_environment("CAP_MODE") == "light" else "dark")
	DisplayServer.window_set_size(Vector2i(w, h))
	root.size = Vector2i(w, h)
	var bg := ColorRect.new()
	bg.color = UK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	root.add_child(margin)
	var col: VBoxContainer = UK.vbox(6)
	margin.add_child(col)

	var states := ["normal", "hover", "pressed", "disabled"]
	col.add_child(UK.lbl("Primary (red)", 13, UK.MUTED))
	col.add_child(_row(UK, states, "primary"))
	col.add_child(UK.lbl("Secondary (outline)", 13, UK.MUTED))
	col.add_child(_row(UK, states, "secondary"))
	col.add_child(UK.lbl("Danger", 13, UK.MUTED))
	col.add_child(_row(UK, states, "danger"))
	col.add_child(UK.lbl("A choice of a set: unselected, selected", 13, UK.MUTED))
	var choice: HBoxContainer = UK.hbox(6)
	for on in [false, true]:
		var b: Button = UK.btn("Hard" if on else "Easy", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UK.set_selected(b, on)
		choice.add_child(b)
	col.add_child(choice)
	col.add_child(UK.lbl("Tabs: inactive, active", 13, UK.MUTED))
	var tabs: HBoxContainer = UK.hbox(0)
	for active in [false, true]:
		var t: Button = UK.tab("MIDS" if active else "DEFS", active)
		tabs.add_child(t)
	col.add_child(tabs)
	col.add_child(UK.lbl("Score figures in each club's accent colour, on the page", 13, UK.MUTED))
	for fixture in [["COL", "ESS"], ["SYD", "ESS"], ["TAS", "GCS"]]:
		var pair: HBoxContainer = UK.hbox(8)
		for code in fixture:
			var cell: VBoxContainer = UK.vbox(0)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_child(UK.lbl(db.club_short(code), 13, UK.TEXT, true))
			var cols: Array = db.club_colours(code)
			cell.add_child(UK.figure("12.8 (80)", 30, cols[2]))
			pair.add_child(cell)
		col.add_child(pair)
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.save_png(out) != OK:
		push_error("capture: could not save " + out)
	print("CAPTURE saved ", out, " at ", w, "x", h)
	quit()


## One row of a control in each state. Hover and pressed are the control's own
## style boxes, shown on a normal button so the state is visible without a pointer.
func _row(UK, states: Array, kind: String) -> HBoxContainer:
	var row: HBoxContainer = UK.hbox(6)
	for st in states:
		var b: Button
		match kind:
			"primary":
				b = UK.btn(str(st).capitalize(), 14, true)
			"danger":
				b = UK.danger_btn(str(st).capitalize(), 14)
			_:
				b = UK.btn(str(st).capitalize(), 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if st == "disabled":
			b.disabled = true
		elif st != "normal":
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox(st))
		row.add_child(b)
	return row
