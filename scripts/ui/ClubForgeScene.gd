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
	"tagger": "Tagger", "playmaker": "Playmaker", "key_defender": "Key defender", "rebounder": "Small defender",
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
	"long": "Long", "tied_back": "Tied back", "dreadlocks": "Dreadlocks",
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
	if _form == "club":
		_root.add_child(_club_workspace(_scroll))
	elif _form == "player":
		_root.add_child(_player_workspace(_scroll))
	else:
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


## Create a player: the prospect himself above the form (PlayerPreview), front on
## and from behind, with his name and what he plays, changing as you build him.
## Beside the form on a wide screen.
func _player_workspace(form: ScrollContainer) -> Control:
	var wide := UiKit.view_width(self) >= 760.0 and UiKit.view_width(self) > UiKit.view_height(self)
	var preview := PlayerPreview.new()
	preview.name = "ForgePlayerPreview"
	preview.spec = _spec
	# The player you are making is the page's hero on a big screen.
	var big := wide and UiKit.view_width(self) >= 1100.0
	preview.custom_minimum_size = Vector2(420, 530) if big else (Vector2(260, 330) if wide else Vector2(170, 190))
	var name_l := UiKit.lbl("", UiKit.H1 if wide else UiKit.H2, UiKit.TEXT, true)
	name_l.name = "ForgePlayerPreviewName"
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var line := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	line.name = "ForgePlayerPreviewLine"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ppv = {"name": name_l, "line": line}
	_refresh_player_preview()
	var out: BoxContainer
	if wide:
		out = UiKit.hbox(20)
		var side := UiKit.vbox(10)
		side.name = "ForgePlayerPanel"
		side.custom_minimum_size.x = 420 if big else 260
		side.add_child(preview)
		side.add_child(name_l)
		side.add_child(line)
		out.add_child(side)
	else:
		out = UiKit.vbox(8)
		var strip := UiKit.hbox(10)
		strip.name = "ForgePlayerPanel"
		strip.add_child(preview)
		var words := UiKit.vbox(2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.add_child(name_l)
		words.add_child(line)
		strip.add_child(words)
		out.add_child(strip)
	out.add_child(form)
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return out


func _process(_delta: float) -> void:
	if _form == "player":
		_refresh_player_preview()


func _refresh_player_preview() -> void:
	var name_l = _ppv.get("name")
	if name_l == null or not is_instance_valid(name_l):
		return
	var full := ("%s %s" % [str(_spec.get("first", "")).strip_edges(), str(_spec.get("last", "")).strip_edges()]).strip_edges()
	(name_l as Label).text = full if full != "" else "Your player"
	var bits := PackedStringArray([STYLE_LABELS.get(str(_spec.get("style", "")), _role_label(str(_spec.get("role", "MID")))),
			"%d cm" % int(_spec.get("height_cm", 184))])
	if int(_spec.get("number_pref", 0)) > 0:
		bits.append("No. %d" % int(_spec["number_pref"]))
	(_ppv["line"] as Label).text = " · ".join(bits)


func _default_spec() -> Dictionary:
	return {"first": "", "last": "", "nickname": "", "role": "MID", "role2": "", "height_cm": 184,
			"style": "", "strengths": [], "weaknesses": [], "foot": "R", "number_pref": 0, "fav_club": "",
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
	# FL-005: the club he followed as a kid. Flavour only; nothing reads it.
	body.add_child(_sub("Favourite club growing up"))
	var fav := UiKit.option()
	fav.name = "ForgeFavClub"
	fav.custom_minimum_size.y = 44
	var codes := [""]
	fav.add_item("Not recorded")
	var named := []
	for code in TradeRequests.CLUB_STATES:
		if str(code) != "TAS":
			named.append([GameDB.club_name(str(code)), str(code)])
	named.sort()
	for n in named:
		fav.add_item(str(n[0]))
		codes.append(str(n[1]))
	fav.select(maxi(0, codes.find(str(_spec.get("fav_club", "")))))
	fav.item_selected.connect(func(i: int): _spec["fav_club"] = codes[i])
	body.add_child(fav)

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
var _colour_box: VBoxContainer
var _kit_box: VBoxContainer
## The live preview's crest and words.
var _pv := {}
var _ppv := {}
## The director's flow (2026-10-07): name the club, pick the design, then
## pick a colour (the brush) and click the part of the guernsey to paint.
var _brush := ""
const PART_KEY := {"body": "primary", "pattern": "secondary", "trim": "accent"}
const PART_LABEL := {"body": "Main colour", "pattern": "Pattern colour", "trim": "Trim colour"}


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
	head.add_child(UiKit.colour_marker(_club_colours(saved), 30.0, str(saved.get("design", "plain")), str(saved.get("code", ""))))
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
	body.add_child(_heading("Home"))
	var home := GridContainer.new()
	home.name = "ForgeHome"
	home.columns = 1 if UiKit.view_width(self) < 520.0 else 3
	home.add_theme_constant_override("h_separation", 8)
	home.add_theme_constant_override("v_separation", 6)
	body.add_child(home)
	var state := UiKit.option()
	state.name = "ForgeState"
	for s in STATES:
		state.add_item(str(s[1]))
		state.set_item_metadata(state.item_count - 1, str(s[0]))
		if str(s[0]) == _club_state:
			state.select(state.item_count - 1)
	state.item_selected.connect(func(i: int):
		_club_state = str(state.get_item_metadata(i))
		_build())
	home.add_child(state)
	var place := UiKit.option()
	place.name = "ForgePlace"
	place.add_item("Choose a place")
	place.set_item_metadata(0, "")
	for loc in ClubForge.locations():
		if str(loc.get("state", "")) == _club_state:
			place.add_item(str(loc["place"]))
			place.set_item_metadata(place.item_count - 1, str(loc["id"]))
			if str(loc["id"]) == str(_club["location"]):
				place.select(place.item_count - 1)
	place.item_selected.connect(func(i: int):
		var id := str(place.get_item_metadata(i))
		if id != "":
			_pick_place(id))
	home.add_child(place)
	var here := ClubForge.location(str(_club["location"]))
	if not here.is_empty():
		var grounds := ClubForge.grounds(here)
		var ground := UiKit.option()
		ground.name = "ForgeGround"
		for g in grounds:
			ground.add_item(str(g))
			if str(g) == str(_club["ground"]):
				ground.select(ground.item_count - 1)
		ground.disabled = grounds.size() < 2
		ground.item_selected.connect(func(i: int):
			_club["ground"] = grounds[i]
			_refresh_preview())
		home.add_child(ground)

	body.add_child(_heading("Name"))
	body.add_child(_field("ForgeClubName", "name", "Club name", ClubForge.NAME_MAX))
	body.add_child(_field("ForgeClubNickname", "short", "Nickname, like the Magpies", ClubForge.SHORT_MAX))
	body.add_child(_field("ForgeClubCode", "code", "Abbreviation, like COL", 4))

	_one_colour_each()
	body.add_child(_heading("Guernsey"))
	_kit_box = UiKit.vbox(6)
	_kit_box.name = "ForgeKit"
	body.add_child(_kit_box)
	_rebuild_kit()
	body.add_child(_heading("Colours"))
	_colour_box = UiKit.vbox(8)
	_colour_box.name = "ForgeColours"
	body.add_child(_colour_box)
	_rebuild_paint()
	body.add_child(UiKit.spacer(10))


## The club as it will look, kept in view while the form scrolls: beside it
## on a wide screen, above it on a phone. Save sits with it, so it is always
## one tap away.
func _club_workspace(form: ScrollContainer) -> Control:
	var wide := UiKit.view_width(self) >= 760.0 and UiKit.view_width(self) > UiKit.view_height(self)
	var crest := GuernseyCrest.make(Color.WHITE, Color.WHITE, Color.WHITE, "plain", "", 200.0 if wide else 84.0)
	crest.name = "ForgePreview"
	var name_l := UiKit.lbl("", UiKit.H1 if wide else UiKit.H2, UiKit.TEXT, true)
	name_l.name = "ForgePreviewName"
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var line := UiKit.lbl("", UiKit.SMALL, UiKit.MUTED)
	line.name = "ForgePreviewLine"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem = UiKit.lbl("", UiKit.SMALL, UiKit.BAD)
	_problem.name = "ForgeProblem"
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem.visible = false
	var save := UiKit.btn("Save club", 17, true)
	save.name = "ForgeSaveClub"
	save.custom_minimum_size = Vector2(120, 48)
	save.pressed.connect(_on_save_club)
	_pv = {"crest": crest, "name": name_l, "line": line}
	var out: BoxContainer
	if wide:
		out = UiKit.hbox(20)
		var side := UiKit.vbox(10)
		side.name = "ForgePreviewPanel"
		side.custom_minimum_size.x = 260
		var centre := CenterContainer.new()
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centre.add_child(crest)
		side.add_child(centre)
		_paintable(crest)
		side.add_child(_sub("Pick a colour, then click the part of the guernsey to paint."))
		side.add_child(name_l)
		side.add_child(line)
		side.add_child(UiKit.spacer(6))
		side.add_child(_problem)
		side.add_child(save)
		out.add_child(side)
		out.add_child(form)
	else:
		out = UiKit.vbox(8)
		var strip := UiKit.hbox(10)
		strip.name = "ForgePreviewPanel"
		strip.add_child(crest)
		var words := UiKit.vbox(2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(name_l)
		words.add_child(line)
		strip.add_child(words)
		save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		strip.add_child(save)
		out.add_child(strip)
		out.add_child(_problem)
		out.add_child(form)
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_preview()
	return out


func _refresh_preview() -> void:
	var crest = _pv.get("crest")
	if crest == null or not is_instance_valid(crest):
		return
	var cols := _kit_colours()
	crest.primary = cols[0]
	crest.secondary = cols[1]
	crest.accent = cols[2]
	crest.design = str(_club["design"])
	crest.code = str(_club["code"]).strip_edges()
	crest.queue_redraw()
	var canvas = _pv.get("paint")
	if canvas != null and is_instance_valid(canvas):
		canvas.primary = cols[0]
		canvas.secondary = cols[1]
		canvas.accent = cols[2]
		canvas.design = str(_club["design"])
		canvas.code = crest.code
		canvas.queue_redraw()
	var name := str(_club["name"]).strip_edges()
	(_pv["name"] as Label).text = name if name != "" else "Your club"
	var bits := PackedStringArray()
	for key in ["short", "code", "ground"]:
		var v := str(_club.get(key, "")).strip_edges()
		if v != "":
			bits.append(v)
	(_pv["line"] as Label).text = " · ".join(bits) if not bits.is_empty() else "Choose a place to start"
	if is_instance_valid(_problem):
		_problem.visible = false


## The guernsey's colours in the order the crest draws them: the guernsey,
## its pattern, the trim.
func _kit_colours() -> Array:
	var kit := str(_club["kit"]).split("/")
	var by := {"p": _club["primary"], "s": _club["secondary"], "a": _club["accent"]}
	var out := []
	for i in range(3):
		var t := str(kit[i]) if i < kit.size() else "psa"[i]
		out.append(Color.from_string(str(by.get(t, "#FFFFFF")), Color.WHITE))
	return out


## The paint flow keeps the club's colours in guernsey order - main,
## pattern, trim - so painting a part is painting one colour.
func _one_colour_each() -> void:
	var cols := _kit_colours()
	_club["primary"] = "#" + (cols[0] as Color).to_html(false).to_upper()
	_club["secondary"] = "#" + (cols[1] as Color).to_html(false).to_upper()
	_club["accent"] = "#" + (cols[2] as Color).to_html(false).to_upper()
	_club["kit"] = "p/s/a"


## A guernsey you paint: the part under the pointer is outlined; a click or
## tap paints it with the chosen colour.
func _paintable(c: GuernseyCrest) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseMotion:
			var part := c.part_at((ev as InputEventMouseMotion).position)
			if part == "pattern" and str(_club["design"]) == "plain":
				part = ""
			if part != c.highlight:
				c.highlight = part
				c.queue_redraw()
		elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var part := c.part_at((ev as InputEventMouseButton).position)
			if part != "":
				_paint_part(part)
				c.accept_event())
	c.mouse_exited.connect(func():
		c.highlight = ""
		c.queue_redraw())


func _paint_part(part: String) -> void:
	if part == "pattern" and str(_club["design"]) == "plain":
		return
	if _brush == "":
		_problem.text = "Pick a colour first, then click the guernsey."
		_problem.visible = true
		return
	_club[PART_KEY[part]] = _brush
	_kit_touched = true
	_rebuild_kit()
	_rebuild_paint()
	_refresh_preview()


## The palette (the colour you paint with, outlined), a guernsey to paint on
## a phone (on a wide screen the preview beside the form is it), and what
## each part wears, each also a tap target.
func _rebuild_paint() -> void:
	if not is_instance_valid(_colour_box):
		return
	UiKit.clear(_colour_box)
	var wide := UiKit.view_width(self) >= 760.0 and UiKit.view_width(self) > UiKit.view_height(self)
	var grid := GridContainer.new()
	grid.name = "ForgePalette"
	var room := UiKit.view_width(self) - 40.0 - (280.0 if wide else 0.0)
	grid.columns = clampi(int((room + 6.0) / 50.0), 4, 15)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for c in ClubForge.PALETTE:
		var hex := str(c[2])
		var on := _brush.to_lower() == hex.to_lower()
		var b := Button.new()
		b.name = "ForgeColour_" + str(c[0])
		b.tooltip_text = str(c[1])
		b.custom_minimum_size = Vector2(44, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		var sb := UiKit.style(Color.html(hex), 0, UiKit.RADIUS, UiKit.TEXT if on else Color(UiKit.TEXT, 0.18))
		sb.set_border_width_all(3 if on else 1)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func():
			_brush = hex
			if is_instance_valid(_problem):
				_problem.visible = false
			_rebuild_paint())
		grid.add_child(b)
	_colour_box.add_child(grid)
	var brush_name := _colour_name(_brush, "")
	_colour_box.add_child(_sub(("Painting with %s: click the part of the guernsey to colour." % brush_name)
			if brush_name != "" else "Pick a colour, then click the part of the guernsey to colour."))
	if not wide:
		var cols := _kit_colours()
		var canvas := GuernseyCrest.make(cols[0], cols[1], cols[2], str(_club["design"]),
				str(_club["code"]).strip_edges(), 200.0)
		canvas.name = "ForgePaint"
		_paintable(canvas)
		_pv["paint"] = canvas
		var centre := CenterContainer.new()
		centre.add_child(canvas)
		_colour_box.add_child(centre)
	var parts := GridContainer.new()
	parts.name = "ForgeParts"
	parts.columns = 1 if UiKit.view_width(self) < 520.0 else 3
	parts.add_theme_constant_override("h_separation", 6)
	parts.add_theme_constant_override("v_separation", 6)
	for part in ["body", "pattern", "trim"]:
		if part == "pattern" and str(_club["design"]) == "plain":
			continue
		var key: String = PART_KEY[part]
		var b := _swatch_button("ForgePart_" + part, str(PART_LABEL[part]), _colour_name(str(_club[key]), "Colour"),
				Color.from_string(str(_club[key]), Color.WHITE), false)
		b.pressed.connect(_paint_part.bind(part))
		parts.add_child(b)
	_colour_box.add_child(parts)


## The design, shown as the guernsey itself in the club's colours, then which
## colour is the guernsey and which the pattern.
func _rebuild_kit() -> void:
	if not is_instance_valid(_kit_box):
		return
	UiKit.clear(_kit_box)
	var narrow := UiKit.view_width(self) < 520.0
	var designs := GridContainer.new()
	designs.name = "ForgeDesign"
	designs.columns = 4 if narrow else 6
	designs.add_theme_constant_override("h_separation", 6)
	designs.add_theme_constant_override("v_separation", 6)
	var cols := _kit_colours()
	for d in ClubForge.DESIGNS:
		var b := Button.new()
		b.name = "ForgeDesign_" + str(d)
		b.tooltip_text = str(DESIGN_LABELS.get(d, d))
		b.custom_minimum_size = Vector2(0, 78)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		UiKit.paint_choice(b, str(_club["design"]) == str(d))
		var face := UiKit.vbox(2)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.alignment = BoxContainer.ALIGNMENT_CENTER
		var centre := CenterContainer.new()
		centre.add_child(GuernseyCrest.make(cols[0], cols[1], cols[2], str(d), "", 44.0))
		face.add_child(centre)
		var label := UiKit.lbl(str(DESIGN_LABELS.get(d, d)), 12, UiKit.MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.add_child(label)
		_ignore_mouse(face)
		b.add_child(face)
		b.pressed.connect(func():
			_club["design"] = str(d)
			_kit_touched = true
			_rebuild_kit()
			_rebuild_paint()
			_refresh_preview())
		designs.add_child(b)
	_kit_box.add_child(designs)


## A choice that carries its colour: a swatch, then its words.
func _swatch_button(node_name: String, title: String, colour_name: String, colour: Color, on: bool) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 48 if title != "" else 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UiKit.paint_choice(b, on)
	var face := UiKit.hbox(8)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_theme_constant_override("separation", 8)
	var pad := Control.new()
	pad.custom_minimum_size.x = 2
	face.add_child(pad)
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(22, 22)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := UiKit.style(colour, 0, 4, Color(UiKit.TEXT, 0.35))
	sb.set_border_width_all(1)
	chip.add_theme_stylebox_override("panel", sb)
	face.add_child(chip)
	var words := UiKit.vbox(0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if title != "":
		words.add_child(UiKit.lbl(title, 12, UiKit.MUTED))
	words.add_child(UiKit.ellipsis(colour_name, 14, UiKit.TEXT if on else UiKit.MUTED, on))
	face.add_child(words)
	_ignore_mouse(face)
	b.add_child(face)
	return b


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


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
		_club[key] = t
		_refresh_preview())
	return f


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
