extends SceneTree
## godot --headless --path . --script tests/run_back_nav_tests.gd
## Back, everywhere (director, 2026-10-12: "check the back button works on all
## screens on PC"). Every screen is opened the way a player gets to it, at
## 1280x720, and left four ways: a real mouse click on its on-screen Back
## control, the Escape key, the mouse's back button and the Android back
## request. Each must land on the screen before it, with exactly one step
## taken off the router's stack and nothing lost on the way. Overlays on a
## screen (sheets, popups) must close first, leaving the screen as it was.
## Classes are reached through load() and autoload nodes (a --script runner
## compiles before the autoloads exist).

var _state: Node
var _router: Node
var _db: Node
var _checks := 0
var _failures: Array[String] = []
## One line per screen and way out, for the PR's table.
var _table: Array[String] = []

const SUITE_SEED := 2027


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
	_state.save_path = "user://test_back_nav.save"
	_state.settings_path = "user://test_back_nav.cfg"
	_state.replay_seed = SUITE_SEED
	_state.delete_saved_career()
	root.size = Vector2i(1280, 720)
	await _settle()

	await _screens()
	await _overlays()
	await _main_menu()
	await _draft()
	await _match()
	await _crawl()

	print("BACKTABLE")
	for line in _table:
		print(line)
	print("Back navigation tests: %d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	quit(1 if not _failures.is_empty() else 0)


# ---------------------------------------------------------------------------
# Ways out
# ---------------------------------------------------------------------------
const WAYS := ["click", "escape", "mouse_back", "android"]


## A mouse click at the control's centre, through the window the way a mouse
## goes. Returns "" when the control got it.
func _click(c: Control) -> String:
	if c == null or not is_instance_valid(c):
		return "no control"
	if not c.is_visible_in_tree():
		return "%s is hidden" % c.name
	var at: Vector2 = c.get_screen_transform() * (c.size * 0.5)
	if not Rect2(Vector2.ZERO, Vector2(c.get_window().size)).has_point(at):
		return "%s is off the screen" % c.name
	var hit := [false]
	var watch := c is BaseButton
	var on_press := func(): hit[0] = true
	if watch:
		(c as BaseButton).pressed.connect(on_press)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.global_position = at
		ev.pressed = down
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await process_frame
		await process_frame
	if watch and is_instance_valid(c):
		(c as BaseButton).pressed.disconnect(on_press)
	if watch and not hit[0]:
		var top := root.gui_get_hovered_control()
		return "the click on %s (at %s, rect %s) went to %s" % [c.name, str(at), str(c.get_global_rect()), top.name if top != null else "nothing"]
	return ""


func _key_escape() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await process_frame


func _mouse_back() -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_XBUTTON1
		ev.position = Vector2(640, 360)
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await process_frame


## Leave by `way`. `back_btn` is the on-screen Back control for "click".
func _leave(way: String, back_btn: Control) -> String:
	match way:
		"click":
			return await _click(back_btn)
		"escape":
			await _key_escape()
		"mouse_back":
			await _mouse_back()
		"android":
			_router.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	return ""


# ---------------------------------------------------------------------------
# Screens: each one, reached from the hub, left four ways
# ---------------------------------------------------------------------------
## [router key, what to prepare, the screen Back should land on]
const SCREENS := [
	["list", "", "hub"],
	["training", "", "hub"],
	["coaching", "", "hub"],
	["staff", "", "hub"],
	["stats", "", "hub"],
	["selection", "", "hub"],
	["offseason", "", "hub"],
	["season_review", "", "hub"],
	["forge", "", "hub"],
]


func _fresh_career() -> void:
	_state.reset()
	_state.start_season("COL", _db.club_list("COL"))
	_state.replay_seed = SUITE_SEED


## Put the router where a player would be: main menu, hub, then `key`.
func _open(key: String) -> void:
	_router.stack = []
	_router.go("main")
	await _settle()
	_router.go("hub")
	await _settle()
	if key != "hub":
		_router.go(key)
		await _settle()


func _fingerprint() -> String:
	# What a screen's Back must not change: the season's place and the club.
	var s = _state.season
	return "%s|%s|%s" % [str(s.round_index) if s != null else "-", str(_state.my_club), str(_state.season_year)]


func _screens() -> void:
	for row in SCREENS:
		var key := str(row[0])
		var expect := str(row[2])
		for way in WAYS:
			_fresh_career()
			await _open(key)
			var scene := current_scene
			var before := _fingerprint()
			var depth: int = (_router.stack as Array).size()
			var on_screen: bool = _router.current() == key
			_check(on_screen, "%s opens from the hub (%s)" % [key, way])
			if not on_screen:
				_table.append("%s | %s | did not open" % [key, way])
				continue
			await _settle(3)
			var btn: Control = scene.find_child("TopBarBack", true, false)
			if way == "click":
				_check(btn != null, "%s has an on-screen Back control" % key)
			var why: String = await _leave(way, btn)
			await _settle(10)
			var now: String = _router.current()
			var stack: Array = _router.stack
			var ok: bool = why == "" and now == expect and stack.size() == depth - 1 and _no_duplicate_tail(stack) \
					and current_scene != null and is_instance_valid(current_scene) and current_scene != scene \
					and _fingerprint() == before
			_check(ok, "%s: Back by %s returns to %s (%s; now %s, stack %s)" % [key, way, expect, why, now, str(stack)])
			_table.append("%s | %s | %s" % [key, way, "ok" if ok else "FAIL %s now=%s stack=%s" % [why, now, str(stack)]])


func _no_duplicate_tail(stack: Array) -> bool:
	return stack.size() < 2 or str(stack[stack.size() - 1]) != str(stack[stack.size() - 2])


## The Controls under `scene`, by instance id: before an overlay opens, so its
## roots (the new ones whose parent is not new) can be found after.
func _control_ids(scene: Node) -> Dictionary:
	var d := {}
	for c in scene.find_children("*", "Control", true, false):
		d[c.get_instance_id()] = true
	return d


func _new_roots(scene: Node, before: Dictionary) -> Array:
	# An overlay is a new full-screen Control sitting directly on the screen
	# (modal_box); content a screen rebuilds inside itself is not one.
	var out := []
	var win := Vector2(scene.get_window().size)
	for c in scene.find_children("*", "Control", true, false):
		if before.has(c.get_instance_id()):
			continue
		if c.get_parent() != scene:
			continue
		if c.is_queued_for_deletion() or not c.is_visible_in_tree():
			continue
		var r: Rect2 = (c as Control).get_global_rect()
		if r.size.x >= win.x * 0.6 and r.size.y >= win.y * 0.6:
			out.append(c)
	return out


func _alive(roots: Array) -> bool:
	for r in roots:
		if is_instance_valid(r) and r.is_inside_tree() and not r.is_queued_for_deletion() and r.is_visible_in_tree():
			return true
	return false


## The overlay's own way out on screen: a visible Back / Close / Done / Cancel.
func _closer(roots: Array) -> Button:
	for r in roots:
		if not is_instance_valid(r):
			continue
		for b in r.find_children("*", "Button", true, false):
			var t := str((b as Button).text).strip_edges()
			if (b as Button).is_visible_in_tree() and ["Close", "Done", "Back", "Cancel", "Not now", "Back to your calls", "Back to hub", "OK", "Skip", "Got it", "Continue", "Start"].has(t):
				return b
	return null


## One overlay, left four ways. After the first step back the screen is still
## there as it was; one more Escape then leaves it for the screen before.
func _overlay_case(label: String, key: String, opener: Callable, prep := Callable()) -> void:
	for way in WAYS:
		_fresh_career()
		if prep.is_valid():
			prep.call()
		await _open(key)
		var scene := current_scene
		await _settle(3)
		var ids := _control_ids(scene)
		var depth: int = (_router.stack as Array).size()
		await opener.call(scene)
		await _settle(8)
		var roots := _new_roots(scene, ids)
		var opened := _alive(roots)
		_check(opened, "%s: the overlay opens (%s)" % [label, way])
		if not opened:
			var fresh := []
			for c in scene.find_children("*", "Control", true, false):
				if not ids.has(c.get_instance_id()):
					fresh.append("%s(%s vis=%s)" % [c.name, c.get_class(), str(c.is_visible_in_tree())])
			print("DBG %s new controls: %s | scene %s | current %s" % [label, str(fresh.slice(0, 8)), str(scene.name), str(current_scene.name)])
			_table.append("%s | %s | did not open" % [label, way])
			continue
		var before := _fingerprint()
		var closer := _closer(roots)
		if way == "click":
			_check(closer != null, "%s: the overlay has an on-screen way out" % label)
		var why: String = await _leave(way, closer)
		await _settle(8)
		var closed := not _alive(roots)
		var same: bool = _router.current() == key and (_router.stack as Array).size() == depth and current_scene == scene
		var ok: bool = why == "" and closed and same and _fingerprint() == before
		_check(ok, "%s: Back by %s closes it and stays on %s (%s; closed %s, now %s)" % [label, way, key, why, str(closed), _router.current()])
		var line := "ok" if ok else "FAIL %s closed=%s now=%s stack=%s" % [why, str(closed), _router.current(), str(_router.stack)]
		# Then one more step goes to the screen before, once.
		if ok and way == "escape":
			await _key_escape()
			await _settle(10)
			var before_key := "main" if key == "hub" else "hub"
			var left: bool = _router.current() == before_key and (_router.stack as Array).size() == depth - 1
			_check(left, "%s: the next Back leaves %s for %s, one step (now %s)" % [label, key, before_key, _router.current()])
			if not left:
				line += " | second Back FAIL now=%s" % _router.current()
		_table.append("%s | %s | %s" % [label, way, line])


func _first_player_id() -> String:
	for p in _db.club_list("COL"):
		return str(p["id"])
	return ""


func _click_named(scene: Node, node_name: String) -> String:
	return await _click(scene.find_child(node_name, true, false))


func _overlays() -> void:
	var pid := _first_player_id()
	await _overlay_case("hub: settings sheet", "hub", func(s): await _click_named(s, "HubSettings"))
	await _overlay_case("hub: news", "hub", func(s): s.call("_show_news"))
	await _overlay_case("hub: quick sim", "hub", func(s): s.call("_open_quick_sim"))
	await _overlay_case("hub: results popup", "hub", func(s): s.call("_on_sim_round"))
	await _overlay_case("list: player profile", "list", func(s): s.call("_open_profile", pid))
	await _overlay_case("list: captaincy sheet", "list", func(s): s.call("_open_captaincy"))
	await _overlay_case("training: stat guide", "training", func(s): await _click_named(s, "StatGuideButton"))
	await _overlay_case("training: first-visit intro", "training", func(s): s.call("_show_intro"),
			func(): _state.set_setting("seen_training_intro", false))
	await _overlay_case("stats: first-visit intro", "stats", func(s): s.call("_show_intro"))
	await _overlay_case("selection: team report", "selection", func(s): s.call("_show_report", "MEL"))
	await _overlay_case("selection: synergies", "selection", func(s): s.call("_show_synergies"))
	await _overlay_case("selection: plan", "selection", func(s): s.call("_show_plan"))
	await _overlay_case("selection: player profile", "selection", func(s): s.call("_open_profile", pid))
	await _overlay_case("offseason: talks", "offseason", func(s): s.call("_open_talks", pid))
	await _overlay_case("season review: awards program", "season_review", func(s): s.call("_open_awards_program"),
			func(): _state.season_awards = {"year": 2026, "brownlow": []})


# ---------------------------------------------------------------------------
# Main menu: its sheets, then a lone Back does nothing and never quits
# ---------------------------------------------------------------------------
func _main_menu() -> void:
	for opener in ["MenuSettings", "MenuHelp"]:
		for way in WAYS:
			_state.reset()
			_router.stack = []
			_router.go("main")
			await _settle()
			var scene := current_scene
			var ids := _control_ids(scene)
			await _click_named(scene, opener)
			await _settle(8)
			var roots := _new_roots(scene, ids)
			var label := "main menu: %s" % opener
			var opened := _alive(roots)
			_check(opened, "%s opens (%s)" % [label, way])
			if not opened:
				_table.append("%s | %s | did not open" % [label, way])
				continue
			var closer := _closer(roots)
			if way == "click":
				_check(closer != null, "%s has an on-screen way out" % label)
			var why: String = await _leave(way, closer)
			await _settle(8)
			var ok: bool = why == "" and not _alive(roots) and _router.current() == "main" and current_scene == scene
			_check(ok, "%s: Back by %s closes it and stays on the menu (%s)" % [label, way, why])
			var line := "ok" if ok else "FAIL %s now=%s" % [why, _router.current()]
			# With nothing open, another Back on the menu does nothing (no quit, no dead end).
			if ok and way == "escape":
				await _key_escape()
				await _settle(6)
				var still: bool = _router.current() == "main" and current_scene == scene
				_check(still, "%s: Escape on the bare menu stays put" % label)
				if not still:
					line += " | bare menu Escape FAIL"
			_table.append("%s | %s | %s" % [label, way, line])


# ---------------------------------------------------------------------------
# Draft: Back to the menu (it replaces, so the stack stays one deep)
# ---------------------------------------------------------------------------
func _draft() -> void:
	for way in WAYS:
		_state.reset()
		_router.stack = []
		_router.go("main")
		await _settle()
		_router.go("draft")
		await _settle(8)
		var scene := current_scene
		var btn: Control = scene.find_child("BackToMenu", true, false)
		if way == "click":
			_check(btn != null, "draft has an on-screen Back control")
		var why: String = await _leave(way, btn)
		await _settle(10)
		var ok: bool = why == "" and _router.current() == "main" and (_router.stack as Array).size() == 1 and current_scene != scene
		_check(ok, "draft: Back by %s returns to the menu (%s; now %s, stack %s)" % [way, why, _router.current(), str(_router.stack)])
		_table.append("draft | %s | %s" % [way, "ok" if ok else "FAIL %s now=%s stack=%s" % [why, _router.current(), str(_router.stack)]])


# ---------------------------------------------------------------------------
# Match day: a live match refuses to be left half way (by design) but its
# sheets close, and full time leaves cleanly
# ---------------------------------------------------------------------------
func _to_break() -> bool:
	for i in range(40):
		var m := current_scene
		if m.find_child("CoachBox", true, false) != null:
			# The first call box (before the bounce) has no Match stats yet: play on.
			if m.find_child("BreakStats", true, false) != null:
				return true
			var go: Button = m.find_child("StartQuarter", true, false)
			if go != null:
				go.emit_signal("pressed")
		var card = m.find_child("MomentCard", true, false)
		if card != null:
			var pick: Button = card.find_child("Moment_0", true, false)
			if pick != null:
				pick.emit_signal("pressed")
		elif m.get("_pitch") != null:
			(m.get("_pitch") as Node).call("skip_to_end")
		await _settle(8)
	return current_scene.find_child("BreakStats", true, false) != null


func _live_match() -> bool:
	_fresh_career()
	if not _state.prepare_interactive_match():
		return false
	_router.stack = []
	_router.go("main")
	await _settle()
	_router.go("hub")
	await _settle()
	_router.go("match")
	await _settle(8)
	return true


func _match() -> void:
	# Break: Match stats opens from the break and every way out closes it.
	for way in WAYS:
		_check(await _live_match(), "a live match is prepared (%s)" % way)
		var m := current_scene
		var at_break: bool = await _to_break()
		_check(at_break, "the match reaches a break (%s)" % way)
		if not at_break:
			_table.append("match break: Match stats | %s | no break reached" % way)
			continue
		var ids := _control_ids(m)
		var clicked: String = await _click_named(m, "BreakStats")
		await _settle(8)
		var roots := _new_roots(m, ids)
		_check(_alive(roots), "Match stats opens from the break (%s: %s)" % [way, clicked])
		var closer := _closer(roots)
		if way == "click":
			_check(closer != null, "Match stats has an on-screen way out")
		var why: String = await _leave(way, closer)
		await _settle(8)
		var ok: bool = why == "" and not _alive(roots) and _router.current() == "match" and m.find_child("CoachBox", true, false) != null
		_check(ok, "match break: Back by %s closes Match stats and keeps the break (%s)" % [way, why])
		_table.append("match break: Match stats | %s | %s" % [way, "ok" if ok else "FAIL %s now=%s" % [why, _router.current()]])
	# Break with nothing open: Back is refused (a live match is not left half way) with a hint.
	for way in ["escape", "mouse_back", "android"]:
		_check(await _live_match(), "a live match is prepared (%s)" % way)
		var m2 := current_scene
		await _to_break()
		var depth: int = (_router.stack as Array).size()
		await _leave(way, null)
		await _settle(8)
		var stays: bool = _router.current() == "match" and (_router.stack as Array).size() == depth and current_scene == m2
		_check(stays, "a live match is not left by %s" % way)
		var hint := m2.find_child("Hint", true, false)
		var note := "ok, stays, hint shown" if hint != null else "ok, stays, NO HINT SHOWN"
		_table.append("match break: bare Back (refused by design) | %s | %s" % [way, note if stays else "FAIL left the match"])
	# Full time: Continue and every Back lands on the hub, one step.
	for way in WAYS:
		_check(await _live_match(), "a live match is prepared (%s)" % way)
		var m3 := current_scene
		m3.call("_on_skip")
		var cont: Control = null
		for i in range(40):
			await _settle(6)
			cont = m3.find_child("FullTimeContinue", true, false)
			if cont != null:
				break
		_check(cont != null, "full time shows Continue (%s)" % way)
		if cont == null:
			_table.append("match full time | %s | no full time reached" % way)
			continue
		var depth3: int = (_router.stack as Array).size()
		var vignette: Node = root.find_child("FarewellVignette", true, false)
		if way == "click" and vignette != null:
			# A tap skips a farewell; then Continue is clear.
			await _click(vignette as Control)
			await _settle(30)
		var why3: String = await _leave(way, cont)
		await _settle(10)
		var left_over: bool = root.find_child("FarewellVignette", true, false) != null and _router.current() == "hub"
		var ok3: bool = why3 == "" and _router.current() == "hub" and (_router.stack as Array).size() == depth3 - 1 and not left_over
		_check(ok3, "match full time: Back by %s returns to the hub (%s; now %s)" % [way, why3, _router.current()])
		_table.append("match full time | %s | %s" % [way, "ok" if ok3 else "FAIL %s now=%s stack=%s" % [why3, _router.current(), str(_router.stack)]])


# ---------------------------------------------------------------------------
# Crawl: click a spread of each screen's own buttons; whatever opens over the
# screen must close with Escape and with its own Close, leaving the screen as
# it was (this finds the sheets and popups nobody listed above)
# ---------------------------------------------------------------------------
const CRAWL_SCREENS := ["hub", "list", "training", "coaching", "staff", "stats", "selection", "offseason", "season_review"]
const CRAWL_PER_SCREEN := 9


func _crawl_buttons(scene: Node) -> Array:
	var out := []
	for b in scene.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and str(b.name) != "TopBarBack" and b.size.x > 4.0 and b.size.y > 4.0:
			out.append(b)
	return out


func _crawl() -> void:
	for key in CRAWL_SCREENS:
		_fresh_career()
		await _open(key)
		var count: int = _crawl_buttons(current_scene).size()
		var picks := []
		if count > 0:
			var step := maxf(1.0, float(count) / float(CRAWL_PER_SCREEN))
			var at := 0.0
			while int(at) < count and picks.size() < CRAWL_PER_SCREEN:
				picks.append(int(at))
				at += step
		for idx in picks:
			var opened_label := ""
			for way in ["escape", "close"]:
				if way == "close" and opened_label == "":
					break
				_fresh_career()
				await _open(key)
				await _settle(3)
				var scene := current_scene
				var buttons := _crawl_buttons(scene)
				if idx >= buttons.size():
					break
				var btn: Button = buttons[idx]
				var label := "%s > %s" % [key, str(btn.text).strip_edges().left(24) if str(btn.text).strip_edges() != "" else str(btn.name)]
				var ids := _control_ids(scene)
				var depth: int = (_router.stack as Array).size()
				var before := _fingerprint()
				await _click(btn)
				await _settle(8)
				if _router.current() != key or current_scene != scene:
					break   # it went to another screen: the screens above cover that
				var roots := _new_roots(scene, ids)
				if not _alive(roots):
					break   # nothing opened over the screen
				opened_label = label
				var closer := _closer(roots)
				if way == "close" and closer == null:
					_check(false, "crawl %s: the overlay has no on-screen Close or Done" % label)
					_table.append("crawl: %s | close | FAIL no on-screen Close or Done" % label)
					continue
				var why: String = await _leave("escape" if way == "escape" else "click", closer)
				await _settle(8)
				var ok: bool = why == "" and not _alive(roots) and _router.current() == key 						and (_router.stack as Array).size() == depth and current_scene == scene and _fingerprint() == before
				_check(ok, "crawl %s: %s closes it and stays on %s (%s; now %s)" % [label, way, key, why, _router.current()])
				_table.append("crawl: %s | %s | %s" % [label, way, "ok" if ok else "FAIL %s now=%s alive=%s" % [why, _router.current(), str(_alive(roots))]])
