class_name VignetteCrowd
extends RefCounted
## The crowd behind the vignettes: a stand of supporters, painted once into a
## texture and reused every frame (one draw instead of thousands, for phones).
## Rows of heads and shoulders, smaller and darker towards the back, a good share
## in the two clubs' colours (jumpers, scarves), the rest in everyday dark
## clothes and skin tones. No faces, no likenesses: a crowd at a distance.

static var _cache := {}


## Seats in rows, every row the same size: the texture VignetteGround lays along its
## stands, where the camera's perspective makes the far rows small. SEAT_COLS seats
## across and SEAT_ROWS rows down, a person in most seats (in the clubs' colours or
## everyday clothes), the odd one standing, the odd seat empty, stairs every so often.
## A flag or scarf held up here and there in a club's colours.
const SEAT_COLS := 64
const SEAT_ROWS := 36
const SEAT_PX := Vector2i(16, 14)

static func seats(colours: Array, seed := 7) -> ImageTexture:
	var key := "seats|%s|%d" % [str(colours), seed]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 8:
		_cache.clear()
	var w := SEAT_COLS * SEAT_PX.x
	var h := SEAT_ROWS * SEAT_PX.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.07, 0.085))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var skins := [Color(0.85, 0.68, 0.55), Color(0.72, 0.53, 0.4), Color(0.55, 0.38, 0.27), Color(0.36, 0.24, 0.17)]
	var plain := [Color(0.16, 0.16, 0.18), Color(0.24, 0.24, 0.27), Color(0.3, 0.27, 0.24), Color(0.4, 0.4, 0.42), Color(0.5, 0.48, 0.45)]
	var club := []
	for c in colours:
		if c is Array and not (c as Array).is_empty():
			club.append((c as Array)[0])
			if (c as Array).size() > 1:
				club.append((c as Array)[1])
	for r in range(SEAT_ROWS):
		var y := r * SEAT_PX.y
		# The row's step: a lighter lip of concrete under each row.
		img.fill_rect(Rect2i(0, y + SEAT_PX.y - 2, w, 2), Color(0.13, 0.13, 0.15))
		for c in range(SEAT_COLS):
			var x := c * SEAT_PX.x
			if c % 16 == 7:
				img.fill_rect(Rect2i(x, y, SEAT_PX.x, SEAT_PX.y), Color(0.16, 0.16, 0.18))   # the stairs
				continue
			if rng.randf() < 0.07:
				continue                                  # an empty seat
			var body: Color = club[rng.randi() % club.size()] if not club.is_empty() and rng.randf() < 0.5 \
					else plain[rng.randi() % plain.size()]
			var skin: Color = skins[rng.randi() % skins.size()]
			var dx := rng.randi_range(-2, 2)
			var stand_up := rng.randf() < 0.08
			var top := y + (0 if stand_up else 3)
			img.fill_rect(Rect2i(x + 3 + dx, top + 5, 10, SEAT_PX.y - 6 - (top - y)), body)          # shoulders
			img.fill_rect(Rect2i(x + 5 + dx, top, 6, 6), skin.darkened(0.15))                          # head
			if rng.randf() < 0.45:
				img.fill_rect(Rect2i(x + 5 + dx, top, 6, 2), Color(0.12, 0.1, 0.09))                    # hair or a beanie
			if not club.is_empty() and rng.randf() < 0.04:
				# A flag or a scarf held up.
				var flag: Color = club[rng.randi() % club.size()]
				img.fill_rect(Rect2i(x + 10 + dx, maxi(0, y - 6), 7, 6), flag)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The stand as a texture for two clubs' colours, painted once at a fixed size and
## stretched to fit: as a camera zooms the stand only scales, it never repaints
## (repainting at each new size reshuffled the whole crowd every frame).
const STAND_W := 512
const STAND_H := 160

static func stand(colours: Array, seed := 7) -> ImageTexture:
	var w := STAND_W
	var h := STAND_H
	var key := "%s|%d" % [str(colours), seed]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 8:
		_cache.clear()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.06, 0.06, 0.07))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var skins := [Color(0.85, 0.68, 0.55), Color(0.72, 0.53, 0.4), Color(0.55, 0.38, 0.27), Color(0.36, 0.24, 0.17)]
	var plain := [Color(0.16, 0.16, 0.18), Color(0.24, 0.24, 0.27), Color(0.3, 0.27, 0.24), Color(0.38, 0.38, 0.4)]
	var club := []
	for c in colours:
		if c is Array and not (c as Array).is_empty():
			club.append((c as Array)[0])
			if (c as Array).size() > 1:
				club.append((c as Array)[1])
	# Back rows first; each row a little bigger and lighter than the one behind.
	var y := 1.0
	var row := 0
	while y < h:
		var depth := y / float(h)                    # 0 at the back, 1 at the front
		var head := lerpf(1.2, 3.0, depth)
		var pitch := head * 2.3
		# Kept well under the players: the stand sits back, softer and darker than the play.
		var light := lerpf(0.35, 0.7, depth)
		var x := -rng.randf() * pitch
		while x < w:
			if rng.randf() < 0.9:                     # the odd empty seat
				var body: Color = club[rng.randi() % club.size()] if not club.is_empty() and rng.randf() < 0.45 \
						else plain[rng.randi() % plain.size()]
				var skin: Color = skins[rng.randi() % skins.size()]
				var bx := int(x + rng.randf_range(-0.4, 0.4) * head)
				var by := int(y + rng.randf_range(-0.3, 0.3) * head)
				var haze := Color(0.12, 0.13, 0.16)
				img.fill_rect(Rect2i(bx - int(head * 0.95), by + int(head * 0.7), int(head * 1.9) + 1, int(head * 1.6) + 1),
						body.lerp(haze, 0.35).darkened(1.0 - light))
				img.fill_rect(Rect2i(bx - int(head * 0.55), by - int(head * 0.5), int(head * 1.1) + 1, int(head * 1.2) + 1),
						skin.lerp(haze, 0.4).darkened(1.0 - light * 0.9))
			x += pitch * rng.randf_range(0.85, 1.15)
		y += head * 2.1
		row += 1
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Draw the stand into rect on ci. Now and then a supporter stands with an arm up
## and sits again, slowly (t: the scene's clock) - a few at a time, not a shimmer.
static func draw(ci: CanvasItem, rect: Rect2, colours: Array, t: float, seed := 7) -> void:
	if rect.size.x < 4.0 or rect.size.y < 4.0:
		return
	ci.draw_texture_rect(stand(colours, seed), rect, false)
	# Haze from the light towers over the far rows.
	for i in range(4):
		ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * (0.25 - 0.05 * i))),
				Color(0.85, 0.88, 1.0, 0.025), true)
	# A stir: arms up here and there, moving through the crowd.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 99
	# Counted and sized by the stand's shape and height, not the screen's pixels: when a
	# camera zooms the stand, the same people stay in their seats, only larger.
	var unit := rect.size.y / 190.0
	for n in range(maxi(3, int(rect.size.x / rect.size.y * 2.7))):
		var px := rng.randf() * rect.size.x
		var py := rng.randf_range(0.45, 0.95) * rect.size.y
		var phase := rng.randf() * TAU
		# Up for about a second in every five, easing up and down.
		var up := smoothstep(0.75, 0.95, sin(t * 1.2 + phase))
		if up > 0.0:
			var size := lerpf(1.2, 2.6, py / rect.size.y) * unit
			var col: Color = (colours[n % colours.size()] as Array)[0] if not colours.is_empty() else Color.WHITE
			ci.draw_rect(Rect2(rect.position + Vector2(px, py - size * 2.0 * up), Vector2(size * 0.6, size * 1.4)),
					Color(col.darkened(0.3), 0.6 * up), true)
