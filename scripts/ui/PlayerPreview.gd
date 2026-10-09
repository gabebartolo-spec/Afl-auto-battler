class_name PlayerPreview
extends Control
## Create a player: the prospect as you build him, on the match figures
## themselves - front on, bouncing on his toes, and from behind with his number.
## Reads the form's spec every frame, so a change to his look, height or number
## shows at once. Presentation only.
##
## He has no club yet, so he wears a plain prospect's guernsey. Hair, skin and
## sleeves are drawn as on the ground; looks the figures don't draw yet (facial
## hair, headband, bandaging, tattoos) aren't faked here.

## A draft hopeful's plain light training guernsey and dark shorts: no club's colours,
## and light enough to stand out on the dark page.
const PROSPECT_KIT := {"design": "plain", "base": Color("#d6d2c8"), "pattern": Color("#2b2d33"),
		"pattern2": Color("#2b2d33"), "shorts": Color("#2b2d33")}
## The ruck build is drawn for a ruckman, the small build under BroadcastVignette.SMALL_CM.
const READY_RATE := 2.6

var spec := {}
var _t := 0.0


func _ready() -> void:
	material = StoppageVignette.figure_material([PROSPECT_KIT])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Which figure he's drawn on: the ruck build for a ruckman, the small build for a
## small man, otherwise the average build.
static func build(s: Dictionary) -> String:
	if str(s.get("role", "")) == "RUCK":
		return "ruck"
	return "small" if int(s.get("height_cm", 184)) < BroadcastVignette.SMALL_CM else "average"


func _draw() -> void:
	if spec.is_empty() or size.y <= 0.0:
		return
	var look: Dictionary = spec.get("look", {})
	var body := build(spec)
	var tall := float(VignetteFigures.BODIES[body]["height_m"])
	var cm := float(spec.get("height_cm", 184))
	# Room for the tallest prospect; each man drawn at his own height.
	var px_per_m := (size.y - 10.0) / 2.12
	var k := px_per_m / VignetteFigures.PX_PER_M * (cm / 100.0) / tall
	var feet_y := size.y - 6.0
	var hair := str(look.get("hair_style", VignetteFigures.HAIR_BASE))
	var colour := StoppageVignette.look_colour(0, {"skin": int(look.get("skin", 1)), "hair": int(look.get("hair", 1)),
			"long_sleeves": bool(look.get("long_sleeves", false))})
	var xs := [size.x * 0.27, size.x * 0.73]
	for i in range(2):
		var facing := "front" if i == 0 else "back"
		var anim := "ready" if VignetteFigures.has(body, "ready", facing) else "idle"
		var info := VignetteFigures.strip(body, anim, facing)
		var frame := int(_t * READY_RATE + i * 1.3) % maxi(1, int(info["frames"]))
		var feet := Vector2(xs[i], feet_y)
		draw_set_transform_matrix(Transform2D(0.0, Vector2(1.0, 0.28), 0.0, feet))
		draw_circle(Vector2.ZERO, 0.38 * px_per_m, Color(0, 0, 0, 0.28))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var number := int(spec.get("number_pref", 0))
		var num := StoppageVignette.number_colour(0, number) if i == 1 and number > 0 else Color(0, 0, 0, 0)
		StoppageVignette.draw_frame(self, feet, info, StoppageVignette.figure_frame(info, frame, anim, facing), k,
				colour, false, num, Transform2D.IDENTITY, hair)
