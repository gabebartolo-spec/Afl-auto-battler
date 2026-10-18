extends SceneTree
## The gate a builder runs before a capture reaches the lead: walks a live screen and prints what a
## screen critic would measure. Headless is fine (no pixels needed):
##   godot --headless --path . --script tools/visual/screen_lint.gd -- --screen hub|draft|prebounce|res://x.tscn
##         [--size 390x844] [--club FRE] [--setup res://my_setup.gd] [--fixture]
## --setup names a script with `static func lint_setup(tree: SceneTree, scene: Node) -> void` (runs after the
## screen is up, to open a sheet or pick a tab). --fixture adds a deliberate 40 px button, two 11 px lines and
## a pair of disagreeing counts to the screen, to prove the lint catches them.
## Checks: (1) tap targets under 44 px at phone width, (2) text under 13 px, (3) the same fact drawn twice
## and counts that disagree, (4) text contrast under 4.5:1. Contrast method: headless has no rendered frame,
## so each label is compared with the colours of its ancestors' styleboxes and ColorRects, blended up from the
## first opaque one (the page colour UiKit.BG when none is opaque). It cannot see colour that _draw() paints.
## Exit code 1 when any FIX is found. Never touches a real save.

## An options row beside a fact (FactOptionsRow): its labels repeat by design.
const OPTION_ROW_NAMES := ["OptionName", "OptionGain", "OptionSub"]
const MIN_TAP := 44.0
const MIN_FONT := 13
const MIN_CONTRAST := 4.5
const STOP_WORDS := ["there", "their", "about", "which", "other", "these", "those", "round", "total"]

var _w := 390
var _h := 844
var _fixes := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var screen := "hub"
	var club := "FRE"
	var setup := ""
	var fixture := false
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--fixture": fixture = true
			"--screen": screen = str(a[i + 1])
			"--club": club = str(a[i + 1])
			"--setup": setup = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	state.autosave_enabled = false
	state.save_path = "user://screenlint.save"
	state.settings_path = "user://screenlint.cfg"
	load("res://scripts/ui/UiKit.gd").apply_appearance("dark")
	state.reset()
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	var scene: Node = null
	match screen:
		"hub":
			state.start_season(club, db.club_list(club))
			state.tutorials = false
			router.stack = []
			router.go("main")
			await _frames(8)
			router.go("hub")
			await _frames(20)
			for b in root.find_children("*", "Button", true, false):
				if (b as Button).text == "Got it" and (b as Button).is_visible_in_tree():
					(b as Button).emit_signal("pressed")
			await _frames(20)
			scene = root
		"draft":
			state.draft = load("res://scripts/sim/Draft.gd").new(db.all_players_sorted() + db.all_draftees_sorted(),
					db.active_clubs(2027).duplicate(), 12345)
			scene = load("res://scenes/DraftScene.tscn").instantiate()
			root.add_child(scene)
			scene.call("_on_club_chosen", club)
			await _frames(14)
		"prebounce":
			state.career_seed = 2050
			state.replay_seed = 2050
			state.set_setting("seen_training_intro", true)
			state.start_season(club, db.club_list(club))
			state.prepare_interactive_match()
			scene = load("res://scenes/MatchScene.tscn").instantiate()
			root.add_child(scene)
			await _frames(24)
		_:
			scene = load(screen).instantiate()
			root.add_child(scene)
			await _frames(14)
	if setup != "":
		load(setup).lint_setup(self, scene)
		await _frames(12)
	if fixture:
		var host := Control.new()
		host.name = "LintFixture"
		root.add_child(host)
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bad := Button.new()
		bad.name = "FixtureShortButton"
		bad.text = "Save changes now"
		bad.position = Vector2(10, 10)
		bad.custom_minimum_size = Vector2(160, 40)
		bad.size = Vector2(160, 40)
		host.add_child(bad)
		for k in range(2):
			var l := Label.new()
			l.name = "FixtureLine%d" % k
			l.text = "26 prospects left" if k == 0 else "8 prospects left"
			l.add_theme_font_size_override("font_size", 11)
			l.position = Vector2(10, 60 + 20 * k)
			host.add_child(l)
		await _frames(4)
	_lint(screen)
	quit(1 if _fixes > 0 else 0)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _visible(c: CanvasItem) -> bool:
	if not c.is_visible_in_tree():
		return false
	var n: Node = c
	while n != null:
		if n is CanvasItem and (n as CanvasItem).modulate.a < 0.05:
			return false
		n = n.get_parent()
	if c is Control and ((c as Control).size.x < 1.0 or (c as Control).size.y < 1.0):
		return false
	return true


func _text_of(c: Node) -> String:
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text().strip_edges()
	if c is Label:
		return (c as Label).text.strip_edges()
	if c is Button:
		return (c as Button).text.strip_edges()
	return ""


func _font_size(c: Control) -> int:
	if c is RichTextLabel:
		return c.get_theme_font_size("normal_font_size")
	return c.get_theme_font_size("font_size")


func _text_colour(c: Control) -> Color:
	var col: Color
	if c is RichTextLabel:
		col = c.get_theme_color("default_color")
	elif c is Button:
		col = c.get_theme_color("font_disabled_color" if (c as Button).disabled else "font_color")
	else:
		col = c.get_theme_color("font_color")
	col.a *= c.self_modulate.a
	return col


## The colour this ancestor paints behind its children, or null.
func _layer_of(n: Node) -> Variant:
	if n is ColorRect:
		return (n as ColorRect).color
	var sb: StyleBox = null
	if n is Button:
		sb = (n as Control).get_theme_stylebox("disabled" if (n as Button).disabled else "normal")
	elif n is PanelContainer or n is Panel:
		sb = (n as Control).get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		return (sb as StyleBoxFlat).bg_color
	return null


func _background(c: Control) -> Color:
	var layers: Array = []
	var n: Node = c
	var opaque := false
	while n != null:
		var l: Variant = _layer_of(n)
		if l != null and (l as Color).a > 0.0:
			layers.append(l)
			if (l as Color).a >= 0.99:
				opaque = true
				break
		n = n.get_parent()
	var base: Color = load("res://scripts/ui/UiKit.gd").BG
	for i in range(layers.size() - 1, -1, -1):
		var top: Color = layers[i]
		base = base.lerp(Color(top.r, top.g, top.b, 1.0), top.a)
	return base


## The last three names on the node's path (the full path of a generated row is a page long).
func _where(c: Node) -> String:
	var parts := str(c.get_path()).trim_prefix("/root/").split("/")
	return "/".join(parts.slice(maxi(0, parts.size() - 3)))


func _flat(t: String) -> String:
	return t.replace(char(10), " / ")


## Print up to `cap` lines of a list, then how many more there are.
func _list(lines: Array, cap := 8) -> void:
	for i in range(mini(cap, lines.size())):
		print(lines[i])
	if lines.size() > cap:
		print("   ... and %d more" % (lines.size() - cap))


func _lint(screen: String) -> void:
	var ui = load("res://scripts/ui/UiKit.gd")
	var tap_list: Array = []
	var small: Array = []
	var texts: Array = []
	var low: Array = []
	var phone := _w < 700
	for c in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not _visible(ctl):
			continue
		var tappable := false
		if ctl is BaseButton:
			tappable = ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE
		elif ctl.mouse_filter == Control.MOUSE_FILTER_STOP and not ctl.get_signal_connection_list("gui_input").is_empty():
			tappable = true
		if tappable and phone and ctl.size.y < MIN_TAP - 0.5:
			tap_list.append(ctl)
		var t := _text_of(ctl)
		if t == "" or not (ctl is Label or ctl is RichTextLabel or ctl is Button):
			continue
		texts.append({"node": ctl, "text": t})
		if _font_size(ctl) < MIN_FONT:
			small.append(ctl)
		var fg := _text_colour(ctl)
		var bg := _background(ctl)
		var fg_flat := bg.lerp(Color(fg.r, fg.g, fg.b, 1.0), fg.a)
		var r: float = ui.contrast(fg_flat, bg)
		if r < MIN_CONTRAST:
			low.append([ctl, r])
	print("SCREEN LINT  screen=%s  size=%dx%d  contrast method: ancestor style colours (no rendered frame)" % [screen, _w, _h])
	print("1. Tap targets under %d px tall%s: %d" % [int(MIN_TAP), "" if phone else " (phone width only; skipped here)", tap_list.size()])
	var tl: Array = []
	for c in tap_list:
		tl.append("   %s  rect=%s  \"%s\"" % [_where(c), str((c as Control).get_global_rect()), _flat(_text_of(c)).left(30)])
	_list(tl)
	print("2. Text under %d px: %d" % [MIN_FONT, small.size()])
	var sl: Array = []
	for c in small:
		sl.append("   %s  size=%d  \"%s\"" % [_where(c), _font_size(c), _flat(_text_of(c)).left(40)])
	_list(sl)
	var by_text := {}
	for e in texts:
		var key: String = String(e.text).strip_edges().to_lower()
		if key.length() < 8:
			continue
		# The same option under two opposition facts is the feature (P-13), not a
		# repeat: an option row's name and its gain and cost lines are exempt.
		if str((e.node as Node).name) in OPTION_ROW_NAMES:
			continue
		if not by_text.has(key):
			by_text[key] = []
		by_text[key].append(e.node)
	var dup_lines: Array = []
	for k in by_text:
		if by_text[k].size() >= 2:
			var paths: Array = []
			for n in by_text[k]:
				paths.append(_where(n))
			dup_lines.append("   \"%s\" x%d: %s" % [String(k).left(40), by_text[k].size(), "; ".join(paths.slice(0, 4))])
	var conflicts: Array = []
	var maybes: Array = []
	var num_re := RegEx.create_from_string("\\d[\\d,.]*")
	var word_re := RegEx.create_from_string("[a-z]{5,}")
	var counted: Array = []
	for e in texts:
		var tx: String = String(e.text).to_lower()
		var ms := num_re.search_all(tx)
		if ms.is_empty() or tx.length() > 60:
			continue
		var tmpl := num_re.sub(tx, "#", true)
		if word_re.search_all(tmpl).is_empty():
			continue
		var nums: Array = []
		for m in ms:
			nums.append(m.get_string())
		var words: Array = []
		for m in word_re.search_all(tmpl):
			if not STOP_WORDS.has(m.get_string()):
				words.append(m.get_string())
		counted.append({"node": e.node, "text": tx, "tmpl": tmpl, "nums": nums, "words": words})
	for i in range(counted.size()):
		for j in range(i + 1, counted.size()):
			var p: Dictionary = counted[i]
			var q: Dictionary = counted[j]
			if p.nums == q.nums:
				continue
			var line := "   \"%s\" (%s)  vs  \"%s\" (%s)" % [_flat(p.text).left(40), _where(p.node), _flat(q.text).left(40), _where(q.node)]
			if p.tmpl == q.tmpl:
				if p.words.size() >= 1:
					conflicts.append(line)
			else:
				var shared := false
				for w in p.words:
					if q.words.has(w):
						shared = true
				if shared:
					maybes.append(line)
	print("3. Same fact drawn twice: %d" % dup_lines.size())
	_list(dup_lines)
	print("   Same words, different numbers (list rows legitimately repeat a pattern; eyeball, not counted as FIX): %d" % conflicts.size())
	_list(conflicts)
	print("   Counts that may disagree (a shared word, different numbers; eyeball, not counted as FIX): %d" % maybes.size())
	_list(maybes)
	print("4. Contrast under %.1f:1: %d" % [MIN_CONTRAST, low.size()])
	var ll: Array = []
	for pr in low:
		ll.append("   %s  %.2f:1  \"%s\"" % [_where(pr[0]), pr[1], _flat(_text_of(pr[0])).left(30)])
	_list(ll)
	_fixes = tap_list.size() + small.size() + dup_lines.size() + low.size()
	print("%s  %s %dx%d: %d tap, %d small text, %d duplicate, %d contrast; to eyeball: %d same-words counts, %d shared-word counts" % [
		"PASS" if _fixes == 0 else "FIX", screen, _w, _h, tap_list.size(), small.size(), dup_lines.size(),
		low.size(), conflicts.size(), maybes.size()])
