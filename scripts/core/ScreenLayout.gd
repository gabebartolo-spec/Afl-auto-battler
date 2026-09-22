extends Node
## Keep UI units device-independent, without stretching a 1280px desktop
## canvas onto a portrait phone. Rotation changes the layout, not the text size.

var _updating := false


func _ready() -> void:
	get_window().size_changed.connect(_update_scale)
	_update_scale()


func _update_scale() -> void:
	if _updating:
		return
	_updating = true
	var window := get_window()
	var pixels := Vector2(window.size)
	if pixels.x <= 0 or pixels.y <= 0:
		_updating = false
		return
	var density := 1.0
	if DisplayServer.get_name() != "headless":
		density = maxf(1.0, DisplayServer.screen_get_scale())
	if OS.has_feature("web"):
		# The web canvas is sized in physical pixels by Godot's HTML shell.
		var ratio = JavaScriptBridge.eval("window.devicePixelRatio || 1")
		if ratio != null:
			density = maxf(1.0, float(ratio))
	elif OS.has_feature("android") or OS.has_feature("ios"):
		density = maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
	# Small desktop windows remain usable too. Below 320 UI units there is
	# no longer room for four touch targets and their position labels.
	density = minf(density, minf(pixels.x, pixels.y) / 320.0)
	var logical := Vector2i(roundi(pixels.x / density), roundi(pixels.y / density))
	if window.content_scale_size != logical:
		window.content_scale_size = logical
	_updating = false


## Insets in UI units, for notches and gesture/home-indicator areas. The OS
## returns screen coordinates; only mobile fullscreen windows need these.
func safe_insets() -> Vector4:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return Vector4.ZERO
	var window := get_window()
	var bounds := Rect2(Vector2(window.position), Vector2(window.size))
	var safe := Rect2(DisplayServer.get_display_safe_area()).intersection(bounds)
	if not safe.has_area() or not bounds.has_area():
		return Vector4.ZERO
	var scale := get_viewport().get_visible_rect().size / bounds.size
	return Vector4(
		maxf(0.0, safe.position.x - bounds.position.x) * scale.x,
		maxf(0.0, safe.position.y - bounds.position.y) * scale.y,
		maxf(0.0, bounds.end.x - safe.end.x) * scale.x,
		maxf(0.0, bounds.end.y - safe.end.y) * scale.y)
