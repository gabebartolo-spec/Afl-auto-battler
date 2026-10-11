class_name Leadership
extends RefCounted
## A player's Leadership rating (1-99), shown beside his other ratings.
##
## What it measures: how much a dressing room follows him. It is NOT his
## playing quality: OVR and the attributes never feed it, and appointing a
## captain does not raise it. It is worked out when asked, from facts the save
## already holds, so an older save simply has it and nothing new is stored:
##   - senior games (career total, this season included),
##   - age,
##   - years at his current club,
##   - a captaincy or leadership-group role in the 2026 public record
##     (data/leadership_2026.csv, from the clubs' own announcements), real
##     players only,
##   - for an invented player only, a fixed spread from his id, so two players
##     with the same games and age are not clones. A real player never gets an
##     invented character judgement: his number comes from the facts above.
## It is never trained and never moves by hand; it climbs as games and years
## at the club add up. Captaincy years and the armband arrive with the
## appointment work (P2-2), which then feeds this the same way.

const PATH := "res://data/leadership_2026.csv"
const FLOOR := 22
const CEILING := 96
## Role bonus, best role only (they never stack).
const ROLE_BONUS := {"captain": 16, "vice": 11, "group": 7}
const ROLE_WORDS := {"captain": "Captain", "vice": "Vice-captain", "group": "Leadership group"}
const SEASON := 2026
## Experience: one point per this many games (to 28), then age and tenure.
const GAMES_PER_POINT := 8.0
const GAMES_MAX := 28.0
const AGE_FROM := 20.0
const AGE_PER_YEAR := 1.2
const AGE_MAX := 12.0
const TENURE_PER_YEAR := 1.5
const TENURE_MAX := 8.0
const BASE := 30.0
## Spread for an invented player, either way.
const SPREAD := 7

static var _roles: Dictionary = {}
static var _loaded := false


static func reload() -> void:
	_loaded = false
	_roles = {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_roles = {}
	if not FileAccess.file_exists(PATH):
		return
	var lines := FileAccess.get_file_as_string(PATH).split("\n", false)
	for i in range(1, lines.size()):
		var c := lines[i].strip_edges().split(",")
		if c.size() < 4:
			continue
		var key := ("%s %s" % [c[1], c[2]]).to_lower()
		var role := str(c[3])
		if not ROLE_BONUS.has(role):
			continue
		# A player on two lists keeps the better role.
		if not _roles.has(key) or int(ROLE_BONUS[role]) > int(ROLE_BONUS[_roles[key]]):
			_roles[key] = role


## His 2026 role from the public record: "captain", "vice", "group" or "".
static func role_2026(p: Dictionary) -> String:
	_load()
	var real := str(p.get("real_name", "")).strip_edges().to_lower()
	if real == "":
		return ""
	return str(_roles.get(real, ""))


## "Captain in 2026" and so on, or "" for anyone without a role on record.
static func role_line(p: Dictionary) -> String:
	var r := role_2026(p)
	if r == "":
		return ""
	return "%s in %d" % [ROLE_WORDS[r], SEASON]


static func is_real(p: Dictionary) -> bool:
	return str(p.get("real_name", "")).strip_edges() != ""


## His senior games, whatever the save knows: the career record, or this
## season's games when that is all there is.
static func games(p: Dictionary) -> int:
	var c = p.get("career")
	var g := 0
	if c is Dictionary:
		g = int((c as Dictionary).get("games", 0))
	return maxi(g, int(p.get("gm", 0)))


## Whole years he has been at his current club (the last stint, if it is this club).
static func tenure_years(p: Dictionary) -> int:
	var c = p.get("career")
	if not (c is Dictionary):
		return 0
	var stints: Array = (c as Dictionary).get("stints", [])
	if stints.is_empty():
		return 0
	var s: Array = stints[stints.size() - 1]
	if str(s[0]) != str(p.get("club", "")):
		return 0
	return maxi(0, int(s[2]) - int(s[1]) + 1)


## The rating, 1-99.
static func of(p: Dictionary) -> int:
	var v := BASE
	v += minf(float(games(p)) / GAMES_PER_POINT, GAMES_MAX)
	v += clampf((float(p.get("age", AGE_FROM)) - AGE_FROM) * AGE_PER_YEAR, 0.0, AGE_MAX)
	v += minf(float(tenure_years(p)) * TENURE_PER_YEAR, TENURE_MAX)
	var r := role_2026(p)
	if r != "":
		v += float(ROLE_BONUS[r])
	if not is_real(p):
		v += float(abs(str(p.get("id", "")).hash()) % (2 * SPREAD + 1) - SPREAD)
	return clampi(int(round(v)), FLOOR, CEILING)


## One line for the profile's drill-down: what the number is made of.
static func basis_text() -> String:
	return "Leadership comes from games played, age, years at his club and any captaincy or leadership-group role. It is not his playing quality, and it is never trained."
