extends RefCounted
## The live match view (PitchView, MatchDirector, MatchMotion) is presentation
## only: these checks hold it to that. Run through
## tests/run_match_visual_tests.gd.

var failures: Array[String] = []
var checks := 0


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	var res := _result(42)
	_test_sim_untouched(res)
	_test_full_playback(res)
	_test_speed_sequencing(res)
	_test_rng_isolation(res)
	_test_appended_segments()
	_test_pitch_view_api(res)
	_test_empty_view()
	print("Match visual tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _sim(seed: int, a := "RIC", b := "SYD") -> MatchSim:
	return MatchSim.new(Squad.new(a, GameDB.club_list(a), true, a),
			Squad.new(b, GameDB.club_list(b), false, b), seed)


func _result(seed: int) -> Dictionary:
	var res := _sim(seed).run()
	res["home"] = "RIC"
	res["away"] = "SYD"
	res["label"] = "Round 1"
	return res


## Play `events` through a director in steps of `dt` until everything is
## released. Returns the released events and what was seen on the way.
func _play(res: Dictionary, events: Array, dt: float, watch := true) -> Dictionary:
	var d := MatchDirector.new()
	d.setup(res, events)
	var out := []
	var nan := 0
	var outside := 0
	var max_step := 0.0
	var prev := []
	for t in d.tokens:
		prev.append(t["pos"])
	var guard := 0
	var limit := int(6000.0 / dt)
	while not d.idle() and guard < limit:
		guard += 1
		out.append_array(d.advance(dt))
		if not watch:
			continue
		for i in range(d.tokens.size()):
			var p: Vector2 = d.tokens[i]["pos"]
			if not p.is_finite():
				nan += 1
			elif not MatchMotion.inside_oval(p, -0.01):
				outside += 1
			max_step = maxf(max_step, p.distance_to(prev[i]))
			prev[i] = p
		if not (d.ball["pos"] as Vector2).is_finite() or not is_finite(float(d.ball["h"])):
			nan += 1
	return {"out": out, "director": d, "nan": nan, "outside": outside,
			"max_step": max_step, "stalled": guard >= limit}


# ---------------------------------------------------------------------------
func _test_sim_untouched(res: Dictionary) -> void:
	var before: Array = (res["events"] as Array).duplicate(true)
	var played := _play(res, res["events"], 1.0 / 15.0, false)
	_check(played["out"].size() == before.size(), "Every event is released once")
	_check(res["events"] == before, "Playback never writes to an event")
	# The same fixture replayed from scratch is identical: the view has no
	# path back into the match.
	var again := _result(42)
	_check(again["events"] == before, "Event log identical after a playback")
	_check(again["score"] == res["score"] and again["winner"] == res["winner"],
			"Score and winner identical after a playback")
	_check(again["players"] == res["players"] and again["team"] == res["team"],
			"Player and team stats identical after a playback")


func _test_full_playback(res: Dictionary) -> void:
	var played := _play(res, res["events"], 1.0 / 60.0 * 4.0)
	var d: MatchDirector = played["director"]
	var out: Array = played["out"]
	_check(not played["stalled"], "Playback reaches the end of the log")
	_check(out.size() == (res["events"] as Array).size(), "All %d events released (%d)" % [
			(res["events"] as Array).size(), out.size()])
	var in_order := true
	for i in range(mini(out.size(), (res["events"] as Array).size())):
		if not is_same(out[i], res["events"][i]):
			in_order = false
			break
	_check(in_order, "Events are released in log order, as the same dictionaries")
	_check(int(played["nan"]) == 0, "No NaN positions (%d)" % int(played["nan"]))
	_check(int(played["outside"]) == 0, "Every player stays on the oval (%d outside)" % int(played["outside"]))
	# 4x at 60 fps: a sprinter covers well under 2 m a frame. More would be a
	# visible jump.
	_check(float(played["max_step"]) < 2.2, "No player jumps (largest frame step %.2f m)" % float(played["max_step"]))
	var arrivals: Array = d.arrivals
	var close := 0
	var worst := 0.0
	for a in arrivals:
		var err := absf((a["pos"] as Vector2).x - float(a["want_x"]))
		worst = maxf(worst, err)
		if err <= 3.0:
			close += 1
	_check(arrivals.size() > 800, "Arrivals are logged (%d)" % arrivals.size())
	_check(float(close) >= 0.99 * float(arrivals.size()),
			"The ball is at the logged spot when the event is released (%d of %d within 3 m)" % [close, arrivals.size()])
	_check(worst < 15.0, "No release far from the logged spot (worst %.1f m)" % worst)
	var scores := 0
	for a in arrivals:
		if str(a["kind"]) == "goal" or str(a["kind"]) == "behind":
			scores += 1
			if absf((a["pos"] as Vector2).x) < 84.0:
				scores -= 1000
	_check(scores > 0, "Every goal and behind is released at the goal line")


func _test_speed_sequencing(res: Dictionary) -> void:
	var evs: Array = (res["events"] as Array).slice(0, 220)
	var slow: Array = _play(res, evs, 1.0 / 60.0, false)["out"]
	var fast: Array = _play(res, evs, 1.0 / 60.0 * 8.0, false)["out"]
	var lumpy: Array = _play(res, evs, 0.4, false)["out"]
	_check(slow.size() == evs.size() and fast.size() == evs.size() and lumpy.size() == evs.size(),
			"Every speed releases every event")
	var same := true
	for i in range(evs.size()):
		if i >= slow.size() or i >= fast.size() or i >= lumpy.size() \
				or not is_same(slow[i], evs[i]) or not is_same(fast[i], evs[i]) \
				or not is_same(lumpy[i], evs[i]):
			same = false
			break
	_check(same, "1x, 8x and long frames release the same events in the same order")


func _test_rng_isolation(res: Dictionary) -> void:
	var evs: Array = (res["events"] as Array).slice(0, 150)
	seed(12345)
	var expect := [randi(), randi(), randi()]
	seed(12345)
	var a := _play(res, evs, 1.0 / 15.0, false)
	var got := [randi(), randi(), randi()]
	_check(got == expect, "Playback draws nothing from the global random stream")
	var b := _play(res, evs, 1.0 / 15.0, false)
	var sa: Dictionary = (a["director"] as MatchDirector).snapshot()
	var sb: Dictionary = (b["director"] as MatchDirector).snapshot()
	_check(var_to_str(sa) == var_to_str(sb), "The same match plays out the same way twice")
	# A different fixture label reseeds the presentation only.
	var other := res.duplicate()
	other["label"] = "Round 2"
	var c := _play(other, evs, 1.0 / 15.0, false)
	_check(c["out"].size() == evs.size(), "Another presentation seed still releases every event")


func _test_appended_segments() -> void:
	var res := _result(7)
	var all: Array = res["events"]
	var cut := 0
	for i in range(all.size()):
		if str(all[i]["kind"]) == "quarter":
			cut = i + 1
			break
	var events := all.slice(0, cut)
	var d := MatchDirector.new()
	d.setup(res, events)
	var out := []
	var guard := 0
	while not d.idle() and guard < 100000:
		guard += 1
		out.append_array(d.advance(1.0 / 15.0))
	_check(out.size() == cut, "The first segment plays to its end (%d/%d)" % [out.size(), cut])
	events.append_array(all.slice(cut))
	_check(not d.idle(), "Appended events wake the view")
	guard = 0
	while not d.idle() and guard < 200000:
		guard += 1
		out.append_array(d.advance(1.0 / 15.0))
	var ok := out.size() == all.size()
	for i in range(mini(out.size(), all.size())):
		if not is_same(out[i], all[i]):
			ok = false
			break
	_check(ok, "Appended segments release every event in order (%d/%d)" % [out.size(), all.size()])


func _test_pitch_view_api(res: Dictionary) -> void:
	var pv := PitchView.new()
	pv.size = Vector2(800, 600)
	var seen := []
	var fin := [0]
	pv.event_played.connect(func(ev): seen.append(ev))
	pv.finished.connect(func(): fin[0] += 1)
	pv.setup(res)
	_check(pv.events == res["events"] and not is_same(pv.events, res["events"]),
			"The view keeps its own copy of the event list")
	pv.set_speed(8.0)
	pv.play()
	for i in range(400):
		pv._process(1.0 / 60.0)
	_check(seen.size() > 0 and pv.current_index() == seen.size(), "current_index() counts released events")
	var before := seen.size()
	pv.skip_to_end()
	_check(fin[0] == 1, "skip_to_end() finishes at once")
	_check(seen.size() == before, "skip_to_end() does not replay the feed")
	_check(pv.current_index() == (res["events"] as Array).size() and is_equal_approx(pv.progress(), 1.0),
			"skip_to_end() leaves the view at the end of the log")
	_check(not pv.playing, "Nothing plays after a skip")
	# Playing to the final siren closes playback with one finished signal.
	var pv2 := PitchView.new()
	pv2.size = Vector2(800, 600)
	var fin2 := [0]
	var last := [""]
	pv2.finished.connect(func(): fin2[0] += 1)
	pv2.event_played.connect(func(ev): last[0] = str(ev["kind"]))
	var short := res.duplicate()
	short["events"] = (res["events"] as Array).slice(0, 40) + [(res["events"] as Array)[-1]]
	pv2.setup(short)
	pv2.set_speed(8.0)
	pv2.play()
	var guard := 0
	while pv2.playing and guard < 20000:
		guard += 1
		pv2._process(1.0 / 60.0)
	_check(last[0] == "final" and fin2[0] == 1 and not pv2.playing,
			"The final siren ends playback with one finished signal")
	pv.free()
	pv2.free()


func _test_empty_view() -> void:
	# The main menu draws the oval with no match behind it.
	var pv := PitchView.new()
	pv.size = Vector2(640, 480)
	pv.setup({"events": [], "roster": [[], []], "home": "", "away": ""})
	pv.play()
	pv._process(0.1)
	_check(not pv.playing and pv.director.tokens.is_empty(), "An empty view idles safely")
	pv.free()
