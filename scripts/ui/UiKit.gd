class_name UiKit
extends RefCounted
## Shared UI construction helpers. Every scene builds its tree in code from
## these, which keeps the .tscn files down to a single scripted root and makes
## the layout consistent across desktop and touch.

const BG := Color(0.043, 0.09, 0.047)
const PANEL := Color(0.098, 0.137, 0.106, 0.96)
const PANEL_ALT := Color(0.133, 0.180, 0.141, 0.92)
const LINE := Color(1, 1, 1, 0.10)
const TEXT := Color(0.93, 0.95, 0.93)
const MUTED := Color(0.63, 0.69, 0.64)
const GOLD := Color(0.98, 0.82, 0.32)
const GOOD := Color(0.45, 0.85, 0.48)
const BAD := Color(0.92, 0.42, 0.40)

const ROLE_LABEL := {"RUCK": "Ruck", "MID": "Midfield", "DEF": "Defence", "FWD": "Forward"}
const ROLE_SHORT := {"RUCK": "RUC", "MID": "MID", "DEF": "DEF", "FWD": "FWD"}


## Viewport width. `Control.size` is still 0 inside _ready(), so any layout
## decision made at build time has to read the window instead.
static func view_width(node: Node) -> float:
	var vp := node.get_viewport()
	return vp.get_visible_rect().size.x if vp != null else 1280.0


static func view_height(node: Node) -> float:
	var vp := node.get_viewport()
	return vp.get_visible_rect().size.y if vp != null else 720.0


# ---------------------------------------------------------------------------
# Containers
# ---------------------------------------------------------------------------
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
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func panel(style := PANEL, pad := 14, radius := 10) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = style
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.border_color = LINE
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func spacer(px := 6) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


# ---------------------------------------------------------------------------
# Widgets
# ---------------------------------------------------------------------------
static func lbl(text: String, fs := 16, color := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		l.add_theme_constant_override("outline_size", 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func title(text: String) -> Label:
	var l := lbl(text, 34, TEXT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func subtitle(text: String) -> Label:
	var l := lbl(text, 15, MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func btn(text: String, fs := 17, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", fs)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.30, 0.19) if primary else PANEL_ALT
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	sb.border_color = GOLD if primary else LINE
	sb.set_border_width_all(2 if primary else 1)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = sb.bg_color.lightened(0.14)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = sb.bg_color.darkened(0.18)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func chip(text: String, colour: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = colour
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", sb)
	var l := lbl(text, 12, readable_on(colour), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func readable_on(bg: Color) -> Color:
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color(0.08, 0.08, 0.1) if lum > 0.55 else Color(1, 1, 1)


## Standard top bar: back button, title, optional right-hand widget.
static func top_bar(title_text: String, back := true, right: Control = null) -> HBoxContainer:
	var h := hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if back:
		var b := btn("<", 18)
		b.custom_minimum_size = Vector2(52, 44)
		b.pressed.connect(func(): Router.back())
		h.add_child(b)
	var t := lbl(title_text, 22, TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(t)
	if right != null:
		h.add_child(right)
	elif back:
		# Balance the back button so the title stays centred.
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(52, 0)
		h.add_child(pad)
	return h


static func club_badge(code: String, fs := 14) -> HBoxContainer:
	var h := hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var cols: Array = GameDB.club_colours(code)
	var swatch := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = cols[0]
	sb.border_color = cols[2]
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	swatch.add_theme_stylebox_override("panel", sb)
	swatch.custom_minimum_size = Vector2(14, 14)
	h.add_child(swatch)
	h.add_child(lbl(GameDB.club_short(code), fs, TEXT))
	return h


## Score line, e.g. "12.8 (80)".
static func scoreline(goals: int, behinds: int) -> String:
	return "%d.%d (%d)" % [goals, behinds, goals * 6 + behinds]


static func margin_colour(win: bool) -> Color:
	return GOOD if win else BAD
