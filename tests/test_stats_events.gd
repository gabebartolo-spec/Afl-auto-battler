extends RefCounted
## The Stats patch's match statistics come from football events and add up
## (ROADMAP §1.11): contested and uncontested possessions, ground-ball gets,
## ruck contests and hit-out wins, shots and set shots, running bounces,
## score involvements and goal assists. Run through tests/run_stats_tests.gd.
## Seeded by design: every match here is a MatchSim with an explicit seed.

var failures: Array[String] = []
var checks := 0

const CLUBS := ["GEE", "COL", "CAR", "SYD", "MEL", "BRL"]
const MATCHES := 12


func run() -> void:
	failures.clear()
	checks = 0
	var results := []
	for i in range(MATCHES):
		var h: String = CLUBS[i % CLUBS.size()]
		var a: String = CLUBS[(i + 2) % CLUBS.size()]
		var sim := MatchSim.new(Squad.new(h, GameDB.club_list(h), true, h),
				Squad.new(a, GameDB.club_list(a), false, a), 4100 + i)
		results.append(sim.run())
	_possessions(results)
	_ruck(results)
	_shots(results)
	_bounces(results)
	_involvements(results)
	_contested_marks(results)
	_broken_tackles(results)
	_old_boxes()
	print("Stats event tests: %d checks, %d failures" % [checks, failures.size()])


func _n(st: Dictionary, k: String) -> int:
	return int(round(float(st.get(k, 0.0))))


## Every disposal is one possession, contested or not (a crumb's snap off the
## deck is a contested ground ball with no disposal); a ground-ball get is a
## contested possession; the team totals are the players'.
func _possessions(results: Array) -> void:
	var bad := ""
	var cp := 0
	var up := 0
	for r in results:
		for id in r["players"]:
			var st: Dictionary = r["players"][id]
			var poss := _n(st, "contested_possessions") + _n(st, "uncontested_possessions")
			if poss < _n(st, "disposals") or _n(st, "ground_ball_gets") > _n(st, "contested_possessions"):
				bad = "%s: %d possessions, %d disposals, %d ground balls, %d contested" % [id, poss,
						_n(st, "disposals"), _n(st, "ground_ball_gets"), _n(st, "contested_possessions")]
			cp += _n(st, "contested_possessions")
			up += _n(st, "uncontested_possessions")
		for side in [0, 1]:
			var team: Dictionary = r["team"][side]
			var sum := 0
			for p in r["roster"][side]:
				sum += _n(r["players"].get(str(p["id"]), {}), "contested_possessions")
			if sum != _n(team, "contested_possessions"):
				bad = "team contested possessions %d, players %d" % [_n(team, "contested_possessions"), sum]
	_check(bad == "", "Every disposal is a possession, a ground ball is contested, teams add up (%s)" % bad)
	_check(cp > 0 and up > cp, "Contested and uncontested possessions both happen, most uncontested (%d, %d)" % [cp, up])


## A hit-out is a ruck contest won: both rucks are in every contest, so the
## two sides' contests match and equal every hit-out of the match.
func _ruck(results: Array) -> void:
	var bad := ""
	for r in results:
		var contests := [0, 0]
		var hits := 0
		for side in [0, 1]:
			for p in r["roster"][side]:
				var st: Dictionary = r["players"].get(str(p["id"]), {})
				contests[side] += _n(st, "ruck_contests")
				if _n(st, "hitouts") > _n(st, "ruck_contests"):
					bad = "%s won %d of %d" % [str(p["id"]), _n(st, "hitouts"), _n(st, "ruck_contests")]
				hits += _n(st, "hitouts")
		if contests[0] != contests[1] or contests[0] != hits:
			bad = "contests %s, hit-outs %d" % [str(contests), hits]
	_check(bad == "", "Hit-outs are ruck contests won, both rucks in each (%s)" % bad)


## Every goal and behind a player kicks is a shot; set shots are a share of
## them, with their own goals and behinds.
func _shots(results: Array) -> void:
	var bad := ""
	var shots := 0
	var sets := 0
	for r in results:
		for id in r["players"]:
			var st: Dictionary = r["players"][id]
			if (_n(st, "goals") + _n(st, "behinds") > _n(st, "shots")
					or _n(st, "set_shots") > _n(st, "shots")
					or _n(st, "set_goals") > _n(st, "goals") or _n(st, "set_behinds") > _n(st, "behinds")
					or _n(st, "set_goals") + _n(st, "set_behinds") > _n(st, "set_shots")):
				bad = "%s: %d.%d from %d shots, set %d.%d from %d" % [id, _n(st, "goals"), _n(st, "behinds"),
						_n(st, "shots"), _n(st, "set_goals"), _n(st, "set_behinds"), _n(st, "set_shots")]
			shots += _n(st, "shots")
			sets += _n(st, "set_shots")
	_check(bad == "", "Goals and behinds come from shots, set shots inside them (%s)" % bad)
	_check(sets > 0 and sets < shots, "Some shots are set shots, not all (%d of %d)" % [sets, shots])


## A running bounce is a run with the ball: every one is on a disposal whose
## event carries the run, one for every 15 metres of it.
func _bounces(results: Array) -> void:
	var bad := ""
	var total := 0
	for r in results:
		var from_runs := {}
		for e in r["events"]:
			if (e as Dictionary).has("run"):
				var id := str(e["player_id"])
				from_runs[id] = int(from_runs.get(id, 0)) + int(float(e["run"]) / MatchSim.BOUNCE_EVERY)
		for id in r["players"]:
			var b := _n(r["players"][id], "running_bounces")
			total += b
			if b != int(from_runs.get(id, 0)):
				bad = "%s: %d bounces, runs say %d" % [id, b, int(from_runs.get(id, 0))]
	_check(bad == "", "Every running bounce is on a run with the ball (%s)" % bad)
	var per_team := float(total) / float(MATCHES * 2)
	_check(per_team > 1.0 and per_team < 12.0, "A side bounces it a handful of times a game (%.1f)" % per_team)


## A goal assist is a score involvement, not a goal: the assist goes to a
## teammate who was in the chain.
func _involvements(results: Array) -> void:
	var bad := ""
	for r in results:
		for side in [0, 1]:
			var assists := 0
			for p in r["roster"][side]:
				var st: Dictionary = r["players"].get(str(p["id"]), {})
				assists += _n(st, "goal_assists")
				if _n(st, "goal_assists") > _n(st, "score_involvements"):
					bad = "%s: %d assists, %d involvements" % [str(p["id"]), _n(st, "goal_assists"), _n(st, "score_involvements")]
			if assists > int(r["goals"][side]):
				bad = "%d assists for %d goals" % [assists, int(r["goals"][side])]
	_check(bad == "", "Goal assists are involvements, never more than the goals (%s)" % bad)


## A forward's mark inside 50 is contested only when a defender was at it,
## and says who (his direct opponent, or the spare): never a roll.
func _contested_marks(results: Array) -> void:
	var bad := ""
	var contested := 0
	var lead := 0
	for r in results:
		for e in r["events"]:
			var ev: Dictionary = e
			if str(ev.get("kind", "")) != "mark" or bool(ev.get("general_play", false)) or not ev.has("contested"):
				continue
			if bool(ev["contested"]):
				contested += 1
				if str(ev.get("against_id", "")) == "":
					bad = "a contested mark with no defender named (%s)" % str(ev.get("text", ""))
			else:
				lead += 1
				if ev.has("against_id"):
					bad = "a lead mark naming a defender (%s)" % str(ev.get("text", ""))
	_check(bad == "", "Inside 50, a contested mark names the defender at it, a lead mark none (%s)" % bad)
	_check(contested > 0 and lead > 0, "Forward marks come both ways: %d contested, %d on the lead" % [contested, lead])


## A tackle the carrier breaks is a don't argue (a fend) or an evaded tackle
## (director, 2026-10-08): the side's count is its players', strength in the
## contest leans to the fend and pace to the evade.
func _broken_tackles(results: Array) -> void:
	var bad := ""
	var total := 0
	for r in results:
		for side in [0, 1]:
			for k in ["dont_argues", "evaded_tackles"]:
				var sum := 0
				for p in r["roster"][side]:
					sum += _n(r["players"].get(str(p["id"]), {}), k)
				total += sum
				if sum != _n(r["team"][side], k):
					bad = "team %s %d, players %d" % [k, _n(r["team"][side], k), sum]
	_check(bad == "" and total > 0, "Broken tackles are counted, fends and evades, and the side's are its players' (%s)" % bad)
	var sim := MatchSim.new(Squad.new("GEE", GameDB.club_list("GEE"), true, "GEE"),
			Squad.new("COL", GameDB.club_list("COL"), false, "COL"), 4199)
	var bull := {"attr": {"contested": 95, "carry": 30}}
	var runner := {"attr": {"contested": 30, "carry": 95}}
	var fends := [0, 0]
	for i in range(400):
		if sim._break_kind(bull) == "dont_argues":
			fends[0] += 1
		if sim._break_kind(runner) == "dont_argues":
			fends[1] += 1
	_check(fends[0] > 300 and fends[1] < 100 and fends[1] > 0,
			"A strong contested player mostly fends, a runner mostly evades, neither always (%d and %d of 400)" % fends)


## A match packed before the two were recorded reads back as it was: the
## team-only numbers (possession chains) stay where they were.
func _old_boxes() -> void:
	var old_n := StatBook.FIRST_KEYS.size()
	var old_tn := old_n + 4
	var team := PackedInt32Array()
	team.resize(old_tn)
	team[old_n] = 123
	var player := PackedInt32Array()
	player.resize(old_n)
	player[0] = 21
	var box := {"n": old_n, "tn": old_tn, "who": [[["a", 1, "A"]], [["b", 2, "B"]]],
			"p": {"a": player, "b": player}, "t": [team, team]}
	var full := StatBook.full({"box": box})
	_check(_n(full["team"][0], "chains") == 123 and _n(full["team"][0], "dont_argues") == 0
			and _n(full["players"]["a"], "disposals") == 21,
			"A match saved before broken tackles were kept reads back as it was")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
