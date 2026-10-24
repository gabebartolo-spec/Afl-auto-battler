class_name DraftTradeSheet
extends RefCounted
## Draft night's trade sheet (director 2026-10-25: "implement live trading of
## picks on draft night"). Picks only - this draft's and the next two drafts' -
## never players; the night waits while the sheet is open, there is no clock.
## Offers rivals have put to you for the pick you are on the clock with sit at
## the top with Accept and No thanks; below, the club you are trading with,
## what you give and get, their answer in words (never a value) and Make trade;
## then the picks to add from, yours or theirs. One sheet, one job.

var _scene: Control
var _draft: Draft
var _on_change: Callable
var _overlay: Control
var _body: VBoxContainer
var _club := ""
var _mine: Array = []
var _theirs: Array = []
var _side := "theirs"
var _choosing := false
var _notice := ""


## Open the sheet over `scene`. `on_change` runs after any trade or accepted
## offer, so the screen catches up (the pick on the clock may have moved).
static func open(scene: Control, draft: Draft, on_change: Callable) -> Control:
	var sheet := DraftTradeSheet.new()
	sheet._scene = scene
	sheet._draft = draft
	sheet._on_change = on_change
	sheet._club = sheet._first_rival()
	var box := UiKit.modal_box(scene, 560.0, 0.0)
	sheet._overlay = box["overlay"]
	sheet._overlay.name = "TradeSheet"
	sheet._body = box["body"]
	var close := UiKit.btn("Back to the draft", UiKit.BODY, true)
	close.name = "TradeSheetClose"
	close.custom_minimum_size.y = 48
	close.pressed.connect(func(): sheet._overlay.queue_free())
	(box["footer"] as VBoxContainer).add_child(close)
	sheet._overlay.set_meta("sheet", sheet)   # keeps the sheet alive with its overlay
	sheet._build()
	return sheet._overlay


## The club that last put an offer to you, else the club on the clock after
## you, else the first rival.
func _first_rival() -> String:
	var open := GameState.open_trade_offers()
	if not open.is_empty():
		return str(GameState.trade_offers[int(open[-1])]["club"])
	for i in range(int(_draft.pick_index), _draft.pick_sequence.size()):
		var code := str(_draft.pick_sequence[i])
		if code != GameState.my_club:
			return code
	for code in GameDB.active_clubs(GameState.season_year):
		if code != GameState.my_club:
			return str(code)
	return ""


func _build() -> void:
	if not is_instance_valid(_body):
		return
	UiKit.clear(_body)
	_body.add_child(UiKit.lbl("Trade picks", 20, UiKit.TEXT, true))
	var rule := _para("Only picks change hands tonight: this draft's and the next two drafts'. The night waits while you deal.",
			13, UiKit.MUTED)
	rule.name = "TradeSheetRule"
	_body.add_child(rule)
	if _notice != "":
		var n := _para(_notice, 14, UiKit.EMPH)
		n.name = "TradeNotice"
		_body.add_child(n)
	if _choosing:
		_club_sheet()
		return
	_offers()
	var who := UiKit.hbox(8)
	var with_l := UiKit.ellipsis("Trading with %s" % GameDB.club_name(_club), UiKit.NAME,
			UiKit.club_name_colour(UiKit.club_ink(_club)), true)
	with_l.name = "TradingWith"
	with_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(with_l)
	var change := UiKit.btn("Change club", 14)
	change.name = "TradeClub"
	change.custom_minimum_size = Vector2(0, 44)
	change.pressed.connect(func():
		_choosing = true
		_build())
	who.add_child(change)
	_body.add_child(who)
	var stance := {"rebuilding": "They guard their picks and want the future.",
			"building": "They weigh this draft and the next evenly.",
			"contending": "They would rather the player who helps now than a pick."}
	var cycle := _para("%s. %s" % [TeamRating.category(GameState.club_phase(_club)),
			str(stance.get(GameState.club_phase(_club), ""))], 13, UiKit.MUTED)
	cycle.name = "TradeClubPhase"
	_body.add_child(cycle)
	_body.add_child(UiKit.spacer(4))
	_package("You give", _mine, "GiveRow_", "Nothing yet: add one of your picks below.")
	_package("You get", _theirs, "GetRow_", "Nothing yet: add one of their picks below.")
	var verdict := GameState.evaluate_trade(_club, _mine, _theirs)
	var empty := _mine.is_empty() or _theirs.is_empty()
	var answer := _para("Put a pick on each side.", 14, UiKit.MUTED) if empty else \
			_para(str(verdict["reason"]), 14, UiKit.GOOD if bool(verdict["ok"]) else UiKit.TEXT)
	answer.name = "TradeVerdict"
	if not empty:
		answer.set_meta("code", str(verdict.get("code", "")))
	_body.add_child(answer)
	if not empty and not bool(verdict["ok"]):
		var counter := GameState.trade_counter(_club, _mine, _theirs)
		if not counter.is_empty():
			var ask := _para(str(counter["say"]), 14, UiKit.TEXT)
			ask.name = "TradeCounter"
			_body.add_child(ask)
			var apply := UiKit.btn("Make that change", 14)
			apply.name = "TradeCounterApply"
			apply.custom_minimum_size = Vector2(0, 44)
			apply.pressed.connect(func():
				_mine = (counter["mine"] as Array).duplicate()
				_theirs = (counter["theirs"] as Array).duplicate()
				_build())
			_body.add_child(apply)
	var go := UiKit.btn("Make trade", UiKit.NAME, true)
	go.name = "MakeTrade"
	go.custom_minimum_size = Vector2(0, 48)
	go.disabled = not bool(verdict["ok"])
	go.pressed.connect(func():
		var r := GameState.make_trade(_club, _mine, _theirs)
		_notice = str(r["reason"])
		if bool(r["ok"]):
			_mine = []
			_theirs = []
			_changed()
		_build())
	_body.add_child(go)
	_body.add_child(UiKit.spacer(UiKit.SECTION - 6))
	var sides := UiKit.hbox(4)
	for t in [["theirs", "Their picks"], ["mine", "Your picks"]]:
		var tb := UiKit.tab(str(t[1]), _side == str(t[0]))
		tb.name = "TradeSide_" + str(t[0])
		tb.pressed.connect(func():
			_side = str(t[0])
			_build())
		sides.add_child(tb)
	_body.add_child(sides)
	if _side == "mine":
		_picks(GameState.my_club, _mine, "Mine_")
	else:
		_picks(_club, _theirs, "Their_")


## Offers rivals have put to you tonight, each with Accept and No thanks.
func _offers() -> void:
	var open := GameState.open_trade_offers()
	if open.is_empty():
		return
	_body.add_child(UiKit.lbl("Offers for your pick", UiKit.BODY, UiKit.EMPH, true))
	for i in open:
		var text := _para(GameState.trade_offer_text(i), 14, UiKit.TEXT)
		text.name = "Offer_%d" % i
		_body.add_child(text)
		var row := UiKit.hbox(8)
		for b in [["Accept", "OfferAccept_%d" % i, true], ["No thanks", "OfferDecline_%d" % i, false]]:
			var btn := UiKit.btn(str(b[0]), 14)
			btn.name = str(b[1])
			btn.custom_minimum_size = Vector2(0, 44)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var accept: bool = b[2]
			btn.pressed.connect(func():
				if accept:
					var r := GameState.accept_trade_offer(i)
					_notice = str(r["reason"])
					if bool(r["ok"]):
						_changed()
				else:
					GameState.decline_trade_offer(i)
				_build())
			row.add_child(btn)
		_body.add_child(row)
	_body.add_child(UiKit.spacer(UiKit.SECTION - 6))


## One side of the trade: each pick on its own line with Remove.
func _package(title: String, ids: Array, prefix: String, none: String) -> void:
	_body.add_child(UiKit.lbl(title, UiKit.BODY, UiKit.EMPH, true))
	if ids.is_empty():
		_body.add_child(_para(none, 13, UiKit.MUTED))
		return
	for id in ids.duplicate():
		var row := UiKit.hbox(8)
		row.name = prefix + str(id).replace(":", "_")
		var pk := GameState.pick_asset(str(id))
		var what := UiKit.ellipsis(pick_label(pk) if not pk.is_empty() else "-", 14, UiKit.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(what)
		var rm := UiKit.btn("Remove", UiKit.SECONDARY)
		rm.name = "Remove"
		rm.custom_minimum_size = Vector2(88, 44)
		rm.pressed.connect(func():
			ids.erase(id)
			_build())
		row.add_child(rm)
		_body.add_child(row)


## Every other club, two to a row, with where it is in its cycle.
func _club_sheet() -> void:
	_body.add_child(UiKit.lbl("Trade with", UiKit.BODY, UiKit.EMPH, true))
	var options := []
	for code in GameDB.active_clubs(GameState.season_year):
		if code != GameState.my_club:
			options.append([code, "%s · %s" % [GameDB.club_name(code),
					TeamRating.category(GameState.club_phase(code))]])
	_body.add_child(UiKit.choice_grid("TradeClubChoice", options, _club, 2, func(code: String):
		if code != _club:
			_theirs = []
		_club = code
		_choosing = false
		_build()))


## A club's picks still to be used tonight and its next two drafts', earliest
## first, each a button to add or take out; under each, how the club got it.
func _picks(code: String, chosen: Array, prefix: String) -> void:
	var picks := GameState.club_picks(code)
	if picks.is_empty():
		_body.add_child(_para("%s have no picks left to trade." % GameDB.club_name(code), 13, UiKit.MUTED))
		return
	for pk in picks:
		var id := str(pk["id"])
		var b := UiKit.btn(pick_label(pk, false), 14)
		b.name = prefix + id.replace(":", "_")
		b.custom_minimum_size = Vector2(0, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UiKit.set_selected(b, chosen.has(id))
		b.pressed.connect(func():
			if chosen.has(id):
				chosen.erase(id)
			elif chosen.size() < GameState.TRADE_MAX:
				chosen.append(id)
			_build())
		_body.add_child(b)
		var story := _para(GameState.pick_story(int(pk["year"]), int(pk["round"]), str(pk["origin"])), 12, UiKit.TEXT)
		story.name = "PickStory_" + id.replace(":", "_")
		_body.add_child(story)


## "Pick 7 tonight, first round" / "2028 first round (via Carlton)".
static func pick_label(pk: Dictionary, with_via := true) -> String:
	var nth: String = ["first", "second", "third", "fourth"][clampi(int(pk["round"]) - 1, 0, 3)]
	var text := ""
	if int(pk["year"]) == GameState.season_year and int(pk.get("spot", 0)) > 0:
		text = "Pick %d tonight, %s round" % [int(pk["spot"]), nth]
	else:
		text = "%d %s round" % [int(pk["year"]), nth]
	if with_via and str(pk["origin"]) != str(pk["owner"]):
		text += " (via %s)" % GameDB.club_name(str(pk["origin"]))
	return text


func _changed() -> void:
	if _on_change.is_valid():
		_on_change.call()


func _para(text: String, fs: int, colour: Color) -> Label:
	var l := UiKit.lbl(text, fs, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
