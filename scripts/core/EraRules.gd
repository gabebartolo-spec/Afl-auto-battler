class_name EraRules
extends RefCounted
## The league's rules as they stood in a given season, read from
## data/legacy/era_rules.csv (rule,value,from_year,to_year,quote,source_url,
## checked). Each row holds one rule for an inclusive span of years, with the
## quote and source it was taken from. Legacy mode reads it for the salary
## cap (Contracts.salary_cap_for_year) and the season's rules (TODO row 142,
## L4): list sizes, the rookie list, free agency, the interchange bench and the
## substitute, each from the year it began (director 2026-11-10: "Each rule
## ... arrives in the year it began").
##
## The season being played sets `year` (GameState.season_year's setter), so
## the rules switch at every rollover. A season from GAME_FROM on, or year 0
## (no season), plays the game's own rules (GAME), exactly as before Legacy
## mode: a 2026 career never reads the file for its rules.
##
## A static class rather than GameDB code so sim scripts (Contracts) can read
## it without depending on an autoload; GameDB.era_rule is the front door.

const PATH := "res://data/legacy/era_rules.csv"

## The game's own league: 2026 on. The counts are its constants
## (Contracts.MAX_LIST 44 = 38 senior + 6 Category A, RookieList.CAT_B_SPOTS,
## Ratings.INTERCHANGE); the switches are all on, the substitute off.
const GAME := {
	"senior_list_max": 38, "rookie_list_max": 6, "cat_b_rookie": 2, "list_min": 37,
	"interchange": 5, "substitutes": 0, "medical_sub": 0,
	"rookie_list": 1, "free_agency": 1, "midseason_draft": 1, "coaches_votes": 1,
}
## The first season that plays GAME whatever the file says.
const GAME_FROM := 2026
## Switches: off in an era season with no row (the rookie list before 1997,
## free agency before 2012, the coaches' votes before 2003). Counts fall back
## to GAME's value.
const SWITCHES := ["rookie_list", "free_agency", "midseason_draft", "medical_sub", "substitutes", "cat_b_rookie",
		"coaches_votes"]

## The season being played (GameState sets it with season_year); 0 = none.
static var year := 0
## True once the season's off-season is open (GameState.offseason_year): the
## lists are then being built for the next season, so list limits read the
## next year's rules (the 1993 off-season cuts to 1994's 42; the 1996 one
## opens the 1997 rookie list). The bench stays the season's own.
static var list_ahead := false

static var _rows := {}  # rule -> Array of [from_year, to_year, value]
static var _loaded := false


## The value of `rule` in `year`, or `fallback` when no row covers that year.
static func value(rule_name: String, y: int, fallback := 0.0) -> float:
	for span in _spans(rule_name):
		if y >= int(span[0]) and y <= int(span[1]):
			return float(span[2])
	return fallback


## Whether `y` is a season the real record's rules govern (before GAME_FROM).
static func is_era(y: int) -> bool:
	return y > 0 and y < GAME_FROM


## A season rule in season `y` (-1: the season being played): GAME's value
## from GAME_FROM on, the file's in an era season. An era season with no row
## for the rule has a switch off and a count at GAME's value.
static func rule(name: String, y := -1) -> int:
	var at := year if y < 0 else y
	var game := int(GAME.get(name, 0))
	if not is_era(at):
		return game
	return int(value(name, at, 0.0 if SWITCHES.has(name) else float(game)))


## Whether a switch rule (rookie_list, free_agency, ...) is on in season `y`.
static func on(name: String, y := -1) -> bool:
	return rule(name, y) > 0


## The year whose list limits apply (-1: the lists being built now).
static func list_year(y := -1) -> int:
	if y >= 0:
		return y
	return year + 1 if list_ahead and year > 0 else year


## Senior and Category A spots together (the game's "44").
static func list_max(y := -1) -> int:
	return senior_spots(y) + cat_a_spots(y)


## The fewest players a list may hold, senior and rookies together (director
## 2026-11-13: lists by era). On record from 2004 (37, then 38; 37 from 2021,
## 36 senior and one rookie); before 2004 no minimum is recorded and the year's
## senior maximum less four stands in (director 2026-11-13).
static func list_min(y := -1) -> int:
	return rule("list_min", list_year(y))


static func senior_spots(y := -1) -> int:
	return rule("senior_list_max", list_year(y))


## Category A rookie spots: none before the rookie list began (1997).
static func cat_a_spots(y := -1) -> int:
	var at := list_year(y)
	return rule("rookie_list_max", at) if on("rookie_list", at) else 0


## Category B rookie spots: none before Category B began.
static func cat_b_spots(y := -1) -> int:
	return rule("cat_b_rookie", list_year(y))


## Interchange players on the bench.
static func interchange(y := -1) -> int:
	return rule("interchange", y)


## Substitutes named beside the bench (0, or 1 in 2011-15 and 2021-25).
static func substitutes(y := -1) -> int:
	return rule("substitutes", y)


## Whether the substitute may come on only for an injured player (the
## medical substitute, 2021-25) rather than at any time (2011-15).
static func medical_sub(y := -1) -> bool:
	return on("medical_sub", y)


## Whether a row covers `rule` in `year`.
static func has(rule_name: String, y: int) -> bool:
	for span in _spans(rule_name):
		if y >= int(span[0]) and y <= int(span[1]):
			return true
	return false


## The years the CSV covers for `rule`: [first, last], or [] when it has none.
static func span(rule_name: String) -> Array:
	var spans := _spans(rule_name)
	if spans.is_empty():
		return []
	var lo := int(spans[0][0])
	var hi := int(spans[0][1])
	for s in spans:
		lo = mini(lo, int(s[0]))
		hi = maxi(hi, int(s[1]))
	return [lo, hi]


static func _spans(rule_name: String) -> Array:
	if not _loaded:
		_load()
	return _rows.get(rule_name, [])


static func _load() -> void:
	_loaded = true
	_rows = {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("EraRules: cannot open %s" % PATH)
		return
	var head := f.get_csv_line()
	var col := {}
	for i in head.size():
		col[head[i]] = i
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 4 or str(row[0]).strip_edges() == "":
			continue
		var rname := str(row[int(col.get("rule", 0))])
		if not _rows.has(rname):
			_rows[rname] = []
		(_rows[rname] as Array).append([int(row[int(col.get("from_year", 2))]),
				int(row[int(col.get("to_year", 3))]), float(row[int(col.get("value", 1))])])
	# Earliest span first, so a lookup reads the file's years in order.
	for rname in _rows:
		(_rows[rname] as Array).sort_custom(func(a, b): return int(a[0]) < int(b[0]))
