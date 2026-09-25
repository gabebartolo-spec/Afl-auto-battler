extends RefCounted
## Club achievements: the catalog covers every club with one distinct,
## lore-anchored objective, and each objective type unlocks (or stays
## locked) exactly on the context it is written for. The context is the same
## shape GameState builds at season's end, so these tests exercise the real
## check without simulating a season - plus one full season for the
## end-to-end path and the save round trip.
## Run through tests/run_achievements_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_test_catalog()
	_test_premiership_types()
	_test_grand_final()
	_test_top_ladder_and_slam()
	_test_flags_window()
	_test_second_chance()
	_test_wins()
	_test_debuts()
	_test_no_double_unlock()
	_test_full_season()
	GameState.reset()
	GameState.delete_saved_career()
	print("Achievements tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


# ---------------------------------------------------------------------------
# Context builders (the shape GameState passes to Achievements.check_season)
# ---------------------------------------------------------------------------
## A ladder for `ordered` (top to bottom) with distinct points/percentage.
func _ladder(ordered: Array) -> Dictionary:
	var out := {}
	for i in range(ordered.size()):
		var w := maxi(0, 18 - i)
		var pf := 2000 - i * 10
		var pa := 1500 + i * 10
		out[ordered[i]] = {"code": ordered[i], "p": 20, "w": w, "l": maxi(0, 20 - w),
				"d": 0, "pf": pf, "pa": pa, "pts": 4 * w,
				"pct": 100.0 * pf / pa}
	return out


func _codes(n := 18) -> Array:
	return (GameDB.CLUB_ORDER as Array).slice(0, n)


func _ctx(premier: String, runner: String, ladder: Dictionary,
		year := 2026, slots: Dictionary = {}, history: Array = []) -> Dictionary:
	var enter := {}
	for code in GameDB.CLUB_ORDER:
		enter[code] = GameDB.enter_year(code)
	var finalists := []
	var n := 0
	for code in ladder:
		finalists.append(code)
		n += 1
		if n >= Season.FINALISTS:
			break
	return {"year": year, "premier": premier, "runner_up": runner,
			"ladder": ladder, "finalists": finalists, "finals_slots": slots,
			"history": history, "active": GameDB.active_clubs(year), "enter": enter}


func _ids(unlocked: Dictionary, ctx: Dictionary) -> Array:
	return Achievements.check_season(unlocked, ctx)


# ---------------------------------------------------------------------------
func _test_catalog() -> void:
	_check(Achievements.DEFINITIONS.size() == 20,
			"There are twenty club achievements")
	var seen_ids := {}
	var seen_clubs := {}
	for d in Achievements.DEFINITIONS:
		var id := str(d["id"])
		var club := str(d["club"])
		_check(not seen_ids.has(id), "Achievement ids are unique (%s)" % id)
		seen_ids[id] = true
		_check(not seen_clubs.has(club), "One achievement per club (%s)" % club)
		seen_clubs[club] = true
		_check(str(d.get("name", "")) != "" and str(d.get("desc", "")) != "",
				"%s has a name and lore text" % id)
		_check(str(d.get("type", "")) != "", "%s has a checkable type" % id)
	var active: Array = GameDB.active_clubs(2030)
	_check(seen_clubs.size() == active.size() and seen_clubs.keys().size() == active.size(),
			"Every club that exists by 2030 has an achievement")
	for code in active:
		_check(seen_clubs.has(code), "%s is covered" % code)
	_check(Achievements.definition("ade_first_flag") != {}
			and str(Achievements.definition("ade_first_goalless").get("id", "")) == "",
			"definition() finds real ids and rejects invented ones")


func _test_premiership_types() -> void:
	for row in [["ADE", "ade_first_flag"], ["FRE", "fre_first_flag"],
			["GWS", "gws_first_flag"], ["PAD", "pad_first_flag"],
			["SKN", "skn_long_wait"]]:
		var code := str(row[0])
		var id := str(row[1])
		var ladder := _ladder(_codes())
		var out := _ids({}, _ctx(code, "GEE", ladder))
		_check(out.has(id), "%s wins the flag: %s unlocks" % [code, id])
	# A different premier does not unlock any of them.
	var ladder := _ladder(_codes())
	var out := _ids({}, _ctx("GEE", "HAW", ladder))
	for row in [["ADE", "ade_first_flag"], ["FRE", "fre_first_flag"],
			["GWS", "gws_first_flag"], ["PAD", "pad_first_flag"],
			["SKN", "skn_long_wait"]]:
		_check(not out.has(str(row[1])), "GEE's flag never unlocks %s" % str(row[1]))


func _test_grand_final() -> void:
	var ladder := _ladder(_codes())
	var out := _ids({}, _ctx("GEE", "GCS", ladder))
	_check(out.has("gcs_first_gf"), "A Grand Final appearance (even as runner-up) unlocks GCS")
	var out2 := _ids({}, _ctx("GEE", "HAW", ladder))
	_check(not out2.has("gcs_first_gf"), "Missing the Grand Final does not unlock GCS")


func _test_top_ladder_and_slam() -> void:
	var codes := _codes()
	var ladder := _ladder(codes)
	var out := _ids({}, _ctx("CAR", "GEE", ladder))
	_check(out.has("car_top_ladder"), "Topping the ladder unlocks Carlton")

	# SYD tops the ladder and wins the flag: grand slam. (SYD is 15th in the
	# default ladder, so move it to the top for this context.)
	var syd_top := codes.duplicate()
	syd_top.erase("SYD")
	syd_top.push_front("SYD")
	var ladder2 := _ladder(syd_top)
	var out2 := _ids({}, _ctx("SYD", "GEE", ladder2))
	_check(out2.has("syd_grand_slam"), "Brownlow and the flag in one season: grand slam")
	# Top the ladder, lose the Grand Final: no slam.
	var out3 := _ids({}, _ctx("GEE", "SYD", ladder2))
	_check(not out3.has("syd_grand_slam"), "A lost Grand Final is no grand slam")
	# Win the flag from outside the top of the ladder: no slam.
	var out4 := _ids({}, _ctx("SYD", "GEE", ladder))
	_check(not out4.has("syd_grand_slam"), "The flag alone is not the grand slam")


func _test_flags_window() -> void:
	# Back-to-back (window 2).
	var ladder := _ladder(_codes())
	_check(_ids({}, _ctx("BRL", "GEE", ladder, 2026, {}, [[2025, "BRL"]])).has("brl_back_to_back"),
			"Two flags in a row unlocks the Lions")
	_check(not _ids({}, _ctx("BRL", "GEE", ladder, 2026, {}, [[2024, "BRL"]])).has("brl_back_to_back"),
			"Two seasons apart is not back-to-back")
	_check(_ids({}, _ctx("ESS", "GEE", ladder, 2026, {}, [[2025, "ESS"]])).has("ess_back_to_back"),
			"Essendon back-to-back")
	_check(_ids({}, _ctx("RIC", "GEE", ladder, 2026, {}, [[2025, "RIC"]])).has("ric_back_to_back"),
			"Richmond back-to-back")

	# Three-peat (3 in 3).
	_check(_ids({}, _ctx("HAW", "GEE", ladder, 2026, {},
			[[2024, "HAW"], [2025, "HAW"]])).has("haw_three_peat"), "Three in a row unlocks Hawthorn")
	_check(not _ids({}, _ctx("HAW", "GEE", ladder, 2026, {},
			[[2023, "HAW"], [2025, "HAW"]])).has("haw_three_peat"),
			"A gap inside the window is not a three-peat")

	# Four-peat (4 in 4).
	_check(_ids({}, _ctx("COL", "GEE", ladder, 2026, {},
			[[2023, "COL"], [2024, "COL"], [2025, "COL"]])).has("col_four_peat"),
			"Four in a row unlocks Collingwood")
	_check(not _ids({}, _ctx("COL", "GEE", ladder, 2026, {},
			[[2022, "COL"], [2024, "COL"], [2025, "COL"]])).has("col_four_peat"),
			"Three of four in the window is not enough for the Magpies")

	# 3 in 5 (Geelong) with the window boundary respected.
	_check(_ids({}, _ctx("GEE", "HAW", ladder, 2026, {},
			[[2022, "GEE"], [2024, "GEE"]])).has("gee_dynasty"), "Three flags in five seasons")
	_check(not _ids({}, _ctx("GEE", "HAW", ladder, 2026, {},
			[[2021, "GEE"], [2024, "GEE"]])).has("gee_dynasty"),
			"2021 is outside the five-season window")

	# 5 in 6 (Melbourne).
	var mel_hist := [[2021, "MEL"], [2022, "MEL"], [2023, "MEL"], [2024, "MEL"], [2025, "MEL"]]
	_check(_ids({}, _ctx("MEL", "GEE", ladder, 2026, {}, mel_hist)).has("mel_the_fifties"),
			"Five flags in six seasons")

	# 2 in 3 (North Melbourne).
	_check(_ids({}, _ctx("NTH", "GEE", ladder, 2026, {}, [[2024, "NTH"]])).has("nth_kangaroo_power"),
			"Two flags in three seasons")
	_check(not _ids({}, _ctx("NTH", "GEE", ladder, 2026, {}, [[2023, "NTH"]])).has("nth_kangaroo_power"),
			"Three seasons apart is outside the window")


func _test_second_chance() -> void:
	var ladder := _ladder(_codes())
	var good := {"L_QF1": "WCE", "W_SF1": "WCE", "W_PF1": "WCE", "W_GF": "WCE",
			"L_GF": "GEE"}
	_check(_ids({}, _ctx("WCE", "GEE", ladder, 2026, good)).has("wce_second_chance"),
			"Lose a qualifying, win the semi, prelim and Grand Final: second chances")
	var lost_gf := good.duplicate()
	lost_gf["L_GF"] = "WCE"
	lost_gf.erase("W_GF")
	lost_gf["W_GF"] = "GEE"
	_check(not _ids({}, _ctx("WCE", "GEE", ladder, 2026, lost_gf)).has("wce_second_chance"),
			"Losing the Grand Final along the way is no second chance")
	var lost_sf := {"L_QF1": "WCE", "L_SF1": "WCE"}
	_check(not _ids({}, _ctx("GEE", "HAW", ladder, 2026, lost_sf)).has("wce_second_chance"),
			"Knocked out in the semi never reaches the cup")


func _test_wins() -> void:
	var codes := _codes()
	# WBD fourth: 14 wins in the synthetic ladder - one short.
	var ladder := _ladder(codes)
	ladder["WBD"] = {"code": "WBD", "p": 20, "w": 14, "l": 6, "d": 0,
			"pf": 1800, "pa": 1700, "pts": 56, "pct": 100.0 * 1800.0 / 1700.0}
	_check(not _ids({}, _ctx("GEE", "HAW", ladder)).has("wbd_bulldog_grit"),
			"Fourteen wins are not enough Bulldog grit")
	ladder["WBD"]["w"] = 15
	ladder["WBD"]["pts"] = 60
	_check(_ids({}, _ctx("GEE", "HAW", ladder)).has("wbd_bulldog_grit"),
			"Fifteen home-and-away wins is Bulldog grit")


## Build an ordered club list inserting `code` at `pos` (0-based).
func _insert(base: Array, code: String, pos: int) -> Array:
	var out := []
	for c in base:
		out.append(c)
	out.insert(pos, code)
	return out


func _test_debuts() -> void:
	# 2028: Tasmania debuts. Placed 7th (in the top-ten) -> finals achievement.
	var base := _codes()
	var with_tas := _insert(base, "TAS", 6)
	var ladder19 := _ladder(with_tas)
	_check(with_tas.size() == 19, "Nineteen clubs in the 2028 debut ladder")
	_check(_ids({}, _ctx("GEE", "HAW", ladder19, 2028)).has("tas_debut_finals"),
			"Tasmania in the 2028 finals makes the debut achievement")
	# 2029: the same ladder is not a debut season.
	_check(not _ids({}, _ctx("GEE", "HAW", ladder19, 2029)).has("tas_debut_finals"),
			"The debut achievement only applies in the first season")
	# 2028 but Tasmania outside the top ten -> no finals achievement.
	var tas_outside := _insert(base, "TAS", 12)  # 13th
	_check(not _ids({}, _ctx("GEE", "HAW", _ladder(tas_outside), 2028)).has("tas_debut_finals"),
			"Missing the 2028 finals is no debut achievement")
	# 2030: Canberra debuts. 10th (top-12) unlocks, 19th does not.
	var with_both := _insert(_insert(base, "TAS", 6), "CANB", 9)
	var ladder20 := _ladder(with_both)
	_check(with_both.size() == 20, "Twenty clubs in the 2030 ladder")
	_check(_ids({}, _ctx("GEE", "HAW", ladder20, 2030)).has("canb_debut_top"),
			"A 10th-place 2030 debut makes the top-12 achievement")
	var canb_low := _insert(_insert(base, "TAS", 6), "CANB", 18)  # 19th
	_check(not _ids({}, _ctx("GEE", "HAW", _ladder(canb_low), 2030)).has("canb_debut_top"),
			"A 19th-place 2030 debut misses the top-12 achievement")


func _test_no_double_unlock() -> void:
	var ladder := _ladder(_codes())
	var ctx := _ctx("ADE", "GEE", ladder)
	var out := _ids({"ade_first_flag": {"year": 2025}}, ctx)
	_check(not out.has("ade_first_flag"), "An unlocked achievement is never re-reported")


func _test_full_season() -> void:
	GameState.reset()
	GameState.start_season("GEE", GameDB.club_list("GEE"))
	var guard := 0
	while not GameState.season.is_season_over() and guard < 40:
		GameState.advance()
		guard += 1
	_check(GameState.season.is_season_over(), "The season completes")
	_check(GameState.achievements is Dictionary, "Achievements are a dictionary of unlocks")
	var known := {}
	for d in Achievements.DEFINITIONS:
		known[str(d["id"])] = true
	for id in GameState.achievements:
		_check(known.has(str(id)), "Only catalogued achievements unlock (%s)" % str(id))
		_check(int(GameState.achievements[id].get("year", 0)) == 2026,
				"%s is stamped with the season it unlocked" % str(id))
	# The premier's own premiership-type achievement must have fired.
	var prem := GameState.premier()
	var defn := Achievements.definition("")
	for d in Achievements.DEFINITIONS:
		if str(d["club"]) == prem:
			defn = d
			break
	if str(defn.get("type", "")) == "premiership":
		_check(GameState.achievements.has(str(defn["id"])),
				"The premier's premiership achievement unlocked")
	# The whole state survives a save and load.
	_check(GameState.save_career(), "The career saves")
	var before := GameState.achievements.duplicate()
	_check(GameState.load_career(), "The career loads")
	_check(GameState.achievements == before, "Achievements survive a save and load")
