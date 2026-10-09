class_name VignetteGround
extends RefCounted
## The football ground the vignettes play on, built to the AFL's dimensions and seen
## through each scene's camera (Cam), so every painted line, post and stand sits where it
## would on a real ground and holds its shape as the camera zooms and pans:
##   - the oval, 160 m long and 136 m wide, its boundary line painted round it;
##   - the goal posts on the boundary at each end: goal posts 6.4 m apart, behind posts
##     6.4 m outside them, the goal line between the behind posts, the goal square
##     6.4 m by 9 m in front, the 50 m arc from the middle of the goal line;
##   - the centre square, 50 m by 50 m, and the centre circle, 10 m across with a 3 m
##     circle inside, divided by a line across the ground;
##   - painted lines 10 cm wide (never thinner than a pixel), mown stripes across the
##     oval, the apron outside the boundary, the fence with its boards and the stands
##     rising behind it, full of both clubs' people.
## Oval coordinates: metres from the centre of the ground, x across it (wing to wing),
## y along it towards the end a scene attacks (its goal line at +GOAL_Y).
## Everything is drawn as triangles in a couple of calls, for phones.

const A := 68.0                   # half the oval's width
const L := 80.0                   # half its length
const GOAL_GAP := 6.4             # between the goal posts, and from each to its behind post
## The goal posts tower; the behind posts are clearly shorter (director), so even when a
## close shot cuts off the goal posts' tops, the behinds' stand inside it.
const GOAL_H := 12.0
const BEHIND_H := 6.5
const POST_W := 0.35
const PAD_H := 2.8                # the padding round the foot of each post
const PAD_W := 0.75
const SQUARE_DEPTH := 9.0         # the goal square
const ARC := 50.0
const CENTRE_SQUARE := 50.0
const CIRCLE_R := 5.0
const INNER_R := 1.5
const LINE_W := 0.1
## The fence stands this far outside the boundary; the stand rises behind it.
const FENCE := 6.0
const FENCE_H := 1.2
const STAND_DEPTH := 34.0
const STAND_RISE := 24.0
## One copy of the crowd texture covers this much of the stand, along it.
const CROWD_TILE := 30.0
const NEAR := 0.6                 # metres in front of the camera: nearer is clipped
const SKY := Color(0.025, 0.03, 0.035)
const GRASS := [Color(0.16, 0.39, 0.17), Color(0.18, 0.43, 0.19)]
const APRON := Color(0.13, 0.32, 0.14)
const PAINT := Color(0.97, 0.97, 0.95, 0.92)
const WORN := [Color(0.26, 0.36, 0.17, 0.55), Color(0.38, 0.36, 0.22, 0.45)]

## The ground being shown, by its fixture name ("MCG"). A ground with its own treatment
## (FL-003) draws its landmarks; any other, or "", draws the plain ground.
static var venue := ""

## Where the goal line runs: the boundary at the behind posts.
static var GOAL_Y := L * sqrt(1.0 - pow(1.5 * GOAL_GAP / A, 2.0))


## A camera on the ground: standing at pos (scene metres), height up, looking along fwd
## with its lens level (so posts stay upright); f the focal length in pixels, cx the
## screen x it looks along, hor the horizon's screen y. to_scene maps oval coordinates
## into the scene's own (identity when the scene works in oval coordinates).
class Cam:
	var pos := Vector2.ZERO
	var height := 5.0
	var fwd := Vector2(0, 1)
	var f := 600.0
	var cx := 0.0
	var hor := 0.0
	var to_scene := Transform2D.IDENTITY

	## Across and away from the camera, metres, for a scene point.
	func local(p: Vector2) -> Vector2:
		var d := p - pos
		return Vector2(d.x * fwd.y - d.y * fwd.x, d.dot(fwd))

	## Screen point and pixels per metre there, for a local point h metres up.
	func screen(l: Vector2, h := 0.0) -> Vector3:
		var z := maxf(l.y, 0.001)
		return Vector3(cx + f * l.x / z, hor + f * (height - h) / z, f / z)

	## A scene point h metres up, to the screen (z: pixels per metre; <= 0 behind).
	func project(p: Vector2, h := 0.0) -> Vector3:
		var l := local(p)
		if l.y < NEAR:
			return Vector3(0, 0, -1)
		return screen(l, h)

	func oval(p: Vector2, h := 0.0) -> Vector3:
		return project(to_scene * p, h)


## A camera at pos, height up, looking at target (scene metres).
static func looking(pos: Vector2, height: float, target: Vector2, f: float, cx: float, hor: float) -> Cam:
	var c := Cam.new()
	c.pos = pos
	c.height = height
	c.fwd = (target - pos).normalized()
	c.f = f
	c.cx = cx
	c.hor = hor
	return c


## The whole ground: sky, stands, fence, apron, the oval and its stripes and markings.
## stage: the screen area to cover (the vignette's drawn stage); colours: both clubs'
## colour lists (the crowd, the boards). Goal posts are separate (draw_goals), so a
## scene can put them behind its players.
## board: the match's score for the big screen ({codes: [home, away], goals, behinds,
## q}); empty, the screen shows the clubs' colours only.
## weather: the day's (VignetteWeather; MatchSim.weather) and t the scene's time, for
## what moves with it (flags in the wind).
static func draw_ground(ci: CanvasItem, cam: Cam, stage: Rect2, colours: Array, seed := 7, board := {},
		weather := "", t := 0.0) -> void:
	ci.draw_rect(stage, SKY, true)
	_draw_stands(ci, cam, colours, seed, board, weather, t)
	var tri := Tris.new()
	_fence_and_apron(tri, cam, colours)
	# The oval and its mown stripes, across the ground every 12 m.
	var grass := VignetteWeather.grass(weather, GRASS)
	tri.poly(_clip(cam, _ellipse_ring(A, L, 0.0, 0.0, 180)), grass[0])
	var y := -L
	var n := 0
	while y < L:
		if n % 2 == 1:
			tri.poly(_clip(cam, _band(y, minf(y + 12.0, L))), grass[1])
		y += 12.0
		n += 1
	# Worn turf where the game is heaviest: the goal squares and the centre circle.
	for end in [-1.0, 1.0]:
		var gy: float = GOAL_Y * end
		tri.poly(_clip(cam, _ellipse_ring(4.2, 5.0, 0.0, gy - 3.5 * end, 24)), WORN[0])
		tri.poly(_clip(cam, _ellipse_ring(2.4, 2.8, 0.4, gy - 2.6 * end, 18)), WORN[1])
	tri.poly(_clip(cam, _ellipse_ring(4.0, 3.2, 0.0, 0.0, 24)), WORN[0])
	tri.poly(_clip(cam, _ellipse_ring(1.8, 1.4, 0.3, -0.2, 16)), WORN[1])
	_markings(tri, cam)
	tri.flush(ci)
	if weather == VignetteWeather.WET:
		VignetteWeather.draw_sheen(ci, cam, _tower_spots(), A, L)
	elif weather == VignetteWeather.WINDY:
		VignetteWeather.draw_wind(ci, cam, t)


## The goal posts at one end (end: +1 the far end of oval y, -1 the other), padded
## in pad_colour, nearer posts drawn over farther ones.
static func draw_goals(ci: CanvasItem, cam: Cam, end := 1, pad_colour := Color(0.75, 0.75, 0.78)) -> void:
	_photographers(ci, cam, end)
	var posts := []
	for i in [-1.5, -0.5, 0.5, 1.5]:
		var at := Vector2(i * GOAL_GAP, GOAL_Y * end)
		posts.append([cam.local(cam.to_scene * at).y, at, GOAL_H if absf(i) < 1.0 else BEHIND_H])
	posts.sort_custom(func(a, b): return a[0] > b[0])
	for p in posts:
		var base := cam.oval(p[1])
		if base.z <= 0.0:
			continue
		var top := cam.oval(p[1], p[2])
		var w := maxf(1.5, POST_W * base.z)
		ci.draw_rect(Rect2(base.x - w * 0.5, top.y, w, base.y - top.y), Color(0.96, 0.96, 0.94), true)
		ci.draw_rect(Rect2(base.x - w * 0.5, top.y, w * 0.35, base.y - top.y), Color(1, 1, 1, 0.5), true)
		var pad := cam.oval(p[1], PAD_H)
		var pw := maxf(2.5, PAD_W * base.z)
		ci.draw_rect(Rect2(base.x - pw * 0.5, pad.y, pw, base.y - pad.y), pad_colour, true)
		ci.draw_rect(Rect2(base.x - pw * 0.5, pad.y, pw * 0.3, base.y - pad.y), Color(1, 1, 1, 0.18), true)


## The photographers on the apron behind the goals, either side of the posts: crouched,
## dark against the boards, long lenses pointing up the ground, a glint on the glass.
static func _photographers(ci: CanvasItem, cam: Cam, end: int) -> void:
	for x in [-22.0, -17.5, -14.0, 13.0, 16.5, 21.0, 25.0]:
		var p := Vector2(x, (GOAL_Y + 3.0 + absf(x) * 0.06) * end)
		var s := cam.oval(p)
		if s.z <= 0.0 or s.z < 1.5:
			continue
		var u := s.z
		var at := Vector2(s.x, s.y)
		var body := Color(0.08, 0.08, 0.1)
		ci.draw_rect(Rect2(at + Vector2(-0.3, -0.95) * u, Vector2(0.6, 0.95) * u), body, true)      # crouched
		ci.draw_circle(at + Vector2(0.0, -1.12) * u, 0.17 * u, Color(0.25, 0.2, 0.17))            # head
		ci.draw_rect(Rect2(at + Vector2(-0.45, -1.12) * u, Vector2(0.45, 0.16) * u), Color(0.12, 0.12, 0.13), true)   # lens
		ci.draw_circle(at + Vector2(-0.45, -1.04) * u, maxf(0.6, 0.05 * u), Color(0.75, 0.82, 0.95, 0.8))


## The middle of the goal mouth at one end, h metres up (where a goal goes through).
static func goal_mouth(end := 1, h := 0.0) -> Vector3:
	return Vector3(0.0, GOAL_Y * end, h)


# ---------------------------------------------------------------------------
# Pieces
# ---------------------------------------------------------------------------
static func _markings(tri: Tris, cam: Cam) -> void:
	_line(tri, cam, _ellipse_ring(A, L, 0.0, 0.0, 360), true)                      # the boundary
	for end: float in [-1.0, 1.0]:
		var gy: float = GOAL_Y * end
		_line(tri, cam, [Vector2(-1.5 * GOAL_GAP, gy), Vector2(1.5 * GOAL_GAP, gy)], false)     # goal line
		var sq: float = gy - SQUARE_DEPTH * end
		_line(tri, cam, [Vector2(-0.5 * GOAL_GAP, gy), Vector2(-0.5 * GOAL_GAP, sq),
				Vector2(0.5 * GOAL_GAP, sq), Vector2(0.5 * GOAL_GAP, gy)], false)              # goal square
		# The 50 m arc, from the middle of the goal line, inside the boundary.
		var arc := []
		for i in range(181):
			var a := PI * float(i) / 180.0
			var p := Vector2(cos(a) * ARC, gy - sin(a) * ARC * end)
			if pow(p.x / A, 2.0) + pow(p.y / L, 2.0) < 1.0:
				arc.append(p)
		_line(tri, cam, arc, false)
	var h := CENTRE_SQUARE * 0.5
	_line(tri, cam, [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)], true)
	_line(tri, cam, _ellipse_ring(CIRCLE_R, CIRCLE_R, 0.0, 0.0, 48), true)
	_line(tri, cam, _ellipse_ring(INNER_R, INNER_R, 0.0, 0.0, 24), true)
	_line(tri, cam, [Vector2(-CIRCLE_R, 0.0), Vector2(CIRCLE_R, 0.0)], false)


## A painted line through oval points, 10 cm wide on the ground: each piece as wide on
## screen as that width really looks from the camera, and never thinner than a pixel
## (fainter instead).
static func _line(tri: Tris, cam: Cam, pts: Array, closed: bool) -> void:
	var n := pts.size()
	var segs := n if closed else n - 1
	for i in range(segs):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		# Long straights in short pieces, so perspective bends nothing.
		var pieces := maxi(1, int(a.distance_to(b) / 2.0))
		for k in range(pieces):
			_segment(tri, cam, a.lerp(b, float(k) / pieces), a.lerp(b, float(k + 1) / pieces))


static func _segment(tri: Tris, cam: Cam, a: Vector2, b: Vector2) -> void:
	var la := cam.local(cam.to_scene * a)
	var lb := cam.local(cam.to_scene * b)
	if la.y < NEAR and lb.y < NEAR:
		return
	# Clip at the near plane.
	if la.y < NEAR:
		var t := (NEAR - la.y) / (lb.y - la.y)
		a = a.lerp(b, t)
		la = la.lerp(lb, t)
	elif lb.y < NEAR:
		var t := (NEAR - lb.y) / (la.y - lb.y)
		b = b.lerp(a, t)
		lb = lb.lerp(la, t)
	var sa := cam.screen(la)
	var sb := cam.screen(lb)
	var d := Vector2(sb.x - sa.x, sb.y - sa.y)
	if d.length() < 0.01:
		return
	var ns := Vector2(-d.y, d.x).normalized()
	# The line's true width on screen: its two edges, projected.
	var dir := (b - a).normalized()
	var nw := cam.to_scene.basis_xform(Vector2(-dir.y, dir.x)) * (LINE_W * 0.5)
	var mid := cam.to_scene * a.lerp(b, 0.5)
	var e1 := cam.project(mid + nw)
	var e2 := cam.project(mid - nw)
	var width := absf(Vector2(e1.x - e2.x, e1.y - e2.y).dot(ns)) if e1.z > 0.0 and e2.z > 0.0 else 1.0
	var col := PAINT
	col.a *= clampf(width, 0.35, 1.0)
	var hw := maxf(width, 1.0) * 0.5
	var p1 := Vector2(sa.x, sa.y)
	var p2 := Vector2(sb.x, sb.y)
	tri.poly([p1 + ns * hw, p2 + ns * hw, p2 - ns * hw, p1 - ns * hw], col)


## The apron between the boundary and the fence, and the fence's boards in the clubs'
## colours, panel by panel.
static func _fence_and_apron(tri: Tris, cam: Cam, colours: Array) -> void:
	var n := 180
	for i in range(n):
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var in0 := Vector2(cos(a0) * A, sin(a0) * L)
		var in1 := Vector2(cos(a1) * A, sin(a1) * L)
		var out0 := Vector2(cos(a0) * (A + FENCE), sin(a0) * (L + FENCE))
		var out1 := Vector2(cos(a1) * (A + FENCE), sin(a1) * (L + FENCE))
		# The apron runs on under the front of the stand, so no gap shows between them.
		var back0 := Vector2(cos(a0) * (A + FENCE + 3.0), sin(a0) * (L + FENCE + 3.0))
		var back1 := Vector2(cos(a1) * (A + FENCE + 3.0), sin(a1) * (L + FENCE + 3.0))
		tri.poly(_clip(cam, [in0, in1, back1, back0]), APRON)
		# The boards: an upright quad on the fence line.
		var c: Array = colours[(i / 3) % 2] if colours.size() > 1 else []
		var board: Color = (c[0] as Color).darkened(0.25) if not c.is_empty() else Color(0.2, 0.2, 0.22)
		var la := cam.local(cam.to_scene * out0)
		var lb := cam.local(cam.to_scene * out1)
		if la.y < NEAR or lb.y < NEAR:
			continue
		var b0 := cam.screen(la)
		var b1 := cam.screen(lb)
		var t0 := cam.screen(la, FENCE_H)
		var t1 := cam.screen(lb, FENCE_H)
		tri.poly([Vector2(b0.x, b0.y), Vector2(b1.x, b1.y), Vector2(t1.x, t1.y), Vector2(t0.x, t0.y)], board)
		tri.poly([Vector2(t0.x, t0.y), Vector2(t1.x, t1.y), Vector2(t1.x, t1.y + 1.0), Vector2(t0.x, t0.y + 1.0)],
				Color(1, 1, 1, 0.12))


## The stadium round the oval: two tiers of seats full of both clubs' people, a fascia
## between them in the clubs' colours, the roof's edge with its row of lights, the big
## screen above the far end, the light towers behind, and the haze the lights make.
static func _draw_stands(ci: CanvasItem, cam: Cam, colours: Array, seed: int, board: Dictionary,
		weather := "", t := 0.0) -> void:
	var mcg := venue == "MCG"
	# The MCG's empty seats are a pale blue-grey (Commons, "MCG Shane Warne Stand.png").
	var tex := VignetteCrowd.seats(colours, seed, MCG_SEAT if mcg else Color(0.07, 0.07, 0.085))
	if ci.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		ci.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_towers(ci, cam)
	var ring := _ring_columns(A + FENCE + 2.0, L + FENCE + 2.0, STAND_TILE / 16.0)
	# Tiers, front to back: [inner offset, outer offset, inner height, outer height] beyond
	# the fence line. The MCG rises in three, a band of boxes under each of the upper two.
	var tiers: Array = MCG_TIERS if mcg else [[2.0, 26.0, FENCE_H + 0.3, 13.0], [30.0, 52.0, 17.0, 34.0]]
	var lower: Array = tiers[0]
	var upper: Array = tiers[tiers.size() - 1]
	var shade := Tris.new()
	var lit := Tris.new()
	var c0: Color = (colours[0] as Array)[0] if colours.size() > 0 and not (colours[0] as Array).is_empty() else Color(0.3, 0.3, 0.32)
	var c1: Color = (colours[1] as Array)[0] if colours.size() > 1 and not (colours[1] as Array).is_empty() else c0
	for i in range(ring.size() - 1):
		var a0: float = ring[i][0]
		var a1: float = ring[i + 1][0]
		var panel: Color = (c0 if (i / 6) % 2 == 0 else c1).darkened(0.35)
		for k in range(1, tiers.size()):
			var below: Array = tiers[k - 1]
			var tier: Array = tiers[k]
			# The underside of the tier above and the concourse: dark, behind the fascia.
			_wall(shade, cam, a0, a1, below[1], below[1], below[3], tier[2] + 0.5, Color(0.045, 0.045, 0.055))
			# The fascia along the tier's front, panel by panel in the clubs' colours.
			_wall(lit, cam, a0, a1, tier[0], tier[0], tier[2] - 2.2, tier[2], panel)
			_wall(lit, cam, a0, a1, tier[0], tier[0], tier[2] - 0.25, tier[2], Color(1, 1, 1, 0.25))
		# The roof's edge over the top row, its lights along it.
		_wall(shade, cam, a0, a1, upper[1] - 4.0, upper[1], upper[3] + 1.0, upper[3] + 4.0, Color(0.06, 0.06, 0.07))
	shade.flush(ci)
	var tints := [Color(0.95, 0.95, 0.97), Color(0.86, 0.86, 0.9), Color(0.78, 0.78, 0.82)]
	for k in range(tiers.size()):
		_tier(ci, cam, ring, tiers[k], tex, tints[k] if tiers.size() == 3 else tints[k * 2])
	lit.flush(ci)
	if mcg:
		_mcg_trusses(ci, cam, ring, upper)
	# In the wind, the flags people hold up along the front rows stream out.
	if VignetteWeather.wind(weather) > 0.0:
		for i in range(1, ring.size(), 2):
			var a: float = ring[i][0]
			var off: float = lower[0] + 3.0 + float(i % 5) * 2.0
			var p := Vector2(cos(a) * (A + FENCE + 2.0 + off), sin(a) * (L + FENCE + 2.0 + off))
			var h: float = lower[2] + (off - lower[0]) * (lower[3] - lower[2]) / (lower[1] - lower[0]) + 1.6
			var s := cam.oval(p, h)
			if s.z <= 0.0:
				continue
			var home := (i / 2) % 2 == 0
			VignetteWeather.draw_flag(ci, Vector2(s.x, s.y), 2.4 * s.z, 2.4 * s.z, 1.5 * s.z,
					c0 if home else c1, t, float(i) * 1.3, 1.0, _second(colours, 0 if home else 1))
	# Lights under the roof's edge, every few metres.
	var lights := Tris.new()
	for i in range(0, ring.size(), 2):
		var a: float = ring[i][0]
		var p := Vector2(cos(a) * (A + FENCE + 2.0 + upper[1] - 2.0), sin(a) * (L + FENCE + 2.0 + upper[1] - 2.0))
		var s := cam.oval(p, upper[3] + 1.0)
		if s.z <= 0.0:
			continue
		var r := maxf(0.8, 0.35 * s.z)
		lights.poly([Vector2(s.x - r, s.y - r * 0.5), Vector2(s.x + r, s.y - r * 0.5),
				Vector2(s.x + r, s.y + r * 0.5), Vector2(s.x - r, s.y + r * 0.5)], Color(1.0, 0.97, 0.88, 0.9))
	lights.flush(ci)
	# In the wind, the flags along the roofs stream out in the clubs' colours.
	var wind := VignetteWeather.wind(weather)
	if wind > 0.0:
		for i in range(0, ring.size(), 9):
			var a: float = ring[i][0]
			var p := Vector2(cos(a) * (A + FENCE + 2.0 + upper[1] - 1.0), sin(a) * (L + FENCE + 2.0 + upper[1] - 1.0))
			var s := cam.oval(p, upper[3] + 4.0)
			if s.z <= 0.0:
				continue
			var home := (i / 9) % 2 == 0
			VignetteWeather.draw_flag(ci, Vector2(s.x, s.y), 7.0 * s.z, 5.0 * s.z, 2.6 * s.z,
					c0 if home else c1, t, float(i) * 0.7, wind, _second(colours, 0 if home else 1))
	_screen(ci, cam, c0, c1, board)
	if venue == "MCG":
		_screen(ci, cam, c0, c1, board, -1)
	_haze(ci, cam, weather)


const STAND_TILE := 35.0          # metres of stand per copy of the seats texture


## Columns round the stand ring at even steps along it: [angle, metres along].
static func _ring_columns(ax: float, ay: float, step: float) -> Array:
	var fine := 900
	var s := 0.0
	var prev := Vector2(ax, 0.0)
	var columns := [[0.0, 0.0]]
	var next := step
	for i in range(1, fine + 1):
		var a := TAU * float(i) / fine
		var p := Vector2(cos(a) * ax, sin(a) * ay)
		s += p.distance_to(prev)
		prev = p
		if s >= next:
			columns.append([a, next])
			next += step
	if float(columns[columns.size() - 1][0]) < TAU - 0.0001:
		columns.append([TAU, next])               # close the ring: no seam where it began
	return columns


## One tier of seats, raked from its front (inner offset, height) to its back, the seats
## texture laid along it.
static func _tier(ci: CanvasItem, cam: Cam, ring: Array, tier: Array, tex: Texture2D, tint: Color) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var base_a := A + FENCE + 2.0
	var base_l := L + FENCE + 2.0
	for i in range(ring.size() - 1):
		var a0: float = ring[i][0]
		var a1: float = ring[i + 1][0]
		var u0 := fposmod(float(ring[i][1]) / STAND_TILE, 1.0)
		var u1 := u0 + (float(ring[i + 1][1]) - float(ring[i][1])) / STAND_TILE
		var quad := [Vector3(cos(a0) * (base_a + tier[0]), sin(a0) * (base_l + tier[0]), tier[2]),
				Vector3(cos(a1) * (base_a + tier[0]), sin(a1) * (base_l + tier[0]), tier[2]),
				Vector3(cos(a1) * (base_a + tier[1]), sin(a1) * (base_l + tier[1]), tier[3]),
				Vector3(cos(a0) * (base_a + tier[1]), sin(a0) * (base_l + tier[1]), tier[3])]
		var uv := [Vector2(u0, 1.0), Vector2(u1, 1.0), Vector2(u1, 0.0), Vector2(u0, 0.0)]
		var ls := []
		for q in quad:
			var l := cam.local(cam.to_scene * Vector2(q.x, q.y))
			if l.y < NEAR:
				break
			ls.append(cam.screen(l, q.z))
		if ls.size() < 4:
			continue
		var b := pts.size()
		for k in range(4):
			pts.append(Vector2(ls[k].x, ls[k].y))
			uvs.append(uv[k])
			cols.append(tint)
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols, uvs,
				PackedInt32Array(), PackedFloat32Array(), tex.get_rid())


## An upright band round the stand between two angles: from offset o0 to o1 beyond the
## stand's front line, heights h0 to h1.
static func _wall(tri: Tris, cam: Cam, a0: float, a1: float, o0: float, o1: float, h0: float, h1: float, colour: Color) -> void:
	var ax := A + FENCE + 2.0
	var ay := L + FENCE + 2.0
	var p0 := Vector2(cos(a0) * (ax + o0), sin(a0) * (ay + o0))
	var p1 := Vector2(cos(a1) * (ax + o0), sin(a1) * (ay + o0))
	var q0 := Vector2(cos(a0) * (ax + o1), sin(a0) * (ay + o1))
	var q1 := Vector2(cos(a1) * (ax + o1), sin(a1) * (ay + o1))
	var s := [cam.oval(p0, h0), cam.oval(p1, h0), cam.oval(q1, h1), cam.oval(q0, h1)]
	for v in s:
		if v.z <= 0.0:
			return
	tri.poly([Vector2(s[0].x, s[0].y), Vector2(s[1].x, s[1].y), Vector2(s[2].x, s[2].y), Vector2(s[3].x, s[3].y)], colour)


## The light towers outside the stands: a mast and a bank of lights at the top of each,
## glowing into the night.
static func _towers(ci: CanvasItem, cam: Cam) -> void:
	if venue == "MCG":
		_mcg_towers(ci, cam)
		return
	for p in _tower_spots():
		var base := cam.oval(p, 0.0)
		if base.z <= 0.0:
			continue
		var top := cam.oval(p, 78.0)
		var w := maxf(1.0, 1.4 * base.z)
		ci.draw_rect(Rect2(base.x - w * 0.5, top.y, w, base.y - top.y), Color(0.09, 0.09, 0.1), true)
		var bank := Vector2(6.0, 4.0) * top.z
		for g in range(6):
			ci.draw_circle(Vector2(top.x, top.y), bank.x * (1.0 + g * 1.1), Color(1.0, 0.95, 0.82, 0.05 - g * 0.007))
		ci.draw_rect(Rect2(Vector2(top.x, top.y) - bank * 0.5, bank), Color(0.98, 0.97, 0.9), true)


## The MCG's stands as seen from the ground (Commons, "MCG Shane Warne Stand.png",
## EchidnaLives, 2022, CC BY-SA 4.0): three tiers of seats, a band of boxes under the
## middle and upper tiers, a thin dark roof with a row of pale trusses standing up along
## its edge. Heights are read from the photo, not published.
const MCG_TIERS := [[2.0, 20.0, FENCE_H + 0.3, 10.0], [23.0, 37.0, 13.5, 22.0], [41.0, 58.0, 25.5, 38.0]]
## Pale blue-grey seats as they read at night under the lights (darker than by day, so the
## crowd stays behind the players).
const MCG_SEAT := Color(0.24, 0.27, 0.32)
## A truss every this many stand columns, its base and height in metres.
const MCG_TRUSS_EVERY := 6
const MCG_TRUSS_H := 5.0

static func _mcg_trusses(ci: CanvasItem, cam: Cam, ring: Array, upper: Array) -> void:
	var tri := Tris.new()
	var ax := A + FENCE + 2.0
	var ay := L + FENCE + 2.0
	var off: float = upper[1] - 2.0
	var h0: float = upper[3] + 4.0
	# The roof's top edge, caught by the lights, so the trusses stand on something.
	for i in range(ring.size() - 1):
		_wall(tri, cam, ring[i][0], ring[i + 1][0], upper[1] - 4.0, upper[1], h0 - 0.5, h0, Color(0.5, 0.51, 0.54))
	for i in range(0, ring.size() - 3, MCG_TRUSS_EVERY):
		var a0: float = ring[i][0]
		var a1: float = ring[i + 3][0]
		var am := (a0 + a1) * 0.5
		var p0 := cam.oval(Vector2(cos(a0) * (ax + off), sin(a0) * (ay + off)), h0)
		var p1 := cam.oval(Vector2(cos(a1) * (ax + off), sin(a1) * (ay + off)), h0)
		var pm := cam.oval(Vector2(cos(am) * (ax + off), sin(am) * (ay + off)), h0 + MCG_TRUSS_H)
		if p0.z <= 0.0 or p1.z <= 0.0 or pm.z <= 0.0:
			continue
		var a := Vector2(p0.x, p0.y)
		var b := Vector2(p1.x, p1.y)
		var m := Vector2(pm.x, pm.y)
		# An open triangle of steel: two slim legs up to the apex.
		var w := maxf(0.8, 0.35 * pm.z)
		for leg in [[a, m], [b, m]]:
			var d: Vector2 = (leg[1] - leg[0]).orthogonal().normalized() * w * 0.5
			tri.poly([leg[0] - d, leg[0] + d, leg[1] + d, leg[1] - d], Color(0.62, 0.63, 0.66))
	tri.flush(ci)


## The MCG's six light towers (mcg.org.au, "Light towers"): hollow tubular steel masts
## about 75 m high, tapering from 4.2 m across at the foot to 2 m at the top, each
## carrying a head frame of lamps a further 10 m high, angled 15 degrees in towards the
## ground. The frame's width isn't published: 14 m reads right against photos.
const MCG_MAST := 75.0
const MCG_FRAME_H := 10.0
const MCG_FRAME_W := 14.0
const MCG_TILT := 15.0

static func _mcg_towers(ci: CanvasItem, cam: Cam) -> void:
	var steel := Color(0.09, 0.09, 0.1)
	for p in _tower_spots():
		var base := cam.oval(p, 0.0)
		var top := cam.oval(p, MCG_MAST)
		if base.z <= 0.0 or top.z <= 0.0:
			continue
		var wb := maxf(1.0, 4.2 * base.z) * 0.5
		var wt := maxf(1.0, 2.0 * top.z) * 0.5
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x - wb, base.y), Vector2(base.x + wb, base.y),
				Vector2(top.x + wt, top.y), Vector2(top.x - wt, top.y)]), steel)
		# The head frame: across the tower's line to the centre, its top leaning in.
		var inward: Vector2 = (-(p as Vector2)).normalized()
		var across := Vector2(-inward.y, inward.x) * MCG_FRAME_W * 0.5
		var lean := inward * MCG_FRAME_H * sin(deg_to_rad(MCG_TILT))
		var rise := MCG_FRAME_H * cos(deg_to_rad(MCG_TILT))
		var corners := [cam.oval(p - across, MCG_MAST), cam.oval(p + across, MCG_MAST),
				cam.oval(p + across + lean, MCG_MAST + rise), cam.oval(p - across + lean, MCG_MAST + rise)]
		var quad := PackedVector2Array()
		for c in corners:
			if c.z <= 0.0:
				quad.clear()
				break
			quad.append(Vector2(c.x, c.y))
		if quad.is_empty():
			continue
		var mid := (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
		var reach := quad[0].distance_to(quad[1])
		for g in range(6):
			ci.draw_circle(mid, reach * (0.55 + g * 0.45), Color(1.0, 0.95, 0.82, 0.05 - g * 0.007))
		ci.draw_colored_polygon(quad, steel)
		# The lamps, rows across the frame.
		var lamp := maxf(0.8, 0.45 * top.z)
		for row in range(4):
			for col in range(9):
				var u := (float(col) + 0.5) / 9.0
				var v := (float(row) + 0.5) / 4.0
				var at: Vector2 = quad[0].lerp(quad[1], u).lerp(quad[3].lerp(quad[2], u), v)
				ci.draw_rect(Rect2(at - Vector2(lamp, lamp * 0.7), Vector2(lamp * 2.0, lamp * 1.4)), Color(0.98, 0.97, 0.9), true)


## The big screen high above the far end, behind the goals, showing the match's score
## as it stands (board): each club's code by a chip of its colour, goals.behinds and
## the total, the quarter beneath. Lit, so it glows a little into the night. The MCG has
## one at each end (end -1: the other one).
static func _screen(ci: CanvasItem, cam: Cam, home: Color, away: Color, board: Dictionary, end := 1) -> void:
	var at := Vector2(0.0, (L + FENCE + 40.0) * end)
	var c := cam.oval(at, 30.0)
	if c.z <= 0.0:
		return
	var size := Vector2(30.0, 13.0) * c.z
	var r := Rect2(Vector2(c.x, c.y) - size * 0.5, size)
	for g in range(4):
		ci.draw_rect(r.grow((g + 1) * 1.4 * c.z), Color(0.6, 0.7, 0.9, 0.025), true)
	ci.draw_rect(r.grow(0.6 * c.z), Color(0.04, 0.04, 0.05), true)
	ci.draw_rect(r, Color(0.05, 0.07, 0.11), true)
	var codes: Array = board.get("codes", [])
	if codes.size() < 2:
		ci.draw_rect(Rect2(r.position + r.size * Vector2(0.06, 0.18), r.size * Vector2(0.4, 0.5)), home.lightened(0.15), true)
		ci.draw_rect(Rect2(r.position + r.size * Vector2(0.54, 0.18), r.size * Vector2(0.4, 0.5)), away.lightened(0.15), true)
		return
	var font: Font = UiKit.BOLD
	var fs := int(3.2 * c.z)
	if fs < 5:
		return                                   # too far to read: just the glow
	var goals: Array = board.get("goals", [0, 0])
	var behinds: Array = board.get("behinds", [0, 0])
	for side in range(2):
		var y := r.position.y + r.size.y * (0.36 + 0.34 * side)
		var chip := Rect2(r.position.x + r.size.x * 0.05, y - fs * 0.78, fs * 0.5, fs * 0.9)
		ci.draw_rect(chip, home if side == 0 else away, true)
		ci.draw_rect(chip, Color(1, 1, 1, 0.35), false, 1.0)
		var g := int(goals[side])
		var b := int(behinds[side])
		ci.draw_string(font, Vector2(chip.end.x + fs * 0.35, y), str(codes[side]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
		ci.draw_string(font, Vector2(r.position.x + r.size.x * 0.42, y), "%d.%d" % [g, b],
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.92, 0.95, 0.9))
		ci.draw_string(font, Vector2(r.position.x, y), str(g * 6 + b),
				HORIZONTAL_ALIGNMENT_RIGHT, r.size.x * 0.95, fs, Color(1.0, 0.86, 0.35, 0.98))
	var q := int(board.get("q", 0))
	if q > 0:
		ci.draw_string(font, Vector2(r.position.x, r.end.y - fs * 0.25), "Q%d" % q,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(fs * 0.6), Color(1, 1, 1, 0.6))


## The haze the lights make over the far side: a soft band of light on the horizon, over
## the far stands and the far turf.
static func _haze(ci: CanvasItem, cam: Cam, weather := "") -> void:
	var x0 := cam.cx - 4000.0
	var x1 := cam.cx + 4000.0
	var y := cam.hor
	var band := 0.12 * cam.f
	var haze := VignetteWeather.haze(weather)
	var clear := Color(haze.r, haze.g, haze.b, 0.0)
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y - band * 2.0), Vector2(x1, y - band * 2.0), Vector2(x1, y), Vector2(x0, y)]),
			PackedColorArray([clear, clear, haze, haze]))
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y + band * 0.6), Vector2(x0, y + band * 0.6)]),
			PackedColorArray([haze, haze, clear, clear]))


## A club's second colour (for the band on its flags), white if it has none.
static func _second(colours: Array, side: int) -> Color:
	if side < colours.size() and (colours[side] as Array).size() > 1:
		return (colours[side] as Array)[1]
	return Color(1, 1, 1)


## Where the six light towers stand outside the stands (oval metres).
static func _tower_spots() -> Array:
	var out := []
	for k in range(6):
		var a := TAU * (float(k) + 0.5) / 6.0
		out.append(Vector2(cos(a) * (A + 75.0), sin(a) * (L + 75.0)))
	return out


## Oval points round an ellipse centred at (ox, oy).
static func _ellipse_ring(ax: float, ay: float, ox: float, oy: float, n: int) -> Array:
	var out := []
	for i in range(n):
		var a := TAU * float(i) / n
		out.append(Vector2(ox + cos(a) * ax, oy + sin(a) * ay))
	return out


## The slice of the oval between y0 and y1 (a mown stripe).
static func _band(y0: float, y1: float) -> Array:
	var left := []
	var right := []
	var steps := 6
	for i in range(steps + 1):
		var y := lerpf(y0, y1, float(i) / steps)
		var x := A * sqrt(maxf(0.0, 1.0 - pow(y / L, 2.0)))
		left.append(Vector2(-x, y))
		right.push_front(Vector2(x, y))
	return left + right


## A convex oval polygon cut at the camera's near plane, projected to the screen.
static func _clip(cam: Cam, poly: Array) -> Array:
	var ls := []
	for p in poly:
		ls.append(cam.local(cam.to_scene * p))
	var out := []
	for i in range(ls.size()):
		var a: Vector2 = ls[i]
		var b: Vector2 = ls[(i + 1) % ls.size()]
		var a_in := a.y >= NEAR
		var b_in := b.y >= NEAR
		if a_in:
			out.append(a)
		if a_in != b_in:
			out.append(a.lerp(b, (NEAR - a.y) / (b.y - a.y)))
	var screen := []
	for l in out:
		var s := cam.screen(l)
		screen.append(Vector2(s.x, s.y))
	return screen


## Triangles gathered and drawn in one call.
class Tris:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	## A convex polygon, as a fan.
	func poly(pts: Array, colour: Color) -> void:
		if pts.size() < 3:
			return
		var base := points.size()
		for p in pts:
			points.append(p)
			colors.append(colour)
		for i in range(1, pts.size() - 1):
			indices.append_array([base, base + i, base + i + 1])

	func flush(ci: CanvasItem) -> void:
		if not indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)
