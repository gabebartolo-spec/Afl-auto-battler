extends Control
## The pre-season (PreSeason.gd), between the off-season wrap and Round 1.
## One job per stop:
##   the plan       a load and a focus for each of the three blocks, then go;
##   the time trial who ran well and who did not, and the blocks still to come.
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
	if is_inside_tree() and GameState.preseason_active():
		_build()


func _wide() -> bool:
	return UiKit.view_width(self) >= WIDE


func _build() -> void:
	UiKit.clear(_root)
	_lines = {}
	_choices = {}
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
	if stop == "trial" and _wide():
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
		var words := UiKit.vbox(0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(hero)
		words.add_child(sub)
		who.add_child(words)
	else:
		v.add_child(hero)
		v.add_child(sub)
	if stop == "trial":
		# The stopwatch at the time trial (director, 2026-10-14), at the end of
		# the club's row, where it takes no room from the words. Decoration: it
		# takes no tap, and without the picture the header is as it was.
		var watch := UiArt.view("stopwatch", WATCH_WIDE if _wide() else WATCH_NARROW, CultureSheet.emblem_tint(GameState.my_club))
		if watch != null:
			watch.name = "TrialStopwatch"
			if not _wide():
				# A phone: the club's row keeps its height; the watch hangs
				# from its top into the space beside the big line.
				watch.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			who.add_child(watch)
	v.add_child(_club_rule())
	return v


## The stopwatch at the time trial stop: this tall on a phone and on a wide screen.
const WATCH_NARROW := 44.0
const WATCH_WIDE := 56.0


func _hero(stop: String) -> String:
	match stop:
		"plan":
			return "Eight weeks to Round 1"
		"trial":
			return "The time trial"
	return "Week %d of 8" % mini(PreSeason.weeks(), GameState.preseason_week() + 1)


func _hero_sub(stop: String) -> String:
	match stop:
		"plan":
			return "Set the training for each block. Training runs until the time trial, after week 3."
		"trial":
			return "Two kilometres at the end of week 3. This is the order they finished. No rating or fitness changes because of it."
	return "Training is under way."


## A 2 px rule in the club's colour: the section belongs to your club.
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
	var gain := _stake(v, "Gain:", "BlockGain_%d" % i)
	var cost := _stake(v, "Cost:", "BlockCost_%d" % i)
	_lines[i] = {"gain": gain, "cost": cost}
	return row


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
		(_lines[i]["gain"] as Label).text = PreSeason.gain_line(load, focus, int(i))
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
	var go := _primary("Start training" if stop == "plan" else "Back to training")
	go.name = "PreSeasonGo"
	go.custom_minimum_size = Vector2(0, 48)
	go.pressed.connect(_on_go)
	var quiet := UiKit.hbox(6)
	quiet.name = "PreSeasonNav"
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
	var base: Control = _base_result() if stop != "trial" else Control.new()
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
		if stop != "trial":
			v.add_child(base)
		else:
			base.free()
		v.add_child(go)
		v.add_child(quiet)
	return v


func _on_go() -> void:
	_after(GameState.preseason_advance())


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
	if _settings != null and is_instance_valid(_settings):
		_settings.queue_free()
		_settings = null
		return true
	return false
