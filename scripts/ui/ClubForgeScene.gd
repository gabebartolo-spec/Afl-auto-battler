extends Control
## Club Forge (ARD-M7-009): the main menu's creative destination. V1 holds
## Create a player (ARD-M7-008): a prospect the coach shapes - position,
## height, play style, strengths, foot, number and look - and can bring into a
## new career, where he enters the first National Draft like anyone else. His
## OVR, POT, club and pick are never chosen here. Create a club joins later.
## The player is kept in settings, outside any career (GameState.forge_player).

const ROLES := [["FWD", "Forward"], ["MID", "Midfield"], ["DEF", "Defence"], ["RUCK", "Ruck"]]
const STYLE_LABELS := {
	"key_forward": "Key forward", "small_forward": "Small forward", "defensive_forward": "Defensive forward",
	"leading_forward": "Leading forward", "inside": "Inside midfielder", "outside": "Outside runner",
	"tagger": "Tagger", "playmaker": "Playmaker", "key_defender": "Key defender", "rebounder": "Rebounder",
	"lockdown": "Lockdown defender", "interceptor": "Interceptor", "tap_ruck": "Tap ruck", "mobile_ruck": "Mobile ruck",
}
const TRAIT_LABELS := {
	"marking": "Marking", "kicking": "Kicking", "goalkicking": "Goalkicking", "contested": "Contested ball",
	"pressure": "Pressure", "reading": "Reading the play", "running": "Running", "vision": "Vision",
	"ruckwork": "Ruckwork",
}
const HAIR_LABELS := {
	"bald": "Bald", "buzz": "Buzz cut", "short_crop": "Short crop", "crew": "Crew cut", "side_part": "Side part",
	"textured_short": "Textured", "messy_medium": "Messy", "swept_back": "Swept back", "mullet": "Mullet",
	"mullet_long": "Long mullet", "curly_short": "Short curls", "curly_medium": "Curls", "afro": "Afro",
	"long": "Long", "tied_back": "Tied back",
}
const BEARD_LABELS := {
	"clean": "Clean shaven", "stubble_light": "Light stubble", "stubble_heavy": "Heavy stubble",
	"moustache": "Moustache", "short_beard": "Short beard", "full_beard": "Full beard", "goatee": "Goatee",
	"beard_moustache": "Beard and moustache",
}
const LEVEL_LABELS := [["0", "None"], ["1", "Light"], ["2", "Heavy"]]
const SCAR_LABELS := [["0", "None"], ["1", "Light"], ["2", "Moderate"]]

var _root: VBoxContainer
var _spec := {}
var _editing := false
var _problem: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)
	_root = UiKit.vbox(10)
	margin.add_child(_root)
	_spec = GameState.forge_player()
	get_viewport().size_changed.connect(_build)
	_build()


## Back closes the form first, then leaves the Forge.
func handle_back() -> bool:
	if _editing:
		_editing = false
		_spec = GameState.forge_player()
		_build()
		return true
	return false


func _build() -> void:
	if not is_inside_tree():
		return
	UiKit.clear(_root)
	_root.add_child(UiKit.top_bar("Club Forge", true, null, func(): return handle_back()))
	var body := UiKit.vbox(UiKit.GAP)
	body.name = "ForgeBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _editing:
		_player_form(body)
	else:
		_home(body)
	_root.add_child(UiKit.scroll(body))


func _home(body: VBoxContainer) -> void:
	body.add_child(UiKit.lbl("Your player", UiKit.H2, UiKit.TEXT, true))
	var saved := GameState.forge_player()
	if saved.is_empty():
		var none := UiKit.lbl("Create a prospect and bring him into a new career. He enters the first National Draft like any other kid: where he goes, and what he becomes, is up to the clubs and to him.",
				UiKit.BODY, UiKit.MUTED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(none)
		var make := UiKit.btn("Create a player", 17, true)
		make.name = "ForgeCreatePlayer"
		make.custom_minimum_size.y = 48
		make.pressed.connect(func():
			_spec = _default_spec()
			_editing = true
			_build())
		body.add_child(make)
		return
	var who := UiKit.lbl("%s %s" % [saved["first"], saved["last"]], UiKit.H1, UiKit.TEXT, true)
	who.name = "ForgePlayerName"
	body.add_child(who)
	var bits := PackedStringArray([STYLE_LABELS.get(str(saved.get("style", "")), _role_label(str(saved["role"]))),
			"%d cm" % int(saved["height_cm"]), "%s foot" % ("Left" if str(saved.get("foot", "R")) == "L" else "Right")])
	var line := UiKit.lbl(" · ".join(bits), UiKit.BODY, UiKit.MUTED)
	line.name = "ForgePlayerLine"
	body.add_child(line)
	var note := UiKit.lbl("Bring him into a career from New career.", UiKit.SMALL, UiKit.MUTED)
	body.add_child(note)
	body.add_child(UiKit.spacer(8))
	var edit := UiKit.btn("Edit", 16)
	edit.name = "ForgeEditPlayer"
	edit.custom_minimum_size.y = 44
	edit.pressed.connect(func():
		_spec = saved.duplicate(true)
		_editing = true
		_build())
	body.add_child(edit)
	var drop := UiKit.btn("Remove", 16)
	drop.name = "ForgeRemovePlayer"
	drop.flat = true
	drop.custom_minimum_size.y = 44
	drop.pressed.connect(func():
		GameState.set_forge_player({})
		_build())
	body.add_child(drop)


func _default_spec() -> Dictionary:
	return {"first": "", "last": "", "nickname": "", "role": "MID", "role2": "", "height_cm": 184,
			"style": "", "strengths": [], "weaknesses": [], "foot": "R", "number_pref": 0,
			"look": {"skin": 1, "hair": 1, "hair_style": "short_crop", "beard": "clean", "socks": "tall",
					"headband": false, "scars": 0, "bandage": 0, "tattoos": []}}


func _player_form(body: VBoxContainer) -> void:
	var cols := 2 if UiKit.view_width(self) < 520.0 else 4
	body.add_child(_heading("Name"))
	var first := UiKit.search_field(str(_spec["first"]), "First name")
	first.name = "ForgeFirst"
	first.clear_button_enabled = false
	first.text_changed.connect(func(t): _spec["first"] = t)
	body.add_child(first)
	var last := UiKit.search_field(str(_spec["last"]), "Last name")
	last.name = "ForgeLast"
	last.clear_button_enabled = false
	last.text_changed.connect(func(t): _spec["last"] = t)
	body.add_child(last)
	var nick := UiKit.search_field(str(_spec.get("nickname", "")), "Nickname (optional)")
	nick.name = "ForgeNickname"
	nick.clear_button_enabled = false
	nick.text_changed.connect(func(t): _spec["nickname"] = t)
	body.add_child(nick)

	body.add_child(_heading("Position"))
	body.add_child(UiKit.choice_grid("ForgeRole", ROLES, str(_spec["role"]), cols, func(k):
		_spec["role"] = k
		if str(_spec["role2"]) == k:
			_spec["role2"] = ""
		_spec["style"] = ""
		var band: Array = Prospects.CUSTOM_HEIGHT[k]
		_spec["height_cm"] = clampi(int(_spec["height_cm"]), int(band[0]), int(band[1]))
		_build()))
	var second := [["", "None"]]
	for r in ROLES:
		if str(r[0]) != str(_spec["role"]):
			second.append(r)
	body.add_child(_sub("Second position"))
	body.add_child(UiKit.choice_grid("ForgeRole2", second, str(_spec["role2"]), cols, func(k): _spec["role2"] = k))

	body.add_child(_sub("Height"))
	body.add_child(_stepper("ForgeHeight", "height_cm", "%d cm", Prospects.CUSTOM_HEIGHT[str(_spec["role"])]))

	body.add_child(_heading("Play style"))
	var styles := [["", "None"]]
	for k in Prospects.CUSTOM_STYLES[str(_spec["role"])]:
		styles.append([k, STYLE_LABELS[k]])
	body.add_child(UiKit.choice_grid("ForgeStyle", styles, str(_spec["style"]), cols, func(k): _spec["style"] = k))
	body.add_child(_sub("Strengths (up to two)"))
	body.add_child(_toggles("ForgeStrength", "strengths", "weaknesses", cols))
	body.add_child(_sub("Weaknesses (up to two)"))
	body.add_child(_toggles("ForgeWeakness", "weaknesses", "strengths", cols))
	body.add_child(_sub("Dominant foot"))
	body.add_child(UiKit.choice_grid("ForgeFoot", [["R", "Right"], ["L", "Left"]], str(_spec["foot"]), 2,
			func(k): _spec["foot"] = k))
	body.add_child(_sub("Preferred number (if it's free)"))
	body.add_child(_stepper("ForgeNumber", "number_pref", "%d", [0, 99], "Any"))

	body.add_child(_heading("Look"))
	var look: Dictionary = _spec["look"]
	body.add_child(_sub("Skin tone"))
	body.add_child(_swatches("ForgeSkin", Appearance.SKIN, look, "skin"))
	body.add_child(_sub("Hair colour"))
	body.add_child(_swatches("ForgeHairColour", Appearance.HAIR, look, "hair"))
	body.add_child(_sub("Hair"))
	body.add_child(UiKit.choice_grid("ForgeHair", _pairs(Appearance.HAIR_STYLES, HAIR_LABELS), str(look["hair_style"]), cols,
			func(k): look["hair_style"] = k))
	body.add_child(_sub("Facial hair"))
	body.add_child(UiKit.choice_grid("ForgeBeard", _pairs(Appearance.BEARDS, BEARD_LABELS), str(look["beard"]), cols,
			func(k): look["beard"] = k))
	body.add_child(_sub("Socks"))
	body.add_child(UiKit.choice_grid("ForgeSocks", [["tall", "Tall"], ["short", "Short"]], str(look["socks"]), 2,
			func(k): look["socks"] = k))
	body.add_child(_sub("Headband"))
	body.add_child(UiKit.choice_grid("ForgeHeadband", [["off", "Off"], ["on", "On"]], "on" if bool(look["headband"]) else "off", 2,
			func(k): look["headband"] = k == "on"))
	# No freckles: the director's call, an unnecessary detail.
	for f in [["scars", "Scars", SCAR_LABELS], ["bandage", "Bandaging", LEVEL_LABELS]]:
		body.add_child(_sub(str(f[1])))
		var key := str(f[0])
		body.add_child(UiKit.choice_grid("Forge_" + key, f[2], str(int(look.get(key, 0))), 3,
				func(k): look[key] = int(k)))
	body.add_child(_sub("Tattoos"))
	var ink := "0" if (look["tattoos"] as Array).is_empty() else ("1" if (look["tattoos"] as Array).size() == 1 else "2")
	body.add_child(UiKit.choice_grid("ForgeTattoos", LEVEL_LABELS, ink, 3, func(k):
		var n := {"0": 0, "1": 1, "2": 3}[k] as int
		var tats := []
		for i in n:
			tats.append({"place": Appearance.TATTOO_PLACES[i * 2 % Appearance.TATTOO_PLACES.size()], "design": "design_%d" % (i + 1)})
		look["tattoos"] = tats))
	var art := UiKit.lbl("Hair, facial hair and the rest show on the match figures as the new looks are drawn.", UiKit.SMALL, UiKit.MUTED)
	art.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(art)

	body.add_child(UiKit.spacer(10))
	_problem = UiKit.lbl("", UiKit.SMALL, UiKit.BAD)
	_problem.name = "ForgeProblem"
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem.visible = false
	body.add_child(_problem)
	var save := UiKit.btn("Save player", 17, true)
	save.name = "ForgeSavePlayer"
	save.custom_minimum_size.y = 48
	save.pressed.connect(_on_save)
	body.add_child(save)


func _on_save() -> void:
	var why := Prospects.custom_problem(_spec)
	if why != "":
		_problem.text = why
		_problem.visible = true
		return
	GameState.set_forge_player(_spec)
	_editing = false
	_build()


func _heading(text: String) -> Control:
	var v := UiKit.vbox(0)
	v.add_child(UiKit.spacer(10))
	v.add_child(UiKit.lbl(text, UiKit.H2, UiKit.TEXT, true))
	return v


func _sub(text: String) -> Label:
	return UiKit.lbl(text, UiKit.SMALL, UiKit.MUTED)


func _role_label(role: String) -> String:
	for r in ROLES:
		if str(r[0]) == role:
			return str(r[1])
	return role


func _pairs(keys: Array, labels: Dictionary) -> Array:
	var out := []
	for k in keys:
		out.append([k, labels.get(k, k)])
	return out


## − value + for a number in [lo, hi]; `zero_label` names 0 when 0 means "none".
func _stepper(node_name: String, key: String, fmt: String, band: Array, zero_label := "") -> Control:
	var h := UiKit.hbox(8)
	h.name = node_name
	var value := UiKit.lbl("", UiKit.BODY, UiKit.TEXT, true)
	value.name = node_name + "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var show := func():
		var v := int(_spec[key])
		value.text = zero_label if v == 0 and zero_label != "" else fmt % v
	for d in [-1, 1]:
		var b := UiKit.btn("−" if d < 0 else "+", 18)
		b.name = node_name + ("Down" if d < 0 else "Up")
		b.custom_minimum_size = Vector2(56, 44)
		b.pressed.connect(func():
			_spec[key] = clampi(int(_spec[key]) + d, int(band[0]), int(band[1]))
			show.call())
		if d < 0:
			h.add_child(b)
			h.add_child(value)
		else:
			h.add_child(b)
	show.call()
	return h


## Up to two of the traits, never one already picked on the other side.
func _toggles(node_name: String, key: String, other: String, cols: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for k in Prospects.CUSTOM_TRAITS:
		if k == "ruckwork" and str(_spec["role"]) != "RUCK" and str(_spec["role2"]) != "RUCK":
			continue
		var b := UiKit.btn(TRAIT_LABELS[k], 14)
		b.name = "%s_%s" % [node_name, k]
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.paint_choice(b, (_spec[key] as Array).has(k))
		b.pressed.connect(func():
			var mine: Array = _spec[key]
			if mine.has(k):
				mine.erase(k)
			elif mine.size() < 2 and not (_spec[other] as Array).has(k):
				mine.append(k)
			_build())
		grid.add_child(b)
	return grid


## A row of colour swatches; the chosen one outlined.
func _swatches(node_name: String, colours: Array, look: Dictionary, key: String) -> HBoxContainer:
	var h := UiKit.hbox(6)
	h.name = node_name
	for i in colours.size():
		var b := Button.new()
		b.name = "%s_%d" % [node_name, i]
		b.custom_minimum_size = Vector2(44, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on := int(look.get(key, 0)) == i
		var sb := UiKit.style(colours[i], 0, UiKit.RADIUS, UiKit.TEXT if on else Color.TRANSPARENT)
		if on:
			sb.set_border_width_all(3)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func():
			look[key] = i
			_build())
		h.add_child(b)
	return h
