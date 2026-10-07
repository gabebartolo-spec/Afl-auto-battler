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
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)
	_root = UiKit.vbox(8)
	margin.add_child(_root)
	get_viewport().size_changed.connect(_on_resize)
	_build()


func _on_resize() -> void:
	if is_inside_tree() and GameState.season != null:
		_build()


## The width a section has to lay itself out in.
func content_width() -> float:
	return maxf(240.0, UiKit.view_width(self) - 28.0)


func wide() -> bool:
	return content_width() >= 900.0


func _build() -> void:
	UiKit.clear(_root)
	_root.add_child(UiKit.top_bar("Season stats", true))
	var tabs := HFlowContainer.new()
	tabs.name = "StatsSections"
	tabs.add_theme_constant_override("h_separation", 2)
	tabs.add_theme_constant_override("v_separation", 2)
	_root.add_child(tabs)
	for s in SECTIONS:
		var key := str(s[0])
		var t := UiKit.tab(str(s[1]), key == current)
		t.name = "Section_" + key
		t.custom_minimum_size = Vector2(0 if wide() else 112, 44)
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
	_body.add_child(_section(current))


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
