extends Control
## Trades & Contracts: the off-season, between the Grand Final and the
## national draft. Re-sign or release your expiring players, sign free
## agents rivals let go, and trade with any club. Everything is priced
## against the salary cap.

var _root: VBoxContainer
var _tab := "contracts"
var _notice := ""
var _trade_club := ""
var _mine: Array = []     # your player ids in the trade (up to 2)
var _theirs: Array = []   # their player ids (up to 2)
var _scroll_box: ScrollContainer
var _scroll_tab := ""
var _scroll_positions := {}
var _release_overlay: Control
var _talk_overlay: Control
var _talk_id := ""
var _talk_fa := false   # talking to a free agent rather than your own player
var _offer_salary := 0
var _offer_years := 0
var _talk_reply := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.season == null:
		Router.replace("main")
		return
	GameState.open_offseason()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_insets(margin, 12)
	add_child(margin)
	_root = UiKit.vbox(8)
	margin.add_child(_root)
	for code in GameDB.active_clubs(GameState.season_year):
		if code != GameState.my_club:
			_trade_club = code
			break
	get_viewport().size_changed.connect(func():
		if is_inside_tree():
			_build())
	_build()


func _build() -> void:
	if is_instance_valid(_scroll_box):
		_scroll_positions[_scroll_tab] = _scroll_box.scroll_vertical
	UiKit.clear(_root)
	_root.add_child(UiKit.top_bar("Trades & Contracts", true))
	var head := UiKit.panel(UiKit.PANEL, 10, 8)
	_root.add_child(head)
	var hv := UiKit.vbox(4)
	head.add_child(hv)
	var room := GameState.cap_room()
	hv.add_child(UiKit.lbl("Payroll %d of %d  ·  cap room %d  ·  list %d" % [GameState.my_payroll(),
			GameState.salary_cap, room, GameState.my_list.size()], 15,
			UiKit.GOOD if room >= 0 else UiKit.BAD, true))
	if not GameState.offseason_open():
		hv.add_child(_para("The off-season is closed: trades and contracts open when the season ends, until the national draft starts.", 13, UiKit.MUTED))
	else:
		hv.add_child(_para("Out-of-contract players you leave unsigned are re-signed for two seasons if the cap allows.", 12, UiKit.MUTED))
	if _notice != "":
		hv.add_child(_para(_notice, 13, UiKit.GOOD))
	var tabs := UiKit.hbox(4)
	_root.add_child(tabs)
	for t in [["contracts", "Contracts"], ["agents", "Free agents (%d)" % GameState.free_agents.size()], ["trade", "Trade"]]:
		var b := UiKit.tab(str(t[1]), _tab == str(t[0]))
		b.name = "Tab_" + str(t[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			_tab = str(t[0])
			_notice = ""
			_build())
		tabs.add_child(b)
	var body := UiKit.vbox(6)
	_scroll_box = UiKit.scroll(body)
	_scroll_tab = _tab
	_root.add_child(_scroll_box)
	match _tab:
		"contracts":
			_contracts(body)
		"agents":
			_agents(body)
		"trade":
			_trade(body)
	_restore_scroll(_scroll_box, int(_scroll_positions.get(_tab, 0)))


func _restore_scroll(scroll: ScrollContainer, offset: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = offset


func _contracts(body: VBoxContainer) -> void:
	var expiring := Contracts.expiring(GameState.my_list)
	body.add_child(UiKit.lbl("Out of contract  (%d)" % expiring.size(), 15, UiKit.EMPH, true))
	if expiring.is_empty():
		body.add_child(_para("Nobody is out of contract this year.", 13, UiKit.MUTED))
	for p in expiring:
		var want := Contracts.wants(p)
		var card := _player_card(p, "%d OVR  ·  %d POT  ·  age %d  ·  on %d, wants %d for %d seasons" % [
				int(p["overall"]), int(p.get("potential", p["overall"])), int(p.get("age", 0)),
				int(p.get("salary", 0)), int(want["salary"]), int(want["years"])])
		body.add_child(card)
		var row := UiKit.hbox(4)
		row.name = "Contract_" + str(p["id"])
		(card.get_child(0) as VBoxContainer).add_child(row)
		if bool(p.get("resigned", false)):
			row.add_child(UiKit.line("Re-signed: %d more seasons at %d" % [int(p["contract_years"]) - 1,
					int(p.get("salary", 0))], 13, UiKit.GOOD, true))
			continue
		var talks: Dictionary = p.get("talks", {})
		if bool(talks.get("walked", false)):
			row.add_child(UiKit.line("Talks broke down: he'll test free agency", 13, UiKit.BAD, true))
			continue
		if talks.has("counter"):
			(card.get_child(0) as VBoxContainer).add_child(_para("He'd sign for %d over %d season%s." % [
					int(talks["counter"]), int(talks["years"]), "" if int(talks["years"]) == 1 else "s"], 12, UiKit.TEXT))
		var talk := UiKit.btn("Talk contract", 13)
		talk.name = "Negotiate"
		talk.custom_minimum_size = Vector2(0, 44)
		talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		talk.pressed.connect(_open_talks.bind(str(p["id"])))
		row.add_child(talk)
		var rel := UiKit.btn("Release", 13)
		rel.name = "Release"
		rel.custom_minimum_size = Vector2(0, 44)
		rel.pressed.connect(_confirm_release.bind(p))
		row.add_child(rel)
	body.add_child(UiKit.lbl("Whole list", 15, UiKit.EMPH, true))
	var sorted := GameState.my_list.duplicate()
	sorted.sort_custom(func(a, b): return int(a.get("salary", 0)) > int(b.get("salary", 0)))
	for p in sorted:
		body.add_child(_para("%s  ·  %d OVR  ·  salary %d  ·  %d season%s left" % [
				GameDB.player_display_name(p), int(p["overall"]), int(p.get("salary", 0)),
				int(p.get("contract_years", 1)), "" if int(p.get("contract_years", 1)) == 1 else "s"], 12, UiKit.TEXT))


func _confirm_release(p: Dictionary) -> void:
	if is_instance_valid(_release_overlay):
		return
	var box := UiKit.modal_box(self, 440.0, 0.0)
	_release_overlay = box["overlay"]
	_release_overlay.name = "ReleaseConfirmation"
	box["body"].add_child(_para("Release %s?" % GameDB.player_display_name(p), 20, UiKit.TEXT))
	box["body"].add_child(_para("He will leave your list and become a free agent.", 14, UiKit.TEXT))
	var release := UiKit.btn("Release player", 16, true)
	release.name = "ConfirmRelease"
	release.custom_minimum_size.y = 44
	release.pressed.connect(func():
		_close_release()
		_notice = str(GameState.release_player(str(p["id"]))["reason"])
		_build())
	box["footer"].add_child(release)
	var cancel := UiKit.btn("Cancel", 16)
	cancel.name = "CancelRelease"
	cancel.custom_minimum_size.y = 44
	cancel.pressed.connect(_close_release)
	box["footer"].add_child(cancel)


func _close_release() -> void:
	if is_instance_valid(_release_overlay):
		_release_overlay.queue_free()
	_release_overlay = null


func handle_back() -> bool:
	if is_instance_valid(_talk_overlay):
		_close_talks()
		return true
	if not is_instance_valid(_release_overlay):
		return false
	_close_release()
	return true


## Contract talks: propose a salary and a term; he accepts, counters or, after
## too many failed offers, walks. Nothing is signed until he accepts.
func _open_talks(player_id: String, free_agent := false) -> void:
	_talk_fa = free_agent
	_talk_id = player_id
	var p := _talk_player()
	if p.is_empty():
		return
	var want := Contracts.wants(p)
	var talks: Dictionary = p.get("talks", {})
	_talk_reply = ""
	var premium := int(GameState.free_agent_terms(player_id)["premium"]) if free_agent else 0
	_offer_salary = int(talks.get("counter", int(want["salary"]) + premium))
	_offer_years = int(talks.get("years", want["years"]))
	_show_talks()


func _talk_player() -> Dictionary:
	return GameState.free_agent(_talk_id) if _talk_fa else GameState.list_player(_talk_id)


func _show_talks() -> void:
	if is_instance_valid(_talk_overlay):
		_talk_overlay.queue_free()
	var p := _talk_player()
	var want := Contracts.wants(p)
	var talks: Dictionary = p.get("talks", {})
	var terms := GameState.free_agent_terms(_talk_id) if _talk_fa else {}
	var box := UiKit.modal_box(self, 440.0, 0.0)
	_talk_overlay = box["overlay"]
	_talk_overlay.name = "ContractTalks"
	var v: VBoxContainer = box["body"]
	v.add_child(_para(GameDB.player_display_name(p), 20, UiKit.TEXT))
	v.add_child(_para("Age %d  ·  %d OVR  ·  %d POT  ·  on %d now" % [int(p.get("age", 0)), int(p["overall"]),
			int(p.get("potential", p["overall"])), int(p.get("salary", 0))], 13, UiKit.MUTED))
	# For a free agent his terms include what his options add.
	var meet_salary := int(want["salary"]) + int(terms.get("premium", 0))
	v.add_child(_para("He wants %d a season for %d seasons. %s" % [meet_salary, int(want["years"]),
			Contracts.stance(p)], 15, UiKit.TEXT))
	if _talk_fa and GameState.my_list.size() >= Contracts.MAX_LIST:
		v.add_child(_para("Your list is full (%d): release a player first." % Contracts.MAX_LIST, 14, UiKit.BAD))
	for reason in terms.get("reasons", []):
		var why := _para(str(reason), 14, UiKit.BAD if bool(terms["refuse"]) else UiKit.TEXT)
		why.name = "FreeAgentReason"
		v.add_child(why)
	var reply := _talk_reply
	if reply == "" and talks.has("counter"):
		reply = "He'd sign for %d over %d season%s." % [int(talks["counter"]), int(talks["years"]),
				"" if int(talks["years"]) == 1 else "s"]
	if reply != "":
		var r := _para(reply, 15, UiKit.TEXT)
		r.name = "TalksReply"
		v.add_child(r)
	var left := Contracts.MAX_OFFERS - int(talks.get("failed", 0))
	if talks.has("failed") and left == 1:
		v.add_child(_para("One more failed offer and he'll test free agency.", 13, UiKit.BAD))
	v.add_child(UiKit.lbl("Seasons", 14, UiKit.EMPH, true))
	var term_opts := []
	for y in range(1, Contracts.MAX_YEARS + 1):
		term_opts.append([str(y), str(y)])
	v.add_child(UiKit.choice_grid("Term", term_opts, str(_offer_years), 4, func(k: String):
		_offer_years = int(k)
		_show_talks()))
	v.add_child(UiKit.lbl("Salary a season", 14, UiKit.EMPH, true))
	var srow := UiKit.hbox(8)
	v.add_child(srow)
	var less := UiKit.btn("−", 18)
	less.name = "SalaryDown"
	less.custom_minimum_size = Vector2(56, 44)
	less.disabled = _offer_salary <= 1
	less.pressed.connect(func():
		_offer_salary = maxi(1, _offer_salary - 1)
		_show_talks())
	srow.add_child(less)
	var amount := UiKit.lbl(str(_offer_salary), 20, UiKit.TEXT, true)
	amount.name = "SalaryOffer"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(amount)
	var more := UiKit.btn("+", 18)
	more.name = "SalaryUp"
	more.custom_minimum_size = Vector2(56, 44)
	more.pressed.connect(func():
		_offer_salary += 1
		_show_talks())
	srow.add_child(more)
	# Your own player's current salary is already on the books; a free
	# agent's is not.
	var on_books := 0 if _talk_fa else int(p.get("salary", 0))
	var room_after := GameState.cap_room() + on_books - _offer_salary
	var blocked := bool(terms.get("refuse", false)) or (_talk_fa and GameState.my_list.size() >= Contracts.MAX_LIST)
	v.add_child(_para("Cap room after this deal: %d" % room_after, 14, UiKit.TEXT if room_after >= 0 else UiKit.BAD))
	var offer := UiKit.btn("Offer %d for %d season%s" % [_offer_salary, _offer_years, "" if _offer_years == 1 else "s"], 16, true)
	offer.name = "MakeOffer"
	offer.custom_minimum_size.y = 44
	offer.disabled = room_after < 0 or blocked
	offer.pressed.connect(_make_offer.bind(_offer_salary, _offer_years))
	box["footer"].add_child(offer)
	var meet := UiKit.btn("Meet his terms: %d for %d seasons" % [meet_salary, int(want["years"])], 16)
	meet.name = "MeetTerms"
	meet.custom_minimum_size.y = 44
	meet.disabled = GameState.cap_room() + on_books < meet_salary or blocked
	meet.pressed.connect(_make_offer.bind(meet_salary, int(want["years"])))
	box["footer"].add_child(meet)
	var cancel := UiKit.btn("Cancel", 16)
	cancel.name = "CancelTalks"
	cancel.custom_minimum_size.y = 44
	cancel.pressed.connect(_close_talks)
	box["footer"].add_child(cancel)


func _make_offer(salary: int, years: int) -> void:
	var r := GameState.offer_free_agent(_talk_id, salary, years) if _talk_fa \
			else GameState.offer_contract(_talk_id, salary, years)
	if str(r.get("answer", "")) == "counter":
		_talk_reply = str(r["reason"])
		_offer_salary = int(r["salary"])
		_offer_years = years
		_show_talks()
		return
	_close_talks()
	_notice = str(r["reason"])
	_build()


func _close_talks() -> void:
	if is_instance_valid(_talk_overlay):
		_talk_overlay.queue_free()
	_talk_overlay = null


func _agents(body: VBoxContainer) -> void:
	var fas := GameState.free_agents.duplicate()
	fas.sort_custom(func(a, b): return Contracts.worth(a) > Contracts.worth(b))
	if fas.is_empty():
		body.add_child(_para("No free agents right now. Rivals let players go when the season ends.", 13, UiKit.MUTED))
	for p in fas:
		var want := Contracts.wants(p)
		var terms := GameState.free_agent_terms(str(p["id"]))
		var card := _player_card(p, "%d OVR  ·  %d POT  ·  age %d  ·  wants %d for %d seasons  ·  from %s" % [
				int(p["overall"]), int(p.get("potential", p["overall"])), int(p.get("age", 0)),
				int(want["salary"]) + int(terms["premium"]), int(want["years"]),
				GameDB.club_short(str(p.get("released_by", "")))])
		var row := UiKit.hbox(4)
		row.name = "Agent_" + str(p["id"])
		(card.get_child(0) as VBoxContainer).add_child(row)
		var talks: Dictionary = p.get("talks", {})
		if bool(talks.get("walked", false)):
			row.add_child(UiKit.line("Talks broke down: he'll look elsewhere", 13, UiKit.BAD, true))
		else:
			if talks.has("counter"):
				(card.get_child(0) as VBoxContainer).add_child(_para("He'd sign for %d over %d season%s." % [
						int(talks["counter"]), int(talks["years"]), "" if int(talks["years"]) == 1 else "s"], 12, UiKit.TEXT))
			var talk := UiKit.btn("Talk contract", 13)
			talk.name = "FreeAgentTalks"
			talk.custom_minimum_size = Vector2(0, 44)
			talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			talk.pressed.connect(_open_talks.bind(str(p["id"]), true))
			row.add_child(talk)
		body.add_child(card)


func _trade(body: VBoxContainer) -> void:
	var pick := UiKit.option()
	pick.name = "TradeClub"
	pick.custom_minimum_size = Vector2(0, 44)
	for code in GameDB.active_clubs(GameState.season_year):
		if code == GameState.my_club:
			continue
		pick.add_item(GameDB.club_name(code))
		pick.set_item_metadata(pick.item_count - 1, code)
		if code == _trade_club:
			pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int):
		_trade_club = str(pick.get_item_metadata(i))
		_theirs = []
		_build())
	body.add_child(pick)
	var verdict := GameState.evaluate_trade(_trade_club, _mine, _theirs)
	var summary := _para("You give: %s\nYou get: %s\n%s" % [_names(_mine, GameState.my_club),
			_names(_theirs, _trade_club), str(verdict["reason"])], 14,
			UiKit.GOOD if bool(verdict["ok"]) else UiKit.MUTED)
	summary.name = "TradeVerdict"
	body.add_child(summary)
	var go := UiKit.btn("Make trade", 16, true)
	go.name = "MakeTrade"
	go.custom_minimum_size = Vector2(0, 44)
	go.disabled = not bool(verdict["ok"])
	go.pressed.connect(func():
		var r := GameState.make_trade(_trade_club, _mine, _theirs)
		_notice = str(r["reason"])
		if bool(r["ok"]):
			_mine = []
			_theirs = []
		_build())
	body.add_child(go)
	body.add_child(UiKit.lbl("Their list (pick up to 2)", 15, UiKit.EMPH, true))
	body.add_child(_pick_grid(GameState.season.lists.get(_trade_club, []), _theirs, "Their_"))
	body.add_child(UiKit.lbl("Your list (pick up to 2)", 15, UiKit.EMPH, true))
	body.add_child(_pick_grid(GameState.my_list, _mine, "Mine_"))


func _pick_grid(list: Array, chosen: Array, prefix: String) -> Control:
	var v := UiKit.vbox(3)
	var sorted := list.duplicate()
	sorted.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	for p in sorted:
		var id := str(p["id"])
		var on := chosen.has(id)
		var b := UiKit.tab("%s  ·  %s  ·  %d OVR  ·  %d POT  ·  $%d" % [GameDB.player_display_name(p),
				Ratings.role_tag(p), int(p["overall"]), int(p.get("potential", p["overall"])),
				int(p.get("salary", 0))], on)
		b.name = prefix + id
		b.custom_minimum_size = Vector2(0, 40)
		b.clip_text = true
		b.pressed.connect(func():
			if chosen.has(id):
				chosen.erase(id)
			elif chosen.size() < 2:
				chosen.append(id)
			_build())
		v.add_child(b)
	return v


func _names(ids: Array, club: String) -> String:
	var out := []
	for id in ids:
		for p in GameState.season.lists.get(club, []):
			if str(p["id"]) == str(id):
				out.append(GameDB.player_display_name(p))
	return ", ".join(out) if not out.is_empty() else "-"


func _player_card(p: Dictionary, detail: String) -> PanelContainer:
	var card := UiKit.panel(UiKit.PANEL_ALT, 8, 6)
	var v := UiKit.vbox(3)
	card.add_child(v)
	var h := UiKit.hbox(6)
	v.add_child(h)
	h.add_child(UiKit.role_chip(Ratings.role_tag(p)))
	h.add_child(UiKit.ellipsis(GameDB.player_display_name(p), 15, UiKit.TEXT, true))
	v.add_child(_para(detail, 12, UiKit.MUTED))
	return card


func _para(text: String, size: int, colour: Color) -> Label:
	var l := UiKit.lbl(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
