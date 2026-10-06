extends Control
## Club Forge (ARD-M7-009): the main menu's creative destination.
## Create a player (ARD-M7-008): a prospect the coach shapes - position,
## height, play style, strengths, foot, number and look - and can bring into a
## new career, where he enters the first National Draft like anyone else. His
## OVR, POT, club and pick are never chosen here.
## Create a club: a club from a real football place - its name, ground,
## colours and guernsey - that joins a new career as an extra club and drafts
## its list in the League Draft like everyone else (ClubForge).
## Both are kept in settings, outside any career (GameState.forge_player and
## forge_club), and brought in from New career.

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
const STATES := [["VIC", "Victoria"], ["SA", "South Australia"], ["WA", "Western Australia"],
		["NSW", "New South Wales"], ["QLD", "Queensland"], ["TAS", "Tasmania"], ["ACT", "ACT"],
		["NT", "Northern Territory"]]
const DESIGN_LABELS := {
	"plain": "Plain", "stripes": "Stripes", "hoops": "Hoops", "sash": "Sash", "yoke": "Yoke",
	"band": "Chest band", "chevrons": "Chevrons", "panels": "Panels", "chevron": "V", "sides": "Side panels",
	"tiers": "Tiers", "shoulders": "Shoulders",
}

var _root: VBoxContainer
var _spec := {}
var _club := {}
var _club_state := "VIC"
var _form := ""   # "", "player" or "club"
var _problem: Label
var _scroll: ScrollContainer
var _scroll_form := ""


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
	if _form != "":
		_form = ""
		_spec = GameState.forge_player()
		_club = GameState.forge_club()
		_build()
		return true
	return false


func _build() -> void:
	if not is_inside_tree():
		return
	# A pick rebuilds the form; keep the thumb where it was on the same form.
	var keep := _scroll.scroll_vertical if is_instance_valid(_scroll) and _scroll_form == _form else 0
	UiKit.clear(_root)
	_root.add_child(UiKit.top_bar("Club Forge", true, null, func(): return handle_back()))
	var body := UiKit.vbox(UiKit.GAP)
	body.name = "ForgeBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _form == "player":
		_player_form(body)
	elif _form == "club":
		_club_form(body)
	else:
		_home(body)
		_club_home(body)
	_scroll = UiKit.scroll(body)
	_scroll_form = _form
	_root.add_child(_scroll)
	if keep > 0:
		_restore_scroll.call_deferred(_scroll, keep)


func _restore_scroll(sc: ScrollContainer, value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_vertical = value


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
			_form = "player"
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
	var edit := UiKit.btn("Edit", UiKit.NAME)
	edit.name = "ForgeEditPlayer"
	edit.custom_minimum_size.y = 44
	edit.pressed.connect(func():
		_spec = saved.duplicate(true)
		_form = "player"
		_build())
	body.add_child(edit)
	var drop := UiKit.btn("Remove", UiKit.NAME)
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
					"headband": false, "bandage": 0, "tattoos": []}}


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
	# No freckles or scars: the director's call, unnecessary detail.
	for f in [["bandage", "Bandaging", LEVEL_LABELS]]:
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
	_form = ""
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
		var b := UiKit.btn("−" if d < 0 else "+", UiKit.HEADING)
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


# ---------------------------------------------------------------------------
# Create a club
# ---------------------------------------------------------------------------
var _auto_code := ""
var _kit_touched := false


func _club_home(body: VBoxContainer) -> void:
	body.add_child(_heading("Your club"))
	var saved := GameState.forge_club()
	if saved.is_empty():
		var none := UiKit.lbl("Make a club from a real football place: its name, its ground, its colours and its guernsey. It joins a new career as an extra club and drafts its list in the League Draft like everyone else.",
				UiKit.BODY, UiKit.MUTED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(none)
		var make := UiKit.btn("Create a club", 17)
		make.name = "ForgeCreateClub"
		make.custom_minimum_size.y = 48
		make.pressed.connect(func():
			_club = _default_club()
			_club_state = "VIC"
			_auto_code = ""
			_kit_touched = false
			_form = "club"
			_build())
		body.add_child(make)
		return
	var head := UiKit.hbox(10)
	head.add_child(UiKit.colour_marker(_club_colours(saved), 30.0))
	var title := UiKit.lbl(str(saved.get("name", "")), UiKit.H1, UiKit.TEXT, true)
	title.name = "ForgeClubTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	body.add_child(head)
	var loc := ClubForge.location(str(saved.get("location", "")))
	var ground := str(saved.get("ground", "")) if str(saved.get("ground", "")) != "" else str(loc.get("ground", ""))
	var line := UiKit.lbl(" · ".join(PackedStringArray([str(saved.get("short", "")), str(saved.get("code", "")), ground])),
			UiKit.BODY, UiKit.MUTED)
	line.name = "ForgeClubLine"
	body.add_child(line)
	body.add_child(UiKit.lbl("Bring it into a career from New career.", UiKit.SMALL, UiKit.MUTED))
	body.add_child(UiKit.spacer(8))
	var edit := UiKit.btn("Edit club", 16)
	edit.name = "ForgeEditClub"
	edit.custom_minimum_size.y = 44
	edit.pressed.connect(func():
		_club = saved.duplicate(true)
		_club_state = str(loc.get("state", "VIC"))
		_auto_code = ""
		_kit_touched = true
		_form = "club"
		_build())
	body.add_child(edit)
	var drop := UiKit.btn("Remove", 16)
	drop.name = "ForgeRemoveClub"
	drop.flat = true
	drop.custom_minimum_size.y = 44
	drop.pressed.connect(func():
		GameState.set_forge_club({})
		_build())
	body.add_child(drop)


func _default_club() -> Dictionary:
	return {"name": "", "short": "", "code": "", "location": "", "ground": "",
			"primary": ClubForge.palette_hex("navy"), "secondary": ClubForge.palette_hex("white"),
			"accent": ClubForge.palette_hex("gold"), "design": "plain", "kit": "p/s/a"}


func _club_form(body: VBoxContainer) -> void:
	var cols := 2 if UiKit.view_width(self) < 520.0 else 4
	body.add_child(_heading("Home"))
	body.add_child(UiKit.choice_grid("ForgeState", STATES, _club_state, cols, func(k):
		_club_state = k
		_build()))
	var places := []
	for loc in ClubForge.locations():
		if str(loc.get("state", "")) == _club_state:
			places.append([str(loc["id"]), str(loc["place"])])
	body.add_child(_sub("Place"))
	body.add_child(UiKit.choice_grid("ForgePlace", places, str(_club["location"]), cols, func(k): _pick_place(k)))
	var here := ClubForge.location(str(_club["location"]))
	if not here.is_empty():
		var grounds := ClubForge.grounds(here)
		if grounds.size() > 1:
			body.add_child(_sub("Ground"))
			var opts := []
			for i in grounds.size():
				opts.append([str(i), grounds[i]])
			body.add_child(UiKit.choice_grid("ForgeGround", opts, str(maxi(0, grounds.find(str(_club["ground"])))), 1,
					func(k): _club["ground"] = grounds[int(k)]))
		else:
			body.add_child(_sub("Ground: %s" % grounds[0]))

	body.add_child(_heading("Name"))
	body.add_child(_field("ForgeClubName", "name", "Club name", ClubForge.NAME_MAX))
	body.add_child(_field("ForgeClubNickname", "short", "Nickname, like the Magpies", ClubForge.SHORT_MAX))
	body.add_child(_field("ForgeClubCode", "code", "Abbreviation, like COL", 4))

	body.add_child(_heading("Colours"))
	for slot in [["primary", "First colour"], ["secondary", "Second colour"], ["accent", "Third colour"]]:
		body.add_child(_sub(str(slot[1])))
		body.add_child(_palette("ForgeColour_" + str(slot[0]), str(slot[0])))

	body.add_child(_heading("Guernsey"))
	var designs := []
	for d in ClubForge.DESIGNS:
		designs.append([d, DESIGN_LABELS.get(d, d)])
	body.add_child(UiKit.choice_grid("ForgeDesign", designs, str(_club["design"]), cols, func(k):
		_club["design"] = k
		_kit_touched = true
		_build()))
	var kit := Array(str(_club["kit"]).split("/"))
	var slots := [["p", _colour_name(str(_club["primary"]), "First colour")],
			["s", _colour_name(str(_club["secondary"]), "Second colour")],
			["a", _colour_name(str(_club["accent"]), "Third colour")]]
	body.add_child(_sub("Guernsey colour"))
	body.add_child(UiKit.choice_grid("ForgeBase", slots, str(kit[0]), 3, func(k):
		if k == str(kit[1]):
			kit[1] = kit[0]
		kit[0] = k
		_set_kit(kit)
		_build()))
	if str(_club["design"]) != "plain":
		var others := []
		for s in slots:
			if str(s[0]) != str(kit[0]):
				others.append(s)
		body.add_child(_sub("Pattern colour"))
		body.add_child(UiKit.choice_grid("ForgePattern", others, str(kit[1]), 2, func(k):
			kit[1] = k
			_set_kit(kit)))

	body.add_child(UiKit.spacer(10))
	_problem = UiKit.lbl("", UiKit.SMALL, UiKit.BAD)
	_problem.name = "ForgeProblem"
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem.visible = false
	body.add_child(_problem)
	var save := UiKit.btn("Save club", 17, true)
	save.name = "ForgeSaveClub"
	save.custom_minimum_size.y = 48
	save.pressed.connect(_on_save_club)
	body.add_child(save)


## A place fills in what the coach hasn't made his own: the name (while it is
## still the last place's), the abbreviation (while it is still the one we
## suggested), the ground, and - until a colour or design is picked - the
## place's traditional colours and pattern from the library.
func _pick_place(id: String) -> void:
	var before := ClubForge.location(str(_club["location"]))
	var loc := ClubForge.location(id)
	var name := str(_club["name"]).strip_edges()
	if name == "" or name == str(before.get("place", "")):
		_club["name"] = str(loc.get("place", ""))
	var code := str(_club["code"]).strip_edges()
	if code == "" or code == _auto_code:
		_auto_code = _suggest_code(str(loc.get("place", "")))
		_club["code"] = _auto_code
	_club["location"] = id
	_club["ground"] = str(loc.get("ground", ""))
	if not _kit_touched:
		_club.merge(ClubForge.preset(loc), true)
	_build()


## Initials for a place of two or more words (Port Melbourne: PM), else its
## first three letters (Norwood: NOR).
func _suggest_code(place: String) -> String:
	var words := place.replace("-", " ").split(" ", false)
	var out := ""
	if words.size() >= 2:
		for w in words:
			out += w.left(1)
	else:
		out = place.left(3)
	return out.to_upper().left(4)


func _set_kit(kit: Array) -> void:
	for t in ["p", "s", "a"]:
		if not kit.slice(0, 2).has(t):
			kit[2] = t
	_club["kit"] = "/".join(kit.slice(0, 3))
	_kit_touched = true


func _on_save_club() -> void:
	var why := ClubForge.club_problem(_club)
	if why != "":
		_problem.text = why
		_problem.visible = true
		return
	GameState.set_forge_club(_club)
	_form = ""
	_build()


func _field(node_name: String, key: String, placeholder: String, longest: int) -> LineEdit:
	var f := UiKit.search_field(str(_club[key]), placeholder)
	f.name = node_name
	f.clear_button_enabled = false
	f.max_length = longest
	f.text_changed.connect(func(t: String):
		if key == "code":
			var up := t.to_upper()
			if up != t:
				f.text = up
				f.caret_column = up.length()
			t = up
		_club[key] = t)
	return f


## The football palette as swatches; the chosen colour outlined. A pick
## repaints the row in place (no rebuild: the form keeps its scroll).
func _palette(node_name: String, key: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = 5 if UiKit.view_width(self) < 520.0 else 15
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var buttons := {}
	var paint := func():
		for hex in buttons:
			var on := str(_club[key]).to_lower() == str(hex).to_lower()
			var sb := UiKit.style(Color.html(hex), 0, UiKit.RADIUS, UiKit.TEXT if on else Color(UiKit.TEXT, 0.18))
			sb.set_border_width_all(3 if on else 1)
			for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
				(buttons[hex] as Button).add_theme_stylebox_override(st, sb)
	for c in ClubForge.PALETTE:
		var b := Button.new()
		b.name = "%s_%s" % [node_name, c[0]]
		b.tooltip_text = str(c[1])
		b.custom_minimum_size = Vector2(44, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hex := str(c[2])
		b.pressed.connect(func():
			_club[key] = hex
			_kit_touched = true
			paint.call())
		buttons[hex] = b
		grid.add_child(b)
	paint.call()
	return grid


func _colour_name(hex: String, fallback: String) -> String:
	for c in ClubForge.PALETTE:
		if str(c[2]).to_lower() == hex.to_lower():
			return str(c[1])
	return fallback


func _club_colours(spec: Dictionary) -> Array:
	var out := []
	for key in ["primary", "secondary", "accent"]:
		out.append(Color.from_string(str(spec.get(key, "")), Color.WHITE))
	return out
