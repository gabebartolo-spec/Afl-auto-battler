class_name StatsRatings
extends RefCounted
## Season stats > Ratings (director, 2026-10-11): every player in the comp
## ranked by Player rating a game, the season's total under it. Your own
## players carry your club's colour. A one-game wonder can't top it: a player
## is ranked once he has played at least half his club's games, and the rest
## follow below, still listed. One list, built once; it scrolls with the page.

## Wide-screen columns (a phone shows the figure and its line under it).
const RANK_W := 34.0
const CLUB_W := 150.0
const GAMES_W := 70.0
const FIG_W := 104.0
const ROW_H_WIDE := 36.0
const ROW_H_PHONE := 56.0
## Rows built with the section, then rows added each frame after it.
const FIRST := 40
const BATCH := 25


static func build(host: Control) -> Control:
	var v := UiKit.vbox(8)
	v.name = "StatsRatings"
	var wide: bool = host.call("wide")
	v.add_child(UiKit.heading("Player ratings", UiKit.HEADING))
	var rule := UiKit.lbl("Ranked by rating a game among players who have played at least half their club's games. Everyone else is listed below them.",
			UiKit.SECONDARY, UiKit.MUTED)
	rule.name = "RatingsRule"
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rule)
	var list := rows()
	if list.is_empty():
		var none := UiKit.lbl("No one has played a game yet.", UiKit.BODY, UiKit.MUTED)
		none.name = "RatingsEmpty"
		v.add_child(none)
		return v
	var body := UiKit.vbox(0)
	body.name = "RatingsList"
	v.add_child(body)
	if wide:
		body.add_child(_header())
		body.add_child(UiKit.rule())
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


static func _header() -> Control:
	var h := UiKit.hbox(0)
	h.name = "RatingsHeader"
	h.custom_minimum_size.y = 36
	h.add_child(_cell("#", RANK_W, UiKit.MUTED, UiKit.SMALL, HORIZONTAL_ALIGNMENT_RIGHT))
	h.add_child(StatsPlayers._fixed(12.0))
	var who := UiKit.line("Player", UiKit.SMALL, UiKit.MUTED)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(who)
	h.add_child(_cell("Club", CLUB_W, UiKit.MUTED, UiKit.SMALL, HORIZONTAL_ALIGNMENT_LEFT))
	h.add_child(_cell("Games", GAMES_W, UiKit.MUTED, UiKit.SMALL, HORIZONTAL_ALIGNMENT_RIGHT))
	h.add_child(_cell("A game", FIG_W, UiKit.MUTED, UiKit.SMALL, HORIZONTAL_ALIGNMENT_RIGHT))
	h.add_child(_cell("Season", FIG_W, UiKit.MUTED, UiKit.SMALL, HORIZONTAL_ALIGNMENT_RIGHT))
	h.add_child(StatsPlayers._fixed(8.0))
	for n in h.get_children():
		(n as Control).size_flags_vertical = Control.SIZE_SHRINK_END
	return h


## One player: a tap opens his season (StatsPlayers.open_player).
static func _row(host: Control, row: Dictionary, rank: int, wide: bool) -> Control:
	var club := str(row["club"])
	var mine := club == GameState.my_club
	var b := Button.new()
	b.name = "RatingRow_" + str(row["id"])
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	StatsPlayers._editorial(b, mine)
	var id := str(row["id"])
	b.pressed.connect(func(): StatsPlayers.open_player(host, id))
	var h := UiKit.hbox(10 if not wide else 0)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8 if not wide else 0
	h.offset_right = -8
	b.add_child(h)
	var rk := _cell(str(rank) if rank > 0 else "", RANK_W if wide else 28.0, UiKit.MUTED, UiKit.SECONDARY,
			HORIZONTAL_ALIGNMENT_RIGHT)
	rk.name = "Rank"
	h.add_child(rk)
	if wide:
		h.add_child(StatsPlayers._fixed(12.0))
	# The band carries your colour; the figure stays readable on it.
	var fig_col := UiKit.TEXT
	var games := int(row["games"])
	if wide:
		var who := UiKit.ellipsis(str(row["name"]), UiKit.NAME, UiKit.TEXT, mine)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(who)
		h.add_child(_cell(GameDB.club_short(club) if club != "" else "", CLUB_W, UiKit.MUTED, UiKit.SECONDARY,
				HORIZONTAL_ALIGNMENT_LEFT))
		h.add_child(_cell(str(games), GAMES_W, UiKit.MUTED, UiKit.SECONDARY, HORIZONTAL_ALIGNMENT_RIGHT))
		var pg := _cell("%.1f" % float(row["per_game"]), FIG_W, fig_col, UiKit.NAME, HORIZONTAL_ALIGNMENT_RIGHT, true)
		pg.name = "PerGame"
		h.add_child(pg)
		var tot := _cell("%d" % int(round(float(row["total"]))), FIG_W, UiKit.MUTED, UiKit.SECONDARY,
				HORIZONTAL_ALIGNMENT_RIGHT)
		tot.name = "Season"
		h.add_child(tot)
		h.add_child(StatsPlayers._fixed(8.0))
		b.custom_minimum_size.y = ROW_H_WIDE
	else:
		var who := UiKit.vbox(0)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(who)
		who.add_child(UiKit.name_label(str(row["name"]), UiKit.NAME, UiKit.TEXT, true))
		who.add_child(UiKit.line("%s · %d %s" % [club, games, "game" if games == 1 else "games"],
				UiKit.SECONDARY, UiKit.MUTED))
		var fig_box := UiKit.vbox(0)
		fig_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(fig_box)
		var fig := UiKit.figure("%.1f" % float(row["per_game"]), UiKit.NUMBER, fig_col)
		fig.name = "PerGame"
		fig.custom_minimum_size.x = 64
		fig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fig_box.add_child(fig)
		var tot := UiKit.line("%d in all" % int(round(float(row["total"]))), UiKit.SECONDARY, UiKit.MUTED)
		tot.name = "Season"
		tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fig_box.add_child(tot)
		b.custom_minimum_size.y = ROW_H_PHONE
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
