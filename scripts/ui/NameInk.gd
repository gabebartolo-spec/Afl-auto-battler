class_name NameInk
extends RefCounted
## A player's name in running text wears his club's colour, so whose side he is
## on reads at a glance without "(Giants)" after it (design bible, readability:
## "a player's or club's allegiance is obvious at a glance"; director
## 2026-10-14, tester feedback).
##
## Appearance only. The club comes from the players' records for the screen
## (a match's squads, or a club's list), never from the sentence: build an index
## once with `from_squads` / `from_clubs`, then hand it to `label` with any
## line that names players. A name two clubs both carry is left plain rather
## than guessed. The colour is UiKit.club_ink (4.5:1 on the dark page); the
## weight and size are the line's own.

## Surnames that are also everyday words at the start of a sentence: a lone
## surname that is one of these is not tinted (the full name still is).
const COMMON_WORDS := ["Day", "Young", "Long", "Short", "Hall", "Will", "Rich", "Bird",
		"Free", "Wood", "Hill", "Gray", "Grey", "Brown", "Green", "White", "Black"]


## {name text -> club code} for the players in `squads`: an Array of Arrays of
## player dictionaries ("id", and the display name from GameDB), one per side,
## with `codes` the club for each side. Full names, and the surname alone where
## no one else in the index shares it.
static func from_squads(squads: Array, codes: Array) -> Dictionary:
	var lists := []
	for i in range(mini(squads.size(), codes.size())):
		lists.append({"club": str(codes[i]), "players": squads[i]})
	return _index(lists)


## The same from clubs' lists in the game data.
static func from_clubs(codes: Array) -> Dictionary:
	var lists := []
	for c in codes:
		lists.append({"club": str(c), "players": GameDB.club_list(str(c))})
	return _index(lists)


## The same from the season's lists (GameState.season.lists: code -> players),
## which follow trades and re-drafts; `codes` limits it to some clubs (all when
## empty).
static func from_lists(season_lists: Dictionary, codes := []) -> Dictionary:
	var lists := []
	for c in (codes if not codes.is_empty() else season_lists.keys()):
		if season_lists.has(c):
			lists.append({"club": str(c), "players": season_lists[c]})
	return _index(lists)


static func _index(lists: Array) -> Dictionary:
	var out := {}
	var clash := {}
	for entry in lists:
		var club := str(entry["club"])
		for p in entry["players"]:
			var full := GameDB.player_display_name(p)
			if full == "" or full == "Player":
				continue
			_add(out, clash, full, club)
			var parts := full.split(" ", false)
			if parts.size() >= 2:
				var sur: String = parts[parts.size() - 1]
				if sur.length() >= 3 and not COMMON_WORDS.has(sur):
					_add(out, clash, sur, club)
	for k in clash:
		out.erase(k)
	return out


static func _add(out: Dictionary, clash: Dictionary, key: String, club: String) -> void:
	if out.has(key) and str(out[key]) != club:
		clash[key] = true
	out[key] = club


## `text` as BBCode: each name in `index` wrapped in its club's ink, the rest
## escaped. Empty when the text names no one in the index.
static func markup(text: String, index: Dictionary) -> String:
	var spans := spans_in(text, index)
	if spans.is_empty():
		return ""
	var out := ""
	var at := 0
	for s in spans:
		out += _escape(text.substr(at, int(s[0]) - at))
		var col := UiKit.club_ink(str(s[2]))
		out += "[color=#%s]%s[/color]" % [col.to_html(false), _escape(text.substr(int(s[0]), int(s[1]) - int(s[0])))]
		at = int(s[1])
	return out + _escape(text.substr(at))


## The names found, as [start, end, club] in text order. Longer names claim
## their place first ("Tom Stewart" before "Stewart").
static func spans_in(text: String, index: Dictionary) -> Array:
	var spans := []
	if index.is_empty() or text.is_empty():
		return spans
	var keys: Array = index.keys()
	keys.sort_custom(func(a, b): return str(a).length() > str(b).length())
	for k in keys:
		var key := str(k)
		var from := 0
		while true:
			var i := text.find(key, from)
			if i < 0:
				break
			from = i + key.length()
			if not _edge(text, i - 1, true) or not _edge(text, i + key.length(), false):
				continue
			var free := true
			for s in spans:
				if i < int(s[1]) and i + key.length() > int(s[0]):
					free = false
					break
			if free:
				spans.append([i, i + key.length(), str(index[k])])
	spans.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	return spans


## Whether the character at `at` ends a word (so a name there is a whole word).
static func _edge(text: String, at: int, before: bool) -> bool:
	if at < 0 or at >= text.length():
		return true
	var ch := text.unicode_at(at)
	var letter := (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch >= 192 or (ch >= 48 and ch <= 57)
	# An apostrophe after a name ("Worrell's") still ends it.
	return not letter


static func _escape(t: String) -> String:
	var out := ""
	for ch in t:
		out += "[lb]" if ch == "[" else ("[rb]" if ch == "]" else ch)
	return out


## A line of coach-facing text: a plain Label (UiKit.lbl) unless it names a
## player in `index`, then a RichTextLabel set the same (face, size, colour,
## wrap) with each name in its club's ink. Taps and swipes pass through it as
## they do a Label. `plain` rides on it as metadata for anything that reads the
## words.
static func label(text: String, index: Dictionary, fs := UiKit.BODY, color := UiKit.AUTO_COLOUR, bold := false) -> Control:
	var bb := markup(text, index)
	if bb == "":
		return UiKit.lbl(text, fs, color, bold)
	if color == UiKit.AUTO_COLOUR:
		color = UiKit.TEXT
	var r := rich(fs, color, bold)
	r.text = bb
	r.set_meta("plain", text)
	return r


## An empty RichTextLabel set up like UiKit.lbl, for a line whose words change
## (set them with `set_line`).
static func rich(fs := UiKit.BODY, color := UiKit.AUTO_COLOUR, bold := false) -> RichTextLabel:
	if color == UiKit.AUTO_COLOUR:
		color = UiKit.TEXT
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", UiKit.BOLD if bold else UiKit.FONT)
	r.add_theme_font_override("bold_font", UiKit.BOLD)
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.add_theme_color_override("default_color", color)
	return r


## Set a `rich` line's words, each name in the index in its club's ink.
static func set_line(r: RichTextLabel, text: String, index: Dictionary) -> void:
	var bb := markup(text, index)
	r.text = bb if bb != "" else _escape(text)
	r.set_meta("plain", text)


## The words a line shows, whichever kind of label carries it.
static func plain(c: Control) -> String:
	if c.has_meta("plain"):
		return str(c.get_meta("plain"))
	if c is Label:
		return (c as Label).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	return ""
