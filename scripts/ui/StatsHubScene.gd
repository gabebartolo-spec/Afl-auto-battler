extends Control
## Season stats (director, 2026-10-07: the Stats patch, ROADMAP §1.11): the
## hub's way into the whole season - the full ladder, every player's numbers,
## the awards races, the fixture and results, and your trophy room. One tab
## row, one section at a time; each section is its own builder
## (scripts/ui/stats/), handed this scene as its host.

const SECTIONS := [
	["ladder", "Ladder"], ["players", "Player stats"], ["awards", "Awards"],
	["fixture", "Fixture"], ["trophies", "Trophy room"],
]
## The section you were on, kept for the visit after a drill-down (a player's
## bio, a team's field view) brings you back.
static var current := "ladder"

var _root: VBoxContainer
var _body: VBoxContainer
## The sheets over a section (a match's box score, a club's side and a player
## opened from it), the last on top.
var _sheets: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null:
		Router.replace("main")
		return
	# Your club's colour behind the page, as on the hub and match day
	# (director, 2026-10-10: every screen in the gameday style).
	add_child(ClubBackdrop.new().setup(GameState.my_club))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)
	_root = UiKit.vbox(8)
	margin.add_child(_root)
	get_viewport().size_changed.connect(_on_resize)
	_build()
	if not bool(GameState.get_setting("seen_season_stats_intro", false)):
		_show_intro.call_deferred()


func _on_resize() -> void:
	if is_inside_tree() and GameState.season != null:
		_build()


## On a wide screen each section sits centred in a column about as wide as
## its content (director, 2026-10-07: "centre the content mid screen rather
## than anchored left"); the tables that use the width keep all of it.
const SECTION_W := {"ladder": 880.0, "players": 1240.0, "awards": 980.0,
		"fixture": 1240.0, "trophies": 720.0}


func _full_width() -> float:
	return maxf(240.0, UiKit.view_width(self) - 28.0)


## The width a section has to lay itself out in: its column on a wide
## screen, the whole width on a phone.
func content_width() -> float:
	var w := _full_width()
	if w < 900.0:
		return w
	return minf(w, float(SECTION_W.get(current, w)))


## A wide screen (a PC), whatever the section's column.
func wide() -> bool:
	return _full_width() >= 900.0


func _build() -> void:
	UiKit.clear(_root)
	_root.add_child(UiKit.top_bar("Season stats", true))
	_root.add_child(_hero())
	# One row of sections: it scrolls sideways on a phone rather than
	# stacking three rows of tabs over the table.
	var tabs := HBoxContainer.new()
	tabs.name = "StatsSections"
	tabs.add_theme_constant_override("separation", 2)
	if wide():
		tabs.alignment = BoxContainer.ALIGNMENT_CENTER
		_root.add_child(tabs)
	else:
		var strip := ScrollContainer.new()
		strip.name = "SectionStrip"
		strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		strip.custom_minimum_size.y = 46
		strip.add_child(tabs)
		_root.add_child(strip)
	for s in SECTIONS:
		var key := str(s[0])
		var t := UiKit.tab(str(s[1]), key == current)
		t.name = "Section_" + key
		t.custom_minimum_size = Vector2(150 if wide() else 0, 44)
		t.pressed.connect(func():
			current = key
			_build.call_deferred())
		tabs.add_child(t)
	_body = UiKit.vbox(10)
	_body.name = "SectionBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := UiKit.scroll(_body)
	sc.name = "StatsScroll"
	_root.add_child(sc)
	var section := _section(current)
	if wide():
		section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		section.custom_minimum_size.x = content_width()
	_body.add_child(section)


## Where your season stands, as the hub says it: your ladder spot big in
## your colour, the round and your record beside it.
func _hero() -> Control:
	var season: Season = GameState.season
	var row := UiKit.hbox(12)
	row.name = "StatsHero"
	if wide():
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	var pos := UiKit.figure(GameState.ordinal(GameState.my_position()), 40, UiKit.club_vivid(GameState.my_club))
	pos.name = "StatsHeroPosition"
	row.add_child(pos)
	var when := "Home and away complete" if season.is_regular_done() 			else "After round %d of %d" % [season.round_index, Season.REGULAR_ROUNDS]
	var lr := GameState.my_ladder_row()
	var txt := UiKit.vbox(0)
	txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	txt.add_child(UiKit.line("%s  ·  %s  ·  %d pts" % [GameDB.club_short(GameState.my_club),
			GameState.my_record(), int(lr.get("pts", 0))], UiKit.H2, UiKit.TEXT, true))
	txt.add_child(UiKit.line(when, UiKit.SMALL, UiKit.MUTED))
	row.add_child(txt)
	return row


func _section(key: String) -> Control:
	match key:
		"ladder":
			return StatsLadder.build(self)
		"players":
			return StatsPlayers.build(self)
		"awards":
			return StatsAwards.build(self)
		"fixture":
			return StatsFixture.build(self)
		"trophies":
			return StatsTrophies.build(self)
	return Control.new()


## Rebuild the current section (a filter or sort changed).
func refresh() -> void:
	_build.call_deferred()


## First visit only: what is here and how it works, in two lines. "Got it"
## (or Back) closes it for good.
func _show_intro() -> void:
	var box := UiKit.modal_box(self, 520.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "SeasonStatsIntro"
	UiKit.close_on_outside_tap(box)
	open_sheet(overlay)
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Season stats", UiKit.TITLE))
	for line in [
		"The whole season in one place: the ladder, every player's numbers, the awards races, every match, and your club's trophy room.",
		"Tap a column heading to sort, and again to reverse it. Tap a player, a club or a match to open it.",
	]:
		var l := UiKit.lbl(line, 14, UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	GameState.set_setting("seen_season_stats_intro", true)
	var ok := UiKit.btn("Got it", 17, true)
	ok.name = "SeasonStatsIntroOk"
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(func(): close_sheet())
	(box["footer"] as VBoxContainer).add_child(ok)


## A section's sheet goes over the hub, over any already open; Back closes the
## top one first.
func open_sheet(sheet: Control) -> void:
	_sheets.append(sheet)


func close_sheet() -> bool:
	while not _sheets.is_empty():
		var top: Control = _sheets.pop_back()
		if is_instance_valid(top) and not top.is_queued_for_deletion():
			top.queue_free()
			return true
	return false


## Back closes a sheet first, then leaves.
func handle_back() -> bool:
	return close_sheet()
