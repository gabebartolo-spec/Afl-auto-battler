extends RefCounted
## A finger's tap, for UI tests. emit_signal("pressed") proves the handler
## works; it can't show that a player's tap reaches the button. This one goes
## the way a phone's touch goes: a touch at the button's place on screen,
## turned into a mouse click by the engine (Project Settings > pointing), and
## routed through the window and GUI. Anything drawn over the button - a sheet,
## an overlay, the edge of a scroll - takes the tap instead, and the tap fails.
##
##   const Tap := preload("res://tests/tap.gd")
##   var why: String = await Tap.tap(button)   # "" when the button got it

## Frames to let the touch through: the engine passes it on at the next one.
const SETTLE_FRAMES := 2


## Tap c at its centre. Returns "" when c was pressed, else what went wrong.
static func tap(c: Control) -> String:
	if c == null or not is_instance_valid(c):
		return "no control"
	# The tap can close the screen the button is on; keep hold of the tree.
	var tree := c.get_tree()
	if not c.is_visible_in_tree():
		return "%s is hidden" % c.name
	# A player scrolls to a button below the fold before tapping it.
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(c)
			await tree.process_frame
			break
		p = p.get_parent()
	var at := screen_point(c)
	var win := c.get_window()
	if not Rect2(Vector2.ZERO, Vector2(win.size)).has_point(at):
		return "%s is off the screen at %s" % [c.name, str(at)]
	var hit := [false]
	var on_press := func(): hit[0] = true
	var watch := c is BaseButton
	if watch:
		(c as BaseButton).pressed.connect(on_press)
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at
		touch.pressed = down
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		for i in SETTLE_FRAMES:
			await tree.process_frame
	if watch and is_instance_valid(c):
		(c as BaseButton).pressed.disconnect(on_press)
	if not watch:
		return ""
	if hit[0]:
		return ""
	var top := win.gui_get_hovered_control()
	return "the tap on %s went to %s" % [c.name, top.name if top != null else "nothing"]


## Where c's centre is on the screen (window pixels, after stretching).
static func screen_point(c: Control) -> Vector2:
	return c.get_screen_transform() * (c.size * 0.5)
