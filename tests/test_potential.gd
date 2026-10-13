extends RefCounted
## Potential (POT) regression suite: every player has a sane POT, recent
## history spots the injured stars (rehab year), draft pedigree lifts young
## high picks, the rollover pulls ratings toward POT without passing it,
## training is cheaper below POT, draft rank drives prospect POT, and POT
## survives a save (old saves get backfilled).
## Run through tests/run_potential_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season and draft here is seeded (C15): a clock seed makes a different
## league each run.
const SUITE_SEED := 2027


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	_test_every_player_has_potential()
	_test_history_and_pedigree()
	_test_rehab_rollover()
	_test_growth_is_capped()
	_test_training_discount()
	_test_draftee_potential()
	_test_youth_pace()
	_test_pick_values_held()
	_test_save_and_backfill()
	GameState.delete_saved_career()
	GameState.replay_seed = 0
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
		# His opening rating is already lifted part of the way on his record
		# (Ratings.rate_on_record); the rehab year closes the rest. POT still
		# sits well above what his short 2026 alone said, and above today.
		var short_year := int(p.get("season_overall", p["overall"]))
		_check(int(p["potential"]) >= short_year + 15 and int(p["potential"]) > int(p["overall"]),
				"%s's POT reflects his recent seasons (%d vs %d in 2026, %d now)" % [
				name, int(p["potential"]), short_year, int(p["overall"])])
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
	_check(over <= maxi(2, young / 10), "Off-season growth passes POT only in an occasional breakout (%d of %d)" % [over, young])
	_check(grew > young / 2, "Most young players still grow (%d of %d)" % [grew, young])


func _test_training_discount() -> void:
	var p := _real("Connor Rozee").duplicate(true)
	var at_ceiling := p.duplicate(true)
	at_ceiling["potential"] = int(at_ceiling["overall"])
	# POT is now what he can still reach (director, 2026-10-07), a little
	# under his old peak, so the discount is a little smaller.
	# Part of his rehab now comes as his opening rating, so less is left to
	# train back: still well under full price.
	_check(Potential.training_multiplier(p) <= 0.8, "A rehab player trains well under full price (%.2f)" % Potential.training_multiplier(p))
	var past := at_ceiling.duplicate(true)
	past["potential"] = int(past["overall"]) - 2
	var near := at_ceiling.duplicate(true)
	near["potential"] = int(near["overall"]) + 2
	_check(Potential.training_multiplier(near) > 1.0 and Potential.training_multiplier(at_ceiling) > Potential.training_multiplier(near)
			and Potential.training_multiplier(past) > 2.5 * Potential.training_multiplier(at_ceiling) * 0.99,
			"Training gets dearer near POT and steeply dearer past it (%.2f, %.2f, %.2f)" % [
			Potential.training_multiplier(near), Potential.training_multiplier(at_ceiling), Potential.training_multiplier(past)])
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


## Young draftees (director 2026-10-14, "A: gentle"): they arrive lower than the old curve, a few
## are ready-made, the ceiling is the same, and nobody already on a list is rescaled.
func _top_ten(scale: float) -> Array:
	var old := Prospects.DRAFT_NIGHT_SCALE
	Prospects.DRAFT_NIGHT_SCALE = scale
	var out: Array = []
	for y in range(2027, 2033):
		for p in Prospects.generate_class(y, 700 + y):
			if int(p["draft_rank"]) <= 10:
				out.append(p)
	Prospects.DRAFT_NIGHT_SCALE = old
	return out


func _mean_of(ps: Array, key: String) -> float:
	var t := 0.0
	for p in ps:
		t += float(p[key])
	return t / maxf(1.0, float(ps.size()))


func _test_youth_pace() -> void:
	_check(is_equal_approx(Prospects.DRAFT_NIGHT_SCALE, 0.78), "The draft-night scale is the gentle 0.78")
	_check(Potential.YOUTH_STEP_PACE == 1.0 and Potential.YOUTH_GAP_PACE == 1.0, "The climb itself runs at the old pace")
	var old_top := _top_ten(1.0)
	var top := _top_ten(Prospects.DRAFT_NIGHT_SCALE)
	var drop := _mean_of(old_top, "overall") - _mean_of(top, "overall")
	_check(drop >= 10.0 and drop <= 18.0, "A top-10 pick arrives about 14 points lower than on the old curve (%.1f)" % drop)
	_check(absf(_mean_of(old_top, "potential") - _mean_of(top, "potential")) <= 1.5, "His ceiling (POT) is the same")
	# Readiness: a few are ready-made, most typical, some long-term projects.
	var ready := 0
	var project := 0
	var ready_ov := 0.0
	var project_ov := 0.0
	for p in top:
		if str(p.get("readiness", "")) == "ready":
			ready += 1
			ready_ov += float(p["overall"])
		elif str(p.get("readiness", "")) == "project":
			project += 1
			project_ov += float(p["overall"])
	var n := float(top.size())
	_check(float(ready) / n >= 0.10 and float(ready) / n <= 0.35, "About 1 in 5 of a top 10 is ready-made (%d of %d)" % [ready, top.size()])
	_check(project > 0 and ready > 0 and ready_ov / float(ready) > project_ov / float(project) + 8.0,
			"A ready-made pick is well ahead of a project on draft night")
	# He climbs: three off-seasons add well over ten points to the average top-10 pick.
	var start := _mean_of(top, "overall")
	var after := 0.0
	for p in top:
		var c: Dictionary = p.duplicate(true)
		for y in range(3):
			Prospects.age_player(c, 2040 + y)
		after += float(c["overall"])
	after /= n
	_check(after - start >= 15.0, "The average top-10 pick climbs %.1f points in three seasons" % (after - start))
	# Nobody already listed is rescaled: a saved draftee keeps his rating whatever the scale is now,
	# and the real 2026 class (data, not generated) projects the same either way.
	var saved: Dictionary = (_top_ten(1.0)[0] as Dictionary).duplicate(true)
	var kept := int(saved["overall"])
	var scale := Prospects.DRAFT_NIGHT_SCALE
	Prospects.DRAFT_NIGHT_SCALE = 0.5
	var after_aging := int(_age_once(saved)["overall"])
	_check(int(saved["overall"]) == kept, "A draftee already on a list keeps his rating when the scale changes")
	Prospects.DRAFT_NIGHT_SCALE = scale
	_check(after_aging >= kept, "...and a young listed player still climbs")
	var real_pick: Dictionary = {}
	for p in GameDB.draftees:
		real_pick = (p as Dictionary).duplicate(true)
		break
	if not real_pick.is_empty():
		Prospects.project(real_pick)
		var at_scale := int(real_pick["overall"])
		Prospects.DRAFT_NIGHT_SCALE = 1.0
		Prospects.project(real_pick)
		Prospects.DRAFT_NIGHT_SCALE = scale
		_check(at_scale == int(real_pick["overall"]), "The real 2026 class is not rescaled")


## Director 2026-10-14, "hold pick values where they are": a pick is read by the player it buys,
## so lowering the draft-night rating does not cheapen picks (today's values, 12 classes, a
## rebuilding club: pick 1 about 1.9, pick 10 about 1.3, pick 30 about 0.7).
func _pick_value_at(pick: int, scale: float) -> float:
	var old := Prospects.DRAFT_NIGHT_SCALE
	Prospects.DRAFT_NIGHT_SCALE = scale
	var t := 0.0
	for c in range(12):
		var ranked: Array = TradeValue.rank_prospects(Prospects.generate_class(2027 + c, 700 + c))
		t += TradeValue.pick_value([[pick, 1.0]], ranked, "rebuilding")
	Prospects.DRAFT_NIGHT_SCALE = old
	return t / 12.0


func _test_pick_values_held() -> void:
	for e in [[1, 1.9], [10, 1.3], [30, 0.7]]:
		var now := _pick_value_at(int(e[0]), Prospects.DRAFT_NIGHT_SCALE)
		var old := _pick_value_at(int(e[0]), 1.0)
		_check(absf(now - float(e[1])) <= 0.15, "Pick %d is worth about %.1f to a rebuilding club (%.2f)" % [int(e[0]), float(e[1]), now])
		_check(absf(now - old) <= 0.03 * old, "Pick %d is worth the same as on the old curve (%.2f v %.2f)" % [int(e[0]), now, old])


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
	# An old save from before his first game: rated as the dataset has him.
	var orig: Dictionary = GameDB.player_by_id(str(rozee["id"]))
	var at_start := GameState.list_player(str(rozee["id"]))
	at_start["attr"] = (orig["attr"] as Dictionary).duplicate()
	at_start["overall"] = int(orig["overall"])
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
