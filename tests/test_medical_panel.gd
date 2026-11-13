extends RefCounted
## The concussion medical panel (director, 2026-11-11: "if a player gets 5 or
## more concussions within a 5 year period, they should have to pass a medical
## retirement check"; flat odds each time; straight after the fifth).
## The count over a moving five-season window, no sitting at four, a sitting at
## five and at each one after, flat seeded odds, a failed sitting ends the
## career that week for any club, the coach is told with the odds, an old save
## loads, and no other dice move. Run through tests/run_medical_panel_tests.gd.

var failures: Array[String] = []
var checks := 0

## Every season here is seeded: a clock seed makes a different league each run.
const SUITE_SEED := 4411


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	_t("_test_window_moves")
	_t("_test_flat_odds")
	_t("_test_shown_percentage")
	_t("_test_no_sitting_at_four")
	_t("_test_sits_at_five_and_each_after")
	_t("_test_not_cleared_ends_career")
	_t("_test_rivals_get_it")
	_t("_test_through_a_round")
	_t("_test_old_save_loads")
	_t("_test_no_other_dice_move")
	_t("_test_line_in_every_path")
	_t("_test_two_in_a_week")
	_t("_test_press_never_names_him")
	_t("_test_retirement_is_on_the_books")
	_t("_test_a_player_short_still_trades")
	_t("_test_midseason_draft_fills_the_spot")
	_t("_test_short_with_rookie_spots_full")
	_t("_test_grand_final_week")
	GameState.replay_seed = 0
	print(Ran.line("Medical panel", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _career(club := "FRE") -> void:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.start_season(club, GameDB.club_list(club))
	GameState.last_label = "Round 3"


## `n` concussions on his record, one a season, the latest `back` seasons ago.
func _past(p: Dictionary, n: int, back := 1) -> void:
	for i in range(n):
		CareerFacts.add(GameState.career_facts, str(p["id"]), CareerFacts.row(
				GameState.season_year - back - i, "Round 9", "injury", str(p.get("club", "")), "", "concussion"))


## A concussion this week, as the match's injuries hand it on.
func _concuss(p: Dictionary, club: String) -> void:
	p["injury_weeks"] = Injuries.CONCUSSION_MIN
	p["injury_kind"] = "concussion"
	GameState._log_injuries([{"id": str(p["id"]), "club": club, "weeks": Injuries.CONCUSSION_MIN,
			"kind": "concussion"}], GameState.last_label)


## A player of `club` whose sitting on concussion number `nth` of his career
## goes the way asked (and the next one too, when `then` is given).
func _pick(club: String, nth: int, want: bool, then = null) -> Dictionary:
	for p in GameState.season.lists[club]:
		var id := str(p["id"])
		if GameState.career_facts.has(id):
			continue
		if MedicalPanel.cleared(GameState.career_seed, id, GameState.season_year, nth) != want:
			continue
		if then != null and MedicalPanel.cleared(GameState.career_seed, id, GameState.season_year, nth + 1) != then:
			continue
		return p
	return {}


func _medical_news() -> Array:
	return GameState.news.filter(func(n): return str(n.get("kind", "")) == "medical")


func _on_a_list(id: String) -> bool:
	for arr in [GameState.my_list] + GameState.season.lists.values() + GameState.league_lists.values():
		for p in arr:
			if str(p.get("id", "")) == id:
				return true
	return false


func _test_window_moves() -> void:
	var store := {}
	for y in [2026, 2027, 2028, 2029, 2030]:
		CareerFacts.add(store, "a", CareerFacts.row(y, "Round 2", "injury", "FRE", "", "concussion"))
	CareerFacts.add(store, "a", CareerFacts.row(2030, "Round 5", "injury", "FRE", "", "hamstring"))
	CareerFacts.add(store, "a", CareerFacts.row(2030, "Round 7", "injury", "FRE", "", ""))
	_check(MedicalPanel.count(store, "a", 2030) == 5,
			"Five concussions in this season and the four before all count (%d)" % MedicalPanel.count(store, "a", 2030))
	_check(MedicalPanel.count(store, "a", 2031) == 4,
			"A season on, the one from six seasons ago no longer counts (%d)" % MedicalPanel.count(store, "a", 2031))
	_check(MedicalPanel.count(store, "a", 2035) == 0 and MedicalPanel.count_ever(store, "a") == 5,
			"Five seasons on none of them count, though all five stay on his record")
	_check(MedicalPanel.count(store, "nobody", 2030) == 0, "A player with no record has had none")
	_check(MedicalPanel.count(store, "a", 2029) == 4, "A concussion from a later season is not counted early")
	_check(not MedicalPanel.sits(4) and MedicalPanel.sits(5) and MedicalPanel.sits(7),
			"The panel sits at five and above, never at four")


func _test_flat_odds() -> void:
	var by_nth := {}
	var all := 0
	var total := 0
	for nth in [5, 6, 9]:
		var ok := 0
		for i in range(4000):
			if MedicalPanel.cleared(SUITE_SEED + i % 7, "p%d" % i, 2026 + i % 5, nth):
				ok += 1
		by_nth[nth] = float(ok) / 4000.0
		all += ok
		total += 4000
	var share := float(all) / float(total)
	_check(absf(share - MedicalPanel.CLEAR_CHANCE) < 0.02,
			"Over %d sittings the share cleared is the stated chance (%.3f against %.2f)" % [
					total, share, MedicalPanel.CLEAR_CHANCE])
	for nth in by_nth:
		_check(absf(float(by_nth[nth]) - MedicalPanel.CLEAR_CHANCE) < 0.03,
				"The odds are flat: sitting on concussion %d clears %.3f" % [nth, by_nth[nth]])
	var same := true
	for i in range(200):
		if MedicalPanel.cleared(77, "p%d" % i, 2030, 5) != MedicalPanel.cleared(77, "p%d" % i, 2030, 5):
			same = false
	_check(same, "The same career, player, season and concussion always gets the same answer")


func _test_shown_percentage() -> void:
	var pct := "%d%%" % int(round(MedicalPanel.CLEAR_CHANCE * 100.0))
	_check(MedicalPanel.warning(2) == "" and MedicalPanel.warning(0) == "",
			"Below %d the count is not shown" % MedicalPanel.SHOWN_FROM)
	_check(MedicalPanel.warning(4).contains(pct) and MedicalPanel.warning(4).begins_with("4 concussions in 5 years. One more"),
			"At four the line says one more brings the panel, with the chance: %s" % MedicalPanel.warning(4))
	_check(MedicalPanel.warning(3).contains("Two more") and MedicalPanel.warning(3).contains(pct),
			"At three it says two more: %s" % MedicalPanel.warning(3))
	_check(MedicalPanel.warning(5).contains("sits again") and MedicalPanel.warning(5).contains(pct),
			"At five it says another one brings it again: %s" % MedicalPanel.warning(5))
	for cleared in [true, false]:
		var row := {"name": "Sam Hale", "count": 5, "cleared": cleared, "pct": MedicalPanel.clear_pct()}
		_check(MedicalPanel.result_line(row).contains(pct) and MedicalPanel.result_short(row).contains(pct),
				"The week's result states the chance (%s)" % MedicalPanel.result_short(row))
		_check(MedicalPanel.result_line(row).begins_with("Sam Hale had his 5th concussion in 5 years"),
				"It opens on his name and the count: %s" % MedicalPanel.result_line(row))
	# The short lines are whole sentences, so a week of them reads as prose.
	var gone := MedicalPanel.result_short({"name": "Josh Treacy", "cleared": false, "pct": 50})
	_check(gone == "Josh Treacy was not cleared to keep playing. He had a 50% chance. His career is over.",
			"The short line for a career ended is a whole sentence: %s" % gone)
	var kept := MedicalPanel.result_short({"name": "Shai Bolton", "cleared": true, "pct": 50})
	_check(kept == "Shai Bolton was cleared to keep playing once he recovers (a 50% chance).",
			"The short line for a player cleared is a whole sentence: %s" % kept)
	# The sheet shows the same line for a player on four.
	_career()
	var p: Dictionary = GameState.my_list[0]
	_past(p, 4)
	var host := Control.new()
	host.size = Vector2(390, 844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var sheet := PlayerSheet.open(host, p)
	var label := host.find_child("ProfileConcussions", true, false) as Label
	_check(label != null and label.text == MedicalPanel.warning(4) and label.text.contains(pct),
			"The player sheet shows it: %s" % (label.text if label != null else "no line"))
	if sheet != null and is_instance_valid(sheet):
		sheet.queue_free()
	host.queue_free()
	var clean: Dictionary = GameState.my_list[1]
	var host2 := Control.new()
	host2.size = Vector2(390, 844)
	tree.root.add_child(host2)
	PlayerSheet.open(host2, clean)
	_check(host2.find_child("ProfileConcussions", true, false) == null,
			"A player with none has no such line")
	host2.queue_free()


func _test_no_sitting_at_four() -> void:
	_career()
	var p: Dictionary = GameState.my_list[2]
	_past(p, 3)
	_concuss(p, "FRE")
	_check(GameState.concussions_in_window(p) == 4, "He is on four in five years")
	_check(GameState.last_medical.is_empty() and _medical_news().is_empty() and _on_a_list(str(p["id"])),
			"Four brings no sitting and no news; he stays on the list")
	_check(int(p.get("injury_weeks", 0)) == Injuries.CONCUSSION_MIN, "He serves the normal protocol")
	# Five on his record, but one of them six seasons ago: still no sitting.
	var q: Dictionary = GameState.my_list[3]
	_past(q, 3)
	CareerFacts.add(GameState.career_facts, str(q["id"]), CareerFacts.row(
			GameState.season_year - 5, "Round 1", "injury", "FRE", "", "concussion"))
	_concuss(q, "FRE")
	_check(MedicalPanel.count_ever(GameState.career_facts, str(q["id"])) == 5
			and GameState.concussions_in_window(q) == 4 and GameState.last_medical.is_empty(),
			"Five in six seasons is four in the window: no sitting")
	# Other injuries never count.
	var r: Dictionary = GameState.my_list[4]
	_past(r, 4)
	GameState._log_injuries([{"id": str(r["id"]), "club": "FRE", "weeks": 3, "kind": "hamstring"}], "Round 3")
	_check(GameState.last_medical.is_empty(), "A hamstring on top of four concussions brings no sitting")


func _test_sits_at_five_and_each_after() -> void:
	_career()
	var p := _pick("FRE", 5, true, true)
	_check(not p.is_empty(), "A Fremantle player the panel clears twice exists in this seed")
	if p.is_empty():
		return
	var id := str(p["id"])
	_past(p, 4)
	_concuss(p, "FRE")
	_check(GameState.last_medical.size() == 1 and int(GameState.last_medical[0]["count"]) == 5
			and bool(GameState.last_medical[0]["cleared"]),
			"The fifth in five years brings the panel that week: %s" % [GameState.last_medical])
	_check(_on_a_list(id) and int(p.get("injury_weeks", 0)) == Injuries.CONCUSSION_MIN
			and not GameState.departed_names.has(id),
			"Cleared, he stays on the list and serves the normal protocol")
	var news := _medical_news()
	_check(news.size() == 1 and str(news[0]["text"]).contains("cleared him to keep playing")
			and str(news[0]["text"]).contains("%d%%" % MedicalPanel.clear_pct())
			and str(news[0]["text"]).begins_with(GameDB.player_display_name(p)),
			"The coach is told that week, with the chance: %s" % [news])
	_check(GameState.my_medical_lines().size() == 1
			and str(GameState.my_medical_lines()[0]).contains("was cleared to keep playing once he recovers (a %d%% chance)." % MedicalPanel.clear_pct()),
			"The week's injury surface carries it: %s" % [GameState.my_medical_lines()])
	# The next one is another sitting at the same odds.
	p["injury_weeks"] = 0
	_concuss(p, "FRE")
	_check(GameState.last_medical.size() == 2 and int(GameState.last_medical[1]["count"]) == 6
			and int(GameState.last_medical[1]["pct"]) == MedicalPanel.clear_pct(),
			"A sixth brings the panel again at the same stated chance")
	_check(_medical_news().size() == 2 and _on_a_list(id), "Cleared again, he plays on")
	# A week later the surface no longer repeats it.
	GameState._process_injuries([{"home": "FRE", "away": "MEL", "round": 3, "label": "Round 4", "injuries": []}])
	_check(GameState.my_medical_lines().is_empty(), "Next week the notice is gone")


func _test_not_cleared_ends_career() -> void:
	_career()
	var p := _pick("FRE", 5, false)
	_check(not p.is_empty(), "A Fremantle player the panel does not clear exists in this seed")
	if p.is_empty():
		return
	var id := str(p["id"])
	var who := GameDB.player_display_name(p)
	var before := GameState.my_list.size()
	_past(p, 4)
	_concuss(p, "FRE")
	_check(GameState.last_medical.size() == 1 and not bool(GameState.last_medical[0]["cleared"]),
			"The panel sat and did not clear him")
	_check(not _on_a_list(id) and GameState.my_list.size() == before - 1
			and (GameState.season.lists["FRE"] as Array).size() == before - 1,
			"He is off every list that week and the list is one short (%d of %d)" % [GameState.my_list.size(), before])
	_check(GameState.departed_names.has(id) and int(p.get("contract_years", -1)) == 0
			and not p.has("injury_weeks"),
			"His career is over through the career-over path: his name is kept, his contract ends")
	var news := _medical_news()
	_check(news.size() == 1 and str(news[0]["text"]).begins_with(who)
			and str(news[0]["text"]).contains("did not clear him")
			and str(news[0]["text"]).contains("He had a %d%% chance. His career is over" % MedicalPanel.clear_pct())
			and str(news[0].get("club", "")) == "FRE",
			"The coach is told that week, with the chance: %s" % [news])
	_check(GameState.my_medical_lines().size() == 1
			and str(GameState.my_medical_lines()[0]).contains("was not cleared to keep playing. He had a %d%% chance. His career is over." % MedicalPanel.clear_pct()),
			"The week's injury surface carries it: %s" % [GameState.my_medical_lines()])
	var story := NewsFront.story(news[0], "FRE")
	_check(str(story.get("headline", "")).contains(who) and str(story.get("headline", "")).contains("career"),
			"The news front leads with it: %s" % story.get("headline", ""))
	# The list is still a list a side can be picked from, and the season plays on.
	var picked := Ratings.select_side(GameState.my_list, {"MID": [id]})
	var side: Array = (picked["ground"] as Array) + (picked["bench"] as Array)
	var has_him := side.any(func(s): return str(s.get("id", "")) == id)
	_check(side.size() >= 22 and not has_him,
			"A full side is picked without him, even when he is still named (%d)" % side.size())
	var round_before := GameState.season.round_index
	GameState.advance()
	_check(GameState.season.round_index == round_before + 1 and not _on_a_list(id),
			"The next round plays with the list a player short")
	_check(GameState.save_career() and GameState.load_career() and not _on_a_list(id)
			and GameState.departed_names.has(id),
			"Saved and loaded, he is still retired")
	GameState.delete_saved_career()


func _test_rivals_get_it() -> void:
	_career()
	var rival := "MEL"
	var p := _pick(rival, 5, false)
	_check(not p.is_empty(), "A Melbourne player the panel does not clear exists in this seed")
	if p.is_empty():
		return
	var id := str(p["id"])
	var who := GameDB.player_display_name(p)
	var before := (GameState.season.lists[rival] as Array).size()
	_past(p, 4)
	_concuss(p, rival)
	_check(not _on_a_list(id) and (GameState.season.lists[rival] as Array).size() == before - 1
			and GameState.departed_names.has(id),
			"A rival's player who is not cleared is retired the same way")
	var news := _medical_news()
	_check(news.size() == 1 and str(news[0]["text"]).contains(who)
			and str(news[0]["text"]).contains(GameDB.club_name(rival))
			and str(news[0]["text"]).contains("played his last game"),
			"League news carries a rival's medical retirement: %s" % [news])
	_check(GameState.my_medical_lines().is_empty(), "It is not listed among your own players' sittings")
	# A rival who is cleared plays on at his club.
	var q := _pick(rival, 5, true)
	if not q.is_empty():
		_past(q, 4)
		_concuss(q, rival)
		_check(_on_a_list(str(q["id"])) and GameState.last_medical.size() == 2
				and bool(GameState.last_medical[1]["cleared"]),
				"A rival's player who is cleared plays on")
	var theirs := Ratings.select_side(GameState.season.lists[rival])
	_check((theirs["ground"] as Array).size() + (theirs["bench"] as Array).size() >= 22,
			"The rival still fields a full side")


## The round's own path: the match hands on a concussion, the panel sits once
## the round is counted, and a retired player is not among the week's injured.
func _test_through_a_round() -> void:
	_career()
	var p := _pick("FRE", 5, false)
	var q := _pick("FRE", 5, true)
	_check(not p.is_empty() and not q.is_empty(), "One player for each answer exists in this seed")
	if p.is_empty() or q.is_empty():
		return
	_past(p, 4)
	_past(q, 4)
	var res := {"home": "FRE", "away": "MEL", "round": 2, "label": "Round 3", "injuries": [
			{"side": 0, "id": str(p["id"]), "weeks": 2, "kind": "concussion"},
			{"side": 0, "id": str(q["id"]), "weeks": 2, "kind": "concussion"}]}
	GameState._process_injuries([res])
	_check(GameState.last_medical.size() == 2, "Both fifth concussions bring the panel (%d)" % GameState.last_medical.size())
	var hurt := GameState.last_injuries.map(func(r): return str(r["id"]))
	_check(hurt.has(str(q["id"])) and not hurt.has(str(p["id"])),
			"The cleared player is among the week's injured; the retired one is not")
	_check(_on_a_list(str(p["id"])), "He is still on the list while the round is being counted")
	GameState._settle_medical()
	_check(not _on_a_list(str(p["id"])) and _on_a_list(str(q["id"])),
			"Once the round is counted he is gone and the cleared player stays")
	_check(GameState.my_medical_lines().size() == 2, "Both sittings are on the week's surface")
	# The next round's injuries clear last week's sittings.
	GameState._process_injuries([{"home": "FRE", "away": "MEL", "round": 3, "label": "Round 4", "injuries": []}])
	_check(GameState.last_medical.is_empty(), "Next round starts with no sittings")


const OLD_SAVE_FIXTURE := "res://tests/fixtures/career_v1_2026-09-30.save.gz"


func _test_old_save_loads() -> void:
	# A real save from the 2026-09-30 build: no sittings, nobody near the panel.
	GameState.delete_saved_career()
	var gz := FileAccess.get_file_as_bytes(OLD_SAVE_FIXTURE)
	var raw := gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_buffer(raw)
	f.close()
	GameState.reset()
	_check(GameState.load_career(), "The older save opens")
	var most := 0
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			most = maxi(most, GameState.concussions_in_window(p))
	_check(GameState.last_medical.is_empty() and most == 0 and GameState.my_medical_lines().is_empty(),
			"It has no sittings and nobody has a counted concussion (most %d)" % most)
	GameState.advance()
	_check(GameState.season.round_index == 3, "It keeps playing")
	GameState.delete_saved_career()
	# An injury an older save kept as a bare year has no kind: never a concussion.
	_career()
	var p: Dictionary = GameState.my_list[0]
	p["injury_log"] = [GameState.season_year, GameState.season_year, GameState.season_year,
			GameState.season_year - 1, GameState.season_year - 1, GameState.season_year - 2]
	_check(GameState.save_career() and GameState.load_career(), "A career with an old injury record saves and loads")
	p = GameState.list_player(str(p["id"]))
	_check(GameState.concussions_in_window(p) == 0 and MedicalPanel.warning(GameState.concussions_in_window(p)) == "",
			"Six old injuries with no kind recorded are not concussions")
	# A save written before the panel has no last_medical; one written after keeps it.
	var state: Dictionary = GameState._save_state()
	state.erase("last_medical")
	_check(GameState._restore_career(state) and GameState.last_medical.is_empty(),
			"A save without the key loads with no sittings")
	var q := _pick("FRE", 5, true)
	if not q.is_empty():
		_past(q, 4)
		_concuss(q, "FRE")
		_check(GameState.save_career() and GameState.load_career() and GameState.last_medical.size() == 1
				and GameState.my_medical_lines().size() == 1 and GameState.concussions_in_window(GameState.list_player(str(q["id"]))) == 5,
				"The week's sitting and his count survive a save and load")
	GameState.delete_saved_career()


## The panel draws from its own seeded dice: the shared dice and a seeded
## season's results are the same whether or not it sits.
func _test_no_other_dice_move() -> void:
	seed(9001)
	var plain := [randi(), randi(), randi()]
	seed(9001)
	var with := []
	for i in range(3):
		MedicalPanel.cleared(SUITE_SEED, "p%d" % i, 2030, 5)
		with.append(randi())
	_check(plain == with, "A sitting leaves the shared dice where they were")
	# Two identical seeded careers; in the second, every player the panel would
	# clear is one concussion from it, so it sits (and clears) through the
	# rounds. Until a sitting retires someone (a different list from then on)
	# every result must be identical.
	var a := _rounds(false)
	var b := _rounds(true)
	var compared := 0
	var sat_before := false
	for i in range(mini(a["results"].size(), b["results"].size())):
		if int(b["retired_before"][i]) > 0:
			break
		_check(a["results"][i] == b["results"][i], "Round %d is identical with the panel sitting" % (i + 1))
		compared += 1
		if int(b["sat_before"][i]) > 0:
			sat_before = true
	_check(compared >= 1, "At least one round was compared (%d)" % compared)
	_check(int(a["sat"]) == 0, "Nobody was near the panel in the plain career (%d sittings)" % int(a["sat"]))
	_check(sat_before, "A round after a sitting was compared (sittings %d, compared %d)" % [int(b["sat"]), compared])
	print("  no-other-dice: compared %d rounds, sittings in the loaded career %d, a compared round followed a sitting: %s" % [
			compared, int(b["sat"]), sat_before])


func _rounds(loaded: bool) -> Dictionary:
	GameState.reset()
	GameState.career_seed = SUITE_SEED
	GameState.replay_seed = SUITE_SEED
	GameState.start_season("FRE", GameDB.club_list("FRE"))
	if loaded:
		for code in GameState.season.lists:
			for p in GameState.season.lists[code]:
				if MedicalPanel.cleared(GameState.career_seed, str(p["id"]), GameState.season_year, 5):
					_past(p, 4)
	var out := {"results": [], "sat_before": [], "retired_before": [], "sat": 0}
	var sat := 0
	var retired := 0
	for i in range(6):
		out["sat_before"].append(sat)
		out["retired_before"].append(retired)
		GameState.advance()
		out["results"].append(var_to_str(GameState.last_results.map(func(r): return [
				r.get("home"), r.get("away"), r.get("score"), r.get("injuries")])))
		for row in GameState.last_medical:
			sat += 1
			if not bool(row["cleared"]):
				retired += 1
	out["sat"] = sat
	return out


## Four concussions on his record so the next is his fifth in five years and
## the panel's answer to it is `want`: older ones are added until the count of
## his career lands on a sitting that goes that way.
func _one_from_the_panel(p: Dictionary, want: bool) -> bool:
	var id := str(p["id"])
	if MedicalPanel.count_ever(GameState.career_facts, id) != 0:
		return false
	for nth in range(5, 60):
		if MedicalPanel.cleared(GameState.career_seed, id, GameState.season_year, nth) == want:
			_past(p, nth - 1)
			return GameState.concussions_in_window(p) == 4
	return false


## Cuts `club` to `n` players, weakest first and never `keep`. Returns those cut.
func _trim(club: String, n: int, keep: Dictionary) -> Array:
	var list: Array = GameState.season.lists[club]
	var spare := list.filter(func(q): return str(q["id"]) != str(keep.get("id", "")))
	spare.sort_custom(func(a, b): return int(a.get("overall", 0)) < int(b.get("overall", 0)))
	var cut := []
	while list.size() > n and not spare.is_empty():
		var q: Dictionary = spare.pop_front()
		list.erase(q)
		if GameState.league_lists.has(club):
			(GameState.league_lists[club] as Array).erase(q)
		if club == GameState.my_club:
			GameState.my_list.erase(q)
		cut.append(q)
	return cut


## In a first season nobody is in the mid-season draft's pool (no free agents,
## no passed-over prospects), and each club with a rookie spot free picks
## before a short club lower on the ladder. Every other club gives its players
## over the minimum to the pool, so it holds one for every club in the order.
func _fill_pool(skip: Array) -> void:
	for code in GameState.season.lists:
		if skip.has(str(code)):
			continue
		for q in _trim(str(code), Contracts.min_list(), {}):
			q["released_by"] = str(code)
			GameState.free_agents.append(q)
	_check(MidseasonDraft.pool(GameState).size() > GameState.season.lists.size(),
			"The draft's pool holds a player for every club (%d)" % MidseasonDraft.pool(GameState).size())


## The coach's own player's sitting is on the week's surface wherever it can
## happen: a final whose week is named differently from its match (a simulated
## finals week), a final he played, and the practice match. Nothing is matched
## on a round's name.
func _test_line_in_every_path() -> void:
	_career()
	var p := _pick("FRE", 5, true)
	var q := _pick("FRE", 5, false)
	_check(not p.is_empty() and not q.is_empty(), "One player for each answer exists in this seed")
	if p.is_empty() or q.is_empty():
		return
	_past(p, 4)
	_past(q, 4)
	# A simulated finals week: the week is "Semi Finals", the match "Semi Final 1".
	GameState.last_label = "Semi Finals"
	GameState._process_injuries([{"home": "FRE", "away": "MEL", "round": 25, "label": "Semi Final 1", "tag": "SF1",
			"injuries": [{"side": 0, "id": str(p["id"]), "weeks": 2, "kind": "concussion"}]}])
	GameState._settle_medical()
	_check(GameState.my_medical_lines().size() == 1 and str(GameState.my_medical_lines()[0]).contains("was cleared to keep playing once he recovers (a %d%% chance)." % MedicalPanel.clear_pct()),
			"A sitting in a simulated finals week is on the week's surface: %s" % [GameState.my_medical_lines()])
	# A final he played, and this one ends a career.
	GameState.last_label = "Preliminary Final"
	GameState._process_injuries([{"home": "MEL", "away": "FRE", "round": 26, "label": "Preliminary Final 2", "tag": "PF2",
			"injuries": [{"side": 1, "id": str(q["id"]), "weeks": 2, "kind": "concussion"}]}])
	GameState._settle_medical()
	_check(GameState.my_medical_lines().size() == 1
			and str(GameState.my_medical_lines()[0]).contains("was not cleared to keep playing. He had a %d%% chance. His career is over." % MedicalPanel.clear_pct())
			and str(GameState.my_medical_lines()[0]).begins_with(GameDB.player_display_name(q)),
			"A sitting in a final is on the week's surface, and last week's is gone: %s" % [GameState.my_medical_lines()])
	# A rival's sitting the same week is never among yours.
	var r := _pick("MEL", 5, false)
	if not r.is_empty():
		_past(r, 4)
		GameState._process_injuries([{"home": "MEL", "away": "FRE", "round": 27, "label": "Grand Final", "tag": "GF",
				"injuries": [{"side": 0, "id": str(r["id"]), "weeks": 2, "kind": "concussion"}]}])
		GameState._settle_medical()
		_check(GameState.last_medical.size() == 1 and GameState.my_medical_lines().is_empty(),
				"A rival's sitting is not listed among yours")
	# The practice match: the report carries the sitting, and he is not among its hurt.
	_career()
	var s := _pick("FRE", 5, false)
	var t := _pick("FRE", 5, true)
	if s.is_empty() or t.is_empty():
		return
	_past(s, 4)
	_past(t, 4)
	var ids := GameState.my_list.map(func(x): return str(x["id"]))
	var built := {"home": "FRE", "away": "WCE", "started": {}, "ids": {"FRE": ids}, "guests": {"FRE": []}}
	var rep: Dictionary = GameState._practice_finish("FRE", built, {"players": {}, "injuries": [
			{"id": str(s["id"]), "weeks": 2, "kind": "concussion"}, {"id": str(t["id"]), "weeks": 2, "kind": "concussion"}]})
	var sat: Array = rep.get("medical", [])
	_check(sat.size() == 2 and str(sat[0]).contains("was not cleared to keep playing. He had a %d%% chance. His career is over." % MedicalPanel.clear_pct()) and str(sat[1]).contains("was cleared to keep playing once he recovers (a %d%% chance)." % MedicalPanel.clear_pct()),
			"The practice match report carries both sittings: %s" % [sat])
	var hurt: Array = rep.get("hurt", [])
	_check(hurt.size() == 1 and str(hurt[0]).begins_with(GameDB.player_display_name(t)),
			"Its hurt list has the cleared player and not the retired one: %s" % [hurt])
	_check(not _on_a_list(str(s["id"])) and GameState.my_medical_lines().size() == 2
			and not GameState.last_injuries.any(func(x): return str(x["id"]) == str(s["id"])),
			"He is retired that week, the surface carries it and he is not among the week's injured")
	# The report on screen shows it under its own head.
	var scene: Control = load("res://scripts/ui/PreSeasonScene.gd").new()
	var view: Control = scene.call("_match_report", rep, "Practice", [])
	var line := view.find_child("PracticeMedical_0", true, false) as Label
	_check(line != null and line.text == str(sat[0]), "The report screen shows it: %s" % (line.text if line != null else "no line"))
	var kept_line := view.find_child("PracticeMedical_1", true, false) as Label
	_check(line != null and kept_line != null and line.get_theme_color("font_color") == UiKit.BAD
			and kept_line.get_theme_color("font_color") == UiKit.TEXT,
			"The career ended is in the injury red, the cleared player in body ink")
	view.free()
	scene.free()


## Two of yours before the panel in the same week: the hub's result and the
## match summary's "Your week" give one line each, the first headed "Medical
## panel:". The career ended is in the injury red; the cleared player is good
## news, in body ink.
func _test_two_in_a_week() -> void:
	_career()
	GameState.advance()
	var p := _pick("FRE", 5, true)
	var q := _pick("FRE", 5, false)
	_check(not p.is_empty() and not q.is_empty(), "One player for each answer exists in this seed")
	if p.is_empty() or q.is_empty():
		return
	_past(p, 4)
	_past(q, 4)
	_concuss(p, "FRE")
	_concuss(q, "FRE")
	var rows := GameState.my_medical_rows()
	_check(rows.size() == 2 and GameState.my_medical_lines().size() == 2, "Both sittings are on the week's surface: %s" % [rows])
	if rows.size() != 2:
		return
	# The hub's result for the round.
	var hub: Control = load("res://scripts/ui/HubScene.gd").new()
	var hv := VBoxContainer.new()
	hub.call("_my_result", hv, GameState._my_result(GameState.last_results))
	_check_lines(hv, "MyMedical", rows, "The hub")
	hv.free()
	hub.free()
	# The match summary's Your week.
	var ms: Control = load("res://scripts/ui/MatchScene.gd").new()
	ms.set("_res", GameState.last_match)
	ms.set("_review", true)
	ms.set("_my_side", 0 if str(GameState.last_match.get("home", "")) == GameState.my_club else 1)
	var mv := VBoxContainer.new()
	ms.call("_ft_summary", mv)
	_check_lines(mv, "YourMedical", rows, "The match summary")
	mv.free()
	ms.free()


func _check_lines(box: Control, prefix: String, rows: Array, where: String) -> void:
	for i in range(rows.size()):
		var l := box.find_child("%s_%d" % [prefix, i], true, false) as Label
		var want := ("Medical panel: " if i == 0 else "") + str(rows[i]["text"])
		var ink: Color = UiKit.TEXT if bool(rows[i]["cleared"]) else UiKit.BAD
		_check(l != null and l.text == want and l.get_theme_color("font_color") == ink,
				"%s gives sitting %d its own line in %s: %s" % [where, i,
				"body ink" if bool(rows[i]["cleared"]) else "the injury red", l.text if l != null else "no line"])


## A player the panel has just ruled out is still on the list while the round
## is counted: no press question that round may name him.
func _test_press_never_names_him() -> void:
	_career()
	GameState.advance()
	var res: Dictionary = GameState._my_result(GameState.last_results).duplicate(true)
	_check(not res.is_empty(), "Fremantle played the round")
	if res.is_empty():
		return
	var side := 0 if str(res["home"]) == "FRE" else 1
	var hurt := {}
	for inj in GameState.last_injuries:
		hurt[str(inj["id"])] = true
	var before: Dictionary = GameState._press_named(res, side, hurt)
	var low := GameState.list_player(str((before.get("heavy_loss", {}) as Dictionary).get("id", "")))
	var best := GameState.list_player(str((before.get("big_win", {}) as Dictionary).get("id", "")))
	_check(not low.is_empty() and not best.is_empty() and low != best,
			"The round names a lowest-rated player and a best player")
	if low.is_empty() or best.is_empty() or low == best:
		return
	best["injury_weeks"] = 0
	_check(_one_from_the_panel(low, false) and _one_from_the_panel(best, false),
			"Both are one concussion from a sitting that does not clear them")
	# The best player also had a day worth a star question.
	((res["players"] as Dictionary)[str(best["id"])] as Dictionary)["goals"] = 7
	var injuries := []
	for p in [low, best]:
		injuries.append({"side": side, "id": str(p["id"]), "weeks": 2, "kind": "concussion"})
	var played := res.duplicate(true)
	played["injuries"] = injuries
	GameState._process_injuries([played])
	_check(GameState.last_medical.size() == 2 and _on_a_list(str(low["id"])) and _on_a_list(str(best["id"])),
			"The panel rules both out and they are still on the list while the round is counted (%d sittings)" % GameState.last_medical.size())
	var named: Dictionary = GameState._press_named(res, side, {})
	for key in named:
		var nid := str((named[key] as Dictionary).get("id", ""))
		_check(nid != str(low["id"]) and nid != str(best["id"]),
				"The %s question names somebody still playing (%s)" % [key, (named[key] as Dictionary).get("name", "")])
	_check(named.has("heavy_loss"), "There is still a player to name")
	GameState._prepare_media_conference([res])
	var asked := var_to_str(GameState.media_conference)
	for p in [low, best]:
		_check(not asked.contains(str(p["id"])) and not asked.contains(GameDB.player_display_name(p)),
				"That round's press conference does not name %s" % GameDB.player_display_name(p))
	GameState._settle_medical()
	_check(not _on_a_list(str(low["id"])) and not _on_a_list(str(best["id"])), "Both are retired once the round is counted")


## A mid-season medical retirement is kept like any other: his part-season is
## on his career record, he is among the season wrap's outs, a club legend
## goes on the almanac page, and a rival's has its one league-news line.
func _test_retirement_is_on_the_books() -> void:
	_career()
	var p := _pick("FRE", 5, false)
	var rv := _pick("MEL", 5, false)
	_check(not p.is_empty() and not rv.is_empty(), "A player the panel does not clear exists at each club")
	if p.is_empty() or rv.is_empty():
		return
	var id := str(p["id"])
	var year := GameState.season_year
	# 195 games for Fremantle before this season; seven more in it make him a 200-gamer.
	var c := Career.of(p)
	c["games"] = 195
	c["goals"] = 50
	c["stints"] = [["FRE", year - 10, year - 1, 195, 50]]
	c["through"] = year - 1
	GameState.season_tally[id] = {"club": "FRE", "games": 7, "goals": 3, "goals_ha": 3}
	GameState.almanac.append({"year": year, "club": "FRE", "legends": []})
	_past(p, 4)
	_concuss(p, "FRE")
	_check(not _on_a_list(id), "He is retired")
	c = Career.of(p)
	_check(int(c["games"]) == 202 and int(c["goals"]) == 53 and int(c["through"]) == year,
			"His part-season is on his career record: %d games, %d goals, through %d" % [int(c["games"]), int(c["goals"]), int(c["through"])])
	_check(GameState.games_played(p) == 202, "It is counted once (%d games)" % GameState.games_played(p))
	var snap := CoachPathway.snapshot(p, year, GameState.honour_roll)
	_check(int(snap["games"]) == 202 and int(snap["goals"]) == 53,
			"A coaching future starts from the full record (%d games)" % int(snap["games"]))
	_check(GameState.medical_retired.size() == 1 and str(GameState.medical_retired[0]["id"]) == id
			and int(GameState.medical_retired[0]["year"]) == year,
			"He is kept as one of this season's retirees")
	# A rival's retirement: one league-news line, and never one of your outs.
	_past(rv, 4)
	_concuss(rv, "MEL")
	var who := GameDB.player_display_name(rv)
	var about := GameState.news.filter(func(n): return str(n.get("text", "")).contains(who))
	_check(about.size() == 1 and str(about[0].get("kind", "")) == "medical",
			"A rival's retirement has its one league-news line (%d)" % about.size())
	_check(GameState.save_career() and GameState.load_career() and GameState.medical_retired.size() == 2,
			"Saved and loaded, the season's medical retirements are kept (%d)" % GameState.medical_retired.size())
	GameState.delete_saved_career()
	# The almanac's page for the season: he reached 200 games for the club.
	GameState._add_retired_legends({})
	var legends: Array = (GameState.almanac.back() as Dictionary).get("legends", [])
	_check(legends.size() == 1 and str(legends[0]["id"]) == id and int(legends[0]["games"]) == 202,
			"The almanac names him a legend of the club: %s" % [legends])
	# The wrap before next season's Round 1.
	GameState._build_season_wrap(year + 1)
	var outs: Array = GameState.season_wrap.get("outs", [])
	var mine := outs.filter(func(o): return str(o.get("id", "")) == id)
	_check(mine.size() == 1 and str(mine[0].get("how", "")) == "retired, medical panel"
			and str(mine[0].get("name", "")) == GameDB.player_display_name(p),
			"The season wrap lists him among the outs: %s" % [mine])
	_check(not outs.any(func(o): return str(o.get("id", "")) == str(rv["id"])), "A rival's retirement is not one of your outs")
	# A save written before this has no such record.
	var state: Dictionary = GameState._save_state()
	state.erase("medical_retired")
	_check(GameState._restore_career(state) and GameState.medical_retired.is_empty(),
			"A save without the record loads with none")


## The panel sits in the Grand Final week, the week the season closes and the
## off-season opens. A rival's player it does not clear (out of contract, so
## the off-season would re-sign, delist or release him) is retired before the
## off-season opens: no club re-signs him, releases him or retires him again,
## and he is never in the free-agent pool after his career has ended.
func _test_grand_final_week() -> void:
	_career()
	var guard := 0
	while guard < 60 and not GameState.season.is_season_over() and not (GameState.season.is_regular_done()
			and not GameState.season.finals.is_empty() and int(GameState.season.finals.get("week", 0)) == 5):
		guard += 1
		GameState.advance()
	_check(not GameState.season.is_season_over() and int(GameState.season.finals.get("week", 0)) == 5,
			"The season reaches Grand Final week (%d weeks)" % guard)
	if GameState.season.is_season_over():
		return
	# The Grand Final week's own steps, with the panel's concussion handed on by the match.
	GameState._advance_prep()
	GameState._advance_reset()
	GameState._play_week()
	_check(GameState.season.is_season_over() and GameState.last_results.size() == 1,
			"The Grand Final is played (%d results)" % GameState.last_results.size())
	if GameState.last_results.is_empty():
		return
	var res: Dictionary = GameState.last_results[0]
	var side := 1 if str(res.get("home", "")) == GameState.my_club else 0
	var club := str(res.get("away" if side == 1 else "home", ""))
	var p := {}
	for q in GameState.season.lists.get(club, []):
		var qid := str(q["id"])
		if MedicalPanel.count_ever(GameState.career_facts, qid) == 0 and int(q.get("injury_weeks", 0)) == 0 \
				and float(q.get("age", 40.0)) < 29.0 \
				and not MedicalPanel.cleared(GameState.career_seed, qid, GameState.season_year, 5):
			p = q
			break
	_check(not p.is_empty(), "A %s player the panel does not clear exists in this seed" % club)
	if p.is_empty():
		return
	var id := str(p["id"])
	p["contract_years"] = 1
	p.erase("retiring")
	p.erase("resigned")
	_past(p, 4)
	res["injuries"] = (res.get("injuries", []) as Array) + [{"side": side, "id": id, "weeks": 2, "kind": "concussion"}]
	# A rival board's letter would hold the off-season until he answers (this
	# seed's season earns one): the letter this year is already declined, so the
	# off-season opens with the Grand Final.
	ClubArcs._st(GameState)["letter"] = {"year": GameState.season_year, "answer": "declined"}
	GameState._log_week()
	GameState._week_xp()
	GameState._week_rivals()
	GameState._week_after()
	_check(GameState.offseason_year == GameState.season_year and not ClubMoves.letter_open(GameState),
			"The off-season has opened (off-season %d, season %d)" % [GameState.offseason_year, GameState.season_year])
	_check(GameState.last_medical.size() == 1 and not bool(GameState.last_medical[0]["cleared"])
			and GameState.medical_retired.any(func(r): return str(r.get("id", "")) == id),
			"The panel sat in Grand Final week and did not clear him")
	_check(not _on_a_list(id) and GameState.departed_names.has(id), "His career is over and he is on no list")
	_check(not GameState.free_agents.has(p)
			and not GameState.free_agents.any(func(q): return str(q.get("id", "")) == id),
			"He is not in the free-agent pool after his career ended")
	_check(not GameState.offseason_log.any(func(e): return str(e.get("id", "")) == id)
			and not p.has("resigned") and not p.has("retiring") and int(p.get("contract_years", -1)) == 0,
			"The off-season never saw him: not re-signed, released or retired again (%s)" % [
			GameState.offseason_log.filter(func(e): return str(e.get("id", "")) == id)])


## A medical retirement can leave a club one under the minimum list. While it
## is short, a trade that leaves its list no smaller is still legal; one that
## makes it smaller is not, and nothing changes for a club on the minimum.
func _test_a_player_short_still_trades() -> void:
	_career()
	var p := _pick("FRE", 5, false)
	_check(not p.is_empty(), "A Fremantle player the panel does not clear exists in this seed")
	if p.is_empty():
		return
	_trim("FRE", Contracts.min_list(), p)
	_check(GameState.my_list.size() == Contracts.min_list(), "Fremantle is on the minimum list (%d)" % GameState.my_list.size())
	_past(p, 4)
	_concuss(p, "FRE")
	var mine: Array = GameState.my_list
	_check(mine.size() == Contracts.min_list() - 1 and (GameState.season.lists["FRE"] as Array).size() == Contracts.min_list() - 1,
			"The retirement leaves it one short (%d)" % mine.size())
	var theirs: Array = GameState.season.lists["MEL"]
	var cap := 999999999
	var one := Contracts.evaluate_trade(theirs, [theirs[0]], [mine[0]], cap, mine, cap)
	_check(str(one["code"]) != "trade_list_under", "One for one stays legal while a player short (%s)" % one["code"])
	var grows := Contracts.evaluate_trade(theirs, [theirs[0], theirs[1]], [mine[0]], cap, mine, cap)
	_check(str(grows["code"]) != "trade_list_under", "A trade that brings the list back up is legal (%s)" % grows["code"])
	var shrinks := Contracts.evaluate_trade(theirs, [theirs[0]], [mine[0], mine[1]], cap, mine, cap)
	_check(str(shrinks["code"]) == "trade_list_under" and not bool(shrinks["ok"]),
			"A trade that makes the short list smaller is refused (%s)" % shrinks["code"])
	# The same for a rival that is a player short.
	var short_rival: Array = theirs.slice(0, Contracts.min_list() - 1)
	var full: Array = GameDB.club_list("GEE")
	var theirs_one := Contracts.evaluate_trade(short_rival, [short_rival[0]], [full[0]], cap, full, cap)
	_check(str(theirs_one["code"]) != "trade_list_under", "A rival a player short can deal one for one (%s)" % theirs_one["code"])
	var theirs_less := Contracts.evaluate_trade(short_rival, [short_rival[0], short_rival[1]], [full[0]], cap, full, cap)
	_check(str(theirs_less["code"]) == "trade_list_under", "...and not make its list smaller (%s)" % theirs_less["code"])
	# A club on the minimum is treated as before: it cannot go under it.
	var on_min: Array = full.slice(0, Contracts.min_list())
	var under := Contracts.evaluate_trade(theirs, [theirs[0]], [on_min[0], on_min[1]], cap, on_min, cap)
	_check(str(under["code"]) == "trade_list_under", "A club on the minimum still cannot trade under it (%s)" % under["code"])


## The open spot is one the mid-season rookie draft can fill, for your club and
## for a rival.
func _test_midseason_draft_fills_the_spot() -> void:
	_career()
	var p := _pick("FRE", 5, false)
	var rv := _pick("MEL", 5, false)
	_check(not p.is_empty() and not rv.is_empty(), "A player the panel does not clear exists at each club")
	if p.is_empty() or rv.is_empty():
		return
	var cut := _trim("FRE", Contracts.min_list(), p) + _trim("MEL", Contracts.min_list(), rv)
	_past(p, 4)
	_concuss(p, "FRE")
	_past(rv, 4)
	_concuss(rv, "MEL")
	_check(GameState.my_list.size() == Contracts.min_list() - 1
			and (GameState.season.lists["MEL"] as Array).size() == Contracts.min_list() - 1,
			"Both clubs are a player short")
	# The players cut above are the free agents the draft can take.
	for q in cut:
		q["released_by"] = str(q.get("club", ""))
		GameState.free_agents.append(q)
	_fill_pool(["FRE", "MEL"])
	GameState.midseason = {}
	MidseasonDraft._open_draft(GameState)
	var order: Array = GameState.midseason.get("order", [])
	_check(order.has("FRE") and order.has("MEL"), "Both clubs have a pick in the mid-season rookie draft: %s" % [order])
	var guard := 0
	while MidseasonDraft.waiting(GameState) and guard < 3:
		guard += 1
		var left := MidseasonDraft.pool(GameState)
		_check(not left.is_empty() and MidseasonDraft.choose(GameState, str(left[0]["id"])), "Your pick is made")
	_check(bool(GameState.midseason.get("done", false)), "The draft runs to its end")
	_check(GameState.my_list.size() == Contracts.min_list(),
			"Your pick brings the list back to the minimum (%d)" % GameState.my_list.size())
	_check((GameState.season.lists["MEL"] as Array).size() == Contracts.min_list(),
			"The rival's pick brings its list back to the minimum (%d)" % (GameState.season.lists["MEL"] as Array).size())


## A club a player short with every rookie spot taken still has the open spot
## counted: its pick fills the senior spot the retirement left.
func _test_short_with_rookie_spots_full() -> void:
	_career()
	var rv := _pick("MEL", 5, false)
	_check(not rv.is_empty(), "A Melbourne player the panel does not clear exists in this seed")
	if rv.is_empty():
		return
	var cut := _trim("MEL", Contracts.min_list(), rv)
	var list: Array = GameState.season.lists["MEL"]
	for q in list:
		if RookieList.rookie_count(list) >= RookieList.CAT_A_SPOTS:
			break
		if str(q["id"]) != str(rv["id"]) and not RookieList.is_rookie(q):
			q["rookie_list"] = "A"
	_check(not RookieList.rookie_spot_free(list), "Melbourne's rookie spots are all taken")
	_past(rv, 4)
	_concuss(rv, "MEL")
	_check(list.size() == Contracts.min_list() - 1, "Melbourne is a player short (%d)" % list.size())
	for q in cut:
		q["released_by"] = "MEL"
		GameState.free_agents.append(q)
	_fill_pool(["MEL"])
	GameState.midseason = {}
	MidseasonDraft._open_draft(GameState)
	while MidseasonDraft.waiting(GameState):
		var left := MidseasonDraft.pool(GameState)
		if left.is_empty() or not MidseasonDraft.choose(GameState, str(left[0]["id"])):
			break
	var order: Array = GameState.midseason.get("order", [])
	_check(order.has("MEL"), "Melbourne has a pick: %s" % [order])
	_check(list.size() == Contracts.min_list() and RookieList.rookie_count(list) == RookieList.CAT_A_SPOTS,
			"Its pick fills the senior spot (%d players, %d rookies)" % [list.size(), RookieList.rookie_count(list)])
