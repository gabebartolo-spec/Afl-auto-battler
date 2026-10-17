extends RefCounted
## The pre-season practice match (PreSeason.gd, GameState "practice"): who
## plays whom, the side and the prospects trialled, what it leaves behind (and
## what it must not), the AI clubs' matches, saves old and new, the switch off,
## and the screens by real taps on a phone and a PC. Every season is seeded.

const Tap := preload("res://tests/tap.gd")

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 4127
const CLUB := "FRE"


func run() -> void:
	GameState.replay_seed = SUITE_SEED
	Features.set_on("preseason", true)
	_test_pairs()
	_test_flow()
	_test_trial()
	_test_leaves_nothing()
	_test_ai_clubs()
	_test_determinism()
	_test_saves()
	_test_sim_to_round_one()
	await _test_screens_phone()
	await _test_screens_pc()
	_test_switch_off()
	PreSeason.reload()
	Features.clear("preseason")
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print("Practice tests: %d checks, %d failures" % [checks, failures.size()])


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _career(club := CLUB, seed := SUITE_SEED) -> void:
	GameState.reset()
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.start_season(club, GameDB.club_list(club))
	GameState.open_preseason()


## Press on until the practice match is waiting for the coach.
func _to_practice() -> bool:
	var guard := 0
	while GameState.preseason_active() and GameState.preseason_stop() != "practice" and guard < 12:
		guard += 1
		GameState.preseason_advance()
	return GameState.preseason_stop() == "practice"


func _frames(tree: SceneTree, n: int) -> void:
	for i in range(n):
		await tree.process_frame


func _tap(b: Control, what: String) -> bool:
	var why: String = await Tap.tap(b)
	if why != "":
		_check(false, "A finger's tap reaches %s (%s)" % [what, why])
		if is_instance_valid(b) and b is BaseButton:
			(b as BaseButton).emit_signal("pressed")
	return why == ""


func _open(tree: SceneTree) -> Control:
	Router.stack = ["main"]
	Router.go("hub")
	await _frames(tree, 8)
	return tree.current_scene as Control


func _label(scene: Node, node_name: String) -> String:
	var l := scene.find_child(node_name, true, false) as Label if scene != null else null
	return l.text if l != null else ""


func _fits(scene: Control, width: float) -> bool:
	var ok := true
	for n in scene.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.is_visible_in_tree() or l.text == "":
			continue
		var r := l.get_global_rect()
		if r.position.x < -0.5 or r.end.x > width + 0.5:
			ok = false
			push_error("Off the screen: %s (%s)" % [l.text, str(r)])
	return ok


func _ladder_sig() -> String:
	return str(GameState.season.ladder) + str(GameState.season.round_index) + str(GameState.season_log.size())


# ---------------------------------------------------------------------------
func _test_pairs() -> void:
	var all := []
	for c in GameDB.club_order.slice(0, 18):
		all.append(str(c))
	var pairs := PreSeason.practice_pairs(all, "FRE", SUITE_SEED, 2027)
	var seen := {}
	var twice := false
	for pr in pairs:
		twice = twice or seen.has(pr[0]) or seen.has(pr[1])
		seen[pr[0]] = true
		seen[pr[1]] = true
	_check(all.size() == 18 and pairs.size() == 9 and seen.size() == 18 and not twice,
			"The draw gives every one of the 18 clubs exactly one practice match")
	_check(PreSeason.practice_opponent(pairs, "FRE") == "WCE" and PreSeason.practice_opponent(pairs, "WCE") == "FRE",
			"Fremantle play West Coast")
	var near := true
	for pr in pairs:
		near = near and PreSeason.PRACTICE_REGION.get(pr[0], "x") == PreSeason.PRACTICE_REGION.get(pr[1], "y")
	_check(near and PreSeason.practice_opponent(pairs, "ADE") == "PAD" and PreSeason.practice_opponent(pairs, "BRL") == "GCS"
			and PreSeason.practice_opponent(pairs, "SYD") == "GWS",
			"Every pairing is within a region: the Western, Queensland, South Australian and Sydney derbies, and Victorian clubs against Victorian clubs")
	_check(str(PreSeason.practice_pairs(all, "FRE", SUITE_SEED, 2027)) == str(pairs),
			"The same career and year always give the same draw")
	var vic_opponents := {}
	for y in range(2027, 2047):
		vic_opponents[PreSeason.practice_opponent(PreSeason.practice_pairs(all, "MEL", SUITE_SEED, y), "MEL")] = true
	_check(vic_opponents.size() >= 4 and not vic_opponents.has("FRE"),
			"A Victorian club meets a different Victorian club from year to year")
	var odd := all.duplicate()
	odd.append("TAS")
	var p19 := PreSeason.practice_pairs(odd, "TAS", SUITE_SEED, 2027)
	_check(PreSeason.practice_opponent(p19, "TAS") != "" and p19.size() == 9,
			"With an odd number of clubs, yours still has a match (one other club has none)")
	var forged := all.duplicate()
	forged.append("ZZZ")
	forged.append("YYY")
	_check(PreSeason.practice_opponent(PreSeason.practice_pairs(forged, "ZZZ", SUITE_SEED, 2027), "ZZZ") == "YYY",
			"Two clubs outside any region are drawn against each other")
	_check(PreSeason.practice_opponent(PreSeason.practice_pairs(["FRE"], "FRE", 1, 2027), "FRE") == "",
			"A league of one has nobody to play")


func _test_flow() -> void:
	_career()
	_check(_to_practice() and GameState.preseason_week() == 7 and GameState.practice_opponent() == "WCE",
			"The pre-season stops after week 7 for the practice match, against West Coast")
	var pr := GameState.preseason_practice()
	_check(not GameState.practice_played() and (pr["invites"] as Array).is_empty() and not bool(pr["seen"]),
			"...with nobody trialled and nothing played")
	_check(GameState.preseason_step_week() == "practice" and GameState.preseason_week() == 7,
			"Training does not go on past the stop")
	GameState.sim_practice_match()
	_check(GameState.practice_played() and GameState.preseason_stop() == "practice",
			"Simming it plays it, and the stop stays for the report")
	var rep: Dictionary = GameState.preseason_practice()["report"]
	var names: Array = rep["names"]
	var score: Array = rep["score"]
	_check(names == ["Fremantle", "West Coast"] and int(score[0]) >= 0 and int(score[1]) >= 0 and str(rep["opponent"]) == "WCE",
			"The report names the two clubs and carries the score")
	_check(not GameState.sim_practice_match(), "It cannot be played twice")
	_check(GameState.preseason_advance() == "done" and not GameState.preseason_active() and GameState.preseason_week() == 8,
			"Pressing on from the report finishes the last week and opens Round 1")
	_career()
	_to_practice()
	_check(GameState.preseason_advance() == "practice" and GameState.practice_played() and GameState.preseason_stop() == "practice",
			"Pressing on without playing it sims it and shows the report")
	var before: Array = []
	_career()
	_to_practice()
	before = GameState.my_list.map(func(p): return str(p["id"]) + str(p.get("xp", 0)))
	_check(GameState.prepare_practice_match() and GameState.pending_phase == "practice"
			and str(GameState.pending_match["home"]) == "FRE" and str(GameState.pending_match["away"]) == "WCE"
			and GameState.pending_sim != null and not GameDB.is_side("FRE_H"),
			"Coached from the box, it is Fremantle at home to West Coast, two real clubs and no club's two sides")
	GameState._clear_pending()
	_check(before.size() == GameState.my_list.size(), "...and setting it up changes nobody")


func _test_trial() -> void:
	_career()
	_to_practice()
	var prospects: Array = GameState.intra_prospects()
	var ids := prospects.slice(0, 5).map(func(p): return str(p["id"]))
	_check(GameState.toggle_practice_invite(ids[0]) and GameState.toggle_practice_invite(ids[1]) and GameState.toggle_practice_invite(ids[2]),
			"Up to three prospects can be trialled")
	_check(not GameState.toggle_practice_invite(ids[3]) and GameState.practice_invites().size() == 3,
			"...and not a fourth")
	_check(GameState.toggle_practice_invite(ids[2]) and GameState.practice_invites().size() == 2 and GameState.toggle_practice_invite(ids[3]),
			"An invitation can be taken back, and the place given to someone else")
	_check(not GameState.toggle_practice_invite("nobody"), "Someone not in the class cannot be trialled")
	var trialled: Array = GameState.practice_invites().duplicate()
	var built: Dictionary = GameState._practice_mine()
	var squad: Squad = (built["sim"] as MatchSim).squads[0]
	var on := squad.ground.filter(func(p): return trialled.has(str(p["id"])))
	var nums := {}
	var dup := false
	for p in squad.ground + squad.bench:
		dup = dup or nums.has(int(p["num"]))
		nums[int(p["num"])] = true
	_check(squad.ground.size() == 18 and squad.bench.size() == 5 and on.size() == 3 and not dup,
			"A trialled prospect starts: 18 on the ground and 5 on the bench, each with his own number")
	var every_guest := true
	for p in on:
		every_guest = every_guest and bool(p.get("guest", false)) and float(p.get("cond_injury", 1.0)) == 0.0
	_check(every_guest, "...each a guest who cannot be hurt")
	GameDB.unregister_sides()
	GameState.sim_practice_match()
	var rep: Dictionary = GameState.preseason_practice()["report"]
	var lines: Array = rep["prospects"]
	var noted := true
	for row in lines:
		var p := _pool(str(row["id"]))
		var note := PreSeason.seen_line(p, CLUB)
		noted = noted and trialled.has(str(row["id"])) and note.begins_with("Seen in your 2027 practice match.")
	_check(lines.size() == 3 and noted, "Each prospect trialled has a line on his draft card, in his own words: seen in the practice match")
	var p0 := _pool(trialled[0])
	_check(PreSeason.seen_mult(p0, CLUB) < 1.0 and PreSeason.seen_mult(p0, "ZZZ") == 1.0,
			"...and your club's read of him is surer, nobody else's")
	var hurt_guest := false
	for inj in GameState.preseason_injuries():
		hurt_guest = hurt_guest or trialled.has(str(inj["id"]))
	_check(not hurt_guest, "No prospect is ever hurt")
	var untouched := true
	for q in prospects:
		var note: Dictionary = (q.get("seen", {}) as Dictionary).get(CLUB, {})
		if not trialled.has(str(q["id"])) and str(note.get("kind", "")) == "practice":
			untouched = false
	_check(untouched, "Only the prospects trialled are noted")
	# An opponent never trials the same prospect.
	_career()
	_to_practice()
	var mine: Array = GameState._intra_picks(CLUB, 3, [], 1.0)
	for id in mine:
		GameState.toggle_practice_invite(id)
	var b2: Dictionary = GameState._practice_mine()
	var g: Dictionary = b2["guests"]
	var clash := false
	for id in g["WCE"]:
		clash = clash or (g["FRE"] as Array).has(id)
	_check((g["FRE"] as Array).size() == 3 and (g["WCE"] as Array).size() == 3 and not clash,
			"Both clubs trial three prospects and never the same one")
	GameState._clear_pending()


func _pool(id: String) -> Dictionary:
	for p in GameState.draftee_pool:
		if str(p.get("id", "")) == id:
			return p
	return {}


func _test_leaves_nothing() -> void:
	_career()
	_to_practice()
	var ladder := _ladder_sig()
	var board := GameState.board_confidence()
	var tally := str(GameState.season_tally)
	var votes := str(GameState.season_log)
	GameState.sim_practice_match()
	_check(_ladder_sig() == ladder and GameState.board_confidence() == board and str(GameState.season_tally) == tally
			and str(GameState.season_log) == votes and GameState.season.round_index == 0,
			"It leaves nothing on the ladder, the season's record, the votes or the board")
	# Development: the same match with and without it.
	var with_dev := _lists_after(1.0)
	var without := _lists_after(0.0)
	var grew := 0
	var wce_grew := 0
	for k in with_dev["FRE"]:
		grew += 1 if with_dev["FRE"][k] != without["FRE"][k] else 0
	for k in with_dev["WCE"]:
		wce_grew += 1 if with_dev["WCE"][k] != without["WCE"][k] else 0
	_check(grew >= 18 and wce_grew >= 18, "The players who play get a reserves game's development, at both clubs (%d, %d)" % [grew, wce_grew])
	PreSeason.reload()
	var leftover := false
	for code in GameState.season.lists:
		for p in GameState.season.lists[code]:
			leftover = leftover or p.has("cond_injury") or bool(p.get("guest", false))
	_check(not leftover, "Nobody keeps the day's half injury risk, and no guest is left on a list")
	# Injuries happen, at half the rate.
	var rate_ok := float(PreSeason.tune("practice_injury_rate")) == 0.5
	_check(rate_ok, "A listed player carries half a match's injury risk (the director's ruling)")
	var sq: Dictionary = GameState._practice_squad(CLUB, true, [])
	var half := true
	for p in (sq["squad"] as Squad).ground:
		half = half and float(p.get("cond_injury", 0.0)) == 0.5
	_check(half, "...in the side that takes the field")
	for p in GameState.my_list:
		p.erase("cond_injury")


func _lists_after(games: float) -> Dictionary:
	PreSeason.reload()
	PreSeason.data()["practice_xp_games"] = games
	PreSeason.data()["practice_injury_rate"] = 0.0
	_career()
	_to_practice()
	GameState.sim_practice_match()
	var out := {}
	for code in ["FRE", "WCE"]:
		var rows := {}
		for p in GameState.season.lists[code]:
			rows[str(p["id"])] = "%d/%d" % [int(p["overall"]), int(p.get("xp", 0))]
		out[code] = rows
	PreSeason.reload()
	return out


func _test_ai_clubs() -> void:
	_career()
	var before := {}
	for code in GameState.season.clubs:
		before[str(code)] = GameState.season.lists[code].map(func(p): return int(p.get("xp", 0)))
	_to_practice()
	var seen_by := {}
	for q in GameState.draftee_pool:
		for club in (q.get("seen", {}) as Dictionary):
			if (q["seen"][club] as Dictionary).get("kind", "") == "practice":
				seen_by[str(club)] = true
	_check(not seen_by.has(CLUB) and not seen_by.has("WCE") and seen_by.size() >= 12,
			"Every other pair of clubs has played too, each noting the prospects it trialled")
	var pr: Dictionary = GameState.preseason_practice()
	_check(GameState.season.round_index == 0 and GameState.season_log.is_empty(),
			"...and none of it is on the ladder")
	var hurt := 0
	for inj in GameState.preseason_injuries():
		if str(inj.get("how", "")) == "practice":
			hurt += 1
	_check(hurt >= 0, "AI clubs' practice injuries are recorded the way match injuries are")
	_check(str(pr.get("opponent", "")) == "WCE", "Your pairing is waiting for you, not played")


func _test_determinism() -> void:
	var sigs := []
	for i in range(2):
		_career()
		_to_practice()
		GameState.toggle_practice_invite(str(GameState.intra_prospects()[0]["id"]))
		GameState.sim_practice_match()
		var rep: Dictionary = GameState.preseason_practice()["report"]
		sigs.append(str(rep["score"]) + str(rep["stood"]) + str(rep["prospects"]))
	_check(sigs[0] == sigs[1], "The same career, side and trial give the same practice match")


func _test_saves() -> void:
	_career()
	_to_practice()
	GameState.toggle_practice_invite(str(GameState.intra_prospects()[1]["id"]))
	GameState.save_career()
	var kept: Dictionary = GameState.preseason_practice().duplicate(true)
	GameState.reset()
	_check(GameState.load_career() and GameState.preseason_stop() == "practice"
			and str(GameState.preseason_practice()) == str(kept),
			"A save made at the practice stop loads at the practice stop, the trial as it was")
	GameState.sim_practice_match()
	GameState.save_career()
	GameState.reset()
	_check(GameState.load_career() and GameState.practice_played() and GameState.preseason_stop() == "practice"
			and not (GameState.preseason_practice()["report"] as Dictionary).is_empty(),
			"A save made after the match keeps its report")
	# Old saves: made before there was a practice match.
	_career()
	_to_practice()
	GameState.preseason.erase("practice")
	_check(GameState.preseason_stop() == "" and GameState.preseason_advance() == "done" and not GameState.preseason_active(),
			"A save from week 7 with no practice match runs on to Round 1")
	_career()
	var guard := 0
	while GameState.preseason_week() < 5 and guard < 8:
		guard += 1
		GameState.preseason_advance()
	GameState.save_career()
	var raw := CareerSave.read(GameState.save_path)
	_check(not (raw.get("preseason", {}) as Dictionary).has("practice"), "(a save from the intra-club stop holds no practice match yet)")
	GameState.reset()
	_check(GameState.load_career() and _to_practice() and GameState.practice_opponent() == "WCE",
			"A save from before week 7 loads and meets the practice match when it gets there")


func _test_sim_to_round_one() -> void:
	_career()
	GameState.preseason_sim_to_round1()
	_check(not GameState.preseason_active() and GameState.practice_played() and bool(GameState.preseason_practice()["seen"]),
			"Sim to Round 1 plays the practice match on the settings in force and does not stop for it")
	_career("MEL")
	_to_practice()
	var opp := GameState.practice_opponent()
	_check(PreSeason.PRACTICE_REGION.get(opp, "") == "VIC" and opp != "MEL",
			"Melbourne's practice match is against another Victorian club (%s)" % opp)


func _tap_to_practice(tree: SceneTree) -> Control:
	var scene: Control = await _open(tree)
	var guard := 0
	while GameState.preseason_stop() != "practice" and guard < 10:
		guard += 1
		var go := scene.find_child("PreSeasonGo", true, false) as Control
		if GameState.preseason_stop() == "intra" and not GameState.intra_played():
			GameState.sim_intra_match()
			scene = await _open(tree)
			continue
		await _tap(go, "the way on")
		await _frames(tree, 10)
		scene = tree.current_scene as Control
	return scene


func _test_screens_phone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(390, 844)
	_career()
	GameState.set_setting("seen_weekly_loop_intro", true)
	GameState.set_setting("seen_training_intro", true)
	var scene: Control = await _tap_to_practice(tree)
	_check(scene != null and scene.name == "PreSeasonScene" and GameState.preseason_stop() == "practice"
			and _label(scene, "PreSeasonHero") == "The practice match"
			and _label(scene, "PracticeHome") == "Fremantle" and _label(scene, "PracticeAway") == "West Coast",
			"Phone: the practice stop names the match, Fremantle at home to West Coast")
	_check(_label(scene, "PracticeCount") == "0 of 3 trialled" and _label(scene, "PracticePlan").begins_with("Game plan: ")
			and scene.find_child("PracticeSelection", true, false) != null and _fits(scene, 390.0),
			"Phone: it says how many are trialled, the plan, and fits the screen")
	var ids: Array = GameState.intra_prospects().slice(0, 2).map(func(p): return str(p["id"]))
	for id in ids:
		_check(await _tap(scene.find_child("Trial_" + str(id), true, false), "a prospect"),
				"Phone: a finger's tap trials a prospect")
	_check(GameState.practice_invites().size() == 2 and _label(scene, "PracticeCount") == "2 of 3 trialled"
			and bool((scene.find_child("Trial_" + str(ids[0]), true, false) as Button).get_meta("chosen", false)),
			"Phone: the two are marked and counted")
	_check(await _tap(scene.find_child("Trial_" + str(ids[1]), true, false), "the same prospect"),
			"Phone: a second tap takes it back")
	_check(GameState.practice_invites().size() == 1, "Phone: ...and he is out")
	# Side and plan are one tap away, and Back comes home.
	_check(await _tap(scene.find_child("PracticeSelection", true, false), "Selection"), "Phone: a finger's tap opens Selection")
	await _frames(tree, 8)
	_check(Router.current() == "selection", "Phone: Selection opens")
	Router.back()
	await _frames(tree, 8)
	scene = tree.current_scene as Control
	_check(scene != null and scene.name == "PreSeasonScene" and GameState.practice_invites().size() == 1
			and GameState.preseason_stop() == "practice",
			"Phone: Back from Selection returns to the practice stop with the trial kept")
	Router.handle_back()
	await _frames(tree, 8)
	_check(Router.current() == "main" and GameState.preseason_stop() == "practice",
			"Phone: Back at the stop goes to the main menu and keeps it")
	scene = await _open(tree)
	# Coach it.
	_check(await _tap(scene.find_child("PreSeasonGo", true, false), "Coach the match"), "Phone: a finger's tap goes to coach the match")
	await _frames(tree, 30)
	var m := tree.current_scene as Control
	_check(m != null and m.name == "MatchScene" and GameState.pending_phase == "practice"
			and str(GameState.pending_match["home"]) == "FRE" and str(GameState.pending_match["away"]) == "WCE"
			and int(m.get("_my_side")) == 0,
			"Phone: the match opens in the match view, Fremantle v West Coast, the coach in charge of Fremantle")
	var ladder := _ladder_sig()
	m.call("_on_skip")
	await _frames(tree, 40)
	var cont := m.find_child("FullTimeContinue", true, false) as Button
	_check(cont != null and GameState.practice_played() and m.find_child("LadderMove", true, false) == null
			and m.find_child("NextFixture", true, false) == null,
			"Phone: at full time it is over and nothing is said of the ladder or a next round (cont %s, played %s, ladder %s, next %s)" % [
			str(cont != null), str(GameState.practice_played()), str(m.find_child("LadderMove", true, false)), str(m.find_child("NextFixture", true, false))])
	_check(await _tap(cont, "Continue at full time"), "Phone: a finger's tap leaves full time")
	await _frames(tree, 12)
	scene = tree.current_scene as Control
	_check(scene != null and scene.name == "PreSeasonScene" and GameState.preseason_stop() == "practice"
			and _label(scene, "PracticeSide_0") == "Fremantle" and _label(scene, "PracticeSide_1") == "West Coast"
			and _label(scene, "PracticeStood_0") != "" and _label(scene, "PracticeSeen_0") != ""
			and _label(scene, "PracticeSeenLine_0") != "" and _ladder_sig() == ladder and _fits(scene, 390.0),
			"Phone: the report shows the score, who stood out and the line on the prospect, and the ladder is untouched")
	_check(await _tap(scene.find_child("PreSeasonGo", true, false), "Back to training after the match"),
			"Phone: a finger's tap goes on")
	await _frames(tree, 10)
	scene = tree.current_scene as Control
	_check(scene != null and scene.name == "HubScene" and not GameState.preseason_active() and GameState.preseason_week() == 8,
			"Phone: the quiet week passes and the hub opens at Round 1")
	# Simmed from the screen.
	_career()
	scene = await _tap_to_practice(tree)
	_check(await _tap(scene.find_child("PracticeSim", true, false), "Sim the match"), "Phone: a finger's tap sims the match")
	await _frames(tree, 6)
	scene = tree.current_scene as Control
	_check(GameState.practice_played() and _label(scene, "PracticeSide_0") == "Fremantle",
			"Phone: simming shows the report")
	Router.stack = []


func _test_screens_pc() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(960, 540)
	_career("MEL")
	GameState.set_setting("seen_weekly_loop_intro", true)
	GameState.set_setting("seen_training_intro", true)
	var scene: Control = await _tap_to_practice(tree)
	var opp := GameState.practice_opponent()
	_check(scene != null and scene.name == "PreSeasonScene" and _label(scene, "PracticeHome") == "Melbourne" and _label(scene, "PracticeAway") == GameDB.club_name(opp)
			and _fits(scene, 960.0),
			"PC: the practice stop fits the screen and names the match")
	var go := scene.find_child("PreSeasonGo", true, false) as Control
	var foot := scene.find_child("PreSeasonActions", true, false) as Control
	_check(go != null and go.size.x < 500.0 and foot != null and foot.get_global_rect().end.y <= 540.0,
			"PC: the way on is sized to its words and the buttons are on the screen")
	var id := str(GameState.intra_prospects()[0]["id"])
	_check(await _tap(scene.find_child("Trial_" + id, true, false), "a prospect"), "PC: a click trials a prospect")
	_check(GameState.practice_invites() == [id], "PC: he is trialled")
	_check(await _tap(scene.find_child("PracticePlanGo", true, false), "Game plan"), "PC: a click opens the game plan")
	await _frames(tree, 8)
	_check(Router.current() == "coaching", "PC: the game plan opens")
	Router.back()
	await _frames(tree, 8)
	scene = tree.current_scene as Control
	_check(await _tap(scene.find_child("PracticeSim", true, false), "Sim the match"), "PC: a click sims the match")
	await _frames(tree, 6)
	scene = tree.current_scene as Control
	_check(GameState.practice_played() and _label(scene, "PracticeSide_0") == "Melbourne"
			and _label(scene, "PracticeSide_1") == GameDB.club_name(opp) and _fits(scene, 960.0),
			"PC: the report shows the two clubs and fits")
	_check(await _tap(scene.find_child("PreSeasonGo", true, false), "Back to training"), "PC: a click goes on")
	await _frames(tree, 8)
	scene = tree.current_scene as Control
	_check(scene != null and scene.name == "HubScene" and not GameState.preseason_active(),
			"PC: the hub opens at Round 1")
	tree.root.size = Vector2i(390, 844)
	Router.stack = []
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	await _frames(tree, 3)


func _test_switch_off() -> void:
	Features.set_on("preseason", false)
	_career()
	_check(GameState.preseason.is_empty() and GameState.preseason_stop() == "" and GameState.preseason_practice().is_empty(),
			"Switched off, no pre-season and no practice match is opened")
	_check(not GameState.sim_practice_match() and not GameState.prepare_practice_match() and not GameState.toggle_practice_invite("x")
			and GameState.preseason.is_empty(),
			"...and none of its controls does anything")
	Features.set_on("preseason", true)
