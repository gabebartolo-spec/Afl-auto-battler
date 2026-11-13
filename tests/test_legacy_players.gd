extends RefCounted
## No real player goes missing in a Legacy career (TODO row 142; director,
## 2026-11-13: "please make sure that no players are missing or prematurely
## axed etc").
##
## A seeded tracer: a career from the 1990 start runs every off-season the way
## the game does (open_offseason, free agency, the National Draft, the
## rollover, the Rookie Draft) to 2026, matches skipped, and every player id
## is followed from one season's start to the next. Each id that leaves the
## lists, the free agents and the draft pool must end in exactly one way:
##   retired (with age and reason), delisted with no club taking him (career
##   over), medically retired, or aged out of the draft pool.
## It fails on:
##   - an id that vanishes, or sits in two places at once;
##   - a real draftee (data/legacy/classes.csv) who never reaches a list;
##   - real players cut while their real careers ran on: more than a few
##     ended (delisted, dropped, retired) years before their real last season;
##   - a rival list over its era's senior or rookie spots, or under the
##     minimum, after a rollover;
##   - a real state-league or academy player held in the pool past his own
##     draft and aged out.
## Every other Legacy start on the dataset table (2000, 2010, 2020 once they
## land) gets a short run with the same checks. Run through
## tests/run_legacy_players_tests.gd.

var failures: Array[String] = []
var checks := 0

const SUITE_SEED := 1990
const COACHED := "HAW"
## A real player may finish this many seasons before his real last one: the
## sim moves careers, by form, injury and its own list calls.
const MARGIN := 2
## Of the real players whose careers end, at most this share may end more
## than MARGIN seasons early (a mass early cut is a bug; a few are football).
const EARLY_SHARE := 0.15
## Seasons a short run from a later start plays.
const SHORT_SEASONS := 3

var real_last := {}   # "first last|dob" -> his last season on an AFL list (1990-2025)
var table: Array = [] # one row per rollover (print_table)


func run() -> void:
	failures.clear()
	checks = 0
	GameState.replay_seed = SUITE_SEED
	_load_real_careers()
	_t("_test_1990_to_2026")
	for id in Datasets.ready_ids():
		# Any other Legacy start (the 1990 set is the long run above; its
		# data_season is 1989, the year its lists come from).
		var start := int(Datasets.get_set(str(id)).get("start_year", 2027))
		if str(id) != "1990" and start < 2027:
			_t("_test_short_run", [str(id)])
	GameState.replay_seed = 0
	GameDB.reload()
	print(Ran.line("Legacy players", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


# ---------------------------------------------------------------------------
# Real careers
# ---------------------------------------------------------------------------
func _load_real_careers() -> void:
	real_last = {}
	for decade in ["1990s", "2000s", "2010s", "2020s"]:
		var path := "res://data/legacy/%s/lists.csv" % decade
		if not FileAccess.file_exists(path):
			continue
		for r in GameDB._read_dicts(path):
			var key := _key_of(str(r.get("first", "")), str(r.get("last", "")), str(r.get("dob", "")))
			real_last[key] = maxi(int(real_last.get(key, 0)), int(str(r.get("year", "0"))))


static func _key_of(first: String, last: String, dob: String) -> String:
	return "%s %s|%s" % [first.strip_edges(), last.strip_edges(), dob.strip_edges()]


static func _key(p: Dictionary) -> String:
	return "%s|%s" % [str(p.get("real_name", "")).strip_edges(), str(p.get("dob", "")).strip_edges()]


# ---------------------------------------------------------------------------
# The tracer
# ---------------------------------------------------------------------------
## Where every player is: id -> {"loc", "age", ...}. Lists, free agents, the
## undrafted pool and a new club's list under construction. An id in two
## places is reported in "_twice".
func _snapshot() -> Dictionary:
	var out := {}
	var twice := []
	var put := func(p: Dictionary, loc: String) -> void:
		var id := str(p.get("id", ""))
		if id == "":
			return
		if out.has(id):
			twice.append("%s %s in %s and %s" % [id, str(p.get("real_name", "")), str(out[id]["loc"]), loc])
			return
		out[id] = {"loc": loc, "age": float(p.get("age", 0.0)), "ovr": int(p.get("overall", 0)),
			"name": str(p.get("real_name", "")), "key": _key(p),
			"real_class": bool(p.get("real_class", false)), "draft_year": int(p.get("draft_year", 0)),
			"tied": str(p.get("tied_club", "")), "tie_type": str(p.get("tied_type", "")),
			"retiring": int(p.get("retiring", 0)), "rookie": str(p.get("rookie_list", ""))}
	var seen_codes := {}
	if GameState.season != null:
		for code in GameState.season.lists:
			seen_codes[str(code)] = true
			for p in GameState.season.lists[code]:
				put.call(p, "list:" + str(code))
	for code in GameState.league_lists:
		if seen_codes.has(str(code)):
			continue
		for p in GameState.league_lists[code]:
			put.call(p, "list:" + str(code))
	for code in ExpansionBuild.building(GameState):
		for p in ExpansionBuild.list_of(GameState, code):
			put.call(p, "build:" + str(code))
	for p in GameState.free_agents:
		put.call(p, "fa")
	for p in GameState.draftee_pool:
		if not GameState.drafted_draftees.has(str(p.get("id", ""))):
			put.call(p, "pool")
	out["_twice"] = twice
	return out


var laps := {}
var lost_in := {}   # id -> the off-season phase he was last seen before
var _seen := {}

func _lap(what: String, t: int) -> void:
	laps[what] = int(laps.get(what, 0)) + Time.get_ticks_msec() - t
	# Which phase an id left every list, the free agents and the pool in,
	# so a vanished player's message names where to look.
	var now := {}
	for id in _snapshot():
		now[id] = true
	for id in _seen:
		if not now.has(id) and not lost_in.has(id):
			lost_in[id] = what
	_seen = now


## Play one season's worth of off-season from a season's start to the next
## season's start, as the game does with nobody managing a list.
func _roll_one() -> bool:
	var year := GameState.season_year
	GameState.season.round_index = GameState.season.fixture.size()
	lost_in = {}
	_seen = {}
	for id in _snapshot():
		_seen[id] = true
	var t := Time.get_ticks_msec()
	GameState.open_offseason()
	_lap("open_offseason", t)
	t = Time.get_ticks_msec()
	var drafting := GameState.begin_intake_draft()
	_lap("begin_intake_draft", t)
	t = Time.get_ticks_msec()
	if drafting:
		var d: Draft = GameState.draft
		var guard := 0
		while d != null and not d.is_finished() and guard < 5000:
			guard += 1
			var code := d.current_club()
			if not d.club_lists.has(code):
				_check(false, "%d draft: pick %d belongs to %s, who have no seat at this draft" % [year, d.pick_index + 1, code])
				return false
			var c := d._best_ai_pick(code)
			if c.is_empty() or not d._draft_pick(code, c):
				d._skip_current_pick()
		_lap("picks", t)
		t = Time.get_ticks_msec()
		GameState.finish_intake_draft()
	else:
		GameState.start_next_season()
	_lap("next season", t)
	t = Time.get_ticks_msec()
	RookieList.settle(GameState)
	_lap("rookie list", t)
	return GameState.season_year == year + 1


## Follow every id from `before` (the start of `year`) to `after` (the start
## of year + 1): each leaver ends one way, each arrival comes one way.
func _trace(year: int, before: Dictionary, after: Dictionary, life: Dictionary) -> Dictionary:
	var row := {"year": year + 1, "listed": 0, "retired": 0, "medical": 0, "delisted": 0,
		"drafted": 0, "relisted": 0, "entered": 0, "dropped": 0, "to_fa": 0, "reasons": {},
		"vanished": [], "early": [], "aged_out_real": []}
	var retired := {}
	for r in (GameState.intake_summary.get("retired", []) as Array):
		retired[str(r["id"])] = r
	var medical := {}
	for r in GameState.medical_retired:
		if r is Dictionary:
			medical[str(r.get("id", ""))] = true
	for id in after:
		if id == "_twice":
			continue
		var now: Dictionary = after[id]
		var loc := str(now["loc"])
		if loc.begins_with("list:"):
			row["listed"] += 1
		if not before.has(id):
			if loc.begins_with("list:"):
				if GameState.drafted_draftees.has(id):
					row["drafted"] += 1
				else:
					row["entered"] += 1
			continue
		var was := str(before[id]["loc"])
		if loc.begins_with("list:") and was == "pool":
			row["drafted"] += 1
		elif loc.begins_with("list:") and was == "fa":
			row["relisted"] += 1
		elif loc == "fa" and was.begins_with("list:"):
			row["to_fa"] += 1
		if loc.begins_with("list:"):
			life[id] = true
	for id in before:
		if id == "_twice" or after.has(id):
			continue
		var was: Dictionary = before[id]
		var how := ""
		if retired.has(id):
			var r: Dictionary = retired[id]
			if int(was["retiring"]) == year + 1 or int(was["retiring"]) == year:
				how = "retired: chose to"
			elif int(r.get("overall", 99)) <= 32:
				how = "retired: rating"
			elif float(r.get("age", 0)) >= 37.0:
				how = "retired: 37 or older"
			else:
				how = "retired: age 33-36"
			row["retired"] += 1
		elif medical.has(id):
			how = "medical"
			row["medical"] += 1
		elif GameState.departed_names.has(id):
			how = "delisted, unsigned" if str(was["loc"]) != "pool" else "pool, career over"
			row["delisted"] += 1
		elif str(was["loc"]) == "pool":
			how = "pool: aged out" if float(was["age"]) + 1.0 >= 22.0 else "pool: dropped young"
			row["dropped"] += 1
			if bool(was["real_class"]) and not life.has(id):
				row["aged_out_real"].append("%s (%s, class %d%s, age %d)" % [str(was["name"]), id,
						int(was["draft_year"]), ", tied " + str(was["tied"]) if str(was["tied"]) != "" else "",
						int(float(was["age"]) + 1.0)])
		else:
			how = "vanished from " + str(was["loc"])
			row["vanished"].append("%s %s (%s, age %d, gone in %s)" % [id, str(was["name"]), str(was["loc"]),
					int(float(was["age"])), str(lost_in.get(id, "?"))])
		var reasons: Dictionary = row["reasons"]
		reasons[how] = int(reasons.get(how, 0)) + 1
		# A real player whose real career ran on past this season plus the margin.
		var key := str(was["key"])
		if str(was["loc"]) != "pool" and real_last.has(key) and int(real_last[key]) >= year + 1 + MARGIN \
				and int(real_last[key]) < 2025:
			row["early"].append("%s (%s, %s at %d, real last %d)" % [str(was["name"]), how, str(was["loc"]),
					int(float(was["age"])), int(real_last[key])])
		elif str(was["loc"]) != "pool" and real_last.has(key) and int(real_last[key]) == 2025 and year + 1 + MARGIN <= 2025:
			row["early"].append("%s (%s, %s at %d, still listed in 2025)" % [str(was["name"]), how, str(was["loc"]),
					int(float(was["age"]))])
	return row


## Every rival list after a rollover: within its year's senior and rookie
## spots, and at least the minimum.
func _caps(year: int) -> Array:
	var bad := []
	var active := GameDB.active_clubs(year)
	for code in active:
		if str(code) == GameState.my_club:
			continue
		var list: Array = GameState.season.lists.get(code, [])
		var seniors := RookieList.senior_count(list)
		var cat_a := RookieList.cat_a_count(list)
		if seniors > RookieList.senior_spots() or cat_a > RookieList.cat_a_spots() or list.size() < Contracts.min_list():
			# Where an over-full list's players came from, so the message names the step.
			var fnd := list.filter(func(q): return str(q["id"]).begins_with("FND_")).size()
			var joined := list.filter(func(q): return int(q.get("joined", 0)) == year) 					.map(func(q): return str(q.get("real_name", q["id"])))
			bad.append("%s %d: %d seniors of %d, %d rookies of %d, %d listed (state league %d, joined %d: %s)" % [code,
					year, seniors, RookieList.senior_spots(), cat_a, RookieList.cat_a_spots(), list.size(), fnd,
					year, ", ".join(joined)])
	return bad


## The opening draft as the draft screen plays it: the coach takes the best
## player on the board at each of his picks, the rivals pick for themselves.
func _opening_draft() -> void:
	var guard := 0
	while GameState.draft != null and not GameState.draft.is_finished() and guard < 2000:
		guard += 1
		if GameState.draft.is_user_turn():
			var board: Array = GameState.draft.board("", "", "", "overall", true)
			if board.is_empty() or not GameState.draft.pick(board[0]):
				GameState.draft._skip_current_pick()
		else:
			GameState.draft.auto_until_user_turn()


## Run a career from `dataset` for `seasons` rollovers, checking each.
func _career(dataset: String, seasons: int) -> Dictionary:
	GameDB.reload(dataset)
	GameState.reset(dataset)
	GameState.autosave_enabled = false
	GameState.career_seed = SUITE_SEED
	# As Choose your club starts a past season (Main: begin_real_lists): each
	# club's whole real list, its list additions included, and the opening
	# National Draft. start_season's test fallback has neither, so a 2000
	# start opened on 29-32 players a club.
	GameState.begin_real_lists()
	GameState.choose_real_club(COACHED)
	_opening_draft()
	GameState.finish_intake_draft()
	RookieList.settle(GameState)
	var real_seen := {}   # real class id -> {name, draft_year}
	var life := {}        # id -> ever on a list during the run
	var all := {"vanished": [], "twice": [], "early": [], "ended_real": 0, "aged_out_real": [], "caps": [], "rows": []}
	var before := _snapshot()
	for id in before:
		if id != "_twice" and str(before[id]["loc"]).begins_with("list:"):
			life[id] = true
	all["twice"].append_array(before["_twice"])
	for i in range(seasons):
		var year := GameState.season_year
		for id in before:
			if id != "_twice" and bool(before[id]["real_class"]):
				real_seen[id] = before[id]
		var t0 := Time.get_ticks_msec()
		if not _roll_one():
			_check(false, "%s: %d rolls over to %d (now %d)" % [dataset, year, year + 1, GameState.season_year])
			break
		var after := _snapshot()
		print("legacy_players: %s %d -> %d in %d ms %s" % [dataset, year, year + 1, Time.get_ticks_msec() - t0, laps])
		laps = {}
		all["twice"].append_array(after["_twice"])
		var row := _trace(year, before, after, life)
		all["rows"].append(row)
		all["vanished"].append_array(row["vanished"])
		all["early"].append_array(row["early"])
		all["aged_out_real"].append_array(row["aged_out_real"])
		for id in before:
			if id != "_twice" and not after.has(id) and str(before[id]["loc"]) != "pool" and real_last.has(str(before[id]["key"])):
				all["ended_real"] = int(all["ended_real"]) + 1
		all["caps"].append_array(_caps(GameState.season_year))
		before = after
	for id in before:
		if id != "_twice" and bool(before[id]["real_class"]):
			real_seen[id] = before[id]
	# Real draftees who never reached a list though their draft has been held.
	var never := []
	var held := 0
	for id in real_seen:
		var r: Dictionary = real_seen[id]
		if int(r["draft_year"]) >= GameState.season_year:
			continue
		held += 1
		if not life.has(id):
			never.append("%s (%s)" % [str(r["name"]), id])
	all["never"] = never
	all["held"] = held
	return all


func _report(dataset: String, all: Dictionary) -> void:
	print("Legacy players %s: season | listed | retired | medical | delisted (career over) | to free agency | drafted | relisted | entered | dropped from pool | reasons" % dataset)
	for row in all["rows"]:
		print("  %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %s" % [int(row["year"]), int(row["listed"]),
				int(row["retired"]), int(row["medical"]), int(row["delisted"]), int(row["to_fa"]), int(row["drafted"]),
				int(row["relisted"]), int(row["entered"]), int(row["dropped"]), str(row["reasons"])])
	print("  real draftees never listed: %d of %d held drafts" % [(all["never"] as Array).size(), int(all["held"])])
	print("  real careers ended early (> %d seasons before the real last): %d of %d ended" % [MARGIN,
			(all["early"] as Array).size(), int(all["ended_real"])])


func _checks(dataset: String, all: Dictionary) -> void:
	var vanished: Array = all["vanished"]
	_check(vanished.is_empty(), "%s: %d players vanished: %s" % [dataset, vanished.size(), ", ".join(vanished.slice(0, 12))])
	var twice: Array = all["twice"]
	_check(twice.is_empty(), "%s: %d players in two places: %s" % [dataset, twice.size(), ", ".join(twice.slice(0, 8))])
	var never: Array = all["never"]
	_check(never.is_empty(), "%s: %d of %d real draftees never reached a list: %s" % [dataset, never.size(),
			int(all["held"]), ", ".join(never.slice(0, 12))])
	var aged: Array = all["aged_out_real"]
	_check(aged.is_empty(), "%s: %d real prospects aged out of the pool: %s" % [dataset, aged.size(), ", ".join(aged.slice(0, 12))])
	var early: Array = all["early"]
	var ended := maxi(1, int(all["ended_real"]))
	_check(float(early.size()) / float(ended) <= EARLY_SHARE,
			"%s: %d of %d real careers ended more than %d seasons early: %s" % [dataset, early.size(), ended, MARGIN,
			", ".join(early.slice(0, 12))])
	var caps: Array = all["caps"]
	_check(caps.is_empty(), "%s: %d lists outside their era's spots after a rollover: %s" % [dataset, caps.size(),
			", ".join(caps.slice(0, 10))])


## The 1990 start through every rollover to 2026.
func _test_1990_to_2026() -> void:
	var all := _career("1990", 2026 - 1990)
	_check(GameState.season_year == 2026, "The 1990 career reaches 2026 (%d)" % GameState.season_year)
	_report("1990", all)
	_checks("1990", all)


## A later Legacy start: a few rollovers, the same checks.
func _test_short_run(dataset: String) -> void:
	var all := _career(dataset, SHORT_SEASONS)
	_report(dataset, all)
	_checks(dataset, all)
