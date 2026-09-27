class_name Career
extends RefCounted
## A player's senior career across the whole dynasty: games, goals and the
## clubs he played for. Pure rules; GameState applies them once a season.
##
## Stored on the player as p["career"], separate from p["history"] (which
## feeds potential and must not change):
##
##   games, goals  every counted season, finals included
##   stints        [[club, first year, last year, games, goals], ...] - an
##                 unbroken run at one club; a season lost to injury does not
##                 split it, a spell at another club does
##   through       the last season counted, so a season is never added twice
##                 (a reload around the season's close, or both call sites)
##   unknown       [[from, to], ...] seasons that could not be counted: the
##                 years before a career began for a player with no source
##                 (from = 0), or seasons an older save played before this
##                 record existed. Totals never guess at them.
##
## Real players arrive with their AFL career to 2025 (tools/build_history.py,
## one AFL Tables page per season). Everyone else starts from nothing.
##
## Approximation: a season is credited to the club he played his last game of
## it for. The game trades between seasons, so this is exact in practice.

## The last real season before the game begins.
const BEFORE_GAME := 2025


static func fresh() -> Dictionary:
	return {"games": 0, "goals": 0, "stints": [], "through": 0, "unknown": []}


## A player's record, created empty the first time it is needed (a draftee,
## a generated or expansion player).
static func of(p: Dictionary) -> Dictionary:
	if not (p.get("career") is Dictionary):
		p["career"] = fresh()
	return p["career"]


## The dataset's career column: "CLUB:first:last:games:goals;..." for AFL
## seasons to 2025, "" for no senior games yet, "?" when unknown.
static func from_source(text: String) -> Dictionary:
	var c := fresh()
	c["through"] = BEFORE_GAME
	var t := text.strip_edges()
	if t == "?":
		c["unknown"] = [[0, BEFORE_GAME]]
		return c
	for chunk in t.split(";", false):
		var parts := chunk.split(":")
		if parts.size() != 5:
			continue
		var s := [parts[0], int(parts[1]), int(parts[2]), int(parts[3]), int(parts[4])]
		(c["stints"] as Array).append(s)
		c["games"] = int(c["games"]) + int(s[3])
		c["goals"] = int(c["goals"]) + int(s[4])
	return c


## Add one finished season. Does nothing if that season is already counted.
## A player who did not play still has the season marked as counted.
static func add_season(p: Dictionary, year: int, club: String, games: int, goals: int) -> bool:
	var c := of(p)
	if int(c.get("through", 0)) >= year:
		return false
	c["through"] = year
	if games <= 0:
		return true
	c["games"] = int(c["games"]) + games
	c["goals"] = int(c["goals"]) + goals
	var stints: Array = c["stints"]
	if not stints.is_empty() and str((stints[-1] as Array)[0]) == club:
		var s: Array = stints[-1]
		s[2] = year
		s[3] = int(s[3]) + games
		s[4] = int(s[4]) + goals
	else:
		stints.append([club, year, year, games, goals])
	return true


## Close a season for every listed player. `players` maps id -> player dict;
## `tally` is the season's Awards tally (every match, finals included).
static func close_season(players: Dictionary, tally: Dictionary, year: int) -> int:
	var added := 0
	for id in players:
		var p: Dictionary = players[id]
		var t: Dictionary = tally.get(str(id), {})
		var club := str(t.get("club", p.get("club", "")))
		if add_season(p, year, club, int(t.get("games", 0)), int(t.get("goals", 0))):
			added += 1
	return added


## An older save's player, given this record for the first time. `base` is
## what the dataset knows (his AFL career to 2025, or fresh for a generated
## player); the seasons the save already played, first..last, were never
## tallied and are marked unknown rather than invented.
static func migrate(p: Dictionary, base: Dictionary, first: int, last: int) -> void:
	var c: Dictionary = base.duplicate(true) if not base.is_empty() else fresh()
	if last >= first:
		(c["unknown"] as Array).append([first, last])
		c["through"] = maxi(int(c.get("through", 0)), last)
	p["career"] = c


## True when every season of his career is counted.
static func complete(p: Dictionary) -> bool:
	return (of(p)["unknown"] as Array).is_empty()


## "143 games · 87 goals", "1 game · no goals", or "—" when part of the
## career is unknown. "" before his first senior game.
static func totals_text(p: Dictionary) -> String:
	if not complete(p):
		return "—"
	var c := of(p)
	var g := int(c["games"])
	if g <= 0:
		return ""
	return "%s · %s" % [_count(g, "game"), _count(int(c["goals"]), "goal")]


## One line per club: ["Adelaide 2027–2034 · 142 games, 89 goals", ...].
static func club_lines(p: Dictionary, club_name: Callable) -> Array:
	var out := []
	for s in of(p)["stints"]:
		var years := str(s[1]) if int(s[1]) == int(s[2]) else "%d–%d" % [int(s[1]), int(s[2])]
		out.append("%s %s · %s, %s" % [str(club_name.call(str(s[0]))), years,
				_count(int(s[3]), "game"), _count(int(s[4]), "goal")])
	return out


static func _count(n: int, word: String) -> String:
	if n == 0:
		return "no %ss" % word
	return "%d %s%s" % [n, word, "" if n == 1 else "s"]
