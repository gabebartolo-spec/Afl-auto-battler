extends SceneTree
## godot --headless --path . --script tests/run_recruit_undo_tests.gd
## Undo for a delisting, a free-agent signing and a re-signing (TODO row 119,
## 4.R76 / P-09): each undo restores the list, the cap, the contracts, the
## free-agent pool and the news exactly; the national draft starting (the
## off-season's "week moving on") removes it; a reload clears it cleanly; a
## finger's tap on Undo works on a 390 x 844 phone.
## Classes are reached through load() and autoload nodes: a --script runner
## compiles before the autoloads exist.

const Tap := preload("res://tests/tap.gd")
const Ran := preload("res://tests/functions_ran.gd")
## Every season here starts from a fixed seed (C15), never the clock.
const SUITE_SEED := 2027

var _state: Node
var _db: Node
var _contracts: GDScript
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_db = root.get_node("GameDB")
	_contracts = load("res://scripts/sim/Contracts.gd")
	# Never touch a real career save or settings file from a test run.
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	for key in load("res://scripts/ui/FirstVisitIntro.gd").TEXT:
		_state.set_setting("seen_%s_intro" % key, true)
	_t("_test_release_undo")
	_t("_test_free_agent_undo")
	_t("_test_resign_undo")
	_t("_test_unsettled_offers_have_no_undo")
	_t("_test_steps_undo_newest_first")
	_t("_test_draft_ends_undo")
	_t("_test_reload_clears_undo")
	await _t("_test_undo_by_a_finger")
	_state.delete_saved_career()
	print(Ran.line("Recruit undo", self))
	quit(0 if _failures.is_empty() else 1)


func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
		print("FAIL: " + what)


## A fresh Geelong career at its first off-season, with spare players only
## when needed, so the list can lose three and stay at its minimum. No match is
## played: the season is marked over by hand and the off-season opened, which
## is what builds the lists, contracts and free-agent pool an undo puts back.
func _to_offseason() -> void:
	_state.replay_seed = SUITE_SEED
	_state.reset()
	_state.start_season("GEE", _db.club_list("GEE"))
	_state.season.round_index = _state.season.fixture.size()
	_state.ensure_finals()
	_state.season.finals["done"] = true
	_state.open_offseason()
	var base: Dictionary = _state.my_list[_state.my_list.size() - 1]
	# Three releases must leave the list at its minimum (Contracts.min_list()),
	# counting the draftees still to come (up to three of the club's picks, as
	# release_player does). The list starts at the year's minimum, close to the
	# cap, so spare men are added only when those draftees do not cover it:
	# extra salaries would put the club over the cap and leave nothing to sign.
	var takes := mini(3, (_state.draft_list_spots()["picks"] as Array).size())
	for i in range(maxi(0, int(_contracts.min_list()) + 3 - _state.my_list.size() - takes)):
		var extra: Dictionary = base.duplicate(true)
		extra["id"] = "undo_extra_%d" % i
		extra["contract_years"] = 2
		extra.erase("resigned")
		extra.erase("retiring")
		_state.my_list.append(extra)


## Everything an undo must put back, as plain data.
func _world() -> Dictionary:
	var lists := {}
	for code in _state.season.lists:
		var ids := []
		for p in _state.season.lists[code]:
			ids.append(str(p["id"]))
		lists[code] = ids
	var mine := []
	for p in _state.my_list:
		mine.append((p as Dictionary).duplicate(true))
	var pool := []
	for p in _state.free_agents:
		pool.append((p as Dictionary).duplicate(true))
	return {"lists": lists, "mine": mine, "pool": pool, "payroll": _state.my_payroll(),
			"room": _state.cap_room(), "news": _state.news.duplicate(true),
			"log": _state.offseason_log.duplicate(true),
			"comp": _state.compensation.duplicate(true)}


## The parts of two worlds that differ, by name, for a failure message.
func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for k in a:
		if a[k] != b[k]:
			out.append(k)
	return out


## A player of yours under contract who is not retiring, highest rated first
## so his delisting makes the news.
func _releasable() -> Dictionary:
	var best := {}
	for p in _state.my_list:
		if _state.retiring_now(p) or str(p["id"]).begins_with("undo_extra"):
			continue
		if best.is_empty() or int(p["overall"]) > int(best["overall"]):
			best = p
	return best


## A free agent you can sign outright: no rival offer, would play for you, a
## price you can pay. Returns [player, salary, years].
func _signable() -> Array:
	for p in _state.free_agents:
		if _state.retiring_now(p) or bool(_state.free_agent_terms(str(p["id"]))["refuse"]):
			continue
		var years := 2
		var salary: int = maxi(int(_contracts.lowest(p, years)), int(_contracts.asking_salary(p)))
		if salary > _state.cap_room():
			continue
		p.erase("offers")
		p.erase("market_round")
		return [p, salary, years]
	return []


## One of your expiring players and an offer he accepts. [player, salary, years]
func _expiring_deal(min_salary := 0) -> Array:
	for p in _contracts.expiring(_state.my_list):
		if bool(p.get("resigned", false)) or _state.retiring_now(p):
			continue
		var years := 2
		var floor_price: int = int(_contracts.lowest(p, years)) - _state.culture_resign_discount(_state.my_club, p, years)
		var salary: int = maxi(floor_price, int(_contracts.SENIOR_MIN_2027))
		if salary < min_salary:
			continue
		if _state.my_payroll() - int(p.get("salary", 0)) + salary > _state.salary_cap:
			continue
		return [p, salary, years]
	return []


func _test_release_undo() -> void:
	_to_offseason()
	var p := _releasable()
	_check(not p.is_empty(), "A player to delist")
	var id := str(p["id"])
	var before := _world()
	# Half of what is left on his contract stays on the cap (row T1.R26 L4).
	var dead: int = load("res://scripts/sim/ListCosts.gd").dead_money(p)
	var sal := int(p.get("salary", 0))
	var r: Dictionary = _state.release_player(id)
	_check(bool(r["ok"]), "The delisting goes through (%s)" % str(r["reason"]))
	var after := _world()
	_check(not (after["lists"]["GEE"] as Array).has(id) and _state.free_agent(id) == p,
			"He is off your list and in the free-agent pool")
	_check(int(after["payroll"]) == int(before["payroll"]) - sal + dead,
			"His salary leaves your payroll, less what stays on the cap (%d -> %d, dead %d)" % [before["payroll"], after["payroll"], dead])
	_check((after["news"] as Array).size() == (before["news"] as Array).size() + 1,
			"Delisting a player of his standing makes the news")
	var last: Dictionary = _state.recruit_undo_last()
	_check(str(last.get("kind", "")) == "release" and str(last.get("id", "")) == id,
			"Undo is offered for the delisting (%s)" % str(last))
	var u: Dictionary = _state.undo_recruit()
	_check(bool(u["ok"]) and str(u["reason"]).begins_with("Delisting undone"), "The undo goes through (%s)" % str(u["reason"]))
	var back := _world()
	_check(_diff(before, back).is_empty(),
			"List, cap, contracts, free agents, news and the off-season log are exactly as before (%s)" % str(_diff(before, back)))
	_check(_state.list_player(id) == p and _state.my_list.has(p),
			"The same player record is back on your list")
	_check(_state.my_list == _state.season.lists["GEE"], "Your list is still the league's Geelong list")
	_check(_state.recruit_undo_last().is_empty(), "Nothing is left to undo")
	# Delisted again, the market treats him as it did the first time.
	var again: Dictionary = _state.release_player(id)
	_check(bool(again["ok"]) and _diff(after, _world()).is_empty(),
			"Delisting him again lands exactly where the first delisting did (%s)" % str(_diff(after, _world())))


func _test_free_agent_undo() -> void:
	_to_offseason()
	var deal := _signable()
	_check(not deal.is_empty(), "A free agent you can sign outright")
	var p: Dictionary = deal[0]
	var id := str(p["id"])
	var before := _world()
	var r: Dictionary = _state.offer_free_agent(id, int(deal[1]), int(deal[2]))
	_check(str(r["answer"]) == "signed", "He signs (%s)" % str(r.get("reason", "")))
	_check(_state.list_player(id) == p and _state.free_agent(id).is_empty(),
			"He is on your list and out of the pool")
	_check(_state.my_payroll() > int(before["payroll"]), "His salary is on your payroll")
	_check((_state.news as Array).size() > (before["news"] as Array).size(), "The signing makes the news")
	_check(str(_state.recruit_undo_last().get("kind", "")) == "sign", "Undo is offered for the signing")
	var u: Dictionary = _state.undo_recruit()
	_check(bool(u["ok"]) and str(u["reason"]).begins_with("Signing undone"), "The undo goes through (%s)" % str(u["reason"]))
	var back := _world()
	_check(_diff(before, back).is_empty(),
			"List, cap, contracts, free agents and news are exactly as before (%s)" % str(_diff(before, back)))
	_check(_state.free_agent(id) == p and not _state.my_list.has(p), "The same player record is a free agent again")


func _test_resign_undo() -> void:
	_to_offseason()
	var deal := _expiring_deal()
	_check(not deal.is_empty(), "An expiring player who would accept")
	var p: Dictionary = deal[0]
	var id := str(p["id"])
	var before := _world()
	var r: Dictionary = _state.offer_contract(id, int(deal[1]), int(deal[2]))
	_check(str(r["answer"]) == "accept" and bool(p.get("resigned", false)), "He re-signs (%s)" % str(r.get("reason", "")))
	_check(str(_state.recruit_undo_last().get("kind", "")) == "resign", "Undo is offered for the re-signing")
	var u: Dictionary = _state.undo_recruit()
	_check(bool(u["ok"]) and str(u["reason"]).begins_with("Re-signing undone"), "The undo goes through (%s)" % str(u["reason"]))
	var back := _world()
	_check(_diff(before, back).is_empty(),
			"His contract, the payroll and the cap are exactly as before (%s)" % str(_diff(before, back)))
	_check(not p.has("resigned") and _contracts.expiring(_state.my_list).has(p), "He is out of contract again")


## An offer that did not settle anything (a counter) has no undo, and it
## ends the undo of what came before: an undo never rewinds anything else.
func _test_unsettled_offers_have_no_undo() -> void:
	_to_offseason()
	var p := _releasable()
	_state.release_player(str(p["id"]))
	_check(not _state.recruit_undo_last().is_empty(), "The delisting can be undone")
	var deal := _expiring_deal(2 * int(_contracts.SENIOR_MIN_2027))
	_check(not deal.is_empty(), "An expiring player worth well over the minimum")
	var q: Dictionary = deal[0]
	var r: Dictionary = _state.offer_contract(str(q["id"]), int(deal[1]) / 2, 2)
	_check(str(r["answer"]) == "counter" or str(r["answer"]) == "walk", "A lowball offer is countered (%s)" % str(r["answer"]))
	_check(_state.recruit_undo_last().is_empty(), "A counter-offer has no undo and ends the earlier one")
	var u: Dictionary = _state.undo_recruit()
	_check(not bool(u["ok"]) and _state.list_player(str(p["id"])).is_empty(), "Undo changes nothing then")


func _test_steps_undo_newest_first() -> void:
	_to_offseason()
	var a := _releasable()
	var before := _world()
	_state.release_player(str(a["id"]))
	var mid := _world()
	var b := _releasable()
	_state.release_player(str(b["id"]))
	_check(str(_state.recruit_undo_last()["id"]) == str(b["id"]), "Undo takes back the newest delisting first")
	_state.undo_recruit()
	_check(_diff(mid, _world()).is_empty() and str(_state.recruit_undo_last().get("id", "")) == str(a["id"]),
			"After one undo the earlier delisting is next (%s)" % str(_diff(mid, _world())))
	_state.undo_recruit()
	_check(_diff(before, _world()).is_empty() and _state.recruit_undo_last().is_empty(),
			"After two, both players are back as they were (%s)" % str(_diff(before, _world())))


## Off-season, the week moves on when the national draft starts.
func _test_draft_ends_undo() -> void:
	_to_offseason()
	_state.release_player(str(_releasable()["id"]))
	_check(not _state.recruit_undo_last().is_empty(), "Undo is offered before the draft")
	_state.begin_intake_draft()
	_check(not _state.offseason_open() and _state.recruit_undo_last().is_empty() and _state.recruit_undo.is_empty(),
			"Once the national draft starts, Undo is gone")
	_check(not bool(_state.undo_recruit()["ok"]), "And an undo call does nothing")
	# advance() (Sim the week in the season) clears it too.
	_state.recruit_undo.append({"kind": "release", "id": "x", "name": "x", "snap": {}, "after": 0})
	_state.advance()
	_check(_state.recruit_undo.is_empty(), "Sim the week clears any undo step")


## Not saved: a reload brings the career back without the undo, the delisting
## kept.
func _test_reload_clears_undo() -> void:
	_to_offseason()
	var p := _releasable()
	var id := str(p["id"])
	_state.release_player(id)
	var after := _world()
	_check(_state.save_career(), "The career saves")
	_check(_state.load_career(), "The career loads")
	_check(_state.recruit_undo_last().is_empty() and _state.recruit_undo.is_empty(), "After a reload there is no Undo")
	_check(_state.list_player(id).is_empty() and not _state.free_agent(id).is_empty(),
			"The delisting stands after the reload")
	_check((_world()["lists"] as Dictionary) == after["lists"], "Every list reloads as it was saved")
	_check(not bool(_state.undo_recruit()["ok"]), "An undo call after the reload does nothing")


func _test_undo_by_a_finger() -> void:
	_to_offseason()
	root.size = Vector2i(390, 844)
	var p := _releasable()
	var id := str(p["id"])
	var before := _world()
	var scene: Control = load("res://scenes/OffseasonScene.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	_check(scene.find_child("UndoAction", true, false) == null, "No Undo before anything is done")
	_state.release_player(id)
	scene.set("_notice", "%s released." % _db.player_display_name(p))
	scene.call("_build")
	await _settle()
	var b := scene.find_child("UndoAction", true, false) as Button
	var said := scene.find_child("UndoLastText", true, false)
	_check(b != null and said != null, "Undo shows after a delisting")
	if b == null:
		scene.queue_free()
		return
	_check(_text(said) == "You can undo this until the national draft starts.",
			"Beside the delisting notice it says only what Undo does (%s)" % _text(said))
	_check(b.size.y >= 44.0 and b.size.x >= 44.0, "Undo is thumb-sized (%s)" % str(b.size))
	var r := b.get_global_rect()
	_check(r.position.x >= 0.0 and r.end.x <= 390.0 and r.end.y <= 844.0, "Undo is on a 390-wide screen (%s)" % str(r))
	_check(not bool(scene.call("handle_back")), "Back is unchanged: no overlay to close, it leaves the screen")
	var why: String = await Tap.tap(b)
	_check(why == "", "A finger's tap on Undo reaches it (%s)" % why)
	await _settle()
	_check(_state.list_player(id) == p and _diff(before, _world()).is_empty(),
			"The tap puts him back on your list exactly as before (%s)" % str(_diff(before, _world())))
	var notice := scene.find_child("OffseasonNotice", true, false)
	var told := _text(notice) if notice != null else "none"
	_check(told.begins_with("Delisting undone:"), "The notice says the delisting is undone (%s)" % told)
	_check(scene.find_child("UndoAction", true, false) == null, "Undo is gone once used")
	# With no notice naming him (another tab), the row says what it undoes.
	_state.release_player(id)
	scene.set("_notice", "")
	scene.call("_build")
	await _settle()
	said = scene.find_child("UndoLastText", true, false)
	var own := _text(said) if said != null else "none"
	_check(own.begins_with("You delisted ") and own.contains(_db.player_display_name(p)),
			"On its own the row names the delisting it undoes (%s)" % own)
	# A signing put into the trade you are building, then undone, leaves the trade too.
	var deal := _signable()
	_check(not deal.is_empty(), "A free agent to sign and offer in a trade")
	if not deal.is_empty():
		var fa_id := str(deal[0]["id"])
		var signed: Dictionary = _state.offer_free_agent(fa_id, int(deal[1]), int(deal[2]))
		scene.set("_mine", [fa_id])
		scene.set("_notice", "")
		scene.call("_build")
		await _settle()
		var ub := scene.find_child("UndoAction", true, false) as Button
		var why2 := "no Undo"
		if ub != null:
			why2 = await Tap.tap(ub)
		await _settle()
		_check(str(signed["answer"]) == "signed" and why2 == "" and not _state.free_agent(fa_id).is_empty()
				and (scene.get("_mine") as Array).is_empty(),
				"Undoing a signing takes him out of the trade being built (%s, %s)" % [why2, str(scene.get("_mine"))])
	scene.queue_free()
	await _settle()


## What a label reads: a name-inked line keeps its plain text in a meta.
func _text(n: Node) -> String:
	return str(n.get_meta("plain")) if n.has_meta("plain") else str(n.get("text"))


func _settle() -> void:
	for i in range(4):
		await process_frame
