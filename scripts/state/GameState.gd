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
## Transient navigation request. Settings can send the user straight to New
## career setup without touching the existing save.
var new_career_setup_requested := false

var my_club := ""
var my_list: Array = []
var season: Season = null
var draft: Draft = null
var league_lists := {}
var pending_match: Dictionary = {}
var pending_sim: MatchSim = null
var pending_round_results: Array = []
var _others := {}          # the round's other matches, running in the background
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
var last_mro: Array = []         # the last round's MRO outcomes, every club
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
var club_goals := {}             # club -> this season\'s board goal (ClubLife.board_goal)
var _last_finish := {}           # club -> last season\'s ladder position, for the board
var draft_meeting_year := 0     # the National Draft the recruiting panel last met before
var records := {}                # league records across the career
var rivalry_history := {}        # canonical club pair -> emergent rivalry evidence
## Club achievements unlocked this career: id -> {"year", "detail"}.
## Definitions live in scripts/sim/Achievements.gd.
var achievements := {}
var salary_cap := 0              # annual-dollar TPP cap every club's payroll counts against
var free_agents: Array = []      # off-season: players no club kept
var offseason_year := 0          # the season whose off-season has opened
var fa_closed_year := 0          # the season whose free agency has closed
## This off-season's free-agency compensation picks: [{"club", "player",
## "name", "to", "salary", "years", "value", "after"}], slotted into the
## national draft when it opens (Contracts.compensation_after).
var compensation: Array = []
## Traded draft picks: "year:round:origin club" -> the club that owns it. A
## pick not listed still belongs to its own club. Saved; a draft year's
## entries go once that draft is done.
var pick_owner := {}
var offseason_log: Array = []    # what happened in the off-season, for news
var offseason_staff := {}        # your staff (job -> cid) when the off-season opened
## Annual discretionary department funding for the coming season. It is an
## allocation, not cash carried between years (ClubBudget).
var department_budget := {}
var department_budget_year := 0
var season_wrap := {}            # the off-season briefing shown before Round 1 (season_wrap_lines)
var _wrap_picks: Array = []      # your National Draft picks, carried into the rollover
var news: Array = []             # league news feed, newest first
var difficulty := "normal"       # this career's difficulty (DIFFICULTIES key)
var board := {}                  # confidence, goal, warned, sacked, history
var week_event := {}             # this week's event card (ClubLife.pick_event)
var media_conference := {}       # pending post-match press question
var media_memory := {}           # question key -> last round asked
var losing_streak := 0
## Your match-ups for the next match (Matchups): {their forward id: your
## defender id}, on top of the default set-up. Cleared after each of your
## matches - every opponent is a new problem.
var my_matchups := {}
var last_side: Array = []       # ids of your players who took the field in your last match
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
	UiKit.apply_appearance(str(cfg.get_value("ui", "appearance", "dark")))
	_apply_sound_mute(bool(cfg.get_value("ui", "mute_sounds", false)))


func _exit_tree() -> void:
	_collect_others()      # the round's other matches may still be running


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


func appearance() -> String:
	var mode := str(get_setting("appearance", "dark"))
	return mode if mode in ["dark", "light"] else "dark"


## Change the shared UI palette. The caller rebuilds the current screen when
## this returns true so no old-theme controls remain on screen.
func set_appearance(mode: String) -> bool:
	if mode != "dark" and mode != "light":
		return false
	var changed := appearance() != mode
	set_setting("appearance", mode)
	UiKit.apply_appearance(mode)
	return changed


func sounds_muted() -> bool:
	return bool(get_setting("mute_sounds", false))


func set_sounds_muted(muted: bool) -> void:
	set_setting("mute_sounds", muted)
	_apply_sound_mute(muted)


## Mute the Master bus so future music and SFX automatically honour the same
## setting even if they later gain their own child buses.
func _apply_sound_mute(muted: bool) -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, muted)


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
	_phase_cache = {}


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
		"last_mro": last_mro,
		"season_tally": season_tally,
		"club_plan": club_plan,
		"form_log": form_log,
		"season_team": season_team,
		"season_awards": season_awards,
		"honour_roll": honour_roll,
		"records": records,
		"rivalry_history": rivalry_history,
		"achievements": achievements,
		"salary_cap": salary_cap,
		"free_agents": free_agents,
		"offseason_year": offseason_year,
		"fa_closed_year": fa_closed_year,
		"compensation": compensation,
		"pick_owner": pick_owner,
		"offseason_staff": offseason_staff,
		"department_budget": department_budget,
		"department_budget_year": department_budget_year,
		"season_wrap": season_wrap,
		"offseason_log": offseason_log,
		"news": news,
		"difficulty": difficulty,
		"board": board,
		"week_event": week_event,
		"media_conference": media_conference,
		"media_memory": media_memory,
		"losing_streak": losing_streak,
		"my_matchups": my_matchups,
		"last_side": last_side,
		"event_memory": event_memory,
		"db_draftees": GameDB.draftees,
		"db_late_draftees": GameDB.late_draftees,
		"db_alias_next": GameDB._alias_next,
		"coaches": coaches,
		"coach_archive": coach_archive,
		"staff_vacancies": staff_vacancies,
		"club_expect": club_expect,
		"club_goals": club_goals,
		"draft_meeting_year": draft_meeting_year,
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
	state = CareerSave.migrate_club_codes(state)
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
	last_mro = state.get("last_mro", [])
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
	rivalry_history = state.get("rivalry_history", {})
	achievements = state.get("achievements", {})
	salary_cap = int(state.get("salary_cap", 0))
	free_agents = state.get("free_agents", [])
	offseason_year = int(state.get("offseason_year", 0))
	fa_closed_year = int(state.get("fa_closed_year", 0))
	compensation = state.get("compensation", [])
	pick_owner = state.get("pick_owner", {})
	offseason_staff = state.get("offseason_staff", {})
	department_budget = state.get("department_budget", ClubBudget.defaults())
	department_budget_year = int(state.get("department_budget_year", season_year))
	_ensure_department_budget()
	season_wrap = state.get("season_wrap", {})
	offseason_log = state.get("offseason_log", [])
	news = state.get("news", [])
	board = state.get("board", {})
	week_event = state.get("week_event", {})
	media_conference = state.get("media_conference", {})
	media_memory = state.get("media_memory", {})
	losing_streak = int(state.get("losing_streak", 0))
	my_matchups = state.get("my_matchups", {})
	last_side = state.get("last_side", [])
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
	_migrate_money_units()
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
	club_goals = state.get("club_goals", {})
	draft_meeting_year = int(state.get("draft_meeting_year", 0))
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
			# Salary value is derived data too. Always refresh it so old saves
			# cannot retain the retired 1-10 cap-point scale when OVR itself
			# happens not to change.
			p["value"] = Ratings.salary_value(ov)
			if ov == old:
				continue
			p["overall"] = ov
			if p.has("potential"):
				p["potential"] = clampi(int(p["potential"]) + ov - old, 1, Potential.MAX_POT)
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


## Saves written before the real-money conversion stored salary/cap values
## as tiny 1-10 points. Convert every live copy plus in-progress negotiation
## state deterministically. This is intentionally detection-based rather than
## tied to the general career version: a mid-opening-draft save can have no
## season cap yet but still carries an old tiny draft budget.
func _migrate_money_units() -> void:
	var old_units := salary_cap > 0 and salary_cap < 100000
	if draft != null and draft.league_mode and int(draft.budget) > 0 and int(draft.budget) < 100000:
		old_units = true

	var groups: Array = [my_list, free_agents, draftee_pool, GameDB.draftees, GameDB.late_draftees]
	if season != null:
		for code in season.lists:
			groups.append(season.lists[code])
	for code in league_lists:
		groups.append(league_lists[code])
	if draft != null:
		groups.append(draft.pool)
		for code in draft.club_lists:
			groups.append(draft.club_lists[code])

	var seen := {}
	for arr in groups:
		for p in arr:
			if not (p is Dictionary):
				continue
			var id := str(p.get("id", ""))
			var token := id if id != "" else str(hash(p))
			if seen.has(token):
				continue
			seen[token] = true
			if p.has("overall"):
				p["value"] = Ratings.salary_value(int(p["overall"]))
			if old_units and int(p.get("salary", 0)) > 0 and int(p.get("salary", 0)) < 1000:
				p["salary"] = Contracts.old_points_to_salary(int(p["salary"]))
			var talks: Dictionary = p.get("talks", {})
			if old_units and int(talks.get("counter", 0)) > 0 and int(talks.get("counter", 0)) < 1000:
				talks["counter"] = Contracts.old_points_to_salary(int(talks["counter"]))
				p["talks"] = talks
			if old_units:
				for o in p.get("offers", []):
					if int(o.get("salary", 0)) > 0 and int(o.get("salary", 0)) < 1000:
						o["salary"] = Contracts.old_points_to_salary(int(o["salary"]))

	if old_units:
		salary_cap = Contracts.salary_cap_for_year(maxi(GameDB.START_YEAR, season_year))
		for row in compensation:
			if int(row.get("salary", 0)) > 0 and int(row.get("salary", 0)) < 1000:
				row["salary"] = Contracts.old_points_to_salary(int(row["salary"]))
		if draft != null and draft.league_mode:
			draft.budget = Contracts.salary_cap_for_year(GameDB.START_YEAR)
			draft._reserve_at = -1
			draft._reserve_cache = float(Contracts.SENIOR_MIN_2027)
			for code in draft.club_lists:
				draft.club_spend[code] = 0
				for p in draft.club_lists[code]:
					draft.club_spend[code] = int(draft.club_spend[code]) + int(p.get("value", Ratings.salary_value(int(p.get("overall", 50)))))
			for entry in draft.pick_history:
				entry["value"] = Ratings.salary_value(int(entry.get("overall", 50)))


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
	_collect_others()
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
	last_mro = []
	season_tally = {}
	club_plan = "balanced"
	form_log = {}
	season_team = {}
	season_awards = {}
	honour_roll = []
	records = {}
	rivalry_history = {}
	achievements = {}
	coaches = {}
	coach_archive = {}
	staff_vacancies = []
	club_expect = {}
	club_goals = {}
	_last_finish = {}
	draft_meeting_year = 0
	salary_cap = 0
	free_agents = []
	offseason_year = 0
	fa_closed_year = 0
	compensation = []
	pick_owner = {}
	offseason_log = []
	offseason_staff = {}
	department_budget = ClubBudget.defaults()
	department_budget_year = 0
	season_wrap = {}
	_wrap_picks = []
	news = []
	board = {}
	week_event = {}
	media_conference = {}
	media_memory = {}
	losing_streak = 0
	my_matchups = {}
	last_side = []
	event_memory = {}
	difficulty = new_career_difficulty()
	career_seed = randi_range(1, 999999)
	class_tiers = {}
	last_training_report = {}
	_xp_grant_key = ""
	new_career_setup_requested = false
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
	_close_free_agency()
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
	# Recruiting funding narrows only our club's uncertainty; rivals use the
	# same scouting model at Standard rather than hidden true ratings.
	draft.scouting_mults[my_club] = recruiting_uncertainty_mult()
	var comps := []
	for c in compensation:
		if active.has(str(c["club"])):
			comps.append(c)
	draft.set_pick_owners(draft_pick_owners(season_year))
	draft.add_compensation(comps)
	draft.start_for_user(my_club)
	autosave()
	return true


## Commit the intake: merge picks into every club's list, generate next year's
## class, age the whole league (growth, decline, retirements), then build the
## next season on those lists.
func finish_intake_draft() -> bool:
	if draft == null or not draft.intake_mode or not draft.is_finished():
		return false
	# This year's picks are spent.
	for key in pick_owner.keys():
		if int(str(key).split(":")[0]) <= season_year:
			pick_owner.erase(key)
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
			Contracts.rookie_deal(p, season_year + 1)
			if code == my_club:
				_wrap_picks.append([id, int(entry.get("pick", 0))])
			arr.append(p)
			drafted_draftees[id] = code
	draft = null
	_start_next_season(next_year, merged)
	return true


## Roll every list forward one year and rebuild the season. Split out so a
## career can continue even when there is no prospect pool to draft.
func _start_next_season(next_year: int, signed: int) -> void:
	# Where every club finished: next season's board reads it (ClubLife.board_goal).
	_last_finish = {}
	if season != null:
		var table := season.ladder_sorted()
		for k in range(table.size()):
			_last_finish[str(table[k]["code"])] = k + 1
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
	Workload.reset(league_lists)
	Workload.reset({"free_agents": free_agents})
	Injuries.heal_all(league_lists)
	if season != null:
		Workload.reset(season.lists)
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
	# The cap moves with the new season before contracts are assigned.
	salary_cap = Contracts.salary_cap_for_year(next_year)
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
	_collect_others()
	pending_round_results = []
	pending_phase = ""
	pending_label = ""
	_open_board_season()
	_build_season_wrap(next_year)
	autosave()


## The off-season, wrapped up for your club before Round 1: who came, who
## went (and how), staff changes, and what the board expects. Built once at
## the rollover from the records the off-season kept, saved, and shown until
## you begin the season - a reload can neither skip nor repeat it.
func _build_season_wrap(year: int) -> void:
	var ins := []
	var outs := []
	var comp_after := {}
	for c in compensation:
		if str(c["club"]) == my_club:
			comp_after[str(c["player"])] = int(c["after"])
	for e in offseason_log:
		match str(e.get("kind", "")):
			"signed":
				if str(e.get("club", "")) == my_club:
					ins.append({"id": str(e["id"]), "how": "free agent"})
			"released":
				if str(e.get("club", "")) == my_club:
					var how := "free agent" if bool(e.get("wanted", false)) else "delisted"
					if comp_after.has(str(e["id"])):
						how = "free agent; compensation pick after pick %d" % int(comp_after[str(e["id"])])
					outs.append({"id": str(e["id"]), "how": how})
			"trade":
				# Players only: a traded pick shows up as the player it
				# becomes at the draft.
				for id in e.get("in", []):
					if not str(id).begins_with("pick:"):
						ins.append({"id": str(id), "how": "trade"})
				for id in e.get("out", []):
					if not str(id).begins_with("pick:"):
						outs.append({"id": str(id), "how": "trade"})
	for a in intake_assignments:
		if str(a.get("club", "")) == my_club:
			ins.append({"id": str(a["player_id"]), "how": "NGA" if str(a.get("kind", "")) == "nga" else str(a.get("kind", "")), "name": str(a.get("player_name", ""))})
	for pk in _wrap_picks:
		ins.append({"id": str(pk[0]), "how": "pick %d" % int(pk[1])})
	_wrap_picks = []
	for r in intake_summary.get("retired", []):
		if str(r.get("club", "")) == my_club:
			outs.append({"id": str(r["id"]), "how": "retired", "name": str(r.get("name", ""))})
	for row in ins + outs:
		if not row.has("name") or str(row["name"]) == "":
			row["name"] = GameDB.player_display_name_by_id(str(row["id"]), "A player")
		else:
			row["name"] = GameDB.player_display_name_by_id(str(row["id"]), str(row["name"]))
	var staff_lines := []
	if not offseason_staff.is_empty() and not coaches.is_empty():
		var now := Coaches.staff(coaches, my_club)
		for job in Coaches.JOB_LABEL:
			var was := str(offseason_staff.get(job, ""))
			var is_now := str(now.get(job, ""))
			if was != "" and was != is_now and (coaches.has(was) or coach_archive.has(was)):
				# A retired coach may already be archived (or gone from the
				# records): then he has finished in the game.
				var gone: Dictionary = coaches.get(was, coach_archive.get(was, {}))
				var where := "retired"
				if coaches.has(was) and str(gone.get("status", "")) != "retired":
					where = Coaches.whereabouts(gone)
					where = where.left(1).to_lower() + where.substr(1)
				staff_lines.append("%s left: %s." % [GameDB.player_display_name(gone), where])
			if is_now != "" and is_now != was:
				var c: Dictionary = coaches.get(is_now, {})
				staff_lines.append("New %s: %s." % [_job_words(job), GameDB.player_display_name(c)])
	season_wrap = {"year": year, "ins": ins, "outs": outs, "staff": staff_lines,
			"league_coaches": new_senior_coaches(year),
			"goal": board_goal_text(), "reason": board_goal_reason(), "seen": false}


## The clubs with a new senior coach for `year`, as sentences: who replaced
## whom. Read from the coach records (an appointment for `year` starts that
## season), so nothing extra is saved. Most notable first: none of these
## change hands quietly in real football.
func new_senior_coaches(year: int) -> Array:
	var out := []
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) != "club" or str(c.get("job", "")) != "SC" \
				or int(c.get("sc_since", 0)) != year:
			continue
		var club := str(c["club"])
		var before := _previous_senior_coach(club, year, str(cid))
		if before == "":
			out.append("%s: %s is the new senior coach." % [GameDB.club_name(club), GameDB.player_display_name(c)])
		else:
			out.append("%s: %s replaces %s as senior coach." % [GameDB.club_name(club),
					GameDB.player_display_name(c), before])
	out.sort()
	return out


func _previous_senior_coach(club: String, year: int, new_cid: String) -> String:
	for pool in [coaches, coach_archive]:
		for cid in pool:
			if str(cid) == new_cid:
				continue
			for stint in (pool[cid] as Dictionary).get("stints", []):
				if str(stint[0]) == club and str(stint[1]) == "SC" and int(stint[3]) == year - 1:
					return GameDB.player_display_name(pool[cid])
	return ""


static func _job_words(job: String) -> String:
	var label := str(Coaches.JOB_LABEL.get(job, job)).to_lower()
	return label if job == "SC" or job == "SA" else label + " coach"


## Why the board set this season's goal, in a sentence. It reads the list
## the club has assembled against the rest of the league.
func board_goal_reason() -> String:
	var rank := int(board.get("rank", 9))
	match str((board.get("goal", {}) as Dictionary).get("key", "")):
		"top4":
			return "One of the best lists in the competition, and top four last year: the board expects it again."
		"finals":
			return "The board rates this list among the best few in the competition." if rank <= 2 \
					else "The board sees a list good enough to play finals."
		"top12":
			return "The board sees a list in the middle of the pack."
	return "The board knows this list is still building."


## Mark the briefing read: the season can begin.
func begin_season_from_wrap() -> void:
	season_wrap["seen"] = true
	mark_dirty()
	autosave()


func needs_season_wrap() -> bool:
	return not season_wrap.is_empty() and not bool(season_wrap.get("seen", true)) \
			and int(season_wrap.get("year", 0)) == season_year


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
	Contracts.rookie_deal(p, season_year + 1)
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
	Workload.reset(lists)
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
	salary_cap = Contracts.salary_cap_for_year(season_year)
	ensure_contracts()
	# The coaching world from its Round 1 2026 source, carried into this
	# career's first season with you in your club's top job.
	coaches = Coaches.seed(my_club)
	_ensure_department_budget()
	if department_budget_year <= 0:
		department_budget_year = season_year
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
	_collect_others()
	pending_round_results = []
	# The coaching table first: the round's other matches use it (it is not
	# saved, so on the first live week after loading it would be empty).
	_refresh_coach_tactics()
	var round_matches: Array = season.fixture[season.round_index]
	var others := []
	for i in range(round_matches.size()):
		var m: Dictionary = round_matches[i]
		if m["home"] == my_club or m["away"] == my_club:
			pending_match = {"home": m["home"], "away": m["away"],
					"round": season.round_index + 1,
					"label": "Round %d" % (season.round_index + 1)}
		else:
			others.append(season.match_sim(m["home"], m["away"], season.next_seed(i)))
	if pending_match.is_empty():
		for res in Season.run_all(others):
			pending_round_results.append(res)
			season.record_regular(res)
		season.recalc_ladder()
		return false
	# The rest of the round plays out in the background while you coach
	# yours (none of it touches your match), and is collected at full time.
	_others = Season.start_all(others)
	var home := Squad.new(GameDB.club_name(str(pending_match["home"])),
			season.lists[pending_match["home"]], true, str(pending_match["home"]),
			season.selections.get(str(pending_match["home"]), {}))
	var away := Squad.new(GameDB.club_name(str(pending_match["away"])),
			season.lists[pending_match["away"]], false, str(pending_match["away"]),
			season.selections.get(str(pending_match["away"]), {}))
	home.form = season.club_form(str(pending_match["home"]))
	away.form = season.club_form(str(pending_match["away"]))
	CoachEffects.apply(home)
	CoachEffects.apply(away)
	pending_sim = MatchSim.new(home, away, season.next_seed(99))
	pending_sim.moment_side = 0 if str(pending_match["home"]) == my_club else 1
	pending_sim.set_tactics(pending_sim.moment_side, {"gameplan": club_plan})
	pending_sim.set_matchups(pending_sim.moment_side, my_matchups)
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
	_collect_others()
	pending_round_results = []
	var others := []
	var index := []
	for i in range(matches.size()):
		var m: Dictionary = matches[i]
		if i == mine or m["home"] == "" or m["away"] == "":
			continue
		others.append(season.match_sim(m["home"], m["away"], season.finals_seed(i),
				season.finals_at_home(m), true))
		index.append(i)
	_others = Season.start_all(others)
	_others["index"] = index
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
	pending_sim.set_matchups(pending_sim.moment_side, my_matchups)
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
	for r in _collect_others():
		r["round"] = res["round"]
		r["label"] = res["label"]
		pending_round_results.append(r)
		season.record_regular(r)
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
	_record_rivalries(played)
	_after_round(played)
	_clear_pending()
	autosave()


## Record the whole finals week in bracket order (your final included), then
## close the week exactly as a simulated week would.
func _finish_interactive_final(res: Dictionary) -> void:
	var matches := season.finals_week_matches()
	var index: Array = _others.get("index", [])
	var done := _collect_others()
	for j in range(done.size()):
		done[j]["finals_index"] = index[j]
		pending_round_results.append(done[j])
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
	_record_rivalries(played)
	_after_round(played)
	_clear_pending()
	autosave()


## The round's other matches, started when yours was set up: waits for any
## still running (usually none by full time) and hands them over once.
func _collect_others() -> Array:
	if _others.is_empty():
		return []
	var out := Season.finish_all(_others)
	_others = {}
	return out


func _clear_pending() -> void:
	_collect_others()      # never leave a worker running on dropped matches
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
	_record_rivalries(last_results)
	_after_round(last_results)
	autosave()
	return last_phase



## Feed completed league matches into the long-save rivalry history.
func _record_rivalries(results: Array) -> void:
	for res in results:
		if res is Dictionary:
			Rivalries.record_match(rivalry_history, res, season_year)


func rivalry_context(a: String, b: String) -> Dictionary:
	var fixed := Rivalries.established(a, b)
	if not fixed.is_empty():
		return {"state": "established", "title": str(fixed["name"]), "detail": ""}
	var state := Rivalries.state(rivalry_history, a, b)
	if state == "":
		return {}
	return {
		"state": state,
		"title": "Rivals" if state == "rivals" else "Rivalry brewing",
		"detail": Rivalries.context(rivalry_history, a, b),
	}


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


## This week's changes to your side, as a team sheet reads them:
## {"ins": [{"id", "for", "note"}], "outs": [{"id", "why"}]}. An "in" is paired
## with an "out" from the same line where there is one ("for"); "note" is
## "debut" or "first game this season" when it is. Empty before your first
## match.
func week_changes() -> Dictionary:
	var out := {"ins": [], "outs": []}
	if last_side.is_empty() or season == null:
		return out
	var side := current_side()
	var now := {}
	for k in side:
		for id in side[k]:
			now[str(id)] = true
	var was := {}
	for id in last_side:
		was[str(id)] = true
	var outs := []
	for id in last_side:
		if not now.has(str(id)):
			var p := list_player(str(id))
			if p.is_empty():
				continue  # traded or delisted since
			var why := "omitted"
			var suspended := int(p.get("suspension_weeks", 0))
			var wks := int(p.get("injury_weeks", 0))
			if suspended > 0:
				why = "suspended, %s" % ("1 wk" if suspended == 1 else "%d wks" % suspended)
			elif wks > 0:
				why = "injured, %s" % ("1 wk" if wks == 1 else "%d wks" % wks)
			elif bool(p.get("rested", false)):
				why = "rested"
			outs.append({"id": str(id), "why": why, "role": str(p.get("role", ""))})
	var free := outs.duplicate()
	for id in now:
		if was.has(id):
			continue
		var p := list_player(id)
		var pair := {}
		for o in free:
			if str(o["role"]) == str(p.get("role", "")):
				pair = o
				break
		if pair.is_empty() and not free.is_empty():
			pair = free[0]
		free.erase(pair)
		(out["ins"] as Array).append({"id": id, "for": str(pair.get("id", "")), "note": games_note(p)})
	for o in outs:
		(out["outs"] as Array).append({"id": o["id"], "why": o["why"]})
	return out


## "debut" for a player about to play his first senior game, "first game this
## season" for one yet to play this year (after round 1), else "".
func games_note(p: Dictionary) -> String:
	var this_year := int((season_tally.get(str(p.get("id", "")), {}) as Dictionary).get("games", 0))
	if this_year > 0:
		return ""
	var c := Career.of(p)
	if int(c.get("games", 0)) == 0 and (c.get("unknown", []) as Array).is_empty():
		return "debut"
	if season != null and season.round_index > 0:
		return "first game this season"
	return ""


## The team sheet line: "Ins: Jack Viney (for Ed Richards). Outs: Ed Richards
## (injured, 2 wks)." "" when the side is unchanged or has not played yet.
func week_changes_text() -> String:
	var ch := week_changes()
	var bits := PackedStringArray()
	var ins := PackedStringArray()
	for i in ch["ins"]:
		var extra := PackedStringArray()
		if str(i["note"]) != "":
			extra.append(str(i["note"]))
		if str(i["for"]) != "":
			extra.append("for " + GameDB.player_display_name(list_player(str(i["for"]))))
		var name := GameDB.player_display_name(list_player(str(i["id"])))
		ins.append(name + (" (%s)" % ", ".join(extra) if not extra.is_empty() else ""))
	var outs := PackedStringArray()
	for o in ch["outs"]:
		outs.append("%s (%s)" % [GameDB.player_display_name(list_player(str(o["id"]))), str(o["why"])])
	if not ins.is_empty():
		bits.append("Ins: " + ", ".join(ins) + ".")
	if not outs.is_empty():
		bits.append("Outs: " + ", ".join(outs) + ".")
	return " ".join(bits)


## Who in a side makes a game plan work, and how they compare with the
## league, in one line: "Your pressure players are strong: Viney, Oliver,
## Petracca, Brayshaw." Through stars names your best three and how far they
## stand above the rest. "" for Balanced.
func plan_fit_line(ground: Array, plan: String) -> String:
	if plan == "through_stars":
		var stars := PackedStringArray()
		for p in PlanFit.carriers(ground, plan):
			stars.append(GameDB.player_display_name(p))
		return "Your best three are %s: %s." % [PlanFit.stars_word(ground), ", ".join(stars)]
	if not PlanFit.NEEDS.has(plan):
		return ""
	var names := PackedStringArray()
	for p in PlanFit.carriers(ground, plan).slice(0, 4):
		names.append(GameDB.player_display_name(p))
	return "Your %s are %s: %s." % [str(PlanFit.NEEDS[plan]["word"]), PlanFit.fit_word(ground, plan), ", ".join(names)]


## What your list is good at against this league (ListProfile): every club's
## side as it would be picked this week, yours as you have picked it.
func list_profile() -> Array:
	if season == null or my_club == "":
		return []
	return ListProfile.profile(league_grounds(), my_club)


## Every club's match-day side this week, by code; yours as you have picked it.
func league_grounds() -> Dictionary:
	var grounds := {}
	for code in season.lists:
		if str(code) == my_club:
			grounds[my_club] = my_squad().ground
		else:
			grounds[str(code)] = Squad.new(str(code), season.lists[code], false, str(code),
					season.selections.get(code, {})).ground
	return grounds


## The plan a club's list suits as its usual game (PlanFit.standing_plan),
## from the side it would field this week.
func usual_plan(code: String) -> String:
	if season == null or code == "" or not season.lists.has(code):
		return "balanced"
	return PlanFit.standing_plan(Squad.new(code, season.lists[code], false, code,
			season.selections.get(code, {})).ground)


## This week's key match-ups against `opp`: [{"fwd": their forward, "def":
## your defender on him, "set": true when you chose it}], their key forwards
## first. [] without an opponent.
func week_matchups(opp: String) -> Array:
	if season == null or opp == "" or not season.lists.has(opp):
		return []
	var theirs: Array = Squad.new(opp, season.lists[opp], false, opp, season.selections.get(opp, {})).ground
	var mine: Array = my_squad().ground
	var d := Matchups.defaults(theirs, mine)
	var mine_ids := {}
	for p in mine:
		mine_ids[str(p["id"])] = p
	# Your choices, applied the way the match applies them (a swap).
	for fid in my_matchups:
		if not d.has(str(fid)) or not mine_ids.has(str(my_matchups[fid])):
			continue
		var want := str(my_matchups[fid])
		var had := str(d[fid])
		for other in d.keys():
			if str(d[other]) == want and str(other) != str(fid):
				d[other] = had
		d[fid] = want
	var out := []
	for f in Matchups.key_forwards(theirs):
		var fid := str(f["id"])
		if d.has(fid) and mine_ids.has(str(d[fid])):
			out.append({"fwd": f, "def": mine_ids[str(d[fid])], "set": my_matchups.has(fid)})
	return out


## Put your defender `def_id` on their forward `fwd_id` for the next match.
func set_my_matchup(fwd_id: String, def_id: String) -> void:
	my_matchups[fwd_id] = def_id
	_sync_club_plan()
	mark_dirty()



## Compact stored-fact history surfaces. These deliberately read existing
## records/honour_roll rather than reconstructing or inventing old seasons.
func history_record_lines() -> Array:
	var out := []
	var high: Dictionary = records.get("highest_score", {})
	if not high.is_empty():
		out.append("Highest score: %s — %d v %s (%d)" % [
				GameDB.club_name(str(high.get("club", ""))), int(high.get("value", 0)),
				GameDB.club_name(str(high.get("opp", ""))), int(high.get("year", 0))])
	var win: Dictionary = records.get("biggest_win", {})
	if not win.is_empty():
		out.append("Biggest win: %s by %d points v %s (%d)" % [
				GameDB.club_name(str(win.get("club", ""))), int(win.get("value", 0)),
				GameDB.club_name(str(win.get("opp", ""))), int(win.get("year", 0))])
	var goals: Dictionary = records.get("most_goals", {})
	if not goals.is_empty():
		var gp := _find_player(str(goals.get("id", "")))
		var gn := GameDB.player_display_name(gp) if not gp.is_empty() else str(goals.get("id", ""))
		out.append("Season goals: %s — %d (%d)" % [gn, int(goals.get("value", 0)), int(goals.get("year", 0))])
	var votes: Dictionary = records.get("most_votes", {})
	if not votes.is_empty():
		var vp := _find_player(str(votes.get("id", "")))
		var vn := GameDB.player_display_name(vp) if not vp.is_empty() else str(votes.get("id", ""))
		out.append("Brownlow votes: %s — %d (%d)" % [vn, int(votes.get("value", 0)), int(votes.get("year", 0))])
	return out


func recent_honours(limit := 5) -> Array:
	var out := []
	for i in range(honour_roll.size() - 1, -1, -1):
		var h: Dictionary = honour_roll[i]
		out.append(h)
		if out.size() >= limit:
			break
	return out

## Your own side's week worth knowing (Matchup.own_notes).
func my_week_notes() -> Array:
	return Matchup.own_notes(my_list) + milestone_notes()


## Games milestones worth marking (AFL convention: career games).
const MILESTONES := [50, 100, 150, 200, 250, 300, 350, 400]

## His senior games so far: the career record plus this season's games not
## yet closed into it.
func games_played(p: Dictionary) -> int:
	var c := Career.of(p)
	var g := int(c.get("games", 0))
	if int(c.get("through", 0)) < season_year:
		g += int((season_tally.get(str(p.get("id", "")), {}) as Dictionary).get("games", 0))
	return g


## "Jack Viney plays his 100th game." for anyone in this week's side about to
## reach a milestone. Only for a career on record in full.
func milestone_notes() -> Array:
	var out := []
	if season == null:
		return out
	var side := current_side()
	for k in side:
		for id in side[k]:
			var p := list_player(str(id))
			if p.is_empty() or not Career.complete(p):
				continue
			var next := games_played(p) + 1
			if MILESTONES.has(next):
				out.append({"key": "milestone", "player_id": str(id),
						"text": "%s plays his %s game." % [GameDB.player_display_name(p), ordinal(next)]})
	return out


## What he has done for your club: {"games", "goals", "since", "bf": [years],
## "flags": [years]}. Games and goals count every spell at the club, this
## season included; "since" is when his current spell began.
func with_us(p: Dictionary) -> Dictionary:
	var out := {"games": 0, "goals": 0, "since": 0, "bf": [], "flags": []}
	if my_club == "":
		return out
	var id := str(p.get("id", ""))
	var c := Career.of(p)
	var spells := []
	for st in c.get("stints", []):
		if str(st[0]) == my_club:
			out["games"] = int(out["games"]) + int(st[3])
			out["goals"] = int(out["goals"]) + int(st[4])
			spells.append([int(st[1]), int(st[2])])
	var t: Dictionary = season_tally.get(id, {})
	if int(c.get("through", 0)) < season_year and str(t.get("club", "")) == my_club:
		out["games"] = int(out["games"]) + int(t.get("games", 0))
		out["goals"] = int(out["goals"]) + int(t.get("goals", 0))
		if spells.is_empty() or int(spells[-1][1]) < season_year - 1:
			spells.append([season_year, season_year])
	if not spells.is_empty():
		out["since"] = int(spells[-1][0])
	for entry in honour_roll:
		if str(entry.get("my_club", "")) != my_club:
			continue
		var year := int(entry.get("year", 0))
		var bf: Array = entry.get("my_bf", [])
		if not bf.is_empty() and str((bf[0] as Dictionary).get("id", "")) == id:
			(out["bf"] as Array).append(year)
		if str(entry.get("premier", "")) == my_club:
			for sp in spells:
				if year >= int(sp[0]) and year <= int(sp[1]):
					(out["flags"] as Array).append(year)
					break
	return out


## "With us since 2027: 87 games, 42 goals. Best and fairest 2029.
## Premiership 2030." "" for someone yet to play for you.
func with_us_text(p: Dictionary) -> String:
	var w := with_us(p)
	if int(w["games"]) <= 0:
		return ""
	var g := int(w["games"])
	var gl := int(w["goals"])
	var bits := PackedStringArray(["With us since %d: %d game%s, %s." % [int(w["since"]), g,
			"" if g == 1 else "s", "no goals" if gl == 0 else "%d goal%s" % [gl, "" if gl == 1 else "s"]]])
	if not (w["bf"] as Array).is_empty():
		bits.append("Best and fairest %s." % ", ".join(PackedStringArray((w["bf"] as Array).map(func(y): return str(y)))))
	if not (w["flags"] as Array).is_empty():
		var f: Array = w["flags"]
		bits.append("%s %s." % ["Premiership" if f.size() == 1 else "Premierships",
				", ".join(PackedStringArray(f.map(func(y): return str(y))))])
	return " ".join(bits)


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
		if not coaches.is_empty():
			gain = int(round(float(gain) * CoachEffects.xp_mult(staff, p, on_ground)))
		if club == my_club and float(p.get("age", 25.0)) <= ClubBudget.YOUNG_AGE:
			gain = int(round(float(gain) * ClubBudget.development_mult(
					department_budget_level("development"))))
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
	if season != null:
		var regular := last_phase == "regular"
		var week := "%d|%s|%d" % [season_year, "R" if regular else "F",
				season.round_index if regular else (season.finals.get("weeks", []) as Array).size()]
		var recovery_mults := {}
		if my_club != "":
			recovery_mults[my_club] = ClubBudget.recovery_mult(
					department_budget_level("high_performance"))
		Workload.advance_week(season.lists, results, week, recovery_mults)
	_process_injuries(results)
	_process_discipline(results)
	for res in results:
		Awards.tally_match(season_tally, res, not res.has("tag"))
		_note_form_and_team(res)
	_round_news(results)
	_draft_class_news()
	_board_after_round(results)
	_prepare_media_conference(results)
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
		"brownlow": [season_awards["brownlow_winner"]] if not (season_awards.get("brownlow_winner", {}) as Dictionary).is_empty() else [],
		"coleman": (season_awards["coleman"] as Array).slice(0, 1),
		"rising_star": (season_awards["rising_star"] as Array).slice(0, 1),
		"coaches_award": (season_awards["coaches_award"] as Array).slice(0, 1),
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


## Live coaches award leaders: accumulated home-and-away coaches votes.
func coaches_award_leaders(n := 5) -> Array:
	var rows := []
	for id in season_tally:
		rows.append({"id": str(id), "club": str(season_tally[id]["club"]),
				"votes": int(season_tally[id].get("coaches", 0))})
	rows.sort_custom(func(a, b):
		if int(a["votes"]) != int(b["votes"]):
			return int(a["votes"]) > int(b["votes"])
		return str(a["id"]) < str(b["id"]))
	return rows.slice(0, n)


## After a round: every club that played is a week closer to getting its
## injured back, then this round's new injuries (from the matches) go on.
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
		last_injuries += Injuries.apply_match(res, season.lists, season.seed,
				int(res.get("round", season.round_index)))


## Suspensions count down when that player's club plays, then this round's
## MRO outcomes are applied. The incident outcome already came from MatchSim,
## so a reload cannot re-roll a suspension.
func _process_discipline(results: Array) -> void:
	if season == null:
		return
	last_mro = []
	var played := {}
	for res in results:
		for key in ["home", "away"]:
			var code := str(res.get(key, ""))
			if code == "" or played.has(code) or not season.lists.has(code):
				continue
			played[code] = true
			for p in season.lists[code]:
				var w := int(p.get("suspension_weeks", 0))
				if w > 0:
					p["suspension_weeks"] = w - 1
					if w - 1 <= 0:
						p.erase("suspension_weeks")
	for res in results:
		var codes := [str(res.get("home", "")), str(res.get("away", ""))]
		for row in res.get("reports", []):
			var item: Dictionary = (row as Dictionary).duplicate(true)
			var side := clampi(int(item.get("side", 0)), 0, 1)
			var code := codes[side]
			item["club"] = code
			last_mro.append(item)
			if str(item.get("outcome", "")) != "suspension" or not season.lists.has(code):
				continue
			for p in season.lists[code]:
				if str(p.get("id", "")) != str(item.get("id", "")):
					continue
				p["suspension_weeks"] = maxi(int(p.get("suspension_weeks", 0)),
						int(item.get("weeks", 0)))
				break


## Your club's MRO outcomes from the round, in football language.
func my_mro_lines() -> Array:
	var out := []
	for row in last_mro:
		if str(row.get("club", "")) != my_club:
			continue
		var p := list_player(str(row.get("id", "")))
		var name := str(row.get("name", "")) if p.is_empty() else GameDB.player_display_name(p)
		match str(row.get("outcome", "")):
			"suspension":
				var w := int(row.get("weeks", 0))
				out.append("%s suspended for %d match%s" % [name, w, "" if w == 1 else "es"])
			"fine":
				out.append("%s fined for %s" % [name, str(row.get("reason", "rough conduct"))])
	return out


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
## Everyone on a list has a contract, and every club works to the same
## season cap. The first playable season is anchored to the real 2027 TPP
## limit; later game-world seasons use Contracts.salary_cap_for_year().
func ensure_contracts() -> void:
	if season == null:
		return
	for code in season.lists:
		Contracts.assign_initial(season.lists[code])
	if salary_cap <= 0:
		salary_cap = Contracts.salary_cap_for_year(season_year)


func my_payroll() -> int:
	return Contracts.payroll(my_list)


func cap_room() -> int:
	return salary_cap - my_payroll()


# ---------------------------------------------------------------------------
# Annual club department budget
# ---------------------------------------------------------------------------
func _ensure_department_budget() -> void:
	var clean := ClubBudget.defaults()
	for area in ClubBudget.AREA_ORDER:
		clean[area] = ClubBudget.clamp_level(int(department_budget.get(area, ClubBudget.STANDARD)))
	department_budget = clean


func department_budget_level(area: String) -> int:
	_ensure_department_budget()
	return int(department_budget.get(area, ClubBudget.STANDARD))


func department_budget_spent_m() -> float:
	_ensure_department_budget()
	return ClubBudget.total_m(department_budget)


func department_budget_remaining_m() -> float:
	return ClubBudget.ANNUAL_M - department_budget_spent_m()


func can_set_department_budget(area: String, level: int) -> bool:
	if not ClubBudget.valid_area(area) or level < 0 or level >= ClubBudget.LEVELS.size():
		return false
	_ensure_department_budget()
	var trial: Dictionary = department_budget.duplicate()
	trial[area] = level
	return ClubBudget.total_m(trial) <= ClubBudget.ANNUAL_M + 0.001


## Set one department for the coming season. The allocation can only be
## changed while the off-season market is open; once the National Draft starts
## it is locked for that football year.
func set_department_budget(area: String, level: int) -> Dictionary:
	if not offseason_open():
		return {"ok": false, "reason": "Department funding is set during the off-season."}
	if not ClubBudget.valid_area(area) or level < 0 or level >= ClubBudget.LEVELS.size():
		return {"ok": false, "reason": "Unknown funding level."}
	if not can_set_department_budget(area, level):
		return {"ok": false, "reason": "That allocation would exceed the $%.1fm annual club budget." % ClubBudget.ANNUAL_M}
	department_budget[area] = level
	department_budget_year = season_year + 1
	mark_dirty()
	return {"ok": true}


func recruiting_uncertainty_mult() -> float:
	return ClubBudget.scouting_mult(department_budget_level("recruiting"))


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
	# The board funds a fresh operating year. Last season's choices do not
	# become permanent upgrades or compound into a tech tree.
	department_budget = ClubBudget.defaults()
	department_budget_year = season_year + 1
	offseason_log = []
	compensation = []
	offseason_staff = Coaches.staff(coaches, my_club) if not coaches.is_empty() else {}
	free_agents = []
	for code in season.lists:
		if code == my_club:
			continue
		var list: Array = season.lists[code]
		for p in Contracts.expiring(list).duplicate():
			var why := Contracts.ai_release_reason(p, list, salary_cap)
			if why == "" or list.size() <= Contracts.MIN_LIST:
				# Rivals bargain by the same rules: the least he takes for that term.
				var years := Contracts.ai_years(p)
				_resign(p, years, Contracts.lowest(p, years))
			else:
				# A player they wanted but could not fit can earn them a pick;
				# one they delisted cannot.
				_release(code, p, why == "cap")
	# The market opens: rivals put their offers on the table.
	market_stats = {}
	_open_market(free_agents)
	mark_dirty()


## Re-sign for `years` more seasons at `salary` (his asking price when not
## given). The contract ticks at the rollover, so it is stored as years + 1.
func _resign(p: Dictionary, years: int, salary := -1) -> void:
	p["salary"] = salary if salary > 0 else Contracts.asking_salary(p)
	p["contract_years"] = years + 1
	p["resigned"] = true
	p.erase("talks")


## Off a list and into free agency. `wanted`: the club wanted him (he walked,
## or it could not fit his price) rather than delisting him, so losing him
## can earn a compensation pick - if he had been there long enough.
func _release(code: String, p: Dictionary, wanted := false) -> void:
	(season.lists[code] as Array).erase(p)
	p["released_by"] = code
	p["comp_eligible"] = wanted and comp_tenure_ok(p)
	p["contract_years"] = 0
	free_agents.append(p)
	offseason_log.append({"kind": "released", "club": code, "id": str(p["id"]), "wanted": wanted,
			"eligible": bool(p["comp_eligible"])})
	if int(p.get("overall", 0)) >= NEWS_MIN_OVR:
		add_news("contract", "%s let %s (OVR %d) go to free agency." % [
				GameDB.club_name(code), GameDB.player_display_name(p), int(p["overall"])])


## Your expiring player at his asking price for `years` seasons. It is
## still an offer: a shorter term than he wants gets a counter.
func resign_player(player_id: String, years: int) -> Dictionary:
	var p := list_player(player_id)
	return offer_contract(player_id, Contracts.asking_salary(p) if not p.is_empty() else 0, years)


## Where talks with your expiring player stand: {} before any offer, else
## {"failed", "counter", "years", "walked"}. Kept on the player, so a save
## and load picks the talks up where they were. Nothing is signed until he
## accepts.
func contract_talks(player_id: String) -> Dictionary:
	return list_player(player_id).get("talks", {})


## Offer your expiring player `salary` a season for `years` seasons. Returns
## {"ok", "answer": "accept" | "counter" | "walk" | "", "salary", "reason"}.
## The cap is checked first, so an offer you cannot afford costs nothing.
func offer_contract(player_id: String, salary: int, years: int) -> Dictionary:
	var p := list_player(player_id)
	if not p.is_empty() and bool(p.get("resigned", false)):
		return {"ok": false, "answer": "", "reason": "He has already re-signed."}
	if p.is_empty() or not offseason_open() or not Contracts.expiring(my_list).has(p):
		return {"ok": false, "answer": "", "reason": "Contracts can only be settled in the off-season."}
	var talks: Dictionary = p.get("talks", {})
	if bool(talks.get("walked", false)):
		return {"ok": false, "answer": "walk", "reason": "Talks have broken down: he will test free agency."}
	years = clampi(years, 1, Contracts.MAX_YEARS)
	salary = maxi(Contracts.SENIOR_MIN_2027, salary)
	if my_payroll() - int(p.get("salary", 0)) + salary > salary_cap:
		return {"ok": false, "answer": "", "reason": "Not enough cap room for %s a season." % Contracts.money(salary)}
	var name := GameDB.player_display_name(p)
	var reply := Contracts.respond(p, salary, years, int(talks.get("failed", 0)))
	var out := {"ok": false, "answer": str(reply["answer"]), "salary": int(reply["salary"])}
	match str(reply["answer"]):
		"accept":
			_resign(p, years, salary)
			out["ok"] = true
			out["reason"] = "%s re-signs for %d season%s at %s." % [name, years, "" if years == 1 else "s", Contracts.money(salary)]
		"counter":
			talks["failed"] = int(talks.get("failed", 0)) + (2 if bool(reply["insult"]) else 1)
			talks["counter"] = int(reply["salary"])
			talks["years"] = years
			p["talks"] = talks
			out["reason"] = ("He's insulted. " if bool(reply["insult"]) else "") + \
					"He'd sign for %s a season over %d season%s." % [Contracts.money(int(reply["salary"])), years, "" if years == 1 else "s"]
		"walk":
			talks["walked"] = true
			p["talks"] = talks
			out["reason"] = "Talks have broken down: %s will test free agency." % name
	if bool(reply["insult"]):
		ClubLife.add_morale(p, -5)
	mark_dirty()
	return out


func release_player(player_id: String) -> Dictionary:
	var p := list_player(player_id)
	if p.is_empty() or not offseason_open():
		return {"ok": false, "reason": "Players can only be released in the off-season."}
	if my_list.size() <= Contracts.MIN_LIST:
		return {"ok": false, "reason": "Your list cannot go below %d." % Contracts.MIN_LIST}
	_release(my_club, p, false)
	_open_market([p])
	mark_dirty()
	return {"ok": true, "reason": "%s released." % GameDB.player_display_name(p)}


## A free agent at his asking price for `years` seasons. Still an offer: he
## weighs it like any other (offer_free_agent).
func sign_free_agent(player_id: String, years: int) -> Dictionary:
	var p := free_agent(player_id)
	return offer_free_agent(player_id, Contracts.asking_salary(p) if not p.is_empty() else 0, years)


func free_agent(player_id: String) -> Dictionary:
	for q in free_agents:
		if str(q["id"]) == player_id:
			return q
	return {}


## Would he turn you down flat? Only when he would not make your best 22
## and a club that would play him has an offer on the table.
func free_agent_terms(player_id: String) -> Dictionary:
	var p := free_agent(player_id)
	if p.is_empty() or season == null:
		return {"premium": 0, "refuse": false, "reasons": []}
	var rivals := 0
	for o in p.get("offers", []):
		if str(o["club"]) != my_club and not bool(o.get("withdrawn", false)) and str(o.get("role", "depth")) != "depth":
			rivals += 1
	return Contracts.free_agent_terms(p, {"in_best22": fa_role(p, my_club) != "depth", "rivals": rivals})


# ---------------------------------------------------------------------------
# The free-agent market (Contracts has the rules). Offers live on the free
# agent ("offers": [{"club", "salary", "years", "role", "finish_t",
# "withdrawn"}], "market_round": your offers rivals have answered,
# "market_log": the last responses), so a save keeps every offer and no
# reload can change who he picks.
# ---------------------------------------------------------------------------
var _bars := {}   # code -> positional selection bars, for one market pass
## Rival actions this off-season (improve, match, hold, withdraw), for
## measurement; not saved.
var market_stats := {}
var _targets_signed := {}   # code -> targets signed while free agency closes


## His role at `code`: "ground" (in its best 18), "bench" (in its 22) or
## "depth". The club's real selection sets the bar in each position: he is
## a starter if he beats its weakest starter in his position (or his second
## one), on the bench if he beats its weakest bench player.
func fa_role(p: Dictionary, code: String) -> String:
	if not _bars.has(code):
		_bars[code] = _selection_bars(season.lists.get(code, []))
	var bars: Dictionary = _bars[code]
	var ovr := int(p.get("overall", 0))
	for r in [str(p.get("role", "")), str(p.get("role2", ""))]:
		if r != "" and ovr > int(bars.get(r, 0)):
			return "ground"
	return "bench" if ovr > int(bars.get("bench", 0)) else "depth"


func _selection_bars(list: Array) -> Dictionary:
	var side := Ratings.select_22(list)
	var bars := {}
	for q in side["ground"]:
		var r := str(q["role"])
		bars[r] = mini(int(bars.get(r, 999)), int(q["overall"]))
	var bench := 999
	for q in side["bench"]:
		bench = mini(bench, int(q["overall"]))
	bars["bench"] = bench if bench < 999 else 0
	return bars


## 0 for last year's premiers ... 1 for the wooden spoon.
func _finish_t(code: String) -> float:
	var table := season.ladder_sorted()
	for k in range(table.size()):
		if str(table[k]["code"]) == code:
			return float(k) / float(maxi(1, table.size() - 1))
	return 1.0


func _cap_room_of(code: String) -> int:
	return salary_cap - Contracts.payroll(season.lists.get(code, []))


func _offer_of(p: Dictionary, code: String) -> Dictionary:
	for o in p.get("offers", []):
		if str(o["club"]) == code:
			return o
	return {}


## Rivals put offers on the table for `players`. Each club goes after the
## free agents who would improve its side most - up to two it would play
## (in its best 22: the furthest above its bar in their position first) -
## plus one depth signing per spot it is short of its usual list size, best
## players first by what everyone can see (rating, then age). Only with the
## cap room, never the club that let him go, never by a club's place in any
## list.
const FA_TARGETS := 2
## Places in the side by position, for spotting the thinnest part of a list.
const FILL_SHARE := {"RUCK": 1, "MID": 7, "DEF": 5, "FWD": 5}
const FILLER_CAP := 3


func _open_market(players: Array) -> void:
	_bars = {}
	var depth_held := {}
	var targets_held := {}
	for q in free_agents:
		for o in q.get("offers", []):
			if bool(o.get("withdrawn", false)):
				continue
			var held := depth_held if bool(o.get("filler", false)) else targets_held
			held[str(o["club"])] = int(held.get(str(o["club"]), 0)) + 1
	var ranked := players.duplicate()
	ranked.sort_custom(func(a, b):
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		if float(a.get("age", 25.0)) != float(b.get("age", 25.0)):
			return float(a.get("age", 25.0)) < float(b.get("age", 25.0))
		return str(a["id"]) < str(b["id"]))
	var clubs := []
	for code in GameDB.active_clubs(season_year):
		if code != my_club and season.lists.has(code) and (season.lists[code] as Array).size() < Contracts.MAX_LIST:
			clubs.append(code)
	# Every club picks its targets first, independently of the others.
	for code in clubs:
		var room := _cap_room_of(code)
		var aims := FA_TARGETS - int(targets_held.get(code, 0)) - int(_targets_signed.get(code, 0))
		var ft := _finish_t(code)
		var wanted := []
		for p in ranked:
			if str(p.get("released_by", "")) != code and _offer_of(p, code).is_empty() and fa_role(p, code) != "depth":
				wanted.append(p)
		wanted.sort_custom(func(a, b):
			var ga := _gain(a, code)
			var gb := _gain(b, code)
			if ga != gb:
				return ga > gb
			return ranked.find(a) < ranked.find(b))
		for p in wanted:
			if aims <= 0:
				break
			var role := fa_role(p, code)
			var open := Contracts.opening_offer(p, role)
			if int(open["salary"]) > Contracts.club_max(p, role, room):
				continue
			aims -= 1
			_add_offer(p, code, open, role, ft)
	# Then list fillers, among the players no club has targeted, so depth
	# signings don't pile onto the market's best players.
	var targeted := {}
	for p in free_agents:
		for o in p.get("offers", []):
			if not bool(o.get("filler", false)) and not bool(o.get("withdrawn", false)):
				targeted[str(p["id"])] = true
	_place_fillers(clubs, ranked, targeted, depth_held)


## List fillers: each club short of its usual list size fills the position it
## is thinnest in (players per place in the side), best free agent there
## first. At most three fillers per player: when more clubs want him, the
## ones thinnest in his position keep their offers (a lower finish first on a
## tie) and the rest move to their next choice. All clubs choose at once, so
## no club's turn comes first.
func _place_fillers(clubs: Array, ranked: Array, targeted: Dictionary, depth_held: Dictionary) -> void:
	var spots := {}
	var counts := {}
	var closed := {}     # code -> {player id: true} it was bumped from or has
	var holders := {}    # player id -> [codes]
	for code in clubs:
		var list: Array = season.lists[code]
		spots[code] = Contracts.AI_FILL - list.size() - int(depth_held.get(code, 0))
		var c := {}
		for q in list:
			var r := str(q.get("role", ""))
			c[r] = int(c.get(r, 0)) + 1
		counts[code] = c
		closed[code] = {}
	for _round in range(60):
		var proposals := {}
		for code in clubs:
			if int(spots[code]) <= 0:
				continue
			var pick := _filler_choice(code, ranked, targeted, counts[code], closed[code])
			if pick.is_empty():
				spots[code] = 0
				continue
			var id := str(pick["id"])
			if not proposals.has(id):
				proposals[id] = []
			(proposals[id] as Array).append(code)
		if proposals.is_empty():
			break
		for id in proposals:
			var p := free_agent(str(id))
			var all: Array = (holders.get(id, []) as Array) + (proposals[id] as Array)
			all.sort_custom(func(a, b):
				var na := _thinness(counts[a], p)
				var nb := _thinness(counts[b], p)
				if na != nb:
					return na < nb
				return _finish_t(a) > _finish_t(b))
			var before: Array = holders.get(id, [])
			holders[id] = all.slice(0, FILLER_CAP)
			for code in before:
				if not (holders[id] as Array).has(code):
					# Bumped by a club thinner in his position: the spot is free
					# again.
					spots[code] = int(spots[code]) + 1
					counts[code][str(p.get("role", ""))] = int(counts[code].get(str(p.get("role", "")), 1)) - 1
			for code in all:
				closed[code][id] = true
				if (holders[id] as Array).has(code) and (proposals[id] as Array).has(code):
					spots[code] = int(spots[code]) - 1
					counts[code][str(p.get("role", ""))] = int(counts[code].get(str(p.get("role", "")), 0)) + 1
	for id in holders:
		var p := free_agent(str(id))
		for code in holders[id]:
			# A list filler: priced as depth, though he still weighs the role
			# he would have there.
			_add_offer(p, code, Contracts.opening_offer(p, "depth"), fa_role(p, code), _finish_t(code), true)


## How thin `counts` (a club's players by position) is where he plays:
## players per place in the side, the lower of his positions.
func _thinness(counts: Dictionary, p: Dictionary) -> float:
	var best := 999.0
	for r in [str(p.get("role", "")), str(p.get("role2", ""))]:
		if FILL_SHARE.has(r):
			best = minf(best, float(counts.get(r, 0)) / float(FILL_SHARE[r]))
	return best


## The free agent a club would fill its next spot with: the best one in its
## thinnest position, else the best one it can afford at all.
func _filler_choice(code: String, ranked: Array, targeted: Dictionary, counts: Dictionary, closed: Dictionary) -> Dictionary:
	var need := ""
	for r in FILL_SHARE:
		if need == "" or float(counts.get(r, 0)) / float(FILL_SHARE[r]) < float(counts.get(need, 0)) / float(FILL_SHARE[need]):
			need = r
	var room := _cap_room_of(code)
	for any in [false, true]:
		for p in ranked:
			var id := str(p["id"])
			if targeted.has(id) or closed.has(id) or str(p.get("released_by", "")) == code or not _offer_of(p, code).is_empty():
				continue
			if not any and str(p.get("role", "")) != need and str(p.get("role2", "")) != need:
				continue
			if int(Contracts.opening_offer(p, "depth")["salary"]) > Contracts.club_max(p, "depth", room):
				continue
			return p
	return {}


## How far above `code`'s bar he is in his best position: what signing him
## adds to its side.
func _gain(p: Dictionary, code: String) -> int:
	var bars: Dictionary = _bars.get(code, {})
	var ovr := int(p.get("overall", 0))
	var best := ovr - int(bars.get("bench", 0))
	for r in [str(p.get("role", "")), str(p.get("role2", ""))]:
		if r != "" and bars.has(r):
			best = maxi(best, ovr - int(bars[r]))
	return best


func _add_offer(p: Dictionary, code: String, open: Dictionary, role: String, ft: float, filler := false) -> void:
	if not p.has("offers"):
		p["offers"] = []
	var o := {"club": code, "salary": int(open["salary"]), "years": int(open["years"]), "role": role, "finish_t": ft}
	if filler:
		o["filler"] = true
	(p["offers"] as Array).append(o)


## The most `o`'s club will pay him: by his role there, or only his lowest
## for a list filler; never past its cap room.
func offer_max(p: Dictionary, o: Dictionary) -> int:
	var room := _cap_room_of(str(o["club"]))
	if bool(o.get("filler", false)):
		return Contracts.club_max(p, "depth", room)
	return Contracts.club_max(p, str(o.get("role", "depth")), room)


## Rivals behind `leader` answer it once, all at the same moment, so no
## club's turn comes first. Returns sentences such as "Carlton improve: 8
## for 3 seasons." and "Brisbane, Sydney and 3 more withdraw."
func _rival_round(p: Dictionary, leader: Dictionary) -> Array:
	var lines := []
	var moves := []
	for o in p.get("offers", []):
		if o == leader or str(o["club"]) == my_club or bool(o.get("withdrawn", false)):
			continue
		var most := offer_max(p, o)
		moves.append([o, Contracts.rival_response(p, o, leader, most)])
	var gone := []
	var held := []
	for m in moves:
		var o: Dictionary = m[0]
		var r: Dictionary = m[1]
		market_stats[str(r["action"])] = int(market_stats.get(str(r["action"]), 0)) + 1
		var name := GameDB.club_name(str(o["club"]))
		match str(r["action"]):
			"improve", "match":
				o["salary"] = int(r["salary"])
				o["years"] = int(r["years"])
				lines.append("%s %s: %d for %d season%s." % [name, "improve" if str(r["action"]) == "improve" else "match",
						int(r["salary"]), int(r["years"]), "" if int(r["years"]) == 1 else "s"])
			"withdraw":
				o["withdrawn"] = true
				gone.append(name)
			"hold":
				held.append(name)
	if not gone.is_empty():
		lines.append("%s withdraw%s." % [_name_list(gone), "s" if gone.size() == 1 else ""])
	if not held.is_empty():
		lines.append("%s hold%s." % [_name_list(held), "s" if held.size() == 1 else ""])
	return lines


## "Brisbane", "Brisbane and Sydney", "Brisbane, Sydney and 4 more".
func _name_list(names: Array) -> String:
	if names.size() == 1:
		return str(names[0])
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	return "%s, %s and %d more" % [names[0], names[1], names.size() - 2]


## The offers on the table for a free agent, best first for him, each with
## his view of it in words: [{"club", "name", "salary", "years", "view",
## "leading", "mine"}].
func fa_offers(player_id: String) -> Array:
	var p := free_agent(player_id)
	var standing := []
	for o in p.get("offers", []):
		if not bool(o.get("withdrawn", false)):
			standing.append(o)
	standing.sort_custom(func(a, b): return Contracts.prefers(p, a, b))
	var out := []
	for i in range(standing.size()):
		var o: Dictionary = standing[i]
		var other: Dictionary = standing[1] if i == 0 and standing.size() > 1 else (standing[0] if i > 0 else {})
		var club_name := GameDB.club_name(str(o["club"]))
		var view := Contracts.offer_view(p, o, other, club_name)
		if i > 0 and view != "":
			view = "Behind, though: " + view.left(1).to_lower() + view.substr(1)
		elif i > 0:
			view = "Behind."
		out.append({"club": str(o["club"]), "name": club_name, "salary": int(o["salary"]), "years": int(o["years"]),
				"view": view, "leading": i == 0, "mine": str(o["club"]) == my_club})
	return out


## Where his market stands for you: "open" (you can make an offer), "final"
## (one more, your last), "closed" (you have made your final offer).
func fa_market_stage(player_id: String) -> String:
	var n := int(free_agent(player_id).get("market_round", 0))
	return "closed" if n >= Contracts.FA_ROUNDS else ("final" if n == Contracts.FA_ROUNDS - 1 else "open")


## Offer a free agent `salary` a season for `years` seasons. Below his lowest
## price he counters, as your own players do. At or above it, your offer goes
## on the table: if nobody else has offered he signs; otherwise the rivals
## you have overtaken answer once (improve, match, hold or withdraw). Your
## second offer is your final one: rivals answer, then he chooses. Untouched,
## he chooses when free agency closes. Cap room alone never signs anyone.
## Returns {"ok", "answer": "signed" | "table" | "lost" | "counter" | "walk" |
## "reject" | "", "salary", "reason", "responses": [lines]}.
func offer_free_agent(player_id: String, salary: int, years: int) -> Dictionary:
	if not offseason_open():
		return {"ok": false, "answer": "", "reason": "Free agency is only open in the off-season."}
	var p := free_agent(player_id)
	if p.is_empty():
		return {"ok": false, "answer": "", "reason": "He has already signed elsewhere."}
	if my_list.size() >= Contracts.MAX_LIST:
		return {"ok": false, "answer": "", "reason": "Your list is full (%d)." % Contracts.MAX_LIST}
	var talks: Dictionary = p.get("talks", {})
	if bool(talks.get("walked", false)):
		return {"ok": false, "answer": "walk", "reason": "He has stopped talking to you."}
	if int(p.get("market_round", 0)) >= Contracts.FA_ROUNDS:
		return {"ok": false, "answer": "", "reason": "You have made your final offer."}
	years = clampi(years, 1, Contracts.MAX_YEARS)
	salary = maxi(Contracts.SENIOR_MIN_2027, salary)
	var name := GameDB.player_display_name(p)
	var terms := free_agent_terms(player_id)
	if bool(terms["refuse"]):
		return {"ok": false, "answer": "reject", "reason": "%s turns you down. %s" % [name, str(terms["reasons"][0])]}
	if salary > cap_room():
		return {"ok": false, "answer": "", "reason": "Not enough cap room for %d a season." % salary}
	var reply := Contracts.respond(p, salary, years, int(talks.get("failed", 0)))
	if str(reply["answer"]) != "accept":
		var out := {"ok": false, "answer": str(reply["answer"]), "salary": int(reply["salary"])}
		if str(reply["answer"]) == "counter":
			talks["failed"] = int(talks.get("failed", 0)) + (2 if bool(reply["insult"]) else 1)
			talks["counter"] = int(reply["salary"])
			talks["years"] = years
			p["talks"] = talks
			out["reason"] = ("He's insulted. " if bool(reply["insult"]) else "") + \
					"He'd want at least %s a season over %d season%s." % [Contracts.money(int(reply["salary"])), years, "" if years == 1 else "s"]
		else:
			talks["walked"] = true
			p["talks"] = talks
			out["reason"] = "Talks have broken down: %s will look elsewhere." % name
		mark_dirty()
		return out
	# A real offer: on the table, beside any rival's.
	_bars = {}
	var mine := _offer_of(p, my_club)
	if mine.is_empty():
		mine = {"club": my_club}
		if not p.has("offers"):
			p["offers"] = []
		(p["offers"] as Array).append(mine)
	mine["salary"] = salary
	mine["years"] = years
	mine["role"] = fa_role(p, my_club)
	mine["finish_t"] = _finish_t(my_club)
	var rivals_left := false
	for o in p["offers"]:
		if str(o["club"]) != my_club and not bool(o.get("withdrawn", false)):
			rivals_left = true
	if not rivals_left:
		_sign_fa(p, my_club, salary, years)
		mark_dirty()
		return {"ok": true, "answer": "signed", "salary": salary,
				"reason": "%s signs for %d season%s at %s." % [name, years, "" if years == 1 else "s", Contracts.money(salary)], "responses": []}
	p["market_round"] = int(p.get("market_round", 0)) + 1
	var lines := []
	var leader := Contracts.best_offer(p, p["offers"])
	if leader == mine:
		# Only the clubs you have overtaken answer - they see your offer once
		# it is made, never before.
		lines = _rival_round(p, mine)
	p["market_log"] = lines
	var out := {"ok": true, "answer": "table", "salary": salary, "responses": lines}
	if int(p["market_round"]) >= Contracts.FA_ROUNDS:
		var club := _decide_fa(p)
		out["answer"] = "signed" if club == my_club else "lost"
		out["ok"] = club == my_club
		out["reason"] = ("%s signs with you: %s for %d season%s." % [name, Contracts.money(salary), years, "" if years == 1 else "s"]) if club == my_club \
				else "%s chooses %s." % [name, GameDB.club_name(club)] if club != "" else "%s stays on the market." % name
	else:
		var lead := Contracts.best_offer(p, p["offers"])
		out["reason"] = "Your offer leads." if lead == mine else "%s's offer leads." % GameDB.club_name(str(lead["club"]))
	mark_dirty()
	return out


## He picks among the standing offers his suitors can still honour (a spot on
## the list, the cap room). Returns the club he signs with, or "".
func _decide_fa(p: Dictionary) -> String:
	var valid := []
	for o in p.get("offers", []):
		if bool(o.get("withdrawn", false)):
			continue
		var code := str(o["club"])
		var list: Array = season.lists.get(code, [])
		if list.size() >= Contracts.MAX_LIST or int(o["salary"]) > _cap_room_of(code):
			continue
		if code != my_club and bool(o.get("filler", false)) and list.size() >= Contracts.AI_FILL:
			continue
		valid.append(o)
	var best := Contracts.best_offer(p, valid)
	if best.is_empty():
		return ""
	if not bool(best.get("filler", false)) and str(best["club"]) != my_club:
		_targets_signed[str(best["club"])] = int(_targets_signed.get(str(best["club"]), 0)) + 1
	_sign_fa(p, str(best["club"]), int(best["salary"]), int(best["years"]))
	return str(best["club"])


## He joins `code` on the contract he chose; his old club's compensation (if
## any) comes from this contract.
func _sign_fa(p: Dictionary, code: String, salary: int, years: int) -> void:
	_record_departure(p, code, salary, years)
	_join(code, p)
	_resign(p, years, salary)
	p.erase("offers")
	p.erase("market_round")
	p.erase("market_log")
	free_agents.erase(p)
	_bars.erase(code)
	offseason_log.append({"kind": "signed", "club": code, "id": str(p["id"]), "salary": salary, "years": years})
	if code == my_club or int(p.get("overall", 0)) >= NEWS_MIN_OVR:
		add_news("contract", "%s sign free agent %s (OVR %d): %d for %d season%s." % [GameDB.club_name(code),
				GameDB.player_display_name(p), int(p["overall"]), salary, years, "" if years == 1 else "s"])


func _join(code: String, p: Dictionary) -> void:
	var list: Array = season.lists[code]
	if str(p.get("club", "")) != code:
		p["joined"] = season_year
	p["club"] = code
	p["num"] = _next_jumper_number(list)
	p.erase("train_plan")
	p.erase("released_by")
	p.erase("comp_eligible")
	list.append(p)


## Has he been at his club long enough for losing him to earn a pick? Two
## seasons: a player signed cheaply cannot be flipped straight into a pick.
## Players from the original lists and draftees have no join year and count
## as long-serving.
func comp_tenure_ok(p: Dictionary) -> bool:
	return not p.has("joined") or season_year - int(p["joined"]) >= Contracts.COMP_TENURE


## A free agent signs with `to`: if his old club wanted him and he had been
## there long enough, it gets a compensation pick placed by the contract he
## signed. Same rule for every club.
func _record_departure(p: Dictionary, to: String, salary: int, years: int) -> void:
	var from := str(p.get("released_by", ""))
	if from == "" or from == to or not bool(p.get("comp_eligible", false)):
		return
	var clubs := GameDB.active_clubs(season_year).size()
	var value := Contracts.compensation_value(p, salary, years)
	var after := Contracts.compensation_after(value, clubs)
	if after <= 0:
		return
	for c in compensation:
		if str(c["player"]) == str(p["id"]):
			return
	compensation.append({"club": from, "player": str(p["id"]), "name": GameDB.player_display_name(p),
			"to": to, "salary": salary, "years": years, "value": snappedf(value, 0.01), "after": after})
	offseason_log.append({"kind": "compensation", "club": from, "id": str(p["id"]), "after": after})
	add_news("contract", "%s receive a draft pick %s for losing %s to %s." % [GameDB.club_name(from),
			Contracts.pick_words(after, clubs), GameDB.player_display_name(p), GameDB.club_name(to)])


## What losing your out-of-contract player would bring if he signed a
## rival's usual deal: {"after", "words", "reason"}; after 0 = no pick.
func projected_compensation(p: Dictionary) -> Dictionary:
	var clubs := GameDB.active_clubs(season_year).size()
	if not comp_tenure_ok(p):
		return {"after": 0, "words": "", "reason": "He hasn't been here two seasons, so losing him earns no pick."}
	var years := Contracts.ai_years(p)
	var after := Contracts.compensation_after(Contracts.compensation_value(p, Contracts.lowest(p, years), years), clubs)
	if after <= 0:
		return {"after": 0, "words": "", "reason": "Losing him wouldn't earn a draft pick."}
	return {"after": after, "words": Contracts.pick_words(after, clubs),
			"reason": "If he signs elsewhere, expect a pick around %s." % Contracts.pick_words(after, clubs)}


# ---------------------------------------------------------------------------
# Draft picks as trade assets
# ---------------------------------------------------------------------------
## Rounds of a draft that can be traded: deeper picks rarely matter.
const TRADE_PICK_ROUNDS := 3


## The draft years whose picks can be traded now, while the off-season is
## open: this year's national draft and next year's.
func trade_pick_years() -> Array:
	return [season_year, season_year + 1] if offseason_open() else []


func pick_id(year: int, rnd: int, origin: String) -> String:
	return "pick:%d:%d:%s" % [year, rnd, origin]


func pick_owner_of(year: int, rnd: int, origin: String) -> String:
	return str(pick_owner.get("%d:%d:%s" % [year, rnd, origin], origin))


## A pick as a trade asset, or {} if the id isn't a tradeable pick: {"pick",
## "id", "year", "round", "origin", "owner", "positions", "name"}. This year's
## spot is exact - the season is over, the order is the reversed ladder.
func pick_asset(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() != 4 or parts[0] != "pick":
		return {}
	var year := int(parts[1])
	var rnd := int(parts[2])
	var origin := str(parts[3])
	if not trade_pick_years().has(year) or rnd < 1 or rnd > trade_pick_rounds(year) \
			or not GameDB.active_clubs(season_year).has(origin) or not GameDB.active_clubs(year).has(origin):
		return {}
	var positions := [[draft_spot(year, rnd, origin), 1.0]] if year == season_year else future_spots(rnd, origin)
	return {"pick": true, "id": id, "year": year, "round": rnd, "origin": origin,
			"owner": pick_owner_of(year, rnd, origin), "positions": positions,
			"name": _pick_name(year, rnd, origin, int(positions[0][0]) if year == season_year else 0)}


## The overall pick a club's pick in `rnd` will be in this year's national
## draft: the reversed ladder, snaking back each round.
func draft_spot(year: int, rnd: int, origin: String) -> int:
	var order := []
	for row in season.ladder_sorted():
		order.append(str(row["code"]))
	order.reverse()
	var n := order.size()
	var i := order.find(origin)
	var in_round := i + 1 if rnd % 2 == 1 else n - i
	return (rnd - 1) * n + in_round


## Where a club's pick in next year's draft might fall: [[overall pick,
## weight], ...] over every spot in the round. Nobody knows where a club
## will finish, so the spread is wide, centred on what anyone can see now -
## this season's finish and how its list ranks.
func future_spots(rnd: int, origin: String) -> Array:
	var n := GameDB.active_clubs(season_year).size()
	var standing := _standing(origin)
	var t := float(standing[1]) if float(standing[0]) < 0.0 else 0.5 * float(standing[0]) + 0.5 * float(standing[1])
	# Ladder place 0 (top) .. n-1; the draft runs the ladder in reverse.
	var expect := t * float(n - 1)
	var sigma := float(n) / 4.0
	var out := []
	for place in range(n):
		var in_round := n - place if rnd % 2 == 1 else place + 1
		var w := exp(-pow(float(place) - expect, 2.0) / (2.0 * sigma * sigma))
		out.append([(rnd - 1) * n + in_round, w])
	out.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	return out


func _pick_name(year: int, rnd: int, origin: String, at: int) -> String:
	var nth: String = ["first", "second", "third", "fourth"][clampi(rnd - 1, 0, 3)]
	var name := "%s %d %s-round pick" % [GameDB.club_name(origin) + ("'" if GameDB.club_name(origin).ends_with("s") else "'s"),
			year, nth]
	return name + (" (No. %d)" % at if at > 0 else "")


## The tradeable picks `code` owns, earliest first.
func club_picks(code: String) -> Array:
	var out := []
	for year in trade_pick_years():
		for rnd in range(1, trade_pick_rounds(int(year)) + 1):
			for origin in GameDB.active_clubs(season_year):
				if pick_owner_of(int(year), rnd, str(origin)) == code:
					out.append(pick_asset(pick_id(int(year), rnd, str(origin))))
	out.sort_custom(func(a, b):
		if int(a["year"]) != int(b["year"]):
			return int(a["year"]) < int(b["year"])
		if int(a["round"]) != int(b["round"]):
			return int(a["round"]) < int(b["round"])
		return int(a["positions"][0][0]) < int(b["positions"][0][0]))
	return out


## This draft year's traded picks for the draft: {"round:origin": owner}.
func draft_pick_owners(year: int) -> Dictionary:
	var out := {}
	for key in pick_owner:
		var parts := str(key).split(":")
		if int(parts[0]) == year:
			out["%s:%s" % [parts[1], parts[2]]] = str(pick_owner[key])
	return out


## The draft classes a club can see, best first: {year: [prospects]}. This
## year's open class (not the players tied to a club).
func trade_prospects() -> Dictionary:
	var out := {}
	for year in trade_pick_years():
		# Next year's class isn't known yet: this year's stands in for it.
		out[str(year)] = TradeValue.rank_prospects(_open_class(mini(int(year), season_year)))
	return out


func _open_class(year: int) -> Array:
	var pool := []
	for p in draftee_pool:
		if drafted_draftees.has(str(p["id"])) or int(p.get("draft_year", year)) != year:
			continue
		if str(p.get("tied_club", "")) != "" and int(p.get("draft_year", 0)) == year:
			continue
		pool.append(p)
	return pool


## Rounds of `year`'s draft that can be traded: the rounds it will run (as
## many as the class fills, Draft.build_intake), at most TRADE_PICK_ROUNDS.
func trade_pick_rounds(year: int) -> int:
	if year > season_year:
		year = season_year  # next year's class isn't known yet: assume one like this year's
	var clubs := maxi(1, GameDB.active_clubs(season_year).size())
	var rounds := clampi(ceili(float(_open_class(year).size()) / float(clubs)), 1, 4)
	return mini(TRADE_PICK_ROUNDS, rounds)


## Players and picks for a trade, by id: {"assets": [...], "error": ""}.
## Every asset must belong to `owner`, and none may appear twice.
func _trade_assets(ids: Array, owner: String) -> Dictionary:
	var out := []
	var seen := {}
	for id in ids:
		var key := str(id)
		if seen.has(key):
			return {"assets": [], "error": "Each player or pick can only go in once."}
		seen[key] = true
		if key.begins_with("pick:"):
			var pk := pick_asset(key)
			if pk.is_empty() or str(pk["owner"]) != owner:
				return {"assets": [], "error": "That pick isn't theirs to trade." if owner != my_club else "That pick isn't yours to trade."}
			out.append(pk)
		else:
			var found := {}
			for p in season.lists.get(owner, []):
				if str(p["id"]) == key:
					found = p
			if found.is_empty():
				return {"assets": [], "error": "That player isn't on their list." if owner != my_club else "That player isn't on your list."}
			out.append(found)
	return {"assets": out, "error": ""}


## Would `club` accept your `mine` (player and pick ids) for its `theirs`?
func evaluate_trade(club: String, mine: Array, theirs: Array) -> Dictionary:
	if not offseason_open():
		return {"ok": false, "reason": "Trades are only open in the off-season."}
	var g := _trade_assets(theirs, club)
	var t := _trade_assets(mine, my_club)
	if str(g["error"]) != "" or str(t["error"]) != "":
		return {"ok": false, "reason": str(g["error"]) if str(g["error"]) != "" else str(t["error"])}
	var give: Array = g["assets"]
	var take: Array = t["assets"]
	var ctx := trade_context(club)
	var names := {}
	for p in give + take:
		names[str(p["id"])] = str(p["name"]) if Contracts.is_pick(p) else GameDB.player_display_name(p)
	ctx["names"] = names
	ctx["prospects"] = trade_prospects()
	return Contracts.evaluate_trade(season.lists.get(club, []), give, take,
			salary_cap, my_list, salary_cap, float(difficulty_rules()["trade_margin"]), ctx)


## What a club weighs a trade with: its cycle, last season's games for
## everyone, its name.
func trade_context(club: String) -> Dictionary:
	var games := {}
	for id in season_tally:
		games[str(id)] = int((season_tally[id] as Dictionary).get("games", 0))
	return {"phase": club_phase(club), "games": games, "name": GameDB.club_name(club)}


## Where a club is in its cycle - "rebuilding", "building" or "contending" -
## from what anyone can see: last season's finish, how its list ranks, and
## how old its best 22 is (TradeValue.phase). Worked out afresh each time.
## Phases worked out for one state of the league: {"key": fingerprint,
## club: phase}. The fingerprint covers everything a phase reads - every
## list (who, rating, potential, age) and the ladder - so any trade,
## signing, draft, development or load gets a fresh answer.
var _phase_cache := {}


func club_phase(club: String) -> String:
	if season == null or not season.lists.has(club):
		return "building"
	var key := _league_fingerprint()
	if str(_phase_cache.get("key", "")) != key:
		_phase_cache = {"key": key}
	if not _phase_cache.has(club):
		_phase_cache[club] = _club_phase(club)
	return str(_phase_cache[club])


func _league_fingerprint() -> String:
	var parts := PackedStringArray([str(season_year)])
	for code in season.lists:
		var h := 0
		for q in season.lists[code]:
			h = hash([h, str(q["id"]), int(q.get("overall", 0)), int(q.get("potential", 0)), snappedf(float(q.get("age", 0.0)), 0.01)])
		parts.append("%s:%d:%d" % [code, (season.lists[code] as Array).size(), h])
	for code in season.ladder:
		var row: Dictionary = season.ladder[code]
		parts.append("%s=%d/%d/%d/%d" % [code, int(row.get("p", 0)), int(row.get("pts", 0)), int(row.get("pf", 0)), int(row.get("pa", 0))])
	return "|".join(parts)


func _club_phase(club: String) -> String:
	var standing := _standing(club)
	var side := Ratings.select_22(season.lists[club])
	var ages := 0.0
	var n := 0
	for q in (side["ground"] as Array) + (side["bench"] as Array):
		ages += float(q.get("age", 25.0))
		n += 1
	return TradeValue.phase(float(standing[0]), float(standing[1]), ages / float(maxi(1, n)))


## What anyone can see of where a club stands: [finish_t (0 premiers .. 1
## wooden spoon, -1 before a game is played), strength_t (its list's rank, 0
## best .. 1 weakest)].
func _standing(club: String) -> Array:
	var played := false
	for code in season.ladder:
		if int((season.ladder[code] as Dictionary).get("p", 0)) > 0:
			played = true
			break
	var finish_t := -1.0
	if played:
		var table := season.ladder_sorted()
		for k in range(table.size()):
			if str(table[k]["code"]) == club:
				finish_t = float(k) / float(maxi(1, table.size() - 1))
	var ranks := []
	for code in season.lists:
		if GameDB.active_clubs(season_year).has(code):
			ranks.append([str(code), Squad.new(str(code), season.lists[code], true, str(code)).strength()])
	ranks.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var strength_t := 0.5
	for k in range(ranks.size()):
		if str(ranks[k][0]) == club:
			strength_t = float(k) / float(maxi(1, ranks.size() - 1))
	return [finish_t, strength_t]


## Do the trade if `club` accepts: players change lists, picks change owners.
func make_trade(club: String, mine: Array, theirs: Array) -> Dictionary:
	var verdict := evaluate_trade(club, mine, theirs)
	if not bool(verdict["ok"]):
		return verdict
	var incoming: Array = _trade_assets(theirs, club)["assets"]
	var outgoing: Array = _trade_assets(mine, my_club)["assets"]
	for a in incoming:
		_move_asset(a, club, my_club)
	for a in outgoing:
		_move_asset(a, my_club, club)
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


## One traded asset from `from` to `to`: a player changes lists, a pick
## changes owner (a pick back with its own club needs no entry).
func _move_asset(a: Dictionary, from: String, to: String) -> void:
	if Contracts.is_pick(a):
		var key := "%d:%d:%s" % [int(a["year"]), int(a["round"]), str(a["origin"])]
		if to == str(a["origin"]):
			pick_owner.erase(key)
		else:
			pick_owner[key] = to
		return
	(season.lists[from] as Array).erase(a)
	_join(to, a)


## At the rollover: your undecided expiring players are re-signed for two
## seasons if the cap allows (released otherwise), a player whose talks broke
## down leaves for free agency (unless your list is at the minimum, when he
## stays a season), rivals fill their lists
## from free agency, the rest of the free agents leave, and every contract
## ticks down a season.
func _close_contracts() -> void:
	if season == null:
		return
	_close_free_agency()
	for code in season.lists:
		for p in season.lists[code]:
			p["contract_years"] = maxi(1, int(p.get("contract_years", 1)) - 1)
			p.erase("resigned")
			p.erase("talks")


## Free agency closes when the national draft opens (or at the rollover if
## there is no draft), so compensation picks can go into that draft: your
## undecided players are settled, rivals sign who they want, and anyone left
## unsigned retires. Once per off-season.
func _close_free_agency() -> void:
	if season == null or fa_closed_year == season_year:
		return
	open_offseason()
	fa_closed_year = season_year
	for p in Contracts.expiring(my_list).duplicate():
		if bool(p.get("resigned", false)):
			continue
		var walked := bool(p.get("talks", {}).get("walked", false))
		if walked and my_list.size() <= Contracts.MIN_LIST:
			_resign(p, 1)
			continue
		var cost := Contracts.asking_salary(p)
		if not walked and (my_payroll() - int(p.get("salary", 0)) + cost <= salary_cap or my_list.size() <= Contracts.MIN_LIST):
			_resign(p, 2)
		else:
			# He walked, or you could not fit him: you wanted him, as a rival
			# that runs out of room does.
			_release(my_club, p, true)
	_resolve_market()
	# Nobody signed them: their AFL careers end here.
	for p in free_agents:
		_career_over(p)
	free_agents = []
	mark_dirty()


## Free agency closes: every free agent still on the market gets offers
## (those released at the close included); where you never bid, the rivals
## behind the leader answer once among themselves; then each chooses, best
## players first by what everyone can see. Clubs still short of their usual
## list size go again for whoever is left, until nobody else signs.
func _resolve_market() -> void:
	_targets_signed = {}
	_open_market(free_agents)
	for p in free_agents:
		if int(p.get("market_round", 0)) == 0 and _offer_of(p, my_club).is_empty():
			var leader := Contracts.best_offer(p, p.get("offers", []))
			if not leader.is_empty():
				_rival_round(p, leader)
	for _pass in range(40):
		var order := free_agents.duplicate()
		order.sort_custom(func(a, b):
			if int(a["overall"]) != int(b["overall"]):
				return int(a["overall"]) > int(b["overall"])
			if float(a.get("age", 25.0)) != float(b.get("age", 25.0)):
				return float(a.get("age", 25.0)) < float(b.get("age", 25.0))
			return str(a["id"]) < str(b["id"]))
		var signed := 0
		for p in order:
			if _decide_fa(p) != "":
				signed += 1
		if signed == 0 or free_agents.is_empty():
			break
		for p in free_agents:
			p.erase("offers")
		_open_market(free_agents)


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
	var gains := _spend_with_weights(p, plan_weights(p), true, season_ceiling(p))
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


## Where he stands against his projection, in words: "Developing", "Near his
## projected peak", "At his projected peak", "Past his projection" (or
## "Rehab year").
func development_state(p: Dictionary) -> String:
	if bool(p.get("rehab", false)):
		return "Rehab year"
	var gap := int(p.get("potential", p.get("overall", 0))) - int(p.get("overall", 0))
	if gap >= 3:
		return "Developing"
	if gap >= 1:
		return "Near his projected peak"
	if gap == 0:
		return "At his projected peak"
	return "Past his projection"


## Buy stat points while XP lasts, each one going to the best weight per XP.
## POT prices every point the same way for every club; `ceiling` is a
## season limit (SEASON_TRAIN_GAIN, every club alike), not his potential.
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


## The most any player - yours or a rival's - improves through training in
## one season. Natural development happens in the off-season (Prospects.
## age_player); training adds at most this on top, so nobody is rebuilt
## mid-season and no club develops by different rules.
const SEASON_TRAIN_GAIN := 3


## The rating a player's training can take him to this season.
func season_ceiling(p: Dictionary) -> int:
	if not p.has("season_start_ov"):
		p["season_start_ov"] = int(p.get("overall", 0))
	return int(p["season_start_ov"]) + SEASON_TRAIN_GAIN


## Spend a rival player's XP. Returns the attribute points bought.
func ai_spend_xp(p: Dictionary) -> int:
	var ceiling := season_ceiling(p)
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
## his POT (rehabbing a star, bringing on a top pick), dearer near it and
## steeply dearer past it (Potential.training_multiplier).
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
		if int(p["overall"]) >= season_ceiling(p):
			break
		var cost := train_cost(p, attr_key)
		if cost < 0 or int(p.get("xp", 0)) < cost:
			break
		p["xp"] = int(p["xp"]) - cost
		p["attr"][attr_key] = mini(99, int(p["attr"][attr_key]) + 1)
		spent += cost
		gained += 1
		_recalc_player_overall(p)
	if gained == 0:
		var needed := train_cost(p, attr_key)
		fail["cost"] = needed
		if int(p["overall"]) >= season_ceiling(p):
			fail["reason"] = "He has had a full season's development. More after the off-season."
		else:
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
## trade_margin: how much better off a rival must be to accept a trade.
## Difficulty never changes how players develop: every club's players earn,
## train and grow by the same rules (SEASON_TRAIN_GAIN, Potential).
const DIFFICULTIES := {
	"easy": {"label": "Easy", "trade_margin": 0.0,
			"text": "Clubs trade at fair value."},
	"normal": {"label": "Normal", "trade_margin": Contracts.TRADE_MARGIN,
			"text": "The league as tuned."},
	"hard": {"label": "Hard", "trade_margin": 0.12,
			"text": "Rival clubs drive hard bargains in trades."},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard"]


func difficulty_rules() -> Dictionary:
	return DIFFICULTIES.get(difficulty, DIFFICULTIES["normal"])


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


## Around halfway through the home-and-away season, recruiting has seen
## enough of an exceptional class to call it. This is deliberately only a
## superdraft signal: ordinary/weak/strong classes stay uncertain rather than
## turning the news feed into a hidden numeric scouting report.
func _draft_class_news() -> void:
	if season == null or season.is_season_over():
		return
	var reveal_round := ceili(float(Season.REGULAR_ROUNDS) / 2.0)
	if season.round_index < reveal_round:
		return
	if str(class_tiers.get(str(season_year), "")) != "super":
		return
	# The news item itself is the durable acknowledgement. Saves already persist
	# the feed, so this needs no second flag that could drift out of sync.
	for item in news:
		if int(item.get("year", 0)) == season_year and str(item.get("kind", "")) == "superdraft":
			return
	add_news("superdraft", "Recruiters believe this year's national draft is a superdraft — unusually strong at the top and deeper than a normal class. Clubs will be planning their off-season around it.")



## Durable player milestones that can be proven from the save. Historical real
## players only get career-total milestones when Career.complete() says there
## are no unknown seasons; first goals are only announced for players whose
## recorded career had zero goals before this match.
func _player_milestone_news(res: Dictionary) -> void:
	var roster: Array = res.get("roster", [])
	var stats_all: Dictionary = res.get("players", {})
	for side in range(mini(2, roster.size())):
		var code := str(res["home"] if side == 0 else res["away"])
		for r in roster[side]:
			var id := str(r.get("id", ""))
			var st: Dictionary = stats_all.get(id, {})
			var goals := int(st.get("goals", 0))
			if goals <= 0:
				continue
			var p := _find_player(id)
			if p.is_empty():
				continue
			var t: Dictionary = season_tally.get(id, {})
			var season_goals := int(t.get("goals", 0))
			var career := Career.of(p)
			var previous_career_goals := int(career.get("goals", 0))
			if int(career.get("through", 0)) < season_year:
				previous_career_goals += maxi(0, season_goals - goals)
			if Career.complete(p) and previous_career_goals == 0:
				add_news("milestone", "%s kicked his first AFL goal for %s." % [
						GameDB.player_display_name(p), GameDB.club_name(code)])
			if not Career.complete(p):
				continue
			var career_goals := previous_career_goals + goals
			for mark in [100, 200, 300, 400, 500, 600, 700, 800]:
				if previous_career_goals < mark and career_goals >= mark:
					add_news("milestone", "%s reached %d career goals." % [
							GameDB.player_display_name(p), mark])
			for mark in [25, 50, 75, 100]:
				if season_goals - goals < mark and season_goals >= mark:
					add_news("milestone", "%s reached %d goals for the %d season." % [
							GameDB.player_display_name(p), mark, season_year])

## Big games and long injuries to good players from the round just played.
func _round_news(results: Array) -> void:
	for res in results:
		_player_milestone_news(res)
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
	for row in last_mro:
		var outcome := str(row.get("outcome", ""))
		if outcome == "no_action":
			continue
		var club := str(row.get("club", ""))
		var p := _find_player(str(row.get("id", "")))
		var name := str(row.get("name", "")) if p.is_empty() else GameDB.player_display_name(p)
		if outcome == "suspension":
			var w := int(row.get("weeks", 0))
			add_news("mro", "%s (%s) has been suspended for %d match%s for %s." % [
					name, GameDB.club_name(club), w, "" if w == 1 else "es",
					str(row.get("reason", "rough conduct"))])
		elif outcome == "fine":
			add_news("mro", "%s (%s) was fined by the MRO for %s." % [
					name, GameDB.club_name(club), str(row.get("reason", "rough conduct"))])


## A rival who has trained as far as he can this season is a news candidate
## (once a season). Returns the better of him and `best`.
func _development_pick(code: String, p: Dictionary, best: Dictionary) -> Dictionary:
	var start := int(p.get("season_start_ov", p.get("overall", 0)))
	var ov := int(p.get("overall", 0))
	if ov < NEWS_MIN_OVR or ov - start < 2 \
			or int(p.get("news_year", 0)) == season_year:
		return best
	if not best.is_empty() and int((best["p"] as Dictionary)["overall"]) >= ov:
		return best
	return {"code": code, "p": p}


func _season_news() -> void:
	var brownlow_winner: Dictionary = season_awards.get("brownlow_winner", {})
	if not brownlow_winner.is_empty():
		add_news("award", "%s (%s) won the Brownlow Medal with %d votes." % [
				award_name(brownlow_winner), GameDB.club_name(str(brownlow_winner["club"])),
				int(brownlow_winner["votes"])])
	var coaches_top: Array = season_awards.get("coaches_award", [])
	if not coaches_top.is_empty():
		add_news("award", "%s (%s) won the Coaches Award with %d votes." % [
				award_name(coaches_top[0]), GameDB.club_name(str(coaches_top[0]["club"])), int(coaches_top[0]["coaches"])])
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
		out.append(str(p["name"]) if Contracts.is_pick(p) else GameDB.player_display_name(p))
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
	club_goals = {}
	for i in range(ranks.size()):
		var code := str(ranks[i][0])
		club_expect[code] = i + 1
		club_goals[code] = ClubLife.board_goal(i + 1, int(_last_finish.get(code, 0)))
		if code == my_club:
			rank = i + 1
	if board.is_empty():
		board = {"confidence": ClubLife.START_CONFIDENCE, "warned": false, "sacked": false, "history": []}
	board["goal"] = club_goals.get(my_club, ClubLife.board_goal(rank))
	board["rank"] = rank
	board["last_finish"] = int(_last_finish.get(my_club, 0))
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



## A notable user match may produce one short press conference.
func _prepare_media_conference(results: Array) -> void:
	media_conference = {}
	var res := _my_result(results)
	if res.is_empty():
		return
	var side := 0 if str(res["home"]) == my_club else 1
	var opp := str(res["away"] if side == 0 else res["home"])
	var injuries := []
	for inj in last_injuries:
		if str(inj.get("club", "")) == my_club:
			var p := _find_player(str(inj.get("id", "")))
			injuries.append({"name": GameDB.player_display_name(p) if not p.is_empty() else "a player"})
	var star := {}
	var roster: Array = res.get("roster", [[], []])
	var stats: Dictionary = res.get("players", {})
	if roster.size() > side:
		for r in roster[side]:
			var st: Dictionary = stats.get(str(r.get("id", "")), {})
			var goals := int(st.get("goals", 0))
			var disposals := int(st.get("disposals", 0))
			if goals >= 6 or disposals >= 40:
				var p := _find_player(str(r.get("id", "")))
				star = {"name": GameDB.player_display_name(p) if not p.is_empty() else str(r.get("name", "A player")),
						"line": "kicked %d goals" % goals if goals >= 6 else "had %d disposals" % disposals}
				break
	var round_no := season.round_index if last_phase == "regular" else Season.REGULAR_ROUNDS + int((season.finals.get("weeks", []) as Array).size())
	media_conference = MediaConference.pick({
		"result": res, "club": my_club, "opponent_name": GameDB.club_name(opp),
		"round": round_no, "injuries": injuries, "star": star,
	}, media_memory)


func media_conference_pending() -> bool:
	return not media_conference.is_empty()



func skip_media_conference() -> void:
	if media_conference.is_empty():
		return
	media_memory[str(media_conference.get("key", ""))] = int(media_conference.get("round", 0))
	media_conference = {}
	mark_dirty()
	autosave()


func resolve_media_conference(option: int) -> void:
	if media_conference.is_empty():
		return
	var opts: Array = media_conference.get("options", [])
	if option < 0 or option >= opts.size():
		return
	var picked: Dictionary = opts[option]
	if not board.is_empty():
		board["confidence"] = clampi(board_confidence() + int(picked.get("board", 0)), 0, 100)
		board["why"] = "Your post-match comments were noted by the board."
	var morale_delta := int(picked.get("morale", 0))
	if morale_delta != 0:
		for p in my_list:
			ClubLife.add_morale(p, morale_delta)
	media_memory[str(media_conference.get("key", ""))] = int(media_conference.get("round", 0))
	add_news("media", "Post-match: '%s'" % str(picked.get("label", "")))
	media_conference = {}
	mark_dirty()
	autosave()



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
			out = ("%s is told he is in. Auto-pick names him this week." if my_selection().is_empty()
					else "%s is told he is in. Pick him this week.") % name
		"talk":
			ClubLife.add_morale(p, 15)
			p["expects_game"] = 12
			out = ("%s feels heard. Auto-pick names him this week." if my_selection().is_empty()
					else "%s feels heard, and expects a game this week.") % name
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
		var goal: Dictionary = club_goals.get(code, ClubLife.board_goal(int(club_expect.get(code, 9))))
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
	if CoachEffects.table.has(my_club):
		var mine: Dictionary = CoachEffects.table[my_club]
		mine["exec"] = clampf(float(mine.get("exec", 1.0)) * ClubBudget.tactics_mult(
				department_budget_level("football")), 0.75, 1.35)


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
		season.matchups = {my_club: my_matchups} if not my_matchups.is_empty() else {}


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
	# This week's match-ups were for this opponent.
	my_matchups = {}
	_sync_club_plan()
	var side := 0 if codes[0] == my_club else 1
	var roster: Array = res.get("roster", [[], []])
	if roster.size() <= side:
		return
	var players: Dictionary = res.get("players", {})
	last_side = []
	for r in roster[side]:
		last_side.append(str(r["id"]))
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
		"rebounds", "clangers", "hitouts", "disposals", "metres_gained", "distance_run"]


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
## {"win": [sentence], "beaten": [sentence], "games": n}. The most material
## differences first, at most two each; nothing until three games in.
func how_we_play(code := "") -> Dictionary:
	if code == "":
		code = my_club
	var games := int((season_team.get(code, {}) as Dictionary).get("games", 0))
	var out := {"win": [], "beaten": [], "games": games}
	for f in _style_found(code):
		var lines: Array = STYLE_LINES[f["k"]]
		var bucket: Array = out["win"] if bool(f["good"]) else out["beaten"]
		if bucket.size() < 2:
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


## The stats where a club is materially off the league average, most marked
## first: [{"k", "rel", "n", "good"}]. [] before three games.
## - Material: each stat has its own smallest difference worth saying
##   (STYLE_MIN, about one club-to-club spread, never under a goal for a
##   points line), so a point or two a game is never an identity.
## - Early reads are provisional: the per-game difference is shrunk toward
##   the average by games / (games + STYLE_SHRINK), so three games need a
##   big gap and a genuine trait firms up as the season goes on.
## - One diagnosis, not its symptoms: a points-source line is dropped when
##   the total it feeds (points for or against) already says the same.
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
	var shrink := float(games) / float(games + STYLE_SHRINK)
	var found := []
	for k in STYLE_LINES:
		var avg := float(league.get(k, 0.0)) / float(maxi(1, clubs))
		if avg <= 0.0:
			continue
		var raw := float(mine.get(k, 0.0)) / float(games) - avg
		var d := raw * shrink
		var good: bool = (d > 0.0) != bool(STYLE_LINES[k][2])
		if absf(d) >= float(STYLE_MIN[k]):
			found.append({"k": k, "rel": absf(d) / float(STYLE_MIN[k]), "n": int(round(absf(raw))), "good": good})
	found.sort_custom(func(a, b): return float(a["rel"]) > float(b["rel"]))
	var said := {}
	for f in found:
		said["%s|%s" % [f["k"], f["good"]]] = true
	var out := []
	for f in found:
		var total := str(STYLE_PART_OF.get(str(f["k"]), ""))
		if total != "" and said.has("%s|%s" % [total, f["good"]]):
			continue
		out.append(f)
	return out


## The smallest per-game difference from the average side worth calling a
## trait: about one club-to-club spread over a season (measured), and never
## under a goal for a points line.
const STYLE_MIN := {
	"for": 9.0, "against": 8.0, "clearances": 2.5, "inside50": 3.0,
	"pressure_acts": 9.0, "marks": 5.0, "clangers": 3.5, "hitouts": 7.0,
	"from_turnover": 6.0, "from_stoppage": 6.0, "conceded_turnover": 6.0, "conceded_stoppage": 6.0,
}
## Early reads are provisional: the difference counts games / (games + this).
const STYLE_SHRINK := 4
## A points-source line and the total it is part of.
const STYLE_PART_OF := {
	"from_turnover": "for", "from_stoppage": "for",
	"conceded_turnover": "against", "conceded_stoppage": "against",
}


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
