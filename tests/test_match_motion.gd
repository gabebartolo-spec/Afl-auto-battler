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
## A column (the critic's Attack corridor pile, pass 3): three or more of a
## side's discs within COLUMN_ACROSS of each other across the ground, each
## within COLUMN_ALONG of the next along it (a disc on a phone is 8.6 m across).
const COLUMN_ACROSS := 4.0
const COLUMN_ALONG := 9.0
## Heavily overlapping: centres within this many radii (a quarter of a disc covered).
const HEAVY := 1.5
## Attack corridor's spread across the ground in possession, on average (Balanced
## 18-19 m), and ATTACK_SPREAD_FLOOR in 98 frames in 100: it never collapses.
const ATTACK_SPREAD_FLOOR := 9.0
const ATTACK_SPREAD_LO := 10.0
const ATTACK_SPREAD_HI := 11.0
## Balanced is the bar for crowding (lead, 2026-10-18), measured in the same run:
## the corridor is 45% narrower, so it may have this much more heavy overlap and
## this many more points of file-of-three frames, and no longer a file. The rest
## is the leads and the carrier, common to every call (follow-up).
const CROWD_HEAVY_SHARE := 1.3
const CROWD_FILE_POINTS := 0.02
## Win contest in open play: the side's median player at least this much nearer
## the ball than on Balanced.
const CONTEST_NEARER := 8.0
## The pack at a Win contest ball-up: the four on the ball and its ring
## (MatchDirector.PACK_RING), out to a disc's radius past it.
const PACK_AREA := 9.0
## ...and the four on the ball: inside 3 m (MatchDirector.PACK_SECOND), settling.
const ON_BALL := 3.5


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	GameDB.reload()
	var res := _result(42)
	var t0 := Time.get_ticks_msec()
	_test_measures_prove_themselves(res)
	_test_motion_limits(res)
	var t1 := Time.get_ticks_msec()
	_test_call_visibility(res)
	print("  timing: motion limits %.1f s, calls %.1f s" % [(t1 - t0) / 1000.0, (Time.get_ticks_msec() - t1) / 1000.0])
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
		var lane_gap := INF
		var lane_n := 0
		var inside := INF
		var under := 0
		var pack_most := 0
		var pack_n := 0
		var inner_most := 0
		var inner_side_most := 0
		var pack_gap := INF
		var prev_rank := {}
		var prev_order := []
		var prev_carrier := -2
		var swaps := 0
		var swaps_hands := 0
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
			# Draw order: two overlapping discs never change places unless one has
			# passed the other on screen by more than a disc's radius, or the
			# ball has changed hands (the carrier is drawn on top).
			var order_now: Array = pv.draw_order()
			var rank := {}
			for k2 in range(order_now.size()):
				rank[int(order_now[k2])] = k2
			var carrier: int = pv.top_disc()
			var tr0: float = pv.token_radius()
			if not prev_rank.is_empty() and not flipped and order_now != prev_order:
				for i in range(drawn.size()):
					for j in range(i + 1, drawn.size()):
						if drawn[i].distance_to(drawn[j]) >= 2.0 * tr0:
							continue
						if (int(rank[i]) > int(rank[j])) == (int(prev_rank[i]) > int(prev_rank[j])):
							continue
						if carrier != prev_carrier and (i == carrier or j == carrier or i == prev_carrier or j == prev_carrier):
							swaps_hands += 1
							continue
						# On top now: the one lower on screen, by more than a radius.
						var top_i := int(rank[i]) > int(rank[j])
						var dy := drawn[i].y - drawn[j].y
						if (dy if top_i else -dy) <= tr0:
							swaps += 1
			prev_rank = rank
			prev_order = order_now
			prev_carrier = carrier
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
				if ph == "throwup" and (d._plan_of(0) == "contest" or d._plan_of(1) == "contest"):
					# Win contest's ball-up is a ring, not a stack: two a side at
					# most on the ball, and no two of a side on top of each other.
					var inner := 0
					var per := [0, 0]
					for i in range(world.size()):
						if (world[i] as Vector2).distance_to(b) < 3.0:
							inner += 1
							per[int(sides[i])] += 1
						if (world[i] as Vector2).distance_to(b) > PACK_AREA:
							continue
						for j in range(i + 1, world.size()):
							if int(sides[j]) != int(sides[i]) or (world[j] as Vector2).distance_to(b) > PACK_AREA:
								continue
							# A pair with one of the four on the ball in it (inside
							# 3 m, where every disc overlaps on a phone and the
							# draw-apart pushes them out over the ring) is held as
							# players; the ring and everyone else as drawn.
							var pi: Vector2 = d.tokens[i]["pos"]
							var pj: Vector2 = d.tokens[j]["pos"]
							if pi.distance_to(b) < ON_BALL or pj.distance_to(b) < ON_BALL:
								pack_gap = minf(pack_gap, pi.distance_to(pj))
							else:
								pack_gap = minf(pack_gap, (world[i] as Vector2).distance_to(world[j]))
					inner_most = maxi(inner_most, inner)
					inner_side_most = maxi(inner_side_most, maxi(per[0], per[1]))
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
				if side == d._poss and not stop and d._plan_of(side) == "attacking":
					# Attack corridor: its lines of three in their lanes, no two of
					# a line closer than LANE_GAP across (the 12 m floor gives way).
					var threes := {}
					for id in spots:
						var key3 := str(MatchDirector.LANE_LINE.get(str(d.tokens[id]["slot"]), "X"))
						if not threes.has(key3):
							threes[key3] = []
						(threes[key3] as Array).append((spots[id] as Vector2).y)
					for key3 in threes:
						var ys3: Array = threes[key3]
						ys3.sort()
						for q in range(1, ys3.size()):
							lane_gap = minf(lane_gap, float(ys3[q]) - float(ys3[q - 1]))
							lane_n += 1
				elif side == d._poss and not stop:
					for key in lines:
						if (lines[key] as Array).size() >= 3:
							narrow = minf(narrow, _sd(lines[key]))
							narrow_n += 1
		var tag := "%dx" % int(speed)
		_check(frames > 1000 and swaps == 0,
				"%s: two overlapping discs never change places in the draw order unless one passes the other on screen by more than a disc's radius (%d swaps; %d more as the ball changed hands, the carrier drawn on top)" % [
				tag, swaps, swaps_hands])
		print("  draw order %s: %d swaps, %d as the ball changed hands" % [tag, swaps, swaps_hands])
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
					"1x: in possession each line keeps at least %.0f m of spread across the ground, every call but Attack corridor (narrowest %.1f m over %d lines)" % [
					MatchDirector.LINE_WIDTH_MIN, narrow, narrow_n])
			_check(lane_n > 50 and lane_gap >= MatchDirector.LANE_GAP - 0.01,
					"1x: Attack corridor in possession: no two of a line of three closer than %.0f m across the ground (closest %.1f m over %d gaps)" % [
					MatchDirector.LANE_GAP, lane_gap, lane_n])
			_check(inside >= MatchDirector.STRUCT_MARGIN - 0.01 and under == 0,
					"1x: every structure spot is at least %.0f m inside the boundary line (closest %.1f m) and none under the phone's bench strip (%d)" % [
					MatchDirector.STRUCT_MARGIN, inside, under])
			_check(pack_n > 20 and pack_most <= 6,
					"1x: while a Win contest side's stoppage pack forms and the ball goes up, no more than six of its discs are within 6 m of the ball (%d at most over %d frames)" % [pack_most, pack_n])
			_check(pack_n > 20 and inner_most <= 4 and inner_side_most <= 2 and pack_gap >= 2.5,
					"1x: a Win contest ball-up is a ring as the ball goes up: at most four discs within 3 m of the ball (%d), two a side (%d), and no two of a side within 2.5 m of each other in the pack, 9 m round it (closest %.1f m; a pair with one of the four on the ball as players, the rest as drawn)" % [
					inner_most, inner_side_most, pack_gap])
			print("  ball-up ring 1x: within 3 m %d (a side %d), closest pair of a side %.1f m" % [inner_most, inner_side_most, pack_gap])
			print("  motion 1x: visible at worst %.2f / %.2f (%d of %d samples below %.2f), narrowest line %.1f m, corridor lane gap %.1f m, closest to the line %.1f m, contest pack %d" % [
					float(vis_min[0]), float(vis_min[1]), vis_low, vis_n, VISIBLE_FLOOR, narrow, lane_gap, inside, pack_most])
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
	var bal: Dictionary = _shape_of(with_call.call("balanced", []), -1, true)
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
			done[key] = _shape_of(with_call.call(str(c[1]), c[2]), -1, key == "attacking|[]")
		var m: Dictionary = done[key]
		var what := str(c[3])
		var moved := (float(m.get(what, 0.0)) - float(bal.get(what, 0.0))) * float(c[4])
		said.append("%s %.1f m" % [str(c[0]), moved])
		_check(moved >= CALL_FLOOR, "%s moves Fremantle %.1f m from Balanced (%.1f against %.1f), at least %.0f m" % [
				str(c[0]), moved, float(m.get(what, 0.0)), float(bal.get(what, 0.0)), CALL_FLOOR])
	print("  calls against Balanced, as drawn: " + ", ".join(said))
	# Pass 4 (the motion critic's third look): Attack corridor is a narrower
	# whole team, not a pile on the ball; Win contest puts numbers round the ball.
	var att: Dictionary = done["attacking|[]"]
	var con: Dictionary = done["contest|[]"]
	var a_sp := float(att.get("open.spread.mean", 0.0))
	var b_sp := float(bal.get("open.spread.mean", 0.0))
	_check(a_sp >= ATTACK_SPREAD_LO and a_sp <= ATTACK_SPREAD_HI,
			"Attack corridor: in possession Fremantle spreads %.0f to %.0f m across the ground on average (%.1f m; Balanced %.1f m)" % [
			ATTACK_SPREAD_LO, ATTACK_SPREAD_HI, a_sp, b_sp])
	_check(float(att.get("open.spread.p02", 0.0)) >= ATTACK_SPREAD_FLOOR,
			"Attack corridor: the corridor never collapses, at least %.0f m of spread in 98 possession frames in 100 (%.1f m at the 2nd percentile; Balanced %.1f m)" % [
			ATTACK_SPREAD_FLOOR, float(att.get("open.spread.p02", 0.0)), float(bal.get("open.spread.p02", 0.0))])
	# Balanced is the bar (lead, 2026-10-18): the corridor is never more crowded
	# than Balanced on the same events, measured in the same run.
	var a_heavy := float(att.get("has.heavy", 0.0))
	var b_heavy := float(bal.get("has.heavy", 0.0))
	_check(a_heavy <= b_heavy * CROWD_HEAVY_SHARE,
			"Attack corridor: heavily overlapping discs at most %.0f%% of Balanced's in possession (Fremantle's pairs with centres within %.1f radii: %.2f a frame against %.2f)" % [
			100.0 * CROWD_HEAVY_SHARE, HEAVY, a_heavy, b_heavy])
	_check(int(att.get("has.file", 9)) <= int(bal.get("has.file", 0)),
			"Attack corridor: no file of Fremantle's discs longer than Balanced's longest in possession (%d at most; Balanced %d)" % [
			int(att.get("has.file", 9)), int(bal.get("has.file", 0))])
	var a_f3 := float(att.get("has.file3", 1.0))
	var b_f3 := float(bal.get("has.file3", 0.0))
	_check(a_f3 <= b_f3 + CROWD_FILE_POINTS,
			"Attack corridor: a file of three in at most %.0f points more possession frames than Balanced (%.1f%% against %.1f%%)" % [
			100.0 * CROWD_FILE_POINTS, 100.0 * a_f3, 100.0 * b_f3])
	var nearer := float(bal.get("open.med_rad.mean", 0.0)) - float(con.get("open.med_rad.mean", 0.0))
	var nearer75 := float(bal.get("open.med_rad.p75", 0.0)) - float(con.get("open.med_rad.p75", 0.0))
	_check(nearer >= CONTEST_NEARER and nearer75 >= CONTEST_NEARER,
			"Win contest: in open play Fremantle's median player stands at least %.0f m nearer the ball than on Balanced (%.1f m nearer on average, %.1f against %.1f; %.1f m at the 75th percentile)" % [
			CONTEST_NEARER, nearer, float(con.get("open.med_rad.mean", 0.0)), float(bal.get("open.med_rad.mean", 0.0)), nearer75])
	print("  attack corridor against Balanced: spread %.1f m (%.1f), 2nd percentile %.1f m (%.1f), heavy overlaps %.2f a frame (%.2f), any overlap %.2f (%.2f), longest file %d (%d), file-of-three frames %.1f%% (%.1f%%)" % [
			a_sp, b_sp, float(att.get("open.spread.p02", 0.0)), float(bal.get("open.spread.p02", 0.0)), a_heavy, b_heavy,
			float(att.get("has.touch", 0.0)), float(bal.get("has.touch", 0.0)), int(att.get("has.file", 9)), int(bal.get("has.file", 9)),
			100.0 * a_f3, 100.0 * b_f3])
	print("  win contest open play: median from the ball %.1f m (Balanced %.1f), 75th percentile %.1f (%.1f)" % [
			float(con.get("open.med_rad.mean", 0.0)), float(bal.get("open.med_rad.mean", 0.0)),
			float(con.get("open.med_rad.p75", 0.0)), float(bal.get("open.med_rad.p75", 0.0))])
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
func _shape_of(r: Dictionary, events := -1, crowd := false) -> Dictionary:
	if events > 0:
		r = r.duplicate()
		r["events"] = (r["events"] as Array).slice(0, events)
	var pv := _phone(r, 1.0)
	var d: MatchDirector = pv.director
	var acc := {}
	var most := {}
	var frames := {}
	var guard := 0
	while pv.playing and guard < 100000:
		guard += 1
		# 15 frames a second where crowding is counted, 10 for the averages.
		pv._process(FRAME * (2.0 if crowd else 3.0))
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
		if crowd:
			# How crowded Fremantle's discs are as drawn: pairs overlapping at
			# all (closer than a disc across) and heavily (centres within
			# HEAVY radii, a quarter of the disc covered), and its longest file.
			var tr: float = pv.token_radius()
			var touch := 0
			var heavy := 0
			var own := []
			for i in range(drawn.size()):
				if int(d.tokens[i]["side"]) != 0:
					continue
				own.append(world[i])
				for j in range(i + 1, drawn.size()):
					if int(d.tokens[j]["side"]) != 0:
						continue
					var dd := drawn[i].distance_to(drawn[j])
					if dd < 2.0 * tr:
						touch += 1
					if dd < HEAVY * tr:
						heavy += 1
			var file := file_length(own, COLUMN_ACROSS, COLUMN_ALONG)
			m["touch"] = touch
			m["heavy"] = heavy
			m["file3"] = 1.0 if file >= 3 else 0.0
			most[tag + ".file"] = maxi(int(most.get(tag + ".file", 0)), file)
		for k in m:
			var key: String = tag + "." + k
			if not acc.has(key):
				acc[key] = [0.0, 0]
			acc[key][0] += float(m[k])
			acc[key][1] += 1
		if not stop:
			if not frames.has("open.med_rad"):
				frames["open.med_rad"] = []
				frames["open.spread"] = []
			(frames["open.med_rad"] as Array).append(_median(rads))
			if d._poss == 0:
				(frames["open.spread"] as Array).append(_sd(ys))
	pv.free()
	var out := {}
	for key in acc:
		out[key] = float(acc[key][0]) / maxf(1.0, float(acc[key][1]))
	for key in most:
		out[key] = most[key]
	for key in frames:
		var v: Array = frames[key]
		var mean := 0.0
		for x in v:
			mean += float(x) / float(v.size())
		out[key + ".mean"] = mean
		out[key + ".p75"] = _quantile(v, 0.75)
		out[key + ".p25"] = _quantile(v, 0.25)
		out[key + ".p02"] = _quantile(v, 0.02)
	return out


static func _quantile(v: Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	var c := v.duplicate()
	c.sort()
	return float(c[clampi(int(round(q * float(c.size() - 1))), 0, c.size() - 1)])


## The longest single file among `pts` (metres on the ground): discs within
## `across` of each other across the ground, each within `along` of the next up
## it. Three or more in one file is the column the motion critic saw.
static func file_length(pts: Array, across: float, along: float) -> int:
	var best := mini(1, pts.size())
	for a in pts:
		var lane := []
		for p in pts:
			var dy: float = (p as Vector2).y - (a as Vector2).y
			if dy >= 0.0 and dy <= across:
				lane.append((p as Vector2).x)
		lane.sort()
		var run := 1
		for k in range(1, lane.size()):
			run = run + 1 if float(lane[k]) - float(lane[k - 1]) <= along else 1
			best = maxi(best, run)
	return best
