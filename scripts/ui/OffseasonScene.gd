extends Control
## The off-season between the Grand Final and the national draft: contracts,
## free agency, trades and the club's annual department allocation.

var _root: VBoxContainer
var _tab := "contracts"
var _notice := ""
var _trade_club := ""
var _mine: Array = []     # your player and pick ids in the trade
var _theirs: Array = []   # theirs
var _trade_side := "theirs"   # which list the builder shows to add from
var _choosing_club := false   # the club sheet is open
var _counter_key := ""
var _counter := {}
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
var _fa_sort := "value"
var _fa_sort_desc := true


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
	_root.add_child(UiKit.top_bar("Off-season", true))
	var head := UiKit.panel(UiKit.PANEL, 10, 8)
	_root.add_child(head)
	var hv := UiKit.vbox(4)
	head.add_child(hv)
	var room := GameState.cap_room()
	hv.add_child(UiKit.lbl("Payroll %s of %s  ·  cap room %s  ·  list %d" % [Contracts.money(GameState.my_payroll()),
			Contracts.money(GameState.salary_cap), Contracts.money(room), GameState.my_list.size()], 15,
			UiKit.GOOD if room >= 0 else UiKit.BAD, true))
	if not GameState.offseason_open():
		hv.add_child(_para("The off-season is closed: trades and contracts open when the season ends, until the national draft starts.", 13, UiKit.MUTED))
	else:
		hv.add_child(_para("Out-of-contract players you leave unsigned are re-signed for two seasons if the cap allows.", 12, UiKit.MUTED))
	if _notice != "":
		hv.add_child(_para(_notice, 13, UiKit.GOOD))
	var tabs := UiKit.hbox(4)
	_root.add_child(tabs)
	for t in [["contracts", "Contracts"], ["agents", "Agents"], ["trade", "Trade"], ["budget", "Budget"]]:
		var b := UiKit.tab(str(t[1]), _tab == str(t[0]))
		b.name = "Tab_" + str(t[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			_tab = str(t[0])
			_notice = ""
			_choosing_club = false
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
		"budget":
			_budget(body)
	_restore_scroll(_scroll_box, int(_scroll_positions.get(_tab, 0)))


func _restore_scroll(scroll: ScrollContainer, offset: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = offset


func _budget(body: VBoxContainer) -> void:
	var year := GameState.department_budget_year if GameState.department_budget_year > 0 \
			else GameState.season_year + 1
	body.add_child(UiKit.lbl("Club budget · %d" % year, 17, UiKit.EMPH, true))
	body.add_child(_para(
			"$%.1fm to allocate for the football year. It resets next off-season; there is no bank balance to hoard." \
			% ClubBudget.ANNUAL_M, 13, UiKit.MUTED))
	var spent := GameState.department_budget_spent_m()
	var remaining := GameState.department_budget_remaining_m()
	var summary := UiKit.lbl("$%.1fm allocated  ·  $%.1fm remaining" % [spent, maxf(0.0, remaining)],
			14, UiKit.TEXT, true)
	summary.name = "BudgetSummary"
	body.add_child(summary)
	body.add_child(UiKit.spacer(4))

	for area in ClubBudget.AREA_ORDER:
		var level := GameState.department_budget_level(area)
		var card := UiKit.panel(UiKit.PANEL, 8, 8)
		card.name = "Budget_" + area
		body.add_child(card)
		var v := UiKit.vbox(4)
		card.add_child(v)
		var head := UiKit.hbox(8)
		v.add_child(head)
		var label := UiKit.lbl(str(ClubBudget.AREA_LABEL[area]), 15, UiKit.TEXT, true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(label)
		head.add_child(UiKit.line("%s · $%.1fm" % [
				ClubBudget.level_label(level), ClubBudget.cost_m(level)], 13, UiKit.MUTED, true))

		var current := _para(ClubBudget.benefit_text(area, level), 13, UiKit.TEXT)
		current.name = "BudgetBenefit_" + area
		v.add_child(current)

		var next_text := UiKit.lbl("", 12, UiKit.MUTED)
		next_text.name = "BudgetNext_" + area
		next_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if level < ClubBudget.LEVELS.size() - 1:
			next_text.text = "Raise to %s ($%.1fm): %s" % [
					ClubBudget.level_label(level + 1), ClubBudget.cost_m(level + 1),
					ClubBudget.benefit_text(area, level + 1)]
		else:
			next_text.text = "Maximum funding."
		v.add_child(next_text)

		var controls := UiKit.hbox(6)
		v.add_child(controls)
		var lower := UiKit.btn("Lower", 13)
		lower.name = "BudgetLower_" + area
		lower.custom_minimum_size.y = 44
		lower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lower.disabled = level <= 0
		lower.pressed.connect(_change_budget.bind(area, level - 1))
		controls.add_child(lower)

		var raise := UiKit.btn("Raise", 13)
		raise.name = "BudgetRaise_" + area
		raise.custom_minimum_size.y = 44
		raise.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		raise.disabled = level >= ClubBudget.LEVELS.size() - 1 \
				or not GameState.can_set_department_budget(area, level + 1)
		raise.pressed.connect(_change_budget.bind(area, level + 1))
		controls.add_child(raise)


func _change_budget(area: String, level: int) -> void:
	var result := GameState.set_department_budget(area, level)
	_notice = "" if bool(result.get("ok", false)) else str(result.get("reason", ""))
	_build()


func _contracts(body: VBoxContainer) -> void:
	# A retiring player is in Retiring above, not up for a contract.
	var expiring := Contracts.expiring(GameState.my_list).filter(func(q): return not GameState.retiring_now(q))
	var clubs := GameDB.active_clubs(GameState.season_year).size()
	for c in GameState.compensation:
		if str(c["club"]) == GameState.my_club:
			var got := _para("Compensation: a draft pick %s for losing %s to %s." % [
					Contracts.pick_words(int(c["after"]), clubs), str(c["name"]), GameDB.club_name(str(c["to"]))], 13, UiKit.TEXT)
			got.name = "CompReceived"
			body.add_child(got)
	_retiring(body)
	body.add_child(UiKit.lbl("Out of contract  (%d)" % expiring.size(), 15, UiKit.EMPH, true))
	if expiring.is_empty():
		body.add_child(_para("Nobody is out of contract this year.", 13, UiKit.MUTED))
	for p in expiring:
		var want := Contracts.wants(p)
		var card := _player_card(p, "%d OVR  ·  %d POT  ·  age %d  ·  on %s, wants %s for %d seasons" % [
				int(p["overall"]), int(p.get("potential", p["overall"])), int(p.get("age", 0)),
				Contracts.money(int(p.get("salary", 0))), Contracts.money(int(want["salary"])), int(want["years"])])
		body.add_child(card)
		var row := UiKit.hbox(4)
		row.name = "Contract_" + str(p["id"])
		(card.get_child(0) as VBoxContainer).add_child(row)
		if bool(p.get("resigned", false)):
			row.add_child(UiKit.line("Re-signed: %d more seasons at %s" % [int(p["contract_years"]) - 1,
					Contracts.money(int(p.get("salary", 0)))], 13, UiKit.GOOD, true))
			continue
		var talks: Dictionary = p.get("talks", {})
		if bool(talks.get("walked", false)):
			row.add_child(UiKit.line("Talks broke down: he'll test free agency", 13, UiKit.BAD, true))
			var proj := _para(str(GameState.projected_compensation(p)["reason"]), 12, UiKit.TEXT)
			proj.name = "CompProjection"
			(card.get_child(0) as VBoxContainer).add_child(proj)
			continue
		if talks.has("counter"):
			(card.get_child(0) as VBoxContainer).add_child(_para("He'd sign for %s over %d season%s." % [
					Contracts.money(int(talks["counter"])), int(talks["years"]), "" if int(talks["years"]) == 1 else "s"], 12, UiKit.TEXT))
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
		body.add_child(_para("%s  ·  %d OVR  ·  %s  ·  %d season%s left" % [
				GameDB.player_display_name(p), int(p["overall"]), Contracts.money(int(p.get("salary", 0))),
				int(p.get("contract_years", 1)), "" if int(p.get("contract_years", 1)) == 1 else "s"], 12, UiKit.TEXT))


## Your players retiring at the end of the off-season. A healthy one can be
## asked once to go around again; his answer, and its reason, stays shown.
func _retiring(body: VBoxContainer) -> void:
	var rows: Array = GameState.retiring_players()
	if rows.is_empty():
		return
	body.add_child(UiKit.lbl("Retiring  (%d)" % rows.size(), 15, UiKit.EMPH, true))
	for r in rows:
		var p: Dictionary = r["p"]
		var card := _player_card(p, "%d OVR  ·  age %d  ·  %d games this year" % [
				int(p["overall"]), int(p.get("age", 0)), GameState.season_games(str(p["id"]))])
		card.name = "Retiring_" + str(p["id"])
		body.add_child(card)
		var v := card.get_child(0) as VBoxContainer
		var talk: Dictionary = r["talk"]
		if not talk.is_empty():
			var said := _para(str(talk["reason"]), 13, UiKit.GOOD if bool(talk["stays"]) else UiKit.TEXT)
			said.name = "RetireAnswer"
			v.add_child(said)
		elif bool(r["can_ask"]):
			var ask := UiKit.btn("Ask him to go around again", 13)
			ask.name = "TalkRound"
			ask.custom_minimum_size = Vector2(0, 44)
			ask.pressed.connect(func():
				GameState.talk_round(str(p["id"]))
				_build())
			v.add_child(ask)
		elif p.has("talked_round"):
			v.add_child(_para("He went around again once already: this time he's going.", 12, UiKit.MUTED))


func _confirm_release(p: Dictionary) -> void:
	if is_instance_valid(_release_overlay):
		return
	var box := UiKit.modal_box(self, 440.0, 0.0)
	_release_overlay = box["overlay"]
	_release_overlay.name = "ReleaseConfirmation"
	box["body"].add_child(_para("Release %s?" % GameDB.player_display_name(p), 20, UiKit.TEXT))
	box["body"].add_child(_para("He will leave your list and become a free agent. A delisted player earns no draft pick if he signs elsewhere.", 14, UiKit.TEXT))
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
	if _choosing_club and _tab == "trade":
		_choosing_club = false
		_build()
		return true
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
	_offer_salary = int(talks.get("counter", want["salary"]))
	if free_agent:
		# Start from your standing offer, if you have one on the table.
		for row in GameState.fa_offers(player_id):
			if bool(row["mine"]):
				_offer_salary = int(row["salary"])
				_offer_years = int(row["years"])
	if not free_agent or _offer_years <= 0:
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
	v.add_child(_para("Age %d  ·  %d OVR  ·  %s POT  ·  on %s now" % [int(p.get("age", 0)), int(p["overall"]),
			str(GameState.pot_view(p)["text"]), Contracts.money(int(p.get("salary", 0)))], 13, UiKit.MUTED))
	# For a free agent his terms include what his options add.
	var meet_salary := int(want["salary"]) + int(terms.get("premium", 0))
	v.add_child(_para("He wants %s a season for %d seasons. %s" % [Contracts.money(meet_salary), int(want["years"]),
			Contracts.stance(p)], 15, UiKit.TEXT))
	if _talk_fa and GameState.my_list.size() >= Contracts.MAX_LIST:
		v.add_child(_para("Your list is full (%d): release a player first." % Contracts.MAX_LIST, 14, UiKit.BAD))
	for reason in terms.get("reasons", []):
		var why := _para(str(reason), 14, UiKit.BAD if bool(terms["refuse"]) else UiKit.TEXT)
		why.name = "FreeAgentReason"
		v.add_child(why)
	if _talk_fa:
		_offers_table(v)
	var reply := _talk_reply
	if reply == "" and talks.has("counter"):
		reply = "He'd sign for %s over %d season%s." % [Contracts.money(int(talks["counter"])), int(talks["years"]),
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
	less.disabled = _offer_salary <= Contracts.SENIOR_MIN_2027
	less.pressed.connect(func():
		_offer_salary = maxi(Contracts.SENIOR_MIN_2027, _offer_salary - Contracts.SALARY_STEP)
		_show_talks())
	srow.add_child(less)
	var amount := UiKit.lbl(Contracts.money(_offer_salary), 20, UiKit.TEXT, true)
	amount.name = "SalaryOffer"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(amount)
	var more := UiKit.btn("+", 18)
	more.name = "SalaryUp"
	more.custom_minimum_size = Vector2(56, 44)
	more.pressed.connect(func():
		_offer_salary += Contracts.SALARY_STEP
		_show_talks())
	srow.add_child(more)
	# Your own player's current salary is already on the books; a free
	# agent's is not.
	var on_books := 0 if _talk_fa else int(p.get("salary", 0))
	var room_after := GameState.cap_room() + on_books - _offer_salary
	var blocked := bool(terms.get("refuse", false)) or (_talk_fa and GameState.my_list.size() >= Contracts.MAX_LIST)
	v.add_child(_para("Cap room after this deal: %s" % Contracts.money(room_after), 14, UiKit.TEXT if room_after >= 0 else UiKit.BAD))
	var final := _talk_fa and GameState.fa_market_stage(_talk_id) == "final"
	var offer := UiKit.btn("%s %s for %d season%s" % ["Final offer:" if final else "Offer", Contracts.money(_offer_salary), _offer_years,
			"" if _offer_years == 1 else "s"], 16, true)
	offer.name = "MakeOffer"
	offer.custom_minimum_size.y = 44
	offer.disabled = room_after < 0 or blocked
	offer.pressed.connect(_make_offer.bind(_offer_salary, _offer_years))
	box["footer"].add_child(offer)
	var meet := UiKit.btn("Meet his terms: %s for %d seasons" % [Contracts.money(meet_salary), int(want["years"])], 16)
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


## The offers on the table, his view of each, and where the talks stand.
## Four short columns that fit a phone: club, salary, years, his view.
func _offers_table(v: VBoxContainer) -> void:
	var rows := GameState.fa_offers(_talk_id)
	v.add_child(UiKit.lbl("Offers on the table", 14, UiKit.EMPH, true))
	if rows.is_empty():
		v.add_child(_para("No club has made an offer.", 13, UiKit.MUTED))
	else:
		var grid := GridContainer.new()
		grid.name = "OffersTable"
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 4)
		for h in ["Club", "Salary", "Years", "His view"]:
			grid.add_child(UiKit.line(h, 12, UiKit.MUTED))
		for row in rows:
			var who := "You" if bool(row["mine"]) else GameDB.club_short(str(row["club"]))
			var club := UiKit.line(who, 13, UiKit.TEXT, bool(row["leading"]))
			club.name = "Offer_" + str(row["club"])
			grid.add_child(club)
			grid.add_child(UiKit.line(Contracts.money(int(row["salary"])), 13, UiKit.TEXT, bool(row["leading"])))
			grid.add_child(UiKit.line(str(row["years"]), 13, UiKit.TEXT, bool(row["leading"])))
			var view := _para(("Leading. " if bool(row["leading"]) else "") + str(row["view"]), 12, UiKit.TEXT)
			view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			view.custom_minimum_size.x = 120
			grid.add_child(view)
		v.add_child(grid)
	var log: Array = GameState.free_agent(_talk_id).get("market_log", [])
	if not log.is_empty():
		var said := _para("After your offer: " + " ".join(PackedStringArray(log)), 13, UiKit.TEXT)
		said.name = "RivalResponses"
		v.add_child(said)
	var stage := GameState.fa_market_stage(_talk_id)
	var note := "Rivals see an offer once you make it, and can answer it once. Your second offer is final." if stage == "open" \
			else ("Your next offer is final: rivals answer, then he decides." if stage == "final" else "")
	if note != "" and not rows.is_empty():
		v.add_child(_para(note + " Otherwise he decides when free agency closes.", 12, UiKit.MUTED))


func _make_offer(salary: int, years: int) -> void:
	var r := GameState.offer_free_agent(_talk_id, salary, years) if _talk_fa \
			else GameState.offer_contract(_talk_id, salary, years)
	if str(r.get("answer", "")) == "table":
		_talk_reply = str(r["reason"])
		# Your offer stands; the stepper starts from it for any final offer.
		_offer_salary = salary
		_offer_years = years
		_show_talks()
		return
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
	var controls := UiKit.hbox(4)
	controls.name = "FreeAgentSort"
	for entry in [["value", "Value"], ["overall", "OVR"], ["potential", "POT"], ["age", "Age"]]:
		var key := str(entry[0])
		var label := str(entry[1])
		if key == _fa_sort:
			label += " ↓" if _fa_sort_desc else " ↑"
		var sort_btn := UiKit.tab(label, key == _fa_sort)
		sort_btn.name = "AgentSort_" + key
		sort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sort_btn.pressed.connect(func():
			if _fa_sort == key:
				_fa_sort_desc = not _fa_sort_desc
			else:
				_fa_sort = key
				_fa_sort_desc = true
			_build())
		controls.add_child(sort_btn)
	body.add_child(controls)
	fas.sort_custom(func(a, b):
		var av: float
		var bv: float
		match _fa_sort:
			"overall":
				av = float(a.get("overall", 0))
				bv = float(b.get("overall", 0))
			"potential":
				av = float(GameState.pot_view(a)["mid"])
				bv = float(GameState.pot_view(b)["mid"])
			"age":
				av = float(a.get("age", 0))
				bv = float(b.get("age", 0))
			_:
				av = Contracts.worth(a)
				bv = Contracts.worth(b)
		if av == bv:
			return str(a.get("id", "")) < str(b.get("id", ""))
		return av > bv if _fa_sort_desc else av < bv)
	if fas.is_empty():
		body.add_child(_para("No free agents right now. Rivals let players go when the season ends.", 13, UiKit.MUTED))
	for p in fas:
		var want := Contracts.wants(p)
		var card := _player_card(p, "%d OVR  ·  %s POT  ·  age %d  ·  wants %s for %d seasons  ·  from %s" % [
				int(p["overall"]), str(GameState.pot_view(p)["text"]), int(p.get("age", 0)),
				Contracts.money(int(want["salary"])), int(want["years"]),
				GameDB.club_short(str(p.get("released_by", "")))])
		var offers := GameState.fa_offers(str(p["id"]))
		if not offers.is_empty():
			var bits := PackedStringArray()
			for o in offers.slice(0, 3):
				bits.append("%s %s for %d" % ["you" if bool(o["mine"]) else GameDB.club_short(str(o["club"])), Contracts.money(int(o["salary"])), int(o["years"])])
			var line := "Offers: " + ", ".join(bits) + (" and %d more" % (offers.size() - 3) if offers.size() > 3 else "")
			(card.get_child(0) as VBoxContainer).add_child(_para(line + ".", 12, UiKit.TEXT))
		var row := UiKit.hbox(4)
		row.name = "Agent_" + str(p["id"])
		(card.get_child(0) as VBoxContainer).add_child(row)
		var talks: Dictionary = p.get("talks", {})
		if bool(talks.get("walked", false)):
			row.add_child(UiKit.line("Talks broke down: he'll look elsewhere", 13, UiKit.BAD, true))
		else:
			if talks.has("counter"):
				(card.get_child(0) as VBoxContainer).add_child(_para("He'd sign for %s over %d season%s." % [
						Contracts.money(int(talks["counter"])), int(talks["years"]), "" if int(talks["years"]) == 1 else "s"], 12, UiKit.TEXT))
			var talk := UiKit.btn("Talk contract", 13)
			talk.name = "FreeAgentTalks"
			talk.custom_minimum_size = Vector2(0, 44)
			talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			talk.pressed.connect(_open_talks.bind(str(p["id"]), true))
			row.add_child(talk)
		body.add_child(card)


## The trade builder, one screen for a phone: who you're trading with, what
## you give and get (tap Remove to take something out), their answer and
## Make trade; then one list at a time - theirs or yours, picks first - to
## add from. Nothing here shows a value: their answer is in words.
func _trade(body: VBoxContainer) -> void:
	if _choosing_club:
		_trade_club_sheet(body)
		return
	_offers(body)
	var who := UiKit.hbox(8)
	who.add_child(UiKit.ellipsis("Trading with %s" % GameDB.club_name(_trade_club), 16, UiKit.TEXT, true))
	who.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var change := UiKit.btn("Change club", 14)
	change.name = "TradeClub"
	change.custom_minimum_size = Vector2(0, 44)
	change.pressed.connect(func():
		_choosing_club = true
		_build())
	who.add_child(change)
	body.add_child(who)
	var phase := GameState.club_phase(_trade_club)
	var stance := {"rebuilding": "are rebuilding: they guard young talent and want players for the future.",
			"building": "are building: they weigh this season and the future evenly.",
			"contending": "are contending: they want players who help them win now."}
	var cycle := _para("%s %s" % [GameDB.club_name(_trade_club), str(stance.get(phase, ""))], 13, UiKit.MUTED)
	cycle.name = "TradeClubPhase"
	body.add_child(cycle)
	body.add_child(UiKit.spacer(4))
	_package(body, "You give", _mine, GameState.my_club, "GiveRow_",
			"Nothing yet: add from your list below.")
	_package(body, "You get", _theirs, _trade_club, "GetRow_",
			"Nothing yet: add from their list below.")
	var verdict := GameState.evaluate_trade(_trade_club, _mine, _theirs)
	var empty := _mine.is_empty() or _theirs.is_empty()
	var shopping := _mine.size() == 1 and _theirs.is_empty()
	var prompt := "Add what you want back, or put it on the trade table." if shopping else "Put something on each side."
	var answer := _para(prompt if empty else str(verdict["reason"]), 14,
			UiKit.GOOD if bool(verdict["ok"]) else UiKit.MUTED)
	answer.name = "TradeVerdict"
	body.add_child(answer)
	if not empty and not bool(verdict["ok"]):
		var counter := _counter_for(_trade_club, _mine, _theirs)
		if not counter.is_empty():
			var ask := _para(str(counter["say"]), 14, UiKit.TEXT)
			ask.name = "TradeCounter"
			body.add_child(ask)
			var apply := UiKit.btn("Make that change", 14)
			apply.name = "TradeCounterApply"
			apply.custom_minimum_size = Vector2(0, 44)
			apply.pressed.connect(func():
				_mine = (counter["mine"] as Array).duplicate()
				_theirs = (counter["theirs"] as Array).duplicate()
				_build())
			body.add_child(apply)
	var go := UiKit.btn("Make trade", 16, true)
	go.name = "MakeTrade"
	go.custom_minimum_size = Vector2(0, 48)
	go.disabled = not bool(verdict["ok"])
	go.pressed.connect(func():
		var r := GameState.make_trade(_trade_club, _mine, _theirs)
		_notice = str(r["reason"])
		if bool(r["ok"]):
			_mine = []
			_theirs = []
		_build())
	body.add_child(go)
	if shopping:
		var listed := GameState.trade_table.has(str(_mine[0]))
		var table := UiKit.btn("Already on the trade table" if listed else "Put on the trade table", 15)
		table.name = "TradeTable"
		table.custom_minimum_size = Vector2(0, 44)
		table.disabled = listed
		table.pressed.connect(func():
			var r := GameState.put_on_trade_table(str(_mine[0]))
			_notice = str(r["reason"])
			if bool(r["ok"]):
				_mine = []
				_scroll_positions["trade"] = 0
			_build())
		body.add_child(table)
	body.add_child(UiKit.spacer(UiKit.SECTION - 6))
	var sides := UiKit.hbox(4)
	for t in [["theirs", "Their list"], ["mine", "Your list"]]:
		var tb := UiKit.tab(str(t[1]), _trade_side == str(t[0]))
		tb.name = "TradeSide_" + str(t[0])
		tb.pressed.connect(func():
			_trade_side = str(t[0])
			_build())
		sides.add_child(tb)
	body.add_child(sides)
	if _trade_side == "mine":
		_draft_picks(body, GameState.my_club, _mine, "Mine_")
		_pick_grid(body, GameState.my_list, _mine, "Mine_")
	else:
		_draft_picks(body, _trade_club, _theirs, "Their_")
		_pick_grid(body, GameState.season.lists.get(_trade_club, []), _theirs, "Their_")


## Offers rival clubs have put to you: what they'd give and want, in words,
## with Accept and No thanks.
func _offers(body: VBoxContainer) -> void:
	var open := GameState.open_trade_offers()
	if open.is_empty():
		return
	body.add_child(UiKit.lbl("Offers for your players", 15, UiKit.EMPH, true))
	for i in open:
		var text := _para(GameState.trade_offer_text(i), 14, UiKit.TEXT)
		text.name = "Offer_%d" % i
		body.add_child(text)
		var row := UiKit.hbox(8)
		for b in [["Accept", "OfferAccept_%d" % i, true], ["No thanks", "OfferDecline_%d" % i, false]]:
			var btn := UiKit.btn(str(b[0]), 14)
			btn.name = str(b[1])
			btn.custom_minimum_size = Vector2(0, 44)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var accept: bool = b[2]
			btn.pressed.connect(func():
				if accept:
					_notice = str(GameState.accept_trade_offer(i)["reason"])
				else:
					GameState.decline_trade_offer(i)
				_build())
			row.add_child(btn)
		body.add_child(row)
	body.add_child(UiKit.spacer(UiKit.SECTION - 6))


## The counter for this offer, worked out once per offer (it tries every
## one of your players and picks).
func _counter_for(club: String, mine: Array, theirs: Array) -> Dictionary:
	var key := "%s|%s|%s|%d" % [club, ",".join(mine), ",".join(theirs), GameState.my_list.size()]
	if key != _counter_key:
		_counter_key = key
		_counter = GameState.trade_counter(club, mine, theirs)
	return _counter


## One side of the trade: each player or pick on its own line with Remove.
func _package(body: VBoxContainer, title: String, ids: Array, club: String, prefix: String, none: String) -> void:
	body.add_child(UiKit.lbl(title, 15, UiKit.EMPH, true))
	if ids.is_empty():
		body.add_child(_para(none, 13, UiKit.MUTED))
		return
	for id in ids.duplicate():
		var row := UiKit.hbox(8)
		row.name = prefix + str(id).replace(":", "_")
		var what := UiKit.ellipsis(_asset_line(str(id), club), 14, UiKit.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(what)
		var rm := UiKit.btn("Remove", 13)
		rm.name = "Remove"
		rm.custom_minimum_size = Vector2(88, 44)
		rm.pressed.connect(func():
			ids.erase(id)
			_build())
		row.add_child(rm)
		body.add_child(row)


## A player or pick in a trade, in a line: "Name, MID 72" or the pick.
func _asset_line(id: String, club: String) -> String:
	if id.begins_with("pick:"):
		var pk := GameState.pick_asset(id)
		return _pick_label(pk) if not pk.is_empty() else "-"
	for p in GameState.season.lists.get(club, []):
		if str(p["id"]) == id:
			return "%s, %s %d" % [GameDB.player_display_name(p), Ratings.role_tag(p), int(p["overall"])]
	return "-"


## Every other club, two to a row; Back or a choice closes it.
func _trade_club_sheet(body: VBoxContainer) -> void:
	body.add_child(UiKit.lbl("Trade with", 15, UiKit.EMPH, true))
	var options := []
	for code in GameDB.active_clubs(GameState.season_year):
		if code != GameState.my_club:
			options.append([code, GameDB.club_name(code)])
	body.add_child(UiKit.choice_grid("TradeClubChoice", options, _trade_club, 2, func(code: String):
		if code != _trade_club:
			_theirs = []
		_trade_club = code
		_choosing_club = false
		_build()))


## A club's tradeable draft picks, earliest first: "2027 first round, No. 3"
## (next year's has no number yet), and the club it came from if it was
## traded in.
func _draft_picks(body: VBoxContainer, code: String, chosen: Array, prefix: String) -> void:
	var picks := GameState.club_picks(code)
	if picks.is_empty():
		return
	body.add_child(UiKit.lbl("Draft picks", 14, UiKit.MUTED, true))
	for pk in picks:
		var id := str(pk["id"])
		var b := _asset_button(_pick_label(pk), chosen.has(id))
		b.name = prefix + id.replace(":", "_")
		b.pressed.connect(_toggle.bind(chosen, id))
		body.add_child(b)


## A list to add players from, best first: name, position, OVR, POT and age.
func _pick_grid(body: VBoxContainer, list: Array, chosen: Array, prefix: String) -> void:
	body.add_child(UiKit.lbl("Players", 14, UiKit.MUTED, true))
	var sorted := list.duplicate()
	sorted.sort_custom(func(a, b):
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		return str(a["id"]) < str(b["id"]))
	for p in sorted:
		var id := str(p["id"])
		var b := _asset_button("%s  ·  %s  ·  %d OVR  ·  %s POT  ·  %d" % [GameDB.player_display_name(p),
				Ratings.role_tag(p), int(p["overall"]), str(GameState.pot_view(p)["text"]),
				int(p.get("age", 0))], chosen.has(id))
		b.name = prefix + id
		b.pressed.connect(_toggle.bind(chosen, id))
		body.add_child(b)


func _asset_button(text: String, on: bool) -> Button:
	var b := UiKit.btn(text, 14)
	b.custom_minimum_size = Vector2(0, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiKit.set_selected(b, on)
	return b


## Add or take out one player or pick; a side holds at most GameState.TRADE_MAX.
func _toggle(chosen: Array, id: String) -> void:
	if chosen.has(id):
		chosen.erase(id)
	elif chosen.size() < GameState.TRADE_MAX:
		chosen.append(id)
	_build()


func _pick_label(pk: Dictionary) -> String:
	var nth: String = ["first", "second", "third", "fourth"][clampi(int(pk["round"]) - 1, 0, 3)]
	var text := "%d %s round" % [int(pk["year"]), nth]
	if int(pk["year"]) == GameState.season_year:
		text += ", No. %d" % int(pk["positions"][0][0])
	if str(pk["origin"]) != str(pk["owner"]):
		text += " (via %s)" % GameDB.club_name(str(pk["origin"]))
	return text


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
