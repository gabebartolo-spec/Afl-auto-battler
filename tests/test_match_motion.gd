extends RefCounted
## How the live match moves, measured where a phone draws it (the upright oval,
## 300 x 387 as the match screen places it): the motion limits every shape keeps
## and the coach's calls on the oval against Balanced. Run through
## tests/run_match_motion_tests.gd.
##
## Why its own suite (the motion critic, 2026-10-18): the calls were measured
## from target spots and from the engine's positions, and passed, while the
## clips showed discs snapping 4 to 10 m in a frame, a crash at twice a sprint,
## piles hiding numbers and two calls barely moving. Here everything is read
## from the discs as drawn, frame by frame, at 1x and 4x.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 2027
## The phone's oval (capture_oval_audit: the match screen's rect on a 320 x 693
## phone).
const PHONE := Vector2(300, 387)
const FRAME := 1.0 / 30.0
## At least this share of a side's disc area shows in 99 frames in 100 (Balanced
## never drops below 76%; the critic's worst frames were 15.7 of 18 discs with
## Attack corridor and 12.3 with Win contest), and VISIBLE_WORST in every frame.
const VISIBLE_FLOOR := 0.72
const VISIBLE_WORST := 0.55
## Every shape moves its side at least this far from Balanced, measured as below.
const CALL_FLOOR := 8.0


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	var res := _result(42)
	_test_measures_prove_themselves(res)
	_test_motion_limits(res)
	_test_call_visibility(res)
	GameState.replay_seed = 0
	print("Match motion tests: %d checks, %d failures" % [checks, failures.size()])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


## Fremantle v Melbourne (two clubs with real colour), as the clips show them.
func _result(seed: int) -> Dictionary:
	var res := MatchSim.new(Squad.new("FRE", GameDB.club_list("FRE"), true, "FRE"),
			Squad.new("MEL", GameDB.club_list("MEL"), false, "MEL"), seed).run()
	res["home"] = "FRE"
	res["away"] = "MEL"
	res["label"] = "Round 1"
	return res


func _phone(r: Dictionary, speed: float) -> PitchView:
	var pv := PitchView.new()
	pv.size = PHONE
	pv.camera_enabled = false
	pv.upright = true
	pv.setup(r)
	pv.set_speed(speed)
	pv.play()
	return pv


## The drawn discs back on the ground, in metres (the view's own mapping inverted).
static func _drawn_world(pv: PitchView, drawn: PackedVector2Array) -> Array:
	var o: Vector2 = pv._w2s(Vector2.ZERO)
	var ex: Vector2 = pv._w2s(Vector2(1, 0)) - o
	var ey: Vector2 = pv._w2s(Vector2(0, 1)) - o
	var det := ex.x * ey.y - ex.y * ey.x
	var out := []
	for p in drawn:
		var v: Vector2 = p - o
		out.append(Vector2((v.x * ey.y - v.y * ey.x) / det, (ex.x * v.y - ex.y * v.x) / det))
	return out


## The share of `side`'s disc area that shows, with the discs drawn at `drawn`
## (radius `r`) in the order `order` (last on top). Sampled on a grid in each disc.
static func visible_share(drawn: PackedVector2Array, sides: Array, side: int, order: Array, r: float) -> float:
	var rank := {}
	for k in range(order.size()):
		rank[int(order[k])] = k
	var total := 0.0
	var n := 0
	for i in range(drawn.size()):
		if int(sides[i]) != side:
			continue
		n += 1
		var over := []
		for j in range(drawn.size()):
			if j != i and int(rank[j]) > int(rank[i]) and drawn[j].distance_to(drawn[i]) < 2.0 * r:
				over.append(drawn[j])
		if over.is_empty():
			total += 1.0
			continue
		var seen := 0
		var all := 0
		for gx in range(-3, 4):
			for gy in range(-3, 4):
				var q: Vector2 = drawn[i] + Vector2(gx, gy) * r / 3.0
				if q.distance_to(drawn[i]) > r:
					continue
				all += 1
				var hid := false
				for c in over:
					if (c as Vector2).distance_to(q) <= r:
						hid = true
						break
				if not hid:
					seen += 1
		total += float(seen) / float(all)
	return total / maxf(1.0, float(n))


static func _sd(v: Array) -> float:
	var m := 0.0
	for x in v:
		m += float(x) / float(v.size())
	var s := 0.0
	for x in v:
		s += pow(float(x) - m, 2.0) / float(v.size())
	return sqrt(s)


static func _median(v: Array) -> float:
	var c := v.duplicate()
	c.sort()
	return 0.5 * (float(c[(c.size() - 1) / 2]) + float(c[c.size() / 2]))


## The bench strip's two corners on the phone, grown by a disc's radius: no
## structure spot may put a disc under them.
static func _bench_rects(pv: PitchView) -> Array:
	var tr := pv.token_radius()
	var spots: Array = pv.bench_spots(tr)
	if spots.is_empty() or bool(spots[0]["column"]):
		return []
	var br: float = spots[0]["r"]
	var wide := 6.0 + 5.0 * (br * 2.0 + 4.0)
	var tall := br * 2.0 + 24.0
	return [Rect2(0.0, pv.size.y - tall, wide, tall).grow(tr),
			Rect2(pv.size.x - wide, pv.size.y - tall, wide, tall).grow(tr)]


## How far inside the boundary line `p` is, in metres.
static func _inside_by(p: Vector2) -> float:
	var lo := -10.0
	var hi := 40.0
	for i in range(16):
		var m := 0.5 * (lo + hi)
		if MatchMotion.inside_oval(p, m):
			lo = m
		else:
			hi = m
	return lo


## The measures catch what they are for, on inputs known to be wrong.
func _test_measures_prove_themselves(res: Dictionary) -> void:
	var drawn := PackedVector2Array()
	var sides := []
	var order := []
	for i in range(36):
		drawn.append(Vector2(100.0 + 30.0 * float(i % 6), 100.0 + 30.0 * float(i / 6)))
		sides.append(0 if i < 18 else 1)
		order.append(i)
	var apart := visible_share(drawn, sides, 0, order, 9.0)
	for i in range(18, 36):
		drawn[i] = Vector2(100.0, 100.0) + Vector2(float(i % 3), float(i % 2)) * 4.0
	for i in range(0, 9):
		drawn[i] = Vector2(102.0, 101.0)
	var piled := visible_share(drawn, sides, 0, order, 9.0)
	_check(is_equal_approx(apart, 1.0) and piled < VISIBLE_FLOOR,
			"The visibility measure sees a pile: every disc shows when they stand apart (%.2f), half the side under a pack does not (%.2f)" % [apart, piled])
	var pv := _phone(res, 1.0)
	var rects := _bench_rects(pv)
	var pocket: Vector2 = pv._w2s(Vector2(-80.0, -20.0)) if (pv._w2s(Vector2(-80.0, 0.0)).y > PHONE.y * 0.5) \
			else pv._w2s(Vector2(80.0, -20.0))
	var hit := false
	for rc in rects:
		hit = hit or (rc as Rect2).has_point(pocket)
	_check(rects.size() == 2 and hit, "The bench-strip measure sees a back pocket (80 m from the centre, 20 m across) under the strip")
	pv.free()


## Motion limits for every shape and call (MatchMotion.SPRINT, WALK;
## MatchDirector._structure_limits): 640 events with every plan and short call
## on both sides in turn, drawn on the phone at 1x and 4x, every frame.
func _test_motion_limits(res: Dictionary) -> void:
	var r2 := res.duplicate()
	r2["events"] = (res["events"] as Array).slice(0, 640)
	var opening := [{}, {}]
	for e in res["timeline"]:
		if int(e["at"]) == 0:
			opening[int(e["side"])] = e
	var calls := [[["attacking", ["surge"]], ["contest", ["hold"]]],
			[["controlled", ["hold"]], ["through_stars", ["surge"]]],
			[["through_stars", []], ["attacking", ["flood"]]],
			[["contest", ["surge"]], ["controlled", []]]]
	var tl := []
	for k in range(calls.size()):
		for side in range(2):
			var e: Dictionary = (opening[side] as Dictionary).duplicate(true)
			e["at"] = k * 160
			e["side"] = side
			e["plan"] = calls[k][side][0]
			e["bursts"] = calls[k][side][1]
			tl.append(e)
	r2["timeline"] = tl
	for speed in [1.0, 4.0]:
		var pv := _phone(r2, speed)
		var d: MatchDirector = pv.director
		var h: float = FRAME * speed * MatchDirector.TEMPO
		var rects := _bench_rects(pv)
		var sides := []
		for t in d.tokens:
			sides.append(int(t["side"]))
		var prev_tok := []
		var prev_draw := PackedVector2Array()
		var period: int = pv.period
		var tok_most := 0.0
		var draw_most := 0.0
		var vis_min := [1.0, 1.0]
		var vis_n := 0
		var vis_low := 0
		var narrow := INF
		var narrow_n := 0
		var inside := INF
		var under := 0
		var pack_most := 0
		var pack_n := 0
		var frames := 0
		var guard := 0
		while pv.playing and guard < 200000:
			guard += 1
			pv._process(FRAME)
			var drawn: PackedVector2Array = pv.disc_positions()
			var s: float = pv._scale()
			var flipped: bool = pv.period != period
			period = pv.period
			if not prev_tok.is_empty():
				for i in range(d.tokens.size()):
					tok_most = maxf(tok_most, (d.tokens[i]["pos"] as Vector2).distance_to(prev_tok[i]))
					if not flipped:
						draw_most = maxf(draw_most, drawn[i].distance_to(prev_draw[i]) / s)
			prev_tok = []
			for t in d.tokens:
				prev_tok.append(t["pos"])
			prev_draw = drawn.duplicate()
			frames += 1
			if speed > 1.0 or d.mode == "break":
				continue
			var b: Vector2 = d.ball["pos"]
			var stop := d._stoppage_on()
			var setting := d._pi < d._phases.size() and str((d._phases[d._pi] as Dictionary).get("t", "")) in ["setup", "wait"]
			var ph := str((d._phases[d._pi] as Dictionary).get("t", "")) if d._pi < d._phases.size() else ""
			if ph in ["pack", "throwup", "bounce"]:
				# Win contest: no more than six of its discs within 6 m of the
				# ball while the pack forms and the ball goes up.
				var world := _drawn_world(pv, drawn)
				for side in range(2):
					if d._plan_of(side) != "contest":
						continue
					var near := 0
					for i in range(world.size()):
						if int(sides[i]) == side and (world[i] as Vector2).distance_to(b) < 6.0:
							near += 1
					pack_most = maxi(pack_most, near)
					pack_n += 1
			if guard % 4 == 0:
				var order := pv.draw_order()
				var tr := pv.token_radius()
				for side in range(2):
					var vs := visible_share(drawn, sides, side, order, tr)
					vis_min[side] = minf(float(vis_min[side]), vs)
					vis_n += 1
					if vs < VISIBLE_FLOOR:
						vis_low += 1
			if guard % 10 != 0 or setting:
				continue
			# The structure as the director sets it now: the spots, the limits.
			for side in range(2):
				var spots := {}
				for t in d.tokens:
					if int(t["side"]) == side and not d._busy.has(int(t["id"])):
						spots[int(t["id"])] = d._structure_spot(t, d._struct_ball, d._poss)
				d._structure_limits(side, spots, d._struct_ball, stop)
				var lines := {"DEF": [], "MID": [], "FWD": []}
				for id in spots:
					var p: Vector2 = spots[id]
					inside = minf(inside, _inside_by(p))
					for rc in rects:
						if (rc as Rect2).has_point(pv._w2s(p)):
							under += 1
					var role := str(d.tokens[id]["role"])
					(lines["MID" if role == "RUCK" else role] as Array).append(p.y)
				if side == d._poss and not stop:
					for key in lines:
						if (lines[key] as Array).size() >= 3:
							narrow = minf(narrow, _sd(lines[key]))
							narrow_n += 1
		var tag := "%dx" % int(speed)
		_check(not pv.playing and tok_most <= MatchMotion.SPRINT * h * 1.001,
				"%s: no player moves faster than a sprint in any frame (largest %.2f m in a %.3f s frame, %.1f m/s; the cap is %.0f)" % [
				tag, tok_most, h, tok_most / h, MatchMotion.SPRINT])
		_check(draw_most <= (MatchMotion.SPRINT + MatchMotion.WALK) * h * 1.001,
				"%s: no disc is drawn moving faster than a sprint plus the walking draw-apart, so none snaps (largest %.2f m in a frame, %.1f m/s; the cap is %.1f)" % [
				tag, draw_most, draw_most / h, MatchMotion.SPRINT + MatchMotion.WALK])
		print("  motion %s: %d frames, largest player step %.2f m (%.1f m/s), largest disc step %.2f m (%.1f m/s)" % [
				tag, frames, tok_most, tok_most / h, draw_most, draw_most / h])
		if speed == 1.0:
			_check(vis_n > 1000 and vis_low * 100 <= vis_n and float(vis_min[0]) >= VISIBLE_WORST and float(vis_min[1]) >= VISIBLE_WORST,
					"1x: at least %.0f%% of each side's disc area shows in 99 frames in 100 (%d of %d below), and %.0f%% in every frame (Fremantle %.0f%%, Melbourne %.0f%% at worst)" % [
					100.0 * VISIBLE_FLOOR, vis_low, vis_n, 100.0 * VISIBLE_WORST, 100.0 * float(vis_min[0]), 100.0 * float(vis_min[1])])
			_check(narrow_n > 50 and narrow >= MatchDirector.LINE_WIDTH_MIN - 0.01,
					"1x: in possession each line keeps at least %.0f m of spread across the ground (narrowest %.1f m over %d lines)" % [
					MatchDirector.LINE_WIDTH_MIN, narrow, narrow_n])
			_check(inside >= MatchDirector.STRUCT_MARGIN - 0.01 and under == 0,
					"1x: every structure spot is at least %.0f m inside the boundary line (closest %.1f m) and none under the phone's bench strip (%d)" % [
					MatchDirector.STRUCT_MARGIN, inside, under])
			_check(pack_n > 20 and pack_most <= 6,
					"1x: while a Win contest side's stoppage pack forms and the ball goes up, no more than six of its discs are within 6 m of the ball (%d at most over %d frames)" % [pack_most, pack_n])
			print("  motion 1x: visible at worst %.2f / %.2f (%d of %d samples below %.2f), narrowest line %.1f m, closest to the line %.1f m, contest pack %d" % [
					float(vis_min[0]), float(vis_min[1]), vis_low, vis_n, VISIBLE_FLOOR, narrow, inside, pack_most])
		pv.free()


## P-12 visibility floor, measured as the motion critic measures the clips: on
## the phone's oval, from the discs as drawn, Fremantle (side 0) on each call
## against the same events with Fremantle on Balanced, over the frames where the
## call applies. Depth calls are read relative to the ball and to Melbourne:
## the side's centroid and its median player, up the ground.
func _test_call_visibility(res: Dictionary) -> void:
	var with_call := func(plan: String, bursts: Array) -> Dictionary:
		var r2 := res.duplicate()
		r2["events"] = (res["events"] as Array).slice(0, 260)
		var tl := []
		for e in res["timeline"]:
			var e2: Dictionary = (e as Dictionary).duplicate(true)
			if int(e2["side"]) == 0:
				e2["plan"] = plan
				e2["bursts"] = bursts
			tl.append(e2)
		r2["timeline"] = tl
		return r2
	var bal: Dictionary = _shape_of(with_call.call("balanced", []))
	# [call, plan, bursts, measure, the sign a real shape moves it by]
	var cases := [["Attack corridor (in possession, spread across)", "attacking", [], "has.spread", -1.0],
			["Controlled tempo (in possession, front to back)", "controlled", [], "has.span", -1.0],
			["Win contest (at a stoppage, the median player from the ball)", "contest", [], "stop.med_rad", -1.0],
			["Through stars (in possession, toward the star nearest the carrier)", "through_stars", [], "has.tilt", 1.0],
			["Throw numbers at it (in possession, centroid up the ground from the ball)", "balanced", ["surge"], "has.cen_ball", 1.0],
			["Throw numbers at it (in possession, median player from the ball)", "balanced", ["surge"], "has.med_ball", 1.0],
			["Throw numbers at it (in possession, centroid from Melbourne's)", "balanced", ["surge"], "has.cen_opp", 1.0],
			["Slow it down (in possession, centroid from the ball)", "balanced", ["hold"], "has.cen_ball", -1.0],
			["Slow it down (in possession, median player from the ball)", "balanced", ["hold"], "has.med_ball", -1.0],
			["Slow it down (in possession, centroid from Melbourne's)", "balanced", ["hold"], "has.cen_opp", -1.0],
			["Slow it down (without the ball, centroid from the ball)", "balanced", ["hold"], "not.cen_ball", -1.0],
			["Slow it down (without the ball, median player from the ball)", "balanced", ["hold"], "not.med_ball", -1.0],
			["Slow it down (without the ball, centroid from Melbourne's)", "balanced", ["hold"], "not.cen_opp", -1.0]]
	var said := []
	var done := {}
	for c in cases:
		var key := "%s|%s" % [str(c[1]), str(c[2])]
		if not done.has(key):
			done[key] = _shape_of(with_call.call(str(c[1]), c[2]))
		var m: Dictionary = done[key]
		var what := str(c[3])
		var moved := (float(m.get(what, 0.0)) - float(bal.get(what, 0.0))) * float(c[4])
		said.append("%s %.1f m" % [str(c[0]), moved])
		_check(moved >= CALL_FLOOR, "%s moves Fremantle %.1f m from Balanced (%.1f against %.1f), at least %.0f m" % [
				str(c[0]), moved, float(m.get(what, 0.0)), float(bal.get(what, 0.0)), CALL_FLOOR])
	print("  calls against Balanced, as drawn: " + ", ".join(said))
	# The floor is a real measure: with the shapes off (capture --noshape), a
	# call measures as Balanced.
	MatchDirector.debug_no_press_shape = true
	var off: Dictionary = _shape_of(with_call.call("balanced", ["surge"]), 120)
	var off_bal: Dictionary = _shape_of(with_call.call("balanced", []), 120)
	MatchDirector.debug_no_press_shape = false
	_check(absf(float(off.get("has.cen_ball", 0.0)) - float(off_bal.get("has.cen_ball", 0.0))) < 0.5,
			"With the shapes off (capture --noshape), Throw numbers at it measures as Balanced (%.1f against %.1f)" % [
				float(off.get("has.cen_ball", 0.0)), float(off_bal.get("has.cen_ball", 0.0))])


## Fremantle's shape from the drawn discs, averaged over the frames of each kind:
## "has" (in possession, open play), "not" (without it) and "stop" (a stoppage
## from the throw-up on, and the clearance out of it).
func _shape_of(r: Dictionary, events := -1) -> Dictionary:
	if events > 0:
		r = r.duplicate()
		r["events"] = (r["events"] as Array).slice(0, events)
	var pv := _phone(r, 1.0)
	var d: MatchDirector = pv.director
	var acc := {}
	var guard := 0
	while pv.playing and guard < 100000:
		guard += 1
		pv._process(FRAME * 2.0)
		var drawn := pv.disc_positions()
		if d.mode == "break":
			continue
		var stop := d._stoppage_on()
		if stop and d._pi < d._phases.size() and str((d._phases[d._pi] as Dictionary).get("t", "")) in ["setup", "wait"]:
			continue   # 6-6-6: nobody may crash in before the ball is up
		var world := _drawn_world(pv, drawn)
		var b: Vector2 = d.ball["pos"]
		var xs := []
		var ys := []
		var rads := []
		var opp := 0.0
		for i in range(world.size()):
			var p: Vector2 = world[i]
			if int(d.tokens[i]["side"]) == 1:
				opp += p.x / 18.0
				continue
			xs.append(p.x)
			ys.append(p.y)
			rads.append(p.distance_to(b))
		var c := Vector2.ZERO
		for k in range(xs.size()):
			c += Vector2(float(xs[k]), float(ys[k])) / float(xs.size())
		var span := 0.0
		for x in xs:
			span += absf(float(x) - c.x) / float(xs.size())
		var tag := "stop" if stop else ("has" if d._poss == 0 else "not")
		var m := {"cen_ball": c.x - b.x, "med_ball": _median(xs) - b.x, "cen_opp": c.x - opp,
				"spread": _sd(ys), "span": span, "tilt": c.y * signf(float(d._star_y[0])),
				"med_rad": _median(rads)}
		for k in m:
			var key: String = tag + "." + k
			if not acc.has(key):
				acc[key] = [0.0, 0]
			acc[key][0] += float(m[k])
			acc[key][1] += 1
	pv.free()
	var out := {}
	for key in acc:
		out[key] = float(acc[key][0]) / maxf(1.0, float(acc[key][1]))
	return out
