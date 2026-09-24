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
var last_injuries: Array = []    # the last round's new injuries, every club
var season_tally := {}           # player id -> running season numbers (Awards)
var season_awards := {}          # the finished season's awards
var honour_roll: Array = []      # one entry per completed season
var records := {}                # league records across the career
var salary_cap := 0              # cap points every club's payroll counts against
var free_agents: Array = []      # off-season: players no club kept
var offseason_year := 0          # the season whose off-season has opened
var offseason_log: Array = []    # what happened in the off-season, for news
var news: Array = []             # league news feed, newest first
var difficulty := "normal"       # this career's difficulty (DIFFICULTIES key)
var board := {}                  # confidence, goal, warned, sacked, history
var week_event := {}             # this week's event card (ClubLife.pick_event)
var losing_streak := 0

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
## Match XP. Every club earns it and training plans spend it, so it sets how
## far ratings climb during a season before the off-season re-anchors the
## league (Prospects.renormalise_league). Tuned so a season adds about 4.
const XP_SQUAD := 4
const XP_SELECTED := 6
const XP_NAMED := 3
const XP_PERF_CAP := 24


## Where the career is saved. Tests point this somewhere else so they never
## touch a real save.
var save_path := CareerSave.DEFAULT_PATH
var settings_path := "user://settings.cfg"
## Autosave runs on every screen change, after every round and when the app
## is backgrounded or closed. Tests switch it off.
var autosave_enabled := true
## Set by small edits (training, draft picks) that save on the next screen
## change or when the app is backgrounded, rather than on every tap.
var _dirty := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		show_real_names = bool(cfg.get_value("display", "real_names", false))


func _notification(what: int) -> void:
	# Mobile OSes kill backgrounded apps without warning; save on the way out.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		autosave_if_dirty()


## Small UI preferences (seen tutorials and the like) in the settings file.
func get_setting(key: String, fallback = null):
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return fallback
	return cfg.get_value("ui", key, fallback)


func set_setting(key: String, value) -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("ui", key, value)
	cfg.save(settings_path)


func set_show_real_names(enabled: bool) -> void:
	if show_real_names == enabled:
		return
	show_real_names = enabled
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("display", "real_names", enabled)
	cfg.save(settings_path)
	player_names_changed.emit()


# ---------------------------------------------------------------------------
# Saving and loading
# ---------------------------------------------------------------------------
## True when there is a career worth saving: a season, or a draft where you
## have already picked your club.
func has_career() -> bool:
	return season != null or (draft != null and not draft.user_club.is_empty())


func has_saved_career() -> bool:
	return CareerSave.exists(save_path)


## Club, year and stage of the saved career, for the main menu.
func saved_career_meta() -> Dictionary:
	return CareerSave.read_meta(save_path)


## Save if there is a career and no live match is half played. Mid-match the
## rest of the round is already on the ladder but the round has not closed,
## so the last save (from before the match) is the consistent one to keep.
func autosave() -> bool:
	if not autosave_enabled or not has_career() or not pending_match.is_empty():
		return false
	return save_career()


func mark_dirty() -> void:
	_dirty = true


func autosave_if_dirty() -> bool:
	if not _dirty:
		return false
	return autosave()


func save_career() -> bool:
	if not has_career():
		return false
	# The pre-season league draft is spent once the season starts (it holds a
	# second copy of the whole player pool), so it is not written.
	var keep_draft := draft != null and not (season != null and not draft.intake_mode)
	var state := {
		"season_year": season_year,
		"my_club": my_club,
		"season": _season_to_save() if season != null else null,
		"draft": CareerSave.object_vars(draft) if keep_draft else null,
		"league_lists": _unlinked_lists(league_lists),
		"league_links": _linked_codes(league_lists),
		"my_list": [] if _linked_code(my_list) != "" else my_list,
		"my_list_link": _linked_code(my_list),
		"draftee_pool": draftee_pool,
		"drafted_draftees": drafted_draftees,
		"intake_assignments": intake_assignments,
		"intake_summary": intake_summary,
		"last_training_report": last_training_report,
		"xp_grant_key": _xp_grant_key,
		"default_train_plan": default_train_plan,
		"last_phase": last_phase,
		"last_label": last_label,
		"season_log": CareerSave.slim_results(season_log),
		"last_injuries": last_injuries,
		"season_tally": season_tally,
		"season_awards": season_awards,
		"honour_roll": honour_roll,
		"records": records,
		"salary_cap": salary_cap,
		"free_agents": free_agents,
		"offseason_year": offseason_year,
		"offseason_log": offseason_log,
		"news": news,
		"difficulty": difficulty,
		"board": board,
		"week_event": week_event,
		"losing_streak": losing_streak,
		"db_draftees": GameDB.draftees,
		"db_late_draftees": GameDB.late_draftees,
		"db_alias_next": GameDB._alias_next,
	}
	var ok := CareerSave.write(state, _save_meta(), save_path)
	if ok:
		_dirty = false
	return ok


func _save_meta() -> Dictionary:
	var stage := "Draft"
	if season != null:
		if season.is_season_over():
			stage = "National draft" if draft != null else "Season complete"
		elif season.is_regular_done():
			stage = "Finals"
		else:
			stage = "Round %d" % (season.round_index + 1)
	return {"club": my_club if my_club != "" else (draft.user_club if draft != null else ""),
			"year": season_year, "stage": stage,
			"saved_at": Time.get_datetime_string_from_system()}


## Replace the in-memory career with the saved one. Returns false (and leaves
## a fresh state) if there is no usable save.
func load_career() -> bool:
	var state := CareerSave.read(save_path)
	if state.is_empty():
		return false
	reset()
	season_year = int(state.get("season_year", 2026))
	my_club = str(state.get("my_club", ""))
	if state.get("season") is Dictionary:
		var sv: Dictionary = state["season"]
		season = Season.new(sv["clubs"], sv["lists"], int(sv["seed"]))
		CareerSave.apply_vars(season, sv)
	if state.get("draft") is Dictionary:
		draft = Draft.new([], [], 0)
		CareerSave.apply_vars(draft, state["draft"])
		draft._pick_by_player = {}
		for entry in draft.pick_history:
			draft._pick_by_player[str(entry["player_id"])] = entry
	league_lists = state.get("league_lists", {})
	for code in state.get("league_links", []):
		if season != null and season.lists.has(code):
			league_lists[code] = season.lists[code]
	var link := str(state.get("my_list_link", ""))
	my_list = _season_list(link) if link != "" else state.get("my_list", [])
	draftee_pool = state.get("draftee_pool", [])
	drafted_draftees = state.get("drafted_draftees", {})
	intake_assignments = state.get("intake_assignments", [])
	intake_summary = state.get("intake_summary", {})
	last_training_report = state.get("last_training_report", {})
	_xp_grant_key = str(state.get("xp_grant_key", ""))
	default_train_plan = str(state.get("default_train_plan", "position"))
	last_phase = str(state.get("last_phase", ""))
	last_label = str(state.get("last_label", ""))
	season_log = state.get("season_log", [])
	last_injuries = state.get("last_injuries", [])
	season_tally = state.get("season_tally", {})
	season_awards = state.get("season_awards", {})
	honour_roll = state.get("honour_roll", [])
	records = state.get("records", {})
	salary_cap = int(state.get("salary_cap", 0))
	free_agents = state.get("free_agents", [])
	offseason_year = int(state.get("offseason_year", 0))
	offseason_log = state.get("offseason_log", [])
	news = state.get("news", [])
	board = state.get("board", {})
	week_event = state.get("week_event", {})
	losing_streak = int(state.get("losing_streak", 0))
	difficulty = str(state.get("difficulty", "normal"))
	if not DIFFICULTIES.has(difficulty):
		difficulty = "normal"
	GameDB.draftees = state.get("db_draftees", GameDB.draftees)
	GameDB.late_draftees = state.get("db_late_draftees", [])
	GameDB._alias_next = int(state.get("db_alias_next", GameDB._alias_next))
	_backfill_potential()
	ensure_contracts()
	if season != null and board.is_empty():
		_open_board_season()
	return true


## Careers saved before potential existed: give every player a POT, taking
## the dataset's (with its hand-set overrides) where the player came from it.
func _backfill_potential() -> void:
	var groups: Array = [draftee_pool, GameDB.late_draftees]
	if season != null:
		for code in season.lists:
			groups.append(season.lists[code])
	for code in league_lists:
		groups.append(league_lists[code])
	if draft != null:
		groups.append(draft.pool)
	for arr in groups:
		for p in arr:
			if not (p is Dictionary) or (p as Dictionary).has("potential"):
				continue
			var orig = GameDB.player_by_id(str(p["id"]))
			if orig is Dictionary and (orig as Dictionary).has("potential") and not is_same(orig, p):
				p["potential"] = maxi(int(orig["potential"]), int(p["overall"]))
				if bool(orig.get("rehab", false)) and int(p["overall"]) <= int(orig["overall"]):
					p["rehab"] = true
			else:
				Potential.assign(p)


func delete_saved_career() -> void:
	CareerSave.delete(save_path)


func _season_to_save() -> Dictionary:
	var sv := CareerSave.object_vars(season)
	sv["results"] = CareerSave.slim_results(season.results)
	var fin: Dictionary = season.finals.duplicate()
	if fin.has("weeks"):
		fin["weeks"] = CareerSave.slim_results(fin["weeks"])
	sv["finals"] = fin
	return sv


## Your list and the league lists are, at different points of a career, the
## very arrays the season plays with. Remember which, so loading relinks them
## instead of splitting them into copies. Also covers the league lists
## pointing at your list.
func _linked_code(arr: Array) -> String:
	if season == null:
		return ""
	for code in season.lists:
		if is_same(season.lists[code], arr):
			return "season:" + str(code)
	for code in league_lists:
		if is_same(league_lists[code], arr):
			return "league:" + str(code)
	return ""


func _season_list(link: String) -> Array:
	var parts := link.split(":")
	if parts.size() != 2:
		return []
	if parts[0] == "season" and season != null:
		return season.lists.get(parts[1], [])
	return league_lists.get(parts[1], [])


func _linked_codes(lists: Dictionary) -> Array:
	var out := []
	if season == null:
		return out
	for code in lists:
		if season.lists.has(code) and is_same(lists[code], season.lists[code]):
			out.append(code)
	return out


func _unlinked_lists(lists: Dictionary) -> Dictionary:
	var linked := _linked_codes(lists)
	var out := {}
	for code in lists:
		if not linked.has(code):
			out[code] = lists[code]
	return out


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
	last_injuries = []
	season_tally = {}
	season_awards = {}
	honour_roll = []
	records = {}
	salary_cap = 0
	free_agents = []
	offseason_year = 0
	offseason_log = []
	news = []
	board = {}
	week_event = {}
	losing_streak = 0
	difficulty = new_career_difficulty()
	last_training_report = {}
	_xp_grant_key = ""
	_dirty = false
	default_train_plan = "position"
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
	open_offseason()
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
	autosave()
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
			Contracts.rookie_deal(p)
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

	# Free agents are on no list until a rival signs them, so heal after
	# free agency closes, and heal the season's lists too.
	_close_contracts()
	Injuries.heal_all(league_lists)
	if season != null:
		Injuries.heal_all(season.lists)
	season_tally = {}
	season_awards = {}
	intake_summary = Prospects.age_league(league_lists, next_year)
	intake_summary["signed"] = signed
	for r in intake_summary.get("retired", []):
		if int(r.get("overall", 0)) >= NEWS_MIN_OVR:
			add_news("retirement", "%s (%s) has retired at %d." % [
					GameDB.player_display_name_by_id(str(r["id"]), str(r["name"])),
					GameDB.club_name(str(r["club"])), int(float(r["age"]))])
	intake_summary["year"] = next_year
	draftee_pool = Prospects.age_pool(draftee_pool, next_year, drafted_draftees)
	intake_summary["renormalised"] = Prospects.renormalise_league(league_lists,
			draftee_pool, GameDB.baseline_overall, GameDB.baseline_spread)

	# One array per club from here on: the season, the league lists and your
	# list are the same arrays, so trades and signings touch them all.
	var lists := {}
	for code in GameDB.CLUB_ORDER:
		lists[code] = league_lists[code]
		for p in lists[code]:
			p["season_start_ov"] = int(p["overall"])
	my_list = lists.get(my_club, [])
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
	_open_board_season()
	autosave()


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
	Contracts.rookie_deal(p)
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
	salary_cap = draft.budget if draft != null and draft.league_mode else 0
	ensure_contracts()
	_open_board_season()
	last_phase = "regular"
	last_label = "Round 1"
	last_training_report = {}
	_xp_grant_key = ""
	autosave()


## Set up your next match (home-and-away round or final) to be played live,
## quarter by quarter, with the coach box. Every other match that week is
## simulated straight away. Returns false when you have no match to play.
func prepare_interactive_match() -> bool:
	if season == null or season.is_season_over():
		return false
	_settle_week_event()
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
			season.lists[pending_match["home"]], true, str(pending_match["home"]),
			season.selections.get(str(pending_match["home"]), {}))
	var away := Squad.new(GameDB.club_name(str(pending_match["away"])),
			season.lists[pending_match["away"]], false, str(pending_match["away"]),
			season.selections.get(str(pending_match["away"]), {}))
	pending_sim = MatchSim.new(home, away, season.next_seed(99))
	pending_sim.moment_side = 0 if str(pending_match["home"]) == my_club else 1
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
				season.finals_neutral(m), true)
		res["finals_index"] = i
		pending_round_results.append(res)
	var fm: Dictionary = matches[mine]
	var neutral := season.finals_neutral(fm)
	pending_match = {"home": fm["home"], "away": fm["away"],
			"round": Season.REGULAR_ROUNDS + int(season.finals["week"]),
			"label": str(fm["label"]), "tag": str(fm["tag"]),
			"neutral": neutral, "finals_index": mine}
	var home := Squad.new(GameDB.club_name(str(fm["home"])),
			season.lists[fm["home"]], not neutral, str(fm["home"]),
			season.selections.get(str(fm["home"]), {}))
	var away := Squad.new(GameDB.club_name(str(fm["away"])),
			season.lists[fm["away"]], false, str(fm["away"]),
			season.selections.get(str(fm["away"]), {}))
	pending_sim = MatchSim.new(home, away, season.finals_seed(mine))
	pending_sim.finals_mode = true
	pending_sim.moment_side = 0 if str(fm["home"]) == my_club else 1
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
	_train_rivals(played)
	_after_round(played)
	_clear_pending()
	autosave()


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
	_train_rivals(played)
	_after_round(played)
	_clear_pending()
	autosave()


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
	_settle_week_event()
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
	_train_rivals(last_results)
	_after_round(last_results)
	autosave()
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


## Where your finals campaign stands: "" if you are not a finalist, else
## "alive" (you play this week), "bye" (won a qualifying final, week off),
## "eliminated", "premier" or "runner_up".
func my_finals_status() -> String:
	if season == null or season.finals.is_empty():
		return ""
	var top: Array = season.finals.get("top", [])
	if not top.has(my_club):
		return ""
	if season.is_season_over():
		if premier() == my_club:
			return "premier"
		if str(season.finals.get("runner_up", "")) == my_club:
			return "runner_up"
		return "eliminated"
	var slots: Dictionary = season.finals.get("slots", {})
	for tag in ["EF1", "EF2", "SF1", "SF2", "PF1", "PF2", "GF"]:
		if str(slots.get("L_" + tag, "")) == my_club:
			return "eliminated"
	for m in season.finals_week_matches():
		if m["home"] == my_club or m["away"] == my_club:
			return "alive"
	return "bye"


## One line on what your last final means, for the full-time and results
## screens. Reads the bracket, so a level final decided on ladder position
## still reports the right outcome.
func finals_outcome_line(res: Dictionary) -> String:
	var tag := str(res.get("tag", ""))
	if tag == "" or season == null or season.finals.is_empty():
		return ""
	var slots: Dictionary = season.finals.get("slots", {})
	var won: bool = str(slots.get("W_" + tag, "")) == my_club
	match tag.substr(0, 2):
		"QF":
			return "Straight through to a home preliminary final, with a week off." if won \
					else "Second chance: you host a semi final next week."
		"EF":
			return "Through to the semi finals." if won \
					else "Knocked out in an elimination final. Your season is over."
		"SF":
			return "Through to the preliminary finals." if won \
					else "Knocked out in the semi finals. Your season is over."
		"PF":
			return "Into the Grand Final!" if won \
					else "One game short: out in the preliminary final."
		"GF":
			return ("%d PREMIERS" % season_year) if won \
					else ("Runners-up in %d" % season_year)
	return ""


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
	# Training plans spend the fresh XP straight away.
	last_training_report["auto"] = apply_train_plans()


## Every player on the list is paid. Named players and good games earn more.
## The old trainer picked five names at random and hid everyone else.
func grant_match_xp(res: Dictionary) -> Dictionary:
	return _grant_xp(my_club, my_list, res)


## Pay one club's list for a match. Same scale for every club: the rivals
## earn exactly what your players earn.
func _grant_xp(club: String, list: Array, res: Dictionary) -> Dictionary:
	var stats_all: Dictionary = res.get("players", {})
	var squad := Squad.new(GameDB.club_name(club), list,
			str(res.get("home", "")) == club, club,
			season.selections.get(club, {}) if season != null else {})
	var ground_ids := {}
	var bench_ids := {}
	for p in squad.ground:
		ground_ids[str(p["id"])] = true
	for p in squad.bench:
		bench_ids[str(p["id"])] = true
	var rows: Array = []
	var total := 0
	for p in list:
		var id := str(p["id"])
		var on_ground := ground_ids.has(id)
		var on_bench := bench_ids.has(id)
		var stats: Dictionary = stats_all.get(id, {})
		var gain := _xp_amount(stats, on_ground, on_bench)
		if club == my_club:
			gain = int(round(float(gain) * float(difficulty_rules()["xp_mult"])))
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


# ---------------------------------------------------------------------------
# Rival clubs train too
# ---------------------------------------------------------------------------
## What each position's coaches spend XP on, by weight. Each point goes to
## the best weight per XP, so spending spreads as the cheap stats climb.
const AI_TRAIN_FOCUS := {
	"MID": {"disposal": 3.0, "contested": 3.0, "pressure": 2.0, "carry": 2.0,
			"star": 2.0, "goalkicking": 1.0, "accuracy": 1.0, "creating": 1.0,
			"discipline": 1.0},
	"DEF": {"intercept": 3.0, "marking": 3.0, "pressure": 3.0, "disposal": 2.0,
			"contested": 1.0, "discipline": 1.0, "carry": 1.0},
	"FWD": {"goalkicking": 3.0, "accuracy": 3.0, "marking": 3.0, "creating": 2.0,
			"pressure": 1.0, "disposal": 1.0, "contested": 1.0},
	"RUCK": {"ruck": 4.0, "contested": 2.0, "marking": 2.0, "disposal": 1.0,
			"intercept": 1.0},
}


# ---------------------------------------------------------------------------
# Training plans: your players spend their own XP after every game
# ---------------------------------------------------------------------------
## [key, label, description]. "position" uses AI_TRAIN_FOCUS for the player's
## role; "focus_<stat>" puts everything into one stat; "manual" banks XP.
const TRAIN_PLANS := [
	["position", "Position plan", "Trains what his position needs - the same priorities rival clubs use."],
	["inside_mid", "Inside midfielder", "Contested ball, disposal and pressure: win it at the coalface."],
	["outside_mid", "Outside runner", "Carry and disposal: move it through the corridor."],
	["key_def", "Key defender", "Intercept and marking, with pressure and discipline."],
	["rebound_def", "Rebounding defender", "Disposal, carry and intercept: win it back and launch."],
	["key_fwd", "Key forward", "Goalkicking, marking and accuracy: the target inside 50."],
	["small_fwd", "Small forward", "Pressure, goalkicking, accuracy and creating."],
	["ruck", "Ruck", "Ruck work first, then contested ball and marking."],
	["star", "Star power", "Build a match-winner: star power, with disposal."],
	["manual", "Manual", "No automatic spending. His XP banks until you spend it."],
]
const PLAN_WEIGHTS := {
	"inside_mid": {"contested": 3.0, "disposal": 2.0, "pressure": 2.0, "star": 1.0},
	"outside_mid": {"carry": 3.0, "disposal": 3.0, "creating": 1.0, "star": 1.0},
	"key_def": {"intercept": 3.0, "marking": 3.0, "pressure": 1.0, "discipline": 1.0},
	"rebound_def": {"disposal": 3.0, "carry": 2.0, "intercept": 2.0},
	"key_fwd": {"goalkicking": 3.0, "marking": 3.0, "accuracy": 2.0},
	"small_fwd": {"pressure": 3.0, "goalkicking": 2.0, "accuracy": 2.0, "creating": 1.0},
	"ruck": {"ruck": 4.0, "contested": 2.0, "marking": 1.0},
	"star": {"star": 3.0, "disposal": 1.0},
}
## The plan for anyone without his own. New careers start on Position plan.
var default_train_plan := "position"


## "Training plans bought 23 stat points across 17 players." for the last
## game, or "" when nothing was bought.
func training_summary_line() -> String:
	var auto: Dictionary = last_training_report.get("auto", {})
	if int(auto.get("points", 0)) <= 0:
		return ""
	return "Training plans bought %d stat points across %d players." % [
			int(auto["points"]), int(auto["players"])]


# ---------------------------------------------------------------------------
# Injuries
# ---------------------------------------------------------------------------
## Everything that follows a round: injuries, the awards tally, and - when
## the Grand Final has just been played - the season's awards.
func _after_round(results: Array) -> void:
	_process_injuries(results)
	for res in results:
		Awards.tally_match(season_tally, res, not res.has("tag"))
	_round_news(results)
	_board_after_round(results)
	if season != null and season.is_season_over() \
			and int(season_awards.get("year", 0)) != season_year:
		_close_season_awards()
	_next_week_event()


func _close_season_awards() -> void:
	var players := {}
	for code in season.lists:
		for p in season.lists[code]:
			players[str(p["id"])] = p
	open_offseason()
	season_awards = Awards.season_awards(season_tally, players, season_year)
	records = Awards.update_records(records, season_awards, season_log)
	var mine_bf: Array = (season_awards["best_and_fairest"] as Dictionary).get(my_club, [])
	honour_roll.append({
		"year": season_year,
		"premier": premier(),
		"runner_up": str(season.finals.get("runner_up", "")),
		"brownlow": (season_awards["brownlow"] as Array).slice(0, 1),
		"coleman": (season_awards["coleman"] as Array).slice(0, 1),
		"rising_star": (season_awards["rising_star"] as Array).slice(0, 1),
		"my_bf": mine_bf.slice(0, 1),
		"my_club": my_club,
		"my_position": my_position(),
	})
	# The board's verdict first, so the premiers top the news feed.
	_board_season_end()
	_season_news()


## A readable player name for an awards row, even for a retired player.
func award_name(row: Dictionary) -> String:
	var id := str(row.get("id", ""))
	for code in season.lists if season != null else {}:
		for p in season.lists[code]:
			if str(p["id"]) == id:
				return GameDB.player_display_name(p)
	return GameDB.player_display_name_by_id(id, id)


## Live Coleman leaders: [{id, club, goals}] for the home-and-away season.
func coleman_leaders(n := 5) -> Array:
	var rows := []
	for id in season_tally:
		rows.append({"id": str(id), "club": str(season_tally[id]["club"]),
				"goals": int(season_tally[id]["goals_ha"])})
	rows.sort_custom(func(a, b): return int(a["goals"]) > int(b["goals"]))
	return rows.slice(0, n)


## After a round: every club that played is a week closer to getting its
## injured back, then this round's new injuries are rolled.
func _process_injuries(results: Array) -> void:
	if season == null:
		return
	last_injuries = []
	for res in results:
		for side in ["home", "away"]:
			var code := str(res.get(side, ""))
			if season.lists.has(code):
				Injuries.tick(season.lists[code])
	for res in results:
		last_injuries += Injuries.roll_match(res, season.lists, season.seed,
				int(res.get("round", season.round_index)))


## Your club's new injuries from the last round, as readable lines.
func my_new_injuries() -> Array:
	var out := []
	for inj in last_injuries:
		if str(inj.get("club", "")) != my_club:
			continue
		var p := list_player(str(inj["id"]))
		if p.is_empty():
			continue
		out.append("%s (%s, %s)" % [GameDB.player_display_name(p), str(inj["kind"]),
				_weeks_text(int(inj["weeks"]))])
	return out


func _weeks_text(w: int) -> String:
	return "1 week" if w == 1 else "%d weeks" % w


# ---------------------------------------------------------------------------
# Contracts, free agency and trades
# ---------------------------------------------------------------------------
## Everyone on a list has a contract, and there is a cap. Old saves and the
## test fallback (no career draft) get them here: the cap is then the
## biggest payroll in the league, so every club starts under it.
func ensure_contracts() -> void:
	if season == null:
		return
	var biggest := 0
	for code in season.lists:
		Contracts.assign_initial(season.lists[code])
		biggest = maxi(biggest, Contracts.payroll(season.lists[code]))
	if salary_cap <= 0:
		salary_cap = biggest


func my_payroll() -> int:
	return Contracts.payroll(my_list)


func cap_room() -> int:
	return salary_cap - my_payroll()


## True while trades, re-signings and free agency are open: the season is
## over and the national draft has not started.
func offseason_open() -> bool:
	return season != null and (season.is_season_over() or season.is_regular_done()) \
			and not (draft != null and draft.intake_mode) and offseason_year == season_year


## Season over: rivals decide on their expiring players at once - keep who
## is worth his new price, let the rest go to free agency. Yours wait for you.
func open_offseason() -> void:
	if season == null or offseason_year == season_year:
		return
	ensure_contracts()
	offseason_year = season_year
	offseason_log = []
	free_agents = []
	for code in season.lists:
		if code == my_club:
			continue
		var list: Array = season.lists[code]
		for p in Contracts.expiring(list).duplicate():
			if Contracts.ai_keeps(p, list, salary_cap) or list.size() <= Contracts.MIN_LIST:
				_resign(p, _ai_years(p))
			else:
				_release(code, p)
	mark_dirty()


func _ai_years(p: Dictionary) -> int:
	var age := float(p.get("age", 25.0))
	return 3 if age <= 25.0 else (2 if age <= 30.0 else 1)


## Re-sign for `years` more seasons at today's price. The contract ticks at
## the rollover, so it is stored as years + 1.
func _resign(p: Dictionary, years: int) -> void:
	p["salary"] = Contracts.asking_salary(p)
	p["contract_years"] = years + 1
	p["resigned"] = true


func _release(code: String, p: Dictionary) -> void:
	(season.lists[code] as Array).erase(p)
	p["released_by"] = code
	p["contract_years"] = 0
	free_agents.append(p)
	offseason_log.append({"kind": "released", "club": code, "id": str(p["id"])})
	if int(p.get("overall", 0)) >= NEWS_MIN_OVR:
		add_news("contract", "%s let %s (OVR %d) go to free agency." % [
				GameDB.club_name(code), GameDB.player_display_name(p), int(p["overall"])])


## Your expiring player: re-sign him for 1-4 seasons. Returns a result
## {"ok", "reason"}.
func resign_player(player_id: String, years: int) -> Dictionary:
	var p := list_player(player_id)
	if p.is_empty() or not offseason_open():
		return {"ok": false, "reason": "Contracts can only be settled in the off-season."}
	var cost := Contracts.asking_salary(p)
	if my_payroll() - int(p.get("salary", 0)) + cost > salary_cap:
		return {"ok": false, "reason": "Not enough cap room: he wants %d." % cost}
	_resign(p, clampi(years, 1, Contracts.MAX_YEARS))
	mark_dirty()
	return {"ok": true, "reason": "Re-signed for %d seasons at %d." % [years, cost]}


func release_player(player_id: String) -> Dictionary:
	var p := list_player(player_id)
	if p.is_empty() or not offseason_open():
		return {"ok": false, "reason": "Players can only be released in the off-season."}
	if my_list.size() <= Contracts.MIN_LIST:
		return {"ok": false, "reason": "Your list cannot go below %d." % Contracts.MIN_LIST}
	_release(my_club, p)
	mark_dirty()
	return {"ok": true, "reason": "%s released." % GameDB.player_display_name(p)}


func sign_free_agent(player_id: String, years: int) -> Dictionary:
	if not offseason_open():
		return {"ok": false, "reason": "Free agency is only open in the off-season."}
	var p := {}
	for q in free_agents:
		if str(q["id"]) == player_id:
			p = q
	if p.is_empty():
		return {"ok": false, "reason": "He has already signed elsewhere."}
	if my_list.size() >= Contracts.MAX_LIST:
		return {"ok": false, "reason": "Your list is full (%d)." % Contracts.MAX_LIST}
	var cost := Contracts.asking_salary(p)
	if cost > cap_room():
		return {"ok": false, "reason": "Not enough cap room: he wants %d." % cost}
	_join(my_club, p)
	_resign(p, clampi(years, 1, Contracts.MAX_YEARS))
	free_agents.erase(p)
	offseason_log.append({"kind": "signed", "club": my_club, "id": player_id})
	add_news("contract", "%s sign free agent %s (OVR %d)." % [GameDB.club_name(my_club),
			GameDB.player_display_name(p), int(p["overall"])])
	mark_dirty()
	return {"ok": true, "reason": "%s signed for %d seasons." % [GameDB.player_display_name(p), years]}


func _join(code: String, p: Dictionary) -> void:
	var list: Array = season.lists[code]
	p["club"] = code
	p["num"] = _next_jumper_number(list)
	p.erase("train_plan")
	p.erase("released_by")
	list.append(p)


## Would `club` accept your `mine` (ids) for its `theirs` (ids)?
func evaluate_trade(club: String, mine: Array, theirs: Array) -> Dictionary:
	if not offseason_open():
		return {"ok": false, "reason": "Trades are only open in the off-season."}
	var give := []
	for id in theirs:
		for p in season.lists.get(club, []):
			if str(p["id"]) == str(id):
				give.append(p)
	var take := []
	for id in mine:
		var p := list_player(str(id))
		if not p.is_empty():
			take.append(p)
	return Contracts.evaluate_trade(season.lists.get(club, []), give, take,
			salary_cap, my_list, salary_cap, float(difficulty_rules()["trade_margin"]))


func make_trade(club: String, mine: Array, theirs: Array) -> Dictionary:
	var verdict := evaluate_trade(club, mine, theirs)
	if not bool(verdict["ok"]):
		return verdict
	var incoming := []
	for id in theirs:
		for p in (season.lists[club] as Array).duplicate():
			if str(p["id"]) == str(id):
				(season.lists[club] as Array).erase(p)
				incoming.append(p)
	var outgoing := []
	for id in mine:
		var p := list_player(str(id))
		my_list.erase(p)
		outgoing.append(p)
	for p in incoming:
		_join(my_club, p)
	for p in outgoing:
		_join(club, p)
	for sel_key in ["RUCK", "MID", "DEF", "FWD", "BENCH", "OUT"]:
		var sel := my_selection()
		if sel.has(sel_key):
			for p in outgoing:
				(sel[sel_key] as Array).erase(str(p["id"]))
	offseason_log.append({"kind": "trade", "club": club, "in": theirs.duplicate(), "out": mine.duplicate()})
	add_news("trade", "Trade: %s get %s from %s for %s." % [GameDB.club_name(my_club),
			_names(incoming), GameDB.club_name(club), _names(outgoing)])
	mark_dirty()
	return {"ok": true, "reason": "Trade done."}


## At the rollover: your undecided expiring players are re-signed for two
## seasons if the cap allows (released otherwise), rivals fill their lists
## from free agency, the rest of the free agents leave, and every contract
## ticks down a season.
func _close_contracts() -> void:
	if season == null:
		return
	open_offseason()
	for p in Contracts.expiring(my_list).duplicate():
		if bool(p.get("resigned", false)):
			continue
		var cost := Contracts.asking_salary(p)
		if my_payroll() - int(p.get("salary", 0)) + cost <= salary_cap or my_list.size() <= Contracts.MIN_LIST:
			_resign(p, 2)
		else:
			_release(my_club, p)
	free_agents.sort_custom(func(a, b): return Contracts.worth(a) > Contracts.worth(b))
	for code in season.lists:
		if code == my_club:
			continue
		var list: Array = season.lists[code]
		for p in free_agents.duplicate():
			if list.size() >= 38:
				break
			if Contracts.asking_salary(p) <= salary_cap - Contracts.payroll(list):
				_join(code, p)
				_resign(p, 1)
				free_agents.erase(p)
				offseason_log.append({"kind": "signed", "club": code, "id": str(p["id"])})
				if int(p.get("overall", 0)) >= NEWS_MIN_OVR:
					add_news("contract", "%s sign free agent %s (OVR %d)." % [
							GameDB.club_name(code), GameDB.player_display_name(p), int(p["overall"])])
	free_agents = []
	for code in season.lists:
		for p in season.lists[code]:
			p["contract_years"] = maxi(1, int(p.get("contract_years", 1)) - 1)
			p.erase("resigned")


# ---------------------------------------------------------------------------
# Team selection
# ---------------------------------------------------------------------------
## Your chosen side, or {} when the best 22 are picked automatically.
func my_selection() -> Dictionary:
	if season == null:
		return {}
	return season.selections.get(my_club, {})


## Set your side ({} = auto-pick every week). Stored on the season, so it is
## saved with the career and used by every one of your matches.
func set_selection(selection: Dictionary) -> void:
	if season == null:
		return
	if selection.is_empty():
		season.selections.erase(my_club)
	else:
		season.selections[my_club] = selection.duplicate(true)
	mark_dirty()


## The side that would take the field this week, as a selection.
func current_side() -> Dictionary:
	var squad := my_squad()
	var out := {"RUCK": [], "MID": [], "DEF": [], "FWD": [], "BENCH": []}
	for p in squad.ground:
		(out[str(p["role"])] as Array).append(str(p["id"]))
	for p in squad.bench:
		(out["BENCH"] as Array).append(str(p["id"]))
	return out


func my_squad() -> Squad:
	return Squad.new(GameDB.club_name(my_club), my_list, true, my_club, my_selection())


## Every plan a player can follow, including single-stat focuses:
## [[key, label], ...]
func train_plan_options() -> Array:
	var out := []
	for row in TRAIN_PLANS:
		out.append([str(row[0]), str(row[1])])
	for row in TRAIN_STATS:
		out.append(["focus_" + str(row[0]), "Focus: " + str(row[1])])
	return out


func train_plan_label(key: String) -> String:
	for row in train_plan_options():
		if str(row[0]) == key:
			return str(row[1])
	return "Position plan"


func train_plan_description(key: String) -> String:
	for row in TRAIN_PLANS:
		if str(row[0]) == key:
			return str(row[2])
	if key.begins_with("focus_"):
		return "Every point goes into %s." % train_stat_label(key.substr(6))
	return ""


## The plan a player actually follows: his own, or the club plan.
func plan_for(p: Dictionary) -> String:
	var own := str(p.get("train_plan", ""))
	return own if own != "" else default_train_plan


## Give one player his own plan ("" = follow the club plan). Banked XP is
## spent under the new plan straight away.
func set_player_plan(player_id: String, key: String) -> Dictionary:
	var p := list_player(player_id)
	if p.is_empty():
		return {}
	if key == "":
		p.erase("train_plan")
	else:
		p["train_plan"] = key
	mark_dirty()
	return apply_plan_to(p)


## Change the club plan (everyone without his own follows it), then spend.
func set_default_plan(key: String) -> Dictionary:
	default_train_plan = key
	mark_dirty()
	return apply_train_plans()


## Spend every list player's XP under his plan. Returns
## {"points": n, "players": m, "by_player": {id: {stat: points}}}.
func apply_train_plans() -> Dictionary:
	var out := {"points": 0, "players": 0, "by_player": {}}
	for p in my_list:
		var gains := apply_plan_to(p)
		if gains.is_empty():
			continue
		var pts := 0
		for k in gains:
			pts += int(gains[k])
		out["points"] = int(out["points"]) + pts
		out["players"] = int(out["players"]) + 1
		out["by_player"][str(p["id"])] = gains
	return out


## Spend one player's XP under his plan. Returns {stat: points bought}.
func apply_plan_to(p: Dictionary) -> Dictionary:
	var key := plan_for(p)
	if key == "manual":
		return {}
	var weights: Dictionary
	if key.begins_with("focus_"):
		weights = {key.substr(6): 1.0}
	elif PLAN_WEIGHTS.has(key):
		weights = PLAN_WEIGHTS[key]
	else:
		weights = AI_TRAIN_FOCUS.get(str(p.get("role", "MID")), AI_TRAIN_FOCUS["MID"])
	var gains := _spend_with_weights(p, weights, false)
	if not gains.is_empty():
		mark_dirty()
	return gains


## Buy stat points while XP lasts, each one going to the best weight per XP.
## Rivals stop at potential; your plans keep going (past POT at the premium).
func _spend_with_weights(p: Dictionary, weights: Dictionary, stop_at_pot: bool,
		ceiling := -1) -> Dictionary:
	var gains := {}
	var games := float(p.get("gm", 18.0))
	var attr: Dictionary = p.get("attr", {})
	var stop_at := ceiling if ceiling >= 0 else int(p.get("potential", 0))
	while true:
		if stop_at_pot and int(p.get("overall", 0)) >= stop_at:
			break
		var best_key := ""
		var best_ratio := 0.0
		var best_cost := 0
		var mult := Potential.training_multiplier(p)
		for key in weights:
			if not attr.has(key):
				continue
			var cur := int(attr[key])
			if cur >= 99:
				continue
			var cost := _cost_for(cur, games, mult)
			var ratio := float(weights[key]) / float(cost)
			if ratio > best_ratio:
				best_ratio = ratio
				best_key = key
				best_cost = cost
		if best_key == "" or int(p.get("xp", 0)) < best_cost:
			break
		p["xp"] = int(p["xp"]) - best_cost
		attr[best_key] = int(attr[best_key]) + 1
		gains[best_key] = int(gains.get(best_key, 0)) + 1
		_recalc_player_overall(p)
	return gains


## After a round: every rival club's players are paid for the game and their
## coaches spend it. Rivals only train a player up to his potential (you can
## go past it, at a premium), which keeps the league from inflating.
func _train_rivals(results: Array) -> void:
	if season == null:
		return
	var best := {}
	for res in results:
		for side in ["home", "away"]:
			var code := str(res.get(side, ""))
			if code == "" or code == my_club or not season.lists.has(code):
				continue
			var list: Array = season.lists[code]
			_grant_xp(code, list, res)
			for p in list:
				ai_spend_xp(p)
				best = _development_pick(code, p, best)
	# One development story a round: the best player to reach his season's
	# ceiling. Every rival doing so would drown the feed.
	if not best.is_empty():
		var bp: Dictionary = best["p"]
		bp["news_year"] = season_year
		var start := int(bp["season_start_ov"])
		add_news("development", "%s (%s) has lifted to OVR %d, up %d this season." % [
				GameDB.player_display_name(bp), GameDB.club_name(str(best["code"])),
				int(bp["overall"]), int(bp["overall"]) - start])


## A rival player improves at most this much through training in a season
## (and never past his potential). Real players do not jump five points
## mid-season, and an uncapped league would climb every year only to be
## re-anchored at every rollover.
const AI_SEASON_GAIN := 2


## Spend a rival player's XP. Returns the attribute points bought.
func ai_spend_xp(p: Dictionary) -> int:
	if not p.has("season_start_ov"):
		p["season_start_ov"] = int(p.get("overall", 0))
	var ceiling := mini(int(p.get("potential", 0)), int(p["season_start_ov"]) + rival_season_gain())
	if int(p.get("overall", 0)) >= ceiling:
		return 0
	var focus: Dictionary = AI_TRAIN_FOCUS.get(str(p.get("role", "MID")), AI_TRAIN_FOCUS["MID"])
	var bought := 0
	for n in _spend_with_weights(p, focus, true, ceiling).values():
		bought += int(n)
	return bought


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
	return _cost_for(cur, float(p.get("gm", 18.0)), Potential.training_multiplier(p))


## Potential scales the price: up to half off while a player sits well below
## his POT (rehabbing a star, bringing on a top pick), 50% dearer past it.
func _cost_for(cur: int, games: float, pot_mult := 1.0) -> int:
	var exp_mult := clampf(0.70 + games / 40.0, 0.70, 1.20)
	return maxi(int(round(8.0 * pot_mult)),
			int(round((8.0 + float(cur) * 0.40) * exp_mult * pot_mult)))


func affordable_points(player_id: String, attr_key: String, cap := 5) -> int:
	var p := list_player(player_id)
	if p.is_empty():
		return 0
	var xp := int(p.get("xp", 0))
	var cur := int((p["attr"] as Dictionary).get(attr_key, 1))
	var games := float(p.get("gm", 18.0))
	var pot_mult := Potential.training_multiplier(p)
	var n := 0
	while n < cap and cur < 99:
		var cost := _cost_for(cur, games, pot_mult)
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
	mark_dirty()
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


# ---------------------------------------------------------------------------
# Difficulty
# ---------------------------------------------------------------------------
## rival_gain: the most a rival player improves through training in a season.
## trade_margin: how much better off a rival must be to accept a trade.
## xp_mult: your players' match XP.
const DIFFICULTIES := {
	"easy": {"label": "Easy", "rival_gain": 1, "trade_margin": 0.0, "xp_mult": 1.25,
			"text": "Rivals improve slowly, clubs trade at fair value and your players earn 25% more XP."},
	"normal": {"label": "Normal", "rival_gain": AI_SEASON_GAIN, "trade_margin": Contracts.TRADE_MARGIN,
			"xp_mult": 1.0, "text": "The league as tuned: rivals train up to 2 rating points a season."},
	"hard": {"label": "Hard", "rival_gain": 4, "trade_margin": 0.12, "xp_mult": 0.85,
			"text": "Rivals develop twice as fast, drive hard bargains, and your players earn 15% less XP."},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard"]


func difficulty_rules() -> Dictionary:
	return DIFFICULTIES.get(difficulty, DIFFICULTIES["normal"])


func rival_season_gain() -> int:
	return int(difficulty_rules()["rival_gain"])


## The difficulty the next New Career starts on (a menu setting).
func new_career_difficulty() -> String:
	var d := str(get_setting("difficulty", "normal"))
	return d if DIFFICULTIES.has(d) else "normal"


func set_new_career_difficulty(key: String) -> void:
	if not DIFFICULTIES.has(key):
		return
	set_setting("difficulty", key)
	# Before the season starts the choice still applies to this career.
	if season == null:
		difficulty = key


# ---------------------------------------------------------------------------
# League news
# ---------------------------------------------------------------------------
const MAX_NEWS := 120
## Rival releases, signings and development only make the news from here up.
const NEWS_MIN_OVR := 72


func add_news(kind: String, text: String) -> void:
	var when := "Off-season" if offseason_year == season_year or season == null else last_label
	news.push_front({"year": season_year, "when": when, "kind": kind, "text": text})
	if news.size() > MAX_NEWS:
		news.resize(MAX_NEWS)


## Big games and long injuries to good players from the round just played.
func _round_news(results: Array) -> void:
	for res in results:
		var roster: Array = res.get("roster", [])
		var stats_all: Dictionary = res.get("players", {})
		for side in range(mini(2, roster.size())):
			var code := str(res["home"] if side == 0 else res["away"])
			var opp := str(res["away"] if side == 0 else res["home"])
			for r in roster[side]:
				var st: Dictionary = stats_all.get(str(r["id"]), {})
				if int(st.get("goals", 0)) < 6 and int(st.get("disposals", 0)) < 40:
					continue
				var p := _find_player(str(r["id"]))
				if p.is_empty():
					continue
				if int(st.get("goals", 0)) >= 6:
					add_news("game", "%s kicked %d goals for %s against %s." % [
							GameDB.player_display_name(p), int(st["goals"]),
							GameDB.club_name(code), GameDB.club_name(opp)])
				elif int(st.get("disposals", 0)) >= 40:
					add_news("game", "%s had %d disposals for %s against %s." % [
							GameDB.player_display_name(p), int(st["disposals"]),
							GameDB.club_name(code), GameDB.club_name(opp)])
	for inj in last_injuries:
		var p := _find_player(str(inj.get("id", "")))
		if p.is_empty() or int(inj.get("weeks", 0)) < 4 or int(p.get("overall", 0)) < NEWS_MIN_OVR:
			continue
		add_news("injury", "%s (%s) is out for %s with a %s." % [GameDB.player_display_name(p),
				GameDB.club_name(str(inj.get("club", ""))), _weeks_text(int(inj["weeks"])),
				str(inj.get("kind", "injury")).to_lower()])


## A rival who has trained as far as he can this season is a news candidate
## (once a season). Returns the better of him and `best`.
func _development_pick(code: String, p: Dictionary, best: Dictionary) -> Dictionary:
	var start := int(p.get("season_start_ov", p.get("overall", 0)))
	var ov := int(p.get("overall", 0))
	if ov < NEWS_MIN_OVR or ov - start < mini(2, rival_season_gain()) \
			or int(p.get("news_year", 0)) == season_year:
		return best
	if not best.is_empty() and int((best["p"] as Dictionary)["overall"]) >= ov:
		return best
	return {"code": code, "p": p}


func _season_news() -> void:
	var top: Array = season_awards.get("brownlow", [])
	if not top.is_empty():
		add_news("award", "%s (%s) won the Brownlow Medal with %d votes." % [
				award_name(top[0]), GameDB.club_name(str(top[0]["club"])), int(top[0]["votes"])])
	var gk: Array = season_awards.get("coleman", [])
	if not gk.is_empty():
		add_news("award", "%s (%s) won the Coleman Medal with %d goals." % [
				award_name(gk[0]), GameDB.club_name(str(gk[0]["club"])), int(gk[0]["goals"])])
	if premier() != "":
		add_news("premiers", "%s are the %d premiers." % [GameDB.club_name(premier()), season_year])


func _find_player(id: String) -> Dictionary:
	if season == null:
		return {}
	for code in season.lists:
		for p in season.lists[code]:
			if str(p["id"]) == id:
				return p
	return {}


func _names(players: Array) -> String:
	var out: PackedStringArray = []
	for p in players:
		out.append(GameDB.player_display_name(p))
	return ", ".join(out)



# ---------------------------------------------------------------------------
# The board, morale and the weekly event card (rules in ClubLife)
# ---------------------------------------------------------------------------
## A new season: the board sets its goal from where your list ranks.
func _open_board_season() -> void:
	if season == null or my_club == "":
		return
	var ranks := []
	for code in season.lists:
		ranks.append([str(code), Squad.new(str(code), season.lists[code], true, str(code)).strength()])
	ranks.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var rank := 1
	for i in range(ranks.size()):
		if str(ranks[i][0]) == my_club:
			rank = i + 1
	if board.is_empty():
		board = {"confidence": ClubLife.START_CONFIDENCE, "warned": false, "sacked": false, "history": []}
	board["goal"] = ClubLife.board_goal(rank)
	board["rank"] = rank
	board["year"] = season_year
	board.erase("promise")
	losing_streak = 0
	_next_week_event()


func board_confidence() -> int:
	return int(board.get("confidence", ClubLife.START_CONFIDENCE))


func board_goal_text() -> String:
	return str((board.get("goal", {}) as Dictionary).get("text", ""))


func is_sacked() -> bool:
	return bool(board.get("sacked", false))


func _my_result(results: Array) -> Dictionary:
	for res in results:
		if str(res.get("home", "")) == my_club or str(res.get("away", "")) == my_club:
			return res
	return {}


func _board_after_round(results: Array) -> void:
	var res := _my_result(results)
	# This week's one-off flags (rested, sore, heavy legs) end with the round.
	for p in my_list:
		p.erase("rested")
		p.erase("sore")
		p.erase("heavy_legs")
	if res.is_empty() or board.is_empty():
		return
	var side := 0 if str(res["home"]) == my_club else 1
	var margin := int(res["score"][side]) - int(res["score"][1 - side])
	var conf := ClubLife.after_match(board_confidence(), margin)
	if bool(board.get("promise", false)):
		conf = clampi(conf + (8 if margin > 0 else -10), 0, 100)
		board.erase("promise")
	board["confidence"] = conf
	losing_streak = losing_streak + 1 if margin < 0 else 0
	var played := {}
	var roster: Array = res.get("roster", [[], []])
	if roster.size() > side:
		for r in roster[side]:
			played[str(r["id"])] = true
	ClubLife.morale_after_match(my_list, played, margin > 0)


## Season over: did you meet the goal? Miss it badly twice and you are gone.
func _board_season_end() -> void:
	if board.is_empty():
		return
	var row := my_ladder_row()
	var goal: Dictionary = board.get("goal", {})
	var met := ClubLife.goal_met(goal, my_position(), int(row.get("w", 0)))
	var conf := ClubLife.after_season(board_confidence(), met, premier() == my_club)
	var verdict := "The board is delighted." if met else "The board is disappointed."
	if conf < ClubLife.WARN_LINE:
		if bool(board.get("warned", false)):
			board["sacked"] = true
			verdict = "The board has sacked you."
		else:
			board["warned"] = true
			conf = maxi(conf, 35)
			verdict = "Final warning: miss again next year and you are gone."
	elif met:
		board["warned"] = false
	board["confidence"] = conf
	(board["history"] as Array).append({"year": season_year, "goal": str(goal.get("text", "")),
			"met": met, "position": my_position(), "confidence": conf, "verdict": verdict})
	board["verdict"] = verdict
	add_news("board", "%s board: %s (%s)" % [GameDB.club_name(my_club), verdict,
			"goal met" if met else "goal missed: " + str(goal.get("text", ""))])


func _next_week_event() -> void:
	week_event = {}
	if season == null or season.is_regular_done() or is_sacked():
		return
	var selected := {}
	var side := current_side()
	for k in side:
		for id in side[k]:
			selected[str(id)] = true
	week_event = ClubLife.pick_event({"list": my_list, "round": season.round_index + 1,
			"seed": season.seed, "losses": losing_streak, "selected": selected})


func week_event_pending() -> bool:
	return not week_event.is_empty() and not bool(week_event.get("resolved", false))


## Before a round is played, an unanswered event takes its default.
func _settle_week_event() -> void:
	if week_event_pending():
		resolve_week_event(int(week_event.get("default", 0)))


## Apply the chosen option. Returns what happened.
func resolve_week_event(choice: int) -> String:
	if not week_event_pending():
		return ""
	var options: Array = week_event.get("options", [])
	choice = clampi(choice, 0, options.size() - 1)
	var key := str((options[choice] as Dictionary).get("key", ""))
	var p := list_player(str(week_event.get("player_id", "")))
	var name := GameDB.player_display_name(p) if not p.is_empty() else ""
	var out := ""
	match key:
		"rest":
			p["rested"] = true
			ClubLife.add_morale(p, -3)
			out = "%s is rested this week." % name
		"play":
			p["sore"] = true
			out = "%s plays - fingers crossed." % name
		"heavy":
			for q in my_list:
				q["xp"] = int(q.get("xp", 0)) + 12
				q["heavy_legs"] = true
			apply_train_plans()
			out = "A heavy week: +12 XP each, heavy legs on game day."
		"recover":
			for q in my_list:
				ClubLife.add_morale(q, 4)
			out = "A recovery week: the group is fresher in the head."
		"open":
			for q in my_list:
				ClubLife.add_morale(q, 3)
			board["confidence"] = clampi(board_confidence() + 2, 0, 100)
			out = "The members loved it."
		"closed":
			for q in my_list:
				q["xp"] = int(q.get("xp", 0)) + 6
			apply_train_plans()
			out = "A closed session: +6 XP each."
		"suspend":
			p["rested"] = true
			ClubLife.add_morale(p, -10)
			board["confidence"] = clampi(board_confidence() + 4, 0, 100)
			out = "%s is suspended for a week. The board approves." % name
		"back":
			ClubLife.add_morale(p, 8)
			board["confidence"] = clampi(board_confidence() - 4, 0, 100)
			out = "You back %s. The board is not impressed." % name
		"extend":
			var cost := ceili(Contracts.asking_salary(p) * 1.1)
			if my_payroll() - int(p.get("salary", 0)) + cost <= salary_cap:
				p["salary"] = cost
				p["contract_years"] = 3
				ClubLife.add_morale(p, 10)
				out = "%s signs on for two more seasons at %d." % [name, cost]
			else:
				ClubLife.add_morale(p, -8)
				out = "No cap room to extend %s now - he is disappointed." % name
		"pressure", "promise":
			board["promise"] = true
			out = "You promise a win this week."
		"patience":
			board["confidence"] = clampi(board_confidence() - 3, 0, 100)
			out = "The board grudgingly agrees to wait."
		"develop":
			p["xp"] = int(p.get("xp", 0)) + 40
			ClubLife.add_morale(p, 5)
			apply_plan_to(p)
			out = "%s gets extra development: +40 XP." % name
		"talk":
			ClubLife.add_morale(p, 15)
			out = "%s feels heard." % name
		"earn":
			ClubLife.add_morale(p, -5)
			out = "%s is told to earn his spot." % name
		_:
			if not p.is_empty() and key == "wait":
				ClubLife.add_morale(p, -8 if str(week_event.get("key", "")) == "extension" else -10)
				out = "%s is disappointed." % name
			else:
				out = "Business as usual."
	week_event["resolved"] = true
	week_event["choice"] = choice
	week_event["outcome"] = out
	mark_dirty()
	return out
