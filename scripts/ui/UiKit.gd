class_name UiKit
extends RefCounted
## Shared, touch-friendly widgets. Local fonts keep the same hierarchy on a
## phone and desktop without depending on fonts installed on the device.

const FONT := preload("res://assets/fonts/Barlow-Regular.ttf")
const BOLD := preload("res://assets/fonts/Barlow-SemiBold.ttf")
const DISPLAY := preload("res://assets/fonts/BarlowCondensed-Bold.ttf")

const BG := Color("0b100d")
const PANEL := Color("151e18")
const PANEL_ALT := Color("1d2921")
const INK := Color("090f0b")
const LINE := Color("2c382f")
const TEXT := Color("efefe5")
const MUTED := Color("a2ada0")
const GOLD := Color("d8c176")
const GOOD := Color("9bc69d")
const BAD := Color("df947e")
const ACCENT := Color("b4482f")

const ROLE_LABEL := {"RUCK": "Ruck", "MID": "Midfield", "DEF": "Defence", "FWD": "Forward"}
const ROLE_SHORT := {"RUCK": "RUC", "MID": "MID", "DEF": "DEF", "FWD": "FWD"}
const ROLE_COLOUR := {
	"DEF": Color("8db9c0"), "MID": Color("9bc69d"),
	"RUCK": Color("d8c176"), "FWD": Color("dfaa94"),
}


## Control.size can still be zero inside _ready(). The viewport already has
## the device-independent size supplied by ScreenLayout.
static func view_width(node: Node) -> float:
	var vp := node.get_viewport()
	return vp.get_visible_rect().size.x if vp != null else 1280.0


static func view_height(node: Node) -> float:
	var vp := node.get_viewport()
	return vp.get_visible_rect().size.y if vp != null else 720.0


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.follow_focus = true
	s.scroll_deadzone = 12
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func style(bg: Color, pad := 12, radius := 8, border := LINE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.border_color = border
	sb.set_border_width_all(1)
	return sb


static func panel(colour := PANEL, pad := 14, radius := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", style(colour, pad, radius))
	return p


static func spacer(px := 6) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


## Remove immediately from layout; freeing at frame end avoids deleting the
## button currently emitting pressed. No duplicate rows during a refresh.
static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func lbl(text: String, fs := 16, color := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", BOLD if bold else FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Unwrapped metadata in horizontal rows must keep its intrinsic width.
## A wrapped label's minimum width is only one pixel, which can otherwise
## turn a cap value or club name into a column of single letters.
static func line(text: String, fs := 16, color := TEXT, bold := false) -> Label:
	var l := lbl(text, fs, color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


static func ellipsis(text: String, fs := 16, color := TEXT, bold := false) -> Label:
	var l := lbl(text, fs, color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.tooltip_text = text
	return l


static func heading(text: String, fs := 26) -> Label:
	var l := lbl(text, fs)
	l.add_theme_font_override("font", DISPLAY)
	return l


static func title(text: String) -> Label:
	var l := heading(text, 36)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func subtitle(text: String) -> Label:
	var l := lbl(text, 15, MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func style_button(b: Button, fs := 16, primary := false) -> void:
	b.custom_minimum_size.y = 44
	# Let a parent ScrollContainer see touch drags and cancel the button's
	# pending press via NOTIFICATION_SCROLL_BEGIN instead of making a pick.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color("798477"))
	var sb := style(ACCENT if primary else PANEL_ALT, 8, 6,
			ACCENT.lightened(0.1) if primary else LINE)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = sb.bg_color.lightened(0.08)
	hover.border_color = MUTED
	b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = sb.bg_color.darkened(0.12) if primary else Color("303e31")
	pressed.border_color = GOLD
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", style(PANEL, 8, 6))
	var focus := style(Color.TRANSPARENT, 0, 6, GOLD)
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus)


static func btn(text: String, fs := 16, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, fs, primary)
	return b


static func tab(text: String, active: bool) -> Button:
	var b := btn(text, 14)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := style(PANEL_ALT if active else INK, 6, 4,
			GOLD if active else Color.TRANSPARENT)
	sb.set_border_width_all(0)
	sb.border_width_bottom = 2 if active else 0
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", TEXT if active else MUTED)
	return b


static func option() -> OptionButton:
	var b := OptionButton.new()
	style_button(b, 14)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.fit_to_longest_item = false
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.get_popup().add_theme_font_override("font", FONT)
	b.get_popup().add_theme_font_size_override("font_size", 16)
	b.get_popup().add_theme_constant_override("v_separation", 16)
	return b


static func search_field(text: String, placeholder := "Search players...") -> LineEdit:
	var field := LineEdit.new()
	field.text = text
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(0, 44)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_override("font", FONT)
	field.add_theme_font_size_override("font_size", 16)
	field.add_theme_color_override("font_color", TEXT)
	field.add_theme_color_override("font_placeholder_color", MUTED)
	field.add_theme_color_override("caret_color", GOLD)
	field.add_theme_stylebox_override("normal", style(INK, 10, 6))
	field.add_theme_stylebox_override("focus", style(INK, 10, 6, GOLD))
	field.clear_button_enabled = true
	field.caret_blink = true
	return field


static func chip(text: String, colour: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", style(colour, 4, 4, Color.TRANSPARENT))
	var l := line(text, 12, readable_on(colour), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## A player's traits as small chips (empty when he has none). Tooltips say
## what each one does.
static func trait_chips(p: Dictionary) -> HBoxContainer:
	var h := hbox(4)
	h.name = "Traits"
	for t in Traits.of(p):
		var c := chip(Traits.label(t), BAD.darkened(0.45) if Traits.is_bad(t) else Color("35573c"))
		c.tooltip_text = Traits.text(t)
		h.add_child(c)
	return h


static func role_chip(role: String) -> PanelContainer:
	var primary := role.split("/")[0]
	var colour: Color = ROLE_COLOUR.get(primary, MUTED)
	var p := panel(Color(colour, 0.10), 5, 4)
	var dual := role.contains("/")
	p.custom_minimum_size.x = 78 if dual else 44
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text := role if dual else ("RUCK" if role == "RUCK" else role)
	var l := line(text, 11, colour, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func role_chip_for(p: Dictionary) -> PanelContainer:
	return role_chip(Ratings.role_tag(p))


static func readable_on(bg: Color) -> Color:
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color(0.08, 0.08, 0.1) if lum > 0.55 else Color(1, 1, 1)


static func top_bar(title_text: String, back := true, right: Control = null) -> HBoxContainer:
	var h := hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if back:
		var b := btn("‹", 24)
		b.custom_minimum_size = Vector2(44, 44)
		b.pressed.connect(func(): Router.back())
		h.add_child(b)
	var t := ellipsis(title_text, 22, TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(t)
	if right != null:
		h.add_child(right)
	elif back:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(44, 0)
		h.add_child(pad)
	return h


static func club_badge(code: String, fs := 14, compact := false, shrink := false) -> HBoxContainer:
	var h := hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var cols: Array = GameDB.club_colours(code)
	var swatch := PanelContainer.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := style(cols[0], 0, 3, cols[2])
	sb.set_border_width_all(2)
	swatch.add_theme_stylebox_override("panel", sb)
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(swatch)
	var name_text := code if compact else GameDB.club_short(code)
	if shrink:
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name := ellipsis(name_text, fs, TEXT)
		h.add_child(name)
	else:
		h.add_child(line(name_text, fs, TEXT))
	return h


static func scoreline(goals: int, behinds: int) -> String:
	return "%d.%d (%d)" % [goals, behinds, goals * 6 + behinds]


static func margin_colour(win: bool) -> Color:
	return GOOD if win else BAD


## A dimmer that actually covers its parent. Anchors set before add_child are
## ignored, which is how match controls stayed visible beside the full-time card.
static func cover(parent: Control) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	return overlay


## Dialog that stays inside the viewport. Body scrolls; footer stays put.
static func modal_box(parent: Control, max_w: float, prefer_h := 0.0) -> Dictionary:
	var overlay := cover(parent)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var shell := panel(PANEL, 14, 12)
	center.add_child(shell)
	var outer := vbox(8)
	shell.add_child(outer)
	var body := vbox(8)
	outer.add_child(scroll(body))
	var footer := vbox(6)
	outer.add_child(footer)
	var fit := func() -> void:
		var bounds := overlay.size
		if bounds.x < 40.0 or bounds.y < 40.0:
			bounds = Vector2(view_width(parent), view_height(parent))
		var w := minf(max_w, maxf(220.0, bounds.x - 24.0))
		var h := maxf(160.0, bounds.y - 24.0)
		if prefer_h > 0.0:
			h = minf(h, prefer_h)
		shell.custom_minimum_size = Vector2(w, h)
	fit.call()
	overlay.resized.connect(fit)
	return {"overlay": overlay, "body": body, "footer": footer, "shell": shell}


static func apply_insets(margin: MarginContainer, pad := 12) -> void:
	var safe := ScreenLayout.safe_insets()
	margin.add_theme_constant_override("margin_left", pad + ceili(safe.x))
	margin.add_theme_constant_override("margin_right", pad + ceili(safe.z))
	margin.add_theme_constant_override("margin_top", pad + ceili(safe.y))
	margin.add_theme_constant_override("margin_bottom", pad + ceili(safe.w))


## Shared ladder. Header and rows use one spec, and only the club column grows,
## so the numbers stay under their headings on a phone.
static func ladder_table(rows: Array, mine: String, width: float, limit := 0,
		full := false) -> VBoxContainer:
	var v := vbox(2)
	var specs := ladder_specs(width, full)
	v.add_child(_ladder_header(specs))
	var shown := rows.size() if limit <= 0 else mini(limit, rows.size())
	for i in range(shown):
		v.add_child(_ladder_data_row(rows[i], i + 1, specs, mine))
		if i == 7 and (shown > 8 or limit == 8):
			var note := line("top 8 make the finals", 11, MUTED)
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(note)
	return v


static func ladder_specs(width: float, full: bool) -> Array:
	var specs: Array = [
		{"key": "pos", "title": "#", "w": 26},
		{"key": "club", "title": "Club", "expand": true},
	]
	if width >= 640.0:
		specs.append({"key": "p", "title": "P", "w": 28})
		specs.append({"key": "w", "title": "W", "w": 28})
		specs.append({"key": "l", "title": "L", "w": 28})
		specs.append({"key": "d", "title": "D", "w": 26})
	elif width >= 280.0:
		specs.append({"key": "rec", "title": "W-L", "w": 48})
	if full and width >= 760.0:
		specs.append({"key": "pf", "title": "PF", "w": 40})
		specs.append({"key": "pa", "title": "PA", "w": 40})
	if width >= 460.0:
		specs.append({"key": "pct", "title": "%", "w": 44})
	specs.append({"key": "pts", "title": "Pts", "w": 34})
	return specs


static func _ladder_header(specs: Array) -> HBoxContainer:
	var h := hbox(4)
	for spec in specs:
		var expand: bool = bool(spec.get("expand", false))
		h.add_child(_ladder_label(str(spec["title"]), int(spec.get("w", 0)),
				MUTED, 12, false, expand))
	return h


static func _ladder_data_row(r: Dictionary, pos: int, specs: Array, mine: String) -> HBoxContainer:
	var h := hbox(4)
	var is_mine: bool = str(r["code"]) == mine
	var col := GOLD if is_mine else TEXT
	for spec in specs:
		var key := str(spec["key"])
		var expand: bool = bool(spec.get("expand", false))
		var w := int(spec.get("w", 0))
		if key == "club":
			h.add_child(club_badge(str(r["code"]), 13, false, true))
		elif key == "pos":
			h.add_child(_ladder_label(str(pos), w, col, 13, is_mine, false))
		elif key == "rec":
			h.add_child(_ladder_label("%d-%d" % [int(r["w"]), int(r["l"])], w, col, 12, false, false))
		elif key == "pct":
			h.add_child(_ladder_label("%.0f" % float(r["pct"]), w, col, 12, false, false))
		elif key == "pts":
			h.add_child(_ladder_label(str(int(r["pts"])), w, col, 13, true, false))
		else:
			h.add_child(_ladder_label(str(int(r.get(key, 0))), w, col, 12, false, false))
	return h


static func _ladder_label(text: String, w: int, col: Color, fs: int, bold: bool,
		expand: bool) -> Label:
	var l := ellipsis(text, fs, col, bold) if expand else line(text, fs, col, bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if expand else HORIZONTAL_ALIGNMENT_CENTER
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		l.custom_minimum_size = Vector2(w, 0)
	return l
