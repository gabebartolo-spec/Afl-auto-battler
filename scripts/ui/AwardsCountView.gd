class_name AwardsCountView
extends VBoxContainer
## The awards-night count (T5.Q23b), round by round from the votes each round
## really gave (AwardsCount.gd): the Brownlow, or your club's best and fairest.
## Watched live (the games read out on their own, round after round) or a
## round at a time; the board holds only the votes read so far. It adds up the
## record and never works out a vote. Presentation only.

## The position moved: a game or a round read, the break, Watch or Pause.
signal moved

## A game's votes, read out live: a round of nine about 3.7 s with the pause
## after it, the season about 90 s.
const GAME_PACE := 0.3
## The pause after each round, live, before the next is read.
const ROUND_PAUSE := 1.0
## Your club's count, live: one game at a time.
const CLUB_PACE := 2.0
## The Rising Star, held this long before a live count reads on.
const BREAK_HOLD := 4.0
## Players on the board; level players at the cut are summed up under it.
const BOARD_ROWS := 10
## A board row is read, not tapped. Your club's count: one line.
const ROW_H := 32
## The Brownlow's: the name over the club.
const ROW_H_STACK := 46
const RANK_W := 34.0
const TOTAL_W := 30.0
const GAIN_W := 30.0
## A game's votes: the points, right-aligned so the names line up.
const POINTS_W := 12.0
const ART_H := 120.0
const BREAK_ART_H := 96.0

## "votes" (the Brownlow) or "bf" (your club's best and fairest).
var kind := "votes"
## AwardsCount.brownlow_steps or club_steps.
var steps: Array = []
## Steps read in full, and games read of the next.
var rounds := 0
var matches := 0
## The Rising Star is presented after this many rounds (-1: no break).
var break_after := -1
var at_break := false
var break_seen := false
## Read on by itself (Watch) or a round a tap.
var live := false
## Skip to the result was taken: the final board alone, no round on it.
var skipped := false
## The stored final placings (ids): who is listed first among level totals.
var order: Array = []
var title := ""
var subtitle := ""
## The honour's picture on the opening card (HonoursArt id), and its lines.
var art := ""
var year := 0
var opening: Array = []
## The Rising Star ({id, club}) and the round he was nominated in.
var rising: Dictionary = {}
var rising_round := 0

var _page: VBoxContainer
var _clock: Timer
## id -> total on the board last drawn, so a total counts up from there.
var _shown := {}


func _init() -> void:
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page = UiKit.vbox(8)
	_page.name = "CountPage"
	add_child(_page)
	_clock = Timer.new()
	_clock.name = "CountClock"
	_clock.one_shot = true
	_clock.timeout.connect(_tick)
	add_child(_clock)


## Where the count has got to, for the save (season_awards["count_at"]).
func position() -> Dictionary:
	return {"round": rounds, "match": matches, "break": break_seen, "at_break": at_break,
			"skipped": skipped}


## Back to a saved position, never past the end.
func restore(at: Dictionary) -> void:
	rounds = clampi(int(at.get("round", 0)), 0, steps.size())
	matches = 0
	if rounds < steps.size():
		matches = clampi(int(at.get("match", 0)), 0, maxi(0, (steps[rounds]["matches"] as Array).size() - 1))
	break_seen = bool(at.get("break", false)) or (break_after >= 0 and (rounds > break_after
			or (rounds == break_after and matches > 0)))
	at_break = bool(at.get("at_break", false)) and break_after >= 0 and rounds == break_after \
			and matches == 0 and not break_seen
	skipped = bool(at.get("skipped", false)) and rounds >= steps.size()


## Every round read and the break past: the board is the final count.
func done() -> bool:
	return rounds >= steps.size() and not at_break


## The round being read, or the one just read (-1 before Round 1).
func current() -> int:
	return rounds if matches > 0 else rounds - 1


## Watch, or Pause a count being watched.
func watch() -> void:
	if live:
		live = false
		_clock.stop()
		_changed()
		return
	if done():
		return
	live = true
	_tick()


## A round at a tap: the rest of the round being read, or the next round
## whole (the break is a stop of its own). A count being watched stops.
func next_round() -> void:
	live = false
	_clock.stop()
	_to_boundary()
	_changed()


## The round being read, or the next, at once; a count being watched reads on.
func skip_round() -> void:
	_to_boundary()
	_changed()
	if live:
		if done():
			live = false
			_changed()
		else:
			_clock.start(_wait())


## The rest of the count at once: the final board.
func skip_all() -> void:
	live = false
	_clock.stop()
	rounds = steps.size()
	matches = 0
	at_break = false
	break_seen = true
	skipped = true
	_changed()


func _tick() -> void:
	if not live:
		return
	_item()
	if done():
		live = false
	_changed()
	if live:
		_clock.start(_wait())


## How long, live, before the next game is read.
func _wait() -> float:
	if at_break:
		return BREAK_HOLD
	if kind == "bf":
		return CLUB_PACE
	if matches == 0:
		return ROUND_PAUSE + GAME_PACE  # a round just ended
	return GAME_PACE


func _break_due() -> bool:
	return break_after > 0 and not break_seen and not at_break and rounds == break_after and matches == 0


## One game read, or the break begun or ended.
func _item() -> void:
	if at_break:
		at_break = false
		break_seen = true
		return
	if _break_due():
		at_break = true
		return
	if rounds >= steps.size():
		return
	matches += 1
	if matches >= (steps[rounds]["matches"] as Array).size():
		rounds += 1
		matches = 0


func _to_boundary() -> void:
	if at_break:
		at_break = false
		break_seen = true
	elif _break_due():
		at_break = true
		return
	if rounds < steps.size():
		rounds += 1
		matches = 0


func _changed() -> void:
	render()
	moved.emit()


# ---------------------------------------------------------------------------
# The page.

func render() -> void:
	UiKit.clear(_page)
	var head := UiKit.heading(title, UiKit.TITLE)
	head.name = "CountTitle"
	head.add_theme_color_override("font_color", StatsSide.mine_ink())
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(head)
	_page.add_child(_words(subtitle, UiKit.MUTED, UiKit.SECONDARY))
	if at_break:
		_break_card()
		_board_section("After %s" % _short(str(steps[rounds - 1]["label"])))
		return
	if rounds == 0 and matches == 0:
		_opening_card()
		return
	# The last round read stays up under the final count; Skip to the result
	# shows the final board alone.
	_round_heading()
	if not skipped:
		_latest_game()
	_board_section("Final count" if done() else "Leaderboard")
	if kind == "votes" and not skipped:
		_earlier_games()
	var now := {}
	for r in AwardsCount.board(steps, rounds, matches, order):
		now[str(r["id"])] = int(r["total"])
	_shown = now


func _opening_card() -> void:
	var holder := CenterContainer.new()
	holder.name = "CountArt"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(HonoursArt.view(art, ART_H, GameState.my_club, 0, title))
	_page.add_child(holder)
	for line in opening:
		var l := _words(str(line), UiKit.TEXT, UiKit.BODY)
		l.name = "CountOpening"
		_page.add_child(l)


## "Round 7" big, "of 24 · game 4 of 9" under it; a final by its name.
func _round_heading() -> void:
	var big := "Final count"
	var small := "All %d %s read" % [steps.size(), "rounds" if kind == "votes" else "games"]
	if not skipped and current() >= 0:
		var st: Dictionary = steps[current()]
		big = _short(str(st["label"]))
		var parts := []
		if kind == "votes":
			parts.append("of %d" % steps.size())
			var extra := str(st["label"]).get_slice(" · ", 1) if str(st["label"]).contains(" · ") else ""
			if extra != "":
				parts.append(extra)
			var n := (st["matches"] as Array).size()
			if matches > 0:
				parts.append("game %d of %d" % [matches, n])
			else:
				parts.append("all %d games" % n)
		else:
			var m: Dictionary = (st["matches"] as Array)[0]
			parts.append("v %s" % GameDB.club_name(str(m["away"])))
		small = " · ".join(parts)
	var h := UiKit.heading(big, UiKit.RATING)
	h.name = "CountRound"
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(h)
	var s := _words(small, UiKit.MUTED, UiKit.SECONDARY)
	s.name = "CountRoundLine"
	_page.add_child(s)


## The game just read: its clubs, then its votes, the most first.
func _latest_game() -> void:
	var at := current()
	if at < 0:
		return
	var ms: Array = steps[at]["matches"]
	var idx := (matches if at == rounds else ms.size()) - 1
	if idx < 0 or idx >= ms.size():
		return
	var game := _game(ms[idx], kind == "votes")
	game.name = "CountLatest"
	_page.add_child(game)
	UiKit.reveal(game)


## Every other game read in the round, in the order they were read.
func _earlier_games() -> void:
	var at := current()
	if at < 0:
		return
	var ms: Array = steps[at]["matches"]
	var upto := (matches if at == rounds else ms.size()) - 1
	if upto <= 0:
		return
	var box := UiKit.vbox(8)
	box.name = "CountEarlier"
	box.add_child(_gap(10))
	box.add_child(_words("Earlier in %s" % _short(str(steps[at]["label"])), UiKit.TEXT, UiKit.HEADING, true))
	for j in range(upto):
		box.add_child(_game(ms[j], true))
	_page.add_child(box)


## One game: "Carlton v Essendon", then its votes a line each, the most first
## ("3  Name  Club"), your club's names in bold and each club's short name in
## that club's ink.
func _game(m: Dictionary, teams: bool) -> Control:
	var v := UiKit.vbox(2)
	if teams:
		var line := HFlowContainer.new()
		line.add_theme_constant_override("h_separation", 0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(UiKit.line(GameDB.club_name(str(m["home"])), UiKit.SECONDARY, StatsSide.code_ink(str(m["home"])), true))
		line.add_child(UiKit.line(" v ", UiKit.SECONDARY, UiKit.MUTED))
		line.add_child(UiKit.line(GameDB.club_name(str(m["away"])), UiKit.SECONDARY, StatsSide.code_ink(str(m["away"])), true))
		v.add_child(line)
	var votes := UiKit.vbox(0)
	votes.name = "Votes"
	votes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list: Array = m.get("votes", [])
	if list.is_empty():
		votes.add_child(UiKit.line("No votes", UiKit.BODY, UiKit.MUTED))
	for vote in list:
		var club := str(vote[2])
		var one := UiKit.hbox(6)
		one.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pts := UiKit.line(str(int(vote[1])), UiKit.BODY, UiKit.TEXT, true)
		pts.custom_minimum_size.x = POINTS_W
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		one.add_child(pts)
		one.add_child(UiKit.line(GameState.award_name({"id": str(vote[0])}), UiKit.BODY,
				UiKit.TEXT, club == GameState.my_club))
		if kind == "votes":
			one.add_child(UiKit.line(GameDB.club_short(club), UiKit.SECONDARY, StatsSide.code_ink(club),
					club == GameState.my_club))
		votes.add_child(one)
	v.add_child(votes)
	return v


## The board from the votes read so far, level totals sharing a rank. A tie is
## never split at the cut; your club's best is shown under it when he is not
## on it.
func _board_section(heading: String) -> void:
	var rows := AwardsCount.board(steps, rounds, matches, order)
	var box := UiKit.vbox(0)
	box.name = "CountBoard"
	box.add_child(_gap(10))
	var h := _words(heading, UiKit.TEXT, UiKit.HEADING, true)
	h.name = "CountBoardHeading"
	box.add_child(h)
	box.add_child(_gap(4))
	_page.add_child(box)
	if rows.is_empty():
		box.add_child(_words("No votes yet.", UiKit.MUTED, UiKit.BODY))
		return
	var shown := mini(BOARD_ROWS, rows.size())
	while shown < rows.size() and int(rows[shown]["total"]) == int(rows[shown - 1]["total"]) \
			and int(rows[shown - 1]["total"]) != int(rows[0]["total"]):
		shown -= 1
	var mine_on := false
	for i in range(shown):
		var row := _row(rows[i], i % 2 == 1)
		row.name = "CountRow_%d" % (i + 1)
		box.add_child(row)
		mine_on = mine_on or str(rows[i]["club"]) == GameState.my_club
	if shown < rows.size():
		var next := int(rows[shown]["total"])
		var level := 0
		for r in rows.slice(shown):
			if int(r["total"]) == next:
				level += 1
		if shown + level > BOARD_ROWS:
			var more := _words("%d more on %d %s." % [level, next, "vote" if next == 1 else "votes"],
					UiKit.MUTED, UiKit.SECONDARY)
			more.name = "CountMore"
			box.add_child(more)
	if kind == "votes" and not mine_on:
		for r in rows:
			if str(r["club"]) == GameState.my_club:
				box.add_child(_gap(8))
				box.add_child(_words("Your leading vote-getter", UiKit.MUTED, UiKit.SECONDARY))
				var row := _row(r, false)
				row.name = "CountRowMine"
				box.add_child(row)
				break


## One player on the board: rank, name, total, and what the round being read
## gave him. On the Brownlow's board his club, and "ineligible" for a player
## suspended this season, sit under his name so the name shows whole on a
## phone; your club's own count leaves the club off (every name is yours).
func _row(r: Dictionary, band: bool) -> Control:
	var club := str(r["club"])
	var id := str(r["id"])
	var mine := club == GameState.my_club
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flat := StatsSide.row_style(club, band, mine)
	flat.content_margin_left = StatsSide.RULE_INSET
	flat.content_margin_right = 4
	p.add_theme_stylebox_override("panel", flat)
	p.custom_minimum_size.y = ROW_H_STACK if kind == "votes" else ROW_H
	var h := UiKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var rank := UiKit.line(("=%d" if bool(r.get("shared", false)) else "%d") % int(r["rank"]),
			UiKit.BODY, UiKit.TEXT, true)
	rank.name = "Rank"
	rank.custom_minimum_size.x = RANK_W
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(rank)
	var who := UiKit.ellipsis(GameState.award_name({"id": id}), UiKit.NAME, UiKit.TEXT,
			mine or int(r["rank"]) == 1)
	who.name = "Name"
	if kind == "votes":
		var both := UiKit.vbox(0)
		both.mouse_filter = Control.MOUSE_FILTER_IGNORE
		both.alignment = BoxContainer.ALIGNMENT_CENTER
		both.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		both.add_child(who)
		var under := UiKit.hbox(6)
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c := UiKit.line(GameDB.club_short(club), UiKit.SECONDARY, StatsSide.code_ink(club), mine)
		c.name = "Club"
		under.add_child(c)
		if _ineligible(id):
			var flag := UiKit.line("ineligible", UiKit.SECONDARY, UiKit.MUTED)
			flag.name = "Ineligible"
			under.add_child(flag)
		both.add_child(under)
		h.add_child(both)
	else:
		who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(who)
	var total := UiKit.line(str(int(r["total"])), StatsAwards.FIGURE_SIZE, UiKit.TEXT, true)
	total.name = "Total"
	total.custom_minimum_size.x = TOTAL_W
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(total)
	var gain := UiKit.line("+%d" % int(r["last"]) if int(r["last"]) > 0 and not skipped else "",
			UiKit.SECONDARY, UiKit.MUTED)
	gain.name = "Gain"
	gain.custom_minimum_size.x = GAIN_W
	gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(gain)
	var was := int(_shown.get(id, int(r["total"])))
	if was != int(r["total"]):
		UiKit.count_up(total, int(r["total"]), func(n: int) -> String: return str(n),
				UiKit.Motion.DUR_COUNT, was)
	return p


## The Rising Star, presented at the break in the count.
func _break_card() -> void:
	var box := UiKit.vbox(6)
	box.name = "CountRisingStar"
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(HonoursArt.view("rising_star", BREAK_ART_H, str(rising.get("club", "")), 0, "Rising Star"))
	box.add_child(holder)
	box.add_child(UiKit.heading("Rising Star", UiKit.TITLE))
	var club := str(rising.get("club", ""))
	box.add_child(_words(GameState.award_name(rising), StatsSide.ink(club), UiKit.TITLE, true))
	var line := GameDB.club_name(club)
	if rising_round > 0:
		line += " · nominated in Round %d" % rising_round
	box.add_child(_words(line, UiKit.TEXT, UiKit.BODY))
	_page.add_child(box)
	UiKit.reveal(box)


## Is he ineligible for the Brownlow (suspended this season)?
func _ineligible(id: String) -> bool:
	var season: Season = GameState.season
	if season != null:
		for code in season.lists:
			for p in season.lists[code]:
				if str(p["id"]) == id:
					return bool(p.get("brownlow_ineligible", false))
	var q = GameDB.player_by_id(id)
	return q is Dictionary and bool((q as Dictionary).get("brownlow_ineligible", false))


## "Round 7 · Gather Round" -> "Round 7".
static func _short(label: String) -> String:
	return label.get_slice(" · ", 0)


static func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _words(text: String, colour: Color, font_size := UiKit.BODY, bold := false) -> Label:
	var label := UiKit.lbl(text, font_size, colour, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
