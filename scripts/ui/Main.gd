extends Control
## Main menu. The scrollable foreground also fits short landscape windows.

var _pitch: PitchView
var _buttons: VBoxContainer
var _help_panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pitch = PitchView.new()
	_pitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pitch.setup({"events": [], "roster": [[], []], "home": "", "away": ""})
	_pitch.modulate = Color(1, 1, 1, 0.55)
	_pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pitch)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.03, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var v := UiKit.vbox(12)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(UiKit.scroll(v))
	v.add_child(UiKit.title("AFL AUTO-BATTLER"))
	v.add_child(UiKit.subtitle(
			"Rebuild the league. Draft your list, then take it all the way to September."))
	v.add_child(UiKit.spacer(12))
	var stats := UiKit.lbl(_data_line(), 13, UiKit.MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	v.add_child(UiKit.spacer(8))
	_buttons = UiKit.vbox(10)
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_buttons)

	var resume_draft := GameState.draft != null and not GameState.draft.user_club.is_empty() \
			and GameState.season == null
	if resume_draft or GameState.season != null:
		var resume := UiKit.btn("Resume Draft" if resume_draft else "Resume Season", 19, true)
		resume.name = "ResumeCareer"
		resume.pressed.connect(func(): Router.go("draft" if resume_draft else "hub"))
		_buttons.add_child(resume)
	var new_career := UiKit.btn("New Career", 19, not resume_draft and GameState.season == null)
	new_career.name = "NewCareer"
	new_career.pressed.connect(_on_new_career)
	_buttons.add_child(new_career)
	var help := UiKit.btn("How It Works", 17)
	help.pressed.connect(_show_help)
	_buttons.add_child(help)
	if not OS.has_feature("web"):
		var quit := UiKit.btn("Quit", 17)
		quit.pressed.connect(func(): get_tree().quit())
		_buttons.add_child(quit)
	v.add_child(UiKit.spacer(14))
	var foot := UiKit.lbl("2026 player stats · 18 clubs · One new league", 12, UiKit.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	_buttons.custom_minimum_size.x = minf(340, UiKit.view_width(self) - 32)
	if is_instance_valid(_help_panel):
		var viewport_size := get_viewport().get_visible_rect().size
		_help_panel.size = Vector2(minf(560, viewport_size.x - 24), minf(600, viewport_size.y - 24))
		_help_panel.position = (viewport_size - _help_panel.size) / 2


func _data_line() -> String:
	if not GameDB.loaded:
		return "Data not loaded — check data/players_2026.csv"
	return "%d players · %d clubs · 13 rated attributes" % [GameDB.players.size(), GameDB.clubs.size()]


func _on_new_career() -> void:
	GameState.reset()
	GameState.begin_draft()
	Router.go("draft")


func _show_help() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_help_panel = UiKit.panel(UiKit.PANEL, 16, 12)
	overlay.add_child(_help_panel)
	var v := UiKit.vbox(12)
	_help_panel.add_child(v)
	v.add_child(UiKit.heading("HOW IT WORKS", 28))
	var text := UiKit.lbl(
			"1. Choose your club. All 18 clubs start with empty lists.\n\n"
			+ "2. Draft from one shared player pool under the same cap. The random order reverses each round. Rivals pick between your turns.\n\n"
			+ "3. Track every selection in Picks. The position counters show your list's coverage; tap one to filter the pool. Carry at least two rucks.\n\n"
			+ "4. Play 24 rounds, with matches driven by your players' rated abilities. Set your tactics in the coach box.\n\n"
			+ "5. Finish in the top eight to play finals and chase the flag.\n\n"
			+ "Rotate your device at any time. Your draft picks, search and filters stay intact.", 16)
	v.add_child(UiKit.scroll(text))
	var ok := UiKit.btn("Got it", 17, true)
	ok.pressed.connect(func():
		_help_panel = null
		overlay.queue_free())
	v.add_child(ok)
	_layout()
