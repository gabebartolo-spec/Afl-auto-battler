class_name StatsFixture
extends RefCounted
## Season stats > fixture: every round of the season, the home-and-away
## rounds and then the finals weeks, one round at a time. It opens on the
## round to play (or the last one played); Previous, Next and a round picker
## move about. A played match opens its box score, an upcoming one a preview
## (STATS patch, ROADMAP §1.11). Facts only: what the save kept, nothing
## invented.

const FINALS_WEEKS := ["Wildcard finals", "Qualifying and elimination finals", "Semi finals",
		"Preliminary finals", "Grand Final"]
## The team numbers shown under a played match's quarters, when the result
## still carries them.
const TEAM_ROWS := [
	["disposals", "Disposals"], ["marks", "Marks"], ["tackles", "Tackles"],
	["inside50", "Inside 50s"], ["clearances", "Clearances"], ["hitouts", "Hit-outs"],
]

## The page on show (an index into pages()); -1 is the current round. Kept
## across a rebuild, and dropped when the season has moved on.
static var _page := -1
static var _stamp := ""


## Back to the current round (a new visit).
static func reset() -> void:
	_page = -1


static func build(host: Control) -> Control:
	var season: Season = GameState.season
	var v := UiKit.vbox(10)
	v.name = "StatsFixture"
	var pgs := pages(season)
	if pgs.is_empty():
		v.add_child(UiKit.subtitle("No fixture yet."))
		return v
	var stamp := "%d/%d/%d" % [season.round_index, int(season.finals.get("week", 0)),
			(season.finals.get("weeks", []) as Array).size()]
	if stamp != _stamp:
		_stamp = stamp
		_page = -1
	if _page < 0 or _page >= pgs.size():
		_page = current_page(pgs)
	var page: Dictionary = pgs[_page]
	var narrow := not bool(host.call("wide"))

	# Round navigation: back, the round picker, forward.
	var nav := UiKit.hbox(6)
	nav.name = "RoundNav"
	var prev := UiKit.btn("Previous", UiKit.BODY)
	prev.name = "PrevRound"
	prev.custom_minimum_size = Vector2(120 if not narrow else 96, 44)
	prev.disabled = _page == 0
	prev.pressed.connect(func(): _go(host, _page - 1))
	nav.add_child(prev)
	var pick := UiKit.btn(str(page["title"]), UiKit.NAME)
	pick.name = "RoundPicker"
	if narrow:
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		# A compact group on a wide screen, not a bar across the window.
		pick.custom_minimum_size = Vector2(240, 44)
	pick.clip_text = true
	pick.pressed.connect(func(): _round_sheet(host, pgs))
	nav.add_child(pick)
	var nxt := UiKit.btn("Next", UiKit.BODY)
	nxt.name = "NextRound"
	nxt.custom_minimum_size = Vector2(120 if not narrow else 96, 44)
	nxt.disabled = _page >= pgs.size() - 1
	nxt.pressed.connect(func(): _go(host, _page + 1))
	nav.add_child(nxt)
	v.add_child(nav)
	var status := UiKit.subtitle(_status(season, page))
	status.name = "RoundStatus"
	v.add_child(status)

	var matches: Array = page["matches"]
	# "Upcoming" only where played and unplayed matches share a round.
	var done_n := 0
	for m in matches:
		if not (m["res"] as Dictionary).is_empty():
			done_n += 1
	var mixed := done_n > 0 and done_n < matches.size()
	var list: Container
	if narrow:
		var col := UiKit.vbox(4)
		list = col
	else:
		# Compact rows two or three across, the score beside the clubs.
		var grid := GridContainer.new()
		grid.columns = 3 if float(host.call("content_width")) >= 1240.0 else 2
		grid.add_theme_constant_override("h_separation", 28)
		grid.add_theme_constant_override("v_separation", 4)
		list = grid
	list.name = "FixtureRows"
	v.add_child(list)
	for i in range(matches.size()):
		list.add_child(_row(host, season, matches[i], i, narrow, mixed))
	if matches.is_empty():
		list.add_child(UiKit.lbl("The matches are set once the earlier finals are played.", UiKit.BODY, UiKit.MUTED))
	var byes: Array = page.get("byes", [])
	if not byes.is_empty():
		var names := PackedStringArray()
		for c in byes:
			names.append(GameDB.club_short(str(c)))
		var b := UiKit.lbl("Bye: " + ", ".join(names), UiKit.SMALL, UiKit.MUTED)
		b.name = "ByeLine"
		v.add_child(b)
	return v


static func _go(host: Control, page: int) -> void:
	_page = page
	host.call("refresh")


## Every round of the season as pages: {title, matches, played, byes,
## finals}. A match is {home, away, res, venue, tag, label}; res is empty
## until it is played. The finals weeks are there once the finals have
## started: those played, and the week now to play.
static func pages(season: Season) -> Array:
	var out := []
	for i in range(season.fixture.size()):
		var played: Array = season.results[i] if i < season.results.size() else []
		var matches := []
		var playing := {}
		for m in season.fixture[i]:
			var res := {}
			for r in played:
				if str(r.get("home", "")) == str(m["home"]) and str(r.get("away", "")) == str(m["away"]):
					res = r
			matches.append({"home": str(m["home"]), "away": str(m["away"]), "res": res,
					"venue": season.home_ground(str(m["home"])), "tag": "", "label": "Round %d" % (i + 1)})
			playing[str(m["home"])] = true
			playing[str(m["away"])] = true
		var byes := []
		for c in season.clubs:
			if not playing.has(str(c)):
				byes.append(str(c))
		out.append({"title": "Round %d" % (i + 1), "matches": matches, "played": i < season.results.size(),
				"byes": byes, "finals": false})
	if not season.finals.is_empty():
		var weeks: Array = season.finals.get("weeks", [])
		var last := weeks.size() + (0 if bool(season.finals.get("done", false)) else 1)
		for w in range(mini(last, FINALS_WEEKS.size())):
			var matches := []
			if w < weeks.size():
				for r in weeks[w]:
					matches.append({"home": str(r["home"]), "away": str(r["away"]), "res": r,
							"venue": str(r.get("venue", "")), "tag": str(r.get("tag", "")),
							"label": str(r.get("label", ""))})
			else:
				for m in season.finals_week_matches():
					if str(m["home"]) == "" or str(m["away"]) == "":
						continue
					matches.append({"home": str(m["home"]), "away": str(m["away"]), "res": {},
							"venue": season.finals_venue(m), "tag": str(m["tag"]), "label": str(m["label"])})
			out.append({"title": str(FINALS_WEEKS[w]), "matches": matches, "played": w < weeks.size(),
					"byes": [], "finals": true})
	return out


## The round to open on: the next one to play, or the last played once
## the home-and-away season (and the finals) are through.
static func current_page(pgs: Array) -> int:
	for i in range(pgs.size()):
		if not bool(pgs[i]["played"]) and not (pgs[i]["matches"] as Array).is_empty():
			return i
	return pgs.size() - 1


static func _status(season: Season, page: Dictionary) -> String:
	if bool(page["finals"]):
		return "Played" if bool(page["played"]) else "To play"
	var idx := _page + 1
	if bool(page["played"]):
		return "Played · round %d of %d" % [idx, Season.REGULAR_ROUNDS]
	var what := "Next round" if idx == season.round_index + 1 else "To play"
	return "%s · round %d of %d" % [what, idx, Season.REGULAR_ROUNDS]


## One match as a tappable row: the two clubs one over the other, their
## scores (or, for a match to come, "Upcoming" and the ground) beside them.
## Your club's match is set in bold.
static func _row(host: Control, season: Season, m: Dictionary, index: int, narrow: bool, mixed: bool) -> Control:
	var res: Dictionary = m["res"]
	var done := not res.is_empty()
	var mine := GameState.my_club
	var yours: bool = str(m["home"]) == mine or str(m["away"]) == mine
	var b := Button.new()
	b.name = "Match_%d" % index
	b.set_meta("done", done)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0 if narrow else 400, 76 if done else 60)
	if not narrow:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.clip_contents = true
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color.TRANSPARENT
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(UiKit.TEXT, 0.05)
	hover.set_corner_radius_all(UiKit.RADIUS)
	for state in ["normal", "focus"]:
		b.add_theme_stylebox_override(state, flat)
	for state in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, hover)
	var box := MarginContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("margin_left", 4)
	box.add_theme_constant_override("margin_right", 4)
	var row := UiKit.hbox(10)
	box.add_child(row)
	var clubs := UiKit.vbox(2)
	clubs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clubs.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(clubs)
	var side := UiKit.vbox(2)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	for s in range(2):
		var code := str(m["home"] if s == 0 else m["away"])
		var badge := UiKit.club_badge(code, UiKit.BODY, narrow, true)
		if yours:
			_bold_labels(badge)
		clubs.add_child(badge)
		if done:
			var sc := UiKit.line(UiKit.scoreline(int(res["goals"][s]), int(res["behinds"][s])), UiKit.BODY,
					UiKit.TEXT, yours)
			sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			side.add_child(sc)
	var where := UiKit.ellipsis(str(m["venue"]), UiKit.SMALL, UiKit.MUTED)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	where.custom_minimum_size.x = 96 if narrow else 150
	where.size_flags_horizontal = Control.SIZE_SHRINK_END
	if not done and mixed:
		var when := UiKit.line("Upcoming", UiKit.SMALL, UiKit.MUTED, yours)
		when.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		side.add_child(when)
	# The ground, quietly: under the score, or alone for a match to come.
	side.add_child(where)
	_ignore(box)
	b.pressed.connect(func():
		if done:
			_match_sheet(host, m)
		else:
			_preview_sheet(host, season, m))
	return b


## Everything inside a tappable row hands the tap to the row.
static func _ignore(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore(c)


static func _bold_labels(n: Node) -> void:
	if n is Label:
		(n as Label).add_theme_font_override("font", UiKit.BOLD)
	for c in n.get_children():
		_bold_labels(c)


# ---------------------------------------------------------------------------
# Sheets
# ---------------------------------------------------------------------------
static func _sheet(host: Control, title: String, sub: String) -> Dictionary:
	var box := UiKit.modal_box(host, 560.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "FixtureSheet"
	host.call("open_sheet", overlay)
	var body: VBoxContainer = box["body"]
	body.add_child(UiKit.ellipsis(title, UiKit.H2, UiKit.TEXT, true))
	if sub != "":
		body.add_child(UiKit.lbl(sub, UiKit.SMALL, UiKit.MUTED))
	var close := UiKit.btn("Close", UiKit.BODY)
	close.name = "CloseSheet"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func(): host.call("close_sheet"))
	(box["footer"] as Control).add_child(close)
	return box


## The round picker: every round in a grid, the finals weeks under it.
static func _round_sheet(host: Control, pgs: Array) -> void:
	var box := _sheet(host, "Go to round", "")
	var body: VBoxContainer = box["body"]
	var grid := GridContainer.new()
	grid.name = "RoundGrid"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var finals: VBoxContainer = null
	for i in range(pgs.size()):
		var p: Dictionary = pgs[i]
		var b: Button
		if bool(p["finals"]):
			if finals == null:
				body.add_child(UiKit.section("Finals"))
				finals = UiKit.vbox(6)
				body.add_child(finals)
			b = UiKit.btn(str(p["title"]), UiKit.BODY)
			finals.add_child(b)
		else:
			b = UiKit.btn(str(i + 1), UiKit.BODY)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(b)
		b.name = "RoundPick_%d" % i
		b.custom_minimum_size.y = 44
		UiKit.set_selected(b, i == _page)
		if not bool(p["played"]) and i != _page:
			b.add_theme_color_override("font_color", UiKit.MUTED)
		b.pressed.connect(func():
			host.call("close_sheet")
			_go(host, i))


## A played match: the score, quarter by quarter, then what was kept of it.
static func _match_sheet(host: Control, m: Dictionary) -> void:
	var res: Dictionary = m["res"]
	var home := str(m["home"])
	var away := str(m["away"])
	var sub := str(m["label"])
	if str(m["venue"]) != "":
		sub += " · " + str(m["venue"])
	var box := _sheet(host, "%s v %s" % [GameDB.club_short(home), GameDB.club_short(away)], sub)
	var body: VBoxContainer = box["body"]
	body.name = "MatchBox"
	body.add_child(UiKit.lbl(_result_line(res), UiKit.BODY, UiKit.TEXT, true))
	body.add_child(_quarters(host, res))
	var team: Array = res.get("team", [])
	var players: Dictionary = res.get("players", {})
	if team.size() == 2 and not players.is_empty():
		body.add_child(UiKit.section("Team"))
		body.add_child(_team_rows(team))
		body.add_child(UiKit.section("Players"))
		for side in range(2):
			body.add_child(_players_line(res, side))
	else:
		var gone := UiKit.lbl("Player and team stats were not kept for this match.", UiKit.SMALL, UiKit.MUTED)
		gone.name = "NotKept"
		body.add_child(gone)


static func _result_line(res: Dictionary) -> String:
	var s: Array = res["score"]
	if int(s[0]) == int(s[1]):
		return "A draw"
	var win := 0 if int(s[0]) > int(s[1]) else 1
	var code := str(res["home"] if win == 0 else res["away"])
	return "%s won by %d" % [GameDB.club_short(code), absi(int(s[0]) - int(s[1]))]


static func _quarters(host: Control, res: Dictionary) -> Control:
	var codes := [str(res["home"]), str(res["away"])]
	var qg: Array = res.get("q_goals", [])
	var qb: Array = res.get("q_behinds", [])
	var v := UiKit.vbox(6)
	v.name = "Quarters"
	var wide := float(host.call("content_width")) >= 520.0 and qg.size() <= 4
	if wide:
		var head := UiKit.hbox(4)
		head.add_child(_cell("", 48, UiKit.MUTED))
		for i in range(qg.size()):
			head.add_child(_cell("Q%d" % (i + 1), 52, UiKit.MUTED))
		head.add_child(_cell("Final", 100, UiKit.MUTED))
		v.add_child(head)
	for side in range(2):
		if wide:
			var r := UiKit.hbox(4)
			var badge := UiKit.club_badge(codes[side], UiKit.SMALL, true, false)
			badge.custom_minimum_size.x = 48
			r.add_child(badge)
			for i in range(qg.size()):
				r.add_child(_cell("%d.%d" % [int(qg[i][side]), int(qb[i][side])], 52, UiKit.TEXT))
			r.add_child(_cell(UiKit.scoreline(int(res["goals"][side]), int(res["behinds"][side])), 100,
					UiKit.TEXT, true))
			v.add_child(r)
		else:
			var block := UiKit.vbox(2)
			var head := UiKit.hbox(8)
			head.add_child(UiKit.club_badge(codes[side], UiKit.BODY, true, true))
			head.add_child(UiKit.line(UiKit.scoreline(int(res["goals"][side]), int(res["behinds"][side])),
					UiKit.BODY, UiKit.TEXT, true))
			block.add_child(head)
			var parts := PackedStringArray()
			for i in range(qg.size()):
				parts.append("%s %d.%d" % ["ET" if i >= 4 else "Q%d" % (i + 1), int(qg[i][side]), int(qb[i][side])])
			block.add_child(UiKit.lbl("   ".join(parts), UiKit.SMALL, UiKit.MUTED))
			v.add_child(block)
	return v


static func _cell(text: String, w: int, col: Color, bold := false) -> Label:
	var l := UiKit.line(text, UiKit.SMALL, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func _team_rows(team: Array) -> Control:
	var v := UiKit.vbox(3)
	v.name = "TeamRows"
	for row in TEAM_ROWS:
		var key := str(row[0])
		if not (team[0] as Dictionary).has(key):
			continue
		var h := UiKit.hbox(8)
		var a := UiKit.line(str(int(team[0][key])), UiKit.BODY, UiKit.TEXT, true)
		a.custom_minimum_size.x = 48
		h.add_child(a)
		var label := UiKit.line(str(row[1]), UiKit.SMALL, UiKit.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(label)
		var b := UiKit.line(str(int(team[1][key])), UiKit.BODY, UiKit.TEXT, true)
		b.custom_minimum_size.x = 48
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(b)
		v.add_child(h)
	return v


## One side's goalkickers and its three most involved players, from the
## player box scores the result kept.
static func _players_line(res: Dictionary, side: int) -> Control:
	var players: Dictionary = res["players"]
	var rosters: Array = res.get("roster", [])
	var roster: Array = rosters[side] if rosters.size() > side else []
	var rows := []
	for r in roster:
		var st: Dictionary = players.get(str(r["id"]), {})
		if st.is_empty():
			continue
		rows.append({"name": GameDB.player_display_name_by_id(str(r["id"]), str(r.get("name", "Player"))),
				"goals": int(st.get("goals", 0.0)), "inf": CoachReport.influence(st)})
	var v := UiKit.vbox(2)
	v.name = "Players_%d" % side
	v.add_child(UiKit.lbl(GameDB.club_short(str(res["home"] if side == 0 else res["away"])),
			UiKit.SMALL, UiKit.MUTED, true))
	var kickers := rows.filter(func(r): return int(r["goals"]) > 0)
	kickers.sort_custom(func(a, b): return int(a["goals"]) > int(b["goals"]))
	var kp := PackedStringArray()
	for r in kickers.slice(0, 4):
		kp.append("%s %d" % [r["name"], int(r["goals"])])
	v.add_child(UiKit.lbl("Goals: " + (", ".join(kp) if not kp.is_empty() else "none"), UiKit.BODY, UiKit.TEXT))
	rows.sort_custom(func(a, b): return float(a["inf"]) > float(b["inf"]))
	var best := PackedStringArray()
	for r in rows.slice(0, 3):
		best.append(str(r["name"]))
	if not best.is_empty():
		v.add_child(UiKit.lbl("Most involved: " + ", ".join(best), UiKit.BODY, UiKit.TEXT))
	return v


## A match to come: both clubs, where they sit, where it is played and how
## each has gone lately.
static func _preview_sheet(host: Control, season: Season, m: Dictionary) -> void:
	var home := str(m["home"])
	var away := str(m["away"])
	var sub := str(m["label"])
	if str(m["venue"]) != "":
		sub += " · " + str(m["venue"])
	var box := _sheet(host, "%s v %s" % [GameDB.club_short(home), GameDB.club_short(away)], sub)
	var body: VBoxContainer = box["body"]
	body.name = "PreviewBox"
	var order := {}
	var rows: Array = season.ladder_sorted()
	for i in range(rows.size()):
		order[str(rows[i]["code"])] = i + 1
	for code in [home, away]:
		var block := UiKit.vbox(3)
		block.name = "Preview_" + str(code)
		var head := UiKit.hbox(8)
		head.add_child(UiKit.club_badge(str(code), UiKit.NAME, false, true))
		var row: Dictionary = season.ladder.get(code, {})
		var pos := ("%s · %d-%d" % [_ordinal(int(order.get(code, 0))), int(row.get("w", 0)), int(row.get("l", 0))]) \
				if int(row.get("p", 0)) > 0 else "No games yet"
		head.add_child(UiKit.line(pos, UiKit.SMALL, UiKit.MUTED))
		block.add_child(head)
		var last := last_results(season, str(code), 3)
		if last.is_empty():
			block.add_child(UiKit.lbl("No results yet.", UiKit.SMALL, UiKit.MUTED))
		for l in last:
			block.add_child(UiKit.lbl(str(l), UiKit.SMALL, UiKit.TEXT))
		body.add_child(block)


## A club's last few results this season, newest first, a line each:
## "Round 4: won by 15 v Collingwood".
static func last_results(season: Season, code: String, n: int) -> Array:
	var rounds: Array = season.results.duplicate()
	rounds.append_array(season.finals.get("weeks", []))
	var out := []
	for rnd in rounds:
		for res in rnd:
			var side := -1
			if str(res.get("home", "")) == code:
				side = 0
			elif str(res.get("away", "")) == code:
				side = 1
			if side < 0:
				continue
			var s: Array = res["score"]
			var diff := int(s[side]) - int(s[1 - side])
			var opp := GameDB.club_short(str(res["away"] if side == 0 else res["home"]))
			var word := "drew with"
			if diff > 0:
				word = "won by %d v" % diff
			elif diff < 0:
				word = "lost by %d to" % -diff
			var label := str(res.get("label", "Round %d" % int(res.get("round", 0))))
			out.append("%s: %s %s" % [label, word, opp])
	out.reverse()
	return out.slice(0, n)


static func _ordinal(n: int) -> String:
	if n <= 0:
		return "-"
	var tail := n % 100
	var suffix := "th"
	if tail < 11 or tail > 13:
		match n % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return "%d%s" % [n, suffix]
