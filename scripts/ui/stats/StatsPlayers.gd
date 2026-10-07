class_name StatsPlayers
extends RefCounted
## Season stats > Player stats: every player's season across the whole
## competition (StatBook), not his ratings. Columns come in football groups;
## a phone shows one group, a wide screen as many whole groups as fit. Totals
## or per game; tap a heading to sort (again to reverse); filter by club,
## position, age, role, trait and games. Tap a player for his season and
## career.

## Column groups: [key, label, [[stat, heading, full name], ...]]. A stat is
## a StatBook key, a StatBook rate ("accuracy", ...) or "kh" (kicks to each
## handball).
const GROUPS := [
	["disposals", "Disposals", [["disposals", "D", "disposals"], ["kicks", "K", "kicks"],
			["handballs", "H", "handballs"], ["kh", "K:H", "kicks to each handball"],
			["efficiency", "DE%", "disposal efficiency"]]],
	["ground", "Ground gained", [["metres_gained", "MG", "metres gained"],
			["running_bounces", "RB", "running bounces"], ["inside50", "I50", "inside 50s"],
			["rebounds", "R50", "rebound 50s"]]],
	["contest", "Contested ball", [["contested_possessions", "CP", "contested possessions"],
			["uncontested_possessions", "UP", "uncontested possessions"],
			["cp_rate", "CP%", "contested possession rate"], ["ground_ball_gets", "GBG", "ground-ball gets"],
			["clearances", "CL", "clearances"]]],
	["marking", "Marking", [["marks", "M", "marks"], ["contested_marks", "CM", "contested marks"],
			["intercept_marks", "IM", "intercept marks"]]],
	["goals", "Goals", [["goals", "G", "goals"], ["behinds", "B", "behinds"],
			["shots", "SH", "shots at goal"], ["accuracy", "ACC%", "goalkicking accuracy"],
			["goal_assists", "GA", "goal assists"]]],
	["setshots", "Set shots", [["set_shots", "SS", "set shots"], ["set_goals", "SG", "set-shot goals"],
			["set_accuracy", "SS%", "set-shot accuracy"], ["score_involvements", "SI", "score involvements"]]],
	["ruck", "Ruck", [["hitouts", "HO", "hit-outs"], ["ruck_contests", "RC", "ruck contests"],
			["hitout_win", "HO%", "hit-out win rate"], ["hitouts_adv", "HA", "hit-outs to advantage"],
			["cba", "CBA", "centre bounce attendances"]]],
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
static var _show_filters := false


static func build(host: Control) -> Control:
	var v := UiKit.vbox(8)
	v.name = "StatsPlayers"
	var wide: bool = host.call("wide")
	if not GameState.season_stats.is_empty() and int(GameState.season_stats_from) > 0:
		var note := UiKit.lbl("Counted from round %d: this career's earlier rounds were played before season records were kept."
				% (int(GameState.season_stats_from) + 1), UiKit.SMALL, UiKit.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(note)
	v.add_child(_controls(host, wide))
	var rows := _rows()
	if rows.is_empty():
		var none := UiKit.lbl("No one has played a game yet." if GameState.season_stats.is_empty()
				else "No players match these filters.", UiKit.BODY, UiKit.MUTED)
		none.name = "PlayersEmpty"
		v.add_child(none)
		return v
	var cols := _columns(host, wide)
	_sort_rows(rows)
	v.add_child(_table(host, rows, cols, wide))
	return v


# ---------------------------------------------------------------------------
# Controls: the group, totals or per game, filters
# ---------------------------------------------------------------------------
static func _controls(host: Control, wide: bool) -> Control:
	var v := UiKit.vbox(6)
	var row := HFlowContainer.new()
	row.name = "PlayersControls"
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	v.add_child(row)
	var group := OptionButton.new()
	group.name = "StatGroup"
	UiKit.style_button(group, 14)
	group.custom_minimum_size = Vector2(170, 44)
	for i in range(GROUPS.size()):
		group.add_item(str(GROUPS[i][1]), i)
		if str(GROUPS[i][0]) == _group:
			group.select(i)
	group.item_selected.connect(func(i: int):
		pick_group(str(GROUPS[i][0]))
		host.call("refresh"))
	row.add_child(group)
	var mode := UiKit.choice_grid("StatMode", [["total", "Totals"], ["per_game", "Per game"]],
			"per_game" if _per_game else "total", 2, func(k):
				_per_game = k == "per_game"
				host.call("refresh"))
	mode.custom_minimum_size.x = 200
	row.add_child(mode)
	var active := _active_text()
	if not wide:
		var fb := UiKit.btn("Filters" if active == "" else "Filters (%d)" % _active_count(), 14)
		fb.name = "FiltersToggle"
		fb.custom_minimum_size = Vector2(104, 44)
		fb.pressed.connect(func():
			_show_filters = not _show_filters
			host.call("refresh"))
		row.add_child(fb)
	if _show_filters or wide:
		v.add_child(_filter_row(host))
	if active != "":
		var h := UiKit.hbox(8)
		var t := UiKit.lbl("Showing " + active, UiKit.SMALL, UiKit.TEXT)
		t.name = "ActiveFilters"
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		var reset := UiKit.btn("Reset", 14)
		reset.name = "FiltersReset"
		reset.flat = true
		reset.custom_minimum_size = Vector2(72, 44)
		reset.pressed.connect(func():
			reset_filters()
			host.call("refresh"))
		h.add_child(reset)
		v.add_child(h)
	return v


## Show a group: it leads the columns and sorts by its first stat.
static func pick_group(key: String) -> void:
	for g in GROUPS:
		if str(g[0]) == key:
			_group = key
			_sort = str(g[2][0][0])
			_desc = true
			_shown = PAGE


static func _filter_row(host: Control) -> Control:
	var flow := HFlowContainer.new()
	flow.name = "FilterRow"
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
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
		flow.add_child(_dropdown(host, str(f[0]), f[1]))
	return flow


static func _dropdown(host: Control, key: String, options: Array) -> OptionButton:
	var o := OptionButton.new()
	o.name = "Filter_" + key
	UiKit.style_button(o, 14)
	o.custom_minimum_size = Vector2(150, 44)
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
	_show_filters = false
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
	var room: float = float(host.call("content_width")) - (440.0 if wide else 200.0)
	var w := _col_w(wide)
	for j in range(GROUPS.size()):
		var g: Array = GROUPS[(start + j) % GROUPS.size()]
		var need := float((g[2] as Array).size()) * w
		if j > 0 and (not wide or need > room):
			break
		for c in g[2]:
			cols.append([str(c[0]), str(c[1]), str(c[2]), str(g[1])])
		room -= need
	return cols


static func _col_w(wide: bool) -> float:
	return 46.0 if wide else 38.0


static func _table(host: Control, list: Array, cols: Array, wide: bool) -> Control:
	var v := UiKit.vbox(0)
	v.name = "PlayersTable"
	var w := _col_w(wide)
	var head := UiKit.hbox(2)
	head.name = "PlayersHeader"
	var who := UiKit.line("Player", UiKit.SMALL, UiKit.MUTED)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	head.add_child(_cell("Club", 44.0 if not wide else 120.0, UiKit.MUTED, UiKit.SMALL))
	if wide:
		head.add_child(_cell("Pos", 56.0, UiKit.MUTED, UiKit.SMALL))
		head.add_child(_cell("Age", 40.0, UiKit.MUTED, UiKit.SMALL))
	head.add_child(_sort_button(host, "games", "GM", "games played", 36.0))
	for c in cols:
		head.add_child(_sort_button(host, str(c[0]), str(c[1]), str(c[2]), w))
	v.add_child(head)
	v.add_child(UiKit.rule())
	for i in range(mini(_shown, list.size())):
		v.add_child(_row(host, list[i], i + 1, cols, wide))
	if list.size() > _shown:
		var more := UiKit.btn("Show %d more of %d" % [mini(PAGE, list.size() - _shown), list.size()], 14)
		more.name = "PlayersMore"
		more.custom_minimum_size = Vector2(0, 44)
		more.pressed.connect(func():
			_shown += PAGE
			host.call("refresh"))
		v.add_child(UiKit.spacer(6))
		v.add_child(more)
	# Every heading spelled out (a phone has no hover), and how rates rank.
	var bits: PackedStringArray = ["GM games"]
	for c in cols:
		bits.append("%s %s" % [str(c[1]), str(c[2])])
	bits.append("* played for two clubs")
	v.add_child(UiKit.spacer(6))
	var key := UiKit.lbl("  ·  ".join(bits), UiKit.SMALL, UiKit.MUTED)
	key.name = "PlayersKey"
	key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(key)
	if QUALIFY.has(_sort):
		var q := UiKit.lbl("Ranked by %s among players with at least %d %s so far." % [_name_of(_sort),
				int(qualify_min(_sort)), str(QUALIFY[_sort][2])], UiKit.SMALL, UiKit.MUTED)
		q.name = "PlayersQualify"
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(q)
	return v


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
	b.custom_minimum_size = Vector2(w, 44)
	b.add_theme_font_size_override("font_size", UiKit.SMALL)
	b.add_theme_color_override("font_color", UiKit.TEXT if key == _sort else UiKit.MUTED)
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


static func _row(host: Control, row: Dictionary, rank: int, cols: Array, wide: bool) -> Control:
	var b := Button.new()
	b.name = "PlayerRow_" + str(row["id"])
	b.flat = true
	b.custom_minimum_size.y = 34
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(func(): open_player(host, str(row["id"])))
	var h := UiKit.hbox(2)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(h)
	var mine := str(row["club"]) == GameState.my_club
	var who := UiKit.ellipsis("%d  %s" % [rank, str(row["name"])], UiKit.SMALL, UiKit.TEXT, mine)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(who)
	var club_text := (GameDB.club_short(str(row["club"])) if wide else str(row["club"])) + ("*" if bool(row["moved"]) else "")
	h.add_child(_cell(club_text, 44.0 if not wide else 120.0, UiKit.MUTED, UiKit.SMALL))
	if wide:
		var p: Dictionary = row["p"]
		h.add_child(_cell(str(p.get("role", "")), 56.0, UiKit.MUTED, UiKit.SMALL))
		h.add_child(_cell(str(int(float(p.get("age", 0.0)))) if not p.is_empty() else "", 40.0, UiKit.MUTED, UiKit.SMALL))
	h.add_child(_cell(str(int(row["games"])), 36.0, UiKit.MUTED, UiKit.SMALL))
	var w := _col_w(wide)
	for c in cols:
		var key := str(c[0])
		var cell := _cell(fmt(value(row, key, _per_game), key, _per_game), w,
				UiKit.TEXT if qualifies(row, key) else UiKit.MUTED, UiKit.SMALL, key == _sort)
		cell.name = "Cell_" + key
		h.add_child(cell)
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


static func _cell(text: String, w: float, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.line(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var r := {"id": "", "games": int(row.get("games", 0)), "s": s}
	var grid := GridContainer.new()
	grid.name = "PlayerSeasonGrid"
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	for g in GROUPS:
		var box := UiKit.vbox(1)
		box.custom_minimum_size.x = 320 if wide else 0
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
