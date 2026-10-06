class_name VignetteCamera
extends RefCounted
## A broadcast camera for the flat (screen-space) vignettes: it zooms and pans, the way a
## TV camera on a long lens does from a fixed spot - the whole picture scales together, so
## nothing changes shape as it moves in (a camera moving closer warps the perspective).
##
## A vignette draws its scene through view(): draw_set_transform_matrix(view) at the top
## of _draw, any local transform composed onto it (view * local, and back to view after),
## then Transform2D.IDENTITY for what sits on the glass (letterbox, captions, fades).
## Zoom never goes below 1 and the view is held inside the drawn scene, so the scene's own
## edges never show.


## The view transform: the scene point focus at the screen's centre, zoom x. scene: the
## part of the scene that is drawn (by default exactly the screen); the view never leaves it.
static func view(size: Vector2, focus: Vector2, zoom: float, scene := Rect2()) -> Transform2D:
	var r := scene if scene.has_area() else Rect2(Vector2.ZERO, size)
	var z := maxf(maxf(1.0, zoom), maxf(size.x / r.size.x, size.y / r.size.y))
	var half := size * 0.5 / z
	var f := Vector2(clampf(focus.x, r.position.x + half.x, r.end.x - half.x),
			clampf(focus.y, r.position.y + half.y, r.end.y - half.y))
	return Transform2D(0.0, Vector2(z, z), 0.0, size * 0.5 - f * z)


## A smooth move between two values over [t0, t1] (ease in and out, held at the ends).
static func glide(a, b, t: float, t0: float, t1: float):
	var k := clampf((t - t0) / maxf(0.001, t1 - t0), 0.0, 1.0)
	return lerp(a, b, k * k * (3.0 - 2.0 * k))


## A camera operator's hold: a little drift so a locked-off frame still breathes.
static func breathe(t: float, size: Vector2, amount := 0.004) -> Vector2:
	return Vector2(sin(t * 0.7) * size.x, sin(t * 0.53 + 1.1) * size.y) * amount
