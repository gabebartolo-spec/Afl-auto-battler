extends SceneTree
## godot --headless --path . --script tests/run_awards_count_tests.gd
## Awards night's count (T5.Q23b) on a phone in portrait, 390x844: the
## Brownlow counted a round at a tap and live (Watch, Pause, Skip round, Skip
## to the result), the Rising Star at the halfway break, your club's best and
## fairest game by game with its final, a night left part way picked up again,
## and Back. Every control is pressed with a real tap (tests/tap.gd). The
## season's record is made by hand (tests/award_count_fixture.gd) so the count
## is quick and the same every run; the record a played season leaves is
## proved in tests/test_awards.gd.
## Classes are reached through load() and autoload nodes (a --script runner
## compiles before the autoloads exist).

var _state: Node
var _db: Node
var _checks := 0
var _failures: Array[String] = []
var _host: Control

const Tap := preload("res://tests/tap.gd")
const Fixture := preload("res://tests/award_count_fixture.gd")
const Count := preload("res://scripts/sim/AwardsCount.gd")
const PHONE := Vector2i(390, 844)
## Live, the clock runs this many times faster, so a season reads in seconds.
const FAST := 30.0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _settle(n := 6) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_db = root.get_node("GameDB")
	_state.autosave_enabled = false
	_state.save_path = "user://test_awards_count.save"
	_state.settings_path = "user://test_awards_count.cfg"
	_state.delete_saved_career()
	root.size = PHONE
	await _settle()

	await _t("_test_round_at_a_time")
	await _t("_test_live")
	await _t("_test_club_count")
	await _t("_test_fits_a_phone")
	await _t("_test_resume")
	await _t("_test_back")
	await _t("_test_older_save")

	Engine.time_scale = 1.0
	print(Ran.line("Awards count", self))
	for f in _failures:
		print("  FAIL: " + f)
	quit(1 if not _failures.is_empty() else 0)


# ---------------------------------------------------------------------------
# Helpers

## A Collingwood season with its whole record, and the night opened on it.
func _open() -> Control:
	Engine.time_scale = 1.0
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	Fixture.build(_state, "COL")
	return await _show()


## The night opened over a fresh screen, on the season as it stands.
func _show() -> Control:
	if is_instance_valid(_host):
		_host.free()
	_host = Control.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_host)
	var c: Control = load("res://scripts/ui/SeasonAwards.gd").open(_host)
	await _settle()
	return c


func _find(c: Node, node_name: String) -> Node:
	if c == null or not is_instance_valid(c):
		return null
	return c.find_child(node_name, true, false)


func _text(c: Node, node_name: String) -> String:
	var n = _find(c, node_name)
	return str(n.text) if n != null else ""


## Every label's words under n, in order.
func _words(n: Node) -> String:
	var out := ""
	if n == null or not is_instance_valid(n):
		return out
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out += (l as Label).text + " | "
	return out


func _shown(c: Node, node_name: String) -> bool:
	var n = _find(c, node_name)
	return n != null and (n as CanvasItem).is_visible_in_tree()


func _tap(c: Node, node_name: String) -> String:
	var why: String = await Tap.tap(_find(c, node_name) as Control)
	await _settle(2)
	return why


## Frames until done() is true (the clock running FAST); false if it never is.
func _until(done: Callable, frames := 3000) -> bool:
	for i in range(frames):
		if done.call():
			return true
		await process_frame
	return done.call()


func _name(id: String) -> String:
	return _state.award_name({"id": id})


## The board's first row: [name, total] as drawn, once its total has counted up.
func _top(c: Node) -> Array:
	# A total counts up over UiKit.Motion.DUR_COUNT (0.7 s).
	await create_timer(0.8, true, false, true).timeout
	await _settle(2)
	var row = _find(c, "CountRow_1")
	if row == null:
		return ["", -1]
	return [str(_find(row, "Name").text), int(str(_find(row, "Total").text))]


# ---------------------------------------------------------------------------
# The tests

## A round at a tap: Round 1, Round 2, on to the halfway break and the Rising
## Star, then the next round whole; the board holds only the votes read.
func _test_round_at_a_time() -> void:
	var c := await _open()
	var view = _find(c, "AwardsCount")
	var steps: Array = view.steps
	_check(steps.size() == _state.season.fixture.size(),
			"The Brownlow count reads every home-and-away round (%d)" % steps.size())
	var opening := _words(view)
	_check(opening.contains("read game by game from Round 1") and opening.contains("to win the Coleman Medal"),
			"The night opens on the Brownlow, the Coleman Medal named before it (%s)" % opening.substr(0, 240))
	_check(_text(c, "AwardsNext") == "Next round" and _text(c, "CountWatch") == "Watch"
			and _shown(c, "CountSkipRound") and _shown(c, "CountSkipAll") and _shown(c, "AwardsSkip"),
			"Before the first round: Watch, Skip round, Skip to the result and Next round")
	var why := await _tap(c, "AwardsNext")
	var games := (steps[0]["matches"] as Array).size()
	_check(why == "" and _text(c, "CountRound") == "Round 1"
			and _text(c, "CountRoundLine") == "of %d · all %d games" % [steps.size(), games],
			"A tap on Next round reads Round 1 whole (%s; %s, %s)" % [why, _text(c, "CountRound"), _text(c, "CountRoundLine")])
	var want: Array = Count.board(steps, 1, 0, view.order)
	var top := await _top(c)
	_check(top[0] == _name(str(want[0]["id"])) and top[1] == int(want[0]["total"]),
			"The board holds Round 1's votes only (%s %d)" % [top[0], top[1]])
	var earlier := _find(c, "CountEarlier")
	_check(_find(c, "CountLatest") != null and earlier != null
			and _words(earlier).contains("Earlier in Round 1"),
			"The round's last game leads, the round's other games under the board")
	await _tap(c, "AwardsNext")
	_check(_text(c, "CountRound") == "Round 2", "The next tap reads Round 2 (%s)" % _text(c, "CountRound"))
	var half: int = view.break_after
	for i in range(half - 2):
		await _tap(c, "AwardsNext")
	_check(_text(c, "CountRound") == "Round %d" % half and int(view.rounds) == half,
			"A tap a round reaches Round %d (%s)" % [half, _text(c, "CountRound")])
	await _tap(c, "AwardsNext")
	var star: Dictionary = _state.season_awards["rising_star"][0]
	var card := _words(_find(c, "CountRisingStar"))
	_check(card.contains("Rising Star") and card.contains(_name(str(star["id"])))
			and card.contains("nominated in Round %d" % Fixture.RISING_ROUND)
			and _text(c, "CountBoardHeading") == "After Round %d" % half,
			"At the halfway break the Rising Star is presented over the board (%s)" % card)
	await _tap(c, "AwardsNext")
	_check(_find(c, "CountRisingStar") == null and _text(c, "CountRound") == "Round %d" % (half + 1),
			"Next round after the break reads Round %d" % (half + 1))
	var at: Dictionary = _state.season_awards.get("count_at", {})
	_check(int(at.get("round", -1)) == half + 1 and bool(at.get("break", false)),
			"The night's place is kept as it goes (%s)" % str(at))
	for i in range(steps.size() - half - 1):
		await _tap(c, "AwardsNext")
	var last: Dictionary = steps[steps.size() - 1]
	_check(view.done() and _text(c, "CountRound") == str(last["label"]).get_slice(" · ", 0)
			and _find(c, "CountLatest") != null and _text(c, "CountBoardHeading") == "Final count",
			"The last round read stays up over the final count (%s, %s)" % [_text(c, "CountRound"), _text(c, "CountBoardHeading")])
	var stored: Dictionary = _state.season_awards["brownlow"][0]
	top = await _top(c)
	_check(top[0] == _name(str(stored["id"])) and top[1] == int(stored["votes"]),
			"The count ends on the stored leader (%s %d)" % [top[0], top[1]])
	_check(_text(c, "AwardsNext") == "Reveal winner" and not _shown(c, "CountWatch") and not _shown(c, "CountSkipAll"),
			"With the count read, the one way on is Reveal winner")


## Live: Watch reads the games on by themselves and turns to Pause; Pause
## holds the place; Skip round reads the rest of the round and keeps going;
## the Rising Star break holds, then the count reads on; Skip to the result
## shows the final board, which reveals the stored winner.
func _test_live() -> void:
	var c := await _open()
	var view = _find(c, "AwardsCount")
	Engine.time_scale = FAST
	var why := await _tap(c, "CountWatch")
	_check(why == "" and view.live and _text(c, "CountWatch") == "Pause",
			"Watch reads the count by itself; the button becomes Pause (%s)" % why)
	# Round 1 as it is read, a frame at a time: [game, its line].
	var seen := []
	await _until(func() -> bool:
		if int(view.rounds) == 0 and int(view.matches) > 0 \
				and (seen.is_empty() or int(seen.back()[0]) != int(view.matches)):
			seen.append([int(view.matches), _text(c, "CountRoundLine")])
		return int(view.rounds) > 0)
	var steady := seen.size() >= 3
	for i in range(1, seen.size()):
		steady = steady and int(seen[i][0]) == int(seen[i - 1][0]) + 1 \
				and str(seen[i][1]).ends_with("game %d of %d" % [int(seen[i][0]), (view.steps[0]["matches"] as Array).size()])
	_check(steady, "Live, a round's games are read one at a time (%s)" % str(seen))
	_check(await _until(func() -> bool: return int(view.rounds) >= 3), "Live, the count reads on round after round")
	why = await _tap(c, "CountWatch")
	var at: Dictionary = view.position()
	_check(why == "" and not view.live and _text(c, "CountWatch") == "Resume",
			"Pause stops the count; the button offers Resume (%s)" % why)
	await _settle(30)
	_check(view.position() == at, "A paused count stays where it was (%s, now %s)" % [str(at), str(view.position())])
	await _tap(c, "CountWatch")
	_check(view.live and _text(c, "CountWatch") == "Pause", "Resume reads on")
	Engine.time_scale = 1.0
	var r := int(view.rounds)
	why = await _tap(c, "CountSkipRound")
	_check(why == "" and int(view.rounds) == r + 1 and int(view.matches) <= 1 and view.live,
			"Skip round reads the rest of the round at once and the count keeps going (round %d to %d)" % [r, int(view.rounds)])
	Engine.time_scale = FAST
	_check(await _until(func() -> bool: return view.at_break) and _find(c, "CountRisingStar") != null,
			"Live, the count stops at halfway for the Rising Star")
	_check(await _until(func() -> bool: return not view.at_break and int(view.matches) > 0)
			and _find(c, "CountRisingStar") == null and view.live,
			"After a moment the count reads on by itself")
	Engine.time_scale = 1.0
	why = await _tap(c, "CountSkipAll")
	_check(why == "" and view.done() and not view.live and _text(c, "CountRound") == "Final count"
			and _text(c, "CountBoardHeading") == "Final count" and _find(c, "CountLatest") == null,
			"Skip to the result shows the final board alone (%s)" % why)
	var stored: Dictionary = _state.season_awards["brownlow"][0]
	var top := await _top(c)
	_check(top[0] == _name(str(stored["id"])) and top[1] == int(stored["votes"]),
			"The final board's leader is the stored one (%s %d)" % [top[0], top[1]])
	why = await _tap(c, "AwardsNext")
	var winner: Dictionary = _state.season_awards["brownlow_winner"]
	await _settle()
	_check(why == "" and _words(c).contains(_name(str(winner["id"]))) and _find(c, "AwardsCount") == null,
			"Reveal winner names the stored medallist (%s)" % _name(str(winner["id"])))


## Your club's best and fairest: after the league's awards, its games one at
## a tap, the final last, ending on the stored winner; then the review.
func _test_club_count() -> void:
	var c := await _open()
	await _tap(c, "CountSkipAll")
	for i in range(12):
		var v = _find(c, "AwardsCount")
		if v != null and v.kind == "bf":
			break
		await _tap(c, "AwardsNext")
		await _settle()
	var view = _find(c, "AwardsCount")
	_check(view != null and view.kind == "bf" and _text(c, "CountTitle") == "Copeland Trophy",
			"After the league's awards, Collingwood's Copeland Trophy is counted (%s)" % _text(c, "CountTitle"))
	if view == null:
		return
	_check(_words(view).contains("finals included") and _text(c, "AwardsNext") == "Next game"
			and _shown(c, "CountWatch") and not _shown(c, "CountSkipRound"),
			"The club count reads a game at a tap; Skip round is not offered (%s)" % _text(c, "AwardsNext"))
	var games: int = view.steps.size()
	var first := ""
	for i in range(games):
		await _tap(c, "AwardsNext")
		if i == 0:
			first = _text(c, "CountRoundLine")
	_check(first.begins_with("v ") and _text(c, "CountRound") == Fixture.FINAL_LABEL
			and _text(c, "CountRoundLine") == "v %s" % _db.club_name(Fixture.FINAL_VS)
			and _text(c, "CountBoardHeading") == "Final count",
			"Each game reads against its opponent, the final last (%s; %s)" % [first, _text(c, "CountRound")])
	var stored: Dictionary = _state.season_awards["best_and_fairest"]["COL"][0]
	var top := await _top(c)
	_check(top[0] == _name(str(stored["id"])) and top[1] == int(stored["bf"]),
			"The club count ends on the stored winner (%s %d)" % [top[0], top[1]])
	await _tap(c, "AwardsNext")
	await _settle()
	_check(_words(c).contains(_name(str(stored["id"]))), "Reveal winner presents the club's winner")
	for i in range(6):
		if not is_instance_valid(c):
			break
		await _tap(c, "AwardsNext")
		await _settle()
	_check(not is_instance_valid(c) and bool(_state.season_awards.get("presentation_seen", false))
			and not _state.season_awards.has("count_at"),
			"The night ends on the season review, marked seen")


## Every control at least 48 px tall, on the screen, its words whole, at the
## opening, part way through, live, and at the final board, from 390 down to
## 320 wide; the board never runs off the side.
func _test_fits_a_phone() -> void:
	for size in [PHONE, Vector2i(360, 800), Vector2i(320, 640)]:
		root.size = size
		var c := await _open()
		await _fits(c, size, "the opening")
		await _tap(c, "AwardsNext")
		await _tap(c, "AwardsNext")
		await _fits(c, size, "Round 2")
		await _tap(c, "CountWatch")
		await _fits(c, size, "live")
		await _tap(c, "CountWatch")
		await _fits(c, size, "paused")
		await _tap(c, "CountSkipAll")
		await _fits(c, size, "the final count")
	root.size = PHONE
	await _settle()


func _fits(c: Control, size: Vector2i, when: String) -> void:
	await _settle(3)
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	var bad := []
	var rects := []
	for b in c.find_children("*", "Button", true, false):
		var button := b as Button
		if not button.is_visible_in_tree():
			continue
		var r := button.get_global_rect()
		var font := button.get_theme_font("font")
		var wide := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				button.get_theme_font_size("font_size")).x
		var box := button.get_theme_stylebox("normal")
		var room := r.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
		if r.size.y < 48 or not screen.encloses(r.grow(-0.5)) or wide > room + 0.5:
			bad.append("%s %s h%d w%d text%d" % [button.name, button.text, r.size.y, r.size.x, wide])
		for other in rects:
			if (other as Rect2).grow(-0.5).intersects(r.grow(-0.5)):
				bad.append("%s overlaps" % button.name)
		rects.append(r)
	_check(bad.is_empty(), "At %dx%d, %s: every control 48 px or more, on screen, words whole (%s)" % [size.x, size.y, when, str(bad)])
	var view = _find(c, "AwardsCount")
	var off := []
	if view != null:
		for row in view.find_children("CountRow*", "PanelContainer", true, false):
			var rr := (row as Control).get_global_rect()
			if rr.end.x > size.x + 0.5 or rr.position.x < -0.5:
				off.append(row.name)
			var total := _find(row, "Total") as Control
			if total != null and not rr.grow(0.5).encloses(total.get_global_rect()):
				off.append("%s total" % row.name)
			for part in ["Name", "Club", "Ineligible"]:
				var l := _find(row, part) as Label
				if l == null:
					continue
				var need := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						l.get_theme_font_size("font_size")).x
				if need > l.size.x + 0.5 or not rr.grow(0.5).encloses(l.get_global_rect()):
					off.append("%s %s '%s' %d of %d" % [row.name, part, l.text, l.size.x, need])
	_check(off.is_empty(), "At %dx%d, %s: the board fits the width, every name whole (%s)" % [size.x, size.y, when, str(off)])


## A night left part way is picked up where it was, after a save and a
## reload; a replay starts again from Round 1 and leaves the place alone.
func _test_resume() -> void:
	var c := await _open()
	for i in range(3):
		await _tap(c, "AwardsNext")
	var at: Dictionary = _state.season_awards.get("count_at", {})
	_check(int(at.get("round", -1)) == 3 and int(at.get("stage", -1)) == 0, "Round 3 read, the place is kept (%s)" % str(at))
	_check(_state.save_career(), "The career saves mid count")
	_host.free()
	_check(_state.load_career(), "The career loads")
	c = await _show()
	_check(_text(c, "CountRound") == "Round 3" and _text(c, "AwardsNext") == "Next round",
			"Opened again, the night picks up at Round 3 (%s)" % _text(c, "CountRound"))
	var view = _find(c, "AwardsCount")
	Engine.time_scale = FAST
	await _tap(c, "CountWatch")
	await _until(func() -> bool: return int(view.matches) > 1)
	Engine.time_scale = 1.0
	await _tap(c, "CountWatch")
	var where: Dictionary = view.position()
	_state.save_career()
	_host.free()
	_state.load_career()
	c = await _show()
	view = _find(c, "AwardsCount")
	_check(view != null and int(view.rounds) == int(where["round"]) and int(view.matches) == int(where["match"])
			and not view.live and _text(c, "CountWatch") == "Watch",
			"Paused part way through a round, it picks up on that game (%s, now %s)" % [str(where), str(view.position() if view != null else {})])
	_state.season_awards["presentation_seen"] = true
	var kept: Dictionary = (_state.season_awards.get("count_at", {}) as Dictionary).duplicate()
	c = await _show()
	view = _find(c, "AwardsCount")
	_check(view != null and int(view.rounds) == 0 and _find(c, "CountOpening") != null,
			"A replay starts again from Round 1")
	await _tap(c, "AwardsNext")
	_check(_state.season_awards.get("count_at", {}) == kept, "A replay leaves the kept place alone")


## Skip to season review, by a real tap, ends the night at once and marks it
## seen; so does Android Back on the season review (tests/run_back_nav_tests.gd).
func _test_back() -> void:
	var c := await _open()
	await _tap(c, "AwardsNext")
	var why := await _tap(c, "AwardsSkip")
	await _settle()
	_check(why == "" and not is_instance_valid(c) and bool(_state.season_awards.get("presentation_seen", false))
			and not _state.season_awards.has("count_at"),
			"Skip to season review closes the night, marked seen (%s)" % why)


## A season recorded part way (a save from before the record, or one loaded
## during the season) keeps the winner-by-winner reveal.
func _test_older_save() -> void:
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	Fixture.build(_state, "COL")
	_state.award_counts["from"] = 5
	var c := await _show()
	_check(_find(c, "AwardsCount") == null and _find(c, "CountWatch") == null
			and _text(c, "AwardsNext") == "Reveal winner",
			"Without the whole season's record, the winners are revealed one by one")
	await _tap(c, "AwardsNext")
	var winner: Dictionary = _state.season_awards["brownlow_winner"]
	_check(_words(c).contains(_name(str(winner["id"]))) and _words(c).contains("Final placings"),
			"The reveal names the stored medallist and the placings")
	if is_instance_valid(_host):
		_host.free()
