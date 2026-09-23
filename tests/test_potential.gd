extends RefCounted
## Potential (POT) regression suite: every player has a sane POT, recent
## history spots the injured stars (rehab year), draft pedigree lifts young
## high picks, the rollover pulls ratings toward POT without passing it,
## training is cheaper below POT, draft rank drives prospect POT, and POT
## survives a save (old saves get backfilled).
## Run through tests/run_potential_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_every_player_has_potential()
	_test_history_and_pedigree()
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
		# Real history and draft pedigree may go past the generated caps.
		if p.has("history") or p.has("drafted_pick"):
			continue
		var cap := int(Potential.ROLE_CAP.get(str(p["role"]), 99))
		if int(p["potential"]) > maxi(cap, int(p["overall"])):
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


func _test_history_and_pedigree() -> void:
	var have_history := 0
	for p in GameDB.players:
		if p.has("history"):
			have_history += 1
	_check(have_history > 500, "Most players carry rated past seasons (%d)" % have_history)
	# The injured stars: short 2026, strong recent seasons.
	for name in ["Connor Rozee", "Darcy Moore", "Sam Darcy"]:
		var p := _real(name)
		_check(bool(p.get("rehab", false)), "%s is flagged for a rehab year" % name)
		_check(int(p["potential"]) >= int(p["overall"]) + 15,
				"%s's POT reflects his recent seasons (%d vs %d now)" % [
				name, int(p["potential"]), int(p["overall"])])
	# A full, healthy 2026 is not a rehab case, however good the history.
	var daicos := _real("Nick Daicos")
	_check(not daicos.has("rehab"), "A player with a full 2026 gets no rehab year")
	# Pedigree: the same young player with a top pick gets a higher ceiling.
	var young := {}
	for p in GameDB.players:
		if float(p["age"]) <= 21.0 and int(p["overall"]) < 70 and not p.has("history"):
			young = p.duplicate(true)
			break
	if not young.is_empty():
		var plain := young.duplicate(true)
		plain.erase("potential")
		plain.erase("drafted_type")
		plain.erase("drafted_pick")
		Potential.assign(plain)
		var top := plain.duplicate(true)
		top.erase("potential")
		top["drafted_type"] = "national"
		top["drafted_pick"] = 1
		Potential.assign(top)
		var rookie := plain.duplicate(true)
		rookie.erase("potential")
		rookie["drafted_type"] = "rookie"
		rookie["drafted_pick"] = 1
		Potential.assign(rookie)
		_check(int(top["potential"]) > int(plain["potential"]),
				"A young pick-1 player has a higher ceiling (%d vs %d)" % [
				int(top["potential"]), int(plain["potential"])])
		_check(int(rookie["potential"]) == int(plain["potential"]),
				"A rookie-draft listing carries no pedigree bonus")


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
	# Without his history, the same player barely moves.
	var rozee := _real("Connor Rozee").duplicate(true)
	rozee.erase("potential")
	rozee.erase("rehab")
	rozee.erase("history")
	Potential.assign(rozee)
	var plain := _age_once(rozee)
	_check(int(plain["overall"]) < int(_age_once(_real("Connor Rozee"))["overall"]) - 10,
			"His history is what drives the rehab")


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
	var pot_before := int(rozee["potential"])
	GameState.save_career()
	GameState.load_career()
	var loaded := GameState.list_player(str(rozee["id"]))
	_check(int(loaded.get("potential", 0)) == pot_before and bool(loaded.get("rehab", false)),
			"POT and the rehab flag survive a save")
	_check(loaded.has("history") and loaded.has("drafted_pick"),
			"History and draft pedigree survive a save")
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
	_check(int(back.get("potential", 0)) == pot_before and bool(back.get("rehab", false)),
			"An old save picks up the dataset's POT and rehab year")
