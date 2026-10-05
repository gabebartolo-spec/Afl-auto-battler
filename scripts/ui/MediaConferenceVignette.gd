class_name MediaConferenceVignette
extends Control
## A short post-match media-room scene in the vignettes' style: the coach, a
## pre-rendered figure in a suit with a tie in the club's colour, walks in behind
## the desk and sits down at the microphones; the room is the club's media wall,
## the press in front of him with phones up, a TV camera, the odd flash. The
## question/answers remain authoritative UI layered over it.

signal ready_for_question
const CUT_IN := 0.35
const FREEZE := 1.55
## The coach walks in to his chair, then sits.
const WALK_END := 1.05
const SIT_END := 1.45
## The coach's outfit and look: one for now, swappable when coaches get their own
## appearance (roadmap "coach appearance").
const COACH_SUIT := Color(0.16, 0.17, 0.2)
const COACH_SHIRT := Color(0.93, 0.93, 0.95)
const COACH_LOOK := {"skin": 1, "hair": 2}
const BODY := "coach"
var club := ""
var heading := "Post-match press conference"
var _colours := []
var _t := 0.0
var _ready := false

static func open(host: Node, club_code: String) -> MediaConferenceVignette:
	var v := MediaConferenceVignette.new()
	v.name = "MediaConferenceVignette"
	v.club = club_code
	var db := host.get_tree().root.get_node("GameDB")
	v._colours = db.club_colours(club_code)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(v)
	v._dress()
	return v

## His suit, shirt and a tie in the club's first colour, on the figure material.
func _dress() -> void:
	var tie: Color = _colours[0] if not _colours.is_empty() else Color(0.5, 0.1, 0.1)
	material = StoppageVignette.figure_material([{"design": "suit", "base": COACH_SUIT,
			"pattern": COACH_SHIRT, "pattern2": tie, "shorts": COACH_SUIT}])

func _process(delta: float) -> void:
	_t += delta
	if not _ready and _t >= FREEZE:
		_ready = true
		ready_for_question.emit()
	# The room carries on behind the question: flashes, the coach shifting.
	queue_redraw()

func finish_now() -> void:
	if _ready:
		return
	_t = FREEZE
	_ready = true
	ready_for_question.emit()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _ready and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		finish_now()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	var fade := clampf(_t / CUT_IN, 0.0, 1.0)
	var desk_y := h * 0.66
	var feet_y := h * 0.86                  # behind the desk: his chair's on the floor there
	var pm := h * 0.62 / 1.84               # pixels per metre: standing, he's about 0.62 of the frame
	_draw_wall(w, h, desk_y)
	_draw_camera_rig(w, h)
	# The coach: in from the left behind the desk, sits at the middle microphones.
	var k := 1.0 - pow(1.0 - clampf(_t / WALK_END, 0.0, 1.0), 3.0)
	var x := lerpf(w * 0.08, w * 0.5, k)
	if _t < WALK_END:
		_coach(Vector2(x, feet_y), pm, "coach_walk", "front_r", int(_t * 7.0) % 8)
	elif _t < SIT_END:
		_coach(Vector2(x, feet_y), pm, "coach_sit", "front", mini(2, int((_t - WALK_END) / (SIT_END - WALK_END) * 3.0)))
	else:
		# Settled; now and then a hand comes up as he makes a point.
		var talking := _t > FREEZE + 0.6 and fmod(_t - FREEZE, 3.4) < 1.1
		_coach(Vector2(x, feet_y), pm, "coach_seated", "front", 1 if talking else 0)
	_draw_desk(w, h, desk_y)
	_draw_press(w, h)
	# A camera flash now and then from the pack.
	var f := fmod(_t + 0.3, 1.9)
	if _t > 0.5 and f < 0.07:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.18 * (1.0 - f / 0.07)), true)
	# Same cinematic letterbox language as StoppageVignette.
	var bar := h * 0.075 * (1.0 - pow(1.0 - fade, 3.0))
	draw_rect(Rect2(0, 0, w, bar), Color.BLACK, true)
	draw_rect(Rect2(0, h - bar, w, bar), Color.BLACK, true)
	if fade >= 1.0:
		var font: Font = UiKit.BOLD
		var fs := int(clampf(w / 24.0, 13.0, 18.0))
		var tw := font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((w - tw) * 0.5, bar * 0.5 + fs * 0.36), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
	if fade < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - fade), true)

## The coach figure, feet at feet (hidden behind the desk), pm pixels per metre.
func _coach(feet: Vector2, pm: float, anim: String, facing: String, frame: int) -> void:
	var info := VignetteFigures.strip(BODY, anim, facing)
	var k := pm / VignetteFigures.PX_PER_M
	var origin := feet - Vector2(info["pivot"][0], info["pivot"][1]) * k
	draw_texture_rect_region(StoppageVignette.FIGURE_SHADE, Rect2(origin, VignetteFigures.FRAME * k),
			VignetteFigures.source(info, frame),
			Color(0.0, int(COACH_LOOK["skin"]) / 8.0, int(COACH_LOOK["hair"]) / 8.0, 1.0))

## The media wall: a step-and-repeat of plain club-colour tiles (no invented logos),
## lit from the front, and the room's dark edges.
func _draw_wall(w: float, h: float, desk_y: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.06), true)
	var wall := Rect2(w * 0.04, h * 0.1, w * 0.92, desk_y - h * 0.06)
	draw_rect(wall, Color(0.12, 0.12, 0.14), true)
	var a: Color = _colours[0] if not _colours.is_empty() else Color(0.3, 0.3, 0.32)
	var b: Color = _colours[1] if _colours.size() > 1 else a.lightened(0.3)
	var tw := wall.size.x / 7.0
	var th := wall.size.y / 3.5
	for row in range(4):
		for col in range(8):
			var off := tw * 0.5 if row % 2 == 1 else 0.0
			var r := Rect2(wall.position + Vector2(col * tw - off + tw * 0.12, row * th + th * 0.18), Vector2(tw * 0.76, th * 0.64))
			r = r.intersection(wall)
			if r.size.x <= 1.0 or r.size.y <= 1.0:
				continue
			# Muted, so a white or yellow club doesn't glare over the coach.
			var c := (a if (row + col) % 2 == 0 else b).darkened(0.55)
			draw_rect(r, Color(c, 0.55), true)
			draw_rect(Rect2(r.position + r.size * Vector2(0.3, 0.42), r.size * Vector2(0.4, 0.16)), Color(1, 1, 1, 0.07), true)
	# Key light on the wall behind his chair.
	for i in range(5):
		draw_circle(Vector2(w * 0.5, desk_y - h * 0.12), w * (0.12 + 0.06 * i), Color(1.0, 0.95, 0.85, 0.035))

## The table across the front: its club-colour skirt, top, the microphones bunched in
## front of his chair (broadcasters' blank flags), a bottle and a glass, a name card.
func _draw_desk(w: float, h: float, desk_y: float) -> void:
	# The skirt in the club's colour, lit from above, its folds catching the light.
	var skirt: Color = (_colours[0] if not _colours.is_empty() else Color(0.2, 0.2, 0.22)).darkened(0.3)
	if skirt.get_luminance() < 0.06:
		skirt = skirt.lightened(0.12)          # a black club's skirt still reads as cloth
	draw_rect(Rect2(w * 0.1, desk_y, w * 0.8, h * 0.24), skirt, true)
	for i in range(9):
		var fx := w * (0.13 + 0.093 * i)
		draw_line(Vector2(fx, desk_y + 2.0), Vector2(fx, desk_y + h * 0.24), skirt.darkened(0.3), 1.5)
	draw_rect(Rect2(w * 0.1, desk_y, w * 0.8, h * 0.035), Color(1, 1, 1, 0.08), true)
	var trim: Color = _colours[1] if _colours.size() > 1 else skirt.lightened(0.4)
	draw_rect(Rect2(w * 0.1, desk_y + h * 0.05, w * 0.8, 2.0), Color(trim, 0.6), true)
	draw_rect(Rect2(w * 0.08, desk_y - h * 0.018, w * 0.84, h * 0.03), Color(0.22, 0.2, 0.19), true)
	draw_rect(Rect2(w * 0.08, desk_y - h * 0.018, w * 0.84, 1.5), Color(1, 1, 1, 0.18), true)
	# Name card in front of his place, blank.
	draw_rect(Rect2(w * 0.43, desk_y - h * 0.05, w * 0.14, h * 0.035), Color(0.88, 0.88, 0.86), true)
	var flags := [Color(0.75, 0.12, 0.12), Color(0.12, 0.3, 0.7), Color(0.9, 0.9, 0.9), Color(0.1, 0.55, 0.3), Color(0.95, 0.65, 0.1)]
	# Short desk microphones angled up at him; tips at his chest, clear of his face.
	var mic_h := h * 0.07
	for i in range(flags.size()):
		var bx := w * (0.4 + 0.05 * i) + (i % 2) * 3.0
		var tip := Vector2(w * 0.5 + (bx - w * 0.5) * 0.55, desk_y - mic_h - (i % 3) * 2.0)
		var base := Vector2(bx, desk_y - h * 0.012)
		draw_line(base, tip, Color(0.18, 0.18, 0.2), 2.0)
		draw_rect(Rect2(base + Vector2(-4, -4), Vector2(8, 4)), Color(0.1, 0.1, 0.11), true)
		var flag := Rect2(tip.lerp(base, 0.28) - Vector2(5, 4), Vector2(10, 8))
		draw_rect(flag, flags[i], true)
		draw_circle(tip, 4.0, Color(0.06, 0.06, 0.07))
	# A bottle and a glass of water at his elbow.
	var bottle := Vector2(w * 0.66, desk_y - h * 0.012)
	draw_rect(Rect2(bottle - Vector2(4, h * 0.08), Vector2(8, h * 0.08)), Color(0.6, 0.75, 0.85, 0.75), true)
	draw_rect(Rect2(bottle - Vector2(2, h * 0.095), Vector2(4, h * 0.015)), Color(0.2, 0.4, 0.8), true)
	draw_rect(Rect2(bottle + Vector2(10, -h * 0.04), Vector2(7, h * 0.04)), Color(0.8, 0.88, 0.95, 0.5), true)

## A TV camera on its tripod at the side, shooting the desk.
func _draw_camera_rig(w: float, h: float) -> void:
	var head := Vector2(w * 0.9, h * 0.5)
	var leg := Color(0.09, 0.09, 0.1)
	for dx in [-0.05, 0.0, 0.05]:
		draw_line(head + Vector2(0, h * 0.04), Vector2(head.x + w * dx, h * 0.93), leg, 2.0)
	var body := Rect2(head - Vector2(w * 0.07, h * 0.06), Vector2(w * 0.12, h * 0.1))
	draw_rect(body, Color(0.15, 0.15, 0.17), true)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 2.0)), Color(1, 1, 1, 0.15), true)   # rim light
	draw_rect(Rect2(head - Vector2(w * 0.12, h * 0.035), Vector2(w * 0.055, h * 0.055)), Color(0.1, 0.1, 0.11), true)
	draw_circle(head - Vector2(w * 0.12, h * 0.0075), h * 0.02, Color(0.25, 0.32, 0.45))     # lens
	draw_rect(Rect2(head + Vector2(-w * 0.03, -h * 0.09), Vector2(w * 0.05, h * 0.03)), Color(0.12, 0.12, 0.13), true)   # handle
	draw_circle(head + Vector2(w * 0.04, -h * 0.045), 2.0, Color(0.9, 0.15, 0.15))   # tally light

## The press in the foreground, from behind: heads and shoulders, each one different
## (size, place, tilt), phones and a recorder held up to the desk.
func _draw_press(w: float, h: float) -> void:
	var body := Color(0.035, 0.035, 0.04)
	var rim := Color(0.7, 0.66, 0.6, 0.7)
	# [x, y, size, tilt, holds: 0 nothing, 1 phone, 2 recorder]
	var people := [[0.04, 0.82, 1.1, -0.10, 0], [0.2, 0.87, 1.0, 0.06, 1], [0.37, 0.92, 1.2, -0.04, 0],
			[0.63, 0.87, 0.95, 0.12, 1], [0.8, 0.93, 1.25, -0.08, 2], [0.97, 0.84, 1.05, 0.05, 0]]
	for i in range(people.size()):
		var p: Array = people[i]
		var r: float = h * 0.085 * float(p[2])
		var at := Vector2(w * float(p[0]), h * float(p[1]))
		var sway := sin(_t * (0.9 + 0.17 * i) + i * 1.3) * r * 0.04
		var tilt: float = p[3]
		var hold := int(p[4])
		if hold > 0:
			# Arm up holding a phone or recorder towards the desk, screen lit.
			var hand := at + Vector2(r * (0.9 if tilt >= 0.0 else -0.9), -r * 1.9 + sway)
			draw_line(at + Vector2(r * 0.6 * signf(hand.x - at.x), -r * 0.2), hand, body, r * 0.32)
			if hold == 1:
				draw_rect(Rect2(hand - Vector2(r * 0.3, r * 0.55), Vector2(r * 0.6, r * 1.0)), body, true)
				draw_rect(Rect2(hand - Vector2(r * 0.24, r * 0.48), Vector2(r * 0.48, r * 0.86)), Color(0.55, 0.65, 0.8, 0.55), true)
			else:
				draw_rect(Rect2(hand - Vector2(r * 0.18, r * 0.5), Vector2(r * 0.36, r * 0.8)), Color(0.12, 0.12, 0.13), true)
				draw_circle(hand + Vector2(0, -r * 0.5), r * 0.2, Color(0.2, 0.2, 0.22))
		var shoulders := PackedVector2Array([at + Vector2(-r * 1.6, r * 1.6), at + Vector2(-r * 1.3, -r * 0.1),
				at + Vector2(-r * 0.5, -r * 0.45), at + Vector2(r * 0.5, -r * 0.45), at + Vector2(r * 1.3, -r * 0.1),
				at + Vector2(r * 1.6, r * 1.6)])
		draw_colored_polygon(shoulders, body)
		var head := at + Vector2(tilt * r * 2.0, -r * 1.0 + sway)
		draw_set_transform(head, tilt, Vector2(0.86, 1.0))
		draw_circle(Vector2.ZERO, r * 0.62, body)
		draw_arc(Vector2.ZERO, r * 0.62, PI * 1.15, PI * 1.85, 10, rim, maxf(1.0, r * 0.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
