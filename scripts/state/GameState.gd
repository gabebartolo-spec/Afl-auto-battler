extends Node
## GameState (autoload) - the in-progress season: which club you manage, your
## 44-player list, the fixture, the ladder and the finals bracket.
##
## Every scene reads from here and nothing else, so scene changes never lose
## the season.

var my_club := ""
var my_list: Array = []
var season: Season = null
var draft: Draft = null

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
	last_results = []
	last_match = {}
	last_phase = ""
	last_label = ""
	season_log = []


func begin_draft() -> void:
	draft = Draft.new(GameDB.all_players_sorted())


## Commit the drafted list and build the season around it. The 17 AI clubs keep
## the lists they actually fielded in 2026.
func start_season(club_code: String, list: Array) -> void:
	my_club = club_code
	my_list = list
	var lists := {}
	for code in GameDB.CLUB_ORDER:
		lists[code] = my_list if code == my_club else GameDB.club_list(code)
	season = Season.new(GameDB.CLUB_ORDER.duplicate(), lists,
			int(Time.get_unix_time_from_system()) % 1000000)
	last_phase = "regular"
	last_label = "Round 1"


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
	return season.ladder.get(my_club, {}) if season else {}


func my_position() -> int:
	if season == null:
		return 0
	var rows := season.ladder_sorted()
	for i in rows.size():
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
	return str(season.finals.get("premier", "")) if season else ""
