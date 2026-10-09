class_name OptionsSheet
extends RefCounted
## Settings, from the main menu and from the hub's top bar: display and flow
## preferences apply at once; career actions keep destructive changes behind
## an explicit confirmation.

const APPEARANCE_OPTIONS := [["dark", "Dark"], ["light", "Light"]]
const NAME_OPTIONS := [["generated", "Generated"], ["real", "Real"]]
const NAMES_INFO := "Real shows each player's AFL name; generated names are invented. Ratings and results are the same either way."
const SPEED_OPTIONS := [["1", "1x"], ["2", "2x"], ["4", "4x"], ["8", "8x"]]


## Opens the sheet over `host`. `in_career` adds Main menu and Delete this
## career. Returns the overlay (free it to close).
static func open(host: Control, in_career: bool, quit := false) -> Control:
	var box := UiKit.modal_box(host, 440.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "Settings"
	UiKit.close_on_outside_tap(box)
	var v: VBoxContainer = box["body"]
	v.add_theme_constant_override("separation", 6)
	v.add_child(UiKit.heading("Settings", UiKit.H1))

	_row(v, "Appearance", "SettingsAppearance", APPEARANCE_OPTIONS,
			GameState.appearance(), "Changes the interface only; club colours and the football ground stay as they are.",
			func(k):
				if GameState.set_appearance(k):
					overlay.queue_free()
					host.get_tree().call_deferred("reload_current_scene"))
	_row(v, "Player names", "SettingsNames", NAME_OPTIONS,
			"real" if GameState.show_real_names else "generated", NAMES_INFO,
			func(k): GameState.set_show_real_names(k == "real"))
	_row(v, "Mute sounds", "SettingsMuteSounds", [["off", "Off"], ["on", "On"]],
			"on" if GameState.sounds_muted() else "off",
			"Mutes all music and sound effects.",
			func(k): GameState.set_sounds_muted(k == "on"))
	_row(v, "Music", "SettingsMusic", AudioLevels.LEVELS, GameState.music_level(),
			"The music between matches.", func(k): GameState.set_music_level(k))
	_row(v, "Crowd", "SettingsCrowd", AudioLevels.LEVELS, GameState.crowd_level(),
			"The crowd at a match you watch. The match tells you the same either way.",
			func(k): GameState.set_crowd_level(k))
	_row(v, "Ask before playing a round for me", "SettingsSimConfirm", [["on", "On"], ["off", "Off"]],
			"on" if GameState.confirm_sim_round() else "off",
			"Play round plays out your own match without you. With this on, it asks first.",
			func(k): GameState.set_confirm_sim_round(k == "on"))
	_row(v, "Match speed", "SettingsSpeed", SPEED_OPTIONS,
			str(int(GameState.match_speed())), "How fast a match you watch starts. You can change it during the game.",
			func(k): GameState.set_match_speed(float(k)))
	if ScreenLayout.is_desktop():
		var sizes := []
		for row in ScreenLayout.SCREEN_SIZES:
			sizes.append([row[0], row[1]])
		_row(v, "Screen size", "SettingsScreenSize", sizes, GameState.screen_size(),
				"Everything bigger, for a big screen across the room. TV suits a television from the couch.",
				func(k): GameState.set_screen_size(k))
		_row(v, "Full screen", "SettingsFullscreen", [["off", "Off"], ["on", "On"]],
				"on" if GameState.fullscreen() else "off", "Fill the screen, with no window border.",
				func(k): GameState.set_fullscreen(k == "on"))
	_row(v, "Tutorials", "SettingsTutorials", [["on", "On"], ["off", "Off"]],
			"on" if GameState.tutorials_on() else "off",
			"A short note the first time you open each screen. Off stops them opening by themselves; notes you've already read don't come back.",
			func(k): GameState.set_tutorials_on(k == "on"))
	_row(v, "Battery saver", "SettingsBatterySaver", [["off", "Off"], ["on", "On"]],
			"on" if GameState.battery_saver() else "off",
			"Draws 30 frames a second instead of 60. Uses less battery; matches and scenes play the same, a little less smoothly.",
			func(k): GameState.set_battery_saver(k == "on"))
	_row(v, "Vignettes", "SettingsVignettes", [["on", "On"], ["off", "Off"]],
			"on" if GameState.vignettes_on() else "off",
			"The match-day scenes: the banner, the centre ball-up, replays, the press conference and the awards. Off skips the scenes; every call and result stays the same.",
			func(k): GameState.set_vignettes_on(k == "on"))
	_row(v, "Centre ball-up scene every match", "SettingsBounceScene", [["off", "Off"], ["on", "On"]],
			"on" if GameState.bounce_scene_every_match() else "off",
			"For playtesting: the centre ball-up call comes at the first centre ball-up of every last quarter you coach, whatever the score.",
			func(k): GameState.set_bounce_scene_every_match(k == "on"))

	if in_career:
		v.add_child(UiKit.spacer(UiKit.GAP))
		v.add_child(UiKit.rule())
		var menu := UiKit.btn("Main menu", UiKit.NAME)
		menu.name = "OptionsMainMenu"
		menu.custom_minimum_size = Vector2(0, 44)
		menu.pressed.connect(func():
			overlay.queue_free()
			Router.to_main_menu())
		v.add_child(menu)
		var fresh := UiKit.btn("New career", UiKit.NAME)
		fresh.name = "OptionsNewCareer"
		fresh.custom_minimum_size = Vector2(0, 44)
		fresh.tooltip_text = "Your current save is kept until you confirm the new career."
		fresh.pressed.connect(func():
			overlay.queue_free()
			Router.to_new_career_setup())
		v.add_child(fresh)
		var confirm := UiKit.vbox(6)
		confirm.name = "DeleteConfirm"
		confirm.visible = false
		var del := UiKit.danger_btn("Delete this career", UiKit.NAME)
		del.name = "OptionsDelete"
		del.custom_minimum_size = Vector2(0, 44)
		del.pressed.connect(func():
			del.visible = false
			confirm.visible = true)
		v.add_child(del)
		var warn := UiKit.lbl("This deletes your saved career for good. It cannot be undone.",
				UiKit.BODY, UiKit.BAD)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		confirm.add_child(warn)
		var row := UiKit.hbox(8)
		var keep := UiKit.btn("Keep it", UiKit.NAME)
		keep.name = "OptionsDeleteCancel"
		keep.custom_minimum_size = Vector2(0, 44)
		keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keep.pressed.connect(func():
			confirm.visible = false
			del.visible = true)
		row.add_child(keep)
		var go := UiKit.btn("Delete career", UiKit.NAME, true)
		go.name = "OptionsDeleteConfirm"
		go.custom_minimum_size = Vector2(0, 44)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.pressed.connect(func():
			overlay.queue_free()
			GameState.delete_saved_career()
			GameState.reset()
			Router.to_main_menu(false))
		row.add_child(go)
		confirm.add_child(row)
		v.add_child(confirm)

	v.add_child(UiKit.spacer(UiKit.GAP))
	var ver := UiKit.lbl("Version %s" % str(ProjectSettings.get_setting("application/config/version", "")),
			UiKit.SMALL, UiKit.MUTED)
	ver.name = "OptionsVersion"
	v.add_child(ver)

	var done := UiKit.btn("Done", 17, true)
	done.name = "SettingsDone"
	done.custom_minimum_size = Vector2(0, 44)
	done.pressed.connect(func(): overlay.queue_free())
	box["footer"].add_child(done)
	if quit and not OS.has_feature("web"):
		var q := UiKit.btn("Quit game", UiKit.NAME)
		q.name = "QuitGame"
		q.pressed.connect(func(): host.get_tree().quit())
		box["footer"].add_child(q)
	return overlay


## A labelled row of choices, the current one outlined, with its one-line
## explanation under it.
static func _row(v: VBoxContainer, title: String, node_name: String, options: Array,
		current: String, note: String, on_pick: Callable) -> void:
	v.add_child(UiKit.spacer(4))
	v.add_child(UiKit.lbl(title, UiKit.BODY, UiKit.TEXT, true))
	v.add_child(UiKit.choice_grid(node_name, options, current, options.size(), on_pick))
	var l := UiKit.lbl(note, UiKit.SMALL, UiKit.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
