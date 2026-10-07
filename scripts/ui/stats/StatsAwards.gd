class_name StatsAwards
extends RefCounted
## Season stats > Awards: the races as they stand, the All-Australian team if
## it were picked today, and the Rising Star nominations, round by round.
## Nothing here is awarded until the season's awards are presented; from then
## the honours lead, set apart from the races. Brownlow votes stay sealed
## until the count. Tap any player for his profile and history.

## Ranks a race table shows; a tie across the cut is summed up in one line.
const RACE_ROWS := 10
## A table's width on a wide screen: a name, a club and a figure, not a row
## stretched across a PC monitor.
const TABLE_W := 600.0
## On a wide screen the two races sit side by side, each this wide.
const RACE_W := 460.0
## Rows: one line, no rules between them; every other row on a faint band.
const ROW_H := 32
## On a phone a row is a thumb's target: taller.
const ROW_H_PHONE := 40
## The round, ahead of a Rising Star nominee.
const ROUND_W := 80.0
## Row geometry, shared by the tables and the fit test for the honours.
const LEAD_W := 104.0
const CLUB_W := 72.0
const GAP := 8.0
const FIGURE_SIZE := 17
## The All-Australian slots on the oval (Awards.AA_SLOTS): the five
## midfielders fill the centre square first, then the wings.
const AA_SPOTS := {"RUCK": ["RUCK"], "MID": ["MID", "MID", "MID", "WING", "WING"],
		"DEF": ["DEF"], "FWD": ["FWD"], "BENCH": ["BENCH"]}


static func build(host: Control) -> Control:
	var season: Season = GameState.season
	var v := UiKit.vbox(6)
	v.name = "StatsAwards"
	var aw: Dictionary = GameState.season_awards
	if not aw.is_empty() and int(aw.get("year", 0)) == GameState.season_year:
		v.add_child(_honours(host, aw))
		v.add_child(_aa(host, aw.get("all_australian", []), true, 0))
		v.add_child(_rising(host))
		return v
	var played := mini(season.round_index, Season.REGULAR_ROUNDS)
	var info := "After Round %d. Nothing here is awarded until the season's end." % played
	if season.is_regular_done():
		info = "Home and away complete. The awards are presented after the Grand Final."
	elif played == 0:
		info = "The races start with Round 1. Nothing here is awarded until the season's end."
	var head := _para(info)
	head.name = "AwardsProvisional"
	v.add_child(head)
	var coleman := race(host, "Coleman Medal", "Coleman", "goals_ha", "Goals", "No goals kicked yet.")
	var coaches := race(host, "Coaches Award", "CoachesAward", "coaches", "Votes", "No votes yet.")
	if bool(host.call("wide")):
		# Two races, side by side on a PC.
		var pair := UiKit.hbox(32)
		pair.name = "Races"
		coleman.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		coaches.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		pair.add_child(coleman)
		pair.add_child(coaches)
		v.add_child(pair)
	else:
		v.add_child(coleman)
		v.add_child(coaches)
	var brownlow := UiKit.vbox(4)
	brownlow.name = "BrownlowSealed"
	_title(brownlow, "Brownlow Medal")
	brownlow.add_child(_para("The umpires' votes stay sealed until the count after the Grand Final."))
	v.add_child(brownlow)
	v.add_child(_rising(host))
	if played > 0:
		var min_games := Awards.aa_min_games(played)
		var team := Awards.projected_all_australian(GameState.season_tally, _players(), min_games)
		v.add_child(_aa(host, team, false, min_games))
	return v


## One race from the season tally: rank, player, club, count. Level counts
## share a rank; a tie across the cut is summed up rather than listed.
static func race(host: Control, title: String, node: String, key: String, head: String,
		empty: String) -> Control:
	var v := _table(host, RACE_W)
	v.name = node + "Leaders"
	_title(v, title)
	var rows := []
	for id in GameState.season_tally:
		var n := int((GameState.season_tally[id] as Dictionary).get(key, 0))
		if n > 0:
			rows.append({"id": str(id), "club": str(GameState.season_tally[id]["club"]), "n": n})
	if rows.is_empty():
		var none := _para(empty)
		none.name = node + "Empty"
		v.add_child(none)
		return v
	rows.sort_custom(func(a, b):
		if int(a["n"]) != int(b["n"]):
			return int(a["n"]) > int(b["n"])
		return str(a["id"]) < str(b["id"]))
	v.add_child(_header(head))
	var shown := mini(RACE_ROWS, rows.size())
	# Never split a tie at the cut: the whole level group goes below the line
	# (unless it is the leaders themselves).
	while shown < rows.size() and int(rows[shown]["n"]) == int(rows[shown - 1]["n"]) \
			and int(rows[shown - 1]["n"]) != int(rows[0]["n"]):
		shown -= 1
	var rank := 0
	for i in range(shown):
		var r: Dictionary = rows[i]
		if i == 0 or int(r["n"]) != int(rows[i - 1]["n"]):
			rank = i + 1
		# The leader (or leaders, level) in bold.
		var b := _player_row(host, str(r["id"]), str(r["club"]), str(rank), str(int(r["n"])), "",
				64.0, false, i % 2 == 1, rank == 1)
		b.name = "%s_%d" % [node, i + 1]
		v.add_child(b)
	if shown < rows.size():
		var next := int(rows[shown]["n"])
		var level := 0
		for r in rows.slice(shown):
			if int(r["n"]) == next:
				level += 1
		if shown + level > RACE_ROWS:
			var unit := head.to_lower()
			if next == 1:
				unit = unit.trim_suffix("s")
			var more := _para("%d more on %d %s." % [level, next, unit])
			more.name = node + "More"
			v.add_child(more)
	return v


## The honours once the season's awards are presented: the winners, set apart
## from any race.
static func _honours(host: Control, aw: Dictionary) -> Control:
	var v := _table(host)
	v.name = "AwardsHonours"
	_title(v, "%d honours" % int(aw.get("year", GameState.season_year)))
	var note := _para("Awarded. The full placings are in the season review.")
	note.name = "AwardsAwarded"
	v.add_child(note)
	var brownlow: Dictionary = aw.get("brownlow_winner", {})
	if brownlow.is_empty():
		brownlow = _first(aw.get("brownlow", []))
	# Every figure carries its unit ("56 votes"), in its own right-hand
	# column. The Rising Star has none.
	var winners := [
		["Brownlow Medal", brownlow, "votes", "vote"],
		["Coleman Medal", _first(aw.get("coleman", [])), "goals", "goal"],
		["Coaches Award", _first(aw.get("coaches_award", [])), "coaches", "vote"],
		["Rising Star", _first(aw.get("rising_star", [])), "", ""],
	]
	var rows := []
	var fig_w := 0.0
	var name_w := 0.0
	for w in winners:
		var r: Dictionary = w[1]
		if r.is_empty():
			continue
		var n := int(r.get(str(w[2]), 0))
		var count := "" if str(w[2]) == "" else "%d %s" % [n, str(w[3]) if n == 1 else str(w[3]) + "s"]
		fig_w = maxf(fig_w, _text_w(count, FIGURE_SIZE, true))
		name_w = maxf(name_w, _text_w(GameState.award_name(r), UiKit.NAME, str(r.get("club", "")) == GameState.my_club))
		rows.append([w[0], r, count])
	# The name takes the width the figure and club leave. Where a name still
	# wouldn't fit (a phone), every club goes under its name instead, so the
	# table keeps one shape.
	var row_w: float = TABLE_W if bool(host.call("wide")) else float(host.call("content_width"))
	var stack := name_w > row_w - LEAD_W - CLUB_W - fig_w - 3.0 * GAP
	for i in range(rows.size()):
		var x: Array = rows[i]
		var r: Dictionary = x[1]
		var b := _player_row(host, str(r.get("id", "")), str(r.get("club", "")), "", str(x[2]), str(x[0]),
				fig_w, stack, i % 2 == 1)
		b.name = "Honour_" + str(x[0]).replace(" ", "")
		v.add_child(b)
	return v


## The All-Australian team on the oval: the one named at season's end, or the
## one that would be picked today.
static func _aa(host: Control, team: Array, awarded: bool, min_games: int) -> Control:
	var v := UiKit.vbox(6)
	v.name = "AllAustralian"
	_title(v, "All-Australian team")
	if awarded:
		var named := _para("Named at season's end.")
		named.name = "AANamed"
		v.add_child(named)
	else:
		var proj := _para("Projected: the team if it were picked today, from players with %d or more %s so far. The real team is named at season's end."
				% [min_games, "game" if min_games == 1 else "games"])
		proj.name = "AAProjected"
		v.add_child(proj)
	if team.is_empty():
		v.add_child(_para("Nobody has played enough games yet."))
		return v
	var side := {"RUCK": [], "MID": [], "WING": [], "DEF": [], "FWD": [], "BENCH": []}
	var used := {}
	var list := []
	var notes := {}
	for r in team:
		var id := str(r.get("id", ""))
		var p := _find(id)
		if p.is_empty():
			# Someone the lists no longer hold: the names, without the oval.
			return _aa_names(host, v, team)
		var slot := str(r.get("slot", "BENCH"))
		var spots: Array = AA_SPOTS.get(slot, ["BENCH"])
		var n := int(used.get(slot, 0))
		used[slot] = n + 1
		(side[str(spots[mini(n, spots.size() - 1)])] as Array).append(id)
		list.append(p)
		notes[id] = GameDB.club_short(str(r.get("club", "")))
	var builder := TeamBuilder.new()
	builder.name = "AATeam"
	builder.field_only = true
	builder.notes = notes
	builder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder.setup(side, bool(host.call("wide")), list, true)
	builder.inspect.connect(func(id: String): open_player(host, id))
	v.add_child(builder)
	return v


static func _aa_names(host: Control, v: Control, team: Array) -> Control:
	var lines := {"RUCK": "Ruck", "MID": "Midfield", "DEF": "Defence", "FWD": "Forward", "BENCH": "Interchange"}
	for i in range(team.size()):
		var r: Dictionary = team[i]
		v.add_child(_player_row(host, str(r.get("id", "")), str(r.get("club", "")), "", "",
				str(lines.get(str(r.get("slot", "")), "")), 0.0, false, i % 2 == 1))
	return v


## The Rising Star nominations, newest first. Rounds this save didn't record
## are said plainly, never filled in.
static func _rising(host: Control) -> Control:
	var v := _table(host)
	v.name = "RisingStar"
	_title(v, "Rising Star nominations")
	var rec: Dictionary = GameState.rising_star_noms
	var from := int(rec.get("from", 1))
	var noms: Array = (rec.get("rounds", []) as Array).duplicate()
	noms.sort_custom(func(a, b): return int(a["round"]) > int(b["round"]))
	if noms.is_empty() and from <= 1:
		v.add_child(_para("The first nomination comes after Round 1."))
	for i in range(noms.size()):
		var n: Dictionary = noms[i]
		var b := _player_row(host, str(n["id"]), str(n["club"]), "", "", "Round %d" % int(n["round"]), 0.0,
				false, i % 2 == 1, false, ROUND_W)
		b.name = "RisingStar_%d" % int(n["round"])
		v.add_child(b)
	if from > 1:
		var gap := _para("Round 1's nomination wasn't recorded in this save." if from == 2
				else "Nominations from Rounds 1 to %d weren't recorded in this save." % mini(from - 1, Season.REGULAR_ROUNDS))
		gap.name = "RisingStarUnrecorded"
		v.add_child(gap)
	return v


## A table's column: full width on a phone, TABLE_W on a wide screen.
static func _table(host: Control, width := TABLE_W) -> VBoxContainer:
	var v := UiKit.vbox(0)
	if bool(host.call("wide")):
		v.custom_minimum_size.x = width
		v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return v


## A section's title, with 16 px of air above it.
static func _title(v: Control, text: String) -> void:
	var air := Control.new()
	air.custom_minimum_size.y = 16
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(air)
	var t := UiKit.section(text)
	t.name = "Title"
	v.add_child(t)


## Column heads over a race table, lined up with _player_row.
static func _header(head: String) -> Control:
	var h := UiKit.hbox(8)
	var widths := [28, 0, 72, 64]
	var cols := ["", "Player", "Club", head]
	for i in range(cols.size()):
		var label := UiKit.line(str(cols[i]), 12, UiKit.MUTED)
		label.custom_minimum_size.x = float(widths[i])
		if i == 1:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif i == 3:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(label)
	return h


## One player as a tappable table row: a rank (or a lead such as the award or
## the round), his name, his club and a figure. Your club's players are in
## bold. The tap opens his profile.
static func _player_row(host: Control, id: String, club: String, rank: String, figure: String,
		lead := "", fig_w := 64.0, stack := false, band := false, bold := false, lead_w := LEAD_W) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46 if stack else (ROW_H if bool(host.call("wide")) else ROW_H_PHONE))
	b.clip_contents = true
	var flat := StyleBoxFlat.new()
	flat.bg_color = UiKit.PANEL if band else Color.TRANSPARENT
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(UiKit.TEXT, 0.06)
	for state in ["normal", "focus"]:
		b.add_theme_stylebox_override(state, flat)
	for state in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, hover)
	var row := UiKit.hbox(int(GAP))
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(row)
	if lead != "":
		var l := UiKit.ellipsis(lead, UiKit.BODY, UiKit.MUTED)
		l.custom_minimum_size.x = lead_w
		l.size_flags_horizontal = Control.SIZE_FILL
		row.add_child(l)
	else:
		var n := UiKit.line(rank, UiKit.BODY, UiKit.MUTED)
		n.custom_minimum_size.x = 28
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(n)
	var who := UiKit.ellipsis(GameState.award_name({"id": id}), UiKit.NAME, UiKit.TEXT,
			bold or club == GameState.my_club)
	who.name = "Name"
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c := UiKit.ellipsis(GameDB.club_short(club), 14, UiKit.MUTED)
	c.name = "Club"
	if stack:
		var both := UiKit.vbox(0)
		both.alignment = BoxContainer.ALIGNMENT_CENTER
		both.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		both.add_child(who)
		both.add_child(c)
		row.add_child(both)
	else:
		row.add_child(who)
		c.custom_minimum_size.x = CLUB_W
		c.size_flags_horizontal = Control.SIZE_FILL
		row.add_child(c)
	# A row with a lead keeps its figure's column even without a figure, so
	# its name and club line up with the rows around it.
	if figure != "" or lead != "":
		var f := UiKit.line(figure, FIGURE_SIZE, UiKit.TEXT, true)
		f.name = "Figure"
		f.custom_minimum_size.x = fig_w
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(f)
	_ignore_mouse(row)
	b.pressed.connect(func(): open_player(host, id))
	return b


## A player's profile and history over the hub; Back closes it first.
static func open_player(host: Control, id: String) -> void:
	var p := _find(id)
	if p.is_empty():
		return
	var sheet := PlayerSheet.open(host, p, Callable(), [])
	if host.has_method("open_sheet"):
		host.call("open_sheet", sheet)


## A player by id: on a list this season, or released since.
static func _find(id: String) -> Dictionary:
	var season: Season = GameState.season
	if season != null:
		for code in season.lists:
			for p in season.lists[code]:
				if str(p["id"]) == id:
					return p
	for p in GameState.free_agents:
		if str(p.get("id", "")) == id:
			return p
	return {}


## Every listed player by id, for position and age (Awards).
static func _players() -> Dictionary:
	var out := {}
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			out[str(p["id"])] = p
	return out


## How wide a line of text is set in the game's face.
static func _text_w(text: String, size: int, bold: bool) -> float:
	return (UiKit.BOLD if bold else UiKit.FONT).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func _first(rows: Array) -> Dictionary:
	return rows[0] if not rows.is_empty() else {}


static func _para(text: String) -> Label:
	var l := UiKit.lbl(text, UiKit.SMALL, UiKit.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)
