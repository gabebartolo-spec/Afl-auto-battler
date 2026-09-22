extends Node
## GameState (autoload) - the in-progress season: which club you manage, your
## drafted list, the fixture, the ladder and the finals bracket.
##
## Every scene reads from here and nothing else, so scene changes never lose
## the season.

var my_club := ""
var my_list: Array = []
var season: Season = null
var draft: Draft = null
var league_lists := {}
var pending_match: Dictionary = {}
var pending_sim: MatchSim = null
var pending_round_results: Array = []
var pending_phase := ""
var pending_label := ""

var last_results: Array = []     # every match from the round just played
var last_match: Dictionary = {}  # YOUR match from that round, with events
var last_phase := ""             # "regular" | "finals" | "done"
var last_label := ""             # "Round 7" / "Grand Final" / ...
var season_log: Array = []       # every result, for the season review screen


func reset() -> void:
	my_club = ""
	my_list = []
	season = null
	draft = null
	league_lists = {}
	pending_match = {}
	pending_sim = null
	pending_round_results = []
	pending_phase = ""
	pending_label = ""
	last_results = []
	last_match = {}
	last_phase = ""
	last_label = ""
	season_log = []


func begin_draft() -> void:
	var seed := int(Time.get_unix_time_from_system()) % 1000000
	draft = Draft.new(GameDB.all_players_sorted(), GameDB.CLUB_ORDER.duplicate(), seed)


## Commit the drafted list and build the season around it. The 17 AI clubs keep
## the lists they actually fielded in 2026.
func start_season(club_code: String, list: Array) -> void:
	my_club = club_code
	my_list = list
	var lists := {}
	if draft != null and draft.league_mode and draft.is_finished():
		league_lists = draft.all_lists()
		for code in GameDB.CLUB_ORDER:
			lists[code] = (league_lists.get(code, []) as Array).duplicate()
	else:
		# Fallback for tests or old saves: your drafted list plus real AI lists.
		for code in GameDB.CLUB_ORDER:
			lists[code] = my_list if code == my_club else GameDB.club_list(code)
	season = Season.new(GameDB.CLUB_ORDER.duplicate(), lists,
			int(Time.get_unix_time_from_system()) % 1000000)
	last_phase = "regular"
	last_label = "Round 1"


func prepare_interactive_match() -> bool:
	if season == null or season.is_regular_done():
		return false
	pending_match = {}
	pending_sim = null
	pending_round_results = []
	var round_matches: Array = season.fixture[season.round_index]
	for i in range(round_matches.size()):
		var m: Dictionary = round_matches[i]
		if m["home"] == my_club or m["away"] == my_club:
			pending_match = {"home": m["home"], "away": m["away"],
					"round": season.round_index + 1,
					"label": "Round %d" % (season.round_index + 1),
					"neutral": false}
		else:
			var res := season.simulate(m["home"], m["away"], season.next_seed(i))
			res["round"] = season.round_index + 1
			res["label"] = "Round %d" % (season.round_index + 1)
			pending_round_results.append(res)
			season.record_regular(res)
	if pending_match.is_empty():
		season.recalc_ladder()
		return false
	var home := Squad.new(GameDB.club_name(str(pending_match["home"])),
			season.lists[pending_match["home"]], true, str(pending_match["home"]))
	var away := Squad.new(GameDB.club_name(str(pending_match["away"])),
			season.lists[pending_match["away"]], false, str(pending_match["away"]))
	pending_sim = MatchSim.new(home, away, season.next_seed(99))
	pending_phase = "regular"
	pending_label = str(pending_match["label"])
	last_results = []
	last_match = {}
	last_phase = pending_phase
	last_label = pending_label
	return true


func finish_interactive_match(res: Dictionary) -> void:
	if season == null or pending_match.is_empty():
		return
	res["round"] = int(pending_match.get("round", season.round_index + 1))
	res["label"] = str(pending_match.get("label", "Match"))
	season.record_regular(res)
	var played := pending_round_results.duplicate()
	played.append(res)
	season.results.append(played)
	season.round_index += 1
	season.recalc_ladder()
	last_results = played
	last_match = res
	last_phase = "regular"
	last_label = str(res["label"])
	for r in played:
		season_log.append(r)
	pending_match = {}
	pending_sim = null
	pending_round_results = []
	pending_phase = ""
	pending_label = ""


## Play the next round (or finals week). Returns the phase it played.
func advance() -> String:
	if season == null:
		return "none"
	last_results = []
	last_match = {}

	if not season.is_regular_done():
		last_results = season.play_round()
		last_phase = "regular"
		last_label = "Round %d" % season.round_index
	elif not season.is_season_over():
		if season.finals.is_empty():
			season.start_finals()
		var week := int(season.finals.get("week", 1))
		last_results = season.play_finals_week()
		last_phase = "finals"
		var labels := {1: "Finals Week 1", 2: "Semi Finals",
				3: "Preliminary Finals", 4: "Grand Final"}
		last_label = str(labels.get(week, "Finals Week %d" % week))
		if season.is_season_over():
			last_phase = "done"
	else:
		last_phase = "done"
		return "done"

	for res in last_results:
		season_log.append(res)
		if res["home"] == my_club or res["away"] == my_club:
			last_match = res
	return last_phase


func is_my_match(res: Dictionary) -> bool:
	return res["home"] == my_club or res["away"] == my_club


## Your result this round, or null if you somehow didn't play.
func my_last_result():
	if last_match.is_empty():
		for res in last_results:
			if is_my_match(res):
				return res
		return null
	return last_match


func my_ladder_row() -> Dictionary:
	return season.ladder.get(my_club, {}) if season != null else {}


func my_position() -> int:
	if season == null:
		return 0
	var rows := season.ladder_sorted()
	for i in range(rows.size()):
		if rows[i]["code"] == my_club:
			return i + 1
	return 0


func my_record() -> String:
	var r := my_ladder_row()
	if r.is_empty():
		return "0-0-0"
	return "%d-%d-%d" % [int(r["w"]), int(r["l"]), int(r["d"])]


## Your next opponent and venue, for the fixture card.
func my_next_opponent() -> Dictionary:
	if season == null or season.is_regular_done():
		return {}
	var round_matches: Array = season.fixture[season.round_index]
	for m in round_matches:
		if m["home"] == my_club:
			return {"code": m["away"], "venue": "home"}
		if m["away"] == my_club:
			return {"code": m["home"], "venue": "away"}
	return {}


func season_is_over() -> bool:
	return season != null and season.is_season_over()


func premier() -> String:
	return str(season.finals.get("premier", "")) if season != null else ""


func train_my_list(focus: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system()) + my_list.size() * 31
	var focus_map := {
		"skills": ["disposal", "carry", "discipline"],
		"contest": ["contested", "pressure", "ruck"],
		"goal": ["goalkicking", "accuracy", "marking", "creating"],
		"recovery": ["durability", "pressure"],
	}
	var attrs: Array = focus_map.get(focus, ["disposal"]) as Array
	var weighted := []
	for p in my_list:
		var gm := float(p.get("gm", 20.0))
		var upside := clampf((28.0 - gm) / 28.0, 0.15, 1.0)
		var tickets := maxi(1, roundi(1.0 + upside * 6.0))
		for i in range(tickets):
			weighted.append(p)
	var out := []
	var used := {}
	while out.size() < 5 and not weighted.is_empty():
		var p: Dictionary = weighted[rng.randi_range(0, weighted.size() - 1)]
		if used.has(str(p["id"])):
			weighted.erase(p)
			continue
		used[str(p["id"])] = true
		var gm := float(p.get("gm", 20.0))
		var young_mult := clampf((30.0 - gm) / 18.0, 0.35, 1.65)
		var attr_key := str(attrs[rng.randi_range(0, attrs.size() - 1)])
		var gain := maxi(1, roundi(rng.randf_range(0.7, 1.8) * young_mult))
		var attr: Dictionary = p["attr"]
		var before := int(attr.get(attr_key, 1))
		attr[attr_key] = mini(99, before + gain)
		var old_ov := int(p["overall"])
		_recalc_player_overall(p)
		out.append({"name": str(p["name"]), "attr": attr_key.capitalize(),
				"gain": int(attr[attr_key]) - before,
				"overall_gain": int(p["overall"]) - old_ov})
	return out


func _recalc_player_overall(p: Dictionary) -> void:
	var a: Dictionary = p["attr"]
	var role := str(p["role"])
	var w: Array = Ratings.ROLE_WEIGHTS.get(role, Ratings.ROLE_WEIGHTS["MID"]) as Array
	var fifth: float = float(a.get("ruck", 45)) if role == "RUCK" else float(a.get("contested", 45))
	var core: float = (float(w[0]) * float(a.get("disposal", 45))
			+ float(w[1]) * float(a.get("pressure", 45))
			+ float(w[2]) * float(a.get("goalkicking", 45))
			+ float(w[3]) * float(a.get("intercept", 45))
			+ float(w[4]) * fifth)
	var overall: float = 0.70 * core + 0.22 * float(a.get("star", 45)) \
			+ 0.08 * float(a.get("durability", 45))
	p["overall"] = int(clampi(roundi(overall), 1, 99))
	p["value"] = Ratings.salary_value(int(p["overall"]))
