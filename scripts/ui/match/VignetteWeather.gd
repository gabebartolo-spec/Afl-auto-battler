class_name VignetteWeather
extends RefCounted
## The day's weather as the match views draw it (ARD-M4-016; MatchSim.weather: "perfect",
## "wet", "windy" or "hot"). Presentation only: the look follows the weather and changes
## nothing. Restrained: nothing here covers the ball or a name.
##   wet    darker, sheened turf (the lights in it), a cooler overcast, light rain;
##   windy  flags on the stand roofs streaming, banners and pennants pulling;
##   hot    drier, yellower turf, firmer shadows, a warm haze over the far side.
## Anything else (perfect, unknown or none) draws as before.

const WET := "wet"
const WINDY := "windy"
const HOT := "hot"


## The turf's two mown colours, by weather.
static func grass(weather: String, base: Array) -> Array:
	match weather:
		WET:
			return base.map(func(c: Color) -> Color: return Color(c.r * 0.62, c.g * 0.7, c.b * 0.82))
		HOT:
			return base.map(func(c: Color) -> Color: return c.lerp(Color(0.46, 0.46, 0.22), 0.42))
	return base


## How strongly a figure's shadow falls (alpha), by weather: overcast softens it,
## a hard sun firms it.
static func shadow_alpha(weather: String) -> float:
	match weather:
		WET:
			return 0.18
		HOT:
			return 0.58
	return 0.32


## How hard the wind pulls flags and banners: 0 calm, 1 a strong breeze.
static func wind(weather: String) -> float:
	return 1.0 if weather == WINDY else 0.0


## The haze over the far side: its colour and strength.
static func haze(weather: String) -> Color:
	match weather:
		HOT:
			return Color(1.0, 0.86, 0.6, 0.32)
		WET:
			return Color(0.74, 0.8, 0.9, 0.26)
	return Color(0.85, 0.88, 1.0, 0.13)


## Over the scene, under the names and the bars, at time t: wet, an overcast and rain
## falling across it (streaks thin enough that the ball and the players read through
## them). rect: the screen to cover. (The wind is drawn on the ground: draw_wind.)
static func draw_air(ci: CanvasItem, rect: Rect2, t: float, weather: String) -> void:
	if weather != WET:
		return
	ci.draw_rect(rect, Color(0.05, 0.08, 0.12, 0.13), true)       # overcast
	var n := int(clampf(rect.size.x * rect.size.y / 1900.0, 40.0, 420.0))
	var lean := Vector2(-0.18, 1.0).normalized()                  # it falls slanting a touch
	for i in range(n):
		var h := hash(i * 7919 + 13)
		var fx := float(h % 10007) / 10007.0
		var fy := float((h / 10007) % 10009) / 10009.0
		var speed := 0.9 + 0.5 * float((h / 7) % 97) / 97.0      # screens a second
		var streak := (18.0 + float(h % 15)) * rect.size.y / 844.0
		var y := fposmod(fy + t * speed, 1.0) * (rect.size.y + streak) - streak
		var x := fposmod(fx + 0.09 * y / rect.size.y, 1.0) * rect.size.x
		var p := rect.position + Vector2(x, y)
		var a := 0.24 + 0.16 * float((h / 3) % 7) / 7.0
		ci.draw_line(p, p + lean * streak, Color(0.86, 0.9, 0.96, a), 1.4, true)


## Which way the wind blows, oval metres: down the ground toward the +y end (the end the
## scenes attack), a little across it.
const WIND_DIR := Vector2(0.25, 1.0)


## Wind lines over the ground, seen through cam at time t: long faint wisps a few metres
## up, streaming down the ground toward the windy end and shrinking into the distance
## with it. Drawn with the ground, so the players, the ball and the names stay in front.
static func draw_wind(ci: CanvasItem, cam: VignetteGround.Cam, t: float) -> void:
	# Worked in the scene's own coordinates (the camera's), the wind's direction carried over.
	var dir := cam.to_scene.basis_xform(WIND_DIR).normalized()
	var across := Vector2(dir.y, -dir.x)
	var right := Vector2(cam.fwd.y, -cam.fwd.x)
	for i in range(28):
		var h := hash(i * 4507 + 29)
		var ahead := 7.0 + float((h / 1013) % 991) / 991.0 * 38.0    # metres in front of the camera
		var side := (float(h % 1013) / 1013.0 - 0.5) * ahead * 0.9   # within the view
		var up := 1.5 + float((h / 7) % 83) / 83.0 * 5.0             # in the air, not on the turf
		var speed := 12.0 + float(h % 7)                             # metres a second
		var length := 4.0 + float(h % 5)
		var span := 80.0
		var run := fposmod(t * speed + float(h % 677), span) - span * 0.5
		var start := cam.pos + cam.fwd * ahead + right * side + dir * run
		var curl := 1.0 if h % 3 == 0 else 0.0                       # now and then a wisp curls over
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var ok := true
		for k in range(17):
			var u := float(k) / 16.0
			# An S of a wisp, its tail lifting; a curl turns the head over on itself.
			var off := sin(u * TAU * 0.9 + t * 3.0 + float(i)) * 0.7
			var lift := u * u * 0.8
			var along := length * u
			if curl > 0.0 and u > 0.7:
				var c := (u - 0.7) / 0.3 * PI * 1.4
				along = length * 0.7 + sin(c) * 0.9
				lift += (1.0 - cos(c)) * 0.9
			var s3 := cam.project(start + dir * along + across * off, up + lift)
			if s3.z <= 0.0:
				ok = false
				break
			pts.append(Vector2(s3.x, s3.y))
			cols.append(Color(0.94, 0.96, 1.0, 0.24 * sin(u * PI)))           # fades in and out
		if ok:
			ci.draw_polyline_colors(pts, cols, 1.3, true)


## The wind on the flat pitch view: the same wisps from above, streaming toward one end
## (+x on the view), under the players.
static func draw_wind_flat(ci: CanvasItem, rect: Rect2, t: float) -> void:
	for i in range(14):
		var h := hash(i * 3313 + 7)
		var fy := 0.1 + 0.8 * float(h % 997) / 997.0
		var speed := 0.16 + 0.08 * float((h / 997) % 89) / 89.0        # views a second
		var length := (0.12 + 0.08 * float(h % 7) / 7.0) * rect.size.x
		var x0 := fposmod(float((h / 5) % 991) / 991.0 + t * speed, 1.3) - 0.15
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for k in range(13):
			var u := float(k) / 12.0
			pts.append(rect.position + Vector2(x0 * rect.size.x + u * length,
					fy * rect.size.y + sin(u * 3.0 + t * 2.0 + float(i)) * 3.0))
			cols.append(Color(0.92, 0.95, 1.0, 0.3 * sin(u * PI)))
		ci.draw_polyline_colors(pts, cols, 1.2, true)


## Wet turf holds the lights: under each light tower in view, a long faint streak of
## its light on the grass, running down toward the camera as light on wet grass does.
static func draw_sheen(ci: CanvasItem, cam: VignetteGround.Cam, towers: Array, a_axis: float, l_axis: float) -> void:
	for p in towers:
		var tower: Vector2 = p
		# Where the reflection starts: the boundary on the way to the tower.
		var at: Vector2 = tower.normalized()
		at = Vector2(at.x * a_axis, at.y * l_axis) * 0.97
		var s := cam.oval(at, 0.0)
		if s.z <= 0.0:
			continue
		# A few thin streaks, not a beam: light broken up by the wet grass.
		var down := 0.26 * cam.f
		for k in range(3):
			var dx := (float(k) - 1.0) * 1.4 * s.z
			var w := maxf(0.8, 0.35 * s.z)
			var lit := Color(0.88, 0.92, 1.0, 0.11 - 0.03 * absf(float(k) - 1.0))
			var none := Color(0.88, 0.92, 1.0, 0.0)
			var x := s.x + dx
			ci.draw_polygon(PackedVector2Array([Vector2(x - w, s.y), Vector2(x + w, s.y),
					Vector2(x + w * 1.6 + dx * 0.5, s.y + down), Vector2(x - w * 1.6 + dx * 0.5, s.y + down)]),
					PackedColorArray([lit, lit, none, none]))


## A flag on a pole in a club's colours (the top half colour, the bottom half second),
## streaming with the wind at time t: pole foot at foot, pole height pole_h px, flag w x h
## px, phase so a crowd's flags don't wave as one. wind_strength 0 hangs it, 1 streams it.
static func draw_flag(ci: CanvasItem, foot: Vector2, pole_h: float, w: float, h: float, colour: Color,
		t: float, phase: float, wind_strength: float, second := Color(1, 1, 1)) -> void:
	var top := foot - Vector2(0, pole_h)
	ci.draw_line(foot, top, Color(0.8, 0.8, 0.82), maxf(1.0, w * 0.045), true)
	var steps := 12
	var upper := []
	var middle := []
	var lower := []
	for i in range(steps + 1):
		var u := float(i) / steps
		# A wave runs out from the pole; the free end flicks most.
		var ripple := sin(u * 7.0 - t * 12.0 + phase) * h * 0.18 * u * wind_strength
		var droop := (1.0 - wind_strength) * u * h * 0.9
		var x := top.x + u * w * lerpf(0.35, 1.0, wind_strength) * (1.0 - 0.06 * sin(t * 7.0 + phase) * u)
		var y := top.y + ripple + droop
		upper.append(Vector2(x, y + u * h * 0.06))
		middle.append(Vector2(x, y + h * 0.5))
		lower.append(Vector2(x, y + h - u * h * 0.06 - droop * 0.6))
	_strip(ci, upper, middle, colour)
	_strip(ci, middle, lower, second)
	var outline := PackedVector2Array()
	for p in upper:
		outline.append(p)
	for i in range(steps, -1, -1):
		outline.append(lower[i])
	outline.append(upper[0])
	ci.draw_polyline(outline, Color(0, 0, 0, 0.35), 1.0, true)      # a soft edge, not stair-steps


static func _strip(ci: CanvasItem, a: Array, b: Array, colour: Color) -> void:
	var poly := PackedVector2Array()
	for p in a:
		poly.append(p)
	for i in range(b.size() - 1, -1, -1):
		poly.append(b[i])
	ci.draw_colored_polygon(poly, colour)
