extends Control
## Main menu: the title, Continue and New career, and a quiet How to play and
## Settings. New career opens a short setup (player names, difficulty); the
## club is chosen next, at the start of the draft, where each club's first
## pick is shown. The setup changes nothing until the career starts.

var _pitch: PitchView
var _content: VBoxContainer
var _mode := "home"                 # "home" | "setup"
var _help_panel: PanelContainer
var _confirm_overlay: Control
var _guide_overlay: Control
var _settings_overlay: Control
var _load_error: Label
var _logo: TextureRect
## The setup's choices, applied only when the career starts.
var _pick_real := false
var _pick_difficulty := "normal"

## Placeholder title art. Swap the file (same path) to replace it.
const LOGO := preload("res://assets/ui/aussie_rules_dynasties_logo_placeholder.png")
## The logo's widest and tallest on screen, and its share of a short window.
const LOGO_MAX_W := 560.0
const LOGO_MAX_H_SHARE := 0.26
## The lettering's part of the file (1536 x 1024, mostly black ground), with
## a little room, so the tagline sits under the words rather than the ground.
const LOGO_REGION := Rect2(90, 228, 1374, 614)
const TAGLINE := "Build your dynasty."
const NAME_OPTIONS := [["generated", "Generated"], ["real", "Real"]]
const NAMES_INFO := "Real shows each player's AFL name; generated names are invented. Ratings and results are the same either way."


## The title treatment: the logo, whole and undistorted. Its black ground
## adds nothing under an additive blend, so only the lettering shows over
## the menu's darkened oval - the file itself is left as supplied.
func _logo_art() -> TextureRect:
	_logo = TextureRect.new()
	_logo.name = "Logo"
	var art := AtlasTexture.new()
	art.atlas = LOGO
	art.region = LOGO_REGION
	_logo.texture = art
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.size_flags_horizontal = Control.SIZE_FILL
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_logo.material = mat
	_fit_logo()
	return _logo


## Height from the width it can have (aspect kept), capped so a short
## window still shows the buttons.
func _fit_logo() -> void:
	if not is_instance_valid(_logo):
		return
	var aspect := LOGO_REGION.size.y / LOGO_REGION.size.x
	var w := minf(LOGO_MAX_W, UiKit.view_width(self) - 32.0)
	var h := minf(w * aspect, UiKit.view_height(self) * LOGO_MAX_H_SHARE)
	_logo.custom_minimum_size = Vector2(0, roundf(h))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_logo()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pick_real = GameState.show_real_names
	_pick_difficulty = GameState.new_career_difficulty()
	# The oval stays as a faint ground; the logo and buttons carry the screen.
	_pitch = PitchView.new()
	_pitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pitch.setup({"events": [], "roster": [[], []], "home": "", "away": ""})
	_pitch.modulate = Color(1, 1, 1, 0.22)
	_pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pitch)
	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.066, 0.06, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 16)
	add_child(margin)
	_content = UiKit.vbox(12)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(UiKit.scroll(_content))
	get_viewport().size_changed.connect(_render)
	_render()


func _render() -> void:
	if _mode == "setup":
		_show_setup()
	else:
		_show_home()
	_layout()


## The width of the button column and the setup form.
func _column_width(cap: float) -> float:
	return minf(cap, UiKit.view_width(self) - 48.0)


# ---------------------------------------------------------------------------
# Home
# ---------------------------------------------------------------------------
func _show_home() -> void:
	_mode = "home"
	UiKit.clear(_content)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_logo_art())
	var tag := UiKit.subtitle(TAGLINE)
	tag.name = "Tagline"
	_content.add_child(tag)
	_content.add_child(UiKit.spacer(28))

	var col := UiKit.vbox(10)
	col.name = "MenuButtons"
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.custom_minimum_size.x = _column_width(320.0)
	_content.add_child(col)
	if not GameDB.loaded:
		var err := UiKit.lbl("Player data failed to load. Reinstall the game to play.",
				UiKit.SMALL, UiKit.BAD)
		err.name = "DataError"
		err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(err)

	# A career in memory (back from the hub or the draft) or one on disk.
	var resume_draft := GameState.draft != null and not GameState.draft.user_club.is_empty() \
			and GameState.season == null
	var live := resume_draft or GameState.season != null
	var saved := not GameState.has_career() and GameState.has_saved_career()
	if live or saved:
		var cont := UiKit.btn("Continue", 19, true)
		cont.name = "ResumeCareer" if live else "ContinueCareer"
		if live:
			cont.pressed.connect(func(): Router.go("draft" if resume_draft else "hub"))
		else:
			cont.pressed.connect(_on_continue)
		col.add_child(cont)
		var meta := GameState._save_meta() if live else GameState.saved_career_meta()
		if str(meta.get("club", "")) != "":
			var info := UiKit.lbl(_meta_line(meta), UiKit.SMALL, UiKit.MUTED)
			info.name = "CareerMeta"
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(info)
	_load_error = UiKit.lbl("", UiKit.SMALL, UiKit.BAD)
	_load_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_error.visible = false
	col.add_child(_load_error)
	var new_career := UiKit.btn("New career", 19, not (live or saved))
	new_career.name = "NewCareer"
	# No career can start on missing or incomplete player data.
	new_career.disabled = not GameDB.loaded
	new_career.pressed.connect(_on_new_career)
	col.add_child(new_career)

	_content.add_child(UiKit.spacer(18))
	var quiet := UiKit.hbox(4)
	quiet.alignment = BoxContainer.ALIGNMENT_CENTER
	quiet.add_child(_quiet_btn("How to play", "MenuHelp", _show_help))
	quiet.add_child(_quiet_btn("Settings", "MenuSettings", _show_settings))
	_content.add_child(quiet)


## A secondary action that reads as text: no box, muted until pressed.
func _quiet_btn(text: String, node_name: String, cb := Callable()) -> Button:
	var b := UiKit.btn(text, 15)
	b.name = node_name
	b.flat = true
	b.custom_minimum_size = Vector2(120, 44)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", UiKit.MUTED)
	b.add_theme_color_override("font_hover_color", UiKit.TEXT)
	b.add_theme_color_override("font_pressed_color", UiKit.TEXT)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _meta_line(meta: Dictionary) -> String:
	var club := str(meta.get("club", ""))
	var bits: PackedStringArray = []
	if club != "":
		bits.append(GameDB.club_name(club))
	bits.append(str(meta.get("year", "")))
	if str(meta.get("stage", "")) != "":
		bits.append(str(meta["stage"]))
	return "  ·  ".join(bits)


func _on_continue() -> void:
	if GameState.load_career():
		Router.go("hub" if GameState.season != null else "draft")
		return
	_load_error.text = "That save could not be read. Start a new career to replace it."
	_load_error.visible = true


func _on_new_career() -> void:
	_pick_real = GameState.show_real_names
	_pick_difficulty = GameState.new_career_difficulty()
	_mode = "setup"
	_render()


# ---------------------------------------------------------------------------
# New career setup
# ---------------------------------------------------------------------------
func _show_setup() -> void:
	_mode = "setup"
	UiKit.clear(_content)
	_content.alignment = BoxContainer.ALIGNMENT_BEGIN
	var form := UiKit.vbox(UiKit.SECTION)
	form.name = "NewCareerSetup"
	form.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.custom_minimum_size.x = _column_width(440.0)
	_content.add_child(form)
	form.add_child(UiKit.top_bar("New career", true, null, func():
		_close_setup()
		return true))
	form.add_child(_choice("Player names", "NameMode", NAME_OPTIONS,
			"real" if _pick_real else "generated",
			func(_k): return NAMES_INFO + " You can change this later in Settings.",
			func(k): _pick_real = k == "real"))
	var diff_options := []
	for key in GameState.DIFFICULTY_ORDER:
		diff_options.append([key, str(GameState.DIFFICULTIES[key]["label"])])
	form.add_child(_choice("Difficulty", "Difficulty", diff_options, _pick_difficulty,
			func(k): return str(GameState.DIFFICULTIES[k]["text"]),
			func(k): _pick_difficulty = k))
	# On a phone the start button sits at the bottom, under the thumb; on a
	# wide screen it follows the choices.
	var push := Control.new()
	if UiKit.view_height(self) > UiKit.view_width(self):
		push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(push)
	var start := UiKit.btn("Choose your club", 19, true)
	start.name = "StartCareer"
	start.disabled = not GameDB.loaded
	start.pressed.connect(_on_start)
	form.add_child(start)


## A labelled row of options, the current one outlined, with a "?" that
## shows the rule behind them on request instead of a permanent paragraph.
## `info` maps the current key to its explanation; `on_pick` records a pick.
func _choice(title: String, prefix: String, options: Array, current: String,
		info: Callable, on_pick: Callable) -> VBoxContainer:
	var v := UiKit.vbox(8)
	var head := UiKit.hbox(4)
	var t := UiKit.lbl(title, UiKit.H2, UiKit.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var help := _quiet_btn("?", prefix.trim_suffix("Mode") + "Info")
	help.custom_minimum_size = Vector2(44, 44)
	help.tooltip_text = "What this means"
	head.add_child(help)
	v.add_child(head)
	var row := UiKit.hbox(8)
	v.add_child(row)
	var note := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	note.name = prefix + "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.visible = false
	v.add_child(note)
	help.pressed.connect(func(): note.visible = not note.visible)
	var buttons := {}
	var state := {"key": current}
	var paint := func():
		for k in buttons:
			UiKit.set_selected(buttons[k], k == state["key"])
		note.text = str(info.call(state["key"]))
	for opt in options:
		var key := str(opt[0])
		var b := UiKit.btn(str(opt[1]), 16)
		b.name = "%s_%s" % [prefix, key]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			state["key"] = key
			on_pick.call(key)
			paint.call())
		row.add_child(b)
		buttons[key] = b
	paint.call()
	return v


func _close_setup() -> void:
	_mode = "home"
	_render()


func _on_start() -> void:
	if GameState.has_career() or GameState.has_saved_career():
		_confirm_new_career()
		return
	_start_new_career()


func _start_new_career() -> void:
	GameState.set_show_real_names(_pick_real)
	GameState.set_new_career_difficulty(_pick_difficulty)
	GameState.delete_saved_career()
	GameState.reset()
	GameState.begin_draft()
	Router.go("draft")


func _confirm_new_career() -> void:
	var box := UiKit.modal_box(self, 460.0, 260.0)
	_confirm_overlay = box["overlay"]
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.lbl("Start a new career?", 20, UiKit.EMPH, true))
	var meta := GameState.saved_career_meta()
	var what := "your current career"
	if not meta.is_empty():
		what = "your saved career (%s)" % _meta_line(meta)
	var body := UiKit.lbl("This replaces %s. It cannot be undone." % what, 14, UiKit.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	var go := UiKit.btn("Start new career", 17, true)
	go.name = "ConfirmNewCareer"
	go.custom_minimum_size = Vector2(0, 44)
	go.pressed.connect(func():
		_close_confirm()
		_start_new_career())
	box["footer"].add_child(go)
	var cancel := UiKit.btn("Cancel", 16)
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_close_confirm)
	box["footer"].add_child(cancel)


func _close_confirm() -> void:
	if is_instance_valid(_confirm_overlay):
		_confirm_overlay.queue_free()
	_confirm_overlay = null


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
## Display preferences, which apply at once, and (outside the web build) a
## way to quit that does not compete with the menu.
func _show_settings() -> void:
	var box := UiKit.modal_box(self, 440.0, 280.0)
	_settings_overlay = box["overlay"]
	_settings_overlay.name = "Settings"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Settings", UiKit.H1))
	v.add_child(_choice("Player names", "SettingsNames", NAME_OPTIONS,
			"real" if GameState.show_real_names else "generated",
			func(_k): return NAMES_INFO,
			func(k): GameState.set_show_real_names(k == "real")))
	var done := UiKit.btn("Done", 17, true)
	done.name = "SettingsDone"
	done.pressed.connect(_close_settings)
	box["footer"].add_child(done)
	if not OS.has_feature("web"):
		var quit := UiKit.btn("Quit game", 16)
		quit.name = "QuitGame"
		quit.pressed.connect(func(): get_tree().quit())
		box["footer"].add_child(quit)


func _close_settings() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
	_settings_overlay = null


func _layout() -> void:
	if is_instance_valid(_help_panel):
		var viewport_size := get_viewport().get_visible_rect().size
		_help_panel.size = Vector2(minf(560, viewport_size.x - 24), minf(600, viewport_size.y - 24))
		_help_panel.position = (viewport_size - _help_panel.size) / 2


## Router back hook: close whatever is open, then leave the setup; on the
## menu itself Back does nothing.
func handle_back() -> bool:
	if is_instance_valid(_guide_overlay):
		_guide_overlay.queue_free()
		_guide_overlay = null
		return true
	if is_instance_valid(_confirm_overlay):
		_close_confirm()
		return true
	if is_instance_valid(_settings_overlay):
		_close_settings()
		return true
	if is_instance_valid(_help_panel):
		var overlay := _help_panel.get_parent()
		_help_panel = null
		overlay.queue_free()
		return true
	if _mode == "setup":
		_close_setup()
		return true
	return false


func _show_help() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_help_panel = UiKit.panel(UiKit.PANEL, 16, 12)
	overlay.add_child(_help_panel)
	var v := UiKit.vbox(12)
	_help_panel.add_child(v)
	v.add_child(UiKit.heading("How to play", UiKit.H1))
	var text := UiKit.lbl(
			("1. Choose your club. All %d clubs start with empty lists.\n\n"
			% GameDB.active_clubs(2026).size())
			+ "2. Draft from one shared player pool under the same cap. The random order reverses each round. Rivals pick between your turns. Tap a player to see what kind of footballer he is; only the Draft button picks him.\n\n"
			+ "3. Track every selection in Picks. The position cards in the pool show your list's coverage; tap one to filter the pool. Carry at least two rucks.\n\n"
			+ "4. Play 24 rounds, with matches driven by your players' rated abilities. Set your tactics in the coach box. After each game every player develops: his training plan (Position plan to start) turns his XP into the kind of footballer you choose, and fit players you leave out develop in the reserves at about half the senior rate. Choose plans in Training.\n\n"
			+ "5. Pick your own side on the Team screen, or let the best 22 be picked around injuries. Two of your five midfielders play the wings: a runner suits it, a ball-winner is wasted there. A tagger makes a tag bite.\n\n"
			+ ("6. Finish in the top %d to play finals and chase the flag. The top four start in the qualifying finals, 5-10 in the wildcards and eliminations. The season's awards, the honour roll and league records are in the Season Review.\n\n"
			% Season.FINALISTS)
			+ "7. In the off-season, re-sign, release, sign free agents and trade in Trades & Contracts, then draft the next class. The hub's League news follows the whole league.\n\n"
			+ "Difficulty (Easy, Normal or Hard) is chosen when you start a new career: it sets how fast rivals develop, how hard they bargain, and how much XP your players earn.\n\n"
			+ "Player names are generated by default. Settings switches to real AFL names, such as Jordan Dawson, without changing ratings or gameplay.\n\n"
			+ "Rotate your device at any time. Your draft picks, search and filters stay intact.", 16)
	v.add_child(UiKit.scroll(text))
	var guide := UiKit.btn("Stat guide", 17)
	guide.name = "MenuStatGuide"
	guide.pressed.connect(func():
		_help_panel = null
		overlay.queue_free()
		_guide_overlay = StatGuide.show(self))
	v.add_child(guide)
	var ok := UiKit.btn("Got it", 17, true)
	ok.pressed.connect(func():
		_help_panel = null
		overlay.queue_free())
	v.add_child(ok)
	_layout()
