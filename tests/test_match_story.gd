extends RefCounted
## Run by tests/run_match_story_tests.gd (suite "match_story").
## The match makes the story (MatchStory.gd; director, 2026-11-03, plan step
## 1b): the hero is the best by real match stats, every reason traces to a
## number in the result, records persist across save and load, an old save
## loads.

var _tree: SceneTree
var checks := 0
var failures: Array[String] = []
const SUITE_SEED := 2027


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _settle(n := 6) -> void:
	for i in range(n):
		await _tree.process_frame


func _fresh() -> void:
	GameState.reset()
	GameState.start_season("FRE", GameDB.club_list("FRE"))
	GameState.replay_seed = SUITE_SEED
	GameState.tutorials = false
	Router.stack = []


func _rounds(n: int) -> void:
	for i in range(n):
		GameState.advance()


func _has_win_and_loss() -> bool:
	var won := false
	var lost := false
	for r in _my_matches():
		var me := _side(r)
		var m := int(r["score"][me]) - int(r["score"][1 - me])
		won = won or m > 0
		lost = lost or m < 0
	return won and lost


func _my_matches() -> Array:
	var out := []
	for r in GameState.season_log:
		if str(r["home"]) == GameState.my_club or str(r["away"]) == GameState.my_club:
			out.append(r)
	return out


func run(tree: SceneTree) -> void:
	_tree = tree
	await _tree.process_frame
	GameState.autosave_enabled = false
	GameState.save_path = "user://test_match_story.save"
	GameState.settings_path = "user://test_match_story.cfg"
	GameState.delete_saved_career()
	_t("_test_pure_hero")
	_t("_test_hero_matches_stats")
	_t("_test_reasons_trace")
	_t("_test_records_persist")
	_t("_test_old_save")
	_t("_test_arc_facts_and_digest")
	_t("_test_my_best_in_loss")
	_t("_test_digest_survives_trim")
	_t("_test_factors_never_repeat")
	for size in [Vector2i(390, 844), Vector2i(1280, 720)]:
		_tree.root.size = size
		await _settle()
		await _t("_test_summary", [size])
		await _t("_test_no_repeats", [size])
	GameState.delete_saved_career()
	print(Ran.line("Match story", self))
	for f in failures:
		print("  FAIL: " + f)


func _review() -> Node:
	GameState.review_requested = true
	Router.go("match")
	await _settle(10)
	return _tree.current_scene.find_child("FullTime", true, false)


## A hand-made result: the clutch goal and the clearances count toward the hero.
func _test_pure_hero() -> void:
	var a := {"kicks": 10, "handballs": 5, "marks": 4, "tackles": 3, "goals": 1, "disposals": 15}
	var b := a.duplicate()
	var res := {
		"home": "FRE", "away": "WCE", "score": [70, 64], "goals": [10, 9], "behinds": [10, 10],
		"roster": [[{"id": "p1", "name": "One"}, {"id": "p2", "name": "Two"}], [{"id": "p3", "name": "Three"}]],
		"players": {"p1": a, "p2": b, "p3": {"goals": 6, "kicks": 20, "disposals": 20}},
		"events": [{"kind": "goal", "side": 0, "q": 4, "min": 115, "score": [70, 64], "player_id": "p2", "name": "Two"}],
		"team": [{}, {}],
	}
	var clutch := MatchStory.clutch_goals(res)
	_check(int(clutch.get("p2", 0)) == 1, "a goal 25 minutes into the last, two points down before it, is clutch")
	var hero := MatchStory.hero_of(res)
	_check(str(hero.get("id", "")) == "p2", "the clutch goal makes the hero among equals (%s)" % str(hero.get("id")))
	_check(str(hero.get("line", "")).contains("late with the game in the balance"), "his line says the late goal")
	_check(int(hero["side"]) == 0, "the hero comes from the winners, not the losers' six-goal man")
	res["players"]["p1"]["clearances"] = 12
	_check(str(MatchStory.hero_of(res)["id"]) == "p1", "twelve clearances outweigh one clutch goal")
	res["events"][0]["min"] = 100
	_check(MatchStory.clutch_goals(res).is_empty(), "a goal ten minutes into the last is not clutch")


func _test_hero_matches_stats() -> void:
	_fresh()
	_rounds(4)
	var n := 0
	var ok := true
	for res in GameState.season_log:
		var hero := MatchStory.hero_of(res)
		var s: Array = res["score"]
		var sides := [0, 1] if int(s[0]) == int(s[1]) else [0 if int(s[0]) > int(s[1]) else 1]
		var clutch := MatchStory.clutch_goals(res)
		var best := -1
		var best_ids := []
		for side in sides:
			for r in res["roster"][side]:
				var st: Dictionary = res["players"].get(str(r["id"]), {})
				var pts := MatchStory.hero_points(st, int(clutch.get(str(r["id"]), 0)))
				if pts > best:
					best = pts
					best_ids = [str(r["id"])]
				elif pts == best:
					best_ids.append(str(r["id"]))
		var st: Dictionary = res["players"].get(str(hero.get("id", "")), {})
		if hero.is_empty() or not best_ids.has(str(hero["id"])) or int(hero["points"]) != best \
				or not sides.has(int(hero["side"])) or int(hero["goals"]) != int(float(st.get("goals", 0.0))) \
				or int(hero["disposals"]) != int(float(st.get("disposals", 0.0))):
			ok = false
			print("  hero mismatch: %s vs %s (%d)" % [str(hero), str(best_ids), best])
		n += 1
	_check(n >= 30, "four rounds give enough matches (%d)" % n)
	_check(ok, "every match's hero is the winners' best by goals, disposals, tackles, clearances and clutch goals")


func _test_reasons_trace() -> void:
	_fresh()
	_rounds(4)
	var bad := []
	var counts := {}
	for res in GameState.season_log:
		for side in [0, 1]:
			var why := MatchStory.reasons(res, side)
			if why.is_empty() or why.size() > 3:
				bad.append("%d reasons" % why.size())
			var me: Dictionary = res["team"][side]
			var op: Dictionary = res["team"][1 - side]
			for r in why:
				var stat := str(r["stat"])
				counts[stat] = int(counts.get(stat, 0)) + 1
				var a := int(r["mine"])
				var b := int(r["theirs"])
				var want := []
				if stat == "pressure_rating":
					want = [MatchSim.pressure_rating(me, op), MatchSim.pressure_rating(op, me)]
				elif stat == "scoring_shots":
					want = [int(res["goals"][side]) + int(res["behinds"][side]),
							int(res["goals"][1 - side]) + int(res["behinds"][1 - side])]
				elif stat.begins_with("q"):
					var i := int(r["quarter"]) - 1
					want = [int(res["q_goals"][i][side]) * 6 + int(res["q_behinds"][i][side]),
							int(res["q_goals"][i][1 - side]) * 6 + int(res["q_behinds"][i][1 - side])]
					if not MatchNotes.calls_lines(res, side, i + 1).has(str(r["call"])):
						bad.append("call line not from What your calls did: %s" % str(r["call"]))
				else:
					want = [int(float(me.get(stat, 0.0))), int(float(op.get(stat, 0.0)))]
				if [a, b] != want:
					bad.append("%s says %d-%d, result has %s" % [stat, a, b, str(want)])
				var text := str(r["text"])
				if not (text.contains(str(a)) and text.contains(str(b))):
					bad.append("text lacks its numbers: %s" % text)
	_check(bad.is_empty(), "every reason traces to a number in the result (%s)" % str(bad.slice(0, 3)))
	_check(counts.size() >= 2, "reasons come from more than one stat (%s)" % str(counts))


func _test_records_persist() -> void:
	_fresh()
	_rounds(3)
	var mine := _my_matches()
	_check(GameState.match_stories.size() == mine.size() and mine.size() >= 2,
			"one story per match of yours (%d of %d)" % [GameState.match_stories.size(), mine.size()])
	var rec: Dictionary = GameState.last_match_story()
	var hero := MatchStory.hero_of(GameState.last_match)
	_check(str(rec.get("hero_id", "")) == str(hero.get("id", "x")), "the record names the hero")
	_check(not (rec.get("reasons", []) as Array).is_empty(), "the record keeps the reasons")
	var news := {}
	for n in GameState.news:
		if str(n.get("kind", "")) == "match_story":
			news = n
			break
	_check(not news.is_empty(), "the hero is on the news")
	var story := NewsFront.story(news, GameState.my_club)
	_check(str(story["headline"]) == str(rec["headline"]) and str(story["name"]) == str(rec["hero_name"]),
			"the news front leads with the match headline (%s)" % str(story["headline"]))
	_check(bool(story["mine"]), "the story is marked as your club's")
	var mc: Dictionary = GameState.media_conference
	_check(mc.is_empty() or str(mc.get("question", "")) != "", "the press question still forms")
	var kept: Array = GameState.match_stories.duplicate(true)
	_check(GameState.save_career(), "saves with stories")
	GameState.match_stories = []
	_check(GameState.load_career(), "loads")
	_check(GameState.match_stories == kept, "the stories round-trip through save and load")
	_rounds(1)
	_check(GameState.match_stories.size() == _my_matches().size(), "Sim the week keeps adding them after a load")


func _test_old_save() -> void:
	_fresh()
	_rounds(2)
	GameState.match_stories = []
	_check(GameState.save_career(), "an old-style save is written")
	GameState.match_stories = [{"junk": 1}]
	_check(GameState.load_career(), "an old save loads")
	_check(GameState.match_stories.is_empty(), "absent stories load as empty")
	_rounds(1)
	_check(GameState.match_stories.size() == 1, "and the next match starts the record")
	GameState.delete_saved_career()


func _test_summary(size: Vector2i) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	_fresh()
	_rounds(1)
	var ft := await _review()
	_check(ft != null, "%s: full time opens" % tag)
	var box: Control = ft.find_child("MatchStory", true, false) if ft != null else null
	_check(box != null and box.is_visible_in_tree(), "%s: the Summary shows the match story" % tag)
	if box == null:
		return
	var rec := GameState.last_match_story()
	var hl: Label = box.find_child("MatchHero", true, false)
	_check(hl != null and hl.text == str(rec["hero_name"]), "%s: the hero is named" % tag)
	var why: Node = box.find_child("WhyReasons", true, false)
	_check(why != null and why.get_child_count() == (rec["reasons"] as Array).size(), "%s: the reasons are listed" % tag)
	var factors: Control = ft.find_child("MatchFactors", true, false)
	_check(factors != null, "%s: How it went is built" % tag)
	if factors != null and factors.visible:
		_check(box.get_global_rect().position.y < factors.get_global_rect().position.y,
				"%s: the story sits above How it went" % tag)
	var r := box.get_global_rect()
	_check(r.position.x >= -0.5 and r.end.x <= size.x + 0.5, "%s: the story fits the screen" % tag)
	Router.stack = []
	Router.go("hub")
	await _settle(4)


## hero_streak / hero_count / close_losses equal a count made by hand from
## match_stories, and the season digest totals equal the per-match records.
func _test_arc_facts_and_digest() -> void:
	_fresh()
	_rounds(12)
	var year := int(GameState.season_year)
	var recs: Array = GameState.match_stories.filter(func(r): return int(r["year"]) == year)
	var counts := {}
	var close_l := 0
	var against := 0
	var mine_ids := []
	for r in recs:
		var id := ""
		if str(r["hero_club"]) == str(r["club"]) and str(r["hero_id"]) != "":
			id = str(r["hero_id"])
		elif str(r.get("my_best_id", "")) != "":
			id = str(r["my_best_id"])
		if id != "":
			counts[id] = int(counts.get(id, 0)) + 1
		mine_ids.append(id)
		if int(r["margin"]) < 0 and int(r["margin"]) >= -12:
			close_l += 1
		if int(r["margin"]) < 0 and bool(r["comeback"]):
			against += 1
	var streak := 0
	if not mine_ids.is_empty() and str(mine_ids[-1]) != "":
		for i in range(mine_ids.size() - 1, -1, -1):
			if mine_ids[i] != mine_ids[-1]:
				break
			streak += 1
	var f := MatchStory.arc_facts(GameState.match_stories, year)
	_check(f["hero_counts"] == counts, "hero counts match a hand count (%s vs %s)" % [str(f["hero_counts"]), str(counts)])
	_check(int(f["hero_streak"]) == streak, "hero streak matches a hand count (%d vs %d)" % [int(f["hero_streak"]), streak])
	_check(int(f["close_losses"]) == close_l and int(f["turned_against"]) == against, "close losses and comebacks against match")
	var d: Dictionary = GameState.match_story_digest.get(str(year), {})
	_check(int(d.get("played", 0)) == recs.size() and recs.size() >= 10, "the digest counts every match (%d)" % recs.size())
	var total := 0
	for id in d.get("heroes", {}):
		total += int(d["heroes"][id]["count"])
		_check(int(d["heroes"][id]["count"]) == int(counts.get(id, -1)), "digest hero count for %s matches" % str(id))
	var hand_total := 0
	for id in counts:
		hand_total += int(counts[id])
	_check(total == hand_total, "digest hero total matches the records")
	var best := 0
	var worst := 0
	for r in recs:
		best = maxi(best, int(r["margin"]))
		worst = mini(worst, int(r["margin"]))
	_check(int((d["best_win"] as Dictionary).get("margin", 0)) == best and int((d["worst_loss"] as Dictionary).get("margin", 0)) == worst,
			"digest best win and worst loss are the real ones")
	_check(int(d["close_losses"]) == close_l, "digest close losses match")


## In a loss the record names your best player: yours, and the top by hero points.
func _test_my_best_in_loss() -> void:
	var found := false
	for r in GameState.season_log:
		var side := 0 if str(r["home"]) == GameState.my_club else (1 if str(r["away"]) == GameState.my_club else -1)
		if side < 0 or int(r["score"][side]) >= int(r["score"][1 - side]):
			continue
		found = true
		var rec := MatchStory.record(r, side, GameState.season_year)
		var mb := MatchStory.my_best(r, side)
		_check(int(mb["side"]) == side and str(rec["my_best_id"]) == str(mb["id"]) and str(rec["my_best_id"]) != "",
				"a loss names your best player from your side")
		var clutch := MatchStory.clutch_goals(r)
		var top := -9999
		for p in MatchNotes.rated_players(r, side):
			top = maxi(top, MatchStory.hero_points(p["stats"], int(clutch.get(str(p["id"]), 0))))
		_check(int(mb["points"]) == top, "your best is the top by hero points (%d vs %d)" % [int(mb["points"]), top])
		_check(str(rec["hero_club"]) != str(rec["club"]), "the hero is still the winners'")
		break
	if not found:
		_check(true, "no loss in the sample to check")


## A season folded into the digest survives the list being trimmed past 120.
func _test_digest_survives_trim() -> void:
	_fresh()
	var old := int(GameState.season_year) - 1
	GameState.match_stories = []
	GameState.match_story_digest = {}
	for i in range(GameState.MAX_MATCH_STORIES):
		var rec := {"year": old, "label": "Round %d" % (i % 23 + 1), "club": "FRE", "opp": "WCE", "margin": 10 if i % 2 == 0 else -5,
				"hero_id": "H1", "hero_name": "Old Hero", "hero_club": "FRE", "headline": "x", "turning_point": ""}
		GameState.match_stories.append(rec)
		MatchStory.fold(GameState.match_story_digest, rec)
	_rounds(2)
	_check(GameState.match_stories.size() == GameState.MAX_MATCH_STORIES, "the list stays capped at 120")
	var d: Dictionary = GameState.match_story_digest.get(str(old), {})
	_check(int(d.get("played", 0)) == GameState.MAX_MATCH_STORIES and int(d["heroes"]["H1"]["count"]) == GameState.MAX_MATCH_STORIES,
			"the trimmed season's digest is whole (%s)" % str(d.get("played")))
	_check(GameState.save_career() and GameState.load_career(), "saves and loads with a digest")
	_check(int((GameState.match_story_digest.get(str(old), {}) as Dictionary).get("played", 0)) == GameState.MAX_MATCH_STORIES,
			"the digest survives a save and load")


# ---------------------------------------------------------------------------
# Each fact once (director's bug report, 2026-11-06: "Double up of copy in hero
# of the match and how it went section").
# ---------------------------------------------------------------------------

func _side(r: Dictionary) -> int:
	return 0 if str(r["home"]) == GameState.my_club else (1 if str(r["away"]) == GameState.my_club else -1)


## Pure: How it went never says a fact the story above it already told, over
## twelve seeded rounds.
func _test_factors_never_repeat() -> void:
	_fresh()
	_rounds(12)
	var bad := []
	var cut := 0
	for r in _my_matches():
		var me := _side(r)
		var st := MatchStory.build(r, me)
		var told := MatchStory.told_facts(st)
		var items := MatchNotes.match_factor_items(r, me)
		var shown := MatchNotes.match_factors(r, me, told)
		if shown.size() < MatchNotes.match_factors(r, me).size():
			cut += 1
		for f in shown:
			var fact := ""
			for it in items:
				if str(it["text"]) == str(f):
					fact = str(it["fact"])
			if fact != "" and told.has(fact):
				bad.append("%s repeats %s" % [str(r["label"]), fact])
			if told.has("=" + MatchNotes.norm_sentence(str(f))):
				bad.append("%s repeats the sentence %s" % [str(r["label"]), str(f)])
			if str(f) == str(st["turning_point"]):
				bad.append("%s repeats the turning point" % str(r["label"]))
	# One turning point, from either side's seat: a comeback and the goal that
	# put a side in front for good are one moment, told once. Every match of
	# the twelve rounds, from both seats: one club's dozen games is too thin a
	# sample to be sure of a comeback built on the match's goal run.
	var comebacks := 0
	var run_merged := 0
	for r in GameState.season_log:
		if (r.get("events", []) as Array).is_empty():
			continue
		for side in [0, 1]:
			var st2 := MatchStory.build(r, side)
			if not ["turn", "turn:lead"].has(str(st2.get("turning_fact", ""))):
				continue
			comebacks += 1
			var run := MatchNotes._longest_run(r.get("events", []))
			var same_run := false
			if int(run["len"]) >= 4:
				var turn := ComebackTelling.turn_facts(r, side)
				if not turn.is_empty():
					same_run = int(run["side"]) == int(ComebackTelling.turning_quarter(r, side).get("side", -1)) 							and (turn.get("quarters", []) as Array).has(int(run["q"]))
				else:
					var lead: Array = MatchNotes.turning_point_items(r, side).filter(func(it): return str(it["fact"]) == "turn:lead")
					same_run = not lead.is_empty() and int(lead[0]["side"]) == int(run["side"]) and int(lead[0]["q"]) == int(run["q"])
			if same_run:
				run_merged += 1
			for f in MatchNotes.match_factors(r, side, MatchStory.told_facts(st2)):
				if str(f).contains("in front for good") or str(f).contains("turned it in the"):
					bad.append("%s tells the turning point twice: %s" % [str(r["label"]), str(f)])
				if same_run and str(f) == MatchNotes.run_sentence(r, run):
					bad.append("%s tells the comeback's goal run again: %s" % [str(r["label"]), str(f)])
	_check(comebacks > 0, "the seeded season has a turning point that is a lead change (%d)" % comebacks)
	_check(run_merged > 0, "the seeded season has a turning point made of the match's goal run (%d)" % run_merged)
	_check(bad.is_empty(), "How it went never repeats the story's facts (%s)" % str(bad.slice(0, 3)))
	_check(cut > 0, "the seeded season has matches where the story already said something (%d)" % cut)
	# No told facts: How it went is as it was for every older caller.
	var r0: Dictionary = _my_matches()[0]
	_check(MatchNotes.match_factors(r0, _side(r0)) == MatchNotes.match_factors(r0, _side(r0), {}),
			"no told facts leaves How it went as before")


## The Summary tab's visible text, sentence by sentence, normalised. Only
## sentences of four words or more: a name or a score alone is not a sentence.
func _summary_sentences(ft: Node) -> Array:
	var out := []
	for l in ft.find_children("*", "Label", true, false):
		if not (l as Label).is_visible_in_tree():
			continue
		for line in str(l.text).split("\n", false):
			for part in line.split(". ", false):
				var n := MatchNotes.norm_sentence(part)
				if n.split(" ", false).size() >= 4:
					out.append(n)
	return out


func _labels_text(n: Node) -> String:
	var t := ""
	if n == null:
		return t
	if n is Label:
		t += str(n.text) + "\n"
	for l in n.find_children("*", "Label", true, false):
		t += str(l.text) + "\n"
	return t


## Renders one match's full time and fails on any sentence or fact said twice.
func _check_once(r: Dictionary, tag: String) -> void:
	GameState.last_match = r
	var ft := await _review()
	_check(ft != null, "%s: full time opens" % tag)
	if ft == null:
		return
	var seen := {}
	var twice := []
	for n in _summary_sentences(ft):
		if seen.has(n):
			twice.append(n)
		seen[n] = true
	_check(twice.is_empty(), "%s: no sentence twice on full time (%s)" % [tag, str(twice.slice(0, 2))])
	var me := _side(r)
	var st := MatchStory.build(r, me)
	var factors: Control = ft.find_child("MatchFactors", true, false)
	var ftext := _labels_text(factors)
	var tp := str(st["turning_point"])
	_check(tp == "" or not ftext.contains(tp), "%s: the turning point is not said again under How it went" % tag)
	if (st.get("turning_also", []) as Array).has("run"):
		var run2 := MatchNotes._longest_run(r.get("events", []))
		_check(not ftext.contains(MatchNotes.run_sentence(r, run2)),
				"%s: the goal run the turning point was made of is not told again (%s)" % [tag, ftext.strip_edges()])
	# One turning point: a comeback and the goal that put a side in front for good are the same moment.
	if ["turn", "turn:lead"].has(str(st.get("turning_fact", ""))):
		_check(not ftext.contains("in front for good") and not ftext.contains("turned it in the"),
				"%s: How it went does not tell the turning point a second way (%s)" % [tag, ftext.strip_edges()])
	var codes := [str(r["home"]), str(r["away"])]
	for reason in st["reasons"]:
		if str(reason["stat"]) == "scoring_shots":
			# The no-clear-edge reason quotes both scorelines: How it went does not quote them again.
			for s in [me, 1 - me]:
				var sl := "%d.%d" % [int(r["goals"][s]), int(r["behinds"][s])]
				_check(not ftext.contains(sl), "%s: How it went does not repeat the %s scoreline %s" % [tag, codes[s], sl])
			continue
		if not ["pressure_rating", "clearances", "inside50"].has(str(reason["stat"])):
			continue
		var a := int(reason["mine"])
		var b := int(reason["theirs"])
		for l in ftext.split("\n", false):
			_check(not (l.contains("%d to %d" % [a, b]) or l.contains("%d to %d" % [b, a])),
					"%s: How it went does not repeat the %s numbers (%s)" % [tag, str(reason["stat"]), l])
	# The hero's line (and your best's) never repeats a number his Best players row gives.
	var rows := {}
	var votes := MatchNotes.coaches_votes(r)
	for side in [0, 1]:
		for p in MatchNotes.standouts_by_votes(r, side, 3, votes):
			rows[str(p["id"])] = str(p["line"])
	for pair in [["MatchHeroLine", st["hero"]], ["MatchMyBest", MatchStory.my_best(r, me) if int(st["margin"]) < 0 else {}]]:
		var node := ft.find_child(str(pair[0]), true, false)
		var who: Dictionary = pair[1]
		if node == null or who.is_empty() or not rows.has(str(who["id"])):
			continue
		for bit in str(rows[str(who["id"])]).split(", ", false):
			_check(not str(node.text).to_lower().contains(bit.to_lower()),
					"%s: %s does not repeat %s from Best players (%s)" % [tag, str(pair[0]), bit, str(node.text)])
	# The coaching notes do not say a reason again in other words.
	var notes := _labels_text(ft.find_child("ReportNotes", true, false))
	var topics := CoachReport.told_topics()
	for reason in st["reasons"]:
		var topic := str(topics.get(str(reason["stat"]), ""))
		_check(topic == "" or not notes.contains(topic),
				"%s: the coaching notes do not repeat the %s reason (%s)" % [tag, str(reason["stat"]), notes.strip_edges()])
	var head: Control = ft.find_child("HowItWentHead", true, false)
	_check(factors != null and head != null, "%s: How it went is built" % tag)
	if factors != null and head != null:
		var empty := factors.get_child_count() == 0
		_check(factors.visible == not empty and head.visible == not empty,
				"%s: How it went shows only with something left to say (%d lines)" % [tag, factors.get_child_count()])
	print("  %s: %s" % [tag, " | ".join(_summary_sentences(ft))])
	Router.stack = []
	Router.go("hub")
	await _settle(4)


func _test_no_repeats(size: Vector2i) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	_fresh()
	_rounds(8)
	# Play on until the season has both a win and a loss to read: how many
	# rounds that takes is the sim's business, not this test's.
	var extra := 0
	while extra < 12 and not _has_win_and_loss():
		_rounds(1)
		extra += 1
	var win := {}
	var loss := {}
	for r in _my_matches():
		var me := _side(r)
		var m := int(r["score"][me]) - int(r["score"][1 - me])
		var told := MatchStory.told_facts(MatchStory.build(r, me))
		# The director's kind first: the story already told something How it went had.
		var rich := MatchNotes.match_factors(r, me, told).size() < MatchNotes.match_factors(r, me).size()
		if m > 0 and (win.is_empty() or (rich and not bool(win["rich"]))):
			win = {"r": r, "rich": rich}
		elif m < 0 and (loss.is_empty() or (rich and not bool(loss["rich"]))):
			loss = {"r": r, "rich": rich}
	_check(not win.is_empty() and not loss.is_empty(), "%s: the season gives a win and a loss" % tag)
	if not win.is_empty():
		await _check_once(win["r"], tag + " win")
	if not loss.is_empty():
		await _check_once(loss["r"], tag + " loss")
	# Two debuts in the last match, as the director saw: each said once, in
	# Milestones, in the fuller words; "made his debut" is gone.
	var last: Dictionary = _my_matches()[-1]
	GameState.last_match = last
	var me := _side(last)
	var ids := []
	for row in last["roster"][me]:
		if ids.size() < 2:
			ids.append(str(row["id"]))
	var mk := Milestones.match_key(GameState.season_year, last)
	GameState.milestone_log["last_match"] = mk
	var names := []
	for id in ids:
		var p: Dictionary = GameState.list_player(id)
		var nm := str(GameDB.player_display_name(p))
		names.append(nm)
		Firsts.note(p, "debut", GameState.season_year, str(last["label"]))
		(GameState.milestone_log["log"] as Array).append({"who": "player", "kind": "debut", "value": 1, "id": id,
				"name": nm, "text": "%s made his debut." % nm, "match": mk})
	var ft := await _review()
	var said := _labels_text(ft.find_child("MilestoneLine", true, false) if ft != null else null) \
			+ _labels_text(ft.find_child("PayoffLines", true, false) if ft != null else null)
	_check(not said.contains("made his debut"), "%s: the debut is said in the fuller words (%s)" % [tag, said])
	for i in range(names.size()):
		var goals := int((last["players"].get(ids[i], {}) as Dictionary).get("goals", 0))
		_check(said.count(str(names[i])) == 1 and said.contains(Firsts.debut_line(str(names[i]), goals)),
				"%s: %s's debut is said once (%s)" % [tag, str(names[i]), said.strip_edges()])
	Router.stack = []
	Router.go("hub")
	await _settle(4)
