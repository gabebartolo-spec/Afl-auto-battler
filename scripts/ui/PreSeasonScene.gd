extends Control
## The pre-season (PreSeason.gd), between the off-season wrap and Round 1.
## One job per stop:
##   the plan       a load and a focus for each of the three blocks, then go;
##   the time trial who ran well and who did not, and the blocks still to come;
##   the intra-club  how the two sides are made and which draft prospects are
##                   invited, then (coached or simmed) what the match showed.
## Every choice says what it gains and what it costs in words, and the fitness
## base the training builds is pinned above the way on, so it answers each
## change in view. Nothing is recommended. The hub sends the coach here while a
## pre-season is running and takes him back when Round 1 is next.

const WIDE := 900.0
## A primary button's fill must stand off the page by at least this much, or
## the club's readable ink carries it (Fremantle's purple on the dark page).
const FILL_MIN_CONTRAST := 2.0

var _root: VBoxContainer
var _settings: Control
var _lines := {}        # block index -> {"gain": Label, "cost": Label}
var _drill_rows := {}   # block index -> the plans it drills (shown on a Game plan block)
var _drill_buttons := {}   # block index -> {plan: Button}
var _choices := {}      # "Load0" / "Focus0" -> {key: Button}
var _base_head: Label
var _base_body: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null:
		Router.replace("main")
		return
	if not GameState.preseason_active():
		Router.replace("hub")
		return
	# Back from a coached intra-club match: its two sides are done with.
	GameDB.unregister_sides()
	add_child(ClubBackdrop.new().setup(GameState.my_club).live())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)
	_root = UiKit.vbox(10)
	margin.add_child(_root)
	get_viewport().size_changed.connect(_on_resize)
	_build()


func _on_resize() -> void:
	if is_inside_tree() and GameState.preseason_active() and not UiKit.keyboard_resize(self):
		_build()


func _wide() -> bool:
	return UiKit.view_width(self) >= WIDE


func _build() -> void:
	UiKit.clear(_root)
	_lines = {}
	_choices = {}
	_drill_rows = {}
	_drill_buttons = {}
	var stop: String = GameState.preseason_stop()
	var settings := UiKit.btn("Settings", UiKit.SECONDARY)
	settings.name = "PreSeasonSettings"
	settings.flat = true
	settings.custom_minimum_size = Vector2(64, 44)
	settings.add_theme_color_override("font_color", UiKit.TEXT)
	settings.pressed.connect(func(): _settings = OptionsSheet.open(self, true))
	_root.add_child(UiKit.top_bar("Pre-season", false, settings))

	var page := UiKit.vbox(UiKit.SECTION)
	page.name = "PreSeasonPage"
	_root.add_child(UiKit.scroll(page))
	page.add_child(_header(stop))
	var first := 0
	for i in range(PreSeason.block_count()):
		if not GameState.preseason_block_open(i):
			first = i + 1
	if stop == "story":
		page.add_child(_story_cards())
		page.add_child(_blocks_section(first, _wide()))
		page.add_child(_base_result())
	elif stop == "intra":
		if GameState.intra_played():
			page.add_child(_intra_report())
			page.add_child(_blocks_section(first, _wide()))
			page.add_child(_base_result())
		else:
			page.add_child(_intra_setup())
	elif stop == "trial" and _wide():
		# A PC: the time trial on the left, the weeks to come beside it.
		var cols := UiKit.hbox(28)
		var left := _trial_section()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 0.5
		cols.add_child(left)
		var right := _blocks_section(first, true)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(UiKit.spacer(4))
		right.add_child(_base_result())
		cols.add_child(right)
		page.add_child(cols)
	else:
		if stop == "trial":
			page.add_child(_trial_section())
		else:
			page.add_child(_season_plan_section())
		page.add_child(_blocks_section(first, _wide()))
	if stop == "trial" and not _wide():
		# At the time trial the base answers the blocks below it, not the list:
		# it sits with them at the foot of the page, never pinned over the names.
		page.add_child(_base_result())
	if not _wide():
		# Air under the last row, so the page never ends hard against the footer.
		page.add_child(UiKit.spacer(12))
	_root.add_child(UiKit.rule())
	_root.add_child(_actions(stop))
	_refresh_words()


## Whose pre-season it is and where it stands: the club's marker and colour,
## then the one big line.
func _header(stop: String) -> Control:
	var v := UiKit.vbox(4)
	v.name = "PreSeasonHeader"
	var who := UiKit.hbox(10)
	who.add_child(UiKit.club_marker(GameState.my_club, 32.0))
	var names := UiKit.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var club := UiKit.lbl(GameDB.club_name(GameState.my_club), UiKit.NAME, UiKit.club_ink(GameState.my_club), true)
	club.name = "PreSeasonClub"
	names.add_child(club)
	names.add_child(UiKit.lbl("Before the %d season" % GameState.season_year, UiKit.SECONDARY, UiKit.TEXT))
	who.add_child(names)
	v.add_child(who)
	var hero := UiKit.heading(_hero(stop), UiKit.TITLE)
	hero.name = "PreSeasonHero"
	hero.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sub := UiKit.lbl(_hero_sub(stop), UiKit.BODY, UiKit.TEXT)
	sub.name = "PreSeasonSub"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _wide():
		# A PC is short: the club and the big line share one row.
		names.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		for n in names.get_children():
			(n as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		who.add_theme_constant_override("separation", 14)
		_hang_watch(stop, who, WATCH_WIDE)   # between the club and the big line it belongs to
		var words := UiKit.vbox(0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(hero)
		words.add_child(sub)
		who.add_child(words)
	else:
		_hang_watch(stop, who, WATCH)   # at the end of the club's row, down beside the big line
		v.add_child(hero)
		v.add_child(sub)
	v.add_child(_club_rule())
	return v


## The stopwatch at the time trial, hung from the top of the club's row in a
## slot with no height of its own: the header is exactly as tall as without
## it and nothing under it moves. Steel and white, never tinted; no tap.
func _hang_watch(stop: String, who: HBoxContainer, height: float) -> void:
	if stop != "trial":
		return
	var watch := UiArt.view("stopwatch", height)
	if watch == null:
		return
	watch.name = "TrialStopwatch"
	var slot := Control.new()
	slot.name = "TrialStopwatchSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(watch.custom_minimum_size.x, 0)
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	watch.size = watch.custom_minimum_size
	slot.add_child(watch)
	who.add_child(slot)


## The stopwatch at the time trial stop (director, 2026-10-14: "Bigger, in
## real colours"). It may not move anything, so it is as tall as the words it
## stands beside: on a phone the club's row and the big line (56), on a wide
## screen the one row the header is (40).
const WATCH := 56.0
const WATCH_WIDE := 40.0


func _hero(stop: String) -> String:
	match stop:
		"plan":
			return "Eight weeks to Round 1"
		"trial":
			return "The time trial"
		"intra":
			return "The intra-club match"
		"story":
			return "After week %d of %d" % [GameState.preseason_week(), PreSeason.weeks()]
	return "Week %d of 8" % mini(PreSeason.weeks(), GameState.preseason_week() + 1)


func _hero_sub(stop: String) -> String:
	match stop:
		"plan":
			return "Set the training for each block. Training runs until the time trial, after week 3."
		"trial":
			return "Two kilometres at the end of week 3. This is the order they finished. No rating or fitness changes because of it."
		"intra":
			if GameState.intra_played():
				return "End of week 5. It counts for nothing on the ladder; what it showed is below."
			return "End of week 5: two sides of 23 from your own list, with prospects from this year's National Draft filling the spots. It counts for nothing on the ladder."
		"story":
			return "Something has come up. Answer it, or press on and nothing changes."
	return "Training is under way."


# ---------------------------------------------------------------------------
# The intra-club match: the sides and the invitations, then the report
# ---------------------------------------------------------------------------
var _invite_count: Label
var _invite_rows := {}      # prospect id -> Button


## Before it is played: how the sides are made, and who is invited.
func _intra_setup() -> Control:
	var v := UiKit.vbox(UiKit.SECTION)
	v.name = "IntraSetup"
	var intra: Dictionary = GameState.preseason_intra()
	var mode := str(intra.get("mode", "even"))
	var sides := UiKit.vbox(6)
	sides.add_child(_section_head("The two sides"))
	var names: Array = GameDB.SIDE_COLOUR_NAMES.get(GameState.my_club, ["Home", "Clash"])
	var strips := UiKit.lbl("%s %s v %s %s. You coach %s." % [GameDB.club_name(GameState.my_club), str(names[0]),
			GameDB.club_name(GameState.my_club), str(names[1]), str(names[0])], UiKit.BODY, UiKit.TEXT)
	strips.name = "IntraStrips"
	strips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sides.add_child(strips)
	var options := []
	for k in PreSeason.INTRA_MODES:
		options.append([str(k), str(PreSeason.INTRA_MODE_LABEL[k])])
	var gain := _stake(sides, "Gain:", "IntraGain")
	var cost := _stake(sides, "Cost:", "IntraCost")
	gain.text = str(PreSeason.INTRA_GAIN[mode])
	cost.text = str(PreSeason.INTRA_COST[mode])
	var pick := _choice_row("Sides", "IntraMode", options, mode, func(key: String):
		GameState.set_intra_mode(key)
		gain.text = str(PreSeason.INTRA_GAIN[key])
		cost.text = str(PreSeason.INTRA_COST[key]))
	sides.add_child(pick)
	sides.move_child(pick, (gain.get_meta("row") as Control).get_index())
	v.add_child(sides)

	var need: int = GameState.intra_needed()
	var guests := UiKit.vbox(6)
	guests.name = "IntraInvites"
	guests.add_child(_section_head("Prospects to invite"))
	var why := UiKit.lbl("Your sides need %d more. Whoever you invite, your recruiters see him play against senior bodies: his draft card gets a line on what he did, and their read of him is a little surer. He cannot be hurt and nothing else about him changes." % need,
			UiKit.SECONDARY, UiKit.TEXT)
	why.name = "IntraWhy"
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guests.add_child(why)
	var head := UiKit.hbox(8)
	_invite_count = UiKit.lbl("", UiKit.BODY, UiKit.TEXT, true)
	_invite_count.name = "IntraCount"
	_invite_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_invite_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_invite_count)
	var fill := UiKit.btn("Recruiters fill the rest", UiKit.BODY)
	fill.name = "IntraFill"
	fill.custom_minimum_size = Vector2(0, 44)
	fill.pressed.connect(func():
		GameState.intra_fill_invites()
		_refresh_invites())
	head.add_child(fill)
	guests.add_child(head)
	_invite_rows = {}
	var grid := GridContainer.new()
	grid.name = "IntraProspects"
	grid.columns = 3 if _wide() else 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for p in GameState.intra_prospects():
		var id := str(p["id"])
		var b := UiKit.btn("", UiKit.BODY)
		b.name = "Invite_" + id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34 if _wide() else 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s  ·  %s, age %d" % [GameDB.player_display_name(p),
				str(UiKit.ROLE_LABEL.get(str(p.get("role", "")), str(p.get("role", "")))), int(float(p.get("age", 18.0)))]
		b.pressed.connect(func():
			GameState.toggle_intra_invite(id)
			_refresh_invites())
		_invite_rows[id] = b
		grid.add_child(b)
	guests.add_child(grid)
	v.add_child(guests)
	_refresh_invites()
	return v


## The invitations as they stand: who is in (bold, outlined), and how many.
func _refresh_invites() -> void:
	var invites: Array = GameState.intra_invites()
	for id in _invite_rows:
		_paint_choice(_invite_rows[id], invites.has(str(id)))
	if _invite_count != null and is_instance_valid(_invite_count):
		_invite_count.text = "%d of %d invited" % [invites.size(), GameState.intra_needed()]


## After it is played: the score, who stood out, who struggled, who was hurt,
## and what was seen of each prospect.
func _intra_report() -> Control:
	var v := UiKit.vbox(6)
	v.name = "IntraReport"
	var rep: Dictionary = GameState.preseason_intra().get("report", {})
	var names: Array = rep.get("names", ["", ""])
	var goals: Array = rep.get("goals", [0, 0])
	var behinds: Array = rep.get("behinds", [0, 0])
	for side in range(2):
		var row := UiKit.hbox(8)
		var nm := UiKit.lbl(str(names[side]), UiKit.NAME, UiKit.TEXT, true)
		nm.name = "IntraSide_%d" % side
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var fig := UiKit.figure(UiKit.scoreline(int(goals[side]), int(behinds[side])), UiKit.NUMBER)
		fig.name = "IntraScore_%d" % side
		row.add_child(fig)
		v.add_child(row)
	for part in [["Stood out", "stood", "IntraStood"], ["Struggled", "struggled", "IntraStruggled"]]:
		var ids: Array = rep.get(str(part[1]), [])
		if ids.is_empty():
			continue
		v.add_child(UiKit.spacer(4))
		v.add_child(_section_head(str(part[0])))
		for i in range(ids.size()):
			v.add_child(_runner(str(ids[i]), "", "%s_%d" % [str(part[2]), i]))
	var hurt: Array = rep.get("hurt", [])
	if not hurt.is_empty():
		v.add_child(UiKit.spacer(4))
		v.add_child(_section_head("Hurt in the match"))
		for i in range(hurt.size()):
			var l := UiKit.lbl(str(hurt[i]), UiKit.BODY, UiKit.BAD)
			l.name = "IntraHurt_%d" % i
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	var seen: Array = rep.get("prospects", [])
	if not seen.is_empty():
		var names_by_id := {}
		for p in GameState.intra_prospects():
			names_by_id[str(p["id"])] = GameDB.player_display_name(p)
		v.add_child(UiKit.spacer(4))
		v.add_child(_section_head("Prospects seen"))
		var note := UiKit.lbl("Each line is on his draft card from now on.", UiKit.SECONDARY, UiKit.TEXT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(note)
		for i in range(seen.size()):
			var row: Dictionary = seen[i]
			var box := UiKit.vbox(0)
			var n := UiKit.name_label(str(names_by_id.get(str(row["id"]), "A prospect")))
			n.name = "IntraSeen_%d" % i
			box.add_child(n)
			var line := UiKit.lbl(str(row.get("line", "")), UiKit.SECONDARY, UiKit.TEXT)
			line.name = "IntraSeenLine_%d" % i
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(line)
			box.add_child(UiKit.rule())
			v.add_child(box)
	return v


## A 2 px rule in the club's colour: the section belongs to your club.
## The card or cards the block threw up, answered here as on the hub.
func _story_cards() -> Control:
	var v := UiKit.vbox(10)
	v.name = "PreSeasonCards"
	for i in range(GameState.week_events.size()):
		v.add_child(EventCardView.build(i, not _wide(), func(): _build(),
				func(t: String): EventCardView.rule_sheet(self, t)))
	return v


func _club_rule() -> Control:
	var r := ColorRect.new()
	r.color = UiKit.club_ink(GameState.my_club)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _section_head(text: String) -> Label:
	return UiKit.lbl(text, UiKit.HEADING, UiKit.TEXT, true)


## The season fitness plan (Conditioning): the pre-season is where it is set,
## on the sheet the hub and Training already open. One full-width row, its
## chevron at its own right edge; the plan's name under it is at full strength
## here, because this is the stop where it is chosen.
func _season_plan_section() -> Control:
	var v: BoxContainer = UiKit.hbox(20) if _wide() else UiKit.vbox(4)
	v.name = "PreSeasonSeasonPlan"
	var head := _section_head("Season fitness plan")
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(head)
	var line := SeasonPlanSheet.line(self, func(): _build())
	if line != null:
		var sub := line.find_child("SeasonPlanSub", true, false) as Label
		if sub != null:
			# The plan's name is in the line above it; here, what the tap is for.
			sub.text = "Tap to change it, any time before Round 1."
			sub.add_theme_color_override("font_color", UiKit.TEXT)
		if _wide():
			# A PC: the row is as wide as its words, so its chevron sits beside
			# them, not at the far edge of the screen.
			line.custom_minimum_size = Vector2(380, 44)
			line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(line)
	return v


## The blocks from `first` on: on a phone one under another, on a PC side by
## side when `across`.
func _blocks_section(first: int, across: bool) -> Control:
	var v := UiKit.vbox(10)
	v.name = "PreSeasonBlocks"
	v.add_child(_section_head("Training blocks" if first == 0 else "The weeks to come"))
	var holder: BoxContainer = UiKit.hbox(20) if across else UiKit.vbox(UiKit.SECTION)
	v.add_child(holder)
	for i in range(first, PreSeason.block_count()):
		var b := _block(i)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Side by side, each block (and its club bar) is as tall as its own words.
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		holder.add_child(b)
	var quiet := UiKit.lbl("Week 8 is a quiet week: no training and nothing to choose. Heavy or fresh legs from weeks 6 to 7 last into Round 1.",
			UiKit.SECONDARY, UiKit.TEXT)
	quiet.name = "PreSeasonQuietWeek"
	quiet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(quiet)
	return v


## One block: its weeks, the load, the focus, and what the pair gains and
## costs. A bar in the club's colour sets it apart from the next.
func _block(i: int) -> Control:
	var row := UiKit.hbox(10)
	row.name = "Block_%d" % i
	var bar := ColorRect.new()
	bar.color = UiKit.club_ink(GameState.my_club)
	bar.custom_minimum_size = Vector2(4, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var v := UiKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var title := UiKit.lbl(PreSeason.block_title(i), UiKit.NAME, UiKit.TEXT, true)
	title.name = "BlockTitle_%d" % i
	v.add_child(title)
	var blocks: Array = GameState.preseason_blocks()
	var load_options := []
	for k in PreSeason.loads():
		load_options.append([str(k), str(PreSeason.LOAD_LABEL.get(k, k))])
	var focus_options := []
	for k in PreSeason.focuses():
		focus_options.append([str(k), str(PreSeason.FOCUS_LABEL.get(k, k))])
	v.add_child(_choice_row("Load", "Load%d" % i, load_options, str(blocks[i][0]),
			func(key: String): _pick(i, key, "")))
	v.add_child(_choice_row("Focus", "Focus%d" % i, focus_options, str(blocks[i][1]),
			func(key: String): _pick(i, "", key)))
	var drill := _drill_row(i)
	v.add_child(drill)
	_drill_rows[i] = drill
	var gain := _stake(v, "Gain:", "BlockGain_%d" % i)
	var cost := _stake(v, "Cost:", "BlockCost_%d" % i)
	_lines[i] = {"gain": gain, "cost": cost}
	return row


## The plans a Game plan block can drill: the five that take drilling, one or
## two chosen (a tap on a chosen one lets it go; a third takes the first's place).
## Shown only while the block's focus is Game plan.
func _drill_row(i: int) -> Control:
	var h := UiKit.vbox(4)
	h.name = "Drill%d" % i
	var l := UiKit.lbl("Drill", UiKit.BODY, UiKit.TEXT, true)
	h.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	h.add_child(grid)
	var buttons := {}
	for plan in PreSeason.DRILL_PLANS:
		var key := str(plan)
		var b := UiKit.btn(CoachReport.plan_label(key), UiKit.SECONDARY)
		b.name = "Drill%d_%s" % [i, key]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Two lines (the plan, how well the side knows it); the grid's width is
		# the block's, never the words'.
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(func(): _toggle_drill(i, key))
		buttons[key] = b
		grid.add_child(b)
	_drill_buttons[i] = buttons
	return h


## How well the side knows a plan, and where the drilling set leaves it:
## "medium", or "medium, then high" once the weeks are enough.
func _knows_words(plan: String) -> String:
	var now: int = GameState.plan_level(GameState.my_club, plan)
	var after: int = GameState.plan_level_after_drills(plan)
	var t := PreSeason.fluency_word(now)
	if after != now:
		t += ", then " + PreSeason.fluency_word(after)
	return t


func _toggle_drill(i: int, plan: String) -> void:
	var drills: Array = GameState.preseason_drills(i)
	if drills.has(plan):
		if drills.size() == 1:
			return   # a Game plan block always drills something
		drills.erase(plan)
	else:
		drills.append(plan)
		while drills.size() > int(PreSeason.tune("drill_max_plans")):
			drills.pop_front()
	GameState.set_preseason_drills(i, drills)
	_refresh_words()


## "Load" or "Focus" in bold beside its options. These are the coach's
## decisions, so no option is grey: every one is in full ink, and the chosen
## one is bold inside a light outline (the kit's selection: an outline, never
## a fill, never the club colour). Buttons are named "<node_name>_<key>".
func _choice_row(label: String, node_name: String, options: Array, current: String,
		on_pick: Callable) -> Control:
	var h := UiKit.hbox(8)
	var l := UiKit.lbl(label, UiKit.BODY, UiKit.TEXT, true)
	l.custom_minimum_size = Vector2(52, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var row := UiKit.hbox(6)
	row.name = node_name
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(row)
	var buttons := {}
	for o in options:
		var key := str(o[0])
		var b := UiKit.btn(str(o[1]), UiKit.BODY)
		b.name = "%s_%s" % [node_name, key]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			for k in buttons:
				_paint_choice(buttons[k], str(k) == key)
			on_pick.call(key))
		buttons[key] = b
		_paint_choice(b, key == current)
		# A thumb's height on a phone; a PC's pointer needs less, and its
		# screen is short.
		b.custom_minimum_size = Vector2(0, 34 if _wide() else 44)
		row.add_child(b)
	_choices[node_name] = buttons
	return h


func _paint_choice(b: Button, on: bool) -> void:
	var sb := UiKit.style(UiKit.SURFACE, 8, UiKit.RADIUS, UiKit.TEXT if on else Color.TRANSPARENT)
	sb.set_border_width_all(2 if on else 0)
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_font_override("font", UiKit.BOLD if on else UiKit.FONT)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, UiKit.TEXT)
	b.set_meta("chosen", on)


## A "Gain:" or "Cost:" line: the marker bold, the sentence regular, both at
## full strength (the card-stakes pattern).
func _stake(into: VBoxContainer, mark: String, node_name: String) -> Label:
	var item := UiKit.hbox(6)
	var mk := UiKit.lbl(mark, UiKit.SECONDARY, UiKit.TEXT, true)
	mk.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mk.autowrap_mode = TextServer.AUTOWRAP_OFF
	mk.custom_minimum_size = Vector2(40, 0)
	item.add_child(mk)
	var l := UiKit.lbl("", UiKit.SECONDARY, UiKit.TEXT)
	l.name = node_name
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(l)
	into.add_child(item)
	l.set_meta("row", item)
	return l


func _pick(i: int, load: String, focus: String) -> void:
	var blocks: Array = GameState.preseason_blocks()
	GameState.set_preseason_block(i, load if load != "" else str(blocks[i][0]),
			focus if focus != "" else str(blocks[i][1]))
	_refresh_words()


## The fitness base the training builds, and what that base does: the result
## of every choice above it, pinned over the way on.
func _base_result() -> Control:
	var v := UiKit.vbox(0)
	v.name = "PreSeasonBase"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_base_head = UiKit.lbl("", UiKit.BODY, UiKit.TEXT, true)
	_base_head.name = "PreSeasonBaseWord"
	_base_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_base_head)
	_base_body = UiKit.lbl("", UiKit.SECONDARY, UiKit.TEXT)
	_base_body.name = "PreSeasonBaseEffect"
	_base_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_base_body)
	return v


## The words under every choice, after a pick: no rebuild, so the page stays
## where the thumb left it.
func _refresh_words() -> void:
	var blocks: Array = GameState.preseason_blocks()
	for i in _lines:
		var load := str(blocks[i][0])
		var focus := str(blocks[i][1])
		(_lines[i]["gain"] as Label).text = PreSeason.gain_line(load, focus, int(i), GameState.preseason_drills(int(i)))
		if _drill_rows.has(i):
			(_drill_rows[i] as Control).visible = focus == "plan"
			var drills: Array = GameState.preseason_drills(int(i))
			for plan in (_drill_buttons[i] as Dictionary):
				var btn: Button = _drill_buttons[i][plan]
				_paint_choice(btn, drills.has(str(plan)))
				btn.text = "%s\n%s" % [CoachReport.plan_label(str(plan)), _knows_words(str(plan))]
		var cost := PreSeason.cost_line(load, focus, int(i))
		(_lines[i]["cost"] as Label).text = cost
		# A cost is shown only when there is one.
		((_lines[i]["cost"] as Label).get_meta("row") as Control).visible = cost != ""
	if _base_head != null and is_instance_valid(_base_head):
		var base: String = GameState.preseason_base()
		_base_head.text = "This training builds %s." % str(PreSeason.BASE_LABEL[base])
		_base_body.text = str(PreSeason.BASE_EFFECT[base])


## The time trial: the order they came home, the first five and the last
## three, by name.
func _trial_section() -> Control:
	var v := UiKit.vbox(4)
	v.name = "TimeTrial"
	var trial: Dictionary = GameState.preseason_trial()
	v.add_child(_section_head("First five home"))
	var best: Array = trial.get("best", [])
	for i in range(best.size()):
		v.add_child(_runner(str(best[i]), "%d" % (i + 1), "TrialBest_%d" % i))
	var worst: Array = trial.get("worst", [])
	if not worst.is_empty():   # a list too short for a tail: no heading over no names
		v.add_child(UiKit.spacer(6))
		v.add_child(_section_head("Last three home" if worst.size() == 3 else "Last home"))
		for i in range(worst.size()):
			v.add_child(_runner(str(worst[i]), "", "TrialWorst_%d" % i))
	# Who a Heavy block cost, in the game's usual injury words.
	var hurt: Array = GameState.preseason_injury_lines(1, GameState.preseason_week())
	if not hurt.is_empty():
		v.add_child(UiKit.spacer(6))
		v.add_child(_section_head("Hurt in training"))
		for i in range(hurt.size()):
			var l := UiKit.lbl(str(hurt[i]), UiKit.BODY, UiKit.BAD)
			l.name = "TrialHurt_%d" % i
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	return v


## One runner on one line: his place (the first five), his name in bold, where
## he plays at the right.
func _runner(id: String, place: String, node_name: String) -> Control:
	var p: Dictionary = GameState.list_player(id)
	var box := UiKit.vbox(2)
	var h := UiKit.hbox(10)
	h.custom_minimum_size = Vector2(0, 22 if _wide() else 30)
	if place != "":
		var fig := UiKit.figure(place, UiKit.NUMBER)
		fig.custom_minimum_size = Vector2(26, 0)
		fig.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(fig)
	var n := UiKit.name_label(GameDB.player_display_name(p) if not p.is_empty() else "A player who has left")
	n.name = node_name
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(n)
	if not p.is_empty():
		var role := UiKit.lbl(str(UiKit.ROLE_LABEL.get(str(p.get("role", "")), str(p.get("role", "")))),
				UiKit.SECONDARY, UiKit.TEXT)
		role.autowrap_mode = TextServer.AUTOWRAP_OFF
		role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(role)
	box.add_child(h)
	box.add_child(UiKit.rule())
	return box


## The primary action, filled with the club's readable ink (UiKit.club_ink)
## and dark or light type by its brightness: the kit's own club fill sinks
## into the dark page for some clubs (Fremantle) and into the club's stripes
## for others (the Bulldogs' red).
func _primary(text: String) -> Button:
	var b := UiKit.btn(text, UiKit.NAME, true)
	var fill := UiKit.club_ink(GameState.my_club)
	var ink := UiKit.ink_on(fill)
	var shades := {"normal": fill, "hover": fill.lightened(0.08),
			"pressed": fill.darkened(0.12), "hover_pressed": fill.darkened(0.12)}
	for state in shades:
		var sb := UiKit.style(shades[state], 8, UiKit.RADIUS)
		sb.set_border_width_all(0)
		b.add_theme_stylebox_override(str(state), sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, ink)
	return b


## The way on, pinned under the page: what the training builds, then one
## primary action with the quiet ones beside it.
func _actions(stop: String) -> Control:
	var v := UiKit.vbox(6)
	v.name = "PreSeasonActions"
	var setup := stop == "intra" and not GameState.intra_played()
	var go := _primary("Start training" if stop == "plan" else ("Coach the match" if setup else "Back to training"))
	go.name = "PreSeasonGo"
	go.custom_minimum_size = Vector2(0, 48)
	go.pressed.connect(_on_coach if setup else _on_go)
	var quiet := UiKit.hbox(6)
	quiet.name = "PreSeasonNav"
	if setup:
		var sim_it := UiKit.btn("Sim the match", UiKit.BODY)
		sim_it.name = "IntraSim"
		sim_it.custom_minimum_size = Vector2(0, 44)
		sim_it.pressed.connect(_on_sim_intra)
		quiet.add_child(sim_it)
	if stop == "plan":
		var sim := UiKit.btn("Sim to Round 1", UiKit.BODY)
		sim.name = "PreSeasonSim"
		sim.custom_minimum_size = Vector2(0, 44)
		sim.pressed.connect(_on_sim)
		quiet.add_child(sim)
	for nav in [["My list", "list", "PreSeasonList"], ["Training", "training", "PreSeasonTraining"]]:
		var b := UiKit.btn(str(nav[0]), UiKit.BODY)
		b.name = str(nav[2])
		b.custom_minimum_size = Vector2(0, 44)
		var key := str(nav[1])
		b.pressed.connect(func(): Router.go(key))
		quiet.add_child(b)
	# The result of the plan is pinned here while the whole plan is being
	# set; at the time trial it sits with the blocks instead.
	var base: Control = _base_result() if stop == "plan" else Control.new()
	base.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _wide():
		# A PC: the result at the left, every button together at the right
		# with the way on last (no full-width bar).
		var row := UiKit.hbox(8)
		base.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(base)
		quiet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(quiet)
		go.custom_minimum_size = Vector2(240, 48)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(go)
		v.add_child(row)
	else:
		for c in quiet.get_children():
			(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if stop == "plan":
			v.add_child(base)
		else:
			base.free()
		v.add_child(go)
		v.add_child(quiet)
	return v


func _on_go() -> void:
	_after(GameState.preseason_advance())


## Coach it from the box: the match scene, with the two sides in their strips.
func _on_coach() -> void:
	if GameState.prepare_intra_match():
		Router.go("match")


## Or sim it: the report is the next thing on this screen.
func _on_sim_intra() -> void:
	GameState.sim_intra_match()
	GameState.autosave()
	_build()


func _on_sim() -> void:
	GameState.preseason_sim_to_round1()
	_after("done")


func _after(at: String) -> void:
	if at == "done" or not GameState.preseason_active():
		Router.replace("hub")
	else:
		_build()


## Android Back: an open sheet closes first; otherwise the router takes the
## coach to the main menu, as from the hub (the career is saved).
func handle_back() -> bool:
	var plan_sheet := get_node_or_null("SeasonPlanSheet")
	if plan_sheet != null and is_instance_valid(plan_sheet) and not plan_sheet.is_queued_for_deletion():
		plan_sheet.queue_free()
		_build()
		return true
	var rule := get_node_or_null("RuleSheet")
	if rule != null and is_instance_valid(rule) and not rule.is_queued_for_deletion():
		rule.queue_free()
		return true
	if _settings != null and is_instance_valid(_settings):
		_settings.queue_free()
		_settings = null
		return true
	return false
