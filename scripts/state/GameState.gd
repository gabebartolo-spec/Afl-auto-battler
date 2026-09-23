extends Node
## GameState (autoload) - the in-progress season: which club you manage, your
## drafted list, the fixture, the ladder and the finals bracket.
##
## Every scene reads from here and nothing else, so scene changes never lose
## the season.

## Name presentation is a player preference rather than a career setting. The
## game starts with generated fictional labels; the optional real-name view
## shows each AFL name on its own, without changing the simulation or IDs.
signal player_names_changed
var show_real_names := false

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

## Career loop: season 1 is the 2026 season. Every completed season ends with
## a national intake draft (keep your list, sign the rookies), then the same
## league rolls into the next year with one season of ageing applied.
var season_year := 2026
var draftee_pool: Array = []     # all prospects that have not been drafted yet
var drafted_draftees := {}       # prospect id -> destination club
var intake_assignments: Array = []  # father-son / NGA pre-draft landings
var intake_summary := {}        # last rollover: retirements and growth
## Last game's per-player XP. The training menu reads this so the whole list
## is visible, not a five-name sample.
var last_training_report: Dictionary = {}
var _xp_grant_key := ""

const TRAIN_STATS := [
	["disposal", "Disposal"], ["contested", "Contested"], ["marking", "Marking"],
	["pressure", "Pressure"], ["intercept", "Intercept"], ["carry", "Carry"],
	["goalkicking", "Goalkicking"], ["accuracy", "Accuracy"],
	["creating", "Creating"], ["ruck", "Ruck"], ["discipline", "Discipline"],
	["durability", "Durability"], ["star", "Star power"],
]
const XP_SQUAD := 6
const XP_SELECTED := 8
const XP_NAMED := 4
const XP_PERF_CAP := 36


func set_show_real_names(enabled: bool) -> void:
	if show_real_names == enabled:
		return
	show_real_names = enabled
	player_names_changed.emit()


func reset() -> void:
	# Mid-career seasons mutate the loaded player dicts in place (intake,
	# ageing, XP training). A new career must start from the pristine 2026
	# dataset, so reload the data files before rebuilding anything.
	GameDB.reload()
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
	last_training_report = {}
	_xp_grant_key = ""
	season_year = 2026
	drafted_draftees = {}
	intake_assignments = []
	intake_summary = {}
	draftee_pool = GameDB.draftees.duplicate()


func begin_draft() -> void:
	var seed := int(Time.get_unix_time_from_system()) % 1000000
	draft = Draft.new(GameDB.all_players_sorted(), GameDB.CLUB_ORDER.duplicate(), seed)
	if draftee_pool.is_empty():
		draftee_pool = GameDB.draftees.duplicate()


# ---------------------------------------------------------------------------
# End-of-season intake draft (the national draft: keep your list, add rookies)
# ---------------------------------------------------------------------------
## Open this year's intake. Club-tied prospects (father-son / NGA) land with
## their clubs before the snake starts; the rest forms the open pool, drafted
## in reversed-ladder order (worst club first) like the real national draft.
## Returns false when there is nothing to draft.
func begin_intake_draft() -> bool:
	if season == null:
		return false
	if not (season.is_season_over() or season.is_regular_done()):
		return false
	if draft != null and draft.intake_mode:
		return true  # resume the draft in progress
	if draftee_pool.is_empty():
		draftee_pool = GameDB.draftees.duplicate()

	_ensure_league_lists()
	var available := []
	for p in draftee_pool:
		if not drafted_draftees.has(str(p["id"])):
			available.append(p)
	if available.is_empty():
		return false

	intake_assignments = []
	var open_pool := []
	for p in available:
		var tie := str(p.get("tied_club", ""))
		var tied_this_year: bool = int(p.get("draft_year", 0)) == season_year
		if tie != "" and tied_this_year and league_lists.has(tie):
			_assign_draftee(tie, p, str(p.get("tied_type", "tied")))
		else:
			open_pool.append(p)
	if my_club != "" and league_lists.has(my_club):
		my_list = league_lists[my_club]

	if open_pool.is_empty():
		# Every prospect was club-tied. Nothing to run; the caller can start
		# the next season directly. (Never happens with the shipped class.)
		return false

	var order := []
	for row in season.ladder_sorted():
		order.append(str(row["code"]))
	order.reverse()

	var sizes := {}
	var role_counts := {}
	for code in GameDB.CLUB_ORDER:
		var arr: Array = league_lists.get(code, [])
		sizes[code] = arr.size()
		var c := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
		for p in arr:
			var r := str(p["role"])
			if c.has(r):
				c[r] = int(c[r]) + 1
		role_counts[code] = c

	var seed := int(Time.get_unix_time_from_system()) % 1000000
	draft = Draft.build_intake(open_pool, GameDB.CLUB_ORDER.duplicate(), order,
			seed, sizes, role_counts)
	draft.start_for_user(my_club)
	return true


## Commit the intake: merge picks into every club's list, generate next year's
## class, age the whole league (growth, decline, retirements), then build the
## next season on those lists.
func finish_intake_draft() -> bool:
	if draft == null or not draft.intake_mode or not draft.is_finished():
		return false
	_ensure_league_lists()
	var next_year := season_year + 1
	var merged := 0
	for code in GameDB.CLUB_ORDER:
		var arr: Array = league_lists.get(code, [])
		for p in (draft.club_lists.get(code, []) as Array):
			var id := str(p["id"])
			if drafted_draftees.has(id):
				continue
			merged += 1
			var entry := draft.pick_details(id)
			if not p.has("xp"):
				p["xp"] = 0
				p["xp_games"] = 0
			p["club"] = code
			p["num"] = _next_jumper_number(arr)
			p["draft_pick"] = int(entry.get("pick", 0))
			p["draft_round"] = int(entry.get("round", 0))
			arr.append(p)
			drafted_draftees[id] = code
	draft = null
	_start_next_season(next_year, merged)
	return true


## Roll every list forward one year and rebuild the season. Split out so a
## career can continue even when there is no prospect pool to draft.
func _start_next_season(next_year: int, signed: int) -> void:
	# Next year's generated class joins the pool before ageing, so the fresh
	# 17-year-olds are also a year older in the season they arrive.
	var generated := Prospects.generate_class(next_year)
	GameDB.register_draftees(generated)
	for p in generated:
		draftee_pool.append(p)

	intake_summary = Prospects.age_league(league_lists, next_year)
	intake_summary["signed"] = signed
	intake_summary["year"] = next_year
	draftee_pool = Prospects.age_pool(draftee_pool, next_year, drafted_draftees)

	my_list = league_lists.get(my_club, [])
	var lists := {}
	for code in GameDB.CLUB_ORDER:
		lists[code] = (league_lists[code] as Array).duplicate()
	season = Season.new(GameDB.CLUB_ORDER.duplicate(), lists,
			int(Time.get_unix_time_from_system()) % 1000000)
	season_year = next_year
	season_log = []
	last_training_report = {}
	_xp_grant_key = ""
	last_results = []
	last_match = {}
	last_phase = "regular"
	last_label = "Round 1"
	pending_match = {}
	pending_sim = null
	pending_round_results = []
	pending_phase = ""
	pending_label = ""


## Roll on without an intake (no prospects available, or the manager skipped
## the draft). Same ageing and rebuild, zero new signings.
func start_next_season() -> bool:
	if season == null:
		return false
	if not (season.is_season_over() or season.is_regular_done()):
		return false
	if draft != null:
		if draft.intake_mode and draft.is_finished():
			return finish_intake_draft()
		if draft.intake_mode or not draft.is_finished():
			return false  # an intake still in progress blocks the rollover
		draft = null  # a completed career draft sitting in the slot is spent
	_ensure_league_lists()
	_start_next_season(season_year + 1, 0)
	return true


## The live lists for a rollover are the season's career copies (they carry
## this season's XP and training), not the pre-season dictionaries the draft
## committed. Adopt them (and default the XP fields for any new signing) so
## ageing, retirement and the intake merge all act on what actually played.
func _ensure_league_lists() -> void:
	if season == null or season.lists.is_empty():
		return
	var live := {}
	for code in season.lists:
		var arr: Array = season.lists[code]
		for p in arr:
			if not (p is Dictionary):
				continue
			if not (p as Dictionary).has("xp"):
				p["xp"] = 0
				p["xp_games"] = 0
		live[code] = arr
	if live.is_empty():
		return
	league_lists = live


func _assign_draftee(code: String, p: Dictionary, kind: String) -> void:
	var arr: Array = league_lists.get(code, [])
	if not p.has("xp"):
		p["xp"] = 0
		p["xp_games"] = 0
	p["club"] = code
	p["num"] = _next_jumper_number(arr)
	p["draft_pick"] = 0
	arr.append(p)
	drafted_draftees[str(p["id"])] = code
	intake_assignments.append({
		"club": code, "player_id": str(p["id"]),
		"player_name": str(p.get("generic_name", p.get("name", "Player"))),
		"kind": kind, "overall": int(p["overall"]),
	})


func _next_jumper_number(list: Array) -> int:
	var used := {}
	for p in list:
		used[int(p.get("num", 0))] = true
	for n in range(41, 90):
		if not used.has(n):
			return n
	for n in range(1, 41):
		if not used.has(n):
			return n
	return 99


## Commit the completed league draft and build the season from every club's
## new list. Original club lists are only used by the legacy/test fallback.
func start_season(club_code: String, list: Array) -> void:
	my_club = club_code
	var lists := {}
	if draft != null and draft.league_mode and draft.is_finished():
		league_lists = draft.all_lists()
		for code in GameDB.CLUB_ORDER:
			lists[code] = _career_copies(league_lists.get(code, []))
	else:
		# Fallback for tests or old saves: your drafted list plus real AI lists.
		for code in GameDB.CLUB_ORDER:
			var source: Array = list if code == club_code else GameDB.club_list(code)
			lists[code] = _career_copies(source)
	# Career copies, not the shared database rows. Training must not rewrite
	# the draft pool for the next career.
	my_list = lists.get(my_club, [])
	season = Season.new(GameDB.CLUB_ORDER.duplicate(), lists,
			int(Time.get_unix_time_from_system()) % 1000000)
	last_phase = "regular"
	last_label = "Round 1"
	last_training_report = {}
	_xp_grant_key = ""


## Set up your next match (home-and-away round or final) to be played live,
## quarter by quarter, with the coach box. Every other match that week is
## simulated straight away. Returns false when you have no match to play.
func prepare_interactive_match() -> bool:
	if season == null or season.is_season_over():
		return false
	if season.is_regular_done():
		return _prepare_interactive_final()
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


## Finals version of prepare_interactive_match. Nothing is recorded until
## your final finishes, so the bracket slots stay untouched while you coach.
func _prepare_interactive_final() -> bool:
	ensure_finals()
	var matches := season.finals_week_matches()
	var mine := -1
	for i in range(matches.size()):
		var m: Dictionary = matches[i]
		if m["home"] == my_club or m["away"] == my_club:
			mine = i
	if mine < 0:
		return false
	pending_match = {}
	pending_sim = null
	pending_round_results = []
	for i in range(matches.size()):
		var m: Dictionary = matches[i]
		if i == mine or m["home"] == "" or m["away"] == "":
			continue
		var res := season.simulate(m["home"], m["away"], season.finals_seed(i),
				season.finals_neutral(m))
		res["finals_index"] = i
		pending_round_results.append(res)
	var fm: Dictionary = matches[mine]
	var neutral := season.finals_neutral(fm)
	pending_match = {"home": fm["home"], "away": fm["away"],
			"round": Season.REGULAR_ROUNDS + int(season.finals["week"]),
			"label": str(fm["label"]), "tag": str(fm["tag"]),
			"neutral": neutral, "finals_index": mine}
	var home := Squad.new(GameDB.club_name(str(fm["home"])),
			season.lists[fm["home"]], not neutral, str(fm["home"]))
	var away := Squad.new(GameDB.club_name(str(fm["away"])),
			season.lists[fm["away"]], false, str(fm["away"]))
	pending_sim = MatchSim.new(home, away, season.finals_seed(mine))
	pending_phase = "finals"
	pending_label = str(fm["label"])
	last_results = []
	last_match = {}
	last_phase = pending_phase
	last_label = pending_label
	return true


func finish_interactive_match(res: Dictionary) -> void:
	if season == null or pending_match.is_empty():
		return
	if pending_phase == "finals":
		_finish_interactive_final(res)
		return
	res["round"] = int(pending_match.get("round", season.round_index + 1))
	res["label"] = str(pending_match.get("label", "Match"))
	season.record_regular(res)
	var played := pending_round_results.duplicate()
	played.append(res)
	season.results.append(played)
	season.round_index += 1
	season.recalc_ladder()
	ensure_finals()
	last_results = played
	last_match = res
	last_phase = "regular"
	last_label = str(res["label"])
	for r in played:
		season_log.append(r)
	_grant_match_xp(res)
	_clear_pending()


## Record the whole finals week in bracket order (your final included), then
## close the week exactly as a simulated week would.
func _finish_interactive_final(res: Dictionary) -> void:
	var matches := season.finals_week_matches()
	var by_index := {}
	for r in pending_round_results:
		by_index[int(r["finals_index"])] = r
		r.erase("finals_index")
	by_index[int(pending_match["finals_index"])] = res
	var played := []
	for i in range(matches.size()):
		if not by_index.has(i):
			continue
		var fin: Dictionary = by_index[i]
		season.record_final(matches[i], fin)
		played.append(fin)
	season.complete_finals_week(played)
	last_results = played
	last_match = res
	last_phase = "done" if season.is_season_over() else "finals"
	last_label = str(res["label"])
	for r in played:
		season_log.append(r)
	_grant_match_xp(res)
	_clear_pending()


func _clear_pending() -> void:
	pending_match = {}
	pending_sim = null
	pending_round_results = []
	pending_phase = ""
	pending_label = ""


## Start the finals the moment the home-and-away season ends, so the hub can
## show your qualifying or elimination final straight away.
func ensure_finals() -> void:
	if season != null and season.is_regular_done() and season.finals.is_empty():
		season.start_finals()


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
		ensure_finals()
	elif not season.is_season_over():
		ensure_finals()
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
	_grant_match_xp(last_match)
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


## Deep copy so a career can raise attributes without mutating GameDB.
func _career_copies(source: Array) -> Array:
	var out: Array = []
	for p in source:
		if not (p is Dictionary):
			continue
		var copy: Dictionary = (p as Dictionary).duplicate(true)
		copy["xp"] = 0
		copy["xp_games"] = 0
		out.append(copy)
	return out


func list_player(player_id: String) -> Dictionary:
	for p in my_list:
		if str(p.get("id", "")) == player_id:
			return p
	return {}


func train_stat_label(key: String) -> String:
	for row in TRAIN_STATS:
		if str(row[0]) == key:
			return str(row[1])
	return key


func xp_gain_for(player_id: String) -> int:
	for row in last_training_report.get("rows", []):
		if str(row.get("id", "")) == player_id:
			return int(row.get("xp", 0))
	return 0


func last_duty(player_id: String) -> String:
	for row in last_training_report.get("rows", []):
		if str(row.get("id", "")) != player_id:
			continue
		if bool(row.get("on_ground", false)):
			return "On the ground"
		if bool(row.get("on_bench", false)):
			return "Interchange"
		return "Not selected"
	return ""


func _grant_match_xp(res: Dictionary) -> void:
	if res.is_empty() or my_list.is_empty() or my_club == "":
		return
	if str(res.get("home", "")) != my_club and str(res.get("away", "")) != my_club:
		return
	var key := "%s|%s|%s|%s" % [str(res.get("round", "")), str(res.get("label", "")),
			str(res.get("home", "")), str(res.get("away", ""))]
	if key == _xp_grant_key:
		return
	_xp_grant_key = key
	last_training_report = grant_match_xp(res)


## Every player on the list is paid. Named players and good games earn more.
## The old trainer picked five names at random and hid everyone else.
func grant_match_xp(res: Dictionary) -> Dictionary:
	var stats_all: Dictionary = res.get("players", {})
	var squad := Squad.new(GameDB.club_name(my_club), my_list,
			str(res.get("home", "")) == my_club, my_club)
	var ground_ids := {}
	var bench_ids := {}
	for p in squad.ground:
		ground_ids[str(p["id"])] = true
	for p in squad.bench:
		bench_ids[str(p["id"])] = true
	var rows: Array = []
	var total := 0
	for p in my_list:
		var id := str(p["id"])
		var on_ground := ground_ids.has(id)
		var on_bench := bench_ids.has(id)
		var stats: Dictionary = stats_all.get(id, {})
		var gain := _xp_amount(stats, on_ground, on_bench)
		p["xp"] = int(p.get("xp", 0)) + gain
		p["xp_games"] = int(p.get("xp_games", 0)) + 1
		total += gain
		rows.append({
			"id": id,
			"xp": gain,
			"on_ground": on_ground,
			"on_bench": on_bench,
		})
	rows.sort_custom(func(a, b): return int(a["xp"]) > int(b["xp"]))
	return {
		"label": str(res.get("label", last_label)),
		"home": str(res.get("home", "")),
		"away": str(res.get("away", "")),
		"rows": rows,
		"total": total,
		"count": rows.size(),
	}


func _xp_amount(stats: Dictionary, on_ground: bool, on_bench: bool) -> int:
	var xp := XP_SQUAD
	if on_ground or on_bench:
		xp += XP_SELECTED
	if on_ground:
		xp += XP_NAMED
	if stats.is_empty():
		return xp
	var perf := 0
	perf += int(stats.get("disposals", 0))
	perf += int(stats.get("marks", 0))
	perf += int(stats.get("tackles", 0))
	perf += int(stats.get("goals", 0)) * 8
	perf += int(stats.get("behinds", 0)) * 2
	perf += int(float(stats.get("hitouts", 0)) / 2.0)
	perf += int(stats.get("inside50", 0)) * 2
	perf += int(stats.get("clearances", 0)) * 2
	perf += int(stats.get("rebounds", 0))
	perf += int(stats.get("one_percenters", 0))
	perf -= int(stats.get("clangers", 0))
	return xp + clampi(perf, 0, XP_PERF_CAP)


func train_cost(p: Dictionary, attr_key: String) -> int:
	if not (p.get("attr", {}) as Dictionary).has(attr_key):
		return -1
	var cur := int((p["attr"] as Dictionary).get(attr_key, 1))
	if cur >= 99:
		return -1
	return _cost_for(cur, float(p.get("gm", 18.0)))


func _cost_for(cur: int, games: float) -> int:
	var exp_mult := clampf(0.70 + games / 40.0, 0.70, 1.20)
	return maxi(8, int(round((8.0 + float(cur) * 0.40) * exp_mult)))


func affordable_points(player_id: String, attr_key: String, cap := 5) -> int:
	var p := list_player(player_id)
	if p.is_empty():
		return 0
	var xp := int(p.get("xp", 0))
	var cur := int((p["attr"] as Dictionary).get(attr_key, 1))
	var games := float(p.get("gm", 18.0))
	var n := 0
	while n < cap and cur < 99:
		var cost := _cost_for(cur, games)
		if xp < cost:
			break
		xp -= cost
		cur += 1
		n += 1
	return n


## Spend a player's own XP on one stat. `points` is a cap, not a promise:
## the call stops at 99 or when the bank runs out.
func train_stat(player_id: String, attr_key: String, points := 1) -> Dictionary:
	var fail := {"ok": false, "reason": "Could not train that stat.", "points": 0, "cost": 0}
	var p := list_player(player_id)
	if p.is_empty():
		fail["reason"] = "That player is not on your list."
		return fail
	if not (p.get("attr", {}) as Dictionary).has(attr_key):
		fail["reason"] = "That stat cannot be trained."
		return fail
	var spent := 0
	var gained := 0
	var ov_before := int(p["overall"])
	var stat_before := int(p["attr"][attr_key])
	for _step in range(maxi(1, points)):
		var cost := train_cost(p, attr_key)
		if cost < 0 or int(p.get("xp", 0)) < cost:
			break
		p["xp"] = int(p["xp"]) - cost
		p["attr"][attr_key] = mini(99, int(p["attr"][attr_key]) + 1)
		spent += cost
		gained += 1
	if gained == 0:
		var needed := train_cost(p, attr_key)
		fail["cost"] = needed
		fail["reason"] = "That stat is already 99." if needed < 0 else "Needs %d XP." % needed
		return fail
	_recalc_player_overall(p)
	return {
		"ok": true,
		"reason": "",
		"points": gained,
		"cost": spent,
		"stat_before": stat_before,
		"stat_after": int(p["attr"][attr_key]),
		"overall_before": ov_before,
		"overall_after": int(p["overall"]),
		"xp": int(p["xp"]),
		"attr": attr_key,
	}


func _recalc_player_overall(p: Dictionary) -> void:
	p["overall"] = Ratings.rate_overall(p["attr"], str(p["role"]),
			Ratings.effective_games(p))
	p["value"] = Ratings.salary_value(int(p["overall"]))
