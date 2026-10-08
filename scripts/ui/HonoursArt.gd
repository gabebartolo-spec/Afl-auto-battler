class_name HonoursArt
extends RefCounted
## The honours artwork (premiership cup and flag, medals, trophies), read only
## through assets/honours/honours.json - never a hard-coded path. Each honour
## can carry a mask (R = the club's primary colour, G = its secondary) that
## the manifest's tint shader applies, and the flag a box its year is set in.
## Until an honour has art, its name stands in for the picture.
##
##   {"version": 1, "shader": "honours_tint.gdshader",
##    "uniforms": {"mask": "mask_tex", "primary": "primary", "secondary": "secondary"},
##    "honours": {"premiership_flag": {"png": "...", "mask": "...", "year_box": [x, y, w, h],
##                                     "size": [512, 512], "base_y": 470}, ...}}
##
## Paths are relative to assets/honours/; "mask", "year_box", "base_y",
## "shader" and "uniforms" are optional. Every picture is a square with the
## piece centred; a standing piece (cup, flag, statuette) gives "base_y", the
## pixel row its foot sits on, so a shelf stands them on one line. Medals
## have none and are centred.

const DIR := "res://assets/honours/"
const MANIFEST := DIR + "honours.json"

static var _manifest = null


static func manifest() -> Dictionary:
	if _manifest == null:
		_manifest = {}
		if FileAccess.file_exists(MANIFEST):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest


## Forget the cached manifest (tests, or art arriving mid-run).
static func reload() -> void:
	_manifest = null


static func entry(id: String) -> Dictionary:
	var e = (manifest().get("honours", {}) as Dictionary).get(id, {})
	return e if e is Dictionary else {}


## The honour's picture, if the manifest has one that loads.
static func texture(id: String) -> Texture2D:
	var png := str(entry(id).get("png", ""))
	if png == "" or not ResourceLoader.exists(DIR + png):
		return null
	return load(DIR + png) as Texture2D


static func has_art(id: String) -> bool:
	return texture(id) != null


## The honour at `height` pixels, in `club`'s colours, with `year` in the
## flag's year box. Without art, `name` stands in, at the same size.
static func view(id: String, height: float, club: String, year: int, name: String) -> Control:
	var tex := texture(id)
	if tex == null:
		return _stand_in(id, height, name)
	var e := entry(id)
	var scale := height / float(maxi(1, tex.get_height()))
	var art := TextureRect.new()
	art.name = "Art_" + id
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 512 px art drawn at 96: the mipmaps keep it from shimmering.
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var size := Vector2(round(tex.get_width() * scale), height)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.material = _tint(e, club)
	var box: Array = e.get("year_box", [])
	if year > 0 and box.size() == 4:
		var y := UiKit.lbl(str(year), maxi(8, int(float(box[3]) * scale * 0.7)), UiKit.TEXT, true)
		y.name = "Year"
		y.autowrap_mode = TextServer.AUTOWRAP_OFF
		y.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		y.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		y.position = Vector2(float(box[0]), float(box[1])) * scale
		y.size = Vector2(float(box[2]), float(box[3])) * scale
		y.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(y)
	# A standing piece's foot goes on the bottom edge (the shelf line); the
	# transparent margin under it hangs below, unseen.
	var slot := Control.new()
	slot.name = "Honour_" + id
	slot.custom_minimum_size = size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size = size
	if e.has("base_y"):
		art.position.y = (float(tex.get_height()) - float(e["base_y"])) * scale
	slot.add_child(art)
	return slot


## The tint for a masked honour, or null to show it as drawn.
static func _tint(e: Dictionary, club: String) -> Material:
	var mask_png := str(e.get("mask", ""))
	var shader_path := DIR + str(manifest().get("shader", ""))
	if mask_png == "" or not ResourceLoader.exists(DIR + mask_png) \
			or not ResourceLoader.exists(shader_path) or club == "":
		return null
	var u: Dictionary = manifest().get("uniforms", {})
	var colours := GameDB.club_colours(club)
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	m.set_shader_parameter(str(u.get("mask", "mask_tex")), load(DIR + mask_png))
	m.set_shader_parameter(str(u.get("primary", "primary")), colours[0])
	m.set_shader_parameter(str(u.get("secondary", "secondary")), colours[1])
	return m


## The honour's name in the picture's place: a square of quiet type.
static func _stand_in(id: String, height: float, name: String) -> Control:
	var l := UiKit.lbl(name, UiKit.SMALL if height < 160.0 else UiKit.H2, UiKit.MUTED, true)
	l.name = "StandIn_" + id
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(height * (0.75 if id == "premiership_flag" else 1.0), height)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
