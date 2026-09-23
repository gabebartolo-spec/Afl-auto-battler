class_name Season
extends RefCounted
## A 24-round home-and-away season plus a full AFL finals series.
##
## Fixture: 18 clubs means 9 matches a round and no byes, so 24 rounds gives
## every club 24 games. Rounds 1-17 are a single round-robin; rounds 18-24 are
## the first seven rounds of the return fixture with home/away flipped. That
## mirrors the real AFL, where you meet some clubs twice and others once.

const REGULAR_ROUNDS := 24
const FINALISTS := 8

var clubs: Array = []          # club codes
var lists := {}                # code -> Array of player dicts
var fixture: Array = []        # Array of rounds; each round is Array of matches
var results: Array = []        # played rounds, in order
var ladder := {}               # code -> ladder row
var round_index := 0           # next regular round to play
var seed := 0
var finals := {}               # finals series state, empty until started


func _init(club_codes: Array, club_lists: Dictionary, p_seed: int = 0) -> void:
	clubs = club_codes.duplicate()
	lists = club_lists
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
## round-robin in n-1 rounds.
static func round_robin(codes: Array) -> Array:
	var n := codes.size()
	var rot := codes.duplicate()
	var rounds := []
	for r in range(n - 1):
		var matches := []
		for i in range(floori(n / 2.0)):
			var a: String = rot[i]
			var b: String = rot[n - 1 - i]
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
func simulate(home_code: String, away_code: String, match_seed: int,
		neutral_venue := false, is_final := false) -> Dictionary:
	var home := Squad.new(GameDB_ref().club_name(home_code),
			lists[home_code], not neutral_venue, home_code)
	var away := Squad.new(GameDB_ref().club_name(away_code),
			lists[away_code], false, away_code)
	var sim := MatchSim.new(home, away, match_seed)
	sim.finals_mode = is_final
	var res := sim.run()
	res["neutral"] = neutral_venue
	return res


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
## The real AFL bracket:
##   Week 1  QF 1v4, 2v3      EF 5v8, 6v7
##   Week 2  SF: QF losers v EF winners
##   Week 3  PF: QF winners v SF winners
##   Week 4  GF
func start_finals() -> void:
	var top := []
	for row in ladder_sorted():
		if top.size() >= FINALISTS:
			break
		top.append(row["code"])
	finals = {
		"week": 1,
		"top": top,
		"slots": {},          # "W_QF1" etc -> club code
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
				{"tag": "QF1", "label": "Qualifying Final 1", "home": t[0], "away": t[3]},
				{"tag": "QF2", "label": "Qualifying Final 2", "home": t[1], "away": t[2]},
				{"tag": "EF1", "label": "Elimination Final 1", "home": t[4], "away": t[7]},
				{"tag": "EF2", "label": "Elimination Final 2", "home": t[5], "away": t[6]},
			]
		2:
			return [
				{"tag": "SF1", "label": "Semi Final 1",
						"home": s.get("L_QF1", ""), "away": s.get("W_EF1", "")},
				{"tag": "SF2", "label": "Semi Final 2",
						"home": s.get("L_QF2", ""), "away": s.get("W_EF2", "")},
			]
		3:
			return [
				{"tag": "PF1", "label": "Preliminary Final 1",
						"home": s.get("W_QF1", ""), "away": s.get("W_SF1", "")},
				{"tag": "PF2", "label": "Preliminary Final 2",
						"home": s.get("W_QF2", ""), "away": s.get("W_SF2", "")},
			]
		4:
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
		var res := simulate(m["home"], m["away"], finals_seed(i), finals_neutral(m), true)
		record_final(m, res)
		played.append(res)
	complete_finals_week(played)
	return played


## Seed for match `i` of the current finals week. Shared by the simulated
## week and the interactive finals match so both roll the same game.
func finals_seed(i: int) -> int:
	return seed * 7717 + int(finals["week"]) * 131 + i


## The higher-ranked club hosts every final except the Grand Final, which is
## played at a neutral venue. The bracket always lists the higher seed first.
func finals_neutral(m: Dictionary) -> bool:
	return str(m.get("tag", "")) == "GF"


## Stamp a finals result and advance the bracket slots. Extra time settles
## almost every level final; if even the golden-point period runs dry, the
## higher-ranked side advances.
func record_final(m: Dictionary, res: Dictionary) -> void:
	var s: Dictionary = finals["slots"]
	res["round"] = REGULAR_ROUNDS + int(finals["week"])
	res["label"] = m["label"]
	res["tag"] = m["tag"]
	res["neutral"] = finals_neutral(m)
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
	if int(finals["week"]) == 4 and not played.is_empty():
		finals["premier"] = s.get("W_GF", "")
		finals["runner_up"] = s.get("L_GF", "")
		finals["done"] = true
	else:
		finals["week"] = int(finals["week"]) + 1


func is_season_over() -> bool:
	return not finals.is_empty() and bool(finals["done"])
