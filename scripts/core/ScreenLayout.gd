extends Node
## Keep UI units device-independent, without stretching a 1280px desktop
## canvas onto a portrait phone. Rotation changes the layout, not the text size.

var _updating := false
## The player's screen size choice on a desktop (Options > Screen size): the
## whole interface this much bigger, for a big screen seen from across the
## room (director, 2026-10-08: the game on a 4K TV). 1.0 is Standard.
var ui_scale := 1.0
const SCREEN_SIZES := [["standard", "Standard", 1.0], ["large", "Large", 1.25], ["tv", "TV", 1.6]]
## The desktop canvas the UI is laid out for (project.godot's viewport). A
## bigger window or screen shows the game bigger, not emptier (STYLE-07).
const DESKTOP_REF := Vector2(1280, 720)


## The game's name as players see it. The project keeps its original
## config/name, because Godot keys the desktop save folder to it: renaming
## the project would strand existing careers.
const TITLE := "Aussie Rules Dynasties"


func _ready() -> void:
	_fit_first_window()
	get_window().size_changed.connect(_update_scale)
	_update_scale()
	if DisplayServer.get_name() != "headless":
		get_window().title = TITLE
	# The phone measurement (visual audit 4.8): an exported debug build shows the
	# frame time in the corner. Never in the editor, a test run or a release build.
	if OS.has_feature("template") and OS.is_debug_build():
		add_child.call_deferred(load("res://scripts/core/PerfProbe.gd").new())


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
		density = desktop_density(pixels, DisplayServer.screen_get_scale(),
				DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0)
	if OS.has_feature("web"):
		# The web canvas is sized in physical pixels by Godot's HTML shell.
		var ratio = JavaScriptBridge.eval("window.devicePixelRatio || 1")
		if ratio != null:
			density = maxf(1.0, float(ratio))
	elif OS.has_feature("android") or OS.has_feature("ios"):
		density = maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
	else:
		density *= ui_scale
	# Small desktop windows remain usable too. Below 320 UI units there is
	# no longer room for four touch targets and their position labels.
	density = minf(density, minf(pixels.x, pixels.y) / 320.0)
	var logical := Vector2i(roundi(pixels.x / density), roundi(pixels.y / density))
	if window.content_scale_size != logical:
		window.content_scale_size = logical
	_updating = false


## Godot opens its window at the project's 1280 x 720 in physical pixels:
## on a scaled Windows display (300% on a 4K screen) that is a third of the
## screen. Open it at the OS's size instead - scaled by its DPI, at most 90%
## of the screen, centred - as a native window would be.
func _fit_first_window() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_name() != "Windows":
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var os_density := float(DisplayServer.screen_get_dpi()) / 96.0
	if os_density <= 1.05:
		return
	var screen := DisplayServer.screen_get_usable_rect()
	var want := Vector2(get_window().size) * os_density
	var room := Vector2(screen.size) * 0.9
	var fit := minf(1.0, minf(room.x / want.x, room.y / want.y))
	var size := Vector2i(want * fit)
	get_window().size = size
	get_window().position = screen.position + (screen.size - size) / 2


## Desktop density: the larger of the OS's own scaling (Windows reports it
## only as DPI - screen_get_scale is 1 there - so a 4K screen at 300% read as
## 1 and drew 15-unit text at 15 physical pixels) and the fit that keeps the
## canvas no bigger than DESKTOP_REF. Never both multiplied.
static func desktop_density(pixels: Vector2, os_scale: float, dpi: int) -> float:
	var os_density := maxf(os_scale, float(dpi) / 96.0 if dpi > 0 else 1.0)
	var fit := minf(pixels.x / DESKTOP_REF.x, pixels.y / DESKTOP_REF.y)
	return maxf(1.0, maxf(os_density, fit))


## Desktop only: a phone's density already comes from its screen.
static func is_desktop() -> bool:
	return not (OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web"))


func set_screen_size(key: String) -> void:
	ui_scale = 1.0
	for row in SCREEN_SIZES:
		if str(row[0]) == key:
			ui_scale = float(row[2])
	_update_scale()


func set_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless" or not is_desktop():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on
			else DisplayServer.WINDOW_MODE_WINDOWED)


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
