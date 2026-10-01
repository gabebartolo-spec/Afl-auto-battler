class_name MediaConferenceVignette
extends Control
## A short post-match media-room scene in the same procedural language as
## ARD's match vignettes: letterbox, club colours, simple figures and staged
## movement. The question/answers remain authoritative UI layered over it.

signal ready_for_question
const CUT_IN := 0.35
const FREEZE := 1.55
var club := ""
var heading := "Post-match press conference"
var _colours := []
var _t := 0.0
var _ready := false

static func open(host: Node, club_code: String) -> MediaConferenceVignette:
	var v := MediaConferenceVignette.new()
	v.name = "MediaConferenceVignette"
	v.club = club_code
	v._colours = GameDB.club_colours(club_code)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(v)
	return v

func _process(delta: float) -> void:
	if _ready:
		return
	_t += delta
	if _t >= FREEZE:
		_ready = true
		ready_for_question.emit()
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
	var fade := clampf(_t / CUT_IN, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.055, 0.065), true)
	var desk_y := size.y * 0.58
	# Sponsor/media wall: restrained club-colour bands rather than fake logos.
	var wall := Rect2(size.x * 0.08, size.y * 0.13, size.x * 0.84, size.y * 0.37)
	draw_rect(wall, Color(0.11, 0.11, 0.13), true)
	for i in range(6):
		var x := wall.position.x + wall.size.x * float(i) / 6.0
		draw_rect(Rect2(x, wall.position.y, maxf(3.0, wall.size.x / 42.0), wall.size.y), Color(_colours[i % mini(2, _colours.size())], 0.55), true)
	# Coach arrives from frame left and settles behind the microphones.
	var k := 1.0 - pow(1.0 - clampf(_t / 1.1, 0.0, 1.0), 3.0)
	var cx := lerpf(-size.x * 0.12, size.x * 0.5, k)
	_draw_coach(Vector2(cx, desk_y - size.y * 0.06))
	draw_rect(Rect2(0, desk_y, size.x, size.y * 0.12), Color(0.12, 0.12, 0.14), true)
	# Two microphones and shadowed reporters/cameras in the foreground.
	for dx in [-24.0, 24.0]:
		draw_line(Vector2(size.x * 0.5 + dx, desk_y), Vector2(size.x * 0.5 + dx * 0.45, desk_y - 30), Color(0.65,0.65,0.67), 3)
		draw_circle(Vector2(size.x * 0.5 + dx * 0.45, desk_y - 32), 5, Color(0.06,0.06,0.07))
	for x in [0.12, 0.3, 0.72, 0.88]:
		draw_circle(Vector2(size.x * x, size.y * 0.82), size.x * 0.07, Color(0.025,0.025,0.03))
	# Same cinematic letterbox language as StoppageVignette.
	var bar := size.y * 0.075 * (1.0 - pow(1.0 - fade, 3.0))
	draw_rect(Rect2(0, 0, size.x, bar), Color.BLACK, true)
	draw_rect(Rect2(0, size.y - bar, size.x, bar), Color.BLACK, true)
	if fade >= 1.0:
		var font: Font = UiKit.BOLD
		var fs := int(clampf(size.x / 24.0, 13.0, 18.0))
		var w := font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x-w)*0.5, bar*0.5+fs*0.36), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1,1,1,0.92))
	if fade < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0,0,0,1.0-fade), true)

func _draw_coach(at: Vector2) -> void:
	var scale := clampf(size.x / 390.0, 0.8, 1.35)
	var shirt: Color = _colours[0] if not _colours.is_empty() else Color(0.3,0.3,0.32)
	var trim: Color = _colours[1] if _colours.size() > 1 else shirt.lightened(0.25)
	draw_rect(Rect2(at.x-30*scale, at.y-48*scale, 60*scale, 62*scale), shirt, true)
	draw_rect(Rect2(at.x-5*scale, at.y-48*scale, 10*scale, 62*scale), trim, true)
	draw_circle(Vector2(at.x, at.y-68*scale), 18*scale, Color(0.76,0.60,0.47))
