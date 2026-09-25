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
		hv.add_child(_para("Anything you leave undecided is re-signed for two seasons if the cap allows.", 12, UiKit.MUTED))
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
	_root.add_child(UiKit.scroll(body))
	match _tab:
		"contracts":
			_contracts(body)
		"agents":
			_agents(body)
		"trade":
			_trade(body)


func _contracts(body: VBoxContainer) -> void:
	var expiring := Contracts.expiring(GameState.my_list)
	body.add_child(UiKit.lbl("Out of contract  (%d)" % expiring.size(), 15, UiKit.GOLD, true))
	if expiring.is_empty():
		body.add_child(_para("Nobody is out of contract this year.", 13, UiKit.MUTED))
	for p in expiring:
		var card := _player_card(p, "%d OVR  ·  %d POT  ·  age %d  ·  now %d, asks %d" % [
				int(p["overall"]), int(p.get("potential", p["overall"])), int(p.get("age", 0)),
				int(p.get("salary", 0)), Contracts.asking_salary(p)])
		body.add_child(card)
		var row := UiKit.hbox(4)
		row.name = "Contract_" + str(p["id"])
		(card.get_child(0) as VBoxContainer).add_child(row)
		if bool(p.get("resigned", false)):
			row.add_child(UiKit.line("Re-signed: %d more seasons" % (int(p["contract_years"]) - 1), 13, UiKit.GOOD, true))
			continue
		for years in [1, 2, 3, 4]:
			var b := UiKit.btn("%d yr" % years, 13)
			b.name = "Resign_%d" % years
			b.custom_minimum_size = Vector2(0, 40)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func():
				_notice = str(GameState.resign_player(str(p["id"]), years)["reason"])
				_build())
			row.add_child(b)
		var rel := UiKit.btn("Release", 13)
		rel.name = "Release"
		rel.custom_minimum_size = Vector2(0, 40)
		rel.pressed.connect(func():
			_notice = str(GameState.release_player(str(p["id"]))["reason"])
			_build())
		row.add_child(rel)
	body.add_child(UiKit.lbl("Whole list", 15, UiKit.GOLD, true))
	var sorted := GameState.my_list.duplicate()
	sorted.sort_custom(func(a, b): return int(a.get("salary", 0)) > int(b.get("salary", 0)))
	for p in sorted:
		body.add_child(_para("%s  ·  %d OVR  ·  salary %d  ·  %d season%s left" % [
				GameDB.player_display_name(p), int(p["overall"]), int(p.get("salary", 0)),
				int(p.get("contract_years", 1)), "" if int(p.get("contract_years", 1)) == 1 else "s"], 12, UiKit.TEXT))


func _agents(body: VBoxContainer) -> void:
	var fas := GameState.free_agents.duplicate()
	fas.sort_custom(func(a, b): return Contracts.worth(a) > Contracts.worth(b))
	if fas.is_empty():
		body.add_child(_para("No free agents right now. Rivals let players go when the season ends.", 13, UiKit.MUTED))
	for p in fas:
		var card := _player_card(p, "%d OVR  ·  %d POT  ·  age %d  ·  asks %d  ·  from %s" % [
				int(p["overall"]), int(p.get("potential", p["overall"])), int(p.get("age", 0)),
				Contracts.asking_salary(p), GameDB.club_short(str(p.get("released_by", "")))])
		var row := UiKit.hbox(4)
		row.name = "Agent_" + str(p["id"])
		(card.get_child(0) as VBoxContainer).add_child(row)
		for years in [1, 2, 3]:
			var b := UiKit.btn("Sign %d yr" % years, 13)
			b.name = "Sign_%d" % years
			b.custom_minimum_size = Vector2(0, 40)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func():
				_notice = str(GameState.sign_free_agent(str(p["id"]), years)["reason"])
				_build())
			row.add_child(b)
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
	body.add_child(UiKit.lbl("Their list (pick up to 2)", 15, UiKit.GOLD, true))
	body.add_child(_pick_grid(GameState.season.lists.get(_trade_club, []), _theirs, "Their_"))
	body.add_child(UiKit.lbl("Your list (pick up to 2)", 15, UiKit.GOLD, true))
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
