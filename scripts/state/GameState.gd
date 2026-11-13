extends Node
## GameState (autoload) - the in-progress season: which club you manage, your
## drafted list, the fixture, the ladder and the finals bracket.
##
## Every scene reads from here and nothing else, so scene changes never lose
## the season.

## Every real player is shown under his AFL name (director, 2026-11-12: "Real
## Names only"). Generated and custom players have no real name and keep the
## name they were given. An old settings file's display/real_names is ignored.
## Transient navigation request. Settings can send the user straight to New
## career setup without touching the existing save.
var new_career_setup_requested := false
## The career's custom prospect (Club Forge, ARD-M7-008): his id once made,
## one per career. Followed through drafts and career history.
var custom_prospect_id := ""
## His story as last told (OwnProspect): where
## he was, his games and goals, which beats are already in the news.
var custom_prospect_story := {}
## How this career began (ARD-M5-016): "redraft" (the League Draft) or "real"
## (every club keeps its real end-of-2026 list and the 2026 National Draft is
## run before 2027). Older saves have no field and are redrafts.
var start_mode := "redraft"
## The real league this career started from (Datasets, Legacy mode row 142):
## GameDB holds this set while the career runs. reset(dataset) chooses it; the
## save keeps it, and a save from before the choice is today's 2026 set.
var dataset := Datasets.DEFAULT
## A challenge start (row 114, Challenge.gd): {} for none, else
## {"kind": "youth" | "rebuild" | "goal", ...}. Older saves have none.
var challenge := {}
## The 2026 National Draft of a real-lists career is under way (no season yet).
var opening_draft := false
## Your dual-ruck call (ARD-M5-001): off until you make it, kept across
## seasons; copied into each season's selection for your club (_sync_dual).
var user_dual_ruck := false

var my_club := ""
var my_list: Array = []
var season: Season = null
var draft: Draft = null
var league_lists := {}
var pending_match: Dictionary = {}
var pending_sim: MatchSim = null
## How the match now being set up is taken (MATCH_WAYS): the poster's choice,
## read once when the live match is prepared. The pre-season match is always
## watched. The match screen reads it; it never reaches the sim.
var match_way_live := "watch"
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
## The last round's medical panel sittings, every club (MedicalPanel.gd):
## [{id, club, name, overall, count, cleared, pct, year, at}]. Optional in a save, absent = [].
var last_medical: Array = []
## Players the panel did not clear this week, [club, player], until _settle_medical.
var _medical_out: Array = []
## Careers the panel ended, kept until the season they ended in has rolled over:
## {"id", "club", "name", "age", "overall", "year", "player"}. The rollover
## treats them as it treats that season's other retirees (the season wrap's
## outs, the almanac's legends), then drops them.
var medical_retired: Array = []
var season_tally := {}           # player id -> running season numbers (Awards)
## Every player's season statistics across the competition (StatBook): id ->
## {"club", "clubs", "games", "s": {stat: total}}. season_stats_from is the
## round the book starts at: 0, or the round an older save was at when it
## first loaded with the book (rounds before it were never counted).
var season_stats := {}
var season_stats_from := 0
var club_plan := "balanced"      # your standing game plan, from the first bounce
## Your own plan (CustomPlan: {"name", "s", "c"}, director 2026-11-12), the
## sixth plan in How we play; {} = none built. Saved only when begun, so an
## older save loads with none (and drops a game-plan trait it held).
var custom_plan := {}
var form_log := {}               # your player id -> his last three Player Ratings
## Your players' games in the reserves this season (ReservesForm): id ->
## {"last", "sum", "n", "key"}. Display only. Optional in a save: an older
## save loads with none.
var reserves_log := {}
## A story card's role trial: {id, role, left, home, auto, before, wrote}, or {}.
## One player plays his second position for `left` more of your games (see
## start_role_trial); optional in a save, absent means no trial.
var role_trial := {}
## The monthly training report (TrainingReport.gd): the ratings at the start of the 4-round block in
## progress, and the latest report built. Optional in a save, absent = {}.
var training_block := {}
var training_report := {}
var trial_result := {}          # the last trial's result until its card is dealt: {id, role, word, avg, par, ok, trained}
var pos_ratings := {}           # this season, the league's starters' ratings by position: role -> [sum, games]
var season_team := {}            # club -> {"games": n, stat: season total}
var season_awards := {}          # the finished season's awards
## This season's Rising Star nominations, one a home-and-away round:
## {"from": the first round recorded, "rounds": [{round, id, club}]}. A save
## from before nominations were recorded starts "from" its next round.
var rising_star_noms := {"from": 1, "rounds": []}
## This season's votes round by round, for the awards-night count
## (AwardsCount.gd): the Brownlow's match by match and your club's best and
## fairest. A save from before they were kept starts "from" its next round,
## and its count falls back to naming the winners.
var award_counts := AwardsCount.fresh(0, "")
var honour_roll: Array = []      # one entry per completed season
var almanac: Array = []          # the club almanac, one page per season (Almanac.gd)
## The club honour board (HonourBoard.gd, row 122): player id -> his row.
## An older save builds it once on load from what is on record.
var honour_board := {}
## The boards of clubs you coached before a move (HonourBoard.change_club):
## club code -> {player id: row}.
var honour_boards := {}
## Every coach in the game, once: cid -> record (Coaches.gd). A club's staff
## is read from the records, never stored beside them.
var coaches := {}
## Notable coaches who have left the game: cid -> slim record (CoachMarket).
var coach_archive := {}
## Your staff jobs open after the season, waiting for you: [{job, reason}].
## Anything still open is auto-filled when the next season starts.
var staff_vacancies: Array = []
## Rival clubs' approaches for your coaches this season (director,
## 2026-10-07): found when the home-and-away season ends, answered through
## the finals, settled by the off-season market. [{cid, from_job, club, job,
## choice ("" unanswered, "promote", "stay", "go"), kept (bool), text}]
var coach_approaches: Array = []
var coach_approach_year := 0
## Every club's place in the preseason pecking order (list strength), for
## judging AI senior coaches at season's end: code -> rank.
var club_expect := {}
var club_goals := {}             # club -> this season\'s board goal (ClubLife.board_goal)
var _last_finish := {}           # club -> last season\'s ladder position, for the board
var draft_meeting_year := 0     # the National Draft the recruiting panel last met before
var records := {}                # league records across the career
var rivalry_history := {}        # canonical club pair -> emergent rivalry evidence
## The first season whose finals are counted per player (p["finals_games"]). 0 for a
## career begun with the count; an older save counts from its next finals.
var finals_counted_since := 0
## Club achievements unlocked this career: id -> {"year", "detail"}.
## Definitions live in scripts/sim/Achievements.gd.
var achievements := {}
## G7: the career's durable facts, {player id: [row, ...]} (CareerFacts.gd).
## Saved with the career; a player leaving the lists does not take them.
var career_facts := {}
## Undo steps for your last delistings, free-agent signings and re-signings
## (RecruitUndo, row 119). Session only, never saved; cleared when the week
## moves on.
var recruit_undo: Array = []
## Released contracts still on a club's cap for the coming season (ListCosts,
## row T1.R26 L4): club code -> {"year": season, "amount": dollars}.
var dead_cap := {}
var milestone_log := Milestones.empty()   # milestone games (Milestones.gd)
## Players who have left the game: id -> his name card (CareerFacts.name_card),
## so an honour-roll or record line can still name him.
var departed_names := {}
var salary_cap := 0              # annual-dollar TPP cap every club's payroll counts against
var free_agents: Array = []      # off-season: players no club kept
var offseason_year := 0:         # the season whose off-season has opened
	set(value):
		offseason_year = value
		# Lists built in the off-season are next season's (EraRules.list_ahead).
		EraRules.list_ahead = value != 0 and value == season_year
var fa_closed_year := 0          # the season whose free agency has closed
## This off-season's free-agency compensation picks: [{"club", "player",
## "name", "to", "salary", "years", "value", "after"}], slotted into the
## national draft when it opens (Contracts.compensation_after).
var compensation: Array = []
## Traded draft picks: "year:round:origin club" -> the club that owns it. A
## pick not listed still belongs to its own club. Saved; a draft year's
## entries go once that draft is done.
var pick_owner := {}
## How the club holding a traded pick got it: "year:round:origin club" ->
## {"from": the club it came from, "season": the season whose trade period it
## was, "gave": [{"id", "name"}] what went the other way}. Saved (a new key; an
## older save has none and the pick reads "<origin>'s pick, traded in"). Goes with the
## pick's entry in pick_owner. See pick_story.
var pick_got := {}
## Your players marked untouchable: {player id: true}. Rivals stop asking for
## them in the offers they put to you. Saved (a new key; an older save has none).
var untouchable := {}
var offseason_log: Array = []    # what happened in the off-season, for news
## New clubs building their lists (ExpansionBuild): {club code: its state}.
## Empty, and not saved, while no club is building.
var expansion := {}
## A Legacy career's rollovers (LegacyRollover): the clubs that played finals
## each season and how the Fitzroy merger went. Empty, and not saved, on today's data.
var legacy := {}
## Does Canberra join in 2030? A choice at career start (a new career starts
## without it); a career saved before the choice existed keeps Canberra.
var canberra_on := true
## The year the new clubs (Tasmania, and Canberra while the career has it)
## enter instead of their data years; 0 keeps the data years. A League
## redraft takes them into the 2027 draft as equals (director, 2026-11-08):
## no list build, no priority picks, no cap relief. Saved only when set.
var expansion_from := 0
## Real 2026 lists with Canberra (director, 2026-11-08): 2027-2029 are played
## without you, every club run by its own staff, and you choose your club at
## the 2029 National Draft. True from the start of the career until that
## choice; the club choice then reads it (opening_draft is the 2026 one).
var sim_ahead := false
## Offers rival clubs have made you this off-season: [{"club", "give" (their
## player and pick ids), "take" (yours), "status": "open", "accepted",
## "declined" or "off"}]. See _make_trade_offers.
var trade_offers: Array = []
## Offers you turned down, not made again the next year: {"club|your ids": year}.
var trade_declined := {}
## Your players and picks on the trade table this off-season (ids): clubs
## that want one say so with an offer. See put_on_trade_table.
var trade_table: Array = []
## Players who have asked to be traded this off-season (TradeRequests):
## {player id: {"club", "why": "home" or "games", "to": [clubs]}}. Met by a
## trade, or lapsing when the next off-season opens.
var trade_requests := {}
var offseason_staff := {}        # your staff (job -> cid) when the off-season opened
## Annual discretionary department funding for the coming season. It is an
## allocation, not cash carried between years (ClubBudget).
var department_budget := {}
var department_budget_year := 0
var season_wrap := {}            # the off-season briefing shown before Round 1 (season_wrap_lines)
var _wrap_picks: Array = []      # your National Draft picks, carried into the rollover
var news: Array = []             # league news feed, newest first
## Players the round's news already named for their game (a milestone or a big
## game), so a career best does not give him a second item. Not saved.
var _named_this_round := {}
var board_patience := "fair"     # this career's board dial (DifficultyDials step)
var rival_recruiting := "shrewd" # this career's rival dial (DifficultyDials step)
var tutorials := true            # this career's first-visit menu tips (Tutorials.gd)
## The league's real controversies (YearEvents): chosen at New career, kept
## with the career. On, a scandal's real penalty lands (fines, lost picks, a
## finals ban); off, the scandals never happen. Saved.
var controversies := true
## The supplements saga, its own switch at New career (director, 2026-11-13:
## its "full 1 year ban of list" is far more severe): on, Essendon's 2013
## penalties and the 2016 season bans land; off, none of it happens. Apart
## from Controversies either way. Saved.
var supplements := true
## The real year events of a legacy career (YearEvents.state): the ones fired,
## and the penalties still running. Saved.
var year_events := {}
var postseason_intro_seen := false  # the first postseason's sheet: this career's, not the device's
## The first season you coach from its start (0: none yet). Years played
## without you (sim-ahead, waiting for Tasmania, pre-made histories) close
## before it and must not use up the first postseason's sheet.
var my_first_season := 0
var board := {}                  # confidence, goal, warned, sacked, history
## This week's story cards (StoryEngine.pick_week): usually none or one, two
## in a big week. Each is answered on the hub before the round is played.
var week_events: Array = []
## The first of them, for the code and tests that deal in one card.
var week_event: Dictionary:
	get:
		return week_events[0] if not week_events.is_empty() else {}
	set(value):
		week_events = [] if value.is_empty() else [value]
## The week's checklist record (WeekChecklist.gd).
var week_checks := {}
## Trust between you and the people around the club (Trust.gd): {"p:<player
## id>": {"t", "log"}}. Missing means neutral. Saved; later phases add coaches,
## journalists, the board and club culture under their own keys, same shape.
var relations := {}
## What the stories remember (StoryEngine.new_state): cooldowns, flags, arcs.
var story := {}
## Off only in tests and audits that measure the game without the cards.
var stories_on := true
var media_conference := {}       # pending post-match press question
var backing_talk := {}           # a sit-down when a promised run ends (Backing.talk)
var media_memory := {}           # question key -> {year, round} last asked (legacy: round int)
## The match makes the story: one record per match of yours, oldest first
## (MatchStory.record). Empty, and not saved, until the first.
var match_stories: Array = []
## Each season of match stories folded into a digest, keyed by year (a
## string), so the almanac keeps a season after the list is trimmed
## (MatchStory.fold). Empty, and not saved, until the first.
var match_story_digest := {}
## Club records for every club (Almanac.update_club_records):
## code -> {record key: {value, who, year, label}}, plus "_streak" (the run now).
## Empty, and not saved, until the first round.
var club_records := {}
## The coach's career arcs (ClubArcs). Empty until the first.
var coach_arcs := {}
## Weeks of running a season-end card took off next pre-season's fitness base
## (B8 "Celebrate it properly": negative). Read once when the pre-season
## opens.
var preseason_run_debt: float = 0.0
## Matches kept: four seasons' worth, enough for the coach's arcs.
const MAX_MATCH_STORIES := 120
var losing_streak := 0
## How the prepared match was made, so a change to the side before the first
## bounce rebuilds it the same way (rebuild_pending_side).
var _pending_build := {}
var last_side: Array = []       # ids of your players who took the field in your last match
## Players on a promised run (Backing) who could not play this round, noted at
## the start of _after_round before the week's injuries and suspensions tick
## down, so a player healed by this very round is not "left out while fit".
## Not saved: it is rebuilt every round.
var _backing_unavailable := {}
## The same for every listed player at every club: injured or suspended for
## this round's game, so not "left out while fit" (morale, a promised game).
var _round_unavailable := {}

## Career loop: season 1 is the 2026 season. Every completed season ends with
## a national intake draft (keep your list, sign the rookies), then the same
## league rolls into the next year with one season of ageing applied.
var season_year := 2026:
	set(value):
		season_year = value
		# Money shows in this season's dollars (Legacy mode, Contracts.dollars).
		Contracts.money_year = value
		# The league's rules of this season (list sizes, the bench, free
		# agency): EraRules switches them at every rollover (L4).
		EraRules.year = value
		EraRules.list_ahead = offseason_year != 0 and offseason_year == value
## Rolled once per career: decides each generated draft class's quality tier
## (Prospects.class_tier), so a reload never re-rolls a class.
var career_seed := 0
## Season conditioning (Conditioning.gd): club code -> this season's record
## {"year", "changes": [[week, plan]], "offset"}. Missing = Steady.
var conditioning := {}
## This year's pre-season (PreSeason.gd): {"year", "week" (weeks done, 0..8),
## "clubs": {code: {"blocks": [[load, focus] x3], "run"}}, "trial", "trial_seen",
## "done"}. A Game plan block is [load, "plan", drills], plus (only once a
## position group drills something else) a fourth item {group: drills}; a block
## without it drills the same for every group (PreSeason.group_drills).
## Empty means none is running: a career saved before pre-seasons
## existed plays on as it was and gets its first at the next rollover.
var preseason := {}
## How well each club knows each game plan (PreSeason.gd, plan familiarity):
## club code -> {plan: 0 barely / 1 partly / 2 well}, and the rounds each plan
## has gone unplayed. Optional in a save (the key is written once a record
## exists): a save without it gets the defaults, each club's
## usual plan well and the rest partly (_ensure_plan_known).
var plan_known := {}
var plan_idle := {}
## The plans each rival coach has called this season, quarter by quarter, and
## why (RivalRead.record_row; MatchSim.ai_why), for the Assistant's report
## (rival coach read, director 2026-11-08): {"year": season_year, "clubs":
## {code: [row, ...]}, "usual": {code: plan}}, a row per match in the order
## played. "usual" is each rival coach's usual game for the season, settled
## at the season's first round (_settle_usual_plans) and kept all year. This
## season only; optional in a save (written once a row or a usual game
## exists), so a save from before it loads empty: the report says nothing of
## their record, and each coach settles his usual game at the next round.
var rival_plans := {}
## Your coach (row 119): his name, and his two archetypes' record
## (Archetypes.blank shape: scores, what he holds, this season's tally).
## interview_due: a new career's appointment interview is still to be sat.
## Optional in a save: an older one loads with no name, no archetypes and no
## interview, and his coaching earns its archetypes by drift.
var coach_name := ""
var coach_arch := {}
var interview_due := false
## Who leads each club (Captaincy.gd): club code -> its record. A club with
## no entry has named no one; an older save has none for anyone.
var captaincy := {}
## The coach's scouting list (row 130, ScoutingList): [{"id", "year", "round",
## "first": {"overall", "potential"}}], the read when he was listed.
var scouting_list: Array = []
## Whether AI clubs choose a season plan by phase (never saved). On now that
## the plan screen lets you choose yours (BOSS, 2026-10-12): contenders peak
## for September and rebuilders develop. This one switch is the director's
## lever on the AI side (his Develop-dominance question): off, every AI club
## plays Steady, as before.
var fitness_ai_by_phase := true
## Audits only (never saved): club -> high-performance level, for AI clubs.
var fitness_hp_override := {}
## Club Forge: the career's created club as its spec (ClubForge), or {}.
## Saved with the career and registered with GameDB whenever it loads.
var custom_club := {}
## "My Selected Best 23" (director, 2026-10-07): your saved recurring side, a
## selection ({RUCK, MID, WING, DEF, FWD, BENCH} -> ids), or {} if none.
var best23 := {}
## The hub search's shortlist (row T3.R43, P-65): player ids and "club:CODE",
## in the order the coach added them. A look-up list; no effect on the game.
var shortlist: Array = []
## "When I sim the week" (row T3.R43, P-66): the lines the assistant follows
## each week you sim (SimOrders keys -> answer). Missing keys take the defaults.
var sim_orders := {}
var class_tiers := {}             # draft year (string) -> tier key, as generated
var draftee_pool: Array = []     # all prospects that have not been drafted yet
var drafted_draftees := {}       # prospect id -> destination club
var midseason := {}              # carnival and mid-season rookie draft (MidseasonDraft)
var rookie_draft := {}           # the Rookie Draft after the National Draft (RookieList; saved once it exists)
var sir_doug := {}               # this season's Sir Doug Nicholls Round: {year, round, designs} (SirDougRound)
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
## A new club card opens over the hub on arrival (HubScene). Never saved;
## test runs that drive the hub for something else switch it off.
var event_sheets := true
## A new draft or season is seeded from the clock, so no two careers play
## alike. Measurement tools set this so a career replays exactly: each of
## those seeds then comes from it and the year (_clock_seed). 0 in the game.
var replay_seed := 0
## Set by small edits (training, draft picks) that save on the next screen
## change or when the app is backgrounded, rather than on every tap.
var _dirty := false


func _ready() -> void:
	CareerSave.beat_hook = Season.beat   # load screen keeps moving while players decode
	PreSeason.data()   # its sizes are read once, before any scouting read needs one
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	UiKit.apply_appearance(str(cfg.get_value("ui", "appearance", "dark")))
	UiKit.apply_text_size(str(cfg.get_value("ui", "text_size", "standard")))
	_carry_old_sound_levels(cfg)
	_apply_sound_mute(bool(cfg.get_value("ui", "mute_sounds", false)))
	AudioLevels.apply_volume(AudioLevels.valid(cfg.get_value("ui", "volume", AudioLevels.DEFAULT_VOLUME)))
	Feel.haptics = bool(cfg.get_value("ui", "haptics", true))
	Feel.reduced = bool(cfg.get_value("ui", "reduced_motion", false))
	ScreenLayout.set_screen_size(str(cfg.get_value("ui", "screen_size", "standard")))
	# A desktop opens fullscreen unless the player chose Window (director, 2026-10-12).
	ScreenLayout.set_fullscreen(bool(cfg.get_value("ui", "fullscreen", true)))
	_apply_battery_saver(bool(cfg.get_value("ui", "battery_saver", false)))
	clamp_saved_orientation()
	ScreenLayout.lock_portrait()


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


## The player made in Club Forge (ARD-M7-008), kept outside any career so it
## can be brought into the next one: a custom-prospect spec, or {}.
func forge_player() -> Dictionary:
	var v = get_setting("forge_player", {})
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


func set_forge_player(spec: Dictionary) -> void:
	set_setting("forge_player", spec.duplicate(true))


## The club made in Club Forge (ARD-M7-009), kept outside any career like the
## player: a ClubForge spec, or {}. New career brings it in (create_club).
func forge_club() -> Dictionary:
	var v = get_setting("forge_club", {})
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


func set_forge_club(spec: Dictionary) -> void:
	set_setting("forge_club", spec.duplicate(true))


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


## Standard, Larger or Largest (row 118): an unknown saved value reads as
## Standard.
func text_size() -> String:
	var key := str(get_setting("text_size", "standard"))
	return key if UiKit.TEXT_SCALE.has(key) else "standard"


## Sets the size of the game's words. The caller rebuilds the current screen
## when this returns true, so no control keeps the old size.
func set_text_size(key: String) -> bool:
	if not UiKit.TEXT_SCALE.has(key):
		return false
	var changed := text_size() != key
	set_setting("text_size", key)
	UiKit.apply_text_size(key)
	return changed


func sounds_muted() -> bool:
	return bool(get_setting("mute_sounds", false))


func set_sounds_muted(muted: bool) -> void:
	set_setting("mute_sounds", muted)
	_apply_sound_mute(muted)


## One Volume for every sound (row 98), a whole percent; Mute sits over it.
func volume() -> int:
	return AudioLevels.valid(get_setting("volume", AudioLevels.DEFAULT_VOLUME))


func set_volume(pct: int) -> void:
	set_setting("volume", AudioLevels.valid(pct))
	AudioLevels.apply_volume(AudioLevels.valid(pct))


## A settings file from before row 98 kept a level each for music, the crowd
## and button sounds. Carry them over once as Mute and Volume
## (AudioLevels.from_old says how) and drop the old keys, so the file has one
## answer and no level the player can no longer see stays applied.
func _carry_old_sound_levels(cfg: ConfigFile) -> void:
	var old := {}
	for k in AudioLevels.OLD_KEYS:
		if cfg.has_section_key("ui", k):
			old[k] = cfg.get_value("ui", k)
	if old.is_empty():
		return
	var now := AudioLevels.from_old(old)
	if not cfg.has_section_key("ui", "volume"):
		cfg.set_value("ui", "volume", now["volume"])
	if bool(now["mute"]):
		cfg.set_value("ui", "mute_sounds", true)
	for k in old:
		cfg.erase_section_key("ui", k)
	cfg.save(settings_path)


## A light buzz under a press and a big moment, on a phone. On by default.
func haptics_on() -> bool:
	return bool(get_setting("haptics", true))


func set_haptics_on(on: bool) -> void:
	set_setting("haptics", on)
	Feel.haptics = on


## Reduced motion: no fades, count-ups, press-ins, pulses, moving backgrounds
## or screen shake. Off by default; every fact shows the same either way.
func reduced_motion() -> bool:
	return bool(get_setting("reduced_motion", false))


func set_reduced_motion(on: bool) -> void:
	set_setting("reduced_motion", on)
	Feel.reduced = on


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


## Playtest aid (ARD-M8-007): the centre-bounce scene in every match you
## coach, at the first centre bounce of the last quarter whatever the score.
## Off by default; it changes when the call comes, not the football.
func bounce_scene_every_match() -> bool:
	return bool(get_setting("bounce_scene_every_match", false))


func set_bounce_scene_every_match(enabled: bool) -> void:
	set_setting("bounce_scene_every_match", enabled)


## Vignettes (ROADMAP §1.11): the match-day scenes - the run through the
## banner, the centre ball-up call, the replays, the press conference and the
## awards on stage. On by default. Off plays none of them; every decision, its
## information and every result stay exactly the same.
func screen_size() -> String:
	return str(get_setting("screen_size", "standard"))


func set_screen_size(key: String) -> void:
	set_setting("screen_size", key)
	ScreenLayout.set_screen_size(key)


## Phone is portrait only (director, 2026-11-05): an older build's saved
## landscape or follow-the-phone choice is rewritten as portrait on load.
func clamp_saved_orientation() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK or not cfg.has_section_key("ui", "screen_orientation"):
		return
	var saved := str(cfg.get_value("ui", "screen_orientation"))
	if saved != ScreenLayout.clamp_orientation(saved):
		set_setting("screen_orientation", ScreenLayout.clamp_orientation(saved))


func fullscreen() -> bool:
	return bool(get_setting("fullscreen", true))


func set_fullscreen(on: bool) -> void:
	set_setting("fullscreen", on)
	ScreenLayout.set_fullscreen(on)


## Battery saver (ROADMAP §1.11 battery work): draw at most 30 frames a second
## instead of 60. Matches, scenes and timers run on real time, so nothing plays
## slower or differently; motion is a little less smooth. Off by default.
const FPS_NORMAL := 60
const FPS_SAVER := 30


func battery_saver() -> bool:
	return bool(get_setting("battery_saver", false))


func set_battery_saver(on: bool) -> void:
	set_setting("battery_saver", on)
	_apply_battery_saver(on)


func _apply_battery_saver(on: bool) -> void:
	Engine.max_fps = FPS_SAVER if on else FPS_NORMAL


## A small, short shake of the live oval when a goal is scored (director,
## 2026-10-10). On by default; Off for anyone who doesn't want the screen to move.
func screen_shake_on() -> bool:
	return bool(get_setting("screen_shake", true))


func set_screen_shake_on(on: bool) -> void:
	set_setting("screen_shake", on)


func vignettes_on() -> bool:
	return bool(get_setting("vignettes", true))


func set_vignettes_on(on: bool) -> void:
	set_setting("vignettes", on)


## The live match view's players as small figures instead of tokens: a
## prototype gated by the director's phone (visual audit §8 Phase 3.3). Off
## by default; nothing in the match changes either way.
func match_figures_on() -> bool:
	return bool(get_setting("match_figures", false))


func set_match_figures_on(on: bool) -> void:
	set_setting("match_figures", on)


## How fast a watched match starts (1x, 2x, 4x or 8x). 4x by default.
func match_speed() -> float:
	var s := float(get_setting("match_speed", 4.0))
	return s if s in [1.0, 2.0, 4.0, 8.0] else 4.0


func set_match_speed(s: float) -> void:
	if s in [1.0, 2.0, 4.0, 8.0]:
		set_setting("match_speed", s)


## How you take your own match, chosen on the hub's poster and kept for the
## next one (director, 2026-10-18, P-14): Watch it or Skip to full time.
## Watch for anyone who has never chosen. Playback only: the match is the same.
## Key moments, once a third way, is cut (director, 2026-11-08: "it's just
## noise"): a settings file that still holds it reads as Watch.
const MATCH_WAYS := ["watch", "skip"]


func match_way() -> String:
	var w := str(get_setting("match_way", "watch"))
	return w if w in MATCH_WAYS else "watch"


func set_match_way(w: String) -> void:
	if w in MATCH_WAYS:
		set_setting("match_way", w)


# ---------------------------------------------------------------------------
# Saving and loading
# ---------------------------------------------------------------------------
## True when there is a career worth saving: a season, or a draft where you
## have already picked your club.
func has_career() -> bool:
	# The years played without you are not a career yet: nothing is saved,
	# and the old save stays, until you choose your club.
	if sim_ahead and my_club == "":
		return false
	return season != null or (draft != null and not draft.user_club.is_empty())


func has_saved_career() -> bool:
	return CareerSave.exists(save_path)


## One sentence per line, so a narrow phone never leaves one word alone.
const SAVE_UNREADABLE := "Your saved career could not be read.\nStarting a new career will overwrite it."


## Why a career file on disk cannot be continued, in the coach's words, or
## "" when there is nothing wrong (or no file at all).
func saved_career_problem() -> String:
	match CareerSave.problem(save_path):
		"newer":
			return "Your saved career is from a newer version.\nUpdate the game to keep playing it.\nStarting a new career will overwrite it."
		"unreadable":
			return SAVE_UNREADABLE
	return ""


## Club, year and stage of the saved career, for the main menu.
func saved_career_meta() -> Dictionary:
	return CareerSave.read_meta(save_path)


## Save if there is a career and no live match is half played. Mid-match the
## rest of the round is already on the ladder but the round has not closed,
## so the last save (from before the match) is the consistent one to keep.
## Full saves written this run: tests count them to keep a tap to one save.
var saves_written := 0
## Set while the season skip plays the season out: each round leaves the save
## alone and the skip saves once at the end (a save every round was a quarter of
## the skip's time). Killed mid-skip, the career is where the skip began.
var _batching := false
## The coach's answers to the survey before the season skip (SkipOrders),
## held only while the skip runs; {} the rest of the time.
var _skip_orders := {}


func autosave() -> bool:
	if _batching or not autosave_enabled or not has_career() or not pending_match.is_empty():
		return false
	return save_career()


func mark_dirty() -> void:
	_dirty = true
	_phase_cache = {}
	_teach_key = ""   # a hire, fire, poach or market move may have changed a staff


func autosave_if_dirty() -> bool:
	if not _dirty:
		return false
	return autosave()


func save_career() -> bool:
	if not has_career():
		return false
	saves_written += 1
	var ok := CareerSave.write(_save_state(), _save_meta(), save_path)
	if ok:
		_dirty = false
	return ok


## A pre-made history (PremadeHistory): the league as it stands when Choose
## your club opens, packed for shipping. Only the generator tool writes one.
func write_history(path: String, meta: Dictionary) -> bool:
	if not choosing_club():
		return false
	var state := _save_state()
	state["sim_ahead"] = true
	state["sim_ahead_to"] = sim_ahead_to
	return CareerSave.write_packed(state, meta, path)


## Start from a shipped history instead of playing the years live. The career's
## own choices (the dials, the tips, the challenge) are kept, and its future is
## its own: a new career seed, so two careers from one history part ways from
## the first season. False, with nothing changed, when no fresh history fits:
## the caller then plays the years live. A forged prospect enters in 2026, so
## his career has to be played; a seeded run stays reproducible.
func begin_from_history(first_season: int) -> bool:
	if replay_seed != 0 or custom_prospect_id != "":
		return false
	var path := PremadeHistory.pick(first_season)
	if path == "":
		return false
	var state := CareerSave.read_packed(path)
	if state.is_empty():
		return false
	var held := challenge
	var board_was := board_patience
	var rivals_was := rival_recruiting
	var tips_were := tutorials
	# You, the coach, are this career's, not the history's: the press
	# interview still waits and its answers set the coaching style as in any start
	# (director, 2026-11-10: "interview should happen in every game mode").
	var interview_was := interview_due
	var coach_was := coach_name
	var arch_was := coach_arch
	if not _restore_career(state):
		return false
	GameDB.pristine = false   # a career's data from here on: the next reset() reloads
	board_patience = board_was
	rival_recruiting = rivals_was
	tutorials = tips_were
	interview_due = interview_was
	coach_name = coach_was
	coach_arch = arch_was
	CoachEffects.my_arch = coach_arch
	_sim_ahead_challenge = held
	challenge = {}
	career_seed = randi_range(1, 999999)
	mark_dirty()
	return true


## Everything a save holds.
func _save_state() -> Dictionary:
	# The pre-season league draft is spent once the season starts (it holds a
	# second copy of the whole player pool), so it is not written.
	var keep_draft := draft != null and not (season != null and not draft.intake_mode)
	SirDougRound.ensure(self)   # this season's round is written once and read back
	HonourBoard.sweep(self)   # anyone who has left your list since the last save
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
		"midseason": midseason,
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
		"last_medical": last_medical,
		"medical_retired": medical_retired,
		"season_tally": season_tally,
		"season_stats": StatBook.pack_book(season_stats),
		"season_stats_from": season_stats_from,
		"club_plan": club_plan,
		"form_log": form_log,
		"reserves_log": reserves_log,
		"role_trial": role_trial,
		"trial_result": trial_result,
		"pos_ratings": pos_ratings,
		"season_team": season_team,
		"season_awards": season_awards,
		"rising_star_noms": rising_star_noms,
		"award_counts": award_counts,
		"honour_roll": honour_roll,
		"almanac": almanac,
		"honour_board": honour_board,
		"honour_boards": honour_boards,
		"records": records,
		"rivalry_history": rivalry_history,
		"finals_counted_since": finals_counted_since,
		"achievements": achievements,
		"career_facts": career_facts,
		"milestone_log": milestone_log,
		"last_finish": _last_finish,
		"departed_names": departed_names,
		"salary_cap": salary_cap,
		"free_agents": free_agents,
		"offseason_year": offseason_year,
		"fa_closed_year": fa_closed_year,
		"compensation": compensation,
		"pick_owner": pick_owner,
		"pick_got": pick_got,
		"untouchable": untouchable,
		"offseason_staff": offseason_staff,
		"department_budget": department_budget,
		"department_budget_year": department_budget_year,
		"season_wrap": season_wrap,
		"offseason_log": offseason_log,
		"trade_offers": trade_offers,
		"trade_declined": trade_declined,
		"trade_table": trade_table,
		"trade_requests": trade_requests,
		"news": news,
		"board_patience": board_patience,
		"rival_recruiting": rival_recruiting,
		"tutorials": tutorials,
		"controversies": controversies,
		"supplements": supplements,
		"year_events": year_events,
		"postseason_intro_seen": postseason_intro_seen,
		"my_first_season": my_first_season,
		"board": board,
		"week_events": week_events,
		"week_checks": week_checks,
		"relations": relations,
		"story": story,
		"media_conference": media_conference,
		"backing_talk": backing_talk,
		"media_memory": media_memory,
		"losing_streak": losing_streak,
		"last_side": last_side,
		"db_draftees": GameDB.draftees,
		"db_late_draftees": GameDB.late_draftees,
		"db_alias_next": GameDB._alias_next,
		"coaches": coaches,
		"coach_archive": coach_archive,
		"staff_vacancies": staff_vacancies,
		"coach_approaches": coach_approaches,
		"coach_approach_year": coach_approach_year,
		"club_expect": club_expect,
		"club_goals": club_goals,
		"draft_meeting_year": draft_meeting_year,
		"career_seed": career_seed,
		"dead_cap": dead_cap,
		"conditioning": conditioning,
		"preseason": preseason,
		"captaincy": captaincy,
		"scouting_list": scouting_list,
		"class_tiers": class_tiers,
		"custom_prospect_id": custom_prospect_id,
		"start_mode": start_mode,
		"dataset": dataset,
		"names_real": 1,   # no generated name of a real player is written (RealNamesSwap)
		"challenge": challenge,
		"opening_draft": opening_draft,
		"custom_club": custom_club,
		"best23": best23,
		"shortlist": shortlist,
		"sim_orders": sim_orders,
		"user_dual_ruck": user_dual_ruck,
		# Players carry p["career"]; saves without this mark predate it.
		"career_version": CAREER_VERSION,
	}
	if not rookie_draft.is_empty():
		state["rookie_draft"] = rookie_draft
	if not sir_doug.is_empty():   # written only once a record exists
		state["sir_doug"] = sir_doug
	if not custom_prospect_story.is_empty():
		state["custom_prospect_story"] = custom_prospect_story
	# The new-club build writes nothing while no club is building and the
	# career keeps Canberra.
	if not expansion.is_empty():
		state["expansion"] = expansion
	if not canberra_on:
		state["canberra_on"] = false
	if expansion_from != 0:
		state["expansion_from"] = expansion_from
	if not legacy.is_empty():
		state["legacy"] = legacy
	if not match_stories.is_empty():
		state["match_stories"] = match_stories
	if not match_story_digest.is_empty():
		state["match_story_digest"] = match_story_digest
	if not club_records.is_empty():
		state["club_records"] = club_records
	if not coach_arcs.is_empty():
		state["coach_arcs"] = coach_arcs
	if preseason_run_debt != 0.0:
		state["preseason_run_debt"] = preseason_run_debt
	state["training_block"] = training_block
	state["training_report"] = training_report
	if not plan_known.is_empty():
		state["plan_known"] = plan_known
		state["plan_idle"] = plan_idle
	if not rival_plans.is_empty():
		state["rival_plans"] = rival_plans
	if coach_name != "":
		state["coach_name"] = coach_name
	if not coach_arch.is_empty():
		state["coach_arch"] = coach_arch
	if not custom_plan.is_empty():
		state["custom_plan"] = custom_plan
	if interview_due:
		state["interview_due"] = true
	return state


func _save_meta() -> Dictionary:
	var stage := "Draft"
	if season != null:
		if season.is_season_over():
			stage = "National draft" if draft != null else "Season complete"
		elif season.is_regular_done():
			stage = "Finals"
		else:
			stage = season.round_name(season.round_index)
	var club := my_club if my_club != "" else (draft.user_club if draft != null else "")
	return {"club": club, "club_name": GameDB.club_name(club) if club != "" else "",
			"year": season_year, "stage": stage,
			"saved_at": Time.get_datetime_string_from_system()}


## Replace the in-memory career with the saved one. Returns false (and leaves
## a fresh state) if there is no usable save.
func load_career() -> bool:
	return _restore_career(CareerSave.read(save_path))


func _restore_career(state: Dictionary) -> bool:
	# Season.beat() between the steps: the load screen keeps its ball moving
	# (it touches nothing in the career and draws no random numbers).
	if state.is_empty():
		return false
	# The league the career started from loads first: everything below reads it.
	# A save from before the choice is the 2026 set; one whose set this build
	# does not ship cannot be restored onto another league's players.
	var ds := str(state.get("dataset", Datasets.DEFAULT))
	if not Datasets.ready(ds):
		push_error("GameState: the save's dataset '%s' is not in this build." % ds)
		return false
	Season.beat()
	reset(ds)
	# A save from a build that could show generated names (before 2026-11-12)
	# may have written them into its news, stories and records: swapped once.
	if int(state.get("names_real", 0)) < 1:
		Season.beat()
		load("res://scripts/state/RealNamesSwap.gd").apply(state, GameDB.players)
	# A pre-made history stops where Choose your club opens.
	Season.beat()
	sim_ahead = bool(state.get("sim_ahead", false))
	sim_ahead_to = int(state.get("sim_ahead_to", SIM_AHEAD_TO))
	# A created club joins the competition before anything reads the clubs.
	custom_club = state.get("custom_club", {})
	# A redraft's new clubs entered with everyone (a save without it keeps the
	# data years). Canberra, before anything reads the clubs: a save from before
	# the choice existed keeps it. set_canberra applies the entry years.
	expansion_from = int(state.get("expansion_from", 0))
	Season.beat()
	set_canberra(bool(state.get("canberra_on", true)))
	expansion = state.get("expansion", {}) if state.get("expansion") is Dictionary else {}
	legacy = state.get("legacy", {}) if state.get("legacy") is Dictionary else {}
	LegacyRollover.restore(self)
	best23 = state.get("best23", {})
	shortlist = state.get("shortlist", []) if state.get("shortlist") is Array else []
	sim_orders = state.get("sim_orders", {}) if state.get("sim_orders") is Dictionary else {}
	if not custom_club.is_empty():
		GameDB.register_club(ClubForge.row(custom_club))
	Season.beat()
	season_year = int(state.get("season_year", 2026))
	GameDB.apply_era(season_year)
	my_club = str(state.get("my_club", ""))
	if state.get("season") is Dictionary:
		var sv: Dictionary = state["season"]
		season = Season.new(sv["clubs"], sv["lists"], int(sv["seed"]), int(sv.get("year", 0)))
		Season.beat()
		CareerSave.apply_vars(season, sv)
		Season.beat()
		_sync_dual()
		# Saves written under the old eight-finalist bracket cannot be
		# restored into the wildcard series (different slots, different
		# weeks), so the finals restart from the ladder as it was saved.
		if not season.finals.is_empty() \
				and int((season.finals.get("top", []) as Array).size()) != season.finalists():
			season.finals = {}
	Season.beat()
	if state.get("draft") is Dictionary:
		draft = Draft.new([], [], 0)
		CareerSave.apply_vars(draft, state["draft"])
		_watch_draft_night()
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
	midseason = state.get("midseason", {})
	rookie_draft = state.get("rookie_draft", {})
	sir_doug = state.get("sir_doug", {}) if state.get("sir_doug") is Dictionary else {}
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
	last_medical = state.get("last_medical", []) if state.get("last_medical") is Array else []
	medical_retired = state.get("medical_retired", []) if state.get("medical_retired") is Array else []
	_medical_out = []
	season_tally = state.get("season_tally", {})
	season_stats = StatBook.unpack_book(state.get("season_stats", {}))
	season_stats_from = int(state.get("season_stats_from", 0))
	if not state.has("season_stats") and season != null:
		# An older save, part way through a season: the book counts from here.
		season_stats_from = season.round_index
	# An older save's game-plan trait ("plan_trait", cut 2026-11-12) is dropped.
	custom_plan = CustomPlan.clean(state.get("custom_plan", {}))
	club_plan = MatchSim.plan_key(str(state.get("club_plan", "balanced")))
	if not CLUB_PLANS.has(club_plan) or (club_plan == CustomPlan.KEY and not CustomPlan.ready(custom_plan)):
		club_plan = "balanced"
	form_log = state.get("form_log", {})
	reserves_log = state.get("reserves_log", {}) if state.get("reserves_log") is Dictionary else {}
	role_trial = state.get("role_trial", {}) if state.get("role_trial") is Dictionary else {}
	trial_result = state.get("trial_result", {}) if state.get("trial_result") is Dictionary else {}
	pos_ratings = state.get("pos_ratings", {}) if state.get("pos_ratings") is Dictionary else {}
	Season.beat()
	season_team = state.get("season_team", {})
	if not state.has("season_stats"):
		# ...and so do the clubs' new statistics (TEAM_BOOK_KEYS).
		for code in season_team:
			(season_team[code] as Dictionary)["book_games"] = 0
	_sync_club_plan()
	season_awards = state.get("season_awards", {})
	# Older saves recorded no nominations: the rounds already played stay
	# unrecorded (never back-filled), and recording starts with the next one.
	rising_star_noms = state.get("rising_star_noms",
			{"from": season.round_index + 1 if season != null else 1, "rounds": []})
	# The same for the count's votes: never back-filled from the totals.
	award_counts = state.get("award_counts", AwardsCount.fresh(season_year, my_club,
			season.round_index + 1 if season != null else 1))
	honour_roll = state.get("honour_roll", [])
	almanac = state.get("almanac", [])  # older saves: none; the page falls back to the honour roll
	records = state.get("records", {})
	rivalry_history = state.get("rivalry_history", {})
	# An older save has played finals nobody counted: its count starts with the next ones.
	finals_counted_since = int(state.get("finals_counted_since",
			int(state.get("season_year", 0)) + (1 if season != null and not season.finals.is_empty() else 0)))
	achievements = state.get("achievements", {})
	career_facts = state.get("career_facts", {})
	milestone_log = Milestones.normalise(state.get("milestone_log"), self)
	_last_finish = state.get("last_finish") if state.get("last_finish") is Dictionary else {}
	departed_names = state.get("departed_names", {})
	salary_cap = int(state.get("salary_cap", 0))
	free_agents = state.get("free_agents", [])
	offseason_year = int(state.get("offseason_year", 0))
	fa_closed_year = int(state.get("fa_closed_year", 0))
	compensation = state.get("compensation", [])
	pick_owner = state.get("pick_owner", {})
	pick_got = state.get("pick_got", {})
	untouchable = state.get("untouchable", {})
	offseason_staff = state.get("offseason_staff", {})
	department_budget = state.get("department_budget", ClubBudget.defaults())
	department_budget_year = int(state.get("department_budget_year", season_year))
	Season.beat()
	_ensure_department_budget()
	season_wrap = state.get("season_wrap", {})
	offseason_log = state.get("offseason_log", [])
	trade_offers = state.get("trade_offers", [])
	trade_declined = state.get("trade_declined", {})
	trade_table = state.get("trade_table", [])
	trade_requests = state.get("trade_requests", {})
	news = state.get("news", [])
	board = state.get("board", {})
	week_events = state.get("week_events", [])
	week_checks = state.get("week_checks", {}) if state.get("week_checks") is Dictionary else {}
	if not state.has("week_events"):
		week_event = state.get("week_event", {})
	relations = state.get("relations", {})
	var raw_story: Variant = state.get("story", {})
	var old_calendar := StoryEngine.is_old_calendar(raw_story)
	if old_calendar:
		StoryEngine.migrate_calendar(raw_story)
	story = StoryEngine.ensure(raw_story if raw_story is Dictionary else {})
	media_conference = state.get("media_conference", {})
	match_stories = state.get("match_stories", []) if state.get("match_stories") is Array else []
	match_story_digest = state.get("match_story_digest", {}) if state.get("match_story_digest") is Dictionary else {}
	club_records = state.get("club_records", {}) if state.get("club_records") is Dictionary else {}
	coach_arcs = state.get("coach_arcs", {}) if state.get("coach_arcs") is Dictionary else {}
	if old_calendar:
		CoachArcs.migrate_calendar(coach_arcs)
		week_checks = {}
	preseason_run_debt = float(state.get("preseason_run_debt", 0.0))
	backing_talk = state.get("backing_talk", {})
	media_memory = state.get("media_memory", {})
	losing_streak = int(state.get("losing_streak", 0))
	# "my_matchups" in an older save is ignored: key match-ups are cut
	# (director, 2026-11-07: "Roles replace match-ups").
	last_side = state.get("last_side", [])
	# A career saved before the dials has only "difficulty" (easy, normal,
	# hard): it keeps the Fair board (the old setting never touched the board)
	# and its rivals follow the old setting.
	var legacy := DifficultyDials.from_legacy(str(state.get("difficulty", "normal")))
	board_patience = DifficultyDials.normalize(DifficultyDials.BOARD,
			str(state.get("board_patience", legacy[DifficultyDials.BOARD])))
	rival_recruiting = DifficultyDials.normalize(DifficultyDials.RIVALS,
			str(state.get("rival_recruiting", legacy[DifficultyDials.RIVALS])))
	tutorials = bool(state.get("tutorials", true))
	controversies = bool(state.get("controversies", true))
	# A save from before the switch had the saga under Controversies.
	supplements = bool(state.get("supplements", controversies))
	year_events = state.get("year_events", {}) if state.get("year_events", {}) is Dictionary else {}
	# A save from before this field is past being a fresh career.
	postseason_intro_seen = bool(state.get("postseason_intro_seen", true))
	# A save from before this field: a club you hold outside the years played
	# without you is one you coach this season.
	my_first_season = int(state.get("my_first_season",
			season_year if my_club != "" and not sim_ahead else 0))
	GameDB.draftees = state.get("db_draftees", GameDB.draftees)
	GameDB.late_draftees = state.get("db_late_draftees", [])
	GameDB._alias_next = int(state.get("db_alias_next", GameDB._alias_next))
	# Saves from before class tiers use seed 0: still one fixed roll per year.
	career_seed = int(state.get("career_seed", 0))
	dead_cap = (state.get("dead_cap", {}) as Dictionary).duplicate(true)
	conditioning = state.get("conditioning", {})
	preseason = state.get("preseason", {})
	# Saves from before the one pre-season match (director, 2026-11-03) may hold
	# the old intra-club match: it is gone, and the practice match is the match.
	preseason.erase("intra")
	training_block = state.get("training_block", {}) if state.get("training_block") is Dictionary else {}
	training_report = state.get("training_report", {}) if state.get("training_report") is Dictionary else {}
	plan_known = state.get("plan_known", {}) if state.get("plan_known") is Dictionary else {}
	plan_idle = state.get("plan_idle", {}) if state.get("plan_idle") is Dictionary else {}
	_clean_plan_known()
	rival_plans = state.get("rival_plans", {}) if state.get("rival_plans") is Dictionary else {}
	CoachEffects.usual = _season_usuals()
	CoachEffects.customs = _season_customs()
	coach_name = str(state.get("coach_name", ""))
	coach_arch = state.get("coach_arch", {}) if state.get("coach_arch") is Dictionary else {}
	interview_due = bool(state.get("interview_due", false))
	CoachEffects.my_arch = coach_arch
	captaincy = state.get("captaincy", {})
	var scouted = state.get("scouting_list", [])
	scouting_list = scouted if scouted is Array else []
	class_tiers = state.get("class_tiers", {})
	custom_prospect_id = str(state.get("custom_prospect_id", ""))
	var own_story = state.get("custom_prospect_story", {})
	custom_prospect_story = own_story if own_story is Dictionary else {}
	start_mode = str(state.get("start_mode", "redraft"))
	var ch = state.get("challenge", {})
	challenge = ch if ch is Dictionary else {}
	opening_draft = bool(state.get("opening_draft", false))
	user_dual_ruck = bool(state.get("user_dual_ruck", false))
	_sync_dual()
	_recompute_ratings()
	_migrate_money_units()
	var saved_version := int(state.get("career_version", 0))
	if saved_version < 1:
		_migrate_careers()
	if saved_version < 2:
		_migrate_player_clubs()
	_migrate_train_plans()
	_migrate_injury_logs()
	_mark_unicorns()
	_backfill_potential()
	ensure_contracts()
	if season != null and board.is_empty() and my_club != "":
		_open_board_season()
	coaches = state.get("coaches", {})
	_teach_key = ""
	coach_archive = state.get("coach_archive", {})
	staff_vacancies = state.get("staff_vacancies", [])
	coach_approaches = state.get("coach_approaches", [])
	coach_approach_year = int(state.get("coach_approach_year", 0))
	# A save from before the board kept its own: _open_board_season above
	# already set them, so only saved values replace them.
	if not (state.get("club_expect", {}) as Dictionary).is_empty():
		club_expect = state["club_expect"]
	if not (state.get("club_goals", {}) as Dictionary).is_empty():
		club_goals = state["club_goals"]
	draft_meeting_year = int(state.get("draft_meeting_year", 0))
	# A save from before the jumper fix (2026-10-07) may have two players in
	# one number on a list: renumber the later ones, once.
	if season != null:
		for code in season.lists:
			unique_jumpers(season.lists[code])
	Season.beat()
	# A save from before the coaching world: seed it for this career now.
	if season != null and coaches.is_empty():
		coaches = Coaches.seed(my_club)
	# A save whose created club started with every job vacant (before the
	# director's 2026-10-07 playtest fix): staff it now. Only a club with
	# nobody at all is touched, and not yours while you have jobs to fill.
	if season != null:
		var bare := []
		for club in GameDB.active_clubs(season_year):
			if club == my_club and not staff_vacancies.is_empty():
				continue
			bare.append(club)
		CoachMarket.staff_new_clubs(coaches, bare, my_club, season_year - 1, career_seed)
	Season.beat()
	# A card drawn before the story deck (2026-10-11) has no template behind
	# it: this week's card is drawn again from the deck, once.
	if season != null and week_event_pending() and str(week_event.get("tid", "")) == "":
		_next_week_event()
	# The honour board (row 122): an older save had none, so it is built once
	# from what the career recorded; never guessed.
	Season.beat()
	honour_board = state.get("honour_board", {}) if state.get("honour_board") is Dictionary else {}
	honour_boards = state.get("honour_boards", {}) if state.get("honour_boards") is Dictionary else {}
	if not state.has("honour_board"):
		HonourBoard.backfill(self, func(id: String) -> Dictionary: return _any_player(id))
	return true


## A save from before born Unicorns (2026-10-08): the hand-picked ones get
## their flag back wherever they now play. A Unicorn made by training under
## the old rule stays a player of his learned positions, without the trait.
func _mark_unicorns() -> void:
	var all: Array = my_list + free_agents + GameDB.draftees
	if season != null:
		for code in season.lists:
			all.append_array(season.lists[code])
	GameDB.mark_unicorns(all)


## Career records (Career.gd) arrived with save format 1; a listed player's
## club field following his list (a league re-draft) with save format 2.
const CAREER_VERSION := 2


## A save from before format 2: a re-drafted player still carried his 2026
## club. Each listed player takes the club of the list he is on, once. A
## real-lists career already agrees, so nothing there changes.
func _migrate_player_clubs() -> void:
	if season == null:
		return
	# A run you promised was stamped with the club field he had then; it moves
	# with him, or his "With us" line would drop it (Backing.memory_bits).
	for code in season.lists:
		for p in season.lists[code]:
			if p is Dictionary:
				_restamp_backed(p, str(code))
	_rehome_players(season.lists)
	for p in my_list:
		if p is Dictionary and my_club != "":
			_restamp_backed(p, my_club)
			p["club"] = my_club


## Runs made at the club field he carried before the migration now read as made
## at `club`, where he is listed. Runs made at any other club stay as they are.
func _restamp_backed(p: Dictionary, club: String) -> void:
	var old := str(p.get("club", ""))
	if old == club or not (p.get("backed") is Array):
		return
	for e in p["backed"]:
		if e is Dictionary and str(e.get("club", "")) == old:
			e["club"] = club


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
			draft._reserve_cache = float(Contracts.senior_min(GameDB.START_YEAR))
			for code in draft.club_lists:
				draft.club_spend[code] = 0
				for p in draft.club_lists[code]:
					draft.club_spend[code] = int(draft.club_spend[code]) + int(p.get("value", Ratings.salary_value(int(p.get("overall", 50)))))
			for entry in draft.pick_history:
				entry["value"] = Ratings.salary_value(int(entry.get("overall", 50)))


func delete_saved_career() -> void:
	CareerSave.delete(save_path)


# ---------------------------------------------------------------------------
# Backups and earlier saves (row 57)
# ---------------------------------------------------------------------------
## A career in memory is saved first (never mid-match: the save from before
## the match is the consistent one), so the backup is the career as it is.
func export_career() -> PackedByteArray:
	if has_career() and pending_match.is_empty():
		save_career()
	return CareerSave.export_bytes(save_path)


## A file name that says whose career it is: ard-fremantle-2027-round-6.ardsave
func export_file_name() -> String:
	var meta := _save_meta() if has_career() else saved_career_meta()
	var bits := ["ard"]
	for k in ["club_name", "year", "stage"]:
		var v := str(meta.get(k, "")).to_lower().strip_edges()
		if v != "":
			bits.append(v.replace(" ", "-").replace("'", ""))
	return "-".join(bits) + "." + CareerSave.EXPORT_EXT


## Why a backup file could not be loaded, in the coach's words, or "" once it
## is the career save (open it with load_career()).
func import_career(bytes: PackedByteArray) -> String:
	# The career in memory is saved first, so it is kept as an earlier save.
	if has_career() and pending_match.is_empty():
		save_career()
	match CareerSave.import_bytes(bytes, save_path):
		"":
			return ""
		"newer":
			return "That backup is from a newer version of the game.\nUpdate the game to load it."
	return "That file is not a career backup, or it is damaged.\nYour career is unchanged."


## The earlier saves kept for restoring, newest first (CareerSave.history).
func saved_career_history() -> Array:
	return CareerSave.history(save_path)


func restore_saved_career(slot: int) -> bool:
	# The career in memory is saved first, so it is one of the earlier saves after.
	return CareerSave.restore_history(slot, save_path, func():
		if has_career() and pending_match.is_empty():
			save_career())


func _season_to_save() -> Dictionary:
	var sv := CareerSave.object_vars(season)
	# The shape is read again from the year on load (SeasonRules.for_year).
	sv.erase("rules")
	# The season's results keep every match's stat lines (StatBook); the
	# season log keeps only scores, so no match is saved twice.
	sv["results"] = _slim_rounds()
	var fin: Dictionary = season.finals.duplicate()
	if fin.has("weeks"):
		fin["weeks"] = CareerSave.slim_results(fin["weeks"], true)
	sv["finals"] = fin
	return sv


## A played round never changes, so its slim copy (scores plus packed stat
## lines, StatBook.pack: the bulk of a save's build late in a season) is
## made once and reused by every later save. A round is looked up by the very
## array the season holds; a load or a new season holds new arrays.
var _slim_cache: Array = []   # [{"src": Array, "n": int, "out": Array}] by round


func _slim_rounds() -> Array:
	var out := []
	var rounds: Array = season.results
	if _slim_cache.size() > rounds.size():
		_slim_cache.resize(rounds.size())
	for i in range(rounds.size()):
		var src: Array = rounds[i]
		var hit: Dictionary = _slim_cache[i] if i < _slim_cache.size() else {}
		if hit.is_empty() or not is_same(hit["src"], src) or int(hit["n"]) != src.size():
			hit = {"src": src, "n": src.size(), "out": CareerSave.slim_results(src, true)}
			if i < _slim_cache.size():
				_slim_cache[i] = hit
			else:
				_slim_cache.append(hit)
		out.append(hit["out"])
	return out


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


## `next_dataset` is the real league the next career starts from (Datasets):
## today's 2026 set unless a start or a save names another.
func reset(next_dataset := Datasets.DEFAULT) -> void:
	# Mid-career seasons mutate the loaded player dicts in place (intake,
	# ageing, XP training). A new career must start from the pristine
	# dataset, so reload the data files before rebuilding anything. The caches
	# built from the players (prospect shapes, story cards) are dropped with it,
	# so a new career never reads one built under the last. PlayerProfile's rating
	# scale stays: matches on worker threads only read it (Season warms it first),
	# and clearing it let a worker rebuild it and crash (CI 38237786675).
	Prospects.forget_cache()
	StoryDeck.reload()
	# Boot already loaded the data and no career has touched it yet (the cold
	# Continue, or the first New career): reuse it rather than parse every
	# file again. A career changes the player dicts in place, so it is spent.
	# Another league's data is never reused, pristine or not.
	dataset = next_dataset
	if not GameDB.pristine or GameDB.dataset_id != dataset:
		GameDB.reload(dataset)
	GameDB.pristine = false
	# Nothing of the last career's market or caches carries into this one
	# (a second career in one process played its off-season differently).
	market_stats = {}
	_targets_signed = {}
	fa_lost = []
	recruit_undo = []
	dead_cap = {}
	_bars = {}
	_fa_phase = {}
	_repl_class = {}
	_order_cache = {}
	_standings_cache = {}
	_fringe_cache = {}
	CoachEffects.table = {}
	CoachEffects.relations = {}
	custom_club = {}
	best23 = {}
	shortlist = []
	sim_orders = {}
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
	last_medical = []
	medical_retired = []
	_medical_out = []
	season_tally = {}
	season_stats = {}
	season_stats_from = 0
	club_plan = "balanced"
	custom_plan = {}
	CoachEffects.my_custom = {}
	form_log = {}
	reserves_log = {}
	role_trial = {}
	training_block = {}
	training_report = {}
	trial_result = {}
	pos_ratings = {}
	season_team = {}
	season_awards = {}
	rising_star_noms = {"from": 1, "rounds": []}
	award_counts = AwardsCount.fresh(season_year, my_club)
	honour_roll = []
	almanac = []
	honour_board = {}
	honour_boards = {}
	records = {}
	rivalry_history = {}
	finals_counted_since = 0
	achievements = {}
	career_facts = {}
	milestone_log = Milestones.empty()
	departed_names = {}
	coaches = {}
	coach_archive = {}
	staff_vacancies = []
	coach_approaches = []
	coach_approach_year = 0
	club_expect = {}
	club_goals = {}
	_last_finish = {}
	draft_meeting_year = 0
	postseason_intro_seen = false
	my_first_season = 0
	salary_cap = 0
	free_agents = []
	offseason_year = 0
	fa_closed_year = 0
	compensation = []
	pick_owner = {}
	pick_got = {}
	untouchable = {}
	offseason_log = []
	trade_offers = []
	trade_declined = {}
	trade_table = []
	trade_requests = {}
	offseason_staff = {}
	department_budget = ClubBudget.defaults()
	department_budget_year = 0
	season_wrap = {}
	_wrap_picks = []
	news = []
	board = {}
	expansion = {}
	legacy = {}
	expansion_from = 0  # before set_canberra, which applies it to the entry years
	set_canberra(false)
	sim_ahead = false
	sim_ahead_to = SIM_AHEAD_TO
	_sim_ahead_challenge = {}
	week_events = []
	week_checks = {}
	relations = {}
	story = StoryEngine.new_state()
	media_conference = {}
	match_stories = []
	match_story_digest = {}
	club_records = {}
	coach_arcs = {}
	preseason_run_debt = 0.0
	backing_talk = {}
	media_memory = {}
	losing_streak = 0
	last_side = []
	board_patience = new_career_dial(DifficultyDials.BOARD)
	rival_recruiting = new_career_dial(DifficultyDials.RIVALS)
	tutorials = new_career_tutorials()
	controversies = new_career_controversies()
	supplements = new_career_supplements()
	year_events = {}
	# A seeded run (replay_seed, the tests) needs a seeded career too: this
	# seed picks every club's conditioning timing, staff and prospects, and a
	# random one made the same league play out differently each run.
	career_seed = randi_range(1, 999999) if replay_seed == 0 \
			else 1 + posmod(replay_seed * 7919 + 101, 999999)
	conditioning = {}
	preseason = {}
	plan_known = {}
	plan_idle = {}
	rival_plans = {}
	CoachEffects.known = {}
	CoachEffects.usual = {}
	CoachEffects.customs = {}
	coach_name = ""
	coach_arch = {}
	interview_due = false
	CoachEffects.my_arch = coach_arch
	captaincy = {}
	scouting_list = []
	class_tiers = {}
	last_training_report = {}
	_xp_grant_key = ""
	new_career_setup_requested = false
	custom_prospect_id = ""
	custom_prospect_story = {}
	user_dual_ruck = false
	_dirty = false
	default_train_plan = "position"
	start_mode = "redraft"
	challenge = {}
	opening_draft = false
	season_year = GameDB.START_YEAR
	drafted_draftees = {}
	midseason = {}
	rookie_draft = {}
	sir_doug = {}
	intake_assignments = []
	intake_summary = {}
	# The 2026 class was drafted before the career began (it is in the
	# League Draft pool); the first class drafted in the career is 2027's,
	# made exactly as a rollover makes the next year's class.
	draftee_pool = _first_class(season_year)


## The career seed the first class was made from (see start_season).
var _first_class_seed := 0


## Create the career's custom prospect from `spec` (Prospects.custom_problem
## lists what it needs). He joins the first National Draft class, drafted at
## this season's end, like any other prospect: no club, pick, OVR or POT is
## chosen, and no club is told to take him or leave him. One per career, made
## before the career's first season starts. Returns "" or what's wrong.
func add_custom_prospect(spec: Dictionary) -> String:
	if custom_prospect_id != "":
		return "This career already has its own prospect."
	if season != null:
		return "Create him before the career starts."
	var why := Prospects.custom_problem(spec)
	if why != "":
		return why
	var p := Prospects.make_custom(spec, season_year, career_seed)
	var aged := Prospects.age_pool([p], season_year, {})
	if aged.is_empty():
		return "He is too old for the draft."
	GameDB.register_draftees(aged)
	draftee_pool.append(aged[0])
	custom_prospect_id = str(aged[0]["id"])
	mark_dirty()
	return ""


## The draft class a career starting in `year` drafts at that season's end:
## generated and aged the way _start_next_season prepares next year's.
func _first_class(year: int) -> Array:
	_first_class_seed = career_seed
	# A Legacy career drafts the real class of its year (row 142, L8).
	if LegacyRollover.has_class(year):
		var real := LegacyRollover.real_class(year)
		GameDB.register_draftees(real)
		return Prospects.age_pool(real, year, {})
	var generated := Prospects.generate_class(year, career_seed)
	class_tiers[str(year)] = Prospects.class_tier(career_seed, year)
	FamilyTies.assign(generated, year, career_seed, FamilyTies.listed_entries(GameDB.players, 0.0))
	GameDB.register_draftees(generated)
	return Prospects.age_pool(generated, year, {})


## Generated family ties for a new class (bio only; see FamilyTies): relatives
## come from everyone listed now and from the retired.
func _assign_family_ties(cls: Array, year: int) -> void:
	var everyone: Array = []
	for code in league_lists:
		everyone.append_array(league_lists[code])
	var entries := FamilyTies.listed_entries(everyone, float(year - season_year))
	entries.append_array(FamilyTies.retired_entries(departed_names, year))
	FamilyTies.assign(cls, year, career_seed, entries)


## The seed for a new draft or season: the clock, or with `replay_seed` set,
## a fixed one for this year and `use`.
func _clock_seed(use: int) -> int:
	if replay_seed != 0:
		return posmod(replay_seed * 7919 + season_year * 131 + use * 17, 1000000)
	return int(Time.get_unix_time_from_system()) % 1000000


## Club Forge: add the career's one created club, before the League Draft: it
## enters with the career and drafts its list like everyone else. Making it
## again replaces it. Returns what is wrong with the spec, or "".
func create_club(spec: Dictionary) -> String:
	if draft != null or season != null:
		return "The club is made before the League Draft."
	var problem := ClubForge.club_problem(spec)
	if problem != "":
		return problem
	GameDB.unregister_custom_clubs()
	custom_club = spec.duplicate(true)
	GameDB.register_club(ClubForge.row(custom_club))
	return ""


## A real-lists career (ARD-M5-016): every founding club keeps its real
## end-of-2026 list, and the real 2026 draft class goes through the 2026
## National Draft before the first season, 2027. No 2026 season is simulated:
## the draft runs in 2026, in reverse order of the real 2026 ladder, and the
## season starts once it is done (finish_intake_draft). You choose your club
## on the draft screen. League redraft (begin_draft) is unchanged.
func begin_real_lists() -> void:
	start_mode = "real"
	opening_draft = true
	season_year = GameDB.DATA_SEASON
	my_club = ""
	my_list = []
	var active := GameDB.active_clubs(GameDB.START_YEAR)
	league_lists = {}
	for code in active:
		# The whole registered list: the players with 2026 games and those
		# without (GameDB.list_additions).
		league_lists[code] = _career_copies(GameDB.club_list(code) + GameDB.club_additions(code))
		unique_jumpers(league_lists[code])
	# The 2026 list decisions, before the draft: the retired are gone, the
	# delisted are free agents any club may sign.
	for code in active:
		for p in (league_lists[code] as Array).duplicate():
			var kind := GameDB.departure_kind(p)
			if kind == "":
				continue
			(league_lists[code] as Array).erase(p)
			if kind == "retired":
				continue
			p["released_by"] = code
			p["comp_eligible"] = false
			p["contract_years"] = 0
			free_agents.append(p)
	# The 2026 trade period and free agency (data/club_moves_2026.csv): those
	# players are on their new club's list. data_club stays the club he played
	# 2026 for, so his record still runs through 2026 there (start_season).
	var joined := {}
	for code in active:
		for p in (league_lists[code] as Array).duplicate():
			var mv := GameDB.club_move(p)
			if mv.is_empty() or str(mv["from"]) != code or not league_lists.has(str(mv["to"])):
				continue
			(league_lists[code] as Array).erase(p)
			p["data_club"] = str(p.get("data_club", code))
			p["club"] = str(mv["to"])
			# He lands on the list he really joined: the senior list (row 88),
			# a rookie at his old club included, unless the data names a
			# rookie list (a Category B signing, data/club_moves_2026.csv).
			p.erase("list_type")
			if str(mv.get("list", "")) in ["rookie", "cat_b"]:
				p["list_type"] = str(mv["list"])
			(league_lists[str(mv["to"])] as Array).append(p)
			joined[str(mv["to"])] = true
	for code in joined:
		unique_jumpers(league_lists[code])
	# Rebuild (Challenge): the bottom club of 2026, less its three best, or a
	# club joining the league built from nothing (row T5.Q25). The choice is
	# made on Choose your club; its three walk out only if the bottom club is
	# taken (choose_real_club).
	if Challenge.kind(self) == "rebuild":
		challenge["club"] = Challenge.bottom_club(active)
		challenge["gone"] = []
	intake_assignments = []
	# The real 2026 class, and the career's own prospect if it has one.
	var cls: Array = _career_copies(GameDB.draftees)
	for q in draftee_pool:
		if str(q.get("id", "")) == custom_prospect_id and custom_prospect_id != "":
			cls.append(q)
	var open_pool := []
	# The real rookies are marked first, so the 44 is counted as it stands
	# (a Category B rookie is outside it) before any tied prospect is listed.
	for code in league_lists:
		RookieList.mark_real_types(league_lists[code])
	for p in cls:
		var tie := str(p.get("tied_club", ""))
		if tie != "" and int(p.get("draft_year", 0)) == season_year and league_lists.has(tie) \
				and _tie_fits(tie):
			_assign_draftee(tie, p, str(p.get("tied_type", "tied")))
		else:
			open_pool.append(p)
	draftee_pool = draftee_pool.filter(func(q): return str(q.get("id", "")) != custom_prospect_id)
	# The starting lists split into senior and rookie lists, and the opening
	# National Draft fills the senior list.
	RookieList.seed_lists(league_lists)
	var sizes := {}
	var role_counts := {}
	var role_pairs := {}
	for code in active:
		var arr: Array = league_lists[code]
		sizes[code] = RookieList.draft_size(arr)
		var c := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
		var pairs: Array = []
		for p in arr:
			var r := str(p["role"])
			if c.has(r):
				c[r] = int(c[r]) + 1
			pairs.append([r, str(p.get("role2", ""))])
		role_counts[code] = c
		role_pairs[code] = pairs
	draft = Draft.build_intake(open_pool, active.duplicate(), opening_order(active),
			prospect_read_seed(), sizes, role_counts, role_pairs)
	draft.senior_cap = RookieList.senior_spots()
	_draft_sees_44()
	draft.user_max_age = Challenge.max_age(self)
	OwnProspect.check(self)
	mark_dirty()


## The 2026 National Draft order: the real 2026 ladder reversed, the premiers
## last and the runners-up second last (the simplified order the intake draft
## uses every year). Clubs missing from the ladder file go first, in club order.
func opening_order(active: Array) -> Array:
	var ladder := GameDB.ladder_of(GameDB.DATA_SEASON)
	var rows := []
	for r in ladder:
		if active.has(str(r["club"])):
			rows.append(r)
	var premier := ""
	var runner := ""
	for r in rows:
		if str(r["finals"]) == "premiers":
			premier = str(r["club"])
		elif str(r["finals"]) == "runners_up":
			runner = str(r["club"])
	var order := []
	for code in active:
		if not rows.any(func(r): return str(r["club"]) == code):
			order.append(code)
	for i in range(rows.size() - 1, -1, -1):
		var code := str(rows[i]["club"])
		if code != premier and code != runner:
			order.append(code)
	if runner != "":
		order.append(runner)
	if premier != "":
		order.append(premier)
	return order


## The yearly National Draft order: the ladder reversed, but the premiers pick
## last and the runners-up second last (as opening_order does for 2026).
func intake_order() -> Array:
	var order := []
	for row in season.ladder_sorted():
		# A club merged away this off-season (Fitzroy, 1996) has no seat.
		if not LegacyRollover.merged_away(self, str(row["code"])):
			order.append(str(row["code"]))
	order.reverse()
	var runner := str(season.finals.get("runner_up", ""))
	var premier_code := premier()
	for code in [runner, premier_code]:
		if code != "" and order.has(code):
			order.erase(code)
			order.append(code)
	return order


## The season-wrap word for a club-tied intake (Draft tied_type codes), as
## the draft screen says it.
static func _tie_label(kind: String) -> String:
	match kind:
		"NGA":
			return "Next Generation Academy"
		"FS":
			return "Father-son"
	return kind


## Your club in a real-lists career, chosen on the draft screen.
func choose_real_club(code: String) -> void:
	if not opening_draft or not league_lists.has(code):
		return
	# Rebuild: the bottom club is the one real list on offer; its three best
	# walk out as you take over.
	var rebuild := Challenge.kind(self) == "rebuild"
	if rebuild and code != str(challenge.get("club", "")):
		return
	if rebuild and (challenge.get("gone", []) as Array).is_empty():
		challenge["gone"] = Challenge.strip_best(self, code)
		_draft_sees_list(code)
	my_club = code
	my_list = league_lists[code]
	draft.scouting_mults[code] = recruiting_uncertainty_mult()
	draft.start_for_user(code)
	var no_spot_line := _ties_without_a_spot_line(code)
	if no_spot_line != "":
		add_news("draft", no_spot_line)
	if rebuild:
		add_news("challenge", "%s The 2026 National Draft is next." % Challenge.stated_line(self))
	mark_dirty()


## The opening draft's picture of `code`'s list (its senior count and roles),
## read again after the list changed under it (a Rebuild's walkouts).
func _draft_sees_list(code: String) -> void:
	var arr: Array = league_lists[code]
	var c := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
	var pairs: Array = []
	for p in arr:
		var r := str(p["role"])
		if c.has(r):
			c[r] = int(c[r]) + 1
		pairs.append([r, str(p.get("role2", ""))])
	draft.existing_sizes[code] = RookieList.draft_size(arr)
	draft.list_44[code] = RookieList.list_size(arr)
	draft.existing_role_counts[code] = c
	draft.existing_roles[code] = pairs


## The National Draft is told every club's list as the 44 counts it, so a
## club at or over the 44 passes its picks (RookieList.add_block's rule).
func _draft_sees_44() -> void:
	for code in draft.existing_sizes:
		if league_lists.has(code):
			draft.list_44[code] = RookieList.list_size(league_lists[code])
		elif draft.guests.has(code):
			draft.list_44[code] = RookieList.list_size(ExpansionBuild.list_of(self, str(code)))


## A father-son or academy player is listed before the draft only where the
## 44 has room for him (RookieList.add_block: the same rule as every other
## way onto a list; he may take the senior list past its spots, as he always
## could). With no room he goes into the open draft, where any club may take him.
## In a Legacy era a rival whose senior spots are full delists its least worth
## senior to take him, as a list manager would, so its list keeps the era's
## spots (Brisbane 2000 at 43 of 42); your own list stays yours to cut.
func _tie_fits(code: String) -> bool:
	var arr: Array = league_lists[code] if league_lists.has(code) else ExpansionBuild.list_of(self, code)
	var why := RookieList.add_block(arr, "senior")
	if why == "list":
		return false
	if why == "senior" and code != my_club and EraRules.is_era(season_year) \
			and season != null and season.lists.has(code):
		var staying := arr.filter(func(q): return not retiring_now(q))
		if RookieList.senior_count(staying) >= RookieList.senior_spots():
			var worst := _least_worth(staying, "")
			if not worst.is_empty():
				_release(code, worst, false)
	return true


## The tied prospects of `code` this year that it had no list spot for, by
## name: they are in the open draft.
func ties_without_a_spot(code: String) -> Array:
	var out := []
	if draft == null or code == "":
		return out
	for p in draft.pool:
		if str(p.get("tied_club", "")) == code and int(p.get("draft_year", 0)) == season_year \
				and not drafted_draftees.has(str(p["id"])):
			out.append(GameDB.player_display_name(p))
	return out


## The news line for them ("" when there are none).
func _ties_without_a_spot_line(code: String) -> String:
	var names := ties_without_a_spot(code)
	if names.is_empty():
		return ""
	return "%s No list spot for %s (father-son or academy), so %s in the open draft and any club may take %s." % [
			RookieList.over_words(RookieList.list_size(league_lists[code])), _all_names(names),
			"he is" if names.size() == 1 else "they are", "him" if names.size() == 1 else "them"]


func _all_names(names: Array) -> String:
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return "%s and %s" % [", ".join(PackedStringArray(names.slice(0, names.size() - 1))), str(names[names.size() - 1])]


# ---------------------------------------------------------------------------
# Real 2026 lists with Canberra: 2027-2029 played without you
# ---------------------------------------------------------------------------
## The first season you coach in a real-lists career with Canberra (director,
## 2026-11-08): Canberra's 2030 entry with its build, and every club,
## Tasmania and Canberra included, open to you.
const SIM_AHEAD_TO := 2030
## Your first season while the years are played without you: 2030, or 2028 when
## you take Tasmania from the real 2026 lists (director, 2026-11-09).
var sim_ahead_to := SIM_AHEAD_TO
## The challenge you set up, held back until you choose your club.
var _sim_ahead_challenge := {}

## Start the career: the real lists and the 2026 National Draft, with no club
## of yours. sim_ahead_step then plays it through to the 2029 National Draft.
func begin_sim_ahead() -> void:
	begin_real_lists()
	_hold_years_without_you(SIM_AHEAD_TO)


func _hold_years_without_you(first_season: int) -> void:
	sim_ahead = true
	sim_ahead_to = first_season
	# Your challenge starts with your first season, not with the years
	# played without you.
	_sim_ahead_challenge = challenge
	challenge = {}
	mark_dirty()


## The clubs joining the league after a real-lists career starts, which you
## can take by waiting for them (director, 2026-11-09: picking Tasmania plays
## 2027 without you and starts you in 2028). On the 2026 National Draft's club
## choice only. Canberra (2030) is here only under a Rebuild, which keeps its
## 2027 start with Canberra on; any other real-lists start with Canberra plays
## 2027-2029 without you first (row T5.Q25).
func waiting_clubs() -> Array:
	if not opening_draft or my_club != "" or sim_ahead:
		return []
	var out := []
	if GameDB.enter_year("TAS") == GameDB.START_YEAR + 1:
		out.append("TAS")
	if Challenge.kind(self) == "rebuild" and GameDB.enter_year("CANB") == SIM_AHEAD_TO:
		out.append("CANB")
	return out


## The first of waiting_clubs(), or "".
func waiting_club() -> String:
	var w := waiting_clubs()
	return str(w[0]) if not w.is_empty() else ""


## Take a waiting club: from the 2026 National Draft, the years up to its
## first National Draft are played without you (sim_ahead_step), and it is
## yours from that draft. A Rebuild taken this way builds the new club from
## nothing; the bottom club keeps its three.
func begin_wait_for_club(code: String) -> bool:
	if code == "" or not waiting_clubs().has(code):
		return false
	if Challenge.kind(self) == "rebuild":
		challenge["club"] = code
		challenge["gone"] = []
	_hold_years_without_you(GameDB.enter_year(code))
	return true


## The 2029 National Draft is open and waits for you to choose your club.
func choosing_club() -> bool:
	return sim_ahead and my_club == "" and draft != null and draft.intake_mode \
			and season != null and season_year == sim_ahead_to - 1


## One step of the years played without you, under the cover: a round, a
## week of the finals or an off-season with its drafts, each by the rules
## every club lives by (each club's own staff decides, as for any rival).
## Returns the line the cover shows next, or "" once the 2029 National Draft
## waits for your club (choosing_club) or there is nothing left to play.
func sim_ahead_step() -> String:
	if not sim_ahead or my_club != "" or choosing_club():
		return ""
	if draft != null and draft.intake_mode:
		# A draft between seasons (the 2026 one first): every club picks.
		draft.start_for_user("")
		finish_intake_draft()
		return "Starting the %d season..." % season_year
	if season == null:
		return ""
	RookieList.settle(self)
	if not season.is_season_over():
		advance()
		return "Playing %d: %s..." % [season_year, _next_week_label()]
	if begin_intake_draft():
		if choosing_club():
			return ""
		finish_intake_draft()
	else:
		start_next_season()
	return "Starting the %d season..." % season_year


## The week about to be played, for the cover ("Round 7", "the Grand Final").
func _next_week_label() -> String:
	if season == null or season.is_season_over():
		return "the off-season"
	if not season.is_regular_done():
		return season.round_label(season.round_index)
	var w := int(season.finals.get("week", 1))
	if season.finals_format() != "wildcard10":
		var again: Array = season.finals.get("replay", [])
		var name := SeasonRules.week_name(season.finals_format(), w)
		if not again.is_empty():
			name = str((season.finals_week_matches()[0] as Dictionary).get("label", name))
		return "the Grand Final" if name == "Grand Final" else ("the " + name.to_lower() if name != "" else "the finals")
	return str({1: "the Wildcard Round", 2: "the qualifying and elimination finals", 3: "the semi finals",
			4: "the preliminary finals", 5: "the Grand Final"}.get(w, "the finals"))


## Your club joins next season and you are at its first draft: the season on
## file is one it did not play, so there is no Hub to go back to yet.
func club_yet_to_play() -> bool:
	return season != null and my_club != "" and not season.lists.has(my_club)


## Your club, chosen at the 2029 National Draft after the years played
## without you. You take over as its senior coach (the coach who had the job
## is free to be hired), and from here it is your club: you make its picks in
## this draft, and a new club still building its list (Canberra) builds it
## with the same picks and sign-on money it has under its own staff.
func choose_sim_ahead_club(code: String) -> bool:
	if not choosing_club() or not draft.clubs.has(code):
		return false
	my_club = code
	my_list = league_lists[code] if league_lists.has(code) else ExpansionBuild.list_of(self, code)
	# Your career starts here: everyone on a list begins at 100% (row 125). The
	# picks in this draft, yours and theirs, still arrive as draftees.
	for c in draft.clubs:
		_clear_familiarity(league_lists[c] if league_lists.has(c) else ExpansionBuild.list_of(self, str(c)))
	if season != null:
		for c in season.lists:
			_clear_familiarity(season.lists[c])
	_clear_familiarity(free_agents)
	var sc := ClubMoves._senior_coach(self, code)
	if not sc.is_empty():
		CoachMarket._leave_job(sc, season_year)
	board = {}
	staff_vacancies = []
	coach_approaches = []
	trade_requests = {}
	week_events = []
	sim_ahead = false
	challenge = _sim_ahead_challenge
	_sim_ahead_challenge = {}
	# A Rebuild on a joining club is that club's rebuild, whether the years before
	# it were played out or read from a shipped history (begin_from_history).
	if Challenge.kind(self) == "rebuild" and GameDB.enter_year(code) > GameDB.START_YEAR 			and str(challenge.get("club", "")) != code:
		challenge["club"] = code
		challenge["gone"] = []
	draft.scouting_mults[code] = recruiting_uncertainty_mult()
	draft.start_for_user(code)
	add_news("career", "You are the new senior coach of %s, from the %d National Draft." % [
			GameDB.club_name(code), season_year])
	mark_dirty()
	autosave()
	return true


func begin_draft() -> void:
	GameDB.pristine = false   # a career's data from here on: the next reset() reloads
	var seed := _clock_seed(1)
	# The clubs of the first playable season (the founding eighteen in 2027;
	# expansion clubs arrive later with their own lists). The pool is the
	# league 2026 left behind: every listed player plus the 2026 draft class,
	# drafted before the 2027 season.
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	# Every club drafts as an equal (director, 2026-11-08): Tasmania, and
	# Canberra when the career has it, are in the 2027 redraft with the
	# founding eighteen and a created club, with no new-club concessions.
	# A past season's redraft (Legacy mode) is its own clubs only: the clubs
	# that joined later still join in their real years.
	expansion_from = GameDB.START_YEAR if dataset == Datasets.DEFAULT else 0
	_apply_entry_years()
	var clubs: Array = GameDB.active_clubs(GameDB.START_YEAR)
	var short: int = Ratings.LIST_SIZE * clubs.size() - pool.size()
	if short > 0:
		pool.append_array(Prospects.generate_depth_pool(short, GameDB.START_YEAR, str(seed)))
	draft = Draft.new(pool, clubs.duplicate(), seed)
	draft.user_max_age = Challenge.max_age(self)
	OwnProspect.check(self)


# ---------------------------------------------------------------------------
# End-of-season intake draft (the national draft: keep your list, add rookies)
# ---------------------------------------------------------------------------
## Open this year's intake. Club-tied prospects (father-son / NGA) land with
## their clubs before the draft starts; the rest forms the open pool, drafted
## in reversed-ladder order (worst club first) like the real national draft.
## Returns false when there is nothing to draft.
func begin_intake_draft() -> bool:
	# Sacked: the Hub and the season review hold the draft until he has
	# chosen a job, so a run that gets here sacked is headless and takes the
	# first club offered (_sacking_settled). A finished career has no draft.
	if season == null or not _sacking_settled():
		return false
	if not (season.is_season_over() or season.is_regular_done()):
		return false
	if draft != null and draft.intake_mode:
		return true  # resume the draft in progress
	# A rival's letter waits on the Hub; a run that drafts with it unanswered
	# (headless) says no, and the off-season opens at his club (ClubMoves).
	ClubMoves.settle_letter(self)
	open_offseason()
	recruit_undo.clear()
	_close_free_agency()
	Season.beat()
	if draftee_pool.is_empty() and season_year == GameDB.DATA_SEASON:
		# A career begun in 2026 (before 2027 starts) still drafts the real
		# 2026 class at its first season's end.
		draftee_pool = GameDB.draftees.duplicate()

	_ensure_league_lists()
	# A new club signs its state-league foundation before the draft; a Legacy
	# club's real ones past its size join this draft's pool (LegacyRollover).
	for code in ExpansionBuild.building(self):
		ExpansionBuild.ensure_foundation(self, code)
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
		var academy: String = ExpansionBuild.academy_club(self, p)
		if tie != "" and tied_this_year and league_lists.has(tie):
			if _tie_fits(tie):
				_assign_draftee(tie, p, str(p.get("tied_type", "tied")))
			else:
				open_pool.append(p)
		elif academy != "":
			ExpansionBuild.ensure_foundation(self, academy)
			if _tie_fits(academy):
				_assign_draftee(academy, p, "NGA")
			else:
				open_pool.append(p)
		else:
			open_pool.append(p)
	if my_club != "" and league_lists.has(my_club):
		my_list = league_lists[my_club]

	if open_pool.is_empty():
		# Every prospect was club-tied. Nothing to run; the caller can start
		# the next season directly. (Never happens with the shipped class.)
		return false

	var order := intake_order()

	# A new club's extra picks, and the pick it must trade: made first, because
	# that trade moves a player and the lists are measured next.
	var before_room := draftee_pool.size()
	var new_club_picks: Array = ExpansionBuild.draft_picks(self, GameDB.active_clubs(season_year).size(), open_pool.size())
	# A real foundation player a new club makes room by is in this draft.
	open_pool.append_array(draftee_pool.slice(before_room))

	var sizes := {}
	var role_counts := {}
	var role_pairs := {}
	for code in GameDB.club_order:
		var arr: Array = league_lists.get(code, [])
		sizes[code] = RookieList.draft_size(arr)
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
	# _start_next_season) rather than drafting into one - unless it is
	# building its list (ExpansionBuild): then it has a seat and early picks.
	var active := GameDB.active_clubs(season_year)
	# The scouting list read this class with prospect_read_seed all year: draft
	# night must use the same seed, or its marks, ranges and rank disagree.
	var seed := prospect_read_seed()
	draft = Draft.build_intake(open_pool, active.duplicate(), order,
			seed, sizes, role_counts, role_pairs)
	# The National Draft fills the senior list; the Rookie Draft follows.
	draft.senior_cap = RookieList.senior_spots()
	draft.user_max_age = Challenge.max_age(self)
	# Everyone gone before next season, for every club: the rollover retires
	# them (Prospects.age_league, at most MAX_RETIRE_PER_CLUB a club), so the
	# draft fills their places and does not hold them as full ones.
	for code in sizes:
		var going: Array = (league_lists.get(code, []) as Array).filter(func(q): return retiring_now(q))
		going = going.slice(0, Prospects.MAX_RETIRE_PER_CLUB)
		draft.leaving[code] = going.size()
		draft.leaving_senior[code] = RookieList.draft_size(going)
		draft.leaving_44[code] = RookieList.list_size(going)
	ExpansionBuild.seat_guests(self, draft)
	_draft_sees_44()
	var no_spot_line := _ties_without_a_spot_line(my_club) if league_lists.has(my_club) else ""
	if no_spot_line != "":
		add_news("draft", no_spot_line)
	# Recruiting funding narrows only our club's uncertainty; rivals use the
	# same scouting model at Standard rather than hidden true ratings.
	draft.scouting_mults[my_club] = recruiting_uncertainty_mult()
	var comps := []
	for c in compensation:
		if active.has(str(c["club"])):
			comps.append(c)
	comps.append_array(new_club_picks)
	draft.set_pick_owners(draft_pick_owners(season_year))
	draft.add_compensation(comps)
	# A joining club's job he took at the season's close starts here, at its
	# first National Draft, with its picks (ClubMoves, TODO T5.Q25).
	var leaving := my_club
	if ClubMoves.apply_move_at_draft(self):
		draft.scouting_mults.erase(leaving)
		draft.scouting_mults[my_club] = recruiting_uncertainty_mult()
	_watch_draft_night()
	# Played without you, the 2029 draft waits for your club (choosing_club).
	if not choosing_club():
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
	for key in pick_got.keys():
		if int(str(key).split(":")[0]) <= season_year:
			pick_got.erase(key)
	_ensure_league_lists()
	# A club building its list drafts into the list it is building.
	for code in ExpansionBuild.building(self):
		if ExpansionBuild.has_package(self, code):
			league_lists[code] = ExpansionBuild.list_of(self, code)
	var next_year := season_year + 1
	var merged := 0
	for code in GameDB.club_order:
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
			TeamFamiliarity.arrive_draftee(p)
			p["num"] = _next_jumper_number(arr)
			p["draft_pick"] = int(entry.get("pick", 0))
			p["draft_round"] = int(entry.get("round", 0))
			_mark_drafted(p, "national", int(entry.get("pick", 0)))
			Contracts.draftee_deal(p, season_year + 1)
			if not opening_draft and season != null and season.lists.has(code):
				# The yearly draft's rookies are ticked at this rollover
				# (_close_contracts ticks season.lists), so they are stored as
				# years + 1 like _resign: two full seasons, as the opening
				# draft gives. A club still building (ExpansionBuild) drafts
				# into a list the tick never reaches: it keeps the plain deal.
				p["contract_years"] = Contracts.ROOKIE_YEARS + 1
			# The opening draft has no season wrap of its own: its picks must
			# not turn up in the next year's wrap.
			if code == my_club and not opening_draft:
				_wrap_picks.append([id, int(entry.get("pick", 0))])
			arr.append(p)
			drafted_draftees[id] = code
	OwnProspect.check(self, season_year)
	# Your picks that passed for a full list go in the draft-night news.
	var passed_line: String = draft.user_passed_line()
	if passed_line != "":
		add_news("draft", "National Draft: " + passed_line)
	draft = null
	if opening_draft:
		# The 2026 National Draft is done: the first season, 2027, starts on
		# these lists. Nothing ages, develops or retires; the real 2026
		# history is added once, by start_season.
		opening_draft = false
		draft_meeting_year = 0
		season_year = GameDB.START_YEAR
		start_season(my_club, league_lists.get(my_club, []))
		# Rebuild: the players who walked out sign with rival clubs for 2027.
		Challenge.place_gone(self)
		open_preseason(false)   # saved once, below
		# The Rookie Draft follows the opening National Draft too, in its order.
		RookieList.open_draft(self, opening_order(GameDB.active_clubs(season_year)))
		autosave()
		return true
	# The Rookie Draft follows in the same order (RookieList).
	var rookie_order := intake_order() if season != null else []
	_start_next_season(next_year, merged)
	RookieList.open_draft(self, rookie_order)
	autosave()
	return true


## Roll every list forward one year and rebuild the season. Split out so a
## career can continue even when there is no prospect pool to draft.
## "real name|dob" of every real man the career already holds: on a list, a
## list a new club is building, the free agents or the draft pool.
func _real_people() -> Dictionary:
	var out := {}
	var add := func(p: Dictionary) -> void:
		var dob := str(p.get("dob", ""))
		if str(p.get("real_name", "")) != "" and dob.length() >= 10:
			out["%s|%s" % [str(p["real_name"]), dob]] = true
	var lists: Array = []
	if season != null:
		lists.append_array(season.lists.values())
	lists.append_array(league_lists.values())
	for code in ExpansionBuild.building(self):
		lists.append(ExpansionBuild.list_of(self, code))
	lists.append(free_agents)
	lists.append(draftee_pool)
	for arr in lists:
		for p in arr:
			if p is Dictionary:
				add.call(p)
	return out


func _start_next_season(next_year: int, signed: int) -> void:
	# His first postseason is over, seen or not; a season played without
	# you is not his (bug-bash 6).
	if my_first_season != 0 and season_year >= my_first_season:
		postseason_intro_seen = true
	# Where every club finished: next season's board reads it (ClubLife.board_goal).
	_last_finish = {}
	if season != null:
		var table := season.ladder_sorted()
		for k in range(table.size()):
			_last_finish[str(table[k]["code"])] = k + 1
	# Undecided assistants stay; then no staff job starts the season empty.
	_settle_staff_contracts()
	_fill_open_staff()
	_expire_my_promises()
	Season.beat()
	# The honour board (row 122): anyone who left in the off-season (a trade,
	# free agency) is stamped with the season he left after, before the year
	# turns over and before a club move changes whose board it is.
	HonourBoard.sweep(self)
	# A Legacy career: who played finals, and the Fitzroy merger story
	# (settled before the coach moves, so a Fitzroy coach goes to Brisbane).
	LegacyRollover.note_finals(self)
	LegacyRollover.before_moves(self, next_year)
	# Coach arcs: a club change decided at the season's close is made now.
	ClubMoves.apply_move(self)
	# The season's close normally counted careers already (Career skips a
	# season it has seen); this covers a season rolled on without one.
	if season != null:
		var played := {}
		for code in season.lists:
			for p in season.lists[code]:
				played[str(p["id"])] = p
		Career.close_season(played, season_tally, season_year, season_stats, season_stats_from)
	LegacyRollover.merge_lists(self)
	# A canon move (Dangerfield to Geelong) or the merger lands after the
	# off-season's trim: the club that took him delists to its era's spots
	# again, before free agency closes, so the one let go still has a market.
	if season != null:
		_era_trim_rivals()
	Season.beat()
	# Next year's generated class joins the pool before ageing, so the fresh
	# 17-year-olds are also a year older in the season they arrive. A Legacy
	# career's is that year's real class.
	var generated := []
	if LegacyRollover.has_class(next_year):
		# A man already in the career (a new club's state-league signing who
		# was later drafted in real life, Maverick Weller) is not drafted twice.
		var here := _real_people()
		generated = LegacyRollover.real_class(next_year).filter(func(q):
			return not here.has("%s|%s" % [str(q.get("real_name", "")), str(q.get("dob", ""))]))
	else:
		generated = Prospects.generate_class(next_year, career_seed)
		class_tiers[str(next_year)] = Prospects.class_tier(career_seed, next_year)
		_assign_family_ties(generated, next_year)
	GameDB.register_draftees(generated)
	for p in generated:
		draftee_pool.append(p)

	Season.beat()
	# Free agents are on no list until a rival signs them, so heal after
	# free agency closes, and heal the season's lists too.
	_close_contracts()
	Season.beat()
	# A club that built its list (ExpansionBuild) brings it now, so its
	# players age into their first season with everyone else.
	for code in GameDB.club_order:
		if GameDB.enter_year(code) == next_year and ExpansionBuild.enter(self, code):
			add_news("expansion", "%s (the %s) join the competition for %d, their first season. %s" % [
					GameDB.club_name(code), GameDB.club_short(code), next_year,
					ExpansionBuild.entry_line(self, code)])
	Workload.reset(league_lists)
	Workload.reset({"free_agents": free_agents})
	Injuries.heal_all(league_lists)
	if season != null:
		Workload.reset(season.lists)
		Injuries.heal_all(season.lists)
	# A run you promised does not carry into the next season: it lapses, for
	# every list and for free agents, so a player traded or released never
	# takes it to another club.
	for code in league_lists:
		for p in league_lists[code]:
			Backing.lapse(p)
	for p in free_agents:
		Backing.lapse(p)
		# Not on a list, so not given back: a stale record must not count
		# again next season (row 90).
		p.erase("season_gains")
	# Brownlow eligibility is season-specific. A new season starts clean.
	var seen_brownlow := {}
	for code in league_lists:
		for p in league_lists[code]:
			var id := str(p.get("id", ""))
			if seen_brownlow.has(id):
				continue
			seen_brownlow[id] = true
			p.erase("brownlow_ineligible")
			p.erase("brownlow_ineligible_cases")
	for p in free_agents:
		p.erase("brownlow_ineligible")
		p.erase("brownlow_ineligible_cases")
	season_tally = {}
	season_stats = {}
	season_stats_from = 0
	form_log = {}
	reserves_log = {}
	role_trial = {}
	training_block = {}
	training_report = {}
	trial_result = {}
	pos_ratings = {}
	season_team = {}
	rival_plans = {}
	CoachEffects.usual = {}
	CoachEffects.customs = {}
	season_awards = {}
	rising_star_noms = {"from": 1, "rounds": []}
	award_counts = AwardsCount.fresh(season_year, my_club)
	# Everyone listed before ageing: a retiree leaves the lists inside
	# age_league, and his playing career must be captured from him first.
	var listed := {}
	for code in league_lists:
		for p in league_lists[code]:
			listed[str(p["id"])] = p
	# The season's training, measured on the season's lists before anyone
	# ages or retires; given back after ageing, before the re-anchor (row 90).
	var train_unwind := Prospects.training_unwind(league_lists, next_year)
	Season.beat()
	intake_summary = Prospects.age_league(league_lists, next_year, _rollover_min_left)
	Season.beat()
	intake_summary["signed"] = signed
	# A free agent still in the pool (_fa_staying) is a year older too; out of
	# the game, he does not develop.
	for p in free_agents:
		p["age"] = float(p.get("age", 25.0)) + 1.0
	_retirees_to_coaching(intake_summary.get("retired", []), listed)
	_add_retired_legends(listed)
	for r in intake_summary.get("retired", []):
		if int(r.get("overall", 0)) >= NEWS_MIN_OVR:
			add_news("retirement", "%s (%s) has retired at %d." % [
					GameDB.player_display_name_by_id(str(r["id"]), str(r["name"])),
					GameDB.club_name(str(r["club"])), int(float(r["age"]))])
	intake_summary["year"] = next_year
	draftee_pool = Prospects.age_pool(draftee_pool, next_year, drafted_draftees)
	Season.beat()
	# Expansion: any club whose first season is next_year arrives with a
	# generated list (aged across the full range, not just a rookie class),
	# so it ages, drafts, trains and simulates like every other club.
	for code in GameDB.club_order:
		if GameDB.enter_year(code) != next_year:
			continue
		if not (league_lists.get(code, []) as Array).is_empty():
			continue
		league_lists[code] = Prospects.generate_expansion_list(code, next_year)
		add_news("expansion", "%s (the %s) join the competition for %d, their first season." % [
				GameDB.club_name(code), GameDB.club_short(code), next_year])
	Prospects.apply_training_unwind(league_lists, train_unwind)
	intake_summary["renormalised"] = Prospects.renormalise_league(league_lists,
		draftee_pool, GameDB.baseline_overall, GameDB.baseline_spread)
	Season.beat()

	# One array per club from here on: the season, the league lists and your
	# list are the same arrays, so trades and signings touch them all.
	var lists := {}
	for code in GameDB.club_order:
		lists[code] = league_lists.get(code, [])
		for p in lists[code]:
			p["season_start_ov"] = int(p["overall"])
			p.erase("season_gains")
	my_list = lists.get(my_club, [])
	# The season simulates only this year's active clubs; `lists` keeps an
	# entry for every club so saves and rollovers never miss a key.
	season = Season.new(GameDB.active_clubs(next_year).duplicate(), lists,
			_clock_seed(3), next_year)
	_sync_dual()
	Season.beat()
	# The cap moves with the new season before contracts are assigned.
	salary_cap = Contracts.salary_cap_for_year(next_year)
	# Money too: contracts assigned below are in the new season's dollars
	# (season_year, whose setter also does this, moves only further down).
	Contracts.money_year = next_year
	# Expansion lists are born here, so their contracts must be assigned
	# here too (start_season does the same for the first season).
	ensure_contracts()
	ExpansionBuild.set_relief(self, next_year)
	season_year = next_year
	# The clubs as they were this year (the Bears until 1997); today's years change nothing.
	GameDB.apply_era(season_year)
	_fill_short_lists()
	if my_first_season == 0 and my_club != "" and not sim_ahead:
		my_first_season = season_year
	# Dynamic rivalries cool once a season when two clubs stop meeting.
	Rivalries.age(rivalry_history, season_year)
	season_log = []
	last_training_report = {}
	_xp_grant_key = ""
	last_results = []
	last_match = {}
	last_medical = []
	last_phase = "regular"
	last_label = "Round 1"
	pending_match = {}
	pending_sim = null
	_collect_others()
	Season.beat()
	pending_round_results = []
	pending_phase = ""
	pending_label = ""
	_open_board_season()
	_captaincy_refresh()
	_ground_rename_news()
	_culture_rollover()
	_build_season_wrap(next_year)
	# The season those careers ended in is wrapped up: nothing reads them again.
	medical_retired = medical_retired.filter(func(r): return r is Dictionary and int(r.get("year", 0)) >= season_year)
	OwnProspect.check(self)
	preseason = {}
	open_preseason(false)   # the caller saves once, when the rollover is done


## The careers the medical panel ended in `year` (MedicalPanel), any club.
func _medical_retirees(year: int) -> Array:
	return medical_retired.filter(func(r): return r is Dictionary and int(r.get("year", 0)) == year)


## The backstop for the year's list minimum (director, 2026-11-13: lists by
## era): the draft counts every retiree, but a list can still start a season
## short (a club change, a merger, an era's minimum rising). Every club under
## Contracts.min_list() signs the best free agents left, yours included, and
## the news says so.
func _fill_short_lists() -> void:
	if season == null:
		return
	for code in GameDB.active_clubs(season_year):
		if not season.lists.has(code):
			continue
		var list: Array = season.lists[code]
		var short := Contracts.min_list() - list.size()
		if short <= 0:
			continue
		var pool := free_agents.filter(func(q): return not bool(q.get("retired", false)))
		pool.sort_custom(func(a, b):
			if int(a.get("overall", 0)) != int(b.get("overall", 0)):
				return int(a.get("overall", 0)) > int(b.get("overall", 0))
			return str(a["id"]) < str(b["id"]))
		var names: PackedStringArray = []
		for p in pool.slice(0, short):
			var want := Contracts.wants(p)
			_sign_fa(p, str(code), int(want["salary"]), int(want["years"]))
			p.erase("fa_kept")
			names.append(GameDB.player_display_name(p))
		if names.is_empty():
			continue
		add_news("contract", "%s were %d short of the %d-player list minimum for %d and signed %s from the free agents." % [
				GameDB.club_name(str(code)), short, Contracts.min_list(), season_year,
				_names_words(names)])


static func _names_words(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## The season's retirees who are legends of your club go on its almanac page:
## the off-season's (still in `listed`, id -> player) and the ones the medical
## panel retired during the season, who left the lists that week.
func _add_retired_legends(listed: Dictionary) -> void:
	var retired: Array = (intake_summary.get("retired", []) as Array).duplicate()
	var known := listed.duplicate()
	for row in _medical_retirees(season_year):
		var r: Dictionary = row
		if r.get("player") is Dictionary and not known.has(str(r.get("id", ""))):
			known[str(r["id"])] = r["player"]
			retired.append(r)
	Almanac.add_legends(self, retired, known)


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
	var trade_lines := []
	for e in offseason_log:
		match str(e.get("kind", "")):
			"ai_trade", "offer_declined":
				trade_lines.append(str(e.get("text", "")))
			"signed":
				if str(e.get("club", "")) == my_club:
					ins.append({"id": str(e["id"]), "how": "free agent"})
			"released":
				if str(e.get("club", "")) == my_club:
					var how := "free agent" if bool(e.get("wanted", false)) else "delisted"
					if str(e.get("to", "")) != "":
						how = "signed with %s" % GameDB.club_name(str(e["to"]))
						if comp_after.has(str(e["id"])):
							how += "; compensation pick after pick %d" % int(comp_after[str(e["id"])])
					elif comp_after.has(str(e["id"])):
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
			ins.append({"id": str(a["player_id"]), "how": _tie_label(str(a.get("kind", ""))), "name": str(a.get("player_name", ""))})
	for pk in _wrap_picks:
		ins.append({"id": str(pk[0]), "how": "pick %d" % int(pk[1])})
	_wrap_picks = []
	for r in intake_summary.get("retired", []):
		if str(r.get("club", "")) == my_club:
			outs.append({"id": str(r["id"]), "how": "retired", "name": str(r.get("name", ""))})
	# A career the medical panel ended during the season just gone is one of its
	# retirements too.
	for r in _medical_retirees(year - 1):
		if str(r.get("club", "")) == my_club:
			outs.append({"id": str(r["id"]), "how": "retired, medical panel", "name": str(r.get("name", ""))})
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
	season_wrap = {"year": year, "ins": ins, "outs": outs, "staff": staff_lines, "trades": trade_lines,
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


## Why the board set this season's goal, in a sentence, with where the list
## ranks on paper (ClubLife.goal_reason). A save from before the board kept
## the club count reads it from this season's rankings.
func board_goal_reason() -> String:
	return ClubLife.goal_reason(board.get("goal", {}), int(board.get("rank", 0)),
			int(board.get("clubs", club_expect.size())))


## Mark the briefing read: the season can begin.
func begin_season_from_wrap() -> void:
	season_wrap["seen"] = true
	mark_dirty()
	autosave()


func needs_season_wrap() -> bool:
	return not season_wrap.is_empty() and not bool(season_wrap.get("seen", true)) \
			and int(season_wrap.get("year", 0)) == season_year


## The smallest a list may be left at by the rollover's retirements
## (Prospects.age_league): 0 after a National Draft, which refills every list;
## the list minimum on a rollover with no draft (start_next_season).
var _rollover_min_left := 0


## Roll on without an intake (no prospects available, or the manager skipped
## the draft). Same ageing and rebuild, zero new signings.
func start_next_season() -> bool:
	if season == null or not _sacking_settled():
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
	# No draft refills the lists, so no retirement takes one under the minimum.
	_rollover_min_left = Contracts.min_list()
	_start_next_season(season_year + 1, 0)
	_rollover_min_left = 0
	autosave()
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
	var arr: Array = league_lists[code] if league_lists.has(code) else ExpansionBuild.list_of(self, code)
	if not p.has("xp"):
		p["xp"] = 0
		p["xp_games"] = 0
	p["club"] = code
	TeamFamiliarity.arrive_draftee(p)
	p["num"] = _next_jumper_number(arr)
	p["draft_pick"] = 0
	_mark_drafted(p, kind, 0)
	Contracts.draftee_deal(p, season_year + 1)
	if not opening_draft and season != null and season.lists.has(code):
		# Same as a national-draft rookie (finish_intake_draft): the yearly
		# tie lands on a list _close_contracts ticks at this rollover, so it
		# is stored as years + 1 to start next season with two.
		p["contract_years"] = Contracts.ROOKIE_YEARS + 1
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
func _mark_drafted(p: Dictionary, kind: String, pick: int, club := "") -> void:
	p["drafted_year"] = season_year
	p["drafted_type"] = kind
	# The club that first drafted him: a home-grown player (Challenge goals).
	# Older saves lack it, and a player is only ever marked once.
	if not p.has("drafted_club"):
		p["drafted_club"] = club if club != "" else str(p.get("club", ""))
	if pick > 0:
		p["drafted_pick"] = pick
	else:
		p.erase("drafted_pick")


## One player per number on a list. The first to hold a number (list order:
## the earliest pick in a League Draft) keeps it; anyone else wearing it, or
## none, takes the next free one. Nobody else is renumbered. Returns how many
## changed.
static func unique_jumpers(list: Array) -> int:
	var used := {}
	var changed := 0
	var clash := []
	for p in list:
		var n := int(p.get("num", 0))
		if n <= 0 or used.has(n):
			clash.append(p)
		else:
			used[n] = true
	for p in clash:
		var free := 99
		for n in range(41, 90):
			if not used.has(n):
				free = n
				break
		if free == 99:
			for n in range(1, 41):
				if not used.has(n):
					free = n
					break
		p["num"] = free
		used[free] = true
		changed += 1
	return changed


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
	GameDB.pristine = false   # a career's data from here on: the next reset() reloads
	my_club = club_code
	if my_first_season == 0 and my_club != "" and not sim_ahead:
		my_first_season = season_year
	var lists := {}
	# A league re-draft moves players between clubs: each arrives carrying his
	# 2026 club, and takes his new club's code once his record is written below.
	var rehome := false
	if start_mode == "real" and not league_lists.is_empty() and season == null:
		# A real-lists career: each club's real list plus its 2026 draftees,
		# already career copies (begin_real_lists).
		for code in GameDB.club_order:
			if league_lists.has(code):
				lists[code] = league_lists[code]
	elif draft != null and draft.league_mode and draft.is_finished():
		league_lists = draft.all_lists()
		rehome = true
		for code in GameDB.club_order:
			lists[code] = _career_copies(league_lists.get(code, []))
			# Drafted players arrive in their old clubs' numbers: two 35s can
			# land on one list (director's PC playtest, 2026-10-07).
			unique_jumpers(lists[code])
		# A re-drafted list of 44 splits into 38 seniors
		# and six rookies, the youngest.
		RookieList.seed_lists(lists, false)
		# The 2026 draft class had never been drafted: the club that took
		# him in the League redraft first drafted him (home-grown, Challenge).
		# Real players keep the club that drafted them in the AFL.
		for code in lists:
			for p in lists[code]:
				if str(p.get("id", "")).begins_with("D2026_") and not p.has("drafted_club"):
					p["drafted_club"] = code
	else:
		# Fallback for tests or old saves: your drafted list plus real AI lists.
		for code in GameDB.club_order:
			var source: Array = list if code == club_code else GameDB.club_list(code)
			lists[code] = _career_copies(source)
			# The raw data can hold two players in one number (SYD 36): the
			# same rule as every other start, or a reload renumbers him and
			# the saved career no longer matches the one played straight.
			unique_jumpers(lists[code])
	# Career copies, not the shared database rows. Training must not rewrite
	# the draft pool for the next career.
	my_list = lists.get(my_club, [])
	# reset() made the first class from the seed it rolled; a career whose seed
	# was set since (a replay, an audit) makes it from its own, or two runs of
	# the same seed draft different classes.
	if drafted_draftees.is_empty() and _first_class_seed != career_seed:
		# The career's own prospect (add_custom_prospect) stays in the class.
		var own := draftee_pool.filter(func(q): return str(q.get("id", "")) == custom_prospect_id)
		draftee_pool = _first_class(season_year) + own
	Workload.reset(lists)
	# The real 2026 season is history before the career starts: every real
	# player's record runs through 2026, at the club he played it for. A
	# 2026 draftee has no senior games; his record starts after 2026 too.
	if season_year > GameDB.DATA_SEASON:
		for code in lists:
			for p in lists[code]:
				Career.add_season(p, GameDB.DATA_SEASON, str(p.get("data_club", p.get("club", ""))),
						int(float(p.get("gm", 0.0))), int(float(p.get("gl", 0.0))))
	if rehome:
		_rehome_players(lists)
	# Fixtures, ladders and finals cover only the clubs active this year.
	season = Season.new(GameDB.active_clubs(season_year).duplicate(), lists,
			_clock_seed(4), season_year)
	_sync_dual()
	salary_cap = Contracts.salary_cap_for_year(season_year)
	ensure_contracts()
	# The coaching world from its Round 1 2026 source, carried into this
	# career's first season with you in your club's top job.
	coaches = Coaches.seed(my_club)
	# A created club has no 2026 staff to seed: it hires now, as an expansion
	# club does before its first season.
	CoachMarket.staff_new_clubs(coaches, GameDB.active_clubs(season_year), my_club, season_year - 1, career_seed)
	_ensure_department_budget()
	if department_budget_year <= 0:
		department_budget_year = season_year
	_open_board_season()
	_captaincy_refresh()
	_ground_rename_news()
	last_phase = "regular"
	last_label = "Round 1"
	last_training_report = {}
	_xp_grant_key = ""
	autosave()


## The match you are about to coach, from the clubs' sides as they stand now
## (prepare_interactive_match and the finals one fill _pending_build first).
func _build_pending_sim() -> void:
	var h := str(pending_match["home"])
	var a := str(pending_match["away"])
	var at_home: Array = _pending_build["at_home"]
	var home := Squad.new(GameDB.club_name(h), season.lists[h], bool(at_home[0]), h, season.selections.get(h, {}))
	var away := Squad.new(GameDB.club_name(a), season.lists[a], bool(at_home[1]), a, season.selections.get(a, {}))
	home.form = season.club_form(h)
	away.form = season.club_form(a)
	CoachEffects.apply(home)
	CoachEffects.apply(away)
	pending_sim = MatchSim.new(home, away, int(_pending_build["seed"]))
	pending_sim.finals_mode = bool(_pending_build["finals"])
	pending_sim.extra_time_allowed = bool(_pending_build.get("extra_time", true))
	pending_sim.weather = _pending_build["weather"]
	pending_sim.season_year = season.year
	pending_sim.moment_side = 0 if h == my_club else 1
	pending_sim.always_offer_bounce = bounce_scene_every_match()
	pending_sim.set_tactics(pending_sim.moment_side, {"gameplan": club_plan})
	_pending_build["sim"] = pending_sim


## True from Play match until the first bounce: the match is set up and every
## pre-match call (the side included) can still change (TODO row 25).
func match_day_setup_open() -> bool:
	return pending_sim != null and not pending_match.is_empty() and _pending_build.get("sim") == pending_sim \
			and pending_sim.events.is_empty() and pending_sim.current_quarter == 1


## The side changed on Team selection before the first bounce: the match is
## made again from the new side, with the same seed, weather and plan, and
## every call you made on the setup that the new side still allows.
func rebuild_pending_side() -> void:
	if match_day_setup_open():
		var old: MatchSim = pending_sim
		_build_pending_sim()
		_carry_calls(old, pending_sim)
	side_from_match = false


## Your calls from the old match onto the one made from the new side. A call
## that needs a player no longer in the side goes back to the assistant's pick
## for that call only; the rest stay yours.
func _carry_calls(old: MatchSim, sim: MatchSim) -> void:
	var side := sim.moment_side
	var mine: Squad = sim.squads[side]
	var on_ground := {}
	for p in mine.ground:
		on_ground[str(p["id"])] = true
	# The loose man: yours stays yours; the assistant's stays his if he still plays.
	var loose := str(old.interceptor[side])
	if loose == "" or sim.taking_part(side, loose):
		if bool((old._own[side] as Dictionary)["interceptor"]):
			sim.coach_interceptor(side, loose)
		else:
			sim.set_interceptor(side, loose, false)
	# Plan, Play through, tag, who tags, the minder on their spare and the pep talk.
	var t: Dictionary = (old.tactics[side] as Dictionary).duplicate()
	t.erase("interceptor_id")
	t.erase("interceptor_set")
	if str(t.get("tagger_id", "")) != "" and not sim.taking_part(side, str(t["tagger_id"])):
		t["tagger_id"] = ""
	# A Play through pick no longer in the side goes back to no one.
	for slot in MatchSim.FOCUS_SLOT_ROLES:
		if str(t.get(slot, "")) != "" and not sim.taking_part(side, str(t[slot])):
			t[slot] = ""
	if bool(t.get("spare_accountable", false)) and not on_ground.has(str(t.get("spare_minder_id", ""))):
		var minders := Matchups.minder_candidates(mine.ground)
		if minders.is_empty():
			t["spare_accountable"] = false
			t["spare_minder_id"] = ""
		else:
			t["spare_minder_id"] = str(minders[0]["id"])
	sim.set_tactics(side, t)


## Set when Change the side leaves the match-day setup for Team selection.
var side_from_match := false


## Set up your next match (home-and-away round or final) to be played live,
## quarter by quarter, with the coach box. Every other match that week is
## simulated straight away. Returns false when you have no match to play.
func prepare_interactive_match() -> bool:
	if season == null or season.is_season_over():
		return false
	match_way_live = match_way()
	preseason_sim_to_round1()
	_settle_week_event()
	MidseasonDraft.settle(self)
	RookieList.settle(self)
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
	_settle_usual_plans()
	# This week's conditioning, before any of the week's matches is built.
	_stamp_conditioning()
	var round_matches: Array = season.fixture[season.round_index]
	var others := []
	for i in range(round_matches.size()):
		var m: Dictionary = round_matches[i]
		if m["home"] == my_club or m["away"] == my_club:
			pending_match = {"home": m["home"], "away": m["away"],
					"round": season.round_index + 1,
					"label": season.round_label(season.round_index)}
			# Gather Round: the host ground it is staged at (GatherRound).
			if season.round_index == season.gather_round():
				pending_match["venue"] = season.round_venue(season.round_index, str(m["home"]), str(m["away"]))
		else:
			others.append(season.match_sim(m["home"], m["away"], season.next_seed(i),
					season.round_at_home(season.round_index, m["home"], m["away"]), false,
					season.weather_for(m["home"], m["away"], season.round_index)))
	if pending_match.is_empty():
		# Your bye: record nothing, the caller's advance() plays the whole round.
		return false
	# The rest of the round plays out in the background while you coach
	# yours (none of it touches your match), and is collected at full time.
	_others = Season.start_all(others)
	_pending_build = {"at_home": season.round_at_home(season.round_index, str(pending_match["home"]),
			str(pending_match["away"])), "seed": season.next_seed(99), "finals": false,
			"weather": season.weather_for(str(pending_match["home"]), str(pending_match["away"]), season.round_index)}
	_build_pending_sim()
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
	_stamp_conditioning()
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
	# The coaching table first: the week's other finals use it too (it is not
	# saved, so after loading it would be empty), as on the regular-round path.
	_refresh_coach_tactics()
	_settle_usual_plans()
	var others := []
	var index := []
	for i in range(matches.size()):
		var m: Dictionary = matches[i]
		if i == mine or m["home"] == "" or m["away"] == "":
			continue
		others.append(season.match_sim(m["home"], m["away"], season.finals_seed(i),
				season.finals_at_home(m), true,
				season.weather_for(m["home"], m["away"], season.finals_round(), m)))
		(others[others.size() - 1] as MatchSim).extra_time_allowed = season.finals_extra_time(m)
		index.append(i)
	_others = Season.start_all(others)
	_others["index"] = index
	var fm: Dictionary = matches[mine]
	var at_home: Array = season.finals_at_home(fm)
	pending_match = {"home": fm["home"], "away": fm["away"],
			"round": season.finals_round(),
			"label": str(fm["label"]), "tag": str(fm["tag"]),
			"venue": season.finals_venue(fm), "finals_index": mine}
	_pending_build = {"at_home": at_home, "seed": season.finals_seed(mine), "finals": true,
			"weather": season.weather_for(str(fm["home"]), str(fm["away"]), season.finals_round(), fm),
			"extra_time": season.finals_extra_time(fm)}
	_build_pending_sim()
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
	if pending_phase == "practice":
		_finish_live_practice(res)
		return
	if pending_phase == "finals":
		_finish_interactive_final(res)
		return
	res["round"] = int(pending_match.get("round", season.round_index + 1))
	res["label"] = str(pending_match.get("label", "Match"))
	# Gather Round: every match keeps the host ground it was staged at.
	var gather := int(res["round"]) - 1 == season.gather_round()
	if gather:
		res["venue"] = str(pending_match.get("venue", ""))
	for r in _collect_others():
		r["round"] = res["round"]
		r["label"] = res["label"]
		if gather:
			r["venue"] = season.round_venue(int(res["round"]) - 1, str(r["home"]), str(r["away"]))
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
		season.start_finals(YearEvents.finals_banned(self))


## advance() with the week's matches run on threads while the screen keeps
## drawing frames: the loading cover's set shot plays on (in a browser too,
## where nothing draws until the game hands control back). Same steps, same
## matches, same order, so the same results as advance().
func advance_async() -> String:
	if season == null:
		return advance()
	_advance_prep()
	ensure_finals()          # a no-op before the finals; advance() does it first there too
	var job := season.start_week()
	while Season.running(job):
		await get_tree().process_frame
	_advance_reset()
	# A browser shows a frame only between JavaScript tasks: a frame between
	# the steps after the matches keeps the cover's ball from hanging.
	for step in _play_steps():
		await get_tree().process_frame
		var stop: String = step.call()
		if stop != "":
			return stop
	return last_phase


## Play the next round (or finals week). Returns the phase it played.
func advance() -> String:
	# Season.beat() between the steps, as in _restore_career: the cover's ball
	# keeps moving through Sim the week and a skip.
	if season == null:
		return "none"
	_advance_prep()
	_advance_reset()
	for step in _play_steps():
		Season.beat()
		var stop: String = step.call()
		if stop != "":
			return stop
	Season.beat()
	return last_phase


func _advance_reset() -> void:
	last_results = []
	last_match = {}
	last_pos_before = my_position()


## The week's steps before its matches.
func _advance_prep() -> void:
	recruit_undo.clear()
	Season.beat()
	preseason_sim_to_round1()
	Season.beat()
	_settle_week_event()
	Season.beat()
	MidseasonDraft.settle(self)
	Season.beat()
	RookieList.settle(self)
	Season.beat()
	_sync_club_plan()
	Season.beat()
	_refresh_coach_tactics()
	Season.beat()
	if not season.is_season_over():
		_settle_usual_plans()
	Season.beat()
	_stamp_conditioning()


## The week's matches and everything after them, in order. Each step returns
## "" to go on, or the phase to stop at.
func _play_steps() -> Array[Callable]:
	return [_play_week, _log_week, _week_xp, _week_rivals, _week_after, _week_save]


func _play_week() -> String:
	if not season.is_regular_done():
		last_results = season.play_round()
		last_phase = "regular"
		last_label = season.round_label(season.round_index - 1)
		ensure_finals()
	elif not season.is_season_over():
		ensure_finals()
		var week := int(season.finals.get("week", 1))
		var past := _finals_week_title()
		last_results = season.play_finals_week()
		last_phase = "finals"
		var labels := {1: "Wildcard Round", 2: "Qualifying & Elimination Finals",
				3: "Semi Finals", 4: "Preliminary Finals", 5: "Grand Final"}
		last_label = str(labels.get(week, "Finals Week %d" % week)) if past == "" else past
		if season.is_season_over():
			last_phase = "done"
	else:
		last_phase = "done"
		return "done"
	return ""


## The coming finals week's title in a past year's series ("Semi Finals",
## "Qualifying Final Replay"); "" in the game's league (its own labels).
func _finals_week_title() -> String:
	if season.finals_format() == "wildcard10":
		return ""
	if not (season.finals.get("replay", []) as Array).is_empty():
		return str((season.finals_week_matches()[0] as Dictionary).get("label", "Finals"))
	return SeasonRules.week_name(season.finals_format(), int(season.finals.get("week", 1)))


func _week_xp() -> String:
	_grant_match_xp(last_match)
	return ""


func _week_rivals() -> String:
	_train_rivals(last_results)
	_record_rivalries(last_results)
	return ""


func _week_after() -> String:
	_after_round(last_results)
	return ""


func _week_save() -> String:
	autosave()
	return ""


func _log_week() -> String:
	for res in last_results:
		season_log.append(res)
		if res["home"] == my_club or res["away"] == my_club:
			last_match = res
	return ""



# ---------------------------------------------------------------------------
# Season conditioning (Conditioning.gd)
# ---------------------------------------------------------------------------
## The week about to be played: 0..23 the home-and-away rounds, 24.. the
## finals weeks.
func fitness_week() -> int:
	if season == null:
		return 0
	if not season.is_regular_done():
		return season.round_index
	return season.finals_round() - 1


## Only your club has a department budget; AI clubs run Standard (a known
## parity gap: AI clubs cannot invest).
func fitness_hp_level(club: String) -> int:
	if fitness_hp_override.has(club):
		return int(fitness_hp_override[club])
	if club == my_club:
		return department_budget_level("high_performance")
	return ClubBudget.STANDARD


## This season's record for a club, made the first time it is asked for. At
## week 0 an AI club picks its plan by phase; a club first seen mid-season
## (an old save) runs Steady.
func fitness_record(club: String) -> Dictionary:
	var rec: Dictionary = conditioning.get(club, {})
	if rec.is_empty() or int(rec.get("year", 0)) != season_year:
		var plan := Conditioning.DEFAULT_PLAN
		if club != my_club and season != null and fitness_week() == 0 and fitness_ai_by_phase:
			plan = Conditioning.ai_plan(_club_phase(club))
		rec = Conditioning.new_season(plan, season_year, club, fitness_hp_level(club), career_seed)
		conditioning[club] = rec
	return rec


## The plan a club is running. Read-only once the season is over: the
## off-season never makes next year's record from this year's state.
func fitness_plan(club: String) -> String:
	if season == null:
		return Conditioning.DEFAULT_PLAN
	if season.is_season_over():
		var rec: Dictionary = conditioning.get(club, {})
		if int(rec.get("year", 0)) != season_year:
			return Conditioning.DEFAULT_PLAN
		return Conditioning.plan_at(rec, fitness_week())
	return Conditioning.plan_at(fitness_record(club), fitness_week())


## The club's first bye (week), or -1.
func fitness_bye_week(club: String) -> int:
	if season == null:
		return -1
	# The fixture is drawn once with the season: each club's bye is found once.
	# (A loaded season's fixture is a new array, so it is found afresh.)
	if not is_same(_bye_fixture, season.fixture) or _bye_rounds != season.fixture.size():
		_bye_fixture = season.fixture
		_bye_rounds = season.fixture.size()
		_bye_weeks = {}
	if not _bye_weeks.has(club):
		_bye_weeks[club] = _find_bye_week(club)
	return int(_bye_weeks[club])


var _bye_fixture: Array = []
var _bye_rounds := -1
var _bye_weeks := {}


func _find_bye_week(club: String) -> int:
	for ri in range(season.fixture.size()):
		var plays := false
		for m in season.fixture[ri]:
			if str(m["home"]) == club or str(m["away"]) == club:
				plays = true
				break
		if not plays:
			return ri
	return -1


## Develop and manage's point of season room for a young player
## (Conditioning.ceiling_step): only when the plan has run since the
## pre-season or the bye.
func fitness_ceiling_step(p: Dictionary) -> int:
	var club := str(p.get("club", ""))
	if season == null or club == "":
		return 0
	var rec: Dictionary = conditioning.get(club, {})
	if not season.is_season_over():
		rec = fitness_record(club)
	elif int(rec.get("year", 0)) != season_year:
		return 0
	var w := fitness_week()
	# Only a young player on Develop and manage can get the point: ask for the
	# bye (a walk of the whole fixture) only then. Same answer, a lot less work
	# when every rival player's ceiling is asked for every week.
	if Conditioning.xp_mult(Conditioning.plan_at(rec, w), p) <= 1.0:
		return 0
	return Conditioning.ceiling_step(rec, w, fitness_bye_week(club), p)


## Where your club stands, in words, for the hub and Training: "Building,
## peak due in August". Empty once the season is over.
func fitness_status_line() -> String:
	if season == null or season.is_season_over():
		return ""
	return Conditioning.status_line(fitness_record(my_club), fitness_week())


func can_revise_fitness() -> bool:
	return season != null and not season.is_regular_done() \
			and Conditioning.revision_weeks(fitness_bye_week(my_club)).has(fitness_week())


## Your season plan, at a revision point. False when it is not one.
func set_fitness_plan(plan: String) -> bool:
	if not Conditioning.valid_plan(plan) or not can_revise_fitness():
		return false
	conditioning[my_club] = Conditioning.revise(fitness_record(my_club), fitness_week(), plan)
	mark_dirty()
	return true


## Before each week's matches: AI clubs look again at every revision point
## you get (Conditioning.revision_weeks: their bye, round 14, the last month),
## then every listed player carries his club's conditioning for the week.
func _stamp_conditioning() -> void:
	if season == null:
		return
	var w := fitness_week()
	for club in season.lists:
		var rec := fitness_record(str(club))
		if w > 0 and str(club) != my_club and fitness_ai_by_phase and not season.is_regular_done() \
				and Conditioning.revision_weeks(fitness_bye_week(str(club))).has(w) \
				and Conditioning.chosen_at(rec, w) < w:
			var plan := Conditioning.ai_plan(_club_phase(str(club)))
			if plan != Conditioning.plan_at(rec, w):
				rec = Conditioning.revise(rec, w, plan)
				conditioning[club] = rec
		season.fitness_plans[str(club)] = Conditioning.plan_at(rec, w)
		Conditioning.stamp_list(season.lists[club],
				Conditioning.actual(rec, w, fitness_hp_level(str(club))), Conditioning.plan_at(rec, w),
				Conditioning.base_curve(rec, w))


# ---------------------------------------------------------------------------
# The pre-season (PreSeason.gd): eight weeks between the wrap and Round 1
# ---------------------------------------------------------------------------
## Open this year's pre-season: every club gets its blocks (yours the default
## plan, an AI club's by its phase). Called at the rollover and when a new
## career's first season is made; start_season itself stays the plain "build
## the season" step tests and tools use. Once a year; never mid-season.
## `save`: false when the caller saves once itself at the end of a bigger
## step (the rollover), so one tap writes the career once, not twice.
func open_preseason(save := true) -> void:
	if season == null or season.round_index != 0 or season.is_regular_done():
		return
	if int(preseason.get("year", 0)) == season_year:
		return
	# A year on: every plan slips a step over the off-season. The first
	# year of a career (or of a save from before familiarity) has nothing to slip.
	var offseason := not plan_known.is_empty()
	var blocks := {}
	for club in season.clubs:
		var code := str(club)
		if code == my_club:
			var mine := PreSeason.default_blocks()
			# After a slip, the plan you play is drilled in the last block
			# unless you say otherwise.
			if offseason and PreSeason.DRILL_PLANS.has(club_plan):
				mine[mine.size() - 1] = [str(mine[mine.size() - 1][0]), "plan", [club_plan]]
			blocks[code] = mine
		else:
			blocks[code] = PreSeason.with_plan_block(
					PreSeason.ai_blocks(_club_phase(code), _best22_age(code)),
					_club_phase(code), _usual_plan(code))
	preseason = PreSeason.new_state(season_year, blocks)
	if preseason_run_debt != 0.0:
		# A season-end card's cost: the list starts this pre-season behind.
		var mine_e: Dictionary = (preseason.get("clubs", {}) as Dictionary).get(my_club, {})
		if not mine_e.is_empty():
			mine_e["run"] = float(mine_e.get("run", 0.0)) + preseason_run_debt
		preseason_run_debt = 0.0
	if offseason:
		_slip_plan_known()
	_ensure_plan_known()
	mark_dirty()
	if save:
		autosave()


## The mean age of the side a club would pick (what _club_phase reads).
func _best22_age(club: String) -> float:
	var side := Ratings.select_22(season.lists[club])
	var ages := 0.0
	var n := 0
	for q in (side["ground"] as Array) + (side["bench"] as Array):
		ages += float(q.get("age", 25.0))
		n += 1
	return ages / float(maxi(1, n))


## Training injuries so far this pre-season, every club: [{id, club, week,
## weeks, kind}], in the order they happened.
func preseason_injuries() -> Array:
	return preseason.get("injuries", [])


## Your players hurt in training in weeks `from`..`to`, in the game's usual
## injury words: "Name (hamstring, 2 weeks)". The weeks are as they were
## when it happened.
func preseason_injury_lines(from := 1, to := 99) -> Array:
	var out := []
	for inj in preseason_injuries():
		if str(inj.get("club", "")) != my_club or int(inj.get("week", 0)) < from or int(inj.get("week", 0)) > to:
			continue
		var p := list_player(str(inj["id"]))
		if p.is_empty():
			continue
		out.append("%s (%s, %s)" % [GameDB.player_display_name(p), Injuries.wording(str(inj["kind"])),
				_weeks_text(int(inj["weeks"]))])
	return out


## A pre-season is running: opened this year, not finished, Round 1 unplayed.
func preseason_active() -> bool:
	return season != null and not preseason.is_empty() \
			and int(preseason.get("year", 0)) == season_year \
			and not bool(preseason.get("done", true)) \
			and season.round_index == 0 and not season.is_regular_done()


## Weeks of it done (0..8).
func preseason_week() -> int:
	return int(preseason.get("week", 0))


## Where it is waiting for you: "plan" before week 1, "trial" after the time
## trial, "" when it is not waiting (none running, or between weeks).
func preseason_stop() -> String:
	if not preseason_active():
		return ""
	var w := preseason_week()
	if w == 0:
		return "plan"
	if str(PreSeason.STOPS.get(w, "")) == "trial" and not bool(preseason.get("trial_seen", false)):
		return "trial"
	# The pre-season match (director, 2026-11-03: the intra-club match and the
	# practice match are one): the opponent and the trial, then the report.
	if str(PreSeason.STOPS.get(w, "")) == "practice" and preseason.get("practice") is Dictionary \
			and not bool((preseason["practice"] as Dictionary).get("seen", false)):
		return "practice"
	# The papers, in the quiet last week: the ladder and the story to answer.
	if str(PreSeason.STOPS.get(w, "")) == "papers" and not papers_record().is_empty() \
			and not bool(papers_record().get("seen", false)):
		return "papers"
	# The story cards the block threw up (data/stories, phase "preseason").
	if bool(preseason.get("story_pending", false)):
		return "story"
	return ""


## A club's three blocks: [[load, focus], ...].
func preseason_blocks(club := "") -> Array:
	var code := my_club if club == "" else club
	return ((preseason.get("clubs", {}) as Dictionary).get(code, {}) as Dictionary).get("blocks", [])


## A block can be changed until its first week is trained.
func preseason_block_open(i: int) -> bool:
	return preseason_active() and i >= 0 and i < PreSeason.block_count() \
			and preseason_week() < int(PreSeason.block_weeks(i)[0])


## Set your load and focus for block `i`. False once it has started.
func set_preseason_block(i: int, load: String, focus: String) -> bool:
	if not preseason_block_open(i) or not PreSeason.valid_block(load, focus):
		return false
	var blocks := preseason_blocks()
	if i >= blocks.size():
		return false
	if focus == "plan":
		# The plans it drills stay as they were, or start on the default.
		var was: Array = PreSeason.clean_drills(blocks[i][2] if (blocks[i] as Array).size() > 2 else [])
		if was.is_empty():
			_ensure_plan_known()
			was = PreSeason.default_drill(_usual_plan(my_club), plan_known.get(my_club, {}))
		# A position group's own drills stay with the block while it is on Game plan.
		var split := PreSeason.block_split(blocks[i])
		blocks[i] = [load, focus, was, split] if not split.is_empty() else [load, focus, was]
	else:
		blocks[i] = [load, focus]
	mark_dirty()
	return true


## Choose which plan (or two) a Game plan block drills: the plans given, up to
## the most it allows. With `group` ("MID", "DEF", "FWD", "RUCK"; director,
## 2026-11-06, row 101: "split it between position groups") for that group
## alone; without, for the whole side, every group alike. False for a block
## that is not on Game plan, or that has started, or when none of the plans
## can be drilled.
func set_preseason_drills(i: int, plans: Array, group := "") -> bool:
	var blocks := preseason_blocks()
	if not preseason_block_open(i) or i >= blocks.size() or str(blocks[i][1]) != "plan":
		return false
	if group != "" and not PreSeason.GROUPS.has(group):
		return false
	var drills := PreSeason.clean_drills(plans)
	if drills.is_empty():
		return false
	var b: Array = blocks[i]
	var side: Array = PreSeason.clean_drills(b[2] if b.size() > 2 else [])
	var split := PreSeason.block_split(b)
	if group == "":
		side = drills
		split = {}
	elif drills == side:
		split.erase(group)
	else:
		split[group] = drills
	blocks[i] = [str(b[0]), "plan", side, split] if not split.is_empty() else [str(b[0]), "plan", side]
	mark_dirty()
	return true


## The plans block `i` drills ([] unless it is a Game plan block): the whole
## side's, or with `group` what that position group drills.
func preseason_drills(i: int, group := "") -> Array:
	var blocks := preseason_blocks()
	if i < 0 or i >= blocks.size() or str(blocks[i][1]) != "plan" or (blocks[i] as Array).size() < 3:
		return []
	return PreSeason.group_drills(blocks[i], group) if group != "" else PreSeason.clean_drills(blocks[i][2])


## True when Game plan block `i` drills differently for the position groups.
func preseason_drills_split(i: int) -> bool:
	var blocks := preseason_blocks()
	return i >= 0 and i < blocks.size() and not PreSeason.block_split(blocks[i]).is_empty()


## The fitness base your plan is heading for, were every block trained as it
## is set now: "thin" / "sound" / "strong".
func preseason_base() -> String:
	return PreSeason.base_band(preseason_run_forecast())


## The weeks of running your side will have by Round 1: what is already done
## (cards included, such as a camp) and the weeks still to come as set now.
## Before week 1 that is exactly the plan's total.
func preseason_run_forecast() -> float:
	var blocks := preseason_blocks()
	var entry: Dictionary = (preseason.get("clubs", {}) as Dictionary).get(my_club, {})
	var run := float(entry.get("run", 0.0))
	for w in range(preseason_week() + 1, PreSeason.weeks() + 1):
		var i := PreSeason.block_of_week(w)
		if i >= 0 and i < blocks.size():
			run += PreSeason.work(str(blocks[i][0]), str(blocks[i][1]), "running")
	return run


## The time trial, by player id: {"best": [...], "worst": [...]}, or {}.
func preseason_trial() -> Dictionary:
	return preseason.get("trial", {})


## Train one week, every club by the same rules. Returns where it stopped:
## "trial" (the time trial has been run), "done" (Round 1 is next) or "".
func preseason_step_week() -> String:
	var at: Variant = _preseason_week_begin()
	if at is Dictionary:
		return _preseason_week_end(at, Season.run_all(at["sims"]))
	return str(at)


## preseason_step_week, with the other clubs' practice matches on threads
## while frames draw, so the loading cover's set shot plays on in a browser.
## Same matches, same order, so the same week.
func preseason_step_week_async() -> String:
	var at: Variant = _preseason_week_begin()
	if at is Dictionary:
		var job := Season.start_all(at["sims"], Season.web_cores())
		while Season.running(job):
			await get_tree().process_frame
		return _preseason_week_end(at, Season.finish_all(job))
	return str(at)


## A pre-season week up to its practice matches: where it stops, or (the
## practice week) the matches to play, for _preseason_week_end.
func _preseason_week_begin() -> Variant:
	if not preseason_active():
		return "done"
	RookieList.settle(self)
	if ["trial", "practice", "papers", "story"].has(preseason_stop()):
		return preseason_stop()
	if preseason_week() >= PreSeason.weeks():
		_finish_preseason()
		return "done"
	var w := preseason_week() + 1
	var clubs: Dictionary = preseason.get("clubs", {})
	for club in season.clubs:
		if clubs.has(str(club)) and season.lists.has(club):
			# A week passes for anyone already hurt, then the week is trained.
			Injuries.tick(season.lists[club])
			_light_heal(clubs[str(club)], season.lists[club], w)
			_preseason_train(str(club), clubs[str(club)], w)
	preseason["week"] = w
	mark_dirty()
	if str(PreSeason.STOPS.get(w, "")) == "trial":
		preseason["trial"] = PreSeason.trial(my_list, career_seed, season_year, my_club)
		preseason["trial_seen"] = false
		return "trial"
	if str(PreSeason.STOPS.get(w, "")) == "practice":
		return _ai_practices(clubs)
	if str(PreSeason.STOPS.get(w, "")) == "papers":
		_build_papers()
		return "papers"
	if w >= PreSeason.weeks():
		_finish_preseason()
		return "done"
	return ""


## A Light week is easy on the body: the injured heal light_heal_extra weeks
## more (a concussion runs on matches, under the protocols, so not that).
func _light_heal(entry: Dictionary, list: Array, w: int) -> void:
	var i := PreSeason.block_of_week(w)
	var blocks: Array = entry.get("blocks", [])
	if i < 0 or i >= blocks.size() or str(blocks[i][0]) != "light":
		return
	for p in list:
		var left := int(p.get("injury_weeks", 0))
		if left <= 0 or str(p.get("injury_kind", "")) == "concussion":
			continue
		p["injury_weeks"] = maxi(0, left - int(PreSeason.tune("light_heal_extra")))
		if int(p["injury_weeks"]) == 0:
			p.erase("injury_kind")


## One club's training week: running work toward its base, skills work as
## development XP for every fit player, spent as a match's XP is.
func _preseason_train(club: String, entry: Dictionary, w: int) -> void:
	var i := PreSeason.block_of_week(w)
	var blocks: Array = entry.get("blocks", [])
	if i < 0 or i >= blocks.size():
		return   # the quiet week: the side freshens up
	var load := str(blocks[i][0])
	var focus := str(blocks[i][1])
	entry["run"] = float(entry.get("run", 0.0)) + PreSeason.work(load, focus, "running")
	var xp := PreSeason.week_xp(load, focus)
	var list: Array = season.lists[club]
	if xp > 0:
		var staff: Dictionary = CoachEffects.staffs(coaches).get(club, {}) if not coaches.is_empty() else {}
		for p in list:
			if int(p.get("injury_weeks", 0)) > 0:
				continue
			p["xp"] = int(p.get("xp", 0)) + _club_xp(club, p, xp, staff, false)
			if club != my_club:
				ai_spend_xp(p)
		if club == my_club:
			apply_train_plans()
	_preseason_injuries(club, list, load, w)


## A Heavy week's risk, every club alike: each fit player's own roll for a
## soft-tissue injury (PreSeason.training_injury), recorded on him the way a
## match injury is, in the pre-season's record, as a career fact, and (yours)
## in the news.
func _preseason_injuries(club: String, list: Array, load: String, w: int) -> void:
	if load != "heavy":
		return
	var rows := []
	for p in list:
		var inj := PreSeason.training_injury(p, load, career_seed, season_year, club, w)
		if inj.is_empty():
			continue
		p["injury_weeks"] = int(inj["weeks"])
		p["injury_kind"] = str(inj["kind"])
		rows.append({"id": str(p["id"]), "club": club, "week": w, "weeks": int(inj["weeks"]), "kind": str(inj["kind"])})
		if club == my_club:
			add_news("injury", "%s (%s, %s) was hurt in pre-season training." % [
					GameDB.player_display_name(p), str(inj["kind"]), _weeks_text(int(inj["weeks"]))], "Pre-season")
	if rows.is_empty():
		return
	if not (preseason.get("injuries") is Array):
		preseason["injuries"] = []
	(preseason["injuries"] as Array).append_array(rows)
	_log_injuries(rows, "Pre-season")


## Week 8 is done: each club's running work becomes the base on its season
## fitness record (the one value handed over), and a heavy or light last block
## is the existing heavy-legs or fresh week for Round 1.
func _finish_preseason() -> void:
	var clubs: Dictionary = preseason.get("clubs", {})
	for club in season.clubs:
		var code := str(club)
		if season.lists.has(club):
			TeamFamiliarity.round_one(season.lists[club])
		if not clubs.has(code) or not season.lists.has(club):
			continue
		var entry: Dictionary = clubs[code]
		var rec := fitness_record(code)
		var band := PreSeason.base_band(float(entry.get("run", 0.0)))
		if band == PreSeason.DEFAULT_BASE:
			rec.erase("base")
		else:
			rec["base"] = band
		conditioning[code] = rec
		var flag := PreSeason.round_one_flag(entry.get("blocks", []))
		for p in season.lists[club]:
			p.erase("heavy_legs")
			p.erase("fresh")
			if flag != "":
				p[flag] = true
	preseason["done"] = true
	preseason["legs"] = true
	var drilled := _finish_drills()
	if my_club != "" and clubs.has(my_club):
		add_news("preseason", "Pre-season is done. %s go into Round 1 on %s.%s" % [
				GameDB.club_name(my_club),
				str(PreSeason.BASE_LABEL[Conditioning.base_of(fitness_record(my_club))]), drilled], "Pre-season")
	mark_dirty()


# ---------------------------------------------------------------------------
# The papers (PreSeason.gd, week 8): a predicted ladder and one story to answer
# ---------------------------------------------------------------------------
## Yours, this pre-season: {"order": [club codes, best first], "pred", "kind"
## (finish, breakout, pressure, or "" when there is nothing to answer), "pid",
## "claim" (the finish you named, 0 for none), "answered", "choice", "result",
## "seen"}. {} before week 8.
func papers_record() -> Dictionary:
	return preseason.get("papers", {}) if preseason.get("papers") is Dictionary else {}


## The paper's ladder, best first: each club's best side as TeamRating reads it
## after the summer's injuries, near-ties to last year's finish, then nudged by
## the practice matches ("moves": club -> {places, margin, earned, by} for each
## club its result earned a move; "by" names what stopped one that fell short).
func _build_papers() -> void:
	var ratings := {}
	var last := {}
	for club in season.clubs:
		var code := str(club)
		ratings[code] = TeamRating.rating(season.lists[club])
		last[code] = last_finish_of(code)
	var listed := PreSeason.predicted_order(ratings, last, club_expect)
	# The practice matches nudge it (director, 2026-11-12): every club the same.
	var margins: Dictionary = preseason.get("practice_margins", {}) if preseason.get("practice_margins") is Dictionary else {}
	var order := PreSeason.practice_nudge(listed, margins)
	var moves := PreSeason.practice_moves(listed, order, margins)
	var pred := order.find(my_club) + 1
	var eligible := []
	if pred > season.finalists():
		eligible.append("finish")
	if PreSeason.finishes_short(board.get("goal", {}) as Dictionary, pred):
		eligible.append("pressure")
	var pid := _papers_breakout()
	if pid != "":
		eligible.append("breakout")
	var kind := ""
	if not eligible.is_empty():
		kind = PreSeason.pick_paper(eligible, PreSeason.papers_seed(career_seed, season_year, my_club))
	preseason["papers"] = {"order": order, "moves": moves, "pred": pred, "kind": kind,
			"pid": pid if kind == "breakout" else "", "claim": 0, "answered": false,
			"choice": -2, "result": "", "seen": false}
	mark_dirty()


## The young player the papers would tip: fit, young, able to be backed, the
## most potential (then the id). "" when none.
func _papers_breakout() -> String:
	var best := {}
	for p in my_list:
		if float(p.get("age", 30.0)) > float(PreSeason.tune("papers_breakout_age")):
			continue
		if int(p.get("injury_weeks", 0)) > 0 or not Backing.can_back(p, games_played(p)):
			continue
		var pot := int(p.get("potential", p.get("overall", 0)))
		var best_pot := int(best.get("potential", best.get("overall", 0)))
		if best.is_empty() or pot > best_pot or (pot == best_pot and str(p["id"]) < str(best["id"])):
			best = p
	return str(best.get("id", ""))


## The paper's line on a club's practice move ("Up two after a 56-point
## practice thumping"), or "" when its result did not move it.
func papers_move_line(code: String) -> String:
	var mv: Dictionary = (papers_record().get("moves", {}) as Dictionary).get(code, {})
	if mv.is_empty():
		return ""
	var margins: Dictionary = preseason.get("practice_margins", {}) if preseason.get("practice_margins") is Dictionary else {}
	var by := str(mv.get("by", ""))
	var by_name := by if by == "" or by == "top" or by == "bottom" else GameDB.club_name(by)
	return PreSeason.practice_move_line(int(mv.get("places", 0)), int(mv.get("margin", 0)),
			int(mv.get("earned", mv.get("places", 0))), by_name, int(margins.get(by, 0)))


## The papers' power rankings: club -> a line or two on it in a footy writer's
## voice (PowerRankings), from its facts now. Every club the same, yours too;
## words only. {} before the papers print.
func papers_blurbs() -> Dictionary:
	var order: Array = papers_record().get("order", [])
	if order.is_empty():
		return {}
	return PowerRankings.blurbs(order, papers_facts())


## Each club's facts for its power-ranking blurb (PowerRankings documents the
## keys): its lines ranked against the league's, its best players, its best new
## face, its best player out injured, its kid to watch, its practice result.
func papers_facts() -> Dictionary:
	var order: Array = papers_record().get("order", [])
	var margins: Dictionary = preseason.get("practice_margins", {}) if preseason.get("practice_margins") is Dictionary else {}
	var depth := {"DEF": 6, "MID": 6, "FWD": 6, "RUCK": 2}
	var words := {"DEF": "defence", "MID": "midfield", "FWD": "forward line", "RUCK": "ruck division"}
	# Each line's strength: the mean of its best few fit players.
	var lines := {}
	for code in order:
		var by_role := {}
		for p in season.lists[code]:
			if int(p.get("injury_weeks", 0)) > 0:
				continue
			var r := str(p.get("role", ""))
			if not depth.has(r):
				continue
			if not by_role.has(r):
				by_role[r] = []
			(by_role[r] as Array).append(p)
		var mine := {}
		for r in depth:
			var ps: Array = by_role.get(r, [])
			ps.sort_custom(func(a, b): return int(a.get("overall", 0)) > int(b.get("overall", 0)))
			var top := ps.slice(0, int(depth[r]))
			var sum := 0
			for p in top:
				sum += int(p.get("overall", 0))
			mine[r] = {"value": float(sum) / float(maxi(1, int(depth[r]))),
					"lead": GameDB.player_display_name(top[0]) if not top.is_empty() else ""}
		lines[str(code)] = mine
	var ranks := {}
	for r in depth:
		var codes := order.duplicate()
		codes.sort_custom(func(a, b): return float(lines[str(a)][r]["value"]) > float(lines[str(b)][r]["value"]))
		for i in range(codes.size()):
			if not ranks.has(str(codes[i])):
				ranks[str(codes[i])] = {}
			ranks[str(codes[i])][r] = i + 1
	var out := {}
	for i in range(order.size()):
		var code := str(order[i])
		var list: Array = (season.lists[code] as Array).duplicate()
		list.sort_custom(func(a, b): return int(a.get("overall", 0)) > int(b.get("overall", 0)))
		var fit := list.filter(func(p): return int(p.get("injury_weeks", 0)) <= 0)
		var f := {"name": GameDB.club_name(code), "pos": i + 1, "clubs": order.size(),
				"last": last_finish_of(code), "move": papers_move_line(code)}
		if fit.size() > 0:
			f["star"] = GameDB.player_display_name(fit[0])
		if fit.size() > 1:
			f["second"] = GameDB.player_display_name(fit[1])
		var best_r := ""
		var worst_r := ""
		for r in ["MID", "FWD", "DEF", "RUCK"]:
			if best_r == "" or int(ranks[code][r]) < int(ranks[code][best_r]):
				best_r = r
			if worst_r == "" or int(ranks[code][r]) > int(ranks[code][worst_r]):
				worst_r = r
		f["line"] = {"word": words[best_r], "rank": int(ranks[code][best_r]), "lead": lines[code][best_r]["lead"]}
		f["weak"] = {"word": words[worst_r], "rank": int(ranks[code][worst_r])}
		# The best new face from another club who would make the side.
		for k in range(mini(22, list.size())):
			var p: Dictionary = list[k]
			var stints: Array = Career.of(p).get("stints", [])
			if int(p.get("joined", -1)) >= season_year - 1 and not stints.is_empty() \
					and str((stints[-1] as Array)[0]) != code:
				f["recruit"] = {"name": GameDB.player_display_name(p), "from": GameDB.club_name(str((stints[-1] as Array)[0]))}
				break
		for p in list:
			if int(p.get("injury_weeks", 0)) > 0:
				f["hurt"] = {"name": GameDB.player_display_name(p), "kind": Injuries.wording(str(p.get("injury_kind", "")))}
				break
		var young := {}
		for p in fit:
			if float(p.get("age", 30.0)) > 21.0 or (fit.size() > 0 and p == fit[0]):
				continue
			if young.is_empty() or int(p.get("potential", 0)) > int(young.get("potential", 0)):
				young = p
		if not young.is_empty():
			f["young"] = {"name": GameDB.player_display_name(young), "age": int(float(young.get("age", 20.0)))}
		if margins.has(code):
			f["has_margin"] = true
			f["margin"] = int(margins[code])
		out[code] = f
	return out


## The story to answer, as a card (the same card the weekly stories use), or
## {} when the papers have nothing to ask this year.
func papers_card() -> Dictionary:
	var rec := papers_record()
	var kind := str(rec.get("kind", ""))
	if kind == "":
		return {}
	var who: Dictionary = list_player(str(rec.get("pid", ""))) if str(rec.get("pid", "")) != "" else {}
	if kind == "breakout" and who.is_empty():
		return {}
	return story_card(str(PreSeason.PAPER_CARD[kind]), who)


## Answer the papers with choice `choice` of the card. Returns what happened.
func papers_answer(choice: int) -> String:
	var rec := papers_record()
	if preseason_stop() != "papers" or bool(rec.get("answered", false)):
		return ""
	var card := papers_card()
	if card.is_empty() or (card.get("options", []) as Array).is_empty():
		return ""
	choice = clampi(choice, 0, (card["options"] as Array).size() - 1)
	var out := ClubStories.apply_choice(self, card, choice)
	StoryEngine.record_choice(story, card, choice, story_week())
	rec["answered"] = true
	rec["choice"] = choice
	rec["result"] = out
	mark_dirty()
	return out


## Say nothing: the card's own cost for silence, as any unanswered card.
func papers_say_nothing() -> void:
	var rec := papers_record()
	if bool(rec.get("answered", false)):
		return
	rec["answered"] = true
	var card := papers_card()
	if card.is_empty():
		return
	var cost: Dictionary = card.get("unanswered", {})
	if int(cost.get("board", 0)) != 0 and not board.is_empty():
		board["confidence"] = clampi(board_confidence() + int(cost["board"]), 0, 100)
	if int(cost.get("trust", 0)) != 0 and str(card.get("player_id", "")) != "":
		Trust.change(relations, Trust.player_key(str(card["player_id"])), int(cost["trust"]),
				str(cost.get("why", "You said nothing")), int(season_year), "Pre-season")
	rec["choice"] = -1
	rec["result"] = str(cost.get("text", "Business as usual."))
	StoryEngine.record_choice(story, card, -1, story_week())
	mark_dirty()


## Talking the club up puts a finish on the record. The board's goal does not move.
func papers_on_record(rank: int) -> void:
	if papers_record().is_empty():
		return
	(preseason["papers"] as Dictionary)["claim"] = maxi(0, rank)
	mark_dirty()


# ---------------------------------------------------------------------------
# Plan familiarity (PreSeason.gd): how well each club knows each game plan.
# The rules are PreSeason's; this keeps the record.
# ---------------------------------------------------------------------------
## The plan a club plays as its own: yours is the one you have set; an AI
## club's is the one its list suits (PlanFit.standing_plan). "balanced" when none.
func _usual_plan(club: String) -> String:
	if club == my_club:
		return club_plan
	if season == null or not season.lists.has(club):
		return "balanced"
	return PlanFit.standing_plan((Ratings.select_22(season.lists[club])["ground"] as Array))


## Give every club a record it lacks (the defaults), and hand the live record
## to the match engine's coaching table. Without a season: nothing kept.
func _ensure_plan_known() -> void:
	if season == null:
		CoachEffects.known = {}
		return
	for club in season.clubs:
		var code := str(club)
		if not plan_known.has(code):
			plan_known[code] = PreSeason.start_levels(_usual_plan(code))
			plan_idle[code] = {}
	CoachEffects.known = plan_known


## Saved fluencies read back in range, for real plans (a save from before
## part-steps holds whole levels, which are fluencies already).
func _clean_plan_known() -> void:
	var clean := {}
	for club in plan_known:
		if not (plan_known[club] is Dictionary):
			continue
		var row := {}
		for plan in ["balanced"] + PreSeason.DRILL_PLANS:
			row[plan] = PreSeason.clamp_fluency(float((plan_known[club] as Dictionary).get(plan, PreSeason.start_level(str(plan), ""))))
		row["balanced"] = PreSeason.WELL
		clean[str(club)] = row
	plan_known = clean
	var idle := {}
	for club in plan_known:
		var row := {}
		var src: Variant = plan_idle.get(club, {})
		if src is Dictionary:
			for plan in PreSeason.DRILL_PLANS:
				row[plan] = maxi(0, int((src as Dictionary).get(plan, 0)))
		idle[club] = row
	plan_idle = idle


## How well `club` knows `plan` (0 barely, 1 partly, 2 well). Without a
## season: well.
func plan_level(club: String, plan: String) -> int:
	return int(plan_fluency(club, plan))


## The same with the part of a step: 1.5 is medium, half way to high.
func plan_fluency(club: String, plan: String) -> float:
	if season == null:
		return float(PreSeason.WELL)
	_ensure_plan_known()
	return float((plan_known.get(club, {}) as Dictionary).get(plan, PreSeason.WELL))


## Your side's plan under its words: "Plan fluency: medium", or
## "Plan fluency: 50% to high" part way. "" without a
## season or a club.
func plan_known_line(plan: String) -> String:
	if season == null or my_club == "":
		return ""
	return PreSeason.known_line(plan_fluency(my_club, plan))


## Where the pre-season, as your blocks are set now, leaves a plan (a card's
## extra drilling, such as staying home from camp, included).
func plan_level_after_drills(plan: String) -> int:
	return int(plan_fluency_after_drills(plan))


## The same with the part of a step.
func plan_fluency_after_drills(plan: String) -> float:
	return PreSeason.drilled_fluency(plan_fluency(my_club, plan), float(my_drill_credit().get(plan, 0.0)))


## Your weeks of drilling by plan: the blocks as set now and any card's.
func my_drill_credit() -> Dictionary:
	var credit: Dictionary = PreSeason.drill_credit(preseason_blocks(), PreSeason.group_shares(my_list))
	var extra: Dictionary = preseason.get("bonus_drill", {})
	for plan in extra:
		credit[plan] = float(credit.get(plan, 0.0)) + float(extra[plan])
	return credit


## Whether the plans carry a "Plan fluency" line at all (a season and a club).
func plan_known_shown() -> bool:
	return season != null and my_club != ""


func _slip_plan_known() -> void:
	for club in plan_known:
		plan_known[club] = PreSeason.slip_levels(plan_known[club])
		plan_idle[club] = {}


## Week 8: each club's drilled plans move up, weeks short of a step counting as
## part of one (a plan nobody drilled is as it was). Returns the sentence for your
## news: "" when nothing moved.
func _finish_drills() -> String:
	_ensure_plan_known()
	var line := ""
	var clubs: Dictionary = preseason.get("clubs", {})
	for club in clubs:
		var code := str(club)
		if not plan_known.has(code):
			continue
		# A split block's drilling counts each position group by its share of the list.
		var list: Array = season.lists.get(club, []) if season != null else []
		var credit: Dictionary = PreSeason.drill_credit((clubs[club] as Dictionary).get("blocks", []),
				PreSeason.group_shares(list))
		if code == my_club:
			var extra: Dictionary = preseason.get("bonus_drill", {})
			for plan in extra:
				credit[plan] = float(credit.get(plan, 0.0)) + float(extra[plan])
		for plan in credit:
			var was := float((plan_known[code] as Dictionary).get(plan, 0))
			var now := PreSeason.drilled_fluency(was, float(credit[plan]))
			(plan_known[code] as Dictionary)[plan] = now
			(plan_idle[code] as Dictionary)[plan] = 0
			if code == my_club and now != was:
				line += " The side's fluency in %s is now %s." % [CoachReport.plan_label(str(plan)), PreSeason.fluency_long(now)]
	return line


## A round has been played: a plan played keeps its place; one left alone
## through fade_rounds rounds slips a step (slowly). Finals do not count.
## Your coaching this round counts toward his archetypes' drift (row 119):
## each quarter on a plan, and each Throw numbers at it or Stack the
## contest called.
func _note_coach_arch(results: Array) -> void:
	for res in results:
		if not (res is Dictionary) or (res as Dictionary).has("tag"):
			continue
		var side := 0 if str(res.get("home", "")) == my_club else (1 if str(res.get("away", "")) == my_club else -1)
		if side < 0:
			continue
		for h in (res as Dictionary).get("tactics_history", []):
			var plans: Array = (h as Dictionary).get("plans", []) if h is Dictionary else []
			if plans.size() > side:
				Archetypes.tally_plan(coach_arch, MatchSim.plan_key(str((plans[side] as Dictionary).get("gameplan", "balanced"))))
		for m in (res as Dictionary).get("moments", []):
			if m is Dictionary and int(m.get("side", -1)) == side:
				Archetypes.tally_call(coach_arch, str(m.get("call", "")))
	CoachEffects.my_arch = coach_arch


## The season is over: his archetypes drift with how he coached it, and any
## change is announced (row 119).
func _coach_arch_season_end() -> void:
	if coach_arch.is_empty():
		return
	var out := Archetypes.season_end(coach_arch)
	coach_arch = out["arch"]
	CoachEffects.my_arch = coach_arch
	for c in out["changed"]:
		add_news("coach", Archetypes.change_line(str(c[0]), str(c[1]), str(c[2])))


## Sit the appointment interview: `picks` one answer per question.
## The club the new coach was appointed to: my_club, or in a League redraft
## (which sets my_club only once the draft ends) the club he is drafting for.
func coach_club() -> String:
	if my_club != "":
		return my_club
	return draft.user_club if draft != null else ""


## The press interview comes once the coach has a club and before his first
## pick (director, 2026-11-11: "its meant to go before the draft"). A draft
## already run to its end counts too: a club with a full list passes every
## pick the moment it is taken (the 2030 start), and its coach still sits the
## interview before he sees the board.
func interview_before_draft() -> bool:
	return interview_due and coach_club() != "" and draft != null


func finish_interview(picks: Array) -> Dictionary:
	coach_arch = Archetypes.score_interview(picks)
	interview_due = false
	CoachEffects.my_arch = coach_arch
	mark_dirty()
	autosave()
	return coach_arch


func _note_plans_played(results: Array) -> void:
	if plan_known.is_empty():
		return
	var fade := maxi(1, int(PreSeason.tune("fade_rounds")))
	for res in results:
		if (res as Dictionary).has("tag"):
			continue
		var played := [{}, {}]
		for h in (res as Dictionary).get("tactics_history", []):
			for side in range(2):
				played[side][MatchSim.plan_key(str(((h["plans"] as Array)[side] as Dictionary).get("gameplan", "balanced")))] = true
		for side in range(2):
			var code := str([res["home"], res["away"]][side])
			if not plan_known.has(code):
				continue
			var idle: Dictionary = plan_idle[code]
			for plan in PreSeason.DRILL_PLANS:
				if (played[side] as Dictionary).has(plan):
					idle[plan] = 0
					continue
				idle[plan] = int(idle.get(plan, 0)) + 1
				if int(idle[plan]) >= fade:
					idle[plan] = 0
					var row: Dictionary = plan_known[code]
					row[plan] = PreSeason.clamp_fluency(float(row.get(plan, 0)) - 1.0)
	mark_dirty()


## A round has been played: each rival coach's plans and why, quarter by
## quarter, join his club's record for the season (rival_plans), finals too,
## before the results are slimmed for the save (which drops the plans).
func _note_rival_plans(results: Array) -> void:
	if not rival_plans.is_empty() and int(rival_plans.get("year", 0)) != season_year:
		rival_plans = {}
	for res in results:
		if not (res is Dictionary):
			continue
		for side in range(2):
			var row := RivalRead.record_row(res, side)
			if row.is_empty():
				continue
			if rival_plans.is_empty():
				rival_plans = {"year": season_year, "clubs": {}}
			var clubs: Dictionary = rival_plans["clubs"]
			var code := str([res.get("home", ""), res.get("away", "")][side])
			if not clubs.has(code):
				clubs[code] = []
			# Whose calls these were: a new coach's read starts from his first
			# game (rival_rows).
			row["c"] = str(Coaches.staff(coaches, code).get("SC", ""))
			(clubs[code] as Array).append(row)


## `code`'s rival coach's record this season (RivalRead.record_row rows, in
## the order played); [] for another season's record or none.
func rival_rows(code: String) -> Array:
	if int(rival_plans.get("year", 0)) != season_year or not (rival_plans.get("clubs") is Dictionary):
		return []
	var rows = (rival_plans["clubs"] as Dictionary).get(code, [])
	if not rows is Array:
		return []
	# Only the games of the coach there now (director, 2026-11-09). A row
	# from an older save names no coach and stays.
	var now := str(Coaches.staff(coaches, code).get("SC", ""))
	return (rows as Array).filter(func(r): return str((r as Dictionary).get("c", now)) == now)


## Each rival coach's usual game this season (rival_plans "usual"): club ->
## plan; {} for another season's record or none.
func _season_usuals() -> Dictionary:
	if int(rival_plans.get("year", 0)) != season_year or not (rival_plans.get("usual") is Dictionary):
		return {}
	return rival_plans["usual"]


## Each rival coach's own plan this season, for one who built one
## (rival_plans "custom"): club -> CustomPlan; {} as _season_usuals.
func _season_customs() -> Dictionary:
	if int(rival_plans.get("year", 0)) != season_year or not (rival_plans.get("custom") is Dictionary):
		return {}
	return rival_plans["custom"]


## Before a round is played: a rival coach with no usual game yet this season
## settles on one, the plan the side he would field this week suits best,
## weighed by how well his club knows it (PlanFit.standing_plan, as the match
## engine used to work out every week), and keeps it all year. A coach
## re-picking it each week off a changed side or a plan his side had let slip
## spent most of a season on plans that were not his usual game, and his
## report contradicted itself (director's note, 2026-11-08). The match engine reads it as each AI
## club's usual game (CoachEffects.usual, Squad.usual_plan).
func _settle_usual_plans() -> void:
	if season == null:
		return
	if not rival_plans.is_empty() and int(rival_plans.get("year", 0)) != season_year:
		rival_plans = {}
	var usual := _season_usuals()
	for club in season.clubs:
		var code := str(club)
		if code == my_club or usual.has(code) or not season.lists.has(code):
			continue
		var sq := _rival_squad(code)
		if not sq.ai_plans:
			continue
		if rival_plans.is_empty():
			rival_plans = {"year": season_year, "clubs": {}}
		if not (rival_plans.get("usual") is Dictionary):
			rival_plans["usual"] = {}
		usual = rival_plans["usual"]
		# Every club gets it (director, 2026-11-09): some coaches build a plan
		# of their own for the season, on seeded dice (CustomPlan.ai_builds).
		if CustomPlan.ai_builds(code, season_year):
			if not (rival_plans.get("custom") is Dictionary):
				rival_plans["custom"] = {}
			(rival_plans["custom"] as Dictionary)[code] = CustomPlan.ai_pick(code, season_year)
			usual[code] = CustomPlan.KEY
		else:
			usual[code] = PlanFit.standing_plan(sq.ground, sq.plan_know)
	CoachEffects.usual = usual
	CoachEffects.customs = _season_customs()


## Press on from where the pre-season is waiting, to the next stop or to
## Round 1. Returns "trial" or "done".
func preseason_advance() -> String:
	if not preseason_active():
		return "done"
	if preseason_stop() == "trial":
		preseason["trial_seen"] = true
	elif preseason_stop() == "story":
		_end_preseason_cards()
	elif preseason_stop() == "practice":
		if not practice_played():
			sim_practice_match()
			mark_dirty()
			autosave()
			return "practice"
		(preseason["practice"] as Dictionary)["seen"] = true
	elif preseason_stop() == "papers":
		# Pressed on without answering: saying nothing is an answer, and costs
		# what it costs on any card.
		papers_say_nothing()
		(preseason["papers"] as Dictionary)["seen"] = true
	var at := ""
	while at == "":
		at = preseason_step_week()
		# The end of a block may bring a card: it stops the pre-season after
		# the time trial or the pre-season match, if that is the week.
		if preseason_active() and PreSeason.STORY_WEEKS.has(preseason_week()) and int(preseason.get("cards_week", 0)) != preseason_week():
			preseason["cards_week"] = preseason_week()
			if _preseason_cards() and at == "":
				at = "story"
	mark_dirty()
	autosave()
	return at


## "Sim to Round 1": the rest of the pre-season on the settings in force,
## stopping for nothing. Also what a round played with a pre-season still
## pending does first, so a hands-off run never skips one.
func preseason_sim_to_round1() -> void:
	if not preseason_active():
		return
	preseason["hands_off"] = true
	while preseason_active():
		_hands_off_cards()
		_hands_off_stops(sim_practice_match())
		preseason_step_week()
	mark_dirty()
	autosave()


## preseason_sim_to_round1 with its matches on threads and a frame drawn each
## week, so the loading cover's set shot plays on (in a browser too). Same
## steps, same matches, same order, so the same pre-season.
func preseason_sim_to_round1_async() -> void:
	if not preseason_active():
		return
	preseason["hands_off"] = true
	while preseason_active():
		_hands_off_cards()
		_hands_off_stops(await sim_practice_match_async())
		await preseason_step_week_async()
		await get_tree().process_frame
	mark_dirty()
	autosave()


## A hands-off pre-season presses on past the trial and any card...
func _hands_off_cards() -> void:
	preseason["trial_seen"] = true
	if preseason_stop() == "story":
		_end_preseason_cards()


## ...and past the practice match (`simmed`: yours was just played without
## you) and the papers.
func _hands_off_stops(simmed: bool) -> void:
	if preseason_stop() == "practice":
		# Simmed here, the match is never shown, so its result goes in the
		# news (a match already coached live has its report shown).
		if simmed:
			var line := practice_news_line()
			if line != "":
				add_news("preseason", line, "Pre-season")
		(preseason["practice"] as Dictionary)["seen"] = true
	if preseason_stop() == "papers":
		papers_say_nothing()
		(preseason["papers"] as Dictionary)["seen"] = true


# ---------------------------------------------------------------------------
# Pre-season story cards (data/stories, phase "preseason")
# ---------------------------------------------------------------------------
## The block just finished may stop the pre-season for a card (at most one;
## most pre-seasons two or three over the three blocks). Round 1's cards, drawn
## when the season was made, wait aside until the pre-season is done. Returns
## whether a card is waiting.
func _preseason_cards() -> bool:
	if my_club == "" or not stories_on or is_sacked():
		return false
	var drawn := ClubStories.pick(self)
	if drawn.is_empty():
		return false
	if not preseason.has("round1"):
		preseason["round1"] = week_events
	week_events = drawn
	preseason["story_pending"] = true
	mark_dirty()
	return true


## The coach presses on from a card stop: what is still unanswered settles by
## the card's own rule, and Round 1's cards come back.
func _end_preseason_cards() -> void:
	_settle_week_event()
	preseason["story_pending"] = false
	if preseason.has("round1"):
		week_events = preseason["round1"]
		preseason.erase("round1")
	else:
		week_events = []
	mark_dirty()


## Running done on a card, in weeks of solid running toward the fitness base.
func preseason_add_running(weeks: float) -> void:
	var entry: Dictionary = (preseason.get("clubs", {}) as Dictionary).get(my_club, {})
	if entry.is_empty():
		return
	entry["run"] = maxf(0.0, float(entry.get("run", 0.0)) + weeks)


## The plan a card's drilling goes to: the one the side plays, or for a side
## that plays Balanced, the one it knows least.
func card_drill_plan() -> String:
	var plan := club_plan
	if not PreSeason.DRILL_PLANS.has(plan):
		_ensure_plan_known()
		plan = str(PreSeason.default_drill(plan, plan_known.get(my_club, {}))[0])
	return plan


## Weeks of drilling a card adds to the plan the side plays (or, for a side that
## plays Balanced, to the plan it knows least): counted with the blocks' own
## when the pre-season ends (_finish_drills).
func preseason_add_drill(weeks: int) -> void:
	var plan := card_drill_plan()
	var extra: Dictionary = preseason.get("bonus_drill", {})
	extra[plan] = float(extra.get(plan, 0.0)) + float(weeks)
	preseason["bonus_drill"] = extra


# ---------------------------------------------------------------------------
# The draft class the pre-season match trials (PreSeason.gd)
# ---------------------------------------------------------------------------
## The prospects who can be invited: the coming National Draft's class, not
## yet drafted, in the order the pool holds them. A kid already spoken for by
## another club (his tie, or a new club's academy) never reaches that draft, so
## he is no trial for this one; a kid tied to your own club still is.
func preseason_prospects() -> Array:
	var out := []
	for p in draftee_pool:
		if not drafted_draftees.has(str(p.get("id", ""))) and not _spoken_for_elsewhere(p):
			out.append(p)
	return out


## Whether begin_intake_draft will hand this prospect to a club that is not yours.
func _spoken_for_elsewhere(p: Dictionary) -> bool:
	var tie := str(p.get("tied_club", ""))
	if tie != "" and int(p.get("draft_year", 0)) == season_year:
		return tie != my_club
	var academy: String = ExpansionBuild.academy_club(self, p)
	return academy != "" and academy != my_club


## Your recruiters' read of this year's draft class, by id: {"overall": [lo, hi],
## "potential": [lo, hi], "rank": n}, the rank being where they have him in the
## class (director, 2026-10-19: prospects show OVR, POT and a projected draft
## ranking). The same read and weighting the National Draft shows and drafts on
## (DraftScouting.projection with this season's intake seed, Draft
## AI_POT_WEIGHT_INTAKE), so the draft night board agrees with it.
func prospect_reads(prospects: Array) -> Dictionary:
	var seed := prospect_read_seed()
	var mult := recruiting_uncertainty_mult()
	var out := {}
	var order := []
	for p in prospects:
		var view := DraftScouting.projection(p, my_club, seed, mult)
		var id := str(p.get("id", ""))
		out[id] = {"overall": view["overall"], "potential": view["potential"]}
		order.append([DraftScouting.scouted_worth(p, my_club, seed, Draft.AI_POT_WEIGHT_INTAKE, mult), id])
	order.sort_custom(func(a, b):
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) > float(b[0])
		return str(a[1]) < str(b[1]))
	for i in range(order.size()):
		(out[str(order[i][1])] as Dictionary)["rank"] = i + 1
	return out


## The seed of this season's reads of the draft class (prospect_reads).
func prospect_read_seed() -> int:
	return _clock_seed(2) if replay_seed != 0 else posmod(career_seed * 7919 + season_year * 131 + 34, 1000000)


## Best first; ties go to the id, so the same list gives the same order.
func _better_rated(a: Dictionary, b: Dictionary) -> bool:
	if int(a["overall"]) != int(b["overall"]):
		return int(a["overall"]) > int(b["overall"])
	return str(a["id"]) < str(b["id"])


## [value, id] rows, highest value first; ties go to the id.
func _higher_row(a: Array, b: Array) -> bool:
	if float(a[0]) != float(b[0]):
		return float(a[0]) > float(b[0])
	return str(a[1]) < str(b[1])


## The `n` prospects a club's recruiters rate highest (after `have`), by the
## read that club has of them: [ids], `have` not included.
func _guest_picks(club: String, n: int, have: Array, scouting_mult: float, skip := []) -> Array:
	var rows := []
	for p in preseason_prospects():
		if have.has(str(p["id"])) or skip.has(str(p["id"])):
			continue
		rows.append([DraftScouting.scouted_worth(p, club, career_seed, 0.5, scouting_mult), str(p["id"])])
	rows.sort_custom(_higher_row)
	var out := []
	for i in range(mini(maxi(0, n - have.size()), rows.size())):
		out.append(str(rows[i][1]))
	return out




# ---------------------------------------------------------------------------
# The practice match (PreSeason.gd): end of week 7, one match against another
# club. No ladder, no season record, no points.
# ---------------------------------------------------------------------------
## Yours, this pre-season: {"opponent", "invites": [prospect ids], "played",
## "seen", "report"}. {} before week 7, or when no club was left to play.
## (The hook for plan familiarity: a played practice match is
## preseason["practice"]["played"], with your plan in club_plan.)
func preseason_practice() -> Dictionary:
	return preseason.get("practice", {}) if preseason.get("practice") is Dictionary else {}


func practice_played() -> bool:
	return bool(preseason_practice().get("played", false))


## The club you play, or "".
func practice_opponent() -> String:
	return str(preseason_practice().get("opponent", ""))


func practice_invites() -> Array:
	return preseason_practice().get("invites", [])


## Trial a prospect, or take the invitation back. False when the places are
## taken, he is not in the class, or the match is played.
func toggle_practice_invite(id: String) -> bool:
	if preseason_stop() != "practice" or practice_played():
		return false
	var invites: Array = practice_invites()
	if invites.has(id):
		invites.erase(id)
		mark_dirty()
		return true
	var known := false
	for p in preseason_prospects():
		known = known or str(p.get("id", "")) == id
	if not known or invites.size() >= PreSeason.practice_guests():
		return false
	invites.append(id)
	(preseason["practice"] as Dictionary)["invites"] = invites
	mark_dirty()
	return true


## The club's side for the day: its named side (or the best available) with
## each invited prospect in place of the weakest starter in his line. Every
## listed player carries half a match's injury risk for it; a prospect plays
## as a copy with a spare number and cannot be hurt.
## Returns {"squad", "ids": [everyone in it], "guests": [prospect ids]}.
func _practice_squad(code: String, is_home: bool, invites: Array) -> Dictionary:
	var list: Array = season.lists[code]
	var rate := float(PreSeason.tune("practice_injury_rate"))
	for p in list:
		p["cond_injury"] = rate
	var sq := Squad.new(GameDB.club_name(code), list, is_home, code, season.selections.get(code, {}))
	var used := {}
	for p in list:
		used[int(p.get("num", 0))] = true
	var number := int(PreSeason.tune("guest_spare_number"))
	var pool := {}
	for p in preseason_prospects():
		pool[str(p["id"])] = p
	var ranked := []
	for id in invites:
		if pool.has(str(id)):
			ranked.append(pool[str(id)])
	ranked.sort_custom(_better_rated)
	var replaced := {}
	var guests := []
	for p in ranked:
		while used.has(number):
			number += 1
		used[number] = true
		var g := PreSeason.guest(p, number, code)
		var at := -1
		for pass_same in [true, false]:
			for i in range(sq.ground.size()):
				if replaced.has(i) or (pass_same and str(sq.ground[i]["role"]) != str(g.get("role", ""))):
					continue
				if at < 0 or float(sq.ground[i]["overall"]) < float(sq.ground[at]["overall"]):
					at = i
			if at >= 0:
				break
		if at < 0:
			continue
		var slot := Ratings._for_slot(g, str(sq.ground[at]["role"]))
		if sq.ground[at].has("line"):
			slot["line"] = sq.ground[at]["line"]
		sq.ground[at] = slot
		replaced[at] = true
		guests.append(str(g["id"]))
	if not guests.is_empty():
		sq._aggregate()
	sq.form = season.club_form(code)
	var ids := []
	for p in sq.ground + sq.bench:
		ids.append(str(p["id"]))
	return {"squad": sq, "ids": ids, "guests": guests}


## What trialling costs your side for the day, for the stop's Cost line: how
## far, as a percentage, each prospect rates below the starter he would replace
## (the same swap _practice_squad makes), averaged over the ones chosen, or over
## every prospect on offer before any is chosen. 0 when none rates below. Reads
## the side; changes nothing.
func practice_trial_gap_pct(invites: Array) -> int:
	if season == null or not season.lists.has(my_club):
		return 0
	var sq := Squad.new(GameDB.club_name(my_club), season.lists[my_club], true, my_club, season.selections.get(my_club, {}))
	var pool := []
	for p in preseason_prospects():
		if invites.is_empty() or invites.has(str(p["id"])):
			pool.append(p)
	var total := 0.0
	var n := 0
	for p in pool:
		var g := PreSeason.guest(p, 0, my_club)
		var at := -1
		for pass_same in [true, false]:
			for i in range(sq.ground.size()):
				if pass_same and str(sq.ground[i]["role"]) != str(g.get("role", "")):
					continue
				if at < 0 or float(sq.ground[i]["overall"]) < float(sq.ground[at]["overall"]):
					at = i
			if at >= 0:
				break
		if at < 0:
			continue
		var starter := float(sq.ground[at]["overall"])
		var slot := Ratings._for_slot(g, str(sq.ground[at]["role"]))
		if starter > 0.0:
			total += maxf(0.0, (starter - float(slot["overall"])) / starter * 100.0)
			n += 1
	return roundi(total / float(n)) if n > 0 else 0


## A practice match between two clubs: {"sim", "home", "away", "ids": {club:
## [ids]}, "guests": {club: [prospect ids]}}. Your side takes your game plan.
func _practice_build(home: String, away: String, home_invites: Array, away_invites: Array) -> Dictionary:
	var h := _practice_squad(home, true, home_invites)
	var a := _practice_squad(away, false, away_invites)
	CoachEffects.apply(h["squad"])
	CoachEffects.apply(a["squad"])
	var sim := MatchSim.new(h["squad"], a["squad"], PreSeason.practice_seed(career_seed, season_year, home, away))
	sim.season_year = season_year
	for side in range(2):
		sim.season_plans[side] = fitness_plan(str([home, away][side]))
		if [home, away][side] == my_club:
			sim.set_tactics(side, {"gameplan": club_plan})
	var started := {}
	for p in (h["squad"] as Squad).ground + (a["squad"] as Squad).ground:
		started[str(p["id"])] = true
	return {"sim": sim, "home": home, "away": away, "started": started,
			"ids": {home: h["ids"], away: a["ids"]}, "guests": {home: h["guests"], away: a["guests"]}}


## What a practice match leaves behind, at either club: a reserves game's
## development for the listed players who played, any injury to a listed
## player (never a prospect), and the club's note on each prospect it
## trialled. Nothing reaches the season's ladder, statistics, votes, records or
## the board; the margin moves the club on the papers' pre-season ladder
## (PreSeason.practice_nudge). Returns your report (for your club), or {}.
func _practice_finish(club: String, built: Dictionary, res: Dictionary) -> Dictionary:
	var stats_all: Dictionary = res.get("players", {})
	# Each club's margin, for the papers' ladder (PreSeason.practice_nudge).
	var sc: Array = res.get("score", [0, 0])
	var margin := int(sc[0]) - int(sc[1])
	if not (preseason.get("practice_margins") is Dictionary):
		preseason["practice_margins"] = {}
	(preseason["practice_margins"] as Dictionary)[club] = margin if club == str(built["home"]) else -margin
	var guests: Array = (built["guests"] as Dictionary).get(club, [])
	var played := {}
	for id in (built["ids"] as Dictionary).get(club, []):
		played[str(id)] = true
	var list: Array = season.lists[club]
	for p in list:
		p.erase("cond_injury")
	var staff: Dictionary = CoachEffects.staffs(coaches).get(club, {}) if not coaches.is_empty() else {}
	var xp := int(round(float(reserves_xp()) * float(PreSeason.tune("practice_xp_games"))))
	for p in list:
		if not played.has(str(p["id"])):
			continue
		p["xp"] = int(p.get("xp", 0)) + _club_xp(club, p, xp, staff, false)
		if club != my_club:
			ai_spend_xp(p)
	if club == my_club:
		apply_train_plans()
	var rows := []
	var w := preseason_week()
	for inj in res.get("injuries", []):
		var id := str(inj["id"])
		if guests.has(id):
			continue
		for p in list:
			if str(p["id"]) != id or int(p.get("injury_weeks", 0)) > 0:
				continue
			p["injury_weeks"] = int(inj["weeks"])
			p["injury_kind"] = str(inj["kind"])
			rows.append({"id": id, "club": club, "week": w, "weeks": int(inj["weeks"]), "kind": str(inj["kind"]), "how": "practice"})
			if club == my_club:
				add_news("injury", "%s (%s, %s) was hurt in the practice match." % [
						GameDB.player_display_name(p), str(inj["kind"]), _weeks_text(int(inj["weeks"]))], "Pre-season")
	if not rows.is_empty():
		if not (preseason.get("injuries") is Array):
			preseason["injuries"] = []
		(preseason["injuries"] as Array).append_array(rows)
	# The panel's sittings from this match: the rows this call adds, nothing matched by name.
	var sat_from := last_medical.size()
	if not rows.is_empty():
		_log_injuries(rows, "Practice match")
	var sat := []
	var sat_cleared := []
	for row in last_medical.slice(sat_from):
		if str(row.get("club", "")) == my_club:
			sat.append(MedicalPanel.result_short(row))
			sat_cleared.append(bool(row.get("cleared", false)))
	var seen_rows := []
	for p in draftee_pool:
		var id := str(p.get("id", ""))
		if not guests.has(id):
			continue
		var line := PreSeason.prospect_line(stats_all.get(id, {}))
		if not (p.get("seen") is Dictionary):
			p["seen"] = {}
		(p["seen"] as Dictionary)[club] = {"year": season_year, "line": line, "kind": "practice"}
		seen_rows.append({"id": id, "line": line})
	if club != my_club:
		return {}
	# Your report, by the match's own player rating: listed players only;
	# "struggled" is among those who started on the ground.
	var started: Dictionary = built.get("started", {})
	var scored := []
	for p in list:
		if played.has(str(p["id"])) and stats_all.has(str(p["id"])):
			scored.append([MatchNotes.rating(stats_all[str(p["id"])]), str(p["id"])])
	scored.sort_custom(_higher_row)
	var stood := []
	var struggled := []
	for i in range(mini(3, scored.size())):
		stood.append(str(scored[i][1]))
	for i in range(scored.size() - 1, 2, -1):
		if struggled.size() < 2 and started.has(str(scored[i][1])):
			struggled.append(str(scored[i][1]))
	var hurt := []
	for r in rows:
		var hp := list_player(str(r["id"]))
		if hp.is_empty():
			continue   # the medical panel ended his career (MedicalPanel)
		hurt.append("%s (%s, %s)" % [GameDB.player_display_name(hp), Injuries.wording(str(r["kind"])), _weeks_text(int(r["weeks"]))])
	last_injuries = rows.filter(func(r): return not list_player(str(r["id"])).is_empty())
	var score: Array = res.get("score", [0, 0])
	return {"score": [int(score[0]), int(score[1])], "goals": res.get("goals", [0, 0]), "behinds": res.get("behinds", [0, 0]),
			"names": [GameDB.club_name(str(built["home"])), GameDB.club_name(str(built["away"]))],
			"opponent": str(built["away"]),
			"stood": stood, "struggled": struggled, "hurt": hurt, "medical": sat, "medical_cleared": sat_cleared, "prospects": seen_rows}


## The practice week, once its matches are played.
func _preseason_week_end(job: Dictionary, results: Array) -> String:
	if _ai_practices_done(job, results):
		# Every other pair of clubs plays its own that week; yours waits for you.
		return "practice"
	if preseason_week() >= PreSeason.weeks():
		_finish_preseason()
		return "done"
	return ""


## Every other pair of clubs plays its practice match: each club's recruiters
## choose the prospects to trial by their own read of the class, the sides are
## their named or best available, and the matches are built in draw order,
## played together and finished in draw order (so the outcome never depends on
## which finished first). Your pairing is only noted; you play it. Returns
## the matches to play ({builds, sims, mine}); mine is "" when the draw
## leaves your club without a match.
func _ai_practices(clubs: Dictionary) -> Dictionary:
	_refresh_coach_tactics()
	var codes := []
	for club in season.clubs:
		if clubs.has(str(club)) and season.lists.has(club):
			codes.append(str(club))
	var pairs := PreSeason.practice_pairs(codes, my_club, career_seed, season_year)
	var builds := []
	var sims := []
	var n := PreSeason.practice_guests()
	var mine := ""
	for pr in pairs:
		var a := str(pr[0])
		var b := str(pr[1])
		if a == my_club or b == my_club:
			mine = b if a == my_club else a
			continue
		var pa := _guest_picks(a, n, [], 1.0)
		var pb := _guest_picks(b, n, [], 1.0, pa)
		var built := _practice_build(a, b, pa, pb)
		builds.append(built)
		sims.append(built["sim"])
	return {"builds": builds, "sims": sims, "mine": mine}


## The other clubs' practice matches go in; true when yours waits for you.
func _ai_practices_done(job: Dictionary, results: Array) -> bool:
	var builds: Array = job["builds"]
	var mine := str(job["mine"])
	for i in range(builds.size()):
		_practice_finish(str(builds[i]["home"]), builds[i], results[i])
		_practice_finish(str(builds[i]["away"]), builds[i], results[i])
	if mine == "":
		return false
	preseason["practice"] = {"opponent": mine, "invites": [], "played": false, "seen": false}
	return true


## The trial spots you have not filled, filled by your recruiters with the
## prospects they rate highest (what every club's recruiters do for theirs).
func practice_fill_invites() -> void:
	if preseason_stop() != "practice" or practice_played():
		return
	var invites: Array = practice_invites()
	for id in _guest_picks(my_club, PreSeason.practice_guests(), invites, recruiting_uncertainty_mult()):
		invites.append(id)
	(preseason["practice"] as Dictionary)["invites"] = invites


## Your practice match: your club at home, the opponent's recruiters trialling
## the prospects you have not.
func _practice_mine() -> Dictionary:
	_refresh_coach_tactics()
	var pr: Dictionary = preseason["practice"]
	var opp := str(pr["opponent"])
	practice_fill_invites()
	var mine: Array = pr.get("invites", [])
	return _practice_build(my_club, opp, mine, _guest_picks(opp, PreSeason.practice_guests(), [], 1.0, mine))


func _practice_done(built: Dictionary, res: Dictionary) -> void:
	var pr: Dictionary = preseason["practice"]
	pr["report"] = _practice_finish(my_club, built, res)
	_practice_finish(str(pr["opponent"]), built, res)
	pr["played"] = true


## The practice match's result in one news line, from the stored report:
## "Practice match: Fremantle 9.8 (62) beat West Coast 7.10 (52). Stood out:
## A, B." "" when there is no report.
func practice_news_line() -> String:
	var rep: Dictionary = preseason_practice().get("report", {})
	if rep.is_empty():
		return ""
	var names: Array = rep.get("names", [GameDB.club_name(my_club), GameDB.club_name(practice_opponent())])
	var goals: Array = rep.get("goals", [0, 0])
	var behinds: Array = rep.get("behinds", [0, 0])
	var sides := []
	for i in range(2):
		var g := int(goals[i])
		var b := int(behinds[i])
		sides.append("%s %d.%d (%d)" % [str(names[i]), g, b, g * 6 + b])
	var mine := int(goals[0]) * 6 + int(behinds[0])
	var theirs := int(goals[1]) * 6 + int(behinds[1])
	var verb := "drew with" if mine == theirs else ("beat" if mine > theirs else "lost to")
	var line := "Practice match: %s %s %s." % [sides[0], verb, sides[1]]
	var stood := []
	for id in rep.get("stood", []):
		var p := list_player(str(id))
		if not p.is_empty():
			stood.append(GameDB.player_display_name(p))
	if not stood.is_empty():
		line += " Stood out: %s." % ", ".join(PackedStringArray(stood))
	return line


## Your practice match, simmed on the side and the trial as they stand.
func sim_practice_match() -> bool:
	if preseason_stop() != "practice" or practice_played():
		return false
	var built := _practice_mine()
	_practice_done(built, (built["sim"] as MatchSim).run())
	mark_dirty()
	return true


## sim_practice_match on a thread while frames draw (same match, same result).
func sim_practice_match_async() -> bool:
	if preseason_stop() != "practice" or practice_played():
		return false
	var built := _practice_mine()
	var job := Season.start_all([built["sim"]], 1)
	while Season.running(job):
		await get_tree().process_frame
	_practice_done(built, Season.finish_all(job)[0])
	mark_dirty()
	return true


var _practice_built := {}     # the live practice match being coached (never saved)


## Set your practice match up to be coached live from the box, like any match.
func prepare_practice_match() -> bool:
	if preseason_stop() != "practice" or practice_played():
		return false
	# The practice match is always watched: Skip does not carry over ("Coach
	# the match" was pressed, and Sim the match is beside it).
	match_way_live = "watch"
	_clear_pending()
	_practice_built = _practice_mine()
	pending_sim = _practice_built["sim"]
	pending_match = {"home": my_club, "away": practice_opponent(), "round": 0, "label": "Practice match"}
	pending_sim.moment_side = 0
	pending_sim.always_offer_bounce = bounce_scene_every_match()
	pending_phase = "practice"
	pending_label = "Practice match"
	return true


func _finish_live_practice(res: Dictionary) -> void:
	if _practice_built.is_empty() or not (preseason.get("practice") is Dictionary):
		_clear_pending()
		return
	_practice_done(_practice_built, res)
	_practice_built = {}
	_clear_pending()
	mark_dirty()
	autosave()


## After Round 1 the pre-season's heavy or fresh legs are spent, at every
## club (your own week flags are cleared with the round, as always).
func _preseason_clear_legs() -> void:
	if not bool(preseason.get("legs", false)) or season == null:
		return
	preseason["legs"] = false
	for code in season.lists:
		for p in season.lists[code]:
			p.erase("heavy_legs")
			p.erase("fresh")


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


## Where a club finished last season, 0 when there is nothing true to say. In
## a career's first season that is the real final ladder before it (the real
## 2026 ladder, data/ladder_2026.csv), but only for a real-lists career whose
## club is a real one: a redrafted league, a Club Forge club and expansion
## clubs have no real finish.
func last_finish_of(code: String) -> int:
	if _last_finish.has(code):
		return int(_last_finish[code])
	if not _last_finish.is_empty() or start_mode != "real" or season_year != GameDB.START_YEAR:
		return 0
	var mine := false
	var theirs := 0
	for r in GameDB.ladder_of(GameDB.DATA_SEASON):
		if str(r["club"]) == my_club:
			mine = true
		if str(r["club"]) == code:
			theirs = int(r["pos"])
	return theirs if mine else 0


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
	return Matchup.facts(code, season.lists, season.selections, season.club_results(code),
			MatchSim.loose_pick(_rival_squad(code).ground, my_squad().ground))


## Your former players on `code`'s list (FormerPlayers.against): who left
## you and now lines up against you, the most games for you first.
func former_players(code: String) -> Array:
	if season == null or code == "" or code == my_club or not season.lists.has(code):
		return []
	return FormerPlayers.against(season.lists[code], my_club, season_year, season_wrap,
			captaincy_record(code), honour_roll)



## Storylines before the bounce (OldClubLines, T5.Q9): players in this week's
## two sides who meet a club they played 100+ games for, every spell and this
## season counted, the most games first. `skip` holds ids another pre-match
## line already names. Presentation only: the match never reads it.
func old_club_lines(code: String, skip := {}) -> Array:
	if season == null or code == "" or code == my_club or not season.lists.has(code):
		return []
	var mine := my_squad()
	var theirs := Squad.new(GameDB.club_name(code), season.lists[code], true, code,
			season.selections.get(code, {}))
	return OldClubLines.rows(_listed(my_list, mine), _listed(season.lists[code], theirs), my_club, code,
			func(p: Dictionary, club: String) -> int: return int(club_tally(p, club)["games"]), skip)


## The list's own player records for a squad's picked side (ground and bench):
## the squad holds match copies, the list holds his career.
func _listed(list: Array, sq: Squad) -> Array:
	var ids := {}
	for p in sq.ground + sq.bench:
		ids[str(p.get("id", ""))] = true
	return list.filter(func(p): return p is Dictionary and ids.has(str(p.get("id", ""))))

## What comes next, in one line: "Next: Round 5 v Carlton at the MCG." ""
## when there is no fixture to name (finals are drawn week by week).
func next_fixture_line() -> String:
	if season == null or season.is_regular_done():
		return ""
	var nxt := my_next_opponent()
	if nxt.is_empty():
		return ""
	if nxt.has("event"):
		return "Next: %s, v %s at %s." % [season.round_label(season.round_index),
				GameDB.club_name(str(nxt["code"])), GameDB.ground_shown(str(nxt["ground"]))]
	return "Next: %s %s %s." % [season.round_name(season.round_index),
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


## The assistant's report on an opponent (director, 2026-10-07): what has
## been seen of them, each fact said once - [["How they play", [lines]],
## ["Who matters", [lines]], ["Their coach", [lines]]], a part left out when
## it has nothing.
## How they play: their usual game and what it costs their legs, which plan
## their list suits and how well they know each, their style, a run of
## results, their plans this season and against you (rival_plans).
## Who matters: their best player missing, their danger, their tagger, the
## loose man their coach starts with (when he is not the danger) and his
## minder rule.
## Their coach (a rival coach's club only): his habit with the scoreboard and
## the fire-up, his box's sharpness and tag timing, his counter rule.
## Rival coach read (director, 2026-11-08): every line is RivalRead, from the
## rules MatchSim.ai_tactics plays. Facts only, never how to beat them.
func opponent_report(code: String) -> Array:
	if season == null or code == "" or not season.lists.has(code):
		return []
	var sq := _rival_squad(code)
	var play := []
	var usual := _squad_usual(sq)
	if THEIR_PLAN.has(usual):
		var legs := RivalRead.legs_clause(usual)
		var what := str(THEIR_PLAN[usual])
		play.append("Their usual game plan is %s. %s%s%s" % [RivalRead.called(usual),
				what.left(1).to_upper(), what.substr(1), " " + legs if legs != "" else ""])
	if usual == CustomPlan.KEY:
		var own := CustomPlan.rival_line(_season_customs().get(code, {}))
		if own != "":
			play.append(own)
	var levels := {}
	for plan in PreSeason.DRILL_PLANS:
		levels[plan] = plan_level(code, str(plan))
	play.append("%s %s" % [RivalRead.fit_line(sq.ground), RivalRead.know_line(levels)])
	play.append_array(their_style(code, 3))
	var people := []
	var danger_id := ""
	for f in opponent_people(code):
		if str(f["key"]) == "form":
			play.append(str(f["text"]))
		else:
			people.append(str(f["text"]))
			if str(f["key"]) == "danger":
				danger_id = str(f.get("player_id", ""))
	var rows := rival_rows(code)
	for line in [RivalRead.season_line(rows, usual), RivalRead.last_line(rows, my_club), RivalRead.vs_line(rows, my_club)]:
		if line != "":
			play.append(line)
	var mine := my_squad()
	var tagger = MatchSim.tagger_for(sq.ground)
	var has_tagger: bool = tagger != null and Roles.is_tagger(tagger)
	if has_tagger:
		people.append(RivalRead.tagger_line(GameDB.player_display_name(tagger)))
	var loose := MatchSim.loose_pick(sq.ground, mine.ground)
	if not loose.is_empty() and str(loose.get("id", "")) != danger_id:
		people.append(RivalRead.loose_line(GameDB.player_display_name(loose), sq.coach_style))
	var minders := Matchups.minder_candidates(sq.ground)
	if not MatchSim.loose_pick(mine.ground, sq.ground).is_empty() and not minders.is_empty():
		people.append(RivalRead.minder_line(GameDB.player_display_name(minders[0])))
	var coach := []
	if sq.ai_plans:
		var sc: Dictionary = club_staff(code).get("SC", {})
		coach.append(RivalRead.coach_line(GameDB.player_display_name(sc) if not sc.is_empty() else "",
				sq.coach_style))
		coach.append(RivalRead.box_line(sq.tactics_read, has_tagger))
		coach.append(RivalRead.counter_line())
	var out := []
	var seen := {}
	for part in [["How they play", play], ["Who matters", people], ["Their coach", coach]]:
		var lines := []
		for t in part[1]:
			if not seen.has(str(t)):
				seen[str(t)] = true
				lines.append(str(t))
		if not lines.is_empty():
			out.append([part[0], lines])
	return out


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
			elif p.has("season_ban"):
				why = "banned for the season"
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
## Petracca, Brayshaw." "" for Balanced.
func plan_fit_line(ground: Array, plan: String) -> String:
	if not PlanFit.NEEDS.has(plan):
		return ""
	var names := PackedStringArray()
	for p in PlanFit.carriers(ground, plan).slice(0, 4):
		names.append(GameDB.player_display_name(p))
	return "Your %s are %s: %s." % [str(PlanFit.NEEDS[plan]["word"]), PlanFit.fit_word(ground, plan), ", ".join(names)]


## The same facts in two short parts for the game plan panel: how good
## the side is for the plan, and the best three for it. {} for Balanced.
func plan_fit_short(ground: Array, plan: String) -> Dictionary:
	if not PlanFit.NEEDS.has(plan):
		return {}
	var names := PackedStringArray()
	for p in PlanFit.carriers(ground, plan).slice(0, 3):
		names.append(GameDB.player_display_name(p))
	var judged := "Your %s are %s." % [str(PlanFit.NEEDS[plan]["word"]), PlanFit.fit_word(ground, plan)]
	return {"judged": judged, "names": ", ".join(names)}


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


## A club's usual game as the match engine opens with it (MatchSim standing):
## the one its coach settled on this season (_settle_usual_plans), or before
## that the plan the side it would field this week suits (PlanFit.standing_plan),
## weighed by how well the club knows each plan.
func usual_plan(code: String) -> String:
	if season == null or code == "" or not season.lists.has(code):
		return "balanced"
	return _squad_usual(_rival_squad(code))


## `code`'s side as the match engine will field it this week, with its
## coaching (CoachEffects: plan knowledge, box, coach's tendency). Its row is
## worked out from the coaches as they stand (CoachEffects.row), as the match
## does at kick-off, not read from the table: a loaded career has no table
## until its next match, and rebuilding one here would write a new coach's
## style on his record early (Coaches.style) and change how a reloaded career
## plays. The coaches' records are left alone. Its tactics_exec leaves out
## high performance (_refresh_coach_tactics); nothing that reads it here uses it.
func _rival_squad(code: String) -> Squad:
	var sq := Squad.new(code, season.lists[code], false, code, season.selections.get(code, {}))
	_ensure_plan_known()
	if not coaches.is_empty():
		CoachEffects.apply_row(sq, CoachEffects.row(CoachEffects.staffs(coaches).get(code, {}), code == my_club))
		sq.usual_plan = str(_season_usuals().get(code, "")) if sq.ai_plans else ""
	return sq


## The usual game the match engine opens `sq` with (MatchSim standing): its
## coach's for the season once settled, else the plan its side suits.
static func _squad_usual(sq: Squad) -> String:
	return sq.usual_plan if sq.usual_plan != "" else PlanFit.standing_plan(sq.ground, sq.plan_know)


## Compact stored-fact history surfaces. These deliberately read existing
## records/honour_roll rather than reconstructing or inventing old seasons.
## "quarter time", "half time" or "three-quarter time" for break 0, 1 or 2.
func _break_name(i: int) -> String:
	return ["quarter time", "half time", "three-quarter time"][clampi(i, 0, 2)]


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
	var back: Dictionary = records.get("biggest_comeback", {})
	if not back.is_empty():
		out.append("Greatest comeback: %s, from %d points down at %s, beat %s (%d)" % [
				GameDB.club_name(str(back.get("club", ""))), int(back.get("value", 0)),
				_break_name(int(back.get("at", 1))), GameDB.club_name(str(back.get("opp", ""))),
				int(back.get("year", 0))])
	var blown: Dictionary = records.get("biggest_blown", {})
	if not blown.is_empty():
		out.append("Biggest lead lost: %s led %s by %d points at %s and lost (%d)" % [
				GameDB.club_name(str(blown.get("club", ""))), GameDB.club_name(str(blown.get("opp", ""))),
				int(blown.get("value", 0)), _break_name(int(blown.get("at", 1))), int(blown.get("year", 0))])
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


## The years `code` won the flag in this career, newest first (honour_roll: what
## happened in this save, nothing imported or invented).
func premiership_years(code: String) -> Array:
	var out := []
	for i in range(honour_roll.size() - 1, -1, -1):
		var h: Dictionary = honour_roll[i]
		if code != "" and str(h.get("premier", "")) == code:
			out.append(int(h.get("year", 0)))
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


## Your side as arranged now, ground and bench: what the Team Chemistry meter reads.
func familiarity_side() -> Array:
	if season == null or my_club == "":
		return []
	var squad := my_squad()
	return squad.ground + squad.bench


## Every club's week for team familiarity: a man who played comes on a senior
## game's worth; a man left out but fit, a reserves game's.
func _familiarity_after_round(results: Array) -> void:
	if season == null:
		return
	for res in results:
		var roster: Array = res.get("roster", [[], []])
		for side in range(2):
			var code := str(res.get("home" if side == 0 else "away", ""))
			if code == "" or not season.lists.has(code) or roster.size() <= side:
				continue
			var played := {}
			for r in roster[side]:
				played[str(r["id"])] = true
			for p in season.lists[code]:
				var id := str(p["id"])
				if played.has(id):
					TeamFamiliarity.after_game(p, true)
				elif Ratings.available(p) and not _round_unavailable.has(id):
					TeamFamiliarity.after_game(p, false)


func _clear_familiarity(list: Array) -> void:
	for p in list:
		TeamFamiliarity.clear(p)


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


## The run-through banner's occasion for a match (Banners.pick reads it):
## {home, away, us, round, marquee, final, must_win, spoon, first_game,
## premiers, milestone, year, seed}. `match` is a fixture or finals entry
## ({home, away} and a finals "tag"). Only what anyone at the ground knows:
## the ladder, the fixture, the record books. Presentation only.
##  - must_win: the last home-and-away round only, from the ladder (points,
##    then percentage as it stands): a loss leaves this side out of the ten
##    whatever else happens this round, and a win can still get it in.
##  - spoon: both sides in the bottom three in the last six rounds.
##  - first_game: an expansion club's first ever match.
##  - premiers: the reigning premier in its first match of the season (the
##    flag game), not every week.
##  - milestone: someone in this side's 23 whose next game is his debut or
##    a 50-game milestone (to 350), else a known farewell in the last
##    round or a final.
const BANNER_FINALS := {"WC": "wildcard", "QF": "qualifying", "EF": "elimination",
		"SF": "semi", "PF": "preliminary", "GF": "grand"}
const BANNER_MILESTONES := [50, 100, 150, 200, 250, 300, 350]
## Games for one club that its banner honours (FL-002), when they aren't
## also a career milestone: a player who came from another club.
const BANNER_CLUB_MILESTONES := [100, 150, 200, 250, 300]


func banner_context(match: Dictionary) -> Dictionary:
	var home := str(match.get("home", ""))
	var away := str(match.get("away", ""))
	var us := my_club if (my_club == home or my_club == away) else home
	var them := away if us == home else home
	var tag := str(match.get("tag", ""))
	var week := str(BANNER_FINALS.get(tag.substr(0, 2), "")) if tag != "" else ""
	var regular := week == "" and season != null and not season.is_regular_done()
	var last_round := regular and season.round_index == season.fixture.size() - 1
	var round_label := str(match.get("label", season.round_name(season.round_index) if season != null else ""))
	var ctx := {
		"home": home, "away": away, "us": us, "round": round_label,
		"marquee": MarqueeGames.label(home, away), "final": week,
		"must_win": last_round and _must_win(us, them),
		"spoon": regular and season.round_index >= season.fixture.size() - 6 and _bottom(home, 3) and _bottom(away, 3),
		"first_game": _first_game(home, away) if regular else "",
		"premiers": _flag_game(home, away) if regular else "",
		"milestone": _banner_milestone(us, last_round or week != ""),
		# FL-008: your premierships of this career, on pennants round your own ground.
		"flags": premiership_years(us) if us == home and us == my_club else [],
		"year": season_year,
		"seed": hash([int(season.seed) if season != null else 0, season_year, round_label, home, away]),
		# The day's weather (the hub's upcoming match carries it), for the pre-match scene.
		"weather": str(match.get("weather", "")),
	}
	return ctx


func _ladder_ahead(row: Dictionary, pts: int, pct: float) -> bool:
	var rp := int(row.get("pts", 0))
	return rp > pts or (rp == pts and float(row.get("pct", 0.0)) > pct)


## How many clubs finish above `us` on `pts` this round, at least (lowest)
## or at most (highest), over every result of the round's other games.
func _ahead_count(us: String, them: String, pts: int, lowest: bool) -> int:
	var pct := float((season.ladder[us] as Dictionary).get("pct", 0.0))
	var playing := {}
	var n := 0
	for m in season.fixture[season.round_index]:
		var h := str(m["home"])
		var a := str(m["away"])
		playing[h] = true
		playing[a] = true
		if h == us or a == us:
			continue
		var rh: Dictionary = season.ladder[h]
		var ra: Dictionary = season.ladder[a]
		var h_win := int(_ladder_ahead({"pts": int(rh.get("pts", 0)) + 4, "pct": rh.get("pct", 0.0)}, pts, pct)) + int(_ladder_ahead(ra, pts, pct))
		var a_win := int(_ladder_ahead(rh, pts, pct)) + int(_ladder_ahead({"pts": int(ra.get("pts", 0)) + 4, "pct": ra.get("pct", 0.0)}, pts, pct))
		n += mini(h_win, a_win) if lowest else maxi(h_win, a_win)
	for code in season.ladder:
		if not playing.has(code) and _ladder_ahead(season.ladder[code], pts, pct):
			n += 1
	# Their side of our game: they lose if we win, and win if we lose.
	if them != "" and season.ladder.has(them):
		var rt: Dictionary = season.ladder[them]
		var won := pts > int((season.ladder[us] as Dictionary).get("pts", 0))
		n += int(_ladder_ahead(rt if won else {"pts": int(rt.get("pts", 0)) + 4, "pct": rt.get("pct", 0.0)}, pts, pct))
	return n


func _must_win(us: String, them: String) -> bool:
	if season == null or not season.ladder.has(us):
		return false
	var pts := int((season.ladder[us] as Dictionary).get("pts", 0))
	var out_if_lose := _ahead_count(us, them, pts, true) >= season.finalists()
	var in_if_win := _ahead_count(us, them, pts + 4, true) < season.finalists()
	return out_if_lose and in_if_win


func _bottom(code: String, n: int) -> bool:
	var rows := season.ladder_sorted()
	for i in range(maxi(0, rows.size() - n), rows.size()):
		if str(rows[i]["code"]) == code:
			return true
	return false


func _first_game(home: String, away: String) -> String:
	for code in [home, away]:
		if GameDB.enter_year(code) == season_year and GameDB.enter_year(code) > 2026 \
				and season.ladder.has(code) and int(season.ladder[code]["p"]) == 0:
			return code
	return ""


## Last season's premier, in its first game of this season.
func _flag_game(home: String, away: String) -> String:
	var prem := ""
	for entry in honour_roll:
		if int(entry.get("year", 0)) == season_year - 1:
			prem = str(entry.get("premier", ""))
	if prem != "" and (prem == home or prem == away) and season.ladder.has(prem) \
			and int(season.ladder[prem]["p"]) == 0:
		return prem
	return ""


func _banner_milestone(code: String, farewell_ok: bool) -> Dictionary:
	if season == null or not season.lists.has(code):
		return {}
	var sq: Squad = my_squad() if code == my_club else Squad.new(GameDB.club_name(code), season.lists[code], true, code)
	var best := {}
	var best_games := -1
	var club := {}
	var club_games := -1
	var farewell := {}
	for p in sq.ground + sq.bench:
		var name := str(GameDB.player_display_name(p))
		var surname := name.split(" ")[-1]
		var played := games_played(p)
		var next := played + 1
		if Career.complete(p) and (BANNER_MILESTONES.has(next) or played == 0) and next > best_games:
			best = {"player": surname, "name": name, "games": next, "id": str(p.get("id", ""))}
			best_games = next
		elif Career.complete(p):
			var here := int(club_tally(p, code)["games"]) + 1
			if BANNER_CLUB_MILESTONES.has(here) and here > club_games:
				club = {"player": surname, "name": name, "games": here, "club": true, "id": str(p.get("id", ""))}
				club_games = here
		if farewell_ok and farewell.is_empty() and retiring_now(p):
			farewell = {"player": surname, "name": name, "games": "farewell", "id": str(p.get("id", ""))}
	if not best.is_empty():
		return best
	return club if not club.is_empty() else farewell


## What he has done for your club: {"games", "goals", "since", "bf": [years],
## "flags": [years]}. Games and goals count every spell at the club, this
## season included; "since" is when his current spell began.
## His games and goals for one club, every spell, this season included:
## {"games", "goals", "spells": [[from, to], ...]}.
func club_tally(p: Dictionary, code: String) -> Dictionary:
	var out := {"games": 0, "goals": 0, "spells": []}
	var c := Career.of(p)
	for st in c.get("stints", []):
		if str(st[0]) == code:
			out["games"] = int(out["games"]) + int(st[3])
			out["goals"] = int(out["goals"]) + int(st[4])
			(out["spells"] as Array).append([int(st[1]), int(st[2])])
	var t: Dictionary = season_tally.get(str(p.get("id", "")), {})
	if int(c.get("through", 0)) < season_year and str(t.get("club", "")) == code:
		out["games"] = int(out["games"]) + int(t.get("games", 0))
		out["goals"] = int(out["goals"]) + int(t.get("goals", 0))
		var sp: Array = out["spells"]
		if sp.is_empty() or int(sp[-1][1]) < season_year - 1:
			sp.append([season_year, season_year])
	return out


func with_us(p: Dictionary) -> Dictionary:
	var out := {"games": 0, "goals": 0, "since": 0, "bf": [], "flags": []}
	if my_club == "":
		return out
	var id := str(p.get("id", ""))
	var tally := club_tally(p, my_club)
	out["games"] = tally["games"]
	out["goals"] = tally["goals"]
	var spells: Array = tally["spells"]
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


## "With us since 2028: 3 games, 1 goal. Debuted in Round 7, 2028, on your
## say-so. First goal in Round 9, 2028. Best and fairest 2029. Premiership
## 2030." "" for someone yet to play for you. The debut and the first goal are
## what Firsts kept when they happened.
func with_us_text(p: Dictionary) -> String:
	var w := with_us(p)
	if int(w["games"]) <= 0:
		return ""
	var g := int(w["games"])
	var gl := int(w["goals"])
	var bits := PackedStringArray(["With us since %d: %d game%s, %s." % [int(w["since"]), g,
			"" if g == 1 else "s", "no goals" if gl == 0 else "%d goal%s" % [gl, "" if gl == 1 else "s"]]])
	bits.append_array(PackedStringArray(Firsts.with_us_bits(p)))
	if not (w["bf"] as Array).is_empty():
		bits.append("%s %s." % [BestAndFairest.award_name(my_club),
				", ".join(PackedStringArray((w["bf"] as Array).map(func(y): return str(y))))])
	if not (w["flags"] as Array).is_empty():
		var f: Array = w["flags"]
		bits.append("%s %s." % ["Premiership" if f.size() == 1 else "Premierships",
				", ".join(PackedStringArray(f.map(func(y): return str(y))))])
	return " ".join(bits)


## Players of yours in the match about to be played for whom a goal would be a
## first AFL goal: a career on record in full with none yet. {id: true}. The
## live feed says it when one of them kicks it (MatchNotes.story_feed_line).
func first_goal_candidates() -> Dictionary:
	var out := {}
	if pending_sim == null or pending_match.is_empty() or my_club == "":
		return out
	var side := 0 if str(pending_match.get("home", "")) == my_club else 1
	var squad: Squad = pending_sim.squads[side]
	for row in squad.ground + squad.bench:
		var p := list_player(str(row["id"]))
		if not p.is_empty() and Career.complete(p) and career_goals_before(p) == 0:
			out[str(p["id"])] = true
	return out


## What a match of yours settled, for full time: a debut, a first goal, a
## promised run done (Firsts.match_lines). [] for a match that is not yours or
## settled nothing.
func payoff_lines(res: Dictionary) -> Array:
	if my_club == "":
		return []
	var me := 0 if str(res.get("home", "")) == my_club else (1 if str(res.get("away", "")) == my_club else -1)
	return Firsts.match_lines(res, me, season_year, list_player, my_list)


## payoff_lines before the cap, each {id, kind, text} (Firsts.match_items).
func payoff_items(res: Dictionary) -> Array:
	if my_club == "":
		return []
	var me := 0 if str(res.get("home", "")) == my_club else (1 if str(res.get("away", "")) == my_club else -1)
	return Firsts.match_items(res, me, season_year, list_player, my_list)


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


## Your next opponent, venue and forecast (ARD-M4-016), for the fixture card.
func my_next_opponent() -> Dictionary:
	if season == null or season.is_regular_done():
		return {}
	var round_matches: Array = season.fixture[season.round_index]
	for m in round_matches:
		if m["home"] == my_club or m["away"] == my_club:
			var home: bool = m["home"] == my_club
			var out := {"code": m["away"] if home else m["home"], "venue": "home" if home else "away",
					"weather": season.weather_for(str(m["home"]), str(m["away"]), season.round_index)}
			# Gather Round: the match is at the host ground; "home" only for a club
			# playing at its own ground (rule 2.38), else "neutral".
			if season.round_index == season.gather_round():
				var at: Array = season.round_at_home(season.round_index, str(m["home"]), str(m["away"]))
				out["event"] = GatherRound.NAME
				out["ground"] = season.round_venue(season.round_index, str(m["home"]), str(m["away"]))
				out["venue"] = "home" if bool(at[0 if home else 1]) else "neutral"
			return out
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
	if season.finals_eliminated(my_club):
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
	if not ["wildcard10", "afl8"].has(season.finals_format()):
		return _past_finals_outcome_line(res, tag, won)
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


## finals_outcome_line for a past year's final five, six or McIntyre eight,
## read from the bracket: where the result sends you next.
func _past_finals_outcome_line(res: Dictionary, tag: String, won: bool) -> String:
	if bool(res.get("replay_due", false)):
		return "Level at the final siren: the final is played again next week."
	if tag == "GF":
		return ("%d PREMIERS" % season_year) if won else ("Runners-up in %d" % season_year)
	if not won:
		return "Second chance: you play again next week." if season.loser_goes_on(tag, my_club) 				else "Knocked out. Your season is over."
	var spec := SeasonRules.bracket(season.finals_format())
	var at := -1
	var next_week := -1
	var next_label := ""
	for w in range(spec.size()):
		for e in spec[w]:
			if str(e[0]) == tag:
				at = w
	for w in range(at + 1, spec.size()):
		for e in spec[w]:
			var mine := str(e[2]) == "W_" + tag or str(e[3]) == "W_" + tag
			for side in [str(e[2]), str(e[3])]:
				if at == 0 and side.begins_with("RW") and season.finals_slot(side) == my_club:
					mine = true
			if mine and next_week < 0:
				next_week = w
				next_label = str(e[1])
	if next_label == "Grand Final":
		return "Into the Grand Final!" + (" A week off first." if next_week > at + 1 else "")
	if next_week > at + 1:
		return "Through, with a week off before the %s." % SeasonRules.week_name(
				season.finals_format(), next_week + 1).to_lower()
	return "Through to the %s." % SeasonRules.week_name(season.finals_format(), next_week + 1).to_lower()


## A player's club is the list he is on (Develop's room and the coaches'
## teaching read it). Returns how many players it changed.
func _rehome_players(lists: Dictionary) -> int:
	var changed := 0
	for code in lists:
		for p in lists[code]:
			if p is Dictionary and str(p.get("club", "")) != str(code):
				p["club"] = str(code)
				changed += 1
	return changed


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


## A player's display name from any current list, for ids the database
## cannot resolve (a player who joined a list during the career), or from the
## name kept when he left the game (CareerFacts.name_card). "" if none.
func season_player_name(player_id: String) -> String:
	var groups: Array = [my_list, free_agents]
	if season != null:
		for code in season.lists:
			groups.append(season.lists[code])
	for arr in groups:
		for p in arr:
			if p is Dictionary and str(p.get("id", "")) == player_id:
				return GameDB.player_display_name(p)
	if departed_names.get(player_id) is Dictionary:
		return GameDB.player_display_name(departed_names[player_id])
	return ""


## His potential as your club knows it: exact for your own players, a
## recruiters' range for anyone else (DraftScouting.pot_read). {"mid",
## "range", "exact"}; "text" is ready to show ("82" or "78-84").
func pot_view(p: Dictionary) -> Dictionary:
	var pot := maxi(int(p.get("overall", 50)), int(p.get("potential", p.get("overall", 50))))
	if not list_player(str(p.get("id", ""))).is_empty():
		return {"mid": pot, "range": [pot, pot], "exact": true, "text": str(pot)}
	var r := DraftScouting.pot_read(p, my_club, career_seed,
			ClubBudget.scouting_mult(department_budget_level("recruiting")))
	var rg: Array = r["range"]
	return {"mid": int(r["mid"]), "range": rg, "exact": false,
			"text": str(rg[0]) if int(rg[0]) == int(rg[1]) else DraftScouting.range_text(rg)}


## Anyone in the game by id: your list, the season's lists, then the free
## agents. {} when he has left the game.
func _any_player(player_id: String) -> Dictionary:
	var p := list_player(player_id)
	if not p.is_empty():
		return p
	if season != null:
		for code in season.lists:
			for q in season.lists[code]:
				if str(q.get("id", "")) == player_id:
					return q
	return free_agent(player_id)


func list_player(player_id: String) -> Dictionary:
	for p in my_list:
		if str(p.get("id", "")) == player_id:
			return p
	return {}


## FL-005: change or remove one of your players' nicknames (cosmetic only, no
## cost). "" removes it; it stays removed. Returns the nickname now shown.
const NICKNAME_MAX := 16


func set_player_nickname(player_id: String, text: String) -> String:
	var p := list_player(player_id)
	if p.is_empty():
		return ""
	p["nickname"] = text.strip_edges().left(NICKNAME_MAX)
	return FictionalIdentity.nickname(p)


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
	TrainingReport.before_game(self)
	last_training_report = grant_match_xp(res)
	_note_reserves_games(last_training_report, key)
	# Training plans spend the fresh XP straight away.
	last_training_report["auto"] = apply_train_plans()
	last_training_report["projects"] = _advance_projects()
	TrainingReport.after_game(self)


## Your players left out but fit play in the reserves (the XP's own test,
## _grant_xp): each gets a game line and a rating there (ReservesForm).
## Display only, with its own seeded roll: nothing else in the career moves.
func _note_reserves_games(report: Dictionary, key: String) -> void:
	for row in report.get("rows", []):
		if not bool(row.get("reserves", false)):
			continue
		var id := str(row["id"])
		var p := list_player(id)
		if p.is_empty():
			continue
		ReservesForm.record(reserves_log, id,
				ReservesForm.game(p, ReservesForm.seed_for(career_seed, "%d|%s" % [season_year, key], id)), key)


## The form marks on Team selection for a side (ReservesForm.marks): the
## coldest three in it and the hottest three fit players left out.
func form_marks(side: Dictionary) -> Dictionary:
	var in_side := {}
	var side_ids := []
	for line in side:
		for id in side[line]:
			in_side[str(id)] = true
			side_ids.append(str(id))
	var reserve_ids := []
	for p in my_list:
		if not in_side.has(str(p["id"])) and Ratings.available(p):
			reserve_ids.append(str(p["id"]))
	return ReservesForm.marks(side_ids, reserve_ids, form_log, reserves_log, _xp_grant_key)


## Every player on the list is paid. Named players and good games earn more;
## fit players left out develop in the reserves at half a senior game.
## The old trainer picked five names at random and hid everyone else.
func grant_match_xp(res: Dictionary) -> Dictionary:
	return _grant_xp(my_club, my_list, res)


## Pay one club's list for a match. Same scale for every club: the rivals
## earn exactly what your players earn.
func _grant_xp(club: String, list: Array, res: Dictionary, staffs = null) -> Dictionary:
	var stats_all: Dictionary = res.get("players", {})
	var side := Ratings.select_side(list,
			season.selections.get(club, {}) if season != null else {})
	var ground_ids := {}
	var bench_ids := {}
	for p in side["ground"]:
		ground_ids[str(p["id"])] = true
	for p in side["bench"]:
		bench_ids[str(p["id"])] = true
	var rows: Array = []
	var total := 0
	var reserves_count := 0
	var reserves_total := 0
	# The club's teachers (CoachEffects): only once there is a coaching world.
	if staffs == null and not coaches.is_empty():
		staffs = CoachEffects.staffs(coaches)
	var staff: Dictionary = staffs.get(club, {}) if not coaches.is_empty() else {}
	var plan := ""
	for p in list:
		var id := str(p["id"])
		var on_ground := ground_ids.has(id)
		var on_bench := bench_ids.has(id)
		var stats: Dictionary = stats_all.get(id, {})
		# Left out but fit to play: he turns out in the reserves.
		var reserves := not on_ground and not on_bench and Ratings.available(p)
		if plan == "":
			plan = fitness_plan(club)   # once a club, not once a player
		var gain := _club_xp(club, p, _xp_amount(stats, on_ground, on_bench, reserves), staff, on_ground, plan)
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


## XP as his club turns it into development: its teachers (CoachEffects),
## your development department for the young, and the season plan. The same
## for a match's XP and a pre-season week's.
## `plan`: the club's fitness plan when the caller already has it ("" asks).
func _club_xp(club: String, p: Dictionary, base: int, staff: Dictionary, on_ground: bool, plan := "") -> int:
	var gain := base
	if not coaches.is_empty():
		gain = int(round(float(gain) * CoachEffects.xp_mult(staff, p, on_ground)))
	if club == my_club and float(p.get("age", 25.0)) <= ClubBudget.YOUNG_AGE:
		gain = int(round(float(gain) * ClubBudget.development_mult(
				department_budget_level("development"))))
	# A Father Figure's kids develop a little faster (row 119). From the staff
	# here, not the round's table: pre-season work runs off match day, where a
	# loaded career has no table yet and a straight one still has last
	# season's, so a reload trained its kids differently.
	if not coaches.is_empty() and float(p.get("age", 25.0)) <= Archetypes.KIDS_AGE:
		var kx := float(Archetypes.KIDS_XP.get(CoachEffects.philosophical(staff, club == my_club), 1.0))
		if kx != 1.0:
			gain = int(round(float(gain) * kx))
	var plan_xp := Conditioning.xp_mult(plan if plan != "" else fitness_plan(club), p)
	if plan_xp != 1.0:
		gain = int(round(float(gain) * plan_xp))
	# A patient club brings its young players on a touch quicker (Culture).
	if Culture.young_for_growth(p, season_year):
		var grow := culture_effect(club, "young_growth")
		if grow != 0.0:
			gain = int(round(float(gain) * (1.0 + grow)))
	return gain


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
## archetypes lean a player toward one job (and the traits that go with it).
## Manual (spend XP by hand) was cut 2026-11-03: old saves map to the
## closest plan (_closest_plan).
const TRAIN_PLANS := [
	{"key": "position", "label": "By position", "roles": []},
	{"key": "inside_mid", "label": "Inside midfielder", "roles": ["MID"],
			"text": "Wins the ball at stoppages and keeps it in the tackle.",
			"weights": {"contested": 3.0, "disposal": 1.0}},
	{"key": "outside_mid", "label": "Wing", "roles": ["MID"],
			"text": "Runs the wing: carries it from defence to attack and hits targets inside 50.",
			"weights": {"carry": 3.0, "disposal": 2.0, "creating": 1.0}},
	{"key": "key_def", "label": "Key defender", "roles": ["DEF"],
			"text": "Stops the opposition: spoils and marks inside 50, tackles hard.",
			"weights": {"intercept": 3.0, "pressure": 2.0}},
	{"key": "rebound_def", "label": "Small defender", "roles": ["DEF"],
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
]
# ---------------------------------------------------------------------------
# Learning another position (roadmap M5-003, director-selected RC-003)
# ---------------------------------------------------------------------------
## A bounded development project: for PROJECT_WEEKS fit weeks his training
## goes into another position's game instead of his own - his own rating
## grows more slowly, the price - then he either plays there well enough to be
## picked there or it has not taken. Built on the ordinary training plan: the
## same XP and season limit, no new currency, nothing guaranteed.
## Who may try (director, 2026-10-06): a plausible move only (his rating there
## within PROJECT_REACH of his own); the job follows his size - key forward,
## key defender and ruck take height, a small forward or small defender has
## to be small; POT 70+ for a second position and POT 90+ for a third (made
## rarer by the director, 2026-10-06, so Unicorns stay rare).
## Three positions across forward, midfield and back make him a Unicorn
## (Traits). One project per player a season, PROJECT_MAX a club at once.
## The price is explicit: from the day he starts, training in his own position
## can lift him only PROJECT_OWN_GAIN more that season (and a learned position
## gives LEARN_PAYBACK back the season after) (the new position's
## training can still help his own game where the two overlap).
## Rival clubs learn positions too, PROJECT_MAX at once as you may, by the
## same gates (_ai_projects).
const LEARN_PREFIX := "learn_"
const PROJECT_WEEKS := 8
const PROJECT_REACH := 6
## He earns the position when his rating there is within PROJECT_PASS of his
## own. Tightened from 3 to 1 (row 93, T8.Q15, director 2026-11-06: "Tighten
## pass margin"; reach and the price unchanged): at 3 about 92% of projects
## passed (tools/audit/passmargin_impl.gd).
const PROJECT_PASS := 1
const PROJECT_MAX := 2
const PROJECT_OWN_GAIN := 2
## A position learned pays back: the next season his training can lift his own
## rating LEARN_PAYBACK more than the usual limit, never past his POT
## (director, 2026-10-06: projects must matter).
const LEARN_PAYBACK := 1
const PROJECT_POT := {1: 70, 2: 90}      # positions he has -> POT to learn another
const MAX_POSITIONS := 3
const KEY_FWD_CM := 192.0
const SMALL_FWD_CM := 181.0
const KEY_DEF_CM := PlayerProfile.KEY_DEF_CM
const RUCK_CM := 196.0
## The jobs a player can learn, by line, with what each trains.
const LEARN_JOBS := {
	"mid": {"role": "MID", "word": "midfielder", "weights": {"contested": 3.0, "disposal": 1.0, "carry": 1.0}},
	"key_fwd": {"role": "FWD", "word": "key forward", "weights": {"marking": 3.0, "goalkicking": 3.0, "accuracy": 1.0}},
	"fwd": {"role": "FWD", "word": "forward", "weights": {"goalkicking": 3.0, "marking": 2.0, "accuracy": 1.0, "pressure": 1.0}},
	"small_fwd": {"role": "FWD", "word": "small forward", "weights": {"goalkicking": 3.0, "accuracy": 2.0, "carry": 1.0, "creating": 1.0}},
	"key_def": {"role": "DEF", "word": "key defender", "weights": {"intercept": 3.0, "pressure": 2.0}},
	"small_def": {"role": "DEF", "word": "small defender", "weights": {"pressure": 3.0, "carry": 2.0, "intercept": 1.0}},
	"ruck": {"role": "RUCK", "word": "ruck", "weights": {"ruck": 3.0, "contested": 1.0}},
}


## The job he is learning ("key_fwd"), or "".
func project_job(p: Dictionary) -> String:
	return str((p.get("project", {}) as Dictionary).get("job", ""))


## The position he is learning ("FWD"), or "".
func project_role(p: Dictionary) -> String:
	var job := project_job(p)
	return str((LEARN_JOBS.get(job, {}) as Dictionary).get("role", ""))


## His rating were he to play `role`, from his attributes (the scale his own
## rating is on).
func rating_as(p: Dictionary, role: String) -> int:
	return Ratings.rate_overall(p["attr"], role, Ratings.effective_games(p))


func active_projects() -> int:
	var n := 0
	for q in my_list:
		if project_job(q) != "":
			n += 1
	return n


## The job his size gives him in a line: tall players learn the key jobs, small
## ones the small jobs, the rest the line's general job. "" = not for him.
static func learn_job_for(p: Dictionary, role: String) -> String:
	var h := float(p.get("height_cm", 0.0))
	match role:
		"MID":
			return "mid"
		"FWD":
			if h >= KEY_FWD_CM:
				return "key_fwd"
			if h > 0.0 and h <= SMALL_FWD_CM:
				return "small_fwd"
			return "fwd"
		"DEF":
			return "key_def" if h >= KEY_DEF_CM else "small_def"
		"RUCK":
			return "ruck" if h >= RUCK_CM else ""
	return ""


## The POT he needs to learn one more position, or -1 when he has all he may.
static func learn_pot_needed(p: Dictionary) -> int:
	var have := Ratings.positions(p).size()
	if have >= MAX_POSITIONS:
		return -1
	return int(PROJECT_POT.get(have, 999))


## The jobs he could set out to learn now ([] while he is learning one, has
## tried this season, falls short of the POT, or the club runs PROJECT_MAX).
func learnable_jobs(p: Dictionary) -> Array:
	var out := []
	if active_projects() >= PROJECT_MAX:
		return out
	return _jobs_open(p)


## The positions he could learn, whatever the club is already running (the
## training report lists these; the Training menu offers them only while the
## club has a free project).
func open_jobs(p: Dictionary) -> Array:
	return _jobs_open(p)


## His own gates before any job is looked at: not learning one now, not done
## with one this season, ratings on record, and the POT for one more position.
func _may_project(p: Dictionary) -> bool:
	if project_job(p) != "" or bool(p.get("projected", false)) or (p.get("attr", {}) as Dictionary).is_empty():
		return false
	if int(p.get("project_year", 0)) == season_year:
		return false
	var need := learn_pot_needed(p)
	return need >= 0 and int(p.get("potential", p.get("overall", 0))) >= need


## The jobs open to him by his own gates (POT, size, how far the move is, one
## a season), whatever his club is already running.
func _jobs_open(p: Dictionary) -> Array:
	var out := []
	if not _may_project(p):
		return out
	var have := Ratings.positions(p)
	var own := int(p.get("overall", 0))
	for role in ["MID", "FWD", "DEF", "RUCK"]:
		if have.has(role):
			continue
		var job := learn_job_for(p, role)
		if job != "" and own - rating_as(p, role) <= PROJECT_REACH:
			out.append(job)
	return out


## "Week 3 of 8" while he learns, else "".
func project_progress(p: Dictionary) -> String:
	if project_job(p) == "":
		return ""
	return "Week %d of %d" % [int(p["project"].get("weeks", 0)), PROJECT_WEEKS]


func _start_project(p: Dictionary, job: String) -> void:
	var role := str(LEARN_JOBS[job]["role"])
	p["project_cap"] = mini(season_ceiling(p), int(p.get("overall", 0)) + PROJECT_OWN_GAIN)
	p["project"] = {"job": job, "weeks": 0, "year": season_year,
			"start_own": int(p.get("overall", 0)), "start_there": rating_as(p, role),
			"ceiling": rating_as(p, role) + SEASON_TRAIN_GAIN}
	p["project_year"] = season_year


## One week of his project (a week he is fit). At PROJECT_WEEKS he earns the
## position if his rating there is within PROJECT_PASS of his own, or it has
## not taken; either way he goes back to the club plan. {} or a result row.
func _project_week(p: Dictionary, announce := true) -> Dictionary:
	var job := project_job(p)
	if job == "" or int(p.get("injury_weeks", 0)) > 0:
		return {}
	var pr: Dictionary = p["project"]
	pr["weeks"] = int(pr.get("weeks", 0)) + 1
	if int(pr["weeks"]) < PROJECT_WEEKS:
		return {}
	return _finish_project(p, announce, season.round_name(maxi(0, season.round_index - 1)))


## The verdict on his project, at PROJECT_WEEKS or when the season ends first:
## learned if his rating there is within PROJECT_PASS of his own. The
## decision and its outcome are kept as a career fact (G7): `at` is when it
## was judged ("Round 12", or "Season end" when the season ended first).
func _finish_project(p: Dictionary, announce := true, at := "Season end") -> Dictionary:
	var job := project_job(p)
	var role := project_role(p)
	var own := int(p.get("overall", 0))
	var there := rating_as(p, role)
	var learned := there >= own - PROJECT_PASS
	if learned and Ratings.positions(p).has(role):
		pass   # a position he already has (a role trial that passed): trained, nothing new to add
	elif learned:
		p["learn_payback_year"] = season_year + 1
		if str(p.get("role2", "")) == "":
			p["role2"] = role
		else:
			var more: Array = p.get("learned", [])
			more.append(role)
			p["learned"] = more
	CareerFacts.add(career_facts, str(p.get("id", "")), CareerFacts.row(season_year, at, "project",
			str(p.get("club", "")), job, "learned" if learned else "not taken"))
	p.erase("project")
	p.erase("train_plan")
	if not announce:
		return {"id": str(p["id"]), "job": job, "learned": learned, "own": own, "there": there}
	var name := GameDB.player_display_name(p)
	var word := str(LEARN_JOBS[job]["word"])
	var a := "an" if word.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a"
	var talk := _dev_talk_for(p, job)
	var said := str(talk.get("said", ""))
	var told := season.round_name(int(talk.get("round", 1)) - 1) if season != null else "Round %d" % int(talk.get("round", 0))
	if said != "":
		_dev_talk_out(p, "learned" if learned else "not taken")
	if learned and said == "promise" and at != "Season end":
		# The games he was promised are owed now (_dev_promise_week starts them).
		talk["state"] = "owed"
		add_news("training", "%s has learned to play as %s %s. His three games there, as you told him in %s, start when he's next in the side." % [
				name, a, word, told])
	elif learned and said == "depth":
		add_news("training", "%s has learned to play as %s %s: cover for the side, as you told him in %s." % [name, a, word, told])
	elif learned:
		if said == "promise":
			talk["state"] = "owed"   # the season is over: open_offseason lapses it
		add_news("training", "%s has learned to play as %s %s: he can be picked there now." % [name, a, word])
	elif said == "promise":
		talk["state"] = "off"
		add_news("training", "%s's time training as %s %s has not taken, so the games there you talked about in %s are off. He knew it might not." % [
				name, a, word, told])
	else:
		add_news("training", "%s's time training as %s %s has not taken: he is not ready to be picked there." % [name, a, word])
	return {"id": str(p["id"]), "job": job, "learned": learned, "own": own, "there": there}


# ---------------------------------------------------------------------------
# Development talks (row T5.r93, RPG programme, ARD-M5-003; bible 5.9 #93):
# a player learning a position wants to know what it is for. The talk is a
# card in the week's one optional slot (data/stories/training.json,
# training_dev_talk), in the first DEV_TALK_WEEKS weeks of his project. Promise
# him games there if it takes, or tell him it is for depth; the verdict's news
# line remembers which, and a promise becomes his next DEV_PROMISE_GAMES games
# in the new position (a role trial), kept, broken or lapsed by what happens.
# p["dev_talk"] = {"year", "round", "job", "role", "said": "promise"|"depth",
#   "state": "heard" | "owed" | "on" | "kept" | "broken" | "off" | "lapsed"}
# ---------------------------------------------------------------------------
const DEV_TALK_WEEKS := 4
const DEV_PROMISE_GAMES := 3
## What leaving him out of the promised games costs: a promised game's sting.
const DEV_PROMISE_STING := 12
## How often a project takes from how far off he is in its early weeks: the
## share that learned the position, by the gap (his own rating minus his rating
## there) at the end of his week 1 to 4 (tools/audit/taketalk_impl.gd, 12 seeds
## of 3 seasons, every club's projects). TAKE_PCT[week - 1][gap] is the percent
## that learned it; a gap under 0 counts as 0 and one over TAKE_GAP_MAX as it.
const TAKE_GAP_MAX := 5
const TAKE_PCT := [
	[100, 100, 85, 67, 27, 0],
	[100, 100, 79, 45, 4, 0],
	[100, 100, 77, 22, 1, 0],
	[100, 100, 69, 6, 0, 0],
]


## His talk about the project he is on (or just finished), {} if none.
func _dev_talk_for(p: Dictionary, job: String) -> Dictionary:
	var t = p.get("dev_talk", {})
	if t is Dictionary and int(t.get("year", 0)) == season_year and str(t.get("job", "")) == job:
		return t
	return {}


## Is a talk about his project due? He is learning a position he does not
## have, in the first DEV_TALK_WEEKS weeks, and you have not talked about it.
func dev_talk_due(p: Dictionary) -> bool:
	var job := project_job(p)
	if job == "" or not _dev_talk_for(p, job).is_empty():
		return false
	if Ratings.positions(p).has(project_role(p)):
		return false
	var w := int((p["project"] as Dictionary).get("weeks", 0))
	return w >= 1 and w <= DEV_TALK_WEEKS


## "about 6 in 10": how often projects this far off at this stage take.
func take_odds(p: Dictionary) -> String:
	var role := project_role(p)
	if role == "":
		return ""
	var w := clampi(int((p["project"] as Dictionary).get("weeks", 1)), 1, DEV_TALK_WEEKS)
	var gap := clampi(int(p.get("overall", 0)) - rating_as(p, role), 0, TAKE_GAP_MAX)
	return odds_in_ten(int(TAKE_PCT[w - 1][gap]))


## A percent as the cards say odds: "about 6 in 10"; the ends stay true
## ("fewer than 1 in 10", "more than 9 in 10").
static func odds_in_ten(pct: int) -> String:
	var n := int(round(pct / 10.0))
	if n <= 0:
		return "fewer than 1 in 10"
	if n >= 10:
		return "more than 9 in 10"
	return "about %d in 10" % n


## The talk is had (a card's choice): `said` "promise" or "depth". Kept on him
## and as a career fact (G7, kind "talk", d "project|said"); the fact's out
## is "heard" until the project's verdict, so the selection talks' settling
## (_after_match_talks) never reads it.
func dev_talk(p: Dictionary, said: String) -> void:
	var job := project_job(p)
	if job == "" or season == null:
		return
	var round_no := season.round_index + 1
	p["dev_talk"] = {"year": season_year, "round": round_no, "job": job, "role": project_role(p),
			"said": said, "state": "heard"}
	CareerFacts.add(career_facts, str(p["id"]), CareerFacts.row(season_year, season.round_name(round_no - 1), "talk",
			my_club, "project|" + said, "heard"))
	mark_dirty()


## Settle his project talk's career fact: "learned", "not taken", then "kept",
## "broken" or "lapsed" for a promise.
func _dev_talk_out(p: Dictionary, out: String) -> void:
	var rows = career_facts.get(str(p["id"]), [])
	if not (rows is Array):
		return
	for i in range((rows as Array).size() - 1, -1, -1):
		var r: Array = rows[i]
		if str(r[CareerFacts.K]) == "talk" and str(r[CareerFacts.D]).begins_with("project|") \
				and int(r[CareerFacts.Y]) == season_year:
			r[CareerFacts.OUT] = out
			return


## The promise owed or under way, {} if none.
static func _dev_owed(p: Dictionary) -> Dictionary:
	var t = p.get("dev_talk", {})
	if t is Dictionary and str(t.get("said", "")) == "promise" and str(t.get("state", "")) in ["owed", "on"]:
		return t
	return {}


## Each week: a fit player owed his games expects to play (Auto-pick names
## him), and once he is in the side his games in the new position start (a role
## trial of DEV_PROMISE_GAMES, marked as promised).
func _dev_promise_week() -> void:
	if season == null:
		return
	for p in my_list:
		var t := _dev_owed(p)
		# Injured, suspended or rested he cannot play: naming him would only push
		# a fit man out, and his games wait.
		if t.is_empty() or not Ratings.available(p):
			continue
		# A side you named takes him in, as Auto-pick does, so his games can start.
		var named := not my_selection().is_empty()
		var was_in := in_current_side(p)
		var made_way := name_promised(p)
		p["expects_game"] = DEV_PROMISE_STING
		if named and not was_in:
			var who := GameDB.player_display_name(p)
			if in_current_side(p):
				add_news("club", "%s is in the side this week for his promised games%s." % [who,
						(", in place of %s" % made_way) if made_way != "" else ""])
			else:
				add_news("club", "%s is owed his promised games, but %s" % [who, NO_ROOM_WORDS.substr(0, 1).to_lower() + NO_ROOM_WORDS.substr(1)])
		# His promised games were under way and the trial is gone (another
		# trial took its place): they are owed again, and start once it is free.
		if str(t["state"]) == "on" and (str(role_trial.get("id", "")) != str(p["id"]) or not role_trial.has("promised")):
			t["state"] = "owed"
		if str(t["state"]) == "owed" and role_trial.is_empty():
			# Already picked in that line or not, the promised games are counted.
			var said := start_role_trial(p, DEV_PROMISE_GAMES, str(t.get("role", "")), true)
			if said != "":
				role_trial["promised"] = int(t.get("round", 0))
				t["state"] = "on"
				add_news("training", said)


## After your match: a fit player owed his games who did not play was left out
## of them. The promise breaks (its sting is the promised game's, paid by the
## expects_game settling that follows).
func _dev_promise_after_match(played: Dictionary, no_room := {}) -> void:
	for p in my_list:
		var t := _dev_owed(p)
		var pid := str(p["id"])
		if t.is_empty() or played.has(pid) or no_room.has(pid) or int(p.get("injury_weeks", 0)) > 0 \
				or _round_unavailable.has(pid):
			continue
		_dev_promise_broken(p, t, false)


func _dev_promise_broken(p: Dictionary, t: Dictionary, sting: bool) -> void:
	t["state"] = "broken"
	_dev_talk_out(p, "broken")
	if not role_trial.is_empty() and str(role_trial.get("id", "")) == str(p["id"]):
		_end_role_trial(true)
	var word := str((LEARN_JOBS.get(str(t.get("job", "")), {}) as Dictionary).get("word", "new position"))
	var a := "an" if word.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a"
	add_news("club", "%s was promised three games as %s %s and was left out of them. He took it hard." % [
			GameDB.player_display_name(p), a, word])
	if sting:
		p.erase("expects_game")
		ClubLife.add_morale(p, -DEV_PROMISE_STING)
		Trust.change(relations, Trust.player_key(str(p["id"])), ClubStories.BROKEN_PROMISE_TRUST,
				"You promised him games in his new position and left him out", season_year, last_label)
		_culture_move(my_club, "together", -StoryEngine.BROKEN_TOGETHER, "You promised a player games and left him out")


## The season is over before his promised games: the promise lapses, no sting.
func _dev_promises_lapse() -> void:
	for p in my_list:
		var t := _dev_owed(p)
		if t.is_empty():
			continue
		t["state"] = "lapsed"
		_dev_talk_out(p, "lapsed")
		p.erase("expects_game")
		var word := str((LEARN_JOBS.get(str(t.get("job", "")), {}) as Dictionary).get("word", "new position"))
		add_news("training", "The season ended before %s's games as a %s, so that promise lapses." % [
				GameDB.player_display_name(p), word])


## A rival club's projects for one game: it runs up to PROJECT_MAX at once,
## as you may. Each one goes where it helps the club most: the job in its
## thinnest position (players there per place in the side, FILL_SHARE), for a
## player who gives up nothing for it - his season ceiling is within
## AI_PROJECT_ROOM of his rating, so the cap a project puts on his own
## training costs him nothing (director 2026-11-03). Its learners' weeks count
## as yours do. No news.
func _ai_projects(list: Array) -> void:
	var running := 0
	for p in list:
		if project_job(p) != "":
			running += 1
	while running < PROJECT_MAX:
		var pick := _ai_project_choice(list)
		if pick.is_empty():
			break
		_start_project(pick["player"], str(pick["job"]))
		running += 1
	for p in list:
		_project_week(p, false)


## A player gives up nothing to a project when his season ceiling is at most
## this far above his rating.
const AI_PROJECT_ROOM := 2


## The (player, job) a rival club's next project goes to, {"player", "job"},
## or {}: the job in its thinnest position, then the player closest to his
## own rating there, then by id.
func _ai_project_choice(list: Array) -> Dictionary:
	var counts := {}
	for q in list:
		for r in Ratings.positions(q):
			counts[r] = int(counts.get(r, 0)) + 1
	for q in list:
		if project_job(q) != "":
			var r := project_role(q)
			counts[r] = int(counts.get(r, 0)) + 1   # a learner already on the way
	var best := {}
	var best_key := []
	for p in list:
		# The cheap gates first: most players can't start a project at all.
		if not _may_project(p):
			continue
		# season_ceiling notes his start-of-season rating when it is missing; ask
		# a copy only then, so the check leaves him as it found him.
		var ceiling := season_ceiling(p if p.has("season_start_ov") else p.duplicate())
		if ceiling - int(p.get("overall", 0)) > AI_PROJECT_ROOM:
			continue
		for j in _jobs_open(p):
			var role := str(LEARN_JOBS[j]["role"])
			if not FILL_SHARE.has(role):
				continue
			var thin := float(counts.get(role, 0)) / float(FILL_SHARE[role])
			var gap := int(p.get("overall", 0)) - rating_as(p, role)
			var key := [thin, gap, str(p["id"]), str(j)]
			if best.is_empty() or _key_less(key, best_key):
				best = {"player": p, "job": str(j)}
				best_key = key
	return best


static func _key_less(a: Array, b: Array) -> bool:
	for i in range(a.size()):
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


func _advance_projects() -> Array:
	var out := []
	for p in my_list:
		var r := _project_week(p)
		if not r.is_empty():
			out.append(r)
	if not out.is_empty():
		mark_dirty()
	return out


## What the Position plan means for each role.
const POSITION_PLAN_TEXT := {
	"MID": "Mostly contested ball, with disposal and carry - what wins a midfielder's games.",
	"DEF": "Intercept and pressure first, then carry - what stops the opposition.",
	"FWD": "Goalkicking and marking first, then carry and accuracy - what puts a score on the board.",
	"RUCK": "Wins the tap, then the ball at the stoppage - a ruck's job in a match.",
}
## The plan for anyone without his own: Position plan (always).
var default_train_plan := "position"


## "11 players kept developing in the reserves." for the last game (no XP: the
## director, 2026-10-14), or "" when nobody was in the reserves.
func reserves_summary_line() -> String:
	var n := int(last_training_report.get("reserves_count", 0))
	if n <= 0:
		return ""
	return "%d %s developing in the reserves." % [n, "player kept" if n == 1 else "players kept"]


## What the last game's training changed, in one line: "Training: 3 players
## rose in OVR. Jones unlocked Sharpshooter." - or "" when nothing visible
## changed. Stat points alone are not news. Who rose, and from what to what, is
## `training_rise_lines` (director, 2026-10-19: name every one, no "N more").
func training_summary_line() -> String:
	var auto: Dictionary = last_training_report.get("auto", {})
	var rises: Array = auto.get("rises", [])
	var traits: Array = auto.get("traits", [])
	var at_pot: Array = auto.get("at_pot", [])
	if rises.is_empty() and traits.is_empty():
		return ""
	var bits: PackedStringArray = []
	if not rises.is_empty():
		bits.append("%d %s in OVR." % [rises.size(), "player rose" if rises.size() == 1 else "players rose"])
	for t in traits:
		bits.append("%s unlocked %s." % [_short_name(str(t[0])), Traits.label(str(t[1]))])
	if at_pot.size() == 1:
		bits.append("%s reached his potential." % _short_name(str(at_pot[0])))
	elif at_pot.size() > 1:
		bits.append("%d players reached their potential." % at_pot.size())
	return "Training: " + " ".join(bits)


## Every player the last game's training lifted, one entry each, "Jack Steele
## 76 to 77", biggest rise first then by name.
func training_rise_lines() -> PackedStringArray:
	var rises: Array = (last_training_report.get("auto", {}) as Dictionary).get("rises", [])
	var rows: Array = []
	for r in rises:
		rows.append([_short_name(str(r[0])), int(r[1]), int(r[2])])
	rows.sort_custom(func(x, y):
		var dx: int = int(x[2]) - int(x[1])
		var dy: int = int(y[2]) - int(y[1])
		return dx > dy if dx != dy else str(x[0]) < str(y[0]))
	var out: PackedStringArray = []
	for row in rows:
		out.append("%s %d to %d" % [row[0], row[1], row[2]])
	return out


func _short_name(id: String) -> String:
	var p := list_player(id)
	return GameDB.player_display_name(p) if not p.is_empty() else "A player"


# ---------------------------------------------------------------------------
# Injuries
# ---------------------------------------------------------------------------
## Everything that follows a round: injuries, the awards tally, and - when
## the Grand Final has just been played - the season's awards.
func _after_round(results: Array) -> void:
	_note_plans_played(results)
	_note_rival_plans(results)
	_note_coach_arch(results)
	MidseasonDraft.after_round(self)
	ScoutingList.week(self)
	# Who on a promised run could not play this week, before anything ticks.
	_backing_unavailable = {}
	for p in my_list:
		if Backing.is_active(p) and not Backing.fit(p):
			_backing_unavailable[str(p["id"])] = true
	_round_unavailable = {}
	for arr in ([my_list] + (season.lists.values() if season != null else [])):
		for p in arr:
			if not Backing.fit(p):
				_round_unavailable[str(p["id"])] = true
	if season != null:
		var regular := last_phase == "regular"
		var week := "%d|%s|%d" % [season_year, "R" if regular else "F",
				season.round_index if regular else (season.finals.get("weeks", []) as Array).size()]
		var recovery_mults := {}
		for code in season.lists:
			recovery_mults[code] = 1.0 + culture_effect(str(code), "recovery")
		if my_club != "":
			recovery_mults[my_club] = float(recovery_mults.get(my_club, 1.0)) * ClubBudget.recovery_mult(
					department_budget_level("high_performance"))
		Workload.advance_week(season.lists, results, week, recovery_mults)
	_process_injuries(results)
	_process_discipline(results)
	_count_finals(results)
	var counted := AwardsCount.snapshot(season_tally, results)
	for res in results:
		Awards.tally_match(season_tally, res, not res.has("tag"))
		StatBook.add_match(season_stats, res)
		_note_form_and_team(res)
	_record_award_counts(counted, results)
	Milestones.record_round(self, results)
	_nominate_rising_star(results)
	_round_news(results)
	_record_match_story(results)
	Almanac.update_club_records(self, results)
	_note_firsts(results)
	_note_career_highs(results)
	OwnProspect.check(self)
	_draft_class_news()
	_board_after_round(results)
	_rival_morale_after_round(results)
	_familiarity_after_round(results)
	_fade_press_lifts()
	_prepare_media_conference(results)
	# One optional ask a week (director, 2026-10-09, G1): a sit-down takes the
	# week's slot and the press question waits for another week.
	if not backing_talk.is_empty():
		media_conference = {}
	if season != null and season.is_season_over() \
			and int(season_awards.get("year", 0)) != season_year:
		_close_season_awards()
	# A career the medical panel ended this week ends here, once the round is
	# counted (in the Grand Final week the season's close has already settled
	# it, before the off-season opens).
	_settle_medical()
	_captaincy_week()
	_culture_week(results)
	_next_week_event()
	_find_coach_approaches()
	if Milestones.shown():
		Milestones.preview_news(self)


## Each player who took the field in a final has played one more final in this
## save (p["finals_games"]), at any club: what "his first final" reads.
func _count_finals(results: Array) -> void:
	if season == null:
		return
	for res in results:
		if not (res is Dictionary) or not (res as Dictionary).has("tag"):
			continue
		var roster: Array = res.get("roster", [])
		for side in range(mini(2, roster.size())):
			var code := str(res["home"] if side == 0 else res["away"])
			var by_id := {}
			for q in season.lists.get(code, []):
				by_id[str(q["id"])] = q
			for r in roster[side]:
				var q = by_id.get(str(r["id"]))
				if q != null:
					q["finals_games"] = int(q.get("finals_games", 0)) + 1


## True when every senior game he has played is one this save has seen: a career
## on record in full, begun in this game (or since the finals count began).
## Only then can "his first final" be said as a fact.
func save_saw_every_game(p: Dictionary) -> bool:
	if not Career.complete(p):
		return false
	var from := maxi(Career.BEFORE_GAME + 1, finals_counted_since)
	for st in (Career.of(p).get("stints", []) as Array):
		if int((st as Array)[1]) < from:
			return false
	return true


## Was this story flag set on the player (or "club") this season?
func story_flag_set(holder: String, flag: String) -> bool:
	var at := int(((story.get("flags", {}) as Dictionary).get(holder, {}) as Dictionary).get(flag, StoryEngine.NEVER))
	return at >= StoryEngine.week_abs(season_year, 1)


## The round's votes for the awards-night count (AwardsCount.gd): the change
## in the season tally across this round's matches, `before` its snapshot.
func _record_award_counts(before: Dictionary, results: Array) -> void:
	if season == null or results.is_empty():
		return
	if int(award_counts.get("year", 0)) != season_year or str(award_counts.get("club", "")) != my_club:
		# Kept for another season or club (an older save): start again from here.
		award_counts = AwardsCount.fresh(season_year, my_club,
				int((results[0] as Dictionary).get("round", 1)) if results[0] is Dictionary else 1)
	var order: Array = []
	var rnd := int((results[0] as Dictionary).get("round", 0)) - 1 if results[0] is Dictionary else -1
	if not (results[0] as Dictionary).has("tag") and rnd >= 0 and rnd < season.fixture.size():
		order = season.fixture[rnd]
	AwardsCount.record_round(award_counts, before, season_tally, results, my_club, order)


## A home-and-away round's Rising Star nomination (Awards.rising_star_nominee).
func _nominate_rising_star(results: Array) -> void:
	if season == null or last_phase != "regular":
		return
	var rnd := season.round_index
	var nominated := {}
	for n in rising_star_noms.get("rounds", []):
		nominated[str(n["id"])] = true
		if int(n["round"]) == rnd:
			return  # already named this round
	if rnd < int(rising_star_noms.get("from", 1)):
		return
	var ages := {}
	for code in season.lists:
		for p in season.lists[code]:
			ages[str(p["id"])] = float(p.get("age", 30.0))
	var pick := Awards.rising_star_nominee(results, ages, nominated)
	if pick.is_empty():
		return
	pick["round"] = rnd
	if not rising_star_noms.has("rounds"):
		rising_star_noms["rounds"] = []
	(rising_star_noms["rounds"] as Array).append(pick)


func _close_season_awards() -> void:
	var players := {}
	for code in season.lists:
		for p in season.lists[code]:
			players[str(p["id"])] = p
	# Before the off-season releases anyone, so a delisted player keeps it.
	Career.close_season(players, season_tally, season_year, season_stats, season_stats_from)
	# Your staff as the season ended, for the season wrap; the off-season
	# itself opens at the close's end (below).
	offseason_staff = Coaches.staff(coaches, my_club) if not coaches.is_empty() else {}
	season_awards = Awards.season_awards(season_tally, players, season_year, rising_star_noms)
	var medal := Awards.norm_smith(_grand_final_result())
	# Premiership-year tattoos (row 73): cosmetic, on the players, no match RNG.
	PremiershipInk.record_grand_final(_grand_final_result(), premier(), players, season_year)
	if not medal.is_empty():
		season_awards["norm_smith"] = medal
	# The Golden Fist (T5.Q11c), from the season's book. A book begun part way
	# through (an older save) asks for games in proportion to the rounds it saw.
	var fist := Awards.golden_fist(season_stats, players, Awards.aa_min_games(
			maxi(1, season.regular_rounds() - season_stats_from), season.regular_rounds()) if season_stats_from > 0 else Awards.AA_MIN_GAMES)
	if not fist.is_empty():
		season_awards["golden_fist"] = fist
	records = Awards.update_records(records, season_awards, season_log)
	var mine_bf: Array = (season_awards["best_and_fairest"] as Dictionary).get(my_club, [])
	Almanac.count_honours(self, players)
	honour_roll.append({
		"year": season_year,
		"premier": premier(),
		"runner_up": str(season.finals.get("runner_up", "")),
		# The men who played in the premiership side, for the club's page
		# across generations (PremiershipSide, row T5.r158). Absent in a season
		# closed before it was kept: never back-filled.
		"premier_side": PremiershipInk.premiership_ids(_grand_final_result(), premier()),
		"brownlow": [season_awards["brownlow_winner"]] if not (season_awards.get("brownlow_winner", {}) as Dictionary).is_empty() else [],
		"coleman": (season_awards["coleman"] as Array).slice(0, 1),
		"rising_star": (season_awards["rising_star"] as Array).slice(0, 1),
		"coaches_award": (season_awards["coaches_award"] as Array).slice(0, 1),
		# Absent in a season played before the medal existed: never back-filled.
		"norm_smith": [season_awards["norm_smith"]] if season_awards.has("norm_smith") else [],
		# Absent in a season played before the Golden Fist existed: never back-filled.
		"golden_fist": (season_awards.get("golden_fist", []) as Array).slice(0, 1),
		"my_bf": mine_bf.slice(0, 1),
		"my_club": my_club,
		"my_position": my_position(),
		# Your season for the trophy room (the club page): the home-and-away
		# record, the last final you played ("" for no finals; its tag, e.g.
		# "PF1") and your All-Australians. Older entries lack these keys.
		"my_record": my_record(),
		"my_finals": _my_last_final(),
		"my_aa": _my_all_australians(),
	})
	# The season hero (director, 2026-11-03): a named club award on the honour
	# roll, the most match-hero awards (match story digest) this season.
	var sh := Almanac.season_hero(self)
	if not sh.is_empty():
		honour_roll[-1]["season_hero"] = [sh]
	# The coach's ledger (P-39): which of this season's honoured players you
	# drafted, kept now so the ledger still has them after they leave the game.
	honour_roll[-1]["my_drafted"] = CoachLedger.snapshot(honour_roll[-1], _any_player, honour_roll,
			my_club, season_year, my_first_season, start_mode)
	# Your club annual starts with your first season: the years played
	# without you (sim_ahead) are on the honour roll, not in your annual.
	if my_club != "":
		var page := Almanac.season_entry(self)
		Challenge.mark_season(self, page)   # your own goal, the season it is met
		almanac.append(page)
		# The honour board (row 122): every player of yours, read afresh from the
		# season just closed, and anyone who has gone since the last close.
		for p in my_list:
			HonourBoard.upsert(self, p)
		HonourBoard.sweep(self)
		var first := Almanac.first_sentence(str(almanac[-1].get(Almanac.STORY_KEY, "")))
		if first != "":
			add_news("almanac_story", first)
	# A career the medical panel ended in the Grand Final week ends now: his
	# season is counted and honoured above, and the off-season below (a coach's
	# move, re-signings, delistings, free agency) must not find him on a list.
	_settle_medical()
	# Achievements first, then the season news, so the premiership line
	# stays the newest item in the feed.
	_close_season_achievements()
	_board_season_end()
	_coaching_offseason()
	# Coach arcs: a sacked or poached coach changes clubs (ClubMoves).
	ClubMoves.season_close(self)
	# The off-season opens at his club. A rival board's letter waiting for
	# his answer holds it: it opens once he answers, at whichever club he is
	# then at (ClubMoves.accept_letter / decline_letter).
	open_offseason(true)
	# Its opening moved rival lists: a sacked coach's offers say them as they stand.
	ClubMoves.restate_offers(self)
	_season_news()


## This season's Grand Final result, or {} before it is played.
func _grand_final_result() -> Dictionary:
	if season == null:
		return {}
	for week in season.finals.get("weeks", []):
		for res in week:
			if str(res.get("tag", "")) == "GF":
				return res
	return {}


## The Norm Smith Medal for a Grand Final result, for the screens that show it
## straight after the siren: {} for any other match, else {name, club, line,
## text}. `text` is the plain-words line the news uses.
func norm_smith_for(res: Dictionary) -> Dictionary:
	if str(res.get("tag", "")) != "GF":
		return {}
	var m := Awards.norm_smith(res)
	if m.is_empty():
		return {}
	var who := award_name(m)
	var out: Dictionary = m.duplicate()
	out["name"] = who
	out["text"] = "Norm Smith Medal: %s (%s), %s" % [who, GameDB.club_name(str(m["club"])), str(m["line"])]
	return out


## The seasons a player won the Norm Smith Medal in this save, oldest first.
func norm_smith_years(player_id: String) -> Array:
	var out := []
	for e in honour_roll:
		var rows: Array = (e as Dictionary).get("norm_smith", [])
		if not rows.is_empty() and str((rows[0] as Dictionary).get("id", "")) == player_id:
			out.append(int((e as Dictionary).get("year", 0)))
	return out


## The tag of the last final your club played this season ("" if none).
func _my_last_final() -> String:
	var tag := ""
	for week in season.finals.get("weeks", []):
		for res in week:
			if is_my_match(res):
				tag = str(res.get("tag", ""))
	return tag


## The ids of your club's players in this season's All-Australian team.
func _my_all_australians() -> Array:
	var out := []
	for r in season_awards.get("all_australian", []):
		if str(r.get("club", "")) == my_club:
			out.append(str(r["id"]))
	return out


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
	for code in GameDB.club_order:
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
		add_news("achievement", "Achievement unlocked: %s - %s (%s)" % [
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


## Browser builds have no threads: the round's other matches play one per
## frame while yours is on screen (see Season.pump).
func _process(_delta: float) -> void:
	if not _others.is_empty() and _others.has("todo"):
		Season.pump(_others)


## After a round: every club that played is a week closer to getting its
## injured back, then this round's new injuries (from the matches) go on.
func _process_injuries(results: Array) -> void:
	if season == null:
		return
	last_injuries = []
	last_medical = []
	for res in results:
		for side in ["home", "away"]:
			var code := str(res.get(side, ""))
			if season.lists.has(code):
				Injuries.tick(season.lists[code])
	for res in results:
		var rows := Injuries.apply_match(res, season.lists, season.seed,
				int(res.get("round", season.round_index)))
		last_injuries += rows
		_log_injuries(rows, str(res.get("label", "")), false)
	# A player the panel did not clear is not one of the week's injured: his
	# news is the panel's.
	last_injuries = _not_medically_out(last_injuries)


## Each new injury is a career fact (CareerFacts): the season, the match,
## his club and what it was, so later decisions can cite his real history -
## only what this career saw.
func _log_injuries(rows: Array, label: String, settle := true) -> void:
	for r in rows:
		CareerFacts.add(career_facts, str(r["id"]),
				CareerFacts.row(season_year, label, "injury", str(r["club"]), "", str(r.get("kind", ""))))
		if str(r.get("kind", "")) == "concussion":
			_medical_panel(str(r["id"]), str(r["club"]), label)
	if settle:
		_settle_medical()


## His concussions in this season and the four before (MedicalPanel.count).
func concussions_in_window(p: Dictionary) -> int:
	return MedicalPanel.count(career_facts, str(p.get("id", "")), season_year)


## A concussion has just gone on his record. With five or more in five years
## the medical panel sits that week (director, 2026-11-11): one roll of its own
## at the flat MedicalPanel.CLEAR_CHANCE, the same for every club's player.
func _medical_panel(id: String, club: String, at: String) -> void:
	var n := MedicalPanel.count(career_facts, id, season_year)
	if not MedicalPanel.sits(n) or season == null:
		return
	var p := {}
	for q in season.lists.get(club, []):
		if str(q.get("id", "")) == id:
			p = q
	if p.is_empty():
		return
	var ok := MedicalPanel.cleared(career_seed, id, season_year, MedicalPanel.count_ever(career_facts, id))
	var row := {"id": id, "club": club, "name": GameDB.player_display_name(p),
			"overall": int(p.get("overall", 0)), "count": n, "cleared": ok, "pct": MedicalPanel.clear_pct(),
			"year": season_year, "at": at}
	last_medical.append(row)
	if not ok:
		_medical_out.append([club, p])
	if club == my_club:
		add_news("medical", MedicalPanel.result_line(row), "", {"club": club, "name": row["name"], "cleared": ok})
	elif not ok or int(row["overall"]) >= NEWS_MIN_OVR:
		add_news("medical", MedicalPanel.league_line(row, GameDB.club_name(club)), "", {"club": club, "name": row["name"], "cleared": ok})
	mark_dirty()


## The ids of the players the panel has not cleared this week, who are still
## on their lists until _settle_medical.
func _medically_out_ids() -> Dictionary:
	var gone := {}
	for pair in _medical_out:
		gone[str((pair[1] as Dictionary).get("id", ""))] = true
	return gone


## The injury rows without anyone the panel has just retired.
func _not_medically_out(rows: Array) -> Array:
	if _medical_out.is_empty():
		return rows
	var gone := _medically_out_ids()
	return rows.filter(func(r): return not gone.has(str(r.get("id", ""))))


func _settle_medical() -> void:
	var out := _medical_out
	_medical_out = []
	for pair in out:
		_medical_retire(str(pair[0]), pair[1])


## The panel did not clear him: his career ends this week, mid-season. He comes
## off his club's list (the spot stays empty until the club next adds a player:
## the mid-season rookie draft, or the off-season), his contract ends with him
## as a retiring player's does (nothing is left on the cap), and the career-over
## path does the rest (the honour board, his name for the record books, a
## coaching future). His part-season goes on his career record first, as the
## season's close does for everyone still listed, so what is kept of him has
## it; and he is remembered as one of this season's retirees (medical_retired).
## The retirement cannot be refused, so a club on the minimum list goes one
## under it (Contracts.evaluate_trade lets it keep trading at that size).
func _medical_retire(club: String, p: Dictionary) -> void:
	var id := str(p.get("id", ""))
	Career.close_season({id: p}, season_tally, season_year, season_stats, season_stats_from)
	medical_retired.append({"id": id, "club": club, "name": GameDB.player_display_name(p),
			"age": float(p.get("age", 0.0)), "overall": int(p.get("overall", 0)), "year": season_year, "player": p})
	if season != null and season.lists.has(club):
		(season.lists[club] as Array).erase(p)
	if league_lists.has(club):
		(league_lists[club] as Array).erase(p)
	if club == my_club:
		my_list.erase(p)
		if str(role_trial.get("id", "")) == str(p.get("id", "")):
			_end_role_trial(false)
	p.erase("injury_weeks")
	p.erase("injury_kind")
	p["contract_years"] = 0
	_career_over(p, "medical")
	mark_dirty()


## The medical panel's sittings on your players in the week just played, as
## short lines for the week's injuries: "Name was cleared to keep playing once
## he recovers (a 50% chance)." last_medical holds that week's sittings and nothing older
## (emptied before each round's injuries and at the rollover), so nothing is
## matched on a round's name: a home-and-away round, a final played or
## simulated and the practice match all show theirs.
func my_medical_lines() -> Array:
	return my_medical_rows().map(func(r): return str(r["text"]))


## The same, each with whether he was cleared ({"text", "cleared"}): a cleared
## player is good news and is not drawn in the injury red.
func my_medical_rows() -> Array:
	var out := []
	for row in last_medical:
		if str(row.get("club", "")) == my_club:
			out.append({"text": MedicalPanel.result_short(row), "cleared": bool(row.get("cleared", false))})
	return out


## A save from before career facts kept injuries on the player as bare years
## (p["injury_log"]). They move to the fact store once, nothing invented, and
## the old key goes. Every player the save holds is visited. A player can sit
## in two lists as the same dict or, with an unlinked list, as two copies: his
## years move the first time his id is met, and any other copy just drops them.
func _migrate_injury_logs() -> void:
	var all: Array = [my_list, free_agents]
	if season != null:
		for code in season.lists:
			all.append(season.lists[code])
	for code in league_lists:
		all.append(league_lists[code])
	var moved := {}
	for arr in all:
		for p in arr:
			if not (p is Dictionary) or not (p as Dictionary).has("injury_log"):
				continue
			var id := str(p.get("id", ""))
			if moved.has(id):
				(p as Dictionary).erase("injury_log")
				continue
			moved[id] = true
			CareerFacts.migrate_injury_log(career_facts, p)


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
			var code: String = str(codes[side])
			item["club"] = code
			item["case_id"] = "%d|%s|%s|%d|%d|%d" % [season_year, code,
					str(item.get("id", "")), int(item.get("q", 0)), int(item.get("min", 0)),
					last_mro.size()]
			last_mro.append(item)
			if not season.lists.has(code):
				continue
			for p in season.lists[code]:
				if str(p.get("id", "")) != str(item.get("id", "")):
					continue
				# User rule: any MRO sanction makes him Brownlow-ineligible.
				# Votes continue to accrue; Awards only checks this at winner time.
				if str(item.get("outcome", "")) != "no_action":
					var cases: Array = p.get("brownlow_ineligible_cases", []).duplicate()
					var case_id := str(item.get("case_id", ""))
					if case_id != "" and not cases.has(case_id):
						cases.append(case_id)
					p["brownlow_ineligible_cases"] = cases
					p["brownlow_ineligible"] = not cases.is_empty()
				if str(item.get("outcome", "")) == "suspension":
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
		if str(row.get("challenge_result", "")) == "overturned":
			out.append("%s cleared at the Tribunal" % name)
			continue
		if str(row.get("appeal_result", "")) == "overturned":
			out.append("%s cleared at the Appeals Board" % name)
			continue
		match str(row.get("outcome", "")):
			"suspension":
				var w := int(row.get("weeks", 0))
				var suffix := ""
				if str(row.get("appeal_result", "")) == "upheld":
					suffix = " — appeal failed"
				elif str(row.get("challenge_result", "")) == "upheld":
					suffix = " — Tribunal upheld"
				out.append("%s suspended for %d match%s%s" % [name, w, "" if w == 1 else "es", suffix])
			"fine":
				out.append("%s fined for %s%s" % [name, str(row.get("reason", "rough conduct")),
						" — challenge failed" if str(row.get("challenge_result", "")) == "upheld" else ""])
	return out


## User-club sanctions from the round that can still be challenged before the
## next match. The case strength describes the charge, not the hidden verdict.
func pending_mro_challenges() -> Array:
	var out := []
	for row in last_mro:
		if str(row.get("club", "")) != my_club or str(row.get("outcome", "")) == "no_action":
			continue
		var copy: Dictionary = (row as Dictionary).duplicate(true)
		if not bool(row.get("challenged", false)):
			copy["stage"] = "tribunal"
			copy["case"] = tribunal_case(row)
			out.append(copy)
		elif str(row.get("challenge_result", "")) == "upheld" \
				and str(row.get("outcome", "")) == "suspension" \
				and not bool(row.get("appealed", false)):
			copy["stage"] = "appeal"
			copy["case"] = appeal_case(row)
			out.append(copy)
	return out


## What a failed Tribunal challenge or appeal costs: the board's confidence
## (0-100) drops this much (director, 2026-11-10, row T1.R26 C1).
const TRIBUNAL_BOARD_COST := 5


## The two lines under a Tribunal or Appeals Board case: what winning gives and
## what losing costs, with the real odds (row T1.R26 C1).
static func tribunal_gate(row: Dictionary) -> Array:
	var appeal := str(row.get("stage", "tribunal")) == "appeal"
	var pct := int(round(100.0 * (appeal_chance(row) if appeal else tribunal_chance(row))))
	var cleared := "no fine" if str(row.get("outcome", "")) == "fine" else "no suspension"
	return [
		"Gain: %d%% chance he's cleared: %s, and Brownlow-eligible again" % [pct, cleared],
		"Cost: if it fails (%d%%), the board's confidence drops %d%%" % [100 - pct, TRIBUNAL_BOARD_COST],
	]


func _tribunal_loss_cost() -> void:
	if not board.is_empty():
		board["confidence"] = clampi(board_confidence() - TRIBUNAL_BOARD_COST, 0, 100)


static func tribunal_chance(row: Dictionary) -> float:
	if str(row.get("outcome", "")) == "fine":
		return 0.42
	match int(row.get("weeks", 0)):
		1:
			return 0.34
		2:
			return 0.22
		_:
			return 0.12


static func tribunal_case(row: Dictionary) -> String:
	var chance := tribunal_chance(row)
	if chance >= 0.35:
		return "Arguable"
	if chance >= 0.20:
		return "Difficult"
	return "Long shot"


## Appeals Board grounds are narrower than the first Tribunal challenge.
static func appeal_chance(row: Dictionary) -> float:
	match int(row.get("weeks", 0)):
		1:
			return 0.16
		2:
			return 0.10
		_:
			return 0.06


static func appeal_case(row: Dictionary) -> String:
	return "Narrow" if appeal_chance(row) >= 0.12 else "Very difficult"


## Rebuild the player's live sanction state after a successful contest.
func _recompute_mro_player(player_id: String, cleared_case_id: String) -> void:
	var p := list_player(player_id)
	if p.is_empty():
		return
	var cases: Array = p.get("brownlow_ineligible_cases", []).duplicate()
	cases.erase(cleared_case_id)
	if cases.is_empty():
		p.erase("brownlow_ineligible_cases")
		p.erase("brownlow_ineligible")
	else:
		p["brownlow_ineligible_cases"] = cases
		p["brownlow_ineligible"] = true

	# Suspension availability is current-state, so only live unresolved cases
	# from this round can remain alongside the case just overturned.
	var remaining_weeks := 0
	for row in last_mro:
		if str(row.get("id", "")) != player_id or str(row.get("outcome", "")) != "suspension":
			continue
		if str(row.get("challenge_result", "")) == "overturned" \
				or str(row.get("appeal_result", "")) == "overturned":
			continue
		remaining_weeks = maxi(remaining_weeks, int(row.get("weeks", 0)))
	if remaining_weeks > 0:
		p["suspension_weeks"] = remaining_weeks
	else:
		p.erase("suspension_weeks")


## One Tribunal challenge per MRO sanction. The evidence roll was stored in
## MatchSim when the incident happened, so save/reload cannot fish for a new
## result. A successful challenge clears the sanction and restores Brownlow
## eligibility exactly as requested; votes themselves are never altered.
func challenge_mro(player_id: String) -> Dictionary:
	var target := {}
	for row in last_mro:
		if str(row.get("club", "")) == my_club \
				and str(row.get("id", "")) == player_id \
				and str(row.get("outcome", "")) != "no_action" \
				and not bool(row.get("challenged", false)):
			target = row
			break
	if target.is_empty():
		return {"ok": false, "reason": "There is no MRO sanction left to challenge."}
	target["challenged"] = true
	var success := float(target.get("tribunal_roll", 1.0)) < tribunal_chance(target)
	target["challenge_result"] = "overturned" if success else "upheld"
	var p := list_player(player_id)
	var name := str(target.get("name", player_id)) if p.is_empty() else GameDB.player_display_name(p)
	if success:
		_recompute_mro_player(player_id, str(target.get("case_id", "")))
		add_news("tribunal", "%s has successfully challenged the MRO sanction at the Tribunal and is Brownlow-eligible again." % name)
		mark_dirty()
		return _mro_verdict(target, "tribunal", true, name,
				"%s wins the Tribunal challenge. The sanction is overturned and Brownlow eligibility is restored." % name)

	add_news("tribunal", "%s's Tribunal challenge failed; the MRO sanction stands." % name)
	_tribunal_loss_cost()
	mark_dirty()
	return _mro_verdict(target, "tribunal", false, name,
			"%s's Tribunal challenge fails. The original sanction stands, and the board's confidence drops %d%%." % [name, TRIBUNAL_BOARD_COST])


## A failed Tribunal suspension can go once to the Appeals Board. Successful
## appeal clears the sanction and restores Brownlow eligibility; failure is final.
func appeal_mro(player_id: String) -> Dictionary:
	var target := {}
	for row in last_mro:
		if str(row.get("club", "")) == my_club \
				and str(row.get("id", "")) == player_id \
				and str(row.get("outcome", "")) == "suspension" \
				and str(row.get("challenge_result", "")) == "upheld" \
				and not bool(row.get("appealed", false)):
			target = row
			break
	if target.is_empty():
		return {"ok": false, "reason": "There is no Tribunal decision available to appeal."}
	target["appealed"] = true
	var success := float(target.get("appeal_roll", 1.0)) < appeal_chance(target)
	target["appeal_result"] = "overturned" if success else "upheld"
	var p := list_player(player_id)
	var name := str(target.get("name", player_id)) if p.is_empty() else GameDB.player_display_name(p)
	if success:
		_recompute_mro_player(player_id, str(target.get("case_id", "")))
		add_news("tribunal", "%s has won at the Appeals Board; the suspension is overturned and Brownlow eligibility is restored." % name)
		mark_dirty()
		return _mro_verdict(target, "appeal", true, name,
				"%s wins the appeal. The suspension is overturned and Brownlow eligibility is restored." % name)
	add_news("tribunal", "%s's Appeals Board case failed; the suspension and Brownlow ineligibility stand." % name)
	_tribunal_loss_cost()
	mark_dirty()
	return _mro_verdict(target, "appeal", false, name,
			"%s's appeal fails. The suspension and Brownlow ineligibility stand, and the board's confidence drops %d%%." % [name, TRIBUNAL_BOARD_COST])


## What a Tribunal or Appeals Board hearing decided, for the verdict sheet:
## the sanction before and after, the odds we went in with, Brownlow
## standing, the next step, and what the hearing cost: a lost hearing costs
## the board's confidence (TRIBUNAL_BOARD_COST, row T1.R26 C1).
func _mro_verdict(row: Dictionary, stage: String, success: bool, name: String, reason: String) -> Dictionary:
	var p := list_player(str(row.get("id", "")))
	var odds := appeal_chance(row) if stage == "appeal" else tribunal_chance(row)
	var next_odds := -1.0
	if not success and stage == "tribunal" and str(row.get("outcome", "")) == "suspension":
		next_odds = appeal_chance(row)
	var weeks := int(row.get("weeks", 0)) if str(row.get("outcome", "")) == "suspension" else 0
	return {"ok": true, "success": success, "reason": reason,
			"stage": stage, "id": str(row.get("id", "")), "name": name, "club": my_club,
			"outcome": str(row.get("outcome", "")), "weeks_before": weeks,
			"weeks_after": weeks if not success else 0,
			"odds": odds, "next_odds": next_odds,
			"brownlow_ok": not p.is_empty() and not bool(p.get("brownlow_ineligible", false)),
			"risked": "%d%% of the board's confidence" % TRIBUNAL_BOARD_COST,
			"paid": "nothing" if success else "the board's confidence, down %d%%" % TRIBUNAL_BOARD_COST}


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
	return Contracts.payroll(my_list) + dead_for(my_club)


## What released contracts leave on `code`'s cap this coming season.
func dead_for(code: String) -> int:
	return int((dead_cap.get(code, {}) as Dictionary).get("amount", 0))


func cap_room() -> int:
	return cap_for(my_club) - my_payroll()


# ---------------------------------------------------------------------------
# Annual club department budget
# ---------------------------------------------------------------------------
func _ensure_department_budget() -> void:
	# A save from before row 99 still holds the Football department line.
	if department_budget.has(ClubBudget.OLD_FOOTBALL):
		department_budget = ClubBudget.fold_football(department_budget)
	var clean := ClubBudget.defaults()
	for area in ClubBudget.AREA_ORDER:
		clean[area] = ClubBudget.clamp_level(int(department_budget.get(area, ClubBudget.STANDARD)))
	# A fine's cut can leave the allocation over the year's budget: the
	# best-funded area steps down until it fits. Without a cut the
	# allocation is left as it was (set_department_budget already keeps it
	# legal).
	var cap := department_budget_annual_m()
	while cap < ClubBudget.ANNUAL_M and ClubBudget.total_m(clean) > cap + 0.001:
		var top := ""
		for area in ClubBudget.AREA_ORDER:
			if int(clean[area]) > 0 and (top == "" or int(clean[area]) > int(clean[top])):
				top = area
		if top == "":
			break
		clean[top] = int(clean[top]) - 1
	department_budget = clean


func department_budget_level(area: String) -> int:
	_ensure_department_budget()
	return int(department_budget.get(area, ClubBudget.STANDARD))


func department_budget_spent_m() -> float:
	_ensure_department_budget()
	return ClubBudget.total_m(department_budget)


func department_budget_remaining_m() -> float:
	return department_budget_annual_m() - department_budget_spent_m()


## What the board gives for the football year being set: $10.5m, less a
## league fine's cut (YearEvents) that year.
func department_budget_annual_m() -> float:
	var year := season_year + (1 if season_closed() else 0)
	return ClubBudget.ANNUAL_M - YearEvents.budget_cut_m(self, year)


func can_set_department_budget(area: String, level: int) -> bool:
	if not ClubBudget.valid_area(area) or level < 0 or level >= ClubBudget.LEVELS.size():
		return false
	_ensure_department_budget()
	var trial: Dictionary = department_budget.duplicate()
	trial[area] = level
	return ClubBudget.total_m(trial) <= department_budget_annual_m() + 0.001


## Set one department for the coming season. The allocation can only be
## changed while the off-season market is open; once the National Draft starts
## it is locked for that football year.
func set_department_budget(area: String, level: int) -> Dictionary:
	if not offseason_open():
		return {"ok": false, "reason": "Department funding is set during the off-season."}
	if not ClubBudget.valid_area(area) or level < 0 or level >= ClubBudget.LEVELS.size():
		return {"ok": false, "reason": "Unknown funding level."}
	if department_budget_annual_m() < ClubBudget.ANNUAL_M and not can_set_department_budget(area, level):
		return {"ok": false, "reason": "That allocation would exceed this year's $%.1fm club budget, after the league's fine." 				% department_budget_annual_m()}
	if not can_set_department_budget(area, level):
		return {"ok": false, "reason": "That allocation would exceed the %s annual club budget." % ClubBudget.money_m(ClubBudget.ANNUAL_M)}
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


## The season's close has run (its awards are out) and the next season has not
## begun: the feed's "Off-season", also while a rival board's letter holds the
## off-season's opening (ClubMoves).
func season_closed() -> bool:
	return season == null or offseason_year == season_year or int(season_awards.get("year", 0)) == season_year


## Season over: rivals decide on their expiring players at once - keep who
## is worth his new price, let the rest go to free agency. Yours wait for you.
## `keep_staff`: the season's close already took your staff for the wrap.
func open_offseason(keep_staff := false) -> void:
	if season == null or offseason_year == season_year or ClubMoves.letter_open(self):
		return
	# Sacked with jobs to choose from: the off-season waits for his choice and
	# opens at the club he takes (ClubMoves.take_job), never at the one he left.
	if is_sacked() and not ClubMoves.offers(self).is_empty():
		return
	ensure_contracts()
	# The season is over: every unfinished project is judged where it stands.
	for code in season.lists:
		for p in season.lists[code]:
			if project_job(p) != "":
				_finish_project(p, str(code) == my_club)
	_dev_promises_lapse()
	offseason_year = season_year
	for code in season.lists:
		ListCosts.season_over(season.lists[code], season_year)
	ListCosts.season_over(free_agents, season_year)
	for code in dead_cap.keys():
		if int((dead_cap[code] as Dictionary).get("year", 0)) <= season_year:
			dead_cap.erase(code)
	_coach_arch_season_end()
	# Selection bars from before today (a rival board's letter reads them) must
	# not reach the market: a reload, which does not keep them, would play it differently.
	_bars = {}
	# The board funds a fresh operating year. Last season's choices do not
	# become permanent upgrades or compound into a tech tree.
	department_budget = ClubBudget.defaults()
	department_budget_year = season_year + 1
	offseason_log = []
	compensation = []
	if not keep_staff:
		offseason_staff = Coaches.staff(coaches, my_club) if not coaches.is_empty() else {}
	_decide_retirements()
	# A Legacy career's Fitzroy merger is settled now, before any club
	# re-signs: the leftovers go into this year's National Draft, as in 1996.
	LegacyRollover.settle_merger(self)
	# A free agent whom no club took in a year (kept in the pool last
	# off-season, _fa_staying, or let go before the season): his AFL career
	# ends here, on the record. One whose club is gone (Fitzroy's players after
	# the merger, LegacyRollover.merge_lists, freed after the last market
	# closed) has had no market yet: he goes to this one.
	var carried := []
	var playing := GameDB.active_clubs(season_year)
	for p in free_agents:
		var by := str(p.get("released_by", ""))
		if not p.has("fa_kept") and by != "" and not playing.has(by):
			carried.append(p)
		else:
			_career_over(p, "delisted")
	free_agents = carried
	# A new club's approaches are settled first: it had first call.
	ExpansionBuild.resolve(self)
	# No rating or injury moves while rivals re-sign: each list's best 22 only
	# needs working out again when the list itself changes.
	TradeValue.remember_bars(true)
	var testing := []
	var testers := {}
	for code in season.lists:
		Season.beat()
		if code == my_club:
			continue
		var list: Array = season.lists[code]
		for p in Contracts.expiring(list).duplicate():
			if retiring_now(p):
				continue  # he retires at the rollover: no contract, no free agency
			if not list.has(p):
				continue   # already delisted to make cap room for a better player
			var why := ai_release_reason(code, p)
			# Talked round this off-season, he cannot be delisted by choice
			# until the next one: the club keeps him, as yours must.
			if why == "delist" and ListStings.release_held(p, season_year + 1):
				why = Contracts.ai_release_reason(p, list, cap_for(code))
			if why == "cap" and list.size() > Contracts.min_list():
				# Before a wanted player walks for want of cap room, the club
				# delists its least valuable expiring players it does not pick
				# (ones it could replace or not) - but only when that frees
				# enough room to keep him. Otherwise it keeps them all.
				var spares := _cap_spares(code, p)
				for spare in spares:
					_release(code, spare, false)
				if not spares.is_empty():
					why = ai_release_reason(code, p)
			if why == "" or list.size() <= Contracts.min_list():
				# Rivals bargain by the same rules: the least he takes for that term
				# (a club pushing to win now keeps him a little cheaper, as yours does).
				# Testers leave together later, so count them: the club must still
				# have a full list for the trade period while they listen.
				if why == "" and list.size() - int(testers.get(code, 0)) > Contracts.AI_FILL and tests_market(p, list):
					testing.append(p)
					testers[code] = int(testers.get(code, 0)) + 1
					continue
				var years := Contracts.ai_term(p, list)
				var least := Contracts.lowest(p, years) - culture_resign_discount(code, p, years)
				_resign(p, years, least, least)
			else:
				# A player they wanted but could not fit can earn them a pick;
				# one they delisted cannot.
				_release(code, p, why == "cap")
	TradeValue.remember_bars(false)
	_era_trim_rivals()
	# Released together, after every club has settled, so one club's tested
	# player is not another's replacement while it decides.
	for p in testing:
		var from := str(p.get("club", ""))
		_release(from, p, true, false)
		p["home_offer"] = from
		p["home_offer_year"] = season_year
	# Rival clubs trade first, so their free-agent offers are made from the
	# lists they'll actually have.
	trade_offers = []
	trade_table = []
	_collect_trade_requests()
	Season.beat()
	_open_trade_market()
	Season.beat()
	# The market opens: rivals put their offers on the table. Last year's
	# signings are last year's: each club aims for its targets afresh (they
	# were never cleared, so year 2's opening offers were cut by year 1's
	# signings, and a reload, which does not keep them, changed the market).
	market_stats = {}
	_targets_signed = {}
	fa_lost = []   # the wrap tells this off-season's losses, not last year's
	_bars = {}
	_fa_phase = {}
	_open_market(free_agents)
	Season.beat()
	mark_dirty()


## Out of contract at a rival, in its best 22 and with the service for free
## agency: he hears what the market offers, as your best 23 do (_market_test),
## with his club's usual re-signing offer on the table (_open_market). Real
## free agents number about 115 a year and about 10 move (2023: 11; 2024: at
## least 8); at 28 the game measured 10-17 a year after the new club's first.
const TEST_MARKET_AGE := 28.0


## Legacy mode (EraRules): when next season's lists are smaller (52 to 42 in
## 1994, eight rookies to six in 2013), each rival delists its least valuable
## players (Contracts.worth) down to the new limits, as the real clubs did. Yours makes room by
## the same rule at the draft (draft_room_short). Today's seasons never shrink.
func _era_trim_rivals() -> void:
	if not EraRules.is_era(season_year):
		return
	for code in season.lists:
		if code == my_club:
			continue
		var list: Array = season.lists[code]
		var guard := 0
		while guard < 60:
			guard += 1
			# Who retires at the rollover leaves anyway: he takes no spot.
			var staying := list.filter(func(q): return not retiring_now(q))
			var rookies_over := RookieList.cat_a_count(staying) > RookieList.cat_a_spots()
			var seniors_over := RookieList.senior_count(staying) > RookieList.senior_spots()
			if not (rookies_over or seniors_over) or list.size() <= Contracts.min_list():
				break
			var worst := _least_worth(staying, "" if seniors_over else "A")
			if worst.is_empty():
				break
			_release(code, worst, false)


## The player of list kind `kind` ("" senior, "A" Category A rookie) a rival
## delists first. Least worth goes first: rating blended with potential and
## discounted for age (Contracts.worth), never rating alone, so a 69 at 20
## with 75 to come stays ahead of a 70 at 35 (director, 2026-11-13: "smart
## delistings, not binary ones").
func _least_worth(list: Array, kind: String) -> Dictionary:
	var worst := {}
	for p in list:
		if str(p.get("rookie_list", "")) != kind:
			continue
		if worst.is_empty() or Contracts.worth(p) < Contracts.worth(worst) \
				or (Contracts.worth(p) == Contracts.worth(worst) and str(p["id"]) < str(worst["id"])):
			worst = p
	return worst


func tests_market(p: Dictionary, list: Array) -> bool:
	# No free agency before 2012 (EraRules, Legacy mode): a wanted player
	# out of contract re-signs or is traded; he cannot walk to the market.
	if not EraRules.on("free_agency"):
		return false
	return float(p.get("age", 0.0)) >= TEST_MARKET_AGE and comp_tenure_ok(p) and Contracts.needed(p, list)


## Why rival `code` lets expiring player `p` go (Contracts.ai_release_reason),
## measured against the best replacement it can actually get at his position.
func ai_release_reason(code: String, p: Dictionary) -> String:
	var list: Array = season.lists.get(code, [])
	# A player in its best 22 is never delisted, so his replacement is never
	# weighed: only the class ranking replacement_worth keeps is made as before.
	if Contracts.needed(p, list):
		_fill_repl_class(code)
		return Contracts.ai_release_reason(p, list, cap_for(code))
	return Contracts.ai_release_reason(p, list, cap_for(code), replacement_worth(code, p))


## What replacement_worth leaves behind when it reaches the draft: the class
## ranked once per class size (_repl_class), filled at the same calls it was.
func _fill_repl_class(code: String) -> void:
	if str(_repl_class.get("key", "")) == "%d:%d" % [season_year, draftee_pool.size()]:
		return
	var spot := 0
	for pk in club_picks(code):
		if int(pk["year"]) == season_year:
			var at := int((pk["positions"] as Array)[0][0])
			if spot == 0 or at < spot:
				spot = at
	if spot > 0:
		_repl_class = {"key": "%d:%d" % [season_year, draftee_pool.size()],
				"ranked": TradeValue.rank_prospects(_open_class(season_year))}


## The best a club can get in his place, on Contracts.worth's scale: the top
## free agent on the market at his position, or the best prospect at his
## position its next pick in this year's draft can reach. -INF when neither.
func replacement_worth(code: String, p: Dictionary) -> float:
	var role := str(p.get("role", ""))
	var best := -INF
	for q in free_agents:
		if str(q.get("role", "")) == role or str(q.get("role2", "")) == role:
			best = maxf(best, Contracts.worth(q))
	var spot := 0
	for pk in club_picks(code):
		if int(pk["year"]) == season_year:
			var at := int((pk["positions"] as Array)[0][0])
			if spot == 0 or at < spot:
				spot = at
	if spot > 0:
		var key := "%d:%d" % [season_year, draftee_pool.size()]
		if str(_repl_class.get("key", "")) != key:
			_repl_class = {"key": key, "ranked": TradeValue.rank_prospects(_open_class(season_year))}
		var ranked: Array = _repl_class["ranked"]
		for i in range(spot - 1, ranked.size()):
			var q: Dictionary = ranked[i]
			if str(q.get("role", "")) == role or str(q.get("role2", "")) == role:
				best = maxf(best, Contracts.worth(TradeValue._held(q)))
				break   # ranked best first: the first at his position is the best left
	return best


var _repl_class := {}


## The expiring player `code` would delist first to make cap room for `keep`:
## the least valuable one outside its best 22, or {}.
func _spare_expiring(code: String, keep: Dictionary, on: Array = []) -> Dictionary:
	var list: Array = on if not on.is_empty() else season.lists.get(code, [])
	var spare := {}
	for q in Contracts.expiring(list):
		if q == keep or retiring_now(q) or bool(q.get("resigned", false)) or Contracts.needed(q, list) 				or ListStings.release_held(q, season_year + 1):
			continue
		if spare.is_empty() or Contracts.worth(q) < Contracts.worth(spare) \
				or (Contracts.worth(q) == Contracts.worth(spare) and str(q["id"]) < str(spare["id"])):
			spare = q
	return spare


## The expiring players `code` delists, least valuable first, to fit `keep`
## under its cap: [] when even delisting every one it could (down to the
## minimum list) would not make the room, so it never loses them for nothing.
func _cap_spares(code: String, keep: Dictionary) -> Array:
	var scratch: Array = (season.lists.get(code, []) as Array).duplicate()
	var asking := Contracts.asking_salary(keep)
	var out := []
	while asking > cap_for(code) - Contracts.payroll(scratch) + int(keep.get("salary", 0)):
		if scratch.size() <= Contracts.min_list():
			return []
		var spare := _spare_expiring(code, keep, scratch)
		if spare.is_empty():
			return []
		scratch.erase(spare)
		out.append(spare)
	return out


## Who retires at this rollover is decided now, by the ageing rules, so a
## club can talk a healthy veteran round first (Retirement). Rival clubs ask
## by the same rules straight away; yours waits for you (talk_round).
func _decide_retirements() -> void:
	var year := season_year + 1
	for code in season.lists:
		var list: Array = season.lists[code]
		for p in list:
			if not Retirement.intends(p, year):
				continue
			p["retiring"] = year
			if str(code) == my_club or not Retirement.can_ask(p, list, year):
				continue
			var res := Retirement.answer(p, season_year, season_games(str(p["id"])), career_facts)
			Retirement.apply(p, res, year)
			if bool(res["stays"]) and int(p.get("overall", 0)) >= NEWS_MIN_OVR:
				add_news("retirement", "%s (%s) has decided to play on in %d." % [
						GameDB.player_display_name(p), GameDB.club_name(str(code)), year])


## Retiring at the coming rollover, and not talked round.
func retiring_now(p: Dictionary) -> bool:
	var year := season_year + 1
	return int(p.get("retiring", 0)) == year and int(p.get("play_on", 0)) != year


## Games he played this season (0 when he did not play).
func season_games(player_id: String) -> int:
	return int((season_tally.get(player_id, {}) as Dictionary).get("games", 0))


## Your players retiring at this rollover, best first:
## [{"p": player, "can_ask": bool, "talk": {} or his answer}].
func retiring_players() -> Array:
	var year := season_year + 1
	var out := []
	for p in my_list:
		if int(p.get("retiring", 0)) == year and int(p.get("play_on", 0)) != year:
			out.append({"p": p, "can_ask": Retirement.can_ask(p, my_list, year),
					"talk": (p.get("retire_talk", {}) as Dictionary) if int((p.get("retire_talk", {}) as Dictionary).get("year", 0)) == year else {}})
	for p in my_list:
		if int(p.get("play_on", 0)) == year:
			out.append({"p": p, "can_ask": false, "talk": p.get("retire_talk", {})})
	out.sort_custom(func(a, b): return int(a["p"].get("overall", 0)) > int(b["p"].get("overall", 0)))
	return out


## Ask him to go around again. His answer: {"stays", "reason"}, or {} when
## he cannot be asked.
func talk_round(player_id: String) -> Dictionary:
	var p := list_player(player_id)
	var year := season_year + 1
	if p.is_empty() or not offseason_open() or not Retirement.can_ask(p, my_list, year):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|ask_again|%s|%d" % [career_seed, str(p["id"]), year])
	var res := Retirement.answer(p, season_year, season_games(player_id), career_facts, rng.randf())
	Retirement.apply(p, res, year)
	var name := GameDB.player_display_name(p)
	add_news("retirement", ("%s will go around again in %d." % [name, year]) if bool(res["stays"])
			else ("%s is sticking with his decision to retire." % name))
	mark_dirty()
	return res


## Re-sign for `years` more seasons at `salary` (his asking price when not
## given). The contract ticks at the rollover, so it is stored as years + 1.
## Under his ask he carries a sting sized by the share of the gap to
## `floor_price` saved (the least he takes on that term; Contracts.lowest when
## not given), the same rule for every club (ListStings.haggle_points).
func _resign(p: Dictionary, years: int, salary := -1, floor_price := -1) -> void:
	var ask := Contracts.asking_salary(p)
	if salary > 0 and salary < ask:
		p["haggle_sting"] = season_year + 1
		p["haggle_points"] = ListStings.haggle_points(salary, ask,
				floor_price if floor_price >= 0 else Contracts.lowest(p, years))
	p["salary"] = salary if salary > 0 else ask
	p["contract_years"] = years + 1
	p["resigned"] = true
	p.erase("talks")


## Off a list and into free agency. `wanted`: the club wanted him (he walked,
## or it could not fit his price) rather than delisting him, so losing him
## can earn a compensation pick - if he had been there long enough.
func _release(code: String, p: Dictionary, wanted := false, announce := true) -> void:
	var dead := ListCosts.dead_money(p) if offseason_open() and not retiring_now(p) else 0
	if dead > 0:
		dead_cap[code] = {"year": season_year + 1, "amount": dead_for(code) + dead}
	(season.lists[code] as Array).erase(p)
	p["released_by"] = code
	# A delisted rookie is a free agent: whoever signs him, his old club
	# included, puts him on its senior list (row 88).
	p.erase("rookie_list")
	# Compensation picks came with free agency (2012 on, EraRules).
	p["comp_eligible"] = wanted and comp_tenure_ok(p) and EraRules.on("free_agency")
	p["contract_years"] = 0
	free_agents.append(p)
	offseason_log.append({"kind": "released", "club": code, "id": str(p["id"]), "wanted": wanted,
			"eligible": bool(p["comp_eligible"])})
	if announce and int(p.get("overall", 0)) >= NEWS_MIN_OVR:
		# Before free agency (Legacy, to 2011) a released player is delisted:
		# any club may still sign him, as the pre-season draft allowed.
		var line := "%s let %s (OVR %d) go to free agency." if EraRules.on("free_agency") 				else "%s delisted %s (OVR %d)."
		add_news("contract", line % [GameDB.club_name(code), GameDB.player_display_name(p), int(p["overall"])])


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


## His opinion of you, 0..100, as the game shows it (Trust.opinion).
func opinion_of_you(player_id: String) -> int:
	return Trust.opinion(Trust.value(relations, Trust.player_key(player_id)))


## How likely he is to refuse to re-sign with you, in percent: 1% for every
## point his opinion of you is under 50 (director 2026-11-08).
func resign_refuse_chance(p: Dictionary) -> int:
	return Contracts.refuse_chance(opinion_of_you(str(p.get("id", ""))))


## Does he refuse to re-sign with you this season? One draw per player a
## season, seeded from the career, so asking again never changes his answer;
## only a different opinion of you does.
func resign_refused(p: Dictionary) -> bool:
	var chance := resign_refuse_chance(p)
	return chance > 0 and StoryEngine.risk_hit(career_seed, season_year, 0,
			"resign_refuse|" + str(p.get("id", "")), chance)


## He refuses: talks are over and the news says why in one line, `tail`
## saying where he goes. Returns the line.
func refuse_resign(p: Dictionary, tail: String) -> String:
	var opinion := opinion_of_you(str(p.get("id", "")))
	var talks: Dictionary = p.get("talks", {})
	talks["walked"] = true
	talks["refused"] = opinion
	p["talks"] = talks
	var line := "%s %s" % [Contracts.REFUSED % [GameDB.player_display_name(p), opinion], tail]
	add_news("contract", line)
	mark_dirty()
	return line


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
	if talks.has("refused"):
		return {"ok": false, "answer": "walk", "reason": Contracts.REFUSED_TALKS % int(talks["refused"])}
	if bool(talks.get("walked", false)):
		return {"ok": false, "answer": "walk", "reason": "Talks have broken down: he will test free agency."}
	years = clampi(years, 1, Contracts.MAX_YEARS)
	salary = maxi(Contracts.senior_min(), salary)
	if my_payroll() - int(p.get("salary", 0)) + salary > cap_for(my_club):
		return {"ok": false, "answer": "", "reason": "Not enough cap room for %s a season." % Contracts.money(salary)}
	# Under 50, he may refuse you whatever you offer (director 2026-11-08).
	if resign_refused(p):
		refuse_resign(p, Contracts.REFUSED_GOES)
		return {"ok": false, "answer": "walk", "reason": Contracts.REFUSED_TALKS % int(p["talks"]["refused"])}
	var name := GameDB.player_display_name(p)
	var snap := RecruitUndo.snapshot(self, player_id)
	var reply := Contracts.respond(p, salary, years, int(talks.get("failed", 0)),
			-culture_resign_discount(my_club, p, years))
	var out := {"ok": false, "answer": str(reply["answer"]), "salary": int(reply["salary"])}
	match str(reply["answer"]):
		"accept":
			_resign(p, years, salary, Contracts.lowest(p, years) - culture_resign_discount(my_club, p, years))
			out["ok"] = true
			out["reason"] = "%s re-signs for %d season%s at %s." % [name, years, "" if years == 1 else "s", Contracts.money(salary)]
		"counter":
			talks["failed"] = int(talks.get("failed", 0)) + (Contracts.INSULT_STRIKES if bool(reply["insult"]) else 1)
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
		ClubLife.add_morale(p, -Contracts.INSULT_MORALE)
	if bool(out["ok"]):
		RecruitUndo.push(self, snap, "resign", p)
	mark_dirty()
	return out


## The step Undo would reverse ({"kind": "release" | "sign" | "resign", "id",
## "name"}), or {} when there is none (RecruitUndo).
func recruit_undo_last() -> Dictionary:
	return RecruitUndo.last(self)


## Reverse your last delisting, free-agent signing or re-signing, exactly as
## things stood before it. Returns {"ok", "kind", "reason"}.
func undo_recruit() -> Dictionary:
	var out := RecruitUndo.undo(self)
	if bool(out["ok"]):
		mark_dirty()
	return out


func release_player(player_id: String) -> Dictionary:
	var p := list_player(player_id)
	if p.is_empty() or not offseason_open():
		return {"ok": false, "reason": "Players can only be released in the off-season."}
	if my_list.size() <= Contracts.min_list():
		return {"ok": false, "reason": "Your list cannot go below %d." % Contracts.min_list()}
	if ListStings.release_held(p, season_year + 1):
		return {"ok": false, "reason": ListCosts.HELD_REASON % GameDB.player_display_name(p)}
	# A player whose career ends at this rollover leaves the game when he is
	# let go (_open_market), so that one cannot be undone.
	var snap := {} if retiring_now(p) else RecruitUndo.snapshot(self, player_id)
	_release(my_club, p, false)
	HonourBoard.leave(self, p, "delisted")
	_open_market([p])
	if not snap.is_empty():
		RecruitUndo.push(self, snap, "release", p)
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


## Would he turn you down flat? Only when he would not make your best 23
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


## His role at `code`: "ground" (in its best 18), "bench" (in its 23) or
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
	return cap_for(code) - Contracts.payroll(season.lists.get(code, [])) - dead_for(code)


## The cap `code` works under: the league's, plus a new club's sign-on money
## in its first two seasons, stepping down over the next two
## (ExpansionBuild.relief; nothing for anyone else).
func cap_for(code: String) -> int:
	return salary_cap + ExpansionBuild.relief(self, code)


## Whether Canberra joins this career in 2030. Set before the career's first
## draft (the new-career screen) and kept in the save.
func set_canberra(on: bool) -> void:
	canberra_on = on
	if GameDB.clubs.has("CANB"):
		GameDB.set_enter_year("CANB", GameDB.data_enter_year("CANB") if on else Expansion.NEVER)
	_apply_entry_years()


## The new clubs the data brings in after the first season (Tasmania,
## Canberra; never a created club) enter in expansion_from when it is set. A
## club the career leaves out (Canberra on No) stays out.
func _apply_entry_years() -> void:
	if expansion_from <= 0:
		return
	for code in GameDB.club_order:
		var data := GameDB.data_enter_year(str(code))
		if data > GameDB.START_YEAR and data < Expansion.NEVER \
				and GameDB.enter_year(str(code)) < Expansion.NEVER:
			GameDB.set_enter_year(str(code), expansion_from)


func _offer_of(p: Dictionary, code: String) -> Dictionary:
	for o in p.get("offers", []):
		if str(o["club"]) == code:
			return o
	return {}


## Rivals put offers on the table for `players`. Each club goes after the
## free agents who would improve its side most - up to two it would play
## (in its best 23: the furthest above its bar in their position first) -
## plus one depth signing per spot it is short of its usual list size, best
## players first by what everyone can see (rating, then age). Only with the
## cap room, never the club that let him go, never by a club's place in any
## list.
const FA_TARGETS := 2
## Places in the side by position, for spotting the thinnest part of a list.
const FILL_SHARE := {"RUCK": 1, "MID": 7, "DEF": 5, "FWD": 5}
const FILLER_CAP := 3
const TARGET_CAP := 3


## The clubs that have targeted him in this off-season's market.
func chased_by(p: Dictionary) -> Array:
	var rec: Dictionary = p.get("chasers", {})
	if int(rec.get("year", -1)) != season_year:
		return []
	return (rec.get("clubs", []) as Array).duplicate()


## He has left the free-agent pool: what the market knew of him goes.
static func clear_market_marks(p: Dictionary) -> void:
	for key in ["home_offer", "home_offer_year", "chasers"]:
		p.erase(key)


func _open_market(players: Array) -> void:
	# A player retiring at this rollover is not on the market: his career ends.
	for p in players.duplicate():
		if retiring_now(p):
			players.erase(p)
			free_agents.erase(p)
			_career_over(p)
	_bars = {}
	_fa_phase = {}
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
		if code != my_club and season.lists.has(code) and RookieList.senior_spot_free(season.lists[code]):
			clubs.append(code)
	# A rival's own out-of-contract player keeps its offer while he listens.
	for p in players:
		# Only an offer made this off-season: an older save can carry one from
		# a club that has since let him go.
		var home := str(p.get("home_offer", "")) if int(p.get("home_offer_year", -1)) == season_year else ""
		if home != "" and season.lists.has(home) and _offer_of(p, home).is_empty():
			var term := int(Contracts.wants(p)["years"])
			_add_offer(p, home, {"salary": Contracts.lowest(p, term) - culture_resign_discount(home, p, term), "years": term},
					fa_role(p, home), _finish_t(home))
	# Every club picks its targets, those that finished lowest first, and no
	# more than TARGET_CAP clubs chase one player: the rest move to their next
	# choice, so the whole market gets looked at, not only its top few.
	# Chasers are counted across every opening of this off-season's market
	# (and kept in the save), so a later round can't add a fourth.
	var chasers := {}
	for p in players:
		chasers[str(p["id"])] = chased_by(p)
	var by_finish := clubs.duplicate()
	by_finish.sort_custom(func(a, b):
		if _finish_t(a) != _finish_t(b):
			return _finish_t(a) > _finish_t(b)
		return str(a) < str(b))
	for code in by_finish:
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
			var chasing: Array = chasers.get(str(p["id"]), [])
			if not chasing.has(code) and chasing.size() >= TARGET_CAP:
				continue
			var role := fa_role(p, code)
			var open := Contracts.opening_offer(p, role)
			if int(open["salary"]) > Contracts.club_max(p, role, room, _fa_phase_of(code)):
				continue
			aims -= 1
			if not chasing.has(code):
				chasing.append(code)
				chasers[str(p["id"])] = chasing
				p["chasers"] = {"year": season_year, "clubs": chasing.duplicate()}
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
			if int(Contracts.opening_offer(p, "depth")["salary"]) > Contracts.club_max(p, "depth", room, _fa_phase_of(code)):
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
	var amb := culture_effect(code, "free_agent_score")
	if amb != 0.0:
		o["amb"] = amb
	if filler:
		o["filler"] = true
	(p["offers"] as Array).append(o)


## The most `o`'s club will pay him: by his role there, or only his lowest
## for a list filler; never past its cap room.
func offer_max(p: Dictionary, o: Dictionary) -> int:
	var room := _cap_room_of(str(o["club"]))
	if bool(o.get("filler", false)):
		return Contracts.club_max(p, "depth", room, _fa_phase_of(str(o["club"])))
	return Contracts.club_max(p, str(o.get("role", "depth")), room, _fa_phase_of(str(o["club"])))


## A club's phase for this market (_club_phase), read once per off-season
## market (cleared with _bars).
var _fa_phase := {}


func _fa_phase_of(code: String) -> String:
	if code == my_club or not season.lists.has(code):
		return ""   # your offers are yours to make
	if not _fa_phase.has(code):
		_fa_phase[code] = _club_phase(code)
	return str(_fa_phase[code])


## Rivals behind `leader` answer it once, all at the same moment, so no
## club's turn comes first. Returns sentences such as "Carlton improve: $650k
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
				lines.append("%s %s: %s for %d season%s." % [name, "improve" if str(r["action"]) == "improve" else "match",
						Contracts.money(int(r["salary"])), int(r["years"]), "" if int(r["years"]) == 1 else "s"])
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
				"view": view, "leading": i == 0, "mine": str(o["club"]) == my_club,
				"worth": Contracts.worth_to_him(p, o)})
	return out


## What your offer of `salary` for `years` would be worth to free agent
## `player_id` a season (Contracts.worth_to_him), before you make it: your
## role for him, last year's finish and your culture, as `offer_free_agent`
## would put them on the table (row T1.R26 FA weights).
func fa_offer_worth(player_id: String, salary: int, years: int) -> int:
	var p := free_agent(player_id)
	return Contracts.worth_to_him(p, {"club": my_club, "salary": salary, "years": years,
			"role": fa_role(p, my_club), "finish_t": _finish_t(my_club),
			"amb": culture_effect(my_club, "free_agent_score")})


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
	var barred := Challenge.block_reason(self, p)
	if barred != "":
		return {"ok": false, "answer": "", "code": "challenge", "reason": barred}
	# A signing lands on the senior list (row 88), so it needs a senior spot.
	var no_spot := RookieList.add_block(my_list, "senior")
	if no_spot != "":
		return {"ok": false, "answer": "", "reason": RookieList.block_words(my_list, no_spot)}
	var talks: Dictionary = p.get("talks", {})
	if talks.has("refused"):
		return {"ok": false, "answer": "walk", "reason": Contracts.REFUSED_TALKS % int(talks["refused"])}
	if bool(talks.get("walked", false)):
		return {"ok": false, "answer": "walk", "reason": "He has stopped talking to you."}
	# One you let go is re-signing with you: the same draw as in talks.
	if str(p.get("released_by", "")) == my_club and resign_refused(p):
		refuse_resign(p, Contracts.REFUSED_STAYS)
		return {"ok": false, "answer": "walk", "reason": Contracts.REFUSED_TALKS % int(p["talks"]["refused"])}
	if int(p.get("market_round", 0)) >= Contracts.FA_ROUNDS:
		return {"ok": false, "answer": "", "reason": "You have made your final offer."}
	years = clampi(years, 1, Contracts.MAX_YEARS)
	salary = maxi(Contracts.senior_min(), salary)
	var name := GameDB.player_display_name(p)
	var terms := free_agent_terms(player_id)
	if bool(terms["refuse"]):
		return {"ok": false, "answer": "reject", "code": str(terms["code"]),
				"reason": AiReasons.line(str(terms["code"]), {"player": name})}
	if salary > cap_room():
		return {"ok": false, "answer": "", "reason": "Not enough cap room for %s a season." % Contracts.money(salary)}
	var reply := Contracts.respond(p, salary, years, int(talks.get("failed", 0)))
	if str(reply["answer"]) != "accept":
		var out := {"ok": false, "answer": str(reply["answer"]), "salary": int(reply["salary"])}
		if str(reply["answer"]) == "counter":
			talks["failed"] = int(talks.get("failed", 0)) + (Contracts.INSULT_STRIKES if bool(reply["insult"]) else 1)
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
	var snap := RecruitUndo.snapshot(self, player_id)
	_bars = {}
	_fa_phase = {}
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
	mine["amb"] = culture_effect(my_club, "free_agent_score")
	var rivals_left := false
	for o in p["offers"]:
		if str(o["club"]) != my_club and not bool(o.get("withdrawn", false)):
			rivals_left = true
	if not rivals_left:
		_sign_fa(p, my_club, salary, years)
		RecruitUndo.push(self, snap, "sign", p)
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
		if club != "" and club != my_club and fa_last_why != "":
			# Why he went there, from the branch his choice took (P-18).
			out["code"] = fa_last_why
			out["club"] = club
			out["reason"] = AiReasons.line(fa_last_why, {"player": name, "club": GameDB.club_name(club)})
	else:
		var lead := Contracts.best_offer(p, p["offers"])
		out["reason"] = "Your offer leads." if lead == mine else "%s's offer leads." % GameDB.club_name(str(lead["club"]))
	if str(out["answer"]) == "signed":
		RecruitUndo.push(self, snap, "sign", p)
	mark_dirty()
	return out


## Why the last free agent _decide_fa settled went elsewhere rather than to
## you: a reason code (data/ai_reasons.json), "" when you had no offer in or
## he chose you. Not saved.
var fa_last_why := ""
## Free agents you had an offer in for who chose another club, and why:
## [{"id", "name", "club", "code"}]. Shown in the off-season wrap; session
## only, not saved (P-18, lead 2026-10-18: no new save key).
var fa_lost: Array = []


## The off-season wrap's free-agency lines: each free agent you were after
## who chose a rival, and why (fa_lost), the club's name for its ink.
## [{"text", "club"}]; empty after a reload (not saved).
func fa_lost_lines() -> Array:
	var out := []
	for e in fa_lost:
		out.append({"club": str(e["club"]), "text": AiReasons.line(str(e["code"]),
				{"player": str(e["name"]), "club": GameDB.club_name(str(e["club"]))})})
	return out


## He picks among the standing offers his suitors can still honour (a spot on
## the list, the cap room). Returns the club he signs with, or "".
func _decide_fa(p: Dictionary) -> String:
	fa_last_why = ""
	var valid := []
	var mine := {}
	var mine_out := ""
	for o in p.get("offers", []):
		if bool(o.get("withdrawn", false)):
			continue
		var code := str(o["club"])
		var list: Array = season.lists.get(code, [])
		var why_not := RookieList.add_block(list, "senior")
		var no_spot := why_not != ""
		if no_spot or int(o["salary"]) > _cap_room_of(code):
			if code == my_club:
				mine_out = ("fa_your_44" if why_not == "list" else "fa_your_list") if no_spot else "fa_your_cap"
			continue
		if code == my_club:
			mine = o
		if code != my_club and bool(o.get("filler", false)) and list.size() >= Contracts.AI_FILL:
			continue
		valid.append(o)
	var best := Contracts.best_offer(p, valid)
	if best.is_empty():
		return ""
	if AiReasons.enabled and str(best["club"]) != my_club:
		if mine_out != "":
			fa_last_why = mine_out
		elif not mine.is_empty():
			fa_last_why = str(Contracts.prefers_why(p, best, mine)[1])
		if fa_last_why != "":
			fa_lost.append({"id": str(p["id"]), "name": GameDB.player_display_name(p),
					"club": str(best["club"]), "code": fa_last_why})
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
	clear_market_marks(p)
	free_agents.erase(p)
	_bars.erase(code)
	offseason_log.append({"kind": "signed", "club": code, "id": str(p["id"]), "salary": salary, "years": years})
	if bool(p.get("tested", false)):
		p.erase("tested")
		var stayed := code == my_club
		add_news("contract", ("%s tested free agency and re-signs with %s: %s for %d season%s." if stayed
				else "%s tested free agency and leaves for %s: %s for %d season%s.") % [GameDB.player_display_name(p),
				GameDB.club_name(code), Contracts.money(salary), years, "" if years == 1 else "s"])
	elif code == my_club or int(p.get("overall", 0)) >= NEWS_MIN_OVR:
		add_news("contract", "%s sign free agent %s (OVR %d): %s for %d season%s." % [GameDB.club_name(code),
				GameDB.player_display_name(p), int(p["overall"]), Contracts.money(salary), years, "" if years == 1 else "s"])


func _join(code: String, p: Dictionary) -> void:
	var list: Array = season.lists[code]
	clear_market_marks(p)
	if str(p.get("club", "")) != code:
		p["joined"] = season_year
		# A move lands him on the new club's senior list (row 88, RookieList).
		p.erase("rookie_list")
		TeamFamiliarity.arrive_club(p, games_played(p) == 0)
	# A new club ends a project; his season's chance stays spent. The old
	# club's decision is kept as a career fact, with how it ended.
	if project_job(p) != "" and str(p.get("club", "")) != code:
		CareerFacts.add(career_facts, str(p.get("id", "")), CareerFacts.row(season_year, "",
				"project", str(p.get("club", "")), project_job(p), "ended by a move"))
	p["club"] = code
	p["num"] = _next_jumper_number(list)
	p.erase("train_plan")
	for key in ["train_focus", "train_focus_year", "focus_ledger"]:
		p.erase(key)
	p.erase("project")
	p.erase("released_by")
	p.erase("fa_kept")
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
## open or the national draft is on: this year's draft and the next two (the
## AFL's rule; director 2026-10-25, "this and next 2 drafts").
func trade_pick_years() -> Array:
	if offseason_open() or draft_night_open():
		return [season_year, season_year + 1, season_year + 2]
	return []


## True while the national draft is on: picks still to be made trade live
## (director 2026-10-25); players do not, the lists are closed.
func draft_night_open() -> bool:
	return draft != null and draft.intake_mode and draft.league_mode and not draft.is_finished() \
				and season != null and my_club != "" and season.lists.has(my_club)


func pick_id(year: int, rnd: int, origin: String) -> String:
	return "pick:%d:%d:%s" % [year, rnd, origin]


func pick_owner_of(year: int, rnd: int, origin: String) -> String:
	return str(pick_owner.get("%d:%d:%s" % [year, rnd, origin], origin))


## How the club that holds a pick got it, in one line. Its own: "Your own, 7th
## on the ladder" (this year's draft; next year's has no place yet). Traded in:
## "From Melbourne, for Jack Smith, 2027 trade period", or, when the club it
## came from had it from someone else, "Melbourne's pick, from Carlton, for ...".
## A fact, never a grade of the trade.
func pick_story(year: int, rnd: int, origin: String) -> String:
	if season == null:
		return ""
	var holder := pick_owner_of(year, rnd, origin)
	if holder == origin:
		var whose := "Your own" if holder == my_club else "%s's own" % GameDB.club_name(holder)
		if year == season_year and season.ladder.has(origin):
			whose += ", %s on the ladder" % ordinal(club_position(origin))
		return whose
	var got: Dictionary = pick_got.get("%d:%d:%s" % [year, rnd, origin], {})
	if got.is_empty():
		return "%s's pick, traded in" % GameDB.club_name(origin)
	var prev := str(got.get("from", ""))
	var words: Array = []
	for g in got.get("gave", []):
		var gid := str(g.get("id", ""))
		var named := _find_player(gid) if not gid.begins_with("pick:") else {}
		words.append(GameDB.player_display_name(named) if not named.is_empty() else str(g.get("name", "")))
	var what := ""
	if words.size() == 1:
		what = str(words[0])
	elif words.size() == 2:
		what = "%s and %s" % [words[0], words[1]]
	elif words.size() > 2:
		what = "%s and %d more" % [words[0], words.size() - 1]
	var from_words := "you" if prev == my_club else GameDB.club_name(prev)
	var line := ("From %s" % from_words) if prev == origin else (
			"%s's pick, from %s" % [GameDB.club_name(origin), from_words])
	if what != "":
		line += ", for " + what
	return line + ", %d trade period" % int(got.get("season", year))


## Last home-and-away rounds on, until the draft: where your first pick would
## fall if the season ended today, in words. Today's order only, no guess at
## what the other clubs will do. "" earlier in the year or once the draft is on.
func pick_order_line() -> String:
	if season == null or my_club == "" or season.fixture.is_empty() or draft != null:
		return ""
	if season.round_index < season.fixture.size() - PICK_LINE_ROUNDS:
		return ""
	var year := season_year
	for rnd in range(1, trade_pick_rounds(year) + 1):
		for origin in _draft_order():
			if pick_owner_of(year, rnd, str(origin)) != my_club:
				continue
			var at := draft_spot(year, rnd, str(origin))
			var lead := "Your first pick:" if season.is_regular_done() else "Your first pick today:"
			var line := "%s No. %d" % [lead, at]
			if str(origin) != my_club:
				line += ", %s's" % GameDB.club_name(str(origin))
			return line + "."
	return "You hold no pick in the first %d rounds of this draft." % trade_pick_rounds(year)


## The last six home-and-away rounds show where the first pick falls (the
## director's proposal P-47: "from round 18" of 23).
const PICK_LINE_ROUNDS := 6


## Mark one of your players untouchable, or take the mark off. Rivals stop
## asking for him in the offers they put to you; his value and his own
## requests are untouched. Offers already on the table for him are withdrawn.
func set_untouchable(id: String, on: bool) -> void:
	if on and not my_list.any(func(q): return str(q["id"]) == id):
		return
	if on:
		untouchable[id] = true
		# Off the trade table too, so taking the mark off lets him be tabled again.
		trade_table.erase(id)
		for o in trade_offers:
			if str(o["status"]) == "open" and (o["take"] as Array).has(id) and not bool(o.get("request", false)):
				o["status"] = "off"
	else:
		untouchable.erase(id)
	mark_dirty()


func is_untouchable(id: String) -> bool:
	return untouchable.has(id)


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
	var owner := pick_owner_of(year, rnd, origin)
	var positions: Array
	var spot := 0
	if year == season_year and draft_night_open():
		# On the night a pick is where it sits in the order still to run: the
		# prospects left are what it buys. A pick already made is spent.
		var slot: int = draft.pick_slot(rnd, origin)
		if slot < 0:
			return {}
		spot = slot + 1
		owner = str(draft.pick_sequence[slot])
		positions = [[slot - int(draft.pick_index) + 1, 1.0]]
	elif year == season_year:
		spot = draft_spot(year, rnd, origin)
		positions = [[spot, 1.0]]
	else:
		positions = future_spots(rnd, origin)
	return {"pick": true, "id": id, "year": year, "round": rnd, "origin": origin,
			"owner": owner, "positions": positions, "spot": spot,
			"name": _pick_name(year, rnd, origin, spot)}


## The overall pick a club's pick in `rnd` will be in this year's national
## draft: the reversed ladder, the same order every round.
func draft_spot(year: int, rnd: int, origin: String) -> int:
	var order := _draft_order()
	var n := order.size()
	var i := order.find(origin)
	var regular := (rnd - 1) * n + i + 1
	# A new club's extra picks come first: every pick behind them is later.
	var ahead := ExpansionBuild.picks_ahead(self, year, regular, n)
	# So do this off-season's free-agency compensation picks, placed as
	# begin_intake_draft hands them to the draft. The list outlives the
	# rollover (the season wrap reads it), so count it only while this
	# season's off-season is open.
	if year == season_year and offseason_year == season_year:
		var active := GameDB.active_clubs(season_year)
		for c in compensation:
			if active.has(str(c["club"])) and int(c["after"]) < regular:
				ahead += 1
	return regular + ahead


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
		var in_round := n - place
		var w := exp(-pow(float(place) - expect, 2.0) / (2.0 * sigma * sigma))
		out.append([(rnd - 1) * n + in_round, w])
	out.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	return out


## This year's national draft order: the ladder reversed.
var _order_cache := {}


func _draft_order() -> Array:
	var key := _league_fingerprint()
	if str(_order_cache.get("key", "")) != key:
		# The draft's own order (premier last, runner-up before it), so a
		# pick's number matches the one it is called on draft night.
		_order_cache = {"key": key, "order": intake_order()}
	return _order_cache["order"]


func _pick_name(year: int, rnd: int, origin: String, at: int) -> String:
	if year == season_year and at > 0 and draft_night_open():
		return "pick %d tonight" % at   # the night's own words: the number on the board
	var nth: String = ["first", "second", "third", "fourth"][clampi(rnd - 1, 0, 3)]
	var name := "%s %d %s-round pick" % [CopyRules.possessive(GameDB.club_name(origin)),
			year, nth]
	return name + (" (No. %d)" % at if at > 0 else "")


## The tradeable picks `code` owns, earliest first.
func club_picks(code: String) -> Array:
	var out := []
	for year in trade_pick_years():
		for rnd in range(1, trade_pick_rounds(int(year)) + 1):
			for origin in GameDB.active_clubs(season_year):
				if pick_owner_of(int(year), rnd, str(origin)) == code:
					var pk := pick_asset(pick_id(int(year), rnd, str(origin)))
					if not pk.is_empty():   # a pick already made tonight is spent
						out.append(pk)
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
	var active := GameDB.active_clubs(year)
	for key in pick_owner:
		var parts := str(key).split(":")
		# A pick held by a club no longer in the league (Fitzroy after 1996)
		# goes back to the club it came from.
		if int(parts[0]) == year and active.has(str(pick_owner[key])) \
				and not LegacyRollover.merged_away(self, str(pick_owner[key])):
			out["%s:%s" % [parts[1], parts[2]]] = str(pick_owner[key])
	return out


## The draft classes a club can see, best first: {year: [prospects]}. This
## year's open class (not the players tied to a club).
func trade_prospects() -> Dictionary:
	var out := {}
	for year in trade_pick_years():
		# Next year's class isn't known yet: this year's stands in for it, whole
		# (tonight's picks don't thin a class that hasn't been drafted).
		out[str(year)] = TradeValue.rank_prospects(_open_class(mini(int(year), season_year), int(year) <= season_year))
	return out


func _open_class(year: int, tonight := true) -> Array:
	var pool := []
	for p in draftee_pool:
		if drafted_draftees.has(str(p["id"])) or int(p.get("draft_year", year)) != year:
			continue
		if tonight and draft_night_open() and draft.picked.has(str(p["id"])):
			continue   # taken tonight: no pick buys him now
		if str(p.get("tied_club", "")) != "" and int(p.get("draft_year", 0)) == year:
			continue
		pool.append(p)
	return pool


## Rounds of `year`'s draft that can be traded: the rounds it will run (as
## many as the class fills, Draft.build_intake), at most TRADE_PICK_ROUNDS.
func trade_pick_rounds(year: int) -> int:
	if draft_night_open():
		# The night runs the rounds it was planned with; the pool shrinking
		# pick by pick does not take a round off the table.
		return mini(TRADE_PICK_ROUNDS, maxi(1, draft.planned_rounds()))
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
			return {"assets": [], "error": AiReasons.line("trade_twice"), "code": "trade_twice"}
		seen[key] = true
		if key.begins_with("pick:"):
			var pk := pick_asset(key)
			if pk.is_empty() or str(pk["owner"]) != owner:
				var pc := "trade_not_their_pick" if owner != my_club else "trade_not_your_pick"
				return {"assets": [], "error": AiReasons.line(pc), "code": pc}
			out.append(pk)
		else:
			var found := {}
			for p in season.lists.get(owner, []):
				if str(p["id"]) == key:
					found = p
			if found.is_empty():
				var fc := "trade_not_their_player" if owner != my_club else "trade_not_your_player"
				return {"assets": [], "error": AiReasons.line(fc), "code": fc}
			if retiring_now(found):
				# His career ends at the rollover: there is nobody to trade.
				return {"assets": [], "error": AiReasons.line("trade_retiring"), "code": "trade_retiring"}
			out.append(found)
	return {"assets": out, "error": "", "code": ""}


## Would `club` accept your `mine` (player and pick ids) for its `theirs`?
func evaluate_trade(club: String, mine: Array, theirs: Array) -> Dictionary:
	var night := draft_night_open()
	if not offseason_open() and not night:
		return {"ok": false, "code": "trade_closed", "reason": AiReasons.line("trade_closed")}
	if night:
		for id in mine + theirs:
			if not str(id).begins_with("pick:"):
				return {"ok": false, "code": "trade_night_picks_only", "reason": AiReasons.line("trade_night_picks_only")}
	var g := _trade_assets(theirs, club)
	var t := _trade_assets(mine, my_club)
	if str(g["error"]) != "" or str(t["error"]) != "":
		var bad: Dictionary = g if str(g["error"]) != "" else t
		return {"ok": false, "code": str(bad["code"]), "reason": str(bad["error"])}
	var give: Array = g["assets"]
	var take: Array = t["assets"]
	if _trade_ban_breaks(my_club, club, take, give):
		var who := my_club if YearEvents.trade_banned(self, my_club) else club
		return {"ok": false, "code": "trade_banned",
				"reason": "The league has barred %s from trading players in until after %d." % [
				GameDB.club_name(who), int((year_events.get("trade_bans", {}) as Dictionary).get(who, season_year))]}
	var wont := _wont_go(give, my_club)
	if wont == "":
		wont = _wont_go(take, club)
	if wont != "":
		return {"ok": false, "code": "trade_asked_elsewhere", "reason": wont}
	# Your challenge (Youth only, Rebuild) binds what comes in, never what goes.
	for p in give:
		var barred := Challenge.block_reason(self, p)
		if barred != "":
			return {"ok": false, "code": "trade_challenge", "reason": barred}
	var ctx := trade_context(club)
	var names := {}
	for p in give + take:
		names[str(p["id"])] = str(p["name"]) if Contracts.is_pick(p) else GameDB.player_display_name(p)
	ctx["names"] = names
	# On the night a club judges a pick by its own read of the prospects left
	# (the same read it drafts with), not the consensus.
	ctx["prospects"] = _night_prospects(club) if night else trade_prospects()
	return Contracts.evaluate_trade(season.lists.get(club, []), give, take,
			cap_for(club), my_list, salary_cap, float(difficulty_rules()["trade_margin"]), ctx)


## What a club weighs a trade with: its cycle, last season's games for
## everyone, its name.
func trade_context(club: String) -> Dictionary:
	var games := {}
	for id in season_tally:
		games[str(id)] = int((season_tally[id] as Dictionary).get("games", 0))
	var asked := {}
	for id in trade_requests:
		if str(trade_requests[id]["club"]) == club:
			asked[str(id)] = true
	return {"phase": club_phase(club), "games": games, "name": GameDB.club_name(club), "asked": asked,
			"year": season_year}


## Where a club is in its cycle - "rebuilding", "building" or "contending" -
## from what anyone can see: last season's finish, how its list ranks, and
## how old its best 23 is (TradeValue.phase). Worked out afresh each time.
## Phases worked out for one state of the league: {"key": fingerprint,
## club: phase}. The fingerprint covers everything a phase reads - every
## list (who, rating, potential, age) and the ladder - so any trade,
## signing, draft, development or load gets a fresh answer.
var _phase_cache := {}


## A club's list as the game sees it (TeamRating): its match-day side today on the
## OVR scale, the same list in three seasons, and its phase, with the line a
## screen shows ("Contender. Team rating 78. On this list, 81 in three years.").
func team_outlook(club: String) -> Dictionary:
	if season == null or not season.lists.has(club):
		return {}
	var list: Array = season.lists[club]
	var phase := club_phase(club)
	var now := TeamRating.rating(list)
	var later := TeamRating.forecast(list)
	return {"rating": now, "forecast": later, "phase": phase, "category": TeamRating.category(phase),
			"line": TeamRating.line(phase, now, later)}


func club_phase(club: String) -> String:
	if season == null or not season.lists.has(club):
		return "building"
	var key := _league_fingerprint()
	if str(_phase_cache.get("key", "")) != key:
		_phase_cache = {"key": key}
	if not _phase_cache.has(club):
		_phase_cache[club] = _club_phase(club)
	return str(_phase_cache[club])


## Set while the trade market works through one state of the league (see
## _freeze_league), so its many lookups don't re-hash every list.
var _frozen_fingerprint := ""


func _freeze_league(on: bool) -> void:
	_frozen_fingerprint = ""
	TradeValue.remember_bars(on)
	if on:
		_frozen_fingerprint = _league_fingerprint()


func _league_fingerprint() -> String:
	if _frozen_fingerprint != "":
		return _frozen_fingerprint
	var parts := PackedStringArray([str(season_year)])
	for code in season.lists:
		var h := 0
		for q in season.lists[code]:
			h = hash([h, str(q["id"]), int(q.get("overall", 0)), int(q.get("potential", 0)), snappedf(float(q.get("age", 0.0)), 0.01)])
		parts.append("%s:%d:%d" % [code, (season.lists[code] as Array).size(), h])
	for code in season.ladder:
		var row: Dictionary = season.ladder[code]
		parts.append("%s=%d/%d/%d/%d" % [code, int(row.get("p", 0)), int(row.get("pts", 0)), int(row.get("pf", 0)), int(row.get("pa", 0))])
	parts.append("gf=%s/%s" % [str(season.finals.get("premier", "")), str(season.finals.get("runner_up", ""))])
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
	var all := _standings()
	return all.get(club, [-1.0, 0.5])


## Every club's standing at once (see _standing), worked out once per
## state of the league - ranking lists means rating every squad.
var _standings_cache := {}


func _standings() -> Dictionary:
	var key := _league_fingerprint()
	if str(_standings_cache.get("key", "")) == key:
		return _standings_cache["all"]
	var played := false
	for code in season.ladder:
		if int((season.ladder[code] as Dictionary).get("p", 0)) > 0:
			played = true
			break
	var all := {}
	for code in season.lists:
		all[str(code)] = [-1.0, 0.5]
	if played:
		var table := season.ladder_sorted()
		for k in range(table.size()):
			if all.has(str(table[k]["code"])):
				all[str(table[k]["code"])][0] = float(k) / float(maxi(1, table.size() - 1))
	var ranks := []
	for code in season.lists:
		if GameDB.active_clubs(season_year).has(code):
			ranks.append([str(code), Squad.new(str(code), season.lists[code], true, str(code)).strength()])
	ranks.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	for k in range(ranks.size()):
		all[str(ranks[k][0])][1] = float(k) / float(maxi(1, ranks.size() - 1))
	_standings_cache = {"key": key, "all": all}
	return all


## Do the trade if `club` accepts: players change lists, picks change owners.
func make_trade(club: String, mine: Array, theirs: Array) -> Dictionary:
	var verdict := evaluate_trade(club, mine, theirs)
	if not bool(verdict["ok"]):
		return verdict
	var incoming: Array = _trade_assets(theirs, club)["assets"]
	var outgoing: Array = _trade_assets(mine, my_club)["assets"]
	var night := draft_night_open()
	var at: int = int(draft.pick_index) + 1 if night else 0
	_execute_trade(my_club, club, outgoing, incoming)
	var said := "%s get %s from %s for %s." % [GameDB.club_name(my_club),
			_names(incoming), GameDB.club_name(club), _names(outgoing)]
	var row := {"kind": "trade", "club": club, "in": theirs.duplicate(), "out": mine.duplicate()}
	if night:
		row["night"] = true
		draft.night_trades.append({"at": at, "buyer": my_club, "seller": club, "in": theirs.duplicate(),
				"out": mine.duplicate(), "text": said})
	offseason_log.append(row)
	add_news("trade", ("Draft night trade: " if night else "Trade: ") + said)
	mark_dirty()
	return {"ok": true, "reason": "Trade done."}


## What went the other way in a trade, kept with the pick: [{"id", "name"}].
func _trail_assets(assets: Array) -> Array:
	var out := []
	for x in assets:
		out.append({"id": str(x["id"]), "name": str(x["name"]) if Contracts.is_pick(x) else GameDB.player_display_name(x)})
	return out


## A pick that changed hands remembers who it came from and for what; a pick
## that went home to its own club has no story but its own.
func _note_pick_got(a: Dictionary, from: String, to: String, gave: Array) -> void:
	if not Contracts.is_pick(a):
		return
	var key := "%d:%d:%s" % [int(a["year"]), int(a["round"]), str(a["origin"])]
	if to == str(a["origin"]):
		pick_got.erase(key)
	else:
		pick_got[key] = {"from": from, "season": season_year, "gave": gave.duplicate(true)}


## One traded asset from `from` to `to`: a player changes lists, a pick
## changes owner (a pick back with its own club needs no entry).
func _move_asset(a: Dictionary, from: String, to: String) -> void:
	if Contracts.is_pick(a):
		var key := "%d:%d:%s" % [int(a["year"]), int(a["round"]), str(a["origin"])]
		if to == str(a["origin"]):
			pick_owner.erase(key)
		else:
			pick_owner[key] = to
		if int(a["year"]) == season_year and draft_night_open():
			draft.reassign_pick(draft.pick_slot(int(a["round"]), str(a["origin"])), to)
		return
	(season.lists[from] as Array).erase(a)
	_join(to, a)


# ---------------------------------------------------------------------------
# The market moving on its own: counters, offers to you, trades between rivals
# ---------------------------------------------------------------------------
## Most players and picks one side can put in a trade.
const TRADE_MAX := 5
## At most this many offers to you in an off-season.
const MAX_OFFERS := 2
## Trades between rival clubs in an off-season: they keep dealing while
## deals both sides accept are there (director 2026-11-03). This is only a
## runaway guard, never a limit a sane market reaches.
const MAX_AI_TRADES := 40
## Most trades one rival club makes on draft night, and on behalf of players
## who asked to move.
const DEALS_PER_CLUB := 2
## Bids a buyer tries, dearest first, for one it would stand by.
const NEGOTIATE_STEPS := 6
## Targets a rival buyer asks about, down its wish list, before it gives up
## on trading this year. Its first asks are often the young stars nobody
## sells; the deals that do get done come further down.
const TARGET_TRIES := 15
## Most offers that come in for one player or pick on the trade table.
const MAX_TABLE_OFFERS := 3
## Ask their price (row 67): the most pieces of yours a club names for one
## of its players, and how many packages it weighs before saying no.
const ASK_PRICE_PIECES := 3
const ASK_PRICE_TRIES := 40
## Past those first tries the weighing goes on through the packages near the
## price (up to ASK_PRICE_OVER of it), ASK_PRICE_MOST at most, so a club that
## turns down the cheapest forty is still asked about the next.
const ASK_PRICE_OVER := 1.25
const ASK_PRICE_MOST := 400
## How close to the most it would pay a club opens with nobody else bidding
## (each rival suitor on the trade table pushes it up a tenth).
const UNASKED_BID := 0.8


## Would `club` accept `gets` (assets from `other`) for `gives` (its own)?
## The same rules and valuation as a trade with you.
func _club_verdict(club: String, other: String, gives: Array, gets: Array, margin: float,
		prospects: Dictionary) -> Dictionary:
	var ctx := trade_context(club)
	ctx["prospects"] = prospects
	return Contracts.evaluate_trade(season.lists[club], gives, gets, cap_for(club),
			season.lists[other], cap_for(other), margin, ctx)


# ---------------------------------------------------------------------------
# Draft night (director 2026-10-25): picks trade live. You offer at any time;
# rivals put offers to you as your pick comes up; rivals deal among themselves
# and the board shows it. Picks of this draft and the next two, never players;
# the same values as the trade period, each club by its own read of the class.
# ---------------------------------------------------------------------------
## Rivals asked, by the seeded club order, before a night deal is given up.
const NIGHT_BUYERS := 5
## Rivals that may put an offer to you for the pick you are on the clock with.
const NIGHT_OFFER_TRIES := 6
## How far under fair value (the consensus read) a night offer may sit: a real
## haggle, never a lowball (director 2026-10-25).
const NIGHT_OFFER_FLOOR := 0.9
## The pick index your last night offers were made for (-1: none yet).
var night_offers_at := -1


## The draft is on: listen for rivals on the clock.
func _watch_draft_night() -> void:
	if draft == null or not draft.intake_mode:
		return
	if not draft.rival_on_clock.is_connected(_rival_on_clock):
		draft.rival_on_clock.connect(_rival_on_clock)
	night_offers_at = -1


## The prospects left on the night as `club` reads them, best first (the read
## it drafts with: Draft._ai_score, its own scouting error included), for every
## draft year on the table (next years' classes stand in as this one does).
func _night_prospects(club: String) -> Dictionary:
	var out := {}
	if not draft_night_open():
		return out
	var whole: Array = (draft.pool as Array).duplicate()
	var scored := {}
	for p in whole:
		scored[str(p["id"])] = float(draft._ai_score(club, p))
	whole.sort_custom(func(a, b):
		var sa := float(scored[str(a["id"])])
		var sb := float(scored[str(b["id"])])
		if sa != sb:
			return sa > sb
		return str(a["id"]) < str(b["id"]))
	var left := whole.filter(func(p): return not draft.picked.has(str(p["id"])))
	# Only this year's picks buy from what is left tonight; a future pick is
	# judged against the whole stand-in class.
	for year in trade_pick_years():
		out[str(year)] = left if int(year) <= season_year else whole
	return out


## A rival is on the clock with pick `index`: a rival with a later pick in the
## round bids for it whenever the pick is worth more to it, by its own read of
## the class, than to the seller by the seller's read (plus the trade margin),
## paying with picks priced by its read; the seller judges by its own. No
## dice (director 2026-11-03); each club still makes at most DEALS_PER_CLUB
## deals, and the seeded club order is the same on a reload.
func _rival_on_clock(code: String, index: int) -> void:
	if not draft_night_open() or code == my_club or index >= draft.pick_rounds.size():
		return
	var rnd := int(draft.pick_rounds[index])
	if rnd > TRADE_PICK_ROUNDS or index >= draft.pick_origin.size():
		return
	var origin := str(draft.pick_origin[index])
	var pick := pick_asset(pick_id(season_year, rnd, origin))
	if pick.is_empty() or str(pick["owner"]) != code:
		return
	# Rival with rival: each must come out ahead, by its own read. The
	# difficulty margin is what rivals ask of you, not of each other.
	var margin := NIGHT_RIVAL_MARGIN
	_freeze_league(true)
	var sellers_read := trade_prospects()
	var seller_worth := _worth_to_read(code, pick, sellers_read)
	var seller_rel := _night_rel(code, pick, sellers_read)
	var tried := 0
	for buyer in _club_order("night:%d" % index):
		if tried >= NIGHT_BUYERS:
			break
		if buyer == code or _deals(buyer, true) >= DEALS_PER_CLUB:
			continue
		# A buyer with a later pick in this round wants to move up.
		var later := draft.upcoming_picks(buyer, 1)
		if later.is_empty() or int(later[0]) - 1 <= index or int(draft.pick_rounds[int(later[0]) - 1]) != rnd:
			continue
		tried += 1
		var read := _night_prospects(buyer)
		var buyer_worth := _worth_to_read(buyer, pick, read)
		# Clubs count value on their own scales (a contender's picks all read
		# lower), so the gate compares each club's pick against the same pick a
		# year on: a bid only where the buyer wants it now more than the seller.
		var buyer_rel := _night_rel(buyer, pick, read)
		if buyer_rel <= seller_rel * (1.0 + margin):
			continue   # worth no more to it than to the seller: no bid
		# The buyer raises its bid, cheapest package first, up to the most it
		# would pay; the seller takes the first it values enough. One opening
		# bid and no second offer left every deal on the table.
		var pkg := _night_bid(buyer, code, pick, buyer_worth, margin, read, sellers_read)
		if pkg.is_empty():
			continue
		_log_night_trade(buyer, code, pick, pkg, index + 1, [buyer_rel, seller_rel * (1.0 + margin)])
		break
	_freeze_league(false)


## How much better off each rival must be for a night deal between rivals.
const NIGHT_RIVAL_MARGIN := 0.01


## Packages a night buyer tries, cheapest first, before it gives up on a pick.
const NIGHT_BID_TRIES := 60


## The cheapest package of `buyer`'s that both sides stand by for `pick`
## (each by its own read), from its opening (UNASKED_BID of the most it would
## pay) up to that most; [] if none.
func _night_bid(buyer: String, seller: String, pick: Dictionary, worth: float, margin: float,
		read: Dictionary, sellers_read: Dictionary) -> Array:
	var tries := 0
	var most := worth / (1.0 + margin)
	for o in _bids(buyer, most, read):
		if tries >= NIGHT_BID_TRIES:
			break
		if float(o[1]) < UNASKED_BID * most:
			continue   # an opening well under the pick's worth: not a real bid
		if not bool(_club_verdict(buyer, seller, o[0], [pick], margin, read)["ok"]):
			continue
		tries += 1
		if bool(_club_verdict(seller, buyer, [pick], o[0], margin, sellers_read)["ok"]):
			return o[0]
	return []


## A pick's worth to `club` in units of the same slot in next year's draft:
## how much it wants this pick now rather than later, on a scale every club shares.
func _night_rel(club: String, pick: Dictionary, read: Dictionary) -> float:
	var later := TradeValue.pick_value(pick["positions"], read.get(str(season_year + 1), []), club_phase(club), 1)
	return _worth_to_read(club, pick, read) / maxf(later, 0.0001)


## What a pick is worth to `club` by a given read of the class.
func _worth_to_read(club: String, pick: Dictionary, read: Dictionary) -> float:
	return TradeValue.pick_value(pick["positions"], read.get(str(pick["year"]), []), club_phase(club),
			int(pick["year"]) - season_year)


## A night deal between rivals: done, on the board, in the news.
## `worths`: [the pick to the buyer, the bar it cleared (its worth to the
## seller plus the margin)], each against the same slot next year, kept so the
## gate can be checked.
func _log_night_trade(buyer: String, seller: String, pick: Dictionary, pkg: Array, at: int, worths := []) -> void:
	var phases := [club_phase(buyer), club_phase(seller)]
	_execute_trade(buyer, seller, pkg, [pick])
	var said := "%s get %s from %s for %s." % [GameDB.club_name(buyer),
			_names([pick]), GameDB.club_name(seller), _names(pkg)]
	var ids := pkg.map(func(a): return str(a["id"]))
	offseason_log.append({"kind": "ai_trade", "club": buyer, "with": seller, "in": [str(pick["id"])],
			"out": ids, "text": said, "phases": phases, "night": true})
	draft.night_trades.append({"at": at, "buyer": buyer, "seller": seller, "in": [str(pick["id"])],
			"out": ids, "text": said, "worths": worths})
	add_news("trade", "Draft night trade: " + said)
	mark_dirty()


## You are on the clock: a few rivals with a later pick in the round may put an
## offer to you for it, each priced by its own read of the class (so an offer
## can be well under what you think the pick is worth). Once per pick of yours;
## the offers go off the table when the pick is made. Returns how many came in.
func make_night_offers() -> int:
	if not draft_night_open() or not draft.is_user_turn() or night_offers_at == int(draft.pick_index):
		return 0
	night_offers_at = int(draft.pick_index)
	var index := int(draft.pick_index)
	var rnd := int(draft.pick_rounds[index])
	if rnd > TRADE_PICK_ROUNDS:
		return 0
	var pick := pick_asset(pick_id(season_year, rnd, str(draft.pick_origin[index])))
	if pick.is_empty() or str(pick["owner"]) != my_club:
		return 0
	for o in trade_offers:
		if bool(o.get("night", false)) and str(o["status"]) != "off" and (o["take"] as Array).has(str(pick["id"])):
			return 0   # a reload: the offers for this pick were already made (open or declined)
	var made := 0
	var tried := 0
	_freeze_league(true)
	var consensus := trade_prospects()
	for club in _club_order("night offers:%d" % index):
		if made >= MAX_OFFERS or tried >= NIGHT_OFFER_TRIES:
			break
		var later := draft.upcoming_picks(club, 1)
		if later.is_empty() or int(later[0]) - 1 <= index or int(draft.pick_rounds[int(later[0]) - 1]) != rnd:
			continue
		tried += 1
		var read := _night_prospects(club)
		# No haggling on the clock: a rival bids the most it would pay by its own
		# read, and only tables it if, by the consensus read of the class, you
		# would come out even or ahead (director 2026-10-25: a late pick and a
		# future second for pick 6 is "absurd"). A club that rates a prospect
		# above the field finds the room; one that does not stays quiet.
		var pkg := _bid(club, pick, _worth_to_read(club, pick, read), 1.0, read, my_club)
		if pkg.is_empty() or not bool(_club_verdict(my_club, club, [pick], pkg, NIGHT_OFFER_FLOOR - 1.0, consensus)["ok"]):
			continue
		trade_offers.append({"club": club, "give": pkg.map(func(a): return str(a["id"])),
				"take": [str(pick["id"])], "status": "open", "night": true})
		made += 1
		add_news("trade", "%s have made an offer for your pick %d." % [GameDB.club_name(club), int(pick["spot"])])
	_freeze_league(false)
	if made > 0:
		mark_dirty()
	return made


## When `club` turns your offer down on value, the one change that would get
## it done, in its own words: one more of yours (the least it would settle
## for), or else one of theirs left out. {"say", "mine", "theirs", "code" (the
## refusal's reason code)}, or {}
## when the offer stands or no single change would do.
func trade_counter(club: String, mine: Array, theirs: Array) -> Dictionary:
	_freeze_league(true)
	var out := _counter(club, mine, theirs)
	_freeze_league(false)
	return out


func _counter(club: String, mine: Array, theirs: Array) -> Dictionary:
	var v := evaluate_trade(club, mine, theirs)
	if bool(v["ok"]) or not v.has("in") or mine.is_empty() or theirs.is_empty():
		return {}
	var best := {}
	var least := INF
	if mine.size() < TRADE_MAX:
		var extra := []
		for pk in club_picks(my_club):
			extra.append(str(pk["id"]))
		if not draft_night_open():   # players never move on draft night
			for p in my_list:
				# Rivals never ask for a player you marked untouchable, in a counter too.
				if not untouchable.has(str(p["id"])):
					extra.append(str(p["id"]))
		for id in extra:
			if mine.has(id):
				continue
			var w := evaluate_trade(club, mine + [id], theirs)
			if bool(w["ok"]) and float(w["in"]) < least:
				least = float(w["in"])
				best = {"say": "“We'd need %s as well.”" % _ask_name(str(id)), "mine": mine + [id], "theirs": theirs.duplicate()}
	if not best.is_empty() or theirs.size() < 2:
		return _with_code(best, v)
	var most := -1.0
	for id in theirs:
		var rest := theirs.filter(func(x): return x != id)
		var w := evaluate_trade(club, mine, rest)
		if bool(w["ok"]) and float(w["out"]) > most:
			most = float(w["out"])
			best = {"say": "“We could do it without %s.”" % _ask_name(str(id), "our"), "mine": mine.duplicate(), "theirs": rest}
	return _with_code(best, v)


## A counter carries the reason code of the refusal it answers (P-18).
func _with_code(counter: Dictionary, verdict: Dictionary) -> Dictionary:
	if not counter.is_empty():
		counter["code"] = str(verdict.get("code", ""))
	return counter


## A player's name, or a pick as `whose` ("your", "our", "their") would
## put it: "your 2027 second-round pick".
func _ask_name(id: String, whose := "your") -> String:
	if id.begins_with("pick:"):
		var pk := pick_asset(id)
		if pk.is_empty():
			return "a pick already made"
		if int(pk["year"]) == season_year and int(pk.get("spot", 0)) > 0 and draft_night_open():
			return "%s pick %d tonight" % [whose, int(pk["spot"])]   # the night's own words
		var nth: String = ["first", "second", "third", "fourth"][clampi(int(pk["round"]) - 1, 0, 3)]
		var from := "" if str(pk["origin"]) == str(pk["owner"]) else " (from %s)" % GameDB.club_name(str(pk["origin"]))
		return "%s %d %s-round pick%s" % [whose, int(pk["year"]), nth, from]
	return GameDB.player_display_name(_find_player(id))


## Clubs in an order that changes each year but not on a reload.
func _club_order(tag: String) -> Array:
	var out := []
	for code in GameDB.active_clubs(season_year):
		if code != my_club and season.lists.has(code):
			out.append(str(code))
	out.sort_custom(func(a, b): return hash([season_year, tag, a]) < hash([season_year, tag, b]))
	return out


## The off-season's trade market: rival clubs trade with each other where
## both come out ahead, then a few put offers to you.
func _open_trade_market() -> void:
	if my_club == "" or not season.lists.has(my_club):
		return
	# A mark on a player who has since left (retired, delisted, traded) goes.
	for id in untouchable.keys():
		if not my_list.any(func(q): return str(q["id"]) == str(id)):
			untouchable.erase(id)
	var prospects := trade_prospects()
	_freeze_league(true)
	_requested_trades(prospects)
	_ai_trades(prospects)
	_make_trade_offers(prospects)
	_freeze_league(false)


## What a club wants from another's list: the one player who'd walk into its
## side (a contender or builder: a clear upgrade, 31 or younger) or, for a
## rebuilder, a young player still growing who'd get a game. {} if nobody.
func _trade_target(club: String, from_list: Array, skip: Dictionary) -> Dictionary:
	var phase := club_phase(club)
	var bars := TradeValue.selection_bars(season.lists[club])
	var best := {}
	var best_v := 0.0
	for p in from_list:
		if skip.has(str(p["id"])):
			continue
		var age := float(p.get("age", 30.0))
		var wants := false
		if phase == "rebuilding":
			wants = age <= 23.0 and TradeValue.future_rating(p) >= TradeValue.now_rating(p) + 5.0 \
					and TradeValue.fit(p, bars) >= 0.8
		else:
			wants = age <= 31.0 and TradeValue.fit(p, bars) >= 1.15
		if not wants:
			continue
		var v := float(TradeValue.value(p, {"phase": phase, "bars": bars})["total"])
		if v > best_v:
			best_v = v
			best = p
	return best


## What `buyer` could offer, priced by itself alone: its picks and the
## players outside its best ten, singly and in pairs, each valued as the
## club would value giving it up - never by what the other side thinks.
## Only packages worth no more than `most` to it; cheapest first:
## [[assets, value], ...].
## `to`: the club the package would go to. Your challenge (Youth only,
## Rebuild) bars some players from coming to you, so a bid to you never
## includes them.
func _bids(buyer: String, most: float, prospects: Dictionary, to := "") -> Array:
	var phase := club_phase(buyer)
	var bars := TradeValue.selection_bars(season.lists[buyer])
	var proj := TradeValue.selection_bars(season.lists[buyer], true)
	var pool := []
	for pk in club_picks(buyer):
		pool.append([pk, TradeValue.pick_value(pk["positions"], prospects.get(str(pk["year"]), []), phase,
				int(pk["year"]) - season_year)])
	var night := draft_night_open()
	var list: Array = (season.lists[buyer] as Array).duplicate() if not night else []
	list.sort_custom(func(a, b):
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		return str(a["id"]) < str(b["id"]))
	for k in range(10, list.size()):
		var q: Dictionary = list[k]
		if trade_requests.has(str(q["id"])):
			continue  # he goes only where he asked to, not as a makeweight
		if retiring_now(q):
			continue  # he retires at the rollover: nobody to send
		if to == my_club and Challenge.block_reason(self, q) != "":
			continue  # your challenge bars him from coming to you
		pool.append([q, float(TradeValue.value(q, {"phase": phase, "bars": bars, "proj": proj, "own": true})["total"])])
	var out := []
	for i in range(pool.size()):
		var vi := float(pool[i][1])
		if vi <= 0.0:
			continue
		var idi := str(pool[i][0]["id"])
		if vi <= most:
			out.append([[pool[i][0]], vi, idi])
		for j in range(i + 1, pool.size()):
			var both := TradeValue.package([vi, float(pool[j][1])])   # priced as the other club prices it
			if float(pool[j][1]) > 0.0 and both <= most:
				out.append([[pool[i][0], pool[j][0]], both, idi + "," + str(pool[j][0]["id"])])
			if not night or float(pool[j][1]) <= 0.0:
				continue
			# On the night, picks are all a club can pay with: three may go together.
			for k in range(j + 1, pool.size()):
				var three := TradeValue.package([vi, float(pool[j][1]), float(pool[k][1])])
				if float(pool[k][1]) > 0.0 and three <= most:
					out.append([[pool[i][0], pool[j][0], pool[k][0]], three,
							idi + "," + str(pool[j][0]["id"]) + "," + str(pool[k][0]["id"])])
	out.sort_custom(func(x, y):
		if float(x[1]) != float(y[1]):
			return float(x[1]) < float(y[1])
		return str(x[2]) < str(y[2]))
	return out


## A club's opening bid for something it values at `worth`: the package
## nearest `shade` of the most it would pay (worth less its trading margin),
## that it would stand by. [] if it has nothing that fits.
func _bid(club: String, asset: Dictionary, worth: float, shade: float, prospects: Dictionary, other := "",
		margin := -1.0) -> Array:
	if other == "":
		other = my_club
	if margin < 0.0:
		margin = float(difficulty_rules()["trade_margin"])
	var most := worth / (1.0 + margin)
	var options := _bids(club, most, prospects, other)
	options.sort_custom(func(x, y):
		var dx := absf(float(x[1]) - shade * most)
		var dy := absf(float(y[1]) - shade * most)
		if dx != dy:
			return dx < dy
		return float(x[1]) < float(y[1]))
	for o in options.slice(0, 6):
		if bool(_club_verdict(club, other, o[0], [asset], margin, prospects)["ok"]):
			return o[0]
	return []


## Rival clubs trade with each other when both come out ahead by their own
## lights: a club with a real need and a player elsewhere who meets it (see
## _trade_pool for who is on offer). The buyer bids from its own valuation,
## cheapest first, and the seller takes the first bid it values enough -
## neither sees the other's sums. Turned down, the buyer tries its next
## target, up to TARGET_TRIES. Clubs keep dealing while such deals exist;
## a club whose turn finds no deal is out of that year's market;
## never with you; MAX_AI_TRADES a year is a runaway guard only.
func _ai_trades(prospects: Dictionary) -> void:
	var done := 0
	# Every club gets a turn as a buyer, one deal a turn, then the next pass:
	# no club buys twice before the rest have had their chance. The market
	# runs until a whole pass finds no deal both sides accept.
	var order := _club_order("ai_trades")
	var sellers := _club_order("sellers")
	var dealt := true
	var out := {}   # a club that finds no deal on its turn leaves the market
	while dealt and done < MAX_AI_TRADES:
		dealt = false
		for buyer in order:
			if done >= MAX_AI_TRADES:
				break
			if buyer == my_club or out.has(buyer):
				continue
			out[buyer] = true
			var others := []
			var club_of := {}
			for code in sellers:
				if code == my_club or code == buyer:
					continue
				for q in _trade_pool(buyer, code):
					others.append(q)
					club_of[str(q["id"])] = code
			var tried := {}
			for _try in range(TARGET_TRIES):
				var target := _trade_target(buyer, others, tried)
				if target.is_empty():
					break
				tried[str(target["id"])] = true
				var seller := str(club_of[str(target["id"])])
				var most := _worth_to(buyer, target, prospects) / (1.0 + Contracts.TRADE_MARGIN)
				var pkg := _negotiate(buyer, seller, target, _bids(buyer, most, prospects), prospects)
				if pkg.is_empty() or _trade_ban_breaks(buyer, seller, pkg, [target]):
					continue
				_log_ai_trade(buyer, seller, target, pkg, "")
				done += 1
				dealt = true
				out.erase(buyer)
				break


## Would this deal bring a player into a club the league has barred from
## trading players in (YearEvents)? `buyer` gets `got`, `seller` gets `pkg`.
func _trade_ban_breaks(buyer: String, seller: String, pkg: Array, got: Array) -> bool:
	for side in [[buyer, got], [seller, pkg]]:
		if not YearEvents.trade_banned(self, str(side[0])):
			continue
		for a in side[1]:
			if not Contracts.is_pick(a):
				return true
	return false


## A trade between two rival clubs: done, logged and in the news. `why`: the
## request it met ("home", "games") or "".
func _log_ai_trade(buyer: String, seller: String, target: Dictionary, pkg: Array, why: String) -> void:
	# Where each club stood when it dealt: a phase ranks a list against the
	# league's, so earlier trades can move it.
	var phases := [club_phase(buyer), club_phase(seller)]
	_execute_trade(buyer, seller, pkg, [target])
	var said := "%s get %s from %s for %s." % [GameDB.club_name(buyer),
			_names([target]), GameDB.club_name(seller), _names(pkg)]
	var row := {"kind": "ai_trade", "club": buyer, "with": seller,
			"in": [str(target["id"])], "out": pkg.map(func(a): return str(a["id"])), "text": said, "phases": phases}
	if why != "":
		row["request"] = why
	offseason_log.append(row)
	add_news("trade", "Trade: " + said)


## Trades a club has made with other rivals this off-season.
func _deals(club: String, night_only := false) -> int:
	if club == my_club:
		return DEALS_PER_CLUB
	var n := 0
	for e in offseason_log:
		if night_only and not bool(e.get("night", false)):
			continue
		if str(e.get("kind", "")) == "ai_trade" and (str(e["club"]) == club or str(e["with"]) == club):
			n += 1
	return n


# ---------------------------------------------------------------------------
# Trade requests (TradeRequests): players asking to go home, or for a game
# ---------------------------------------------------------------------------
## Each club's home state, for the clubs in this season.
func _club_states() -> Dictionary:
	var out := {}
	for code in GameDB.active_clubs(season_year):
		var s := str(TradeRequests.CLUB_STATES.get(str(code), ""))
		if s == "":
			s = str(GameDB.club(str(code)).get("state", ""))
		if s != "":
			out[str(code)] = s
	return out


## The season is over: who asks to be traded. Yours are in the news, and so
## is anyone who names your club.
func _collect_trade_requests() -> void:
	trade_requests = {}
	var states := _club_states()
	var bars := {}
	for code in states:
		if season.lists.has(code):
			bars[code] = TradeValue.selection_bars(season.lists[code])
	for code in states:
		if not season.lists.has(code):
			continue
		var side := {}
		for q in Ratings.select_22(season.lists[code])["ground"]:
			side[str(q["id"])] = true
		for p in season.lists[code]:
			var id := str(p["id"])
			var starts := []
			if not side.has(id):
				var keen := []
				for other in bars:
					var f := TradeValue.fit(p, bars[other])
					if other != code and f >= 1.0:
						keen.append([str(other), f])
				keen.sort_custom(func(a, b):
					if float(a[1]) != float(b[1]):
						return float(a[1]) > float(b[1])
					return str(a[0]) < str(b[0]))
				starts = keen.map(func(k): return str(k[0]))
			var games := int((season_tally.get(id, {}) as Dictionary).get("games", 0))
			var ask := TradeRequests.asks(p, str(code), season_year, states, starts, side.has(id), games)
			if ask.is_empty():
				continue
			ask["club"] = str(code)
			trade_requests[id] = ask
			if str(code) == my_club or (ask["to"] as Array).has(my_club):
				add_news("trade", _request_line(p, ask))


## The requests that concern you while trades are open: your players who
## have asked out, and players elsewhere who named your club. Player ids.
func my_trade_requests() -> Array:
	if not offseason_open():
		return []
	var out := []
	for id in trade_requests:
		var r: Dictionary = trade_requests[id]
		if str(r["club"]) == my_club or (r["to"] as Array).has(my_club):
			out.append(str(id))
	out.sort()
	return out


## A request in a line (see _request_line); "" if there is none.
func trade_request_line(id: String) -> String:
	if not trade_requests.has(id):
		return ""
	return _request_line(_find_player(id), trade_requests[id])


## "Jack Smith (Carlton) has asked to be traded home: Adelaide or Port
## Adelaide." / "... has asked for a trade to get a game: ..."
func _request_line(p: Dictionary, ask: Dictionary) -> String:
	var who := GameDB.player_display_name(p)
	var at := GameDB.club_name(str(ask["club"]))
	var names: Array = (ask["to"] as Array).map(func(c): return GameDB.club_name(str(c)))
	var to := str(names[-1]) if names.size() < 2 else ", ".join(names.slice(0, -1)) + " or " + str(names[-1])
	if str(ask["why"]) == "home":
		return "%s (%s) has asked to be traded home: %s." % [who, at, to]
	return "%s (%s) has asked for a trade to get a game: %s." % [who, at, to]


## A player who has asked out goes only to a club he named: the reason one
## of `assets` (from `from`) won't go to `to`, or "".
func _wont_go(assets: Array, to: String) -> String:
	for a in assets:
		if Contracts.is_pick(a) or not trade_requests.has(str(a["id"])):
			continue
		var ask: Dictionary = trade_requests[str(a["id"])]
		if not (ask["to"] as Array).has(to):
			return AiReasons.line("trade_asked_elsewhere", {"player": GameDB.player_display_name(a),
					"to": " or ".join((ask["to"] as Array).map(func(c): return GameDB.club_name(str(c))))})
	return ""


## Rival clubs a player asked to join try to get him first, each bidding by
## its own valuation; his club, knowing it can't keep him, takes less
## (TradeRequests.KEEP). Yours are left to you (offers come to you instead).
func _requested_trades(prospects: Dictionary) -> void:
	var ids := trade_requests.keys()
	ids.sort()
	for id in ids:
		if not trade_requests.has(id):
			continue  # met already
		var ask: Dictionary = trade_requests[id]
		var seller := str(ask["club"])
		if seller == my_club or _deals(seller) >= DEALS_PER_CLUB:
			continue
		var target := {}
		for q in season.lists.get(seller, []):
			if str(q["id"]) == str(id):
				target = q
		if target.is_empty():
			continue
		for buyer in ask["to"]:
			if str(buyer) == my_club or not season.lists.has(str(buyer)) or _deals(str(buyer)) >= DEALS_PER_CLUB:
				continue
			var most := _worth_to(str(buyer), target, prospects) / (1.0 + Contracts.TRADE_MARGIN)
			var pkg := _negotiate(str(buyer), seller, target, _bids(str(buyer), most, prospects), prospects)
			if pkg.is_empty() or _trade_ban_breaks(str(buyer), seller, pkg, [target]):
				continue
			_log_ai_trade(str(buyer), seller, target, pkg, str(ask["why"]))
			break


## Who `buyer` may go after at `seller`: the players outside its starting
## side, whom anyone can see aren't first picks there - and, for a contender
## buying from a rebuilding club, anyone on the list, as for you. A
## rebuilder's established players are on the market to every contender,
## not only to you; its own valuation still decides what it lets go.
func _trade_pool(buyer: String, seller: String) -> Array:
	var pool: Array = season.lists[seller] if club_phase(buyer) == "contending" \
			and club_phase(seller) == "rebuilding" else _fringe(seller)
	return pool.filter(func(q): return not retiring_now(q) and (not trade_requests.has(str(q["id"])) \
			or (trade_requests[str(q["id"])]["to"] as Array).has(buyer)))


## The players outside a club's starting side (its bench and beyond) - who
## anyone can see aren't first picks there. Worked out once per state of
## the league.
var _fringe_cache := {}


func _fringe(code: String) -> Array:
	var key := _league_fingerprint()
	if str(_fringe_cache.get("key", "")) != key:
		_fringe_cache = {"key": key}
	if not _fringe_cache.has(code):
		var ground := {}
		for q in Ratings.select_22(season.lists[code])["ground"]:
			ground[str(q["id"])] = true
		_fringe_cache[code] = (season.lists[code] as Array).filter(func(q): return not ground.has(str(q["id"])))
	return _fringe_cache[code]


## The buyer's best bid it would stand by goes to the seller first: its
## dearest, or failing that the next of a handful down the range (a package
## priced against its own list can still look a little dear once the whole
## trade is weighed). Turned down, there's no deal. Taken, the buyer works
## back down a handful of cheaper bids for the least the seller would still
## take. Each side judges only by its own valuation. [] when there's no deal.
func _negotiate(buyer: String, seller: String, target: Dictionary, bids: Array, prospects: Dictionary) -> Array:
	if bids.is_empty():
		return []
	var sells := func(pkg: Array) -> bool:
		return bool(_club_verdict(seller, buyer, [target], pkg, Contracts.TRADE_MARGIN, prospects)["ok"])
	var buys := func(pkg: Array) -> bool:
		return bool(_club_verdict(buyer, seller, pkg, [target], Contracts.TRADE_MARGIN, prospects)["ok"])
	var n := bids.size()
	var top := -1
	var tries := mini(NEGOTIATE_STEPS, n)
	for k in range(tries):
		var at := n - 1 - int(floor(float(k) * float(n - 1) / float(maxi(1, tries - 1))))
		if buys.call(bids[at][0]):
			top = at
			break
	if top < 0 or not sells.call(bids[top][0]):
		return []
	var steps := mini(6, top)
	for k in range(steps):
		var at := int(floor(float(k) * float(top) / float(maxi(1, steps))))
		var pkg: Array = bids[at][0]
		if sells.call(pkg) and buys.call(pkg):
			return pkg
	return bids[top][0]


## A few rival clubs with a real need put an offer to you: one of your
## players they want (see _trade_target), and an opening bid priced by their
## own valuation alone - nothing about what your club thinks him worth, so
## an offer can be well under it. At most MAX_OFFERS; an offer you turned
## down isn't made again the next year.
func _make_trade_offers(prospects: Dictionary) -> void:
	var asked := {}
	# Your players who have asked out: the first club he named that can
	# make an offer does. These don't count against MAX_OFFERS.
	var ids := trade_requests.keys()
	ids.sort()
	for id in ids:
		var ask: Dictionary = trade_requests[id]
		var p := _find_player(str(id))
		if str(ask["club"]) != my_club or p.is_empty():
			continue
		for club in ask["to"]:
			var key := "%s|%s" % [str(club), str(id)]
			if not season.lists.has(str(club)) or (trade_declined.has(key) and int(trade_declined[key]) >= season_year - 1):
				continue
			var pkg := _bid(str(club), p, _worth_to(str(club), p, prospects), UNASKED_BID, prospects)
			if pkg.is_empty():
				continue
			trade_offers.append({"club": str(club), "give": pkg.map(func(a): return str(a["id"])),
					"take": [str(id)], "status": "open", "request": true})
			asked[str(id)] = true
			add_news("trade", "%s have made an offer for %s." % [GameDB.club_name(str(club)), _names([p])])
			break
	var made := 0
	for club in _club_order("offers"):
		if made >= MAX_OFFERS:
			break
		var open := my_list.filter(func(q): return not untouchable.has(str(q["id"])) and (not trade_requests.has(str(q["id"])) \
				or (trade_requests[str(q["id"])]["to"] as Array).has(club)))
		var target := _trade_target(club, open, asked)
		if target.is_empty():
			continue
		var key := "%s|%s" % [club, str(target["id"])]
		if trade_declined.has(key) and int(trade_declined[key]) >= season_year - 1:
			continue
		var pkg := _bid(club, target, _worth_to(club, target, prospects), UNASKED_BID, prospects)
		if pkg.is_empty():
			continue
		trade_offers.append({"club": club, "give": pkg.map(func(a): return str(a["id"])),
				"take": [str(target["id"])], "status": "open"})
		asked[str(target["id"])] = true
		made += 1
		add_news("trade", "%s have made an offer for %s." % [GameDB.club_name(club), _names([target])])


## What a player or pick is worth to `club`, by the trade model: a pick as
## the prospect it expects; a player against its side as it stands. 0 for
## another club's player who wouldn't get a game there (unless the club is
## rebuilding and he is young and still growing).
func _worth_to(club: String, asset: Dictionary, prospects: Dictionary) -> float:
	var phase := club_phase(club)
	if Contracts.is_pick(asset):
		return TradeValue.pick_value(asset["positions"], prospects.get(str(asset["year"]), []), phase,
				int(asset["year"]) - season_year)
	var own := (season.lists[club] as Array).has(asset)
	var bars := TradeValue.selection_bars((season.lists[club] as Array).filter(func(q): return q != asset))
	var growing := phase == "rebuilding" and float(asset.get("age", 30.0)) <= 23.0 \
			and TradeValue.future_rating(asset) >= TradeValue.now_rating(asset) + 5.0
	if not own and TradeValue.fit(asset, bars) < 0.6 and not growing:
		return 0.0
	return float(TradeValue.value(asset, {"phase": phase, "bars": bars, "own": own})["total"])


## Put one of your players or picks on the trade table. Every rival values
## it for itself - its needs, its list, where it is in its cycle, its picks
## and cap - knowing nothing of what your club thinks it worth. The keenest,
## up to MAX_TABLE_OFFERS, bid from their own valuation: alone they open
## low, and the more genuine suitors there are the closer each goes to the
## most it would pay. Nobody may bid, and no fair return is promised. Once
## each an off-season.
## {"ok", "reason", "offers": how many came in}.
func put_on_trade_table(id: String) -> Dictionary:
	if not offseason_open():
		return {"ok": false, "reason": "The trade table is open in the off-season, not on draft night.", "offers": 0}
	if trade_table.has(id):
		return {"ok": false, "reason": "That's already on the trade table.", "offers": 0}
	if untouchable.has(id):
		return {"ok": false, "reason": "He's marked untouchable. Take the mark off to hear offers.", "offers": 0}
	var found := _trade_assets([id], my_club)
	if str(found["error"]) != "":
		return {"ok": false, "reason": str(found["error"]), "offers": 0}
	trade_table.append(id)
	var asset: Dictionary = found["assets"][0]
	var prospects := trade_prospects()
	_freeze_league(true)
	var keen := []
	for club in _club_order("table"):
		if _wont_go([asset], club) != "":
			continue
		var v := _worth_to(club, asset, prospects)
		if v > 0.0:
			keen.append([club, v])
	keen.sort_custom(func(a, b):
		if float(a[1]) != float(b[1]):
			return float(a[1]) > float(b[1])
		return str(a[0]) < str(b[0]))
	# Suitors: the keenest clubs that have something to offer.
	var suitors := []
	for row in keen.slice(0, 6):
		if not _bids(str(row[0]), float(row[1]) / (1.0 + float(difficulty_rules()["trade_margin"])), prospects, my_club).is_empty():
			suitors.append(row)
	var shade := UNASKED_BID + 0.1 * float(mini(suitors.size(), 3) - 1)
	var made := 0
	for row in suitors:
		if made >= MAX_TABLE_OFFERS:
			break
		var pkg := _bid(str(row[0]), asset, float(row[1]), shade, prospects)
		if pkg.is_empty():
			continue
		trade_offers.append({"club": str(row[0]), "give": pkg.map(func(a): return str(a["id"])),
				"take": [id], "status": "open", "table": true})
		made += 1
	_freeze_league(false)
	var what := _ask_name(id)
	if made > 0:
		add_news("trade", "On the trade table: %d club%s made an offer for %s." % [made, "" if made == 1 else "s", what])
	mark_dirty()
	var reason := "No club has made an offer for %s." % what
	if made == 1:
		reason = "One club has made an offer for %s." % what
	elif made > 1:
		reason = "%s clubs have made offers for %s." % [_count_word(made, true), what]
	return {"ok": true, "reason": reason, "offers": made}


## This year's list problem in three lines (P-48): who is out of contract,
## how old your best six are, and list spots against this year's picks. Facts
## only, no advice: the coach reads the brief.
func list_problem() -> Array:
	if season == null or my_club == "":
		return []
	var side: Array = my_list.duplicate()
	side.sort_custom(func(a, b):
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		return str(a["id"]) < str(b["id"]))
	var best22 := {}
	for q in side.slice(0, 22):
		best22[str(q["id"])] = true
	var out_of := Contracts.expiring(my_list).filter(func(q): return not retiring_now(q))
	var key := out_of.filter(func(q): return best22.has(str(q["id"]))).size()
	var first := "Nobody out of contract." if out_of.is_empty() else "%s out of contract, %s of them in your best 22." % [
			_count_word(out_of.size(), true), _count_word(key)]
	if not out_of.is_empty() and key == 0:
		first = "%s out of contract, none of them in your best 22." % _count_word(out_of.size(), true)
	var six := side.slice(0, 6)
	var ages := 0.0
	for q in six:
		ages += float(q.get("age", 25))
	var going := my_list.filter(func(q): return retiring_now(q)).size()
	var second := "Your best six average %d years old." % roundi(ages / float(maxi(1, six.size())))
	if going > 0:
		second += " %s retiring." % _count_word(going, true)
	return [first, second, draft_spots_line(going)]


## The brief's third line: senior list spots against this year's picks, and
## which picks pass when there are more picks than spots (the draft's own
## count, draft_list_spots). `going`: your players retiring at the rollover.
func draft_spots_line(going: int = -1) -> String:
	var s := draft_list_spots()
	if going < 0:
		going = int(s["retiring"])
	var spots := int(s["open"])
	var picks: Array = s["picks"]
	var line := "%s senior list spot%s, %s pick%s in the %d draft." % [_count_word(spots, true), "" if spots == 1 else "s",
			_count_word(picks.size()), "" if picks.size() == 1 else "s", season_year]
	if bool(s.get("by_44", false)):
		# The 44, not the senior list, sets the spots: say which count it is.
		line = "%s list spot%s (%d of %d on your senior and Category A rookie lists together), %s pick%s in the %d draft." % [
				_count_word(spots, true), "" if spots == 1 else "s", int(s["list"]), int(s["list_cap"]),
				_count_word(picks.size()), "" if picks.size() == 1 else "s", season_year]
	var passing: Array = s["passing"]
	if not passing.is_empty():
		line = line.trim_suffix(".") + ": %s %s will pass unless you delist before it starts." % [
				"pick" if passing.size() == 1 else "picks", Draft.picks_words(passing)]
	if going > 0:
		line += " Retiring players hold their spot until the draft is over."
	return line


## The National Draft's list spots for your club: the one count the brief,
## the draft button and the draft screen all read. Before the draft it is the
## senior list as it will stand when the draft opens - your senior list now,
## less the players free agency's close lets go or sends to the market
## (_fa_close_plan), plus this year's father-son and academy ties. Retiring
## players still hold their spot: they leave at the rollover, after the draft.
## On draft night it is the draft's own count (Draft.spots_plan).
## The 44 (senior and Category A rookie lists together) is counted beside the
## senior list by the same rule every signing uses (RookieList.add_block):
## "list" is that count, and "by_44" is true when it, not the senior list,
## sets the open spots. A father-son or academy player is counted only while
## the 44 has room for him.
## {"cap", "held", "open", "picks": [pick numbers, in order], "usable",
##  "passing", "retiring", "resign" (undecided players who re-sign as the
##  draft opens), "maybe" (players testing the market or holding your offer,
##  each of whom takes a spot if he signs with you), "ties", "live"}
func draft_list_spots() -> Dictionary:
	var out := {"cap": RookieList.senior_spots(), "held": 0, "open": 0, "picks": [], "usable": [],
			"passing": [], "retiring": 0, "resign": 0, "maybe": 0, "ties": 0, "live": false,
			"list": 0, "list_cap": Contracts.max_list(), "by_44": false}
	if season == null or my_club == "":
		return out
	out["retiring"] = my_list.filter(func(q): return retiring_now(q)).size()
	if draft != null and draft.intake_mode:
		var plan := draft.spots_plan(my_club)
		out["live"] = true
		out["cap"] = draft.list_cap()
		out["open"] = int(plan["open"])
		out["held"] = draft.list_cap() - int(plan["open"])
		out["usable"] = plan["usable"]
		out["passing"] = plan["passing"]
		out["picks"] = (plan["usable"] as Array) + (plan["passing"] as Array)
		out["list"] = draft.list_now(my_club)
		out["by_44"] = draft.full_at_44(my_club)
		return out
	var held := RookieList.senior_count(my_list)
	var in_44 := RookieList.list_size(my_list)
	var resign := 0
	var maybe := 0
	if fa_closed_year != season_year:
		for step in _fa_close_plan():
			var p: Dictionary = step[0]
			match str(step[1]):
				"test":
					maybe += 1
					if not RookieList.is_rookie(p):
						held -= 1
					if not RookieList.is_cat_b(p):
						in_44 -= 1
				"release":
					if not RookieList.is_rookie(p):
						held -= 1
					if not RookieList.is_cat_b(p):
						in_44 -= 1
				_:
					resign += 1
		for p in free_agents:
			if not _offer_of(p, my_club).is_empty():
				maybe += 1
	var ties := 0
	for p in draftee_pool:
		if not drafted_draftees.has(str(p["id"])) and str(p.get("tied_club", "")) == my_club \
				and int(p.get("draft_year", 0)) == season_year and in_44 + ties < Contracts.max_list():
			ties += 1
	held += ties
	in_44 += ties
	var picks := []
	for pk in club_picks(my_club):
		if int(pk["year"]) == season_year and int(pk.get("spot", 0)) > 0:
			picks.append(int(pk["spot"]))
	picks.sort()
	var open := maxi(0, mini(int(out["cap"]) - held, Contracts.max_list() - in_44))
	out["list"] = in_44
	out["by_44"] = Contracts.max_list() - in_44 < int(out["cap"]) - held
	out["held"] = held
	out["open"] = open
	out["resign"] = resign
	out["maybe"] = maybe
	out["ties"] = ties
	out["picks"] = picks
	out["usable"] = picks.slice(0, mini(open, picks.size()))
	out["passing"] = picks.slice(mini(open, picks.size()))
	return out


## The fewest players a club takes at the National Draft: three, or every pick
## it holds when it holds fewer (director, 2026-11-12, "Must make room").
const DRAFT_MIN_TAKE := 3

## How many more senior spots your club must open before the National Draft
## may start (0 when the rule is met): the picks you hold, up to three, less
## the spots open when it opens (draft_list_spots). Delisting a player or
## trading a pick away brings it down. Only a list that meets the rule passes
## its other picks.
func draft_room_short() -> int:
	var s := draft_list_spots()
	if bool(s["live"]):
		return 0
	return maxi(0, mini(DRAFT_MIN_TAKE, (s["picks"] as Array).size()) - int(s["open"]))


## The gate's line (director, 2026-11-12): "Clubs must take at least three
## players. Delist two to make room, or trade the picks." "" when met.
func draft_room_line() -> String:
	var n := draft_room_short()
	if n <= 0:
		return ""
	return "Clubs must take at least three players. Delist %s to make room, or trade the picks." % _count_word(n)


func _count_word(n: int, capital := false) -> String:
	var words := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
			"eleven", "twelve"]
	var w := str(words[n]) if n >= 0 and n < words.size() else str(n)
	return w.capitalize() if capital else w


## Ask around (P-50): every rival answers in one line whether it wants your
## player, from the same valuation it trades with. Nothing is offered or saved;
## the coach then opens the usual trade sheet with any club that answered.
## [{"club", "kind": "yes" | "more" | "no", "line", "mine", "theirs"}], keen
## clubs first, then by name. "mine"/"theirs" fill the trade sheet.
func ask_around(id: String) -> Array:
	if not offseason_open() or id.begins_with("pick:"):
		return []
	var found := _trade_assets([id], my_club)
	if str(found["error"]) != "":
		return []
	var asset: Dictionary = found["assets"][0]
	var who := GameDB.player_display_name(asset)
	var prospects := trade_prospects()
	var margin := float(difficulty_rules()["trade_margin"])
	var out := []
	_freeze_league(true)
	for club in _club_order("ask"):
		var name := GameDB.club_name(club)
		var row := {"club": club, "kind": "no", "line": "", "mine": [id], "theirs": []}
		var wont := _wont_go([asset], club)
		var worth := 0.0 if wont != "" else _worth_to(club, asset, prospects)
		if wont != "":
			row["line"] = "%s: not interested. %s" % [name, wont]
		elif worth <= 0.0:
			row["line"] = "%s: not interested. %s wouldn't get a game in their side." % [name, who]
		else:
			# The most it would give: the package nearest the full price it puts on him.
			var pkg := _bid(club, asset, worth, 1.0, prospects, "", margin)
			if not pkg.is_empty():
				row["kind"] = "yes"
				row["theirs"] = pkg.map(func(a): return str(a["id"]))
				row["line"] = "%s: interested. They'd give %s." % [name,
						" and ".join(pkg.map(func(a): return _ask_name(str(a["id"]), "their")))]
			else:
				# He's worth something to them, but less than anything they'd part with:
				# what else of yours would get their cheapest piece.
				var cheapest := _bids(club, INF, prospects, my_club)
				var counter := {}
				if not cheapest.is_empty():
					var theirs: Array = (cheapest[0][0] as Array).map(func(a): return str(a["id"]))
					if bool(evaluate_trade(club, [id], theirs)["ok"]):
						counter = {"mine": [id], "theirs": theirs, "straight": true}
						row["kind"] = "yes"
						row["theirs"] = theirs
						row["line"] = "%s: interested. They'd give %s." % [name,
								" and ".join(theirs.map(func(x): return _ask_name(str(x), "their")))]
					else:
						counter = _counter(club, [id], theirs)
					if not counter.is_empty() and not counter.has("straight"):
						row["kind"] = "more"
						row["mine"] = counter["mine"]
						row["theirs"] = counter["theirs"]
						var extra: Array = (counter["mine"] as Array).filter(func(x): return str(x) != id)
						row["line"] = "%s: interested, not on %s alone. For %s they'd want %s as well." % [name, who,
								" and ".join(theirs.map(func(x): return _ask_name(str(x), "their"))),
								" and ".join(extra.map(func(x): return _ask_name(str(x))))]
				if counter.is_empty():
					row["line"] = "%s: interested, but nothing they'd part with is a fair swap for %s alone." % [name, who]
		out.append(row)
	_freeze_league(false)
	var rank := {"yes": 0, "more": 1, "no": 2}
	out.sort_custom(func(a, b):
		if int(rank[a["kind"]]) != int(rank[b["kind"]]):
			return int(rank[a["kind"]]) < int(rank[b["kind"]])
		return GameDB.club_name(str(a["club"])) < GameDB.club_name(str(b["club"])))
	return out


## Ask their price's search: the first of `packages` ([pieces, value], cheapest
## first) that `takes` says yes to, as an index; -1 for none. The first
## ASK_PRICE_TRIES are always weighed; after them only packages worth up to
## ASK_PRICE_OVER of the price, and never more than ASK_PRICE_MOST in all.
static func ask_price_pick(packages: Array, price: float, takes: Callable) -> int:
	for i in range(mini(packages.size(), ASK_PRICE_MOST)):
		if i >= ASK_PRICE_TRIES and float(packages[i][1]) > price * ASK_PRICE_OVER:
			break
		if bool(takes.call(packages[i])):
			return i
	return -1


## Ask their price (row 67, 4.Q11): the other way from Ask around. Name a
## player at another club and it says what of yours it would take for him,
## from the same valuation it trades with. It weighs each of your picks and
## players as it would receive them (never one you marked untouchable) and
## names the package of up to ASK_PRICE_PIECES it values nearest its price
## that it would still accept. Nothing is offered or saved: the coach weighs
## the ask on the usual trade sheet. {"ok", "line", "mine", "theirs"}; ok
## false, with the reason in "line", when nothing of yours would do.
func ask_price(club: String, id: String) -> Dictionary:
	var theirs := [id]
	var name := GameDB.club_name(club)
	var none := {"ok": false, "line": "", "mine": [], "theirs": theirs}
	var found := _trade_assets(theirs, club)
	if str(found["error"]) != "":
		none["line"] = str(found["error"])
		return none
	var target: Dictionary = found["assets"][0]
	var who := _ask_name(id, "their")
	var prospects := trade_prospects()
	var phase := club_phase(club)
	var margin := float(difficulty_rules()["trade_margin"])
	_freeze_league(true)
	# Each of yours as they'd value receiving him alone, against their side
	# without the player they'd give up (Contracts.evaluate_trade's own sums).
	var remaining: Array = (season.lists[club] as Array).filter(func(q): return q != target)
	var bars := TradeValue.selection_bars(remaining)
	var proj := TradeValue.selection_bars(remaining, true)
	var games: Dictionary = trade_context(club)["games"]
	var pool := []
	for pk in club_picks(my_club):
		pool.append([str(pk["id"]), TradeValue.pick_value(pk["positions"], prospects.get(str(pk["year"]), []), phase,
				int(pk["year"]) - season_year)])
	if not draft_night_open():   # players never move on draft night
		for q in my_list:
			var qid := str(q["id"])
			if untouchable.has(qid) or retiring_now(q) or _wont_go([q], club) != "":
				continue
			pool.append([qid, float(TradeValue.value(q, {"phase": phase, "bars": bars, "proj": proj,
					"games": int(games.get(qid, -1))})["total"])])
	pool = pool.filter(func(a): return float(a[1]) > 0.0)
	# What they'd give up, and any refusal no package can answer (a closed
	# market, your challenge, a player who asked to go elsewhere).
	var price := -1.0
	var hard := ""
	# One piece can fail on list size or the cap; the first that reaches the
	# weighing gives the club's price.
	for a in pool:
		var v := evaluate_trade(club, [str(a[0])], theirs)
		if v.has("out"):
			price = float(v["out"]) * (1.0 + margin)
			break
		if str(v.get("code", "")) in ["trade_closed", "trade_night_picks_only", "trade_challenge",
				"trade_asked_elsewhere"]:
			hard = str(v["reason"])
			break
	var packages := []
	if price > 0.0:
		var n := pool.size()
		for i in range(n):
			packages.append([[i], float(pool[i][1])])
			for j in range(i + 1, n):
				packages.append([[i, j], TradeValue.package([pool[i][1], pool[j][1]])])
				if ASK_PRICE_PIECES < 3:
					continue
				for k in range(j + 1, n):
					packages.append([[i, j, k], TradeValue.package([pool[i][1], pool[j][1], pool[k][1]])])
		# Fitted one by one into their side a package is never worth more
		# than its pieces alone, so anything under the price can't do.
		packages = packages.filter(func(x): return float(x[1]) >= price)
		packages.sort_custom(func(x, y):
			if float(x[1]) != float(y[1]):
				return float(x[1]) < float(y[1])
			return str(x[0]) < str(y[0]))
	var mine := []
	var at := ask_price_pick(packages, price, func(x):
		return bool(evaluate_trade(club, (x[0] as Array).map(func(i): return str(pool[i][0])), theirs)["ok"]))
	if at >= 0:
		mine = (packages[at][0] as Array).map(func(i): return str(pool[i][0]))
	_freeze_league(false)
	if mine.is_empty():
		none["line"] = hard if hard != "" else "%s: nothing of yours they'd take for %s." % [name, who]
		return none
	return {"ok": true, "mine": mine, "theirs": theirs, "line": "%s would take %s for %s." % [name,
			" and ".join(mine.map(func(x): return _ask_name(str(x)))), who]}


## Offers still on the table: open, and everything in them still where it was.
func open_trade_offers() -> Array:
	var out := []
	for i in range(trade_offers.size()):
		var o: Dictionary = trade_offers[i]
		if str(o["status"]) != "open":
			continue
		if draft_night_open() and not bool(o.get("night", false)):
			continue   # the off-season's offers for players wait: lists are closed tonight
		if str(_trade_assets(o["give"], str(o["club"]))["error"]) != "" or str(_trade_assets(o["take"], my_club)["error"]) != "":
			o["status"] = "off"
			continue
		out.append(i)
	return out


## The offer in words: "Collingwood offer Lachlan Rogers and their 2028
## second-round pick for Toby Chapman."
func trade_offer_text(i: int) -> String:
	var o: Dictionary = trade_offers[i]
	var club := str(o["club"])
	var give := []
	for id in o["give"]:
		give.append(_ask_name(str(id), "their"))
	var take := []
	for id in o["take"]:
		take.append(_ask_name(str(id)))
	return "%s offer %s for %s." % [GameDB.club_name(club), " and ".join(give), " and ".join(take)]


func accept_trade_offer(i: int) -> Dictionary:
	if not open_trade_offers().has(i):
		return {"ok": false, "reason": "That offer is off the table."}
	var o: Dictionary = trade_offers[i]
	var r := make_trade(str(o["club"]), o["take"], o["give"])
	o["status"] = "accepted" if bool(r["ok"]) else "off"
	# Your challenge's own reason stands; anything else means they moved on.
	if not bool(r["ok"]) and str(r.get("code", "")) != "trade_challenge":
		r["reason"] = "%s have moved on: the offer is off." % GameDB.club_name(str(o["club"]))
	mark_dirty()
	return r


func decline_trade_offer(i: int) -> void:
	if not open_trade_offers().has(i):
		return
	var o: Dictionary = trade_offers[i]
	o["status"] = "declined"
	for id in o["take"]:
		trade_declined["%s|%s" % [str(o["club"]), str(id)]] = season_year
	var names := []
	for id in o["take"]:
		names.append(_ask_name(str(id)))
	offseason_log.append({"kind": "offer_declined", "club": str(o["club"]), "take": (o["take"] as Array).duplicate(),
			"text": "You turned down %s's offer for %s." % [GameDB.club_name(str(o["club"])), " and ".join(names)]})
	mark_dirty()


## Assets change hands between two clubs (dicts from _trade_assets or
## pick_asset); your selection loses anyone who leaves.
func _execute_trade(a: String, b: String, a_gives: Array, b_gives: Array) -> void:
	# What each side gave, as the other side will remember it (pick_story).
	var a_gave := _trail_assets(a_gives)
	var b_gave := _trail_assets(b_gives)
	for x in a_gives:
		_move_asset(x, a, b)
		_note_pick_got(x, a, b, b_gave)
	for x in b_gives:
		_move_asset(x, b, a)
		_note_pick_got(x, b, a, a_gave)
	for x in a_gives + b_gives:
		trade_requests.erase(str(x["id"]))
		if not Contracts.is_pick(x):
			untouchable.erase(str(x["id"]))   # he is no longer yours to protect
	if _frozen_fingerprint != "":
		_freeze_league(true)
	var leaving := a_gives if a == my_club else (b_gives if b == my_club else [])
	# The stored selection itself (my_selection() is a copy without the
	# dual-ruck call).
	var stored: Dictionary = season.selections.get(my_club, {}) if season != null else {}
	for sel_key in ["RUCK", "MID", "WING", "DEF", "FWD", "BENCH", "OUT"]:
		var sel := stored
		if sel.has(sel_key):
			for p in leaving:
				(sel[sel_key] as Array).erase(str(p["id"]))
	OwnProspect.check(self)
	mark_dirty()


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
## undecided players are settled - a depth player re-signs if the cap allows,
## one of your best 23 tests the market (_market_test) - rivals sign who they
## want, and anyone left unsigned retires. Once per off-season.
func _close_free_agency() -> void:
	if season == null or fa_closed_year == season_year:
		return
	open_offseason()
	fa_closed_year = season_year
	var testing := []
	for step in _fa_close_plan():
		var p: Dictionary = step[0]
		var talks: Dictionary = p.get("talks", {})
		var told := talks.has("refused")
		if str(step[1]) == "release" and not bool(talks.get("walked", false)) and resign_refused(p):
			refuse_resign(p, Contracts.REFUSED_GOES)
			told = true
		match str(step[1]):
			"resign1":
				_resign(p, 1)
			"resign2":
				_resign(p, 2)
			"test":
				_release(my_club, p, true, false)
				testing.append(p)
			_:
				# He walked or refused you, or you could not fit him: you wanted
				# him, as a rival that runs out of room does. A refusal already
				# said so in the news.
				_release(my_club, p, true, not told)
				HonourBoard.leave(self, p, "free_agent")
	_market_test(testing)
	_resolve_market()
	# Nobody signed them: their AFL careers end here, except the best of the
	# young ones (_fa_staying), who stay in the pool for the Rookie Draft and
	# the mid-season draft. One of yours who went out of contract left as a
	# free agent; one you let go keeps his delisting.
	var staying := _fa_staying()
	for p in free_agents:
		HonourBoard.leave(self, p, "free_agent")
		if staying.has(p):
			p["fa_kept"] = season_year
			for key in ["offers", "market_round", "market_log", "talks"]:
				p.erase(key)
		else:
			_career_over(p, "delisted")
	free_agents = staying
	mark_dirty()


## Under this age an unsigned free agent stays in the pool one more year (the
## director, 2026-11-11: the mid-season draft had nobody to take), and the
## most who stay: the best rated, younger first, then id.
const FA_STAYS_UNDER := 26.0
const FA_STAYS_MAX := 12


## The unsigned free agents who stay available when free agency closes.
func _fa_staying() -> Array:
	var young := []
	for p in free_agents:
		if float(p.get("age", 30.0)) < FA_STAYS_UNDER and not retiring_now(p):
			young.append(p)
	young.sort_custom(func(a, b):
		if int(a.get("overall", 0)) != int(b.get("overall", 0)):
			return int(a.get("overall", 0)) > int(b.get("overall", 0))
		if float(a.get("age", 25.0)) != float(b.get("age", 25.0)):
			return float(a.get("age", 25.0)) < float(b.get("age", 25.0))
		return str(a["id"]) < str(b["id"]))
	return young.slice(0, FA_STAYS_MAX)


## How free agency's close will settle your undecided players, worked out
## without changing anything: [[player, "resign1" | "resign2" | "test" |
## "release"]], in order. A depth player re-signs if the cap allows, one of
## your best 23 tests the market, one who walked, refuses to re-sign with you
## (resign_refused) or does not fit is let go (at the list minimum he re-signs
## instead). _close_free_agency runs this
## plan and draft_list_spots counts it, so the two never disagree.
func _fa_close_plan() -> Array:
	var plan := []
	if season == null:
		return plan
	var best22 := {}
	var side := Ratings.select_22(my_list)
	for q in (side["ground"] as Array) + (side["bench"] as Array):
		best22[str(q["id"])] = true
	# Cap room as you settle them: a standing offer is money you have set
	# aside, so whoever takes yours can always be paid.
	var room := cap_for(my_club) - my_payroll()
	var size := my_list.size()
	for p in Contracts.expiring(my_list):
		if bool(p.get("resigned", false)) or retiring_now(p):
			continue
		var walked := bool(p.get("talks", {}).get("walked", false)) or resign_refused(p)
		if walked and size <= Contracts.min_list():
			plan.append([p, "resign1"])
			continue
		var rise := Contracts.asking_salary(p) - int(p.get("salary", 0))
		var fits := rise <= room
		# Before free agency (Legacy, to 2011) one of your best 23 re-signs:
		# there is no market for him to test.
		if not walked and fits and best22.has(str(p["id"])) and size > Contracts.min_list() 				and EraRules.on("free_agency"):
			plan.append([p, "test"])
			size -= 1
			room -= rise
		elif not walked and (fits or size <= Contracts.min_list()):
			plan.append([p, "resign2"])
			room -= rise
		else:
			plan.append([p, "release"])
			size -= 1
	return plan


## One of your best 23 you never settled tests the market as free agency
## closes, as an out-of-contract player does: your standing offer is his
## asking price over the term he wants, rivals make theirs, and those your
## offer leads answer once; then he takes the offer he likes best
## (_resolve_market) - money, security, his role and how the club finished.
## Nobody in your best 23 re-signs just because you did nothing.
func _market_test(players: Array) -> void:
	if players.is_empty():
		return
	_open_market(players)
	for p in players:
		var want := Contracts.wants(p)
		_add_offer(p, my_club, {"salary": int(want["salary"]), "years": int(want["years"])},
				fa_role(p, my_club), _finish_t(my_club))
		var mine := _offer_of(p, my_club)
		if Contracts.best_offer(p, p.get("offers", [])) == mine:
			p["market_log"] = _rival_round(p, mine)
		p["market_round"] = Contracts.FA_ROUNDS
		p["tested"] = true


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
## Your chosen side, or {} when the best 23 are picked automatically.
func my_selection() -> Dictionary:
	if season == null:
		return {}
	var sel: Dictionary = (season.selections.get(my_club, {}) as Dictionary).duplicate(true)
	sel.erase("DUAL_RUCK")
	sel.erase("TRIAL")   # a role trial's note, not a side you named
	return sel


## Set your side ({} = auto-pick every week). Stored on the season, so it is
## saved with the career and used by every one of your matches.
func set_selection(selection: Dictionary) -> void:
	if season == null:
		return
	var keep := selection.duplicate(true)
	keep["DUAL_RUCK"] = user_dual_ruck
	season.selections[my_club] = keep
	_trial_after_coach_pick(keep)
	_settle_answered_run_asks()
	mark_dirty()


## A card this week asking for a player's chance (a run of games) whose player
## you have since named in the side: he has his game, so the question no longer
## stands (director, 2026-11-10: "often theyre already in the team"). It closes
## as unanswered without its cost; his wait before he asks again still runs.
## A card about something else that also offers him a run (the papers' tip, an
## international learning the game) keeps its other choices and loses that one
## (director, 2026-11-12: "the game is asking if i wanna give a run of games to
## a player already in the team").
func _settle_answered_run_asks() -> void:
	for c in week_events:
		_settle_run_ask(c)


## _settle_answered_run_asks for one card (a week's card or the papers').
func _settle_run_ask(card: Dictionary) -> void:
	if card.is_empty() or bool(card.get("resolved", false)):
		return
	var p := list_player(str(card.get("player_id", "")))
	if p.is_empty() or not in_current_side(p):
		return
	# A card about a picked player (a captain's slump) means its run for him: it stays.
	var t := StoryDeck.by_id(StoryDeck.all(), str(card.get("tid", "")))
	var where: Dictionary = (t.get("subject", {}) as Dictionary).get("where", {})
	if where.has("selected") and bool(where["selected"]):
		return
	var options: Array = card.get("options", [])
	var keep := []
	var d := int(card.get("default", -1))
	var new_d := -1
	for i in range(options.size()):
		var runs := false
		for e in ((options[i] as Dictionary).get("effects", []) as Array):
			if str((e as Dictionary).get("op", "")) == "start_backing":
				runs = true
		if runs:
			continue
		if i == d:
			new_d = keep.size()
		keep.append(options[i])
	if keep.size() == options.size():
		return
	var asks_run := where.has("selected") and not bool(where["selected"])
	if not asks_run and not keep.is_empty():
		card["options"] = keep
		card["default"] = new_d
		mark_dirty()
		return
	card["resolved"] = true
	card["choice"] = -1
	card["outcome"] = "%s is in the side this week: he has his game." % GameDB.player_display_name(p)
	StoryEngine.record_choice(story, card, -1, story_week())
	mark_dirty()


# ---------------------------------------------------------------------------
# Role trial (a story card: "Try him in a new role")
# ---------------------------------------------------------------------------
const TRIAL_LINES := ["RUCK", "MID", "WING", "DEF", "FWD"]


## The line a selection names him in (WING is a midfield line), or "".
static func _line_of(sel: Dictionary, id: String) -> String:
	for line in TRIAL_LINES:
		if (sel.get(line, []) as Array).has(id):
			return line
	return ""


## Is `line` where the trial puts him? (The wing counts as midfield.)
static func _in_trial_line(line: String, want: String) -> bool:
	return line == want or (line == "WING" and want == "MID")


## Move one player into another line of a side: into a free place, else in
## place of the last man there, who takes his old place.
static func _move_in_sel(sel: Dictionary, id: String, target: String) -> void:
	var line := _line_of(sel, id)
	if line == "" or line == target:
		return
	var cap := 5 if target == "MID" else (1 if target == "RUCK" else (2 if target == "WING" else 6))
	if target == "MID":
		cap -= (sel.get("WING", []) as Array).size()
	var from: Array = sel[line]
	var at := from.find(id)
	var into: Array = sel.get(target, [])
	if into.size() < cap:
		from.remove_at(at)
		into.append(id)
	else:
		var other = into[into.size() - 1]
		into[into.size() - 1] = id
		from[at] = other
	sel[line] = from
	sel[target] = into


## The coach tries him in his second position for `games` of his matches
## (director, 2026-10-13: "three games, then home"). With the auto-pick, the
## pick itself plays him there (a TRIAL note on the club's selection, which
## Ratings.select_side reads); with a side you named, he is moved into that
## line. Swapping other players does not end it; moving HIM by hand does
## (_trial_after_coach_pick). Only matches he plays count (_note_trial_game).
## When it ends he goes back to the line he was picked in (_end_role_trial) and
## the result comes as a card (_finish_role_trial). Returns what to tell the
## coach, "" when there is no trial: no second position, not on the ground, or
## already picked there. `even_there` starts it for a player already picked in
## that line (games you promised him: they are counted all the same).
func start_role_trial(p: Dictionary, games: int, role := "", even_there := false) -> String:
	var role2 := ClubStories.trial_role(p) if role == "" else role
	if role2 == "" or season == null:
		return ""
	var id := str(p["id"])
	var now := _line_of(current_side(), id)
	var there := _in_trial_line(now, role2)
	if now == "" or (there and not even_there):
		return ""
	if not role_trial.is_empty():
		_end_role_trial(true)
	var sel := my_selection()
	var trial := {"id": id, "role": role2, "left": games, "home": now, "auto": sel.is_empty(), "ratings": []}
	var stored: Dictionary = (season.selections.get(my_club, {}) as Dictionary).duplicate(true)
	if sel.is_empty():
		stored["TRIAL"] = {id: role2}
	else:
		_move_in_sel(sel, id, role2)
		stored = sel.duplicate(true)
		stored["DUAL_RUCK"] = user_dual_ruck
	season.selections[my_club] = stored
	role_trial = trial
	mark_dirty()
	if there:
		return "%s plays his next %s games as a %s." % [GameDB.player_display_name(p), MatchNotes.count_word(games),
				CoachPathway.position_word({"pos": role2})]
	return "%s plays as a %s for the next %s games, then goes back." % [GameDB.player_display_name(p),
			CoachPathway.position_word({"pos": role2}), MatchNotes.count_word(games)]


## He took the field in one of your matches: the trial counts it, and after the
## last game ends with the result. Games he misses (injured, not picked) do
## not count.
func _note_trial_game(id: String, rating: int) -> void:
	if role_trial.is_empty() or str(role_trial.get("id", "")) != id:
		return
	var rs: Array = role_trial.get("ratings", [])
	rs.append(rating)
	role_trial["ratings"] = rs
	role_trial["left"] = int(role_trial.get("left", 0)) - 1
	if int(role_trial["left"]) <= 0:
		_finish_role_trial()


## The league's average Player Rating for the players who started in `role`
## this season, a whole number; 0 when none have yet.
func position_average(role: String) -> int:
	var row: Array = pos_ratings.get(role, [0, 0])
	if int(row[1]) <= 0:
		return 0
	return int(round(float(row[0]) / float(row[1])))


## Every starter of a league match goes into the season's position averages.
func _note_position_ratings(res: Dictionary) -> void:
	var roster: Array = res.get("roster", [])
	var players: Dictionary = res.get("players", {})
	for side in range(mini(2, roster.size())):
		var r: Array = roster[side]
		for i in range(mini(18, r.size())):
			var role := str((r[i] as Dictionary).get("role", ""))
			if role == "":
				continue
			var row: Array = pos_ratings.get(role, [0, 0])
			row[0] = int(row[0]) + MatchNotes.rating(players.get(str((r[i] as Dictionary)["id"]), {}))
			row[1] = int(row[1]) + 1
			pos_ratings[role] = row


## The three games are played: his average Player Rating over them against
## the league average for the position (director, 2026-10-13: measured against
## players in that position, not his own old one). A pass starts his training
## in that position, three weeks in already. The result waits for next week's
## cards (trial_result).
func _finish_role_trial() -> void:
	var p := list_player(str(role_trial.get("id", "")))
	if p.is_empty():
		_end_role_trial(false)
		return
	var role := str(role_trial.get("role", ""))
	var rs: Array = role_trial.get("ratings", [])
	var total := 0
	for x in rs:
		total += int(x)
	var avg := int(round(float(total) / float(maxi(1, rs.size()))))
	var par := position_average(role)
	var ok := avg >= par
	var trained := ok and _start_trial_training(p, role)
	trial_result = {"id": str(p["id"]), "role": role, "word": CoachPathway.position_word({"pos": role}),
			"avg": avg, "par": par, "ok": ok, "trained": trained}
	# The games you promised him in a development talk (T5.r93): kept.
	if role_trial.has("promised"):
		trial_result["promised"] = int(role_trial["promised"])
		var t := _dev_owed(p)
		if not t.is_empty():
			t["state"] = "kept"
			_dev_talk_out(p, "kept")
			p.erase("expects_game")
	_end_role_trial(true)


const TRIAL_TRAINING_WEEKS := 3


## After a pass: his training goes into the new position, three weeks done
## (the learning project). False when the project's own limits stop it
## (already learning something, the club's two at once, one a season) or the
## position has no job for him.
func _start_trial_training(p: Dictionary, role: String) -> bool:
	var job := learn_job_for(p, role)
	if job == "" or project_job(p) != "" or active_projects() >= PROJECT_MAX \
			or int(p.get("project_year", 0)) == season_year:
		return false
	p["train_plan"] = LEARN_PREFIX + job
	_start_project(p, job)
	(p["project"] as Dictionary)["weeks"] = TRIAL_TRAINING_WEEKS
	return true


## The trial is over: he goes back to the line he was picked in. A TRIAL note
## goes; in a side you named he is moved home if he is still in the trial line
## (if you moved him yourself the trial had already ended).
func _end_role_trial(restore: bool) -> void:
	if role_trial.is_empty():
		return
	if season != null:
		var stored: Dictionary = (season.selections.get(my_club, {}) as Dictionary).duplicate(true)
		if stored.has("TRIAL"):
			stored.erase("TRIAL")
			season.selections[my_club] = stored
		elif restore and not bool(role_trial.get("auto", false)):
			var sel := my_selection()
			var id := str(role_trial.get("id", ""))
			var home := str(role_trial.get("home", ""))
			if home != "" and _in_trial_line(_line_of(sel, id), str(role_trial.get("role", ""))):
				_move_in_sel(sel, id, home)
				sel["DUAL_RUCK"] = user_dual_ruck
				season.selections[my_club] = sel
	role_trial = {}
	mark_dirty()


## You picked a side yourself: if he is still in the trial line (you moved
## other players), the trial runs on; if you moved him, it is over and
## nothing is put back.
func _trial_after_coach_pick(sel: Dictionary) -> void:
	if role_trial.is_empty():
		return
	# No side named (the match-day staff pick it, as Sim the week's "runs for the
	# kids" does): the trial goes on and they place him, as when it began that way.
	var named := sel.duplicate()
	named.erase("DUAL_RUCK")
	if named.is_empty():
		role_trial["auto"] = true
		return
	var line := _line_of(sel, str(role_trial.get("id", "")))
	if _in_trial_line(line, str(role_trial.get("role", ""))):
		role_trial["auto"] = false
	else:
		var promised := role_trial.has("promised")
		var who := list_player(str(role_trial.get("id", "")))
		role_trial = {}
		# Moved out of the games you promised him there (T5.r93): the promise breaks.
		if promised and not who.is_empty() and not _dev_owed(who).is_empty():
			_dev_promise_broken(who, _dev_owed(who), true)


## Dual ruck (ARD-M5-001, director 2026-10-06): your second ruck takes the
## fifth interchange spot. Your call, off until you make it; AI clubs decide
## by their own rule (Ratings.select_22).
func dual_ruck() -> bool:
	return user_dual_ruck


func set_dual_ruck(on: bool) -> void:
	user_dual_ruck = on
	_sync_dual()
	mark_dirty()


## Your club's selection carries your dual-ruck call, so its auto-pick never
## falls under the AI clubs' rule.
func _sync_dual() -> void:
	if season == null or my_club == "":
		return
	var sel: Dictionary = (season.selections.get(my_club, {}) as Dictionary).duplicate(true)
	sel["DUAL_RUCK"] = user_dual_ruck
	season.selections[my_club] = sel


## The side that would take the field this week, as a selection.
func current_side() -> Dictionary:
	var squad := my_squad()
	return _as_selection(squad.ground, squad.bench)


func _as_selection(ground: Array, bench: Array) -> Dictionary:
	var out := {"RUCK": [], "MID": [], "WING": [], "DEF": [], "FWD": [], "BENCH": []}
	for p in ground:
		var key := "WING" if Roles.on_wing(p) else str(p["role"])
		(out[key] as Array).append(str(p["id"]))
	for p in bench:
		(out["BENCH"] as Array).append(str(p["id"]))
	return out


## Auto-pick strategies for the team builder (director, 2026-10-07). Each
## returns {"side": selection, "note": what changed, in words}; applying one
## is the builder's job, and your later moves stay yours until you choose
## again.
##   best   the best available side by rating and position (as rival clubs pick)
##   rest   the same with anyone who needs a break left out, if the list can
##          cover him
##   youth  the best side, then up to three young players (21 and under) in
##          for the lowest-rated older starter in their line, when within 6 of him
##   mine   your saved Best 23, with anyone unavailable replaced by the best
##          available player of his line
const YOUTH_AGE := 21
const YOUTH_GAP := 6
const YOUTH_MAX := 3


func auto_pick(strategy: String) -> Dictionary:
	var r := _auto_pick(strategy)
	if (r["side"] as Dictionary).is_empty():
		return r
	# A player you promised a game stays in, whatever the pick (select_22 does
	# the same): the lowest-rated man of his line who is not owed one makes way.
	var kept: PackedStringArray = []
	for p in my_list:
		if not _promised_game(p) or not Ratings.available(p):
			continue
		var swap := _swap_in((r["side"] as Dictionary).duplicate(true), p)
		if not (swap.get("sel", {}) as Dictionary).is_empty():
			r["side"] = swap["sel"]
			var out: Dictionary = swap.get("out", {})
			kept.append(GameDB.player_display_name(p) + ((" for %s" % GameDB.player_display_name(out)) if not out.is_empty() else ""))
	if not kept.is_empty():
		r["note"] = "%s Kept in as promised: %s." % [str(r["note"]), ", ".join(kept)]
	return r


func _auto_pick(strategy: String) -> Dictionary:
	var pool: Array = my_list.filter(func(p): return Ratings.available(p))
	var dual := 1 if user_dual_ruck else 0
	match strategy:
		"rest":
			# A player you promised a game is not rested out of it.
			var tired: Array = pool.filter(func(p): return Workload.value(p) >= Workload.NEEDS_BREAK and not _promised_game(p))
			var fresh: Array = pool.filter(func(p): return Workload.value(p) < Workload.NEEDS_BREAK or _promised_game(p))
			var sel := Ratings.select_22(fresh if fresh.size() >= (18 + Ratings.bench()) else pool, dual)
			var side := _as_selection(sel["ground"], sel["bench"])
			var rested: PackedStringArray = []
			var in_side := _ids_in(side)
			for p in tired:
				if not in_side.has(str(p["id"])):
					rested.append(GameDB.player_display_name(p))
			var note := "Rested: %s." % ", ".join(rested) if not rested.is_empty() \
					else "Nobody needs a break. This is our best side."
			if not tired.is_empty() and fresh.size() < (18 + Ratings.bench()):
				note = "Not enough fresh players to rest anyone. This is our best side."
			return {"side": side, "note": note}
		"youth":
			var sel2 := Ratings.select_22(pool, dual)
			return blood_youth(_as_selection(sel2["ground"], sel2["bench"]), pool)
		"mine":
			if best23.is_empty():
				return {"side": {}, "note": "No saved Best 23 yet. Set a side and save it."}
			var side3: Dictionary = best23.duplicate(true)
			var by_id3 := {}
			for p in my_list:
				by_id3[str(p["id"])] = p
			var swaps: PackedStringArray = []
			for line in ["RUCK", "MID", "WING", "DEF", "FWD", "BENCH"]:
				var arr3: Array = side3.get(line, [])
				for i in range(arr3.size()):
					var id3 := str(arr3[i])
					var p3 = by_id3.get(id3)
					if p3 != null and Ratings.available(p3):
						continue
					var role3: String = "MID" if line in ["WING", "BENCH"] else line
					var used3 := _ids_in(side3)
					var best3 = null
					for q in pool:
						if used3.has(str(q["id"])) or (line != "BENCH" and not Ratings.plays_role(q, role3)):
							continue
						if best3 == null or int(q["overall"]) > int(best3["overall"]):
							best3 = q
					if best3 != null:
						arr3[i] = str(best3["id"])
						swaps.append("%s in for %s" % [GameDB.player_display_name(best3),
								GameDB.player_display_name(p3) if p3 != null else "a departed player"])
			return {"side": side3, "note": ("Our Best 23. Replacing unavailable players: %s." % "; ".join(swaps)) if not swaps.is_empty()
					else "Our Best 23."}
	var sel4 := Ratings.select_22(pool, dual)
	return {"side": _as_selection(sel4["ground"], sel4["bench"]), "note": "Best side by rating and position."}


## The youth pick on `side_in`: up to YOUTH_MAX young players (YOUTH_AGE and
## under) from `pool`, each in for the lowest-rated older starter of a line
## he plays, when within YOUTH_GAP of him. Returns {"side", "note"}.
func blood_youth(side_in: Dictionary, pool: Array) -> Dictionary:
	var side2: Dictionary = side_in.duplicate(true)
	var by_id := {}
	for p in pool:
		by_id[str(p["id"])] = p
	# Blooding brings young players in for older ones: a youngster who came
	# in is never the next one out, a man swapped out never comes back, and
	# nobody young is dropped, so each swap is a real change and the note
	# names only what changed.
	var brought: Array = []
	var dropped: Array = []
	for _n in range(YOUTH_MAX):
		var used := _ids_in(side2)
		var best_swap := []
		for line in ["DEF", "MID", "WING", "FWD"]:
			var weakest := ""
			for id in side2[line]:
				var w = by_id.get(str(id))
				if w == null or brought.has(str(id)) or is_young(w) or _keeps_place(w):
					continue
				if weakest == "" or int(w["overall"]) < int(by_id[weakest]["overall"]):
					weakest = str(id)
			if weakest == "":
				continue
			var role: String = "MID" if line == "WING" else line
			for p in pool:
				var pid := str(p["id"])
				if used.has(pid) or brought.has(pid) or dropped.has(pid) or not is_young(p) \
						or not Ratings.plays_role(p, role):
					continue
				var gap := int(by_id[weakest]["overall"]) - int(p["overall"])
				if gap <= YOUTH_GAP and (best_swap.is_empty() or int(p["overall"]) > int(by_id[str(best_swap[2])]["overall"])):
					best_swap = [line, weakest, pid]
		if best_swap.is_empty():
			break
		var arr: Array = side2[best_swap[0]]
		arr[arr.find(best_swap[1])] = best_swap[2]
		dropped.append(str(best_swap[1]))
		brought.append(str(best_swap[2]))
	# A youngster in for the full-back is not the full-back: the line is
	# laid out again so the key posts stay with key players.
	if not brought.is_empty():
		for line in ["DEF", "FWD"]:
			var ids: Array = side2[line]
			if ids.all(func(id): return by_id.has(str(id))):
				var laid := Roles.key_post_order(ids.map(func(id): return by_id[str(id)]), line)
				side2[line] = laid.map(func(p): return str(p["id"]))
	return {"side": side2, "note": _blooding_note(brought, dropped, by_id) if not brought.is_empty()
			else "No young player is close enough to take a senior spot. This is our best side."}


## Young for this pick: YOUTH_AGE or under in whole years, as the game shows
## age (a player of 21.6 shows as 21), so a 21-year-old is never dropped.
static func is_young(p: Dictionary) -> bool:
	return int(floor(float(p.get("age", 30.0)))) <= YOUTH_AGE


## The longest blooding note, in characters: two lines of the note at the
## 390 px phone width (about 4.8 px a character over 358 px a line).
const BLOODING_NOTE_MAX := 130


## The youth pick in one sentence, each young player named with the man he
## replaces, the same way for one or three: "Blooding Harry Armstrong for Ben
## Smith." / "Blooding Harry Armstrong for Ben Smith and Josh Dolan for Tom
## Jones." Surnames when full names would run past two lines.
static func _blooding_note(brought: Array, dropped: Array, by_id: Dictionary) -> String:
	var note := _blooding_pairs(brought, dropped, by_id, false)
	if note.length() > BLOODING_NOTE_MAX:
		note = _blooding_pairs(brought, dropped, by_id, true)
	return note


static func _blooding_pairs(brought: Array, dropped: Array, by_id: Dictionary, surnames: bool) -> String:
	var name := func(p: Dictionary) -> String:
		return GameDB.card_surname(p) if surnames else GameDB.player_display_name(p)
	var pairs: Array = []
	for i in range(brought.size()):
		pairs.append("%s for %s" % [name.call(by_id[brought[i]]), name.call(by_id[dropped[i]])])
	return "Blooding %s." % _and_list(pairs)


static func _and_list(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


func _ids_in(side: Dictionary) -> Dictionary:
	var out := {}
	for k in side:
		for id in side[k]:
			out[str(id)] = true
	return out


## "Complete synergy" (director, 2026-10-07): the fewest swaps that switch
## on synergy `key` from your available list. Each swap brings in the best
## available player with a missing trait (from the bench or the list; for a
## line synergy one who plays that line) for the lowest-rated player there
## who is not carrying a synergy you already have. Returns {"side", "note",
## "lost": [synergy labels switched off], "problem": "" or why it can't}.
func complete_synergy(key: String, side: Dictionary) -> Dictionary:
	var syn: Dictionary = Traits.SYNERGIES.get(key, {})
	if syn.is_empty():
		return {"side": side, "note": "", "lost": [], "problem": "No such synergy."}
	var line := str(syn["line"])
	var work: Dictionary = side.duplicate(true)
	for k in ["RUCK", "MID", "WING", "DEF", "FWD", "BENCH"]:
		if not work.has(k):
			work[k] = []
	var before: Array = Traits.active(_ground_for(work))
	if before.has(key):
		return {"side": work, "note": "%s is already on." % str(syn["label"]), "lost": [], "problem": ""}
	var protect := {}
	for k2 in before:
		for c in Traits.carriers(str(k2), _ground_for(work)):
			for q in c[1]:
				protect[str(q["id"])] = true
	var by_id := {}
	for p in my_list:
		by_id[str(p["id"])] = p
	# Each swap as [in, out]. A player brought in is never the next one out,
	# so no swap undoes another. One left out for lacking one trait may come
	# back for another the synergy needs: then his two swaps fold into one
	# (Y in for him, him in for W reads "Y in for W"), so the note is the net change.
	var swaps: Array = []
	var brought := {}
	for _guard in range(8):
		var ground := _ground_for(work)
		if Traits.active(ground).has(key):
			break
		var row := {}
		for r in Traits.progress(ground):
			if str(r["key"]) == key:
				row = r
		var need_t := ""
		for t in syn["needs"]:
			if int(row["have"].get(t, 0)) < int(syn["needs"][t]):
				need_t = str(t)
				break
		if need_t == "":
			break
		var on_ground := {}
		for q in ground:
			on_ground[str(q["id"])] = true
		var cand = null
		for p in my_list:
			var pid := str(p["id"])
			if on_ground.has(pid) or not Ratings.available(p) or not Traits.of(p).has(need_t):
				continue
			if line != "" and not Ratings.plays_role(p, line):
				continue
			if cand == null or int(p["overall"]) > int(cand["overall"]):
				cand = p
		if cand == null:
			var plural := str(Traits.PLURALS.get(need_t, Traits.label(need_t) + "s"))
			return {"side": side, "note": "", "lost": [], "problem": "Not enough %s on your list%s to complete it." % [
					plural.to_lower(), " who can play %s" % ("forward" if line == "FWD" else "back") if line != "" else ""]}
		var targets: Array = [line] if line != "" else (["MID", "WING"] if str(cand["role"]) == "MID" else [str(cand["role"])])
		var victim := ""
		for pass_n in range(2):
			for tl in targets:
				for id in work[tl]:
					var vp = by_id.get(str(id))
					if vp == null or str(id) == str(cand["id"]) or brought.has(str(id)):
						continue
					if Traits.of(vp).has(need_t):
						continue
					if pass_n == 0 and protect.has(str(id)):
						continue
					if victim == "" or int(vp["overall"]) < int(by_id[victim]["overall"]):
						victim = str(id)
			if victim != "":
				break
		if victim == "":
			return {"side": side, "note": "", "lost": [], "problem": "No spot to free without losing another %s." % Traits.label(need_t).to_lower()}
		var cid := str(cand["id"])
		brought[cid] = true
		var bench: Array = work["BENCH"]
		for tl in targets:
			var arr: Array = work[tl]
			var vi := arr.find(victim)
			if vi >= 0:
				arr[vi] = cid
				break
		var bi := bench.find(cid)
		if bi >= 0:
			bench[bi] = victim
		var folded := false
		for sw in swaps:
			if str(sw[1]) == cid:
				sw[1] = victim
				folded = true
				break
		if not folded:
			swaps.append([cid, victim])
	var after: Array = Traits.active(_ground_for(work))
	if not after.has(key):
		return {"side": side, "note": "", "lost": [], "problem": "Your list can't complete it this week."}
	var lost := []
	for k3 in before:
		if not after.has(k3):
			lost.append(str(Traits.SYNERGIES[k3]["label"]))
	var ins: PackedStringArray = []
	for sw in swaps:
		ins.append("%s in for %s" % [GameDB.player_display_name(by_id[sw[0]]), GameDB.player_display_name(by_id[sw[1]])])
	var note := "%s on: %s." % [str(syn["label"]), "; ".join(ins)]
	if not lost.is_empty():
		note += " Lost: %s." % ", ".join(lost)
	return {"side": work, "note": note, "lost": lost, "problem": ""}


func _ground_for(side: Dictionary) -> Array:
	var sel := side.duplicate(true)
	sel["DUAL_RUCK"] = user_dual_ruck
	return Squad.new(GameDB.club_name(my_club), my_list, true, my_club, sel).ground


## Synergies within reach (row 103, 4.Q10): what a player from outside your
## list would do for your synergies with him on your ground, as facts:
## [{key, trait, have, need, completes}], the ones he completes first.
## Counted against your side as it stands (my_squad), in his line for a line
## synergy; a synergy you already field is left out. It never says whom he
## would replace or whether to get him.
func synergy_fit(p: Dictionary) -> Array:
	var out := []
	if p.is_empty() or not list_player(str(p.get("id", ""))).is_empty():
		return out
	var ground: Array = my_squad().ground
	var on: Array = Traits.active(ground)
	var his: Array = Traits.of(p)
	var rows := {}
	for r in Traits.progress(ground):
		rows[str(r["key"])] = r
	for key in Traits.SYNERGIES:
		if on.has(key):
			continue
		var s: Dictionary = Traits.SYNERGIES[key]
		var line := str(s["line"])
		if line != "" and not Ratings.plays_role(p, line):
			continue
		var r: Dictionary = rows[key]
		for t in s["needs"]:
			var have := int(r["have"][t])
			var need := int(s["needs"][t])
			if not his.has(str(t)) or have >= need:
				continue
			out.append({"key": key, "trait": str(t), "have": have, "need": need,
					"completes": int(r["missing"]) == 1})
			break
	var done := out.filter(func(x): return bool(x["completes"]))
	return done + out.filter(func(x): return not bool(x["completes"]))


## The opposition's side as it would take the field this week (their own
## selection, or their auto-pick): {"side": selection, "list": players}.
## Projected - they name their side on match day.
func opponent_side(code: String) -> Dictionary:
	if season == null or not season.lists.has(code):
		return {"side": {}, "list": []}
	var sq := Squad.new(GameDB.club_name(code), season.lists[code], false, code, season.selections.get(code, {}))
	return {"side": _as_selection(sq.ground, sq.bench), "list": season.lists[code]}


## Your answer to a "When I sim the week" line (SimOrders), or its default.
func sim_order(key: String) -> String:
	return str(sim_orders.get(key, SimOrders.defaults().get(key, "")))


func set_sim_order(key: String, value: String) -> void:
	if not SimOrders.KEYS.has(key):
		return
	sim_orders[key] = value
	mark_dirty()


## The cards Sim the week stops for under your standing orders (indices).
func sim_week_stops() -> Array:
	return SimOrders.stops(week_events, SimOrders.defaults().merged(sim_orders, true))


## Sim the week on your standing orders: the week's cards answered the way you
## set (SkipOrders.card_choice), runs for the kids if you asked for them, the
## round played (advance), and the press fronted by the assistant if you said
## so. The hub checks sim_week_stops first. Returns the phase played.
func sim_week() -> String:
	if season == null:
		return "none"
	var orders := _sim_week_orders()
	return _sim_week_after(orders, advance())


## sim_week with the week's matches on threads while frames keep drawing.
func sim_week_async() -> String:
	if season == null:
		return "none"
	var orders := _sim_week_orders()
	var phase: String = await advance_async()
	return _sim_week_after(orders, phase)


func _sim_week_orders() -> Dictionary:
	var orders := SimOrders.defaults().merged(sim_orders, true)
	var policy := str(orders["questions"])
	_skip_orders = {"questions": policy if policy in ["players", "board"] else "usual"}
	if str(orders["youth"]) == "kids" and not season.is_regular_done():
		if not my_selection().is_empty():
			set_selection({})
		_skip_back_kids("season")
	return orders


func _sim_week_after(orders: Dictionary, phase: String) -> String:
	_skip_orders = {}
	if str(orders["press"]) == "assistant":
		skip_media_conference()
	return phase


## Put a player (id) or a club ("club:CODE") on the shortlist, or take it
## off. True when it is on the list afterwards.
func toggle_shortlist(id: String) -> bool:
	if id == "":
		return false
	var on := shortlist.has(id)
	if on:
		shortlist.erase(id)
	else:
		shortlist.append(id)
	mark_dirty()
	return not on


## Save the side as your recurring Best 23 (kept until you save another).
func set_best23(side: Dictionary) -> void:
	best23 = side.duplicate(true)
	best23.erase("OUT")
	best23.erase("DUAL_RUCK")
	mark_dirty()


func my_squad() -> Squad:
	return Squad.new(GameDB.club_name(my_club), my_list, true, my_club,
			season.selections.get(my_club, {}) if season != null else {})


## Your side as picked with your coaching on it, as the match gives it at
## kick-off (_refresh_coach_tactics, CoachEffects.apply), for a screen. Worked
## out from the coaches as they stand, not read from the round's table: a
## loaded career has no table until its next match (_rival_squad).
func my_coached_squad() -> Squad:
	var sq := my_squad()
	if season == null or coaches.is_empty():
		CoachEffects.apply(sq)
		return sq
	_ensure_plan_known()
	sq.together = Culture.club_effect(relations, sq.code, "match_contest", "together") 			if culture_effects_on and not relations.is_empty() else 0.0
	var staff: Dictionary = CoachEffects.staffs(coaches).get(my_club, {})
	var row := CoachEffects.row(staff, true)
	row["arch_p"] = CoachEffects.philosophical(staff, true)
	row["exec"] = clampf(float(row.get("exec", 1.0)) * ClubBudget.tactics_mult(fitness_hp_level(my_club)), 0.75, 1.35)
	CoachEffects.apply_row(sq, row)
	return sq


## Every plan: [[key, label], ...].
func train_plan_options() -> Array:
	var out := []
	for row in TRAIN_PLANS:
		out.append([str(row["key"]), str(row["label"])])
	return out


func _plan_row(key: String) -> Dictionary:
	if key.begins_with(LEARN_PREFIX):
		var job := key.trim_prefix(LEARN_PREFIX)
		if not LEARN_JOBS.has(job):
			return {}
		var row: Dictionary = LEARN_JOBS[job]
		var word := str(row["word"])
		return {"key": key, "label": "Learn to play %s" % word, "roles": [],
				# The sizes the project runs on (row T1.R26 C2): PROJECT_OWN_GAIN,
				# PROJECT_PASS, LEARN_PAYBACK.
				"text": "%d weeks training as %s %s instead of in his own position. For the rest of the season his own rating can rise only %d more. If his rating there ends within %d of his own, he can be picked there too, and next season his own rating can climb %d past the usual limit; if not, it has not taken." % [
					PROJECT_WEEKS, "an" if word.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a", word,
					PROJECT_OWN_GAIN, PROJECT_PASS, LEARN_PAYBACK],
				"weights": row["weights"]}
	for row in TRAIN_PLANS:
		if str(row["key"]) == key:
			return row
	return {}


func train_plan_label(key: String) -> String:
	var row := _plan_row(key)
	return str(row.get("label", "By position")) if not row.is_empty() else "By position"


## What the plan makes of him, in football terms. The Position plan reads
## per role, so pass the player (or his role).
func train_plan_description(key: String, role := "") -> String:
	if key == "position" or _plan_row(key).is_empty():
		if role != "":
			return str(POSITION_PLAN_TEXT.get(role, POSITION_PLAN_TEXT["MID"]))
		return "Trains what his position is judged on - the safe default, and what rival clubs do."
	return str(_plan_row(key).get("text", ""))


## The plans that make sense for this player: Position plan, the archetypes
## of his role (and his second role), and a position he could learn.
func plans_for(p: Dictionary) -> Array:
	var out := []
	for row in TRAIN_PLANS:
		if plan_valid_for(p, str(row["key"])):
			out.append(str(row["key"]))
	var learn := []
	var current := project_job(p)
	if current != "":
		learn.append(LEARN_PREFIX + current)
	for job in learnable_jobs(p):
		learn.append(LEARN_PREFIX + str(job))
	out.append_array(learn)
	return out


func plan_valid_for(p: Dictionary, key: String) -> bool:
	if key.begins_with(LEARN_PREFIX):
		var job := key.trim_prefix(LEARN_PREFIX)
		return project_job(p) == job or learnable_jobs(p).has(job)
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
	return "position"


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
	var learning := project_job(p)
	if key == "" or not plan_valid_for(p, key):
		p.erase("train_plan")
	else:
		p["train_plan"] = key
	# Moving off a project ends it, unfinished; this season's chance is spent.
	var now := str(p.get("train_plan", ""))
	if learning != "" and now != LEARN_PREFIX + learning:
		p.erase("project")
	if now.begins_with(LEARN_PREFIX) and project_job(p) == "":
		_start_project(p, now.trim_prefix(LEARN_PREFIX))
	mark_dirty()
	return apply_plan_to(p)


## The club plan is always Position plan (the only plan that suits every
## role). Kept for callers; spends banked XP.
func set_default_plan(_key := "position") -> Dictionary:
	default_train_plan = "position"
	mark_dirty()
	return apply_train_plans()


## Plans from older saves: the club plan becomes Position plan, and a
## player's own plan that no longer exists or does not suit his role is
## cleared. Manual (cut 2026-11-03), whether his own or followed from a
## Manual club plan, becomes the plan closest to how he was hand-trained;
## his banked XP is spent under it on the next apply.
func _migrate_train_plans() -> void:
	var club_manual := default_train_plan == "manual"
	default_train_plan = "position"
	for p in my_list:
		var own := str(p.get("train_plan", ""))
		_migrate_focus(p, own)
		if own == "manual" or (own == "" and club_manual):
			var best := _closest_plan(p)
			if best == "position":
				p.erase("train_plan")
			else:
				p["train_plan"] = best
			continue
		if own != "" and not plan_valid_for(p, own):
			p.erase("train_plan")


## Stat focus from older saves (row 97). An old single-stat plan
## ("focus_marking", cut 2026-11-03) becomes his stat focus, open to change
## this season, and his plan falls back as before. A save holding several
## focuses keeps the first his role can use; one he cannot use is dropped.
func _migrate_focus(p: Dictionary, own: String) -> void:
	if not p.has("train_focus") and own.begins_with("focus_"):
		p["train_focus"] = own.trim_prefix("focus_")
	if not p.has("train_focus"):
		return
	var keep := stat_focus(p)
	if keep == "":
		p.erase("train_focus")
		p.erase("train_focus_year")
	else:
		p["train_focus"] = keep


## The plan whose spending best matches how a player already is: each plan
## valid for him scores the weighted mean of his attributes on what it
## trains, and an archetype must beat Position plan by a clear margin (3
## points) to win, so a balanced player stays on the safe default.
func _closest_plan(p: Dictionary) -> String:
	var attr: Dictionary = p.get("attr", {})
	var score := func(w: Dictionary) -> float:
		var tot := 0.0
		var sum := 0.0
		for k in w:
			tot += float(w[k])
			sum += float(w[k]) * float(attr.get(k, 0))
		return sum / tot if tot > 0.0 else 0.0
	var best := "position"
	var best_score: float = score.call(plan_weights(p, "position")) + 3.0
	for row in TRAIN_PLANS:
		var key := str(row["key"])
		if key == "position" or not row.has("weights") or not plan_valid_for(p, key):
			continue
		var s: float = score.call(row["weights"])
		if s > best_score:
			best_score = s
			best = key
	return best


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
	var job := project_job(p)
	if job != "" and plan_for(p) == LEARN_PREFIX + job:
		# Learning: the same season limit, counted in the new position.
		var learnt := _spend_with_weights(p, plan_weights(p), true,
				int(p["project"].get("ceiling", 0)), project_role(p))
		if not learnt.is_empty():
			mark_dirty()
		return learnt
	var gains := _spend_with_weights(p, plan_weights(p), true, season_ceiling(p), "", stat_focus(p))
	if not gains.is_empty():
		mark_dirty()
	return gains


# ---------------------------------------------------------------------------
# Stat focus (row 97, T1.Q7, director 2026-11-06: "one stat focus per player
# per season, drills do the rest").
# ---------------------------------------------------------------------------
## The share of a player's training XP that goes into his focus stat over the
## season; his plan (the club's drills) spends the rest as it always did. The
## same XP and season ceiling: a focus moves where points go, never how many.
const FOCUS_SHARE := 1.0 / 3.0


## The stats a coach may make a player's focus: any his role uses in a match
## (stat_useful_for), so a focus never trains something that does nothing.
func focus_options(p: Dictionary) -> Array:
	var out := []
	for row in TRAIN_STATS:
		if stat_useful_for(p, str(row[0])):
			out.append(str(row[0]))
	return out


## His focus stat, or "" (none). A save holding more
## than one keeps the first his role can use.
func stat_focus(p: Dictionary) -> String:
	var raw = p.get("train_focus", "")
	var keys: Array = raw if raw is Array else [raw]
	var ok := focus_options(p)
	for k in keys:
		if ok.has(str(k)):
			return str(k)
	return ""


## Picked this season: it stays until the next season opens.
func focus_locked(p: Dictionary) -> bool:
	return p.has("train_focus") and int(p.get("train_focus_year", -1)) == season_year


## Set his focus for the season. False when it is already
## picked this season, or his role does not use the stat. Banked XP is spent
## at once, the same as a plan change.
func set_stat_focus(player_id: String, key: String) -> bool:
	var p := list_player(player_id)
	if p.is_empty() or focus_locked(p) or not focus_options(p).has(key):
		return false
	p["train_focus"] = key
	p["train_focus_year"] = season_year
	mark_dirty()
	apply_plan_to(p)
	return true


## The trait a stat focus grows him toward (row 103, 4.Q10): a trait his
## role can earn from that stat that he does not have yet, {key, min, gap,
## crowded} ({} when none). "crowded" when he already carries MAX_GOOD (five)
## good traits, so a rival club's player aims at nothing more (Traits.of keeps
## the five furthest past their lines). The screen never explains it.
func focus_trait(p: Dictionary, stat: String) -> Dictionary:
	if stat == "":
		return {}
	var have: Array = Traits.of(p)
	var good := 0
	for t in have:
		if Traits.DEFS.has(t) and not Traits.is_bad(str(t)):
			good += 1
	var attr: Dictionary = p.get("attr", {})
	var roles := [str(p.get("role", "")), str(p.get("role2", ""))]
	for key in Traits.DEFS:
		var d: Dictionary = Traits.DEFS[key]
		if d.has("max") or str(d["stat"]) != stat or have.has(key):
			continue
		var need_roles: Array = d["roles"]
		if not need_roles.is_empty() and not (need_roles.has(roles[0]) or need_roles.has(roles[1])):
			continue
		if bool(d.get("small", false)) and int(attr.get("marking", 0)) >= 52:
			continue
		return {"key": key, "min": int(d["min"]), "gap": maxi(0, int(d["min"]) - int(attr.get(stat, 0))),
				"crowded": good >= Traits.MAX_GOOD}
	return {}


## Rival clubs grow traits the same way (every club gets it, director
## 2026-11-09): a player with room for another trait puts his stat focus on
## the nearest trait a synergy needs, within AI_TRAIT_REACH points, and keeps
## it until he earns it. "" = none. Nothing is told; it is their training.
const AI_TRAIT_REACH := 6


func _ai_trait_focus(p: Dictionary) -> String:
	var cur := str(p.get("train_focus", ""))
	if cur != "":
		var still := focus_trait(p, cur)
		if not still.is_empty() and not bool(still["crowded"]):
			return cur
		p.erase("train_focus")
	var wanted := {}
	for s in Traits.SYNERGIES.values():
		for t in (s as Dictionary)["needs"]:
			wanted[str(t)] = true
	var best := ""
	var best_gap := AI_TRAIT_REACH + 1
	for n in Traits.near(p):
		if not wanted.has(str(n["key"])) or int(n["gap"]) >= best_gap:
			continue
		var ft := focus_trait(p, str(n["stat"]))
		if ft.is_empty() or bool(ft["crowded"]) or not focus_options(p).has(str(n["stat"])):
			continue
		best = str(n["stat"])
		best_gap = int(n["gap"])
	if best != "":
		p["train_focus"] = best
	return best


## [focus XP, drills XP] spent this season while he had a focus.
func focus_spent(p: Dictionary) -> Array:
	var led: Array = p.get("focus_ledger", [])
	if led.size() < 3 or int(led[0]) != season_year:
		return [0, 0]
	return [int(led[1]), int(led[2])]


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
		ceiling := -1, rate_role := "", focus := "") -> Dictionary:
	var gains := {}
	# A stat focus takes FOCUS_SHARE of the season's spending; the plan buys
	# the rest (ledger: [year, focus XP, drills XP]).
	var spent: Array = focus_spent(p) if focus != "" else [0, 0]
	var games := float(p.get("gm", 18.0))
	var attr: Dictionary = p.get("attr", {})
	var stop_at := ceiling if ceiling >= 0 else int(p.get("potential", 0))
	while true:
		var rated := int(p.get("overall", 0)) if rate_role == "" else rating_as(p, rate_role)
		if stop_at_pot and rated >= stop_at:
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
		var on_focus := false
		if focus != "" and attr.has(focus) and int(attr[focus]) < 99:
			# The focus point is due only if buying it keeps his running focus
			# share at or under FOCUS_SHARE, judged after the purchase, so
			# neither the first point nor a dear focus point overshoots.
			var f_cost := _cost_for(int(attr[focus]), games, mult)
			var s0 := float(spent[0])
			var total := float(int(spent[0]) + int(spent[1]))
			var due := s0 + float(f_cost) <= FOCUS_SHARE * (total + float(f_cost))
			# A due focus point he can't yet afford doesn't stall training:
			# the plan's cheaper drill point is bought instead.
			if (due or best_key == "") and int(p.get("xp", 0)) >= f_cost:
				on_focus = true
				best_key = focus
				best_cost = f_cost
		if best_key == "" or int(p.get("xp", 0)) < best_cost:
			break
		p["xp"] = int(p["xp"]) - best_cost
		attr[best_key] = int(attr[best_key]) + 1
		gains[best_key] = int(gains.get(best_key, 0)) + 1
		if focus != "":
			spent[0 if on_focus else 1] = int(spent[0 if on_focus else 1]) + best_cost
			p["focus_ledger"] = [season_year, int(spent[0]), int(spent[1])]
		_recalc_player_overall(p)
	if not gains.is_empty() and rate_role == "":
		# The season's training in his own position, kept so the off-season
		# can take the league's lift back off where it went (Prospects.
		# training_unwind); cleared at rollover. A new position's learning
		# is not counted: it is his to keep.
		var season_gains: Dictionary = p.get("season_gains", {})
		for key in gains:
			season_gains[key] = int(season_gains.get(key, 0)) + int(gains[key])
		p["season_gains"] = season_gains
	return gains


## After a round: every rival club's players are paid for the game and their
## coaches spend it. Rivals only train a player up to his potential (you can
## go past it, at a premium), which keeps the league from inflating.
func _train_rivals(results: Array) -> void:
	if season == null:
		return
	var best := {}
	# Once a week, not once a club: nobody changes jobs in between.
	var staffs = CoachEffects.staffs(coaches) if not coaches.is_empty() else null
	for res in results:
		for side in ["home", "away"]:
			var code := str(res.get(side, ""))
			if code == "" or code == my_club or not season.lists.has(code):
				continue
			var list: Array = season.lists[code]
			_grant_xp(code, list, res, staffs)
			for p in list:
				ai_spend_xp(p)
				best = _development_pick(code, p, best)
			_ai_projects(list)
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

## Every club's staff, read once a round for the teaching step: the records
## change only between rounds (hirings, the off-season market).
var _teach_staffs := {}
var _teach_key := ""


## A point on or off this player's season training ceiling from his club's
## teachers (CoachEffects.teach_step); 0 outside a coaching world.
func teach_step(p: Dictionary) -> int:
	if coaches.is_empty() or str(p.get("club", "")) == "":
		return 0   # no club, no teachers: a free agent or a prospect is neither lifted nor held back
	var key := "%d|%d|%d" % [season_year, season.round_index if season != null else -1, coaches.size()]
	if key != _teach_key:
		_teach_staffs = CoachEffects.staffs(coaches)
		_teach_key = key
	return CoachEffects.teach_step(_teach_staffs.get(str(p.get("club", "")), {}), p)


## The rating a player's training can take him to this season (less once he
## starts on another position). His club's teachers move it a point either
## way (CoachEffects.teach_step), at every club alike.
func season_ceiling(p: Dictionary) -> int:
	if not p.has("season_start_ov"):
		p["season_start_ov"] = int(p.get("overall", 0))
	var full := int(p["season_start_ov"]) + SEASON_TRAIN_GAIN + teach_step(p)
	# Develop and manage (Conditioning): a point more room for the young.
	if season != null and str(p.get("club", "")) != "":
		full += fitness_ceiling_step(p)
		# A patient or rebuilding club (Culture): a point more room for its young,
		# inside POT, at every club alike.
		var step := culture_ceiling_step(p)
		if step > 0:
			full = maxi(full, mini(full + step, int(p.get("potential", 0))))
	# The season after he learns a position: a little more room, inside POT.
	if int(p.get("learn_payback_year", 0)) == season_year:
		full = maxi(full, mini(full + LEARN_PAYBACK, int(p.get("potential", 0))))
	if int(p.get("project_year", 0)) == season_year and p.has("project_cap"):
		return mini(full, int(p["project_cap"]))
	return full


## Spend a rival player's XP. Returns the attribute points bought.
func ai_spend_xp(p: Dictionary) -> int:
	var job := project_job(p)
	if job != "":
		var learnt := 0
		for n in _spend_with_weights(p, LEARN_JOBS[job]["weights"], true,
				int(p["project"].get("ceiling", 0)), project_role(p)).values():
			learnt += int(n)
		return learnt
	var ceiling := season_ceiling(p)
	if int(p.get("overall", 0)) >= ceiling:
		return 0
	var focus: Dictionary = Ratings.ROLE_WEIGHTS.get(str(p.get("role", "MID")), Ratings.ROLE_WEIGHTS["MID"])
	var bought := 0
	for n in _spend_with_weights(p, focus, true, ceiling, "", _ai_trait_focus(p)).values():
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


func _recalc_player_overall(p: Dictionary) -> void:
	p["overall"] = Ratings.rate_overall(p["attr"], str(p["role"]),
			Ratings.effective_games(p))
	p["value"] = Ratings.salary_value(int(p["overall"]))


# ---------------------------------------------------------------------------
# Difficulty: two named dials (data/difficulty_dials.json)
# ---------------------------------------------------------------------------
## Board patience: how many poor seasons the board puts up with before it
## warns you, then moves on you (ClubLife.season_end). Rival recruiting: how
## hard the other clubs bargain over trades with you (trade_margin). Difficulty
## never changes how players develop: every club's players earn, train and
## grow by the same rules (SEASON_TRAIN_GAIN, Potential), and the rivals get no
## hidden information or rating boost.
func difficulty_rules() -> Dictionary:
	var board_step := DifficultyDials.step(DifficultyDials.BOARD, board_patience)
	var rival_step := DifficultyDials.step(DifficultyDials.RIVALS, rival_recruiting)
	return {
		"trade_margin": float(rival_step.get("trade_margin", Contracts.TRADE_MARGIN)),
		"poor_seasons_before_warning": int(board_step.get("poor_seasons_before_warning", 1)),
		"poor_season_below": int(board_step.get("poor_season_below", ClubLife.WARN_LINE)),
	}


## This career's dial as a step key ("board_patience" or "rival_recruiting").
func career_dial(dial: String) -> String:
	return board_patience if dial == DifficultyDials.BOARD else rival_recruiting


## The one read-only line Settings shows for this career's two dials:
## "This career: Fair board · Shrewd rivals." (step names, no numbers).
func career_dials_line() -> String:
	return "This career: %s board · %s rivals." % [
			DifficultyDials.label(DifficultyDials.BOARD, board_patience),
			DifficultyDials.label(DifficultyDials.RIVALS, rival_recruiting)]


## First-visit menu tips (director, 2026-10-07): chosen at New career, kept
## with the career, changeable in Settings. Off stops them opening by
## themselves; nothing else changes.
func new_career_tutorials() -> bool:
	return bool(get_setting("tutorials", true))


func set_new_career_tutorials(on: bool) -> void:
	set_setting("tutorials", on)
	if season == null:
		tutorials = on


## Controversies (director: "real penalties land", a switch at game
## creation): chosen at New career, kept with the career.
func new_career_controversies() -> bool:
	return bool(get_setting("controversies", true))


func set_new_career_controversies(on: bool) -> void:
	set_setting("controversies", on)
	if season == null:
		controversies = on


## The supplements saga's own switch: chosen at New career, kept with the
## career. Until it is first chosen it follows Controversies.
func new_career_supplements() -> bool:
	return bool(get_setting("supplements", new_career_controversies()))


func set_new_career_supplements(on: bool) -> void:
	set_setting("supplements", on)
	if season == null:
		supplements = on


func tutorials_on() -> bool:
	return tutorials


## Whether a first-visit intro opens by itself: this career's tips are on and
## it hasn't been seen on this device. Help buttons open intros regardless.
func intro_due(key: String) -> bool:
	if key == "postseason":
		return tutorials and not postseason_intro_seen
	return tutorials and not bool(get_setting("seen_%s_intro" % key, false))


## The first postseason's sheet goes with the career (ruling 56: "a fresh
## career's first postseason"); every other intro goes with the device.
func mark_intro_seen(key: String) -> void:
	if key == "postseason":
		postseason_intro_seen = true
		mark_dirty()
	else:
		set_setting("seen_%s_intro" % key, true)


## Settings: this career's tips on or off (and the next New career's default).
func set_tutorials_on(on: bool) -> void:
	tutorials = on
	set_setting("tutorials", on)
	mark_dirty()


## The step of a dial the next New Career starts on (a menu setting). A
## device that only ever chose Easy, Normal or Hard starts on the Fair board and the matching rivals.
func new_career_dial(dial: String) -> String:
	var saved := str(get_setting(dial, ""))
	if saved == "":
		return str(DifficultyDials.from_legacy(str(get_setting("difficulty", "normal")))[dial])
	return DifficultyDials.normalize(dial, saved)


func set_new_career_dial(dial: String, key: String) -> void:
	if not DifficultyDials.DIALS.has(dial) or not DifficultyDials.order(dial).has(key):
		return
	set_setting(dial, key)
	# Before the season starts the choice still applies to this career.
	if season == null:
		if dial == DifficultyDials.BOARD:
			board_patience = key
		else:
			rival_recruiting = key


# ---------------------------------------------------------------------------
# League news
# ---------------------------------------------------------------------------
const MAX_NEWS := 120
## Rival releases, signings and development only make the news from here up.
const NEWS_MIN_OVR := 72


func add_news(kind: String, text: String, when_label: String = "", extra := {}) -> void:
	var when := when_label
	if when == "":
		when = "Off-season" if season_closed() else last_label
	var item := {"year": season_year, "when": when, "kind": kind, "text": text}
	item.merge(extra)
	news.push_front(item)
	if news.size() > MAX_NEWS:
		news.resize(MAX_NEWS)


## A ground the season is played at that takes a new name this year gets one
## story before Round 1 (Princes Park became Optus Oval in 1994): the old name,
## the new one and the clubs that call it home. Today's grounds keep their
## names, so a career from 2026 never sees one.
func _ground_rename_news() -> void:
	if season == null:
		return
	var homes := {}   # ground key -> club codes at home there
	for code in season.clubs:
		var g := GameDB.ground_key(season.home_ground(str(code)))
		if not homes.has(g):
			homes[g] = []
		(homes[g] as Array).append(str(code))
	var used := homes.keys()
	for i in range(season.fixture.size()):
		for m in season.fixture[i]:
			var v := GameDB.ground_key(season.round_venue(i, str(m["home"]), str(m["away"])))
			if not used.has(v):
				used.append(v)
	var gf := GameDB.ground_key(season.grand_final_venue())
	if not used.has(gf):
		used.append(gf)
	for g in used:
		var old := GameDB.ground_renamed_from(str(g), season_year)
		if old == "" or not Milestones.tell_once(self, "ground|%s|%d" % [g, season_year]):
			continue
		var now := GameDB.ground_name(str(g), season_year)
		var clubs: Array = homes.get(g, [])
		var names := PackedStringArray(clubs.map(func(c): return GameDB.club_name(str(c))))
		var first := season.round_name(0)
		var text := "%s takes a new name this season: from %s it is %s" % [old,
				"the " + first if first == "Opening Round" else first, now]
		if names.size() > 0:
			text += ", home of %s" % " and ".join(names)
		add_news("ground", text + ".", "Pre-season", {"club": str(clubs[0]) if clubs.size() > 0 else "",
				"old": old, "new": now})


## Around halfway through the home-and-away season, recruiting has seen
## enough of an exceptional class to call it. This is deliberately only a
## superdraft signal: ordinary/weak/strong classes stay uncertain rather than
## turning the news feed into a hidden numeric scouting report.
func _draft_class_news() -> void:
	if season == null or season.is_season_over():
		return
	var reveal_round := ceili(float(season.regular_rounds()) / 2.0)
	if season.round_index < reveal_round:
		return
	if str(class_tiers.get(str(season_year), "")) != "super":
		return
	# The feed is trimmed to MAX_NEWS, so the item cannot be its own memory. An
	# older save that already has the line in its feed is not told twice.
	for item in news:
		if int(item.get("year", 0)) == season_year and str(item.get("kind", "")) == "superdraft":
			return
	if not Milestones.tell_once(self, "superdraft|%d" % season_year):
		return
	add_news("superdraft", "Recruiters believe this year's national draft is a superdraft — unusually strong at the top and deeper than a normal class. Clubs will be planning their off-season around it.")



## What your players did first in this round's match of yours, kept on them
## (Firsts): the debut and the first goal. Only a career on record in full, so
## "first" is a fact; the tally already holds the match, so a debut is the
## first game on it with none before.
func _note_firsts(results: Array) -> void:
	if my_club == "":
		return
	for res in results:
		var side := 0 if str(res.get("home", "")) == my_club else (1 if str(res.get("away", "")) == my_club else -1)
		var roster: Array = res.get("roster", [])
		if side < 0 or roster.size() <= side:
			continue
		var label := str(res.get("label", ""))
		var stats_all: Dictionary = res.get("players", {})
		for r in roster[side]:
			var id := str(r.get("id", ""))
			var p := list_player(id)
			if p.is_empty() or not Career.complete(p):
				continue
			if games_played(p) == 1:
				Firsts.note(p, "debut", season_year, label)
			var goals := int((stats_all.get(id, {}) as Dictionary).get("goals", 0))
			if goals > 0 and career_goals_before(p, goals) == 0:
				Firsts.note(p, "goal", season_year, label)


## Every player's best games, kept on him (CareerHighs), and the week's news
## for a new career high by one of yours: one per player, his biggest, and at
## most CareerHighs.MAX_NEWS a round, and none for a player the round's news
## already named for his game (_named_this_round). The tally already holds the
## match, so his games before it are one fewer than games_played.
func _note_career_highs(results: Array) -> void:
	var said := []
	# Everyone on a list, by id, once for the round (the first list he is on, as
	# _find_player finds him): a search of every list per player was most of this.
	var by_id := {}
	if season != null:
		for code in season.lists:
			for q in season.lists[code]:
				var qid := str(q["id"])
				if not by_id.has(qid):
					by_id[qid] = q
	for res in results:
		var roster: Array = res.get("roster", [])
		var stats_all: Dictionary = res.get("players", {})
		var label := str(res.get("label", ""))
		var key := Milestones.match_key(season_year, res)
		var codes := [str(res.get("home", "")), str(res.get("away", ""))]
		for side in range(mini(2, roster.size())):
			for r in roster[side]:
				var id := str(r.get("id", ""))
				var p: Dictionary = by_id.get(id, {})
				if p.is_empty():
					continue
				var highs := CareerHighs.update(p, stats_all.get(id, {}), maxi(0, games_played(p) - 1),
						Career.complete(p), season_year, label, key)
				if highs.is_empty() or my_club == "" or codes[side] != my_club or _named_this_round.has(id):
					continue
				said.append([CareerHighs._step(highs[0]), CareerHighs.news_line(
						GameDB.player_display_name(p), str(highs[0][0]), int(highs[0][1]),
						codes[1 - side], label)])
	# The biggest few, added smallest first: news is newest first, so the
	# biggest ends on top.
	said.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	for i in range(mini(CareerHighs.MAX_NEWS, said.size()) - 1, -1, -1):
		add_news("milestone", str(said[i][1]))


## Players of yours in the match about to be played whose career high the feed
## could say: {id: {stat: best}}, for a record that holds every game he has
## played and at least CareerHighs.MIN_GAMES of them (MatchNotes.career_high_lines).
func career_high_candidates() -> Dictionary:
	var out := {}
	if pending_sim == null or pending_match.is_empty() or my_club == "":
		return out
	var side := 0 if str(pending_match.get("home", "")) == my_club else 1
	var squad: Squad = pending_sim.squads[side]
	for row in squad.ground + squad.bench:
		var p := list_player(str(row["id"]))
		if p.is_empty() or not CareerHighs.complete(p) or not Career.complete(p):
			continue
		var rec := CareerHighs.get_record(p)
		if int(rec.get("games", 0)) < CareerHighs.MIN_GAMES or int(rec.get("games", 0)) != games_played(p):
			continue
		var bests := {}
		for stat in CareerHighs.STATS:
			bests[stat] = CareerHighs.best(p, stat)
		out[str(p["id"])] = bests
	return out


## His career goals before the match being played or just played: the record,
## plus this season's goals so far when the record stops short of the season.
## `this_match` is what the season's tally already holds of that match (0 before
## it is played, his goals in it once it is counted).
func career_goals_before(p: Dictionary, this_match := 0) -> int:
	var c := Career.of(p)
	var before := int(c.get("goals", 0))
	if int(c.get("through", 0)) < season_year:
		var tally := int((season_tally.get(str(p.get("id", "")), {}) as Dictionary).get("goals", 0))
		before += maxi(0, tally - this_match)
	return before


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
			var previous_career_goals := career_goals_before(p, goals)
			if Career.complete(p) and previous_career_goals == 0:
				_named_this_round[id] = true
				add_news("milestone", "%s kicked his first AFL goal for %s." % [
						GameDB.player_display_name(p), GameDB.club_name(code)])
			if not Career.complete(p):
				continue
			var career_goals := previous_career_goals + goals
			for mark in [100, 200, 300, 400, 500, 600, 700, 800]:
				if previous_career_goals < mark and career_goals >= mark:
					_named_this_round[id] = true
					add_news("milestone", "%s reached %d career goals." % [
							GameDB.player_display_name(p), mark])
			for mark in [25, 50, 75, 100]:
				if season_goals - goals < mark and season_goals >= mark:
					_named_this_round[id] = true
					add_news("milestone", "%s reached %d goals for the %d season." % [
							GameDB.player_display_name(p), mark, season_year])

## Big games and long injuries to good players from the round just played.
func _round_news(results: Array) -> void:
	_named_this_round = {}
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
				_named_this_round[str(r["id"])] = true
				if int(st.get("goals", 0)) >= 6:
					add_news("game", "%s kicked %d goals for %s against %s." % [
							GameDB.player_display_name(p), int(st["goals"]),
							GameDB.club_name(code), GameDB.club_name(opp)])
				elif int(st.get("disposals", 0)) >= 40:
					add_news("game", "%s had %d disposals for %s against %s." % [
							GameDB.player_display_name(p), int(st["disposals"]),
							GameDB.club_name(code), GameDB.club_name(opp)])
	# The round's big stories, every match (LeagueStories): an injury told as a
	# story is not also a plain line.
	var told := {}
	for st in LeagueStories.round_stories(results, LeagueStories.context(self)):
		if str(st["id"]) != "":
			told[str(st["id"])] = true
		add_news("league_story", LeagueStories.text(st), "", {"headline": st["headline"],
				"beats": st["beats"], "club": st["club"], "weight": st["weight"], "angle": st["angle"]})
	for inj in last_injuries:
		var p := _find_player(str(inj.get("id", "")))
		if p.is_empty() or int(inj.get("weeks", 0)) < 4 or int(p.get("overall", 0)) < NEWS_MIN_OVR 				or told.has(str(inj.get("id", ""))):
			continue
		add_news("injury", "%s (%s) is out for %s with %s." % [GameDB.player_display_name(p),
				GameDB.club_name(str(inj.get("club", ""))), _weeks_text(int(inj["weeks"])),
				Injuries.wording(str(inj.get("kind", "")))])
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
	var fist: Array = season_awards.get("golden_fist", [])
	if not fist.is_empty():
		add_news("award", "%s (%s) won the %s with %s." % [award_name(fist[0]),
				GameDB.club_name(str(fist[0]["club"])), Awards.GOLDEN_FIST, Awards.golden_fist_line(fist[0])])
	var medal: Dictionary = season_awards.get("norm_smith", {})
	if not medal.is_empty():
		add_news("award", "Norm Smith Medal: %s (%s), %s" % [award_name(medal),
				GameDB.club_name(str(medal["club"])), str(medal["line"])])
	if premier() != "":
		# Plus one sentence of the club's flag history (row 76).
		add_news("premiers", LeagueNews.premiers_line(premier(), season_year, honour_roll))


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
		club_goals[code] = ClubLife.board_goal(i + 1, int(_last_finish.get(code, 0)), ranks.size(), season.finalists())
		if code == my_club:
			rank = i + 1
	if board.is_empty():
		board = {"confidence": ClubLife.START_CONFIDENCE, "warned": false, "sacked": false, "history": []}
	board["goal"] = club_goals.get(my_club, ClubLife.board_goal(rank, 0, ranks.size(), season.finalists()))
	board["rank"] = rank
	board["clubs"] = ranks.size()
	board["last_finish"] = int(_last_finish.get(my_club, 0))
	board["year"] = season_year
	board.erase("promise")
	losing_streak = 0
	StoryEngine.new_season(story)
	ClubArcs.season_start(self)
	_next_week_event()
func board_confidence() -> int:
	return int(board.get("confidence", ClubLife.START_CONFIDENCE))


## The board's mood in words (ClubLife.board_state), and why it last moved.
func board_state() -> String:
	return ClubLife.board_state(board_confidence(), int(difficulty_rules()["poor_season_below"]))


## The hub's board warning (ClubLife.board_warning) for this career's board: ""
## unless confidence is under ClubLife.POOR_LINE.
func board_warning() -> String:
	var rules := difficulty_rules()
	return ClubLife.board_warning(board_confidence(), bool(board.get("warned", false)),
			int(rules["poor_season_below"]), int(rules["poor_seasons_before_warning"]),
			int(board.get("poor_seasons", 0)))


func board_why() -> String:
	return str(board.get("why", ""))


func board_goal_text() -> String:
	return str((board.get("goal", {}) as Dictionary).get("text", ""))


func is_sacked() -> bool:
	return bool(board.get("sacked", false))


## Can the season roll on after a sacking? Not when the coaching career is
## over (no reprieve left, or he retired). A choice of jobs still open when
## the season rolls on (only a headless run gets here: the Hub's sacked card
## and begin_intake_draft stand in the way) takes the first club offered
## (ClubMoves).
func _sacking_settled() -> bool:
	if not is_sacked():
		return true
	ClubMoves.take_first_offer(self)
	return not is_sacked()


func _my_result(results: Array) -> Dictionary:
	for res in results:
		if str(res.get("home", "")) == my_club or str(res.get("away", "")) == my_club:
			return res
	return {}


## A finals card's sting: lose the final it was set for, and one roll from the
## save's seed says whether the side's morale also falls (by the card's size), on
## top of the lift the card already gave.
func _settle_loss_sting(res: Dictionary) -> void:
	if res.is_empty() or not res.has("tag") or season == null:
		return
	# Lost: the bracket says who went through (a level final is settled on the ladder).
	if str((season.finals.get("slots", {}) as Dictionary).get("W_" + str(res["tag"]), "")) == my_club:
		return
	var rule: Array = []
	for p in my_list:
		if p.has("loss_sting"):
			rule = p["loss_sting"]
			break
	if rule.is_empty():
		return
	if not StoryEngine.risk_hit(int(season.seed), season_year, int(res.get("round", 0)), "loss_sting", int(rule[0])):
		return
	for p in my_list:
		if p.has("loss_sting"):
			ClubLife.add_morale(p, int((p["loss_sting"] as Array)[1]))


func _board_after_round(results: Array) -> void:
	var res := _my_result(results)
	# Last week's sit-down, unread, has had its week.
	backing_talk = {}
	_settle_loss_sting(res)
	# This week's one-off flags (rested, sore, heavy legs, fresh, a slow start) end with
	# the round. On a week off in the finals nothing was played, so the ones that
	# are for the next match wait for it.
	var week_off: bool = res.is_empty() and last_phase == "finals"
	for p in my_list:
		p.erase("rested")
		p.erase("sore")
		if not week_off:
			p.erase("heavy_legs")
			p.erase("fresh")
			p.erase("slow_start")
			p.erase("loss_sting")
	_preseason_clear_legs()
	if not res.is_empty() and not role_trial.is_empty() and list_player(str(role_trial.get("id", ""))).is_empty():
		_end_role_trial(false)   # he left the list: no trial, no stale note
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
		conf = clampi(conf + (StoryEngine.PROMISE_WIN_UP if margin > 0 else -StoryEngine.PROMISE_WIN_DOWN), 0, 100)
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
	ClubLife.morale_after_match(my_list, played, margin > 0, soft, culture_effect(my_club, "sting"), _round_unavailable,
			str(CoachEffects.arch_of(my_club)[1]))
	# A promised man left out because every place was held by another promised
	# man could not have been named: no promise of his breaks for this match.
	var no_room := _no_room_ids(played)
	# A player promised a run (Backing): each game he plays counts towards it.
	# Left out while fit, the promise breaks and it stings, once, and the run
	# is over; unable to play, the run waits. His one-week expectation is
	# settled here rather than by the loop below, so it never stings twice.
	var stats_all: Dictionary = res.get("players", {})
	for p in my_list:
		if not Backing.is_active(p):
			continue
		var pid := str(p["id"])
		var run_state := Backing.after_match(p, played.has(pid), not _backing_unavailable.has(pid) and not no_room.has(pid),
				{"year": season_year, "label": str(res.get("label", ""))}, stats_all.get(pid, {}))
		if run_state == "done" or run_state == "broken":
			Backing.mark_asked(p, story_week())   # no new ask for a while (Backing.ASK_GAP)
		if backing_talk.is_empty() and (run_state == "done" or run_state == "broken"):
			backing_talk = Backing.talk(p, Backing.ledger(p).back())
		if run_state == "broken":
			ClubLife.add_morale(p, -CoachEffects.softened(Backing.STING, float(soft.get(pid, 0.0))))
			Trust.change(relations, Trust.player_key(pid), ClubStories.BROKEN_RUN_TRUST,
					"You broke your word on his run of games", season_year, last_label)
			_culture_move(my_club, "together", -StoryEngine.BROKEN_TOGETHER, "You broke your word on a player's run of games")
		p.erase("expects_game")
	# Games promised in a development talk (T5.r93): left out of them fit breaks it.
	_dev_promise_after_match(played, no_room)
	# A player promised a game (a talk, or a kid given his chance): leaving
	# him out fit sours it. Once: the promise ends with the round.
	for p in my_list:
		if p.has("expects_game"):
			var sting := int(p["expects_game"]) if typeof(p["expects_game"]) == TYPE_INT else 12
			p.erase("expects_game")
			if not played.has(str(p["id"])) and int(p.get("injury_weeks", 0)) <= 0 \
					and not _round_unavailable.has(str(p["id"])) and not no_room.has(str(p["id"])):
				ClubLife.add_morale(p, -CoachEffects.softened(sting, float(soft.get(str(p["id"]), 0.0))))
				Trust.change(relations, Trust.player_key(str(p["id"])), ClubStories.BROKEN_PROMISE_TRUST,
						"You promised him a game and left him out", season_year, last_label)
				_culture_move(my_club, "together", -StoryEngine.BROKEN_TOGETHER, "You promised a player a game and left him out")
	_after_match_talks(played, int(res.get("round", season.round_index)))


## Every rival club's players take the week the way yours do
## (ClubLife.morale_after_match): who played gets a lift, more for a win; a
## fit player left out loses some, softened by that club's own
## man-managers. Morale moves match form (MatchSim.fit), so it follows the
## same rule at every club - run for yours alone, it was a free edge in
## every match (docs/COMPETITIVE_BALANCE.md).
func _rival_morale_after_round(results: Array) -> void:
	if season == null:
		return
	var staffs: Dictionary = CoachEffects.staffs(coaches) if not coaches.is_empty() else {}
	for res in results:
		var roster: Array = res.get("roster", [[], []])
		var score: Array = res.get("score", [0, 0])
		for side in range(2):
			var code := str(res.get("home" if side == 0 else "away", ""))
			if code == "" or code == my_club or not season.lists.has(code):
				continue
			var list: Array = season.lists[code]
			var played := {}
			if roster.size() > side:
				for r in roster[side]:
					played[str(r["id"])] = true
			var soft := {}
			var staff: Dictionary = staffs.get(code, {})
			if not staff.is_empty():
				for p in list:
					soft[str(p["id"])] = CoachEffects.soften(staff, p)
			ClubLife.morale_after_match(list, played, int(score[side]) > int(score[1 - side]), soft, culture_effect(code, "sting"),
					_round_unavailable, str(CoachEffects.arch_of(code)[1]))


## Keep your match's story (hero, turning point, reasons) and put its
## headline on the news front. Played or simmed, the same record.
func _record_match_story(results: Array) -> void:
	if my_club == "":
		return
	var res := _my_result(results)
	if res.is_empty():
		return
	var side := 0 if str(res["home"]) == my_club else 1
	var rec := MatchStory.record(res, side, season_year)
	if rec.is_empty():
		return
	match_stories.append(rec)
	# Folded into its season's digest first, so trimming never loses a season.
	MatchStory.fold(match_story_digest, rec)
	if match_stories.size() > MAX_MATCH_STORIES:
		match_stories = match_stories.slice(match_stories.size() - MAX_MATCH_STORIES)
	if str(rec["hero_name"]) != "":
		var line := "%s. %s: %s." % [str(rec["headline"]), str(rec["hero_name"]), str(rec["hero_line"])]
		if str(rec.get("my_best_name", "")) != "":
			line += " Your best: %s, %s." % [str(rec["my_best_name"]), str(rec["my_best_line"])]
		add_news("match_story", line)


## The latest match story record, {} when there is none.
func last_match_story() -> Dictionary:
	if match_stories.is_empty():
		return {}
	return match_stories[-1]


## A notable user match may produce one short press conference.
func _prepare_media_conference(results: Array) -> void:
	media_conference = {}
	var res := _my_result(results)
	if res.is_empty():
		return
	var side := 0 if str(res["home"]) == my_club else 1
	var opp := str(res["away"] if side == 0 else res["home"])
	var injuries := []
	# A player the panel has just ruled out is still on the list while the round
	# is counted (_settle_medical): no question this week is about him.
	var gone := _medically_out_ids()
	var hurt := gone.duplicate()
	for inj in last_injuries:
		if str(inj.get("club", "")) == my_club:
			var p := _find_player(str(inj.get("id", "")))
			hurt[str(inj.get("id", ""))] = true
			injuries.append({"name": GameDB.player_display_name(p) if not p.is_empty() else "a player",
					"id": str(inj.get("id", "")) if not list_player(str(inj.get("id", ""))).is_empty() else ""})
	var star := {}
	var roster: Array = res.get("roster", [[], []])
	var stats: Dictionary = res.get("players", {})
	if roster.size() > side:
		for r in roster[side]:
			var st: Dictionary = stats.get(str(r.get("id", "")), {})
			var goals := int(st.get("goals", 0))
			var disposals := int(st.get("disposals", 0))
			if (goals >= 6 or disposals >= 40) and not gone.has(str(r.get("id", ""))):
				var p := _find_player(str(r.get("id", "")))
				star = {"name": GameDB.player_display_name(p) if not p.is_empty() else str(r.get("name", "A player")),
						"line": "kicked %d goals" % goals if goals >= 6 else "had %d disposals" % disposals,
						"id": str(r.get("id", "")) if not list_player(str(r.get("id", ""))).is_empty() else ""}
				break
	# Only a real standout (6 goals or 40 disposals) is a star question: an
	# ordinary game asks nothing (director 2026-11-06; ruling 5.52, never a
	# schedule). MatchStory keeps its hero and "your best" for the match copy.
	var round_no := season.round_index if last_phase == "regular" else season.regular_rounds() + int((season.finals.get("weeks", []) as Array).size())
	# How many of your side were young enough for the Philosopher to ask.
	var young := 0
	if roster.size() > side:
		for r in roster[side]:
			var p := _find_player(str(r.get("id", "")))
			if not p.is_empty() and MediaConference.is_young(float(p.get("age", 30.0))):
				young += 1
	# A listed player's first game, or a career milestone, on the day: only for
	# a career on record in full, so the count is true.
	var debut := {}
	var milestone := {}
	if roster.size() > side:
		for r in roster[side]:
			var p := list_player(str(r.get("id", "")))
			if p.is_empty() or not Career.complete(p) or gone.has(str(r.get("id", ""))):
				continue
			var g := games_played(p)
			var who := {"id": str(p.get("id", "")), "name": GameDB.player_display_name(p), "games": g}
			if g == 1 and debut.is_empty():
				debut = who
			elif BANNER_MILESTONES.has(g) and g >= 100 and g > int(milestone.get("games", 0)):
				milestone = who
	var fin := {}
	if res.has("tag"):
		var lbl := str(res.get("label", "final"))
		if lbl.length() > 2 and lbl.right(1).is_valid_int():
			lbl = lbl.left(lbl.length() - 2)
		fin = {"label": lbl if lbl == "Grand Final" else lbl.to_lower(), "status": my_finals_status()}
	var won_run := 0
	var form: Array = season.club_results(my_club)
	for i in range(form.size() - 1, -1, -1):
		if str(form[i]) != "W":
			break
		won_run += 1
	media_conference = MediaConference.pick({
		"result": res, "club": my_club, "opponent_name": GameDB.club_name(opp),
		"round": round_no, "injuries": injuries, "star": star, "year": season_year, "young": young,
		"named": _press_named(res, side, hurt), "debut": debut, "milestone": milestone, "final": fin,
		"losing_run": losing_streak, "winning_run": won_run, "my_pos": my_position(), "opp_pos": club_position(opp),
	}, media_memory)
	if not media_conference.is_empty():
		# How often each question has come up this career: its written
		# versions take turns (MediaConference._turn).
		var asked: Dictionary = media_memory["asked"] if media_memory.get("asked") is Dictionary else {}
		var key := str(media_conference.get("key", ""))
		asked[key] = int(asked.get(key, 0)) + 1
		media_memory["asked"] = asked
		# The Muckraker quotes a claim back once, not after every heavy loss
		# that season (audit 19/60: it came round every six rounds).
		if str(media_conference.get("qid", "")) == "heavy_loss.said" and media_memory.get("said|big_win") is Dictionary:
			(media_memory["said|big_win"] as Dictionary)["quoted"] = true
		media_conference["opp"] = GameDB.club_name(opp)
		# How he asks follows your standing with him (director 2026-11-06, Q1);
		# the question itself stays as it was.
		var j := str(media_conference.get("journalist", ""))
		media_conference["lead"] = MediaConference.lead_in(j, press_standing(j))


## Who a named answer can be about, per question: after a heavy loss your
## lowest-rated player who played (not one hurt in the match), after a big win
## your best, with a young side the lowest-rated who played at 21 or under.
## Listed players only; a question with nobody gets no fourth answer.
func _press_named(res: Dictionary, side: int, hurt: Dictionary) -> Dictionary:
	var out := {}
	var rated := MatchNotes.rated_players(res, side)
	var gone := _medically_out_ids()
	for i in range(rated.size() - 1, -1, -1):
		var id := str(rated[i]["id"])
		var p := list_player(id)
		if p.is_empty() or hurt.has(id) or gone.has(id):
			continue
		if not out.has("heavy_loss"):
			out["heavy_loss"] = {"id": id, "name": GameDB.player_display_name(p)}
		if not out.has("young_side") and MediaConference.is_young(float(p.get("age", 30.0))):
			out["young_side"] = {"id": id, "name": GameDB.player_display_name(p)}
	var mb := MatchStory.my_best(res, side)
	if not mb.is_empty() and not list_player(str(mb["id"])).is_empty() and not gone.has(str(mb["id"])):
		out["big_win"] = {"id": str(mb["id"]), "name": GameDB.player_display_name(list_player(str(mb["id"])))}
	return out


## Your standing with a journalist, -2..+2 (director 2026-11-06, Q1). Absent
## means even. It fades one step toward even a season, applied the first time
## it is read in a new season (no rollover code).
func press_standing(journalist: String) -> int:
	_press_standing_decay()
	var st: Dictionary = media_memory.get("standing", {}) if media_memory.get("standing") is Dictionary else {}
	return clampi(int(st.get(journalist, 0)), MediaConference.STANDING_MIN, MediaConference.STANDING_MAX)


func _press_standing_decay() -> void:
	if not (media_memory.get("standing") is Dictionary):
		return
	var year := int(media_memory.get("standing_year", season_year))
	if year >= season_year:
		media_memory["standing_year"] = maxi(year, season_year)
		return
	var st: Dictionary = media_memory["standing"]
	for j in st.keys():
		var v := MediaConference.standing_decayed(int(st[j]), season_year - year)
		if v == 0:
			st.erase(j)
		else:
			st[j] = v
	media_memory["standing_year"] = season_year


func _set_press_standing(journalist: String, v: int) -> void:
	_press_standing_decay()
	var st: Dictionary = media_memory.get("standing", {}) if media_memory.get("standing") is Dictionary else {}
	if v == 0:
		st.erase(journalist)
	else:
		st[journalist] = v
	media_memory["standing"] = st
	media_memory["standing_year"] = season_year


## Press morale fades a point every second round, whoever asked, before this
## week's question forms (ruling 5.54: effects decay). A player who has left
## your list (traded, signed elsewhere, released, or left behind by your own
## club move) keeps fading at the same pace: every list and the free agents.
func _fade_press_lifts() -> void:
	if season == null:
		return
	var round_no := season.round_index if last_phase == "regular" else season.regular_rounds() + int((season.finals.get("weeks", []) as Array).size())
	var faded := {}
	for p in my_list:
		MediaConference.fade_lift(p, round_no)
		faded[str(p.get("id", ""))] = true
	var others := free_agents.duplicate()
	for code in season.lists:
		others.append_array(season.lists[code])
	for p in others:
		if p.has("press_lift") and not faded.has(str(p.get("id", ""))):
			MediaConference.fade_lift(p, round_no)
			faded[str(p.get("id", ""))] = true
	# The board's press move fades the same way (a point a round).
	var lift := int(media_memory.get("board_lift", 0))
	if lift != 0:
		if not board.is_empty():
			board["confidence"] = clampi(board_confidence() - signi(lift), 0, 100)
		lift -= signi(lift)
		if lift == 0:
			media_memory.erase("board_lift")
		else:
			media_memory["board_lift"] = lift


## Moves board confidence by a press answer's `delta`, through the board's
## press lift (media_memory "board_lift"): stacked answers never pass BOARD_CAP
## and only what really moved is kept to fade. Returns the change applied.
func _press_board(delta: int) -> int:
	if board.is_empty() or delta == 0:
		return 0
	var old := int(media_memory.get("board_lift", 0))
	var want := clampi(old + delta, mini(-MediaConference.BOARD_CAP, old), maxi(MediaConference.BOARD_CAP, old))
	var before := board_confidence()
	board["confidence"] = clampi(before + want - old, 0, 100)
	var moved := board_confidence() - before
	if old + moved == 0:
		media_memory.erase("board_lift")
	else:
		media_memory["board_lift"] = old + moved
	return moved


## The record the Stats Geek reads (ruling 5.48): ladder, place, form and the
## losing run, all already saved.
func press_record() -> Dictionary:
	var row := my_ladder_row()
	var form := club_form_info(my_club)
	return {"w": int(row.get("w", 0)), "l": int(row.get("l", 0)), "d": int(row.get("d", 0)),
			"pct": float(row.get("pct", 0.0)), "pos": my_position(), "form": float(form.get("value", 0.0)),
			"last": str(form.get("last", "")), "streak": losing_streak}


func backing_talk_pending() -> bool:
	return not backing_talk.is_empty()


func close_backing_talk() -> void:
	backing_talk = {}
	mark_dirty()


func media_conference_pending() -> bool:
	return not media_conference.is_empty()



func skip_media_conference() -> void:
	if media_conference.is_empty():
		return
	media_memory[str(media_conference.get("key", ""))] = {"year": season_year, "round": int(media_conference.get("round", 0))}
	media_conference = {}
	mark_dirty()
	autosave()


## What a press answer's odds follow (MediaConference.chance): the group's
## mood, a young side, who asked, what the question is about, your standing
## with him, and for answer `option` the record check and the named player.
func press_facts(option := -1) -> Dictionary:
	var total := 0
	for p in my_list:
		total += ClubLife.morale(p)
	var j := str(media_conference.get("journalist", ""))
	var f := {"morale": float(total) / float(maxi(1, my_list.size())) if not my_list.is_empty() else float(ClubLife.MORALE_BASE),
			"young": int(media_conference.get("young", 0)), "journalist": j,
			"key": str(media_conference.get("key", "")), "standing": press_standing(j)}
	var opts: Array = media_conference.get("options", [])
	if option >= 0 and option < opts.size():
		var kind := MediaConference.kind_of(opts[option], option)
		f["verdict"] = press_verdict(kind)
		var his := list_player(str((opts[option] as Dictionary).get("player", "")))
		if not his.is_empty():
			f["his_morale"] = float(ClubLife.morale(his))
			f["his_age"] = float(his.get("age", 30.0))
			f["name"] = GameDB.player_display_name(his)
	return f


## The Stats Geek's verdict on an answer ("" for anyone else).
func press_verdict(kind: String) -> String:
	if not bool((MediaConference.PERSONA.get(str(media_conference.get("journalist", "")), {}) as Dictionary).get("record", false)):
		return ""
	return MediaConference.record_verdict(kind, press_record())


## The chance (percent) that the pending question's answer `option` lands its
## first way; the gate shows it and resolve_media_conference rolls against it.
func press_chance(option: int) -> int:
	var opts: Array = media_conference.get("options", [])
	if option < 0 or option >= opts.size():
		return 0
	return MediaConference.chance(MediaConference.kind_of(opts[option], option), press_facts(option))


## {"journalist", "verdict", "name", "standing", "facts"} for answer
## `option`: what its effects and its line follow.
func press_context(option: int) -> Dictionary:
	var opts: Array = media_conference.get("options", [])
	if option < 0 or option >= opts.size():
		return {}
	var o: Dictionary = opts[option]
	var kind := MediaConference.kind_of(o, option)
	var name := str(o.get("name", ""))
	var his := list_player(str(o.get("player", "")))
	if not his.is_empty():
		name = GameDB.player_display_name(his)
	var j := str(media_conference.get("journalist", ""))
	# Backing a player you called out gives back his opinion of you (director 2026-11-08).
	var restore := 0
	var owed: Array = (media_memory.get("callouts", {}) as Dictionary).get(str(o.get("player", "")), [])
	if kind == "back_named" and not owed.is_empty():
		restore = Trust.opinion_move(Trust.value(relations, Trust.player_key(str(o["player"]))), -int(owed.back()))
	return {"journalist": j, "verdict": press_verdict(kind), "name": name,
			"standing": press_standing(j) if MediaConference.JOURNALISTS.has(j) else 0, "facts": press_facts(option),
			"lost": MediaConference.after_loss(media_conference), "won": MediaConference.after_win(media_conference),
			"restore": restore}


## The line under answer `option` (MediaConference.odds_line).
func press_odds_line(option: int) -> String:
	var opts: Array = media_conference.get("options", [])
	if option < 0 or option >= opts.size():
		return ""
	var kind := MediaConference.kind_of(opts[option], option)
	var ctx := press_context(option)
	return MediaConference.odds_line(kind, press_chance(option), MediaConference.effects(kind, ctx), ctx)


## The question as asked: his lead-in, then the question.
func press_question_text() -> String:
	var lead := str(media_conference.get("lead", ""))
	var q := str(media_conference.get("question", ""))
	return q if lead == "" else "%s %s" % [lead, q]


## Under the byline: "Gary's opinion of you is Warm: every answer is 5% more
## likely to land well."; "" when Neutral.
func press_standing_line() -> String:
	var j := str(media_conference.get("journalist", ""))
	if not MediaConference.JOURNALISTS.has(j):
		return ""
	return MediaConference.standing_effect(j, press_standing(j))


## The Stats Geek's record line, "" for anyone else.
func press_record_line() -> String:
	if not bool((MediaConference.PERSONA.get(str(media_conference.get("journalist", "")), {}) as Dictionary).get("record", false)):
		return ""
	var rec := press_record()
	if int(rec["w"]) + int(rec["l"]) + int(rec["d"]) < MediaConference.RECORD_MIN_GAMES:
		return str(MediaConference.RECORD_CLAUSE["early"])
	return MediaConference.record_line(rec)


## The answer is a roll (bible; director 2026-10-18, ch. 30 row 33): drawn
## once, now, from the career's press stream, against the odds the gate showed.
## Returns how it landed ({"kind", "landed": "a"|"b", "chance", "line"}), {}
## when there is nothing to answer.
func resolve_media_conference(option: int) -> Dictionary:
	if media_conference.is_empty():
		return {}
	var opts: Array = media_conference.get("options", [])
	if option < 0 or option >= opts.size():
		return {}
	var picked: Dictionary = opts[option]
	var kind := MediaConference.kind_of(picked, option)
	Archetypes.tally_press(coach_arch, kind)
	var odds := press_chance(option)
	var ctx := press_context(option)
	var fx := MediaConference.effects(kind, ctx)
	var key := str(media_conference.get("key", ""))
	var round_no := int(media_conference.get("round", 0))
	var j := str(media_conference.get("journalist", ""))
	var landed := "a" if MediaConference.roll(career_seed, season_year, round_no, key, option) <= odds else "b"
	var out: Dictionary = fx[landed]
	var board_moved := _press_board(int(out["board"]))
	if board_moved != 0:
		# Added to the board's match reason, never in place of it (director 2026-11-06).
		board["why"] = (str(board.get("why", "")).strip_edges() + " "
				+ MediaConference.board_sentence(j, board_moved)).strip_edges()
	var morale_delta := int(out["morale"])
	# After a loss a lift stops just below what a win gave (director 2026-11-07).
	var up := MediaConference.LOSS_LIFT_CAP if bool(ctx.get("lost", false)) else -1
	if morale_delta != 0:
		for p in my_list:
			MediaConference.apply_lift(p, morale_delta, MediaConference.LIST_CAP, up)
	var his := list_player(str(picked.get("player", "")))
	if int(out["his"]) != 0 and not his.is_empty():
		MediaConference.apply_lift(his, int(out["his"]), MediaConference.NAMED_CAP, up)
	var opinion := _press_opinion(kind, his, int(out.get("opinion", 0)), round_no)
	var before := press_standing(j)
	var after := MediaConference.standing_after(before, MediaConference.standing_move(j, kind, str(ctx.get("verdict", ""))))
	if MediaConference.JOURNALISTS.has(j) and after != before:
		_set_press_standing(j, after)
	media_memory[key] = {"year": season_year, "round": round_no}
	# What you said, so a journalist can hold you to it later this season.
	media_memory["said|" + key] = {"year": season_year, "option": option,
			"opp": str(media_conference.get("opp", "")), "round": round_no}
	var line := MediaConference.after_line(kind, landed, fx, str(ctx.get("name", "")))
	add_news("media", ("Post-match: '%s' %s %s" % [str(picked.get("label", "")), line,
			MediaConference.opinion_after(opinion)]).strip_edges())
	media_conference = {}
	mark_dirty()
	autosave()
	var size := maxi(absi(int(out["morale"])), absi(int(out["his"])))
	return {"kind": kind, "landed": landed, "chance": odds, "line": line, "journalist": j,
			"standing": [before, after], "verdict": str(ctx.get("verdict", "")), "effects": out, "opinion": opinion,
			"fade_rounds": maxi(MediaConference.fade_rounds(size), MediaConference.board_fade_rounds(board_moved)),
			"fade_morale": MediaConference.fade_rounds(size), "fade_board": MediaConference.board_fade_rounds(board_moved)}



## A named answer and his opinion of you (director 2026-11-08). Calling him
## out and his taking it personally costs `move` points (trust twice that),
## kept in media_memory["callouts"] so backing him by name later gives the
## latest one back, whichever way the backing lands. Returns {"name", "from",
## "to"} (out of 100) when it moved, else {}.
func _press_opinion(kind: String, his: Dictionary, move: int, round_no: int) -> Dictionary:
	if his.is_empty():
		return {}
	var pid := str(his.get("id", ""))
	var key := Trust.player_key(pid)
	var from := Trust.value(relations, key)
	var when := last_label if last_label != "" else (season.round_name(round_no - 1) if season != null else "Round %d" % round_no)
	var callouts: Dictionary = media_memory.get("callouts", {})
	var owed: Array = callouts.get(pid, [])
	if kind == "criticise_named" and move < 0:
		var d := Trust.change(relations, key, move * Trust.PER_POINT, "You called him out in the press", season_year, when)
		if d != 0:
			owed.append(d)
	elif kind == "back_named" and not owed.is_empty():
		Trust.change(relations, key, -int(owed.pop_back()), "You backed him in the press after calling him out", season_year, when)
	if owed.is_empty():
		callouts.erase(pid)
	else:
		callouts[pid] = owed
	if callouts.is_empty():
		media_memory.erase("callouts")
	else:
		media_memory["callouts"] = callouts
	var to := Trust.value(relations, key)
	if to == from:
		return {}
	return {"name": GameDB.player_display_name(his), "from": Trust.opinion(from), "to": Trust.opinion(to)}


## Season over: did you meet the goal? The board's confidence at the end decides a
## warning and then the sack (ClubLife.season_end).
func _board_season_end() -> void:
	if board.is_empty():
		return
	var row := my_ladder_row()
	var goal: Dictionary = board.get("goal", {})
	var met := ClubLife.goal_met(goal, my_position(), int(row.get("w", 0)), season.clubs.size())
	var conf := ClubLife.after_season(board_confidence(), met, premier() == my_club)
	var end := ClubLife.season_end(conf, met, bool(board.get("warned", false)),
			int(board.get("poor_seasons", 0)), difficulty_rules())
	conf = int(end["confidence"])
	var verdict := str(end["verdict"])
	board["warned"] = bool(end["warned"])
	board["poor_seasons"] = int(end["poor_seasons"])
	if bool(end["sacked"]):
		board["sacked"] = true
	board["confidence"] = conf
	(board["history"] as Array).append({"year": season_year, "goal": str(goal.get("text", "")),
			"met": met, "position": my_position(), "confidence": conf, "verdict": verdict})
	board["verdict"] = verdict
	board["why"] = verdict
	add_news("board", "%s board: %s (%s)" % [GameDB.club_name(my_club), verdict,
			"goal met" if met else "goal missed: " + str(goal.get("text", ""))])


func _next_week_event() -> void:
	ExpansionBuild.week(self)
	_dev_promise_week()
	week_events = []
	# The league's real year events land whatever your week holds (a sacked
	# coach's club still pays its fine); your club's cards come first.
	var year_cards := YearEvents.week(self) if my_club != "" else []
	if season == null or is_sacked() or not stories_on or my_club == "":
		return
	week_events = ClubStories.pick(self)
	for i in range(year_cards.size() - 1, -1, -1):
		week_events.push_front(year_cards[i])
	ClubArcs.week(self)
	LegacyRollover.week(self)


## Skip to the end of the season (director, 2026-11-07: "We need to bring back
## the ability to skip full seasons"; 2026-11-08: "It's just skipping games, no
## off season skipping"). Every week left, the finals included, is played out
## without you, exactly as Sim the week plays it, following the survey's
## answers (SkipOrders). It stops once the season is over, where the last Sim
## the week stops (the last match opens the off-season, so rivals settle their
## contracts as always): re-signings, trades, free agency and the draft stay yours.
## The last week's card is left for you, as after Sim the week. Sacked on the
## way, it stops there. Saved once, at the end.
## `to` (director, 2026-11-09: "the option to skip just the home and away
## season"): "home_away" stops after the last home-and-away round, with the
## finals drawn and yours to coach; "season" plays on to the end of the finals.
## Returns {"ok", "year", "weeks", "reason": "done" | "sacked" | "none"}.
func skip_season(orders := {}, to := "season") -> Dictionary:
	var job := skip_begin(orders, to)
	while skip_step(job):
		pass
	return skip_finish(job)


## skip_season in steps, one week each, so the loading cover can show a frame
## (and the round) between weeks: skip_begin, skip_step until false, then
## skip_finish. The same calls in the same order as skip_season.
func skip_begin(orders := {}, to := "season") -> Dictionary:
	if season == null or is_sacked() or _skip_reached(to):
		return {"ok": false, "year": season_year, "weeks": 0, "reason": "none", "to": to, "done": true}
	_batching = true
	_skip_orders = SkipOrders.defaults(club_plan)
	_skip_orders.merge(orders, true)
	# The survey's answers (SkipOrders): the game plan stands as your plan; a
	# run for the kids needs auto-pick, which names a promised player.
	set_club_plan(str(_skip_orders["game_plan"]))
	if str(_skip_orders["youth"]) == "kids" and not season.is_regular_done() and not my_selection().is_empty():
		set_selection({})
	return {"year": season_year, "weeks": 0, "to": to}


## Plays the next week of a skip. False once there is nothing left to play.
func skip_step(job: Dictionary) -> bool:
	if bool(job.get("done", false)):
		return false
	var to := str(job["to"])
	if season == null or _skip_reached(to) or int(job["weeks"]) >= 80 or is_sacked():
		return false
	if str(_skip_orders["youth"]) == "kids":
		_skip_back_kids(to)
	advance()
	job["weeks"] = int(job["weeks"]) + 1
	return not is_sacked()


## skip_step with the week's matches on threads while frames keep drawing.
func skip_step_async(job: Dictionary) -> bool:
	if bool(job.get("done", false)):
		return false
	var to := str(job["to"])
	if season == null or _skip_reached(to) or int(job["weeks"]) >= 80 or is_sacked():
		return false
	if str(_skip_orders["youth"]) == "kids":
		_skip_back_kids(to)
	await advance_async()
	job["weeks"] = int(job["weeks"]) + 1
	return not is_sacked()


## Ends a skip: saved once. {"ok", "year", "weeks", "reason": "done" | "sacked" | "none"}.
func skip_finish(job: Dictionary) -> Dictionary:
	if bool(job.get("done", false)):
		return {"ok": false, "year": job["year"], "weeks": 0, "reason": "none"}
	var year := int(job["year"])
	var weeks := int(job["weeks"])
	if is_sacked() or season == null or not _skip_reached(str(job["to"])):
		_batching = false
		_skip_orders = {}
		autosave()
		return {"ok": false, "year": year, "weeks": weeks, "reason": "sacked"}
	_batching = false
	_skip_orders = {}
	mark_dirty()
	autosave()
	return {"ok": true, "year": year, "weeks": weeks, "reason": "done"}


## The cover's line while a skip plays the coming week: the round of the
## season's rounds, or the finals.
func skip_progress() -> String:
	if season == null:
		return ""
	if not season.is_regular_done():
		return "Playing %s..." % season.round_progress(season.round_index)
	return "Playing the finals..."


## Has the skip got where it was going?
func _skip_reached(to: String) -> bool:
	return season.is_regular_done() if to == "home_away" else season.is_season_over()


## Your matches left in the home and away, the bye not counted.
func _home_away_games_left() -> int:
	var n := 0
	for r in range(season.round_index, season.fixture.size()):
		for m in season.fixture[r]:
			if m["home"] == my_club or m["away"] == my_club:
				n += 1
				break
	return n


## The survey's questions for this skip, only those it can still act on: with
## the home and away done no new run can start, and with no match left there is
## no plan to set; the week's cards always remain.
func skip_questions(to := "season") -> Array:
	var done := season.is_regular_done()
	var status := my_finals_status()
	var has_match := not done or status not in ["", "eliminated", "premier", "runner_up"]
	var out := []
	for q in SkipOrders.questions(to):
		match str(q["key"]):
			"game_plan":
				if has_match:
					out.append(q)
			"youth":
				if not done and (to != "home_away" or _home_away_games_left() >= Backing.RUN_GAMES):
					out.append(q)
			_:
				out.append(q)
	return out


## "Give the kids a run" (SkipOrders): before each week of the skip, your
## best players with few senior games are promised runs (Backing) until
## SkipOrders.YOUTH_RUNS are on at once; auto-pick names them. A skip that stops
## at the home and away starts no run it cannot finish: the finals are the
## coach's own, so a promise made for him must not bind his side there.
func _skip_back_kids(to := "season") -> void:
	if to == "home_away" and _home_away_games_left() < Backing.RUN_GAMES:
		return
	var on := 0
	var kids := []
	for p in my_list:
		if Backing.is_active(p):
			on += 1
		elif can_back(p):
			kids.append(p)
	kids.sort_custom(func(a, b):
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		return str(a["id"]) < str(b["id"]))
	for p in kids:
		if on >= SkipOrders.YOUTH_RUNS:
			break
		_start_backing(p)
		on += 1


func week_event_pending() -> bool:
	for c in week_events:
		if not bool((c as Dictionary).get("resolved", false)):
			return true
	return false


## Before a round is played, every unanswered card settles: no benefit comes
## without a choice. It changes nothing unless not acting has its own
## consequence (the card's "default": a sore star plays sore; "unanswered":
## silence costs the board).
func _settle_week_event() -> void:
	for i in range(week_events.size()):
		var card: Dictionary = week_events[i]
		if bool(card.get("resolved", false)):
			continue
		# Away on a skip, the survey's answer to the week's questions (SkipOrders).
		var pick := SkipOrders.card_choice(card, str(_skip_orders.get("questions", "usual")))
		if pick >= 0:
			resolve_card(i, pick)
			continue
		var d := int(card.get("default", -1))
		if d >= 0:
			resolve_card(i, d)
			continue
		var cost: Dictionary = card.get("unanswered", {})
		if int(cost.get("board", 0)) != 0 and not board.is_empty():
			board["confidence"] = clampi(board_confidence() + int(cost["board"]), 0, 100)
		if int(cost.get("trust", 0)) != 0 and str(card.get("player_id", "")) != "":
			var facts: Dictionary = card.get("facts", {})
			var when := season.round_name(int(facts.get("round", 1)) - 1) if int(facts.get("finals_week", 0)) == 0 else "Finals"
			Trust.change(relations, Trust.player_key(str(card["player_id"])), int(cost["trust"]),
					str(cost.get("why", "You said nothing")), int(season_year), when)
		card["resolved"] = true
		card["choice"] = -1
		card["outcome"] = str(cost.get("text", "Business as usual."))
		StoryEngine.record_choice(story, card, -1, story_week())
		ClubArcs.answered(self, card, -1)
		mark_dirty()


## Answer the first card still waiting. Returns what happened.
func resolve_week_event(choice: int) -> String:
	for i in range(week_events.size()):
		if not bool((week_events[i] as Dictionary).get("resolved", false)):
			return resolve_card(i, choice)
	return ""


## Answer card `index` of this week's cards with `choice`. Returns what
## happened, in words, ending with what changed in trust and the board.
func resolve_card(index: int, choice: int) -> String:
	if index < 0 or index >= week_events.size():
		return ""
	var card: Dictionary = week_events[index]
	if bool(card.get("resolved", false)):
		return ""
	var options: Array = card.get("options", [])
	if options.is_empty():
		return ""
	choice = clampi(choice, 0, options.size() - 1)
	var out := ClubStories.apply_choice(self, card, choice)
	StoryEngine.record_choice(story, card, choice, story_week())
	card["resolved"] = true
	card["choice"] = choice
	card["outcome"] = out
	ClubArcs.answered(self, card, choice)
	LegacyRollover.answered(self, card, choice)
	mark_dirty()
	return out


## This week on the stories' calendar (StoryEngine.week_abs).
func story_week() -> int:
	return StoryEngine.week_abs(season_year, ClubStories.week_in_season(self))


## One card from the deck, built for this week about `p` (or the club),
## whether or not it would come up: for tests and captures.
func story_card(tid: String, p: Dictionary = {}) -> Dictionary:
	return ClubStories.card_for(self, tid, p)


# ---------------------------------------------------------------------------
# Backing a young player (Backing.gd)
# ---------------------------------------------------------------------------
## Can this player be backed from selection? Few senior games on a career on
## record in full, available to play, no run on already, and a match to play.
func can_back(p: Dictionary) -> bool:
	if season == null or my_club == "" or list_player(str(p.get("id", ""))).is_empty():
		return false
	if my_next_opponent().is_empty():
		return false
	return Backing.can_back(p, games_played(p))


## Promise a player a run, from selection. Returns what to tell the coach, or
## "" when he cannot be backed.
func back_player(player_id: String) -> String:
	var p := list_player(player_id)
	if p.is_empty() or not can_back(p):
		return ""
	var named := false
	var side := current_side()
	for k in side:
		if (side[k] as Array).has(str(p["id"])):
			named = true
	var dropped := _start_backing(p)
	var out := "%s has your word for %s games." % [GameDB.player_display_name(p),
			MatchNotes.count_word(Backing.RUN_GAMES)]
	if not named:
		out += " " + promised_in_words(p, dropped)
	return out


## What naming him does to the side, in words: who he comes in for.
static func backed_in_words(dropped: String) -> String:
	return "He's in the side this week%s." % ((", in place of %s" % dropped) if dropped != "" else "")


## Every one of the 23 is held by a player owed a game (or on a role trial):
## a promised man cannot be named, and says so rather than claiming a place.
const NO_ROOM_WORDS := "There's no room for him in the 23 this week: every spot is held by a player you've promised a game."


## What a promise did to this week's side, in words, after name_promised: who
## he came in for, or why he is not in it.
func promised_in_words(p: Dictionary, dropped: String) -> String:
	if in_current_side(p):
		return backed_in_words(dropped)
	if not Ratings.available(p):
		if dropped != "":
			return "He's named in place of %s, but can't play this week." % dropped
		return "He can't play this week."
	return NO_ROOM_WORDS


## Owed a game this week: a run (Backing), a card's "a game this week", or
## the games of a development talk.
static func _promised_game(q: Dictionary) -> bool:
	return Backing.is_active(q) or q.has("expects_game") or not _dev_owed(q).is_empty()


## Never the one to make way for a promised player: another promised player,
## or the player on a role trial (the trial needs him in the side).
func _keeps_place(q: Dictionary) -> bool:
	return _promised_game(q) or (not role_trial.is_empty() and str(role_trial.get("id", "")) == str(q.get("id", "")))


## After a match: the fit promised players who could not have been named,
## by id. In a side you named, every place in his line and on the bench was
## held by a player who keeps it (_swap_in says no room); on Auto-pick, every
## one who took the field was owed a game or on a trial.
func _no_room_ids(played: Dictionary) -> Dictionary:
	var out := {}
	var sel := my_selection()
	var all_kept := not played.is_empty()
	for id in played:
		var q := list_player(str(id))
		if q.is_empty() or not _keeps_place(q):
			all_kept = false
	for p in my_list:
		if not _promised_game(p) or played.has(str(p["id"])):
			continue
		if (all_kept if sel.is_empty() else _swap_in(sel.duplicate(true), p).has("no_room")):
			out[str(p["id"])] = true
	return out


## Start a run for one of your players: the week's match is his first game if
## he plays it. He is thrilled, and he expects to be picked: auto-pick names
## him while the run is on, and a side you named takes him in at once
## (director, 2026-11-10: "if u accept, the player is not automatically in the
## team even though he should be"). Returns the name of the player he comes in
## for, or "" (already in the side, or nobody had to make way).
func _start_backing(p: Dictionary) -> String:
	if Backing.is_active(p):
		return ""
	var dropped := name_promised(p)
	var round_no := 0 if season.is_regular_done() else season.round_index + 1
	Backing.start(p, season_year, round_no, games_played(p))
	ClubLife.add_morale(p, Backing.THRILL)
	p["expects_game"] = Backing.STING
	mark_dirty()
	return dropped


## A game you promised him (a run, a card's "a game this week", the games of a
## development talk): a side you named takes him in at once (backing_swap), so
## the List, Selection and the match all show him from the moment you say it;
## auto-pick names him by itself. Call it before he is marked as owed the game.
## Returns the name of the player he comes in for, or "" (already in the side,
## or nobody had to make way).
func name_promised(p: Dictionary) -> String:
	var swap := backing_swap(p)
	var dropped := backing_drop_name(p) if swap.is_empty() else ""
	if not (swap.get("out", {}) as Dictionary).is_empty():
		dropped = GameDB.player_display_name(swap["out"])
	if not (swap.get("sel", {}) as Dictionary).is_empty():
		var keep: Dictionary = swap["sel"]
		keep["DUAL_RUCK"] = user_dual_ruck
		var stored: Dictionary = season.selections.get(my_club, {})
		if stored.has("TRIAL"):
			keep["TRIAL"] = stored["TRIAL"]
		season.selections[my_club] = keep
		mark_dirty()
	return dropped


## Is he in the side that would take the field this week (ground or bench)?
func in_current_side(p: Dictionary) -> bool:
	var id := str(p.get("id", ""))
	var side := current_side()
	for k in side:
		if (side[k] as Array).has(id):
			return true
	return false


## A side you named, with him put in it for a run: {"sel": the new side,
## "out": the player who makes way ({} when a gap took him)}, or {} on
## Auto-pick or when he is already named. He takes the place of, in order: a
## player named in his line who cannot play this week, the lowest-rated
## player named in his line who is not owed a game himself, the
## lowest-rated such player on the bench. The one who makes way goes to the
## players left out.
func backing_swap(p: Dictionary) -> Dictionary:
	return _swap_in(my_selection(), p)


## backing_swap on any selection (`sel` is changed: pass a copy). {} when
## `sel` is empty or he is already named (a man suspended or injured is still
## named for his run, and it waits for him); {"no_room": true} when every
## place in his line and on the bench is held by a player who keeps it
## (_keeps_place) and the bench is full.
func _swap_in(sel: Dictionary, p: Dictionary) -> Dictionary:
	if sel.is_empty():
		return {}
	var id := str(p.get("id", ""))
	for k in sel:
		if k != "OUT" and sel[k] is Array and (sel[k] as Array).has(id):
			return {}
	var role := str(p.get("role", "MID"))
	var lines: Array = ["MID", "WING"] if role == "MID" else [role]
	var best := {}
	var best_key := ""
	var best_rank := INF
	for pass_keys in [lines, ["BENCH"]]:
		for k in pass_keys:
			for other_id in (sel.get(k, []) as Array):
				var q := list_player(str(other_id))
				if q.is_empty():
					continue
				if _keeps_place(q):
					continue
				# Out this week anyway first; then the lowest rated.
				var rank := float(q.get("overall", 0)) - (1000.0 if not Ratings.available(q) else 0.0)
				if rank < best_rank:
					best_rank = rank
					best = q
					best_key = str(k)
		if not best.is_empty():
			break
	var out_list: Array = (sel.get("OUT", []) as Array).duplicate()
	out_list.erase(id)
	if best.is_empty():
		# Nobody can make way: he goes on the bench if it has a spot (a sixth
		# name would not make the 23), and the pick fills round him.
		var bench: Array = (sel.get("BENCH", []) as Array).duplicate()
		var fit_bench := 0
		for b in bench:
			var bq := list_player(str(b))
			if not bq.is_empty() and Ratings.available(bq):
				fit_bench += 1
		if fit_bench >= Ratings.bench():
			return {"no_room": true}
		bench.append(id)
		sel["BENCH"] = bench
		sel["OUT"] = out_list
		return {"sel": sel, "out": {}}
	var arr: Array = (sel[best_key] as Array).duplicate()
	arr[arr.find(str(best["id"]))] = id
	sel[best_key] = arr
	out_list.append(str(best["id"]))
	sel["OUT"] = out_list
	return {"sel": sel, "out": best}


## The name of the player who would make way if he were backed now, or "":
## in a side you named, the one backing_swap takes out; on Auto-pick, the
## one Auto-pick would leave out to name him. Read-only.
## `before`: this week's side when the caller has it already.
func backing_drop_name(p: Dictionary, before: Dictionary = {}) -> String:
	if season == null or my_club == "":
		return ""
	if before.is_empty():
		before = current_side()
	for k in before:
		if (before[k] as Array).has(str(p.get("id", ""))):
			return ""
	if not my_selection().is_empty():
		var out: Dictionary = backing_swap(p).get("out", {})
		return GameDB.player_display_name(out) if not out.is_empty() else ""
	var had := p.has("expects_game")
	if not had:
		p["expects_game"] = Backing.STING
	var after := current_side()
	if not had:
		p.erase("expects_game")
	var now := {}
	for k in after:
		for x in after[k]:
			now[str(x)] = true
	for k in before:
		for x in before[k]:
			if not now.has(str(x)):
				return GameDB.player_display_name(list_player(str(x)))
	return ""


## One line for each run you have promised, as Selection shows them. A named
## side that leaves a fit one out says so (auto-pick always names him).
func backing_notes() -> Array:
	var out := []
	var sel := my_selection()
	var named := {}
	for k in sel:
		if k == "OUT":
			continue   # left out on purpose: not named
		for id in sel[k]:
			named[str(id)] = true
	for p in my_list:
		var line := Backing.note(p, sel.is_empty() or named.has(str(p["id"])))
		if line != "":
			out.append({"key": "backing", "player_id": str(p["id"]), "text": line})
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
	var ctx := _coach_market_ctx(coaches, coach_archive)
	ctx["protected"] = _protected_coaches()
	# The ones leaving go to the job they were offered, when it opens.
	var promised := {}
	for a in coach_approaches:
		if not bool(a.get("kept", false)):
			promised[str(a["cid"])] = [str(a["club"]), str(a["job"])]
	ctx["promised"] = promised
	var out := CoachMarket.offseason(ctx)
	for v in out["vacancies"]:
		if not _vacancy_open(str(v["job"])):
			staff_vacancies.append(v)
	for t in out["news"]:
		add_news("coaching", str(t))
	coach_approaches = []


## Your club's season as a coach weighs it when a rival approaches him
## (CoachMarket.stay_chance): board goal met, finals, a flag.
func _my_coach_result() -> Dictionary:
	if season == null:
		return {}
	var r: Dictionary = (_coach_market_ctx({}, {})["results"] as Dictionary).get(my_club, {}).duplicate()
	r["flag"] = premier() == my_club
	return r


## The market's view of the season just played: each club's board goal met
## or not, from the ladder as it stands.
func _coach_market_ctx(the_coaches: Dictionary, archive: Dictionary) -> Dictionary:
	var results := {}
	var table := season.ladder_sorted()
	var club_count := table.size()
	for i in range(table.size()):
		var row: Dictionary = table[i]
		var code := str(row["code"])
		var goal: Dictionary = club_goals.get(code, ClubLife.board_goal(int(club_expect.get(code, ClubLife.default_rank(club_count))), 0, club_count, season.finalists()))
		var pos := i + 1
		var met := ClubLife.goal_met(goal, pos, int(row.get("w", 0)), club_count)
		results[code] = {"met": met, "finals": pos <= season.finalists(),
				"severe": not met and pos >= table.size() - 2 and int(club_expect.get(code, club_count)) <= 10}
	return {"coaches": the_coaches, "archive": archive,
			"year": season_year, "my_club": my_club, "clubs": GameDB.active_clubs(season_year + 1),
			"results": results, "premier": premier(), "seed": career_seed}


## Your coaches no rival may take: everyone but those you let go or did not
## answer for. Nobody is poached from you without being asked about.
func _protected_coaches() -> Dictionary:
	var out := {}
	var going := {}
	for a in coach_approaches:
		if str(a.get("choice", "")) in ["", "go"] or (str(a.get("choice", "")) != "" and not bool(a.get("kept", false))):
			going[str(a["cid"])] = true
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) == "club" and str(c.get("club", "")) == my_club and not going.has(cid):
			out[cid] = true
	return out


## When the home-and-away season ends, the off-season market is run on a copy
## to see which of your coaches rival clubs will come for, and for what job.
## Each becomes an approach you answer through the finals.
func _find_coach_approaches() -> void:
	if season == null or coaches.is_empty() or not season.is_regular_done() \
			or season.is_season_over() or coach_approach_year == season_year:
		return
	coach_approach_year = season_year
	coach_approaches = []
	var copy: Dictionary = coaches.duplicate(true)
	CoachMarket.offseason(_coach_market_ctx(copy, coach_archive.duplicate(true)))
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) != "club" or str(c.get("club", "")) != my_club:
			continue
		var n: Dictionary = copy.get(cid, {})
		if str(n.get("status", "")) == "club" and str(n.get("club", "")) not in ["", my_club]:
			coach_approaches.append({"cid": cid, "from_job": str(c.get("job", "")), "club": str(n["club"]),
					"job": str(n["job"]), "choice": "", "kept": false, "text": ""})
	for a in coach_approaches:
		add_news("coaching", "%s want your %s, %s, as their %s." % [GameDB.club_name(str(a["club"])),
				CoachMarket._job_word(str(a["from_job"])), _coach_name(coaches[str(a["cid"])]),
				CoachMarket._job_word(str(a["job"]))])
	mark_dirty()


## Why you can't promise him the senior assistant's job, or "" when you can.
func approach_promise_block(i: int) -> String:
	if i < 0 or i >= coach_approaches.size():
		return "No such approach."
	var a: Dictionary = coach_approaches[i]
	if str(a["from_job"]) == "SA":
		return "He is already your senior assistant."
	if CoachMarket.holds_promise(coaches.get(str(a["cid"]), {}), my_club):
		return "You have already promised him that job."
	return ""


## How he weighs an answer, 0-100: he stays at CoachMarket.STAY_BAR (50) or
## more. No roll: the same weight gives the same answer every time.
func approach_weight(i: int, choice: String) -> int:
	if i < 0 or i >= coach_approaches.size() or choice == "go":
		return 0
	var a: Dictionary = coach_approaches[i]
	var c: Dictionary = coaches.get(str(a["cid"]), {})
	return int(round(100.0 * CoachMarket.stay_chance(c, choice, str(a["job"]), season_year, _my_coach_result())))


## Why you can't offer him senior assistant, or "" when you can.
func approach_promote_block(i: int) -> String:
	if i < 0 or i >= coach_approaches.size():
		return "No such approach."
	var a: Dictionary = coach_approaches[i]
	if str(a["from_job"]) == "SA":
		return "He is already your senior assistant."
	var staff := Coaches.staff(coaches, my_club)
	if staff.has("SA"):
		var sa: Dictionary = coaches.get(str(staff["SA"]), {})
		return "%s is your senior assistant." % _coach_name(sa)
	return ""


## Answer approach `i`: "promote" (senior assistant), "stay" (ask him to
## stay where he is) or "go". Returns what happened, in words.
func answer_approach(i: int, choice: String) -> String:
	if i < 0 or i >= coach_approaches.size():
		return ""
	var a: Dictionary = coach_approaches[i]
	if str(a["choice"]) != "":
		return str(a["text"])
	var c: Dictionary = coaches.get(str(a["cid"]), {})
	var who := _coach_name(c)
	var rival := GameDB.club_name(str(a["club"]))
	if choice == "promote" and approach_promote_block(i) != "":
		return approach_promote_block(i)
	if choice == "promise" and approach_promise_block(i) != "":
		return approach_promise_block(i)
	a["choice"] = choice
	if choice == "go":
		a["text"] = "%s will join %s after the season. You wished him well." % [who, rival]
	elif CoachMarket.stays(c, choice, str(a["job"]), season_year, career_seed, _my_coach_result()):
		a["kept"] = true
		if choice == "promote":
			var old := str(c.get("job", ""))
			CoachMarket.promote_to_sa(c, my_club, season_year, career_seed)
			_let_down("SA", str(a["cid"]))
			staff_vacancies.append({"job": old, "reason": "%s stepped up to senior assistant." % who})
			a["text"] = "%s turns %s down to become your senior assistant." % [who, rival]
		elif choice == "promise":
			CoachMarket.make_promise(c, season_year)
			a["text"] = "%s turns %s down. You have promised him the senior assistant's job by %d." % [
					who, rival, season_year + CoachMarket.PROMISE_SEASONS]
		else:
			a["text"] = "%s turns %s down and stays on." % [who, rival]
	else:
		a["text"] = "%s thanks you, but becomes %s's %s after the season." % [who, rival,
				CoachMarket._job_word(str(a["job"]))]
	add_news("coaching", str(a["text"]))
	mark_dirty()
	return str(a["text"])


func coach_approaches_open() -> int:
	var n := 0
	for a in coach_approaches:
		if str(a.get("choice", "")) == "":
			n += 1
	return n


func _coach_name(c: Dictionary) -> String:
	return CoachMarket._name(c) if not c.is_empty() else "He"


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
func _career_over(p: Dictionary, how := "retired") -> void:
	var gone_id := str(p.get("id", ""))
	HonourBoard.leave(self, p, how)
	if gone_id != "" and not departed_names.has(gone_id):
		var card := CareerFacts.name_card(p)
		# What a later generated son needs of him: his age, the year and his club.
		card["age"] = float(p.get("age", 0.0))
		card["year"] = season_year
		card["club"] = str(p.get("club", ""))
		departed_names[gone_id] = card
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
	_ensure_plan_known()
	CoachEffects.usual = _season_usuals()
	CoachEffects.relations = relations if culture_effects_on else {}
	if coaches.is_empty() or season == null:
		CoachEffects.table = {}
		return
	CoachEffects.my_arch = coach_arch
	CoachEffects.set_table(coaches, GameDB.active_clubs(season_year), my_club)
	# High performance sets how sharply the plan is carried out (row 99): your
	# club's budget, or an audit's level for an AI club; AI clubs otherwise run
	# Standard and keep their coaches' own figure untouched.
	for code in CoachEffects.table:
		var level := fitness_hp_level(str(code))
		if str(code) != my_club and level == ClubBudget.STANDARD:
			continue
		var t: Dictionary = CoachEffects.table[code]
		t["exec"] = clampf(float(t.get("exec", 1.0)) * ClubBudget.tactics_mult(level), 0.75, 1.35)


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
	_let_down(job, cid)
	_close_vacancy(job)
	if left != "":
		staff_vacancies.append({"job": left, "reason": "%s stepped up to %s." % [
				GameDB.player_display_name(coaches[cid]), CoachMarket._job_word(job)]})
	_dirty = true


func auto_fill_staff(job: String) -> void:
	var left := CoachMarket.auto_fill(coaches, my_club, job, season_year, career_seed)
	_let_down(job, str(Coaches.staff(coaches, my_club).get(job, "")))
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


## Your assistants whose term ends with this season, in the off-season:
## each waits for Re-sign or Release. Coach records, by job order.
func expiring_staff() -> Array:
	var out := []
	if not can_release_staff():
		return out
	for job in Coaches.JOBS:
		if job == "SC":
			continue
		var c: Dictionary = club_staff(my_club).get(job, {})
		if c.is_empty():
			continue
		CoachMarket.ensure_fields(c, season_year)
		if int(c.get("contract_to", season_year + 1)) <= season_year:
			out.append(c)
	return out


## Re-sign your expiring assistant on his terms (CoachMarket.assistant_stance).
func resign_staff(cid: String) -> void:
	if not coaches.has(cid):
		return
	var c: Dictionary = coaches[cid]
	if str(c.get("club", "")) != my_club or not expiring_staff().has(c):
		return
	CoachMarket.resign(c, season_year)
	_dirty = true


## At the rollover an assistant you did not decide on stays, on his terms -
## as an expiring player you leave alone is re-signed.
func _settle_staff_contracts() -> void:
	for c in expiring_staff():
		CoachMarket.resign(c, season_year)


## You gave `job` to `cid`: anyone you had promised it to hears about it.
func _let_down(job: String, cid: String) -> void:
	for line in CoachMarket.settle_promises(coaches, my_club, job, cid):
		add_news("coaching", str(line))


## A season starts: a promise to one of your coaches whose time is up and was
## not kept is broken, and the news says so.
func _expire_my_promises() -> void:
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if not CoachMarket.holds_promise(c, my_club):
			continue
		if str(c.get("status", "")) != "club" or str(c.get("club", "")) != my_club:
			c.erase("promise")
		elif int(c["promise"].get("by", 0)) <= season_year + 1:
			add_news("coaching", CoachMarket._broken_line(c))
			CoachMarket.break_promise(c)


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
const CLUB_PLANS := ["balanced", "attacking", "defensive", "contest", "controlled", "custom"]


## Your standing game plan: every match starts with it, played or simmed,
## and the quarter-break calls change it from there.
func set_club_plan(key: String) -> void:
	if not CLUB_PLANS.has(key) or (key == CustomPlan.KEY and not CustomPlan.ready(custom_plan)):
		return
	club_plan = key
	_sync_club_plan()
	mark_dirty()


## Your own plan's pick (CustomPlan): `part` "s" (the strength) or "c" (the
## cost), `id` from that list. A pick that clashes with the other part is
## refused (false). Every match on your own plan from the next bounce.
func set_custom_pick(part: String, id: String) -> bool:
	if part != "s" and part != "c":
		return false
	var p := custom_plan.duplicate()
	if p.is_empty():
		p = {"name": "", "s": "", "c": ""}
	p[part] = id
	if CustomPlan.clash(str(p.get("s", "")), str(p.get("c", ""))):
		return false
	var cleaned := CustomPlan.clean(p)
	if str(cleaned.get(part, "")) != id:
		return false
	custom_plan = cleaned
	_sync_club_plan()
	mark_dirty()
	return true


## Your own plan's name ("" for the default, CustomPlan.DEFAULT_NAME).
func set_custom_name(nm: String) -> void:
	var p := custom_plan.duplicate()
	if p.is_empty():
		p = {"name": "", "s": "", "c": ""}
	p["name"] = CustomPlan.name_clean(nm)
	custom_plan = CustomPlan.clean(p)
	_sync_club_plan()
	mark_dirty()


func _sync_club_plan() -> void:
	CoachEffects.my_custom = custom_plan.duplicate()
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
		row["book_games"] = int(row.get("book_games", 0)) + 1
		for k in TEAM_BOOK_KEYS:
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
	_note_position_ratings(res)
	if not is_my_match(res):
		return
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
		_note_trial_game(id, pts)


## Points from one kind of source; stoppages include centre bounces.
static func _source_pts(t: Dictionary, k: String) -> float:
	var v := float(t.get("score_from_" + k, 0.0))
	if k == "stoppage":
		v += float(t.get("score_from_centre", 0.0))
	return v


const FORM_GAMES := 3
const TEAM_KEYS := ["clearances", "inside50", "tackles", "pressure_acts", "marks",
		"rebounds", "clangers", "hitouts", "disposals", "metres_gained", "distance_run"]
## The club statistics added with the Stats patch. A club row counts its own
## games for them ("book_games"): an older save loaded mid-season starts them
## at that point, so a per-game figure is never spread over games it did not
## see.
const TEAM_BOOK_KEYS := ["kicks", "handballs", "contested_possessions", "uncontested_possessions",
		"ground_ball_gets", "running_bounces", "shots", "goals", "behinds", "intercepts",
		"one_percenters", "frees_for", "frees_against", "hitouts_adv", "contested_marks"]


## A club's season figure a game: scores for and against, and every team
## statistic (TEAM_KEYS, TEAM_BOOK_KEYS). -1 before it has played.
func club_per_game(code: String, key: String) -> float:
	var row: Dictionary = season_team.get(code, {})
	var g := int(row.get("book_games", row.get("games", 0))) if TEAM_BOOK_KEYS.has(key) else int(row.get("games", 0))
	if g <= 0:
		return -1.0
	return float(row.get(key, 0.0)) / float(g)


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
	"from_stoppage": 6.0, "conceded_stoppage": 6.0,
}
## Early reads are provisional: the difference counts games / (games + this).
const STYLE_SHRINK := 4
## A points-source line and the total it is part of.
const STYLE_PART_OF := {
	"from_stoppage": "for", "conceded_stoppage": "against",
}


## An opponent's usual game plan, said as what it does on the field (the
## same trade-offs as CoachReport.PLAN_PARTS, from their side). What it
## costs their legs follows it (RivalRead.legs_clause).
const THEIR_PLAN := {
	"balanced": "they play it straight, with no plan's extra edge and none of its costs.",
	"attacking": "they run it through the corridor for ground and better shots, and turn it over more.",
	"defensive": "they press high, so they win it back in their half, but there is space behind them when you get through.",
	"contest": "they put numbers at the stoppages to win the clearances, and the ball moves slower.",
	"controlled": "they keep the ball and make few errors, but gain less ground.",
}


## STYLE_LINES as said of an opponent: [when it helps them, when it hurts
## them]. Each says what it means on the field (director, 2026-10-07: a style
## with no football consequence is gibberish), never what to do about it.
const THEIR_STYLE := {
	"for": ["They kick big scores: more than most sides.", "They struggle to score: less than most sides."],
	"against": ["They are hard to score against: most sides kick less against them.",
			"They leak scores: most sides kick more against them."],
	"clearances": ["They win it at the stoppages: their midfield gets first hands to most ball-ups.",
			"They get beaten at the stoppages: their midfield rarely gets first hands."],
	"inside50": ["They live in their forward half: their opponents' defenders see a lot of the ball.",
			"They struggle to get it forward: their forwards see little of the ball."],
	"pressure_acts": ["They pressure the ball hard: ball carriers against them get tackled and rushed into turnovers.",
			"They barely pressure the ball: ball carriers against them get time to pick a target."],
	"marks": ["They keep it by foot and mark it: when they have it, the ball rarely hits the ground.",
			"They rarely mark it: their ball is won on the ground, at the contest."],
	"clangers": ["They look after the ball: they rarely hand it back.",
			"They turn it over: their mistakes hand the ball to their opponents."],
	"hitouts": ["Their ruck wins the tap: their midfield gets first use at the ball-ups.",
			"They get beaten in the ruck: their midfield rarely gets first use at the ball-ups."],
	"from_stoppage": ["They score from the stoppages: their clearances often become scores.",
			"They rarely score from the stoppages: their clearances seldom become scores."],
	"conceded_stoppage": ["They shut down stoppage scores: clearances against them rarely become scores.",
			"They give up scores from the stoppages: clearances against them often become scores."],
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
	"from_stoppage": ["We score from the stoppages: %d more points a game from them than the average side.",
			"We rarely score from the stoppages: %d fewer points a game from them than the average side.", false],
	"conceded_stoppage": ["We shut down their stoppage game: %d fewer points a game conceded from stoppages than the average side.",
			"They hurt us from the stoppages: %d more points a game conceded from them than the average side.", true],
}


# --- Sit-downs that grow out of what happened (RPG-003 slice 1) -------------

## What the week's sit-down may open on, per player of yours (ClubLife.
## talk_case): {id: {"games", "in_last_side", "selected", "age",
## "weeks_without", "injury", "kpi"}}. Only facts the game has kept.
func talk_info(selected: Dictionary) -> Dictionary:
	var out := {}
	if season == null:
		return out
	var last_ids := {}
	for id in last_side:
		last_ids[str(id)] = true
	for p in my_list:
		var id := str(p["id"])
		var kind := Backing.kpi_kind(p)
		var ks: Array = Backing.KPI[kind]["stats"]
		out[id] = {"games": games_played(p), "in_last_side": last_ids.has(id),
				"selected": selected.has(id), "age": float(p.get("age", 30.0)),
				"weeks_without": weeks_without_game(p), "injury": _back_from(p), "kpi": _kpi_text(p),
				"verdict": _kpi_verdict(p), "job": talk_job(p),
				"need": "%s and %s" % [Backing.KPI_LABEL[ks[0]], Backing.KPI_LABEL[ks[1]]]}
	return out


## Your rounds since his last senior game for you this season: the rounds
## played so far when he has none this season, -1 when an older save cannot
## say (it never kept the round).
func weeks_without_game(p: Dictionary) -> int:
	var lg = p.get("last_game", [])
	if lg is Array and (lg as Array).size() == 2 and int(lg[0]) == season_year:
		return maxi(0, season.round_index - int(lg[1]))
	if int((season_tally.get(str(p["id"]), {}) as Dictionary).get("games", 0)) == 0:
		return season.round_index
	return -1


## The injury he is back from without a game since ("hamstring"), or "": his
## latest injury fact this season, from a round at or after his last game.
func _back_from(p: Dictionary) -> String:
	if int(p.get("injury_weeks", 0)) > 0:
		return ""
	var inj := CareerFacts.of(career_facts, str(p["id"]), "injury")
	if inj.is_empty():
		return ""
	var f: Dictionary = inj[-1]
	var hurt := season.round_of_label(str(f["at"])) if season != null else 0
	if int(f["y"]) != season_year or hurt == 0:
		return ""
	var lg = p.get("last_game", [])
	var last := int(lg[1]) if lg is Array and (lg as Array).size() == 2 and int(lg[0]) == season_year else 0
	if hurt < last:
		return ""
	return str(f["out"]).replace("_", " ") if str(f["out"]) != "" else "injury"


## His season on the numbers his job is judged by (Backing.KPI): "Seven
## games: 12 disposals and 1 clearance a game.", or "" with no game this
## season.
func _kpi_text(p: Dictionary) -> String:
	var row: Dictionary = season_stats.get(str(p["id"]), {})
	var games := int(row.get("games", 0))
	if games <= 0:
		return ""
	var kind := Backing.kpi_kind(p)
	return Backing.kpi_line(kind, games, _kpi_totals(kind, row))


## How his season reads on those numbers: "good", "quiet" or "" (Backing.kpi_verdict).
func _kpi_verdict(p: Dictionary) -> String:
	var row: Dictionary = season_stats.get(str(p["id"]), {})
	var games := int(row.get("games", 0))
	if games <= 0:
		return ""
	var kind := Backing.kpi_kind(p)
	return Backing.kpi_verdict(kind, games, _kpi_totals(kind, row))


func _kpi_totals(kind: String, row: Dictionary) -> Dictionary:
	var tot := {}
	for k in Backing.KPI[kind]["stats"]:
		tot[k] = StatBook.total(row, str(k))
	return tot


## His job as a coach says it: "key back", "ruck", "small forward"...
func talk_job(p: Dictionary) -> String:
	match Backing.kpi_kind(p):
		"key_fwd":
			return "key forward"
		"fwd":
			return PlayerProfile.forward_type(p).to_lower()
		"wing":
			return "wingman"
		"ruck":
			return "ruck"
		"key_back":
			return "key back"
		"def":
			return "defender"
	return "midfielder"


## What talking him through it comes to, in plain facts. Good numbers are
## never spun as a poor season: he just doesn't see why he's out.
func _explain_outcome(name: String, e: Dictionary) -> String:
	var kpi := str(e.get("kpi", ""))
	if kpi == "":
		return "You tell %s what a %s has to show: %s. He expects a game this week." % [
				name, str(e.get("job", "player")), str(e.get("need", ""))]
	if str(e.get("verdict", "")) == "good":
		return "You go through his season with %s: %s He doesn't see why he's out, and he expects a game this week." % [name, kpi]
	return "You go through his season with %s: %s He expects a game this week." % [name, kpi]


## Keep the sit-down as a career fact (G7, kind "talk"): d is what opened it
## and what you said ("dropped|promise"); out is settled after your next match.
func _note_talk(p: Dictionary, said: String, case := "mood") -> void:
	CareerFacts.add(career_facts, str(p["id"]), CareerFacts.row(season_year,
			season.round_name(season.round_index), "talk", my_club,
			"%s|%s" % [case if case != "" else "mood", said], ""))


## After your match: the round each player of yours last played, and every
## sit-down still open settled, with a line saying how it came out.
func _after_match_talks(played: Dictionary, round_no: int) -> void:
	for p in my_list:
		var id := str(p["id"])
		if played.has(id):
			p["last_game"] = [season_year, round_no]
		var rows = career_facts.get(id, [])
		if not (rows is Array):
			continue
		for r in rows:
			if str(r[CareerFacts.K]) != "talk" or str(r[CareerFacts.OUT]) != "":
				continue
			var said := str(r[CareerFacts.D]).get_slice("|", 1)
			var name := GameDB.player_display_name(p)
			if played.has(id):
				r[CareerFacts.OUT] = "played"
				add_news("club", ("%s is back in the side, as you told him." if said == "promise"
						else "%s is back in the side.") % name)
			elif int(p.get("injury_weeks", 0)) > 0:
				r[CareerFacts.OUT] = "injured"
				add_news("club", "%s was hurt before his chance came." % name)
			else:
				r[CareerFacts.OUT] = "waiting"
				add_news("club", ("%s is still waiting for the game you promised him." if said == "promise"
						else "%s is still waiting for a game.") % name)


# ---------------------------------------------------------------------------
# Captaincy (Captaincy.gd): a captain and up to two vice-captains per club
# ---------------------------------------------------------------------------
## A club's list as it is now: yours (the list you edit), else this season's
## live one, else the league's (the off-season moves players between them).
func club_roster(code: String) -> Array:
	if code == my_club and not my_list.is_empty():
		return my_list
	if season != null and offseason_year != season_year and season.lists.has(code):
		return season.lists[code]
	if league_lists.has(code):
		return league_lists[code]
	if season != null and season.lists.has(code):
		return season.lists[code]
	return []


## A club's record as it stands now, read only ({} when nothing is named):
## a leader who has since left the club (traded, retired, delisted) is not in
## it, whenever you ask, off-season included.
func captaincy_record(code: String) -> Dictionary:
	var rec: Dictionary = captaincy.get(code, {})
	if rec.is_empty():
		return rec
	var now: Dictionary = rec.duplicate(true)
	Captaincy.prune(now, club_roster(code))
	return now


## "Captain" / "Vice-captain" for a player of any club, or "".
func captaincy_word(p: Dictionary) -> String:
	return Captaincy.role_word(captaincy_record(str(p.get("club", ""))), str(p.get("id", "")))


## Has the season begun, so that taking an armband off costs? Before round 1,
## and through the off-season, changes are free.
func captaincy_mid_season() -> bool:
	if season_closed():
		return false
	return season.round_index > 0 or season.is_regular_done() or not season.finals.is_empty()


func _captain_name(id: String, roster: Array) -> String:
	for p in roster:
		if str((p as Dictionary).get("id", "")) == id:
			return GameDB.player_display_name(p)
	return "A player"


## Every club has a record: the 2026 record for real lists, the rule for a club
## without one. Your own club is named the same way when its record is first made
## (director 2026-10-12: in a redraft or custom career it starts with a captain
## named by the rule, and you can change him on the Captaincy page). When your
## captain retires or leaves, the best-rated vice-captain steps up by the same rule
## as a rival's (the highest Leadership if none is left), with a note to the coach
## (director 2026-10-12). A spot the coach emptied himself stays empty: nobody is
## added for him. A save from before this ("seeded" missing) is named once, by the
## rule, at the first round after it loads, unless it already has leaders.
func _captaincy_refresh() -> void:
	if season == null:
		return
	for code in season.lists:
		var roster: Array = season.lists[code]
		var rec: Dictionary = captaincy.get(code, {})
		var fresh_rec := rec.is_empty()
		if fresh_rec:
			rec = Captaincy.fresh(season_year)
			rec["slots"] = Captaincy.from_record(str(code), roster)
		var had_captain := not Captaincy.ids(rec, "captain").is_empty()
		var lost_captain: String = str(Captaincy.ids(rec, "captain")[0]) if had_captain else ""
		Captaincy.prune(rec, roster)
		if str(code) != my_club:
			var made := Captaincy.fill(rec, roster)
			if made != "" and not fresh_rec:
				rec["since"] = season_year
				add_news("captaincy", "%s have named %s captain." % [
						GameDB.club_name(str(code)), _captain_name(made, roster)])
		elif not bool(rec.get("seeded", false)) and Captaincy.slots(rec).is_empty():
			# Your club, the first time: named by the rule. No news.
			Captaincy.fill(rec, roster)
		elif had_captain and Captaincy.ids(rec, "captain").is_empty():
			# Your captain has retired or left: the next in line steps up. A spot you emptied
			# yourself has no captain to lose, so it never comes here.
			var stepped := ""
			if Captaincy.slots(rec).is_empty():
				# He was the only leader the coach had named: one captain by the rule, and
				# no vice-captains the coach never had.
				var pick := Captaincy.by_rule(roster)
				if not pick.is_empty():
					stepped = str(pick[0]["id"])
					rec["slots"] = [{"id": stepped, "role": "captain"}]
			else:
				stepped = Captaincy.fill(rec, roster)
			if stepped != "":
				rec["since"] = season_year
				var mid := captaincy_mid_season()
				var retired := false
				for r in (intake_summary.get("retired", []) as Array) + medical_retired:
					if str((r as Dictionary).get("id", "")) == lost_captain:
						retired = true
				var note := "Your captain has %s, so %s takes over as captain. You can change it on the Captaincy page." % [
						"retired" if retired else "left the club", _captain_name(stepped, roster)]
				# Before Round 1 it is the off-season, as the feed calls it; the page says Pre-season.
				Captaincy.add_log(rec, season_year,
						last_label if mid else ("Off-season" if offseason_year == season_year else "Pre-season"), note)
				add_news("captaincy", note, last_label if mid else "Off-season")
		rec["seeded"] = true
		captaincy[code] = rec


## After each round: players who left a club leave its captaincy, a rival may
## replace a captain, and a vacancy at a rival is filled. Chance is a hash of
## the career seed, club and week, never the match dice, so stories of this
## kind cannot move a result.
func _captaincy_week() -> void:
	# Once the season is over the off-season refresh does it, after the premiers
	# have made the news.
	if season == null or my_club == "" or season.is_season_over():
		return
	_captaincy_refresh()
	var week := season.round_index
	for code in season.lists:
		if str(code) == my_club:
			continue
		var roster: Array = season.lists[code]
		var rec: Dictionary = captaincy.get(code, {})
		var caps := Captaincy.ids(rec, "captain")
		if caps.is_empty():
			continue
		var lead_id: String = str(caps[0])
		var lead: Dictionary = {}
		for p in roster:
			if str((p as Dictionary).get("id", "")) == lead_id:
				lead = p
		if lead.is_empty():
			continue
		var why := ""
		var club := GameDB.club_name(str(code))
		var who := GameDB.player_display_name(lead)
		if int(lead.get("injury_weeks", 0)) >= Captaincy.LONG_INJURY_WEEKS:
			# Neutral, for anyone: a long injury, said as a fact.
			why = "%s has stood down as %s captain: he is out for %d weeks." % [
					who, club, int(lead.get("injury_weeks", 0))]
		elif not Leadership.is_real(lead) and last_phase == "regular":
			# An invented captain only: a scandal or a bad run, as league news.
			var roll := float(("%d|%s|%d" % [career_seed, code, season_year * 100 + week]).hash() % 100000) / 100000.0
			if roll < Captaincy.strip_chance:
				var form: Array = season.club_results(str(code))
				var recent: Array = form.slice(maxi(0, form.size() - 4))
				var losses := 0
				for r in recent:
					if str(r) == "L":
						losses += 1
				if recent.size() >= 3 and losses >= 3:
					why = "%s has been stripped of the %s captaincy after a poor run." % [who, club]
				else:
					why = "%s has been stripped of the %s captaincy after an off-field incident." % [who, club]
		if why == "":
			continue
		var kept := []
		for s in Captaincy.slots(rec):
			if str((s as Dictionary)["id"]) != lead_id:
				kept.append(s)
		rec["slots"] = kept
		var made := Captaincy.fill(rec, roster)
		rec["since"] = season_year
		var line := why
		if made != "":
			line += " %s takes over." % _captain_name(made, roster)
		Captaincy.add_log(rec, season_year, last_label, line)
		add_news("captaincy", line)
		captaincy[code] = rec


## What naming these leaders would cost, before anything is done.
func captaincy_preview(new_slots: Array) -> Dictionary:
	var roster := club_roster(my_club)
	var rec := captaincy_record(my_club)
	if rec.is_empty():
		rec = Captaincy.fresh(season_year)
	return Captaincy.preview(rec, new_slots, roster,
			season_year, captaincy_mid_season(), func(id): return _captain_name(id, roster))


## Name your leaders: [{"id", "role"}], at most three, a captain among them.
## The costs the preview listed are applied. Returns the preview (ok false:
## nothing changed).
func set_captaincy(new_slots: Array) -> Dictionary:
	var pv := captaincy_preview(new_slots)
	if not bool(pv["ok"]):
		return pv
	var rec: Dictionary = captaincy_record(my_club)
	if rec.is_empty():
		rec = Captaincy.fresh(season_year)
	var roster := club_roster(my_club)
	var when := last_label if captaincy_mid_season() else "Pre-season"
	for id in pv["morale"]:
		for p in roster:
			if str((p as Dictionary).get("id", "")) == str(id):
				ClubLife.add_morale(p, int(pv["morale"][id]))
	for id in pv["trust"]:
		var passed := (pv["passed"] as Array).has(id)
		Trust.change(relations, Trust.player_key(str(id)), int(pv["trust"][id]),
				"You passed him over for the captaincy" if passed else "You took the armband off him",
				season_year, when)
	for id in pv["passed"]:
		(rec["passed"] as Dictionary)[str(id)] = season_year
	if bool(pv["used_change"]):
		(rec["changes"] as Dictionary)[str(season_year)] = Captaincy.changes_used(rec, season_year) + 1
	var names := PackedStringArray()
	for s in new_slots:
		names.append("%s %s" % [Captaincy.ROLE_WORDS[str((s as Dictionary)["role"])], _captain_name(str((s as Dictionary)["id"]), roster)])
	rec["slots"] = new_slots.duplicate(true)
	rec["since"] = season_year
	Captaincy.add_log(rec, season_year, when, ", ".join(names) if not names.is_empty() else "No one named")
	captaincy[my_club] = rec
	mark_dirty()
	return pv


## Off only for an audit that measures what culture's effects add.
var culture_effects_on := true


## One culture effect at a club (Culture.effect_of): the same rule for every
## club; 0 for a club with a neutral strand (an older save has none).
func culture_effect(code: String, kind: String) -> float:
	if not culture_effects_on:
		return 0.0
	return Culture.club_effect(relations, code, kind, str(Culture.KIND_STRAND[kind]))


## Points of season training ceiling a player's club culture adds (Ambition:
## patient or rebuilding, for under-22s and first-season draftees); 0 elsewhere.
func culture_ceiling_step(p: Dictionary) -> int:
	var club := str(p.get("club", ""))
	if club == "" or not Culture.young_for_growth(p, season_year):
		return 0
	return maxi(0, int(round(culture_effect(club, "young_ceiling"))))


## How much less than his lowest a player re-signs for at `code` (Ambition:
## pushing to win now), in dollars; the same for your club and every rival.
func culture_resign_discount(code: String, p: Dictionary, years: int) -> int:
	return int(round(float(Contracts.lowest(p, years)) * culture_effect(code, "resign_floor")))


# ---------------------------------------------------------------------------
# Club culture (Culture.gd): three strands per club, in words
# ---------------------------------------------------------------------------
## Once-a-season bookkeeping, kept beside the strands in `relations`
## ("k:done"): the season closed, the rollover counted, the clubs already in
## the league news this season.
func _culture_marks() -> Dictionary:
	var m: Dictionary = relations.get("k:done", {})
	if m.is_empty():
		m = {"t": 0, "log": [], "season": 0, "roll": 0, "news": {}}
		relations["k:done"] = m
	return m


## Move a club's strand, with the reason. A rival whose strand crosses into a
## new named band makes the league news (once a season, neutral words); yours
## is in the culture under your leaders (the Captaincy panel).
func _culture_move(code: String, strand: String, d: int, why: String) -> void:
	var before := Culture.value(relations, code, strand)
	var when := "Off-season" if season_closed() else last_label
	if Culture.change(relations, code, strand, d, why, season_year, when) == 0:
		return
	if code == my_club:
		return
	var after := Culture.value(relations, code, strand)
	if Culture.band_key(strand, before) == Culture.band_key(strand, after) or not Culture.news_ok(strand, after):
		return
	var told: Dictionary = _culture_marks()["news"]
	if int(told.get(code, 0)) == season_year:
		return
	told[code] = season_year
	var line := "%s %s." % [GameDB.club_name(code), Culture.news_phrase(strand, after)]
	# The season's close keeps the premiers on top of the feed: its news waits for
	# the rollover.
	if season != null and season.is_season_over():
		var pending: Array = _culture_marks().get("pending", [])
		pending.append(line)
		_culture_marks()["pending"] = pending
		return
	add_news("culture", line)


## After each round, every club that played in it (`results`): a run of losses
## or wins that has just reached its mark moves Togetherness, once. A club on a
## bye, or out of the finals, has reached nothing new that week. When the
## season is over, its close.
func _culture_week(results: Array) -> void:
	if season == null or my_club == "":
		return
	var played := {}
	for res in results:
		played[str((res as Dictionary).get("home", ""))] = true
		played[str((res as Dictionary).get("away", ""))] = true
	for code in season.lists:
		if not played.has(str(code)):
			continue
		var form: Array = season.club_results(str(code))
		var losses := 0
		var wins := 0
		var i := form.size() - 1
		while i >= 0 and str(form[i]) == "L":
			losses += 1
			i -= 1
		i = form.size() - 1
		while i >= 0 and str(form[i]) == "W":
			wins += 1
			i -= 1
		var step := Culture.run_step(losses, wins)
		if not step.is_empty():
			_culture_move(str(code), str(step[0]), int(step[1]), str(step[2]))
	if season.is_season_over():
		_culture_season()


## The season's close for every club: its finish, the age of its best 22 and
## the discipline of its list against the league's.
func _culture_season() -> void:
	var marks := _culture_marks()
	if int(marks["season"]) == season_year:
		return
	marks["season"] = season_year
	var table := season.ladder_sorted()
	var disc := {}
	var league_sum := 0.0
	var league_n := 0
	for code in season.lists:
		var sum := 0.0
		var n := 0
		for p in season.lists[code]:
			var a: Dictionary = (p as Dictionary).get("attr", {})
			if a.has("discipline"):
				sum += float(a["discipline"])
				n += 1
		disc[str(code)] = sum / maxf(1.0, float(n))
		league_sum += sum
		league_n += n
	var league_mean := league_sum / maxf(1.0, float(league_n))
	var champion := premier()
	var ages := {}
	var age_sum := 0.0
	for code in season.lists:
		var best: Array = (season.lists[code] as Array).duplicate()
		best.sort_custom(func(x, y): return int(x.get("overall", 0)) > int(y.get("overall", 0)))
		var age := 0.0
		var count := mini(22, best.size())
		for j in range(count):
			age += float(best[j].get("age", 25.0))
		age /= maxf(1.0, float(count))
		ages[str(code)] = age
		age_sum += age
	var age_mean := age_sum / maxf(1.0, float(ages.size()))
	for k in range(table.size()):
		var code := str(table[k]["code"])
		for st in Culture.season_steps(k + 1, table.size(), code == champion,
				float(ages.get(code, age_mean)) - age_mean, float(disc.get(code, league_mean)) - league_mean,
				season.finalists()):
			_culture_move(code, str(st["strand"]), int(st["d"]), str(st["why"]))
		for s in Culture.STRANDS:
			Culture.settle(relations, code, str(s[0]))


## At the rollover, every club: how many new faces came from other clubs.
func _culture_rollover() -> void:
	if season == null:
		return
	var marks := _culture_marks()
	if int(marks["roll"]) == season_year:
		return
	marks["roll"] = season_year
	for line in marks.get("pending", []):
		add_news("culture", str(line))
	marks["pending"] = []
	var faces := {}
	var counts := []
	for code in season.lists:
		var n := 0
		for p in season.lists[code]:
			var c = (p as Dictionary).get("career")
			if not (c is Dictionary):
				continue
			var stints: Array = (c as Dictionary).get("stints", [])
			# Only an arrival since the last rollover: a recruit who has not
			# played for his new club yet is not a new face again next year.
			if not stints.is_empty() and str((stints[stints.size() - 1] as Array)[0]) != str(code) \
					and int(p.get("joined", -1)) >= season_year - 1:
				n += 1
		faces[str(code)] = n
		counts.append(n)
	counts.sort()
	var median := 0.0
	if not counts.is_empty():
		var mid := counts.size() / 2
		median = float(counts[mid]) if counts.size() % 2 == 1 else (float(counts[mid - 1]) + float(counts[mid])) / 2.0
	for code in faces:
		for st in Culture.new_faces_step(int(faces[code]), median):
			_culture_move(str(code), str(st["strand"]), int(st["d"]), str(st["why"]))
