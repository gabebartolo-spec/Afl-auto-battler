class_name ClubForge
extends RefCounted
## Club Forge, Create a club (ARD-M7-009): the identity of the one club a
## career may add. A created club is an extra member of the competition, never
## a reskin of an existing one. It enters with the career (director,
## 2026-10-06): it drafts its list in the League Draft like everyone else, and
## from then on it is a club like any other.
##
## A spec is plain save data:
##   {"name", "short" (nickname), "code" (2-4 letters), "location" (an id in
##    data/forge_locations.json), "ground" (the place's ground or one of its
##    alternatives; default the place's ground), "primary", "secondary",
##    "accent" ("#RRGGBB"), "design" (a guernsey design), "kit" (which colour
##    is the guernsey, the pattern, the pattern's second colour and the shorts:
##    "p/s/a" or "p/s/a/s", tokens p, s or a)}.

const LOCATIONS_PATH := "res://data/forge_locations.json"
## Codes that already mean something: the fixture's bye and renamed old codes.
const RESERVED_CODES := ["BYE"]
## Guernsey designs a created club may wear: the vignette set less the coach's
## suit and Tasmania's map of the island.
const DESIGNS := ["plain", "stripes", "hoops", "sash", "yoke", "band", "chevrons", "panels",
		"chevron", "sides", "tiers", "shoulders"]
const NAME_MAX := 24
const SHORT_MAX := 16
## How far apart (RGB distance, 0-1.73) the guernsey and its pattern must be
## for the design to read on a small screen.
const MIN_CONTRAST := 0.25

static var _locations: Array = []


static func locations() -> Array:
	if _locations.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LOCATIONS_PATH))
		if parsed is Dictionary:
			_locations = parsed.get("locations", [])
	return _locations


static func location(id: String) -> Dictionary:
	for loc in locations():
		if str(loc.get("id", "")) == id:
			return loc
	return {}


## The grounds a place offers: its own first, then any alternatives.
static func grounds(loc: Dictionary) -> Array:
	var out := [str(loc.get("ground", ""))]
	for g in loc.get("ground_alternatives", []):
		var name := str(g.get("ground", g)) if g is Dictionary else str(g)
		if name != "" and not out.has(name):
			out.append(name)
	return out


## What is wrong with a spec, in the words the creator shows, or "" when it
## makes a club.
static func club_problem(spec: Dictionary) -> String:
	var name := str(spec.get("name", "")).strip_edges()
	if name.length() < 2:
		return "Give the club a name."
	if name.length() > NAME_MAX:
		return "Keep the name to %d letters." % NAME_MAX
	var short := str(spec.get("short", "")).strip_edges()
	if short.length() < 2:
		return "Give the club a nickname."
	if short.length() > SHORT_MAX:
		return "Keep the nickname to %d letters." % SHORT_MAX
	var code := str(spec.get("code", "")).strip_edges()
	if not _is_code(code):
		return "The abbreviation is two to four capital letters."
	for other in GameDB.clubs:
		var c: Dictionary = GameDB.clubs[other]
		if bool(c.get("custom", false)):
			continue
		if str(other) == code:
			return "%s already goes by %s." % [str(c.get("name", other)), code]
		if str(c.get("name", "")).to_lower() == name.to_lower():
			return "There is already a club called %s." % name
	if GameDB.CLUB_ORDER.has(code) or RESERVED_CODES.has(code) or CareerSave.RENAMED_CLUBS.has(code):
		return "%s is taken. Try another abbreviation." % code
	var loc := location(str(spec.get("location", "")))
	if loc.is_empty():
		return "Choose where the club is from."
	var ground := str(spec.get("ground", ""))
	if ground != "" and not grounds(loc).has(ground):
		return "Choose one of %s's grounds." % str(loc.get("place", ""))
	for key in ["primary", "secondary", "accent"]:
		if not Color.html_is_valid(str(spec.get(key, ""))):
			return "Choose the club's three colours."
	if not DESIGNS.has(str(spec.get("design", "plain"))):
		return "Choose a guernsey design."
	var kit := _kit(spec)
	if kit.is_empty():
		return "Choose which colours the guernsey wears."
	var cols := _colours(spec)
	var base: Color = cols["psa".find(kit[0])]
	var pattern: Color = cols["psa".find(kit[1])]
	if str(spec.get("design", "plain")) != "plain" and _distance(base, pattern) < MIN_CONTRAST:
		return "The guernsey and its pattern need colours you can tell apart."
	return ""


## The club as GameDB keeps it (the shape data/clubs.csv loads into), or {}
## when the spec has a problem.
static func make_club(spec: Dictionary) -> Dictionary:
	return row(spec) if club_problem(spec) == "" else {}


## The club from a spec without judging it: a saved club loads as it was made
## even if the library or the rules have changed since.
static func row(spec: Dictionary) -> Dictionary:
	var loc := location(str(spec.get("location", "")))
	var cols := _colours(spec)
	var ground := str(spec.get("ground", ""))
	var kit := _kit(spec)
	return {
		"code": str(spec["code"]).strip_edges(),
		"name": str(spec["name"]).strip_edges(),
		"short": str(spec["short"]).strip_edges(),
		"primary": cols[0], "secondary": cols[1], "accent": cols[2],
		"ground": ground if ground != "" else str(loc.get("ground", "")),
		"enter": GameDB.START_YEAR,
		"guernsey": "%s:%s" % [str(spec.get("design", "plain")), "/".join(kit if not kit.is_empty() else ["p", "s", "a"])],
		"location": str(spec.get("location", "")),
		"place": str(loc.get("place", "")),
		"state": str(loc.get("state", "")),
		"custom": true,
	}


static func _is_code(code: String) -> bool:
	if code.length() < 2 or code.length() > 4:
		return false
	for ch in code:
		if ch < "A" or ch > "Z":
			return false
	return true


## The kit tokens, or [] when they are not three or four of p, s and a with
## the guernsey and its pattern in different colours.
static func _kit(spec: Dictionary) -> Array:
	var tokens := str(spec.get("kit", "p/s/a")).split("/")
	if tokens.size() < 3 or tokens.size() > 4:
		return []
	for t in tokens:
		if not ["p", "s", "a"].has(t):
			return []
	if tokens[0] == tokens[1]:
		return []
	return Array(tokens)


static func _colours(spec: Dictionary) -> Array:
	var out := []
	for key in ["primary", "secondary", "accent"]:
		out.append(Color.from_string(str(spec.get(key, "")), Color.WHITE))
	return out


static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
