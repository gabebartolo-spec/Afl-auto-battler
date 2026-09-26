class_name Season
extends RefCounted
## A 24-round home-and-away season plus a full AFL finals series.
##
## Fixture: with 18 clubs, 9 matches a round and no byes, 24 rounds gives
## every club 24 games: a single round-robin (17 rounds) plus the first seven
## rounds of the return fixture with home/away flipped. An odd club count
## (expansion) rotates a virtual BYE, so every club still plays 24 games.
##
## Finals (10 finalists):
##   Week 1  Wildcard: WC1 7v10, WC2 8v9
##   Week 2  QF1 1v4, QF2 2v3, EF1 5v(W_WC2), EF2 6v(W_WC1) - the wildcard
##           winners are reseeded as the 7th and 8th seeds by their original
##           ladder position
##   Week 3  SF: QF losers v EF winners
##   Week 4  PF: QF winners v SF winners
##   Week 5  GF

const REGULAR_ROUNDS := 24
const FINALISTS := 10
## The Grand Final is always played here, whichever clubs make it.
const GRAND_FINAL_VENUE := "MCG"

var clubs: Array = []          # club codes
var lists := {}                # code -> Array of player dicts
var fixture: Array = []        # Array of rounds; each round is Array of matches
var results: Array = []        # played rounds, in order
var ladder := {}               # code -> ladder row
var round_index := 0           # next regular round to play
var seed := 0
var finals := {}               # finals series state, empty until started
var selections := {}           # code -> chosen match-day side (empty = auto)


func _init(club_codes: Array, club_lists: Dictionary, p_seed: int = 0) -> void:
	clubs = club_codes.duplicate()
	# Keep only this season's clubs. Callers build `club_lists` for every
	# club that will ever exist, and the offseason, contracts and free-agent
	# passes iterate `lists` - a phantom entry for a club that has not
	# entered yet would let rivals "sign" free agents into it and silently
	# pre-fill the expansion club's debut list (skipping its generation).
	lists = {}
	for c in clubs:
		lists[c] = club_lists.get(c, [])
	seed = p_seed
	ladder = {}
	for c in clubs:
		ladder[c] = {"code": c, "p": 0, "w": 0, "l": 0, "d": 0,
				"pf": 0, "pa": 0, "pts": 0, "pct": 0.0}
	fixture = build_fixture()


# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------
## Circle method: hold one club still and rotate the rest, giving a full
## round-robin in n-1 rounds. An odd club count (expansion) adds a virtual
## BYE to the rotation, so every club still meets every other exactly once.
static func round_robin(codes: Array) -> Array:
	var n := codes.size()
	var rot := codes.duplicate()
	if n % 2 == 1:
		rot.append("BYE")
		n += 1
	var rounds := []
	for r in range(n - 1):
		var matches := []
		for i in range(n / 2):
			var a: String = rot[i]
			var b: String = rot[n - 1 - i]
			if a == "BYE" or b == "BYE":
				continue
			# Alternate venue by round and pairing so no club is permanently
			# home or away against a given opponent.
			if (r + i) % 2 == 0:
				matches.append({"home": a, "away": b})
			else:
				matches.append({"home": b, "away": a})
		rounds.append(matches)
		var last = rot.pop_back()
		rot.insert(1, last)
	return rounds


func build_fixture() -> Array:
	var first_half := round_robin(clubs)
	var out := []
	for r in first_half:
		out.append(r)
	# Return fixture: same pairings, venues flipped.
	for r in first_half:
		if out.size() >= REGULAR_ROUNDS:
			break
		var flipped := []
		for m in r:
			flipped.append({"home": m["away"], "away": m["home"]})
		out.append(flipped)
	return out.slice(0, REGULAR_ROUNDS)


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------
## `at_home`: whether each club plays at its own home ground (the engine's
## home-ground edge). Normally the home club hosts; see finals_at_home() for
## the Grand Final.
func simulate(home_code: String, away_code: String, match_seed: int,
		at_home := [true, false], is_final := false) -> Dictionary:
	var home := Squad.new(GameDB_ref().club_name(home_code),
			lists[home_code], bool(at_home[0]), home_code, selections.get(home_code, {}))
	var away := Squad.new(GameDB_ref().club_name(away_code),
			lists[away_code], bool(at_home[1]), away_code, selections.get(away_code, {}))
	home.form = club_form(home_code)
	away.form = club_form(away_code)
	var sim := MatchSim.new(home, away, match_seed)
	sim.finals_mode = is_final
	return sim.run()


## A club's results this season, oldest first: "W", "L" or "D" for every
## home-and-away match and final it has played. Finals decided on ladder
## position after a level score count as a draw.
func club_results(code: String) -> Array:
	var out := []
	var rounds: Array = results.duplicate()
	rounds.append_array(finals.get("weeks", []))
	for rnd in rounds:
		for res in rnd:
			var side := -1
			if str(res.get("home", "")) == code:
				side = 0
			elif str(res.get("away", "")) == code:
				side = 1
			if side < 0:
				continue
			var s: Array = res["score"]
			if int(s[side]) > int(s[1 - side]):
				out.append("W")
			elif int(s[side]) < int(s[1 - side]):
				out.append("L")
			else:
				out.append("D")
	return out


## Team form, -1..1, going into the club's next match (ClubLife.team_form).
func club_form(code: String) -> float:
	return ClubLife.team_form(club_results(code))


## GameDB is an autoload; reaching it from a RefCounted needs the scene tree.
func GameDB_ref() -> Node:
	return Engine.get_main_loop().root.get_node("GameDB")


func next_seed(extra: int = 0) -> int:
	return seed * 1000003 + round_index * 9176 + extra * 7919 + 13


func play_round() -> Array:
	if round_index >= fixture.size():
		return []
	var round_matches: Array = fixture[round_index]
	var played := []
	for i in range(round_matches.size()):
		var m: Dictionary = round_matches[i]
		var res := simulate(m["home"], m["away"], next_seed(i))
		res["round"] = round_index + 1
		res["label"] = "Round %d" % (round_index + 1)
		played.append(res)
		record_regular(res)
	results.append(played)
	round_index += 1
	recalc_ladder()
	return played


func record_regular(res: Dictionary) -> void:
	var h: String = res["home"]
	var a: String = res["away"]
	var s: Array = res["score"]
	ladder[h]["pf"] = int(ladder[h]["pf"]) + s[0]
	ladder[h]["pa"] = int(ladder[h]["pa"]) + s[1]
	ladder[a]["pf"] = int(ladder[a]["pf"]) + s[1]
	ladder[a]["pa"] = int(ladder[a]["pa"]) + s[0]
	ladder[h]["p"] = int(ladder[h]["p"]) + 1
	ladder[a]["p"] = int(ladder[a]["p"]) + 1
	if s[0] > s[1]:
		ladder[h]["w"] = int(ladder[h]["w"]) + 1
		ladder[a]["l"] = int(ladder[a]["l"]) + 1
	elif s[1] > s[0]:
		ladder[a]["w"] = int(ladder[a]["w"]) + 1
		ladder[h]["l"] = int(ladder[h]["l"]) + 1
	else:
		ladder[h]["d"] = int(ladder[h]["d"]) + 1
		ladder[a]["d"] = int(ladder[a]["d"]) + 1


func recalc_ladder() -> void:
	for c in ladder:
		var row: Dictionary = ladder[c]
		row["pts"] = int(row["w"]) * 4 + int(row["d"]) * 2
		var pa := int(row["pa"])
		row["pct"] = (100.0 * int(row["pf"]) / pa) if pa > 0 else 0.0


## Points first, then percentage - the actual AFL tiebreak order.
func ladder_sorted() -> Array:
	var out := []
	for c in ladder:
		out.append(ladder[c])
	out.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return int(a["pts"]) > int(b["pts"])
		if not is_equal_approx(a["pct"], b["pct"]):
			return a["pct"] > b["pct"]
		return int(a["pf"]) > int(b["pf"]))
	return out


func is_regular_done() -> bool:
	return round_index >= fixture.size()


# ---------------------------------------------------------------------------
# Finals
# ---------------------------------------------------------------------------
## The wildcard bracket (see the class doc): ten finalists, five weeks.
func start_finals() -> void:
	var top := []
	for row in ladder_sorted():
		if top.size() >= FINALISTS:
			break
		top.append(row["code"])
	finals = {
		"week": 1,
		"top": top,
		"slots": {},          # "W_WC1" etc -> club code
		"weeks": [],          # played weeks: Array of Array of results
		"premier": "",
		"runner_up": "",
		"done": false,
	}


func finals_week_matches() -> Array:
	if finals.is_empty():
		return []
	var t: Array = finals["top"]
	var s: Dictionary = finals["slots"]
	match int(finals["week"]):
		1:
			return [
				{"tag": "WC1", "label": "Wildcard Final 1", "home": t[6], "away": t[9]},
				{"tag": "WC2", "label": "Wildcard Final 2", "home": t[7], "away": t[8]},
			]
		2:
			return [
				{"tag": "QF1", "label": "Qualifying Final 1", "home": t[0], "away": t[3]},
				{"tag": "QF2", "label": "Qualifying Final 2", "home": t[1], "away": t[2]},
				# Wildcard winners reseed by original ladder position: the
				# winner of 7v10 takes the 7th seed, the winner of 8v9 the 8th.
				{"tag": "EF1", "label": "Elimination Final 1",
						"home": t[4], "away": s.get("W_WC2", "")},
				{"tag": "EF2", "label": "Elimination Final 2",
						"home": t[5], "away": s.get("W_WC1", "")},
			]
		3:
			return [
				{"tag": "SF1", "label": "Semi Final 1",
						"home": s.get("L_QF1", ""), "away": s.get("W_EF1", "")},
				{"tag": "SF2", "label": "Semi Final 2",
						"home": s.get("L_QF2", ""), "away": s.get("W_EF2", "")},
			]
		4:
			return [
				{"tag": "PF1", "label": "Preliminary Final 1",
						"home": s.get("W_QF1", ""), "away": s.get("W_SF1", "")},
				{"tag": "PF2", "label": "Preliminary Final 2",
						"home": s.get("W_QF2", ""), "away": s.get("W_SF2", "")},
			]
		5:
			return [{"tag": "GF", "label": "Grand Final",
						"home": s.get("W_PF1", ""), "away": s.get("W_PF2", "")}]
	return []


func play_finals_week() -> Array:
	if finals.is_empty() or bool(finals["done"]):
		return []
	var matches := finals_week_matches()
	var played := []
	for i in range(matches.size()):
		var m: Dictionary = matches[i]
		if m["home"] == "" or m["away"] == "":
			continue
		var res := simulate(m["home"], m["away"], finals_seed(i), finals_at_home(m), true)
		record_final(m, res)
		played.append(res)
	complete_finals_week(played)
	return played


## Seed for match `i` of the current finals week. Shared by the simulated
## week and the interactive finals match so both roll the same game.
func finals_seed(i: int) -> int:
	return seed * 7717 + int(finals["week"]) * 131 + i


## Where a final is played. The higher-ranked club hosts every final at its
## home ground, except the Grand Final, which is always at the MCG whoever
## makes it. The bracket always lists the higher seed first.
func finals_venue(m: Dictionary) -> String:
	if str(m.get("tag", "")) == "GF":
		return GRAND_FINAL_VENUE
	return home_ground(str(m.get("home", "")))


## Which of a final's clubs plays at its own home ground (the engine's
## home-ground edge). The host of every other final has it, exactly as in a
## home-and-away match. At the Grand Final a club has it only if the MCG is
## its home ground, whichever slot it is listed in: two MCG clubs, or none,
## and neither side has an edge.
func finals_at_home(m: Dictionary) -> Array:
	if str(m.get("tag", "")) != "GF":
		return [true, false]
	return [home_ground(str(m.get("home", ""))) == GRAND_FINAL_VENUE,
			home_ground(str(m.get("away", ""))) == GRAND_FINAL_VENUE]


func home_ground(code: String) -> String:
	return str(GameDB_ref().club(code).get("ground", ""))


## Stamp a finals result and advance the bracket slots. Extra time settles
## almost every level final; if even the golden-point period runs dry, the
## higher-ranked side advances.
func record_final(m: Dictionary, res: Dictionary) -> void:
	var s: Dictionary = finals["slots"]
	res["round"] = REGULAR_ROUNDS + int(finals["week"])
	res["label"] = m["label"]
	res["tag"] = m["tag"]
	res["venue"] = finals_venue(m)
	var sc: Array = res["score"]
	var winner: String
	var loser: String
	if sc[0] == sc[1]:
		var top: Array = finals["top"]
		winner = m["home"] if top.find(m["home"]) < top.find(m["away"]) else m["away"]
		loser = m["away"] if winner == m["home"] else m["home"]
		res["decided_on_ladder"] = true
	else:
		winner = m["home"] if sc[0] > sc[1] else m["away"]
		loser = m["away"] if winner == m["home"] else m["home"]
	s["W_" + m["tag"]] = winner
	s["L_" + m["tag"]] = loser


## Close the current finals week once every match in it has been recorded.
func complete_finals_week(played: Array) -> void:
	var s: Dictionary = finals["slots"]
	finals["weeks"].append(played)
	if int(finals["week"]) == 5 and not played.is_empty():
		finals["premier"] = s.get("W_GF", "")
		finals["runner_up"] = s.get("L_GF", "")
		finals["done"] = true
	else:
		finals["week"] = int(finals["week"]) + 1


func is_season_over() -> bool:
	return not finals.is_empty() and bool(finals["done"])
