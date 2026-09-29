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
var last_pos_before := 0          # your ladder spot before that round
## Set by the hub before opening the match screen to review last_match: the
## screen goes straight to full time and plays or applies nothing.
var review_requested := false
var last_phase := ""             # "regular" | "finals" | "done"
var last_label := ""             # "Round 7" / "Grand Final" / ...
var season_log: Array = []       # every result, for the season review screen
var last_injuries: Array = []    # the last round's new injuries, every club
var season_tally := {}           # player id -> running season numbers (Awards)
var club_plan := "balanced"      # your standing game plan, from the first bounce
var form_log := {}               # your player id -> his last three Player Ratings
var season_team := {}            # club -> {"games": n, stat: season total}
var season_awards := {}          # the finished season's awards
var honour_roll: Array = []      # one entry per completed season
## Every coach in the game, once: cid -> record (Coaches.gd). A club's staff
## is read from the records, never stored beside them.
var coaches := {}
## Notable coaches who have left the game: cid -> slim record (CoachMarket).
var coach_archive := {}
## Your staff jobs open after the season, waiting for you: [{job, reason}].
## Anything still open is auto-filled when the next season starts.
var staff_vacancies: Array = []
## Every club's place in the preseason pecking order (list strength), for
## judging AI senior coaches at season's end: code -> rank.
var club_expect := {}
var records := {}                # league records across the career
## Club achievements unlocked this career: id -> {"year", "detail"}.
## Definitions live in scripts/sim/Achievements.gd.
var achievements := {}
var salary_cap := 0              # cap points every club's payroll counts against
var free_agents: Array = []      # off-season: players no club kept
var offseason_year := 0          # the season whose off-season has opened
var offseason_log: Array = []    # what happened in the off-season, for news
var news: Array = []             # league news feed, newest first
var difficulty := "normal"       # this career's difficulty (DIFFICULTIES key)
var board := {}                  # confidence, goal, warned, sacked, history
var week_event := {}             # this week's event card (ClubLife.pick_event)
var losing_streak := 0
## What the event cards have already raised this season (ClubLife.pick_event
## memory): "extension|id", "media|id" -> true, "unhappy|id" -> round.
var event_memory := {}

## Career loop: season 1 is the 2026 season. Every completed season ends with
## a national intake draft (keep your list, sign the rookies), then the same
## league rolls into the next year with one season of ageing applied.
var season_year := 2026
## Rolled once per career: decides each generated draft class's quality tier
## (Prospects.class_tier), so a reload never re-rolls a class.
var career_seed := 0
var class_tiers := {}             # draft year (string) -> tier key, as generated
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
## A full senior game: named on the ground with a capped performance. Most
## senior players earn exactly this (the cap is easy to reach), so it is the
## reference the reserves rate is set against.
const XP_SENIOR_GAME := XP_SQUAD + XP_SELECTED + XP_NAMED + XP_PERF_CAP
## Reserves (VFL) development. An available player left out of the senior 22
## plays in the reserves in the background and earns this share of a full
## senior game - no match, stats or selection of its own. Injured and
## rested/suspended players (Ratings.available) only get XP_SQUAD.
const RESERVES_XP_SHARE := 0.5


## XP for a week in the reserves: RESERVES_XP_SHARE of a full senior game
## (19 of 37 at 0.5), before the difficulty multiplier.
static func reserves_xp() -> int:
	return int(round(float(XP_SENIOR_GAME) * RESERVES_XP_SHARE))


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


## Ask before Sim round plays your match without you. On by default.
func confirm_sim_round() -> bool:
	return bool(get_setting("confirm_sim_round", true))


func set_confirm_sim_round(enabled: bool) -> void:
	set_setting("confirm_sim_round", enabled)


## How fast a watched match starts (1x, 2x, 4x or 8x). 4x by default.
func match_speed() -> float:
	var s := float(get_setting("match_speed", 4.0))
	return s if s in [1.0, 2.0, 4.0, 8.0] else 4.0


func set_match_speed(s: float) -> void:
	if s in [1.0, 2.0, 4.0, 8.0]:
		set_setting("match_speed", s)


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
		# Enough of your last match to review it after a reload.
		"last_match": CareerSave.review_result(last_match),
		"last_pos_before": last_pos_before,
		"season_log": CareerSave.slim_results(season_log),
		"last_injuries": last_injuries,
		"season_tally": season_tally,
		"club_plan": club_plan,
		"form_log": form_log,
		"season_team": season_team,
		"season_awards": season_awards,
		"honour_roll": honour_roll,
		"records": records,
		"achievements": achievements,
		"salary_cap": salary_cap,
		"free_agents": free_agents,
		"offseason_year": offseason_year,
		"offseason_log": offseason_log,
		"news": news,
		"difficulty": difficulty,
		"board": board,
		"week_event": week_event,
		"losing_streak": losing_streak,
		"event_memory": event_memory,
		"db_draftees": GameDB.draftees,
		"db_late_draftees": GameDB.late_draftees,
		"db_alias_next": GameDB._alias_next,
		"coaches": coaches,
		"coach_archive": coach_archive,
		"staff_vacancies": staff_vacancies,
		"club_expect": club_expect,
		"career_seed": career_seed,
		"class_tiers": class_tiers,
		# Players carry p["career"]; saves without this mark predate it.
		"career_version": CAREER_VERSION,
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
		# Saves written under the old eight-finalist bracket cannot be
		# restored into the wildcard series (different slots, different
		# weeks), so the finals restart from the ladder as it was saved.
		if not season.finals.is_empty() \
				and int((season.finals.get("top", []) as Array).size()) != Season.FINALISTS:
			season.finals = {}
	if state.get("draft") is Dictionary:
		draft = Draft.new([], [], 0)
		CareerSave.apply_vars(draft, state["draft"])
		draft._pick_by_player = {}
		for entry in draft.pick_history:
			if bool(entry.get("released", false)):
				continue   # released to make cap room: back in the pool
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
	last_match = state.get("last_match", {})
	last_pos_before = int(state.get("last_pos_before", 0))
	season_log = state.get("season_log", [])
	last_injuries = state.get("last_injuries", [])
	season_tally = state.get("season_tally", {})
	club_plan = str(state.get("club_plan", "balanced"))
	if not CLUB_PLANS.has(club_plan):
		club_plan = "balanced"
	form_log = state.get("form_log", {})
	season_team = state.get("season_team", {})
	_sync_club_plan()
	season_awards = state.get("season_awards", {})
	honour_roll = state.get("honour_roll", [])
	records = state.get("records", {})
	achievements = state.get("achievements", {})
	salary_cap = int(state.get("salary_cap", 0))
	free_agents = state.get("free_agents", [])
	offseason_year = int(state.get("offseason_year", 0))
	offseason_log = state.get("offseason_log", [])
	news = state.get("news", [])
	board = state.get("board", {})
	week_event = state.get("week_event", {})
	losing_streak = int(state.get("losing_streak", 0))
	event_memory = state.get("event_memory", {})
	difficulty = str(state.get("difficulty", "normal"))
	if not DIFFICULTIES.has(difficulty):
		difficulty = "normal"
	GameDB.draftees = state.get("db_draftees", GameDB.draftees)
	GameDB.late_draftees = state.get("db_late_draftees", [])
	GameDB._alias_next = int(state.get("db_alias_next", GameDB._alias_next))
	# Saves from before class tiers use seed 0: still one fixed roll per year.
	career_seed = int(state.get("career_seed", 0))
	class_tiers = state.get("class_tiers", {})
	_recompute_ratings()
	if int(state.get("career_version", 0)) < CAREER_VERSION:
		_migrate_careers()
	_migrate_train_plans()
	_backfill_potential()
	ensure_contracts()
	if season != null and board.is_empty():
		_open_board_season()
	coaches = state.get("coaches", {})
	coach_archive = state.get("coach_archive", {})
	staff_vacancies = state.get("staff_vacancies", [])
	club_expect = state.get("club_expect", {})
	# A save from before the coaching world: seed it for this career now.
	if season != null and coaches.is_empty():
		coaches = Coaches.seed(my_club)
	return true


## Career records (Career.gd) arrived with save format 1.
const CAREER_VERSION := 1


## A save from before career records: every player gets his dataset career
## (AFL seasons to 2025, or nothing for a generated player), and the seasons
## this save already played are marked unknown - their games and goals were
## never kept, so they are not guessed.
func _migrate_careers() -> void:
	var closed := season != null and (offseason_year == season_year
			or int(season_awards.get("year", 0)) == season_year)
	var last := season_year if closed else season_year - 1
	var played: Array = [my_list, free_agents]
	if season != null:
		for code in season.lists:
			played.append(season.lists[code])
	for code in league_lists:
		played.append(league_lists[code])
	var others: Array = [draftee_pool, GameDB.late_draftees]
	if draft != null:
		others.append(draft.pool)
		for code in draft.club_lists:
			others.append(draft.club_lists[code])
	for pass_i in range(2):
		var group: Array = played if pass_i == 0 else others
		# Only players who could have played were on a list or a free agent;
		# a prospect still in the pool has missed nothing.
		var gap_to := last if pass_i == 0 else Career.BEFORE_GAME
		for arr in group:
			for p in arr:
				if not (p is Dictionary) or (p as Dictionary).has("career"):
					continue
				var orig = GameDB.player_by_id(str(p["id"]))
				var base: Dictionary = {}
				if orig is Dictionary and (orig as Dictionary).get("career") is Dictionary \
						and not is_same(orig, p):
					base = orig["career"]
				Career.migrate(p, base, Career.BEFORE_GAME + 1, gap_to)


## Overall is derived data: rebuild it from the attributes on load, so a
## save written under an older rating formula never keeps stale ratings.
## What is pinned to a player's old overall - his POT and the season-start
## mark for the rival training cap - moves by the same amount, so his
## headroom is kept. With an unchanged formula nothing moves.
func _recompute_ratings() -> void:
	var groups: Array = [my_list, draftee_pool, free_agents, GameDB.late_draftees]
	if season != null:
		for code in season.lists:
			groups.append(season.lists[code])
	for code in league_lists:
		groups.append(league_lists[code])
	if draft != null:
		groups.append(draft.pool)
		for code in draft.club_lists:
			groups.append(draft.club_lists[code])
	for arr in groups:
		for p in arr:
			if not (p is Dictionary) or not (p as Dictionary).has("attr") or not (p as Dictionary).has("role"):
				continue
			var old := int(p.get("overall", 0))
			var ov := Ratings.rate_overall(p["attr"], str(p["role"]), Ratings.effective_games(p))
			if ov == old:
				continue
			p["overall"] = ov
			p["value"] = Ratings.salary_value(ov)
			if p.has("potential"):
				p["potential"] = clampi(int(p["potential"]) + ov - old, ov, Potential.MAX_POT)
			if p.has("season_start_ov"):
				p["season_start_ov"] = int(p["season_start_ov"]) + ov - old


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
	last_pos_before = 0
	review_requested = false
	last_phase = ""
	last_label = ""
	season_log = []
	last_injuries = []
	season_tally = {}
	club_plan = "balanced"
	form_log = {}
	season_team = {}
	season_awards = {}
	honour_roll = []
	records = {}
	achievements = {}
	coaches = {}
	coach_archive = {}
	staff_vacancies = []
	club_expect = {}
	salary_cap = 0
	free_agents = []
	offseason_year = 0
	offseason_log = []
	news = []
	board = {}
	week_event = {}
	losing_streak = 0
	event_memory = {}
	difficulty = new_career_difficulty()
	career_seed = randi_range(1, 999999)
	class_tiers = {}
	last_training_report = {}
	_xp_grant_key = ""
	_dirty = false
	default_train_plan = "position"
	season_year = GameDB.START_YEAR
	drafted_draftees = {}
	intake_assignments = []
	intake_summary = {}
	# The 2026 class was drafted before the career began (it is in the
	# League Draft pool); the first class drafted in the career is 2027's,
	# made exactly as a rollover makes the next year's class.
	draftee_pool = _first_class(season_year)


## The draft class a career starting in `year` drafts at that season's end:
## generated and aged the way _start_next_season prepares next year's.
func _first_class(year: int) -> Array:
	var generated := Prospects.generate_class(year, career_seed)
	class_tiers[str(year)] = Prospects.class_tier(career_seed, year)
	GameDB.register_draftees(generated)
	return Prospects.age_pool(generated, year, {})


func begin_draft() -> void:
	var seed := int(Time.get_unix_time_from_system()) % 1000000
	# The clubs of the first playable season (the founding eighteen in 2027;
	# expansion clubs arrive later with their own lists). The pool is the
	# league 2026 left behind: every listed player plus the 2026 draft class,
	# drafted before the 2027 season.
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	draft = Draft.new(pool, GameDB.active_clubs(season_year).duplicate(), seed)


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
	if draftee_pool.is_empty() and season_year == GameDB.DATA_SEASON:
		# A career begun in 2026 (before 2027 starts) still drafts the real
		# 2026 class at its first season's end.
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
	var role_pairs := {}
	for code in GameDB.CLUB_ORDER:
		var arr: Array = league_lists.get(code, [])
		sizes[code] = arr.size()
		var c := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
		var pairs: Array = []
		for p in arr:
			var r := str(p["role"])
			if c.has(r):
				c[r] = int(c[r]) + 1
			pairs.append([r, str(p.get("role2", ""))])
		role_counts[code] = c
		role_pairs[code] = pairs

	# Only clubs on this season's ladder take intake picks. An expansion club
	# arrives with its own generated list at its first season (see
	# _start_next_season) rather than drafting into one.
	var active := GameDB.active_clubs(season_year)
	var seed := int(Time.get_unix_time_from_system()) % 1000000
	draft = Draft.build_intake(open_pool, active.duplicate(), order,
			seed, sizes, role_counts, role_pairs)
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
			_mark_drafted(p, "national", int(entry.get("pick", 0)))
			Contracts.rookie_deal(p)
			arr.append(p)
			drafted_draftees[id] = code
	draft = null
	_start_next_season(next_year, merged)
	return true


## Roll every list forward one year and rebuild the season. Split out so a
## career can continue even when there is no prospect pool to draft.
func _start_next_season(next_year: int, signed: int) -> void:
	# The new season never starts with one of your staff jobs empty.
	_fill_open_staff()
	# The season's close normally counted careers already (Career skips a
	# season it has seen); this covers a season rolled on without one.
	if season != null:
		var played := {}
		for code in season.lists:
			for p in season.lists[code]:
				played[str(p["id"])] = p
		Career.close_season(played, season_tally, season_year)
	# Next year's generated class joins the pool before ageing, so the fresh
	# 17-year-olds are also a year older in the season they arrive.
	var generated := Prospects.generate_class(next_year, career_seed)
	class_tiers[str(next_year)] = Prospects.class_tier(career_seed, next_year)
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
	form_log = {}
	season_team = {}
	season_awards = {}
	# Everyone listed before ageing: a retiree leaves the lists inside
	# age_league, and his playing career must be captured from him first.
	var listed := {}
	for code in league_lists:
		for p in league_lists[code]:
			listed[str(p["id"])] = p
	intake_summary = Prospects.age_league(league_lists, next_year)
	intake_summary["signed"] = signed
	_retirees_to_coaching(intake_summary.get("retired", []), listed)
	for r in intake_summary.get("retired", []):
		if int(r.get("overall", 0)) >= NEWS_MIN_OVR:
			add_news("retirement", "%s (%s) has retired at %d." % [
					GameDB.player_display_name_by_id(str(r["id"]), str(r["name"])),
					GameDB.club_name(str(r["club"])), int(float(r["age"]))])
	intake_summary["year"] = next_year
	draftee_pool = Prospects.age_pool(draftee_pool, next_year, drafted_draftees)
	# Expansion: any club whose first season is next_year arrives with a
	# generated list (aged across the full range, not just a rookie class),
	# so it ages, drafts, trains and simulates like every other club.
	for code in GameDB.CLUB_ORDER:
		if GameDB.enter_year(code) != next_year:
			continue
		if not (league_lists.get(code, []) as Array).is_empty():
			continue
		league_lists[code] = Prospects.generate_expansion_list(code, next_year)
		add_news("expansion", "%s (the %s) join the competition for %d, their first season." % [
				GameDB.club_name(code), GameDB.club_short(code), next_year])
	intake_summary["renormalised"] = Prospects.renormalise_league(league_lists,
		draftee_pool, GameDB.baseline_overall, GameDB.baseline_spread)

	# One array per club from here on: the season, the league lists and your
	# list are the same arrays, so trades and signings touch them all.
	var lists := {}
	for code in GameDB.CLUB_ORDER:
		lists[code] = league_lists.get(code, [])
		for p in lists[code]:
			p["season_start_ov"] = int(p["overall"])
	my_list = lists.get(my_club, [])
	# The season simulates only this year's active clubs; `lists` keeps an
	# entry for every club so saves and rollovers never miss a key.
	season = Season.new(GameDB.active_clubs(next_year).duplicate(), lists,
			int(Time.get_unix_time_from_system()) % 1000000)
	# Expansion lists are born here, so their contracts must be assigned
	# here too (start_season does the same for the first season).
	ensure_contracts()
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
	_mark_drafted(p, kind, 0)
	Contracts.rookie_deal(p)
	arr.append(p)
	drafted_draftees[str(p["id"])] = code
	intake_assignments.append({
		"club": code, "player_id": str(p["id"]),
		"player_name": str(p.get("generic_name", p.get("name", "Player"))),
		"kind": kind, "overall": int(p["overall"]),
	})


## The same draft keys real players carry (drafted_year / drafted_type /
## drafted_pick), so a career draftee's story reads like anyone's: "Pick 31,
## 2028 national draft". A pre-listed (father-son, academy) player has no
## pick. His potential was set when he was projected and is not re-derived.
func _mark_drafted(p: Dictionary, kind: String, pick: int) -> void:
	p["drafted_year"] = season_year
	p["drafted_type"] = kind
	if pick > 0:
		p["drafted_pick"] = pick
	else:
		p.erase("drafted_pick")


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
	# The real 2026 season is history before the career starts: every real
	# player's record runs through 2026, at the club he played it for. A
	# 2026 draftee has no senior games; his record starts after 2026 too.
	if season_year > GameDB.DATA_SEASON:
		for code in lists:
			for p in lists[code]:
				Career.add_season(p, GameDB.DATA_SEASON, str(p.get("data_club", p.get("club", ""))),
						int(float(p.get("gm", 0.0))), int(float(p.get("gl", 0.0))))
	# Fixtures, ladders and finals cover only the clubs active this year.
	season = Season.new(GameDB.active_clubs(season_year).duplicate(), lists,
			int(Time.get_unix_time_from_system()) % 1000000)
	salary_cap = draft.budget if draft != null and draft.league_mode else 0
	ensure_contracts()
	# The coaching world from its Round 1 2026 source, carried into this
	# career's first season with you in your club's top job.
	coaches = Coaches.seed(my_club)
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
	last_pos_before = my_position()
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
					"label": "Round %d" % (season.round_index + 1)}
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
	home.form = season.club_form(str(pending_match["home"]))
	away.form = season.club_form(str(pending_match["away"]))
	_refresh_coach_tactics()
	CoachEffects.apply(home)
	CoachEffects.apply(away)
	pending_sim = MatchSim.new(home, away, season.next_seed(99))
	pending_sim.moment_side = 0 if str(pending_match["home"]) == my_club else 1
	pending_sim.set_tactics(pending_sim.moment_side, {"gameplan": club_plan})
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
				season.finals_at_home(m), true)
		res["finals_index"] = i
		pending_round_results.append(res)
	var fm: Dictionary = matches[mine]
	var at_home: Array = season.finals_at_home(fm)
	pending_match = {"home": fm["home"], "away": fm["away"],
			"round": Season.REGULAR_ROUNDS + int(season.finals["week"]),
			"label": str(fm["label"]), "tag": str(fm["tag"]),
			"venue": season.finals_venue(fm), "finals_index": mine}
	var home := Squad.new(GameDB.club_name(str(fm["home"])),
			season.lists[fm["home"]], bool(at_home[0]), str(fm["home"]),
			season.selections.get(str(fm["home"]), {}))
	var away := Squad.new(GameDB.club_name(str(fm["away"])),
			season.lists[fm["away"]], bool(at_home[1]), str(fm["away"]),
			season.selections.get(str(fm["away"]), {}))
	home.form = season.club_form(str(fm["home"]))
	away.form = season.club_form(str(fm["away"]))
	_refresh_coach_tactics()
	CoachEffects.apply(home)
	CoachEffects.apply(away)
	pending_sim = MatchSim.new(home, away, season.finals_seed(mine))
	pending_sim.finals_mode = true
	pending_sim.moment_side = 0 if str(fm["home"]) == my_club else 1
	pending_sim.set_tactics(pending_sim.moment_side, {"gameplan": club_plan})
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
	_sync_club_plan()
	_refresh_coach_tactics()
	last_results = []
	last_match = {}
	last_pos_before = my_position()

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
		var labels := {1: "Wildcard Round", 2: "Qualifying & Elimination Finals",
				3: "Semi Finals", 4: "Preliminary Finals", 5: "Grand Final"}
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


## A club's team form for the hub: {"value": -1..1, "label": "Hot"...,
## "last": the last five results oldest first, e.g. "WWLWW"}.
func club_form_info(code: String) -> Dictionary:
	if season == null:
		return {"value": 0.0, "label": "Steady", "last": ""}
	var res := season.club_results(code)
	var f := ClubLife.team_form(res)
	return {"value": f, "label": ClubLife.team_form_label(f),
			"last": "".join(res.slice(maxi(0, res.size() - ClubLife.FORM_WEIGHTS.size())))}


## "Form: Good  ·  WWWWL" - or "Form: Steady  ·  no games yet". The word and
## the results say it; the internal -1..1 value stays internal.
static func form_line(info: Dictionary, prefix := "Form") -> String:
	var last := str(info.get("last", ""))
	return "%s: %s  ·  %s" % [prefix, str(info["label"]), last if last != "" else "no games yet"]


## Two or three football facts about this week's opponent (Matchup), from
## the sides the engine will field. [] when there is no season or club.
func opponent_facts(code: String) -> Array:
	if season == null or code == "" or not season.lists.has(code):
		return []
	return Matchup.facts(code, season.lists, season.selections, season.club_results(code))


## What comes next, in one line: "Next: Round 5 v Carlton at the MCG." ""
## when there is no fixture to name (finals are drawn week by week).
func next_fixture_line() -> String:
	if season == null or season.is_regular_done():
		return ""
	var nxt := my_next_opponent()
	if nxt.is_empty():
		return ""
	return "Next: Round %d %s %s." % [season.round_index + 1,
			"v" if str(nxt["venue"]) == "home" else "at", GameDB.club_name(str(nxt["code"]))]


## Your side's lines against the league, in words (Matchup.standing): the
## side as you have it picked, so a change of selection shows here.
func my_line_standing() -> Array:
	if season == null or my_club == "":
		return []
	return Matchup.standing(my_club, season.lists, season.selections, my_squad())


## One line of it: "Midfield strong · Ruck below par · Attack one of the best
## · Defence middle of the pack".
func my_line_standing_text() -> String:
	var bits := PackedStringArray()
	for r in my_line_standing():
		bits.append("%s %s" % [str(r[0]), str(r[1])])
	return "  ·  ".join(bits)


## This week line against line (Matchup.head_to_head), your side as picked.
func my_head_to_head(code: String) -> Array:
	if season == null or my_club == "" or code == "":
		return []
	return Matchup.head_to_head(my_club, code, season.lists, season.selections, my_squad())


## Their danger, who they are missing and their run (Matchup.people).
func opponent_people(code: String) -> Array:
	if season == null or code == "" or not season.lists.has(code):
		return []
	return Matchup.people(code, season.lists, season.selections, season.club_results(code))


## Who in a side makes a game plan work, and how they compare with the
## league, in one line: "Your pressure players are strong: Viney, Oliver,
## Petracca, Brayshaw." "" for a plan with no needs (Balanced, Through stars).
func plan_fit_line(ground: Array, plan: String) -> String:
	if not PlanFit.NEEDS.has(plan):
		return ""
	var names := PackedStringArray()
	for p in PlanFit.carriers(ground, plan).slice(0, 4):
		names.append(GameDB.player_display_name(p))
	return "Your %s are %s: %s." % [str(PlanFit.NEEDS[plan]["word"]), PlanFit.fit_word(ground, plan), ", ".join(names)]


## The plan a club's list suits as its usual game (PlanFit.standing_plan),
## from the side it would field this week.
func usual_plan(code: String) -> String:
	if season == null or code == "" or not season.lists.has(code):
		return "balanced"
	return PlanFit.standing_plan(Squad.new(code, season.lists[code], false, code,
			season.selections.get(code, {})).ground)


## Your own side's week worth knowing (Matchup.own_notes).
func my_week_notes() -> Array:
	return Matchup.own_notes(my_list)


## A club's ladder position in words: "3rd".
static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suffix]


func club_position(code: String) -> int:
	if season == null:
		return 0
	var rows := season.ladder_sorted()
	for i in range(rows.size()):
		if rows[i]["code"] == code:
			return i + 1
	return 0


## What a round did to your ladder spot: "Up to 6th." / "Down to 11th." /
## "Still 8th." `before` is your position before the round (0 = unknown).
func ladder_move_line(before: int) -> String:
	var now := my_position()
	if now <= 0:
		return ""
	if before <= 0 or before == now:
		return "Still %s on the ladder." % ordinal(now) if before > 0 else "%s on the ladder." % ordinal(now)
	return "%s to %s on the ladder." % ["Up" if now < before else "Down", ordinal(now)]


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
	for tag in ["WC1", "WC2", "EF1", "EF2", "SF1", "SF2", "PF1", "PF2", "GF"]:
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
		"WC":
			return "Through! You reseed by ladder position for a qualifying or elimination final." \
					if won else "Knocked out in the wildcard round. Your season is over."
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
		if bool(row.get("reserves", false)):
			return "Reserves"
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


## Every player on the list is paid. Named players and good games earn more;
## fit players left out develop in the reserves at half a senior game.
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
	var reserves_count := 0
	var reserves_total := 0
	# The club's teachers (CoachEffects): only once there is a coaching world.
	var staff: Dictionary = CoachEffects.staffs(coaches).get(club, {}) if not coaches.is_empty() else {}
	for p in list:
		var id := str(p["id"])
		var on_ground := ground_ids.has(id)
		var on_bench := bench_ids.has(id)
		var stats: Dictionary = stats_all.get(id, {})
		# Left out but fit to play: he turns out in the reserves.
		var reserves := not on_ground and not on_bench and Ratings.available(p)
		var gain := _xp_amount(stats, on_ground, on_bench, reserves)
		if club == my_club:
			gain = int(round(float(gain) * float(difficulty_rules()["xp_mult"])))
		if not coaches.is_empty():
			gain = int(round(float(gain) * CoachEffects.xp_mult(staff, p, on_ground)))
		p["xp"] = int(p.get("xp", 0)) + gain
		p["xp_games"] = int(p.get("xp_games", 0)) + 1
		total += gain
		if reserves:
			reserves_count += 1
			reserves_total += gain
		rows.append({
			"id": id,
			"xp": gain,
			"on_ground": on_ground,
			"on_bench": on_bench,
			"reserves": reserves,
		})
	rows.sort_custom(func(a, b): return int(a["xp"]) > int(b["xp"]))
	return {
		"reserves_count": reserves_count,
		"reserves_total": reserves_total,
		"label": str(res.get("label", last_label)),
		"home": str(res.get("home", "")),
		"away": str(res.get("away", "")),
		"rows": rows,
		"total": total,
		"count": rows.size(),
	}


# ---------------------------------------------------------------------------
# Training plans: every player's XP is spent after every game
# ---------------------------------------------------------------------------
## A plan is a kind of footballer. Each spends XP on what the match engine
## actually rewards for that job - never on an attribute that does nothing
## for the role (tests/test_training.gd checks every plan against
## Ratings.ROLE_WEIGHTS and the trait table). Each point goes to the best
## weight per XP, so spending spreads as the cheap stats climb.
##
## "position" trains the role core that OVR is built from
## (Ratings.ROLE_WEIGHTS) - the safe default, and what rival clubs use. The
## archetypes lean a player toward one job (and the traits that go with it);
## "manual" pauses development until you spend by hand.
const TRAIN_PLANS := [
	{"key": "position", "label": "Position plan", "roles": []},
	{"key": "inside_mid", "label": "Inside midfielder", "roles": ["MID"],
			"text": "Wins the ball at stoppages and keeps it in the tackle.",
			"weights": {"contested": 3.0, "disposal": 1.0}},
	{"key": "outside_mid", "label": "Wing", "roles": ["MID"],
			"text": "Runs the wing: carries it from defence to attack and hits targets inside 50.",
			"weights": {"carry": 3.0, "disposal": 2.0, "creating": 1.0}},
	{"key": "key_def", "label": "Key defender", "roles": ["DEF"],
			"text": "Stops the opposition: spoils and marks inside 50, tackles hard.",
			"weights": {"intercept": 3.0, "pressure": 2.0}},
	{"key": "rebound_def", "label": "Rebounding defender", "roles": ["DEF"],
			"text": "Wins it back, then runs it out of defence.",
			"weights": {"carry": 3.0, "intercept": 2.0}},
	{"key": "key_fwd", "label": "Key forward", "roles": ["FWD"],
			"text": "The target: marks inside 50 and kicks the goals.",
			"weights": {"marking": 3.0, "goalkicking": 3.0, "accuracy": 1.0}},
	{"key": "small_fwd", "label": "Small forward", "roles": ["FWD"],
			"text": "Goals from the ground: kicks straight and creates, and stays small enough to crumb.",
			"weights": {"goalkicking": 3.0, "accuracy": 2.0, "carry": 1.0, "creating": 1.0}},
	# Rucks need this for a second-role ruck (a defender or forward who
	# pinch-hits), whose Position plan trains his first role.
	{"key": "ruck", "label": "Ruck", "roles": ["RUCK"],
			"text": "Wins the hit-out, then the ball at the stoppage.",
			"weights": {"ruck": 3.0, "contested": 1.0}},
	{"key": "manual", "label": "Manual (development paused)", "roles": [],
			"text": "Nothing is trained automatically. His XP banks until you spend it by hand - banked XP does not make him better."},
]
## What the Position plan means for each role.
const POSITION_PLAN_TEXT := {
	"MID": "Mostly contested ball, with disposal and carry - what wins a midfielder's games.",
	"DEF": "Intercept and pressure first, then carry - what stops the opposition.",
	"FWD": "Goalkicking and marking first, then carry and accuracy - what puts a score on the board.",
	"RUCK": "Wins the tap, then the ball at the stoppage - a ruck's job in a match.",
}
## The plan for anyone without his own: Position plan, or Manual.
var default_train_plan := "position"


## "11 players developed in the reserves: +19 XP each." for the last game,
## or "" when nobody was in the reserves.
func reserves_summary_line() -> String:
	var n := int(last_training_report.get("reserves_count", 0))
	if n <= 0:
		return ""
	var each := int(round(float(last_training_report.get("reserves_total", 0)) / float(n)))
	return "%d %s developed in the reserves: +%d XP each." % [n,
			"player" if n == 1 else "players", each]


## What the last game's training changed, in one line: "Training: 3 players
## rose in OVR (Smith 71 to 72, ...). Jones unlocked Sharpshooter." - or ""
## when nothing visible changed. Stat points alone are not news.
func training_summary_line() -> String:
	var auto: Dictionary = last_training_report.get("auto", {})
	var rises: Array = auto.get("rises", [])
	var traits: Array = auto.get("traits", [])
	var at_pot: Array = auto.get("at_pot", [])
	if rises.is_empty() and traits.is_empty():
		return ""
	var bits: PackedStringArray = []
	if not rises.is_empty():
		var names: PackedStringArray = []
		for r in rises.slice(0, 2):
			names.append("%s %d to %d" % [_short_name(str(r[0])), int(r[1]), int(r[2])])
		if rises.size() > 2:
			names.append("%d more" % (rises.size() - 2))
		bits.append("%d %s in OVR (%s)." % [rises.size(),
				"player rose" if rises.size() == 1 else "players rose", ", ".join(names)])
	for t in traits.slice(0, 2):
		bits.append("%s unlocked %s." % [_short_name(str(t[0])), Traits.label(str(t[1]))])
	if at_pot.size() == 1:
		bits.append("%s reached his potential." % _short_name(str(at_pot[0])))
	elif at_pot.size() > 1:
		bits.append("%d players reached their potential." % at_pot.size())
	return "Training: " + " ".join(bits)


func _short_name(id: String) -> String:
	var p := list_player(id)
	return GameDB.player_display_name(p) if not p.is_empty() else "A player"


# ---------------------------------------------------------------------------
# Injuries
# ---------------------------------------------------------------------------
## Everything that follows a round: injuries, the awards tally, and - when
## the Grand Final has just been played - the season's awards.
func _after_round(results: Array) -> void:
	_process_injuries(results)
	for res in results:
		Awards.tally_match(season_tally, res, not res.has("tag"))
		_note_form_and_team(res)
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
	# Before the off-season releases anyone, so a delisted player keeps it.
	Career.close_season(players, season_tally, season_year)
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
	# Achievements first, then the season news, so the premiership line
	# stays the newest item in the feed.
	_close_season_achievements()
	_board_season_end()
	_coaching_offseason()
	_season_news()


## Club achievements unlock only at season's end: every objective reads the
## final ladder, the finished bracket or the flag history, all of which are
## settled by then.
func _close_season_achievements() -> void:
	if season == null:
		return
	# Past seasons only - this season's flag comes in as ctx["premier"], and
	# the honour roll already carries the entry for it.
	var history := []
	for entry in honour_roll:
		if int(entry.get("year", 0)) == season_year:
			continue
		if str(entry.get("premier", "")) != "":
			history.append([int(entry.get("year", 0)), str(entry.get("premier", ""))])
	var enter := {}
	for code in GameDB.CLUB_ORDER:
		enter[code] = GameDB.enter_year(code)
	var ctx := {
		"year": season_year,
		"premier": premier(),
		"runner_up": str(season.finals.get("runner_up", "")),
		"ladder": season.ladder,
		"finalists": season.finals.get("top", []),
		"finals_slots": season.finals.get("slots", {}),
		"history": history,
		"active": GameDB.active_clubs(season_year),
		"enter": enter,
	}
	for id in Achievements.check_season(achievements, ctx):
		achievements[id] = {"year": season_year}
		var defn: Dictionary = Achievements.definition(id)
		add_news("achievement", "Achievement unlocked: %s  -  %s (%s)" % [
				str(defn["name"]), GameDB.club_name(str(defn["club"])),
				GameDB.club_short(str(defn["club"]))])


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
	for sel_key in ["RUCK", "MID", "WING", "DEF", "FWD", "BENCH", "OUT"]:
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
	# Nobody signed them: their AFL careers end here.
	for p in free_agents:
		_career_over(p)
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
	var out := {"RUCK": [], "MID": [], "WING": [], "DEF": [], "FWD": [], "BENCH": []}
	for p in squad.ground:
		var key := "WING" if Roles.on_wing(p) else str(p["role"])
		(out[key] as Array).append(str(p["id"]))
	for p in squad.bench:
		(out["BENCH"] as Array).append(str(p["id"]))
	return out


func my_squad() -> Squad:
	return Squad.new(GameDB.club_name(my_club), my_list, true, my_club, my_selection())


## Every plan: [[key, label], ...].
func train_plan_options() -> Array:
	var out := []
	for row in TRAIN_PLANS:
		out.append([str(row["key"]), str(row["label"])])
	return out


func _plan_row(key: String) -> Dictionary:
	for row in TRAIN_PLANS:
		if str(row["key"]) == key:
			return row
	return {}


func train_plan_label(key: String) -> String:
	var row := _plan_row(key)
	return str(row.get("label", "Position plan")) if not row.is_empty() else "Position plan"


## What the plan makes of him, in football terms. The Position plan reads
## per role, so pass the player (or his role).
func train_plan_description(key: String, role := "") -> String:
	if key == "position" or _plan_row(key).is_empty():
		if role != "":
			return str(POSITION_PLAN_TEXT.get(role, POSITION_PLAN_TEXT["MID"]))
		return "Trains what his position is judged on - the safe default, and what rival clubs do."
	return str(_plan_row(key).get("text", ""))


## The plans that make sense for this player: Position plan, the archetypes
## of his role (and his second role), and Manual.
func plans_for(p: Dictionary) -> Array:
	var out := []
	for row in TRAIN_PLANS:
		if plan_valid_for(p, str(row["key"])):
			out.append(str(row["key"]))
	return out


func plan_valid_for(p: Dictionary, key: String) -> bool:
	var row := _plan_row(key)
	if row.is_empty():
		return false
	var roles: Array = row["roles"]
	return roles.is_empty() or roles.has(str(p.get("role", ""))) or roles.has(str(p.get("role2", "")))


## The plan a player actually follows: his own if it suits him, else the
## club plan. A saved plan that no longer exists (single-stat focuses, Star
## power) or belongs to another role falls back safely.
func plan_for(p: Dictionary) -> String:
	var own := str(p.get("train_plan", ""))
	if own != "" and plan_valid_for(p, own):
		return own
	return default_train_plan if default_train_plan == "manual" else "position"


## What a plan spends on for this player.
func plan_weights(p: Dictionary, key := "") -> Dictionary:
	if key == "":
		key = plan_for(p)
	var row := _plan_row(key)
	if row.has("weights"):
		return row["weights"]
	return Ratings.ROLE_WEIGHTS.get(str(p.get("role", "MID")), Ratings.ROLE_WEIGHTS["MID"])


## Give one player his own plan ("" = follow the club plan). Banked XP is
## spent under the new plan straight away.
func set_player_plan(player_id: String, key: String) -> Dictionary:
	var p := list_player(player_id)
	if p.is_empty():
		return {}
	if key == "" or not plan_valid_for(p, key):
		p.erase("train_plan")
	else:
		p["train_plan"] = key
	mark_dirty()
	return apply_plan_to(p)


## Change the club plan - Position plan or Manual; nothing else suits every
## role - then spend.
func set_default_plan(key: String) -> Dictionary:
	default_train_plan = "manual" if key == "manual" else "position"
	mark_dirty()
	return apply_train_plans()


## Plans from older saves: the club plan becomes Position plan (a Manual
## club plan becomes Manual on each player who followed it, so nobody's
## development starts or stops behind your back), and a player's own plan
## that no longer exists or does not suit his role is cleared.
func _migrate_train_plans() -> void:
	if default_train_plan == "manual":
		for p in my_list:
			if str(p.get("train_plan", "")) == "":
				p["train_plan"] = "manual"
	default_train_plan = "position"
	for p in my_list:
		var own := str(p.get("train_plan", ""))
		if own != "" and not plan_valid_for(p, own):
			p.erase("train_plan")


## Spend every list player's XP under his plan. Returns
## {"points", "players", "by_player": {id: {stat: points}}, and what it
## changed: "rises": [[id, from, to]], "traits": [[id, trait]],
## "at_pot": [id]}.
func apply_train_plans() -> Dictionary:
	var out := {"points": 0, "players": 0, "by_player": {}, "rises": [], "traits": [], "at_pot": []}
	for p in my_list:
		var ov := int(p.get("overall", 0))
		var had: Array = Traits.of(p)
		var gains := apply_plan_to(p)
		if gains.is_empty():
			continue
		var pts := 0
		for k in gains:
			pts += int(gains[k])
		out["points"] = int(out["points"]) + pts
		out["players"] = int(out["players"]) + 1
		out["by_player"][str(p["id"])] = gains
		var now := int(p["overall"])
		if now > ov:
			(out["rises"] as Array).append([str(p["id"]), ov, now])
			var pot := int(p.get("potential", 0))
			if ov < pot and now >= pot:
				(out["at_pot"] as Array).append(str(p["id"]))
		for t in Traits.of(p):
			if not had.has(t) and not Traits.is_bad(t):
				(out["traits"] as Array).append([str(p["id"]), t])
	return out


## Spend one player's XP under his plan. Returns {stat: points bought}.
func apply_plan_to(p: Dictionary) -> Dictionary:
	if plan_for(p) == "manual":
		return {}
	var gains := _spend_with_weights(p, plan_weights(p), false)
	if not gains.is_empty():
		mark_dirty()
	return gains


## Whether an attribute does anything for this player's role in a match:
## the role core OVR is built from (Ratings.ROLE_WEIGHTS), a trait his role
## can earn from it, or star power and durability (every role).
func stat_useful_for(p: Dictionary, key: String) -> bool:
	return stat_useful_for_role(str(p.get("role", "MID")), key) \
			or (str(p.get("role2", "")) != "" and stat_useful_for_role(str(p["role2"]), key))


static func stat_useful_for_role(role: String, key: String) -> bool:
	if key == "star" or key == "durability":
		return true
	if (Ratings.ROLE_WEIGHTS.get(role, {}) as Dictionary).has(key):
		return true
	for t in Traits.DEFS:
		var d: Dictionary = Traits.DEFS[t]
		if d.has("max") or str(d["stat"]) != key:
			continue
		var roles: Array = d["roles"]
		if roles.is_empty() or roles.has(role):
			return true
	return false


## How much room a player has left, in words: "Developing", "Near his
## ceiling" or "At his ceiling" (or "Rehab year").
func development_state(p: Dictionary) -> String:
	if bool(p.get("rehab", false)):
		return "Rehab year"
	var gap := int(p.get("potential", p.get("overall", 0))) - int(p.get("overall", 0))
	if gap >= 3:
		return "Developing"
	if gap >= 1:
		return "Near his ceiling"
	return "At his ceiling"


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
	var focus: Dictionary = Ratings.ROLE_WEIGHTS.get(str(p.get("role", "MID")), Ratings.ROLE_WEIGHTS["MID"])
	var bought := 0
	for n in _spend_with_weights(p, focus, true, ceiling).values():
		bought += int(n)
	return bought


func _xp_amount(stats: Dictionary, on_ground: bool, on_bench: bool, reserves := false) -> int:
	if reserves:
		return reserves_xp()
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
	return maxi(int(round(8.0 * pot_mult * TRAIN_COST_SCALE)),
			int(round((8.0 + float(cur) * 0.40) * exp_mult * pot_mult * TRAIN_COST_SCALE)))


## Training plans spend only on what a role uses in a match, so every point
## now counts toward the rating; before, a share went on attributes that did
## nothing. Points cost this much more so a season's development stays where
## it was (one season through GameState: your list +5 OVR, as before).
const TRAIN_COST_SCALE := 1.25


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
	# The ladder's codes are exactly this season's active clubs, so the
	# ranking (and the board goal that follows from it) ignores clubs that
	# have not entered the competition yet.
	for code in season.ladder:
		ranks.append([str(code), Squad.new(str(code), season.lists[code], true, str(code)).strength()])
	ranks.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var rank := 1
	club_expect = {}
	for i in range(ranks.size()):
		club_expect[str(ranks[i][0])] = i + 1
		if str(ranks[i][0]) == my_club:
			rank = i + 1
	if board.is_empty():
		board = {"confidence": ClubLife.START_CONFIDENCE, "warned": false, "sacked": false, "history": []}
	board["goal"] = ClubLife.board_goal(rank)
	board["rank"] = rank
	board["year"] = season_year
	board.erase("promise")
	losing_streak = 0
	event_memory = {}
	_next_week_event()


func board_confidence() -> int:
	return int(board.get("confidence", ClubLife.START_CONFIDENCE))


## The board's mood in words (ClubLife.board_state), and why it last moved.
func board_state() -> String:
	return ClubLife.board_state(board_confidence())


func board_why() -> String:
	return str(board.get("why", ""))


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
	# This week's one-off flags (rested, sore, heavy legs, fresh) end with
	# the round.
	for p in my_list:
		p.erase("rested")
		p.erase("sore")
		p.erase("heavy_legs")
		p.erase("fresh")
	if res.is_empty() or board.is_empty():
		return
	var side := 0 if str(res["home"]) == my_club else 1
	var margin := int(res["score"][side]) - int(res["score"][1 - side])
	losing_streak = losing_streak + 1 if margin < 0 else 0
	var goal: Dictionary = board.get("goal", {})
	var moved := ClubLife.after_match(board_confidence(), margin, ClubLife.goal_steps(goal), losing_streak)
	var conf := int(moved["confidence"])
	var opp := str(res["away"]) if side == 0 else str(res["home"])
	board["why"] = ClubLife.match_reason(goal, GameDB.club_name(opp), margin, losing_streak)
	if bool(board.get("promise", false)):
		conf = clampi(conf + (8 if margin > 0 else -10), 0, 100)
		board.erase("promise")
		board["why"] = ("You promised the board a win over %s, and delivered." if margin > 0
				else "You promised the board a win over %s, and did not deliver.") % GameDB.club_name(opp)
	board["confidence"] = conf
	var played := {}
	var roster: Array = res.get("roster", [[], []])
	if roster.size() > side:
		for r in roster[side]:
			played[str(r["id"])] = true
	# Your man-managers soften what being left out costs (CoachEffects).
	var soft := {}
	if not coaches.is_empty():
		var staff: Dictionary = club_staff(my_club)
		for p in my_list:
			soft[str(p["id"])] = CoachEffects.soften(staff, p)
	ClubLife.morale_after_match(my_list, played, margin > 0, soft)
	# A player promised a game (a talk, or a kid given his chance): leaving
	# him out fit sours it. Once: the promise ends with the round.
	for p in my_list:
		if p.has("expects_game"):
			var sting := int(p["expects_game"]) if typeof(p["expects_game"]) == TYPE_INT else 12
			p.erase("expects_game")
			if not played.has(str(p["id"])) and int(p.get("injury_weeks", 0)) <= 0:
				ClubLife.add_morale(p, -CoachEffects.softened(sting, float(soft.get(str(p["id"]), 0.0))))


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
	board["why"] = verdict
	add_news("board", "%s board: %s (%s)" % [GameDB.club_name(my_club), verdict,
			"goal met" if met else "goal missed: " + str(goal.get("text", ""))])


func _next_week_event() -> void:
	var last_key := str(week_event.get("key", ""))
	week_event = {}
	if season == null or season.is_regular_done() or is_sacked():
		return
	var selected := {}
	var side := current_side()
	for k in side:
		for id in side[k]:
			selected[str(id)] = true
	week_event = ClubLife.pick_event({"list": my_list, "round": season.round_index + 1,
			"seed": season.seed, "losses": losing_streak, "selected": selected,
			"cap_room": salary_cap - my_payroll(), "memory": event_memory,
			"last_key": last_key})
	# Remember what came up, so the same player is not back every week.
	if not week_event.is_empty():
		var pid := str(week_event.get("player_id", ""))
		match str(week_event["key"]):
			"extension", "media":
				event_memory["%s|%s" % [week_event["key"], pid]] = true
			"unhappy":
				event_memory["unhappy|" + pid] = season.round_index + 1


## Quick sim: play up to `rounds` home-and-away rounds (-1: to the end of the
## home-and-away season). It never plays a final, and stops early if the
## season ends or something genuinely stops the club (you are sacked).
## Returns {"played": n, "reason": "done" | "season_end" | "sacked"}.
func quick_sim(rounds: int) -> Dictionary:
	var played := 0
	var reason := "done"
	while season != null and (rounds < 0 or played < rounds):
		if season.is_regular_done():
			reason = "season_end"
			break
		advance()
		played += 1
		if is_sacked():
			reason = "sacked"
			break
	if reason == "done" and season != null and season.is_regular_done():
		reason = "season_end"
	return {"played": played, "reason": reason}


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
	var pid := str(week_event.get("player_id", ""))
	var p := list_player(pid)
	var name := GameDB.player_display_name(p) if not p.is_empty() else ""
	var out := ""
	# The card was about a player who has since left the club: nothing to do.
	if pid != "" and p.is_empty():
		key = "_gone"
	match key:
		"_gone":
			out = "The moment has passed: he is no longer at the club."
		"rest":
			p["rested"] = true
			out = "%s is rested this week." % name
		"play":
			if int(p.get("injury_weeks", 0)) > 0:
				out = "%s has since been ruled out anyway." % name
			else:
				p["sore"] = true
				out = "%s plays - fingers crossed." % name
		"heavy":
			for q in my_list:
				q["xp"] = int(q.get("xp", 0)) + ClubLife.HEAVY_XP
				q["heavy_legs"] = true
			apply_train_plans()
			out = "A heavy week: +%d XP each, heavy legs on game day." % ClubLife.HEAVY_XP
		"recover":
			for q in my_list:
				ClubLife.add_morale(q, 3)
				q["fresh"] = true
			out = "A recovery week: fresher bodies and minds."
		"open":
			for q in my_list:
				ClubLife.add_morale(q, 3)
			board["confidence"] = clampi(board_confidence() + 4, 0, 100)
			out = "The members loved it."
		"closed":
			for q in my_list:
				q["xp"] = int(q.get("xp", 0)) + ClubLife.CLOSED_XP
			apply_train_plans()
			out = "A closed session: +%d XP each." % ClubLife.CLOSED_XP
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
			var cost := ClubLife.early_price(p)
			var years := ClubLife.early_years(p)
			if int(p.get("contract_years", 1)) > 1:
				out = "%s is already signed beyond this season." % name
			elif my_payroll() - int(p.get("salary", 0)) + cost <= salary_cap:
				p["salary"] = cost
				p["contract_years"] = years
				ClubLife.add_morale(p, 8)
				out = "%s signs on for %d more season%s at %d." % [name, years - 1,
						"" if years == 2 else "s", cost]
			else:
				# The cap moved since the card was drawn: nobody's fault.
				out = "The cap no longer has room to extend %s now; it waits for the off-season." % name
		"pressure", "promise":
			board["promise"] = true
			out = "You promise a win this week."
		"patience":
			board["confidence"] = clampi(board_confidence() - 3, 0, 100)
			out = "The board grudgingly agrees to wait."
		"develop":
			# A week with the development coaches instead of playing: the
			# XP comes at the cost of this week's game, senior or reserves.
			p["xp"] = int(p.get("xp", 0)) + ClubLife.DEV_WEEK_XP
			p["rested"] = true
			apply_plan_to(p)
			out = "%s spends the week with the development coaches: +%d XP." % [name, ClubLife.DEV_WEEK_XP]
		"blood":
			# His chance: he earns a senior game's XP by playing it - if you
			# pick him. Leaving him out after this stings.
			ClubLife.add_morale(p, 5)
			p["expects_game"] = 10
			out = "%s is told he is in. Pick him this week." % name
		"talk":
			ClubLife.add_morale(p, 15)
			p["expects_game"] = 12
			out = "%s feels heard, and expects a game this week." % name
		"earn":
			ClubLife.add_morale(p, -5)
			for q in my_list:
				if q != p:
					ClubLife.add_morale(q, 2)
			out = "%s is told to earn his spot. The group respects it." % name
		_:
			if not p.is_empty() and key == "wait":
				ClubLife.add_morale(p, -5)
				out = "%s is disappointed, but it can wait for the off-season." % name
			else:
				out = "Business as usual."
	week_event["resolved"] = true
	week_event["choice"] = choice
	week_event["outcome"] = out
	mark_dirty()
	return out


# ---------------------------------------------------------------------------
# Coaching staff (Coaches.gd): read-only for now
# ---------------------------------------------------------------------------
## A club's staff as records by job ("SC" absent at your club: that is you).
func club_staff(club: String) -> Dictionary:
	var out := {}
	var jobs := Coaches.staff(coaches, club)
	for job in jobs:
		out[job] = coaches[jobs[job]]
	return out


func coach(cid: String) -> Dictionary:
	return coaches.get(cid, {})


## The coaching world moves once a season, at its close (CoachMarket): AI
## senior coaches are judged against where their list ranked preseason -
## the same goal the board sets you - and every vacancy is filled. Your
## open jobs wait in staff_vacancies.
func _coaching_offseason() -> void:
	if season == null or coaches.is_empty():
		return
	var results := {}
	var table := season.ladder_sorted()
	for i in range(table.size()):
		var row: Dictionary = table[i]
		var code := str(row["code"])
		var goal := ClubLife.board_goal(int(club_expect.get(code, 9)))
		var pos := i + 1
		var met := ClubLife.goal_met(goal, pos, int(row.get("w", 0)))
		results[code] = {"met": met, "finals": pos <= Season.FINALISTS,
				"severe": not met and pos >= table.size() - 2 and int(club_expect.get(code, 18)) <= 10}
	var out := CoachMarket.offseason({"coaches": coaches, "archive": coach_archive,
			"year": season_year, "my_club": my_club, "clubs": GameDB.active_clubs(season_year + 1),
			"results": results, "premier": premier(), "seed": career_seed})
	for v in out["vacancies"]:
		if not _vacancy_open(str(v["job"])):
			staff_vacancies.append(v)
	for t in out["news"]:
		add_news("coaching", str(t))


## Retirees who go into coaching (CoachPathway): each is decided once, here,
## and becomes a coach record carrying a compact playing-career snapshot. The
## player record itself is not kept.
func _retirees_to_coaching(retired: Array, listed: Dictionary) -> void:
	for r in retired:
		var pid := str(r.get("id", ""))
		if listed.has(pid):
			_career_over(listed[pid])


## A playing career has ended - retired, or delisted and not picked up - and
## this is the last moment the player is in hand.
func _career_over(p: Dictionary) -> void:
	if coaches.is_empty():
		return
	var pid := str(p.get("id", ""))
	var cid := CoachPathway.cid_for(pid)
	if pid == "" or coaches.has(cid) or coach_archive.has(cid):
		return
	var played := CoachPathway.snapshot(p, season_year, honour_roll)
	if CoachPathway.interested(pid, played, career_seed):
		coaches[cid] = CoachPathway.make_coach(p, played, season_year, career_seed)


## Every club's tactics for the coming matches (CoachEffects), derived from
## the coach records each time and never saved.
func _refresh_coach_tactics() -> void:
	if coaches.is_empty() or season == null:
		CoachEffects.table = {}
		return
	CoachEffects.set_table(coaches, GameDB.active_clubs(season_year), my_club)


func _vacancy_open(job: String) -> bool:
	for v in staff_vacancies:
		if str(v["job"]) == job:
			return true
	return false


## The shortlist for one of your open jobs (coach records, best first).
func staff_shortlist(job: String) -> Array:
	var out := []
	for cid in CoachMarket.shortlist(coaches, my_club, job, season_year, career_seed, 4):
		out.append(coaches[cid])
	return out


## Appoint a coach to one of your open jobs. Promoting your own assistant
## opens his old job instead.
func appoint_staff(job: String, cid: String) -> void:
	if not coaches.has(cid):
		return
	var left := CoachMarket.appoint_mine(coaches, cid, my_club, job, season_year, career_seed)
	_close_vacancy(job)
	if left != "":
		staff_vacancies.append({"job": left, "reason": "%s stepped up to %s." % [
				GameDB.player_display_name(coaches[cid]), CoachMarket._job_word(job)]})
	_dirty = true


func auto_fill_staff(job: String) -> void:
	var left := CoachMarket.auto_fill(coaches, my_club, job, season_year, career_seed)
	_close_vacancy(job)
	if left != "":
		staff_vacancies.append({"job": left, "reason": "Filled from within: his old job is open."})
	_dirty = true


func _close_vacancy(job: String) -> void:
	for i in range(staff_vacancies.size() - 1, -1, -1):
		if str(staff_vacancies[i]["job"]) == job:
			staff_vacancies.remove_at(i)


## The offseason is the time to change staff: release an assistant (no
## payout, no negotiation); his job opens for you to fill.
func can_release_staff() -> bool:
	return season != null and season.is_season_over()


func release_staff(cid: String) -> void:
	if not can_release_staff() or not coaches.has(cid):
		return
	var c: Dictionary = coaches[cid]
	if str(c.get("club", "")) != my_club or str(c.get("job", "")) == "SC":
		return
	CoachMarket.ensure_fields(c, season_year)
	var job := CoachMarket.release(coaches, cid, season_year)
	staff_vacancies.append({"job": job, "reason": "You released %s." % GameDB.player_display_name(c)})
	_dirty = true


## A season never starts a staff member short: open jobs are auto-filled.
func _fill_open_staff() -> void:
	var guard := 0
	while not staff_vacancies.is_empty() and guard < 12:
		guard += 1
		auto_fill_staff(str(staff_vacancies[0]["job"]))


# ---------------------------------------------------------------------------
# Coaching hub: the standing game plan, player form, how the side plays
# ---------------------------------------------------------------------------
## The plans a club can stand on; the same six as the quarter-break calls.
const CLUB_PLANS := ["balanced", "attacking", "defensive", "contest", "controlled", "through_stars"]


## Your standing game plan: every match starts with it, played or simmed,
## and the quarter-break calls change it from there.
func set_club_plan(key: String) -> void:
	if not CLUB_PLANS.has(key):
		return
	club_plan = key
	_sync_club_plan()
	mark_dirty()


func _sync_club_plan() -> void:
	if season != null:
		season.plans = {my_club: club_plan} if club_plan != "balanced" else {}


## After each match: your players' last three Player Ratings, and every
## club's season team totals.
func _note_form_and_team(res: Dictionary) -> void:
	var codes := [str(res.get("home", "")), str(res.get("away", ""))]
	var team: Array = res.get("team", [])
	var score: Array = res.get("score", [0, 0])
	for side in range(mini(2, team.size())):
		var row: Dictionary = season_team.get(codes[side], {"games": 0})
		row["games"] = int(row["games"]) + 1
		for k in TEAM_KEYS:
			row[k] = float(row.get(k, 0.0)) + float((team[side] as Dictionary).get(k, 0.0))
		row["for"] = float(row.get("for", 0.0)) + float(score[side])
		row["against"] = float(row.get("against", 0.0)) + float(score[1 - side])
		# Where the points come from, both ways (MatchSim score sources).
		var mine_t: Dictionary = team[side]
		var theirs_t: Dictionary = team[1 - side] if team.size() > 1 else {}
		for k in ["turnover", "stoppage"]:
			row["from_" + k] = float(row.get("from_" + k, 0.0)) + _source_pts(mine_t, k)
			row["conceded_" + k] = float(row.get("conceded_" + k, 0.0)) + _source_pts(theirs_t, k)
		season_team[codes[side]] = row
	if not is_my_match(res):
		return
	var side := 0 if codes[0] == my_club else 1
	var roster: Array = res.get("roster", [[], []])
	if roster.size() <= side:
		return
	var players: Dictionary = res.get("players", {})
	for r in roster[side]:
		var id := str(r["id"])
		var f: Dictionary = form_log.get(id, {"last": [], "sum": 0, "n": 0})
		var pts := MatchNotes.rating(players.get(id, {}))
		var last: Array = f["last"]
		last.append(pts)
		f["last"] = last.slice(maxi(0, last.size() - FORM_GAMES))
		f["sum"] = int(f["sum"]) + pts
		f["n"] = int(f["n"]) + 1
		form_log[id] = f


## Points from one kind of source; stoppages include centre bounces.
static func _source_pts(t: Dictionary, k: String) -> float:
	var v := float(t.get("score_from_" + k, 0.0))
	if k == "stoppage":
		v += float(t.get("score_from_centre", 0.0))
	return v


const FORM_GAMES := 3
const TEAM_KEYS := ["clearances", "inside50", "tackles", "pressure_acts", "marks",
		"rebounds", "clangers", "hitouts", "disposals", "metres_gained"]


## Players whose last three games stand out against their own season:
## {"hot": [...], "cold": [...]}, each [{id, recent, season}], at most
## three a side, only for players with five games or more this season.
func player_form() -> Dictionary:
	var hot := []
	var cold := []
	for p in my_list:
		var id := str(p["id"])
		var f: Dictionary = form_log.get(id, {})
		var last: Array = f.get("last", [])
		var n := int(f.get("n", 0))
		if last.size() < FORM_GAMES or n < 5:
			continue
		var recent := 0.0
		for x in last:
			recent += float(x)
		recent /= float(last.size())
		var avg := float(f["sum"]) / float(n)
		var row := {"id": id, "recent": int(round(recent)), "season": int(round(avg))}
		if recent >= avg + FORM_GAP:
			hot.append(row)
		elif recent <= avg - FORM_GAP:
			cold.append(row)
	hot.sort_custom(func(a, b): return int(a["recent"]) - int(a["season"]) > int(b["recent"]) - int(b["season"]))
	cold.sort_custom(func(a, b): return int(a["recent"]) - int(a["season"]) < int(b["recent"]) - int(b["season"]))
	return {"hot": hot.slice(0, 3), "cold": cold.slice(0, 3)}


const FORM_GAP := 15.0


## How the side plays, from the season so far against the average club:
## {"win": [sentence], "beaten": [sentence], "games": n}. The biggest
## differences first, at most three each; nothing until three games in.
func how_we_play(code := "") -> Dictionary:
	if code == "":
		code = my_club
	var games := int((season_team.get(code, {}) as Dictionary).get("games", 0))
	var out := {"win": [], "beaten": [], "games": games}
	for f in _style_found(code):
		var lines: Array = STYLE_LINES[f["k"]]
		var bucket: Array = out["win"] if bool(f["good"]) else out["beaten"]
		if bucket.size() < 3:
			bucket.append(str(lines[0] if bool(f["good"]) else lines[1]) % int(f["n"]))
	return out


## How an opponent plays, from their season so far, in words and no numbers:
## "They win it at the stoppages." At most `limit`, most marked first; [] before
## they have played three games.
func their_style(code: String, limit := 2) -> Array:
	var out := []
	for f in _style_found(code):
		if out.size() >= limit:
			break
		out.append(str(THEIR_STYLE[f["k"]][0 if bool(f["good"]) else 1]))
	return out


## The stats where a club is clearly off the league average, most marked
## first: [{"k", "rel", "n", "good"}]. [] before three games.
func _style_found(code: String) -> Array:
	var mine: Dictionary = season_team.get(code, {})
	var games := int(mine.get("games", 0))
	if games < 3:
		return []
	var league := {}
	var clubs := 0
	for c in season_team:
		var row: Dictionary = season_team[c]
		var g := float(maxi(1, int(row.get("games", 0))))
		clubs += 1
		for k in STYLE_LINES:
			league[k] = float(league.get(k, 0.0)) + float(row.get(k, 0.0)) / g
	var found := []
	for k in STYLE_LINES:
		var avg := float(league.get(k, 0.0)) / float(maxi(1, clubs))
		if avg <= 0.0:
			continue
		var d := float(mine.get(k, 0.0)) / float(games) - avg
		var good: bool = (d > 0.0) != bool(STYLE_LINES[k][2])
		if absf(d) / avg >= STYLE_GAP and int(round(absf(d))) >= 1:
			found.append({"k": k, "rel": absf(d) / avg, "n": int(round(absf(d))), "good": good})
	found.sort_custom(func(a, b): return float(a["rel"]) > float(b["rel"]))
	return found


## STYLE_LINES as said of an opponent: [when it helps them, when it hurts them].
const THEIR_STYLE := {
	"for": ["They kick big scores.", "They struggle to score."],
	"against": ["They are hard to score against.", "They leak scores."],
	"clearances": ["They win it at the stoppages.", "They get beaten at the stoppages."],
	"inside50": ["They live in their forward half.", "They struggle to get it forward."],
	"pressure_acts": ["They bring the heat.", "They give opponents time."],
	"marks": ["They hold it by foot and mark it.", "They rarely take a mark."],
	"clangers": ["They look after the ball.", "They turn it over."],
	"hitouts": ["Their ruck wins the tap.", "They get beaten in the ruck."],
	"from_turnover": ["They hurt sides on the turnover.", "They rarely score on the turnover."],
	"from_stoppage": ["They score from the stoppages.", "They rarely score from the stoppages."],
	"conceded_turnover": ["They rarely get caught on the turnover.", "They get caught on the turnover."],
	"conceded_stoppage": ["They shut down stoppage scores.", "They give up scores from the stoppages."],
}


## How far off the average a side must be before it is a trait of its play.
const STYLE_GAP := 0.07
## stat -> [said when it helps, said when it hurts, lower is better]
const STYLE_LINES := {
	"for": ["We kick a winning score: %d points a game more than the average side.",
			"We struggle to score: %d points a game fewer than the average side.", false],
	"against": ["We are hard to score against: %d points a game fewer conceded than the average side.",
			"We leak scores: %d points a game more conceded than the average side.", true],
	"clearances": ["We win it at the stoppages: %d more clearances a game than the average side.",
			"We get beaten at the stoppages: %d fewer clearances a game than the average side.", false],
	"inside50": ["We live in our forward half: %d more inside 50s a game than the average side.",
			"We struggle to get it forward: %d fewer inside 50s a game than the average side.", false],
	"pressure_acts": ["We bring the heat: %d more pressure acts a game than the average side.",
			"We give opponents time: %d fewer pressure acts a game than the average side.", false],
	"marks": ["We hold it by foot and mark it: %d more marks a game than the average side.",
			"We rarely take a mark: %d fewer a game than the average side.", false],
	"clangers": ["We look after the ball: %d fewer clangers a game than the average side.",
			"We turn it over: %d more clangers a game than the average side.", true],
	"hitouts": ["Our ruck wins the tap: %d more hit-outs a game than the average side.",
			"We are beaten in the ruck: %d fewer hit-outs a game than the average side.", false],
	"from_turnover": ["We hurt sides on the turnover: %d more points a game from it than the average side.",
			"We rarely score on the turnover: %d fewer points a game from it than the average side.", false],
	"from_stoppage": ["We score from the stoppages: %d more points a game from them than the average side.",
			"We rarely score from the stoppages: %d fewer points a game from them than the average side.", false],
	"conceded_turnover": ["We rarely get caught on the turnover: %d fewer points a game conceded from it than the average side.",
			"They hurt us on the turnover: %d more points a game conceded from it than the average side.", true],
	"conceded_stoppage": ["We shut down their stoppage game: %d fewer points a game conceded from stoppages than the average side.",
			"They hurt us from the stoppages: %d more points a game conceded from them than the average side.", true],
}
