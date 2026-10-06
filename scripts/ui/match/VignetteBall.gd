class_name VignetteBall
extends RefCounted
## The football in the match scenes: a Sherrin rendered in Blender (ard-asset-pipeline
## tools/blender/ball_sprite.py, packed by tools/pack_ball.py) - leather panels, seams,
## white laces and a thin dark rim so a small ball still reads. ball.png holds FRAMES
## frames of it spinning end over end, a whole turn, left to right: row 0 the red ball,
## row 1 the yellow one the AFL plays with under lights (director, 2026-10-06). Each
## frame is CELL px square with the ball LENGTH px long in it.

const TEX := preload("res://assets/vignette/ball.png")
const FRAMES := 16
const CELL := 64.0
const LENGTH := 57.0
## Turns a second end over end in flight (a punt).
const SPIN := 2.0
## Every match scene is played under lights, so the night ball.
const NIGHT := true


## The ball centred at centre, length px long end to end. In flight it spins with the
## scene's time t; held or bouncing it sits laces up, a little turned (frame).
static func draw(ci: CanvasItem, centre: Vector2, length: float, t := 0.0, spinning := false,
		frame := 1) -> void:
	var f := posmod(int(floor(t * SPIN * FRAMES)), FRAMES) if spinning else frame
	var size := Vector2(CELL, CELL) * (length / LENGTH)
	var src := Rect2(f * CELL, (CELL if NIGHT else 0.0), CELL, CELL)
	ci.draw_texture_rect_region(TEX, Rect2(centre - size * 0.5, size), src)
