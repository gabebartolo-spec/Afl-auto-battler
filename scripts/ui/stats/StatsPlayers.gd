class_name StatsPlayers
extends RefCounted
## Season stats > Players: every player's season across the whole competition
## (StatBook), not his ratings. A phone shows one stat at a time as a
## leaderboard: rank, guernsey, full name, one big figure (visual audit
## Phase 2). A wide screen adds the table, its columns in football groups with
## words in the headings; tap a heading to sort (again to reverse). Totals or
## per game; filters in a sheet (club, position, age, role, trait, games). Tap
## a player for his season and career.

## Column groups: [key, label, [[stat, heading, full name], ...]]. A stat is
## a StatBook key, a StatBook rate ("accuracy", ...) or "kh" (kicks to each
## handball).
const GROUPS := [
	["overall", "Overall", [["rating", "PR", "player rating"]]],
	["disposals", "Disposals", [["disposals", "D", "disposals"], ["kicks", "K", "kicks"],
			["handballs", "H", "handballs"], ["efficiency", "DE%", "disposal efficiency"]]],
	["ground", "Ground gained", [["metres_gained", "MG", "metres gained"],
			["running_bounces", "RB", "running bounces"], ["inside50", "I50", "inside 50s"],
			["rebounds", "R50", "rebound 50s"]]],
	["contest", "Contested ball", [["contested_possessions", "CP", "contested possessions"],
			["uncontested_possessions", "UP", "uncontested possessions"],
			["cp_rate", "CP%", "contested possession rate"], ["ground_ball_gets", "GBG", "ground-ball gets"],
			["clearances", "CL", "clearances"], ["cba", "CBA", "centre bounce attendances"],
			["dont_argues", "DA", "don't argues"], ["evaded_tackles", "ET", "evaded tackles"]]],
	["marking", "Marking", [["marks", "M", "marks"], ["contested_marks", "CM", "contested marks"],
			["intercept_marks", "IM", "intercept marks"]]],
	["goals", "Goals", [["goals", "G", "goals"], ["behinds", "B", "behinds"],
			["shots", "SH", "shots at goal"], ["accuracy", "ACC%", "goalkicking accuracy"],
			["goal_assists", "GA", "goal assists"]]],
	["setshots", "Set shots and open play", [["set_shots", "SS", "set shots"], ["set_goals", "SG", "set-shot goals"],
			["set_accuracy", "SS%", "set-shot accuracy"], ["open_accuracy", "OP%", "open-play accuracy"],
			["score_involvements", "SI", "score involvements"]]],
	["ruck", "Ruck", [["hitouts", "HO", "hit-outs"], ["ruck_contests", "RC", "ruck contests"],
			["hitout_win", "HO%", "hit-out win rate"], ["hitouts_adv", "HA", "hit-outs to advantage"]]],
	["defence", "Defence", [["intercepts", "INT", "intercepts"], ["tackles", "T", "tackles"],
			["one_percenters", "1%", "one percenters"], ["spoils", "SP", "spoils"],
			["pressure_acts", "PA", "pressure acts"]]],
	["discipline", "Discipline", [["frees_for", "FF", "frees for"], ["frees_against", "FA", "frees against"],
			["clangers", "CG", "clangers"]]],
]
## A rate ranks only players with enough under it, scaled to the rounds
## played: so many a round (shots, ruck contests...), at least one.
const QUALIFY := {
	"accuracy": ["shots", 1.0, "shots"], "set_accuracy": ["set_shots", 0.5, "set shots"],
	"open_accuracy": ["open_shots", 0.5, "open-play shots"],
	"hitout_win": ["ruck_contests", 6.0, "ruck contests"], "cp_rate": ["possessions", 6.0, "possessions"],
	"efficiency": ["disposals", 6.0, "disposals"], "kh": ["handballs", 2.0, "handballs"],
}
const PAGE := 50
const POSITIONS := [["", "All positions"], ["DEF", "Defenders"], ["MID", "Midfielders"],
		["RUCK", "Rucks"], ["FWD", "Forwards"]]
const AGES := [["", "All ages"], ["u21", "21 and under"], ["22_25", "22 to 25"],
		["26_29", "26 to 29"], ["30", "30 and over"]]
const GAMES := [["1", "Played a game"], ["5", "5 games or more"], ["10", "10 games or more"],
		["0", "Every listed player"]]

static var _group := "disposals"
static var _per_game := false
static var _sort := "disposals"
static var _desc := true
static var _shown := PAGE
static var _filters := {"club": "", "pos": "", "age": "", "role": "", "trait": "", "games": "1"}


static func build(host: Control) -> Control:
	var v := UiKit.vbox(8)
	v.name = "StatsPlayers"
	var wide: bool = host.call("wide")
	if not GameState.season_stats.is_empty() and int(GameState.season_stats_from) > 0:
		var note := UiKit.lbl("Counted from round %d: this career's earlier rounds were played before season records were kept."
				% (int(GameState.season_stats_from) + 1), UiKit.SECONDARY, UiKit.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(note)
	var controls := _controls(host, wide)
	v.add_child(controls)
	var rows := _rows()
	if rows.is_empty():
		var none := UiKit.lbl("No one has played a game yet." if GameState.season_stats.is_empty()
				else "No players match these filters.", UiKit.BODY, UiKit.MUTED)
		none.name = "PlayersEmpty"
		v.add_child(none)
		return v
	_sort_rows(rows)
	# A phone shows one stat at a time as a leaderboard (visual audit Phase 2,
	# guide 4.5); a wide screen adds the table, with words in its headings.
	if wide:
		var table := _table(host, rows, _columns(host, wide), wide)
		v.add_child(table)
		# The controls start where the table starts.
		controls.custom_minimum_size.x = table.custom_minimum_size.x
		controls.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		v.add_child(_board(host, rows))
	_qualify_note(v)
	return v


# ---------------------------------------------------------------------------
# Controls: the stat, totals or per game, filters
# ---------------------------------------------------------------------------
static func _controls(host: Control, wide: bool) -> Control:
	var v := UiKit.vbox(6)
	var row := UiKit.hbox(6)
	row.name = "PlayersControls"
	v.add_child(row)
	# The stat, chosen by its name. The list is a sheet, not a pop-up menu:
	# forty stats are taller than a phone, and a pop-up menu does not follow
	# a finger (director's phone playtest, 2026-10-10).
	var pick := UiKit.btn(_cap(_name_of(_sort)), 14)
	pick.name = "StatPick"
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.clip_text = true
	pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pick.custom_minimum_size = Vector2(280 if wide else 0, 44)
	pick.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if wide else Control.SIZE_EXPAND_FILL
	pick.pressed.connect(func(): open_stats(host))
	row.add_child(pick)
	# Totals or per game: one line of words, the current one underlined.
	var mode := UiKit.segmented("StatMode", [["total", "Totals"], ["per_game", "Per game"]],
			"per_game" if _per_game else "total", func(key: String):
				_per_game = key == "per_game"
				host.call("refresh"))
	row.add_child(mode)
	var active := _active_text()
	var fb := UiKit.btn("Filters" if active == "" else "Filters (%d)" % _active_count(), UiKit.SECONDARY)
	fb.name = "FiltersToggle"
	fb.custom_minimum_size = Vector2(96, 44)
	fb.pressed.connect(func(): open_filters(host))
	row.add_child(fb)
	if active != "":
		var h := UiKit.hbox(8)
		var t := UiKit.lbl("Showing " + active, UiKit.SECONDARY, UiKit.TEXT)
		t.name = "ActiveFilters"
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		var reset := UiKit.btn("Reset", UiKit.SECONDARY)
		reset.name = "FiltersReset"
		reset.flat = true
		reset.custom_minimum_size = Vector2(72, 44)
		reset.pressed.connect(func():
			reset_filters()
			host.call("refresh"))
		h.add_child(reset)
		v.add_child(h)
	return v


## Every stat as a sheet over the list, each group's stats under its name;
## the list scrolls under a finger and a tap on a stat ranks by it.
static func open_stats(host: Control) -> void:
	var box := UiKit.modal_box(host, 520.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "StatSheet"
	UiKit.close_on_outside_tap(box)
	host.call("open_sheet", overlay)
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Rank players by", UiKit.TITLE))
	for g in GROUPS:
		var head := UiKit.lbl(str(g[1]), UiKit.SECONDARY, UiKit.MUTED)
		head.name = "StatGroup_" + str(g[0])
		v.add_child(head)
		for c in g[2]:
			var key := str(c[0])
			var b := UiKit.btn(_cap(str(c[2])), UiKit.NAME)
			b.name = "Stat_" + key
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 48)
			UiKit.paint_choice(b, key == _sort)
			b.pressed.connect(func():
				pick_stat(key)
				host.call("close_sheet")
				host.call("refresh"))
			v.add_child(b)
	var done := UiKit.btn("Close", UiKit.NAME)
	done.name = "StatSheetClose"
	done.custom_minimum_size = Vector2(0, 48)
	done.pressed.connect(func(): host.call("close_sheet"))
	box["footer"].add_child(done)


## The filters as a sheet over the list: one picker a line, Reset and Done.
static func open_filters(host: Control) -> void:
	var box := UiKit.modal_box(host, 520.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "FiltersSheet"
	UiKit.close_on_outside_tap(box)
	host.call("open_sheet", overlay)
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Filters", UiKit.TITLE))
	var list := _filter_row(host)
	v.add_child(list)
	var reset := UiKit.btn("Reset", UiKit.NAME)
	reset.name = "FiltersSheetReset"
	reset.custom_minimum_size = Vector2(0, 48)
	reset.pressed.connect(func():
		reset_filters()
		host.call("close_sheet")
		host.call("refresh"))
	box["footer"].add_child(reset)
	var done := UiKit.btn("Done", UiKit.NAME, true)
	done.name = "FiltersDone"
	done.custom_minimum_size = Vector2(0, 48)
	done.pressed.connect(func(): host.call("close_sheet"))
	box["footer"].add_child(done)


## Rank by a stat: it leads, most first, and its group is the table's.
static func pick_stat(key: String) -> void:
	for g in GROUPS:
		for c in g[2]:
			if str(c[0]) == key:
				_group = str(g[0])
				_sort = key
				_desc = true
				_shown = PAGE


# ---------------------------------------------------------------------------
# The leaderboard (a phone): one stat, ranked
# ---------------------------------------------------------------------------
static func _board(host: Control, list: Array) -> Control:
	var v := UiKit.vbox(0)
	v.name = "PlayersBoard"
	for i in range(mini(_shown, list.size())):
		if i > 0:
			v.add_child(UiKit.rule())
		v.add_child(_board_row(host, list[i], i + 1))
	if list.size() > _shown:
		var more := UiKit.btn("Show %d more of %d" % [mini(PAGE, list.size() - _shown), list.size()], UiKit.SECONDARY)
		more.name = "PlayersMore"
		more.custom_minimum_size = Vector2(0, 44)
		more.pressed.connect(func():
			_shown += PAGE
			host.call("refresh"))
		v.add_child(UiKit.spacer(8))
		v.add_child(more)
	return v


## One man: rank, guernsey, his full name with his club and games under it,
## and the stat big at the right with the other way of counting it beneath.
static func _board_row(host: Control, row: Dictionary, rank: int) -> Control:
	var b := Button.new()
	b.name = "PlayerRow_" + str(row["id"])
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	_editorial(b, str(row["club"]) == GameState.my_club)
	b.pressed.connect(func(): open_player(host, str(row["id"])))
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 8)
	for side in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 6)
	b.add_child(m)
	var h := UiKit.hbox(10)
	m.add_child(h)
	var club := str(row["club"])
	var mine := club == GameState.my_club
	var pos := UiKit.line(str(rank), UiKit.SECONDARY, UiKit.MUTED)
	pos.name = "Rank"
	pos.custom_minimum_size.x = 26
	pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pos)
	if club != "":
		var marker := UiKit.club_marker(club, 22.0)
		marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(marker)
	var who := UiKit.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(who)
	who.add_child(UiKit.name_label(str(row["name"]), UiKit.NAME, UiKit.TEXT, true))
	var games := int(row["games"])
	var meta := "%s · %d %s" % [club, games, "game" if games == 1 else "games"]
	if bool(row["moved"]):
		meta += " · two clubs"
	var sub := UiKit.line(meta, UiKit.SECONDARY, UiKit.MUTED)
	sub.name = "Meta"
	who.add_child(sub)
	var key := _sort
	var v := value(row, key, _per_game)
	var fig_box := UiKit.vbox(0)
	fig_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(fig_box)
	var quiet: bool = v <= 0.0 or not qualifies(row, key)
	var fig := UiKit.figure(fmt(v, key, _per_game) + ("%" if StatBook.RATES.has(key) and v >= 0.0 else ""),
			UiKit.NUMBER, UiKit.MUTED if quiet else (UiKit.club_vivid(club) if mine else UiKit.TEXT))
	fig.name = "Cell_" + key
	fig.custom_minimum_size.x = 64
	fig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fig_box.add_child(fig)
	var under := _under(row, key)
	if under != "":
		var u := UiKit.line(under, UiKit.SECONDARY, UiKit.MUTED)
		u.name = "Under"
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fig_box.add_child(u)
	for n in m.find_children("*", "Control", true, false):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.custom_minimum_size.y = maxf(56.0, m.get_combined_minimum_size().y)
	return b


## The small figure under the big one: a count the other way (a game, or in
## all), a rate what it is out of ("of 41 shots"); nothing for kicks to handballs.
static func _under(row: Dictionary, key: String) -> String:
	if key == "kh" or key == "games":
		return ""
	if StatBook.RATES.has(key):
		if not QUALIFY.has(key):
			return ""
		var n := int((row["s"] as Dictionary).get(str(QUALIFY[key][0]), 0.0))
		return "of %d %s" % [n, str(QUALIFY[key][2])] if n > 0 else ""
	var other := value(row, key, not _per_game)
	if other < 0.0:
		return ""
	return ("%s in all" % fmt(other, key, false)) if _per_game else ("%s a game" % fmt(other, key, true))


## How a rate ranks, under the list.
static func _qualify_note(v: Control) -> void:
	if QUALIFY.has(_sort):
		var q := UiKit.lbl("Ranked by %s among players with at least %d %s so far." % [_name_of(_sort),
				int(qualify_min(_sort)), str(QUALIFY[_sort][2])], UiKit.SECONDARY, UiKit.MUTED)
		q.name = "PlayersQualify"
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(q)


## Show a group: it leads the columns and sorts by its first stat.
static func pick_group(key: String) -> void:
	for g in GROUPS:
		if str(g[0]) == key:
			_group = key
			_sort = str(g[2][0][0])
			_desc = true
			_shown = PAGE


static func _filter_row(host: Control) -> Control:
	var flow := UiKit.vbox(8)
	flow.name = "FilterRow"
	var clubs := [["", "All clubs"]]
	for code in GameState.season.lists:
		clubs.append([str(code), GameDB.club_name(str(code))])
	var roles := [["", "All roles"]]
	var traits := [["", "All traits"]]
	var seen_roles := {}
	var seen_traits := {}
	for p in _index().values():
		var r := Roles.label(p)
		if r != "" and not seen_roles.has(r):
			seen_roles[r] = true
			roles.append([r, r])
		for t in Traits.of(p):
			if not seen_traits.has(str(t)):
				seen_traits[str(t)] = true
				traits.append([str(t), Traits.label(str(t))])
	var by_label := func(a, b):
		if str(a[0]) == "" or str(b[0]) == "":
			return str(a[0]) == "" and str(b[0]) != ""
		return str(a[1]) < str(b[1])
	roles.sort_custom(by_label)
	traits.sort_custom(by_label)
	for f in [["club", clubs], ["pos", POSITIONS], ["age", AGES], ["role", roles], ["trait", traits], ["games", GAMES]]:
		var d := _dropdown(host, str(f[0]), f[1])
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_child(d)
	return flow


static func _dropdown(host: Control, key: String, options: Array) -> OptionButton:
	var o := OptionButton.new()
	o.name = "Filter_" + key
	UiKit.style_button(o, 14)
	o.custom_minimum_size = Vector2(150, 44)
	o.clip_text = true
	o.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Sized by the row, not by its longest option (Greater Western Sydney).
	o.fit_to_longest_item = false
	for i in range(options.size()):
		o.add_item(str(options[i][1]), i)
		if str(options[i][0]) == str(_filters[key]):
			o.select(i)
	o.item_selected.connect(func(i: int):
		set_filter(key, str(options[i][0]))
		host.call("refresh"))
	return o


static func set_filter(key: String, value: String) -> void:
	_filters[key] = value
	_shown = PAGE


static func reset_filters() -> void:
	_filters = {"club": "", "pos": "", "age": "", "role": "", "trait": "", "games": "1"}
	_shown = PAGE


## Back to the opening view: Disposals, totals, sorted by disposals, no
## filters (a new visit, a test).
static func reset_view() -> void:
	pick_group("disposals")
	_per_game = false
	reset_filters()


## The filters in force, in words ("Magpies · Midfielders · 21 and under"),
## or "" with none beyond the default.
static func _active_text() -> String:
	var bits: PackedStringArray = []
	if _filters["club"] != "":
		bits.append(GameDB.club_short(str(_filters["club"])))
	for f in [["pos", POSITIONS], ["age", AGES]]:
		for o in f[1]:
			if str(o[0]) != "" and str(o[0]) == str(_filters[f[0]]):
				bits.append(str(o[1]))
	if _filters["role"] != "":
		bits.append(str(_filters["role"]))
	if _filters["trait"] != "":
		bits.append(Traits.label(str(_filters["trait"])))
	if _filters["games"] != "1":
		for o in GAMES:
			if str(o[0]) == str(_filters["games"]):
				bits.append(str(o[1]).to_lower())
	return " · ".join(bits)


static func _active_count() -> int:
	var n := 0
	for k in _filters:
		if str(_filters[k]) != ("1" if k == "games" else ""):
			n += 1
	return n


# ---------------------------------------------------------------------------
# The rows
# ---------------------------------------------------------------------------
## Every listed player (and free agents), by id.
static func _index() -> Dictionary:
	var out := {}
	if GameState.season != null:
		for code in GameState.season.lists:
			for p in GameState.season.lists[code]:
				out[str(p["id"])] = p
	for p in GameState.free_agents:
		if p is Dictionary and not out.has(str(p.get("id", ""))):
			out[str(p["id"])] = p
	return out


## The players on show, filtered: everyone in the season book (and, with
## "Every listed player", the listed ones yet to play).
static func rows() -> Array:
	return _rows()


static func _rows() -> Array:
	var index := _index()
	var book: Dictionary = GameState.season_stats
	var min_games := int(_filters["games"])
	var ids := {}
	for id in book:
		ids[id] = true
	if min_games == 0 and GameState.season != null:
		for code in GameState.season.lists:
			for p in GameState.season.lists[code]:
				ids[str(p["id"])] = true
	var out := []
	for id in ids:
		var row: Dictionary = book.get(id, {})
		var p: Dictionary = index.get(id, {})
		var games := int(row.get("games", 0))
		if games < min_games:
			continue
		var club := str(p.get("club", ""))
		if club == "":
			club = str(row.get("club", ""))
		if _filters["club"] != "" and club != str(_filters["club"]):
			continue
		if _filters["pos"] != "" and str(p.get("role", "")) != str(_filters["pos"]):
			continue
		if _filters["age"] != "" and (p.is_empty() or not _age_ok(float(p.get("age", 0.0)), str(_filters["age"]))):
			continue
		if _filters["role"] != "" and (p.is_empty() or Roles.label(p) != str(_filters["role"])):
			continue
		if _filters["trait"] != "" and (p.is_empty() or not Traits.of(p).has(str(_filters["trait"]))):
			continue
		var name := GameDB.player_display_name(p) if not p.is_empty() \
				else GameDB.player_display_name_by_id(str(id), "Player")
		var s: Dictionary = (row.get("s", {}) as Dictionary).duplicate()
		s["possessions"] = float(s.get("contested_possessions", 0.0)) + float(s.get("uncontested_possessions", 0.0))
		s["open_shots"] = float(s.get("shots", 0.0)) - float(s.get("set_shots", 0.0))
		s["rating"] = season_rating(s)
		out.append({"id": str(id), "p": p, "name": name, "club": club, "games": games, "s": s,
				"moved": (row.get("clubs", {}) as Dictionary).size() > 1})
	return out


static func _age_ok(age: float, band: String) -> bool:
	var a := int(age)
	match band:
		"u21":
			return a <= 21
		"22_25":
			return a >= 22 and a <= 25
		"26_29":
			return a >= 26 and a <= 29
		"30":
			return a >= 30
	return true


## A season of Player Rating: the match rating's own points (MatchNotes)
## over his season's stats. In all it is his rating points for the year; a
## game, his average rating.
static func season_rating(s: Dictionary) -> float:
	var total := 0.0
	for k in MatchNotes.RATING_POINTS:
		total += float(MatchNotes.RATING_POINTS[k]) * float(s.get(k, 0.0))
	return maxf(0.0, total)


## A row's value for a stat: a count (total or per game), a rate, or -1 for
## nothing to show (no games; nothing under the rate).
static func value(row: Dictionary, key: String, per_game: bool) -> float:
	var s: Dictionary = row["s"]
	if key == "games":
		return float(row["games"])
	if StatBook.RATES.has(key):
		return StatBook.rate(s, key)
	if key == "kh":
		return StatBook.kick_ratio(s)
	var t := float(s.get(key, 0.0))
	if per_game:
		var g := int(row["games"])
		return t / float(g) if g > 0 else -1.0
	return t


## Whether a row has enough under a rate to be ranked by it.
static func qualifies(row: Dictionary, key: String) -> bool:
	if not QUALIFY.has(key):
		return true
	var q: Array = QUALIFY[key]
	return float((row["s"] as Dictionary).get(q[0], 0.0)) >= qualify_min(key)


static func qualify_min(key: String) -> float:
	var rounds := 1
	if GameState.season != null:
		rounds = maxi(1, GameState.season.round_index - int(GameState.season_stats_from))
	return maxf(1.0, ceilf(float(QUALIFY[key][1]) * float(rounds)))


static func _sort_rows(list: Array) -> void:
	var key := _sort
	var per := _per_game
	var desc := _desc
	list.sort_custom(func(a, b):
		var qa := qualifies(a, key)
		var qb := qualifies(b, key)
		if qa != qb:
			return qa
		var x := value(a, key, per)
		var y := value(b, key, per)
		if x != y:
			return x > y if desc else x < y
		if int(a["games"]) != int(b["games"]):
			return int(a["games"]) > int(b["games"])
		return str(a["name"]) < str(b["name"]))


## The rows as sorted now (for tests).
static func sorted_rows() -> Array:
	var list := _rows()
	_sort_rows(list)
	return list


# ---------------------------------------------------------------------------
# The table
# ---------------------------------------------------------------------------
## The columns on show: the chosen group, then (on a wide screen) the groups
## after it, as many whole groups as the width holds.
static func _columns(host: Control, wide: bool) -> Array:
	var start := 0
	for i in range(GROUPS.size()):
		if str(GROUPS[i][0]) == _group:
			start = i
	var cols := []
	var room: float = float(host.call("content_width")) - (480.0 if wide else 190.0)
	var w := _col_w(wide)
	for j in range(GROUPS.size()):
		var g: Array = GROUPS[(start + j) % GROUPS.size()]
		var need := float((g[2] as Array).size()) * w + _group_gap(wide)
		if j > 0 and (not wide or need > room):
			break
		for c in g[2]:
			cols.append([str(c[0]), str(c[1]), str(c[2]), str(g[1])])
		room -= need
	return cols


static func _col_w(wide: bool) -> float:
	return 92.0 if wide else 34.0


static func _club_w(wide: bool) -> float:
	return 120.0 if wide else 38.0


static func _games_w(wide: bool) -> float:
	return 56.0 if wide else 28.0


## A name as the table shows it: in full on a wide screen, "N. Daicos" on a
## phone so the surname is never cut.
static func _table_name(name: String, wide: bool) -> String:
	if wide:
		return name
	var at := name.find(" ")
	return name if at <= 0 else name.substr(0, 1) + ". " + name.substr(at + 1)


## The look (director, 2026-10-07: "functional, but ugly"): rows banded
## faintly instead of ruled, numbers right-aligned under right-aligned
## headings, the rank in its own muted column, each group's name over its
## columns with a gap between groups, and zeros muted so what a player did
## stands out.
## A row is a tap target: thumb-sized (40 px) on a phone, 32 px with a
## pointer on a wide screen.
static func _row_h(wide: bool) -> float:
	return 32.0 if wide else 40.0


## Widths that shrink on a phone, so a surname still fits beside one group.
static func _rank_w(wide: bool) -> float:
	return 30.0 if wide else 22.0


static func _rank_gap(wide: bool) -> float:
	return 10.0 if wide else 6.0


static func _group_gap(wide: bool) -> float:
	return 14.0 if wide else 6.0


static func _tail(wide: bool) -> float:
	return 8.0 if wide else 4.0


static func _table(host: Control, list: Array, cols: Array, wide: bool) -> Control:
	var v := UiKit.vbox(0)
	v.name = "PlayersTable"
	var w := _col_w(wide)
	var name_w := _name_w(list)
	var total := _rank_w(wide) + _rank_gap(wide) + name_w + _club_w(wide) + 96.0 + _games_w(wide) + _tail(wide)
	var seen := ""
	for c in cols:
		if str(c[3]) != seen:
			total += _group_gap(wide)
			seen = str(c[3])
		total += w
	v.custom_minimum_size.x = total
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Each group's name over its columns, a rule under it spanning just them, so
	# the name reads as the group's (alone, centred, "Disposals" sat over Kicks).
	var groups := UiKit.hbox(0)
	groups.name = "PlayersGroups"
	groups.add_child(_fixed(_rank_w(wide) + _rank_gap(wide)))
	groups.add_child(_fixed(name_w))
	groups.add_child(_fixed(_club_w(wide) + (96.0 if wide else 0.0) + _games_w(wide)))
	var at := 0
	while at < cols.size():
		var g := str(cols[at][3])
		var n := 0
		while at + n < cols.size() and str(cols[at + n][3]) == g:
			n += 1
		groups.add_child(_fixed(_group_gap(wide)))
		var span := UiKit.vbox(3)
		span.name = "PlayersGroup_" + g
		span.custom_minimum_size.x = w * n
		var gl := UiKit.ellipsis(g, UiKit.SMALL, UiKit.MUTED, true)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		span.add_child(gl)
		span.add_child(UiKit.rule())
		groups.add_child(span)
		at += n
	groups.add_child(_fixed(_tail(wide)))
	v.add_child(groups)
	var head := UiKit.hbox(0)
	head.name = "PlayersHeader"
	head.custom_minimum_size.y = 44
	head.add_child(_cell("#", _rank_w(wide), UiKit.MUTED, UiKit.SMALL, false, HORIZONTAL_ALIGNMENT_RIGHT))
	head.add_child(_fixed(_rank_gap(wide)))
	var who := UiKit.line("Player", UiKit.SMALL, UiKit.MUTED)
	who.custom_minimum_size.x = name_w
	head.add_child(who)
	head.add_child(_cell("Club", _club_w(wide), UiKit.MUTED, UiKit.SMALL, false, HORIZONTAL_ALIGNMENT_LEFT))
	if wide:
		head.add_child(_cell("Pos", 56.0, UiKit.MUTED, UiKit.SMALL, false, HORIZONTAL_ALIGNMENT_LEFT))
		head.add_child(_cell("Age", 40.0, UiKit.MUTED, UiKit.SMALL, false, HORIZONTAL_ALIGNMENT_RIGHT))
	head.add_child(_sort_button(host, "games", "Games", "games played", _games_w(wide)))
	var last_group := ""
	for c in cols:
		if str(c[3]) != last_group:
			head.add_child(_fixed(_group_gap(wide)))
			last_group = str(c[3])
		head.add_child(_sort_button(host, str(c[0]), _cap(str(c[2])), str(c[2]), w))
	head.add_child(_fixed(_tail(wide)))
	for n in head.get_children():
		(n as Control).size_flags_vertical = Control.SIZE_SHRINK_END
	v.add_child(head)
	v.add_child(UiKit.rule())
	for i in range(mini(_shown, list.size())):
		v.add_child(_row(host, list[i], i + 1, cols, wide, name_w))
	if list.size() > _shown:
		var more := UiKit.btn("Show %d more of %d" % [mini(PAGE, list.size() - _shown), list.size()], 14)
		more.name = "PlayersMore"
		more.custom_minimum_size = Vector2(0, 44)
		more.pressed.connect(func():
			_shown += PAGE
			host.call("refresh"))
		v.add_child(UiKit.spacer(8))
		v.add_child(more)
	return v


## The name column: the longest name on show, plus a gutter.
static func _name_w(list: Array) -> float:
	var widest := 120.0
	for i in range(mini(_shown, list.size())):
		var n := str(list[i]["name"])
		widest = maxf(widest, UiKit.BOLD.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SMALL).x)
	return ceilf(widest) + 24.0


static func _fixed(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _name_of(key: String) -> String:
	for g in GROUPS:
		for c in g[2]:
			if str(c[0]) == key:
				return str(c[2])
	return key


static func _sort_button(host: Control, key: String, text: String, full: String, w: float) -> Button:
	var b := Button.new()
	b.name = "Sort_" + key
	b.text = text + ("" if key != _sort else (" ↓" if _desc else " ↑"))
	b.flat = true
	b.custom_minimum_size = Vector2(w, 0)
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# A heading in words wraps to a second line rather than being cut, and
	# sits on the row's one baseline (no padding, bottom-aligned).
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", UiKit.SMALL)
	b.add_theme_color_override("font_color", UiKit.TEXT if key == _sort else UiKit.MUTED)
	# The same face as the plain headings beside it; the sort key in bold.
	b.add_theme_font_override("font", UiKit.BOLD if key == _sort else UiKit.FONT)
	b.tooltip_text = "Sort by %s" % full
	b.pressed.connect(func():
		sort_by(key)
		host.call("refresh"))
	return b


## Sort by a stat: most first; the same stat again reverses it.
static func sort_by(key: String) -> void:
	if _sort == key:
		_desc = not _desc
	else:
		_sort = key
		_desc = true


## A leaderboard row is editorial (guide 3, 4.2): no surface of its own, a
## rule between rows; your club's row in your colour; a pointer lifts it a shade.
static func _editorial(b: Button, mine: bool) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0, 0, 0, 0)
	if mine:
		base.bg_color = Color(UiKit.club_vivid(GameState.my_club), 0.22)
		base.border_width_left = 4
		base.border_color = UiKit.club_vivid(GameState.my_club)
	var over := StyleBoxFlat.new()
	over.bg_color = Color(UiKit.TEXT, 0.05)
	for sb in [base, over]:
		(sb as StyleBoxFlat).set_content_margin_all(0)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", over)
	b.add_theme_stylebox_override("pressed", over)
	b.add_theme_stylebox_override("hover_pressed", over)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## A table row's band: every other row a faint flat surface; a pointer over any
## row lifts it a shade.
static func _band(b: Button, odd: bool) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = UiKit.PANEL if odd else Color(0, 0, 0, 0)
	var over := StyleBoxFlat.new()
	over.bg_color = UiKit.PANEL_ALT
	for sb in [base, over]:
		(sb as StyleBoxFlat).set_content_margin_all(0)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", over)
	b.add_theme_stylebox_override("pressed", over)
	b.add_theme_stylebox_override("hover_pressed", over)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _row(host: Control, row: Dictionary, rank: int, cols: Array, wide: bool, name_w: float) -> Control:
	var b := Button.new()
	b.name = "PlayerRow_" + str(row["id"])
	b.custom_minimum_size.y = _row_h(wide)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	_band(b, rank % 2 == 0)
	b.pressed.connect(func(): open_player(host, str(row["id"])))
	var h := UiKit.hbox(0)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(h)
	var mine := str(row["club"]) == GameState.my_club
	h.add_child(_cell(str(rank), _rank_w(wide), UiKit.MUTED, UiKit.SMALL, false, HORIZONTAL_ALIGNMENT_RIGHT))
	h.add_child(_fixed(_rank_gap(wide)))
	var who := UiKit.line(_table_name(str(row["name"]), wide), UiKit.SMALL, UiKit.TEXT, mine)
	who.custom_minimum_size.x = name_w
	h.add_child(who)
	var club_text := (GameDB.club_short(str(row["club"])) if wide else str(row["club"])) + ("*" if bool(row["moved"]) else "")
	h.add_child(_cell(club_text, _club_w(wide), UiKit.MUTED, UiKit.SMALL, false, HORIZONTAL_ALIGNMENT_LEFT))
	if wide:
		var p: Dictionary = row["p"]
		h.add_child(_cell(str(p.get("role", "")), 56.0, UiKit.MUTED, UiKit.SMALL, false, HORIZONTAL_ALIGNMENT_LEFT))
		h.add_child(_cell(str(int(float(p.get("age", 0.0)))) if not p.is_empty() else "", 40.0, UiKit.MUTED,
				UiKit.SMALL, false, HORIZONTAL_ALIGNMENT_RIGHT))
	h.add_child(_cell(str(int(row["games"])), _games_w(wide), UiKit.MUTED, UiKit.SMALL, false, HORIZONTAL_ALIGNMENT_RIGHT))
	var w := _col_w(wide)
	var last_group := ""
	for c in cols:
		if str(c[3]) != last_group:
			h.add_child(_fixed(_group_gap(wide)))
			last_group = str(c[3])
		var key := str(c[0])
		var v := value(row, key, _per_game)
		var shown := fmt(v, key, _per_game)
		# What he did stands out: zeros, nothing to show and rates without
		# enough under them are muted.
		var quiet: bool = v <= 0.0 or not qualifies(row, key)
		var cell := _cell(shown, w, UiKit.MUTED if quiet else UiKit.TEXT, UiKit.SMALL, key == _sort,
				HORIZONTAL_ALIGNMENT_RIGHT)
		cell.name = "Cell_" + key
		h.add_child(cell)
	h.add_child(_fixed(_tail(wide)))
	for n in h.find_children("*", "Control", true, false):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## A value as shown: a rate as a whole percentage, kicks to handballs to one
## place, a per-game count to one place, a total whole; "–" for nothing.
static func fmt(v: float, key: String, per_game: bool) -> String:
	if v < 0.0:
		return "–"
	if StatBook.RATES.has(key):
		return "%d" % int(round(v * 100.0))
	if key == "kh" or (per_game and key != "games"):
		return "%.1f" % v
	return str(int(round(v)))


static func _cell(text: String, w: float, col: Color, fs: int, bold := false,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := UiKit.line(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = align
	l.clip_text = true
	return l


# ---------------------------------------------------------------------------
# A player's season and career
# ---------------------------------------------------------------------------
## His season so far and his career, by season: the numbers he has put up.
## His profile (ratings, traits) is a tap from here.
static func open_player(host: Control, id: String) -> void:
	var p: Dictionary = _index().get(id, {})
	var row: Dictionary = GameState.season_stats.get(id, {})
	var box := UiKit.modal_box(host, 760.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "PlayerStatsSheet"
	UiKit.close_on_outside_tap(box)
	host.call("open_sheet", overlay)
	var v: VBoxContainer = box["body"]
	var name := GameDB.player_display_name(p) if not p.is_empty() else GameDB.player_display_name_by_id(id, "Player")
	v.add_child(UiKit.lbl(name, UiKit.H1, UiKit.TEXT, true))
	if not p.is_empty():
		var who: PackedStringArray = [GameDB.club_name(str(p.get("club", row.get("club", ""))))]
		var r := Roles.label(p)
		if r != "":
			who.append(r)
		if float(p.get("age", 0.0)) > 0.0:
			who.append("%d years old" % int(p["age"]))
		v.add_child(UiKit.lbl(" · ".join(who), UiKit.SMALL, UiKit.MUTED))
	# This season.
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.section("This season"))
	var games := int(row.get("games", 0))
	if games <= 0:
		v.add_child(UiKit.lbl("Yet to play a game this season.", UiKit.BODY, UiKit.MUTED))
	else:
		var clubs: Dictionary = row.get("clubs", {})
		var head := "%d %s" % [games, "game" if games == 1 else "games"]
		if clubs.size() > 1:
			var parts: PackedStringArray = []
			for c in clubs:
				parts.append("%d for %s" % [int(clubs[c]), GameDB.club_short(str(c))])
			head += " (" + ", ".join(parts) + ")"
		v.add_child(UiKit.lbl(head, UiKit.BODY, UiKit.TEXT, true))
		v.add_child(_season_grid(row, host.call("wide")))
	# His career, season by season.
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.section("Career"))
	v.add_child(_career(p))
	if not p.is_empty():
		var prof := UiKit.btn("Profile", UiKit.NAME)
		prof.name = "PlayerStatsProfile"
		prof.custom_minimum_size = Vector2(0, 48)
		prof.pressed.connect(func():
			host.call("close_sheet")
			var sheet := PlayerSheet.open(host, p, Callable(), [])
			host.call("open_sheet", sheet))
		box["footer"].add_child(prof)
	var close := UiKit.btn("Close", UiKit.NAME, true)
	close.name = "PlayerStatsClose"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(func(): host.call("close_sheet"))
	box["footer"].add_child(close)


## Every recorded number he has this season, by group: total, per game.
static func _season_grid(row: Dictionary, wide: bool) -> Control:
	var s: Dictionary = (row.get("s", {}) as Dictionary).duplicate()
	s["possessions"] = float(s.get("contested_possessions", 0.0)) + float(s.get("uncontested_possessions", 0.0))
	s["open_shots"] = float(s.get("shots", 0.0)) - float(s.get("set_shots", 0.0))
	s["rating"] = season_rating(s)
	var r := {"id": "", "games": int(row.get("games", 0)), "s": s}
	var grid := GridContainer.new()
	grid.name = "PlayerSeasonGrid"
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	for g in GROUPS:
		var box := UiKit.vbox(1)
		box.custom_minimum_size.x = 320 if wide else 0
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(UiKit.lbl(str(g[1]), UiKit.SMALL, UiKit.MUTED, true))
		var any := false
		for c in g[2]:
			var key := str(c[0])
			var t := value(r, key, false)
			# A count he has none of, or a rate with nothing under it, is left out.
			if t < 0.0 or (t == 0.0 and not StatBook.RATES.has(key) and key != "kh"):
				continue
			any = true
			var h := UiKit.hbox(6)
			var lab := UiKit.ellipsis(_cap(str(c[2])), UiKit.SMALL, UiKit.TEXT)
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(lab)
			h.add_child(_cell(fmt(t, key, false) + ("%" if StatBook.RATES.has(key) else ""), 56.0, UiKit.TEXT, UiKit.SMALL, true))
			var per := "" if (StatBook.RATES.has(key) or key == "kh") else fmt(value(r, key, true), key, true) + " a game"
			h.add_child(_cell(per, 84.0, UiKit.MUTED, UiKit.SMALL))
			box.add_child(h)
		if any:
			grid.add_child(box)
	return grid


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


## Season by season: the seasons with full records (Career "lines"), then the
## games and goals of every season at each club, which reach back before
## records were kept.
static func _career(p: Dictionary) -> Control:
	var v := UiKit.vbox(2)
	v.name = "PlayerCareer"
	if p.is_empty():
		v.add_child(UiKit.lbl("No career record.", UiKit.SMALL, UiKit.MUTED))
		return v
	var c := Career.of(p)
	var lines: Array = c.get("lines", [])
	if not lines.is_empty():
		var head := UiKit.hbox(4)
		for col in [["Year", 48.0], ["Club", 56.0], ["GM", 34.0], ["G", 34.0], ["D", 40.0], ["CP", 40.0], ["M", 40.0], ["T", 40.0]]:
			head.add_child(_cell(str(col[0]), float(col[1]), UiKit.MUTED, UiKit.SMALL))
		v.add_child(head)
		for line in lines:
			var a: PackedInt32Array = line[3]
			var h := UiKit.hbox(4)
			h.name = "CareerLine_%d" % int(line[0])
			h.add_child(_cell(str(line[0]), 48.0, UiKit.TEXT, UiKit.SMALL))
			h.add_child(_cell(str(line[1]), 56.0, UiKit.TEXT, UiKit.SMALL))
			h.add_child(_cell(str(int(line[2])), 34.0, UiKit.TEXT, UiKit.SMALL))
			for k in ["goals", "disposals", "contested_possessions", "marks", "tackles"]:
				var i := StatBook.KEYS.find(k)
				h.add_child(_cell(str(a[i]) if i >= 0 and i < a.size() else "–", 34.0 if k == "goals" else 40.0,
						UiKit.TEXT, UiKit.SMALL))
			v.add_child(h)
	var by_club := Career.club_lines(p, func(code): return GameDB.club_short(str(code)))
	if not by_club.is_empty():
		var t := UiKit.lbl(("At each club, games and goals: " if not lines.is_empty() else "")
				+ "  ·  ".join(by_club), UiKit.SMALL, UiKit.MUTED)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
	if lines.is_empty() and by_club.is_empty():
		v.add_child(UiKit.lbl("No senior games before this season.", UiKit.SMALL, UiKit.MUTED))
	if not Career.complete(p):
		v.add_child(UiKit.lbl("Part of his career was played before records were kept.", UiKit.SMALL, UiKit.MUTED))
	return v
