class_name UiArt
extends RefCounted
## Rendered props that dress a screen (director, 2026-10-13: "using tripo
## models to beautify our UI and stuff, just like how we did with our club
## guernsey logos on the ladder"): one model, rendered once, shipped as a
## picture in assets/ui/models. A grey render takes a club's colour as a tint;
## the match ball is rendered in its own red and is never tinted. Decoration
## only: nothing here is game information and nothing takes a tap. Without
## the file the caller gets null and keeps what it showed before.

## Where the pictures live: <id>.png (a test points this elsewhere).
static var dir := "res://assets/ui/models"


static func texture(id: String) -> Texture2D:
	var path := "%s/%s.png" % [dir, id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## The picture `height` units tall at its own shape, or null without the file.
static func view(id: String, height: float, tint := Color.WHITE) -> TextureRect:
	var tex := texture(id)
	if tex == null:
		return null
	var t := TextureRect.new()
	t.name = "Art_" + id
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# A 3x picture drawn small: the mipmaps keep it from shimmering.
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.custom_minimum_size = Vector2(round(height * float(tex.get_width()) / float(maxi(1, tex.get_height()))), height)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = tint
	return t
