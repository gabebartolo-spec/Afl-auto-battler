class_name StatBook
extends RefCounted
## The book of the numbers (the Stats patch, ROADMAP §1.11): which match
## statistics are recorded, a match's stat lines packed small enough to keep
## for every game of the season, every player's season totals across the whole
## competition, and the rates derived from them.
##
## Every count comes from a MatchSim event (MatchSim._p / _t); nothing here
## rolls or estimates. A rate is always derived from its counts, season rates
## from season counts (never an average of match percentages), and a rate
## with nothing under it is "no rate", never zero.

## The player statistics kept and added up, in the order they are packed.
## Append only: a packed box records how many keys it holds, so an older box
## still reads after keys are added. The first set is the one a side's box
## follows with its team-only keys (TEAM_KEYS); later keys go on after both.
const FIRST_KEYS := [
	"disposals", "kicks", "handballs", "contested_possessions", "uncontested_possessions",
	"ground_ball_gets", "marks", "contested_marks", "intercept_marks", "tackles",
	"clearances", "cba", "inside50", "rebounds", "metres_gained", "running_bounces",
	"goals", "behinds", "shots", "set_shots", "set_goals", "set_behinds",
	"goal_assists", "score_involvements", "hitouts", "hitouts_adv", "ruck_contests",
	"intercepts", "one_percenters", "spoils", "smothers", "pressure_acts",
	"frees_for", "frees_against", "clangers", "effective_disposals", "distance_run",
]
## Added 2026-10-08: tackles broken, by how (MatchSim._break_kind).
const LATER_KEYS := ["dont_argues", "evaded_tackles"]
const KEYS := FIRST_KEYS + LATER_KEYS
## A side's statistics kept per match: the players' plus the team-only ones.
const TEAM_KEYS := FIRST_KEYS + ["chains", "pressure_wins", "centre_bounces", "kick_ins"] + LATER_KEYS


# ---------------------------------------------------------------------------
# A match, packed
# ---------------------------------------------------------------------------
## A finished match's stat lines, small: who played for each side (id, number,
## name) and one integer array per player and per side in KEYS order. Kept in
## the saved season results so every match of the season can be opened again.
static func pack(res: Dictionary) -> Dictionary:
	var roster: Array = res.get("roster", [])
	var players: Dictionary = res.get("players", {})
	if roster.size() < 2:
		return {}
	var who := [[], []]
	var lines := {}
	for side in [0, 1]:
		for p in roster[side]:
			var id := str(p["id"])
			(who[side] as Array).append([id, int(p.get("num", 0)), str(p.get("name", ""))])
			lines[id] = _shorts(players.get(id, {}), KEYS)
	var team := []
	for side in [0, 1]:
		team.append(_ints((res.get("team", [{}, {}]) as Array)[side], TEAM_KEYS))
	return {"n": KEYS.size(), "tn": TEAM_KEYS.size(), "who": who, "p": lines, "t": team}


static func _ints(st: Dictionary, keys: Array) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(keys.size())
	for i in range(keys.size()):
		a[i] = int(round(float(st.get(keys[i], 0.0))))
	return a


## A player's match line as 16-bit counts (a match line never reaches 32,767,
## distance run in metres included): half the size of 32-bit integers, for a
## season of them in the save.
static func _shorts(st: Dictionary, keys: Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(keys.size() * 2)
	for i in range(keys.size()):
		b.encode_s16(i * 2, clampi(int(round(float(st.get(keys[i], 0.0)))), -32768, 32767))
	return b


static func _from_shorts(b: PackedByteArray, keys: Array, n: int) -> Dictionary:
	var out := {}
	for i in range(mini(n, b.size() / 2)):
		var v := b.decode_s16(i * 2)
		if v != 0:
			out[keys[i]] = float(v)
	return out


static func _dict(a: PackedInt32Array, keys: Array, n: int) -> Dictionary:
	var out := {}
	for i in range(mini(n, a.size())):
		if a[i] != 0:
			out[keys[i]] = float(a[i])
	return out


## The result with its players, team stats and rosters back from a packed box
## (a result loaded from the save). A result that still has them, or has no
## box, comes back as it is. Rosters come back as {id, num, name}.
static func full(res: Dictionary) -> Dictionary:
	if res.has("players") or not res.has("box"):
		return res
	var box: Dictionary = res["box"]
	if box.is_empty():
		return res
	var out := res.duplicate(false)
	var n := int(box.get("n", KEYS.size()))
	var players := {}
	for id in box["p"]:
		var line = box["p"][id]
		players[id] = _from_shorts(line, KEYS, n) if line is PackedByteArray else _dict(line, KEYS, n)
	out["players"] = players
	var team := []
	for a in box["t"]:
		team.append(_dict(a, TEAM_KEYS, int(box.get("tn", TEAM_KEYS.size()))))
	out["team"] = team
	var roster := [[], []]
	for side in [0, 1]:
		for w in box["who"][side]:
			(roster[side] as Array).append({"id": str(w[0]), "num": int(w[1]), "name": str(w[2])})
	out["roster"] = roster
	return out


# ---------------------------------------------------------------------------
# The season
# ---------------------------------------------------------------------------
## Add one match to the season book: id -> {"club", "clubs": {code: games},
## "games", "s": {key: total}}. Every player named in the 23 played the game.
## Finals count, as in a season's AFL statistics.
static func add_match(book: Dictionary, res: Dictionary) -> void:
	var roster: Array = res.get("roster", [])
	var players: Dictionary = res.get("players", {})
	var codes := [str(res.get("home", "")), str(res.get("away", ""))]
	for side in range(mini(2, roster.size())):
		for p in roster[side]:
			var id := str(p["id"])
			var row: Dictionary = book.get(id, {"club": codes[side], "clubs": {}, "games": 0, "s": {}})
			row["club"] = codes[side]
			var clubs: Dictionary = row["clubs"]
			clubs[codes[side]] = int(clubs.get(codes[side], 0)) + 1
			row["games"] = int(row["games"]) + 1
			var st: Dictionary = players.get(id, {})
			var s: Dictionary = row["s"]
			for k in KEYS:
				var v := float(st.get(k, 0.0))
				if v != 0.0:
					s[k] = float(s.get(k, 0.0)) + v
			book[id] = row


## The season book for the save: each row's totals packed in KEYS order
## ({id: [club, clubs, games, PackedInt32Array, keys]}), and back.
static func pack_book(book: Dictionary) -> Dictionary:
	var out := {}
	for id in book:
		var row: Dictionary = book[id]
		out[id] = [str(row.get("club", "")), row.get("clubs", {}), int(row.get("games", 0)),
				_ints(row.get("s", {}), KEYS), KEYS.size()]
	return out


static func unpack_book(data: Dictionary) -> Dictionary:
	var out := {}
	for id in data:
		var v = data[id]
		if v is Dictionary:
			out[id] = v  # already a row
			continue
		var a: Array = v
		out[id] = {"club": str(a[0]), "clubs": a[1], "games": int(a[2]),
				"s": _dict(a[3], KEYS, int(a[4]) if a.size() > 4 else KEYS.size())}
	return out


## A season total (0 when he has none).
static func total(row: Dictionary, key: String) -> float:
	if key == "games":
		return float(row.get("games", 0))
	return float((row.get("s", {}) as Dictionary).get(key, 0.0))


## Per game, over the games he played; -1 with no games.
static func per_game(row: Dictionary, key: String) -> float:
	var g := int(row.get("games", 0))
	if g <= 0:
		return -1.0
	return total(row, key) / float(g)


## The derived rates: [key, label, numerator, denominator(s)]. Each is a
## share of its own counts.
const RATES := {
	"cp_rate": ["Contested possession rate", "contested_possessions", ["contested_possessions", "uncontested_possessions"]],
	"hitout_win": ["Hit-out win rate", "hitouts", ["ruck_contests"]],
	"accuracy": ["Goalkicking accuracy", "goals", ["shots"]],
	"set_accuracy": ["Set-shot accuracy", "set_goals", ["set_shots"]],
	"efficiency": ["Disposal efficiency", "effective_disposals", ["disposals"]],
	"open_accuracy": ["Open-play accuracy", "goals", ["shots"]],
}


## A rate as a fraction (0-1) from a season row or a match's stat line
## (st = {key: count}); -1 when there is nothing under it (no shots, no
## ruck contests). "open_accuracy" is goals from open play over shots in
## open play (every shot that was not a set shot).
static func rate(st: Dictionary, which: String) -> float:
	if which == "open_accuracy":
		var op := open_play(st)
		return float(op["goals"]) / float(op["shots"]) if float(op["shots"]) > 0.0 else -1.0
	var r: Array = RATES[which]
	var d := 0.0
	for k in r[2]:
		d += float(st.get(k, 0.0))
	if d <= 0.0:
		return -1.0
	return float(st.get(r[1], 0.0)) / d


## Kicks to each handball, as "1.4"; -1 with no handballs.
static func kick_ratio(st: Dictionary) -> float:
	var h := float(st.get("handballs", 0.0))
	if h <= 0.0:
		return -1.0
	return float(st.get("kicks", 0.0)) / h


## Open-play (general) shots and their goals: the shots that were not set
## shots.
static func open_play(st: Dictionary) -> Dictionary:
	return {"shots": float(st.get("shots", 0.0)) - float(st.get("set_shots", 0.0)),
			"goals": float(st.get("goals", 0.0)) - float(st.get("set_goals", 0.0)),
			"behinds": float(st.get("behinds", 0.0)) - float(st.get("set_behinds", 0.0))}
