extends Control
## Draws recorded token and ball paths over the pitch (tools/visual/capture_match.gd).

var trails: Array = []        # [{points: PackedVector2Array, colour: Color}]
var dots: Array = []          # [{pos: Vector2, colour: Color, r: float}]


func _draw() -> void:
	for t in trails:
		var pts: PackedVector2Array = t["points"]
		if pts.size() >= 2:
			draw_polyline(pts, t["colour"], float(t.get("width", 1.5)), true)
	for d in dots:
		draw_circle(d["pos"], float(d.get("r", 3.0)), d["colour"])
