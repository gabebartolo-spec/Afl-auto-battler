class_name NameLink
extends RefCounted
## One way for a player's name to open his profile (director, 2026-10-14: "virtually
## every time you see a players name anywhere in the game i want to be able to click
## on it and open their bio"). Tapping the name opens the same sheet My list opens
## (PlayerSheet) over whatever screen you are on; Back or Close returns you to the
## screen exactly as it was, because the sheet is only laid over it.
##
## Two entry points, both ending in `open`:
##  - a name in a running line: `url(shown, id)` wraps it for a RichTextLabel and
##    `wire(label)` makes the label open the profile when the name is tapped;
##  - a name that is a control of its own: connect its press to `open(self, id)`.
## Appearance and look-up only; no effect on the game.

const SCHEME := "player:"
const SHEET_NAME := "PlayerProfile"


## BBCode for `shown` as a tappable name.
static func url(shown: String, id: String) -> String:
	return "[url=%s%s]%s[/url]" % [SCHEME, id, shown]


## `text` as BBCode with each name in `ids` ({shown name -> id}) a tappable name and
## the rest escaped. For a line that has no club colours (NameInk wraps the coloured
## ones itself).
static func markup(text: String, ids: Dictionary) -> String:
	var names: Array = ids.keys()
	names.sort_custom(func(a, b): return str(a).length() > str(b).length())
	var spans := []
	for k in names:
		var key := str(k)
		var from := 0
		while key != "":
			var i := text.find(key, from)
			if i < 0:
				break
			from = i + key.length()
			if i > 0 and text[i - 1].to_lower() != text[i - 1].to_upper():
				continue
			var j := i + key.length()
			if j < text.length() and text[j].to_lower() != text[j].to_upper():
				continue
			var free := true
			for s in spans:
				if i < int(s[1]) and j > int(s[0]):
					free = false
			if free:
				spans.append([i, j, str(ids[k])])
	spans.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var out := ""
	var at := 0
	for s in spans:
		out += _escape(text.substr(at, int(s[0]) - at))
		out += url(_escape(text.substr(int(s[0]), int(s[1]) - int(s[0]))), str(s[2]))
		at = int(s[1])
	return out + _escape(text.substr(at))


## A wrapping line of `text` in `colour` whose names in `ids` open profiles.
static func line(text: String, ids: Dictionary, size: int, colour: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", colour)
	r.text = markup(text, ids)
	# One colour for the whole line, so its names are underlined to read as taps.
	wire(r, true)
	return r


static func _escape(t: String) -> String:
	return t.replace("[", "[lb]")


## Make this label's player links open profiles. Names stay as coloured as the
## line made them (no underline); a drag that starts on a name still scrolls.
static func wire(label: RichTextLabel, underline := false) -> void:
	label.meta_underlined = underline
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	if label.has_meta("name_link_wired"):
		return
	label.set_meta("name_link_wired", true)
	label.gui_input.connect(_on_input.bind(label))
	label.meta_clicked.connect(_on_meta.bind(label))
	_add_slop(label)


## A name in running text is as tall as its line, so a thumb is given the whole line
## pitch: the label gets an invisible hit strip reaching half the gap to the line
## above and half the gap to the line below (a box's `separation`), which never
## overlaps the next line's strip. A tap in a strip is handed to the label at its
## nearest edge, so it finds the name the same way a tap on the text does. Nothing
## is drawn and nothing moves.
const HIT_NAME := "NameHit"


static func _add_slop(label: RichTextLabel) -> void:
	var hit := Control.new()
	hit.name = HIT_NAME
	hit.set_meta("name_link_hit", true)
	hit.mouse_filter = Control.MOUSE_FILTER_PASS
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The strips reach outside the label's box, which a clipping label would cut off.
	label.clip_contents = false
	label.add_child(hit, false, Node.INTERNAL_MODE_BACK)
	hit.gui_input.connect(_on_strip.bind(label, hit))
	label.tree_entered.connect(func() -> void: _fit_slop.call_deferred(label))
	label.resized.connect(func() -> void: _fit_slop(label))
	_fit_slop.call_deferred(label)


static func _fit_slop(label: RichTextLabel) -> void:
	if not is_instance_valid(label):
		return
	var hit := label.get_node_or_null(HIT_NAME) as Control
	if hit == null:
		return
	var gap := 0.0
	var parent := label.get_parent()
	if parent is BoxContainer and (parent as BoxContainer).vertical:
		gap = float((parent as BoxContainer).get_theme_constant("separation")) * 0.5
	hit.offset_top = -floorf(gap)
	hit.offset_bottom = floorf(gap)


## A tap that lands in a strip (above or below the text box) opens the name nearest
## it: on the label's top line for a tap above, its bottom line for a tap below.
## A press that turns into a swipe opens nothing and still scrolls the page.
static func _on_strip(ev: InputEvent, label: RichTextLabel, _hit: Control) -> void:
	if not (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	var at: Vector2 = (ev as InputEventMouseButton).global_position
	if ev.is_pressed():
		label.set_meta("name_link_strip_down", at)
		return
	if not label.has_meta("name_link_strip_down"):
		return
	var down: Vector2 = label.get_meta("name_link_strip_down")
	label.remove_meta("name_link_strip_down")
	if at.distance_to(down) > 12.0 or label.get_global_rect().has_point(at):
		return
	var id := nearest_id(label, at)
	if id != "":
		open(label, id)


## The id of the name on `label` nearest the point (global): among the names on its
## top line when the point is above the box, on its bottom line when below; the
## nearest by how far along the line it starts. "" when the label names no one.
static func nearest_id(label: RichTextLabel, at: Vector2) -> String:
	var found := []
	var rx := RegEx.new()
	rx.compile("\\[url=%s([^\\]]+)\\](.*?)\\[/url\\]" % SCHEME)
	var parsed := label.get_parsed_text()
	var cursor := 0
	for m in rx.search_all(label.text):
		var shown := m.get_string(2).replace("[lb]", "[")
		var i := parsed.find(shown, cursor)
		if i < 0:
			continue
		cursor = i + shown.length()
		found.append([m.get_string(1), i, shown])
	if found.is_empty():
		return ""
	var want_line := 0 if at.y < label.get_global_rect().position.y else label.get_line_count() - 1
	var font := label.get_theme_font("normal_font")
	var size := label.get_theme_font_size("normal_font_size")
	var best := ""
	var best_d := INF
	for f in found:
		var idx := int(f[1])
		if label.get_character_line(idx) != want_line:
			continue
		var line_start := idx
		while line_start > 0 and label.get_character_line(line_start - 1) == want_line:
			line_start -= 1
		var x0 := font.get_string_size(parsed.substr(line_start, idx - line_start), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x1 := x0 + font.get_string_size(str(f[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var local_x := at.x - label.get_global_rect().position.x
		var d := 0.0 if local_x >= x0 and local_x <= x1 else minf(absf(local_x - x0), absf(local_x - x1))
		if d < best_d:
			best_d = d
			best = str(f[0])
	return best


## A tap opens the profile; a press that turns into a swipe does not. The label
## may report the name on the press or on the let-go, so both are held until the
## finger is up and has not travelled.
static func _on_input(ev: InputEvent, label: RichTextLabel) -> void:
	if not (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	var at: Vector2 = (ev as InputEventMouseButton).global_position
	if ev.is_pressed():
		label.set_meta("name_link_down", at)
		label.remove_meta("name_link_pending")
		return
	label.set_meta("name_link_up_frame", Engine.get_process_frames())
	if label.has_meta("name_link_pending") and _still(label, at):
		var id := str(label.get_meta("name_link_pending"))
		label.remove_meta("name_link_pending")
		open(label, id)


static func _still(label: Control, at: Vector2) -> bool:
	return label.has_meta("name_link_down") and at.distance_to(label.get_meta("name_link_down")) <= 12.0


static func _on_meta(meta: Variant, label: RichTextLabel) -> void:
	var s := str(meta)
	if not s.begins_with(SCHEME):
		return
	var id := s.substr(SCHEME.length())
	if int(label.get_meta("name_link_up_frame", -1)) == Engine.get_process_frames():
		# Reported as the finger lifted.
		if _still(label, label.get_global_mouse_position()):
			open(label, id)
		return
	label.set_meta("name_link_pending", id)


## His record: your list first, then the season's lists (they follow trades), then
## the game's data.
static func find(id: String) -> Dictionary:
	var p: Dictionary = GameState.list_player(id)
	if not p.is_empty():
		return p
	if GameState.season != null:
		for code in GameState.season.lists:
			for q in GameState.season.lists[code]:
				if str(q.get("id", "")) == id:
					return q
	var g: Variant = GameDB.player_by_id(id)
	return g if g is Dictionary else {}


## Open his profile over the screen `from` is on. Returns the sheet, or null when
## no one has that id. A profile already open is replaced, not stacked.
static func open(from: Node, id: String) -> Control:
	var p := find(id)
	if p.is_empty() or from == null or not from.is_inside_tree():
		return null
	var host: Control = null
	var n: Node = from
	while n != null and not (n is Window):
		if n is Control:
			host = n
		n = n.get_parent()
	if host == null:
		return null
	for c in host.get_children():
		if c.name == SHEET_NAME and c.has_meta("name_link"):
			c.queue_free()
			c.name = "PlayerProfileClosing"
	var sheet := PlayerSheet.open(host, p)
	sheet.set_meta("name_link", true)
	return sheet


## Back closes a profile opened this way before the screen sees it. True when it did.
static func close_open(scene: Node) -> bool:
	if scene == null:
		return false
	for c in scene.get_children():
		if c.name == SHEET_NAME and c.has_meta("name_link") and not c.is_queued_for_deletion():
			c.queue_free()
			return true
	return false
