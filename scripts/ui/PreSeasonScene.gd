extends Control
## The pre-season (PreSeason.gd), between the off-season wrap and Round 1.
## One job per stop:
##   the plan       a load and a focus for each of the three blocks, then go;
##   the time trial who ran well and who did not, and the blocks still to come.
## Every choice says what it gains and what it costs in words. Nothing is
## recommended. The hub sends the coach here while a pre-season is running
## and takes him back when Round 1 is next.

const WIDE := 900.0

var _root: VBoxContainer
var _settings: Control
var _lines := {}        # block index -> {"gain": Label, "cost": Label}
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
	var stop: String = GameState.preseason_stop()
	var settings := UiKit.btn("Settings", UiKit.SECONDARY)
	settings.name = "PreSeasonSettings"
	settings.flat = true
	settings.custom_minimum_size = Vector2(64, 44)
	settings.add_theme_color_override("font_color", UiKit.MUTED)
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
		left.size_flags_stretch_ratio = 0.8
		cols.add_child(left)
		var right := UiKit.vbox(UiKit.SECTION)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(_blocks_section(first, false))
		right.add_child(_base_section())
		cols.add_child(right)
		page.add_child(cols)
	else:
		if stop == "trial":
			page.add_child(_trial_section())
		elif _wide():
			var top := UiKit.hbox(28)
			var plan := _season_plan_section()
			plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(plan)
			var base := _base_section(true)
			base.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(base)
			page.add_child(top)
		else:
			page.add_child(_season_plan_section())
		page.add_child(_blocks_section(first, _wide(), not (_wide() and stop != "trial")))
		if not (_wide() and stop != "trial"):
			page.add_child(_base_section())
	_refresh_words()
	_root.add_child(_actions(stop))


## Whose pre-season it is and where it stands: the club's marker and colour,
## then the one big line.
func _header(stop: String) -> Control:
	var v := UiKit.vbox(4)
	v.name = "PreSeasonHeader"
	var who := UiKit.hbox(10)
	who.add_child(UiKit.club_marker(GameState.my_club, 32.0))
	var names := UiKit.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var club := UiKit.lbl(GameDB.club_name(GameState.my_club), UiKit.NAME, UiKit.TEXT, true)
	club.name = "PreSeasonClub"
	names.add_child(club)
	names.add_child(UiKit.lbl("%d pre-season" % GameState.season_year, UiKit.SECONDARY, UiKit.MUTED))
	who.add_child(names)
	v.add_child(who)
	var hero := UiKit.heading(_hero(stop), UiKit.TITLE)
	hero.name = "PreSeasonHero"
	hero.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hero)
	var sub := UiKit.lbl(_hero_sub(stop), UiKit.BODY, UiKit.TEXT)
	sub.name = "PreSeasonSub"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	v.add_child(_club_rule())
	return v


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
			return "Two kilometres at the end of week 3. Weeks 4 to 8 are still to come."
	return "Training is under way."


## A 2 px rule in the club's colour: the section belongs to your club.
func _club_rule() -> Control:
	var r := ColorRect.new()
	r.color = UiKit.club_vivid(GameState.my_club)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _section_head(text: String) -> Label:
	return UiKit.lbl(text, UiKit.HEADING, UiKit.TEXT, true)


## The season fitness plan (Conditioning): the pre-season is where it is set,
## on the sheet the hub and Training already open.
func _season_plan_section() -> Control:
	var v := UiKit.vbox(4)
	v.name = "PreSeasonSeasonPlan"
	v.add_child(_section_head("Season fitness plan"))
	var line := SeasonPlanSheet.line(self, func(): _build())
	if line != null:
		v.add_child(line)
	return v


## The blocks from `first` on: on a phone one under another, on a PC side by
## side when `across`.
func _blocks_section(first: int, across: bool, with_quiet := true) -> Control:
	var v := UiKit.vbox(10)
	v.name = "PreSeasonBlocks"
	v.add_child(_section_head("Training blocks" if first == 0 else "The weeks to come"))
	var holder: BoxContainer = UiKit.hbox(20) if across else UiKit.vbox(UiKit.SECTION)
	v.add_child(holder)
	for i in range(first, PreSeason.block_count()):
		var b := _block(i)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(b)
	if with_quiet:
		v.add_child(_quiet_week())
	return v


func _quiet_week() -> Label:
	var quiet := UiKit.lbl("Week 8 is a quiet week: no training choice, the side freshens up for Round 1.",
			UiKit.SECONDARY, UiKit.TEXT)
	quiet.name = "PreSeasonQuietWeek"
	quiet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return quiet


## One block: its weeks, the load, the focus, and what the pair gains and
## costs. A bar in the club's colour sets it apart from the next.
func _block(i: int) -> Control:
	var row := UiKit.hbox(10)
	row.name = "Block_%d" % i
	var bar := ColorRect.new()
	bar.color = UiKit.club_vivid(GameState.my_club)
	bar.custom_minimum_size = Vector2(4, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var title := UiKit.lbl(PreSeason.block_title(i), UiKit.NAME, UiKit.TEXT, true)
	title.name = "BlockTitle_%d" % i
	v.add_child(title)
	var blocks: Array = GameState.preseason_blocks()
	var load := str(blocks[i][0])
	var focus := str(blocks[i][1])
	var load_options := []
	for k in PreSeason.loads():
		load_options.append([str(k), str(PreSeason.LOAD_LABEL.get(k, k))])
	var focus_options := []
	for k in PreSeason.focuses():
		focus_options.append([str(k), str(PreSeason.FOCUS_LABEL.get(k, k))])
	v.add_child(_choice_row("Load", UiKit.segmented("Load%d" % i, load_options, load,
			func(key: String): _pick(i, key, ""))))
	v.add_child(_choice_row("Focus", UiKit.segmented("Focus%d" % i, focus_options, focus,
			func(key: String): _pick(i, "", key))))
	var gain := _stake(v, "Gain:", "BlockGain_%d" % i)
	var cost := _stake(v, "Cost:", "BlockCost_%d" % i)
	_lines[i] = {"gain": gain, "cost": cost}
	return row


## "Load" or "Focus" in bold beside its options: what he is choosing is never
## left in grey.
func _choice_row(label: String, options: Control) -> Control:
	var h := UiKit.hbox(8)
	var l := UiKit.lbl(label, UiKit.BODY, UiKit.TEXT, true)
	l.custom_minimum_size = Vector2(52, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	h.add_child(options)
	return h


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
	return l


func _pick(i: int, load: String, focus: String) -> void:
	var blocks: Array = GameState.preseason_blocks()
	GameState.set_preseason_block(i, load if load != "" else str(blocks[i][0]),
			focus if focus != "" else str(blocks[i][1]))
	_refresh_words()


## The fitness base the plan is heading for, and what that base does.
func _base_section(with_quiet := false) -> Control:
	var v := UiKit.vbox(4)
	v.name = "PreSeasonBase"
	v.add_child(_section_head("Fitness base"))
	_base_head = UiKit.lbl("", UiKit.NAME, UiKit.TEXT, true)
	_base_head.name = "PreSeasonBaseWord"
	_base_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_base_head)
	_base_body = UiKit.lbl("", UiKit.SECONDARY, UiKit.TEXT)
	_base_body.name = "PreSeasonBaseEffect"
	_base_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_base_body)
	if with_quiet:
		v.add_child(_quiet_week())
	return v


## The words under every choice, after a pick: no rebuild, so the page stays
## where the thumb left it.
func _refresh_words() -> void:
	var blocks: Array = GameState.preseason_blocks()
	for i in _lines:
		var load := str(blocks[i][0])
		var focus := str(blocks[i][1])
		var last := PreSeason.is_last_block(int(i))
		(_lines[i]["gain"] as Label).text = PreSeason.gain_line(load, focus, last)
		(_lines[i]["cost"] as Label).text = PreSeason.cost_line(load, focus, last)
	if _base_head != null and is_instance_valid(_base_head):
		var base: String = GameState.preseason_base()
		_base_head.text = "This training builds %s." % str(PreSeason.BASE_LABEL[base])
		_base_body.text = str(PreSeason.BASE_EFFECT[base])


## The time trial: the first five and the last three, by name.
func _trial_section() -> Control:
	var v := UiKit.vbox(6)
	v.name = "TimeTrial"
	var trial: Dictionary = GameState.preseason_trial()
	v.add_child(_section_head("First five home"))
	var best: Array = trial.get("best", [])
	for i in range(best.size()):
		v.add_child(_runner(str(best[i]), "%d" % (i + 1), "TrialBest_%d" % i))
	v.add_child(UiKit.spacer(6))
	v.add_child(_section_head("Last three home"))
	var worst: Array = trial.get("worst", [])
	for i in range(worst.size()):
		v.add_child(_runner(str(worst[i]), "", "TrialWorst_%d" % i))
	return v


## One runner: his place (the first five), his name in bold, his position and
## age under it.
func _runner(id: String, place: String, node_name: String) -> Control:
	var p: Dictionary = GameState.list_player(id)
	var box := UiKit.vbox(4)
	var h := UiKit.hbox(10)
	if place != "":
		var fig := UiKit.figure(place, UiKit.NUMBER)
		fig.custom_minimum_size = Vector2(26, 0)
		fig.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(fig)
	var names := UiKit.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UiKit.name_label(GameDB.player_display_name(p) if not p.is_empty() else "A player who has left")
	n.name = node_name
	names.add_child(n)
	if not p.is_empty():
		names.add_child(UiKit.lbl("%s, %d" % [str(UiKit.ROLE_LABEL.get(str(p.get("role", "")), str(p.get("role", "")))),
				int(float(p.get("age", 0.0)))], UiKit.SECONDARY, UiKit.MUTED))
	h.add_child(names)
	box.add_child(h)
	box.add_child(UiKit.rule())
	return box


## The way on, pinned under the page: one primary action, and on the plan
## stop the hands-off one beside the club's screens.
func _actions(stop: String) -> Control:
	var v := UiKit.vbox(6)
	v.name = "PreSeasonActions"
	var go := UiKit.btn("Start the pre-season" if stop == "plan" else "Back to training", UiKit.NAME, true)
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
	if _wide():
		# A PC: the quiet actions at the left, the way on at the right, sized
		# to its words (no full-width bar).
		var row := UiKit.hbox(8)
		row.add_child(quiet)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(gap)
		go.custom_minimum_size = Vector2(260, 48)
		row.add_child(go)
		v.add_child(row)
	else:
		for c in quiet.get_children():
			(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
