class_name FormerPlayers
extends RefCounted
## The one who got away (P-16, director 2026-10-18): a player who was on your
## list in this career, played for you and left (delisted, traded or let walk),
## and now lines up against you. Pure rules from what is already kept; writes
## nothing, adds no randomness and never touches how he plays.
##
##   his games and goals for you   Career stints at your club (every spell)
##   in this career                one of those spells runs past
##                                 Career.BEFORE_GAME (a real-life spell that
##                                 ended before the game began does not count)
##   how he left                   last off-season's wrap (GameState.season_wrap
##                                 "outs"), the only place the move is kept;
##                                 "" for an older move
##   his role now                  his club's captaincy record
##   his best and fairests for you GameState.honour_roll (your club's winner)
##
## A player who never played a game for you is not one of these.

## At most this many on the pre-match lines.
const SHOWN := 2
## The report names him only when he played this long (game minutes, of 120)
## or kicked a goal.
const REPORT_MINUTES := 60
## A match's length in game minutes (four 30-minute quarters).
const MATCH_MINUTES := 120

const HOW_WORDS := {"trade": "traded", "delisted": "delisted"}


## The ex-players in `opp_list` (the opposition's players), the most games for
## you first: {"id", "p", "games", "goals", "from", "to", "how", "role", "bf"}.
##   how    "traded", "delisted", "left as a free agent" or "" (not kept)
##   moved  true when he left in the off-season just gone
##   role   "captain", "vice-captain" or ""
##   bf     the years he won your best and fairest
## `wrap` is GameState.season_wrap, `year` the season being played,
## `captaincy` the opposition's Captaincy record, `honour_roll` GameState's.
static func against(opp_list: Array, my_club: String, year: int, wrap: Dictionary = {},
		captaincy: Dictionary = {}, honour_roll: Array = []) -> Array:
	var out := []
	if my_club == "":
		return out
	var left_how := {}
	if int(wrap.get("year", 0)) == year:
		for row in wrap.get("outs", []):
			left_how[str((row as Dictionary).get("id", ""))] = str((row as Dictionary).get("how", ""))
	for p in opp_list:
		if not (p is Dictionary):
			continue
		var id := str(p.get("id", ""))
		if id == "" or str(p.get("club", "")) == my_club:
			continue
		var career = p.get("career", {})
		if not (career is Dictionary):
			continue
		var games := 0
		var goals := 0
		var first := 0
		var last := 0
		var in_career := false
		for st in (career as Dictionary).get("stints", []):
			if str(st[0]) != my_club:
				continue
			games += int(st[3])
			goals += int(st[4])
			first = int(st[1]) if first == 0 else mini(first, int(st[1]))
			last = maxi(last, int(st[2]))
			if int(st[2]) > Career.BEFORE_GAME:
				in_career = true
		if games <= 0 or not in_career:
			continue
		var how := ""
		var moved := left_how.has(id)
		if moved:
			var raw := str(left_how[id])
			how = HOW_WORDS.get(raw, "left as a free agent" if raw.begins_with("free agent") else "")
		var bf := []
		for e in honour_roll:
			if str((e as Dictionary).get("my_club", "")) != my_club:
				continue
			var w: Array = (e as Dictionary).get("my_bf", [])
			if not w.is_empty() and str((w[0] as Dictionary).get("id", "")) == id:
				bf.append(int((e as Dictionary).get("year", 0)))
		out.append({"id": id, "p": p, "games": games, "goals": goals, "from": first, "to": last,
				"how": how, "moved": moved, "role": _role(captaincy, id), "bf": bf})
	out.sort_custom(func(a, b):
		if int(a["games"]) != int(b["games"]):
			return int(a["games"]) > int(b["games"])
		return str(a["id"]) < str(b["id"]))
	return out


static func _role(rec: Dictionary, id: String) -> String:
	match Captaincy.role_of(rec, id):
		"captain":
			return "captain"
		"vice":
			return "vice-captain"
	return ""


## The pre-match line for one of them: "Sam Walsh, 142 games for you, now
## Carlton's captain." / "Sam Walsh, traded to Carlton last year, lines up
## against you." / "Sam Walsh, 142 games for you, now plays for Carlton."
## `name` is his display name, `club` his club's name as the sheet says it.
static func poster_line(row: Dictionary, name: String, club: String) -> String:
	var role := str(row.get("role", ""))
	var g := int(row.get("games", 0))
	var games := "%d game%s for you" % [g, "" if g == 1 else "s"]
	if role != "":
		return "%s, %s, now %s's %s." % [name, games, club, role]
	if bool(row.get("moved", false)) and str(row.get("how", "")) == "traded":
		return "%s, traded to %s last year, lines up against you." % [name, club]
	return "%s, %s, now plays for %s." % [name, games, club]


## The report line: "Sam Walsh against his old side: 31 touches, 1 goal."
static func report_line(name: String, touches: int, goals: int) -> String:
	return "%s against his old side: %d touch%s, %s." % [name, touches, "" if touches == 1 else "es",
			"no goals" if goals == 0 else "%d goal%s" % [goals, "" if goals == 1 else "s"]]


## Game minutes `id` spent on the ground for `side` in a finished match, from
## the result's opening bench and its interchange and injury events. -1 when he
## was not in the side.
static func minutes_on(res: Dictionary, side: int, id: String) -> int:
	var roster: Array = res.get("roster", [[], []])
	if roster.size() <= side:
		return -1
	var num := -1
	for p in roster[side]:
		if str((p as Dictionary).get("id", "")) == id:
			num = int((p as Dictionary).get("num", -1))
	if num < 0:
		return -1
	var bench: Array = res.get("bench", [[], []])
	var on := true
	if bench.size() > side:
		for b in bench[side]:
			if str((b as Dictionary).get("id", "")) == id:
				on = false
	var since := 0
	var total := 0
	var end := MATCH_MINUTES
	for ev in res.get("events", []):
		var e: Dictionary = ev
		end = maxi(end, int(e.get("min", 0)))
		if int(e.get("side", -1)) != side:
			continue
		var at := int(e.get("min", 0))
		match str(e.get("kind", "")):
			"sub":
				if str(e.get("player_id", "")) == id and not on:
					on = true
					since = at
				elif int(e.get("off_num", -1)) == num and on:
					on = false
					total += at - since
			"injury":
				if str(e.get("player_id", "")) == id and on:
					on = false
					total += at - since
	if on:
		total += end - since
	return total


## The report lines for the ex-players in `rows` (from against()) who played
## for the side opposite `my_side`: [{"id", "text"}], only for one who was on
## the ground REPORT_MINUTES or more or kicked a goal.
static func report_lines(res: Dictionary, my_side: int, rows: Array) -> Array:
	var out := []
	var side := 1 - my_side
	var players: Dictionary = res.get("players", {})
	for row in rows:
		var id := str((row as Dictionary).get("id", ""))
		var mins := minutes_on(res, side, id)
		if mins < 0:
			continue
		var st: Dictionary = players.get(id, {})
		var goals := int(float(st.get("goals", 0.0)))
		if mins < REPORT_MINUTES and goals <= 0:
			continue
		var name := GameDB.player_display_name_by_id(id, "")
		if name == "" and (row as Dictionary).get("p") is Dictionary:
			name = GameDB.player_display_name((row as Dictionary)["p"])
		out.append({"id": id, "text": report_line(name, int(float(st.get("disposals", 0.0))), goals)})
	return out
