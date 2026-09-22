extends Control
## Main menu.

var _pitch: PitchView


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# The oval doubles as the menu backdrop.
	_pitch = PitchView.new()
	_pitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pitch.setup({"events": [], "roster": [[], []], "home": "", "away": ""})
	_pitch.modulate = Color(1, 1, 1, 0.55)
	add_child(_pitch)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.03, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var v := UiKit.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(v)

	v.add_child(UiKit.title("AFL AUTO-BATTLER"))
	v.add_child(UiKit.subtitle(
			"Draft a full 44-player list from real 2026 AFL season stats,\n"
			+ "then play a 24-round home and away season plus finals."))
	v.add_child(UiKit.spacer(22))

	var stats := UiKit.lbl(_data_line(), 13, UiKit.MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	v.add_child(UiKit.spacer(14))

	var buttons := UiKit.vbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(buttons)

	var b_new := UiKit.btn("New Career", 19, true)
	b_new.custom_minimum_size = Vector2(340, 54)
	b_new.pressed.connect(_on_new_career)
	buttons.add_child(b_new)

	var b_how := UiKit.btn("How It Works", 17)
	b_how.custom_minimum_size = Vector2(340, 50)
	b_how.pressed.connect(_show_help)
	buttons.add_child(b_how)

	var b_quit := UiKit.btn("Quit", 17)
	b_quit.custom_minimum_size = Vector2(340, 50)
	b_quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(b_quit)

	v.add_child(UiKit.spacer(26))
	var foot := UiKit.lbl(
			"Player data harvested from afltables.com (2026 season).  "
			+ "Match engine calibrated against real team totals.",
			11, Color(0.5, 0.56, 0.51))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)


func _data_line() -> String:
	if not GameDB.loaded:
		return "DATA NOT LOADED - check data/players_2026.csv"
	return "%d players  -  %d clubs  -  %d rated attributes each" % [
			GameDB.players.size(), GameDB.clubs.size(), 13]


func _on_new_career() -> void:
	GameState.reset()
	GameState.begin_draft()
	Router.go("draft")


func _show_help() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)

	var p := UiKit.panel(UiKit.PANEL, 22, 12)
	p.custom_minimum_size = Vector2(560, 0)
	centre.add_child(p)

	var v := UiKit.vbox(9)
	p.add_child(v)
	v.add_child(UiKit.lbl("How It Works", 24, UiKit.GOLD, true))
	v.add_child(UiKit.lbl(
			"1. Pick a club to take over. The other 17 keep the lists they\n"
			+ "    actually fielded in 2026.\n\n"
			+ "2. Draft 44 players from the whole competition under a salary\n"
			+ "    cap. Every player is rated from their real season stats.\n\n"
			+ "3. Play 24 rounds. Each match is simulated as a sequence of\n"
			+ "    possession chains: stoppages, clearances, marks, tackles,\n"
			+ "    inside 50s and shots on goal, all driven by your players'\n"
			+ "    actual abilities.\n\n"
			+ "4. Finish top 8 and play a real AFL finals series through to\n"
			+ "    the Grand Final.\n\n"
			+ "The engine is tuned so a simulated match reproduces real AFL\n"
			+ "team totals - about 88 points, 365 disposals, 52 inside 50s,\n"
			+ "34 hit-outs and 18 free kicks per team per game.",
			14, UiKit.TEXT))
	var ok := UiKit.btn("Got it", 17, true)
	ok.pressed.connect(func(): overlay.queue_free())
	v.add_child(ok)
