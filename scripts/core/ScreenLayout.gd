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


## True when the last resize was a phone keyboard coming up or going down: a
## text field had the focus and the width in pixels did not change. Screens
## that rebuild on a resize leave themselves alone then (UiKit.keyboard_resize).
var keyboard_up := false
## The scale and pixel width of the last resize that was not a phone keyboard.
var _kept_density := 0.0
var _kept_width := 0


## True while a text field has the focus (the phone keyboard is up, or about
## to be).
func typing() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit


func _ready() -> void:
	_fit_first_window()
	get_window().size_changed.connect(_update_scale)
	_update_scale()
	if DisplayServer.get_name() != "headless":
		get_window().title = TITLE


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
	if OS.has_feature("web") or web_ratio_test > 0.0:
		# The web canvas is sized in physical pixels by Godot's HTML shell, so
		# the pixel ratio alone gives a 1440p browser a 2560-unit canvas and
		# 13-unit text. Fit it to the desktop design size as a window would be.
		density = web_density(pixels, _web_ratio())
	elif OS.has_feature("android") or OS.has_feature("ios"):
		density = maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
	else:
		density *= ui_scale
	# Small desktop windows remain usable too. Below 320 UI units there is
	# no longer room for four touch targets and their position labels.
	density = minf(density, minf(pixels.x, pixels.y) / 320.0)
	# A phone keyboard can take most of a sideways phone's height. Fitting
	# 320 units into what is left would shrink the whole screen and change
	# its width in units, and every screen would rebuild under the keyboard
	# (and free the field being typed in). Same width in pixels while a text
	# field has focus means a keyboard: keep the scale the screen had. Not on
	# a desktop, which has no such keyboard: there a window made shorter is
	# just a shorter window.
	keyboard_up = not is_desktop() and _kept_density > 0.0 			and int(pixels.x) == _kept_width and typing()
	if keyboard_up:
		density = _kept_density
	else:
		_kept_density = density
		_kept_width = int(pixels.x)
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
	# A tool run with --script sets its own window size and position (and a
	# capture is parked off-screen so it never takes the keyboard focus).
	if OS.get_cmdline_args().has("--script") or OS.get_cmdline_args().has("-s"):
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


## The widest portrait canvas, in units, a phone's browser is laid out for.
## Phones come in at 360-440 on their own pixel ratio and are left alone; a
## portrait window wider than this in pixels is zoomed to it.
const PHONE_REF_W := 480.0

## A test stands in for a browser at this devicePixelRatio (0 = a real run).
static var web_ratio_test := 0.0


## The browser's devicePixelRatio (the page caps it at 2, export_presets.cfg).
func _web_ratio() -> float:
	if web_ratio_test > 0.0:
		return web_ratio_test
	var ratio = JavaScriptBridge.eval("window.devicePixelRatio || 1")
	return maxf(1.0, float(ratio)) if ratio != null else 1.0


## Density in a browser, for a canvas of `pixels` physical pixels at the
## browser's `ratio`. The canvas is sized in physical pixels, so a 1440p
## browser at ratio 1 would draw 2560 units: 13-unit text, match sheets
## splayed across a strip. Landscape fits the desktop's 1280 x 720 as a
## desktop window does (director, 2026-10-18: "Yes, scale it"), so 3840 wide
## at ratio 3 is still ~1280 units. Portrait keeps a phone's own ratio and
## only zooms a portrait window wider than PHONE_REF_W units. Never less than
## the browser's own ratio.
static func web_density(pixels: Vector2, ratio: float) -> float:
	var own := maxf(1.0, ratio)
	if pixels.x >= pixels.y:
		return maxf(own, minf(pixels.x / DESKTOP_REF.x, pixels.y / DESKTOP_REF.y))
	return maxf(own, pixels.x / PHONE_REF_W)


## The Screen setting on a phone or in its browser: follow the phone's own
## rotation (the default), or hold portrait or landscape.
const ORIENTATIONS := [["auto", "Follow the phone"], ["portrait", "Portrait"], ["landscape", "Landscape"]]


## The engine's orientation for a saved choice. Anything unknown follows the phone.
static func orientation_for(key: String) -> int:
	match key:
		"portrait":
			return DisplayServer.SCREEN_PORTRAIT
		"landscape":
			return DisplayServer.SCREEN_LANDSCAPE
	return DisplayServer.SCREEN_SENSOR


## Hold the chosen orientation by the engine's own means. Android honours it.
## A browser only locks the screen while the page is fullscreen (the Fullscreen
## API, allowed only from a tap), so choosing Portrait or Landscape on the web
## goes fullscreen first. Safari on an iPhone has no orientation lock at all:
## there, the choice cannot hold and the phone's own rotation rules.
## Returns what was asked of the engine, for a test to read.
func set_orientation(key: String, from_tap := false) -> Dictionary:
	var asked := {"orientation": orientation_for(key), "fullscreen": false}
	if DisplayServer.get_name() == "headless" or is_desktop() and not force_web_phone:
		return asked
	if OS.has_feature("web") and key != "auto" and from_tap:
		JavaScriptBridge.eval(PAGE_FULLSCREEN_JS % key, true)
		asked["fullscreen"] = true
	DisplayServer.screen_set_orientation(asked["orientation"])
	return asked


## The whole page goes fullscreen, not the game's canvas (the engine's own
## fullscreen). The phone keyboard is raised by a text box the engine keeps
## beside the canvas; with only the canvas fullscreen that box is off the
## screen and the keyboard never opens (godotengine/godot#117342). The
## rotation is held once the page is fullscreen, as the browser requires.
const PAGE_FULLSCREEN_JS := """(function(o){
var d=document.documentElement;
function hold(){try{var p=screen.orientation&&screen.orientation.lock?screen.orientation.lock(o):null;if(p&&p.catch){p.catch(function(){});}}catch(e){}}
if(document.fullscreenElement||document.webkitFullscreenElement){hold();return;}
var ask=d.requestFullscreen||d.webkitRequestFullscreen;
if(!ask){return;}
try{var p=ask.call(d);if(p&&p.then){p.then(hold).catch(function(){});}else{hold();}}catch(e){}
})('%s');"""


## A test or capture stands in for the web build: not a desktop, not a phone.
static var force_web := false
## ...and for a phone's browser (web_android / web_ios): the web, and touch.
static var force_web_phone := false


## A phone or tablet's own OS: the close-up follows-the-ball camera belongs to
## its small screen. The web is not one: a browser on a PC is as roomy as a
## desktop, and a browser on a phone is narrow (the stacked layout).
static func is_phone() -> bool:
	return force_web_phone or OS.has_feature("android") or OS.has_feature("ios") 			or OS.has_feature("web_android") or OS.has_feature("web_ios")


## "Tap" on a phone (native or its browser), "Click" everywhere else.
static func tap_word() -> String:
	return "Tap" if is_phone() else "Click"


## LAYOUT, not platform: a roomy landscape window gets the wide layouts (side
## panels, columns, the whole ground) on desktop and web alike, because the
## screen's shape and size decide. A phone's own OS keeps its layouts. Features
## that exist only on a desktop (Exit game, the Display setting, Alt+Enter) stay
## on is_desktop(); the wide-layout checks use this.
static func roomy(w: float, h: float) -> bool:
	return not is_phone() and w >= 760.0 and w > h * 1.2


## The PC layouts (side panels, columns) for a screen of at least min_w units,
## landscape when asked. Never on a phone or its browser: a phone browser inside
## a wide frame (itch's 1280x720) would otherwise get the PC layout, cropped.
static func wide_view(w: float, h: float, min_w: float, landscape := true) -> bool:
	return not is_phone() and w >= min_w and (not landscape or w > h)


## Desktop only: a phone's density already comes from its screen.
static func is_desktop() -> bool:
	if force_web or force_web_phone:
		return false
	var on := []
	for f in ["android", "ios", "web"]:
		if OS.has_feature(f):
			on.append(f)
	return desktop_for(on)


## The platform rule on its own, so a test can ask it about a web export:
## desktop means none of android, ios or web is among the features.
static func desktop_for(features: Array) -> bool:
	return not (features.has("android") or features.has("ios") or features.has("web"))


func set_screen_size(key: String) -> void:
	ui_scale = 1.0
	for row in SCREEN_SIZES:
		if str(row[0]) == key:
			ui_scale = float(row[2])
	_update_scale()


## The window mode a desktop wants: borderless fullscreen on the current
## monitor (not exclusive: Alt+Tab and the OS scaling stay as they are), or a
## maximised window. Rendering stays at the screen's native resolution either
## way (window/dpi/allow_hidpi, canvas_items stretch: _update_scale).
static func wanted_mode(fullscreen: bool) -> int:
	return DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_MAXIMIZED


## The mode a saved settings file asks for at start: fullscreen unless the
## player chose Window.
static func start_mode(cfg: ConfigFile) -> int:
	return wanted_mode(bool(cfg.get_value("ui", "fullscreen", true)))


func set_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless" or not is_desktop():
		return
	# A tool run with --script sets its own window size: leave it alone.
	if OS.get_cmdline_args().has("--script") or OS.get_cmdline_args().has("-s"):
		return
	DisplayServer.window_set_mode(wanted_mode(on))


## Alt+Enter switches between fullscreen and window, on a desktop.
func _input(event: InputEvent) -> void:
	if not is_desktop() or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.alt_pressed 			and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		GameState.set_fullscreen(not GameState.fullscreen())


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
