class_name PressScene
extends Control
## The post-match press conference as its own full screen (ruling 3.52, director
## 2026-10-19 "why is press conference still not a full screen scene?", ruled
## again 2026-11-06 Q4): the 2.5D room, the journalist and his outlet, the
## question, each answer with its odds line, and the result shown here once
## the answer lands. Continue, Skip or Back returns to the hub.
##
## The hub routes here (Router "press"). A hub that is not the running scene
## (a test or capture that builds one by hand) gets this screen laid over it
## instead, full size, through embed(); it closes the same way.

signal closed

## His opinion of you on the gate ("Opinion of you: Neutral") and after the
## answer ("Kev Pollard's opinion of you: Neutral → Warm"); the words are
## MediaConference.STANDING_WORDS.
const OPINION := "Opinion of you: %s"
const OPINION_MOVED := "%s's opinion of you: %s → %s"
## How long it lasts, after the answer. Morale and the board fade at different
## paces, so when both moved and differ, both are said.
const FADE_ONE := "It wears off over %d round%s."
const FADE_BOTH := "Morale wears off over %d round%s, the board over %d."

var _embedded := false
var _root: VBoxContainer
var _column: VBoxContainer
var _top_skip: Button
var _answered := false


## This screen laid over `host` (full size, not routed); `closed` fires when it
## leaves.
static func embed(host: Control) -> PressScene:
	var s: PressScene = load("res://scripts/ui/PressScene.gd").new()
	s._embedded = true
	host.add_child(s)
	return s


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not GameState.media_conference_pending():
		if not _embedded:
			Router.replace("hub" if GameState.season != null else "main")
		else:
			queue_free.call_deferred()
		return
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	add_child(ClubBackdrop.new().setup(GameState.my_club))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 16)
	add_child(margin)
	_root = UiKit.vbox(8)
	_root.name = "MediaConference"
	margin.add_child(_root)
	_build()


func _build() -> void:
	var vw := UiKit.view_width(self)
	var vh := UiKit.view_height(self)
	var wide := ScreenLayout.roomy(vw, vh)
	_root.add_child(_bar())
	var where := where_text(GameState.media_conference)
	if where != "":
		var w := UiKit.lbl(where, UiKit.SMALL, UiKit.MUTED)
		w.name = "MediaWhere"
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_root.add_child(w)
	var page := UiKit.vbox(14)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(UiKit.scroll(page))
	_column = UiKit.vbox(16 if wide else 15)
	_column.name = "MediaAnswers"
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scene: MediaConferenceVignette = null
	if wide:
		var row := UiKit.hbox(24)
		row.name = "MediaRow"
		page.add_child(row)
		if GameState.vignettes_on():
			var stage_w := minf(vw * 0.5, (vh - 120.0) * 1.6)
			var stage := Control.new()
			stage.name = "MediaConferenceStage"
			stage.custom_minimum_size = Vector2(stage_w, stage_w / 1.6)
			stage.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			stage.clip_contents = true
			row.add_child(stage)
			scene = MediaConferenceVignette.open(stage, GameState.my_club)
		row.add_child(_column)
	else:
		# A short strip of the room on a phone, so the question and the first
		# answer sit above the fold.
		if GameState.vignettes_on():
			var stage := Control.new()
			stage.name = "MediaConferenceStage"
			stage.custom_minimum_size = Vector2(0, minf(180.0, vh * 0.24))
			stage.clip_contents = true
			page.add_child(stage)
			scene = MediaConferenceVignette.open(stage, GameState.my_club)
		page.add_child(_column)
	var shown := _question(wide)
	for it in shown:
		(it as Control).visible = scene == null
	if scene != null:
		scene.ready_for_question.connect(func():
			for it in shown:
				if is_instance_valid(it):
					(it as Control).visible = true)


## Skip on the left (a word, not an arrow: it says what leaving does), the
## title in the middle.
func _bar() -> HBoxContainer:
	var h := UiKit.hbox(8)
	h.name = "MediaBar"
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_skip = UiKit.btn("Skip", UiKit.BODY)
	_top_skip.name = "MediaTopSkip"
	_top_skip.flat = true
	_top_skip.custom_minimum_size = Vector2(56, 44)
	_top_skip.pressed.connect(func(): handle_back())
	h.add_child(_top_skip)
	var t := UiKit.heading("Press conference", UiKit.TITLE)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(t)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(56, 0)
	h.add_child(pad)
	return h


## "Round 12 · v Carlton" ("" when the question does not say).
static func where_text(conf: Dictionary) -> String:
	var r := int(conf.get("round", 0))
	var opp := str(conf.get("opp", ""))
	var bits: PackedStringArray = []
	if r > Season.REGULAR_ROUNDS:
		bits.append("Finals")
	elif r > 0:
		bits.append("Round %d" % r)
	if opp != "":
		bits.append("v " + opp)
	return " · ".join(bits)


## The question and its answers; returns what the room reveals when it is
## ready.
func _question(wide: bool) -> Array:
	var prompt := UiKit.vbox(10 if wide else 6)
	prompt.name = "MediaPrompt"
	_column.add_child(prompt)
	var j := str(GameState.media_conference.get("journalist", ""))
	var jd: Dictionary = MediaConference.JOURNALISTS.get(j, {})
	# Who asks, in bold, his outlet beside it.
	var who := HFlowContainer.new()
	who.name = "MediaByline"
	who.add_theme_constant_override("h_separation", 6)
	prompt.add_child(who)
	if jd.is_empty():
		who.add_child(UiKit.lbl(str(GameState.media_conference.get("by", "Journalist")), UiKit.H2, UiKit.TEXT, true))
	else:
		var n := UiKit.lbl(str(jd.get("name", "")), UiKit.H2, UiKit.TEXT, true)
		n.name = "MediaJournalist"
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		who.add_child(n)
		var o := UiKit.lbl("· " + str(jd.get("outlet", "")), UiKit.SMALL, UiKit.MUTED)
		o.name = "MediaOutlet"
		o.autowrap_mode = TextServer.AUTOWRAP_OFF
		o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		who.add_child(o)
		# How he stands with you, and what it does to every answer (director
		# 2026-11-06): the word in bold, its effect under it. No good/bad colour.
		var v := GameState.press_standing(j)
		var sw := UiKit.lbl(OPINION % MediaConference.standing_word(v), UiKit.BODY, UiKit.TEXT, true)
		sw.name = "MediaStandingWord"
		prompt.add_child(sw)
		var effect := standing_effect_line(j, v)
		if effect != "":
			var sl := UiKit.lbl(effect, UiKit.SMALL, UiKit.TEXT)
			sl.name = "MediaStanding"
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			prompt.add_child(sl)
	var q := NameInk.label(GameState.press_question_text(), _league_names(), UiKit.H1 if wide else UiKit.H2, UiKit.TEXT, wide)
	q.name = "MediaQuestion"
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_child(q)
	# The Stats Geek reads your record (ruling 5.48): the record itself, shown.
	var record := GameState.press_record_line()
	if record != "":
		var rl := UiKit.lbl(record, UiKit.BODY if wide else UiKit.SMALL, UiKit.TEXT)
		rl.name = "MediaRecord"
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prompt.add_child(rl)
	# How long the moves last and what his personality does to their size,
	# said once here rather than under every answer (director 2026-11-07).
	var rules := UiKit.lbl(MediaConference.rules_line(j), UiKit.SMALL, UiKit.TEXT)
	rules.name = "MediaRules"
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_child(rules)
	var shown: Array = [prompt]
	var opts: Array = GameState.media_conference.get("options", [])
	for i in range(opts.size()):
		var group := UiKit.vbox(4 if wide else 3)
		group.name = "MediaAnswerGroup_%d" % i
		_column.add_child(group)
		shown.append(group)
		var b := UiKit.btn(str((opts[i] as Dictionary).get("label", "")), UiKit.H2 if wide else UiKit.BODY)
		b.name = "MediaAnswer_%d" % i
		b.custom_minimum_size = Vector2(0, 56 if wide else 48)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		NameInk.dress_button(b, _league_names())
		b.pressed.connect(_answer.bind(i))
		group.add_child(b)
		# Both ways it can land, their odds and sizes (bible §4), in the page's
		# own ink: the coach is deciding on it.
		var effect := NameInk.label(GameState.press_odds_line(i),
				_league_names(), UiKit.BODY if wide else UiKit.SMALL, UiKit.TEXT)
		effect.name = "MediaAnswerLine_%d" % i
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		group.add_child(effect)
	var skip := UiKit.btn("Skip, say nothing", UiKit.BODY)
	skip.name = "MediaSkip"
	skip.flat = not wide
	skip.custom_minimum_size = Vector2(240 if wide else 0, 44)
	if wide:
		skip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	skip.pressed.connect(func():
		GameState.skip_media_conference()
		_leave())
	_column.add_child(skip)
	shown.append(skip)
	return shown


## "Every answer to him is 5% more likely to land well." ("" when even.)
static func standing_effect_line(journalist: String, v: int) -> String:
	if v == 0:
		return ""
	return "Every answer to %s is %d%% %s likely to land well." % [
			"her" if MediaConference.is_woman(journalist) else "him",
			absi(v) * MediaConference.STANDING_ODDS, "more" if v > 0 else "less"]


## The answer lands here, in the room (ruling 3.52: result in-scene). The
## other answers go; what you said stays, as a quote, with how it landed
## under it.
func _answer(i: int) -> void:
	if _answered:
		return
	var opts: Array = GameState.media_conference.get("options", [])
	var said := str((opts[i] as Dictionary).get("label", "")) if i >= 0 and i < opts.size() else ""
	var landed := GameState.resolve_media_conference(i)
	_answered = true
	UiKit.clear(_column)
	if landed.is_empty():
		_leave()
		return
	if _top_skip != null and is_instance_valid(_top_skip):
		# Gone once answered, its space kept so the title stays centred.
		_top_skip.disabled = true
		_top_skip.modulate.a = 0.0
		_top_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var out := UiKit.vbox(8)
	out.name = "MediaOutcome"
	_column.add_child(out)
	var quote := NameInk.label("You said: “%s”" % said, _league_names(), UiKit.BODY, UiKit.TEXT)
	quote.name = "MediaSaid"
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	out.add_child(quote)
	var parts := outcome_parts(str(landed.get("line", "")))
	var head := UiKit.lbl(str(parts[0]), UiKit.H2, UiKit.TEXT, true)
	head.name = "MediaOutcomeLine"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	out.add_child(head)
	var chance := int(landed.get("chance", 0))
	if str(landed.get("landed", "a")) == "b":
		chance = 100 - chance
	var odds := UiKit.lbl("It was a %d%% chance." % chance, UiKit.BODY, UiKit.TEXT)
	odds.name = "MediaOutcomeChance"
	out.add_child(odds)
	for row in press_outcome_rows(landed, str(parts[1])):
		var l := UiKit.lbl(str(row[1]), UiKit.SMALL, UiKit.TEXT)
		l.name = str(row[0])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		out.add_child(l)
	var ok := UiKit.btn("Continue", UiKit.NAME, true)
	ok.name = "MediaOutcomeDone"
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(_leave)
	out.add_child(ok)


## "The players lifted: morale +2% across the list." -> ["The players
## lifted", "morale +2% across the list"].
static func outcome_parts(line: String) -> Array:
	var at := line.find(": ")
	if at < 0:
		return [line.trim_suffix("."), ""]
	return [line.substr(0, at), line.substr(at + 2).trim_suffix(".")]


## The lines under how it landed: the sizes, the standing change, the record's
## verdict and how long it lasts, each [node name, text].
static func press_outcome_rows(landed: Dictionary, sizes: String) -> Array:
	var rows: Array = []
	if sizes != "":
		rows.append(["MediaOutcomeSizes", sizes.replace(", ", " · ")])
	var j := str(landed.get("journalist", ""))
	var st: Array = landed.get("standing", [])
	if st.size() == 2 and int(st[0]) != int(st[1]) and MediaConference.JOURNALISTS.has(j):
		rows.append(["MediaOutcomeStanding", OPINION_MOVED % [str(MediaConference.JOURNALISTS[j]["name"]),
				MediaConference.standing_word(int(st[0])), MediaConference.standing_word(int(st[1]))]])
	var verdict := str(landed.get("verdict", ""))
	if MediaConference.RECORD_CLAUSE.has(verdict):
		rows.append(["MediaOutcomeRecord", str(MediaConference.RECORD_CLAUSE[verdict])])
	var rounds := int(landed.get("fade_rounds", 0))
	var m := int(landed.get("fade_morale", 0))
	var b := int(landed.get("fade_board", 0))
	if m > 0 and b > 0 and m != b:
		rows.append(["MediaOutcomeFade", FADE_BOTH % [m, "" if m == 1 else "s", b]])
	elif rounds > 0:
		rows.append(["MediaOutcomeFade", FADE_ONE % [rounds, "" if rounds == 1 else "s"]])
	return rows


## Back skips the question (as Skip does) or, once answered, leaves.
func handle_back() -> bool:
	if not _answered:
		GameState.skip_media_conference()
	_leave()
	return true


func _leave() -> void:
	if _embedded:
		closed.emit()
		queue_free()
		return
	if Router.can_go_back():
		Router.back()
	else:
		Router.replace("hub")


var _name_index := {}


func _league_names() -> Dictionary:
	if _name_index.is_empty() and GameState.season != null:
		_name_index = NameInk.from_lists(GameState.season.lists)
	return _name_index
