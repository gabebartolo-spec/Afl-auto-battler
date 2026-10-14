class_name NewsFront
extends RefCounted
## League news as a footy website's front page for the round (director,
## 2026-10-14: "make it look like website frontpage rather than a ticker feed").
##
## build() is the page's content, with no nodes: a lead story ranked by a fixed
## rule (rank()), a few secondary stories, and everything else grouped into
## briefs ("First AFL goals", "Injuries", "Tribunal and MRO", "Milestones").
## Every item of the round lands in exactly one place. fill() and mini() draw it.
## The items are the plain {year, when, kind, text} lines the game already keeps,
## so older saves read the same.

const SECONDARY_MAX := 3
## A story needs this much weight to be a secondary headline; the rest are briefs.
const SECONDARY_MIN := 40

const _FIRST_GOAL := "first_goals"
const _MILESTONE := "milestones"
const _INJURY := "injuries"
const _MRO := "mro"
const _YOURS := "yours"
const _AROUND := "around"
const BRIEF_ORDER := [_FIRST_GOAL, _INJURY, _MRO, _MILESTONE, _YOURS, _AROUND]
const BRIEF_TITLE := {
	_FIRST_GOAL: "First AFL goals", _INJURY: "Injuries", _MRO: "Tribunal and MRO",
	_MILESTONE: "Milestones", _YOURS: "Your club", _AROUND: "Around the league",
}
const WORDS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

static var _rx := {}
static var _codes := {}


# ---------------------------------------------------------------------------
# Reading an item
# ---------------------------------------------------------------------------
static func _re(key: String, pattern: String) -> RegEx:
	if not _rx.has(key):
		var r := RegEx.new()
		r.compile(pattern)
		_rx[key] = r
	return _rx[key]


## Club code for a club's full name ("" when it is none).
static func code_of(club_name: String) -> String:
	if _codes.is_empty() or _codes.size() != GameDB.clubs.size():
		_codes = {}
		for code in GameDB.clubs:
			_codes[GameDB.club_name(str(code))] = str(code)
	return str(_codes.get(club_name, ""))


static func _word(n: int) -> String:
	return WORDS[n] if n >= 0 and n < WORDS.size() else str(n)


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


## One item as a story: {kind, text, group, club, name, headline, standfirst,
## weight, mine}. `club` is the club the story is about (colours its headline).
static func story(item: Dictionary, my_club := "") -> Dictionary:
	var text := str(item.get("text", ""))
	var kind := str(item.get("kind", ""))
	var s := {"kind": kind, "text": text, "group": _AROUND, "club": "", "name": "",
			"headline": text, "standfirst": "", "weight": 25, "mine": false, "round": 0}
	var m: RegExMatch
	if kind == "game":
		m = _re("goals", "^(.+) kicked (\\d+) goals for (.+) against (.+)\\.$").search(text)
		if m != null:
			var n := int(m.get_string(2))
			s.merge({"name": m.get_string(1), "club": code_of(m.get_string(3)), "weight": 60 + 5 * mini(n - 6, 6) + 10,
					"headline": "%s bags %s" % [m.get_string(1), _word(n)],
					"standfirst": "%s goals for %s against %s." % [_cap(_word(n)), m.get_string(3), m.get_string(4)]}, true)
			return _mine(s, my_club)
		m = _re("disp", "^(.+) had (\\d+) disposals for (.+) against (.+)\\.$").search(text)
		if m != null:
			s.merge({"name": m.get_string(1), "club": code_of(m.get_string(3)), "weight": 45,
					"headline": "%s racks up %s" % [m.get_string(1), m.get_string(2)],
					"standfirst": "Disposals for %s against %s." % [m.get_string(3), m.get_string(4)]}, true)
			return _mine(s, my_club)
	elif kind == "milestone":
		m = _re("first", "^(.+) kicked his first AFL goal for (.+)\\.$").search(text)
		if m != null:
			s.merge({"group": _FIRST_GOAL, "name": m.get_string(1), "club": code_of(m.get_string(2)), "weight": 20,
					"headline": m.get_string(1), "standfirst": m.get_string(2)}, true)
			return _mine(s, my_club)
		s["group"] = _MILESTONE
		s["weight"] = 35
	elif kind == "injury":
		s["group"] = _INJURY
		m = _re("injury", "^(.+) \\((.+)\\) is out for (.+) with an? (.+)\\.$").search(text)
		if m != null:
			var wk := int(m.get_string(3).split(" ")[0])
			s.merge({"name": m.get_string(1), "club": code_of(m.get_string(2)), "weight": 40 + 3 * wk,
					"headline": "%s out for %s" % [m.get_string(1), m.get_string(3)],
					"standfirst": "%s will be without him: %s." % [m.get_string(2), m.get_string(4)]}, true)
			return _mine(s, my_club)
	elif kind == "mro":
		s["group"] = _MRO
		m = _re("sus", "^(.+) \\((.+)\\) has been suspended for (\\d+) match(?:es)? for (.+)\\.$").search(text)
		if m != null:
			var w := int(m.get_string(3))
			s.merge({"name": m.get_string(1), "club": code_of(m.get_string(2)), "weight": 50 + 4 * w,
					"headline": "%s suspended for %s" % [m.get_string(1), "a match" if w == 1 else "%s matches" % _word(w)],
					"standfirst": "%s lose him for %s." % [m.get_string(2), m.get_string(4)]}, true)
			return _mine(s, my_club)
		m = _re("fine", "^(.+) \\((.+)\\) was fined by the MRO for (.+)\\.$").search(text)
		if m != null:
			s.merge({"name": m.get_string(1), "club": code_of(m.get_string(2)), "weight": 30,
					"headline": "%s fined" % m.get_string(1),
					"standfirst": "%s: cited by the MRO for %s." % [m.get_string(2), m.get_string(3)]}, true)
			return _mine(s, my_club)
	elif kind == "tribunal":
		s["group"] = _MRO
		s["weight"] = 45
	elif kind == "award":
		m = _re("award", "^(.+) \\((.+)\\) won the (.+) with (\\d+) (votes|goals)\\.$").search(text)
		if m != null:
			s.merge({"name": m.get_string(1), "club": code_of(m.get_string(2)),
					"weight": 90 if m.get_string(3) == "Brownlow Medal" else 80,
					"headline": "%s wins the %s" % [m.get_string(1), m.get_string(3)],
					"standfirst": "%s, with %s %s." % [m.get_string(2), m.get_string(4), m.get_string(5)]}, true)
			return _mine(s, my_club)
		s["weight"] = 75
	elif kind == "premiers":
		m = _re("prem", "^(.+) are the (\\d+) premiers\\.$").search(text)
		if m != null:
			s.merge({"club": code_of(m.get_string(1)), "weight": 100,
					"headline": "%s are the %s premiers" % [m.get_string(1), m.get_string(2)],
					"standfirst": "The flag is theirs."}, true)
			return _mine(s, my_club)
	elif kind == "media":
		m = _re("media", "^Post-match: '(.*)'$").search(text)
		s.merge({"club": my_club, "weight": 66, "mine": true,
				"headline": "“%s”" % (m.get_string(1) if m != null else text),
				"standfirst": "Your word after the match."}, true)
		return s
	elif kind == "board":
		s.merge({"club": my_club, "weight": 75, "mine": true, "standfirst": "From your board."}, true)
		return s
	elif kind in ["club", "captaincy", "coaching", "achievement"]:
		# Your own club's business, told as yours.
		s.merge({"group": _YOURS, "club": my_club, "weight": 30, "mine": true}, true)
		return s
	elif kind == "trade":
		s["weight"] = 35
	return s


static func _mine(s: Dictionary, my_club: String) -> Dictionary:
	if my_club != "" and str(s["club"]) == my_club:
		s["mine"] = true
		s["weight"] = int(s["weight"]) + 8
	return s


## The lead-story rule: highest weight first; equal weights keep the feed's own
## order (the newest first), so the same round always gives the same page.
static func rank(stories: Array) -> Array:
	var idx: Array = range(stories.size())
	idx.sort_custom(func(a, b) -> bool:
		var wa := int((stories[a] as Dictionary)["weight"])
		var wb := int((stories[b] as Dictionary)["weight"])
		return wa > wb or (wa == wb and a < b))
	var out := []
	for i in idx:
		out.append(stories[i])
	return out


# ---------------------------------------------------------------------------
# The page
# ---------------------------------------------------------------------------
## Items of the newest round: those sharing the first item's year and label.
static func latest_round(items: Array) -> Array:
	if items.is_empty():
		return []
	var out := []
	var first: Dictionary = items[0]
	for it in items:
		if int(it.get("year", 0)) == int(first.get("year", 0)) and str(it.get("when", "")) == str(first.get("when", "")):
			out.append(it)
		else:
			break
	return out


## The whole feed in rounds, newest first: [[items of a round], ...].
static func rounds(items: Array) -> Array:
	var out := []
	var rest := items
	while not rest.is_empty():
		var r := latest_round(rest)
		out.append(r)
		rest = rest.slice(r.size())
	return out


## {dateline, lead, secondary: [story], briefs: [{key, title, entries: [story]}], count}.
static func build(items: Array, my_club := "") -> Dictionary:
	var page := {"dateline": "", "lead": {}, "secondary": [], "briefs": [], "count": items.size()}
	if items.is_empty():
		return page
	var first: Dictionary = items[0]
	page["dateline"] = "%d  %s" % [int(first.get("year", 0)), str(first.get("when", ""))]
	var stories := []
	for it in items:
		stories.append(story(it, my_club))
	var ranked := rank(stories)
	page["lead"] = ranked[0]
	var taken := {0: true}
	var side := []
	for i in range(1, ranked.size()):
		if side.size() >= SECONDARY_MAX:
			break
		var st: Dictionary = ranked[i]
		if int(st["weight"]) >= SECONDARY_MIN and str(st["group"]) != _FIRST_GOAL:
			side.append(st)
			taken[i] = true
	page["secondary"] = side
	var groups := {}
	for i in range(ranked.size()):
		if taken.has(i):
			continue
		var g := str(ranked[i]["group"])
		if not groups.has(g):
			groups[g] = []
		groups[g].append(ranked[i])
	var briefs := []
	for key in BRIEF_ORDER:
		if groups.has(key):
			briefs.append({"key": key, "title": BRIEF_TITLE[key], "entries": groups[key]})
	page["briefs"] = briefs
	return page


## Every story on a page, lead first (the count test and the hub card use it).
static func all_stories(page: Dictionary) -> Array:
	var out := []
	if not (page["lead"] as Dictionary).is_empty():
		out.append(page["lead"])
	out.append_array(page["secondary"])
	for b in page["briefs"]:
		out.append_array(b["entries"])
	return out


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------
static func _ink(code: String) -> Color:
	return UiKit.club_name_colour(UiKit.club_ink(code)) if code != "" else UiKit.TEXT


static func _headline(st: Dictionary, fs: int) -> Label:
	var l := UiKit.lbl(str(st["headline"]), fs, _ink(str(st["club"])), true)
	l.name = "Headline"
	return l


static func _yours_tag() -> Label:
	var t := UiKit.lbl("Your club", UiKit.FINE, UiKit.EMPH, true)
	t.name = "YoursTag"
	return t


## A story with the club's bar down its side; big=true for the lead.
static func _story_block(st: Dictionary, big: bool) -> Control:
	var v := UiKit.vbox(4)
	v.name = "Lead" if big else "Story"
	if bool(st["mine"]):
		v.add_child(_yours_tag())
	if str(st["club"]) != "" and big:
		var head := UiKit.hbox(8)
		head.add_child(UiKit.club_marker(str(st["club"]), 34.0))
		head.add_child(UiKit.line(GameDB.club_name(str(st["club"])), UiKit.NAME, _ink(str(st["club"])), true))
		v.add_child(head)
	v.add_child(_headline(st, UiKit.H1 if big else UiKit.NAME))
	if str(st["standfirst"]) != "":
		v.add_child(UiKit.lbl(str(st["standfirst"]), UiKit.SECONDARY if big else UiKit.SMALL, UiKit.TEXT))
	if str(st["club"]) == "":
		return v
	return UiKit.club_section_body(str(st["club"]), v, UiKit.club_ink(str(st["club"])))


static func _brief_block(b: Dictionary, wide: bool) -> Control:
	var v := UiKit.vbox(4)
	v.name = "Brief_" + str(b["key"])
	v.add_child(UiKit.lbl(str(b["title"]), UiKit.NAME, UiKit.TEXT, true))
	v.add_child(UiKit.rule())
	if str(b["key"]) == _FIRST_GOAL:
		# Names and clubs in columns, so fifteen of them read as a list, not a column.
		var g := GridContainer.new()
		g.columns = 3 if wide else 1
		g.add_theme_constant_override("h_separation", 16)
		g.add_theme_constant_override("v_separation", 4)
		for st in b["entries"]:
			var r := _brief_row(st, str(b["key"]))
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(r)
		v.add_child(g)
		return v
	for st in b["entries"]:
		v.add_child(_brief_row(st, str(b["key"])))
	return v


static func _brief_row(st: Dictionary, key: String) -> Control:
	var club := str(st["club"])
	if key == _FIRST_GOAL and club != "":
		var h := UiKit.hbox(6)
		h.name = "BriefRow"
		h.add_child(UiKit.club_marker(club, 20.0))
		h.add_child(UiKit.line(str(st["name"]), UiKit.SECONDARY, _ink(club), true))
		h.add_child(UiKit.line(GameDB.club_short(club), UiKit.SECONDARY, UiKit.TEXT))
		return h
	var row := UiKit.vbox(0)
	row.name = "BriefRow"
	var t := str(st["headline"]) if str(st["standfirst"]) != "" else str(st["text"])
	var l := UiKit.lbl(t, UiKit.SECONDARY, _ink(club) if str(st["name"]) != "" else UiKit.TEXT, str(st["name"]) != "")
	row.add_child(l)
	if str(st["standfirst"]) != "" and key != _FIRST_GOAL:
		row.add_child(UiKit.lbl(str(st["standfirst"]), UiKit.SMALL, UiKit.TEXT))
	return row


## One round as a front page into `body`. `wide` lays it out in columns.
static func fill(body: Container, items: Array, my_club: String, wide: bool) -> void:
	var page := build(items, my_club)
	var head := UiKit.hbox(8)
	var title := UiKit.heading("League news", UiKit.H1)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(title)
	var date := UiKit.lbl(str(page["dateline"]), UiKit.NAME, UiKit.MUTED)
	date.name = "Dateline"
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(date)
	body.add_child(head)
	body.add_child(UiKit.rule())
	if (page["lead"] as Dictionary).is_empty():
		return
	var lead_panel := UiKit.panel(_wash(str(page["lead"]["club"])), 16)
	lead_panel.name = "LeadStory"
	lead_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead_panel.add_child(_story_block(page["lead"], true))
	var side := UiKit.vbox(10)
	side.name = "SecondaryStories"
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in page["secondary"]:
		var card := UiKit.panel(UiKit.PANEL, 12)
		card.add_child(_story_block(st, false))
		side.add_child(card)
	if wide and not page["secondary"].is_empty():
		var top := UiKit.hbox(14)
		top.add_child(lead_panel)
		lead_panel.size_flags_stretch_ratio = 1.5
		side.size_flags_stretch_ratio = 1.0
		top.add_child(side)
		body.add_child(top)
	else:
		body.add_child(lead_panel)
		if not page["secondary"].is_empty():
			body.add_child(side)
	if not page["briefs"].is_empty():
		var grid := GridContainer.new()
		grid.name = "Briefs"
		grid.columns = 2 if wide else 1
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 16)
		var long_one: Control = null
		for b in page["briefs"]:
			var blk := _brief_block(b, wide)
			blk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if wide and str(b["key"]) == _FIRST_GOAL:
				long_one = blk  # the long list takes the whole row, under the short briefs
			else:
				grid.add_child(blk)
		body.add_child(grid)
		if long_one != null:
			body.add_child(long_one)
	# Earlier rounds: the same grouping, as plain lines under a dateline.
	var older := rounds(older_items(items))
	if not older.is_empty():
		body.add_child(UiKit.lbl("Earlier", UiKit.H2, UiKit.TEXT, true))
		for r in older:
			var pg := build(r, my_club)
			body.add_child(UiKit.lbl(str(pg["dateline"]), UiKit.SECONDARY, UiKit.EMPH, true))
			for st in all_stories(pg):
				body.add_child(_earlier_line(st))


static func older_items(items: Array) -> Array:
	return items.slice(latest_round(items).size())


static func _earlier_line(st: Dictionary) -> Control:
	var row := UiKit.vbox(0)
	row.name = "EarlierLine"
	var named := str(st["name"]) != ""
	row.add_child(UiKit.lbl(str(st["headline"]) if str(st["standfirst"]) != "" else str(st["text"]),
			UiKit.SECONDARY, _ink(str(st["club"])) if named else UiKit.TEXT, named))
	return row


static func _wash(club: String) -> Color:
	if club == "":
		return UiKit.PANEL
	return UiKit.PANEL.lerp(UiKit.club_ink(club), 0.22)


## The hub's small front page: the lead and up to three more headlines, the
## whole card one tap (the button named NewsMore sits behind the words).
static func mini(items: Array, my_club: String, on_open: Callable) -> Control:
	var page := build(latest_round(items), my_club)
	var card := MarginContainer.new()
	card.name = "NewsCard"
	var tap := Button.new()
	tap.name = "NewsMore"
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.custom_minimum_size = Vector2(0, 44)
	tap.pressed.connect(on_open)
	card.add_child(tap)
	var v := UiKit.vbox(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var top := UiKit.hbox(8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UiKit.section("League news")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var d := UiKit.lbl(str(page["dateline"]), UiKit.SECONDARY, UiKit.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(d)
	top.add_child(UiKit.lbl("›", UiKit.NAME, UiKit.MUTED))
	v.add_child(top)
	if not (page["lead"] as Dictionary).is_empty():
		var lead := UiKit.panel(_wash(str(page["lead"]["club"])), 12)
		lead.add_child(_story_block(page["lead"], true))
		v.add_child(lead)
		for st in page["secondary"]:
			v.add_child(_story_block(st, false))
	_ignore_mouse(v)
	return card


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)
