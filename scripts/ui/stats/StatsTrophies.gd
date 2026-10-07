class_name StatsTrophies
extends RefCounted
## Season stats > Trophy room: your time at your club. Three groups, kept
## apart: the club's honours (premierships, minor premierships, its
## achievement), your players' honours, and your own seasons in charge.
##
## Tenure: a coach stays with the club he starts a career at (the sack ends
## the career), and every honour roll entry records the club you coached
## that season. Only entries for your club count, and the honour roll holds
## only seasons played in this save, so nothing from before your time is ever
## credited. What an older save didn't record is said plainly, never filled in.

const SHELF_ART := 96.0
const SHEET_ART := 280.0
const SHEET_MAX_W := 480.0
const TABLE_W := 600.0
## Rows: one line, no rules between them; every other row on a faint band
## (the hub's shared row style).
const ROW_H := 32
## On a phone a row is a thumb's target: taller.
const ROW_H_PHONE := 40
## The honours a player can win, as the honour roll stores them: the entry's
## key, the art's id, the honour's name, the count's key and its unit.
const PLAYER_HONOURS := [
	["brownlow", "league_bnf_medal", "Brownlow Medal", "votes", "vote"],
	["coleman", "leading_goalkicker_medal", "Coleman Medal", "goals", "goal"],
	["rising_star", "rising_star", "Rising Star", "", ""],
	["coaches_award", "coaches_award", "Coaches Award", "coaches", "vote"],
	["my_bf", "club_bnf", "Best and fairest", "bf", "best and fairest vote"],
]
const FINALS := {"WC": "Wildcard round", "QF": "Qualifying final", "EF": "Elimination final",
		"SF": "Semi final", "PF": "Preliminary final", "GF": "Grand Final"}


static func build(host: Control) -> Control:
	var v := UiKit.vbox(6)
	v.name = "StatsTrophies"
	var club := GameState.my_club
	var seasons := tenure()
	var in_progress := _in_progress()
	var first: int = int(seasons[0]["year"]) if not seasons.is_empty() else GameState.season_year
	var count := seasons.size() + (1 if in_progress else 0)
	var intro := _para("Your time at %s: %d %s, from %d." % [GameDB.club_name(club), count,
			"season" if count == 1 else "seasons", first], UiKit.TEXT)
	intro.name = "TrophiesTenure"
	v.add_child(intro)
	v.add_child(_club_honours(host, seasons))
	v.add_child(_player_honours(host, seasons))
	v.add_child(_tenure_table(host, seasons, in_progress))
	return v


## Your completed seasons at your club, oldest first (the honour roll).
static func tenure() -> Array:
	var out := []
	if GameState.my_club == "":
		return out
	for e in GameState.honour_roll:
		if str(e.get("my_club", "")) == GameState.my_club:
			out.append(e)
	out.sort_custom(func(a, b): return int(a["year"]) < int(b["year"]))
	return out


## This season, while it is still being played.
static func _in_progress() -> bool:
	if GameState.season == null:
		return false
	for e in GameState.honour_roll:
		if int(e.get("year", 0)) == GameState.season_year:
			return false
	return true


# ---------------------------------------------------------------------------
# Club honours
# ---------------------------------------------------------------------------
static func _club_honours(host: Control, seasons: Array) -> Control:
	var v := UiKit.vbox(6)
	v.name = "ClubHonours"
	_title(v, "Club honours")
	var club := GameState.my_club
	var items := []
	var flags := 0
	for i in range(seasons.size() - 1, -1, -1):
		var e: Dictionary = seasons[i]
		var year := int(e["year"])
		if str(e.get("premier", "")) == club:
			flags += 1
			items.append({"kind": "premiership", "year": year, "entry": e})
		if int(e.get("my_position", 0)) == 1:
			items.append({"kind": "minor_premiership", "year": year, "entry": e})
	if flags == 0:
		var none := _para("No premierships yet.")
		none.name = "NoPremierships"
		v.add_child(none)
	if not items.is_empty():
		var shelf := _shelf("ClubShelf")
		for it in items:
			shelf.add_child(_club_item(host, it))
		v.add_child(shelf)
	var ach := _achievement(seasons)
	if ach != null:
		v.add_child(ach)
	return v


static func _club_item(host: Control, it: Dictionary) -> Button:
	var club := GameState.my_club
	var year := int(it["year"])
	var art: Control
	var label := ""
	if str(it["kind"]) == "premiership":
		var pair := UiKit.hbox(4)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_child(HonoursArt.view("premiership_cup", SHELF_ART, club, 0, "Premiership cup"))
		pair.add_child(HonoursArt.view("premiership_flag", SHELF_ART, club, year, "Premiership flag"))
		art = pair
		label = "Premiers"
	else:
		art = HonoursArt.view("minor_premiership", SHELF_ART, club, year, "Minor premiership")
		label = "Minor premiers"
	var b := _item(art, label, str(year))
	b.name = "Club_%s_%d" % [str(it["kind"]), year]
	b.pressed.connect(func(): _open_club(host, it))
	return b


## Your club's achievement (Achievements.gd): when it came, or what it asks.
static func _achievement(seasons: Array) -> Control:
	var d := Achievements.definition_by_club(GameState.my_club)
	if d.is_empty():
		return null
	var v := UiKit.vbox(2)
	v.name = "ClubAchievement"
	var got: Dictionary = GameState.achievements.get(str(d["id"]), {})
	var start := int(seasons[0]["year"]) if not seasons.is_empty() else GameState.season_year
	if not got.is_empty() and int(got.get("year", 0)) >= start:
		v.add_child(UiKit.lbl("%s, %d" % [str(d["name"]), int(got["year"])], UiKit.BODY, UiKit.TEXT, true))
		v.add_child(_para(str(d["desc"])))
	else:
		v.add_child(UiKit.lbl(str(d["name"]), UiKit.BODY, UiKit.MUTED, true))
		v.add_child(_para("Not yet: " + str(d["desc"])))
	return v


# ---------------------------------------------------------------------------
# Players' honours
# ---------------------------------------------------------------------------
## Your club's players' honours in your seasons, newest first.
static func player_honours(seasons: Array) -> Array:
	var club := GameState.my_club
	var out := []
	for i in range(seasons.size() - 1, -1, -1):
		var e: Dictionary = seasons[i]
		var year := int(e["year"])
		for h in PLAYER_HONOURS:
			var rows: Array = e.get(str(h[0]), [])
			if rows.is_empty():
				continue
			var r: Dictionary = rows[0]
			# The club best and fairest is always one of yours.
			if str(h[0]) != "my_bf" and str(r.get("club", "")) != club:
				continue
			var count := ""
			if str(h[3]) != "":
				var n := int(r.get(str(h[3]), 0))
				count = "%d %s" % [n, str(h[4]) if n == 1 else str(h[4]) + "s"]
			out.append({"art": str(h[1]), "name": str(h[2]), "id": str(r.get("id", "")),
					"year": year, "count": count})
		for id in e.get("my_aa", []):
			out.append({"art": "all_australian", "name": "All-Australian", "id": str(id),
					"year": year, "count": ""})
	return out


static func _player_honours(host: Control, seasons: Array) -> Control:
	var v := UiKit.vbox(6)
	v.name = "PlayerHonours"
	_title(v, "Players' honours")
	var items := player_honours(seasons)
	if items.is_empty():
		var none := _para("No player honours yet.")
		none.name = "NoPlayerHonours"
		v.add_child(none)
	else:
		var shelf := _shelf("PlayerShelf")
		for i in range(items.size()):
			var it: Dictionary = items[i]
			var art := HonoursArt.view(str(it["art"]), SHELF_ART, GameState.my_club, int(it["year"]), str(it["name"]))
			var b := _item(art, GameState.award_name({"id": str(it["id"])}), "%s %d" % [str(it["name"]), int(it["year"])])
			b.name = "Player_%d" % i
			b.pressed.connect(func(): _open_player(host, it))
			shelf.add_child(b)
		v.add_child(shelf)
	var missing := []
	for e in seasons:
		if not e.has("my_aa"):
			missing.append(int(e["year"]))
	if not missing.is_empty():
		var gap := _para("All-Australian selections weren't kept for %s in this save." % _years(missing))
		gap.name = "AAUnrecorded"
		v.add_child(gap)
	return v


# ---------------------------------------------------------------------------
# Your seasons
# ---------------------------------------------------------------------------
static func _tenure_table(host: Control, seasons: Array, in_progress: bool) -> Control:
	var v := UiKit.vbox(0)
	v.name = "Tenure"
	if bool(host.call("wide")):
		v.custom_minimum_size.x = TABLE_W
		v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_title(v, "Your seasons")
	v.add_child(_tenure_row(["Season", "Finish", "Record", "Finals"], true))
	var row_h := ROW_H if bool(host.call("wide")) else ROW_H_PHONE
	var n := 0
	if in_progress:
		var r := _tenure_row([str(GameState.season_year), GameState.ordinal(GameState.my_position()),
				GameState.my_record(), "In progress"], false, false, row_h)
		n += 1
		r.name = "Season_%d" % GameState.season_year
		v.add_child(r)
	var club := GameState.my_club
	var no_record := []
	var no_finals := []
	var w := 0
	var l := 0
	var d := 0
	for i in range(seasons.size() - 1, -1, -1):
		var e: Dictionary = seasons[i]
		var year := int(e["year"])
		var finals := ""
		if str(e.get("premier", "")) == club:
			finals = "Premiers"
		elif str(e.get("runner_up", "")) == club:
			finals = "Runners-up"
		elif e.has("my_finals"):
			finals = str(FINALS.get(str(e["my_finals"]).substr(0, 2), ""))
		else:
			no_finals.append(year)
		var rec := str(e.get("my_record", ""))
		if rec == "":
			no_record.append(year)
		else:
			var parts := rec.split("-")
			if parts.size() == 3:
				w += int(parts[0])
				l += int(parts[1])
				d += int(parts[2])
		var pos := int(e.get("my_position", 0))
		var r := _tenure_row([str(year), GameState.ordinal(pos) if pos > 0 else "", rec, finals], false,
				n % 2 == 1, row_h)
		n += 1
		r.name = "Season_%d" % year
		v.add_child(r)
	var kept := seasons.size() - no_record.size()
	if kept > 0:
		var span := "Across %d completed %s" % [kept, "season" if kept == 1 else "seasons"] if no_record.is_empty() \
				else "Across the %d %s with a record" % [kept, "season" if kept == 1 else "seasons"]
		var total := _para("%s: %d %s, %d %s, %d %s." % [span, w, "win" if w == 1 else "wins",
				l, "loss" if l == 1 else "losses", d, "draw" if d == 1 else "draws"])
		total.name = "TenureTotals"
		v.add_child(total)
	if not no_record.is_empty():
		var gap := _para("Win-loss records weren't kept for %s in this save." % _years(no_record))
		gap.name = "RecordUnrecorded"
		v.add_child(gap)
	if not no_finals.is_empty():
		var gap := _para("How far the finals went wasn't kept for %s in this save." % _years(no_finals))
		gap.name = "FinalsUnrecorded"
		v.add_child(gap)
	return v


static func _tenure_row(cols: Array, head: bool, band := false, row_h := ROW_H) -> Control:
	var p := PanelContainer.new()
	var flat := StyleBoxFlat.new()
	flat.bg_color = UiKit.PANEL if band else Color.TRANSPARENT
	flat.content_margin_left = 4
	flat.content_margin_right = 4
	p.add_theme_stylebox_override("panel", flat)
	var h := UiKit.hbox(8)
	h.custom_minimum_size.y = 24 if head else row_h
	p.add_child(h)
	var widths := [56, 56, 72, 0]
	for i in range(cols.size()):
		var text := str(cols[i])
		var l := UiKit.line(text, 12 if head else UiKit.BODY,
				UiKit.MUTED if head or i == 0 else UiKit.TEXT, not head and text == "Premiers")
		l.custom_minimum_size.x = float(widths[i])
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if i == 3:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
	return p


# ---------------------------------------------------------------------------
# Shelves and sheets
# ---------------------------------------------------------------------------
static func _shelf(node: String) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.name = node
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 12)
	return f


## One thing on a shelf: its picture over two short lines. A flat button: the
## whole of it takes the tap.
static func _item(art: Control, top: String, bottom: String) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color.TRANSPARENT
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(UiKit.TEXT, 0.05)
	hover.set_corner_radius_all(UiKit.RADIUS)
	for state in ["normal", "focus"]:
		b.add_theme_stylebox_override(state, flat)
	for state in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, hover)
	var v := UiKit.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	# As narrow as the art, so three fit across a phone: the name on one line,
	# the honour and year wrapping under it if they must.
	var width := maxf(SHELF_ART + 4.0, art.get_combined_minimum_size().x)
	var name_l := UiKit.ellipsis(top, UiKit.SMALL, UiKit.TEXT, true)
	name_l.name = "Top"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.custom_minimum_size.x = width
	v.add_child(name_l)
	var what := UiKit.lbl(bottom, 12, UiKit.MUTED)
	what.name = "Bottom"
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	what.custom_minimum_size.x = width
	v.add_child(what)
	b.add_child(v)
	var full := v.get_combined_minimum_size() + Vector2(8, 8)
	b.custom_minimum_size = full
	v.position = Vector2(4, 4)
	v.size = full - Vector2(8, 8)
	_ignore_mouse(v)
	return b


static func _open_club(host: Control, it: Dictionary) -> void:
	var year := int(it["year"])
	var e: Dictionary = it["entry"]
	var club := GameState.my_club
	var lines := []
	var art: Control
	var title := ""
	if str(it["kind"]) == "premiership":
		# The cup and the flag side by side, as large as the sheet allows.
		var h := minf(SHEET_ART * 0.8, (_sheet_w(host) - 8.0) / 2.0)
		var pair := UiKit.hbox(8)
		pair.add_child(HonoursArt.view("premiership_cup", h, club, 0, "Premiership cup"))
		pair.add_child(HonoursArt.view("premiership_flag", h, club, year, "Premiership flag"))
		art = pair
		title = "Premiers %d" % year
		var opp := str(e.get("runner_up", ""))
		if opp != "":
			lines.append("Beat %s in the Grand Final." % GameDB.club_name(opp))
		var pos := int(e.get("my_position", 0))
		if pos > 0:
			lines.append("Finished %s on the ladder." % GameState.ordinal(pos))
	else:
		art = HonoursArt.view("minor_premiership", minf(SHEET_ART, _sheet_w(host)), club, year, "Minor premiership")
		title = "Minor premiers %d" % year
		lines.append("Top of the ladder after the home and away season.")
		var rec := str(e.get("my_record", ""))
		if rec != "":
			lines.append("Record: %s." % rec)
	_sheet(host, "ClubHonourSheet", art, title, lines)


static func _open_player(host: Control, it: Dictionary) -> void:
	var art := HonoursArt.view(str(it["art"]), minf(SHEET_ART, _sheet_w(host)), GameState.my_club,
			int(it["year"]), str(it["name"]))
	var lines := [GameState.award_name({"id": str(it["id"])})]
	var count := str(it["count"])
	if count != "":
		lines.append(count.substr(0, 1).to_upper() + count.substr(1) + ".")
	_sheet(host, "PlayerHonourSheet", art, "%s %d" % [str(it["name"]), int(it["year"])], lines)


## The width inside an honour's sheet: 480 at most, less its padding.
static func _sheet_w(host: Control) -> float:
	return minf(SHEET_MAX_W, UiKit.view_width(host) - 24.0) - 40.0


static func _sheet(host: Control, node: String, art: Control, title: String, lines: Array) -> void:
	var box := UiKit.modal_box(host, SHEET_MAX_W, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = node
	var body: VBoxContainer = box["body"]
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(art)
	var t := UiKit.lbl(title, 22, UiKit.TEXT, true)
	t.name = "SheetTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(t)
	for i in range(lines.size()):
		var l := _para(str(lines[i]), UiKit.TEXT)
		l.name = "SheetLine_%d" % i
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(l)
	var close := UiKit.btn("Close", UiKit.NAME)
	close.name = "SheetClose"
	close.custom_minimum_size.y = 48
	var footer: VBoxContainer = box["footer"]
	footer.add_child(close)
	close.pressed.connect(func():
		if host.has_method("close_sheet"):
			host.call("close_sheet")
		else:
			overlay.queue_free())
	if host.has_method("open_sheet"):
		host.call("open_sheet", overlay)


## A section's title, with 16 px of air above it.
static func _title(v: Control, text: String) -> void:
	var air := Control.new()
	air.custom_minimum_size.y = 16
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(air)
	var t := UiKit.section(text)
	t.name = "Title"
	v.add_child(t)


## "2027", "2027 and 2028", "2026, 2027 and 2028".
static func _years(years: Array) -> String:
	var s: PackedStringArray = []
	for y in years:
		s.append(str(y))
	if s.size() == 1:
		return s[0]
	return ", ".join(s.slice(0, s.size() - 1)) + " and " + s[s.size() - 1]


static func _para(text: String, colour := UiKit.MUTED) -> Label:
	var l := UiKit.lbl(text, UiKit.SMALL, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)
