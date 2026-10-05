class_name VignetteCrowd
extends RefCounted
## The crowd behind the vignettes: a stand of supporters, painted once into a
## texture and reused every frame (one draw instead of thousands, for phones).
## Rows of heads and shoulders, smaller and darker towards the back, a good share
## in the two clubs' colours (jumpers, scarves), the rest in everyday dark
## clothes and skin tones. No faces, no likenesses: a crowd at a distance.

static var _cache := {}


## The stand as a texture, w x h pixels, for two clubs' colours. Cached by size
## and colours, so a scene asks for it every frame for free.
static func stand(w: int, h: int, colours: Array, seed := 7) -> ImageTexture:
	w = maxi(8, w)
	h = maxi(8, h)
	var key := "%d|%d|%s|%d" % [w, h, str(colours), seed]
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
		var head := lerpf(1.6, 4.2, depth)
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


## Draw the stand into rect on ci, with a stir through it now and then: a few
## supporters' arms up (t: the scene's clock). Light falls from the stadium's
## lights across the top.
static func draw(ci: CanvasItem, rect: Rect2, colours: Array, t: float, seed := 7) -> void:
	if rect.size.x < 4.0 or rect.size.y < 4.0:
		return
	ci.draw_texture_rect(stand(int(rect.size.x), int(rect.size.y), colours, seed), rect, false)
	# Haze from the light towers over the far rows.
	for i in range(4):
		ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * (0.25 - 0.05 * i))),
				Color(0.85, 0.88, 1.0, 0.025), true)
	# A stir: arms up here and there, moving through the crowd.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 99
	for n in range(int(rect.size.x / 30.0)):
		var px := rng.randf() * rect.size.x
		var py := rng.randf_range(0.35, 0.95) * rect.size.y
		var phase := rng.randf() * TAU
		var up := maxf(0.0, sin(t * 2.2 + phase))
		if up > 0.6:
			var size := lerpf(1.5, 3.5, py / rect.size.y)
			var col: Color = (colours[n % colours.size()] as Array)[0] if not colours.is_empty() else Color.WHITE
			ci.draw_rect(Rect2(rect.position + Vector2(px, py - size * 2.2 * up), Vector2(size * 0.6, size * 1.6)),
					Color(col.lightened(0.15), 0.7), true)
