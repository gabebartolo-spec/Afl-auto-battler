extends RefCounted
## Potential (POT) regression suite: every player has a sane POT, hand-set
## overrides land (the injured-star rehab case), the rollover pulls ratings
## toward POT without passing it, training is cheaper below POT, draft rank
## drives prospect POT, and POT survives a save (old saves get backfilled).
## Run through tests/run_potential_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_every_player_has_potential()
	_test_overrides()
	_test_rehab_rollover()
	_test_growth_is_capped()
	_test_training_discount()
	_test_draftee_potential()
	_test_save_and_backfill()
	GameState.delete_saved_career()
	print("Potential tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _real(name: String) -> Dictionary:
	for p in GameDB.players:
		if str(p["real_name"]) == name:
			return p
	return {}


func _test_every_player_has_potential() -> void:
	var ok := true
	var capped := true
	for p in GameDB.players + GameDB.draftees:
		if not p.has("potential") or int(p["potential"]) < int(p["overall"]) \
				or int(p["potential"]) > Potential.MAX_POT:
			ok = false
		var cap := int(Potential.ROLE_CAP.get(str(p["role"]), 99))
		if not p.has("rehab") and int(p["potential"]) > maxi(cap, int(p["overall"])):
			capped = false
	_check(ok, "Every player and prospect has a POT between his rating and the max")
	_check(capped, "Generated POTs respect the position caps")
	var reid := _real("Harley Reid")
	var bont := _real("Marcus Bontempelli")
	_check(int(reid["potential"]) - int(reid["overall"]) > int(bont["potential"]) - int(bont["overall"]),
			"A 21-year-old has more headroom than a 30-year-old")
	var pot_a := int(reid["potential"])
	GameDB.reload()
	_check(int(_real("Harley Reid")["potential"]) == pot_a, "POT is stable across reloads")


func _test_overrides() -> void:
	for row in [["Connor Rozee", 86], ["Darcy Moore", 74], ["Sam Darcy", 76]]:
		var p := _real(str(row[0]))
		_check(int(p.get("potential", 0)) == int(row[1]), "%s has POT %d" % row)
		_check(bool(p.get("rehab", false)), "%s is flagged for a rehab year" % row[0])


func _age_once(p: Dictionary, year := 2027) -> Dictionary:
	var copy: Dictionary = p.duplicate(true)
	Prospects.age_player(copy, year)
	return copy


func _test_rehab_rollover() -> void:
	for name in ["Connor Rozee", "Darcy Moore", "Sam Darcy"]:
		var p := _real(name)
		var after := _age_once(p)
		var gap := int(p["potential"]) - int(p["overall"])
		var closed := int(after["overall"]) - int(p["overall"])
		_check(float(closed) >= 0.75 * float(gap) - 3.0,
				"%s closes most of the gap in the rehab year (%d -> %d, POT %d)" % [
				name, int(p["overall"]), int(after["overall"]), int(p["potential"])])
		_check(int(after["overall"]) <= int(p["potential"]), "%s does not pass his POT" % name)
		_check(not after.has("rehab"), "The rehab year is used up (%s)" % name)
	# Without the override, the same player barely moves.
	var rozee := _real("Connor Rozee").duplicate(true)
	rozee.erase("potential")
	rozee.erase("rehab")
	Potential.assign(rozee)
	var plain := _age_once(rozee)
	_check(int(plain["overall"]) < int(_age_once(_real("Connor Rozee"))["overall"]) - 10,
			"The override is what drives the rehab")


func _test_growth_is_capped() -> void:
	var over := 0
	var grew := 0
	var young := 0
	for p in GameDB.players:
		if float(p["age"]) > 23.0:
			continue
		young += 1
		var after := _age_once(p)
		if int(after["overall"]) > maxi(int(p["potential"]), int(p["overall"])):
			over += 1
		if int(after["overall"]) > int(p["overall"]):
			grew += 1
	_check(over == 0, "Off-season growth never passes POT (%d did)" % over)
	_check(grew > young / 2, "Most young players still grow (%d of %d)" % [grew, young])


func _test_training_discount() -> void:
	var p := _real("Connor Rozee").duplicate(true)
	var at_ceiling := p.duplicate(true)
	at_ceiling["potential"] = int(at_ceiling["overall"])
	_check(Potential.training_multiplier(p) <= 0.55, "A rehab player trains at about half price")
	_check(Potential.training_multiplier(at_ceiling) == 1.5, "Past POT, training costs 50% more")
	GameState.reset()
	GameState.start_season("PAD", GameDB.club_list("PAD"))
	var mine := {}
	for q in GameState.my_list:
		if str(q["real_name"]) == "Connor Rozee":
			mine = q
	var normal := mine.duplicate(true)
	normal["potential"] = int(normal["overall"]) + 1
	var cheap := GameState.train_cost(mine, "disposal")
	var full := GameState.train_cost(normal, "disposal")
	_check(cheap > 0 and cheap < full, "Training cost reflects POT (%d vs %d)" % [cheap, full])


func _test_draftee_potential() -> void:
	var top := []
	var late := []
	for p in GameDB.draftees:
		if int(p["draft_rank"]) <= 10:
			top.append(int(p["potential"]))
		elif int(p["draft_rank"]) > 40:
			late.append(int(p["potential"]))
	var avg := func(a: Array) -> float:
		var t := 0.0
		for x in a:
			t += float(x)
		return t / maxf(1.0, float(a.size()))
	_check(avg.call(top) > avg.call(late) + 5.0, "Top-10 picks carry more POT than late picks")
	var gen := Prospects.generate_class(2027)
	var all_ok := true
	for p in gen:
		if not p.has("potential") or int(p["potential"]) < int(p["overall"]):
			all_ok = false
	_check(all_ok and not gen.is_empty(), "Generated draft classes get a POT")
	var d: Dictionary = GameDB.draftees[0].duplicate(true)
	var before := int(d["potential"])
	Prospects.project(d)
	_check(int(d["potential"]) == before, "Re-projecting a prospect keeps the same POT")


func _test_save_and_backfill() -> void:
	GameState.reset()
	GameState.start_season("PAD", GameDB.club_list("PAD"))
	GameState.advance()
	var rozee := {}
	for q in GameState.my_list:
		if str(q["real_name"]) == "Connor Rozee":
			rozee = q
	GameState.save_career()
	GameState.load_career()
	var loaded := GameState.list_player(str(rozee["id"]))
	_check(int(loaded.get("potential", 0)) == 86 and bool(loaded.get("rehab", false)),
			"POT and the rehab flag survive a save")
	# A save written before POT existed: strip it and reload.
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			p.erase("potential")
			p.erase("rehab")
	GameState.save_career()
	GameState.load_career()
	var missing := 0
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			if not p.has("potential"):
				missing += 1
	_check(missing == 0, "Loading an old save fills in every POT")
	var back := GameState.list_player(str(rozee["id"]))
	_check(int(back.get("potential", 0)) == 86 and bool(back.get("rehab", false)),
			"An old save picks up the hand-set POT and rehab year")
