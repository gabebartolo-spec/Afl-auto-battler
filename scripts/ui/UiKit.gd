class_name UiKit
extends RefCounted
## Shared, touch-friendly widgets: the game's visual language in one place.
## The rules behind it are in CLAUDE.md. In short:
##  - Colour belongs to clubs, state (good / bad), selection and the primary
##    action. Ordinary text is TEXT or MUTED; emphasis is weight and size.
##  - Surfaces are flat. A panel groups things and has no border; a secondary
##    button is an outline, so it never reads as another card.
##  - Sentence case. The game's own sign-writer face (ARD Signwriter, drawn
##    for the game after old ground scoreboards): Regular and Bold for reading,
##    the Display cut, with its painted drop shade, for scores and headings.

const FONT := preload("res://assets/fonts/ARDSignwriter-Regular.ttf")
const BOLD := preload("res://assets/fonts/ARDSignwriter-Bold.ttf")
const DISPLAY := preload("res://assets/fonts/ARDSignwriter-Display.ttf")
## The sign-writer's drop shade under display type: down and right, as a share
## of the font size (the drawn shade layer sits at +30, -30 per 1000).
const SHADE := 0.03

## Shared palette. Dark is the default so boot/import remains identical until
## GameState reads the user's appearance preference. These are runtime values
## rather than constants so every screen can rebuild cleanly in light mode.
const AUTO_COLOUR := Color(-1, -1, -1, -1)
static var BG := Color("121110")
static var PANEL := Color("1b1a17")       # a grouped surface
static var PANEL_ALT := Color("24221e")   # a surface on a surface - sparingly
static var INK := Color("0d0c0b")         # inputs and wells
static var LINE := Color("363229")        # rules and outlines
static var TEXT := Color("f1eee6")
static var MUTED := Color("a39e93")
static var FAINT := Color("6e695f")       # disabled
static var EMPH := Color("f1eee6")        # emphasis is weight, not a colour
static var GOOD := Color("8cc49a")        # a genuinely good state, never decoration
static var BAD := Color("e38b73")
static var ACCENT := Color("c8412b")      # the primary action, and nothing else
static var _appearance := "dark"


static func apply_appearance(mode: String) -> void:
	_appearance = "light" if mode == "light" else "dark"
	if _appearance == "light":
		BG = Color("f3f0e8")
		PANEL = Color("e9e4da")
		PANEL_ALT = Color("ddd7cb")
		INK = Color("ffffff")
		LINE = Color("c4bbad")
		TEXT = Color("1d1a16")
		MUTED = Color("6f685f")
		FAINT = Color("9a9287")
		EMPH = TEXT
		GOOD = Color("3f7650")
		BAD = Color("a74734")
		ACCENT = Color("b63c29")
	else:
		BG = Color("121110")
		PANEL = Color("1b1a17")
		PANEL_ALT = Color("24221e")
		INK = Color("0d0c0b")
		LINE = Color("363229")
		TEXT = Color("f1eee6")
		MUTED = Color("a39e93")
		FAINT = Color("6e695f")
		EMPH = TEXT
		GOOD = Color("8cc49a")
		BAD = Color("e38b73")
		ACCENT = Color("c8412b")
	RenderingServer.set_default_clear_color(BG)


static func appearance() -> String:
	return _appearance


## The WCAG contrast ratio of two colours (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _relative_luminance(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


## A club's colour for a live score on `surface` (the panel by default): the
## club's accent, else its second colour, else its first, whichever is the
## first to read at 4.5:1; plain text when none of them does. A club's own
## colour stays wherever it can be read (Sydney's black accent cannot be, on a
## dark panel).
## A club's most vivid colour that still reads on `surface` (3:1): the one to
## carry its atmosphere (Melbourne's red, not its white trim). Falls back to
## score_colour when no vivid colour reads.
static func club_vivid(code: String, surface := AUTO_COLOUR) -> Color:
	if surface == AUTO_COLOUR:
		surface = BG
	var best := Color(0, 0, 0, 0)
	var best_s := 0.18
	for c in GameDB.club_colours(code):
		var col: Color = c
		if col.s > best_s and contrast(col, surface) >= 3.0:
			best_s = col.s
			best = col
	return best if best.a > 0.0 else score_colour(code, surface)


static func score_colour(code: String, surface := AUTO_COLOUR) -> Color:
	if surface == AUTO_COLOUR:
		surface = PANEL
	var cols: Array = GameDB.club_colours(code)
	for i in [2, 1, 0]:
		if contrast(cols[i], surface) >= 4.5:
			return cols[i]
	return TEXT

## Type scale for a phone. Pick from these before inventing a size.
const H1 := 24      # screen title / the one big fact on a screen
const H2 := 18      # section heading
const BODY := 15
const SMALL := 13   # secondary lines
const TINY := 11    # stamps and fine print only

## Type roles (STYLE-02 prep): what a piece of text is, at today's sizes
## exactly. Screens use these rather than a number, so the director's typeface
## and its sizes are set here, once. The face is lbl's: BOLD when it's asked
## for, else FONT; the figures (RATING, SCORE, NUMBER) are DISPLAY. Sizes still
## written as numbers on screens are off this scale (14, 17, 12, 20...) - for
## the typeface pass to place, not guessed at here.
const TITLE := H1           # a screen's title, the one big fact
const HEADING := H2         # a section heading
const NAME := 16            # a player or club name leading a row; button text
const SECONDARY := SMALL    # the line under it
const FINE := TINY          # stamps and fine print
const RATING := 30          # a rating as a figure (DISPLAY)
const SCORE := 24           # a match score as a figure (DISPLAY)
const NUMBER := 22          # a score in a list row (DISPLAY)

## Spacing and corners.
const GAP := 8          # between rows
const SECTION := 18     # between sections
const RADIUS := 6       # panels and buttons; nothing rounder

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


## A scrolling list. Swiping the list does the real work; the scrollbar is the
## fast way down a long one, so its touch area is a finger wide (the engine's
## own rail is 8 units).
const SCROLL_RAIL := 20       # the touch area, in units
const SCROLL_THUMB := 6       # the line you see inside it
const SCROLL_THUMB_MIN := 48  # never shorter than a fingertip

static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.follow_focus = true
	s.scroll_deadzone = 12
	style_scrollbar(s.get_v_scroll_bar())
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


## A slim thumb in a wide touch area, flat like everything else: no track, the
## thumb picks up when it is touched, and it is never too short to grab.
static func style_scrollbar(bar: ScrollBar) -> void:
	# The container sets aside the bar's style width, not its custom size, so
	# the rail is reserved through the (invisible) track.
	var track := StyleBoxEmpty.new()
	track.content_margin_left = SCROLL_RAIL
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", _thumb(Color(MUTED, 0.55)))
	bar.add_theme_stylebox_override("grabber_highlight", _thumb(Color(MUTED, 0.85)))
	bar.add_theme_stylebox_override("grabber_pressed", _thumb(TEXT))


static func _thumb(colour: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = colour
	sb.set_corner_radius_all(SCROLL_THUMB / 2)
	# The thumb hugs the right edge; the rest of the rail is touch area.
	sb.expand_margin_left = -(SCROLL_RAIL - SCROLL_THUMB)
	sb.content_margin_top = SCROLL_THUMB_MIN / 2.0
	sb.content_margin_bottom = SCROLL_THUMB_MIN / 2.0
	return sb


static func style(bg: Color, pad := 12, radius := RADIUS, border := AUTO_COLOUR) -> StyleBoxFlat:
	if border == AUTO_COLOUR:
		border = LINE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(mini(radius, RADIUS))
	sb.set_content_margin_all(pad)
	sb.border_color = border
	sb.set_border_width_all(1)
	return sb


## A flat surface that groups related things: no border, small corners.
static func panel(colour := AUTO_COLOUR, pad := 14, radius := RADIUS) -> PanelContainer:
	if colour == AUTO_COLOUR:
		colour = PANEL
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := style(colour, pad, radius)
	sb.set_border_width_all(0)
	p.add_theme_stylebox_override("panel", sb)
	return p


## A thin rule between sections, where spacing alone is not enough.
static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A section heading: sentence case, weight not colour.
static func section(text: String) -> Label:
	return lbl(text, H2, TEXT, true)


static func spacer(px := 6) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


## Remove immediately from layout; freeing at frame end avoids deleting the
## button currently emitting pressed. No duplicate rows during a refresh.
static func clear(container: Node) -> void:
	# A tap that rebuilds the list it sits in (drafting a player, say) must still
	# reach the ScrollContainer around the list. Taking the tapped row out of the
	# tree mid-tap ends the event there: the scroll never hears the release,
	# stays mid-drag, and every later mouse move drags the list back to where
	# the tap began. So the row under the pointer leaves at the end of the
	# frame instead, hidden and renamed so its replacement can take its name.
	var under: Control = null
	if container.is_inside_tree():
		under = container.get_viewport().gui_get_hovered_control()
	for child in container.get_children():
		if under != null and child is CanvasItem and (child == under or child.is_ancestor_of(under)):
			child.name = "Leaving_%d" % child.get_instance_id()
			(child as CanvasItem).hide()
			child.queue_free()
			continue
		container.remove_child(child)
		child.queue_free()


static func lbl(text: String, fs := 16, color := AUTO_COLOUR, bold := false) -> Label:
	if color == AUTO_COLOUR:
		color = TEXT
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
static func line(text: String, fs := 16, color := AUTO_COLOUR, bold := false) -> Label:
	if color == AUTO_COLOUR:
		color = TEXT
	var l := lbl(text, fs, color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


static func ellipsis(text: String, fs := 16, color := AUTO_COLOUR, bold := false) -> Label:
	if color == AUTO_COLOUR:
		color = TEXT
	var l := lbl(text, fs, color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.tooltip_text = text
	return l


static func heading(text: String, fs := H1) -> Label:
	var l := lbl(text, mini(fs, 30), TEXT, true)
	l.add_theme_font_override("font", DISPLAY)
	shade(l, mini(fs, 30))
	return l


static func title(text: String) -> Label:
	var l := heading(text, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Big numbers - a score, a rating - in the scoreboard face.
static func figure(text: String, fs := 30, color := AUTO_COLOUR) -> Label:
	if color == AUTO_COLOUR:
		color = TEXT
	var l := line(text, fs, color)
	l.add_theme_font_override("font", DISPLAY)
	shade(l, fs)
	return l


## The painted drop shade under display type.
static func shade(l: Label, fs: int) -> void:
	var off := maxi(1, roundi(fs * SHADE))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8) if _appearance == "dark" else Color(0, 0, 0, 0.22))
	l.add_theme_constant_override("shadow_offset_x", off)
	l.add_theme_constant_override("shadow_offset_y", off)


static func subtitle(text: String) -> Label:
	var l := lbl(text, 15, MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Button hierarchy: primary is filled red (one per screen, ideally);
## secondary is an outline; danger is an outline in BAD; disabled fades to
## FAINT. Every button is at least 44 px tall for a thumb.
static func style_button(b: Button, fs := 16, primary := false, danger := false) -> void:
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 44)
	# Let a parent ScrollContainer see touch drags and cancel the button's
	# pending press via NOTIFICATION_SCROLL_BEGIN instead of making a pick.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", fs)
	var ink := BAD if danger else TEXT
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_focus_color", ink)
	b.add_theme_color_override("font_disabled_color", FAINT)
	# Not boring (director, 2026-10-08): a primary action in your club's
	# colour, a secondary one a raised tile, not a grey outline.
	var sb: StyleBoxFlat
	var lead := team_colour()
	if primary:
		sb = raised(lead)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, ink_on(lead))
	else:
		sb = raised(team_tile())
		if danger:
			sb.border_color = BAD.darkened(0.25)
			sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = lead.lightened(0.10) if primary else team_tile().lightened(0.06)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = lead.darkened(0.15) if primary else team_tile().lightened(0.10)
	# A toggled secondary button (a difficulty, a filter) reads as selected.
	if not primary:
		pressed.border_color = TEXT
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	var off := style(Color(TILE, 0.5), 8, RADIUS)
	b.add_theme_stylebox_override("disabled", off)
	var focus := style(Color.TRANSPARENT, 0, RADIUS, TEXT)
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus)


## A raised tile: a solid face, a light top edge and a soft shadow under it.
const TILE := Color("2b2924")


static func raised(bg: Color) -> StyleBoxFlat:
	var sb := style(bg, 8, RADIUS)
	sb.border_width_top = 1
	sb.border_color = bg.lightened(0.18)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Your club's colour for what you act on: its most vivid colour that shows,
## or the accent when it has none (a black-and-white club) or no club yet.
static func team_colour() -> Color:
	var club := ""
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null:
		club = str(gs.my_club)
	if club == "" or not GameDB.clubs.has(club):
		return ACCENT
	# The most vivid of its colours that is neither near black nor near white
	# (Melbourne's red, not its navy), lifted until it shows on the page.
	var best := Color(0, 0, 0, 0)
	for c in GameDB.club_marker_colours(club):
		var col: Color = c
		if col.get_luminance() > 0.7 or col.s < 0.3:
			continue
		if best.a == 0.0 or col.s * col.v > best.s * best.v:
			best = col
	return ClubDuel._show(best) if best.a > 0.0 else ACCENT


## Match day's sheet wash: the opponent's colour, the atmosphere you play
## into, while your club's colour stays on what you act on. When theirs
## looks too like yours (Melbourne v Essendon), their other colour; when that
## is grey too, a plain warm wash.
static func opponent_wash(opp: String) -> Color:
	if not GameDB.clubs.has(opp):
		return team_colour()
	var mine := team_colour()
	var best := Color(0, 0, 0, 0)
	for c in GameDB.club_marker_colours(opp):
		var col := ClubDuel._show(c)
		if col.get_luminance() > 0.7 or col.s < 0.25 or ClubDuel._diff(col, mine) < 0.45:
			continue
		if best.a == 0.0 or col.s * col.v > best.s * best.v:
			best = col
	return best if best.a > 0.0 else TEXT


## A raised tile carrying a breath of your club's colour.
static func team_tile() -> Color:
	return TILE.lerp(team_colour(), 0.10)


## Type that reads on `bg`: white, or near-black on a light colour.
static func ink_on(bg: Color) -> Color:
	return Color("161512") if bg.get_luminance() > 0.6 else Color.WHITE


static func btn(text: String, fs := 16, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, fs, primary)
	return b


## A destructive or risky action: outline and text in BAD.
static func danger_btn(text: String, fs := 16) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, fs, false, true)
	return b


## Mark a secondary button as the current choice of a set (difficulty,
## a filter): a solid light outline and a faint fill, never a new colour.
static func set_selected(b: Button, on: bool) -> void:
	var sb := style(Color(TEXT, 0.08) if on else Color.TRANSPARENT, 8, RADIUS,
			TEXT if on else LINE.lightened(0.12))
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_color_override("font_color", TEXT if on else MUTED)


## Tabs are text with an underline under the current one - no boxes.
static func tab(text: String, active: bool) -> Button:
	var b := btn(text, 15)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := style(Color.TRANSPARENT, 6, 0, TEXT if active else LINE)
	sb.set_border_width_all(0)
	sb.border_width_bottom = 2 if active else 1
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", TEXT if active else MUTED)
	b.add_theme_color_override("font_hover_color", TEXT)
	return b


## One tap picks one: [key, label] options in a grid, the chosen one
## outlined. Buttons are named "<node_name>_<key>". on_pick(key) runs after
## the grid repaints. Short lists only; a long list wants its own sheet.
static func choice_grid(node_name: String, options: Array, current: String, columns: int,
		on_pick: Callable = Callable()) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var state := {"current": current}
	var buttons := {}
	var paint := func() -> void:
		for k in buttons:
			paint_choice(buttons[k], str(k) == str(state["current"]))
	for o in options:
		var key := str(o[0])
		var b := btn(str(o[1]), 14)
		b.name = "%s_%s" % [node_name, key]
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(func():
			state["current"] = key
			paint.call()
			if on_pick.is_valid():
				on_pick.call(key))
		buttons[key] = b
		grid.add_child(b)
	paint.call()
	return grid


## A choice's look: the chosen one outlined in full text, the rest quiet.
static func paint_choice(b: Button, on: bool) -> void:
	# The chosen one filled in your club's colour; the rest raised tiles.
	var lead := team_colour()
	var sb := raised(lead if on else team_tile())
	if on:
		sb.set_border_width_all(2)
		sb.border_color = lead.lightened(0.35)
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_color_override("font_color", ink_on(lead) if on else Color(TEXT, 0.82))
	b.add_theme_color_override("font_hover_color", ink_on(lead) if on else TEXT)


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
	field.add_theme_color_override("caret_color", TEXT)
	field.add_theme_stylebox_override("normal", style(INK, 10, RADIUS))
	field.add_theme_stylebox_override("focus", style(INK, 10, RADIUS, MUTED))
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


## A player's traits as one quiet line ("Ball magnet · Big-game player"),
## Hothead in BAD. Empty when he has none. Tooltips say what each one does.
static func trait_chips(p: Dictionary) -> HBoxContainer:
	var h := hbox(10)
	h.name = "Traits"
	for t in Traits.of(p):
		var l := line(Traits.label(t), SMALL, BAD if Traits.is_bad(t) else MUTED)
		l.tooltip_text = Traits.text(t)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(l)
	return h


## A position tag: coloured text in a fixed-width column so names line up.
## The colour is the one piece of position information, so no box around it.
static func role_chip(role: String) -> PanelContainer:
	var primary := role.split("/")[0]
	var colour: Color = ROLE_COLOUR.get(primary, MUTED)
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var dual := role.contains("/")
	p.custom_minimum_size.x = 72 if dual else 40
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := line(role, 12, colour, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	p.add_child(l)
	return p


static func role_chip_for(p: Dictionary) -> PanelContainer:
	return role_chip(Ratings.role_tag(p))


static func readable_on(bg: Color) -> Color:
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color(0.08, 0.08, 0.1) if lum > 0.55 else Color(1, 1, 1)


## `back_cb` (optional) gets first say on the back button: if it returns
## true it has handled the step back itself (e.g. closed an in-scene view),
## otherwise the router steps back as usual.
static func top_bar(title_text: String, back := true, right: Control = null,
		back_cb: Callable = Callable()) -> HBoxContainer:
	var h := hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if back:
		var b := btn("‹", 26)
		b.name = "TopBarBack"
		b.flat = true
		b.custom_minimum_size = Vector2(44, 44)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.pressed.connect(func():
			if back_cb.is_valid() and back_cb.call():
				return
			Router.back())
		h.add_child(b)
	var t := ellipsis(title_text, 20, TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(t)
	if right != null:
		h.add_child(right)
	elif back:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(44, 0)
		h.add_child(pad)
	return h


## A club's marker: its own guernsey, front on (club marker A, director
## approved; GuernseyCrest). From 32 px the club's code is on the chest; under
## that the club's name beside it carries the code.
static func club_marker(code: String, size := 22.0) -> Control:
	var g := GameDB.club_guernsey(code)
	var cols := GameDB.club_colours(code)
	# The kit's own third colour when it names one (St Kilda's black panel,
	# Port's teal); otherwise a two-colour club's third colour is only a
	# pitch tint, so its trim is the second colour.
	var trim: Color = cols[1]
	if g.get("own_pattern2", false) or GameDB.club_marker_colours(code).size() > 2:
		trim = g["pattern2"]
	# The old flag's footprint (size less its 2 px of frame), so lists of clubs
	# - the ladder above all - keep their row heights.
	return GuernseyCrest.make(g["base"], g["pattern"], trim, str(g["design"]), code, size - 2.0)


## The same guernsey from colours alone (Club Forge shows a club before it
## exists): [primary, secondary, accent], its design and its code.
static func colour_marker(cols: Array, size := 22.0, design := "plain", code := "") -> Control:
	var p: Color = cols[0] if cols.size() > 0 else Color.WHITE
	var s: Color = cols[1] if cols.size() > 1 else p
	var a: Color = cols[2] if cols.size() > 2 else s
	return GuernseyCrest.make(p, s, a, design, code, size)


static func club_badge(code: String, fs := 14, compact := false, shrink := false) -> HBoxContainer:
	var h := hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(club_marker(code))
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
## `wash` tints the top of the sheet; by default your club's colour (match
## day passes the opponent's, from `opponent_wash`).
static func modal_box(parent: Control, max_w: float, prefer_h := 0.0, wash := AUTO_COLOUR) -> Dictionary:
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
	var shell := panel(PANEL, 16)
	center.add_child(shell)
	# Not boring (director, 2026-10-08): a wash of your club's colour from the
	# top of every sheet, fading before the content needs the contrast.
	var lead := team_colour() if wash == AUTO_COLOUR else wash
	shell.draw.connect(func() -> void:
		var w := shell.size.x
		var h := minf(shell.size.y * 0.5, 220.0)
		var top := Color(lead, 0.30)
		var none := Color(lead, 0.0)
		shell.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([top, top, none, none])))
	var outer := vbox(8)
	shell.add_child(outer)
	var body := vbox(8)
	var sc := scroll(body)
	outer.add_child(sc)
	var footer := vbox(6)
	outer.add_child(footer)
	# The sheet is as tall as what it holds (the director's PC playtest,
	# 2026-10-07: a three-paragraph help sheet filled the screen, its buttons
	# at the bottom of empty space). It scrolls only when that is more than
	# the screen, or than prefer_h when the caller caps it.
	var fit := func() -> void:
		if not is_instance_valid(shell):
			return
		var bounds := overlay.size
		if bounds.x < 40.0 or bounds.y < 40.0:
			bounds = Vector2(view_width(parent), view_height(parent))
		var w := minf(max_w, maxf(220.0, bounds.x - 24.0))
		var most := maxf(160.0, bounds.y - 24.0)
		if prefer_h > 0.0:
			most = minf(most, prefer_h)
		var chrome := shell.get_combined_minimum_size().y - sc.get_combined_minimum_size().y
		var room := maxf(80.0, most - chrome)
		sc.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, room)
		shell.custom_minimum_size = Vector2(w, 0.0)
	var refit := func() -> void:
		fit.call_deferred()
	fit.call()
	overlay.resized.connect(fit)
	body.minimum_size_changed.connect(refit)
	footer.minimum_size_changed.connect(refit)
	body.resized.connect(refit)
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
	var cut := Season.FINALISTS - 1
	for i in range(shown):
		v.add_child(_ladder_data_row(rows[i], i + 1, specs, mine))
		if i == cut and (shown > Season.FINALISTS or limit == Season.FINALISTS):
			v.add_child(rule())
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
	var col := TEXT if is_mine else MUTED
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
