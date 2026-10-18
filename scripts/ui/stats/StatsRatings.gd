class_name StatsRatings
extends RefCounted
## Season stats > Ratings (director, 2026-10-11): every player in the comp
## ranked by Player rating a game, the season's total under it. Your own
## players carry your club's colour. A one-game wonder can't top it: a player
## is ranked once he has played at least half his club's games, and the rest
## follow below, still listed. One list, built once; it scrolls with the page.

## A row: thumb-sized at every width.
const ROW_H := 60.0
## How far in a row's words start from its edge (_row offsets its content by this).
const ROW_INSET := 8
const RANK_W := 30.0
const FIG_W := 72.0
## Rows built with the section, then rows added each frame after it.
const FIRST := 40
const BATCH := 25


static func build(host: Control) -> Control:
	var v := UiKit.vbox(8)
	v.name = "StatsRatings"
	var wide: bool = host.call("wide")
	# The heading and its rule start where the rows' words start, never on the
	# section's own edge (it sat flush against the viewport edge).
	var intro := MarginContainer.new()
	intro.name = "RatingsIntro"
	intro.add_theme_constant_override("margin_left", ROW_INSET)
	intro.add_theme_constant_override("margin_right", ROW_INSET)
	v.add_child(intro)
	var intro_box := UiKit.vbox(8)
	intro.add_child(intro_box)
	intro_box.add_child(UiKit.heading("Player ratings", UiKit.HEADING))
	var rule := UiKit.lbl("Ranked by rating a game among players who have played at least half their club's games. Everyone else is listed below them.",
			UiKit.SECONDARY, UiKit.MUTED)
	rule.name = "RatingsRule"
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_box.add_child(rule)
	var list := rows()
	if list.is_empty():
		var none := UiKit.lbl("No one has played a game yet.", UiKit.BODY, UiKit.MUTED)
		none.name = "RatingsEmpty"
		v.add_child(none)
		return v
	var body := UiKit.vbox(0)
	body.name = "RatingsList"
	v.add_child(body)
	# The rows in order, with the line where the ranked players end.
	var items := []
	var rank := 0
	var split := false
	for row in list:
		var ranked := bool(row["qualified"])
		if not ranked and not split:
			split = true
			items.append({})
		if ranked:
			rank += 1
		items.append({"row": row, "rank": rank if ranked else 0})
	# The first screenful at once; the rest a batch a frame after it, so the
	# section opens at once with 500-odd players in it.
	body.set_meta("filled", false)
	_add_items(host, body, items, 0, FIRST, wide)
	if items.size() > FIRST:
		_fill(host, body, items, wide)
	else:
		body.set_meta("filled", true)
	return v


static func _add_items(host: Control, body: Control, items: Array, from: int, to: int, wide: bool) -> void:
	for i in range(from, mini(to, items.size())):
		var it: Dictionary = items[i]
		if it.is_empty():
			var gap := UiKit.lbl("Fewer than half their club's games", UiKit.SECONDARY, UiKit.MUTED, true)
			gap.name = "RatingsUnranked"
			body.add_child(UiKit.spacer(10))
			body.add_child(gap)
			body.add_child(UiKit.rule())
		else:
			body.add_child(_row(host, it["row"], int(it["rank"]), wide))


## The rest of the list, BATCH rows a frame, until it is all there ("filled");
## stops if the section is rebuilt or closed meanwhile.
static func _fill(host: Control, body: Control, items: Array, wide: bool) -> void:
	var at := FIRST
	while at < items.size():
		await host.get_tree().process_frame
		if not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_inside_tree():
			return
		_add_items(host, body, items, at, at + BATCH, wide)
		at += BATCH
	body.set_meta("filled", true)


## Every player who has played this season: {id, name, club, games, total,
## per_game, qualified}. Ranked players first, best rating a game first; the
## rest after them in the same order. Ties: the bigger season, then the name.
static func rows() -> Array:
	var index := StatsPlayers._index()
	var book: Dictionary = GameState.season_stats
	var out := []
	for id in book:
		var entry: Dictionary = book[id]
		var games := int(entry.get("games", 0))
		if games <= 0:
			continue
		var p: Dictionary = index.get(str(id), {})
		var club := str(p.get("club", ""))
		if club == "":
			club = str(entry.get("club", ""))
		var total := StatsPlayers.season_rating(entry.get("s", {}) as Dictionary)
		var name := GameDB.player_display_name(p) if not p.is_empty() \
				else GameDB.player_display_name_by_id(str(id), "Player")
		out.append({"id": str(id), "name": name, "club": club, "games": games, "total": total,
				"per_game": total / float(games), "qualified": games * 2 >= club_games(club)})
	out.sort_custom(func(a, b):
		if bool(a["qualified"]) != bool(b["qualified"]):
			return bool(a["qualified"])
		if not is_equal_approx(float(a["per_game"]), float(b["per_game"])):
			return float(a["per_game"]) > float(b["per_game"])
		if not is_equal_approx(float(a["total"]), float(b["total"])):
			return float(a["total"]) > float(b["total"])
		return str(a["name"]) < str(b["name"]))
	return out


## How many games a club has played this season (the ladder's P). A player
## with no club on record counts as having had a full season to play.
static func club_games(club: String) -> int:
	if GameState.season == null:
		return 0
	var ladder: Dictionary = GameState.season.ladder
	if ladder.has(club):
		return int((ladder[club] as Dictionary).get("p", 0))
	var most := 0
	for c in ladder:
		most = maxi(most, int((ladder[c] as Dictionary).get("p", 0)))
	return most


## One player (director, 2026-10-11: whose team he plays for at a glance, and
## a real hierarchy): rank, his club's guernsey, his name in bold with the
## club's name beside it, his games and season under them in one quiet line,
## and the rating a game big at the right. A tap opens his season.
static func _row(host: Control, row: Dictionary, rank: int, wide: bool) -> Control:
	var club := str(row["club"])
	var mine := club == GameState.my_club
	var b := Button.new()
	b.name = "RatingRow_" + str(row["id"])
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	StatsPlayers._editorial(b, mine)
	var id := str(row["id"])
	b.pressed.connect(func(): StatsPlayers.open_player(host, id))
	var h := UiKit.hbox(10)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = ROW_INSET
	h.offset_right = -10
	b.add_child(h)
	var rk := _cell(str(rank) if rank > 0 else "", RANK_W, UiKit.TEXT, UiKit.SECONDARY, HORIZONTAL_ALIGNMENT_RIGHT, true)
	rk.name = "Rank"
	h.add_child(rk)
	if club != "":
		var mark := UiKit.club_marker(club, 24.0)
		mark.name = "ClubMark"
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(mark)
	var who := UiKit.vbox(2)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(who)
	var top := UiKit.hbox(8)
	who.add_child(top)
	var name_text := str(row["name"])
	var club_text := GameDB.club_short(club) if club != "" else ""
	var name_w := UiKit.BOLD.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.NAME).x + 2.0
	var club_w := UiKit.BOLD.get_string_size(club_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SECONDARY).x + 2.0
	# Beside his name while both fit; a long name puts the club on the line
	# under it, never cut to a letter.
	var room := float(host.call("content_width")) - (16.0 + RANK_W + 24.0 + FIG_W + 40.0)
	var beside := name_w + 8.0 + club_w <= room
	var nm := UiKit.ellipsis(name_text, UiKit.NAME, UiKit.TEXT, true)
	nm.name = "Name"
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not beside else Control.SIZE_SHRINK_BEGIN
	if beside:
		nm.custom_minimum_size.x = name_w
	top.add_child(nm)
	# His club in its own colour where it reads (the guernsey beside him says the
	# side where it does not); yours in bold.
	var club_ink := StatsSide.ink(club)
	if beside:
		var cl := UiKit.line(club_text, UiKit.SECONDARY, club_ink, mine)
		cl.name = "Club"
		top.add_child(cl)
	var games := int(row["games"])
	if not beside and club_text != "":
		# A long name: the club on a line of its own under it, in words.
		var cl := UiKit.line(club_text, UiKit.SECONDARY, club_ink, mine)
		cl.name = "Club"
		who.add_child(cl)
	var quiet := UiKit.ellipsis("%d %s · %d total" % [games, "game" if games == 1 else "games",
			int(round(float(row["total"])))], UiKit.SECONDARY, UiKit.MUTED)
	quiet.name = "Season"
	who.add_child(quiet)
	var pg := UiKit.figure("%.1f" % float(row["per_game"]), UiKit.NUMBER, UiKit.TEXT)
	pg.name = "PerGame"
	pg.custom_minimum_size.x = FIG_W
	pg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pg)
	b.custom_minimum_size.y = ROW_H if beside else ROW_H + 16.0
	for n in h.find_children("*", "Control", true, false):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func _cell(text: String, w: float, col: Color, fs: int, align: int, bold := false) -> Label:
	var l := UiKit.line(text, fs, col, bold)
	l.custom_minimum_size.x = w
	l.horizontal_alignment = align
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	return l
