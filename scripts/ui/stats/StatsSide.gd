class_name StatsSide
extends RefCounted
## Whose side a name, a row or a heading is on, for the season stats pages
## (director, 2026-10-13, the design bible's second pillar: allegiance is
## obvious at a glance, sections are set apart). Only UiKit's own helpers are
## used here: the club colour says WHO, never what happened (GOOD and BAD are
## the game's, for state), and a colour that fails contrast is not used as ink
## (the dark clubs fall back to plain TEXT, and carry their side by the
## guernsey marker beside the name or by the row's thin rule).
## The model is StatsLadder's "mine" row: a wash of the club's vivid colour and
## a 4 px rule on the left.

## The room a row leaves on its left for the rule, so no text sits on it.
const RULE_INSET := 8


## A club's colour as ink where it reads at 4.5:1; plain TEXT when it does not
## or when there is no club.
static func ink(code: String) -> Color:
	if code == "" or not GameDB.clubs.has(code):
		return UiKit.TEXT
	return UiKit.score_colour(code)


## Your club's colour as ink (a section heading), else TEXT.
static func mine_ink() -> Color:
	return ink(GameState.my_club)


## A section heading in your club's colour where it reads: the page's sections
## are told apart by it as well as by their weight.
static func heading(text: String) -> Label:
	var l := UiKit.section(text)
	l.add_theme_color_override("font_color", mine_ink())
	return l


## A row's face: your club's row in a wash of its colour with a 4 px rule, as
## the ladder marks it; any other row a 3 px rule in its club's colour (when
## `club` is given), so the side shows before a name is read.
static func row_style(club: String, band := false, mine := false) -> StyleBoxFlat:
	var flat := StyleBoxFlat.new()
	flat.bg_color = UiKit.PANEL if band else Color.TRANSPARENT
	if club == "" or not GameDB.clubs.has(club):
		return flat
	if mine:
		flat.bg_color = Color(UiKit.club_vivid(club), 0.22)
		flat.border_width_left = 4
	else:
		flat.border_width_left = 3
	flat.border_color = UiKit.club_vivid(club)
	return flat


## Colour the name beside a club_badge's guernsey (and set it bold for yours).
static func badge(b: Node, code: String, bold := false) -> void:
	for c in b.get_children():
		if c is Label:
			var l := c as Label
			l.add_theme_color_override("font_color", ink(code))
			if bold:
				l.add_theme_font_override("font", UiKit.BOLD)


## Weight for every label under a node.
static func embolden(n: Node) -> void:
	if n is Label:
		(n as Label).add_theme_font_override("font", UiKit.BOLD)
	for c in n.get_children():
		embolden(c)
