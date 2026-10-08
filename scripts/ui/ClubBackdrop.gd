class_name ClubBackdrop
extends Control
## Behind a screen of yours (director, 2026-10-08: club colour as the
## atmosphere, the ground's texture instead of flat charcoal): the page
## colour, broad mown-turf bands barely lighter than it, and a wash of your
## club's colour from the top that fades away before the content needs the
## contrast. Drawn once; never takes a tap.

var _club := ""


func setup(club: String) -> ClubBackdrop:
	_club = club
	name = "ClubBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	return self


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.BG)
	# Mown turf: wide bands across the page, a breath lighter in turn.
	var band := 64.0
	var i := 0
	while float(i) * band < h:
		if i % 2 == 0:
			draw_rect(Rect2(0, float(i) * band, w, band), Color(1, 1, 1, 0.018))
		i += 1
	if _club == "":
		return
	# The club's most vivid colour that shows on the page.
	var c := UiKit.club_vivid(_club, UiKit.BG)
	var top := Color(c, 0.26)
	var none := Color(c, 0.0)
	var wash := minf(h * 0.45, 360.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, wash), Vector2(0, wash)]),
			PackedColorArray([top, top, none, none]))
