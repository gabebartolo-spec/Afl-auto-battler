extends RefCounted
## Run by tests/run_coach_arcs_tests.gd (suite "coach_arcs").
## The coach's career arcs (CoachArcs.gd, ClubArcs.gd; director, 2026-11-03,
## phase 1): the arcs file is fit to play, arcs start only from real game
## state, beats come only from active arcs, the state persists through save and
## load (an old save loads empty). A 10-season Sim-the-week career dumps its story log to
## tests/output/coach_arcs_story.txt (not committed) for a person to read.

var _tree: SceneTree
var checks := 0
var failures: Array[String] = []
const SUITE_SEED := 2027
const DUMP := "res://tests/output/coach_arcs_story.txt"


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _fresh() -> void:
	GameState.reset()
	GameState.start_season("FRE", GameDB.club_list("FRE"))
	GameState.replay_seed = SUITE_SEED
	GameState.tutorials = false
	Router.stack = []


## Answers this week's cards the way a player might: a seeded choice, and now
## and then no answer at all (the round settles it).
func _answer(rng: RandomNumberGenerator) -> void:
	for i in range(GameState.week_events.size()):
		var c: Dictionary = GameState.week_events[i]
		if bool(c.get("resolved", false)) or rng.randi_range(0, 5) == 0:
			continue
		GameState.resolve_card(i, rng.randi_range(0, (c.get("options", []) as Array).size() - 1))


func _week(rng: RandomNumberGenerator) -> void:
	_answer(rng)
	GameState.advance()


func run(tree: SceneTree) -> void:
	_tree = tree
	await _tree.process_frame
	GameState.autosave_enabled = false
	GameState.save_path = "user://test_coach_arcs.save"
	GameState.settings_path = "user://test_coach_arcs.cfg"
	GameState.delete_saved_career()
	_t("_test_file_fit")
	_t("_test_triggers_from_state")
	_t("_test_beats_only_active")
	_t("_test_persist")
	_t("_test_hero_count_trigger")
	_t("_test_poached_moves_club")
	_t("_test_sacked_way_back")
	_t("_test_reunion")
	_t("_test_drought_counts_this_club")
	_t("_test_assistant_leaves")
	_t("_test_second_sacking_and_retire")
	_t("_test_real_sacking_record")
	_t("_test_rival_letter")
	_t("_test_joining_club_after_sack")
	_t("_test_joining_club_letter")
	_t("_test_coach_move_lines")
	_t("_test_ten_seasons")
	GameState.delete_saved_career()
	GameState.replay_seed = 0
	print(Ran.line("Coach arcs", self))
	for f in failures:
		print("  FAIL: " + f)


func _test_file_fit() -> void:
	var defs := CoachArcs.all()
	_check(defs.size() == 14, "all fourteen catalogue arcs are built, got %d" % defs.size())
	var errs := CoachArcs.validate(defs)
	_check(errs.is_empty(), "the arcs file is fit to play: %s" % str(errs))


func _test_triggers_from_state() -> void:
	_fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 1
	for i in range(3):
		_week(rng)
	var st: Dictionary = GameState.coach_arcs
	_check(not st.is_empty(), "on: the arc state is kept")
	_check(not (st["active"] as Dictionary).has("hot_seat") and not (st["active"] as Dictionary).has("drought") \
			and not (st["active"] as Dictionary).has("legacy"), "a new coach is not on the hot seat, in a drought or a legend")
	# The board really loses faith: the hot seat follows by round 8.
	GameState.board["confidence"] = 25
	for i in range(8):
		_week(rng)
	_check((st["active"] as Dictionary).has("hot_seat") or (st["done"] as Dictionary).has("hot_seat"),
			"a board below 40 by round 8 puts the coach on the hot seat")
	# A real trade request: the star-wants-out trigger names that player.
	var star: Dictionary = GameState.my_list[0]
	GameState.trade_requests[str(star["id"])] = {"year": GameState.season_year}
	var hit := ClubArcs.trigger(GameState, st, CoachArcs.by_id(CoachArcs.all(), "star_wants_out"), ClubStories.context(GameState), false)
	_check(str(hit.get("who", "")) == str(star["id"]), "a trade request triggers the star-wants-out arc about him: %s" % str(hit))
	# The card names him as every screen does: his AFL name, never the hidden
	# label a real player's "name" field holds (real names only, 2026-11-12).
	var shown: String = GameDB.player_display_name(star)
	_check(str(star.get("real_name", "")) != "" and shown != str(star.get("name", ""))
			and str(hit.get("mem", {}).get("name", "")) == shown,
			"the arc remembers him as %s, not %s: %s" % [shown, str(star.get("name", "")), str(hit.get("mem", {}))])
	GameState.departed_names["GONE_DAD"] = {"generic_name": "Ari Bramble", "real_name": "Gary Ablett", "name": "Ari Bramble"}
	_check(ClubArcs._person_name(GameState, "GONE_DAD") == "Gary Ablett" and ClubArcs._person_name(GameState, "NOBODY") == "his father",
			"a retired real father is named for real, and an unknown one is \"his father\" (%s)" % ClubArcs._person_name(GameState, "GONE_DAD"))
	GameState.departed_names.erase("GONE_DAD")
	GameState.trade_requests.erase(str(star["id"]))
	_check(ClubArcs.trigger(GameState, st, CoachArcs.by_id(CoachArcs.all(), "drought"), ClubStories.context(GameState), true).is_empty(),
			"no drought for a coach with no seasons behind him")

func _test_beats_only_active() -> void:
	_fresh()
	GameState.board["confidence"] = 25
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 2
	var seen := 0
	var stray := []
	for i in range(20):
		_answer(rng)
		GameState.advance()
		for c in GameState.week_events:
			var id := str(c.get("coach_arc", ""))
			if id == "":
				continue
			seen += 1
			if not (GameState.coach_arcs["active"] as Dictionary).has(id):
				stray.append(id)
			_check(ClubArcs.big_call(GameState).get("card", {}) == c or bool(c.get("resolved", false)), "the big call is the due beat")
	_check(seen > 0, "arc beats were dealt")
	_check(stray.is_empty(), "every beat comes from an active arc: %s" % str(stray))


func _test_persist() -> void:
	var before := JSON.stringify(GameState.coach_arcs)
	_check(before.length() > 20, "there is arc state to save")
	_check(GameState.save_career(), "saves")
	GameState.reset()
	_check(GameState.load_career(), "loads")
	_check(JSON.stringify(GameState.coach_arcs) == before, "the arcs come back as they were")
	# An old save (no arcs in it) loads empty.
	GameState.coach_arcs = {}
	_check(GameState.save_career() and GameState.load_career(), "an old save loads")
	_check(GameState.coach_arcs.is_empty(), "an old save's arcs start empty")


func _test_ten_seasons() -> void:
	_fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 3
	# Ten seasons locally (about 10 minutes); CI plays three to stay inside
	# the suite time limit. COACH_ARCS_SEASONS overrides either.
	var n := 3 if OS.get_environment("CI") != "" else 10
	if OS.get_environment("COACH_ARCS_SEASONS").is_valid_int():
		n = maxi(2, OS.get_environment("COACH_ARCS_SEASONS").to_int())
	for s in range(n):
		var guard := 0
		while not GameState.season.is_season_over() and guard < 40:
			guard += 1
			_week(rng)
			# A sacking with a reprieve left brings job offers (the rollover
			# takes the first); with none left the coaching career is over.
			_check(not GameState.is_sacked() or not ClubMoves.offers(GameState).is_empty() or ClubMoves.reprieves(GameState) == 0,
					"a sacked coach with a reprieve has clubs to go to")
		if ClubMoves.career_over(GameState):
			_check(not GameState.start_next_season(), "a career that is over does not roll on")
			break
		if s < n - 1:
			_check(GameState.start_next_season(), "season %d rolls on" % (s + 1))
	var st: Dictionary = GameState.coach_arcs
	var lines := PackedStringArray()
	lines.append("Coach arcs: %d seasons of Sim the week, FRE, seed %d. Clubs: %s" % [n, SUITE_SEED, JSON.stringify(st["coach"]["clubs"])])
	lines.append("Coach: %s" % JSON.stringify(st["coach"]))
	var started := {}
	for row in st["log"]:
		lines.append("%d %s [%s] %s" % [int(row[0]), str(row[1]), str(row[2]), str(row[3])])
		if str(row[3]).begins_with("BEGINS"):
			started[str(row[2])] = true
	lines.append("Arcs started: %s" % str(started.keys()))
	lines.append("Done: %s" % JSON.stringify(st["done"]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var f := FileAccess.open(DUMP, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	_check(f != null, "the story log is written to %s" % DUMP)
	_check(started.size() >= (4 if n >= 10 else 1), "several arcs start over ten seasons: %s" % str(started.keys()))
	_check(int(st["coach"]["seasons"]) == n - 1, "every closed season is counted: %s" % str(st["coach"]))


## Plays the rest of this season, keeping the board where `conf` puts it (-1: leave it).
## `sack` marks the board's sacking before each week, so the close finds him
## sacked whatever the seeded season does (a premiership at confidence 0 still
## clears the board's line, and #1370 changed how this seed plays out).
func _play_out(rng: RandomNumberGenerator, conf := -1, sack := false) -> void:
	var guard := 0
	while not GameState.season.is_season_over() and guard < 40:
		guard += 1
		if conf >= 0:
			GameState.board["confidence"] = conf
			GameState.board["warned"] = true
		if sack:
			GameState.board["sacked"] = true
		_week(rng)


func _senior_at(code: String) -> Dictionary:
	return ClubMoves._senior_coach(GameState, code)


func _my_assistant() -> String:
	for cid in GameState.coaches:
		var c: Dictionary = GameState.coaches[cid]
		if str(c.get("club", "")) == GameState.my_club and str(c.get("job", "")) == "SA" and str(c.get("status", "")) == "club":
			return str(cid)
	return ""


## Arc 3: a rival's offer taken in season; at its close the arc ends "left",
## and at the rollover he is that club's coach, its coach takes his old job,
## and his record carries on. Persists across save and load.
func _test_poached_moves_club() -> void:
	_fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 4
	for i in range(3):
		_week(rng)
	var st: Dictionary = GameState.coach_arcs
	# The trigger reads real finishes: two top-4 seasons at this club.
	var roll: Array = GameState.honour_roll.duplicate(true)
	var finish: Dictionary = GameState._last_finish.duplicate()
	GameState._last_finish = {}
	var k := 0
	for code in GameState.season.ladder:
		k += 1
		GameState._last_finish[str(code)] = k
	GameState.honour_roll.append({"year": GameState.season_year, "my_club": "FRE", "my_position": 2, "premier": "COL"})
	GameState.honour_roll.append({"year": GameState.season_year, "my_club": "FRE", "my_position": 3, "premier": "FRE"})
	var def := CoachArcs.by_id(CoachArcs.all(), "poached")
	_check(ClubMoves.poach_trigger(GameState, st, def["trigger"], false).is_empty(), "poached: only at a season's start")
	var hit := ClubMoves.poach_trigger(GameState, st, def["trigger"], true)
	GameState.honour_roll = roll
	GameState._last_finish = finish
	var suitor := str(hit.get("mem", {}).get("suitor_code", ""))
	_check(suitor != "" and suitor != "FRE", "poached: a struggling rival wants him: %s" % str(hit))
	if suitor == "":
		return
	var their_coach := _senior_at(suitor)
	_check(not their_coach.is_empty(), "poached: the suitor has a senior coach to replace")
	var rec := CoachArcs.start(st, def, GameState.season_year, GameState.story_week(), "", hit["mem"])
	var facts := ClubArcs._facts(GameState, st, rec, {"club": "Fremantle", "opp": ""})
	var b := CoachArcs.due_beat(def, rec, GameState.story_week(), GameState.season_year, "regular", facts)
	_check(str(b.get("id", "")) == "arc_poach_call", "poached: the first beat is the call: %s" % str(b.get("id", "")))
	_check(StoryEngine.fill("{suitor_president} of {suitor}", facts).find("{") < 0, "poached: its names fill the text")
	CoachArcs.answer(def, rec, "arc_poach_call", "listen", GameState.story_week(), GameState.season_year)
	# The captain asks before the offer is in writing, so a denial then is a lie.
	CoachArcs.answer(def, rec, "arc_poach_captain", "truth", GameState.story_week() + 2, GameState.season_year)
	CoachArcs.answer(def, rec, "arc_poach_offer", "take", GameState.story_week() + 5, GameState.season_year)
	_check((rec["flags"] as Dictionary).has("taking") and int(rec["beat"]) == 3, "poached: the offer is taken and every beat played")
	# The board sacks him at the same close (row 111): the signed job stands,
	# the sacking is on his record, and no second chance is spent.
	_play_out(rng, 0, true)
	_check(not GameState.is_sacked() and int(st["coach"]["sackings"]) == 1 and int(st["coach"]["reprieves"]) == 1
			and (st["offers"] as Array).is_empty(),
			"poached and sacked: he still goes, the sacking counts, the second chance is kept: %s" % str(st["coach"]))
	# Row 189: he moves at the season's close, as a rival board's letter taken
	# does, so the off-season opens at the club he joins.
	var moved: Dictionary = st["coach"].get("moved", {})
	_check((st["move"] as Dictionary).is_empty() and str(moved.get("why", "")) == "poached" and str(moved.get("to", "")) == suitor,
			"poached: he moves at the season's close: %s" % str(moved))
	_check(GameState.my_club == suitor and is_same(GameState.my_list, GameState.season.lists[suitor])
			and GameState.offseason_year == GameState.season_year,
			"poached: the off-season opens at %s with its list (club %s)" % [suitor, GameState.my_club])
	_check(GameState.offseason_staff == Coaches.staff(GameState.coaches, suitor),
			"poached: the staff he sees this off-season are %s's" % suitor)
	_no_calls_for("poached", "FRE")
	_check(str(st["done"].get("poached", {}).get("ending", "")) == "left", "poached: it resolves 'left': %s" % str(st["done"].get("poached", {})))
	_check(st["active"].is_empty(), "poached: every arc ends at the club he leaves: %s" % str(st["active"].keys()))
	var coached_before := (st["coach"]["coached"] as Dictionary).size()
	var their_id := str(their_coach.get("cid", ""))
	_check(GameState.save_career() and GameState.load_career() and GameState.my_club == suitor, "poached: saves and loads at the new club")
	_check(GameState.start_next_season(), "poached: the season rolls on")
	st = GameState.coach_arcs
	_check(GameState.my_club == suitor, "poached: he coaches %s now, got %s" % [suitor, GameState.my_club])
	_check(GameState.my_list == GameState.season.lists[suitor], "poached: his list is the new club's")
	their_coach = GameState.coaches.get(their_id, {})
	_check(str(their_coach.get("club", "")) == "FRE" and str(their_coach.get("job", "")) == "SC", "poached: %s's coach takes the Fremantle job" % suitor)
	_check(_senior_at(suitor).is_empty(), "poached: the club he joins has no AI senior coach (he is it)")
	var clubs: Array = st["coach"]["clubs"]
	_check(clubs.size() == 2 and str(clubs[0]["code"]) == "FRE" and int(clubs[0]["to"]) == GameState.season_year - 1 \
			and str(clubs[1]["code"]) == suitor, "poached: the career history has both clubs: %s" % JSON.stringify(clubs))
	_check(int(st["coach"]["seasons"]) == 1, "poached: the Fremantle season is still on his record: %s" % str(st["coach"]))
	_check((st["coach"]["coached"] as Dictionary).size() > coached_before, "poached: the players he coached at both clubs are remembered")
	_check(str(clubs[0].get("chairman", "")) != "" and str(st["people"].get("chairman", "")) != str(clubs[0]["chairman"]),
			"poached: the old chairman is remembered and the new club has its own")
	var before := JSON.stringify(st)
	_check(GameState.save_career() and GameState.load_career(), "poached: saves and loads at the new club")
	_check(JSON.stringify(GameState.coach_arcs) == before and GameState.my_club == suitor, "poached: the career history comes back as it was")
	# A flag won at the club he left is his; a flag the new club won before he
	# got there is not (the move lands before the season is counted).
	var roll_now: Array = GameState.honour_roll
	var last_y := GameState.season_year - 1
	var flags_at := {}
	for premier in ["FRE", suitor]:
		var fake := {"coach": {"start": last_y - 1, "seen": last_y - 1, "club": suitor, "clubs": [],
				"seasons": 0, "games": 0, "flags": 0, "last_flag": 0, "coached": {}}}
		GameState.honour_roll = [{"year": last_y, "my_club": "FRE", "my_record": "16-6-0", "premier": premier}]
		ClubArcs._count_last_season(GameState, fake)
		flags_at[premier] = [int(fake["coach"]["flags"]), int(fake["coach"]["last_flag"])]
	GameState.honour_roll = roll_now
	_check(flags_at["FRE"] == [1, last_y] and flags_at[suitor] == [0, 0],
			"poached: the flag is counted at the club he coached that season, not the new one: %s" % str(flags_at))


## Arc 2 (and arc 11's take-over): sacked at a season's close, he takes a job
## at a bottom club, his assistant takes the job he lost, and the way back
## starts at the new club, remembering the old one.
func _test_sacked_way_back() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 5
	var st: Dictionary = GameState.coach_arcs
	var old := str(GameState.my_club)
	# The career carries on from the poached test, which may hold a sacking.
	var sacks_before := int(st["coach"]["sackings"])
	for i in range(3):
		_week(rng)
	# An assistant with a name, after the job: arc 11 runs as the board sinks.
	var sa_id := _my_assistant()
	_check(sa_id != "", "sacked: the club has a senior assistant")
	if sa_id == "":
		return
	var sa: Dictionary = GameState.coaches[sa_id]
	sa["rep"] = 80
	GameState.board["confidence"] = 30
	var adef := CoachArcs.by_id(CoachArcs.all(), "assistant")
	st["active"].erase("assistant")
	var ahit := ClubMoves.assistant_trigger(GameState, st, adef["trigger"], ClubStories.context(GameState), false)
	_check(str(ahit.get("mem", {}).get("assistant_id", "")) == sa_id, "assistant: the trigger names him: %s" % str(ahit))
	st["done"].erase("assistant")
	var arec := CoachArcs.start(st, adef, GameState.season_year, GameState.story_week(), "", ahit.get("mem", {}))
	CoachArcs.answer(adef, arec, "arc_assist_lunch", "confront", GameState.story_week(), GameState.season_year)
	CoachArcs.answer(adef, arec, "arc_assist_offer", "block", GameState.story_week() + 4, GameState.season_year)
	# A goal no side meets: a premiership (+30) cannot save a missed one (0 - 25 + 30 < 30).
	GameState.board["goal"] = {"key": "wins99", "text": "Win 99 games", "wins": 99}
	# A rival's approach for him at the end of the home-and-away season would
	# take him first (he is the man the arc is about): leave it out.
	var guard := 0
	while not GameState.season.is_regular_done() and guard < 40:
		guard += 1
		GameState.board["confidence"] = 0
		GameState.board["warned"] = true
		_week(rng)
	GameState.coach_approaches = GameState.coach_approaches.filter(func(a): return str(a.get("cid", "")) != sa_id)
	_play_out(rng, 0)
	st = GameState.coach_arcs
	# Row 111 (T5.r22): sacked is not the end. The sacked card stays up with a
	# few clubs to choose from; nothing moves until he takes one.
	_check(GameState.is_sacked(), "sacked: the board's verdict stands until he chooses")
	var jobs: Array = st["offers"]
	var codes := jobs.map(func(o): return str(o["code"]))
	_check(jobs.size() == ClubMoves.OFFERS and not codes.has(old), "sacked: %d clubs offer him a job, not %s: %s" % [ClubMoves.OFFERS, old, str(codes)])
	_check(jobs.all(func(o): return int(o["finish"]) > 0 and str(o["goal"]) != "" and str(o["list"]) != "" and str(o["why_open"]) != ""),
			"sacked: each offer states where they finished, the list, the board's goal and why the job is open: %s" % str(jobs))
	_check(jobs.all(func(o): return _ratings_only(str(o["list"]), str(o["code"]))),
			"sacked: each offer gives the list as its ratings now and in three years, no list word: %s" % str(jobs.map(func(o): return o["list"])))
	_check((st["move"] as Dictionary).is_empty() and int(st["coach"]["reprieves"]) == 1, "sacked: no move until he chooses; one reprieve left")
	# Row 179 (director 2026-11-12: "after a sacking I still pick Shepparton's staff
	# and make its trades"): no off-season opens at the club that sacked him.
	GameState.open_offseason()
	_check(GameState.offseason_year != GameState.season_year and GameState.my_club == old,
			"sacked: no off-season opens at %s while he chooses (off-season %d, season %d)" % [old, GameState.offseason_year, GameState.season_year])
	_check(not ClubMoves.take_job(GameState, old), "sacked: he cannot take a job that was not offered")
	var to := str(jobs[-1]["code"]) if not jobs.is_empty() else ""
	# Bug-bash 2 (2026-11-10): the old board's press move stays with the old
	# board; the new board starts clean and fades nothing from it.
	GameState.media_memory["board_lift"] = 3
	_check(ClubMoves.take_job(GameState, to), "sacked: he takes the job at %s" % to)
	_check(not GameState.is_sacked(), "sacked: the career goes on (no sacked card)")
	# He moves the day he signs: every off-season call is the new club's.
	var moved: Dictionary = st["coach"]["moved"]
	_check(str(moved.get("why", "")) == "sacked" and str(moved.get("to", "")) == to and (st["move"] as Dictionary).is_empty(),
			"sacked: a job at another club: %s" % str(moved))
	_check(GameState.my_club == to and GameState.offseason_year == GameState.season_year,
			"sacked: the off-season opens at %s, not %s (club %s, off-season %d, season %d)" % [
			to, old, GameState.my_club, GameState.offseason_year, GameState.season_year])
	_check(GameState.my_list == GameState.season.lists.get(to, []) and not GameState.my_list.is_empty(),
			"sacked: the list he runs is %s's (%d players)" % [to, GameState.my_list.size()])
	_check(int(st["coach"]["sackings"]) == sacks_before + 1 and int(st["coach"]["reprieves"]) == 0,
			"sacked: the sacking is on his record and the reprieve is spent: %s" % str(st["coach"]))
	_check((st["offers"] as Array).is_empty(), "sacked: the offers are gone once he chooses")
	_check(str(st["done"].get("assistant", {}).get("ending", "")) == "took_job", "assistant: resolves 'took_job': %s" % str(st["done"].get("assistant", {})))
	_check(GameState.start_next_season(), "sacked: the season rolls on")
	_check(not GameState.media_memory.has("board_lift") and GameState.board_confidence() == ClubLife.START_CONFIDENCE,
			"sacked: the old board's press move is gone at the new club (%s, %d)" % [
			str(GameState.media_memory.get("board_lift")), GameState.board_confidence()])
	st = GameState.coach_arcs
	sa = GameState.coaches.get(sa_id, {})
	_check(GameState.my_club == to, "sacked: he coaches %s now" % to)
	_check(str(sa.get("club", "")) == old and str(sa.get("job", "")) == "SC", "assistant: he has the job the coach lost: %s" % str([sa.get("club"), sa.get("job")]))
	var wb: Dictionary = st["active"].get("way_back", {})
	_check(not wb.is_empty(), "way back: it starts at the new club: %s" % str(st["active"].keys()))
	_check(str(wb.get("mem", {}).get("old_club", "")) == GameDB.club_name(old) and str(wb.get("mem", {}).get("former", "")) != "",
			"way back: it remembers the club and a player he left: %s" % str(wb.get("mem", {})))
	_check((st["coach"]["clubs"] as Array).size() == 3 and str(st["coach"]["clubs"][1].get("why_left", "")) == "sacked",
			"sacked: three clubs on the record, the second left by the sack: %s" % JSON.stringify(st["coach"]["clubs"]))
	var seen := {}
	for i in range(8):
		for c in GameState.week_events:
			if str(c.get("coach_arc", "")) == "way_back":
				seen[str(c.get("tid", ""))] = true
		_week(rng)
	_check(seen.has("arc_back_why"), "way back: the first press call is dealt: %s" % str(seen.keys()))
	var before := JSON.stringify(GameState.coach_arcs)
	_check(GameState.save_career() and GameState.load_career(), "way back: saves and loads")
	_check(JSON.stringify(GameState.coach_arcs) == before, "way back: comes back as it was")
	_play_out(rng)
	_check(GameState.start_next_season(), "way back: the season rolls on")
	st = GameState.coach_arcs
	var end := str(st["done"].get("way_back", {}).get("ending", ""))
	_check(end in ["rebuilt", "settled", "sacked_again"], "way back: it resolves: %s" % str(st["done"].get("way_back", {})))


## Row 111 (T5.r22): with the reprieve spent a second sacking ends the
## coaching career; a premiership earns the reprieve back (one at most);
## retiring reads the record out and ends the career; the choice saves.
func _test_second_sacking_and_retire() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 9
	_fresh()
	var st: Dictionary = GameState.coach_arcs
	var old := str(GameState.my_club)
	# An old save without the new keys loads with one reprieve.
	var bare := CoachArcs.new_state()
	(bare["coach"] as Dictionary).erase("reprieves")
	(bare["coach"] as Dictionary).erase("retired")
	bare.erase("offers")
	bare.erase("sack")
	CoachArcs.ensure(bare)
	_check(int(bare["coach"]["reprieves"]) == 1 and int(bare["coach"]["retired"]) == 0 and bare["offers"] is Array,
			"an old save gets one reprieve and no offers")
	# An old save whose coach was already sacked once has had his second chance.
	var once := CoachArcs.new_state()
	(once["coach"] as Dictionary).erase("reprieves")
	once["coach"]["sackings"] = 1
	CoachArcs.ensure(once)
	_check(int(once["coach"]["reprieves"]) == 0, "an old save already sacked once has no second chance left")
	CoachArcs.ensure(once)
	once["coach"]["reprieves"] = 1
	CoachArcs.ensure(once)
	_check(int(once["coach"]["reprieves"]) == 1, "a reprieve earned back after the change is kept on reload")
	# No reprieve left: the sacking ends the career.
	GameState.board["goal"] = {"key": "wins99", "text": "Win 99 games", "wins": 99}
	_play_out(rng, 0)
	st = GameState.coach_arcs
	var flag := GameState.premier() == old
	if flag:
		print("SKIP: %s won the flag, so the sacking never comes" % old)
	else:
		_check(GameState.is_sacked() and (st["offers"] as Array).size() == ClubMoves.OFFERS, "first sacking: jobs on offer")
		var sacks := int(st["coach"]["sackings"])
		# Spend the reprieve and sack him again at the same close.
		st["coach"]["reprieves"] = 0
		st["offers"] = []
		ClubMoves.season_close(GameState)
		_check(GameState.is_sacked() and (st["offers"] as Array).is_empty() and ClubMoves.career_over(GameState),
				"no reprieve left: no offers, the coaching career is over")
		_check(int(st["coach"]["sackings"]) == sacks + 1, "a sacking that ends the career is on his record")
		_check(not GameState.begin_intake_draft(), "a career that is over has no draft")
		_check((st["move"] as Dictionary).is_empty() and not GameState.start_next_season() and GameState.my_club == old,
				"a career that is over does not roll on")
	# A premiership puts the reprieve back, one at most.
	st["coach"]["reprieves"] = 0
	var sacked_was := bool(GameState.board.get("sacked", false))
	GameState.board["sacked"] = false
	var premier_was := str(GameState.season.finals.get("premier", ""))
	GameState.season.finals["premier"] = old
	ClubMoves.season_close(GameState)
	_check(int(st["coach"]["reprieves"]) == 1, "a premiership restores the reprieve")
	ClubMoves.season_close(GameState)
	_check(int(st["coach"]["reprieves"]) == 1, "a second flag does not stack a second reprieve")
	GameState.season.finals["premier"] = premier_was
	GameState.board["sacked"] = sacked_was
	# Offers save and load; then he retires.
	GameState.board["sacked"] = true
	st["offers"] = [{"code": "GCS", "name": GameDB.club_name("GCS"), "finish": 17, "clubs": 18, "list": "Team rating 66. On this list, 70 in three years.",
			"goal": "Win at least 7 games", "why_open": "The board wants a new senior coach."}]
	st["sack"] = {"from": old, "year": GameState.season_year, "heir": ""}
	var before := JSON.stringify(GameState.coach_arcs)
	_check(GameState.save_career() and GameState.load_career(), "sacked with offers: saves and loads")
	_check(JSON.stringify(GameState.coach_arcs) == before and GameState.is_sacked(), "sacked with offers: comes back as it was")
	var lines := ClubMoves.record_lines(GameState)
	_check(lines.size() >= 3 and "\n".join(lines).find(GameDB.club_name(old)) >= 0 and lines[0].find("season") >= 0,
			"the record is read out: %s" % str(lines))
	ClubMoves.retire_coach(GameState)
	st = GameState.coach_arcs
	_check(ClubMoves.retired(GameState) and ClubMoves.career_over(GameState) and (st["offers"] as Array).is_empty(),
			"retired: the career is over")
	_check(not GameState.start_next_season() and not GameState.begin_intake_draft(), "retired: the season does not roll on")
	before = JSON.stringify(GameState.coach_arcs)
	_check(GameState.save_career() and GameState.load_career() and JSON.stringify(GameState.coach_arcs) == before
			and int(GameState.coach_arcs["coach"]["retired"]) == GameState.season_year, "retired: saves and loads")


## Arc 7: a club he coached before on this week's fixture starts the reunion,
## remembering the club, its chairman and a player; the result is recorded.
func _test_reunion() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 6
	for i in range(3):
		_week(rng)
	var st: Dictionary = GameState.coach_arcs
	var old := str(st["coach"]["clubs"][0]["code"])
	var ctx := ClubStories.context(GameState)
	var club: Dictionary = (ctx["club"] as Dictionary).duplicate()
	club["opp"] = GameDB.club_name(old)
	st["active"].erase("way_back")
	st["active"].erase("reunion")
	# An earlier test's career may have met this club already; start fresh.
	for h in st["coach"]["clubs"]:
		(h as Dictionary).erase("reunion")
	var hit := ClubMoves.reunion_trigger(GameState, st, club, ctx, false)
	_check(str(hit.get("mem", {}).get("old_code", "")) == old and str(hit.get("mem", {}).get("old_chairman", "")) != "" \
			and str(hit.get("mem", {}).get("former", "")) != "", "reunion: it remembers the old club, its chairman and a player: %s" % str(hit))
	club["opp"] = GameDB.club_name(GameState.my_club)
	_check(ClubMoves.reunion_trigger(GameState, st, club, ctx, false).is_empty(), "reunion: not against any other club")
	if hit.is_empty():
		return
	var def := CoachArcs.by_id(CoachArcs.all(), "reunion")
	var rec := CoachArcs.start(st, def, GameState.season_year, GameState.story_week(), "", hit["mem"])
	var line := StoryEngine.fill(str(def["beats"][0]["text"][-1]), ClubArcs._facts(GameState, st, rec, club))
	_check(line.find("{") < 0 and line.find(GameDB.club_name(old)) >= 0, "reunion: the grudge text names the old club: %s" % line)
	var last: Array = GameState.season.results[-1]
	last.append({"home": GameState.my_club, "away": old, "score": [90, 60]})
	ClubMoves.record_reunion(GameState, st)
	last.pop_back()
	_check((rec["flags"] as Dictionary).has("won"), "reunion: the win over the old club is recorded")
	var drawn := {"flags": {}}
	var st_draw := {"active": {"reunion": {"flags": drawn["flags"], "mem": hit["mem"]}}}
	last.append({"home": GameState.my_club, "away": old, "score": [70, 70]})
	ClubMoves.record_reunion(GameState, st_draw)
	last.pop_back()
	_check((drawn["flags"] as Dictionary).has("drew") and not (drawn["flags"] as Dictionary).has("lost")
			and not (drawn["flags"] as Dictionary).has("won"), "reunion: a draw is neither a win nor a loss: %s" % str(drawn["flags"]))
	CoachArcs.answer(def, rec, "arc_reunion_grudge", "bite", GameState.story_week(), GameState.season_year)
	CoachArcs.answer(def, rec, "arc_reunion_handshake", "gracious", GameState.story_week() + 1, GameState.season_year)
	_check(int(rec["beat"]) == 2, "reunion: both beats played")
	_check(CoachArcs.closing(def, rec, {}, GameState.season_year + 1) == "remembered", "reunion: a win resolves 'remembered'")
	rec["flags"].erase("won")
	_check(CoachArcs.closing(def, rec, {}, GameState.season_year + 1) == "reconciled", "reunion: a gracious loss resolves 'reconciled'")
	rec["flags"]["drew"] = GameState.story_week()
	var draw_end := CoachArcs.closing(def, rec, {}, GameState.season_year + 1)
	var draw_line := str(def["endings"].get(draw_end, {}).get("line", ""))
	_check(draw_end == "level" and draw_line.contains("Honours shared") and not draw_line.contains("better of"),
			"reunion: a drawn reunion resolves 'level' with draw copy: %s / %s" % [draw_end, draw_line])
	rec["flags"].erase("drew")
	# The same old club comes round again only once every 10 seasons.
	ClubArcs._end(GameState, st, def, rec, "reconciled", "Season start")
	_check(not (st["active"] as Dictionary).has("reunion"), "reunion: an ended reunion is no longer active")
	var year := int(GameState.season_year)
	var hist: Dictionary = {}
	for h in st["coach"]["clubs"]:
		if str(h.get("code", "")) == old:
			hist = h
	_check(int(hist.get("reunion", 0)) == year, "reunion: the old club's last reunion is kept: %s" % str(hist))
	club["opp"] = GameDB.club_name(old)
	for back in [1, 5, 9]:
		hist["reunion"] = year - back
		_check(ClubMoves.reunion_trigger(GameState, st, club, ctx, false).is_empty(),
				"reunion: blocked %d season(s) after the last one against %s" % [back, old])
	hist["reunion"] = year - 10
	_check(not ClubMoves.reunion_trigger(GameState, st, club, ctx, false).is_empty(),
			"reunion: allowed again 10 seasons after the last one against %s" % old)
	# A flag won there: the premiership reunion on its 10-year anniversary,
	# even inside the cooldown, naming the flag year and the club.
	hist["reunion"] = year - 1
	var flag_row := {"year": year - 10, "premier": old, "my_club": old, "my_position": 1}
	GameState.honour_roll.append(flag_row)
	var anniv := ClubMoves.reunion_trigger(GameState, st, club, ctx, false)
	_check(bool(anniv.get("mem", {}).get("flag_reunion", false)) and int(anniv.get("mem", {}).get("flag_year", 0)) == year - 10,
			"reunion: a flag club gets the anniversary reunion: %s" % str(anniv))
	if not anniv.is_empty():
		var arec := CoachArcs.start(st, def, year, GameState.story_week(), "", anniv["mem"])
		var sline := ClubArcs._start_line(def, ClubArcs._facts(GameState, st, arec, club))
		_check(sline.find(str(year - 10)) >= 0 and sline.find(GameDB.club_name(old)) >= 0 and sline.find("premiership") >= 0,
				"reunion: the anniversary names the flag year and the team: %s" % sline)
		ClubArcs._end(GameState, st, def, arec, "enjoyed", "Season start")
		_check(int(hist.get("anniv", 0)) == year, "reunion: the anniversary is marked once told")
		_check(ClubMoves.reunion_trigger(GameState, st, club, ctx, false).is_empty(), "reunion: one anniversary reunion a year")
	GameState.honour_roll.erase(flag_row)
	hist.erase("anniv")
	hist["reunion"] = year


## The drought counts seasons at the club he coaches now, not his whole career.
func _test_drought_counts_this_club() -> void:
	var st := CoachArcs.new_state()
	st["coach"].merge({"seasons": 9, "seen": 2035, "start": 2027, "last_flag": 0, "club": "RIC",
			"clubs": [{"code": "FRE", "from": 2027, "to": 2032}, {"code": "RIC", "from": 2033, "to": 0}]}, true)
	_check(ClubArcs._dry(st) == 3, "drought: 3 seasons at Richmond after six at Fremantle, not 9: %d" % ClubArcs._dry(st))
	st["coach"]["last_flag"] = 2034
	_check(ClubArcs._dry(st) == 1, "drought: counted from a flag won at this club: %d" % ClubArcs._dry(st))
	st["coach"]["last_flag"] = 2030
	_check(ClubArcs._dry(st) == 3, "drought: a flag at the old club does not shorten it here: %d" % ClubArcs._dry(st))
	st["coach"].merge({"seen": 2031, "club": "FRE", "clubs": [{"code": "FRE", "from": 2027, "to": 0}], "last_flag": 0}, true)
	_check(ClubArcs._dry(st) == 5, "drought: one club, every season counted: %d" % ClubArcs._dry(st))
	# One drought runs until a flag (or a club change), not one a season.
	var def := CoachArcs.by_id(CoachArcs.all(), "drought")
	var rec := CoachArcs.start(st, def, 2032, 0, "", {})
	rec["beat"] = (def["beats"] as Array).size()
	_check(CoachArcs.closing(def, rec, {"premiers": false}, 2035) == "", "drought: no flag, it runs on into a fourth season")
	_check(CoachArcs.closing(def, rec, {"premiers": true}, 2035) == "broken", "drought: a flag ends it")


## Arc 11, the other way: backed to go, the assistant takes a rival's senior
## job at the season's close and his own job opens.
func _test_assistant_leaves() -> void:
	var st: Dictionary = GameState.coach_arcs
	var sa_id := _my_assistant()
	_check(sa_id != "", "assistant: the new club has a senior assistant")
	if sa_id == "":
		return
	var sa: Dictionary = GameState.coaches[sa_id]
	var to := ""
	for code in GameState.season.ladder:
		if str(code) != GameState.my_club and not _senior_at(str(code)).is_empty():
			to = str(code)
			break
	var def := CoachArcs.by_id(CoachArcs.all(), "assistant")
	st["active"].erase("assistant")
	var rec := CoachArcs.start(st, def, GameState.season_year, 1, "", {"assistant": GameDB.player_display_name(sa), "assistant_id": sa_id,
			"assistant_to": GameDB.club_name(to), "assistant_code": to})
	CoachArcs.answer(def, rec, "arc_assist_lunch", "delegate", 1, GameState.season_year)
	CoachArcs.answer(def, rec, "arc_assist_offer", "back", 5, GameState.season_year)
	ClubMoves._assistant_leaves(GameState, st)
	_check(str(sa.get("club", "")) == to and str(sa.get("job", "")) == "SC", "assistant: backed, he coaches %s" % to)
	_check(GameState._vacancy_open(str(sa.get("job", "SA"))) or GameState._vacancy_open("SA"), "assistant: his job is open")
	_check(CoachArcs.closing(def, rec, {"sacked": false}, GameState.season_year + 1) == "left_friend", "assistant: resolves 'left_friend'")
	st["active"].erase("assistant")


## The match-story facts (plan step 1b): validate() knows them, and an arc
## whose condition is hero_count >= 3 starts only after the third hero match.
func _test_hero_count_trigger() -> void:
	for f in ["hero_streak", "hero_count", "last_hero_mine", "hero_is_arc_player", "close_losses", "turned_against"]:
		_check(CoachArcs.ARC_FACTS.has(f), "the arcs know the fact %s" % f)
	var probe := [{"id": "probe", "kind": "club", "trigger": {"kind": "media"}, "beats": [CoachArcs.by_id(CoachArcs.all(), "media_darling")["beats"][0].duplicate(true)],
			"endings": {"done": {"line": "Done."}}, "close": [{"when": {}, "ending": "done"}]}]
	probe[0]["beats"][0]["id"] = "probe_beat"
	probe[0]["beats"][0]["when"] = {"hero_count_min": 3, "hero_streak_min": 1, "close_losses_max": 9}
	var errs := CoachArcs.validate(probe)
	_check(errs.is_empty(), "validate() accepts the new facts: %s" % str(errs))
	_fresh()
	# A kid of 19 on the list who is not a backed high-potential pick.
	var young: Dictionary = GameState.my_list[GameState.my_list.size() - 1]
	young["age"] = 19.0
	young["potential"] = 60
	var ctx := ClubStories.context(GameState)
	var kid := {}
	for p in ctx["players"]:
		if str(p["id"]) == str(young["id"]):
			kid = p
	_check(not kid.is_empty(), "the list has a player of 20 or under")
	var def := CoachArcs.by_id(CoachArcs.all(), "protege")
	var st: Dictionary = ClubArcs._st(GameState)
	GameState.match_stories = []
	for n in range(1, 4):
		GameState.match_stories.append({"year": GameState.season_year, "club": GameState.my_club, "opp": "WCE", "margin": 8,
				"hero_id": str(kid.get("id", "")), "hero_name": "Kid", "hero_club": GameState.my_club})
		var hit := ClubArcs.trigger(GameState, st, def, ClubStories.context(GameState), false)
		var named := str(hit.get("who", "")) == str(kid.get("id", ""))
		if n < 3:
			_check(not named, "after %d hero match(es) the protege arc does not start for him" % n)
		else:
			_check(named, "after the third hero match the protege arc starts for him: %s" % str(hit))
	var rec := {"who": str(kid.get("id", "")), "start": GameState.season_year}
	var f := ClubArcs._facts(GameState, st, rec, ctx["club"])
	_check(int(f["hero_count"]) == 3 and int(f["hero_streak"]) == 3 and bool(f["hero_is_arc_player"]),
			"the arc's facts read the match stories (%s)" % str([f["hero_count"], f["hero_streak"], f["hero_is_arc_player"]]))
	GameState.match_stories = []


## Row 111: a real seeded career, two seasons in good standing, sacked at the
## third season's close. The record reads every season and the club's years
## from his first season to the sacking ("Fremantle, 2026 to 2028, sacked").
func _test_real_sacking_record() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 11
	_fresh()
	var first := int(GameState.season_year)
	var old := str(GameState.my_club)
	for s in range(2):
		var guard := 0
		while not GameState.season.is_season_over() and guard < 40:
			guard += 1
			GameState.board["confidence"] = 80
			GameState.board["warned"] = false
			# A rival's approach would move him on: keep him at his club.
			GameState.coach_arcs["active"].erase("poached")
			_week(rng)
		_check(not GameState.is_sacked() and GameState.start_next_season(), "real career: season %d rolls on" % (s + 1))
		_check(GameState.my_club == old, "real career: still at %s" % old)
	GameState.board["goal"] = {"key": "wins99", "text": "Win 99 games", "wins": 99}
	var guard3 := 0
	while not GameState.season.is_season_over() and guard3 < 40:
		guard3 += 1
		GameState.board["confidence"] = 0
		GameState.board["warned"] = true
		# As above: a rival's job taken this season would stand in place of the sacking.
		GameState.coach_arcs["active"].erase("poached")
		_week(rng)
	var last := int(GameState.season_year)
	var lines := ClubMoves.record_lines(GameState)
	print("real career record (%d to %d): %s" % [first, last, " | ".join(lines)])
	if GameState.premier() == old:
		_check(true, "SKIP: %s won the flag, so the sacking never comes" % old)
		return
	_check(GameState.is_sacked(), "real career: sacked at the third season's close")
	_check(last == first + 2 and lines.size() >= 3 and lines[0].begins_with("3 seasons: "),
			"real career: the record counts all three seasons: %s" % str(lines))
	_check(lines[-1] == "%s, %d to %d, sacked" % [GameDB.club_name(old), first, last],
			"real career: the club line runs from his first season to the sacking: %s" % lines[-1])


## Row 112 (T5.r23): after a strong season (finals and the board's goal met)
## the season's close brings one rival board's letter; a weak season brings
## none. The off-season waits for his answer. Declined, it opens at his club and
## nothing else changes; taken, he moves at once: the new club's contracts,
## trades and draft are his this off-season, and the old club settles its
## contracts like any rival under the new club's old coach. One letter a
## season; it saves and loads open or answered.
func _news_has(text: String) -> bool:
	for item in GameState.news:
		if str(item.get("text", "")) == text:
			return true
	return false


func _letters_in_news() -> int:
	var n := 0
	for item in GameState.news:
		if str(item.get("text", "")).begins_with("A letter from"):
			n += 1
	return n


## A strong season played for real: Fremantle are put top of the ladder before
## the last home-and-away round (30 wins added), so they play the finals and
## meet any board goal, and the season's own close writes the letter.
## `tas_joins` false keeps Tasmania out of the league after the reset, so a
## club on the ladder writes the letter.
func _strong_season(rng: RandomNumberGenerator, tas_joins := true) -> void:
	_fresh()
	if not tas_joins:
		GameDB.set_enter_year("TAS", Expansion.NEVER)
	var guard := 0
	while GameState.season.round_index < GameState.season.fixture.size() - 1 and guard < 40:
		guard += 1
		_week(rng)
	GameState.season.ladder["FRE"]["w"] = int(GameState.season.ladder["FRE"]["w"]) + 30
	GameState.season.recalc_ladder()
	_play_out(rng)


## A club's expiring players nobody has decided on yet: still on the list,
## not re-signed, not retiring.
## Row 189: once he has signed elsewhere, the club he leaves offers him no
## off-season call: its contracts are decided, no trade offer or request is
## about its players, and no staff job or approach of its waits for him.
func _no_calls_for(tag: String, old: String) -> void:
	_check(_undecided(old) == 0, "%s: %s's contracts are decided by its own staff (%d waiting)" % [tag, old, _undecided(old)])
	var ids := {}
	for p in GameState.season.lists.get(old, []):
		ids[str(p["id"])] = true
	var offers_old := GameState.trade_offers.filter(func(o): return (o.get("take", []) as Array).any(func(id): return ids.has(str(id))))
	var asks_old := GameState.my_trade_requests().filter(func(id): return ids.has(str(id)))
	_check(offers_old.is_empty() and asks_old.is_empty(),
			"%s: no trade call about %s's players (offers %s, requests %s)" % [tag, old, str(offers_old), str(asks_old)])
	_check(GameState.staff_vacancies.is_empty() and GameState.coach_approaches.is_empty(),
			"%s: no staff call from %s (vacancies %s, approaches %s)" % [tag, old, str(GameState.staff_vacancies), str(GameState.coach_approaches)])


func _undecided(code: String) -> int:
	var n := 0
	for p in Contracts.expiring(GameState.season.lists.get(code, [])):
		if not GameState.retiring_now(p):
			n += 1
	return n


## Saves and loads back through a second file, so the save made with the
## letter open stays as it was for the next answer.
func _round_trip() -> bool:
	var keep := GameState.save_path
	GameState.save_path = "user://test_coach_arcs_answered.save"
	var ok := GameState.save_career() and GameState.load_career()
	GameState.save_path = keep
	return ok


## A letter's or a job offer's list line: the club's rating now and in three
## years and nothing else, never Contender / Wildcard / Rebuilding (director,
## 2026-11-08).
func _ratings_only(line: String, code: String) -> bool:
	var o := GameState.team_outlook(code)
	if o.is_empty():
		return false
	for word in ["Contender", "Wildcard", "Rebuilding"]:
		if line.find(word) >= 0:
			return false
	return line == TeamRating.rating_line(float(o["rating"]), float(o["forecast"]))


func _test_rival_letter() -> void:
	# A club on the ladder writes here: a club joining next season would write
	# first (row T5.Q25, its own tests below), so Tasmania stay out for now.
	_rival_letter_body()
	GameDB.set_enter_year("TAS", GameDB.data_enter_year("TAS"))


func _rival_letter_body() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 11
	_strong_season(rng, false)
	var st: Dictionary = GameState.coach_arcs
	var year := int(GameState.season_year)
	var l := ClubMoves.letter(GameState)
	var code := str(l.get("code", ""))
	_check(ClubMoves.strong_season(GameState) and ClubMoves.letter_open(GameState),
			"a strong season: the close writes a letter that waits for an answer: %s" % str(st.get("letter", {})))
	_check(code != "" and code != "FRE" and int(l.get("finish", 0)) > 0 and str(l.get("list", "")) != ""
			and str(l.get("goal", "")) != "" and str(l.get("why_open", "")) != "" and str(l.get("president", "")) != "",
			"the letter states the club, where they finished, the list, the board's goal and why the job is open: %s" % str(l))
	_check(_ratings_only(str(l.get("list", "")), code) and _ratings_only(str(l.get("my_list", "")), "FRE"),
			"the letter gives both lists as their ratings now and in three years, no list word: %s | %s"
			% [str(l.get("list", "")), str(l.get("my_list", ""))])
	var risk := ClubMoves.letter_risk(GameState)
	_check(risk.size() == 3 and risk[0].find("60 out of 100") >= 0 and risk[2].begins_with("Sacked there"),
			"the letter states the risk: %s" % str(risk))
	_check(not GameState.offseason_open() and _undecided("FRE") > 0 and _undecided(code) > 0,
			"the letter unanswered: the off-season waits, and neither club has settled its contracts (FRE %d, %s %d)"
			% [_undecided("FRE"), code, _undecided(code)])
	var once := JSON.stringify(st["letter"])
	var letters := _letters_in_news()
	ClubMoves._rival_letter(GameState, st)
	_check(letters == 1 and JSON.stringify(st["letter"]) == once and _letters_in_news() == letters,
			"one letter a season, however often the close is read")
	var their_id := str(_senior_at(code).get("cid", ""))
	_check(their_id != "", "the club that wrote has a senior coach to make way")
	_check(GameState.save_career() and GameState.load_career(), "the open letter saves and loads")
	st = GameState.coach_arcs
	_check(JSON.stringify(st["letter"]) == once and ClubMoves.letter_open(GameState) and not GameState.offseason_open(),
			"the open letter comes back as it was, the off-season still waiting")

	# The gate, read again on the same close: a weak season brings no letter.
	var hist: Array = GameState.board["history"]
	var h: Dictionary = GameState.honour_roll[-1]
	st["letter"] = {}
	h["my_finals"] = ""
	ClubMoves._rival_letter(GameState, st)
	_check(not ClubMoves.strong_season(GameState) and ClubMoves.letter(GameState).is_empty(), "no finals: no letter")
	h["my_finals"] = "QF"
	hist[-1]["met"] = false
	ClubMoves._rival_letter(GameState, st)
	_check(ClubMoves.letter(GameState).is_empty(), "the board's goal missed: no letter")
	hist[-1]["met"] = true
	GameState.board["sacked"] = true
	ClubMoves._rival_letter(GameState, st)
	_check(ClubMoves.letter(GameState).is_empty(), "sacked: no letter")

	# Take it: he moves now and runs the new club's off-season.
	_check(GameState.load_career(), "back to the close, the letter open")
	st = GameState.coach_arcs
	var fre_was := str(_senior_at("FRE").get("cid", ""))
	_check(ClubMoves.accept_letter(GameState), "he can take the job")
	_check(not ClubMoves.letter_open(GameState) and not ClubMoves.decline_letter(GameState) and (st["move"] as Dictionary).is_empty(),
			"taken: the answer stands and nothing is left for the rollover: %s" % str(st["move"]))
	_check(GameState.my_club == code and is_same(GameState.my_list, GameState.season.lists[code]),
			"taken: he coaches %s straight away" % code)
	_check(_senior_at(code).is_empty() and str(_senior_at("FRE").get("cid", "")) == their_id,
			"taken: he is %s's one senior coach, and Fremantle are coached by %s's old coach (was %s)" % [code, code, fre_was])
	var after := str(ClubMoves.letter(GameState).get("after", ""))
	var their_name := GameDB.player_display_name(_senior_at("FRE"))
	_check(str(l["why_open"]).find(GameDB.club_name(code)) >= 0 and after.begins_with("Fremantle have appointed %s to replace you." % their_name)
			and after.find(GameDB.club_name(code)) >= 0,
			"the letter and the answer name every coach with his club: %s | %s" % [str(l["why_open"]), after])
	_check(_news_has("You are the new senior coach of %s. %s" % [GameDB.club_name(code), after]),
			"the news of the move says who replaced him at Fremantle and where from")
	_check(GameState.offseason_open() and _undecided(code) > 0 and _undecided("FRE") == 0,
			"taken: the off-season opens; %s's contracts wait for him (%d), Fremantle settle theirs as a rival (%d left)"
			% [code, _undecided(code), _undecided("FRE")])
	var rec: Array = st["coach"]["clubs"]
	_check(rec.size() >= 2 and str(rec[-2]["code"]) == "FRE" and int(rec[-2]["to"]) == year
			and str(rec[-2].get("why_left", "")) == "poached" and str(rec[-1]["code"]) == code
			and int(rec[-1]["from"]) == year + 1 and int(rec[-1]["to"]) == 0,
			"taken: his record closes Fremantle at %d and starts %s in %d: %s" % [year, code, year + 1, str(rec)])
	var answered := JSON.stringify(st["letter"])
	_check(_round_trip() and GameState.my_club == code and JSON.stringify(GameState.coach_arcs["letter"]) == answered,
			"taken: the move and the answer survive a reload")
	_check(GameState.start_next_season() and GameState.my_club == code and _senior_at(code).is_empty()
			and str(_senior_at("FRE").get("cid", "")) == their_id and (GameState.season.lists["FRE"] as Array).size() > 0,
			"taken: the rollover leaves him at %s and Fremantle under their new coach" % code)
	_check(GameState.load_career() and ClubMoves.accept_letter(GameState) and GameState.begin_intake_draft()
			and GameState.draft.user_club == code, "taken: he runs %s's draft" % code)

	# Decline: the off-season opens at Fremantle and nothing else changes.
	_check(GameState.load_career(), "back to the close again")
	st = GameState.coach_arcs
	_check(ClubMoves.decline_letter(GameState), "he can say no")
	_check(not ClubMoves.letter_open(GameState) and (st["move"] as Dictionary).is_empty() and not ClubMoves.accept_letter(GameState),
			"declined: no move, and the letter cannot be taken after")
	_check(GameState.my_club == "FRE" and GameState.offseason_open() and _undecided("FRE") > 0 and _undecided(code) == 0,
			"declined: the off-season opens at Fremantle; their contracts wait for him (%d), %s settle theirs (%d left)"
			% [_undecided("FRE"), code, _undecided(code)])
	_check(_round_trip() and str(GameState.coach_arcs["letter"].get("answer", "")) == "declined", "the answer saves and loads")
	_check(GameState.start_next_season() and GameState.my_club == "FRE" and str(_senior_at(code).get("cid", "")) == their_id,
			"declined: he starts the next season at Fremantle and %s keep their coach" % code)
	_check(ClubMoves.letter(GameState).is_empty(), "last season's letter is gone at the new season")

	# A headless draft says no to a letter left unanswered.
	_check(GameState.load_career(), "back to the close once more")
	GameState.begin_intake_draft()
	_check(str(GameState.coach_arcs["letter"].get("answer", "")) == "declined" and GameState.my_club == "FRE"
			and GameState.offseason_year == GameState.season_year and GameState.draft.user_club == "FRE",
			"a draft started with the letter unanswered: he stays, and the off-season opened at Fremantle first")


# ---------------------------------------------------------------------------
# A club joining the league (director ruling 8, TODO T5.Q25)
# ---------------------------------------------------------------------------
## Every club drafts what it is owed, ours by the AI's own choice here.
func _ai_finish(draft: Draft) -> void:
	var guard := 0
	draft.auto_until_user_turn()
	while not draft.is_finished() and guard < 8000:
		guard += 1
		var cand := draft._best_ai_pick(draft.current_club())
		if cand.is_empty() or not draft._draft_pick(draft.current_club(), cand):
			draft._skip_current_pick()
		draft.auto_until_user_turn()


## Tasmania join the season after this one (the data has them in 2028; a
## test career's year can differ, so the test puts them there). Returns it.
func _tas_joins_next() -> int:
	var next := int(GameState.season_year) + 1
	GameDB.set_enter_year("TAS", next)
	return next


## His move to a club yet to play, checked at its first draft and on through
## its first season: the list, the cap, the board, his record, a reload.
func _check_joined(tag: String, from: String, year: int, their_id: String) -> void:
	var st: Dictionary = GameState.coach_arcs
	_check(GameState.my_club == "TAS" and GameState.draft != null and GameState.draft.user_club == "TAS"
			and GameState.club_yet_to_play(),
			"%s: at the %d National Draft he is Tasmania's coach and makes their picks (%s)" % [tag, year, GameState.my_club])
	_check(is_same(GameState.my_list, ExpansionBuild.list_of(GameState, "TAS")) and GameState.my_list.size() > 0,
			"%s: his list is the one Tasmania are building (%d)" % [tag, GameState.my_list.size()])
	_check(_senior_at("TAS").is_empty() and str(_senior_at(from).get("cid", "")) == their_id,
			"%s: Tasmania's first coach takes the job he left at %s" % [tag, from])
	var rec: Array = st["coach"]["clubs"]
	_check(rec.size() >= 2 and str(rec[-2]["code"]) == from and int(rec[-2]["to"]) == year and str(rec[-1]["code"]) == "TAS"
			and int(rec[-1]["from"]) == year + 1 and int(rec[-1]["to"]) == 0 and (st["move"] as Dictionary).is_empty(),
			"%s: his record closes %s at %d and starts Tasmania in %d: %s" % [tag, from, year, year + 1, str(rec)])
	_check(_news_has("You are the new senior coach of %s. %s" % [GameDB.club_name("TAS"), ClubMoves.successor_line(GameState, from, "TAS", year)]),
			"%s: the news says he is Tasmania's coach and who replaced him" % tag)
	var keep := GameState.save_path
	GameState.save_path = "user://test_coach_arcs_joining.save"
	_check(GameState.save_career() and GameState.load_career() and GameState.my_club == "TAS"
			and GameState.club_yet_to_play() and GameState.draft.user_club == "TAS",
			"%s: it saves and reloads at Tasmania's first draft" % tag)
	_ai_finish(GameState.draft)
	_check(GameState.finish_intake_draft() and GameState.season_year == year + 1 and GameState.my_club == "TAS"
			and GameState.season.lists.has("TAS") and is_same(GameState.my_list, GameState.season.lists["TAS"]),
			"%s: their first season is %d and his list is theirs" % [tag, year + 1])
	var all_tas := GameState.my_list.all(func(p): return str(p.get("club", "")) == "TAS")
	_check(GameState.my_list.size() >= Contracts.min_list() and all_tas,
			"%s: a full list, every player Tasmania's (%d)" % [tag, GameState.my_list.size()])
	_check(ExpansionBuild.relief(GameState, "TAS") > 0
			and GameState.cap_room() == GameState.salary_cap + ExpansionBuild.relief(GameState, "TAS") - GameState.my_payroll(),
			"%s: Tasmania's sign-on money counts on his cap room" % tag)
	_check(not GameState.club_yet_to_play() and GameState.board_confidence() == ClubLife.START_CONFIDENCE
			and not GameState.is_sacked(), "%s: the Hub is home and a fresh board starts him" % tag)
	_check(GameState.save_career() and GameState.load_career() and GameState.my_club == "TAS" and GameState.season_year == year + 1,
			"%s: the first Tasmania season saves and loads" % tag)
	GameState.save_path = keep
	GameDB.set_enter_year("TAS", GameDB.data_enter_year("TAS"))


## Sacked the season before Tasmania join: their job is one of the few on
## offer, saying why it is open and what the list has; taken, he is their
## coach from their first National Draft.
func _test_joining_club_after_sack() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 21
	_fresh()
	var year := int(GameState.season_year)
	var joins := _tas_joins_next()
	GameState.board["goal"] = {"key": "wins99", "text": "Win 99 games", "wins": 99}
	_play_out(rng, 0)
	var st: Dictionary = GameState.coach_arcs
	_check(GameState.is_sacked(), "joining, sacked: sacked at the close")
	var jobs: Array = st["offers"]
	var tas: Dictionary = {}
	for o in jobs:
		if str(o["code"]) == "TAS":
			tas = o
	_check(jobs.size() == ClubMoves.OFFERS and not tas.is_empty(),
			"joining, sacked: Tasmania are one of the %d jobs: %s" % [ClubMoves.OFFERS, str(jobs.map(func(o): return o["code"]))])
	_check(int(tas.get("joins", 0)) == joins and int(tas.get("finish", -1)) == 0
			and str(tas.get("why_open", "")).begins_with("Tasmania join the league in %d." % joins)
			and str(tas.get("list", "")).find("Picks 1, 3 and 9") >= 0 and str(tas.get("goal", "")).ends_with("In the bottom six, it is at least 7 wins."),
			"joining, sacked: the offer says the year they join, why the job is open, their list and picks, and the goal: %s" % str(tas))
	var their_id := str(_senior_at("TAS").get("cid", ""))
	_check(their_id != "", "joining, sacked: Tasmania have signed a first coach who would make way")
	# Row 189: he signs and goes straight to Tasmania's first National Draft;
	# Fremantle play out the off-season under their own staff.
	_check(ClubMoves.take_job(GameState, "TAS") and GameState.draft != null and GameState.draft.intake_mode
			and GameState.fa_closed_year == year,
			"joining, sacked: he takes the job and the National Draft opens, Fremantle's off-season played out")
	_no_calls_for("joining, sacked", "FRE")
	_check(GameState.begin_intake_draft(), "joining, sacked: the National Draft stays open")
	_check_joined("joining, sacked", "FRE", year, their_id)


## A strong season before Tasmania join: their board writes first. Taken, he
## signs now and takes over at Tasmania's first National Draft, which opens at
## once; Fremantle's contracts and trades are their own staff's (row 189).
func _test_joining_club_letter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SUITE_SEED + 22
	_fresh()
	var year := int(GameState.season_year)
	var joins := _tas_joins_next()
	var guard := 0
	while GameState.season.round_index < GameState.season.fixture.size() - 1 and guard < 40:
		guard += 1
		_week(rng)
	GameState.season.ladder["FRE"]["w"] = int(GameState.season.ladder["FRE"]["w"]) + 30
	GameState.season.recalc_ladder()
	_play_out(rng)
	var l := ClubMoves.letter(GameState)
	_check(ClubMoves.letter_open(GameState) and str(l.get("code", "")) == "TAS" and int(l.get("joins", 0)) == joins
			and int(l.get("finish", -1)) == 0 and str(l.get("why_open", "")).begins_with("Tasmania join the league"),
			"joining, letter: Tasmania's board writes, saying the year they join: %s" % str(l))
	var their_id := str(_senior_at("TAS").get("cid", ""))
	# Row 189: taken, he goes straight to Tasmania's first National Draft and
	# Fremantle play out the off-season under their own staff.
	_check(ClubMoves.accept_letter(GameState) and GameState.draft != null and GameState.draft.intake_mode
			and GameState.fa_closed_year == year,
			"joining, letter: taken, the National Draft opens with Fremantle's off-season played out")
	_no_calls_for("joining, letter", "FRE")
	_check(_news_has("You have taken the senior job at Tasmania. You take over at the %d National Draft." % year),
			"joining, letter: the news says when he takes over")
	_check(GameState.begin_intake_draft(), "joining, letter: the National Draft stays open")
	_check_joined("joining, letter", "FRE", year, their_id)


## A stand-in for GameState with only the coaches, so each way a senior job
## falls open can be set up exactly.
class FakeCoaches:
	var coaches := {}


## One made-up coach (fictional names, so the lines never lean on a real one).
func _coach(who: String, status: String, club: String, job: String, stints: Array, sacked_by := {}) -> Dictionary:
	return {"generic_name": who, "status": status, "club": club, "job": job, "stints": stints, "sacked_by": sacked_by}


## Every coach-move line names each coach's club (director, 2026-11-08: "why is
## it sam mitchell in photo 1 and then simon goodwin in photo 2?"): why the job
## is open, who the club signed, and who takes the job he leaves.
func _test_coach_move_lines() -> void:
	var y := 2027
	var signed := _coach("Gary Lenehan", "club", "HAW", "SC", [["SYD", "SA", 2026, y], ["HAW", "SC", y + 1, 0]])
	var cases := [
		[_coach("Rex Pollard", "club", "SYD", "SC", [["HAW", "SC", 2026, y]]),
				"Rex Pollard has left Hawthorn to coach Sydney."],
		[_coach("Rex Pollard", "club", "SYD", "SA", [["HAW", "SC", 2026, y], ["SYD", "SA", y + 1, 0]]),
				"Rex Pollard has left Hawthorn to join Sydney's coaching staff."],
		[_coach("Rex Pollard", "free", "", "", [["HAW", "SC", 2026, y]], {"HAW": y}), "Hawthorn sacked Rex Pollard."],
		[_coach("Rex Pollard", "retired", "", "", [["HAW", "SC", 2020, y]]), "Rex Pollard has retired as Hawthorn coach."],
		[_coach("Rex Pollard", "free", "", "", [["HAW", "SC", 2026, y]]), "Hawthorn have not renewed Rex Pollard's contract."],
		[_coach("Rex Pollard", "club", "HAW", "SA", [["HAW", "SC", 2026, y], ["HAW", "SA", y + 1, 0]]),
				"Hawthorn have moved Rex Pollard to an assistant's job."],
	]
	for c in cases:
		var gs := FakeCoaches.new()
		gs.coaches = {"a": c[0], "b": signed.duplicate(true)}
		var want: String = str(c[1]) + " Gary Lenehan was signed to replace him, but the board wants you instead."
		var got := ClubMoves.why_open_line(gs, "HAW", y)
		_check(got == want, "why the job is open, both coaches with their club: %s" % got)
	# Nobody left: the board wants its sitting coach out.
	var sitting := FakeCoaches.new()
	sitting.coaches = {"b": _coach("Gary Lenehan", "club", "HAW", "SC", [["HAW", "SC", 2024, 0]])}
	_check(ClubMoves.why_open_line(sitting, "HAW", y) == "The Hawthorn board wants to replace Gary Lenehan.",
			"a sitting coach the board would replace is named: %s" % ClubMoves.why_open_line(sitting, "HAW", y))
	_check(ClubMoves.why_open_line(FakeCoaches.new(), "HAW", y) == "The Hawthorn board wants a new senior coach.",
			"no coach at all: the board wants one")
	# Who takes the job he leaves (read after the move): both clubs named.
	var after := [
		[_coach("Gary Lenehan", "club", "FRE", "SC", [["SYD", "SA", 2026, y], ["HAW", "SC", y + 1, y], ["FRE", "SC", y + 1, 0]]),
				"Fremantle have appointed Gary Lenehan to replace you. Hawthorn had just signed him."],
		[_coach("Gary Lenehan", "club", "FRE", "SC", [["HAW", "SC", 2024, y], ["FRE", "SC", y + 1, 0]]),
				"Fremantle have appointed Gary Lenehan to replace you. He makes way for you at Hawthorn."],
		[_coach("Gary Lenehan", "club", "FRE", "SC", [["FRE", "SA", 2025, y], ["FRE", "SC", y + 1, 0]]),
				"Fremantle have promoted your old assistant Gary Lenehan to replace you."],
		[_coach("Gary Lenehan", "club", "FRE", "SC", [["ADE", "SC", 2020, 2024], ["FRE", "SC", y + 1, 0]]),
				"Fremantle have appointed Gary Lenehan to replace you."],
	]
	for c in after:
		var gs := FakeCoaches.new()
		gs.coaches = {"b": c[0]}
		var got := ClubMoves.successor_line(gs, "FRE", "HAW", y)
		_check(got == str(c[1]), "who replaces him at the club he leaves: %s" % got)
	_check(ClubMoves.successor_line(FakeCoaches.new(), "FRE", "HAW", y) == "Fremantle have yet to name your replacement.",
			"no successor yet: said so, club named")
