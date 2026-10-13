extends SceneTree
## godot --headless --path . --script tests/run_scroll_tests.gd
## Scrolling must not fight the player (director, 2026-10-13: the scroll bar on
## Team selection is "sticky and teleports you back up the screen when you let
## go"). Every long page is opened at 1280x720 and 390x844 and scrolled with real
## input events: a press on the scroll bar's thumb and a drag down in steps, the
## mouse wheel, a touch drag on the page, and a touch drag that starts on a
## button. After the thumb is let go the page must stay where it was, have
## followed the pointer on the way, and not have been rebuilt.

var _state: Node
var _router: Node
var _db: Node
var _checks := 0
var _last_mouse := Vector2.ZERO
var _failures: Array[String] = []
var _table: Array[String] = []

const SUITE_SEED := 2027
const SCREENS := ["selection", "list", "training", "coaching", "staff", "stats", "offseason", "season_review", "forge"]
const SIZES := [Vector2i(1280, 720), Vector2i(390, 844)]


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _settle(n := 6) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_router = root.get_node("Router")
	_db = root.get_node("GameDB")
	_state.autosave_enabled = false
	_state.save_path = "user://test_scroll.save"
	_state.settings_path = "user://test_scroll.cfg"
	_state.delete_saved_career()
	if OS.get_environment("NOEMU") != "":
		Input.set_emulate_touch_from_mouse(false)
	for size in SIZES:
		root.size = size
		await _settle()
		for key in SCREENS:
			await _screen(str(key), size)
	for size in SIZES:
		root.size = size
		await _settle()
		await _hub_round1(size)
	print("SCROLLTABLE")
	for line in _table:
		print(line)
	print("Scroll tests: %d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	quit(1 if not _failures.is_empty() else 0)


func _open(key: String) -> void:
	_state.reset()
	_state.start_season("FRE", _db.club_list("FRE"))
	_state.replay_seed = SUITE_SEED
	_state.tutorials = false
	_router.stack = []
	_router.go("main")
	await _settle()
	_router.go("hub")
	await _settle()
	_router.go(key)
	for i in range(90):
		var sc := current_scene as CanvasItem
		if sc == null or sc.modulate.a >= 0.99:
			break
		await process_frame
	await _settle(8)


func _scrollers(node: Node, out: Array) -> void:
	if node is ScrollContainer and (node as ScrollContainer).is_visible_in_tree():
		var s := node as ScrollContainer
		var bar := s.get_v_scroll_bar()
		if bar.max_value - bar.page > 40.0 and s.size.y > 80.0:
			out.append(s)
	for c in node.get_children():
		_scrollers(c, out)


func _ids(node: Node, out: Dictionary) -> void:
	out[node.get_instance_id()] = true
	for c in node.get_children():
		_ids(c, out)


func _mouse_button(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_last_mouse = pos
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await process_frame


func _mouse_move(pos: Vector2, held: bool) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	m.relative = pos - _last_mouse
	m.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_last_mouse = pos
	Input.parse_input_event(m)
	Input.flush_buffered_events()
	await process_frame


## Where the thumb sits on the bar, from the bar's own numbers.
func _thumb(bar: ScrollBar) -> Rect2:
	var r := bar.get_global_rect()
	var range_total: float = bar.max_value - bar.min_value
	var grab_h: float = maxf(r.size.y * bar.page / range_total, 48.0)
	var free: float = r.size.y - grab_h
	var span: float = range_total - bar.page
	var top: float = r.position.y + (free * (bar.value / span) if span > 0.0 else 0.0)
	return Rect2(Vector2(r.position.x, top), Vector2(r.size.x, grab_h))


func _screen(key: String, size: Vector2i) -> void:
	await _open(key)
	var scene := current_scene
	var found: Array = []
	_scrollers(scene, found)
	var tag := "%s %dx%d" % [key, size.x, size.y]
	if found.is_empty():
		_table.append("%s | no long scroller" % tag)
		return
	for si in range(found.size()):
		var sc: ScrollContainer = found[si]
		var label := "%s #%d (%s)" % [tag, si, sc.name]
		var res := []
		await _thumb_drag(sc, label, res)
		await _drift(sc, label, res)
		await _wheel(sc, label, res)
		await _touch(sc, label, res)
		await _resize(sc, label, res)
		_table.append("%s | %s" % [label, " ; ".join(res)])


func _thumb_drag(sc: ScrollContainer, label: String, res: Array) -> void:
	var bar := sc.get_v_scroll_bar()
	sc.scroll_vertical = 0
	await _settle(2)
	var before_ids := {}
	_ids(current_scene, before_ids)
	var touches := [0]
	var spy := func(ev: InputEvent): if ev is InputEventScreenTouch or ev is InputEventScreenDrag: touches[0] += 1
	sc.gui_input.connect(spy)
	var th := _thumb(bar)
	var x := th.position.x + th.size.x - 4.0
	var y := th.position.y + th.size.y * 0.5
	await _mouse_move(Vector2(x, y), false)
	await _mouse_button(Vector2(x, y), true)
	var span: float = bar.max_value - bar.page
	var free: float = bar.get_global_rect().size.y - th.size.y
	var ratio: float = span / maxf(free, 1.0)
	var worst := 0.0
	var steps := []
	var first := 0.0
	var uneven := 0.0
	var started := sc.scroll_vertical
	var dy := 0.0
	for i in range(6):
		dy += 50.0
		var target := minf(dy, free)
		await _mouse_move(Vector2(x, y + dy), true)
		await process_frame
		var want := minf(started + target * ratio, span)
		worst = maxf(worst, absf(sc.scroll_vertical - want))
		if i == 0:
			first = sc.scroll_vertical - started
		elif sc.scroll_vertical < span - 1.0 and sc.scroll_vertical < free * ratio - 1.0:
			var lag := absf((sc.scroll_vertical - started) - first * (i + 1.0))
			uneven = maxf(uneven, lag)
		steps.append("%d/%d" % [sc.scroll_vertical, int(want)])
	var held := sc.scroll_vertical
	var touch_events: int = touches[0]
	await _mouse_button(Vector2(x, y + dy), false)
	await _settle(4)
	var after := sc.scroll_vertical
	sc.gui_input.disconnect(spy)
	var after_ids := {}
	_ids(current_scene, after_ids)
	var rebuilt := false
	for k in before_ids:
		if not after_ids.has(k):
			rebuilt = true
	var moved := held > 20
	var slack := maxf(8.0, ratio * 3.0)
	# Each step of the pointer moves the page as far as the first did: no lag, no jump.
	var tracked := uneven <= maxf(8.0, first * 0.25)
	var stayed := absi(after - held) <= 1
	_check(moved, "%s: pressing the thumb and dragging moves the page (got %d)" % [label, held])
	_check(tracked, "%s: the page follows the thumb step for step (steps drift by %.0f px, first step %.0f)" % [label, uneven, first])
	_check(stayed, "%s: letting go leaves the page where it was (%d -> %d)" % [label, held, after])
	_check(not rebuilt, "%s: letting go does not rebuild the page" % label)
	res.append("touch-events-on-container=%d" % touch_events)
	res.append("grab h=%d/%d ratio=%.2f steps %s" % [int(th.size.y), int(bar.get_global_rect().size.y), ratio, " ".join(steps)])
	res.append("thumb moved=%s tracked=%s(off %.0f) stayed=%s(%d->%d) rebuilt=%s" % [moved, tracked, worst, stayed, held, after, rebuilt])
	# let go for good (a failed case may leave the bar mid-drag)
	await _mouse_button(Vector2(5, 5), false)


func _wheel(sc: ScrollContainer, label: String, res: Array) -> void:
	sc.scroll_vertical = 0
	await _settle(2)
	var at := sc.get_global_rect().get_center()
	await _mouse_move(at, false)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev.position = at
	ev.global_position = at
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await _settle(30)
	var ok := sc.scroll_vertical > 0
	_check(ok, "%s: the wheel scrolls the page (got %d)" % [label, sc.scroll_vertical])
	res.append("wheel=%s" % ok)


func _touch_event(pos: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = down
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	await process_frame


func _drag_event(pos: Vector2, rel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = pos
	d.relative = rel
	Input.parse_input_event(d)
	Input.flush_buffered_events()
	await process_frame


func _buttons(node: Node, out: Array, scroll: ScrollContainer) -> void:
	if node is BaseButton and (node as Control).is_visible_in_tree() and not node is MenuButton:
		var r := (node as Control).get_global_rect()
		var view := scroll.get_global_rect().grow(-30)
		if view.encloses(r) and r.size.x < view.size.x:
			out.append(node)
	for c in node.get_children():
		_buttons(c, out, scroll)


func _touch(sc: ScrollContainer, label: String, res: Array) -> void:
	sc.scroll_vertical = 0
	await _settle(2)
	var view := sc.get_global_rect()
	var from := Vector2(view.position.x + view.size.x * 0.5, view.position.y + view.size.y * 0.8)
	await _touch_event(from, true)
	var p := from
	for i in range(8):
		p.y -= 30.0
		await _drag_event(p, Vector2(0, -30))
	await _touch_event(p, false)
	await _settle(3)
	var plain := sc.scroll_vertical
	_check(plain > mini(100, int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page) / 2), "%s: a touch drag on the page scrolls it (got %d)" % [label, plain])
	res.append("touch=%d" % plain)
	# A drag that starts on a button scrolls and does not press it.
	sc.scroll_vertical = 0
	await _settle(2)
	var btns := []
	_buttons(sc, btns, sc)
	if btns.is_empty():
		res.append("button-drag: no button in view")
		return
	var b: BaseButton = btns[0]
	var hit := [false]
	var on_press := func(): hit[0] = true
	b.pressed.connect(on_press)
	var at: Vector2 = b.get_global_rect().get_center()
	await _touch_event(at, true)
	p = at
	for i in range(8):
		p.y -= 20.0
		await _drag_event(p, Vector2(0, -20))
	await _touch_event(p, false)
	await _settle(3)
	var dragged := sc.scroll_vertical
	b.pressed.disconnect(on_press)
	_check(dragged > mini(60, int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page) / 3), "%s: a touch drag starting on a button scrolls (got %d)" % [label, dragged])
	_check(not hit[0], "%s: a touch drag starting on a button does not press it" % label)
	res.append("button-drag=%d pressed=%s" % [dragged, hit[0]])


## Dragging the thumb while the pointer wanders off the rail onto the page, then
## letting go over whatever is there: the page stays put and nothing underneath
## is pressed or rebuilt.
func _drift(sc: ScrollContainer, label: String, res: Array) -> void:
	var bar := sc.get_v_scroll_bar()
	sc.scroll_vertical = 0
	await _settle(2)
	var pressed := [0]
	var watch := []
	_press_watch(sc, pressed, watch)
	var before_ids := {}
	_ids(current_scene, before_ids)
	var th := _thumb(bar)
	var x := th.position.x + th.size.x - 4.0
	var y := th.position.y + th.size.y * 0.5
	await _mouse_move(Vector2(x, y), false)
	await _mouse_button(Vector2(x, y), true)
	var dy := 0.0
	for i in range(6):
		dy += 40.0
		await _mouse_move(Vector2(x - 25.0 * (i + 1), y + dy), true)
	var held := sc.scroll_vertical
	await _mouse_button(Vector2(x - 150.0, y + dy), false)
	await _settle(4)
	var after := sc.scroll_vertical
	var after_ids := {}
	_ids(current_scene, after_ids)
	var rebuilt := false
	for k in before_ids:
		if not after_ids.has(k):
			rebuilt = true
	for pair in watch:
		if is_instance_valid(pair[0]):
			(pair[0] as BaseButton).pressed.disconnect(pair[1])
	_check(held > 20, "%s: dragging the thumb with the pointer off the rail still scrolls (got %d)" % [label, held])
	_check(absi(after - held) <= 1, "%s: letting go off the rail leaves the page where it was (%d -> %d)" % [label, held, after])
	_check(not rebuilt and pressed[0] == 0, "%s: letting go over the page presses and rebuilds nothing (pressed %d)" % [label, pressed[0]])
	res.append("drift held=%d after=%d pressed=%d rebuilt=%s" % [held, after, pressed[0], rebuilt])
	await _mouse_button(Vector2(5, 5), false)


func _press_watch(node: Node, pressed: Array, watch: Array) -> void:
	if node is BaseButton:
		var f := func(): pressed[0] += 1
		(node as BaseButton).pressed.connect(f)
		watch.append([node, f])
	for c in node.get_children():
		_press_watch(c, pressed, watch)


## The window reporting its size twice in a row (a browser does this) while the
## page is scrolled: the page is rebuilt or not, but the player keeps their place.
func _resize(sc: ScrollContainer, label: String, res: Array) -> void:
	var scene := current_scene
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value * 0.4)
	await _settle(3)
	var want := sc.scroll_vertical
	root.size_changed.emit()
	root.size_changed.emit()
	await _settle(40)
	# the scroller may have been rebuilt: find the long one again
	var again: Array = []
	_scrollers(scene, again)
	var got := -1
	if not again.is_empty():
		var best: ScrollContainer = again[0]
		for c in again:
			if absi((c as ScrollContainer).scroll_vertical - want) < absi(best.scroll_vertical - want):
				best = c
		got = best.scroll_vertical
	_check(absi(got - want) <= 2, "%s: two resize reports in a row keep the player's place (%d -> %d)" % [label, want, got])
	var seen := []
	for c in again:
		seen.append("%d/%d" % [(c as ScrollContainer).scroll_vertical, int((c as ScrollContainer).get_v_scroll_bar().max_value - (c as ScrollContainer).get_v_scroll_bar().page)])
	res.append("resize %d->%d (%s)" % [want, got, " ".join(seen)])


## The hub before Round 1 (a contract card on the page, the whole ladder
## below): every part is reachable by scrolling and ends fully inside the
## visible page, and the card's answer takes a real tap at its position.
func _hub_round1(size: Vector2i) -> void:
	var tag := "hub round 1 %dx%d" % [size.x, size.y]
	_state.reset()
	_state.start_season("WBD", _db.club_list("WBD"))
	_state.replay_seed = SUITE_SEED
	_state.tutorials = false
	_router.stack = []
	_router.go("main")
	await _settle()
	var p: Dictionary = _db.club_list("WBD")[0]
	var card: Dictionary = _state.story_card("contracts_wants_to_extend", p)
	_check(not card.is_empty(), "%s: the contract card builds" % tag)
	_state.week_events = [card]
	_router.go("hub")
	for i in range(90):
		var cs := current_scene as CanvasItem
		if cs == null or cs.modulate.a >= 0.99:
			break
		await process_frame
	await _settle(8)
	var hub := current_scene
	var found: Array = []
	_scrollers(hub, found)
	_check(not found.is_empty(), "%s: the page scrolls" % tag)
	if found.is_empty():
		return
	var sc: ScrollContainer = found[0]
	var bar := sc.get_v_scroll_bar()
	# The week's opponent line before a game: last year's finish or nothing,
	# never "no games yet" or a form.
	var opp: Label = hub.find_child("OppFormLine", true, false)
	_check(opp == null or (not opp.text.contains("no games yet") and not opp.text.contains("Form")
			and not opp.text.contains("on the ladder")), "%s: no ladder spot or form before a game (%s)" % [tag, opp.text if opp else "-"])
	var ev: Control = hub.find_child("WeekEvent", true, false)
	_check(ev != null, "%s: the card is on the hub" % tag)
	if ev != null:
		var view := sc.get_global_rect()
		_check(ev.get_global_rect().size.y <= view.size.y, "%s: the card is shorter than the page (%d v %d)" % [tag, ev.size.y, view.size.y])
		# Scroll to the card, then it sits wholly inside the visible page.
		sc.scroll_vertical = int(ev.get_global_rect().position.y - sc.get_global_rect().position.y + sc.scroll_vertical - 8)
		await _settle(3)
		if OS.get_environment("HUBSHOT") != "":
			get_root().get_viewport().get_texture().get_image().save_png("%s_%s_%dx%d.png" % [OS.get_environment("HUBSHOT"), "card", size.x, size.y])
		var r := ev.get_global_rect()
		_check(view.grow(1).encloses(r), "%s: the card is fully inside the page once scrolled to (%s in %s)" % [tag, r, view])
		# A real tap on its second answer, where the finger lands.
		var b: Control = ev.find_child("Event_1", true, false)
		_check(b != null and view.encloses(b.get_global_rect()), "%s: the answer is inside the page" % tag)
		if b != null:
			var at := b.get_global_rect().get_center()
			await _mouse_button(at, true)
			await _mouse_button(at, false)
			await _settle(4)
			_check(bool((_state.week_events[0] as Dictionary).get("resolved", false)),
					"%s: a real tap on the card's answer answers it" % tag)
	# At the end of the page the last ladder row is wholly visible.
	# (The answer rebuilt the page: take the new one.)
	# (The answer rebuilt the page: take the new one; a page that now fits has
	# nothing to scroll and its last row is in view as it stands.)
	var pages: Array = hub.find_children("*", "ScrollContainer", true, false)
	_check(not pages.is_empty(), "%s: the page is still there after the answer" % tag)
	if pages.is_empty():
		return
	sc = pages[0]
	bar = sc.get_v_scroll_bar()
	sc.scroll_vertical = int(bar.max_value)
	await _settle(4)
	var lad: Control = hub.find_child("LadderSection", true, false)
	_check(lad != null, "%s: the ladder is on the hub" % tag)
	if lad != null:
		var last_row: Control = null
		var stack: Array = [lad]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if n is VBoxContainer and (n as Control).get_child_count() >= 18 and n != lad:
				last_row = (n as Control).get_child((n as Control).get_child_count() - 1)
		_check(last_row != null, "%s: found the ladder's rows" % tag)
		if last_row != null:
			var view2 := sc.get_global_rect()
			_check(view2.grow(1).encloses(last_row.get_global_rect()),
					"%s: the last ladder row is fully inside the page at the end (%s in %s)" % [tag, last_row.get_global_rect(), view2])
	if OS.get_environment("HUBSHOT") != "":
		get_root().get_viewport().get_texture().get_image().save_png("%s_%s_%dx%d.png" % [OS.get_environment("HUBSHOT"), "end", size.x, size.y])
