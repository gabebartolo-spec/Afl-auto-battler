class_name TraitLink
extends RefCounted
## One way for a trait's or line synergy's name to explain itself (director,
## 2026-10-19: "can we hover on traits and it shows us their effects?"). On a
## computer, hovering the name shows its effect; on every device, tapping it opens
## a small sheet with what it does in exact terms and what earns it (a synergy:
## what it needs and what it does). Close, Back or a tap outside returns you to
## the screen exactly as it was.
##
## Three entry points, all ending in `open`:
##  - a name that is a label of its own: `tappable(label, key)`;
##  - a trait or synergy named inside a sentence: `line(text, size, colour)`, which
##    finds every name and makes it a tap (taps and swipes are NameLink's);
##  - anything else: `open(from, key)`.
## Names read as taps by weight, never an underline. Look-up only; no effect on the game.

const SCHEME := "trait:"
const SHEET_NAME := "TraitInfo"
const ROLE_WORDS := {"MID": "midfielders", "DEF": "defenders", "FWD": "forwards", "RUCK": "ruckmen"}


## Every name that can be tapped: {shown label -> key}.
static func names() -> Dictionary:
	var out := {}
	for group in [Traits.DEFS, Traits.EARNED, Traits.SYNERGIES]:
		for key in group:
			out[Traits.label(str(key))] = str(key)
	out[Traits.label("wet_weather")] = "wet_weather"
	return out


## True for a key this knows (a trait, the wet-weather player, Unicorn or a synergy).
static func known(key: String) -> bool:
	return names().values().has(key)


## What the name says when hovered: the effect alone.
static func tip(key: String) -> String:
	return Traits.text(key)


## What earns a trait, in football words and exact thresholds; "" for a synergy.
static func earn_text(key: String) -> String:
	if Traits.SYNERGIES.has(key) or key == "unicorn":
		return ""
	if key == "wet_weather":
		return "Earned with Contested %d and Disposal %d or better." % [
				int(Traits.WET_WEATHER["contested"]), int(Traits.WET_WEATHER["disposal"])]
	var d: Dictionary = Traits.DEFS.get(key, {})
	if d.is_empty():
		return ""
	var stat := GameState.train_stat_label(str(d["stat"]))
	if d.has("max"):
		return "He has it when %s is %d or lower." % [stat, int(d["max"])]
	var who := ""
	var roles: Array = d.get("roles", [])
	if not roles.is_empty():
		var words: PackedStringArray = []
		for r in roles:
			words.append(str(ROLE_WORDS.get(str(r), str(r))))
		who = " for %s" % " and ".join(words)
		if bool(d.get("own_role", false)):
			who += " by trade"
	var small := " Only for a small player (Marking under 52)." if bool(d.get("small", false)) else ""
	return "Earned at %s %d or better%s.%s" % [stat, int(d["min"]), who, small]


## The sheet's words, top to bottom: [title, kind, effect, rule lines...].
static func sheet_lines(key: String) -> Array:
	var out := [Traits.label(key)]
	if Traits.SYNERGIES.has(key):
		var s: Dictionary = Traits.SYNERGIES[key]
		out.append("Line synergy")
		out.append(Traits.text(key))
		out.append(str(s.get("about", "")))
		out.append(Traits.requirement_text(key))
	else:
		out.append("Trait")
		out.append(Traits.text(key))
		var e := earn_text(key)
		if e != "":
			out.append(e)
	return out


## BBCode for `text` with each trait or synergy name a bold tap, the rest escaped.
## `players` ({shown name -> id}, optional) makes his names bold taps to his profile too.
static func markup(text: String, players := {}) -> String:
	var ids := names()
	for k in players:
		ids[str(k)] = NameLink.SCHEME + str(players[k])
	var keys: Array = ids.keys()
	keys.sort_custom(func(a, b): return str(a).length() > str(b).length())
	var spans := []
	for k in keys:
		var key := str(k)
		var from := 0
		while key != "":
			var i := text.find(key, from)
			if i < 0:
				break
			from = i + key.length()
			var j := i + key.length()
			if (i > 0 and _letter(text[i - 1])) or (j < text.length() and _letter(text[j])):
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
		var meta := str(s[2]) if str(s[2]).begins_with(NameLink.SCHEME) else SCHEME + str(s[2])
		out += "[url=%s][b]%s[/b][/url]" % [meta, _escape(text.substr(int(s[0]), int(s[1]) - int(s[0])))]
		at = int(s[1])
	return out + _escape(text.substr(at))


static func _letter(ch: String) -> bool:
	return ch.to_lower() != ch.to_upper()


static func _escape(t: String) -> String:
	return t.replace("[", "[lb]")


## A wrapping line of `text` whose trait and synergy names explain themselves on a tap.
static func line(text: String, size: int, colour: Color, players := {}) -> RichTextLabel:
	var r := NameInk.rich(size, colour)
	r.text = markup(text, players)
	r.set_meta("plain", text)
	r.set_meta("trait_link", true)
	NameLink.wire(r)
	return r


## Make a label that names one trait explain itself: a tooltip on hover, the
## sheet on a tap. A press that turns into a swipe does nothing, so it still
## scrolls the page.
static func tappable(c: Control, key: String) -> Control:
	c.set_meta("name_link_wired", true)
	c.set_meta("trait_key", key)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.tooltip_text = tip(key)
	var down := [Vector2.INF]
	c.gui_input.connect(func(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
			return
		var at: Vector2 = (ev as InputEventMouseButton).global_position
		if ev.is_pressed():
			down[0] = at
		elif down[0] != Vector2.INF and at.distance_to(down[0]) <= 12.0:
			down[0] = Vector2.INF
			open(c, key))
	return c


## Open the sheet over the screen `from` is on. Null for a name it does not know.
## One sheet at a time: opening another replaces it.
static func open(from: Node, key: String) -> Control:
	if not known(key) or from == null or not from.is_inside_tree():
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
		if c.name == SHEET_NAME:
			c.queue_free()
			c.name = "TraitInfoClosing"
	var box := UiKit.modal_box(host, 480.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = SHEET_NAME
	overlay.set_meta("trait_link", true)
	UiKit.close_on_outside_tap(box)
	var v: VBoxContainer = box["body"]
	var rows := sheet_lines(key)
	var title := UiKit.lbl(str(rows[0]), UiKit.H1, UiKit.BAD if Traits.is_bad(key) else UiKit.TEXT, true)
	title.name = "TraitTitle"
	v.add_child(title)
	v.add_child(UiKit.lbl(str(rows[1]), UiKit.SMALL, UiKit.MUTED))
	var effect := UiKit.lbl(str(rows[2]), UiKit.BODY, UiKit.TEXT)
	effect.name = "TraitEffect"
	v.add_child(effect)
	for i in range(3, rows.size()):
		var extra := UiKit.lbl(str(rows[i]), UiKit.SMALL, UiKit.MUTED)
		extra.name = "TraitRule%d" % (i - 3)
		v.add_child(extra)
	var close := UiKit.btn("Close", UiKit.NAME, true)
	close.name = "TraitClose"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(func() -> void: overlay.queue_free())
	box["footer"].add_child(close)
	return overlay


## Back closes an open trait sheet before the screen sees it. True when it did.
static func close_open(scene: Node) -> bool:
	if scene == null:
		return false
	for c in scene.get_children():
		if c.name == SHEET_NAME and not c.is_queued_for_deletion():
			c.queue_free()
			return true
	return false
