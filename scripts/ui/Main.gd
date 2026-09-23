extends Control
## Main menu. The scrollable foreground also fits short landscape windows.

var _pitch: PitchView
var _buttons: VBoxContainer
var _help_panel: PanelContainer
var _name_toggle: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not GameState.player_names_changed.is_connected(_sync_name_toggle):
		GameState.player_names_changed.connect(_sync_name_toggle)
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
	v.add_child(_name_mode_control())
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
	var foot := UiKit.lbl("2026 player stats · 18 clubs · draft the next\ngeneration "
			+ "at the end of every season", 12, UiKit.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _name_mode_control() -> Control:
	var card := UiKit.panel(UiKit.PANEL_ALT, 10, 8)
	card.custom_minimum_size.x = minf(440.0, UiKit.view_width(self) - 32.0)
	var v := UiKit.vbox(5)
	card.add_child(v)
	var row := UiKit.hbox(8)
	v.add_child(row)
	var copy := UiKit.vbox(1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	copy.add_child(UiKit.lbl("PLAYER LABELS", 12, UiKit.GOLD, true))
	copy.add_child(UiKit.lbl("Generated names by default. Turn this on for real AFL names.",
			12, UiKit.MUTED))
	_name_toggle = UiKit.btn("", 14)
	_name_toggle.name = "PlayerNamesToggle"
	_name_toggle.toggle_mode = true
	_name_toggle.button_pressed = GameState.show_real_names
	_name_toggle.custom_minimum_size = Vector2(176, 44)
	_name_toggle.toggled.connect(_on_name_toggle)
	row.add_child(_name_toggle)
	_sync_name_toggle()
	return card


func _on_name_toggle(enabled: bool) -> void:
	GameState.set_show_real_names(enabled)
	_sync_name_toggle()


func _sync_name_toggle() -> void:
	if not is_instance_valid(_name_toggle):
		return
	_name_toggle.button_pressed = GameState.show_real_names
	_name_toggle.text = "Real names: ON" if GameState.show_real_names else "Fictional: ON"
	_name_toggle.tooltip_text = "Real names show the AFL player. Fictional names are generated. Prospects with no real counterpart keep a generated name."


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
			+ "4. Play 24 rounds, with matches driven by your players' rated abilities. Set your tactics in the coach box. After each game every player earns XP, and Training lets you spend it on any stat.\n\n"
			+ "5. Finish in the top eight to play finals and chase the flag.\n\n"
			+ "Player labels are generated names by default. The main-menu toggle switches to real AFL names, such as Jordan Dawson, without changing ratings or gameplay. It does not add a plays-like comparison.\n\n"
			+ "Rotate your device at any time. Your draft picks, search and filters stay intact.", 16)
	v.add_child(UiKit.scroll(text))
	var ok := UiKit.btn("Got it", 17, true)
	ok.pressed.connect(func():
		_help_panel = null
		overlay.queue_free())
	v.add_child(ok)
	_layout()
