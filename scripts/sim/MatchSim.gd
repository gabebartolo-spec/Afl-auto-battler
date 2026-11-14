class_name MatchSim
extends RefCounted
## The match engine. Simulates a game as a sequence of possession chains and
## emits a deterministic, seeded event log that the pitch view replays.
##
## Began as a port of tools/sim_harness.py::MatchSim; that Python copy is stale
## since 2026-10-08 and is not maintained. This file and Ratings.T are the
## engine. The calibration guard is tests/run_calibration_tests.gd (seeded
## games against real 2026 team totals). Emitting events does not draw from
## the RNG, so the richer log costs nothing in calibration.

var squads: Array = []                 # [Squad home, Squad away]
## Each side's bench at the first bounce: [{id, num, name}]. Presentation only.
var opening_bench: Array = []
var rng := RandomNumberGenerator.new()
var team_stats: Array = [{}, {}]
## Actual effort, accumulated only while a player is on the ground. Kept
## separately from energy, which recovers during a match, and from stats.
var exertion := {}
var energy_caps := {}
var player_stats := {}                 # player id -> {stat: float}
var events: Array = []
var q_goals: Array = [[0, 0], [0, 0], [0, 0], [0, 0]]
var q_behinds: Array = [[0, 0], [0, 0], [0, 0], [0, 0]]
var current_minute := 0
var current_quarter := 1
var fp := 0.0
var next_side := -1          # -1 => the stoppage is contested
var at_centre := true
var kick_in := false         # the next chain is a kick-in after a behind
var boundary_throw_in := false # the next chain restarts with a boundary throw-in
const GOAL_SQUARE_DEPTH := 9.0  # metres; kick-ins are taken from inside it
## With no lateral simulation coordinate, boundary exits are rolled as a real
## chain outcome at the ball's current longitudinal position. The rate is
## deliberately modest: roughly the amount needed to produce AFL-like
## boundary stoppages without turning the game into a boundary simulator.
const BOUNDARY_EXIT_P := 0.008
const BOUNDARY_RUSHED_BONUS := 0.004
const OUT_ON_FULL_SHARE := 0.12
const BOUNDARY_TOUCHED_SHARE := 0.28
var tactics := [{}, {}]      # per side: gameplan, focus_mid/fwd/def (focus_id), tag_id, tagger_id, pep
## Tags dropped because the man was no longer a midfielder: {side, id, q}.
var tag_drops: Array = []
## How well each side's match-day players suit each plan (PlanFit): the
## plan's upside is scaled by it, its costs are not.
var plan_fit := [{}, {}]
## Each side's usual game: where an AI club starts, and what it goes back to.
## The plan its coach settled on for the season (Squad.usual_plan), or, with
## none, the one its list suits (PlanFit.standing_plan).
var standing := ["balanced", "balanced"]
## Named match-ups (Matchups, Gate 1.12): per defending side, which defender
## stands on each of the other side's key forwards. {forward id: defender id}.
var duels := [{}, {}]
## Defender given licence to leave his man and hunt aerial balls behind play.
## This is a role/assignment, not an extra player.
var interceptor := ["", ""]
var interceptor_changes: Array = []
## His intercepts the moment he was sent loose, per side ({"id", "n"}): the
## "since the call" tally at the break. A record only.
var interceptor_base := [{}, {}]
## Every contest a matched forward and his direct opponent played:
## forward id -> {"side": attacking side, "contests": [[q, defender id,
## forward marked, goal from it]]}.
var duel_log := {}
## The loose defender against the player he met in a roaming contest:
## "roamer id|target id" -> [contests, won by the roamer]. A record only; the
## contests are decided as before (Defensive forward detail at the breaks).
var roam_pairs := {}
## Match-ups changed during the match: [{"q", "side" (defending), "fwd", "def"}].
var duel_changes: Array = []
## The calls a side's coach has made himself (coach_interceptor, his tag
## and the spare's minder): his assistant leaves them alone for the rest of
## the match (Squad.assistant). The match-ups are always the sim's own: key
## match-ups are cut (director, 2026-11-07: "Roles replace match-ups").
var _own := [{"interceptor": false, "tag": false, "minder": false},
		{"interceptor": false, "tag": false, "minder": false}]
## The contest in play, attached to the score or rebound it produces.
var _duel := {}
## The key forward whose named contest inside 50 was just logged, so the mark
## it produced is tagged (event "duel_contest") like the general-play ones.
var _duel_tag := ""
## Injuries during the match (Injuries.roll per player, from injury_rng so
## the play dice are untouched). Planned at the first bounce:
## [{"side", "id", "q", "min", "weeks", "kind"}]; each happens when its
## time comes and he is on the ground (_check_injuries).
var injury_rng := RandomNumberGenerator.new()
var _injury_plan: Array = []
## The injuries that happened: [{"side", "id", "q", "min", "weeks", "kind",
## "on"}] ("on": who came on for him, "" for none).
var injuries: Array = []
## Reportable incidents that happened in real match contact. The MRO outcome
## is decided here once and applied to league lists after the round.
var reports: Array = []
## Players gone off injured, per side; they take no further part.
var injured_off := [[], []]
## Players the substitute replaced for good (2011-15, EraRules), not hurt:
## they took part, so the box score keeps them.
var subbed_off := [[], []]
## Who won the ball back for the chain being played ({"side", "id"}), so a
## goal from a turnover can say whose intercept it came from.
var _won_back := {}
var _chain_from := {}
## The ground-ball winner after a spoil is drawn on its own dice, so the
## carrier stream (rng) is where it was before the spoil had a gatherer.
var gather_rng := RandomNumberGenerator.new()
var _gathering := false
## The coach's set-shot call while it plays out ({"key"}): every event it
## produces carries "choice", and its result also "setshot".
var _set_choice := {}
## Who the last free kick was paid to ({"side", "id"}): inside his forward 50
## he takes it as a set shot (_free_set_shot).
var _free_taker := {}
## The side whose disposal last went loose (spoiled, smothered) or astray (a
## clanger): a loose-ball win off it in the next chain is an intercept.
var _lost_by := -1
var _ball_lost_by := -1
# Assistant-coach audit trail. Snapshots never touch the RNG, so calibration
# is unaffected. tactics_history[q] records the plans in force for that
# quarter, and "why" each rival coach played his (ai_why; "" for a side you
# coach, and absent from matches saved before the rival coach read);
# quarter_teams[q] records the cumulative team totals afterwards.
var tactics_history: Array = []
var quarter_teams: Array = []
## What each side is playing, for the match view (ARD-M8-003 tactical
## timeline): an entry whenever it changes, applying from the event index `at`.
## {"at", "side", "plan", "bursts" (sorted kinds in force), "tag" (the
## opposition player tagged), "tagger", "loose" (the roaming interceptor),
## "accountable" (a forward sent to the other side's loose man), "duels"
## ({their forward id: our defender id})}. Read only: it draws no dice, so the
## match is the same with or without it.
var timeline: Array = []
var _timeline_last := ["", ""]
## Finals cannot be drawn. With finals_mode on, a level score at the end of
## Q4 leads to extra time instead of the full-time siren.
var finals_mode := false
var extra_time_played := false
## False for a final the year replayed when drawn (every final in 1990, the
## Grand Final to 2015): level at full time, it ends level (Season.record_final).
var extra_time_allowed := true

## Legs. Every player has energy (0-100): on-ground players tire each chain,
## the bench recovers, and coaches rotate tired players off. Energy scales a
## player's effective attributes (fit()), centred so an average match reads
## the same as before - a fresh player is a touch better, a cooked one worse.
var energy := {}
## fit() by player id, with the energy it was computed at (a changed energy recomputes);
## it is asked about half a million times a round of matches. The same numbers, computed once.
var _fit_cache := {}
## Team familiarity (TeamFamiliarity): the whole-game form cut each man plays with,
## his own plus his side's, by id, and each side's team-wide part (for the harness).
var _fam_cut := {}
var team_fam_cut := [0.0, 0.0]
var rotation_policy := ["normal", "normal"]
## A side's season fitness plan when it rotates itself each quarter
## (auto_rotation at every break); "" leaves rotation_policy as set.
## Background matches set both: every club rotates in its own interest.
var season_plans := ["", ""]
var interchanges := [0, 0]
var _chain_no := 0
var _played := [{}, {}]      # side -> id -> true: everyone who took the field

## Where the result came from: expected points each cause added (positive
## helps that side). Pure arithmetic on the probabilities already rolled -
## no RNG draws - so it costs the calibration nothing.
## The coach's decisions each have their own cause (DECISION_CAUSES; the
## full-time summary, director 2026-10-11); "legs", "traits" and "form" are
## the players and the bounce of the ball, with whatever no line measures.
var impact := [{}, {}]
## Who earned each named-man call's credit (row 144): side -> {cause: {player
## id: points}} for NAMED_CAUSES, so full time names the man who was actually
## loose, minding or tagged when the points were earned, not the man the plan
## first named. Bookkeeping only, like `impact`.
var impact_by := [{}, {}]
const NAMED_CAUSES := ["loose", "minder", "tag"]
const DECISION_CAUSES := ["moments", "gameplan", "loose", "tag", "pep", "bursts", "minder"]
## The forward the loose man was on before he was sent loose: def side ->
## {"id": loose man, "fwd": forward id}. Without the call he would be on him.
var _loose_was := [{}, {}]

## Match moments: live matches pause for the coach's call. Only the side in
## moment_side gets them, and they draw from their own RNG, so simulated
## matches (moment_side -1) never see one.
var moment_side := -1
var moment_rng := RandomNumberGenerator.new()
## Stat credits that must not disturb the match's own random sequence (who a
## free kick was paid to): results are identical with or without them.
var stat_rng := RandomNumberGenerator.new()
## Whether a mark inside 50 ends in a set shot and from where (SET_BANDS_ON):
## its own stream, so the rest of the match draws exactly as before.
var shot_rng := RandomNumberGenerator.new()
## Every kick at goal, for the balance harness (tools/balance): [side, 1 for a
## set shot, metres out (-1 where the sim does not place the shot: general
## play), result "goal" / "behind" / ""]. Measurement only: no roll reads it.
var shot_log: Array = []
## Smothers alter possession but use their own stream, so ordinary disposal
## outcomes keep the calibration RNG sequence they had before this feature.
var smother_rng := RandomNumberGenerator.new()
## General-play aerial contests alter real possession outcomes but use their
## own stream so ordinary non-aerial play keeps its prior RNG ordering.
var aerial_rng := RandomNumberGenerator.new()
## Whether a carrier takes on space and runs before he disposes of it: its
## own stream, so every other roll in the match draws exactly as before.
var run_rng := RandomNumberGenerator.new()
## Whether an intercept or a goal-square pack is marked or spilled: it decides
## who takes the next kick, so it has its own stream and every other roll in
## the match draws as before.
var mark_rng := RandomNumberGenerator.new()
## Spectacular-mark selection is presentation/stat context only.
var speccy_rng := RandomNumberGenerator.new()
## Post-free 50m infringements are independent of ordinary play rolls.
var discipline_rng := RandomNumberGenerator.new()
var mro_rng := RandomNumberGenerator.new()
var restart_rng := RandomNumberGenerator.new()
var free_rng := RandomNumberGenerator.new()
## How a broken tackle was broken (_break_kind): its own dice, so the play
## dice are as they were.
var break_rng := RandomNumberGenerator.new()
## Whether a general-play marking contest falls to a key forward leading up
## at it (_key_lead): its own dice, so every other roll in the
## match draws as before.
var lead_rng := RandomNumberGenerator.new()
var _speccy_quota := 0
var _speccies := 0
## Boundary law rolls are isolated from the calibrated play RNG. Adding or
## tuning boundary frequency therefore does not silently re-roll ordinary
## disposals in chains that stay in play.
var boundary_rng := RandomNumberGenerator.new()
## A contest that locks up into a ball-up (match flow, 2026-10-10): its own
## stream, so the calibrated play RNG is not re-rolled by it.
var lockup_rng := RandomNumberGenerator.new()
## The wet ball's fumbles (row 120): their own stream, drawn only on a wet day,
## so every other day's dice are where they were.
var fumble_rng := RandomNumberGenerator.new()
## The last chain ended in a ball-up called in play (a tackle held, a contest
## locked up): the next chain starts at that stoppage.
var _prev_locked := false
## The chain being played: how it began (centre, stoppage, kick_in, free,
## turnover, general) and who touched the ball in it, for score sources and
## score involvements. How the last chain ended decides the next's origin.
var chain_origin := "general"
var _chain_touch := {}
var _prev_end := ""
var pending_moment := {}
var moments: Array = []      # resolved moments, for the readouts
var bursts := [{}, {}]       # side -> {kind: chains left}: short-term calls
var _q_active := false
var _q_i := 0
var _q_count := 0
var _moments_this_q := 0
var _last_moment_chain := -100
var _run := [0, 0]           # unanswered goals
var _asked := {}             # one-off moment keys already offered
## The tired-star call holds until the break: player id -> "rest" (he stays
## on the bench) or "keep" (the rotations leave him out there).
var _held := {}
var _traits := {}            # player id -> Traits.of(), cached
var synergies := [[], []]    # side -> active synergy keys (the starting 18)
## Team form (-1..1) from each club's recent results (Season.club_form), set
## from Squad.form. It touches two narrow things: composure (a side in form
## makes a few fewer clangers) and stoppages (a small edge, like a third of
## the home-ground edge at full form). 0 (the default, and every calibration
## match) changes nothing, and it draws nothing from the RNG.
var form := [0.0, 0.0]
## The day's weather (Weather.CONDITIONS, ARD-M4-016): the rates the match is
## played at. "perfect" is the calibrated game, unchanged. Every size is fitted
## (row 61) to real AFL games against a perfect day, 2016-25, in
## tools/balance/afl_weather_rates.json (AFL Tables match stats with Open-Meteo's
## weather in the match window; tools/balance/build_weather_rates.py), and
## checked with tools/balance.sh match 1000 --a "--weather perfect" --b "--weather <c>":
## - wet (0.3 mm of rain or more, 215 games): marks -13%, tackles +12%, clangers
##   +10%, one-percenters +13%, contested ball +7%, disposals and kicks level,
##   bounces -25%, goals -8.5%, accuracy -1.8 points.
## - windy (a mean 20 km/h or more, 179 games): marks -3%, tackles +4%, clangers
##   +2%, goals -5%, accuracy -1 point, and a breeze end (BREEZE_WITH).
## - hot (25 C or more by day, 43 games): tackles -4%, clangers -3%, disposals
##   and scoring within a few per cent; no measurable late fade (HOT_DRAIN).
var weather := "perfect":
	set(v):
		weather = v if WEATHER_RATES.has(v) or v == "perfect" else "perfect"
		_rates_cache = {}
## The day may turn once, at a break (row 160, director 2026-11-12: "Yes, at a
## break"): {"after": the quarter whose break it turns at (1-3), "to": the
## condition from there}, or {} for a day that holds (Weather.turn, from the
## same key as the forecast, so the forecast's odds are the ones played). It is
## announced at that break (weather_turn_now) and played from the next
## quarter's first bounce: begin_quarter switches `weather`, so every rate,
## plan and trait reads the new condition for the quarters left, as the
## starting weather does for the first. The quarter already played keeps its
## own (the oval replays it after the siren). Draws nothing from the RNG.
var weather_turn := {}
## The forecast's odds that the day turns at a break (Weather.turn_chance),
## shown before the first bounce; 0 for a day that can't.
var weather_odds := 0.0


## The day as Season.weather_day gives it ({weather, chance, turn}), or a bare
## condition that holds all match.
func set_day(day: Variant) -> void:
	if day is Dictionary:
		weather = str((day as Dictionary).get("weather", "perfect"))
		weather_odds = float((day as Dictionary).get("chance", 0.0))
		weather_turn = ((day as Dictionary).get("turn", {}) as Dictionary).duplicate()
	else:
		weather = str(day)


## The weather at the first bounce, once a turn has changed `weather`.
var weather_start := ""
## The quarter whose break the weather turned at, once it has (0: not yet).
var weather_turned_after := 0


## The turn announced at the break just reached, or {} (none due here).
func weather_turn_now() -> Dictionary:
	if weather_turn.is_empty() or weather_turned_after > 0 or _q_active:
		return {}
	if int(weather_turn.get("after", 0)) != current_quarter - 1:
		return {}
	return {"after": int(weather_turn["after"]), "from": weather, "to": str(weather_turn.get("to", weather))}


## The weather the next quarter is played in: the turn's at the break it is
## announced, else the day's. A break's gate sizes the plans for it.
func weather_ahead() -> String:
	var t := weather_turn_now()
	return str(t["to"]) if not t.is_empty() else weather


func _apply_weather_turn() -> void:
	var t := weather_turn_now()
	if t.is_empty():
		return
	weather_start = weather
	weather = str(t["to"])
	weather_turned_after = int(t["after"])


## Ratings.T multipliers, applied in _rates() after the match-flow overrides.
## chains_per_game scales the quarter's chains, the bursts and the rotation
## cadence together, so legs per game are unchanged: the wet's shorter chains
## (more turnovers) make about 5% more of them with disposals held level, the
## heat about 2.5% fewer (a slower game: fewer tackles, clangers and stoppages).
## The wet's inside50_goal also lowers set-shot accuracy (WEATHER_SIM set_acc
## is the rest of it); its stoppages come from fumbles (WEATHER_SIM fumble).
## In the wind the ball is held a little more (handball_share), fewer spoils come
## off the entries (one_percenter_share) and fewer of its clangers are paid as a
## free (clanger_is_free), each sized to the real windy games.
const WEATHER_RATES := {
	"wet": {"chains_per_game": 1.05, "handball_share": 0.97,
			"mark_share_of_kicks": 0.81, "clanger_per_chain": 1.06,
			"stoppage_share": 1.0, "inside50_goal": 0.945, "inside50_behind": 0.93,
			"one_percenter_share": 1.11, "metres_gain_mean": 1.04},
	"windy": {"chains_per_game": 1.01, "mark_share_of_kicks": 0.945, "handball_share": 1.01,
			"one_percenter_share": 0.982, "clanger_is_free": 0.907},
	"hot": {"chains_per_game": 0.975, "pressure_base": 0.97, "stoppage_share": 0.95, "clanger_per_chain": 0.97},
}
## Rates for the sim's own named constants, read through _wx (WEATHER_RATES
## holds Ratings.T multipliers only), sized like WEATHER_RATES (row 61). A
## condition with no row, a perfect day included, plays every one at 1.0 and
## draws no extra dice.
## - set_acc: goals per set shot: every band, a free kick, a mark in the
##   goal-square pack and the lead's shot (_set_goal).
## - miss_behind: the share of missed set shots that still score a behind
##   (SET_MISS_BEHIND, _set_behind); the wind carries more of them out of bounds.
## - lockup: LOCKUP_PRESS and LOCKUP_SPOIL, contests locking up for a ball-up.
## - tackle_spill: TACKLE_SPILL, held tackles that are ball-ups.
##   (Both 1.0 in the wet: its extra stoppages come from fumbles, and more
##   would push the chains, and so the disposals, past the real figure.)
## - fumble: the chance a ground ball is fumbled at the gather (_wet_fumble).
## - tackle_share: PRESS_TACKLE_SHARE, more of the pressure a tackle and less
##   a rushed disposal (pressure acts unchanged).
## - aerial: the chance a contested or inside-50 kick is marked, by either side
##   (general play and its intercept mark, the forward's one-on-one, the entry
##   and the defender who marks it coming out), as mark_share_of_kicks does for
##   the uncontested ones: a greasy ball is dropped in a pack too.
## - run: the chance a carry takes a running bounce (cosmetic, the gain unchanged).
const WEATHER_SIM := {
	"wet": {"set_acc": 0.975, "lockup": 1.0, "tackle_spill": 1.0, "fumble": 0.06, "tackle_share": 1.12,
			"aerial": 0.83, "run": 0.76},
	"windy": {"tackle_share": 1.03, "miss_behind": 0.91},
}
## A windy day has a breeze end (the "five-goal breeze"): shots kicked with it
## are a little easier, against it much harder. The sides change ends each
## quarter, so it helps one side in the first and third, the other in the
## second and fourth; which one starts with it comes from the match seed. Sized
## to the real swing: in windy games the margin moves about 3.7 points a quarter
## toward one end (the quarter-by-quarter margins' extra spread against a
## perfect day, afl_weather_rates.json "breeze"), with goals about 5% down.
const BREEZE_WITH := 1.05
const BREEZE_AGAINST := 0.83
var breeze_side := 0


## Whether `side` kicks with the breeze this quarter (windy days only).
func with_breeze(side: int) -> bool:
	return (side == breeze_side) == (current_quarter % 2 == 1)


## The day's rate for a WEATHER_SIM key: `default` when the condition has no
## row or the row leaves it out. An audit sizes it with tune "WX_<key>".
func _wx(key: String, default := 1.0) -> float:
	var row: Dictionary = WEATHER_SIM.get(weather, {})
	if row.is_empty():
		return default
	return _tv("WX_" + key, float(row.get(key, default)))


## Hot days: legs go faster (the Heat Policy's longer breaks don't undo it).
## Real hot days show no late fade in the scoring (last quarter's share +0.2
## points, se 1.0, afl_weather_rates.json); with the drain the sim's is -0.1
## (se 0.3), the same within the noise.
const HOT_DRAIN := 1.12
var _rates_cache := {}
## The season this match is played in (legacy mode, row 142 L5): a past season
## plays its era's football (EraFootball, multipliers on Ratings.T applied in
## _rates() before the weather's). 0, and 2026 on, play today's.
var season_year := 0:
	set(v):
		season_year = v
		era_rates = EraFootball.rates_for(v)
		_rates_cache = {}
var era_rates := {}


## An era multiplier on one of the engine's own umpiring chances (EraFootball.SIM
## keys; 1.0 today): `free_rate` scales the contextual frees (high contact,
## holding the ball, marking contests) the way each era's umpires paid them.
## A harness `--tune free_rate=F` multiplies it too (the fit's step run).
func _era(key: String) -> float:
	return float(era_rates.get(key, 1.0)) * float(tune.get(key, 1.0))


func _rates() -> Dictionary:
	if _rates_cache.is_empty():
		_rates_cache = Ratings.T.duplicate()
		# Match flow (row 11): stoppages come from contests, a won ball is
		# played on, shorter chains and the turnover mix that goes with them.
		for k in Ratings.FLOW:
			_rates_cache[k] = Ratings.FLOW[k]
		for k in tune:
			if _rates_cache.has(k):
				_rates_cache[k] = tune[k]
		# The season's own football (legacy, row 142 L5): {} from 2026 on.
		for k in era_rates:
			if _rates_cache.has(k):
				_rates_cache[k] = float(_rates_cache[k]) * float(era_rates[k])
		var mult: Dictionary = WEATHER_RATES.get(weather, {})
		for k in mult:
			_rates_cache[k] = float(_rates_cache[k]) * float(mult[k])
	return _rates_cache


## Of the wet-day fumbles, the share where the pack forms on it and the umpire
## calls a ball-up; the rest is a loose ball either side can win off the deck.
const WET_FUMBLE_HELD := 0.5


## A ground ball fumbled in the wet (row 120, director 2026-11-06), at the first
## touch of a chain (the only ground-ball gather play_chain has): he wins it
## off the deck and loses it before he can dispose of it, a clanger, and the
## ball spills, either into a ball-up or loose for either side to win off the deck. Likelier for a poor
## contested player; a Wet-weather player fumbles WET_CLANGERS as often, as he
## makes fewer clangers. {} when he gathers it cleanly. Dice: fumble_rng only.
func _wet_fumble(side: int, carrier, at_fp: float) -> Dictionary:
	var p := _wx("fumble", 0.0) * (1.30 - 0.60 * _a(carrier, "contested") / 100.0)
	if _trait(carrier, "wet_weather"):
		p *= Traits.WET_CLANGERS
	if p <= 0.0 or fumble_rng.randf() >= p:
		return {}
	# He got to it first (a contested ground-ball get), then lost it before he
	# could dispose of it: not a disposal.
	_gain(side, carrier, "gb")
	_t(side, "clangers")
	_p(carrier, "clangers")
	_emit("clanger", side, at_fp, carrier, CLANGER_WHY["wet"] % GameDB.player_display_name(carrier))
	events[events.size() - 1]["why"] = "wet"
	events[events.size() - 1]["fumble"] = true
	_last_disp = {"carrier": carrier, "kind": "", "end": "fumble"}
	if fumble_rng.randf() < WET_FUMBLE_HELD:
		return {"outcome": "stoppage", "fp": at_fp, "actor": carrier}
	return {"outcome": "loose", "fp": at_fp, "actor": carrier}


## Momentum: who has the run of play, -1 (away on top) .. 1 (home on top).
## A goal swings it to the scorers, a behind a little; the swing shrinks as
## it nears the cap and a goal the other way pulls it back harder, so it can
## be arrested and turned. It fades every chain and halves at a break. Its
## only effect is a small edge in who wins the ball at stoppages and loose
## balls (contest_winner) - at most about the home-ground edge, for a few
## minutes. The match screen's meter shows this value.
var momentum := 0.0
## The contest edge at full momentum (tests set 0 to measure without it).
var momentum_edge := MOMENTUM_EDGE
const MOMENTUM_EDGE := 0.04
const MOMENTUM_GOAL := 0.40
const MOMENTUM_BEHIND := 0.10
## Kept each chain: halves in about nine chains (five or six minutes).
const MOMENTUM_DECAY := 0.93
const MOMENTUM_BREAK := 0.5
## Row 78 (T8.Q4): a side on top that is also well
## ahead on the scoreboard can run away with it, as real sides do once the
## other side's heads drop. When the side with the run of play leads by more
## than runaway_lead, its edge grows, up to runaway_gain times more at
## runaway_lead + RUNAWAY_SPAN, its run fades more slowly (runaway_decay), and
## a goal the other way turns it a little less (runaway_hold). Close matches
## (inside runaway_lead) are untouched.
## The knobs are vars so tools/balance.sh can screen values (--set).
var runaway_lead := RUNAWAY_LEAD
var runaway_gain := RUNAWAY_GAIN
var runaway_decay := RUNAWAY_DECAY
var runaway_hold := RUNAWAY_HOLD
const RUNAWAY_LEAD := 24.0
const RUNAWAY_SPAN := 30.0
const RUNAWAY_GAIN := 10.0
const RUNAWAY_DECAY := 0.99
const RUNAWAY_HOLD := 0.7
## Clanger-rate change at full form: 0.95x at +1, 1.05x at -1.
const FORM_COMPOSURE := 0.05
## Stoppage-win chance at full form (home_ground_bonus is 0.030).
const FORM_CONTEST := 0.010


func _init(home: Squad, away: Squad, seed: int = 0) -> void:
	squads = [home, away]
	_clanger_seed = seed
	# Who starts on the bench, for the match view's bench strip (read only).
	for sq in squads:
		var rows := []
		for p in (sq as Squad).bench:
			rows.append({"id": str(p["id"]), "num": int(p["num"]), "name": GameDB.player_display_name(p)})
		opening_bench.append(rows)
	form = [clampf(home.form, -1.0, 1.0), clampf(away.form, -1.0, 1.0)]
	rng.seed = seed
	moment_rng.seed = seed * 7 + 13
	stat_rng.seed = seed * 11 + 5
	shot_rng.seed = seed * 13 + 3
	smother_rng.seed = seed * 23 + 29
	aerial_rng.seed = seed * 73 + 79
	speccy_rng.seed = seed * 31 + 37
	mark_rng.seed = seed * 97 + 101
	run_rng.seed = seed * 83 + 89
	discipline_rng.seed = seed * 41 + 43
	mro_rng.seed = seed * 47 + 53
	restart_rng.seed = seed * 59 + 61
	free_rng.seed = seed * 67 + 71
	break_rng.seed = seed * 101 + 103
	_speccy_quota = speccy_quota(seed)
	boundary_rng.seed = seed * 17 + 19
	lockup_rng.seed = seed * 107 + 109
	gather_rng.seed = seed * 113 + 127
	fumble_rng.seed = seed * 127 + 131
	lead_rng.seed = seed * 109 + 113
	# Its own seed: it once shared lead_rng's, so the mid-kick intercept dice
	# replayed the key-lead dice. Every stream here needs a seed of its own.
	mid_ic_rng.seed = seed * 137 + 139
	injury_rng.seed = seed * 13 + 7
	breeze_side = posmod(hash("breeze|%d" % seed), 2)
	arch_rng.seed = seed * 151 + 157
	custom_rng.seed = seed * 163 + 167
	for side in range(2):
		arch[side] = (squads[side] as Squad).arch.duplicate()
		custom[side] = CustomPlan.clean((squads[side] as Squad).custom_plan) 				if CustomPlan.ready((squads[side] as Squad).custom_plan) else {}
		var morale := _ar(side, "morale", 0.0)
		if morale != 0.0:
			for q in (squads[side] as Squad).ground + (squads[side] as Squad).bench:
				_arch_form[str(q["id"])] = morale / 1000.0
		synergies[side] = Traits.active((squads[side] as Squad).ground)
		standing[side] = (squads[side] as Squad).usual_plan if (squads[side] as Squad).usual_plan != "" \
				else PlanFit.standing_plan((squads[side] as Squad).ground, (squads[side] as Squad).plan_know)
		duels[side] = Matchups.defaults((squads[1 - side] as Squad).ground, (squads[side] as Squad).ground)
		var named: Array = (squads[side] as Squad).ground + (squads[side] as Squad).bench
		team_fam_cut[side] = TeamFamiliarity.team_cut(named)
		_fam_cut.merge(TeamFamiliarity.side_cuts(named))
		for plan in PlanFit.LEAGUE:
			(plan_fit[side] as Dictionary)[plan] = PlanFit.fit((squads[side] as Squad).ground, plan)
		for p in (squads[side] as Squad).ground:
			energy_caps[str(p["id"])] = Workload.energy_cap(p)
			energy[str(p["id"])] = _start_energy(p)
			_played[side][str(p["id"])] = true
		for p in (squads[side] as Squad).bench:
			energy_caps[str(p["id"])] = Workload.energy_cap(p)
			energy[str(p["id"])] = _start_energy(p)
	# AI clubs with the personnel start with a genuine loose interceptor, and
	# so does your side when your assistant has it; you can change him in the
	# coach box.
	for side in range(2):
		if (squads[side] as Squad).ai_plans:
			var best := loose_pick((squads[side] as Squad).ground, (squads[1 - side] as Squad).ground)
			if not best.is_empty():
				set_interceptor(side, str(best["id"]), false)
		elif _assisted(side):
			set_interceptor(side, _assistant_interceptor(side), false)
	_plan_injuries()


## Deterministic spectacular-mark allowance: 30% none, 60% one, 10% two.
## Eligibility still requires a genuine contested mark in the match.
static func speccy_quota(seed: int) -> int:
	var bucket := posmod(hash("speccy|%d" % seed), 10)
	return 0 if bucket < 3 else (1 if bucket < 9 else 2)


## Legs at the first bounce: a heavy week on the track, or playing sore.
## starts him short of fresh.
static func _start_energy(p: Dictionary) -> float:
	var e := 100.0
	if bool(p.get("heavy_legs", false)):
		e = 88.0
	if bool(p.get("sore", false)):
		e = minf(e, ClubLife.SORE_LEGS)
	if bool(p.get("slow_start", false)):
		e = minf(e, ClubLife.SLOW_LEGS)
	return minf(e, Workload.energy_cap(p))


## Put `def_id` (of `def_side`) on the other side's forward `fwd_id`. If he
## was on another forward, that forward gets the defender this one had (a
## swap), as a coach moves his key defenders around. `during` records the
## change for the match story. Returns false for an unknown player.
func set_matchup(def_side: int, fwd_id: String, def_id: String, during := true) -> bool:
	if def_side < 0 or def_side > 1:
		return false
	var att: Squad = squads[1 - def_side]
	var own: Squad = squads[def_side]
	var fwd_ok := false
	for p in att.ground + att.bench:
		if str(p["id"]) == fwd_id:
			fwd_ok = true
	var def_ok := false
	for p in own.ground + own.bench:
		if str(p["id"]) == def_id:
			def_ok = true
	if not fwd_ok or not def_ok:
		return false
	# A defender cannot be both the nominated loose man and a strict direct
	# opponent. Putting him back on someone removes the roaming instruction.
	if str(interceptor[def_side]) == def_id:
		set_interceptor(def_side, "", during)
	var d: Dictionary = duels[def_side]
	if str(d.get(fwd_id, "")) == def_id:
		return true
	var had := str(d.get(fwd_id, ""))
	for other in d.keys():
		if str(d[other]) == def_id and str(other) != fwd_id:
			if had != "":
				d[other] = had
			else:
				d.erase(other)
	d[fwd_id] = def_id
	if during:
		# Between quarters current_quarter is already the next one, so a change
		# at a break starts with it; from a moment card, straight away. A
		# second change at the same break replaces the first.
		var from := maxi(1, current_quarter)
		for i in range(duel_changes.size() - 1, -1, -1):
			var ch: Dictionary = duel_changes[i]
			if int(ch["from"]) == from and int(ch["side"]) == def_side and str(ch["fwd"]) == fwd_id:
				duel_changes.remove_at(i)
		duel_changes.append({"q": maxi(1, current_quarter), "from": from, "side": def_side,
				"fwd": fwd_id, "def": def_id})
	return true


## The coach picks the loose defender himself ("" for none): it stays his
## call for the rest of the match.
func coach_interceptor(side: int, def_id: String) -> bool:
	if side < 0 or side > 1:
		return false
	(_own[side] as Dictionary)["interceptor"] = true
	return set_interceptor(side, def_id, current_quarter > 1 or _q_active)


## Whether the assistant has any routine call left to make for `side`: on
## your side the match-ups always are, and the loose man until you take him.
func assistant_active(side: int) -> bool:
	if not _assisted(side):
		return false
	return not bool((_own[side] as Dictionary)["interceptor"]) or not (duels[side] as Dictionary).is_empty()


## Whether the coach named the loose defender himself, rather than his
## assistant. Always true for a side without an assistant.
func coach_call(side: int) -> bool:
	if side < 0 or side > 1 or not _assisted(side):
		return true
	return bool((_own[side] as Dictionary)["interceptor"])


func _assisted(side: int) -> bool:
	var sq: Squad = squads[side]
	return sq.assistant and not sq.ai_plans


## Nominate one defender to roam behind the ball. If he had a direct forward,
## another available defender inherits that job; with nobody spare, that
## forward becomes unassigned. No extra player is created.
func set_interceptor(def_side: int, def_id: String, during := true) -> bool:
	if def_side < 0 or def_side > 1:
		return false
	if def_id != "":
		var found := false
		for p in (squads[def_side] as Squad).ground + (squads[def_side] as Squad).bench:
			if str(p.get("id", "")) == def_id and str(p.get("role", "")) == "DEF":
				found = true
				break
		if not found:
			return false
	if str(interceptor[def_side]) == def_id:
		return true
	var old := str(interceptor[def_side])
	interceptor[def_side] = def_id
	interceptor_base[def_side] = {"id": def_id,
			"n": int(float((player_stats.get(def_id, {}) as Dictionary).get("intercepts", 0.0)))}

	if def_id != "":
		var d: Dictionary = duels[def_side]
		var used := {}
		for fid in d.keys():
			var did := str(d[fid])
			if did != def_id:
				used[did] = true
		for fid in d.keys().duplicate():
			if str(d.get(fid, "")) != def_id:
				continue
			_loose_was[def_side] = {"id": def_id, "fwd": str(fid)}
			var replacement := ""
			for p in Matchups.defenders((squads[def_side] as Squad).ground):
				var pid := str(p.get("id", ""))
				if pid != def_id and not used.has(pid):
					replacement = pid
					used[pid] = true
					break
			if replacement == "":
				d.erase(fid)
			else:
				d[fid] = replacement

	if during:
		var from := maxi(1, current_quarter)
		for i in range(interceptor_changes.size() - 1, -1, -1):
			var ch: Dictionary = interceptor_changes[i]
			if int(ch.get("from", 0)) == from and int(ch.get("side", -1)) == def_side:
				interceptor_changes.remove_at(i)
		interceptor_changes.append({"q": maxi(1, current_quarter), "from": from,
				"side": def_side, "from_id": old, "id": def_id})
	return true


## The loose defender's intercepts since he was sent loose (-1: nobody is).
func intercepts_since_call(side: int) -> int:
	var id := str(interceptor[side])
	if id == "":
		return -1
	var base: Dictionary = interceptor_base[side]
	var was := int(base.get("n", 0)) if str(base.get("id", "")) == id else 0
	return maxi(0, int(float((player_stats.get(id, {}) as Dictionary).get("intercepts", 0.0))) - was)


func _roaming_interceptor(side: int) -> Dictionary:
	if side < 0 or side > 1:
		return {}
	var id := str(interceptor[side])
	if id == "":
		return {}
	var p := _on_ground(side, id)
	if p.is_empty() or str(p.get("role", "")) != "DEF":
		return {}
	return p


## Chance the loose defender actually reaches this aerial contest. A forward
## sent to him drags him away: a Defensive forward keeps him out of most
## contests, any other forward follows him less well (MINDER_ROAM).
func _roam_chance(def_side: int, minded := true) -> float:
	var p := _roaming_interceptor(def_side)
	if p.is_empty():
		return 0.0
	# A strong strategy only with a strong intercepting defender (director,
	# 2026-10-10): a poor reader of the ball seldom gets there at all.
	return _roam_drag(def_side, LOOSE_REACH_MIN + LOOSE_REACH_RANGE * _loose_read(p), minded)


## Chance the loose defender leaves his post for this entry at all, whatever
## his read (LOOSE_GO). Above _roam_chance he goes but is late (director,
## 2026-10-11): a poor reader goes as often as a good one, and pays for it.
func _roam_go_chance(def_side: int, minded := true) -> float:
	if _roaming_interceptor(def_side).is_empty():
		return 0.0
	return _roam_drag(def_side, LOOSE_GO, minded)


## A loose defender's chance cut by what keeps him from the contests: zone
## intercepts share them out (ROAM_REACH), and a forward sent to him drags
## him away (MINDER_ROAM).
func _roam_drag(def_side: int, chance: float, minded := true) -> float:
	if zone_intercepts:
		chance *= ROAM_REACH
	var minder := _spare_minder(1 - def_side) if minded else {}
	if not minder.is_empty():
		chance *= float(MINDER_ROAM["specialist" if Traits.has(minder, "def_forward") else "other"])
	return chance


## The spare arriving as the extra body: how much harder he makes the mark
## (a better reader of the ball, more), never easier.
func _roam_mark_shift(roamer: Dictionary) -> float:
	return -LOOSE_MARK_EDGE * _loose_read(roamer)


## Whether the spare, as the extra body, gets a fist to a ball the defender
## in the contest missed: LOOSE_EXTRA scaled by his game in the air.
func _roam_spoil(roamer: Dictionary) -> bool:
	return aerial_rng.randf() < _roam_spoil_p(roamer)


func _roam_spoil_p(roamer: Dictionary) -> float:
	return clampf(LOOSE_EXTRA * Matchups.defender_air(roamer) / 70.0
			* (LOOSE_SPOIL_FLOOR + (1.0 - LOOSE_SPOIL_FLOOR) * _loose_read(roamer))
			+ (0.05 if _trait(roamer, "interceptor") else 0.0), 0.0, 0.6)


## How well the loose defender reads the ball, 0 (a side's worst defender on
## the ground, about 52) to 1 (its best interceptor, about 78): it scales his reach, his edge in
## the contest and his spoil.
func _loose_read(p: Dictionary) -> float:
	return clampf((Matchups.interceptor_score(p) - LOOSE_READ_FLOOR) / LOOSE_READ_SPAN, 0.0, 1.0)


## Making their loose defender accountable is one of your forwards' job
## (ARD-M4-004, director 2026-10-06): he goes up the ground with him, so he is
## seldom a target inside 50 himself (MINDER_INVOLVE) - the cost is that
## forward's game, not a hidden penalty on the whole line.
const MINDER_ROAM := {"specialist": 0.40, "other": 0.70}
const MINDER_INVOLVE := 0.25
var _minder_memo := [{}, {}]

## Add a timeline entry for each side whose calls changed since the last one.
func _note_tactics() -> void:
	for side in range(2):
		var tag := _tag_id(side)
		var tagger := ""
		if tag != "":
			var t = tagger_of(side)
			if t != null:
				tagger = str(t["id"])
		var kinds: Array = (bursts[side] as Dictionary).keys()
		kinds.sort()
		var entry := {"side": side, "plan": _plan(side), "bursts": kinds, "tag": tag,
				"tagger": tagger, "loose": str((_roaming_interceptor(side)).get("id", "")),
				"accountable": _spare_accountable(side),
				"duels": (duels[side] as Dictionary).duplicate()}
		var key := var_to_str(entry)
		if key == str(_timeline_last[side]):
			continue
		_timeline_last[side] = key
		entry["at"] = events.size()
		timeline.append(entry)


func _spare_accountable(attacking_side: int) -> bool:
	return not _spare_minder(attacking_side).is_empty()


## The forward `attacking_side` has sent to the opposition's loose defender:
## the one named, or - when he is off the ground or none was named - the next
## a coach would send (Matchups.minder_candidates). {} with no call made or no
## loose defender to go to.
func _spare_minder(attacking_side: int) -> Dictionary:
	if attacking_side < 0 or attacking_side > 1:
		return {}
	var t: Dictionary = tactics[attacking_side]
	if not bool(t.get("spare_accountable", false)) or _roaming_interceptor(1 - attacking_side).is_empty():
		return {}
	var named := _on_ground(attacking_side, str(t.get("spare_minder_id", "")))
	if not named.is_empty() and str(named.get("role", "")) == "FWD":
		return named
	# The stand-in, worked out once and kept while he is still out there and
	# the call is the same (every pick asks; the candidates sort the line).
	var key := str(t.get("spare_minder_id", ""))
	var memo: Dictionary = _minder_memo[attacking_side]
	if str(memo.get("key", "-")) == key:
		var kept := _on_ground(attacking_side, str(memo.get("id", "")))
		if not kept.is_empty() and str(kept.get("role", "")) == "FWD":
			return kept
	var cands := Matchups.minder_candidates((squads[attacking_side] as Squad).ground)
	var pick: Dictionary = {} if cands.is_empty() else cands[0]
	_minder_memo[attacking_side] = {"key": key, "id": str(pick.get("id", ""))}
	return pick


## An AI club moves a key defender when their forward has had the better of
## him: three or more contests last quarter and two in three won.
func _ai_rematch(def_side: int) -> void:
	var held := {}
	if str(interceptor[def_side]) != "":
		held[str(interceptor[def_side])] = true
	for fid in duels[def_side].keys():
		if _beaten(def_side, str(fid)):
			_rematch(def_side, str(fid), held)


## Whether the forward `fid` had the better of his direct opponent last
## quarter: three or more contests and two in three won.
func _beaten(def_side: int, fid: String) -> bool:
	var d: Dictionary = duels[def_side]
	var log: Dictionary = duel_log.get(fid, {})
	var n := 0
	var won := 0
	for c in log.get("contests", []):
		if int(c[0]) == current_quarter - 1 and str(c[1]) == str(d.get(fid, "")):
			n += 1
			if bool(c[2]):
				won += 1
	return n >= 3 and float(won) / float(n) >= 0.67


## Move a beaten key defender: the defender who gives `fid` the lowest mark
## chance (Matchups.mark_chance), never one in `held` (the loose man, calls
## the coach made himself). A defender already on another forward is swapped
## across only when the two pairings' mark chances fall in sum; a free one
## only when he is better on `fid` than the man there now.
func _rematch(def_side: int, fid: String, held: Dictionary) -> void:
	var d: Dictionary = duels[def_side]
	var fwd := _on_ground(1 - def_side, fid)
	var cur_id := str(d.get(fid, ""))
	var cur := _on_ground(def_side, cur_id)
	if fwd.is_empty() or cur.is_empty():
		return
	var on := {}
	for other in d:
		on[str(d[other])] = str(other)
	var now := Matchups.mark_chance(fwd, cur)
	var cands := []
	for p in Matchups.defenders((squads[def_side] as Squad).ground):
		var pid := str(p["id"])
		if pid != cur_id and not held.has(pid):
			cands.append([Matchups.mark_chance(fwd, p), pid, p])
	cands.sort_custom(func(a, b): return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and str(a[1]) < str(b[1])))
	for c in cands:
		var gain := now - float(c[0])
		var f2_id := str(on.get(str(c[1]), ""))
		if f2_id != "":
			var f2 := _on_ground(1 - def_side, f2_id)
			if f2.is_empty():
				continue
			gain += Matchups.mark_chance(f2, c[2]) - Matchups.mark_chance(f2, cur)
		if gain > 0.0:
			set_matchup(def_side, fid, str(c[1]))
			return


## Your assistant's routine calls for the quarter about to start, made at
## the break so the coach box shows them as your starting point: the pep
## talk and tag a rival coach would call in your position (ai_tactics), the
## loose defender a rival coach would pick, and a key defender moved off a
## forward who has had the better of him (_rematch). He acts in your club's
## best interest, as every coach does. Whatever you have set yourself he
## leaves alone: a loose man you have named, and the tag and the spare's
## minder once you have picked them (set_tactics' tag_set / minder_set).
## The game plan is always the coach's: it stays what you last chose until
## you change it (director, 2026-11-07: "After every quarter it changes my
## gameplan from balanced to controlled tempo").
func _assistant_calls(side: int) -> void:
	var own: Dictionary = _own[side]
	var t: Dictionary = (tactics[side] as Dictionary).duplicate()
	var call := ai_tactics(side)
	call.erase("interceptor_id")
	call.erase("gameplan")
	if bool(own["tag"]):
		call.erase("tag_id")
	if bool(own["minder"]):
		call.erase("spare_accountable")
		call.erase("spare_minder_id")
	t.merge(call, true)
	set_tactics(side, t)
	if not bool(own["interceptor"]):
		set_interceptor(side, _assistant_interceptor(side), true)
	var d: Dictionary = duels[side]
	var held := {}
	# The loose man stays loose, whoever named him.
	if str(interceptor[side]) != "":
		held[str(interceptor[side])] = true
	for fid in d.keys():
		if _beaten(side, str(fid)):
			_rematch(side, str(fid), held)


## The loose defender a rival coach would use (_ai_interceptor).
func _assistant_interceptor(side: int) -> String:
	return _ai_interceptor(side, (squads[side] as Squad).ground)


## `t` may carry tag_set / minder_set: the coach picked the tag or the
## spare's minder himself, so from then on they are his call, not his
## assistant's (_assistant_calls).
func set_tactics(side: int, t: Dictionary) -> void:
	if side < 0 or side > 1:
		return
	tactics[side] = t.duplicate()
	for key in ["tag", "minder"]:
		if bool((tactics[side] as Dictionary).get(key + "_set", false)):
			(_own[side] as Dictionary)[key] = true
		(tactics[side] as Dictionary).erase(key + "_set")
	if t.has("interceptor_id"):
		set_interceptor(side, str(t.get("interceptor_id", "")), current_quarter > 1 or _q_active)
	# A tag needs its man still in the match, and a midfielder.
	var tag := str(t.get("tag_id", ""))
	if tag != "" and not tag_target_ok(1 - side, tag):
		_drop_tag(side, tag)


## Gameplan trade-offs. Every plan gives something up, and the main three
## counter each other: Attack Corridor beats Controlled Tempo (no pressure to
## punish it), Controlled Tempo beats the High Press (it plays through
## the pressure), and the press beats Attack Corridor (it squeezes the
## corridor into turnovers). Keys: goal (own conversion), opp_goal (theirs),
## exposed (their conversion when you turn it over), gain (metres),
## clangers, press (pressure you apply), taken (pressure you take),
## contest (stoppage win), pace (how fast legs go).
## What each plan gains (scaled by how well the list suits it, PlanFit); the
## rest of its keys are what it gives up.
const PLAN_UPSIDE := {
	"attacking": ["goal", "gain"],
	"defensive": ["press", "opp_goal"],
	"contest": ["contest"],
	"controlled": ["taken", "clangers", "goal", "pace"],
}
const PLANS := {
	"attacking": {"goal": 1.05, "gain": 1.06, "clangers": 1.12, "pace": 1.12, "exposed": 1.07},
	# The press's own shots: legs spent chasing, shots taken rushed (0.88;
	# director 2026-10-11, the real cost of winning it high, was 0.96).
	"defensive": {"press": 1.09, "opp_goal": 0.965, "goal": 0.88, "gain": 0.95, "pace": 1.12},
	"contest": {"contest": 0.025, "gain": 0.95, "exposed": 1.04},
	"controlled": {"taken": 0.96, "gain": 0.94, "goal": 1.01, "clangers": 0.93, "pace": 0.95},
}


## How much of a plan's upside the day allows (ARD-M4-016, the director:
## "contested footy is better in the wet as it's less precise; in dry weather
## ball handling is easier and it's easier to mark the ball"). A perfect day is
## the calibrated game, so the dry plans' edge there is what the wet takes
## away. The rule is shown to the player in words, never as a recommendation.
const WEATHER_PLAN := {
	"wet": {"contest": 1.35, "defensive": 1.2, "press": 1.2, "attacking": 0.6, "fast": 0.6,
			"controlled": 0.85},
	"windy": {"controlled": 1.25, "attacking": 0.85, "fast": 0.85},
	"hot": {"attacking": 1.2, "fast": 1.2, "defensive": 0.8, "press": 0.8},
}


## A plan's value for this side. Its upside grows with how well the players
## suit it (PlanFit) and how sharply the coaches execute it
## (Squad.tactics_exec, 1.0 = as written); what it gives up is the plan's
## own and does not move.
func _pv(side: int, key: String, fallback := 1.0) -> float:
	var plan := _plan(side)
	var v := float((PLANS.get(plan, {}) as Dictionary).get(key, fallback))
	var scale := 1.0
	# The coach's Strategic archetype grows his own plan's upside and cost (row 119).
	var amp := 1.0
	if str((arch[side] as Dictionary).get("fplan", "")) == plan:
		amp = _ar(side, "sup") if (PLAN_UPSIDE.get(plan, []) as Array).has(key) else _ar(side, "scost")
	if (PLAN_UPSIDE.get(plan, []) as Array).has(key):
		scale = float((squads[side] as Squad).tactics_exec) \
				* float((plan_fit[side] as Dictionary).get(plan, 1.0)) \
				* float((WEATHER_PLAN.get(weather, {}) as Dictionary).get(plan, 1.0))
		# A plan the side knows less than well gives less of its upside.
		var know: Dictionary = (squads[side] as Squad).plan_know
		if not know.is_empty():
			scale *= float(know.get(plan, 1.0))
	return fallback + (v - fallback) * scale * amp


## How much of `plan`'s written upside a squad carries out today: its list's
## fit, its coaches' execution, how well it knows the plan, the weather and a
## Strategic coach's own plan, the same factors _pv multiplies (the gate's
## "Gain for this list today", director 2026-11-10; tests/test_coach_effects.gd
## holds the two together).
static func upside_scale(sq: Squad, plan: String, weather_key := "perfect") -> float:
	plan = plan_key(plan)
	var s := float(sq.tactics_exec) * PlanFit.fit(sq.ground, plan) \
			* float((WEATHER_PLAN.get(weather_key, {}) as Dictionary).get(plan, 1.0))
	if not sq.plan_know.is_empty():
		s *= float(sq.plan_know.get(plan, 1.0))
	if str(sq.arch.get("fplan", "")) == plan:
		s *= float(sq.arch.get("sup", 1.0))
	return s


## How much of `plan`'s written cost a squad pays: the plan's own, grown only
## by a Strategic coach's own plan (row 119).
static func cost_scale(sq: Squad, plan: String) -> float:
	plan = plan_key(plan)
	if str(sq.arch.get("fplan", "")) == plan:
		return float(sq.arch.get("scost", 1.0))
	return 1.0


## Pressure multiplier `side` faces from the opposition's plan, counters in.
## Controlled Tempo takes the sting out of a press as far as its ball users
## can: a side of ordinary ones or better holds it off, poor ones only
## partly (PlanFit, "controlled"). The press is where the ball is
## (PRESS_PLAN_ZONE): numbers pushed up into his back third and taken out
## of our own defensive third. What it pushes up grows with how well the
## list suits the plan; what it leaves at the back does not.
func _press_on(side: int, zone := 1) -> float:
	var m := _pv(1 - side, "press")
	if m > 1.0:
		var suit := (m - 1.0) / (float((PLANS["defensive"] as Dictionary)["press"]) - 1.0)
		var z := float(PRESS_PLAN_ZONE[zone])
		m = 1.0 + (z - 1.0) * suit if z > 1.0 else z
	if m > 1.0 and _plan(side) == "controlled":
		var hold := clampf(float((plan_fit[side] as Dictionary).get("controlled", 1.0)), 0.0, 1.0)
		m = 1.0 + (m - 1.0) * (1.0 - hold)
	elif m > 1.0 and _plan(side) == "attacking":
		m *= 1.10
	return m


## The side whose chain got out of its back third unpressured against a
## press (PRESS_BROKEN_EXPOSED), or -1. Reset at each chain's start.
var _broke_press := -1
## The side whose chain got out of its back third unpressured against The
## "Open on the break" cost of a side's own plan (CustomPlan "broken"), or -1.
## Reset with _broke_press.
var _broke_cluster := -1


## Morale from the coach's Philosophical archetype, as match form by player id
## (10 morale points = 1%, like ClubLife.form), and the dice for his extra injuries.
var _arch_form := {}
var arch_rng := RandomNumberGenerator.new()
## Each side's coach archetype levers (Archetypes.levers, from Squad.arch, row 119).
var arch := [{}, {}]


func _ar(side: int, key: String, d := 1.0) -> float:
	return float((arch[side] as Dictionary).get(key, d))


## Each side's own plan (CustomPlan, Squad.custom_plan; director 2026-11-12),
## cleaned: {"name", "s", "c"}; {} when the club has built none.
var custom := [{}, {}]
## The dice for an own plan's extra injuries ("Injury toll"): their own stream,
## so a match without one plays out exactly as before.
var custom_rng := RandomNumberGenerator.new()


## A side's own-plan lever `key` (CustomPlan entries), or `d` while it is not
## on its own plan, its plan pulls another lever, or the lever's gate is shut
## (quarter or scoreboard). The strength grows with the side's execution, list
## fit, knowledge and the weather like any plan's upside (_custom_up); the cost
## is as written. Off its own plan every lever is 1.0 (or 0.0 when added), so
## the match is the same to the bit.
func _gt(side: int, key: String, d := 1.0) -> float:
	var p: Dictionary = custom[side]
	if p.is_empty() or _plan(side) != CustomPlan.KEY:
		return d
	var s := CustomPlan.entry(str(p["s"]), true)
	if str(s.get("lever", "")) == key:
		return CustomPlan.lever(s, key, d, _custom_up(side)) if _gate_open(side, str(s["gate"])) else d
	var c := CustomPlan.entry(str(p["c"]), false)
	if str(c.get("lever", "")) == key:
		return CustomPlan.lever(c, key, d) if _gate_open(side, str(c["gate"])) else d
	return d


## How much of an own plan's written strength `side` carries out: the same
## factors as any plan's upside (_pv). An own plan asks nothing special of a
## list (fit 1.0, like Balanced) and no Strategic coach's plan is one.
func _custom_up(side: int) -> float:
	var k := CustomPlan.KEY
	var scale := float((squads[side] as Squad).tactics_exec) 			* float((plan_fit[side] as Dictionary).get(k, 1.0)) 			* float((WEATHER_PLAN.get(weather, {}) as Dictionary).get(k, 1.0))
	var know: Dictionary = (squads[side] as Squad).plan_know
	if not know.is_empty():
		scale *= float(know.get(k, 1.0))
	return scale


## Whether an own-plan entry's gate is open for `side` now.
func _gate_open(side: int, gate: String) -> bool:
	match gate:
		"q1":
			return current_quarter == 1
		"q4":
			return current_quarter >= 4
		"lead":
			return score(side) > score(1 - side)
		"lead_big":
			return float(score(side) - score(1 - side)) > runaway_lead
	return true


func _plan(side: int) -> String:
	return plan_key(str((tactics[side] as Dictionary).get("gameplan", "balanced")))


## ARD-M4-015 (the director, 2026-10-06: "merge the duplicates"): "Fast
## movement" was Attack Corridor and "High press" was Defensive Press under
## older names, the same effects; renamed High Press again (director 2026-11-12:
## "Rename High Press"). Old saves and replays map across.
## Through stars (#874) is cut (director, 2026-11-07: the three play-through
## calls are back instead): an old save or replay on it plays Balanced.
const PLAN_ALIAS := {"fast": "attacking", "press": "defensive", "through_stars": "balanced"}


static func plan_key(key: String) -> String:
	return str(PLAN_ALIAS.get(key, key))


func _pep(side: int) -> String:
	return str((tactics[side] as Dictionary).get("pep", "steady"))


## The three play-through calls (director, 2026-10-07): a midfield pillar,
## a forward target and a backline distributor, each chosen on its own.
const FOCUS_SLOTS := ["focus_mid", "focus_fwd", "focus_def"]
## The ground roles each call works from: off them (benched, moved) it waits.
const FOCUS_SLOT_ROLES := {"focus_mid": ["MID", "RUCK"], "focus_fwd": ["FWD"], "focus_def": ["DEF"]}


## Who this side plays through, {id: slot}. The single older call (focus_id,
## older saves') counts as the slot his role fills, unless that slot has its
## own call.
func _focus_slots(side: int) -> Dictionary:
	var t: Dictionary = tactics[side]
	var out := {}
	for slot in FOCUS_SLOTS:
		var id := str(t.get(slot, ""))
		if id != "":
			out[id] = slot
	var legacy := str(t.get("focus_id", ""))
	if legacy != "" and not out.has(legacy):
		var p = _ground_player(side, legacy)
		if p != null:
			var slot := focus_slot_for(str(p["role"]))
			if str(t.get(slot, "")) == "":
				out[legacy] = slot
	return out


## The play-through slot a ground role fills.
static func focus_slot_for(role: String) -> String:
	for slot in FOCUS_SLOT_ROLES:
		if (FOCUS_SLOT_ROLES[slot] as Array).has(role):
			return slot
	return "focus_mid"


## The players this side plays through (every pick, working or waiting).
func focus_ids(side: int) -> Array:
	return _focus_slots(side).keys() if side >= 0 and side <= 1 else []


## Whether `slot`'s call is working now: its man is on the ground in a spot
## the call works from (a forward target resting on the bench is not).
func focus_active(side: int, slot: String) -> bool:
	var id := str((tactics[side] as Dictionary).get(slot, ""))
	if id == "":
		return false
	var p = _ground_player(side, id)
	return p != null and (FOCUS_SLOT_ROLES[slot] as Array).has(str(p["role"]))


func _ground_player(side: int, id: String):
	for p in (squads[side] as Squad).ground:
		if str(p["id"]) == id:
			return p
	return null


func _tag_id(side: int) -> String:
	return str((tactics[side] as Dictionary).get("tag_id", ""))


## A tag in the midfield battle: contest points `side` loses to tags this
## chain. Their tag on one of ours takes that share of his game (1 - the tag
## share) out of our midfield - the better he is, the more it hurts. Our own
## tag costs us TAGGER_COST of our tagger's game: he plays the man, not the
## ball. So a specialist tagger on their star is worth it; your best
## midfielder on an ordinary one is not.
const TAGGER_COST := 0.4
## His own share of the ball while he tags.
const TAGGER_BALL := 0.6

func _tag_drag(side: int) -> float:
	var parts := _tag_parts(side)
	return parts[0] + parts[1]


## _tag_drag in its two halves: [their tag on one of ours, our own tag's
## cost in our tagger's game]. Each half belongs to the coach who called it
## (the tag line of the full-time summary).
func _tag_parts(side: int) -> Array:
	var sq: Squad = squads[side]
	var n_centre := 0
	var n_mids := 0
	for p in sq.ground:
		if str(p["role"]) == "MID":
			n_mids += 1
			if not Roles.on_wing(p):
				n_centre += 1
	if n_mids == 0:
		return [0.0, 0.0]
	var theirs := 0.0
	var ours := 0.0
	var tagged := _on_ground(side, _tag_id(1 - side))
	if not tagged.is_empty() and can_be_tagged(tagged):
		theirs = (1.0 - _tag_share(1 - side)) * _mid_value(tagged, n_centre, n_mids)
	if _tag_id(side) != "" and not _on_ground(1 - side, _tag_id(side)).is_empty():
		var t = tagger_of(side)
		if t != null:
			ours = TAGGER_COST * _mid_value(t, n_centre, n_mids)
	return [theirs, ours]


## One midfielder's part in his side's contest number (Squad._aggregate): his
## contested ball in the centre-square mean, his disposal in the midfield's.
func _mid_value(p: Dictionary, n_centre: int, n_mids: int) -> float:
	var v := 0.22 * _a(p, "disposal") / float(maxi(1, n_mids))
	if not Roles.on_wing(p):
		v += 0.42 * _a(p, "contested") / float(maxi(1, n_centre))
	return v


## How much of the ball the player `side` tags still gets (Roles.tag_keep: the
## Pressure of the man on him and his legs now, so a tiring tagger lets him off
## the leash).
func _tag_share(side: int) -> float:
	var t = tagger_of(side)
	if t == null:
		return Roles.TAG_LOOSEST
	return Roles.tag_keep(t, float(energy.get(str(t["id"]), 100.0)))


# ---------------------------------------------------------------------------
# Stat bookkeeping
# ---------------------------------------------------------------------------
## How a carrier broke a tackle: "dont_argues" (he fended the tackler off) or
## "evaded_tackles" (he stepped out of it). Strength in the contest leans to
## the fend, pace (his running game, carry) to the evade; an even player is a
## coin toss (director, 2026-10-08). A record of what happened: the break
## itself was decided before this, so neither changes the play.
func _break_kind(carrier: Dictionary) -> String:
	var lean := (float(carrier["attr"].get("contested", 50)) - float(carrier["attr"].get("carry", 50))) / 100.0
	var fend := clampf(0.5 + BREAK_LEAN * lean, BREAK_MIN, 1.0 - BREAK_MIN)
	return "dont_argues" if break_rng.randf() < fend else "evaded_tackles"


## How far a contested-over-running gap tilts a broken tackle toward a fend,
## and the least likely either way stays.
const BREAK_LEAN := 1.2
const BREAK_MIN := 0.12


func _t(side: int, key: String, n := 1.0) -> void:
	var d: Dictionary = team_stats[side]
	d[key] = float(d.get(key, 0.0)) + n


## Ground won going forward by this possession: the ball's actual movement
## toward the side's goal. Going backwards earns nothing.
func _metres(side: int, player, m: float) -> void:
	if m <= 0.0:
		return
	_t(side, "metres_gained", m)
	_p(player, "metres_gained", m)


func _effective(side: int, player) -> void:
	_t(side, "effective_disposals")
	_p(player, "effective_disposals")


## Disposal efficiency, 0-100: the share of disposals that kept the ball.
static func disposal_efficiency(st: Dictionary) -> int:
	var d := float(st.get("disposals", 0.0))
	if d <= 0.0:
		return 0
	return int(round(100.0 * float(st.get("effective_disposals", 0.0)) / d))


## A roaming contest decided: the roamer's win or loss, and against whom.
func _roam_note(roamer: Dictionary, target, won: bool) -> void:
	_p(roamer, "roam_wins" if won else "roam_losses")
	if target == null or (target is Dictionary and (target as Dictionary).is_empty()):
		return
	var key := "%s|%s" % [str(roamer.get("id", "")), str(target.get("id", ""))]
	var rec: Array = roam_pairs.get(key, [0, 0])
	rec[0] = int(rec[0]) + 1
	if won:
		rec[1] = int(rec[1]) + 1
	roam_pairs[key] = rec


func _p(player, key: String, n := 1.0) -> void:
	if player == null:
		return
	var id: String = player["id"]
	if not player_stats.has(id):
		player_stats[id] = {}
	var d: Dictionary = player_stats[id]
	d[key] = float(d.get(key, 0.0)) + n


## A side's Pressure Rating for a match (or part of one), from its own and
## its opponent's team stats: pressure acts per 100 opposition disposals,
## with pressure that stopped their move (a tackle that forced a ball-up, or
## a turnover) counting twice. A typical side lands near 60. Our own game
## measure, read straight from what happened.
static func pressure_rating(team: Dictionary, opp_team: Dictionary) -> int:
	var opp_disposals := float(opp_team.get("disposals", 0.0))
	if opp_disposals <= 0.0:
		return 0
	var acts := float(team.get("pressure_acts", 0.0)) + float(team.get("pressure_wins", 0.0))
	return clampi(roundi(100.0 * acts / opp_disposals), 0, 100)


func score(side: int) -> int:
	return int(goals(side) * 6 + behinds(side))


func goals(side: int) -> int:
	return int(float(team_stats[side].get("goals", 0.0)))


func behinds(side: int) -> int:
	return int(float(team_stats[side].get("behinds", 0.0)))


## The club a player represents in this match: the side whose list he is on,
## never p["club"], which can be his source club (a league re-draft, a trade).
func club_of(p: Dictionary) -> String:
	if _side_of.is_empty():
		for side in range(squads.size()):
			var sq: Squad = squads[side]
			for q in sq.list + sq.ground + sq.bench:
				_side_of[str(q["id"])] = side
	var id := str(p.get("id", ""))
	if _side_of.has(id):
		return _side_club(int(_side_of[id]), p)
	return str(p.get("club", ""))


var _side_of := {}       # player id -> the side he plays for today (club_of)


func _side_club(side: int, p: Dictionary) -> String:
	var code := str((squads[side] as Squad).code)
	return code if code != "" else str(p.get("club", ""))


func _emit(kind: String, side: int, fp: float, actor, text: String) -> void:
	events.append({
		"q": current_quarter,
		"min": current_minute,
		"kind": kind,
		"side": side,
		"fp": fp,
		"name": "" if actor == null else GameDB.player_display_name(actor),
		"player_id": "" if actor == null else str(actor.get("id", "")),
		"num": 0 if actor == null else int(actor["num"]),
		"club": "" if actor == null else club_of(actor),
		"text": text,
		"score": [score(0), score(1)],
		"goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
		"mom": snappedf(momentum, 0.01),
	})
	if not _set_choice.is_empty():
		events[events.size() - 1]["choice"] = str(_set_choice["key"])
		if ["goal", "behind", "rebound"].has(kind):
			events[events.size() - 1]["setshot"] = true
			for k in ["passer_id", "to_id"]:
				if _set_choice.has(k):
					events[events.size() - 1][k] = str(_set_choice[k])
	# A score from a turnover: whose intercept it came from.
	if (kind == "goal" or kind == "behind") and not _chain_from.is_empty() \
			and int(_chain_from["side"]) == side:
		events[events.size() - 1]["from_id"] = str(_chain_from["id"])
	# A named contest belongs to the score or rebound it produced.
	if not _duel.is_empty() and ["goal", "behind", "rebound"].has(kind) and actor != null \
			and [str(_duel["fwd"]), str(_duel["def"])].has(str(actor.get("id", ""))):
		events[events.size() - 1]["duel"] = _duel.duplicate()
		if kind == "goal" and str(actor.get("id", "")) == str(_duel["fwd"]):
			var c: Array = (duel_log[str(_duel["fwd"])]["contests"] as Array)
			c[c.size() - 1][3] = true
		_duel = {}


# ---------------------------------------------------------------------------
# Selection helpers
# ---------------------------------------------------------------------------
static func _by_roles(group: Array, roles: Array) -> Array:
	var out := []
	for p in group:
		if roles.has(p["role"]):
			out.append(p)
	return out


## Who can do what, as weights by listed line rather than hard gates: every
## line can make any ordinary play, each leans where it belongs. The lines
## that could always do it keep full weight.
## Carrying by zone (from the carrying side's view).
## Middle zone calibrated 2026-10-06 against real 2026 per-role disposals: a
## forward carries less through the middle than a midfielder (0.6).
## Defenders run on with it (2026-11-08): once they clear the ball out of
## their 50 (D50_KICK_GAIN) a half-back keeps running with the play through
## the middle (0.9) and into the forward half (0.6). At the old 0.45 / 0.2 the
## ball they cleared went almost only to midfielders, wings and small
## forwards: defenders had 32% of their side's disposals (real 35.9%), and
## wings, taggers and small forwards went over the clubs' range. Measured on
## tools/balance.sh match 1000 (league setup): defenders back to 36%, wings
## 22.3, taggers 17.8, small forwards 14.9, all inside the range.
## Realism tune (director, 2026-11-09): midfielders took too much of the ball
## between the arcs and forwards too little (MID 24.7 disposals a game, real
## 20.5; FWD 10.1, real 11.7), so MID comes down here and LEAD_UP_SIZES lets key
## forwards lead up to more. Measured on tools/balance.sh match 1000.
const CARRY_ROLES := {
	"middle": {"MID": 0.7, "RUCK": 0.8, "DEF": 0.75, "FWD": 0.7},
	"attack": {"MID": 0.6, "FWD": 1.0, "DEF": 0.45, "RUCK": 0.22},
	"inside": {"FWD": 1.0, "MID": 0.85, "RUCK": 0.3, "DEF": 0.05},
}
## Back-zone carrying retuned (row 92, T9.Q22, director 2026-11-06: defenders
## carry the ball more than real AFL). A defender still leads the back zone's
## ball, a midfielder drops back to take more of it. The back zone's weights
## (CARRY_ROLES holds the other zones'). Row 92 set them on the intercept
## rating, and they still split the back zone's ball between the lines as
## they did then (_back_roles); unchanged since.
const CARRY_BACK_RETUNED := {"DEF": 0.55, "MID": 1.0, "RUCK": 0.3, "FWD": 0.12}
## The rating a back-zone carrier is picked on (director 2026-11-07): his use
## of the ball, the carry/disposal blend kick_in_taker uses, not his
## intercepting, so the best spoiler is not also the one the ball goes to.
## Who in a line gets it changes; how much each line gets does not.
## The power on the rating in the carrier pick (2026-11-09). At 2 the ball went
## too much to the better-rated line; at 1.4 and 1.6 midfielders came closer
## still; row 136 settled on 1.5, with key forwards' leads holding margins up.
const CARRY_PICK_POW := 1.5
const BALL_USE := "ball_use"
const BALL_USE_CARRY := 0.58
const BALL_USE_DISPOSAL := 0.42
## Forward archetypes (ARD-M3-002), by size as Training's jobs: a key
## forward from 192 cm, a small forward up to 181 cm, a general forward
## between. Key forwards present in the air inside 50 and bring the ball to
## ground; small forwards hunt it at ground level and run up the ground to
## take their marks on the lead; either can still score the other way.
const FWD_KEY_CM := 192.0
const FWD_SMALL_CM := 181.0
## Lead-up work in the middle and attack zones: small half-forwards get to
## more of it, key forwards stay deeper.
const LEAD_UP_SIZES := {"small": 1.25, "general": 1.15, "key": 1.35}
## Who is at the fall of the ball when a contest spills or is spoiled.
const GROUND_SIZES := {"small": 1.8, "general": 1.0, "key": 0.45}
## His own game in the air moves an unmatched entry's mark chance by
## (forward_air - FWD_AIR_CENTRE) / FWD_AIR_SCALE.
const FWD_AIR_CENTRE := 58.0
const FWD_AIR_SCALE := 170.0
## An unmarked, unspoiled entry hits the deck this often (more off a tall
## target), and a ground-ball forward gets the shot instead of the target.
const SPILL_P := {"key": 0.45, "general": 0.30, "small": 0.18}
## Entries are kicked to a target: a key forward is the one they look for
## more often, a small forward less (he gets his off the deck).
const TARGET_SIZES := {"key": 1.12, "general": 1.0, "small": 0.95}
## Whether the first forward to a spill wins it at ground level (by size,
## then his Pressure); lose it and the defence clears it. A forward line of
## talls brings it down with nobody small to win it.
const GROUND_WIN := {"small": 0.85, "general": 0.70, "key": 0.50}


static func fwd_size(p: Dictionary) -> String:
	var h := float(p.get("height_cm", 0.0))
	if h >= FWD_KEY_CM:
		return "key"
	if h > 0.0 and h <= FWD_SMALL_CM:
		return "small"
	return "general"


## Who takes the shot from an entry: a resting ruck or a defender pushed
## forward kicks the odd goal.
const SHOT_ROLES := {"FWD": 1.0, "MID": 1.0, "RUCK": 0.35, "DEF": 0.06}
## Who wins a clearance: forwards and defenders at a stoppage now and then
## (2026-11-09: 0.14, 0.24 and 0.3, against real 2026 by line, from 0.25, 0.12, 0.10).
## A ruck wins a quarter of what a midfielder would around the ground: he
## taps it to them (calibrated 2026-10-06 to 3.8 a game, real 3.6; centre
## bounces pick from the attendees by contested work alone).
const CLEARANCE_ROLES := {"MID": 1.0, "RUCK": 0.14, "FWD": 0.24, "DEF": 0.3}
## A ball-up inside a side's own forward 50 is the forwards' ground: they win
## it as often as a midfielder would, so the stoppages the ruck now taps on
## don't all go to midfielders (item 18, 2026-10-06: keeps rating parity).
const CLEARANCE_ROLES_F50 := {"MID": 1.0, "RUCK": 0.14, "FWD": 1.0, "DEF": 0.3}
## The clearance winner takes the chain's first disposal, as a clearance is
## in real football (director, 2026-10-06; evidence #363). The carrier pick is
## still drawn, so the rest of the chain's dice are where they were. Off only
## as the audit baseline (the old rule: the first carrier from the whole ground).
static var clearance_keeps := true
## Who is credited a one-percenter (a spoil, smother or shepherd).
const ONE_PCT_ROLES := {"DEF": 1.0, "RUCK": 0.5, "MID": 0.3, "FWD": 0.1}


## `_weighted` over a whole group, each player's weight scaled by his line.
func _weighted_roles(group: Array, key: String, roles: Dictionary, power := 2.0, side := -1, purpose := "",
		sizes: Dictionary = {}, zone := ""):
	if group.is_empty():
		return null
	var ctx := _pick_ctx(side) if side >= 0 else {}
	if side >= 0:
		ctx["zone"] = zone
	var weights := []
	for p in group:
		var rating := _ball_use(p) if key == BALL_USE else _a(p, key)
		var w: float = float(roles.get(str(p["role"]), 0.0)) * pow(maxf(1.0, rating), power)
		if not sizes.is_empty() and str(p["role"]) == "FWD":
			w *= float(sizes.get(fwd_size(p), 1.0))
		if side >= 0:
			w *= _tactic_player_mult(side, p, purpose, ctx)
		weights.append(w)
	return _pick(group, weights)


## Weighted random pick. Better players at the relevant attribute get the ball
## more often, squared so the gap is meaningful but not deterministic.
func _weighted(group: Array, key: String, power := 2.0, side := -1, purpose := ""):
	if group.is_empty():
		return null
	var ctx := _pick_ctx(side) if side >= 0 else {}
	var weights := []
	for p in group:
		var w: float = pow(maxf(1.0, _a(p, key)), power)
		if side >= 0:
			w *= _tactic_player_mult(side, p, purpose, ctx)
		weights.append(w)
	return _pick(group, weights)


## What _tactic_player_mult needs that is the same for every player in one
## pick - the focus, the tags, the plan. Worked out once a pick, not once a
## player (finding the tagger walks the whole ground). Pure: no dice.
func _pick_ctx(side: int) -> Dictionary:
	var their_tag := _tag_id(1 - side)
	var tagger_id := ""
	if _tag_id(side) != "":
		var tagger = tagger_of(side)
		if tagger != null:
			tagger_id = str(tagger["id"])
	var minder := _spare_minder(side)
	return {"focus": _focus_slots(side), "their_tag": their_tag, "minder": str(minder.get("id", "")),
			"tag_share": _tag_share(1 - side) if their_tag != "" else 1.0,
			"tagger": tagger_id}


func _tactic_player_mult(side: int, p: Dictionary, purpose: String, ctx: Dictionary = {}) -> float:
	if ctx.is_empty():
		ctx = _pick_ctx(side)
	var out := 1.0
	var id := str(p["id"])
	var slot := str((ctx["focus"] as Dictionary).get(id, ""))
	# A call works only while he fills a spot it works from.
	if slot != "" and not (FOCUS_SLOT_ROLES[slot] as Array).has(str(p["role"])):
		slot = ""
	var focused := slot != ""
	# "transition" is a carry in the middle of the ground (pick_carrier).
	var carrying := purpose == "carrier" or purpose == "transition"
	# The wings run the ball through the middle and are not at the stoppage.
	if purpose == "transition" and Roles.on_wing(p):
		out *= Roles.WING_TRANSITION
	elif purpose == "clearance" and Roles.on_wing(p):
		out *= Roles.WING_STOPPAGE
	# "Play through him" is a job by the slot he fills (focus_role_text).
	# A midfielder or ruck gets more of the ball in every chain, and is not
	# made the shooter: his forwards still take the shots. A forward gets
	# the ball up forward and the shots at goal; a defender has first use
	# coming out of the back half. A small early boost, then the usage
	# curve fades him back toward a low-30s disposal game.
	if focused:
		out *= _focus_mult(slot, purpose, str(ctx.get("zone", "")))
	if carrying and _trait(p, "ball_magnet"):
		out *= 1.10
	if carrying and weather == "wet" and _trait(p, "wet_weather"):
		out *= Traits.WET_BALL
	if purpose == "clearance" and _trait(p, "bull"):
		out *= 1.15
	# A Crumber lives at the feet of the pack: he is there when it spills.
	if purpose == "crumb" and _trait(p, "crumber"):
		out *= CRUMBER_AT_FEET
	if id == str(ctx["their_tag"]) and can_be_tagged(p) and (carrying or purpose == "shooter" or purpose == "crumb"):
		out *= float(ctx["tag_share"])
	# Our tagger is playing the man, not the ball.
	if carrying and id == str(ctx["tagger"]):
		out *= TAGGER_BALL
	# Our forward minding their loose defender is up the ground with him.
	if id == str(ctx.get("minder", "")) and purpose in ["shooter", "aerial_target", "crumb", "carrier"]:
		out *= MINDER_INVOLVE
	if carrying:
		out *= _usage_mult(p, focused)
	return out


## What playing through a player is worth, by the slot he fills and where the
## pick is made. FOCUS_CARRY is the chain bias; a forward also has FOCUS_SHOT
## when the shooter is picked (a redistribution of the shots, not more of them),
## and a defender FOCUS_EXIT for the carrier out of the back half only.
const FOCUS_CARRY := 1.14
const FOCUS_SHOT := 1.25
const FOCUS_EXIT := 1.25


func _focus_mult(slot: String, purpose: String, zone: String) -> float:
	var carrying := purpose == "carrier" or purpose == "transition"
	match slot:
		"focus_fwd":
			if purpose == "shooter":
				return FOCUS_SHOT
			if carrying and zone != "back" and zone != "middle":
				return FOCUS_CARRY
		"focus_def":
			if carrying and zone == "back":
				return FOCUS_EXIT
		_:
			if carrying:
				return FOCUS_CARRY
	return 1.0


## The usage curve: disposals before a player's share starts to fade, and how
## fast it fades; a played-through man's runs on longer (GateOdds.focus_texts).
const USAGE_START := 18.0
const USAGE_START_FOCUSED := 21.0
const USAGE_WIDTH := 6.4
const USAGE_WIDTH_FOCUSED := 5.4


## Soft possession cap. Team disposal volume is unchanged — this only stops one
## player absorbing every chain once they have already had a huge game.
## Must match tools/sim_harness.py::usage_multiplier (the unfocused curve).
func _usage_mult(p: Dictionary, focused: bool) -> float:
	var d := 0.0
	var id := str(p["id"])
	if player_stats.has(id):
		d = float((player_stats[id] as Dictionary).get("disposals", 0.0))
	var start := USAGE_START_FOCUSED if focused else USAGE_START
	if d <= start:
		return 1.0
	var over := d - start
	var width := USAGE_WIDTH_FOCUSED if focused else USAGE_WIDTH
	return maxf(0.02, exp(-(over * over) / (width * width)))


func _pick(group: Array, weights: Array):
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return group[0]
	var r := (gather_rng if _gathering else rng).randf() * total
	var acc := 0.0
	for i in range(group.size()):
		acc += weights[i]
		if r <= acc:
			return group[i]
	return group[group.size() - 1]


## Which side wins the ball at a stoppage. Field position nudges it (a centre
## bounce deep in your forward half slightly favours the home structure), and
## the result is clamped so no list is ever guaranteed the ball.
func contest_winner(use_fp: bool, fp: float) -> int:
	var T := _rates()
	var lim := float(T["contest_clamp"])
	# Midfield legs scale the contest strength; the Legs line gets the credit.
	var tags0 := _tag_parts(0)
	var tags1 := _tag_parts(1)
	var drag0: float = tags0[0] + tags0[1]
	var drag1: float = tags1[0] + tags1[1]
	# A side's tag: what it takes out of their midfield, less what its tagger
	# gives up of his own game.
	_credit(0, "tag", (float(tags1[0]) - float(tags0[1])) / float(T["contest_swing"]) * POSSESSION_VALUE, _tag_id(0))
	_credit(1, "tag", (float(tags0[0]) - float(tags1[1])) / float(T["contest_swing"]) * POSSESSION_VALUE, _tag_id(1))
	var c0: float = squads[0].contest * _mid_fit(0) - drag0
	var c1: float = squads[1].contest * _mid_fit(1) - drag1
	var legs_edge: float = ((c0 + drag0 - c1 - drag1) - (squads[0].contest - squads[1].contest)) / float(T["contest_swing"])
	_credit(0, "legs", legs_edge * POSSESSION_VALUE)
	_credit(1, "legs", -legs_edge * POSSESSION_VALUE)
	var form_edge := FORM_CONTEST * (float(form[0]) - float(form[1]))
	_credit(0, "form", FORM_CONTEST * float(form[0]) * POSSESSION_VALUE)
	_credit(1, "form", FORM_CONTEST * float(form[1]) * POSSESSION_VALUE)
	# Togetherness (row 84): a tight group goes in for each other at the
	# contest, a group with cliques doesn't. Credited for audits only: the
	# director wants no match copy for it (2026-11-10), only the culture screen.
	var tog0 := float((squads[0] as Squad).together)
	var tog1 := float((squads[1] as Squad).together)
	_credit(0, "together", tog0 * POSSESSION_VALUE)
	_credit(1, "together", tog1 * POSSESSION_VALUE)
	var p_home: float = (0.5
			+ (c0 - c1) / float(T["contest_swing"])
			+ home_edge() + form_edge + tog0 - tog1)
	# The side with the run of play wins a little more of the ball.
	var run := runaway()
	p_home += momentum_edge * momentum * (1.0 + runaway_gain * run) * _front_run()
	if run > 0.0:
		# A runaway can carry the leader to the contest cap on its own; cap it
		# here so the coaches' contest calls below still move the odds (the
		# trailing coach's surge or stack is never swallowed by the cap).
		p_home = clampf(p_home, 1.0 - lim, lim)
	var b0 := _contest_bonus(0, not use_fp)
	var b1 := _contest_bonus(1, not use_fp)
	p_home += b0 - b1
	_credit_contest(0, not use_fp)
	_credit_contest(1, not use_fp)
	if use_fp:
		p_home += clampf(fp / 900.0, -0.07, 0.07)
	p_home = maxf(1.0 - lim, minf(lim, p_home))
	if not _tap.is_empty():
		# At a ruck contest the tap, not the list's ruck on paper, is what
		# the rucks give (the lists' ruck term comes out; see _ruck_tap).
		p_home -= RUCK_WEIGHT * (float(squads[0].ruck) - float(squads[1].ruck)) / float(T["contest_swing"])
		p_home = clampf(p_home + float(_tap["edge"]), 0.08, 0.92)
	return 0 if rng.randf() < p_home else 1


## The home-ground edge at stoppages, from side 0's point of view: a club
## playing at its own home ground (Squad.home) has it. In an ordinary match
## that is the home side only. At the Grand Final (always the MCG) either
## club, or both, can be at home - two MCG clubs cancel out, and a club
## listed in the home slot gets nothing for the slot alone.
func home_edge() -> float:
	var bonus := float(Ratings.T["home_ground_bonus"])
	return (bonus if (squads[0] as Squad).home else 0.0) \
			- (bonus if (squads[1] as Squad).home else 0.0)


func _contest_bonus(side: int, stoppage := false) -> float:
	return _contest_plan(side) + _contest_pep(side) + _contest_calls(side, stoppage) \
			+ _contest_traits(side) + _contest_own_plan(side, stoppage)


## An own plan's edge at a stoppage ("Stoppage numbers", or its cost "Light
## at stoppages"; CustomPlan).
func _contest_own_plan(side: int, stoppage: bool) -> float:
	return _gt(side, "stoppage", 0.0) if stoppage else 0.0


func _contest_traits(side: int) -> float:
	return Traits.power("engine_room") if synergies[side].has("engine_room") else 0.0


func _contest_plan(side: int) -> float:
	return _pv(side, "contest", 0.0)


## Fire them up lifts a side at the contest only while it is chasing the
## game; level or in front it has nothing to answer, so the lift is gone
## while the costs (legs, tempers: PEP_FIRE) stay.
func _contest_pep(side: int) -> float:
	if not _contest_pep_on(side):
		return 0.0
	return fire_up_contest(side)


func _contest_pep_on(side: int) -> bool:
	return _pep(side) == "fire_up" and score(side) < score(1 - side)


## What Fire them up adds at the contest for this side while it chases the
## game: the base lift scaled by its own plan's pep lever (CustomPlan), as the gate shows it.
func fire_up_contest(side: int) -> float:
	return PEP_FIRE_CONTEST * _gt(side, "pep")


## Calm the group: a quarter-long, milder Slow it down (the "hold" call),
## as Fire them up is a milder Throw numbers at it - fewer clangers, less
## pressure felt and legs that last longer, for less ground gained.
const PEP_CALM := {"clangers": 0.92, "taken": 0.95, "gain": 0.92, "pace": 0.95}
## Fire them up's lift at the contest while chasing the game (_contest_pep).
const PEP_FIRE_CONTEST := 0.018
## Fire them up: legs go quicker and tempers fray.
const PEP_FIRE := {"clangers": 1.10, "pace": 1.20}
## Bring the heat (director, 2026-10-10): harder pressure on their ball carriers, so
## more turnovers forced and tackles laid; legs burn out much faster for it.
## Sized 2026-10-11 on 480 paired matches: margin about even (+1.3 ± 1.9),
## the most pressure of the variants tried, legs burning far quicker.
const PEP_HEAT := {"pace": 1.60}
const PEP_HEAT_PRESS := 1.08
## Heat on top of the High Press: the same hunting, so the gains overlap and
## only this share of heat's pressure bonus is added (the legs cost stays in full).
const PEP_HEAT_ON_PRESS := 0.5


## The pep talk's multiplier on one chain quantity (1.0 when it has none).
func _pep_mult(side: int, key: String) -> float:
	if _pep(side) == "calm":
		return float(PEP_CALM.get(key, 1.0))
	if _pep(side) == "fire_up":
		return float(PEP_FIRE.get(key, 1.0))
	if _pep(side) == "heat":
		return float(PEP_HEAT.get(key, 1.0))
	return 1.0


## How much harder a side presses the ball carrier this quarter (Bring the heat).
func _pep_heat(side: int) -> float:
	if _pep(side) != "heat":
		return 1.0
	if _pv(side, "press") > 1.0:
		return 1.0 + (PEP_HEAT_PRESS - 1.0) * PEP_HEAT_ON_PRESS
	return PEP_HEAT_PRESS


func _contest_calls(side: int, stoppage: bool) -> float:
	var b := 0.0
	if _burst(side, "stack") and stoppage:
		b += STACK_CONTEST
	if _burst(side, "surge"):
		b += SURGE_CONTEST
	return b


## Hothead (Traits): he gives away this many times his share of clangers,
## on top of his teammates' (so the side gives away more clangers and free
## kicks, not just him).
const HOTHEAD_ERRORS := 1.5
## The benchmark clanger rate is real 2026 play, which already has its
## hotheads in it: the average 2026 side fields about two, which lifts its
## clangers by this much. The base rate is divided by it, so a disciplined
## side gives away fewer than the benchmark and a side of hotheads more,
## while the league-wide clanger and free-kick rates stay calibrated.
const HOTHEAD_BASE := 1.10
## Roughly one 50m penalty every couple of matches at ordinary discipline.
const FIFTY_BASE := 0.012
## A reportable tackle is rare. Poor discipline and Hothead raise the chance,
## but neither can turn ordinary aggression into a weekly suspension machine.
const REPORT_BASE := 0.0035
## Contextual frees replace part of the old generic clanger/free bucket.
const HIGH_CONTACT_BASE := 0.022
const HTB_NO_PRIOR := 0.10
const HTB_PRIOR := 0.24
const MARK_FREE_BASE := 0.020
const GENERIC_FREE_MULT := 0.40


## Who gives away a side's clanger: poor discipline makes it likelier, a
## Hothead HOTHEAD_ERRORS times likelier again. Returns [weights for the
## on-ground players, the side's Hothead uplift] - the uplift is the
## weights' total over what it would be without Hotheads (1.0 with none).
func _clanger_weights(side: int) -> Array:
	var weights := []
	var w_base := 0.0
	var w_all := 0.0
	for p in (squads[side] as Squad).ground:
		var w := float(pow(maxf(1.0, 101.0 - _a(p, "discipline")), 1.6))
		w_base += w
		if _trait(p, "hothead"):
			w *= HOTHEAD_ERRORS
		if weather == "wet" and _trait(p, "wet_weather"):
			w *= Traits.WET_CLANGERS
		w_all += w
		weights.append(w)
	return [weights, w_all / w_base if w_base > 0.0 else 1.0]


## Pay a football free with a real cause. Returns the mark after any 50.
func _award_context_free(receiving_side: int, mark_fp: float, offender, recipient,
		cause: String, label: String, context := "") -> float:
	_t(receiving_side, "frees_for")
	_p(recipient, "frees_for")
	_t(1 - receiving_side, "frees_against")
	_p(offender, "frees_against")
	_t(receiving_side, "free_" + cause)
	var who := GameDB.player_display_name(recipient) if recipient != null else "the opposition"
	_emit("free", receiving_side, mark_fp, recipient, "%s — free kick to %s" % [label, who])
	_free_taker = {"side": receiving_side, "id": "" if recipient == null else str(recipient.get("id", ""))}
	var ev: Dictionary = events[events.size() - 1]
	ev["free_cause"] = cause
	if context != "":
		ev["free_context"] = context
	ev["against_id"] = "" if offender == null else str(offender.get("id", ""))
	ev["against_name"] = "" if offender == null else GameDB.player_display_name(offender)
	return _maybe_fifty(receiving_side, mark_fp, offender, recipient)


## A tackle infringement against the tackler: high contact/rough conduct.
func _high_contact_free(tackler) -> bool:
	if tackler == null:
		return false
	var discipline := _a(tackler, "discipline")
	var p := HIGH_CONTACT_BASE * (1.35 - 0.70 * discipline / 100.0)
	if _trait(tackler, "hothead"):
		p *= 1.45
	var era := _era("free_rate")
	return free_rng.randf() < clampf(p * era, 0.006, 0.045 * era)


## Holding the ball only exists after a legal tackle actually stops the carrier.
## More prior opportunity (later in the chain) makes it more likely; clean
## contested/disposal players are a little harder to catch.
func _holding_ball_free(carrier, touches: int) -> bool:
	if carrier == null:
		return false
	var p := HTB_PRIOR if touches > 1 else HTB_NO_PRIOR
	p *= 1.18 - 0.30 * _a(carrier, "contested") / 100.0
	p *= 1.12 - 0.24 * _a(carrier, "disposal") / 100.0
	var era := _era("free_rate")
	return free_rng.randf() < clampf(p * era, 0.05, 0.28 * era)


## A genuine aerial contest can be infringed by either side. Poor discipline
## shifts who is more likely to hold/block; it never overwhelms the contest.
func _marking_free(side: int, attacker, defender) -> Dictionary:
	if attacker == null or defender == null:
		return {}
	var def_p := MARK_FREE_BASE * (1.35 - 0.65 * _a(defender, "discipline") / 100.0)
	var att_p := MARK_FREE_BASE * 0.70 * (1.35 - 0.65 * _a(attacker, "discipline") / 100.0)
	if _trait(defender, "hothead"):
		def_p *= 1.35
	if _trait(attacker, "hothead"):
		att_p *= 1.35
	var era := _era("free_rate")
	def_p *= era
	att_p *= era
	var r := free_rng.randf()
	if r < clampf(def_p, 0.004, 0.035 * era):
		return {"side": side, "offender": defender, "recipient": attacker,
				"cause": "marking", "label": "Holding in the marking contest"}
	if r < clampf(def_p, 0.004, 0.035 * era) + clampf(att_p, 0.003, 0.025 * era):
		return {"side": 1 - side, "offender": attacker, "recipient": defender,
				"cause": "marking", "label": "Blocking in the marking contest"}
	return {}


## The free that ends a chain on a clanger used to be one generic "General
## infringement". Its rate is unchanged; what it was for now follows where the
## chain was (ARD-M3-007, docs/FREE_KICKS_2026-10-06.md):
##  - a chain that began at a ball-up: often the ruck contest itself - one ruck
##    held or blocked the other, paid at the stoppage, ruck to ruck;
##  - the ball in the receiving side's forward 50: often a forward held or
##    blocked in a marking contest by one of `side`'s defenders;
##  - otherwise the player who erred dropped or threw it: incorrect disposal.
## New picks draw only from free_rng, so the play dice are as they were.
## {"cause", "label", "offender", "recipient", "fp", "context"}.
const RUCK_FREE_SHARE := 0.90     # of the frees in a chain that began at a ball-up
## A ruck free is paid where the ruckmen contested, so only when the chain
## ended near it: the ball is not brought back up the ground for it.
const RUCK_FREE_REACH := 15.0
const F50_MARK_FREE_SHARE := 0.85 # of the frees in the receiving side's forward 50


func _chain_free_cause(side: int, err, recipient, start_fp: float, end_fp: float) -> Dictionary:
	var opp := 1 - side
	if (chain_origin == "centre" or chain_origin == "stoppage") \
			and absf(end_fp - start_fp) <= RUCK_FREE_REACH:
		var mine := _contestant(squads[side])
		var theirs := _contestant(squads[opp])
		if not mine.is_empty() and not theirs.is_empty() and _is_ruckman(mine[0]) \
				and _is_ruckman(theirs[0]) and free_rng.randf() < RUCK_FREE_SHARE:
			var held := free_rng.randf() < 0.5
			return {"cause": "ruck_contest", "label": "Holding in the ruck" if held else "Blocking in the ruck",
					"offender": mine[0], "recipient": theirs[0], "fp": start_fp, "context": "ruck"}
	var f50 := float(Ratings.T["forward50_line"])
	var in_their_f50 := end_fp > f50 if opp == 0 else end_fp < -f50
	if in_their_f50 and free_rng.randf() < F50_MARK_FREE_SHARE:
		var dfd = _free_pick(squads[side].ground, "DEF", "discipline", true)
		var fwd = _free_pick(squads[opp].ground, "FWD", "marking", false)
		if dfd != null and fwd != null:
			return {"cause": "marking", "label": "Holding in the marking contest",
					"offender": dfd, "recipient": fwd, "fp": end_fp, "context": "forward50"}
	return {"cause": "incorrect_disposal", "label": "Incorrect disposal",
			"offender": err, "recipient": recipient, "fp": end_fp, "context": "error"}


## One of a side's on-ground players in `role`, weighted on `key` (low values
## weigh more when `low`), drawn from free_rng. null with nobody in the role.
func _free_pick(ground: Array, role: String, key: String, low: bool):
	var group := []
	var weights := []
	var total := 0.0
	for p in ground:
		if str(p.get("role", "")) != role:
			continue
		var v := _a(p, key)
		var w := maxf(1.0, (101.0 - v) if low else v)
		group.append(p)
		weights.append(w)
		total += w
	if group.is_empty():
		return null
	var r := free_rng.randf() * total
	for i in range(group.size()):
		r -= float(weights[i])
		if r <= 0.0:
			return group[i]
	return group[group.size() - 1]


## A free can be marched 50 for dissent, encroachment or delay. We do not
## pretend to simulate umpire micromanagement: discipline and Hothead only
## alter a small post-free risk. Returns the new mark for the free.
static func fifty_mark(receiving_side: int, mark_fp: float, goal_line: float) -> float:
	var dir := 1.0 if receiving_side == 0 else -1.0
	return clampf(mark_fp + 50.0 * dir, -goal_line, goal_line)


func _maybe_fifty(receiving_side: int, mark_fp: float, offender, recipient) -> float:
	if offender == null:
		return mark_fp
	var discipline := _a(offender, "discipline")
	var chance := FIFTY_BASE * (1.35 - 0.70 * discipline / 100.0) * _ar(1 - receiving_side, "fifty")
	if _trait(offender, "hothead"):
		chance *= 1.65
	if discipline_rng.randf() >= clampf(chance, 0.002, 0.035):
		return mark_fp
	var new_fp := fifty_mark(receiving_side, mark_fp, float(Ratings.T["goal_line"]))
	_t(receiving_side, "fifties_for")
	_t(1 - receiving_side, "fifties_against")
	_p(offender, "fifties_against")
	_emit("fifty", receiving_side, new_fp, recipient,
			"50-metre penalty against %s" % GameDB.player_display_name(offender))
	var ev: Dictionary = events[events.size() - 1]
	ev["from_fp"] = mark_fp
	ev["against_id"] = str(offender.get("id", ""))
	ev["against_name"] = GameDB.player_display_name(offender)
	return new_fp


## A tackle can become a reportable rough-conduct incident. It is attached to
## the real tackler/victim and current quarter/minute; no post-match re-roll.
func _maybe_report(side: int, offender, victim) -> void:
	if offender == null or victim == null:
		return
	var discipline := _a(offender, "discipline")
	var chance := REPORT_BASE * (1.30 - 0.60 * discipline / 100.0) * _ar(side, "fifty")
	if _trait(offender, "hothead"):
		chance *= 1.75
	if mro_rng.randf() >= clampf(chance, 0.001, 0.014):
		return
	var severity := mro_rng.randf() + (50.0 - discipline) / 500.0 \
			+ (0.06 if _trait(offender, "hothead") else 0.0)
	var tribunal_roll := mro_rng.randf()
	var appeal_roll := mro_rng.randf()
	var outcome := "no_action"
	var weeks := 0
	if severity >= 0.985:
		outcome = "suspension"
		weeks = 3
	elif severity >= 0.94:
		outcome = "suspension"
		weeks = 2
	elif severity >= 0.76:
		outcome = "suspension"
		weeks = 1
	elif severity >= 0.52:
		outcome = "fine"
	reports.append({
		"side": side,
		"id": str(offender.get("id", "")),
		"name": GameDB.player_display_name(offender),
		"victim_id": str(victim.get("id", "")),
		"victim_name": GameDB.player_display_name(victim),
		"q": current_quarter,
		"min": current_minute,
		"reason": "rough conduct",
		"outcome": outcome,
		"weeks": weeks,
		"tribunal_roll": tribunal_roll,
		"appeal_roll": appeal_roll,
		"challenged": false,
		"appealed": false,
	})


# ---------------------------------------------------------------------------
# What the coach's structural calls were worth (the full-time summary)
# ---------------------------------------------------------------------------
## A general-play marking contest (_general_aerial_contest) with the loose man
## able to fly in: his worth to his side is the marks he would deny and the
## balls he would spoil, on the chance he gets there, each about a turnover.
## A forward sent to him (the defensive forward) is worth the share of that
## he takes away. Expected, never rolled.
func _credit_general_loose(side: int, target: Dictionary, defender: Dictionary, roamer: Dictionary) -> void:
	var opp := 1 - side
	var mark0 := _general_mark_chance(target, defender, 0.0)
	var mark_r := _general_mark_chance(target, defender, _roam_mark_shift(roamer))
	var spoil_p := _general_spoil_chance(target, defender)
	var denied := (mark0 - mark_r) + (1.0 - mark_r) * (1.0 - spoil_p) * _roam_spoil_p(roamer)
	var p_r := _roam_chance(opp)
	_credit(opp, "loose", p_r * denied * TURNOVER_VALUE, str(roamer.get("id", "")))
	var minder := _spare_minder(side)
	if not minder.is_empty():
		_credit(side, "minder", (_roam_chance(opp, false) - p_r) * denied * TURNOVER_VALUE, str(minder.get("id", "")))


## A general-play aerial contest (_general_aerial): the loose man reads it
## better (LOOSE_READ), so he is the one who meets it more often. Worth the
## change in the defending side's chance of coming away with the ball (an
## intercept mark, or half the spills), as at a stoppage.
func _credit_aerial_loose(def_side: int, fp: float, receiver: Dictionary) -> void:
	var loose := str(interceptor[def_side])
	var zone := _aerial_zone(def_side, fp)
	if loose == "" or zone == "forward":
		return
	var roles: Dictionary = AERIAL_ROLES[zone]
	var receive := _a(receiver, "marking")
	var w_sum := 0.0
	var wl_sum := 0.0
	var e := 0.0
	var el := 0.0
	var found := false
	for p in (squads[def_side] as Squad).ground:
		var w := float(roles.get(str(p["role"]), 0.0)) * pow(maxf(1.0, _a(p, "intercept")), AERIAL_READ)
		var wl := w
		if str(p["id"]) == loose:
			wl *= 1.0 + LOOSE_READ * _a(p, "intercept") / 100.0
			found = true
		var stop := 0.62 * _a(p, "intercept") + 0.38 * _a(p, "marking")
		var mp := clampf(0.34 + (receive - stop) / 240.0
				+ (0.05 if _trait(receiver, "aerial") else 0.0), 0.16, 0.55) * _wx("aerial")
		var sp := clampf(0.36 + (stop - receive) / 220.0
				+ (0.07 if _trait(p, "interceptor") else 0.0), 0.20, 0.65)
		var ip := sp * INTERCEPT_MARK * (0.6 + 0.8 * _a(p, "intercept") / 100.0) * _wx("aerial") * _gt(1 - def_side, "icept")
		var ours := ip + 0.5 * (1.0 - mp - ip)
		w_sum += w
		wl_sum += wl
		e += w * ours
		el += wl * ours
	if found and w_sum > 0.0 and wl_sum > 0.0:
		_credit(def_side, "loose", (el / wl_sum - e / w_sum) * POSSESSION_VALUE, loose)


## An inside-50 entry, before it is played: what the defending coach's loose
## man and his own match-up on this forward, and the attacking coach's
## defensive forward, are each worth in expected points against not having
## made that call. Same rules as the contest in resolve_forward50; the draws
## themselves are untouched. minder_dp: how much more often the defensive
## forward would be the target without the call (_minder_pick_shift).
func _credit_entry(side: int, shooter: Dictionary, feeder, defender, line_def, matched: Dictionary,
		roamer: Dictionary, minder_dp := 0.0) -> void:
	var opp := 1 - side
	var roams := not roamer.is_empty() and str(roamer.get("id", "")) != str(defender.get("id", ""))
	var p_r := _roam_chance(opp) if roams else 0.0
	var p_go := _roam_go_chance(opp) if roams else 0.0
	var actual := _entry_ev(side, shooter, feeder, defender, matched, roamer, p_r, p_go)
	if roams:
		# Without the call: no third man, and the forward he left back with him.
		var lw: Dictionary = _loose_was[opp]
		var bare := 0.0
		if str(lw.get("id", "")) == str(roamer.get("id", "")) and str(lw.get("fwd", "")) == str(shooter.get("id", "")):
			bare = _entry_ev(side, shooter, feeder, roamer, roamer, roamer, 0.0, 0.0)
		else:
			bare = _entry_ev(side, shooter, feeder, defender, matched, roamer, 0.0, 0.0)
		_credit(opp, "loose", bare - actual, str(roamer.get("id", "")))
	var minder := _spare_minder(side)
	if not minder.is_empty():
		# The defensive forward: the entry as played against the same entry
		# without the call. Their loose man is free to roam...
		var unminded := actual
		if roams:
			unminded = _entry_ev(side, shooter, feeder, defender, matched, roamer,
					_roam_chance(opp, false), _roam_go_chance(opp, false))
		var worth := actual - unminded
		# ...and the defensive forward is the target on minder_dp more of the
		# entries, at the others' expense: his entry against theirs (theirs is
		# this entry's, or their average so far when the entry is his).
		var mid := str(minder.get("id", ""))
		var others: Array = _minder_others[side]
		var their_ev := unminded
		if str(shooter.get("id", "")) == mid:
			their_ev = float(others[0]) / float(others[1]) if int(others[1]) > 0 else NAN
		else:
			others[0] = float(others[0]) + unminded
			others[1] = int(others[1]) + 1
		if minder_dp > 0.0 and not is_nan(their_ev):
			var m_def := _on_ground(opp, str((duels[opp] as Dictionary).get(mid, "")))
			var m_roams := not roamer.is_empty() and str(roamer.get("id", "")) != str((m_def if not m_def.is_empty() else line_def).get("id", ""))
			var his := _entry_ev(side, minder, feeder, m_def if not m_def.is_empty() else line_def, m_def, roamer,
					_roam_chance(opp, false) if m_roams else 0.0, _roam_go_chance(opp, false) if m_roams else 0.0)
			worth -= minder_dp * (his - their_ev)
		_credit(side, "minder", worth, mid)


## How much more often the defensive forward would be the target of an entry
## without the call (resolve_forward50's pick: the weighted roles, or a key
## target on key_target() of entries): a full target with no MINDER_INVOLVE
## and, with a match-up, one of the key targets again. 0.0 with no call. Pure.
## Running sum and count of the other forwards' entries without the call, by
## side (the defensive forward's cost is his entry against theirs).
var _minder_others := [[0.0, 0], [0.0, 0]]


func _minder_pick_shift(side: int, keys: Array, T: Dictionary) -> float:
	var minder := _spare_minder(side)
	if minder.is_empty():
		return 0.0
	var mid := str(minder.get("id", ""))
	var ctx := _pick_ctx(side)
	var w_sum := 0.0
	var w_min := 0.0
	for p in (squads[side] as Squad).ground:
		var w: float = float(SHOT_ROLES.get(str(p["role"]), 0.0)) * pow(maxf(1.0, _a(p, "goalkicking")), float(T["shooter_power"]))
		if str(p["role"]) == "FWD":
			w *= float(TARGET_SIZES.get(fwd_size(p), 1.0))
		w *= _tactic_player_mult(side, p, "shooter", ctx)
		w_sum += w
		if str(p["id"]) == mid:
			w_min = w
	if w_sum <= 0.0:
		return 0.0
	var w_off := w_min / MINDER_INVOLVE
	var keys_off := keys.duplicate()
	if (duels[1 - side] as Dictionary).has(mid):
		keys_off.append(minder)
	var p_on := _shot_pick_p(w_min / w_sum, keys, mid)
	var p_off := _shot_pick_p(w_off / (w_sum - w_min + w_off), keys_off, mid)
	return maxf(0.0, p_off - p_on)


func _shot_pick_p(p_weighted: float, keys: Array, sid: String) -> float:
	if keys.is_empty():
		return p_weighted
	var ks := keys.duplicate()
	ks.sort_custom(func(a, b): return Matchups.forward_air(a) > Matchups.forward_air(b))
	var k := 0.0
	if str(ks[0].get("id", "")) == sid:
		k = 1.0 if ks.size() == 1 else 0.6
	elif ks.size() > 1 and str(ks[1].get("id", "")) == sid:
		k = 0.4
	return (1.0 - key_target()) * p_weighted + key_target() * k


## Expected points of an inside-50 entry (6 a goal, 1 a behind) with
## `matched` his direct opponent ({} for none) and the loose man arriving in
## time with chance p_roam, leaving his post at all with p_go (late between).
func _entry_ev(side: int, shooter: Dictionary, feeder, defender, matched: Dictionary,
		roamer: Dictionary, p_roam: float, p_go: float) -> float:
	var T := _rates()
	var atk: Squad = squads[side]
	var dfn: Squad = squads[1 - side]
	var dfd = defender
	var duel_shift := 0.0
	if not matched.is_empty():
		dfd = matched
		duel_shift = Matchups.mark_shift(shooter, matched)
	var mark_cap := 0.78 if matched.is_empty() else Matchups.DUEL_CAP
	var base_m := 0.5 + (atk.fwd_mark - dfn.def_intercept) / 240.0 			+ (0.06 if _trait(shooter, "aerial") else 0.0) + duel_shift
	if matched.is_empty():
		base_m += (Matchups.forward_air(shooter) - FWD_AIR_CENTRE) / FWD_AIR_SCALE
	var spoil_read := dfn.def_intercept
	if not matched.is_empty():
		spoil_read = 0.5 * dfn.def_intercept + 0.5 * Matchups.defender_air(matched)
	var p_sp := clampf(0.30 + 0.35 * spoil_read / 100.0
			+ (0.05 if dfd != null and _trait(dfd, "interceptor") else 0.0) - duel_shift, 0.05, 0.95)
	var beaten := Matchups.BEATEN_SHOT if not matched.is_empty() else 1.0
	var g_m := shot_chance(side, shooter, true, false, false, feeder, dfd)
	var g_s := shot_chance(side, shooter, false, true, false, feeder, dfd)
	var g_c := shot_chance(side, shooter, false, false, false, feeder, dfd)
	var b0 := float(T["inside50_behind"]) * (0.80 + 0.40 * _a(shooter, "goalkicking") / 100.0)
	var p_m0 := clampf(base_m, 0.10, mark_cap)
	# Off the deck: a crumb after a spoil, and (unmatched) the spill to a
	# ground-ball forward when nobody touched it.
	var deck := _deck_ev(side)
	var spill := 0.0
	if matched.is_empty():
		spill = float(SPILL_P.get(fwd_size(shooter) if str(shooter.get("role", "")) == "FWD" else "general", 0.30))
	var ev := (1.0 - p_go) * _entry_mode_ev(p_m0, p_sp, 0.0, 1.0, 1.0, 1.0, g_m, g_s, g_c, b0, beaten,
			deck, spill)
	if p_go > 0.0 and not roamer.is_empty():
		var gap := 1.0 - _loose_read(roamer)
		var p_mr := clampf(base_m + _roam_mark_shift(roamer), 0.10, mark_cap)
		ev += p_roam * _entry_mode_ev(p_mr, p_sp, _roam_spoil_p(roamer), 1.0 + 0.15 * gap,
				1.0 + 0.08 * gap, 1.0 + 0.05 * gap, g_m, g_s, g_c, b0, beaten, deck, spill)
		ev += maxf(0.0, p_go - p_roam) * _entry_mode_ev(p_m0, p_sp, 0.0,
				1.0 + float(LOOSE_LATE_SPACE["marked"]) * gap, 1.0 + float(LOOSE_LATE_SPACE["unmarked"]) * gap,
				1.0 + 0.05 * gap, g_m, g_s, g_c, b0, beaten, deck, spill)
	return ev


## One way the entry plays out: marked with p_m; otherwise spoilt by the man
## in the contest (p_sp) or the extra body (p_extra); space left behind
## (sp_m, sp_u, sp_b) counts only when nobody got a fist to it. Off a spoil
## that does not score, a crumb (deck[0] points); untouched and unmatched,
## the ball spills to a ground-ball forward on `spill` of them (deck[1],
## deck[2]: his goal and behind chances times his chance of winning it).
func _entry_mode_ev(p_m: float, p_sp: float, p_extra: float, sp_m: float, sp_u: float, sp_b: float,
		g_m: float, g_s: float, g_c: float, b0: float, beaten: float, deck: Array = [0.0, 0.0, 0.0],
		spill := 0.0) -> float:
	var clean := 1.0 - p_sp
	var marked := 6.0 * g_m * (p_sp + clean * sp_m) + b0 * (p_sp + clean * sp_b)
	var p_spt := p_sp + clean * p_extra
	var gs := beaten * g_s
	var bs := beaten * b0
	var spoil_v := 6.0 * gs + bs + maxf(0.0, 1.0 - gs - bs) * float(deck[0])
	var kept := beaten * (6.0 * g_c * sp_u + b0 * sp_b)
	var ground := 6.0 * float(deck[1]) * sp_u + float(deck[2]) * sp_b
	var clean_v := (1.0 - spill) * kept + spill * ground
	return p_m * marked + (1.0 - p_m) * (p_spt * spoil_v + (1.0 - p_spt) * clean_v)


## What the ball on the deck inside 50 is worth to `side` (_crumb, and the
## spill in resolve_forward50), over the forwards who get to it as
## _ground_forward picks them: [crumb points off a spoil, goal and behind
## chances of the spill times his chance of winning it]. Kept for the
## quarter (the forwards on the ground move little within one). Pure.
var _deck_memo := [{}, {}]


func _deck_ev(side: int) -> Array:
	var memo: Dictionary = _deck_memo[side]
	var key := "%d|%s" % [current_quarter, str(tactics[side].get("spare_accountable", false))]
	if str(memo.get("key", "")) == key:
		return memo["v"]
	var T := _rates()
	var ctx := _pick_ctx(side)
	ctx["zone"] = ""
	var w_sum := 0.0
	var crumb := 0.0
	var gg := 0.0
	var gb := 0.0
	for p in (squads[side] as Squad).ground:
		var w: float = float(CRUMB_ROLES.get(str(p["role"]), 0.0)) * pow(maxf(1.0, _a(p, "pressure")), 2.0)
		if str(p["role"]) == "FWD":
			w *= float(GROUND_SIZES.get(fwd_size(p), 1.0))
		w *= _tactic_player_mult(side, p, "crumb", ctx)
		if w <= 0.0:
			continue
		var g := shot_chance(side, p, false, false)
		var b := float(T["inside50_behind"]) * (0.80 + 0.40 * _a(p, "goalkicking") / 100.0)
		var c := CRUMB_P * (0.7 + 0.6 * _a(p, "pressure") / 100.0)
		var size: String = fwd_size(p) if str(p.get("role", "")) == "FWD" else "general"
		var win := float(GROUND_WIN[size]) * (0.85 + 0.30 * _a(p, "pressure") / 100.0)
		w_sum += w
		crumb += w * c * (6.0 * g * CRUMB_SNAP + b)
		gg += w * win * g
		gb += w * win * b
	var v := [0.0, 0.0, 0.0] if w_sum <= 0.0 else [crumb / w_sum, gg / w_sum, gb / w_sum]
	_deck_memo[side] = {"key": key, "v": v}
	return v


## A won stoppage is worth about a possession chain's points.
const POSSESSION_VALUE := 1.0
const TURNOVER_VALUE := 0.5
const CLANGER_VALUE := 0.6


func _credit_contest(side: int, stoppage: bool) -> void:
	_credit(side, "gameplan", _contest_plan(side) * POSSESSION_VALUE)
	# The call itself gets its base lift and its own plan's pep lever (booked to the game plan) gets what it
	# added to (or took from) that lift, so the two add up to what the contest got.
	var pep_base := PEP_FIRE_CONTEST if _contest_pep_on(side) else 0.0
	_credit(side, "pep", pep_base * POSSESSION_VALUE)
	_credit(side, "bursts", _contest_calls(side, stoppage) * POSSESSION_VALUE)
	_credit(side, "traits", _contest_traits(side) * POSSESSION_VALUE)
	_credit(side, "gameplan", (_contest_own_plan(side, stoppage)
			+ pep_base * (_gt(side, "pep") - 1.0)) * POSSESSION_VALUE)


func _credit(side: int, cause: String, pts: float, who := "") -> void:
	if pts == 0.0:
		return
	var d: Dictionary = impact[side]
	d[cause] = float(d.get(cause, 0.0)) + pts
	if who != "":
		var by: Dictionary = (impact_by[side] as Dictionary).get_or_add(cause, {})
		by[who] = float(by.get(who, 0.0)) + pts


## Pressure by zone. Where the ball is, from the carrier's end: his back
## third (their forwards press), the middle (their midfield), his forward
## third (their defenders). 2026-11-09: forwards up the ground from the middle,
## midfielders less, on real tackles by line. Each role's share of the pressing there; a
## player's chance to be the one applying it is this times Pressure squared.
const PRESS_ZONES := [
	{"FWD": 1.0, "MID": 0.55, "RUCK": 0.30, "DEF": 0.08},
	{"FWD": 0.70, "MID": 0.80, "RUCK": 0.60, "DEF": 0.25},
	{"FWD": 0.22, "MID": 0.60, "RUCK": 0.30, "DEF": 0.85},
]
const PRESS_ZONE_EDGE := 20.0
## The High Press by zone, from the carrier's end (PRESS_ZONES order):
## the pressure he meets. Their back third is where we push up and hunt; in
## their forward third our numbers are up the ground, so our own defence
## presses less. About the same pressure overall, moved up the ground.
const PRESS_PLAN_ZONE := [1.40, 1.10, 0.60]
## In their back third a rushed disposal is closed down by two or three at
## once, so it turns over this many times as often against a press.
const PRESS_ZONE_TURNOVER := 1.5
## Out of the back third with nobody on him, a side has broken the press:
## the rest of that chain runs at a defence that is outnumbered, and its
## shot is this much likelier to be a goal. The cost of the plan.
const PRESS_BROKEN_EXPOSED := 1.7
## Non-tackle pressure acts per tackle chance, the share of those that turn
## the ball over outright, and the ground a rushed disposal still gains.
## 2026-11-09: a player's pressure acts ran at 60% of real (median 6.5 a game,
## real 11), so there are more of them, each costing the carrier less
## (PRESS_TURNOVER_FLOW, PRESS_RUSH_GAIN): turnovers and scoring hold.
const PRESS_RUSH_RATIO := 3.3
## The share of a pressure chance that is a tackle; the rest of it is a
## rushed disposal instead (pressure acts unchanged). Calibrated to AFL
## tackle counts (2026-10-06: tackles ran about 6% above).
const PRESS_TACKLE_SHARE := 0.97
## A rusher forces turnovers at this rate (match flow), because a share of them
## lock up into ball-ups and a tackle can spill the ball.
const PRESS_TURNOVER_FLOW := 0.175
## Match flow (director 2026-10-10, MATCH_SHAPE_AUDIT_2026-10-10.md): a ball-up
## comes from a contest that locks up, not from a won ball. Of the turnovers a
## presser forces, the share that lock up instead; of the spoils inside 50 the
## defence would rebound, the share that lock up in the pocket.
const LOCKUP_PRESS := 0.35
const LOCKUP_SPOIL := 0.35
## Of the tackles that stop a carrier without a free, the share where the ball is
## knocked free and the other side gathers it (a turnover); the rest are ball-ups.
const TACKLE_SPILL := 0.5
## Getting it out of defence (director 2026-11-07, "Play change": defenders
## get the ball out of their 50 more often). Inside his own defensive 50 a
## defender clears it rather than chipping it around: his kick goes this much
## further (still within his kick range), he handballs this much less, the
## forwards get to him this much less often, and a rushed disposal there
## turns over this much as often. Breaking a tackle is not how the ball gets
## out: about 2 exits in 100 come through one (kicks 77%, handballs 21%), so
## a tackle inside 50 gets no special treatment (director 2026-11-08). Measured
## on tools/balance.sh match 1000: team rebound 50s 26.8 -> 37.2 (real 39.3,
## clubs 37.0-41.9), with every other team rate inside the clubs' range once
## marks per kick, one-percenters and goals per entry were recalibrated
## (Ratings, 2026-11-07). Rebound 50s keep the Champion Data definition
## (_rebound_exit).
const D50_KICK_GAIN := 3.0
const D50_HANDBALL := 0.7
const D50_PRESSURE := 0.50
const D50_TURNOVER := 0.15


## A named constant, or its audit override (tune).
static func _tv(key: String, value: float) -> float:
	return float(tune.get(key, value))
const PRESS_RUSH_GAIN := 0.96
## A close defender occasionally gets boot to ball. Around one or two per
## match across both sides; pressure and the smotherer's ability move it.
const SMOTHER_BASE := 0.008
const SMOTHER_CAP := 0.022
## A subset of genuine 15m+ kicks outside forward 50 become aerial contests.
## 2026-11-09: more of them, spoiled more and marked less (spoils between the
## arcs ran far under real, contested marks over).
## Most ordinary kicks still use the calibrated chain model unchanged.
const GENERAL_AERIAL_P := 0.15
const GENERAL_SPOIL_BASE := 0.82
## A general-play marking contest's mark chance, level players.
const GENERAL_MARK_P := 0.18
## Clamp bounds, kept well clear of the bases (2026-11-10: the bases had come
## to sit on a bound and the players' edge did nothing on that side).
const GENERAL_MARK_MIN := 0.05
const GENERAL_MARK_MAX := 0.70
const GENERAL_SPOIL_MIN := 0.30
const GENERAL_SPOIL_MAX := 0.95
const GENERAL_MARK_ROLES := {"FWD": 1.0, "MID": 0.85, "DEF": 0.65, "RUCK": 0.70}


## Where a pressure act happened, from the presser's end, for the balance
## harness (Champion Data's PressureActsDefensiveHalf and TacklesInside50):
## in his defensive half (the carrier going forward, atk_fp > 0) and a tackle
## inside his forward 50 (the carrier in his own defensive 50). Bookkeeping
## only: no dice.
func _press_where(presser_side: int, atk_fp: float, in_d50: bool, tackle: bool) -> void:
	if atk_fp > 0.0:
		_t(presser_side, "pressure_acts_dhalf")
	if tackle and in_d50:
		_t(presser_side, "tackles_i50")


static func _press_zone(atk_fp: float) -> int:
	if atk_fp < -PRESS_ZONE_EDGE:
		return 0
	if atk_fp > PRESS_ZONE_EDGE:
		return 2
	return 1


## How hard `side` presses in `zone`: its on-ground players' Pressure as
## they are playing now, weighted by who is in that zone.
func _zone_pressure(side: int, zone: int) -> float:
	var w: Dictionary = PRESS_ZONES[zone]
	var total := 0.0
	var weight := 0.0
	for p in (squads[side] as Squad).ground:
		var rw := float(w.get(str(p["role"]), 0.0))
		total += rw * _a(p, "pressure")
		weight += rw
	return total / weight if weight > 0.0 else 45.0


## Who applies the pressure: zone opportunity x Pressure to this power, so the
## best pressers do more of it without doing all of it. Of 2, 1.75, 1.5 and
## 1.25, 1.5 puts the most tackle rows IN of real AFL (the spread of tackles a
## game among each line's players, 2025-26, 12+ games, and each side's top
## tackler a match, 2023-25), with team tackles unchanged:
## tools/balance.sh match, "Tackles and pressure acts per player".
const PRESS_PICK_POW := 1.5


func _pick_presser(side: int, zone: int):
	var w: Dictionary = PRESS_ZONES[zone]
	var group: Array = (squads[side] as Squad).ground
	var weights := []
	var ctx := _pick_ctx(side)
	var pw := _tv("PRESS_PICK_POW", PRESS_PICK_POW)
	for p in group:
		weights.append(float(w.get(str(p["role"]), 0.0))
				* pow(maxf(1.0, _a(p, "pressure")), pw)
				* _tactic_player_mult(side, p, "tackler", ctx))
	return _pick(group, weights)


## Who contests a long kick in general play, by where it lands, from the
## defending side's view (ARD-M4-012, the director: "any player can intercept,
## but the loose defender should get more intercepts if he's good at it").
## Champion Data 2025: defenders win about 57% of intercepts, midfielders 23%,
## forwards 15% and rucks 4% (docs/research/INTERCEPT_EVIDENCE.md).
const AERIAL_ROLES := {
	"back": {"DEF": 1.0, "MID": 0.45, "RUCK": 0.3, "FWD": 0.05},
	"middle": {"MID": 1.0, "DEF": 0.6, "RUCK": 0.5, "FWD": 0.35},
	"forward": {"FWD": 1.0, "MID": 0.75, "RUCK": 0.3, "DEF": 0.1},
}
## The named loose defender reads it better in his own half and the middle:
## his weight grows with his intercept rating, up to double.
const LOOSE_READ := 0.2
## The power on intercept when picking who contests a general-play ball
## (AERIAL_ROLES): above 1 the best reader on the ground takes more than his
## share. Champion Data 2025: the best take about 8 a game, a side about 63.
const AERIAL_READ := 1.0
## The director (2026-10-06): the best loose defenders sit near the real best,
## about 8 intercepts a game (Champion Data 2025: Sam Taylor 8.4), not 12.
## Scales how often he reaches an entry's contest.
const ROAM_REACH := 0.7
## The spare as an extra body: his chance, for a league-average aerial
## defender (70), of getting a fist to a ball the man in the contest missed.
const LOOSE_EXTRA := 0.6
## The loose defender's read of the ball (interceptor score) from which he
## starts to matter, and the span over which he reaches full value.
const LOOSE_READ_FLOOR := 52.0
const LOOSE_READ_SPAN := 26.0
## His chance of reaching an entry's contest: a poor reader's, plus the range
## a top one adds.
const LOOSE_REACH_MIN := 0.06
const LOOSE_REACH_RANGE := 0.7
## How often he leaves his post for an entry: as often as a top reader gets
## there, so a poor reader goes just as often and arrives late instead.
const LOOSE_GO := LOOSE_REACH_MIN + LOOSE_REACH_RANGE
## The least read of the ball (_loose_read) for which a coach plays a man
## loose: the AI, your assistant and the pre-match facts all use it
## (Matchups.best_interceptor). Below it the call stops paying: with the
## best defender's read pinned, points conceded against no loose man were
## +0.6 at 0.18, 0.29 and 0.41 and -1.9 at 0.52, -2.6 at 0.63 (960 pairs
## each, audit runs 38076174976, 38076182331, 38076189216, 38076195850,
## 38076202407). 14/26 (about 0.54) is exactly the old bar, interceptor score 66.
const LOOSE_AI_MIN_READ := 14.0 / 26.0
## How much more dangerous the entry is when he went and got there late, for
## the poorest reader: {unmarked, marked}. He isn't there at all, so the space
## behind him is bigger than when he flies and loses (0.08 / 0.15).
const LOOSE_LATE_SPACE := {"unmarked": 0.12, "marked": 0.20}
## The most he makes the mark harder, for a top reader.
const LOOSE_MARK_EDGE := 0.5
## The share of his spoil a poor reader still gets.
const LOOSE_SPOIL_FLOOR := 0.25
## The power on intercept when picking the defender who meets an entry (main: 2).
const ENTRY_READ := 0.5
## Of the contests the defender wins, the share he marks (an intercept
## mark, the ball turned over) rather than spoils; a better reader marks more.
const INTERCEPT_MARK := 0.35
## How often a long kick in general play is a real contest (main: 0.22).
const AERIAL_CHANCE := 0.22
## Audits only: false plays the old contest (defenders and midfielders, no
## intercept marks) for a before/after on the same seeds.
static var zone_intercepts := true
## Audit only (intercept_impl): chain starts by origin, the previous chain's end
## and whether the ball changed sides. Off unless an audit turns it on.
## Audit only: tuning values to try without a commit, e.g. {"chains_per_game": 240,
## "LOCKUP_PRESS": 0.6}. Ratings.T keys apply through _rates(); named MatchSim
## constants through _tv(). Empty in play and in every test.
static var tune := {}
static var audit_chains_on := false
static var audit_chains := {}
var _audit_last_side := -1


## Where a contest at `fp` is, from `def_side`'s view: its back half, the
## middle, or its forward half (the other side's back half).
func _aerial_zone(def_side: int, fp: float) -> String:
	var x := fp if def_side == 0 else -fp
	if x < -35.0:
		return "back"
	return "middle" if x <= 35.0 else "forward"


## The defending player in a general-play aerial contest at `fp`.
func _aerial_defender(def_side: int, fp: float):
	var zone := _aerial_zone(def_side, fp)
	var roles: Dictionary = AERIAL_ROLES[zone]
	var group: Array = (squads[def_side] as Squad).ground
	var loose := str(interceptor[def_side])
	var weights := []
	for p in group:
		var w := float(roles.get(str(p["role"]), 0.0)) * pow(maxf(1.0, _a(p, "intercept")), AERIAL_READ)
		if loose != "" and str(p["id"]) == loose and zone != "forward":
			w *= 1.0 + LOOSE_READ * _a(p, "intercept") / 100.0
		weights.append(w)
	return _pick(group, weights) if not group.is_empty() else null


## Key forward v key defender up the ground (row 94, T8.Q6, director
## 2026-11-06). A real match-up goes
## where the forward goes: when a general-play marking contest falls to a key
## forward, his direct opponent is the man in it, so the full-time duel line
## counts every contest the two of them had, not only the entries inside 50.


## The direct opponent on the ground for `fwd` (of `side`) in a general-play
## contest; {} with no match-up or his man off the ground.
func _duel_man(side: int, fwd) -> Dictionary:
	if fwd == null:
		return {}
	var did := str((duels[1 - side] as Dictionary).get(str(fwd.get("id", "")), ""))
	return {} if did == "" else _on_ground(1 - side, did)


## One general-play contest between a key forward and his direct opponent, in
## the log the full-time line, the live duel call and the rematch all read
## (resolve_forward50 logs the entries inside 50). `ev` is the event the
## contest produced; it is tagged so the line can be traced to the play. A
## contest nobody won produces no event, so nothing is tagged (as inside 50).
## A marking free from the contest is not logged, as inside 50.
func _log_duel(side: int, fwd: Dictionary, man: Dictionary, marked: bool, ev: Dictionary = {}) -> void:
	var fid := str(fwd["id"])
	if not duel_log.has(fid):
		duel_log[fid] = {"side": side, "contests": []}
	(duel_log[fid]["contests"] as Array).append([current_quarter, str(man["id"]), marked, false])
	ev["duel_contest"] = fid


## A key forward leading up at a general-play marking contest in his side's
## front half: on Matchups.KEY_LEAD of them it falls to one of the
## side's matched key forwards (the better in the air more often, as inside
## 50), so he meets his direct opponent up the ground too. Never the kicker
## (`carrier`): a man cannot lead up at his own kick. {} otherwise.
func _key_lead(side: int, fp: float, carrier = null) -> Dictionary:
	if fp * (1.0 if side == 0 else -1.0) <= 0.0:
		return {}
	var keys := []
	var kid := "" if carrier == null else str(carrier.get("id", ""))
	for fid in (duels[1 - side] as Dictionary):
		var kf := _on_ground(side, str(fid))
		if not kf.is_empty() and kf != _spare_minder(side) and str(kf["id"]) != kid:
			keys.append(kf)
	if keys.is_empty() or lead_rng.randf() >= Matchups.KEY_LEAD:
		return {}
	keys.sort_custom(func(a, b): return Matchups.forward_air(a) > Matchups.forward_air(b))
	return keys[0] if keys.size() == 1 or lead_rng.randf() < 0.6 else keys[1]


## The share of a side's entries inside 50 that look for one of its key
## forwards (Matchups.KEY_TARGET_DUELS).
func key_target() -> float:
	return Matchups.KEY_TARGET_DUELS


## General-play aerial contest on an unmarked kick. We only create one when
## the kick has enough length to plausibly be contested. The defender who wins
## it either marks it (an intercept: the ball is turned over) or spoils it,
## which leaves the ball loose.
func _general_aerial(side: int, mark_fp: float, carrier, gain: float, rushed: bool) -> Dictionary:
	if rushed or gain < 18.0 or aerial_rng.randf() >= (_tv("AERIAL_CHANCE", AERIAL_CHANCE) if zone_intercepts else 0.22):
		return {}
	var opp := 1 - side
	var receiver = kick_receiver(side, mark_fp - gain * (1.0 if side == 0 else -1.0), mark_fp, carrier)
	if receiver == null:
		return {}
	var lead := _key_lead(side, mark_fp, carrier)
	if not lead.is_empty():
		receiver = lead
	var defender = null
	if zone_intercepts:
		_credit_aerial_loose(opp, mark_fp, receiver)
		defender = _aerial_defender(opp, mark_fp)
	else:
		var old := _by_roles((squads[opp] as Squad).ground, ["DEF", "MID"])
		if not old.is_empty():
			defender = _weighted(old, "intercept", 2.0, opp, "defender")
	var man := _duel_man(side, receiver)
	if not man.is_empty():
		defender = man
	if defender == null:
		return {}
	var receive := _a(receiver, "marking")
	var stop := 0.62 * _a(defender, "intercept") + 0.38 * _a(defender, "marking")
	var mark_p := clampf(0.34 + (receive - stop) / 240.0
			+ (0.05 if _trait(receiver, "aerial") else 0.0), 0.16, 0.55) * _wx("aerial")
	var roll := aerial_rng.randf()
	if roll < mark_p:
		_t(side, "marks")
		_p(receiver, "marks")
		var contested := aerial_rng.randf() < 0.55
		if contested:
			_t(side, "contested_marks")
			_p(receiver, "contested_marks")
		_emit("mark", side, mark_fp, receiver,
				"%s marks in general play" % GameDB.player_display_name(receiver))
		var mev: Dictionary = events[events.size() - 1]
		mev["contested"] = contested
		mev["general_play"] = true
		if not man.is_empty():
			mev["against_id"] = str(man["id"])
			_log_duel(side, receiver, man, true, mev)
		return {"outcome": "mark", "actor": receiver, "contested": contested}
	var spoil_p := clampf(0.36 + (stop - receive) / 220.0
			+ (0.07 if _trait(defender, "interceptor") else 0.0), 0.20, 0.65)
	if roll < mark_p + spoil_p:
		var take_p := _tv("INTERCEPT_MARK", INTERCEPT_MARK) * (0.6 + 0.8 * _a(defender, "intercept") / 100.0) * _wx("aerial") * _gt(side, "icept")
		if zone_intercepts and aerial_rng.randf() < take_p:
			_intercept(opp, defender, false)
			_won_back["marked"] = true
			_t(opp, "marks")
			_p(defender, "marks")
			_t(opp, "intercept_marks")
			_p(defender, "intercept_marks")
			_emit("mark", opp, mark_fp, defender,
					"%s intercepts it on the mark" % GameDB.player_display_name(defender))
			var iev: Dictionary = events[events.size() - 1]
			iev["general_play"] = true
			iev["intercept"] = true
			if not man.is_empty():
				_log_duel(side, receiver, man, false, iev)
			return {"outcome": "turnover", "fp": mark_fp, "actor": defender}
		_t(opp, "spoils")
		_p(defender, "spoils")
		_log_spoil(opp, mark_fp)
		_t(opp, "one_percenters")
		_p(defender, "one_percenters")
		_emit("spoil", opp, mark_fp, defender,
				"%s spoils the aerial contest" % GameDB.player_display_name(defender))
		var sev: Dictionary = events[events.size() - 1]
		sev["general_play"] = true
		sev["against_id"] = str(receiver.get("id", ""))
		if not man.is_empty():
			_log_duel(side, receiver, man, false, sev)
		return {"outcome": "loose", "actor": defender}
	# Neither marked nor spoiled: a contest he did not win, as inside 50.
	if not man.is_empty():
		_log_duel(side, receiver, man, false)
	return {}


## Clanger cause (row 12, director 2026-11-04): an error that ends a chain is
## the last disposal's, and the match says why only when the sim really gave a
## reason: the wet ball and the wind both raise the clanger rate
## (WEATHER_RATES), so they are real causes. A rushed touch, a tackle, a kick
## read and taken or an entry all have their own events and do not raise the
## roll, so they are never named as the cause. The error is credited to the
## last carrier, so the player-level clangers stat moves; team totals, score
## and events do not.
## The last touch of the chain being played: {"carrier", "kind", "end"} (end:
## tackle, pressure, aerial or entry when the touch ended that way, else "").
## Bookkeeping for the clanger's cause only; no dice.
var _last_disp := {}
## The match seed, for the clanger-cause share below (a hash, never the dice).
var _clanger_seed := 0
## The weather is blamed only for its own share of clangers: the extra it adds
## over a perfect day, as the paired balance runs measure it (row 61: the wet
## +10%, so 0.10 / 1.10; the wind +2%, so 0.02 / 1.02; the heat makes fewer).
## The extra comes from fumbles, tackles and contests as well as the bad kick
## itself, so it is the day's total, not WEATHER_RATES clanger_per_chain.
## Picked by a hash of seed and event count so the dice are untouched.
const CLANGER_BLAME := {"wet": 0.10, "windy": 0.02}
static func clanger_blame_share(weather_now: String) -> float:
	var rise := float(CLANGER_BLAME.get(weather_now, 0.0))
	return rise / (1.0 + rise)
## Why a clanger went astray: the words after the player's name, by cause. The
## cause is the event's "why"; MatchNotes.clanger_caption has the short form.
const CLANGER_WHY := {
	"wet": "%s loses it on the wet ball",
	"wind": "%s's kick is blown off line",
}


## The cause of a clanger from the touch that ended the chain (`disp`), in the
## weather of the day, after a chain that ended in `outcome`. "" when nothing
## real is to blame: a score, dry still weather, or a touch that ended in its
## own event (a tackle, a kick read and marked). A ball turned over off an entry
## or under pressure can be the wet ball's or the wind's (director, 2026-11-04:
## widen it), so a turnover counts as well as a plain stoppage.
const CLANGER_TURNOVER_ENDS := ["", "entry", "pressure"]
static func clanger_why(disp: Dictionary, weather_now: String, outcome := "stoppage") -> String:
	if disp.is_empty():
		return ""
	var end := str(disp.get("end", ""))
	if outcome == "stoppage":
		if end != "":
			return ""
	elif outcome != "turnover" or not CLANGER_TURNOVER_ENDS.has(end):
		return ""
	if weather_now == "wet":
		return "wet"
	if weather_now == "windy" and str(disp.get("kind", "")) == "kick":
		return "wind"
	return ""


## Kick range (row 10, director 2026-11-03): a kick's receiver must be within
## the kicker's reach, and better kickers reach further.
## Carrier picks per side, "zone|slot role" -> count. Bookkeeping for the
## balance harness (carry share by zone); no dice.
var carry_log := [{}, {}]
## Each side's rebound 50s by how the ball left defensive 50 ("kick",
## "handball", "tackle": carried out through a broken tackle). Bookkeeping
## for the balance harness, not a saved stat; no dice.
var rebound_log := [{}, {}]
## Who takes the ball straight after each rebound 50 (the next touch of the
## same chain), "zone|player id" -> count, the zone where he takes it from his
## side's view. Bookkeeping for the balance harness; no dice.
var exit_rx_log := [{}, {}]
var _exit_open := false
## Every touch later in a chain that has had a rebound 50, "zone|player id"
## -> count, as exit_rx_log. Bookkeeping for the balance harness; no dice.
var post_exit_log := [{}, {}]
var _post_exit := false
## Spoils per side by where they happened, from the spoiling side's end:
## "d50_entry" (a forward-50 entry or goal-square pack), "d50_play", "mid",
## "f50" (general play). Bookkeeping for the balance harness (T2.29); no dice.
var spoil_log := [{}, {}]


func _log_spoil(side: int, at_fp: float, entry := false) -> void:
	var x := at_fp if side == 0 else -at_fp
	var f50 := float(Ratings.T["forward50_line"])
	var k := "d50_entry" if entry else ("d50_play" if x < -f50 else ("f50" if x > f50 else "mid"))
	spoil_log[side][k] = int((spoil_log[side] as Dictionary).get(k, 0)) + 1
## Reach in metres: 30 + 0.35 x his disposal (kicking) rating, so a 40 kicker
## reaches 44 m, a 70 kicker 54.5 m, a 95 kicker 63 m. The ground is 170 m
## goal to goal (Ratings goal_line 85), forward 50 at 35 m from the centre.
const KICK_RANGE_BASE := 30.0
const KICK_RANGE_PER := 0.35
## Where each line stands, metres from the centre toward the side's own goal
## (the sim has no player coordinates; a line's home is its spot in the
## structure). Defenders sit at the half-back line, forwards at half-forward.
const LINE_HOME := {"DEF": -50.0, "MID": 0.0, "RUCK": 0.0, "FWD": 50.0}


## How far `kicker` can kick, metres.
static func kick_range(kicker: Dictionary) -> float:
	var r := float((kicker.get("attr", {}) as Dictionary).get("disposal", 50.0))
	return KICK_RANGE_BASE + KICK_RANGE_PER * r


## The teammates `kicker` can reach from `from_fp` (field position). Nobody
## in range: the nearest teammate (the short option). Pure: no dice.
func kick_targets(side: int, from_fp: float, kicker: Dictionary) -> Array:
	var from_atk := from_fp if side == 0 else -from_fp
	var reach := kick_range(kicker) * _gt(side, "reach")
	var kid := str(kicker.get("id", ""))
	var pool := []
	var nearest = null
	var best := INF
	for p in (squads[side] as Squad).ground:
		if str(p["id"]) == kid:
			continue
		var d := absf(float(LINE_HOME.get(str(p["role"]), 0.0)) - from_atk)
		if d <= reach:
			pool.append(p)
		if d < best:
			best = d
			nearest = p
	if pool.is_empty() and nearest != null:
		pool.append(nearest)
	return pool


## The one receiver choice for a kick, used by every match: watched, Sim the
## week and AI v AI all run this MatchSim. No kicker: the plain carrier pick.
func kick_receiver(side: int, from_fp: float, to_fp: float, kicker):
	if kicker == null:
		return pick_carrier(side, to_fp)
	var pool := kick_targets(side, from_fp, kicker)
	return pick_carrier(side, to_fp, pool if not pool.is_empty() else [])


func pick_carrier(side: int, fp: float, among: Array = []):
	var T := _rates()
	var sq: Squad = squads[side]
	var atk_fp := fp if side == 0 else -fp
	var zone: String
	var key: String
	var purpose := "carrier"
	if atk_fp < -10.0:
		zone = "back"
		key = BALL_USE
	elif atk_fp > float(T["forward50_line"]):
		zone = "inside"
		key = "goalkicking"
	elif atk_fp > 5.0:
		zone = "attack"
		key = "carry"
		purpose = "transition"
	else:
		zone = "middle"
		key = "disposal"
		purpose = "transition"
	var sizes: Dictionary = LEAD_UP_SIZES if zone == "middle" or zone == "attack" else {}
	var group: Array = sq.ground if among.is_empty() else among
	var roles: Dictionary = _back_roles(group) if zone == "back" else CARRY_ROLES[zone]
	var who = _weighted_roles(group, key, roles, _tv("CARRY_PICK_POW", CARRY_PICK_POW), side, purpose, sizes, zone)
	if who != null:
		var k := zone + "|" + str(who["role"])
		carry_log[side][k] = int((carry_log[side] as Dictionary).get(k, 0)) + 1
	return who


## The primary kick-in player: a defender who can use and carry the ball.
## Deterministic within the match so a club has a recognisable rebounder
## instead of a random player materialising in the goal square after each behind.
func kick_in_taker(side: int):
	var ground: Array = (squads[side] as Squad).ground
	var pool := _by_roles(ground, ["DEF"])
	if pool.is_empty():
		pool = ground
	var best = null
	var best_v := -INF
	for p in pool:
		var v := _ball_use(p)
		if best == null or v > best_v or (is_equal_approx(v, best_v)
				and str(p.get("id", "")) < str(best.get("id", ""))):
			best = p
			best_v = v
	return best


func _kick_in_play_on(taker) -> bool:
	if taker == null:
		return false
	var chance := clampf(0.30 + _a(taker, "carry") / 180.0, 0.42, 0.82)
	return restart_rng.randf() < chance


## A 15m+ kick in general play can bring two players to the drop. The result
## is a real mark/spoil/free; a spoil leaves the ball loose rather than gifting
## possession to the defender.
## A general-play marking contest's mark chance. The bounds sit well clear of
## GENERAL_MARK_P so the players' edge (and the loose man's shift) always moves
## it; _credit_general_loose reads the same chance.
func _general_mark_chance(target: Dictionary, defender: Dictionary, roam_shift: float) -> float:
	var edge := (_a(target, "marking") - _a(defender, "intercept")) / 260.0
	if _trait(target, "aerial"):
		edge += 0.05
	return clampf(_tv("GENERAL_MARK_P", GENERAL_MARK_P) + edge + roam_shift,
			GENERAL_MARK_MIN, GENERAL_MARK_MAX) * _wx("aerial")


## The defender's spoil chance once the mark is not taken. Bounds well clear of
## GENERAL_SPOIL_BASE so defender quality and the Interceptor trait count.
func _general_spoil_chance(target: Dictionary, defender: Dictionary) -> float:
	return clampf(_tv("GENERAL_SPOIL_BASE", GENERAL_SPOIL_BASE)
			+ (_a(defender, "intercept") - _a(target, "marking")) / 300.0
			+ (0.06 if _trait(defender, "interceptor") else 0.0),
			GENERAL_SPOIL_MIN, GENERAL_SPOIL_MAX)


func _general_aerial_contest(side: int, mark_fp: float, carrier) -> Dictionary:
	var opp := 1 - side
	var target = _weighted_roles((squads[side] as Squad).ground, "marking",
			GENERAL_MARK_ROLES, 2.0, side, "aerial_target")
	# A man cannot go up for his own kick: draw again among the rest. The first
	# draw stays, so every match without this case keeps its dice.
	if target != null and carrier != null and str(target.get("id", "")) == str(carrier.get("id", "")):
		var others: Array = (squads[side] as Squad).ground.filter(
				func(p): return str(p.get("id", "")) != str(carrier.get("id", "")))
		target = _weighted_roles(others, "marking", GENERAL_MARK_ROLES, 2.0, side, "aerial_target")
	var lead := _key_lead(side, mark_fp, carrier)
	if not lead.is_empty():
		target = lead
	var defs := _by_roles((squads[opp] as Squad).ground, ["DEF"])
	if defs.is_empty():
		defs = (squads[opp] as Squad).ground
	var defender = _weighted(defs, "intercept", 2.0, opp, "aerial_defender")
	# A key forward's contest is against his direct opponent (row 94).
	var man := _duel_man(side, target)
	if not man.is_empty():
		defender = man
	if target == null or defender == null:
		return {}
	# The loose interceptor as an extra body (see resolve_forward50).
	var roaming := false
	var roamer := _roaming_interceptor(opp)
	if not roamer.is_empty() and str(roamer.get("id", "")) != str(defender.get("id", "")):
		_credit_general_loose(side, target, defender, roamer)
	if not roamer.is_empty() and str(roamer.get("id", "")) != str(defender.get("id", "")) 			and aerial_rng.randf() < _roam_chance(opp):
		roaming = true
		_t(opp, "roam_contests")
		_p(roamer, "roam_contests")

	var infringement := _marking_free(side, target, defender)
	if not infringement.is_empty():
		var free_side := int(infringement["side"])
		var mark := _award_context_free(free_side, mark_fp,
				infringement["offender"], infringement["recipient"],
				str(infringement["cause"]), str(infringement["label"]))
		if roaming:
			_roam_note(roamer, target, free_side == opp)
		return {"outcome": "free", "fp": mark, "actor": infringement["recipient"],
				"free_side": free_side}

	var mark_p := _general_mark_chance(target, defender,
			_roam_mark_shift(roamer) if roaming else 0.0)
	if aerial_rng.randf() < mark_p:
		_t(side, "marks")
		_p(target, "marks")
		_t(side, "contested_marks")
		_p(target, "contested_marks")
		_emit("mark", side, mark_fp, target,
				"%s takes a contested mark" % GameDB.player_display_name(target))
		var mev: Dictionary = events[events.size() - 1]
		mev["contested"] = true
		mev["general_play"] = true
		mev["from_id"] = "" if carrier == null else str(carrier.get("id", ""))
		if roaming:
			mev["roaming_interceptor_id"] = str(roamer.get("id", ""))
			_roam_note(roamer, target, false)
		elif not man.is_empty():
			# A third man arriving is not the one-on-one (as inside 50).
			mev["against_id"] = str(man["id"])
			_log_duel(side, target, man, true, mev)
		return {"outcome": "mark", "fp": mark_fp, "actor": target}

	var spoil_p := _general_spoil_chance(target, defender)
	var spoilt := aerial_rng.randf() < spoil_p
	# The defender in it missed: the spare, as the extra body, has his own go.
	if not spoilt and roaming and _roam_spoil(roamer):
		spoilt = true
		defender = roamer
	if spoilt:
		_t(opp, "spoils")
		_p(defender, "spoils")
		_log_spoil(opp, mark_fp)
		_t(opp, "one_percenters")
		_p(defender, "one_percenters")
		_emit("spoil", opp, mark_fp, defender,
				"%s spoils the marking contest" % GameDB.player_display_name(defender))
		var sev: Dictionary = events[events.size() - 1]
		sev["against_id"] = str(target.get("id", ""))
		sev["general_play"] = true
		if roaming:
			sev["roaming_interceptor"] = defender == roamer
			if defender == roamer:
				_roam_note(roamer, target, true)
		elif not man.is_empty():
			_log_duel(side, target, man, false, sev)
		return {"outcome": "loose", "fp": mark_fp, "actor": defender}
	if roaming:
		_roam_note(roamer, target, false)
	elif not man.is_empty():
		# Neither marked nor spoiled: a contest he did not win, as inside 50.
		_log_duel(side, target, man, false)
	return {}


# ---------------------------------------------------------------------------
# Stoppage: ruck contest + clearance
# ---------------------------------------------------------------------------
## Who goes up at the bounce: the player in the ruck spot if he is a
## ruckman; if not (the ruck is resting and a midfielder came on in his
## spot), the ruckman already on the ground - a ruck-forward, say - and only
## with none out there, the best tap man on the ground (an emergency ruck).
## Returned as [] or [player] so callers can keep the list shape.
func _contestant(sq: Squad) -> Array:
	# No in-match main ruck call (director, 2026-11-03): the ruck picked at
	# selection stands in the ruck spot and goes up; an old "main_ruck" key
	# in a tactics dict is ignored.
	var in_slot := _by_roles(sq.ground, ["RUCK"])
	if not in_slot.is_empty() and _is_ruckman(in_slot[0]):
		return [in_slot[0]]
	var best = null
	for p in sq.ground:
		if _is_ruckman(p) and (best == null or float(p["attr"]["ruck"]) > float(best["attr"]["ruck"])):
			best = p
	if best != null:
		return [best]
	for p in sq.ground:
		if best == null or float(p["attr"]["ruck"]) > float(best["attr"]["ruck"]):
			best = p
	return [] if best == null else [best]


## A ruckman by his own listing (any position he can be picked in), whatever
## spot he is standing in today.
static func _is_ruckman(p: Dictionary) -> bool:
	return Traits.plays(p, "RUCK")


static func _ruck_of(contestant: Array) -> float:
	return 45.0 if contestant.is_empty() else float(contestant[0]["attr"]["ruck"])


## The ruck contest at a stoppage, before anyone wins the ball: the two rucks
## on the ground now (not the starting ruck, who may be resting) contest the
## taps - three chances at a hit-out, as many as a real ball-up gives - and
## the first tap won can be to advantage, straight to a team-mate's
## advantage. A tap to advantage swings the stoppage by TAP_ADV_EDGE; a
## tap that is not, by nothing - the mids still have to win it. The lists'
## ruck on paper comes out of the stoppage contest (contest_winner), so on
## average ruck quality counts as much as it did; the tap now decides where.
const RUCK_WEIGHT := 0.24          # Squad.contest's ruck share
const TAP_ADV_EDGE := 0.22
const TAP_ADV_BASE := 0.40         # a league-average ruck's first taps to advantage
const TAP_ADV_SLOPE := 0.004       # per ruck point above the league's 70
var _tap := {}


func _ruck_tap() -> void:
	var T := _rates()
	var ruck := [_contestant(squads[0]), _contestant(squads[1])]
	var king := 0.0
	if not (ruck[0] as Array).is_empty() and _trait(ruck[0][0], "ruck_king"):
		king += 0.05
	if not (ruck[1] as Array).is_empty() and _trait(ruck[1][0], "ruck_king"):
		king -= 0.05
	var share := clampf(0.5 + (_ruck_of(ruck[0]) - _ruck_of(ruck[1])) / 260.0 + king, 0.15, 0.85)
	var hits := [0, 0]
	var first := -1
	for i in range(3):
		if rng.randf() < float(T["hitouts_per_stoppage"]) / 3.0:
			var s := 0 if rng.randf() < share else 1
			hits[s] += 1
			if first < 0:
				first = s
	var adv := false
	var edge := 0.0
	if first >= 0:
		var r := _ruck_of(ruck[first])
		adv = rng.randf() < clampf(TAP_ADV_BASE + TAP_ADV_SLOPE * (r - 70.0), 0.12, 0.6)
		if adv:
			edge = TAP_ADV_EDGE if first == 0 else -TAP_ADV_EDGE
	_tap = {"side": first, "hits": hits, "adv": adv, "edge": edge}

## Returns the player credited with the clearance, or null.
func _stoppage(side: int, opp: int, from_bounce: bool, in_f50 := false):
	if not from_bounce:
		return null
	var T := _rates()
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]
	var ruck_a := _contestant(atk)
	var ruck_b := _contestant(dfn)

	# The hit-outs of this stoppage, as the tap in _ruck_tap had them: the
	# deciding tap and any further taps at the same ball-up.
	var tap := _tap
	_tap = {}
	if not tap.is_empty():
		var hit := {0: int(tap["hits"][0]), 1: int(tap["hits"][1])}
		# Every tap hit at this ball-up was a contest between the two rucks:
		# each was in it whoever won it (hit-out win % = hit-outs / contests).
		var taps := int(hit[0]) + int(hit[1])
		if taps > 0:
			for r3 in [ruck_a, ruck_b]:
				_p((r3 as Array)[0] if not (r3 as Array).is_empty() else null, "ruck_contests", taps)
		for s2 in [0, 1]:
			var r: Array = ruck_a if s2 == side else ruck_b
			if int(hit[s2]) > 0:
				_t(s2, "hitouts", hit[s2])
				_p(r[0] if not r.is_empty() else null, "hitouts", hit[s2])
		var ts := int(tap["side"])
		if ts >= 0 and bool(tap["adv"]):
			var r2: Array = ruck_a if ts == side else ruck_b
			_t(ts, "hitouts_adv")
			_p(r2[0] if not r2.is_empty() else null, "hitouts_adv")

	# A centre bounce: the ruck and three inside mids from each side attend.
	var attend := {}
	if at_centre:
		for s2 in [side, opp]:
			attend[s2] = _centre_attendees(s2)
			_t(s2, "centre_bounces")
			for p in attend[s2]:
				_p(p, "cba")
	if rng.randf() < float(T["clearance_per_stoppage"]):
		_t(side, "clearances")
		var mid
		if at_centre and not (attend[side] as Array).is_empty():
			# A centre clearance goes to someone who was there.
			mid = _weighted(attend[side], "contested", 2.0, side, "clearance")
		else:
			mid = _weighted_roles(atk.ground, "contested", CLEARANCE_ROLES_F50 if in_f50 else CLEARANCE_ROLES, 2.0, side, "clearance")
		_p(mid, "clearances")
		return mid
	return null


# ---------------------------------------------------------------------------
# Boundary laws
# ---------------------------------------------------------------------------
## 2026 AFL last-disposal rule: a kick or handball that crosses the boundary
## between the 50m arcs is a free to the opposition. If it was touched or the
## exit was otherwise contested, it remains a throw-in. Out on the full is a
## free anywhere on the ground.
static func boundary_restart(cross_fp: float, f50: float, disposal_kind: String,
		out_on_full: bool, touched: bool) -> String:
	if out_on_full:
		return "free"
	if absf(cross_fp) < f50 and ["kick", "handball"].has(disposal_kind) and not touched:
		return "free"
	return "throwin"


## A disposal leaves the oval. MatchSim has one field-position axis, so the
## lateral crossing itself is probabilistic; the restart and crossing spot are
## real state. Returns {} when the ball stays in.
func _boundary_exit(side: int, cross_fp: float, carrier, disposal_kind: String,
		rushed: bool, marked: bool) -> Dictionary:
	if marked:
		return {}
	var chance := BOUNDARY_EXIT_P + (BOUNDARY_RUSHED_BONUS if rushed else 0.0)
	if boundary_rng.randf() >= chance:
		return {}
	var out_on_full := disposal_kind == "kick" and boundary_rng.randf() < OUT_ON_FULL_SHARE
	var touched := not out_on_full and boundary_rng.randf() < BOUNDARY_TOUCHED_SHARE
	var restart := boundary_restart(cross_fp, float(Ratings.T["forward50_line"]),
			disposal_kind, out_on_full, touched)
	if restart == "throwin":
		_emit("throwin", -1, cross_fp, null, "Boundary throw-in")
		var bev: Dictionary = events[events.size() - 1]
		bev["last_side"] = side
		bev["disposal_kind"] = disposal_kind
		bev["touched"] = touched
		return {"outcome": "boundary", "fp": cross_fp, "actor": carrier}

	var opp := 1 - side
	var recipient = _free_to(opp, cross_fp if side == 0 else -cross_fp)
	_t(opp, "frees_for")
	_p(recipient, "frees_for")
	_t(side, "frees_against")
	_p(carrier, "frees_against")
	var kind := "out_on_full" if out_on_full else "last_disposal"
	var who := GameDB.player_display_name(recipient) if recipient != null else "the opposition"
	var why := "Out on the full" if out_on_full else "Last disposal out"
	_emit(kind, opp, cross_fp, recipient, "%s - free kick to %s" % [why, who])
	var fev: Dictionary = events[events.size() - 1]
	fev["against_id"] = "" if carrier == null else str(carrier.get("id", ""))
	fev["against_name"] = "" if carrier == null else GameDB.player_display_name(carrier)
	fev["disposal_kind"] = disposal_kind
	var restart_fp := _maybe_fifty(opp, cross_fp, carrier, recipient)
	return {"outcome": "free", "fp": restart_fp, "actor": recipient}


# ---------------------------------------------------------------------------
# One possession chain
# ---------------------------------------------------------------------------
func play_chain(side: int, fp: float, from_bounce: bool, from_kick_in := false) -> Dictionary:
	var T := _rates()
	var opp := 1 - side
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]
	var dir := 1.0 if side == 0 else -1.0
	var f50 := float(T["forward50_line"])
	var gline := float(T["goal_line"])

	_t(side, "chains")
	_broke_press = -1
	_broke_cluster = -1
	_exit_open = false
	_post_exit = false
	var atk_fp := fp if side == 0 else -fp
	var cleared = _stoppage(side, opp, from_bounce, atk_fp >= f50)
	# A chain that starts inside its forward 50 (a ball-up won there) goes
	# through the normal entry below on its first disposal, so it can score.
	var touched_i50 := false

	var touches := 0
	var max_touches := int(T["max_touches_per_chain"])
	# The last disposal, until we know where it went: effective if his side
	# has it next, not if he is caught with it or the chain dies in a
	# stoppage or an entry is rebounded (disposal efficiency).
	var pending = null
	# How the next carrier comes by the ball, from the disposal before it:
	# "up" uncontested (a handball receive, an uncontested mark), "cp" in a
	# contest, "gb" a ground ball won in a contest (POSSESSION_GAINS).
	var next_gain := ""
	# The last kick, for the next carrier's pick (kick_receiver): its kicker
	# and where it was kicked from. null after a handball.
	var last_kicker = null
	var last_kick_fp := 0.0
	while touches < max_touches:
		touches += 1
		if pending != null:
			_effective(side, pending)
			pending = null
		var is_kick_in := from_kick_in and touches == 1
		var carrier = kick_in_taker(side) if is_kick_in else kick_receiver(side, last_kick_fp, fp, last_kicker)
		last_kicker = null
		if touches == 1 and clearance_keeps and cleared != null and not is_kick_in:
			carrier = cleared
		# He marked it, so he takes the kick; or he won the ground ball off a
		# spoil, so the first touch is his. The carrier pick is still drawn,
		# so the rest of the chain's dice are where they were.
		if touches == 1 and chain_origin == "turnover" and (bool(_chain_from.get("marked", false))
				or _chain_from.has("gatherer")):
			var marker := _on_ground(side, str(_chain_from.get("gatherer", _chain_from.get("id", ""))))
			if not marker.is_empty():
				carrier = marker
		var kick_in_play_on := _kick_in_play_on(carrier) if is_kick_in else false
		# The loose ball won off the other side's spoiled, smothered or
		# astray disposal is an intercept possession (Champion Data), by
		# whoever is there to take it: a forward in his forward half as much
		# as a defender down back. Bookkeeping only.
		if touches == 1 and zone_intercepts and chain_origin == "general" and _ball_lost_by == 1 - side \
				and _chain_from.is_empty() and not from_bounce and not is_kick_in:
			_t(side, "intercepts")
			_p(carrier, "intercepts")
			_chain_from = {"side": side, "id": str(carrier.get("id", ""))}
		_chain_touch[str(carrier["id"])] = carrier
		if _post_exit:
			var rx_atk := fp * dir
			var rx_zone := "back" if rx_atk < -10.0 else ("middle" if rx_atk <= 5.0
					else ("attack" if rx_atk <= f50 else "inside"))
			var rk := rx_zone + "|" + str(carrier.get("id", ""))
			post_exit_log[side][rk] = int((post_exit_log[side] as Dictionary).get(rk, 0)) + 1
			if _exit_open:
				_exit_open = false
				exit_rx_log[side][rk] = int((exit_rx_log[side] as Dictionary).get(rk, 0)) + 1
		# Who a clanger would be blamed on, and how his touch ended (clanger_why).
		_last_disp = {"carrier": carrier, "kind": "", "end": ""}
		# The wet ball (row 120): the first touch of a chain, when it is a
		# ground ball (a loose turnover, a general contest, a stoppage with
		# no clean clearance), can be fumbled at the gather. Later touches
		# come by hand or foot, so they are never ground balls.
		if weather == "wet" and not is_kick_in and touches == 1:
			if _first_gain(carrier, cleared, is_kick_in) == "gb":
				var fumbled := _wet_fumble(side, carrier, fp)
				if not fumbled.is_empty():
					return fumbled
		# Champion Data: a kick straight from the goal square is a team
		# kick-in, not a player disposal. Once the taker plays on it is his
		# disposal like ordinary play.
		var counts_disposal := not is_kick_in or kick_in_play_on
		if counts_disposal:
			_t(side, "disposals")
			_p(carrier, "disposals")
			_gain(side, carrier, next_gain if touches > 1 else _first_gain(carrier, cleared, is_kick_in))
		if is_kick_in:
			_t(side, "kick_ins")
			_p(carrier, "kick_ins")
			if kick_in_play_on:
				_t(side, "kick_in_play_ons")
				_p(carrier, "kick_in_play_ons")
		pending = carrier if counts_disposal else null

		var disposal_event := -1
		# Inside his own defensive 50: he looks to clear it (D50_*).
		var in_d50 := (fp if side == 0 else -fp) <= -f50
		var hb_bias: float = (0.85
				+ 0.30 * (100.0 - _a(carrier, "marking")) / 100.0)
		var disposal_kind := "handball"
		var marked := false
		# A kick-in is kicked: no handball roll for its first disposal.
		if not (from_kick_in and touches == 1) \
				and rng.randf() < float(T["handball_share"]) * hb_bias \
				* (_tv("D50_HANDBALL", D50_HANDBALL) if in_d50 else 1.0):
			_t(side, "handballs")
			_p(carrier, "handballs")
			_emit("handball", side, fp, carrier, "%s handballs" % GameDB.player_display_name(carrier))
			disposal_event = events.size() - 1
		else:
			disposal_kind = "kick"
			last_kicker = carrier
			last_kick_fp = fp
			if counts_disposal:
				_t(side, "kicks")
				_p(carrier, "kicks")
			var mark_p: float = (float(T["mark_share_of_kicks"])
					* (0.75 + 0.50 * _a(carrier, "marking") / 100.0))
			marked = false if is_kick_in else rng.randf() < mark_p
			if marked:
				_t(side, "marks")
				_p(carrier, "marks")
				_emit("mark", side, fp, carrier, "%s marks" % GameDB.player_display_name(carrier))
			else:
				_emit("kick", side, fp, carrier, "%s kicks" % GameDB.player_display_name(carrier))
			disposal_event = events.size() - 1
			if is_kick_in:
				var kev: Dictionary = events[events.size() - 1]
				kev["kick_in"] = true
				kev["play_on"] = kick_in_play_on
				kev["kick_in_style"] = "play_on" if kick_in_play_on else "safe"

		# Pressure comes from whoever is near the ball: their forwards when we
		# are coming out of defence, their midfield through the middle, their
		# defenders when we are going forward (PRESS_ZONES).
		atk_fp = fp if side == 0 else -fp
		var zone := _press_zone(atk_fp)
		var pressure: float = (float(T["pressure_base"])
				* (0.72 + 0.56 * _zone_pressure(opp, zone) / 100.0))
		pressure *= 1.10 if atk_fp < 0.0 else 0.95
		if in_d50:
			pressure *= _tv("D50_PRESSURE", D50_PRESSURE)
		if is_kick_in:
			# The conservative exit buys space; playing on gains ground but
			# exposes the taker to more immediate pressure.
			pressure *= 0.68 if not kick_in_play_on else 0.92
		var p_base := pressure
		pressure *= _press_on(side, zone)
		_credit(opp, "gameplan", (pressure - p_base) * TURNOVER_VALUE)
		if zone == 1:
			p_base = pressure
			pressure *= _gt(opp, "mid_press")
			_credit(opp, "gameplan", (pressure - p_base) * TURNOVER_VALUE)
		if synergies[opp].has("lockdown_unit"):
			var lock := Traits.power("lockdown_unit")
			_credit(opp, "traits", pressure * (lock - 1.0) * TURNOVER_VALUE)
			pressure *= lock
		p_base = pressure
		pressure *= _pv(side, "taken") * _ar(side, "taken")
		_credit(side, "gameplan", (p_base - pressure) * TURNOVER_VALUE)
		p_base = pressure
		pressure *= _pep_mult(side, "taken")
		_credit(side, "pep", (p_base - pressure) * TURNOVER_VALUE)
		p_base = pressure
		pressure *= _pep_heat(opp)
		_credit(opp, "pep", (pressure - p_base) * TURNOVER_VALUE)
		if _burst(side, "hold"):
			_credit(side, "bursts", pressure * (1.0 - HOLD_TAKEN) * TURNOVER_VALUE)
			pressure *= HOLD_TAKEN

		# One roll, three outcomes: a tackle, a pressured (rushed) disposal,
		# or no pressure at all. Both of the first two are pressure acts.
		var press_roll := rng.randf()
		var rushed := false
		var tackled := false
		if press_roll < pressure * PRESS_TACKLE_SHARE * _wx("tackle_share"):
			var tackler = _pick_presser(opp, zone)
			_maybe_report(opp, tackler, carrier)
			_t(opp, "tackles")
			_p(tackler, "tackles")
			_t(opp, "pressure_acts")
			_p(tackler, "pressure_acts")
			_press_where(opp, atk_fp, in_d50, true)
			tackled = true
			# High contact belongs to the tackle itself. The ball carrier keeps
			# possession via a free; the tackler is credited the infringement.
			if _high_contact_free(tackler):
				var mark := _award_context_free(side, fp, tackler, carrier,
						"high_contact", "High contact")
				return {"outcome": "free", "fp": mark, "actor": carrier, "free_side": side}
			var retain: float = (float(T["tackle_retention"])
					* (0.75 + 0.50 * _a(carrier, "contested") / 100.0))
			if _trait(carrier, "bull"):
				retain *= 1.10
			if rng.randf() < retain:
				var before_fp := fp
				fp = clampf(fp + rng.randf_range(4.0, 12.0) * dir, -gline, gline)
				_metres(side, carrier, (fp - before_fp) * dir)
				# Carried out of defensive 50 through the tackle: his rebound 50.
				_rebound_exit(side, carrier, before_fp * dir, fp * dir, "tackle")
				var how := _break_kind(carrier)
				_t(side, how)
				_p(carrier, how)
				# He broke the tackle and got it away: his teammate takes it
				# with nobody contesting it.
				next_gain = "up"
				continue
			_t(opp, "pressure_wins")
			# A legal tackle that stops him can be holding the ball; otherwise
			# it remains the ball-up the engine already had.
			if _holding_ball_free(carrier, touches):
				var mark := _award_context_free(opp, fp, carrier, tackler,
						"holding_ball", "Holding the ball")
				return {"outcome": "free", "fp": mark, "actor": tackler, "free_side": opp}
			_last_disp["end"] = "tackle"
			_last_disp["kind"] = disposal_kind
			# Knocked loose in the tackle: whoever is there for the other side gathers
			# it off the ground. Otherwise it is held in: a ball-up. A spilled
			# tackle is not an intercept (row 11): nobody disposed of the ball, so
			# it counts as a spilled tackle and the gatherer's possession is a
			# ground ball get (_first_gain, an unmarked turnover).
			if lockup_rng.randf() < _tv("TACKLE_SPILL", TACKLE_SPILL) * _wx("tackle_spill"):
				var taker = _aerial_defender(opp, fp)
				if taker == null:
					taker = tackler
				_t(opp, "tackle_spills")
				_won_back = {"side": opp, "id": str(taker.get("id", ""))}
				_emit("tackle", opp, fp, tackler,
						"%s tackles %s - it spills free" % [GameDB.player_display_name(tackler), GameDB.player_display_name(carrier)])
				return {"outcome": "turnover", "fp": fp, "actor": taker}
			_emit("tackle", opp, fp, tackler,
					"%s tackles %s - ball up" % [GameDB.player_display_name(tackler), GameDB.player_display_name(carrier)])
			return {"outcome": "stoppage", "fp": fp, "actor": carrier}
		if press_roll < pressure * (1.0 + _tv("PRESS_RUSH_RATIO", PRESS_RUSH_RATIO)):
			# Closed down without a tackle: the disposal is rushed. It gains
			# less ground, and sometimes goes straight to the opposition -
			# likelier against a strong presser, less likely from a clean
			# user of the ball.
			var presser = _pick_presser(opp, zone)
			_t(opp, "pressure_acts")
			_p(presser, "pressure_acts")
			_press_where(opp, atk_fp, in_d50, false)
			var turn_p: float = (_tv("PRESS_TURNOVER", PRESS_TURNOVER_FLOW)
					* (0.80 + 0.40 * _a(presser, "pressure") / 100.0)
					* (1.20 - 0.40 * _a(carrier, "disposal") / 100.0))
			if zone == 0 and _pv(opp, "press") > 1.0:
				turn_p *= PRESS_ZONE_TURNOVER
			if in_d50:
				turn_p *= _tv("D50_TURNOVER", D50_TURNOVER)
			if zone == 0:
				var tp0 := turn_p
				turn_p *= _gt(opp, "fwd_turnover")
				_credit(opp, "gameplan", (turn_p - tp0) * TURNOVER_VALUE)
			if rng.randf() < turn_p:
				# Rushed into a pack: sometimes nobody gets it clean and the
				# umpire calls a ball-up where it locked up.
				if lockup_rng.randf() < _tv("LOCKUP_PRESS", LOCKUP_PRESS) * _wx("lockup"):
					return {"outcome": "stoppage", "fp": fp, "actor": presser}
				_t(opp, "pressure_wins")
				# A rushed handball is picked off by the man on him; a rushed kick
				# lands with whoever is in that part of the ground, and the better
				# readers mark it (match flow, 2026-10-10: these are most of a real
				# game's intercept marks).
				var taker = presser
				if disposal_kind == "kick":
					var reader = _aerial_defender(opp, fp)
					if reader != null:
						taker = reader
				_intercept(opp, taker, false)
				_emit("pressure", opp, fp, presser,
						"%s forces the turnover" % GameDB.player_display_name(presser))
				_last_disp["end"] = "pressure"
				_last_disp["kind"] = disposal_kind
				if disposal_kind == "kick":
					_kick_marked(opp, taker, fp, mark_rng.randf() < _tv("PRESS_KICK_MARKED", PRESS_KICK_MARKED)
							* (0.6 + 0.8 * _a(taker, "intercept") / 100.0) * _gt(side, "icept"))
				return {"outcome": "turnover", "fp": fp, "actor": taker}
			rushed = true

		# A smother is a real blocked kick, not a decorative stat. It leaves
		# the ball live at the contest, so the next chain is won as a loose
		# ball rather than automatically handed to either side.
		if disposal_kind == "kick" and not marked:
			var smotherer = _pick_presser(opp, zone)
			var smother_p := SMOTHER_BASE * (0.55 + 0.90 * _a(smotherer, "pressure") / 100.0)
			smother_p *= 1.35 if rushed else 0.85
			if smother_rng.randf() < minf(SMOTHER_CAP, smother_p):
				_t(opp, "smothers")
				_p(smotherer, "smothers")
				_t(opp, "one_percenters")
				_p(smotherer, "one_percenters")
				_t(opp, "pressure_acts")
				_p(smotherer, "pressure_acts")
				_press_where(opp, atk_fp, in_d50, false)
				_emit("smother", opp, fp, smotherer,
						"%s smothers the kick" % GameDB.player_display_name(smotherer))
				return {"outcome": "loose", "fp": fp, "actor": smotherer}

		var prev_atk_fp := atk_fp
		var gain: float = (float(T["metres_gain_mean"])
				* (0.55 + 0.90 * _a(carrier, "carry") / 100.0))
		gain *= _pv(side, "gain") * _pep_mult(side, "gain") * _ar(side, "gain") * _gt(side, "gain")
		if synergies[side].has("supply_line"):
			gain *= Traits.power("supply_line")
		if _burst(side, "flood") or _burst(side, "hold"):
			gain *= BACK_GAIN
		if _burst(side, "push"):
			gain *= PUSH_GAIN
		gain *= rng.randf_range(0.45, 1.75)
		if disposal_kind == "kick":
			if in_d50:
				gain *= _tv("D50_KICK_GAIN", D50_KICK_GAIN)
			gain = minf(gain, kick_range(carrier) * _gt(side, "reach"))
		if is_kick_in:
			gain *= 0.82 if not kick_in_play_on else 1.12
		if not rushed and zone == 0 and _broke_cluster != side and _gt(opp, "broken") > 1.0:
			_broke_cluster = side
		if rushed:
			gain *= _tv("PRESS_RUSH_GAIN", PRESS_RUSH_GAIN)
		elif zone == 0 and _pv(opp, "press") > 1.0 and _broke_press != side:
			# Out of the back third with nobody on him: the press is broken.
			_broke_press = side
			_t(side, "press_broken")
		fp += gain * dir
		fp = clampf(fp, -gline, gline)
		atk_fp = fp if side == 0 else -fp
		_last_disp["kind"] = disposal_kind
		_metres(side, carrier, atk_fp - prev_atk_fp)
		_run_and_carry(side, carrier, atk_fp - prev_atk_fp, rushed or tackled, is_kick_in, disposal_event, prev_atk_fp)
		# Rebound 50 (Champion Data): his kick or handball takes the ball from
		# inside his defensive 50 out of it, however his side came by it (a
		# kick-in, a stoppage, an intercept, a failed entry) and whatever
		# happens to it next.
		_rebound_exit(side, carrier, prev_atk_fp, atk_fp, disposal_kind)
		# By default the next carrier gets it uncontested: a handball
		# receive, a mark, a kick he gathers with nobody contesting it (the
		# engine has no contest there; a rushed disposal loses ground, not
		# the ball). The genuine contests - an aerial ball, a stoppage, a
		# spill - set their own below and at the chain's start.
		next_gain = "up"

		# Outside forward 50, a genuine long kick can become a contested
		# aerial ball. A mark retains it; a spoil makes the next chain loose.
		if disposal_kind == "kick" and not marked and gain >= 15.0 and atk_fp < f50 				and aerial_rng.randf() < _tv("GENERAL_AERIAL_P", GENERAL_AERIAL_P):
			var aerial := _general_aerial_contest(side, fp, carrier)
			if not aerial.is_empty():
				match str(aerial["outcome"]):
					"mark":
						_effective(side, carrier)
						pending = null
						next_gain = "cp"  # a contested mark
						continue
					"free", "loose":
						return aerial

		var boundary := _boundary_exit(side, fp, carrier, disposal_kind, rushed, marked)
		if not boundary.is_empty():
			return boundary

		if disposal_kind == "kick" and not marked and not is_kick_in:
			var aerial := _general_aerial(side, fp, carrier, gain, rushed)
			if not aerial.is_empty():
				if str(aerial.get("outcome", "")) == "loose":
					return {"outcome": "loose", "fp": fp, "actor": aerial.get("actor")}
				if str(aerial.get("outcome", "")) == "turnover":
					_last_disp["end"] = "aerial"
					return aerial
				# A mark keeps the same side's chain alive at the new field
				# position. It is not another disposal by the original kicker.
				pending = carrier
				next_gain = "cp" if bool(aerial.get("contested", false)) else "up"
				continue
			# Row 89: a kick through the middle with no contest can be read
			# and taken outright by one of their midfielders.
			if aerial.is_empty() and _aerial_zone(opp, fp) == "middle" 					and mid_ic_rng.randf() < _tv("MID_KICK_INTERCEPT", MID_KICK_INTERCEPT):
				var taken := _mid_kick_intercept(side, fp)
				if not taken.is_empty():
					_last_disp["end"] = "aerial"
					return taken

		if atk_fp >= f50 and not touched_i50:
			touched_i50 = true
			_t(side, "inside50")
			_p(carrier, "inside50")
			_emit("inside50", side, fp, carrier,
					"%s sends it inside 50" % GameDB.player_display_name(carrier))
			var entry := resolve_forward50(side, fp, carrier)
			_last_disp["end"] = "entry"
			# A rebound or a free paid to the defence makes the entry
			# ineffective. A free to the attacking side still retained the ball.
			var effective_entry := str(entry["outcome"]) != "turnover"
			if str(entry["outcome"]) == "free" and int(entry.get("free_side", side)) != side:
				effective_entry = false
			if effective_entry:
				_effective(side, carrier)
			return entry

	return {"outcome": "stoppage", "fp": fp, "actor": null}


## Where the defending side kicks in from after `side` scores a behind: the
## middle of the goal square (9 m deep) at the end `side` attacks.
func kick_in_fp(side: int) -> float:
	var dir := 1.0 if side == 0 else -1.0
	return dir * (float(Ratings.T["goal_line"]) - GOAL_SQUARE_DEPTH * 0.5)


## Forward-50 entry resolution: contest the mark, then roll for goal / behind /
## rebound. This is where almost all of the scoring variance lives.
func resolve_forward50(side: int, fp: float, feeder) -> Dictionary:
	var T := _rates()
	var opp := 1 - side
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]

	var shooter = _weighted_roles(atk.ground, "goalkicking", SHOT_ROLES, float(T["shooter_power"]), side, "shooter",
			TARGET_SIZES)
	# Sides look for their key forwards on the way in: a share of entries go
	# to one of them (the better one more often), into his match-up.
	var keys := []
	for fid in (duels[opp] as Dictionary):
		var kf := _on_ground(side, str(fid))
		if not kf.is_empty() and kf != _spare_minder(side):
			keys.append(kf)
	if not keys.is_empty() and rng.randf() < key_target():
		keys.sort_custom(func(a, b): return Matchups.forward_air(a) > Matchups.forward_air(b))
		shooter = keys[0] if keys.size() == 1 or rng.randf() < 0.6 else keys[1]
	# What the defensive forward call costs in who gets the entry: the share
	# he would have had (and his place among the key targets) without it.
	var minder_dp := _minder_pick_shift(side, keys, T)

	var dgroup := _by_roles(dfn.ground, ["DEF"])
	if dgroup.is_empty():
		dgroup = dfn.ground
	# Who meets the entry: the better readers more often, but not so much
	# that one defender takes them all (the best real interceptors average
	# about 8 a game, Champion Data 2025).
	var defender = _weighted(dgroup, "intercept", ENTRY_READ if zone_intercepts else 2.0, opp, "defender")
	# A forward with a direct opponent contests it with him: their aerial
	# games decide it on top of the lines (Matchups).
	_duel = {}
	var duel_shift := 0.0
	var matched := _on_ground(opp, str((duels[opp] as Dictionary).get(str(shooter["id"]), "")))
	var line_def = defender
	if not matched.is_empty():
		defender = matched
		duel_shift = Matchups.mark_shift(shooter, matched)

	# The loose interceptor can arrive as a third man: an extra body at the
	# contest, not a replacement. The defender who met the ball (his direct
	# opponent, or the line's) is still in it; the spare adds his own fist
	# or hands on top (_roam_spoil, LOOSE_EXTRA). He leaves his post on a
	# share of entries whatever his read (_roam_go_chance); his read decides
	# whether he gets there in time. Late, he is not in the contest, but the
	# space he left is (below). One draw, so a top reader plays as before.
	var roaming := false
	var late := false
	var roamer := _roaming_interceptor(opp)
	var roam_shift := 0.0
	var roam_target = shooter
	if not roamer.is_empty() and str(roamer.get("id", "")) != str(defender.get("id", "")):
		var u := aerial_rng.randf()
		if u < _roam_chance(opp):
			roaming = true
			roam_shift = _roam_mark_shift(roamer)
			_t(opp, "roam_contests")
			_p(roamer, "roam_contests")
		elif u < _roam_go_chance(opp):
			late = true
			_t(opp, "roam_late")
			_p(roamer, "roam_late")

	# A marking infringement is paid from the contest itself, not from a
	# post-chain generic dice roll.
	_credit_entry(side, shooter, feeder, defender, line_def, matched, roamer, minder_dp)
	var infringement := _marking_free(side, shooter, defender)
	if not infringement.is_empty():
		var free_side := int(infringement["side"])
		var mark_fp := _award_context_free(free_side, fp,
				infringement["offender"], infringement["recipient"],
				str(infringement["cause"]), str(infringement["label"]))
		if roaming:
			_roam_note(roamer, shooter, free_side == opp)
		return {"outcome": "free", "fp": mark_fp, "actor": infringement["recipient"],
				"free_side": free_side}

	var mark_edge := Matchups.AERIAL_EDGE if _trait(shooter, "aerial") else 0.0
	# A named contest can be lopsided: a great forward on a small defender
	# marks nearly everything, so its ceiling is higher than the lines'.
	var mark_cap := 0.78 if matched.is_empty() else Matchups.DUEL_CAP
	# Unmatched, his own game in the air counts too: a tall marking forward
	# holds more of them, a small one fewer (a named contest has it already).
	var air_shift := 0.0
	if matched.is_empty():
		air_shift = (Matchups.forward_air(shooter) - FWD_AIR_CENTRE) / FWD_AIR_SCALE
	var marked := rng.randf() < clampf(
			Matchups.MARK_BASE + (atk.fwd_mark - dfn.def_intercept) / Matchups.MARK_LINES + mark_edge + duel_shift + air_shift
			+ roam_shift, 0.10, mark_cap) * _wx("aerial")
	# A third-man arrival is not credited to the direct defender's 1v1 log.
	# Interceptor contests have their own evidence/stats and story.
	if not matched.is_empty() and not roaming:
		var fid := str(shooter["id"])
		if not duel_log.has(fid):
			duel_log[fid] = {"side": side, "contests": []}
		(duel_log[fid]["contests"] as Array).append([current_quarter, str(matched["id"]), marked, false])
		_duel_tag = fid
		_duel = {"fwd": fid, "def": str(matched["id"]), "won": "fwd" if marked else "def",
				"q": current_quarter, "n": (duel_log[fid]["contests"] as Array).size()}
	var mark_ev := {}
	if marked:
		_t(side, "marks")
		_p(shooter, "marks")
		# Contested when a defender was at the ball with him: his direct
		# opponent in a one-on-one, or the spare flying at it. Otherwise he
		# marked it on the lead (the Stats patch: from the contest, not a roll).
		var contested := not matched.is_empty() or roaming
		if contested:
			_t(side, "contested_marks")
			_p(shooter, "contested_marks")
		var speccy := false
		if contested and _speccies < _speccy_quota:
			# The quota gives the requested long-run shape: 30% none, 60% one,
			# 10% up to two (mean 0.8, hard max two). Aerial/marking quality
			# decides which genuine contested marks earn the spectacular tag.
			var spectacular_p := clampf(0.28 + (_a(shooter, "marking") - 50.0) / 180.0
					+ (0.12 if _trait(shooter, "aerial") else 0.0), 0.16, 0.62)
			if speccy_rng.randf() < spectacular_p:
				speccy = true
				_speccies += 1
		_emit("mark", side, fp, shooter,
				"%s takes %smark" % [GameDB.player_display_name(shooter), "a spectacular " if speccy else "the "])
		var mev: Dictionary = events[events.size() - 1]
		mark_ev = mev
		mev["contested"] = contested
		mev["speccy"] = speccy
		if contested:
			# Who was at it with him: his direct opponent, or the spare.
			mev["against_id"] = str((matched if not matched.is_empty() else defender).get("id", ""))
		if roaming:
			mev["roaming_interceptor_id"] = str(roamer.get("id", ""))
			_roam_note(roamer, shooter, false)
		if _duel_tag != "":
			mev["duel_contest"] = _duel_tag
	_duel_tag = ""
	var spoil_edge := 0.05 if defender != null and _trait(defender, "interceptor") else 0.0
	var spoil_read := dfn.def_intercept
	if not matched.is_empty():
		# His own reading of the ball, alongside the line's.
		spoil_read = 0.5 * dfn.def_intercept + 0.5 * Matchups.defender_air(matched)
	# In a named contest the same aerial gap decides whether he gets a fist
	# to it (Matchups): a defender on top spoils more, one beaten spoils less.
	var spoilt := rng.randf() < clampf(0.30 + 0.35 * spoil_read / 100.0 + spoil_edge - duel_shift, 0.05, 0.95)
	# The defender in the contest missed it: the spare, flying in as the extra
	# body, gets his own fist to it.
	var spoiler = defender
	if roaming and not marked and not spoilt and _roam_spoil(roamer):
		spoilt = true
		spoiler = roamer
	if spoilt and not marked and spoiler != null:
		# He got a fist to it: a spoil (a credit only).
		_t(opp, "spoils")
		_p(spoiler, "spoils")
		_log_spoil(opp, fp, true)
		if roaming and spoiler == roamer:
			_roam_note(roamer, shooter, true)
	if rng.randf() < float(T["one_percenter_share"]):
		_t(opp, "one_percenters")
		# A spoil is the spoiler's one-percenter. The other is still drawn (and
		# dropped) so every later random number falls where it did.
		var drawn = _one_percenter(opp)
		_p(spoiler if spoilt and not marked and spoiler != null else drawn, "one_percenters")

	# Unmarked and unspoiled, the ball can hit the deck: a ground-ball forward
	# gets to it first (more often off a tall target) and snaps instead.
	var crumbed := false
	var ground_lost := false
	if not marked and not spoilt and matched.is_empty() 			and rng.randf() < float(SPILL_P.get(fwd_size(shooter) if str(shooter.get("role", "")) == "FWD" else "general", 0.30)):
		var ground_fwd = _ground_forward(side, str(shooter["id"]))
		if ground_fwd != null:
			shooter = ground_fwd
			crumbed = true
			var size: String = fwd_size(ground_fwd) if str(ground_fwd.get("role", "")) == "FWD" else "general"
			ground_lost = rng.randf() >= float(GROUND_WIN[size]) * (0.85 + 0.30 * _a(ground_fwd, "pressure") / 100.0)
	var goal_p := shot_chance(side, shooter, marked, spoilt, true, feeder, defender)
	var behind_p: float = (float(T["inside50_behind"])
			* (0.80 + 0.40 * _a(shooter, "goalkicking") / 100.0))
	if ground_lost:
		goal_p = 0.0  # beaten to it at ground level: the defence clears
		behind_p = 0.0
	# If the spare flies and does not kill the ball, or goes and gets there
	# late, the space behind him is the price of the role: the resulting
	# chance is slightly more dangerous. A good reader picks his moment, so
	# leaves less space when he misses.
	if (roaming or late) and not spoilt:
		var gap := 1.0 - _loose_read(roamer)
		if late:
			goal_p *= 1.0 + float(LOOSE_LATE_SPACE["marked" if marked else "unmarked"]) * gap
		else:
			goal_p *= 1.0 + (0.15 if marked else 0.08) * gap
		behind_p *= 1.0 + 0.05 * gap
		if roaming and not marked:
			_roam_note(roamer, roam_target, false)
	# Beaten in the air by his direct opponent, a key forward rarely gets the
	# shot himself: the ball spills or the defender clears it.
	if not matched.is_empty() and not marked:
		goal_p *= Matchups.BEATEN_SHOT
		behind_p *= Matchups.BEATEN_SHOT
	# Row 77: more marks inside 50 go back for the kick, so the general-play
	# shot off an unmarked entry comes less often (SET_GP_SHOT).
	if not marked:
		goal_p *= _tv("SET_GP_SHOT", SET_GP_SHOT)
		behind_p *= _tv("SET_GP_SHOT", SET_GP_SHOT)

	# A mark inside 50 is a set shot from a distance and angle, or the ball
	# goes on (SET_BANDS_ON); the chances come from where he kicks from.
	var set_shot := {}
	var shot_fp := fp
	if marked:
		var split := _set_shot_split(goal_p, behind_p)
		goal_p = float(split["goal"])
		behind_p = float(split["behind"])
		set_shot = split["band"]
		if not set_shot.is_empty():
			shot_fp = (1.0 if side == 0 else -1.0) * (float(T["goal_line"]) - float(set_shot["metres"]))
			# He marked where he kicks from (T2.24): the oval stands the mark on
			# the band's spot, as the call's own scene does. A tag, no roll.
			if not mark_ev.is_empty():
				mark_ev["band"] = str(set_shot["key"])

	if side == moment_side and not set_shot.is_empty() and _moment_ready():
		var close := current_quarter >= 4 and absi(score(side) - score(opp)) <= 18
		# Asked about as often as before: a set shot is under half the marks,
		# and a game has more chains than the 180 this was set for.
		if moment_rng.randf() < (1.0 if close else 0.49 * 180.0 / float(T["chains_per_game"])
				* (SET_SHOT_SHARE / set_share())):
			_offer_set_shot(side, shot_fp, shooter, defender, set_shot, feeder)
			return {"outcome": "moment", "fp": shot_fp, "actor": shooter}

	var roll := rng.randf()
	if roll < goal_p + behind_p or not set_shot.is_empty():
		_shot(side, shooter, not set_shot.is_empty(), "goal" if roll < goal_p else ("behind" if roll < goal_p + behind_p else ""),
				float(set_shot.get("metres", -1.0)), str(set_shot.get("key", "")))
	if roll < goal_p:
		_t(side, "goals")
		_p(shooter, "goals")
		_assist(side, feeder, shooter)
		_scored(side, 6, shooter)
		q_goals[current_quarter - 1][side] += 1
		_score_run(side)
		_emit("goal", side, shot_fp, shooter, _scoreline(side, "GOAL"))
		events[events.size() - 1]["set"] = not set_shot.is_empty()
		if crumbed:
			events[events.size() - 1]["crumb"] = true
		_trait_note(shooter)
		_tag_shot(not set_shot.is_empty())
		return {"outcome": "score", "fp": 0.0, "actor": shooter}
	if roll < goal_p + behind_p:
		_t(side, "behinds")
		_p(shooter, "behinds")
		_scored(side, 1, shooter)
		q_behinds[current_quarter - 1][side] += 1
		_emit("behind", side, shot_fp, shooter, _scoreline(side, "Behind"))
		events[events.size() - 1]["set"] = not set_shot.is_empty()
		if crumbed:
			events[events.size() - 1]["crumb"] = true
		_tag_shot(not set_shot.is_empty())
		return {"outcome": "behind", "fp": kick_in_fp(side), "actor": shooter}

	# A spoil puts it on the deck rather than in the defender's hands: the
	# forwards crumb it now and then and snap, otherwise the defence clears.
	if spoilt and not marked:
		var crumb := _crumb(side, fp)
		if not crumb.is_empty():
			return crumb

	# Spoiled to the deck in the pocket, nobody clean: a ball-up inside 50.
	if spoilt and not marked and lockup_rng.randf() < _tv("LOCKUP_SPOIL", LOCKUP_SPOIL) * _wx("lockup"):
		return {"outcome": "stoppage", "fp": fp, "actor": defender}
	# The defence has it. Its rebound 50 is whoever's kick or handball takes
	# it out of defensive 50 (play_chain), not the contest's.
	# The spare wins the contest only when he got the fist to it; reaching
	# the contest is not winning it. Otherwise the defender in it does. The
	# intercept is his, as before (the stat definition is unchanged).
	var taker = roamer if (roaming and spoiler == roamer) else defender
	_intercept(opp, taker, not spoilt, not matched.is_empty() or roaming)
	# Spoiled to the deck: whoever wins the ground ball has it, not the
	# spoiler by right (he can still be the one there). His first touch is
	# the next chain's first disposal. Drawn on gather_rng, so every other
	# pick's dice are where they were.
	if spoilt and not marked and spoiler != null:
		# The defenders are the ones at the fall of the ball in their own
		# 50; the best user of it among them tends to get there first.
		var near := []
		for p in (squads[opp] as Squad).ground:
			if str(p["role"]) == "DEF":
				near.append(p)
		_gathering = true
		var gatherer = pick_carrier(opp, fp, near)
		_gathering = false
		if gatherer == null:
			gatherer = taker
		_won_back["gatherer"] = str(gatherer.get("id", ""))
		var sn := GameDB.player_display_name(taker)
		var gn := GameDB.player_display_name(gatherer)
		_emit("rebound", opp, fp, gatherer,
				("%s spoils it and wins it off the deck" % sn) if gatherer == taker
				else ("%s spoils it, %s wins it off the deck" % [sn, gn]))
		return {"outcome": "turnover", "fp": fp, "actor": gatherer}
	var tn := GameDB.player_display_name(taker)
	_emit("rebound", opp, fp, taker, ("%s marks it in defence" % tn) if bool(_won_back.get("marked", false))
			else ("%s wins it back in defence" % tn))
	return {"outcome": "turnover", "fp": fp, "actor": taker}


## The ball off a spoil, on the ground inside 50: a crumbing forward (the
## small forwards who hunt it) wins it now and then and snaps. {} when the
## defence clears it or the snap misses everything.
func _crumb(side: int, fp: float) -> Dictionary:
	var crumber = _ground_forward(side)
	if crumber == null or rng.randf() >= CRUMB_P * (0.7 + 0.6 * _a(crumber, "pressure") / 100.0):
		return {}
	var snap := shot_chance(side, crumber, false, false) * CRUMB_SNAP
	var behind_p: float = float(_rates()["inside50_behind"]) * (0.80 + 0.40 * _a(crumber, "goalkicking") / 100.0)
	var r := rng.randf()
	_gain(side, crumber, "gb")
	_shot(side, crumber, false, "goal" if r < snap else ("behind" if r < snap + behind_p else ""))
	if r < snap:
		_t(side, "goals")
		_p(crumber, "goals")
		_scored(side, 6, crumber)
		q_goals[current_quarter - 1][side] += 1
		_score_run(side)
		_emit("goal", side, fp, crumber, _scoreline(side, "GOAL"))
		events[events.size() - 1]["crumb"] = true
		_trait_note(crumber)
		_tag_shot(false)
		return {"outcome": "score", "fp": 0.0, "actor": crumber}
	if r < snap + behind_p:
		_t(side, "behinds")
		_p(crumber, "behinds")
		_scored(side, 1, crumber)
		q_behinds[current_quarter - 1][side] += 1
		_emit("behind", side, fp, crumber, _scoreline(side, "Behind"))
		events[events.size() - 1]["crumb"] = true
		_tag_shot(false)
		return {"outcome": "behind", "fp": kick_in_fp(side), "actor": crumber}
	return {}


## Who is first to a ball on the deck inside 50: forwards first (small ones
## most), a mid at the fall of the ball; not `exclude`, who brought it down.
func _ground_forward(side: int, exclude := ""):
	var group := []
	for p in (squads[side] as Squad).ground:
		if str(p["id"]) != exclude:
			group.append(p)
	return _weighted_roles(group, "pressure", CRUMB_ROLES, 2.0, side, "crumb", GROUND_SIZES)


## Who crumbs off a spoil: forwards first, a mid at the fall of the ball.
const CRUMB_ROLES := {"FWD": 1.0, "MID": 0.15, "RUCK": 0.1, "DEF": 0.03}
const CRUMB_P := 0.30     # of spoils that do not score, before the crumber's pressure
const CRUMB_SNAP := 0.85  # a snap off the deck, against an unmarked shot
## How much more often a Crumber is the one at the fall of the ball.
const CRUMBER_AT_FEET := 2.0


## Who attends a centre bounce for `side`: the ruck who contests it and the
## three inside midfielders on the ground (the best contested players among
## the mids not on a wing). Deterministic: no dice.
func _centre_attendees(side: int) -> Array:
	var sq: Squad = squads[side]
	var out: Array = _contestant(sq).duplicate()
	var mids := []
	for p in sq.ground:
		if str(p["role"]) == "MID" and not Roles.on_wing(p) and not out.has(p):
			mids.append(p)
	mids.sort_custom(func(a, b): return _a(a, "contested") > _a(b, "contested"))
	for p in mids.slice(0, 3):
		out.append(p)
	return out


## The centre bounce for `side` as MatchSim will play it: the ruck who goes up
## ({} with no one to) and the inside midfielders who attend, best first. The
## centre-bounce scene shows exactly these players and never picks its own.
## Read-only: no dice.
func bounce_attendees(side: int) -> Dictionary:
	var ruck := _contestant(squads[side])
	return {"ruck": ruck[0] if not ruck.is_empty() else {},
			"mids": _centre_attendees(side).slice(ruck.size())}


## Possession won from the opposition (a forced turnover, a rebound out of
## defence): an intercept, and an intercept mark when he took it cleanly -
## judged from stat_rng, so play is unchanged.
func _intercept(side: int, who, could_mark: bool, contested := false) -> void:
	if who == null or (who as Dictionary).is_empty():
		return
	_t(side, "intercepts")
	_p(who, "intercepts")
	_won_back = {"side": side, "id": str(who.get("id", ""))}
	# Whether he marked it or gathered it off the spill: a better reader of
	# the ball marks more of them. A mark is a mark: he takes the next kick
	# (the next chain starts from him, _chain_from["marked"]).
	# could_mark: it came off the other side's kick inside 50, so their plan's
	# intercept cost counts (CustomPlan "icept"), as on every intercept mark.
	if could_mark and mark_rng.randf() < 0.35 * (0.5 + _a(who, "intercept") / 100.0) * _wx("aerial") * _gt(1 - side, "icept"):
		_t(side, "marks")
		_p(who, "marks")
		_won_back["marked"] = true
		_won_back["contested"] = contested
		if zone_intercepts:
			_t(side, "intercept_marks")
			_p(who, "intercept_marks")
		if contested:
			_t(side, "contested_marks")
			_p(who, "contested_marks")


## How a chain's first carrier came by the ball (POSSESSION_GAINS): the
## clearing player won it at the stoppage; a teammate he fed received it; no
## clearance means a scramble on the ground. A free is won in a contest; an
## intercept is a contested ball unless he marked it. A kick-in played on is
## an uncontested possession; a kick-in kicked straight in is not one.
func _first_gain(carrier, cleared, is_kick_in: bool) -> String:
	if is_kick_in:
		return "up"
	match chain_origin:
		"centre", "stoppage":
			if cleared == null:
				return "gb"
			return "cp" if str(cleared.get("id", "")) == str(carrier.get("id", "")) else "up"
		"free":
			return "cp"
		"turnover":
			if bool(_chain_from.get("marked", false)):
				return "cp" if bool(_chain_from.get("contested", false)) else "up"
			return "gb"
	return "gb"


## One possession: contested or uncontested, and a ground-ball get when it
## was won off the deck. Bookkeeping only.
func _gain(side: int, carrier, how: String) -> void:
	if how == "":
		return
	if how == "up":
		_t(side, "uncontested_possessions")
		_p(carrier, "uncontested_possessions")
		return
	_t(side, "contested_possessions")
	_p(carrier, "contested_possessions")
	if how == "gb":
		_t(side, "ground_ball_gets")
		_p(carrier, "ground_ball_gets")


## Run and carry (director, 2026-10-07: running bounces must be real): a
## carrier with space - not tackled or rushed, not kicking in, going forward
## from outside his forward 50 - sometimes takes on the space and runs with
## it before he disposes of it, likelier and further the better he carries
## it. A run is distance covered with the ball, angled across the ground as
## much as forward, so the ground the disposal gained is unchanged and the
## match plays exactly as before. He bounces it every BOUNCE_EVERY metres.
## The disposal's event carries "run" (metres) for the pitch.
const BOUNCE_EVERY := 15.0
const RUN_P := 0.03

func _run_and_carry(side: int, carrier, gained: float, pressed: bool, is_kick_in: bool, ev: int, atk_fp: float) -> void:
	if carrier == null or pressed or is_kick_in or gained <= 0.0:
		return
	if atk_fp >= float(_rates()["forward50_line"]):
		return
	var carry := _a(carrier, "carry") / 100.0
	if run_rng.randf() >= RUN_P * (0.3 + 1.4 * carry) * _wx("run"):
		return
	# Rounded first, so the bounces credited are the ones the event's run says (29.96 m
	# was one bounce in the stats and two on the event).
	var run := snappedf(run_rng.randf_range(10.0, 25.0) + 20.0 * carry * run_rng.randf(), 0.1)
	var n := int(run / BOUNCE_EVERY)
	if ev >= 0 and ev < events.size():
		(events[ev] as Dictionary)["run"] = run
	if n > 0:
		_t(side, "running_bounces", n)
		_p(carrier, "running_bounces", n)


## A kick at goal: shots, and set shots apart. `result` is "goal", "behind"
## or "" (it missed everything or fell short). `spot` is where a set shot came
## from, for the balance harness only: a SET_BANDS_ON key ("pocket" is the tight
## angle), "free" for a free kick, "lead" for a played-on mark, "" otherwise.
## A general-play shot is logged only when the sim plays one out: an unmarked
## entry that scores nothing is not told apart from no shot at all.
func _shot(side: int, shooter, set_shot: bool, result: String, metres := -1.0, spot := "") -> void:
	if shooter == null:
		return
	shot_log.append([side, 1 if set_shot else 0, metres if set_shot else -1.0, result, spot if set_shot else ""])
	_t(side, "shots")
	_p(shooter, "shots")
	if set_shot:
		_p(shooter, "set_shots")
		if result == "goal":
			_p(shooter, "set_goals")
		elif result == "behind":
			_p(shooter, "set_behinds")


## A score: its points by how the chain began (score sources), and one score
## involvement for everyone who touched the ball in the chain.
func _scored(side: int, points: int, scorer) -> void:
	_t(side, "score_from_" + chain_origin, float(points))
	_swing_momentum(side, MOMENTUM_GOAL if points >= 6 else MOMENTUM_BEHIND)
	if scorer != null:
		_chain_touch[str(scorer["id"])] = scorer
	for id in _chain_touch:
		var p: Dictionary = _chain_touch[id]
		if _on_ground(side, str(id)).is_empty():
			continue
		_p(p, "score_involvements")


## A score swings momentum to `side`: less the nearer it already is to the
## cap, more when it is turning the other side's run.
func _swing_momentum(side: int, amount: float) -> void:
	var s := 1.0 if side == 0 else -1.0
	if s * momentum < 0.0:
		# Turning a side that has run away with it is harder.
		amount *= 1.0 - runaway_hold * runaway()
	momentum = clampf(momentum + s * amount * (1.0 - s * momentum), -1.0, 1.0)


## Front-runners (an own plan's strength, CustomPlan): the run of play counts
## more for a side well in front. 1.0 for everyone else.
func _front_run() -> float:
	if momentum == 0.0:
		return 1.0
	return _gt(0 if momentum > 0.0 else 1, "momentum")


## How far the side with the run of play has run away with it, 0..1: 0 unless
## that side leads by more than runaway_lead, 1 at runaway_lead + RUNAWAY_SPAN
## or more.
func runaway() -> float:
	if momentum == 0.0:
		return 0.0
	var lead := float(score(0) - score(1)) * signf(momentum)
	return clampf((lead - runaway_lead) / RUNAWAY_SPAN, 0.0, 1.0)


## Who made the spoil, smother or shepherd: mostly defenders, sometimes a
## ruck or a mid back helping. A credit only, drawn from stat_rng.
func _one_percenter(side: int):
	var group: Array = (squads[side] as Squad).ground
	var total := 0.0
	var weights := []
	for p in group:
		var x := float(ONE_PCT_ROLES.get(str(p["role"]), 0.0)) * (0.5 + _a(p, "intercept") / 100.0)
		weights.append(x)
		total += x
	var r := stat_rng.randf() * total
	for i in range(group.size()):
		r -= float(weights[i])
		if r <= 0.0:
			return group[i]
	return group[group.size() - 1]


## A goal assist: the last disposal to the goalkicker, only when the goal
## is kicked (never for the kicker himself).
func _assist(side: int, from, to) -> void:
	if from == null or (from as Dictionary).is_empty() or str(from["id"]) == str(to["id"]):
		return
	_t(side, "goal_assists")
	_p(from, "goal_assists")


## Who a free kick was paid to: an opponent at the contest, weighted like the
## pressure (who is near the ball in that zone). Drawn from stat_rng, so the
## match itself plays out exactly as before.
func _free_to(side: int, against_fp: float):
	var w: Dictionary = PRESS_ZONES[_press_zone(against_fp)]
	var group: Array = (squads[side] as Squad).ground
	var total := 0.0
	var weights := []
	for p in group:
		var x := float(w.get(str(p["role"]), 0.0)) + 0.05
		weights.append(x)
		total += x
	var r := stat_rng.randf() * total
	for i in range(group.size()):
		r -= float(weights[i])
		if r <= 0.0:
			return group[i]
	return group[group.size() - 1]


## Marks the score just logged as a set shot (from a mark) or a shot in
## open play, so the match view stages one and not the other.
func _tag_shot(set_shot: bool) -> void:
	(events[events.size() - 1] as Dictionary)["set_shot"] = set_shot


## Shot quality from the inside-50 kick: 0.94x from a poor creator, 1.06x
## from an elite one (1.0 at 50).
const FEED_BASE := 0.94
const FEED_SLOPE := 0.12


## The goal chance for a shot. With `credit`, the tactical, fatigue and
## call multipliers are also logged as expected points in `impact`.
func shot_chance(side: int, shooter: Dictionary, marked: bool, spoilt: bool, credit := false,
		feeder = null, defender = null) -> float:
	var T := _rates()
	var opp := 1 - side
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]
	var goal_p := float(T["inside50_goal"])
	if weather == "windy":
		if current_quarter > 4:
			# Extra time is two short halves, an end each: the breeze evens out.
			goal_p *= (BREEZE_WITH + BREEZE_AGAINST) * 0.5
		else:
			goal_p *= BREEZE_WITH if with_breeze(side) else BREEZE_AGAINST
	goal_p *= 0.80 + 0.40 * _a(shooter, "goalkicking") / 100.0
	goal_p *= 1.16 if marked else 0.74
	goal_p *= 0.82 + 0.36 * _a(shooter, "accuracy") / 100.0
	if spoilt and not marked:
		goal_p *= 0.58
	goal_p *= 0.90 + 0.20 * atk.attack / 100.0
	# The delivery inside 50: a creative kick makes the shot a better one.
	if feeder != null:
		goal_p *= FEED_BASE + FEED_SLOPE * _a(feeder, "creating") / 100.0
	goal_p *= 1.06 - 0.12 * dfn.defence / 100.0
	if credit:
		# What fresh legs would have given, for the Legs line.
		var fresh := goal_p * (0.80 + 0.40 * float(shooter["attr"]["goalkicking"]) / 100.0) \
				/ (0.80 + 0.40 * _a(shooter, "goalkicking") / 100.0) \
				* (0.82 + 0.36 * float(shooter["attr"]["accuracy"]) / 100.0) \
				/ (0.82 + 0.36 * _a(shooter, "accuracy") / 100.0)
		_credit(side, "legs", 6.0 * (goal_p - fresh))
	var before := goal_p
	var own := _pv(side, "goal")
	# The press closes the corridor: half the attacking plan's edge.
	if own > 1.0 and _pv(opp, "press") > 1.0:
		own = 1.0 + (own - 1.0) * 0.5
	goal_p *= own * _ar(side, "goal")
	if credit:
		_credit(side, "gameplan", 6.0 * (goal_p - before))
	before = goal_p
	# Controlled Tempo picks the press apart and is too slow to punish an
	# attacking side on the rebound; everyone else meets both in full.
	if _plan(side) != "controlled":
		goal_p *= _pv(opp, "opp_goal")
		goal_p *= _pv(opp, "exposed") * _ar(opp, "exposed")
	# This chain broke their press: the defence it runs at is outnumbered.
	if _broke_press == side and _pv(opp, "press") > 1.0:
		goal_p *= PRESS_BROKEN_EXPOSED
	if credit:
		_credit(opp, "gameplan", 6.0 * (before - goal_p))
	before = goal_p
	# Own plans (CustomPlan): the shooter's, then the defence's. Booked to the
	# game plan, as any plan's work is.
	goal_p *= _gt(side, "goal")
	if credit:
		_credit(side, "gameplan", 6.0 * (goal_p - before))
	before = goal_p
	goal_p *= _gt(opp, "opp_goal")
	if _broke_cluster == side:
		goal_p *= _gt(opp, "broken")
	if credit:
		_credit(opp, "gameplan", 6.0 * (before - goal_p))
	before = goal_p
	var tr := 1.0
	if _trait(shooter, "sharpshooter"):
		tr *= 1.06
	if not marked and _trait(shooter, "crumber"):
		tr *= 1.12
	if feeder != null and _trait(feeder, "playmaker"):
		tr *= 1.05
	if synergies[side].has("tall_small"):
		tr *= Traits.power("tall_small")
	goal_p *= tr
	if credit:
		_credit(side, "traits", 6.0 * (goal_p - before))
	before = goal_p
	var dtr := 1.0
	if defender != null and _trait(defender, "lockdown"):
		dtr *= 0.96
	elif not _midfield_minder(side, shooter).is_empty():
		dtr *= 0.96
	if synergies[opp].has("intercept_wall"):
		dtr *= Traits.power("intercept_wall")
	goal_p *= dtr
	if credit:
		_credit(opp, "traits", 6.0 * (before - goal_p))
	before = goal_p
	var call_mult := 1.0
	# Throw numbers at it: more of your shots go in. Slow it down: fewer
	# shots at goal, both ends - the game goes quiet. Flood: numbers back.
	if _burst(side, "surge"):
		call_mult *= SURGE_GOAL
	if _burst(side, "hold"):
		call_mult *= HOLD_GOAL
	if _burst(side, "flood"):
		call_mult *= FLOOD_GOAL
	if _burst(side, "push"):
		call_mult *= PUSH_GOAL
	goal_p *= call_mult
	if credit:
		_credit(side, "bursts", 6.0 * (goal_p - before))
	before = goal_p
	var opp_mult := 1.0
	if _burst(opp, "flood"):
		opp_mult *= FLOOD_OPP_GOAL
	if _burst(opp, "hold"):
		opp_mult *= HOLD_OPP_GOAL
	if _burst(opp, "stack"):
		opp_mult *= STACK_OPP_GOAL
	if _burst(opp, "surge"):
		opp_mult *= SURGE_OPP_GOAL
	if _burst(opp, "push"):
		opp_mult *= PUSH_OPP_GOAL
	goal_p *= opp_mult
	if credit:
		_credit(opp, "bursts", 6.0 * (before - goal_p))
	return goal_p


func _scoreline(side: int, prefix: String) -> String:
	var opp := 1 - side
	return "%s - %s %d.%d (%d) def %s %d.%d (%d)" % [
			prefix, squads[side].name,
			goals(side), behinds(side), score(side),
			squads[opp].name, goals(opp), behinds(opp), score(opp)]


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
func run() -> Dictionary:
	while current_quarter <= 4:
		run_quarter()
	if needs_extra_time():
		run_extra_time()
	return result()


## Play a whole quarter. A live match can instead step through it with
## begin_quarter() / continue_quarter() / end_quarter(), stopping for moments;
## anything still pending here takes the default call.
func run_quarter() -> Dictionary:
	if not _q_active:
		begin_quarter()
	while not continue_quarter():
		resolve_moment(int(pending_moment.get("default", 0)))
	return end_quarter()


func quarter_in_progress() -> bool:
	return _q_active


func begin_quarter() -> void:
	# A turn announced at this break plays from this bounce (row 160).
	_apply_weather_turn()
	var T := _rates()
	_fit_cache.clear()
	# A tired-star call lasts to the break.
	_held.clear()
	if current_quarter > 1:
		for id in energy:
			energy[id] = minf(float(energy_caps.get(id, 100.0)), float(energy[id]) + ENERGY_BREAK_RECOVER)
	# AI clubs pick their plan for the quarter from the score and what they
	# have seen (no dice: replays are unchanged). Why each plays his plan
	# (ai_why) is read at the same moment, for the break sheet; "" for a side
	# you coach.
	var why := ["", ""]
	for side in range(2):
		if (squads[side] as Squad).ai_plans:
			why[side] = ai_why(side)
			set_tactics(side, ai_tactics(side))
			if current_quarter > 1:
				_ai_rematch(side)
		if str(season_plans[side]) != "":
			set_rotation_policy(side, auto_rotation(side, str(season_plans[side])))
	_own_plan_injuries()
	# Snapshot the plans in force this quarter - after the AI has picked its
	# own, so the break says what they actually ran, not last quarter's plan.
	# Before any rolls; duplicates only, no RNG draws.
	tactics_history.append({
		"quarter": current_quarter,
		"plans": [(tactics[0] as Dictionary).duplicate(), (tactics[1] as Dictionary).duplicate()],
		"rotations": [str(rotation_policy[0]), str(rotation_policy[1])],
		"why": why,
	})
	_q_active = true
	_q_i = 0
	_q_count = floori(float(T["chains_per_game"]) / 4.0)
	_moments_this_q = 0
	# Every quarter starts with a centre bounce.
	at_centre = true
	kick_in = false
	boundary_throw_in = false


## Play on until the quarter's chains are done (true) or a moment needs the
## coach (false: see pending_moment, then resolve_moment()).
func continue_quarter() -> bool:
	var T := _rates()
	while _q_i < _q_count:
		if not pending_moment.is_empty():
			return false
		current_minute = (current_quarter - 1) * 30 + int(30 * _q_i / maxi(1, _q_count)) + 1
		if moment_side >= 0 and _boundary_moment():
			return false
		_rival_ballup()
		_q_i += 1
		_play_one_chain(T)
		if not pending_moment.is_empty():
			return false
	return pending_moment.is_empty()


func end_quarter() -> Dictionary:
	var quarter := current_quarter
	_q_active = false
	momentum *= MOMENTUM_BREAK
	# A moment card's call is for a passage of play: the break ends it.
	bursts = [{}, {}]
	quarter_teams.append({
		"quarter": quarter,
		"team": [team_stats[0].duplicate(), team_stats[1].duplicate()],
		"players": player_stats.duplicate(true),
		"score": [score(0), score(1)],
		"goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
		"impact": impact.duplicate(true),
	})
	_emit("quarter", -1, fp, null, "End of quarter %d - %s %d.%d (%d) | %s %d.%d (%d)" % [
		quarter, squads[0].name, goals(0), behinds(0), score(0),
		squads[1].name, goals(1), behinds(1), score(1)])
	current_quarter += 1
	if quarter == 3:
		_three_quarter_sub()
	if quarter < 4:
		for side in range(2):
			if _assisted(side):
				_assistant_calls(side)
	if quarter == 4:
		if needs_extra_time():
			# No siren: the pitch keeps going into extra time.
			_emit("quarter", -1, 0.0, null,
					"Scores level at full time - we are going to extra time!")
		else:
			_emit_full_time("Full time")
	return result()


## True once a finals match is level after four quarters and extra time has
## not been played yet.
func needs_extra_time() -> bool:
	return finals_mode and extra_time_allowed and not extra_time_played and current_quarter > 4 \
			and score(0) == score(1)


## AFL finals extra time: two short halves (three minutes plus time on),
## then, if still level, the next score wins. Only ever runs after Q4 of a
## level final, so home-and-away matches and calibration are untouched.
func run_extra_time() -> Dictionary:
	if not needs_extra_time():
		return result()
	extra_time_played = true
	current_quarter = 5
	q_goals.append([0, 0])
	q_behinds.append([0, 0])
	var T := _rates()
	var per_half: int = maxi(4, roundi(float(T["chains_per_game"]) / 4.0 * 0.15))
	at_centre = true
	kick_in = false
	boundary_throw_in = false
	_play_chains(per_half, 120, 4)
	_emit("quarter", -1, fp, null, "Extra time, half time - %s %d | %s %d" % [
			squads[0].name, score(0), squads[1].name, score(1)])
	at_centre = true
	kick_in = false
	boundary_throw_in = false
	_play_chains(per_half, 124, 4)
	if score(0) == score(1):
		_emit("quarter", -1, fp, null, "Still level - next score wins!")
		# A new period: it opens with a centre bounce like any other.
		at_centre = true
		kick_in = false
		boundary_throw_in = false
		var guard := 0
		while score(0) == score(1) and guard < golden_point_chains:
			current_minute = 128 + int(guard / 4)
			_play_one_chain(T)
			guard += 1
		if score(0) == score(1):
			# A final can't end level: past the cap, the side with more
			# inside-50s (home side on a tie) is awarded a rushed behind.
			var i50_0 := float(team_stats[0].get("inside50", 0.0))
			var i50_1 := float(team_stats[1].get("inside50", 0.0))
			var side := 1 if i50_1 > i50_0 else 0
			_t(side, "behinds")
			# Awarded, not played: no chain earned it, so the last chain's
			# touches and origin get no credit for it.
			_chain_touch = {}
			chain_origin = "awarded"
			_scored(side, 1, null)
			q_behinds[current_quarter - 1][side] += 1
			_emit("behind", side, fp, null, _scoreline(side, "Rushed behind"))
	_emit_full_time("Full time (after extra time)")
	return result()


const GOLDEN_POINT_CHAINS := 60
## The golden-point cap for this match (tests lower it to reach the fallback).
var golden_point_chains := GOLDEN_POINT_CHAINS


func _emit_full_time(prefix: String) -> void:
	_emit("final", -1, 0.0, null, "%s - %s %d.%d (%d) | %s %d.%d (%d)" % [
			prefix, squads[0].name, goals(0), behinds(0), score(0),
			squads[1].name, goals(1), behinds(1), score(1)])


## Play `count` possession chains, stamping minutes across `span` minutes
## from `minute_base`. Shared by the four quarters and extra time; the RNG
## call order is exactly the original quarter loop's.
func _play_chains(count: int, minute_base: int, span: int) -> void:
	var T := _rates()
	for i in range(count):
		current_minute = minute_base + int(span * i / maxi(1, count)) + 1
		_play_one_chain(T)


func _play_one_chain(T: Dictionary) -> void:
	_note_tactics()
	# Every restart is a new chain: a free kick's set shot never inherits a
	# broken press from the chain before (qa, W7 of #647).
	_broke_press = -1
	_broke_cluster = -1
	# A kick-in after a behind is not a stoppage: no ruck contest, no clearance.
	# A boundary throw-in is: it always starts with a contested stoppage.
	var from_kick_in := kick_in
	var from_boundary := boundary_throw_in
	kick_in = false
	boundary_throw_in = false
	# The stoppage roll is drawn exactly as before, so the play RNG stays where
	# it was; it no longer turns a won ball into a ball-up: after an intercept
	# or a free the winner plays on (match flow, director 2026-10-10). A ball-up
	# called in play (a tackle held, a contest locked up) always is one.
	var roll := 1.0
	if not (at_centre or from_boundary) and not from_kick_in:
		roll = rng.randf()
	var won_ball := _prev_end == "turnover" or _prev_end == "free"
	var locked := _prev_locked
	var stoppage := at_centre or from_boundary or locked \
			or (not won_ball and roll < float(T["stoppage_share"]))
	_prev_locked = false
	var side: int
	var start_fp: float
	if stoppage:
		# A centre bounce only after a score or at the start of a quarter;
		# any other stoppage is a ball-up where play stopped, logged so the
		# pitch can stage it there.
		start_fp = 0.0 if at_centre else fp
		_ruck_tap()
		side = contest_winner(false, start_fp)
		if not at_centre and not from_boundary:
			# Boundary exits already logged the throw-in when the ball crossed;
			# this chain is just the contested restart at that same spot.
			_emit("ballup", -1, start_fp, null, "Ball-up")
	else:
		start_fp = fp
		side = next_side if next_side >= 0 else contest_winner(true, fp)

	if stoppage:
		chain_origin = "centre" if at_centre else "stoppage"
	elif from_kick_in:
		chain_origin = "kick_in"
	elif _prev_end == "free" or _prev_end == "turnover":
		chain_origin = _prev_end
	else:
		chain_origin = "general"
	if audit_chains_on:
		var ak := "%s <- %s, %s" % [chain_origin, _prev_end if _prev_end != "" else "-",
				"flip" if (_audit_last_side >= 0 and side != _audit_last_side) else "keep"]
		audit_chains[ak] = int(audit_chains.get(ak, 0)) + 1
		_audit_last_side = side
	_chain_touch = {}
	_chain_from = _won_back if chain_origin == "turnover" else {}
	_won_back = {}
	_ball_lost_by = _lost_by if chain_origin == "general" else -1
	_lost_by = -1
	var res := {}
	_last_disp = {}
	var taker := _free_set_taker(side, start_fp) if chain_origin == "free" else {}
	_free_taker = {}
	if not taker.is_empty():
		res = _free_set_shot(side, start_fp, taker)
	else:
		res = play_chain(side, start_fp, stoppage, from_kick_in)
	var outcome: String = res["outcome"]
	fp = res["fp"]
	if outcome == "moment":
		# The chain ends on the coach's call: resolve_moment() finishes it.
		return

	# Goal: centre bounce. Behind: the other side kicks in (fp is already the
	# goal square). A free goes to whoever it was paid to: usually the other
	# side, but a free to the side in possession (high contact on the
	# carrier, a forward held in a marking contest) keeps the ball with it.
	# A boundary exit restarts with a contested throw-in at the same fp.
	at_centre = (outcome == "score")
	kick_in = (outcome == "behind")
	boundary_throw_in = (outcome == "boundary")
	next_side = (1 - side) if ["turnover", "behind", "free"].has(outcome) else -1
	if outcome == "free" and res.has("free_side"):
		next_side = int(res["free_side"])
	_prev_end = outcome
	_prev_locked = outcome == "stoppage" and res.get("actor") != null
	if outcome == "loose":
		_lost_by = side
	if outcome == "score":
		fp = 0.0
	# A ball-up called in play (a tackle held, a contest locked up) is how the
	# chain ended: no end-of-chain error turns it into a turnover or a free.
	if ["boundary", "free", "loose"].has(outcome) or _prev_locked:
		_after_chain()
		return

	# End-of-chain error: a clanger, sometimes a free kick against.
	var cw := _clanger_weights(side)
	var clanger_p := float(T["clanger_per_chain"]) / HOTHEAD_BASE
	var hot_mult := float(cw[1])
	_credit(side, "traits", -clanger_p * (hot_mult - 1.0) * CLANGER_VALUE)
	clanger_p *= hot_mult
	var cl_mult := _pv(side, "clangers") * _ar(side, "clangers")
	_credit(side, "gameplan", clanger_p * (1.0 - cl_mult) * CLANGER_VALUE)
	clanger_p *= cl_mult
	var gt_cl := _gt(side, "clangers")
	_credit(side, "gameplan", clanger_p * (1.0 - gt_cl) * CLANGER_VALUE)
	clanger_p *= gt_cl
	var pep_cl := _pep_mult(side, "clangers")
	_credit(side, "pep", clanger_p * (1.0 - pep_cl) * CLANGER_VALUE)
	clanger_p *= pep_cl
	var form_cl := 1.0 - FORM_COMPOSURE * float(form[side])
	_credit(side, "form", clanger_p * (1.0 - form_cl) * CLANGER_VALUE)
	clanger_p *= form_cl
	if _burst(side, "hold"):
		_credit(side, "bursts", clanger_p * (1.0 - HOLD_CLANGERS) * CLANGER_VALUE)
		clanger_p *= HOLD_CLANGERS
	if rng.randf() < clanger_p:
		var err = _pick(squads[side].ground, cw[0])
		# Row 12: the error is the last disposal's (when the chain ran out on
		# one), and the line says why. The pick above is still drawn, so the
		# dice are where they were.
		var cause := ""
		if not _last_disp.is_empty():
			cause = clanger_why(_last_disp, weather, outcome)
			if cause != "" and float(absi(hash([_clanger_seed, events.size()])) % 1000) / 1000.0 >= clanger_blame_share(weather):
				cause = ""
			# Only his own side's player can be blamed (the chain may have changed hands).
			if cause != "" and (squads[side].ground.has(_last_disp["carrier"])
					or squads[side].bench.has(_last_disp["carrier"])):
				err = _last_disp["carrier"]
			else:
				cause = ""
		_t(side, "clangers")
		_p(err, "clangers")
		var clanger_line: String = CLANGER_WHY[cause] if cause != "" else "%s gives away a clanger"
		_emit("clanger", side, fp, err, clanger_line % GameDB.player_display_name(err))
		if cause != "":
			events[events.size() - 1]["why"] = cause
		_lost_by = side
		# After a behind the kick-in comes first, and after a goal the centre
		# bounce (director, 2026-11-03): no free is paid over either.
		if not kick_in and not at_centre and free_rng.randf() < float(T["clanger_is_free"]) * GENERIC_FREE_MULT:
			var recipient = _free_to(1 - side, fp if side == 0 else -fp)
			next_side = 1 - side
			_prev_end = "free"
			var why := _chain_free_cause(side, err, recipient, start_fp, fp)
			fp = _award_context_free(1 - side, float(why["fp"]), why["offender"], why["recipient"],
					str(why["cause"]), str(why["label"]), str(why["context"]))
			# Play restarts from the free (and any 50), not another bounce.
			at_centre = false
			boundary_throw_in = false
		elif zone_intercepts and next_side < 0 and not at_centre and not kick_in \
				and rng.randf() < CLANGER_TAKEN:
			_clanger_taken(side, fp)
	_after_chain()


## The director (2026-10-06): a kick that turns it over goes to the other side,
## as in real football, not to a 50/50 loose ball. Whoever is in that part of
## the ground takes it (AERIAL_ROLES), an intercept, and the better readers mark
## it and take the kick.
func _clanger_taken(side: int, at: float) -> void:
	var opp := 1 - side
	var taker = _aerial_defender(opp, at)
	if taker == null:
		return
	_intercept(opp, taker, false)
	next_side = opp
	_prev_end = "turnover"
	_kick_marked(opp, taker, at, rng.randf() < _tv("CLANGER_MARKED", CLANGER_MARKED)
			* (0.6 + 0.8 * _a(taker, "intercept") / 100.0) * _gt(side, "icept"))


## Row 89 (director, 2026-11-06, T8.Q8: midfield intercepts 1.4 a game against
## real 2.5): of general-play kicks that land in the middle third with no
## aerial contest, the share one of the other side's midfielders reads and
## takes outright. Tuned with tools/balance.sh toward Champion Data 2025.
## Retuned with every feature on (2026-11-06): 0.04 gives midfielders 2.58 a game over 1,000 matches
## (real 2.5), from 3.03 at 0.10.
const MID_KICK_INTERCEPT := 0.04
## The share of a chain's time a midfield intercept gives back (it cut the
## passage short). Measured: none drops disposals; a whole chain lifts
## clearances and hitouts (more ball-ups).
const MID_GIVE_BACK := 0.5
var _mid_give_back := 0.0
var mid_ic_rng := RandomNumberGenerator.new()


## The midfield kick-intercept: `side`'s kick at `at` is taken
## by one of the other side's midfielders on the ground, the better readers
## more often; the better readers also mark it (as a clanger taken does).
func _mid_kick_intercept(side: int, at: float) -> Dictionary:
	var opp := 1 - side
	var mids := _by_roles((squads[opp] as Squad).ground, ["MID"])
	if mids.is_empty():
		return {}
	# Its own dice, so the rest of the match draws as it would have.
	var total := 0.0
	for p in mids:
		total += pow(maxf(1.0, _a(p, "intercept")), AERIAL_READ)
	var r := mid_ic_rng.randf() * total
	var taker = mids[mids.size() - 1]
	for p in mids:
		r -= pow(maxf(1.0, _a(p, "intercept")), AERIAL_READ)
		if r <= 0.0:
			taker = p
			break
	_intercept(opp, taker, false)
	_kick_marked(opp, taker, at, mid_ic_rng.randf() < _tv("CLANGER_MARKED", CLANGER_MARKED)
			* (0.6 + 0.8 * _a(taker, "intercept") / 100.0) * _gt(side, "icept"))
	# The passage it cut short did not use all its share of the quarter: that
	# time is played (MID_GIVE_BACK of a chain each), so the match keeps its
	# length of play.
	_mid_give_back += _tv("MID_GIVE_BACK", MID_GIVE_BACK)
	if _mid_give_back >= 1.0:
		_mid_give_back -= 1.0
		_q_count += 1
	return {"outcome": "turnover", "fp": at, "actor": taker}


## A kick that turned over, taken by `taker`: when `marked`, he took it on the
## mark (an intercept mark, and he takes the next kick).
func _kick_marked(side: int, taker, at: float, marked: bool) -> void:
	if not marked:
		return
	_won_back["marked"] = true
	_t(side, "marks")
	_p(taker, "marks")
	_t(side, "intercept_marks")
	_p(taker, "intercept_marks")
	_emit("mark", side, at, taker, "%s intercepts it on the mark" % GameDB.player_display_name(taker))
	var ev: Dictionary = events[events.size() - 1]
	ev["general_play"] = true
	ev["intercept"] = true


## Of the clangers not paid as frees, the share the other side takes outright
## (the rest stay a contest: a fumble, a ball knocked loose), and of those, the
## share taken on the mark by an average reader. Calibrated with
## tools/audit/intercept_impl.gd against Champion Data 2025.
const CLANGER_TAKEN := 1.0
const CLANGER_MARKED := 0.3
## Of rushed kicks that go straight to the opposition, the share an average
## reader marks (match flow: they replace the clanger after a ball-up, which
## gave defenders most of their intercept marks).
const PRESS_KICK_MARKED := 0.4


## The 18 on-ground players per side, so the pitch view can draw real
## guernseys and the match stats screen can show a real box score.
func rosters() -> Array:
	var out := []
	for sq in squads:
		var r := []
		var side := out.size()
		var on: Array = (sq as Squad).ground.duplicate()
		for p in (sq as Squad).bench:
			if _played[side].has(str(p["id"])):
				on.append(p)
		on.append_array(injured_off[side])
		on.append_array(subbed_off[side])
		for p in on:
			r.append({
				"id": str(p["id"]), "num": int(p["num"]),
				"name": GameDB.player_display_name(p), "role": str(p["role"]),
				# "role" is the slot he filled today; this is his own position.
				"list_role": str(p.get("own_role", p["role"])),
				"club": _side_club(side, p), "overall": int(p["overall"]),
				# Presentation only: the view puts the named wings on the wings.
				"line": str(p.get("line", "")),
			})
		out.append(r)
	return out


## Every goal and behind in order, small enough to keep for every match of
## the season (the box score's worm, BoxScore): [quarter, minute, side,
## 1 goal / 0 behind, kicker id, 1 set shot / 0].
func scoring_log() -> Array:
	var out := []
	for e in events:
		var kind := str(e.get("kind", ""))
		if kind == "goal" or kind == "behind":
			out.append([int(e["q"]), int(e["min"]), int(e["side"]), 1 if kind == "goal" else 0,
					str(e.get("player_id", "")), 1 if bool(e.get("setshot", false)) or bool(e.get("set", false)) else 0])
	return out


func result() -> Dictionary:
	var s0 := score(0)
	var s1 := score(1)
	var winner := 0 if s0 > s1 else (1 if s1 > s0 else -1)
	var qsc := []
	# Four quarters, then extra time (if played) as a fifth period, so the
	# periods always add up to the final score.
	for q in range(q_goals.size()):
		qsc.append([q_goals[q][0] * 6 + q_behinds[q][0],
				q_goals[q][1] * 6 + q_behinds[q][1]])
	return {
		"roster": rosters(),
		"bench": opening_bench.duplicate(true),
		"score": [s0, s1],
		"goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
		"quarters": qsc,
		"scoring": scoring_log(),
		"q_goals": q_goals.duplicate(true),
		"q_behinds": q_behinds.duplicate(true),
		"team": [team_stats[0].duplicate(), team_stats[1].duplicate()],
		"players": player_stats.duplicate(true),
		"exertion": exertion.duplicate(),
		"events": events,
		"winner": winner,
		"margin": absi(s0 - s1),
		"home": squads[0].code,
		"away": squads[1].code,
		"tactics_history": tactics_history.duplicate(true),
		"weather": weather,
		# The day's turn at a break, once played (row 160): where it started and
		# which break it turned at; "" and 0 for a day that held.
		"weather_start": weather_start,
		"weather_turned_after": weather_turned_after,
		# Which side kicks with the breeze in the first quarter, for the ground's flags and
		# the big screen's arrow after the match (looks only: set from the seed at the start).
		"breeze_side": breeze_side,
		"timeline": timeline.duplicate(true),
		"quarter_teams": quarter_teams.duplicate(true),
		"extra_time": extra_time_played,
		"impact": impact.duplicate(true),
		"impact_by": impact_by.duplicate(true),
		"moments": moments.duplicate(true),
		"interchanges": interchanges.duplicate(),
		"duels": duel_log.duplicate(true),
		"roam_pairs": roam_pairs.duplicate(true),
		"duel_changes": duel_changes.duplicate(true),
		"matchups": duels.duplicate(true),
		"interceptor": interceptor.duplicate(),
		"interceptor_changes": interceptor_changes.duplicate(true),
		"injuries": injuries.duplicate(true),
		"reports": reports.duplicate(true),
		"synergies": synergies.duplicate(true),
		"tag_drops": tag_drops.duplicate(true),
	}


# ---------------------------------------------------------------------------
# Legs: fatigue and rotations
# ---------------------------------------------------------------------------
const ENERGY_DRAIN := 0.9            # per chain on the ground, before modifiers
const ENERGY_BENCH_RECOVER := 4.0    # per chain on the bench
const ENERGY_BREAK_RECOVER := 20.0   # at each quarter break
const ROTATE_EVERY := 3              # chains between rotation checks, at CADENCE_CHAINS a game
## The chain count the rotation cadence and call lengths were set for: they scale
## with chains_per_game so a match's interchanges and a call's minutes stay the
## same when chains get shorter (match flow, 2026-10-10).
const CADENCE_CHAINS := 200.0


## `n` chains at CADENCE_CHAINS a game, in this match's chains.
func _chains_for(n: int) -> int:
	return maxi(1, roundi(float(n) * float(_rates()["chains_per_game"]) / CADENCE_CHAINS))
const ROLE_DRAIN := {"MID": 1.25, "RUCK": 1.15, "DEF": 0.85, "FWD": 0.9}
## GPS-style distance covered. A full-game player at the base rate covers
## about 14.8 km before role and tactical modifiers; rotations bring the
## typical match-day player into the AFL-like 10-14 km range.
const GPS_METRES_PER_CHAIN := 82.0
const GPS_ROLE_MULT := {"MID": 1.08, "RUCK": 1.00, "DEF": 0.95, "FWD": 0.92}
const GPS_WING_MULT := 1.12
const GPS_TOUCH_MULT := 1.04
const GPS_FOCUS_MULT := 1.06
const GPS_TAGGER_MULT := 1.08
const GPS_TAGGED_MULT := 1.06
const STAR_OVR := 80
## Energy below which a player is rotated off: stars are ridden harder.
const ROTATION_POLICIES := {
	"hard": {"label": "Protect freshness", "role": 80.0, "star": 68.0,
			"text": "Anyone tiring comes off early, your stars included: fresh legs all day, less time on the ground for your best."},
	"normal": {"label": "Balanced rotations", "role": 70.0, "star": 50.0,
			"text": "Rotate the group; your stars stay on a little longer than the rest."},
	"stars": {"label": "Prioritise key players", "role": 68.0, "star": 25.0,
			"text": "Your stars stay on until they are cooked: more of their time on the ground, but they fade late."},
}
## fit(): effective-attribute multiplier. 0.80 + 0.25 x energy puts an
## average match (~80 energy) at 1.0: fresh 1.05, cooked (30) 0.875.
const FIT_BASE := 0.80
const FIT_SLOPE := 0.25


func fit(p: Dictionary) -> float:
	var id: String = p["id"]
	var e: float = energy.get(id, 100.0)
	var hit = _fit_cache.get(id)
	if hit != null and hit[0] == e:
		return hit[1]
	var f := FIT_BASE + FIT_SLOPE * e / 100.0
	if (current_quarter >= 4 or finals_mode) and _trait(p, "big_game"):
		f += 0.05
	f += ClubLife.form(p) + float(_arch_form.get(id, 0.0))
	f -= float(_fam_cut.get(id, 0.0))
	_fit_cache[id] = [e, f]
	return f


## The trait that played a part in the goal just logged, for the feed: a
## Crumber's goal off the deck, a Big-game player's goal when he lifts (the
## last quarter, a final). Presentation only.
func _trait_note(p) -> void:
	if p == null:
		return
	var ev: Dictionary = events[events.size() - 1]
	if bool(ev.get("crumb", false)) and _trait(p, "crumber"):
		ev["trait"] = "crumber"
	elif (current_quarter >= 4 or finals_mode) and _trait(p, "big_game"):
		ev["trait"] = "big_game"


func _trait(p: Dictionary, key: String) -> bool:
	var id: String = p.get("id", "")
	var known = _traits.get(id)
	if known == null:
		known = Traits.of(p)
		_traits[id] = known
	return known.has(key)


## A player's attribute as he is playing right now.
func _a(p: Dictionary, key: String) -> float:
	return float(p["attr"][key]) * fit(p)


## The back zone's role weights for a pick on ball use among `group`: each
## line's CARRY_BACK_RETUNED weight scaled by its players' intercept^2 over
## their ball use^2, so each line takes the share of the ball row 92's
## intercept pick gave it, and within a line the better ball user gets more.
## Pure: no dice, no tuned number.
func _back_roles(group: Array) -> Dictionary:
	var by_int := {}
	var by_use := {}
	for p in group:
		var r := str(p["role"])
		by_int[r] = float(by_int.get(r, 0.0)) + pow(maxf(1.0, _a(p, "intercept")), 2.0)
		by_use[r] = float(by_use.get(r, 0.0)) + pow(maxf(1.0, _ball_use(p)), 2.0)
	var out := {}
	for r in CARRY_BACK_RETUNED:
		var w := float(CARRY_BACK_RETUNED[r])
		out[r] = w * float(by_int[r]) / float(by_use[r]) if by_use.has(r) else w
	return out


## Rebound 50 (Champion Data: moving the ball from the defensive 50 into the
## midfield), director 2026-11-07 "credit rebounds": every exit counts, by
## whoever takes it out, his kick, his handball or his run through a tackle.
## `from_atk` and `to_atk` are the ball's spot before and after, from the
## side's own view; `how` is the exit route (rebound_log). The one place a
## rebound 50 is credited.
func _rebound_exit(side: int, carrier, from_atk: float, to_atk: float, how: String) -> void:
	var f50 := float(Ratings.T["forward50_line"])
	if from_atk <= -f50 and to_atk > -f50:
		_t(side, "rebounds")
		_p(carrier, "rebounds")
		rebound_log[side][how] = int((rebound_log[side] as Dictionary).get(how, 0)) + 1
		_exit_open = true
		_post_exit = true


## His use of the ball as he is playing right now: the kick-in taker's and
## the back-zone carrier's rating (BALL_USE).
func _ball_use(p: Dictionary) -> float:
	return BALL_USE_CARRY * _a(p, "carry") + BALL_USE_DISPOSAL * _a(p, "disposal")


## Mean fit of the on-ground midfielders and rucks: who wins the stoppages.
func _mid_fit(side: int) -> float:
	var total := 0.0
	var n := 0
	for p in (squads[side] as Squad).ground:
		if str(p["role"]) == "MID" or str(p["role"]) == "RUCK":
			total += fit(p)
			n += 1
	return total / float(n) if n > 0 else 1.0


## The rotations a competent coach runs this quarter (director, 2026-11-03:
## the break call is cut, rotations follow the season plan and the legs).
## A club developing and managing its list protects freshness, as does any
## side on a hot day; a close last quarter, or the second half of a final,
## rides the stars (a star running on empty then brings the "rest him now"
## moment); otherwise balanced rotations.
func auto_rotation(side: int, season_plan := "steady") -> String:
	if side < 0 or side > 1:
		return "normal"
	var close := absi(score(side) - score(1 - side)) <= AUTO_RIDE_MARGIN
	if close and (current_quarter >= 4 or (finals_mode and current_quarter >= 3)):
		return "stars"
	if season_plan == "develop" or weather == "hot":
		return "hard"
	return "normal"


## Within this margin (points) a late quarter is close enough to ride the stars.
const AUTO_RIDE_MARGIN := 18


func set_rotation_policy(side: int, key: String) -> void:
	if side >= 0 and side <= 1 and ROTATION_POLICIES.has(key):
		rotation_policy[side] = key


func _after_chain() -> void:
	momentum *= lerpf(MOMENTUM_DECAY, runaway_decay, runaway())
	# Distance, drain and recovery were set for 180 chains a game: a chain is
	# a share of the game's minutes, so per-game loads stay the same.
	var per_chain := 180.0 / float(_rates()["chains_per_game"])
	for side in range(2):
		var sq: Squad = squads[side]
		# Distance and fatigue both respond to the plan's tempo, pep talk and
		# "throw numbers at it". Running Machine / Engine reduce fatigue only:
		# good runners still log the kilometres they actually cover.
		# Bring the heat burns legs, not extra kilometres: its pace is fatigue only.
		var heat_legs := _pep_mult(side, "pace") if _pep(side) == "heat" else 1.0
		var movement_pace := _pv(side, "pace") * (1.0 if _pep(side) == "heat" else _pep_mult(side, "pace"))
		if _burst(side, "surge"):
			movement_pace *= SURGE_PACE
		var fatigue_pace := movement_pace * heat_legs * _ar(side, "legs") * _gt(side, "legs")
		if weather == "hot":
			fatigue_pace *= HOT_DRAIN
		if synergies[side].has("running_machine"):
			fatigue_pace *= Traits.power("running_machine")
		var tagger_id := ""
		if _tag_id(side) != "":
			var tagger = tagger_of(side)
			if tagger != null:
				tagger_id = str(tagger["id"])
		# Asked once a side, not once a player (the same answers every time).
		var focus_now := _focus_slots(side)
		var tagged_id := _tag_id(1 - side)
		var holding := _burst(side, "hold")
		var flooding := _burst(side, "flood")
		var stacking := _burst(side, "stack")
		var pushing := _burst(side, "push")
		for p in sq.ground:
			var id := str(p["id"])
			var role := str(p["role"])
			var gps := GPS_METRES_PER_CHAIN * per_chain * float(GPS_ROLE_MULT.get(role, 1.0)) * movement_pace
			if Roles.on_wing(p):
				gps *= GPS_WING_MULT
			if _chain_touch.has(id):
				gps *= GPS_TOUCH_MULT
			if focus_now.has(id):
				gps *= GPS_FOCUS_MULT
			if id == tagger_id:
				gps *= GPS_TAGGER_MULT
			if id == tagged_id:
				gps *= GPS_TAGGED_MULT
			# Short-term calls move specific lines as football would: slowing
			# down cuts running; a flood asks backs/mids to fold behind the
			# ball; stacking a stoppage pulls mids/rucks into the contest.
			if holding:
				gps *= 0.84
			elif flooding:
				gps *= 1.10 if role == "MID" else (1.07 if role == "DEF" or role == "RUCK" else 0.94)
			elif stacking:
				gps *= 1.08 if role == "MID" or role == "RUCK" else 0.98
			elif pushing:
				# Numbers forward: the midfield and the backs run up past the ball.
				gps *= 1.08 if role == "MID" or role == "DEF" else 1.0
			_t(side, "distance_run", gps)
			_p(p, "distance_run", gps)

			var dur := float((p["attr"] as Dictionary).get("durability", 70.0))
			var d := ENERGY_DRAIN * per_chain * float(ROLE_DRAIN.get(role, 1.0)) 					* (1.2 - 0.4 * dur / 100.0) * fatigue_pace * Workload.drain_mult(p)
			if _trait(p, "engine"):
				d *= 0.75
			exertion[id] = float(exertion.get(id, 0.0)) + d
			energy[id] = maxf(5.0, float(energy.get(id, 100.0)) - d)
		for p in sq.bench:
			var id := str(p["id"])
			energy[id] = minf(float(energy_caps.get(id, 100.0)), float(energy.get(id, 100.0)) + ENERGY_BENCH_RECOVER * per_chain)
		_fit_cache.clear()
		var b: Dictionary = bursts[side]
		for k in b.keys():
			b[k] = int(b[k]) - 1
			if int(b[k]) <= 0:
				b.erase(k)
	_chain_no += 1
	_check_injuries()
	if _chain_no % _chains_for(ROTATE_EVERY) == 0:
		for side in range(2):
			_auto_rotate(side)


## Who will be hurt in this match, and when: one Injuries.roll per player
## in the 23 (the same chance as the old after-the-siren roll), at a minute
## of the four quarters.
func _plan_injuries() -> void:
	for side in range(2):
		var sq: Squad = squads[side]
		for p in sq.ground + sq.bench:
			var inj := Injuries.roll(injury_rng, p)
			# A Hardline coach's extra injuries come off their own dice, so a
			# match without one plays out exactly as before (row 119).
			if inj.is_empty() and _ar(side, "inj") > 1.0 and arch_rng.randf() < _ar(side, "inj") - 1.0:
				inj = Injuries.roll(arch_rng, p)
			if inj.is_empty():
				continue
			inj["side"] = side
			inj["id"] = str(p["id"])
			inj["at"] = injury_rng.randi_range(2, 118)
			_injury_plan.append(inj)


## An own plan's "Injury toll" (CustomPlan "inj"): a side on it this quarter
## takes extra injuries, a quarter's share of the match's, on their own dice
## (custom_rng), so a match without one plays out exactly as before.
func _own_plan_injuries() -> void:
	if current_quarter > 4:
		return
	for side in range(2):
		var extra := _gt(side, "inj") - 1.0
		if extra <= 0.0:
			continue
		var sq: Squad = squads[side]
		for p in sq.ground + sq.bench:
			if custom_rng.randf() >= extra / 4.0:
				continue
			var inj := Injuries.roll(custom_rng, p)
			if inj.is_empty():
				continue
			inj["side"] = side
			inj["id"] = str(p["id"])
			inj["at"] = (current_quarter - 1) * 30 + custom_rng.randi_range(2, 28)
			_injury_plan.append(inj)


## An injury whose time has come: on the ground, he goes off for good and
## the best bench player for his spot comes on (none left: he plays on
## hurt). One resting on the bench who has played takes no further part; one
## yet to come on is hurt when he does.
func _check_injuries() -> void:
	for inj in _injury_plan.duplicate():
		if current_minute < int(inj["at"]):
			continue
		var side := int(inj["side"])
		var sq: Squad = squads[side]
		var id := str(inj["id"])
		var gi := -1
		for i in range(sq.ground.size()):
			if str((sq.ground[i] as Dictionary)["id"]) == id:
				gi = i
		var bi := -1
		for i in range(sq.bench.size()):
			if str((sq.bench[i] as Dictionary)["id"]) == id:
				bi = i
		if gi < 0 and (bi < 0 or not _played[side].has(id)):
			continue
		_injury_plan.erase(inj)
		var hurt: Dictionary = sq.ground[gi] if gi >= 0 else sq.bench[bi]
		var on := ""
		if gi >= 0 and not sq.sub.is_empty():
			# The substitute takes the hurt man's place; he is off for good.
			on = str((sq.sub[0] as Dictionary)["id"])
			_bring_sub(side, gi, true)
			(injured_off[side] as Array).append(hurt)
			var rec_s := {"side": side, "id": id, "q": current_quarter, "min": current_minute,
					"weeks": int(inj["weeks"]), "kind": str(inj["kind"]), "on": on}
			injuries.append(rec_s)
			_emit("injury", side, fp, hurt, "%s is hurt: %s" % [GameDB.player_display_name(hurt), Injuries.wording(str(inj["kind"]))])
			events[events.size() - 1]["on"] = on
			events[events.size() - 1]["on_sub"] = "medical" if EraRules.medical_sub() else "substitute"
			_refill_duel(side, id)
			_drop_tag_on(id)
			continue
		if gi >= 0:
			var rep := _bench_for(side, str(hurt["role"]), 0.0)
			if rep >= 0:
				on = str((sq.bench[rep] as Dictionary)["id"])
				_swap(side, gi, rep)
				bi = rep
		var gone := false   # none left on the bench: he plays on hurt, match-ups and tag kept
		if bi >= 0 and str((sq.bench[bi] as Dictionary)["id"]) == id:
			sq.bench.remove_at(bi)
			(injured_off[side] as Array).append(hurt)
			gone = true
		var rec := {"side": side, "id": id, "q": current_quarter, "min": current_minute,
				"weeks": int(inj["weeks"]), "kind": str(inj["kind"]), "on": on}
		injuries.append(rec)
		_emit("injury", side, fp, hurt, "%s is hurt: %s" % [GameDB.player_display_name(hurt), Injuries.wording(str(inj["kind"]))])
		events[events.size() - 1]["on"] = on
		if gone:
			_refill_duel(side, id)
			_drop_tag_on(id)


## A tag on a player gone off hurt ends with him: no side keeps a hidden tag
## on someone no longer playing (the next break offers a fresh choice; an AI
## side picks again at its next call).
func _drop_tag_on(id: String) -> void:
	for side in range(2):
		if _tag_id(side) == id:
			var t: Dictionary = (tactics[side] as Dictionary).duplicate()
			t["tag_id"] = ""
			tactics[side] = t


## A tag goes on a midfielder: someone in a midfield slot today who is a
## midfielder by position (midfielder_on_ground), or on the bench by the slot
## he last filled. Anyone gone off hurt or not in the match is not a target.
func tag_target_ok(owner: int, id: String) -> bool:
	var g := _on_ground(owner, id)
	if not g.is_empty():
		return can_be_tagged(g)
	for p in (squads[owner] as Squad).bench:
		if str(p["id"]) == id:
			return can_be_tagged(p)
	return false


## End a tag whose man is still in the match but no longer a midfielder, and
## keep a record for the break to say so. A man gone off hurt is already
## reported as injured, so his tag just ends.
func _drop_tag(side: int, id: String) -> void:
	tactics[side]["tag_id"] = ""
	if taking_part(1 - side, id):
		tag_drops.append({"side": side, "id": id, "q": current_quarter})


## Check both sides' tags again: a rotation or a position change can leave a
## tag on someone who is no longer a midfielder.
func _recheck_tags() -> void:
	for side in range(2):
		var tag := _tag_id(side)
		if tag != "" and not tag_target_ok(1 - side, tag):
			var t: Dictionary = (tactics[side] as Dictionary).duplicate()
			tactics[side] = t
			_drop_tag(side, tag)


## Still taking part in the match: on the ground or on the bench, not gone
## off hurt.
func taking_part(side: int, id: String) -> bool:
	var sq: Squad = squads[side]
	for p in sq.ground + sq.bench:
		if str(p["id"]) == id:
			return true
	return false


## A player gone off hurt leaves the match-ups: a key forward's direct
## opponent is freed, and a matched defender's forward goes to the next
## defender on the ground in the default order (not recorded as a coach's
## change). The order of the match-ups is kept.
func _refill_duel(side: int, gone: String) -> void:
	(duels[1 - side] as Dictionary).erase(gone)
	var d: Dictionary = duels[side]
	for fid in d.keys():
		if str(d[fid]) != gone:
			continue
		var used := {}
		for f in d:
			used[str(d[f])] = true
		# The loose man has no forward of his own.
		used[str(interceptor[side])] = true
		var next := ""
		for p in Matchups.defenders((squads[side] as Squad).ground):
			if not used.has(str(p["id"])):
				next = str(p["id"])
				break
		if next == "":
			d.erase(fid)
		else:
			d[fid] = next


## One interchange per check: the most tired player past his policy's line
## comes off for the freshest bench player who can play the spot.
func _auto_rotate(side: int) -> void:
	var sq: Squad = squads[side]
	var policy: Dictionary = ROTATION_POLICIES.get(rotation_policy[side], ROTATION_POLICIES["normal"])
	var worst := -1
	var worst_e := 101.0
	var named_tagger := str((tactics[side] as Dictionary).get("tagger_id", "")) if _tag_id(side) != "" else ""
	for i in range(sq.ground.size()):
		var p: Dictionary = sq.ground[i]
		if str(_held.get(str(p["id"]), "")) == "keep":
			continue
		# The tagger the coach named stays on the ground while his tag is on
		# (director, 2026-10-14); he still tires, and injuries still apply.
		if named_tagger != "" and str(p["id"]) == named_tagger:
			continue
		var e := float(energy.get(str(p["id"]), 100.0))
		var line := float(policy["star"]) if int(p["overall"]) >= STAR_OVR else float(policy["role"])
		if e < line and e < worst_e:
			worst = i
			worst_e = e
	if worst < 0:
		_first_stint(side)
		return
	var bi := _bench_for(side, str((sq.ground[worst] as Dictionary)["role"]), 85.0, true)
	if bi >= 0:
		_swap(side, worst, bi)


## Every interchange player gets on the ground in an AFL match. From the second
## quarter, when nobody is past his line (a side whose legs last, such as a
## Running machine line), a bench player who has not yet played goes on for
## the most tired man in a spot he can play; the usual rotations then take
## over. The same for every club; a rest the coach called still holds, and the
## named tagger and play-through picks keep their own rules.
func _first_stint(side: int) -> void:
	if current_quarter < 2:
		return
	var sq: Squad = squads[side]
	var named := str((tactics[side] as Dictionary).get("tagger_id", "")) if _tag_id(side) != "" else ""
	var focus := {}
	for slot in FOCUS_SLOTS:
		var fid := str((tactics[side] as Dictionary).get(slot, ""))
		if fid != "":
			focus[fid] = slot
	for bi in range(sq.bench.size()):
		var on: Dictionary = sq.bench[bi]
		var on_id := str(on["id"])
		if _played[side].has(on_id) or str(_held.get(on_id, "")) == "rest":
			continue
		var best := -1
		var best_e := 101.0
		var best_fits := false
		for gi in range(sq.ground.size()):
			var p: Dictionary = sq.ground[gi]
			var pid := str(p["id"])
			if str(_held.get(pid, "")) == "keep" or (named != "" and pid == named):
				continue
			var role := str(p["role"])
			var focus_slot := str(focus.get(on_id, ""))
			if focus_slot != "" and not (FOCUS_SLOT_ROLES[focus_slot] as Array).has(role):
				continue
			if named != "" and on_id == named and role != "MID":
				continue
			var fits := Traits.plays(on, role) or focus_slot != ""
			var e := float(energy.get(pid, 100.0))
			if (fits and not best_fits) or (fits == best_fits and e < best_e):
				best = gi
				best_e = e
				best_fits = fits
		if best >= 0:
			_swap(side, best, bi)
			return


## The freshest bench player (at or above `min_energy`) for a ground role,
## or -1. Natural or secondary role first (his own positions, never the slot
## he last filled); any bench player as a fallback.
## A back slot waits for a defender: one short of `min_energy` (by up to
## DEF_TIRED_GAP) still goes on before a fresh man from another line, and
## while a defender on the bench is more tired than that, a routine change in
## the back line waits. Another line's player goes into the back line only
## with no defender on the bench.
## `rotation`: a routine interchange, which leaves a rested star on the bench.
## The coach's named tagger goes back on only in a midfielder's place, and
## first when one comes off, so he picks the tag up again (tagger_of).
## Each play-through pick (focus_mid/fwd/def) goes back on the same way: only
## in a spot his call works from (FOCUS_SLOT_ROLES), which counts as his own
## line, and first when one does; on every path (a forced change puts him in
## another line only as the last man on the bench).
const DEF_TIRED_GAP := 25.0


func _bench_for(side: int, role: String, min_energy: float, rotation := false) -> int:
	var sq: Squad = squads[side]
	var named := str((tactics[side] as Dictionary).get("tagger_id", "")) if _tag_id(side) != "" else ""
	var focus := {}
	for slot in FOCUS_SLOTS:
		var fid := str((tactics[side] as Dictionary).get(slot, ""))
		if fid != "":
			focus[fid] = slot
	var best := -1
	var best_score := -INF
	var best_fits := false
	var def_waiting := false
	for i in range(sq.bench.size()):
		var p: Dictionary = sq.bench[i]
		var e := float(energy.get(str(p["id"]), 100.0))
		if rotation and str(_held.get(str(p["id"]), "")) == "rest":
			continue
		# A play-through pick goes back on only in a spot his call works from,
		# and first when one comes up, so the call never waits from a slot in
		# another line (director, 2026-11-12: the play-through midfielder
		# "spent the whole quarter parked in the goal square"). The line his
		# call names counts as his own, so a coach's out-of-position pick (a
		# forward played through the midfield) goes back on there too. A routine
		# change never puts him in another line; a forced one (an injury, a
		# rest the coach called) does only when no one else is on the bench.
		var focus_slot := str(focus.get(str(p["id"]), ""))
		var in_his_line := focus_slot != "" and (FOCUS_SLOT_ROLES[focus_slot] as Array).has(role)
		var out_of_line := focus_slot != "" and not in_his_line
		if out_of_line and rotation:
			continue
		var fits := Traits.plays(p, role) or in_his_line
		if e < min_energy:
			if role != "DEF" or not fits:
				continue
			if e < min_energy - DEF_TIRED_GAP:
				def_waiting = true
				continue
		var is_named := rotation and named != "" and str(p["id"]) == named
		if is_named and role != "MID":
			continue
		var score := e + (100.0 if fits else 0.0) + (200.0 if is_named or in_his_line else 0.0)
		if out_of_line:
			score -= 1000.0
		if score > best_score:
			best = i
			best_score = score
			best_fits = fits
	if role == "DEF" and def_waiting and not best_fits:
		return -1
	return best


## The substitute of 2011-15 (EraRules, not the medical one) comes on at
## three-quarter time if no injury has called him: the most tired man on the
## ground goes off for good, as clubs used the sub to freshen the last
## quarter. A side with no substitute (every 2026 match) is untouched.
func _three_quarter_sub() -> void:
	if EraRules.medical_sub():
		return
	for side in range(2):
		var sq: Squad = squads[side]
		if sq.sub.is_empty() or sq.ground.is_empty():
			continue
		var gi := 0
		for i in range(1, sq.ground.size()):
			if float(energy.get(str(sq.ground[i]["id"]), 100.0)) < float(energy.get(str(sq.ground[gi]["id"]), 100.0)):
				gi = i
		var off: Dictionary = sq.ground[gi]
		_bring_sub(side, gi)
		(subbed_off[side] as Array).append(off)
		_refill_duel(side, str(off["id"]))
		_drop_tag_on(str(off["id"]))


## The substitute replaces ground player `gi` for the rest of the match (the
## caller decides where the man going off is kept). No interchange counted.
## `injury`: he comes on for a hurt man, whose injury line names him, so his
## own event stays out of the feed (MatchNotes).
func _bring_sub(side: int, gi: int, injury := false) -> void:
	var sq: Squad = squads[side]
	var on: Dictionary = sq.sub[0]
	sq.sub.clear()
	var off: Dictionary = sq.ground[gi]
	var slot := str(off["role"])
	var on_slot: Dictionary = on if str(on["role"]) == slot else Ratings._for_slot(on, slot)
	sq.ground[gi] = on_slot
	var id := str(on["id"])
	energy_caps[id] = Workload.energy_cap(on)
	energy[id] = _start_energy(on)
	_played[side][id] = true
	_fit_cache.clear()
	events.append({
		"q": current_quarter, "min": current_minute, "kind": "sub", "side": side, "fp": fp,
		"name": GameDB.player_display_name(on_slot), "player_id": id,
		"num": int(on["num"]), "off_num": int(off["num"]), "club": _side_club(side, on),
		"substitute": true, "medical": EraRules.medical_sub(), "for_injury": injury,
		"off_name": GameDB.player_display_name(off),
		"text": "%s: %s on for %s" % ["Medical sub" if EraRules.medical_sub() else "Substitute",
				GameDB.player_display_name(on_slot), GameDB.player_display_name(off)],
		"score": [score(0), score(1)], "goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
	})
	_recheck_tags()


func _swap(side: int, gi: int, bi: int) -> void:
	var sq: Squad = squads[side]
	var off: Dictionary = sq.ground[gi]
	var on: Dictionary = sq.bench[bi]
	var slot := str(off["role"])
	var on_slot: Dictionary = on if str(on["role"]) == slot else Ratings._for_slot(on, slot)
	sq.ground[gi] = on_slot
	sq.bench[bi] = off
	interchanges[side] += 1
	_played[side][str(on["id"])] = true
	events.append({
		"q": current_quarter, "min": current_minute, "kind": "sub", "side": side, "fp": fp,
		"name": GameDB.player_display_name(on_slot), "player_id": str(on["id"]),
		"num": int(on["num"]), "off_num": int(off["num"]), "club": _side_club(side, on),
		"text": "Interchange: %s on for %s" % [GameDB.player_display_name(on_slot),
				GameDB.player_display_name(off)],
		"score": [score(0), score(1)], "goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
	})
	# The man who came on may be filling a slot that is not the midfield.
	_recheck_tags()


## Energy for one side, most tired first: [{id, name, num, role, overall,
## energy, on}] with the bench after the ground.
func legs(side: int) -> Array:
	var sq: Squad = squads[side]
	var out := []
	for group in [[sq.ground, true], [sq.bench, false]]:
		var rows := []
		for p in group[0]:
			rows.append({"id": str(p["id"]), "name": GameDB.player_display_name(p),
					"num": int(p["num"]), "role": str(p["role"]), "overall": int(p["overall"]),
					"energy": float(energy.get(str(p["id"]), 100.0)), "on": bool(group[1])})
		rows.sort_custom(func(a, b): return float(a["energy"]) < float(b["energy"]))
		out.append_array(rows)
	return out


# ---------------------------------------------------------------------------
# Match moments
# ---------------------------------------------------------------------------
const MAX_MOMENTS_Q := 2
const MOMENT_GAP := 8                # chains between moments
## A short-term call from a moment card, and how long it lasts (possession
## chains; a quarter is about 45). Long enough to be a passage of play - the
## card says "the next ten minutes" - and every call ends at the break.
## (They lasted 4-8 chains, about two minutes, and measured as no-ops.)
const BURSTS := {
	"stack": {"label": "Stack the stoppage", "chains": 12, "for": "for the next few centre ball-ups"},
	"flood": {"label": "Flood behind the ball", "chains": 45, "for": "for the rest of the quarter"},
	"push": {"label": "Push numbers forward", "chains": 45, "for": "for the rest of the quarter"},
	"surge": {"label": "Throw numbers at it", "chains": 15, "for": "for the next ten minutes"},
	"hold": {"label": "Slow it down", "chains": 15, "for": "for the next ten minutes"},
}


## What each call does while it lasts (the cards say these as percentages,
## GateOdds.burst_lines). Throw numbers: points of win chance at every
## contest, your shots and theirs, and the legs. Slow it down: your shots,
## theirs, clangers and the pressure you feel. Stack: points of win chance at
## a centre bounce (the contest clamp still holds) and their shots. Flood:
## yours and theirs. Slow it down and Flood both cost ground (BACK_GAIN).
## Push numbers forward (row 151) is the flood turned round: your shots and the
## ground you make a kick go up, and so do their shots when they win it back.
const SURGE_CONTEST := 0.03
const SURGE_GOAL := 1.12
const SURGE_OPP_GOAL := 1.25
const SURGE_PACE := 1.3
const HOLD_GOAL := 0.90
const HOLD_OPP_GOAL := 0.85
const HOLD_CLANGERS := 0.75
const HOLD_TAKEN := 0.85
const STACK_CONTEST := 0.10
const STACK_OPP_GOAL := 1.12
const FLOOD_GOAL := 0.90
const FLOOD_OPP_GOAL := 0.80
const BACK_GAIN := 0.85
const PUSH_GOAL := 1.12
const PUSH_OPP_GOAL := 1.25
const PUSH_GAIN := 1.15
## A game's minutes on the clock (four quarters of 30).
const GAME_MINUTES := 120


func _burst(side: int, kind: String) -> bool:
	return (bursts[side] as Dictionary).has(kind)


func _moment_ready() -> bool:
	return moment_side >= 0 and _moments_this_q < MAX_MOMENTS_Q \
			and _chain_no - _last_moment_chain >= MOMENT_GAP and current_quarter <= 4


func _fire(m: Dictionary) -> void:
	m["q"] = current_quarter
	m["min"] = current_minute
	m["side"] = moment_side
	pending_moment = m
	_moments_this_q += 1
	_last_moment_chain = _chain_no


## The late centre-bounce call (the stoppage close games are decided on):
## Q4, the last 20 minutes, at a centre bounce, within two goals, once a
## match (the director's PC playtest, 2026-10-07: it came twice), the
## playtest aid's included.
func _bounce_moment(margin: int) -> bool:
	if current_quarter == 4 and at_centre and current_minute >= 100 and absi(margin) <= 12 \
			and not _asked.has("bounce"):
		_asked["bounce"] = int(_asked.get("bounce", 0)) + 1
		if _asked.has("bounce_playtest"):
			# The playtest aid already asked it. Spend the quarter's call here as
			# the real call would have, so every later call (a set shot most of
			# all) comes exactly as it would have without the aid.
			_moments_this_q += 1
			_last_moment_chain = _chain_no
			return false
		_fire_bounce(margin)
		return true
	return false


## Playtest aid (ARD-M8-007; Settings, "Centre-bounce scene every match"): the
## centre-bounce call comes at the first centre bounce of the last quarter,
## whatever the score or the minute, once a match. It sits outside the
## quarter's calls - their budget and spacing are put back - so every other
## call comes exactly when it would have, and "Play it straight" leaves the
## match as it was. Off by default; set from GameState.
var always_offer_bounce := false


func _playtest_bounce() -> bool:
	if not always_offer_bounce or moment_side < 0 or current_quarter != 4 or not at_centre \
			or _asked.has("bounce_playtest") or _asked.has("bounce"):
		return false
	_asked["bounce_playtest"] = true
	var calls := _moments_this_q
	var last := _last_moment_chain
	_fire_bounce(score(moment_side) - score(1 - moment_side))
	_moments_this_q = calls
	_last_moment_chain = last
	return true


func _fire_bounce(margin: int) -> void:
	var state := "level" if margin == 0 else ("%d up" % margin if margin > 0 else "%d down" % -margin)
	var left: int = current_quarter * 30 - current_minute
	var to_go := EraFootball.clock_minutes(120 - current_minute, season_year)
	var when := "in the last minute" if to_go <= 1 else "with %d minutes left" % to_go
	var title := "Centre ball-up - %s %s" % [state, when]
	# Two distinct calls, each with its own upside and downside and no
	# "Play it straight" (row 15): Flood behind the ball and Push numbers
	# forward (row 151, director 2026-11-10). Unanswered (skipped, auto-played)
	# is no call.
	_fire({"kind": "bounce", "default": -1, "title": title,
		"text": "Set up for the rest of the game.",
		"options": _sized([
			{"key": "flood", "label": "Flood behind the ball",
				"detail": "Numbers behind the ball: they score less easily, and so do you."},
			{"key": "push", "label": "Push numbers forward",
				"detail": "Numbers ahead of the ball: you score more easily, and so do they when they win it back."},
		], left, GateOdds.NONE_COST_BOUNCE)})


## The same late centre ball-up for a rival coach (every club gets the two
## moves; Director Bible 2.35: behind late means more aggressive, protecting a
## narrow lead means safer). Same window as the coach's call (the last quarter,
## the last 20 minutes, a centre ball-up, within two goals, once a match): in
## front he floods behind the ball, behind he pushes numbers forward, level he
## makes no call. From the scoreboard only, no dice. A side you coach is asked
## instead (_bounce_moment) and a simulated side of yours makes no call.
func _rival_ballup() -> void:
	if current_quarter != 4 or not at_centre or current_minute < 100:
		return
	for side in range(2):
		if side == moment_side or not (squads[side] as Squad).ai_plans or _asked.has("rival_bounce|%d" % side):
			continue
		var margin := score(side) - score(1 - side)
		if margin == 0 or absi(margin) > 12:
			continue
		_asked["rival_bounce|%d" % side] = true
		var key := "flood" if margin > 0 else "push"
		_set_burst(side, key)
		_emit("moment", side, fp, null, "%s: %s %s." % [squads[side].name, str(BURSTS[key]["label"]), str(BURSTS[key]["for"])])


## Put a short call on. Flood behind the ball and Push numbers forward are
## opposite set-ups: the new one replaces the other.
func _set_burst(side: int, key: String) -> void:
	var b: Dictionary = bursts[side]
	if key == "push":
		b.erase("flood")
	elif key == "flood":
		b.erase("push")
	b[key] = _chains_for(int(BURSTS[key]["chains"]))


## A risk card's options with what each does for you and what it costs, sized
## from the call's own constants and its length (GateOdds.burst_lines; bible
## §4): "gain" and "cost" lines the card shows under each choice. "none" keeps
## the match as it is and says what that leaves (`none_cost`).
func _sized(options: Array, minutes_left: int, none_cost: String) -> Array:
	for o in options:
		var k := str(o["key"])
		var two: Array = [GateOdds.NONE_GAIN, none_cost] if k == "none" else GateOdds.burst_lines(k, minutes_left, current_quarter >= 4)
		o["gain"] = GateOdds.gain(str(two[0]))
		o["cost"] = GateOdds.cost(str(two[1]))
	return options


func _late_bounce_ready() -> bool:
	return moment_side >= 0 and current_quarter == 4 and _moments_this_q == MAX_MOMENTS_Q \
			and _chain_no - _last_moment_chain >= MOMENT_GAP


## Situations spotted between chains: a hot opposition
## forward, a run of goals against, a tight last-quarter centre bounce.
func _boundary_moment() -> bool:
	if _playtest_bounce():
		return true
	if not _moment_ready():
		# The quarter's calls can be spent before a tight finish arrives: the
		# last quarter keeps one more for the centre bounce, so a close game
		# still gets it (measured: 43% of close finishes got it; 92% now).
		if _late_bounce_ready():
			return _bounce_moment(score(moment_side) - score(1 - moment_side))
		return false
	var me := moment_side
	var opp := 1 - me
	var margin := score(me) - score(opp)
	# No tired-star call: rotations are automatic for both sides (Director Bible
	# 2.60, 2.63 superseded 2026-11-03). Its Keep answer, also the skipped default,
	# held your star on past the line the rival's rotations take theirs off at
	# (fatigue parity, T3.F-defects), so your side now rotates on the same rule.
	# An opposition midfielder kicking a bag: a tag is a midfield job, so
	# only a midfielder can be answered with one.
	for id in player_stats:
		var st: Dictionary = player_stats[id]
		if int(st.get("goals", 0.0)) < 3 or _asked.has("hot|" + str(id)):
			continue
		var hot := _on_ground(opp, str(id))
		if hot.is_empty() or not taggable(hot) or _tag_id(me) == str(id):
			continue
		# The midfielder who would actually go to him (tagger_for). With none of
		# yours on the ground there is no tag to offer: the call waits (not
		# marked asked) until one is back on.
		var minder = tagger_of(me)
		if minder == null:
			continue
		_asked["hot|" + str(id)] = true
		var stopper := GameDB.player_display_name(minder)
		var hot_name := GameDB.player_display_name(hot)
		# The size of the call, from what the sim plays (GateOdds; row 120).
		var on_him: Dictionary = minder
		var kept := GateOdds.tag_kept(on_him, float(energy.get(str(on_him.get("id", "")), 100.0)))
		# A tag already on another of theirs moves if the coach says tag: the card
		# says so, and what leaving it where it is keeps (the answer itself is
		# unchanged: resolve_moment sets the tag on this man either way).
		var tagged := _on_ground(opp, _tag_id(me))
		var on_now := "" if tagged.is_empty() else GameDB.player_display_name(tagged)
		var lines := GateOdds.tag_call_lines(hot_name, stopper, kept, on_now)
		_fire({"kind": "hot", "player_id": str(id), "default": 1,
			"title": "%s has kicked %d" % [hot_name, int(st["goals"])],
			"text": "Their midfielder is hurting you on the scoreboard.",
			"options": [
				{"key": "tag", "label": ("Tag him with %s" if on_now == "" else "Move %s onto him") % stopper,
					"gain": lines["tag_gain"], "cost": lines["tag_cost"]},
				{"key": "leave", "label": "Back your defenders" if on_now == "" else "Leave the tag on %s" % on_now,
					"gain": lines["leave_gain"], "cost": lines["leave_cost"]},
			]})
		return true
	# Three goals in a row against.
	# Once a run: the key is where the run started (their goals before it),
	# so a fourth or fifth goal in the same run asks nothing new. A new run -
	# after you score - can ask again.
	var run_key := "run|%d" % (goals(opp) - int(_run[opp]))
	if _run[opp] >= 3 and not _asked.has(run_key):
		_asked[run_key] = true
		_fire_run_moves(_run[opp])
		return true
	# A tight last-quarter centre bounce.
	return _bounce_moment(margin)


## The run against you as two concrete moves (row 14):
## stack the next centre bounces to win the ball back from the middle, or flood
## behind the ball to stop the goals. Each carries its gain and cost as
## percentages (GateOdds.burst_lines), and neither is called the better. The
## card has no "ride it out": a side that is not asked (a simulated match)
## makes no call, default -1.
func _fire_run_moves(run: int) -> void:
	_fire({"kind": "momentum", "moves": true, "default": -1,
		"title": "They have kicked %d in a row" % run,
		"text": "Two ways to answer it from the next centre bounce.",
		"options": _sized([
			{"key": "stack", "label": "Stack the centre bounce",
				"detail": "Extra numbers at the ball-up."},
			{"key": "flood", "label": "Flood behind the ball",
				"detail": "Everyone back, so they cannot run it in."},
		], current_quarter * 30 - current_minute, GateOdds.NONE_COST_RUN)})


## Lockdown's opponent. A defender's is the forward he stands on the shot
## (the forward-50 defender draw); a midfielder's is one of their
## midfielders: each Lockdown midfielder on the ground picks up their best
## midfielder not already covered (most pressure first, best by rating
## first). Returns the Lockdown midfielder on `shooter` (of `side`), or {}.
func _midfield_minder(side: int, shooter: Dictionary) -> Dictionary:
	if str(shooter.get("role", "")) != "MID":
		return {}
	var minders := []
	for p in (squads[1 - side] as Squad).ground:
		if str(p["role"]) == "MID" and _trait(p, "lockdown"):
			minders.append(p)
	if minders.is_empty():
		return {}
	var mids := _by_roles((squads[side] as Squad).ground, ["MID"])
	mids.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	minders.sort_custom(func(a, b): return _a(a, "pressure") > _a(b, "pressure"))
	for i in range(mini(minders.size(), mids.size())):
		if str(mids[i]["id"]) == str(shooter.get("id", "")):
			return minders[i]
	return {}


func _on_ground(side: int, id: String) -> Dictionary:
	for p in (squads[side] as Squad).ground:
		if str(p["id"]) == id:
			return p
	return {}


## A marked shot inside 50: take it, play on to a teammate, or bomb it long.
func _offer_set_shot(side: int, p_fp: float, shooter: Dictionary, defender, band: Dictionary, feeder = null) -> void:
	var spot := str(band["spot"])
	var dfn: Squad = squads[1 - side]
	var shot_goal := float(band["goal"])
	var shot_behind := float(band["behind"])
	var mate := {}
	for p in _by_roles((squads[side] as Squad).ground, ["FWD", "MID"]):
		if str(p["id"]) != str(shooter["id"]) and (mate.is_empty() or _a(p, "goalkicking") > _a(mate, "goalkicking")):
			mate = p
	var pass_p := clampf(0.50 + 0.35 * _a(shooter, "disposal") / 100.0
			- 0.25 * dfn.def_intercept / 100.0, 0.35, 0.85)
	var mate_goal := _set_goal(clampf(shot_chance(side, mate, true, false) * 1.3, 0.05, 0.9)) if not mate.is_empty() else 0.0
	var bomb_goal := clampf(0.26 + 0.20 * (squads[side] as Squad).fwd_mark / 100.0
			- 0.12 * dfn.def_intercept / 100.0, 0.1, 0.5)
	var options := [
		{"key": "shoot", "label": "Take the shot",
			"detail": chance_words(shot_goal) + ".",
			"goal": shot_goal, "behind": shot_behind},
	]
	if not mate.is_empty():
		options.append({"key": "pass", "label": "Play on to %s" % GameDB.player_display_name(mate),
			"detail": "%s, then he shoots from closer: %s." % [pass_words(pass_p), chance_words(mate_goal).to_lower()],
			"goal": pass_p * mate_goal, "pass": pass_p, "mate_goal": mate_goal,
			"mate_id": str(mate["id"])})
	# "goal" and "behind" are what the coach's default and the Moments line
	# weigh (_option_points), unchanged; the card shows the pack's real dice
	# (bomb_odds) under their own keys.
	var pack := bomb_odds(side, shooter)
	options.append({"key": "bomb", "label": "Bomb it to the goal square",
		"detail": "Into the pack: a forward might mark it or a crumber snap it, but more often the defence clears it.",
		"goal": bomb_goal, "behind": 0.30,
		"show_goal": float(pack["goal"]), "show_behind": float(pack["behind"])})
	# Each option's gain and cost with the odds it plays at (M7, director 2026-11-10).
	for o in options:
		var gc := GateOdds.set_shot_lines(o)
		o["gain"] = gc[0]
		o["cost"] = gc[1]
	_fire({"kind": "set_shot", "default": 0, "player_id": str(shooter["id"]), "band_key": str(band["key"]),
		"defender_id": "" if defender == null else str(defender["id"]), "fp": p_fp,
		"feeder_id": "" if feeder == null else str(feeder["id"]),
		"title": "%s marks %s" % [GameDB.player_display_name(shooter), spot],
		"text": "Your call. %s is %s, and %s." % [GameDB.player_display_name(shooter),
			kick_words(shooter), legs_words(float(energy.get(str(shooter["id"]), 100.0)))],
		"options": options})


## Set shots by where they are kicked from. `acc` is the AFL rate for the
## band (AFL.com.au / Champion Data, 2024 season: 92.2% of set shots from
## 15-30 m directly in front were goals, 73.9% from 30-40 m), `share` how
## often a set shot comes from there. An ordinary kick in an ordinary match
## converts at `acc`; this kicker, his legs, the plans and the defence scale
## it through the marked-entry chance they already give (SET_REF is that
## chance for an ordinary league shot, measured).
const SET_REF := 0.34
## The set-shot share the coach's set-shot call was sized for: the call comes
## up SET_SHOT_SHARE / set_share() as often per marked entry, so it is asked
## about as often in a match as it was at that share.
const SET_SHOT_SHARE := 0.55
## A missed set shot is usually a behind; now and then it falls short or
## goes out on the full.
const SET_MISS_BEHIND := 0.70


## A set shot's goal chance on the day: `goal_p` with the wet's harder kick
## (WEATHER_SIM "set_acc"). Every set shot goes through here: a band from the
## mark, a free kick, a mark in the goal-square pack, the teammate's shot when
## the coach plays on.
func _set_goal(goal_p: float) -> float:
	return clampf(goal_p * _wx("set_acc"), 0.03, 0.97)


## A set shot's behind chance once its goal chance is known: most misses are
## behinds, fewer on a windy day, when more fall short or go out on the full
## (WEATHER_SIM "miss_behind").
func _set_behind(goal_p: float) -> float:
	return (1.0 - goal_p) * SET_MISS_BEHIND * _wx("miss_behind")


## Row 77 (director ruling T8.Q9): real set shots are about 55% of shots
## (Champion Data shot counts, 2026: 5,951 of 10,859; SET_SHOT_EVIDENCE.md
## [WH]), so half the marks inside 50 go back and kick (SET_SHARE_ON), and each
## band converts at the real rate for its distance and angle: goals per set
## shot 2021-25 [ABC], straight in front 20-30 m 85%, 30-40 m 71%, 40-50 m 54%,
## over 50 m 33%; the pocket (10-20 m, wide) the mean of the two wide cells,
## 66% and 55%. Total scoring is held flat by the general-play shot off an
## unmarked entry (SET_GP_SHOT), not by softening the set shot.
const SET_BANDS_ON := [
	{"key": "close", "spot": "from 25 metres, straight in front", "metres": 25.0, "acc": 0.85, "share": 0.20},
	{"key": "front", "spot": "from 35 metres, straight in front", "metres": 35.0, "acc": 0.71, "share": 0.25},
	{"key": "angle", "spot": "from 45 metres on a slight angle", "metres": 45.0, "acc": 0.54, "share": 0.30},
	{"key": "pocket", "spot": "from the pocket, on a tight angle", "metres": 15.0, "acc": 0.605, "share": 0.15},
	{"key": "long", "spot": "from 55 metres out", "metres": 55.0, "acc": 0.33, "share": 0.10},
]
## Tuned on tools/balance.sh match 1000 (2026-11-09): 0.57 and 0.89 put set shots at about 55% of scoring
## shots with total scoring held, after the pressure and carrier changes had moved it to 50%.
const SET_SHARE_ON := 0.57
const SET_GP_SHOT := 0.89


## The share of marks inside 50 that end in a set shot from the mark.
func set_share() -> float:
	return _tv("SET_SHARE_ON", SET_SHARE_ON)


## The bands with this shot's chances filled in: {goal, behind} per band.
static func set_bands(goal_p: float) -> Array:
	var out := []
	for b in SET_BANDS_ON:
		var band: Dictionary = b.duplicate()
		band["goal"] = clampf(float(b["acc"]) * goal_p / SET_REF, 0.03, 0.97)
		band["behind"] = (1.0 - float(band["goal"])) * SET_MISS_BEHIND
		out.append(band)
	return out


## A mark inside 50: a set shot from one of SET_BANDS_ON, or the ball goes on.
## The split keeps the entry's expected goals and behinds exactly what they
## were, so scoring across the league is unchanged; only where they come
## from moves. {"band": {} or the band, "goal", "behind"}.
func _set_shot_split(goal_p: float, behind_p: float) -> Dictionary:
	var bands := set_bands(goal_p)
	var share := set_share()
	var e_goal := 0.0
	var e_behind := 0.0
	for b in bands:
		e_goal += float(b["share"]) * float(b["goal"])
		e_behind += float(b["share"]) * float(b["behind"])
	if shot_rng.randf() < share:
		var r := shot_rng.randf()
		var pick: Dictionary = bands[bands.size() - 1]
		for b in bands:
			r -= float(b["share"])
			if r < 0.0:
				pick = b
				break
		# The wet makes the kick itself harder (row 120), after the expected
		# value above, so the general-play shot does not make it back.
		if _wx("set_acc") != 1.0 or _wx("miss_behind") != 1.0:
			pick = pick.duplicate()
			pick["goal"] = _set_goal(float(pick["goal"]))
			pick["behind"] = _set_behind(float(pick["goal"]))
		return {"band": pick, "goal": pick["goal"], "behind": pick["behind"]}
	var rest := 1.0 - share
	return {"band": {},
			"goal": maxf(0.0, (goal_p - share * e_goal) / rest),
			"behind": maxf(0.0, (behind_p - share * e_behind) / rest)}


## A shot's chance in a coach's words, never a percentage.
static func chance_words(p: float) -> String:
	if p >= 0.65:
		return "He should kick it"
	if p >= 0.5:
		return "Better than even"
	if p >= 0.35:
		return "A coin toss"
	if p >= 0.2:
		return "A tough shot"
	return "A long shot"


## A pass under pressure in words.
static func pass_words(p: float) -> String:
	if p >= 0.75:
		return "The pass is on"
	if p >= 0.6:
		return "The pass usually sticks"
	return "A risky pass"


## How good a kick for goal he is, from his goalkicking and accuracy.
static func kick_words(p: Dictionary) -> String:
	var a: Dictionary = p.get("attr", {})
	var k := 0.5 * float(a.get("goalkicking", 50)) + 0.5 * float(a.get("accuracy", 50))
	if k >= 78:
		return "one of your best kicks for goal"
	if k >= 65:
		return "a reliable kick"
	if k >= 50:
		return "a fair kick"
	return "no natural kick for goal"


## His legs in words.
static func legs_words(e: float) -> String:
	if e >= 75.0:
		return "he is fresh"
	if e >= 55.0:
		return "he is tiring"
	return "his legs are gone"


## Apply the coach's call for the pending moment. Returns the resolved
## moment (with "choice" and "outcome"), and play can continue.
func resolve_moment(choice: int) -> Dictionary:
	if pending_moment.is_empty():
		return {}
	var m := pending_moment
	pending_moment = {}
	var options: Array = m.get("options", [])
	# A call whose default is -1 (the two-choice centre ball-up) can be left
	# unanswered: nothing changes.
	choice = clampi(choice, -1 if int(m.get("default", 0)) < 0 else 0, maxi(0, options.size() - 1))
	var opt: Dictionary = options[choice] if choice >= 0 and not options.is_empty() 			else ({"key": "none", "label": "No call"} if choice < 0 else {})
	var side := int(m.get("side", moment_side))
	var key := str(opt.get("key", ""))
	var outcome := ""
	var points := 0
	match str(m.get("kind", "")):
		"set_shot":
			# The call is worth its expected points against the one the coach
			# did not take (the default, Take the shot), from the chances
			# the card already worked out.
			var opts: Array = m.get("options", [])
			var dflt := int(m.get("default", 0))
			if dflt >= 0 and dflt < opts.size():
				_credit(side, "moments", _option_points(opt) - _option_points(opts[dflt]))
			var res := _resolve_shot(side, m, opt)
			outcome = str(res["text"])
			points = int(res["points"])
		"tired":
			# Both answers hold to the break (the siren in the last quarter).
			var star_id := str(m["player_id"])
			m["disp_at"] = {star_id: float((player_stats.get(star_id, {}) as Dictionary).get("disposals", 0.0))}
			if key == "rest":
				var gi := -1
				var sq: Squad = squads[side]
				for i in range(sq.ground.size()):
					if str((sq.ground[i] as Dictionary)["id"]) == star_id:
						gi = i
				var bi := -1
				for i in range(sq.bench.size()):
					if str((sq.bench[i] as Dictionary)["id"]) == str(m.get("sub_id", "")):
						bi = i
				if bi < 0 and gi >= 0:
					bi = _bench_for(side, str((sq.ground[gi] as Dictionary)["role"]), 0.0)
				if gi >= 0 and bi >= 0:
					var on_id := str((sq.bench[bi] as Dictionary)["id"])
					_swap(side, gi, bi)
					_held[star_id] = "rest"
					m["on_id"] = on_id
					m["disp_at"][on_id] = float((player_stats.get(on_id, {}) as Dictionary).get("disposals", 0.0))
					outcome = "%s comes on; he sits out %s." % [GameDB.player_display_name(_on_ground(side, on_id)),
							"the rest of the match" if current_quarter >= 4 else "the rest of the quarter"]
				else:
					outcome = "No one on the bench to bring on."
			else:
				_held[star_id] = "keep"
				outcome = "He stays out there to the %s." % ("final siren" if current_quarter >= 4 else "break")
		"hot":
			if key == "tag":
				var t: Dictionary = (tactics[side] as Dictionary).duplicate()
				t["tag_id"] = str(m["player_id"])
				tactics[side] = t
				outcome = "Tag on. You can call it off at the break."
			else:
				outcome = "Structure unchanged."
		"momentum", "bounce":
			if BURSTS.has(key):
				_set_burst(side, key)
				outcome = "%s %s." % [str(BURSTS[key]["label"]), str(BURSTS[key]["for"])]
			else:
				outcome = "No change."
	m["choice"] = choice
	m["call"] = key
	m["choice_label"] = str(opt.get("label", ""))
	m["outcome"] = outcome
	m["points"] = points
	moments.append(m)
	_emit("moment", side, fp, null, "Coach's call: %s - %s" % [m["choice_label"], outcome])
	return m


## A set-shot option's expected points, from its card: 6 a goal, 1 a behind.
## Play on: the pass has to land, then his teammate shoots; 0.6 of his
## misses are behinds, as _resolve_shot plays it.
func _option_points(o: Dictionary) -> float:
	var g := float(o.get("goal", 0.0))
	if str(o.get("key", "")) == "pass":
		return g * 6.0 + float(o.get("pass", 0.0)) * (1.0 - float(o.get("mate_goal", 0.0))) * 0.6 * _wx("miss_behind")
	return g * 6.0 + float(o.get("behind", 0.0))


func _resolve_shot(side: int, m: Dictionary, opt: Dictionary) -> Dictionary:
	var opp := 1 - side
	var shooter := _on_ground(side, str(m["player_id"]))
	if shooter.is_empty():
		shooter = (squads[side] as Squad).ground[0]
	var defender := _on_ground(opp, str(m.get("defender_id", "")))
	_chain_touch[str(shooter["id"])] = shooter
	var key := str(opt.get("key", "shoot"))
	fp = float(m.get("fp", fp))
	var kicker := shooter
	# Who gets the assist if it goes through: whoever kicked it in to him,
	# or the man who played on and passed.
	var assist = _on_ground(side, str(m.get("feeder_id", "")))
	var goal_p := float(opt.get("goal", 0.3))
	var behind_p := float(opt.get("behind", 0.2))
	_set_choice = {"key": key}
	if key == "bomb":
		return _bomb(side, shooter, defender)
	if key == "pass":
		_t(side, "disposals")
		_t(side, "kicks")
		_p(shooter, "disposals")
		_p(shooter, "kicks")
		var mate := _on_ground(side, str(opt.get("mate_id", "")))
		_emit("pass", side, fp, shooter, "%s plays on and looks for %s" % [GameDB.player_display_name(shooter),
				GameDB.player_display_name(shooter if mate.is_empty() else mate)])
		if rng.randf() >= float(opt.get("pass", 0.6)):
			return _shot_turnover(side, defender, "%s's pass is intercepted" % GameDB.player_display_name(shooter))
		kicker = shooter if mate.is_empty() else mate
		assist = shooter
		goal_p = float(opt.get("mate_goal", 0.5))
		behind_p = (1.0 - goal_p) * 0.6 * _wx("miss_behind")
		# He leads up into space nearer goal and marks it there.
		fp = _closer_spot(side, fp, PASS_GAIN)
		_t(side, "marks")
		_p(kicker, "marks")
		_emit("receive", side, fp, kicker, "%s marks on the lead" % GameDB.player_display_name(kicker))
		_set_choice["passer_id"] = str(shooter["id"])
		_set_choice["to_id"] = str(kicker["id"])
	return _set_result(side, kicker, assist, defender, goal_p, behind_p, false,
			"lead" if key == "pass" else str(m.get("band_key", "")))


## Where a teammate leads to: `gain` metres nearer goal, no closer than 10 m
## and no further than 30 m out.
func _closer_spot(side: int, from_fp: float, gain: float) -> float:
	var dir := 1.0 if side == 0 else -1.0
	var gl := float(Ratings.T["goal_line"])
	var out := gl - absf(from_fp)
	return dir * (gl - clampf(out - gain, 10.0, 30.0))


## How far nearer goal a played-on pass finds the teammate, in metres.
const PASS_GAIN := 15.0


## A set shot's result: a goal, a behind or the defence rebounds it. Shared by
## the three calls; `crumb` marks a snap off the deck.
func _set_result(side: int, kicker: Dictionary, assist, defender: Dictionary, goal_p: float,
		behind_p: float, crumb: bool, spot := "") -> Dictionary:
	var roll := rng.randf()
	_shot(side, kicker, not crumb, "goal" if roll < goal_p else ("behind" if roll < goal_p + behind_p else ""),
			float(Ratings.T["goal_line"]) - (fp if side == 0 else -fp), spot)
	if roll < goal_p:
		_t(side, "goals")
		_p(kicker, "goals")
		_assist(side, assist, kicker)
		_scored(side, 6, kicker)
		q_goals[current_quarter - 1][side] += 1
		_score_run(side)
		_emit("goal", side, fp, kicker, _scoreline(side, "GOAL"))
		_tag_result(crumb)
		_trait_note(kicker)
		_tag_shot(not crumb)
		_end_moment_chain("score", 0.0, side)
		return {"points": 6, "text": "GOAL to %s!" % GameDB.player_display_name(kicker)}
	if roll < goal_p + behind_p:
		_t(side, "behinds")
		_p(kicker, "behinds")
		_scored(side, 1, kicker)
		q_behinds[current_quarter - 1][side] += 1
		_emit("behind", side, fp, kicker, _scoreline(side, "Behind"))
		_tag_result(crumb)
		_tag_shot(not crumb)
		_end_moment_chain("behind", kick_in_fp(side), side)
		return {"points": 1, "text": "Just a behind from %s." % GameDB.player_display_name(kicker)}
	return _shot_turnover(side, defender, "%s's shot is rebounded" % GameDB.player_display_name(kicker))


## The last event is a set shot's score (or a snap off the pack): flag it.
func _tag_result(crumb: bool) -> void:
	var ev: Dictionary = events[events.size() - 1]
	ev["set"] = not crumb
	# A snap off the pack is general play, though a set-shot choice led to it.
	ev["setshot"] = not crumb
	if crumb:
		ev["crumb"] = true


## Bombed into the goal square: a pack forms. A forward marks it and goes
## back; or it is spoiled to the deck, where a crumber may snap it (or it is
## rushed through, or the defence gathers); or the defence marks or punches
## it clear; or it sails over everyone. Odds from the two sides' marking in
## the pack, calibrated (PACK_*) to keep the old bomb's goal rate.
func _bomb(side: int, shooter: Dictionary, defender: Dictionary) -> Dictionary:
	var opp := 1 - side
	var dir := 1.0 if side == 0 else -1.0
	var sq_fp := dir * (float(Ratings.T["goal_line"]) - GOAL_SQUARE_DEPTH)
	var name := GameDB.player_display_name(shooter)
	var fwds := []
	for p in _by_roles((squads[side] as Squad).ground, ["FWD", "RUCK"]):
		if str(p["id"]) != str(shooter["id"]):
			fwds.append(p)
	var marker = _weighted(fwds, "marking", 2.0, side, "shooter")
	var backs := _by_roles((squads[opp] as Squad).ground, ["DEF"])
	if backs.is_empty():
		backs = (squads[opp] as Squad).ground
	var back: Dictionary = backs[0]
	for p in backs:
		if _pack_def(p) > _pack_def(back):
			back = p
	var att := 0.0 if marker == null else _a(marker, "marking")
	var dfn := _pack_def(back)
	var r := rng.randf()
	# Over everyone: his own kick, so his shot.
	if r < PACK_THROUGH:
		_pack_event(side, sq_fp, shooter, "through", {}, "%s's kick sails over the pack" % name)
		fp = sq_fp
		return _set_result(side, shooter, null, back, PACK_THROUGH_GOAL, 1.0 - PACK_THROUGH_GOAL, false)
	_t(side, "disposals")
	_t(side, "kicks")
	_p(shooter, "disposals")
	_p(shooter, "kicks")
	fp = sq_fp
	var p_mark := clampf(PACK_MARK + (att - dfn) / 250.0, 0.08, 0.40) if marker != null else 0.0
	var p_def := clampf(PACK_DEFENCE + (dfn - att) / 250.0, 0.15, 0.50)
	r = rng.randf()
	if r < p_mark:
		_t(side, "marks")
		_p(marker, "marks")
		_t(side, "contested_marks")
		_p(marker, "contested_marks")
		_pack_event(side, sq_fp, marker, "marked", {"marker_id": str(marker["id"])},
				"%s marks in the goal square" % GameDB.player_display_name(marker))
		var g := _set_goal(clampf(PACK_MARK_ACC * shot_chance(side, marker, true, false) / SET_REF, 0.5, 0.97))
		return _set_result(side, marker, shooter, back, g, _set_behind(g), false)
	if r < p_mark + p_def:
		# The defence wins it: a mark, or a fist that clears it - a good
		# marker takes it, others punch it clear.
		var back_marks := mark_rng.randf() < clampf(0.30 + (_a(back, "marking") - 60.0) / 150.0, 0.15, 0.75)
		if back_marks:
			_t(opp, "marks")
			_p(back, "marks")
			_t(opp, "contested_marks")
			_p(back, "contested_marks")
			_pack_event(side, sq_fp, back, "defence", {"defender_id": str(back["id"])},
					"%s marks in the goal square" % GameDB.player_display_name(back))
		else:
			_t(opp, "spoils")
			_p(back, "spoils")
			_log_spoil(opp, fp, true)
			_t(opp, "one_percenters")
			_p(back, "one_percenters")
			_pack_event(side, sq_fp, back, "defence", {"defender_id": str(back["id"])},
					"%s punches it clear of the pack" % GameDB.player_display_name(back))
		return _shot_turnover(side, back, "Into the pack - the defence wins it", back_marks)
	# Spoiled to the deck: first to it is a forward, more often than not.
	_t(opp, "spoils")
	_p(back, "spoils")
	_log_spoil(opp, fp, true)
	_t(opp, "one_percenters")
	_p(back, "one_percenters")
	var crumber = _ground_forward(side, "" if marker == null else str(marker["id"]))
	var gathers: bool = crumber != null and rng.randf() < PACK_CRUMB * (0.7 + 0.6 * _a(crumber, "pressure") / 100.0)
	_pack_event(side, sq_fp, back, "spoiled",
			{"spoiler_id": str(back["id"]), "crumber_id": str(crumber["id"]) if gathers else ""},
			"%s spoils it to the deck%s" % [GameDB.player_display_name(back),
				(" and %s gathers" % GameDB.player_display_name(crumber)) if gathers else ""])
	if gathers:
		_t(side, "disposals")
		_t(side, "kicks")
		_p(crumber, "disposals")
		_p(crumber, "kicks")
		var snap := shot_chance(side, crumber, false, false) * CRUMB_SNAP
		var bh: float = float(_rates()["inside50_behind"]) * (0.80 + 0.40 * _a(crumber, "goalkicking") / 100.0)
		return _set_result(side, crumber, null, back, snap, bh, true)
	if rng.randf() < PACK_RUSHED:
		# Rushed through for a behind: no one's shot.
		_scored(side, 1, null)
		_t(side, "behinds")
		q_behinds[current_quarter - 1][side] += 1
		_emit("behind", side, fp, null, _scoreline(side, "Rushed behind"))
		events[events.size() - 1]["rushed"] = true
		events[events.size() - 1]["setshot"] = false
		_tag_shot(false)
		_end_moment_chain("behind", kick_in_fp(side), side)
		return {"points": 1, "text": "Rushed through for a behind."}
	return _shot_turnover(side, back, "Spoiled, and the defence gathers")


## What a bomb to the goal square comes to before a die is rolled: the chance
## of a goal and of a behind, from the same PACK_* numbers, players and weights
## _bomb rolls with, averaged over who flies for it and who is at the fall of
## the ball. For the set-shot card only. Pure: no dice, nothing changed.
func bomb_odds(side: int, shooter: Dictionary) -> Dictionary:
	var opp := 1 - side
	var fwds := []
	for p in _by_roles((squads[side] as Squad).ground, ["FWD", "RUCK"]):
		if str(p["id"]) != str(shooter["id"]):
			fwds.append(p)
	var backs := _by_roles((squads[opp] as Squad).ground, ["DEF"])
	if backs.is_empty():
		backs = (squads[opp] as Squad).ground
	var back: Dictionary = backs[0]
	for p in backs:
		if _pack_def(p) > _pack_def(back):
			back = p
	var dfn := _pack_def(back)
	var ctx := _pick_ctx(side)
	# Who flies for it, weighted as _weighted(fwds, "marking", 2.0, side, "shooter").
	var markers := []
	var total := 0.0
	for p in fwds:
		var w: float = pow(maxf(1.0, _a(p, "marking")), 2.0) * _tactic_player_mult(side, p, "shooter", ctx)
		markers.append([p, w])
		total += w
	if markers.is_empty():
		markers.append([null, 1.0])
		total = 1.0
	elif total <= 0.0:
		# _pick takes the first man when nobody carries a weight.
		markers = [[fwds[0], 1.0]]
		total = 1.0
	var goal := 0.0
	var behind := 0.0
	for row in markers:
		var marker = row[0]
		var share: float = float(row[1]) / total
		if share <= 0.0:
			continue
		var att := 0.0 if marker == null else _a(marker, "marking")
		var p_mark := clampf(PACK_MARK + (att - dfn) / 250.0, 0.08, 0.40) if marker != null else 0.0
		var p_def := clampf(PACK_DEFENCE + (dfn - att) / 250.0, 0.15, 0.50)
		var g := 0.0
		var b := 0.0
		if marker != null:
			var mg := _set_goal(clampf(PACK_MARK_ACC * shot_chance(side, marker, true, false) / SET_REF, 0.5, 0.97))
			g += p_mark * mg
			b += p_mark * minf(_set_behind(mg), 1.0 - mg)
		var deck := _deck_odds(side, "" if marker == null else str(marker["id"]), ctx)
		var spill := maxf(0.0, 1.0 - p_mark - p_def)
		g += spill * float(deck["goal"])
		b += spill * float(deck["behind"])
		goal += share * g
		behind += share * b
	return {"goal": PACK_THROUGH * PACK_THROUGH_GOAL + (1.0 - PACK_THROUGH) * goal,
			"behind": PACK_THROUGH * (1.0 - PACK_THROUGH_GOAL) + (1.0 - PACK_THROUGH) * behind}


## A bomb spoiled to the deck: the chance it ends in a goal and in a behind
## (a crumber's snap, or rushed through), averaged over who is at the fall of
## the ball, weighted as _ground_forward picks him. Pure: no dice.
func _deck_odds(side: int, exclude: String, ctx: Dictionary) -> Dictionary:
	var pick_ctx := ctx.duplicate()
	pick_ctx["zone"] = ""
	var rows := []
	var total := 0.0
	for p in (squads[side] as Squad).ground:
		if str(p["id"]) == exclude:
			continue
		var w: float = float(CRUMB_ROLES.get(str(p["role"]), 0.0)) * pow(maxf(1.0, _a(p, "pressure")), 2.0)
		if str(p["role"]) == "FWD":
			w *= float(GROUND_SIZES.get(fwd_size(p), 1.0))
		w *= _tactic_player_mult(side, p, "crumb", pick_ctx)
		rows.append([p, w])
		total += w
	if rows.is_empty():
		return {"goal": 0.0, "behind": PACK_RUSHED}
	if total <= 0.0:
		rows = [[rows[0][0], 1.0]]
		total = 1.0
	var goal := 0.0
	var behind := 0.0
	for row in rows:
		var share: float = float(row[1]) / total
		if share <= 0.0:
			continue
		var crumber: Dictionary = row[0]
		var gathers := clampf(PACK_CRUMB * (0.7 + 0.6 * _a(crumber, "pressure") / 100.0), 0.0, 1.0)
		var snap := clampf(shot_chance(side, crumber, false, false) * CRUMB_SNAP, 0.0, 1.0)
		var bh: float = float(_rates()["inside50_behind"]) * (0.80 + 0.40 * _a(crumber, "goalkicking") / 100.0)
		goal += share * gathers * snap
		behind += share * (gathers * minf(bh, 1.0 - snap) + (1.0 - gathers) * PACK_RUSHED)
	return {"goal": goal, "behind": behind}


## A defender in a goal-square pack: reading it first, then marking it.
func _pack_def(p: Dictionary) -> float:
	return 0.6 * _a(p, "intercept") + 0.4 * _a(p, "marking")


func _pack_event(side: int, at: float, actor, outcome: String, ids: Dictionary, text: String) -> void:
	_emit("pack", side, at, actor, text)
	var ev: Dictionary = events[events.size() - 1]
	ev["outcome"] = outcome
	for k in ["marker_id", "spoiler_id", "crumber_id", "defender_id"]:
		ev[k] = str(ids.get(k, ""))


## A free kick paid inside the forward 50 is a set shot from where it was
## paid (ARD backlog item 24: real set shots are about 55% of shots, and the
## frees in 50 are a big part of them). The taker is whoever it was paid to.
func _free_set_taker(side: int, at_fp: float) -> Dictionary:
	if int(_free_taker.get("side", -1)) != side:
		return {}
	var atk_fp := at_fp if side == 0 else -at_fp
	if atk_fp < float(Ratings.T["forward50_line"]):
		return {}
	return _on_ground(side, str(_free_taker.get("id", "")))


## Set-shot conversion by distance alone (docs/research/SET_SHOT_EVIDENCE.md:
## 97% at 0-15 m falling to 36% beyond 50 m), for an ordinary kick.
const FREE_SET_ACC := [[10.0, 0.97], [20.0, 0.92], [30.0, 0.80], [40.0, 0.62], [50.0, 0.45], [60.0, 0.33]]


static func free_set_acc(metres: float) -> float:
	var pts: Array = FREE_SET_ACC
	if metres <= float(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		if metres <= float(pts[i][0]):
			var t := (metres - float(pts[i - 1][0])) / (float(pts[i][0]) - float(pts[i - 1][0]))
			return lerpf(float(pts[i - 1][1]), float(pts[i][1]), t)
	return float(pts[pts.size() - 1][1])


func _free_set_shot(side: int, at_fp: float, taker: Dictionary) -> Dictionary:
	_t(side, "chains")
	_chain_touch[str(taker["id"])] = taker
	fp = at_fp
	var metres := float(Ratings.T["goal_line"]) - (at_fp if side == 0 else -at_fp)
	var goal_p := _set_goal(free_set_acc(metres) * shot_chance(side, taker, true, false) / SET_REF)
	var behind_p := _set_behind(goal_p)
	var roll := rng.randf()
	# His shot, as any set shot is counted (shots, set shots, their result).
	_shot(side, taker, true, "goal" if roll < goal_p else ("behind" if roll < goal_p + behind_p else ""), metres, "free")
	if roll < goal_p:
		_t(side, "goals")
		_p(taker, "goals")
		_scored(side, 6, taker)
		q_goals[current_quarter - 1][side] += 1
		_score_run(side)
		_emit("goal", side, fp, taker, _scoreline(side, "GOAL"))
		events[events.size() - 1]["set"] = true
		events[events.size() - 1]["from_free"] = true
		_trait_note(taker)
		_tag_shot(true)
		return {"outcome": "score", "fp": 0.0, "actor": taker}
	if roll < goal_p + behind_p:
		_t(side, "behinds")
		_p(taker, "behinds")
		_scored(side, 1, taker)
		q_behinds[current_quarter - 1][side] += 1
		_emit("behind", side, fp, taker, _scoreline(side, "Behind"))
		events[events.size() - 1]["set"] = true
		events[events.size() - 1]["from_free"] = true
		_tag_shot(true)
		return {"outcome": "behind", "fp": kick_in_fp(side), "actor": taker}
	# Short or out on the full: the defence has it.
	var opp := 1 - side
	var backs := _by_roles((squads[opp] as Squad).ground, ["DEF"])
	var back = _weighted(backs if not backs.is_empty() else (squads[opp] as Squad).ground, "marking", 2.0, opp, "defender")
	# Not a mark (could_mark is false): the copy must not call it one. The
	# rebound 50 is whoever's disposal takes it out of defensive 50.
	_intercept(opp, back, false)
	_emit("rebound", opp, fp, back, "%s's set shot falls short; %s gathers it" % [
			GameDB.player_display_name(taker), GameDB.player_display_name(back)])
	events[events.size() - 1]["from_free"] = true
	return {"outcome": "turnover", "fp": fp, "actor": back}


## The goal-square pack (_bomb). Calibrated by tools/audit/setshot_calls_impl.gd so
## a bomb still scores about what it did before the pack (0.26 + 0.20 forward
## marking - 0.12 defence intercept, out of 100).
const PACK_THROUGH := 0.08       # sails over everyone
const PACK_THROUGH_GOAL := 0.55  # and through the big sticks, else a behind
const PACK_MARK := 0.30          # a forward marks it, level pack
const PACK_DEFENCE := 0.25       # the defence marks or punches it, level pack
const PACK_MARK_ACC := 0.92      # his shot from the square, an ordinary kick
const PACK_CRUMB := 0.45         # spoiled: a crumber gathers, before pressure
const PACK_RUSHED := 0.60        # not gathered: rushed through, else they clear it


func _shot_turnover(side: int, defender: Dictionary, text: String, marked := false) -> Dictionary:
	var opp := 1 - side
	# The rebound 50 is whoever's disposal takes it out of defensive 50.
	if not defender.is_empty():
		_intercept(opp, defender, false)
		if marked:
			# He marked it in the pack: the kick out is his.
			_won_back["marked"] = true
			_won_back["contested"] = true
		var dn := GameDB.player_display_name(defender)
		_emit("rebound", opp, fp, defender, ("%s marks it in defence" % dn) if marked
				else ("%s wins it back in defence" % dn))
	_end_moment_chain("turnover", fp, side)
	return {"points": 0, "text": text + " - no score."}


func _end_moment_chain(outcome: String, new_fp: float, side: int) -> void:
	_set_choice = {}
	fp = new_fp
	at_centre = outcome == "score"
	kick_in = outcome == "behind"
	next_side = (1 - side) if outcome == "turnover" or outcome == "behind" else -1
	_prev_end = outcome
	_after_chain()


func _score_run(side: int) -> void:
	_run[side] += 1
	_run[1 - side] = 0



# ---------------------------------------------------------------------------
# The rival coach (live matches)
# ---------------------------------------------------------------------------
## The opposition's plan for the coming quarter: its usual game (standing:
## the plan its coach settled on for the season), protecting a big lead or chasing
## a big deficit (ai_mood). From the second quarter it reads the plan you ran
## last quarter and, when it is one of the main three, switches to the plan
## that beats it (COUNTER) if that plan is worth nearly as much to it as its
## usual game (COUNTER_GIVE, on PlanFit.plan_score). The scoreboard comes
## first: a big lead or deficit decides before any counter. With a specialist
## tagger on the ground it tags your most influential midfielder; without one
## it does not (a tag by a good midfielder costs more than it takes,
## _tag_drag).
## A sharper tactical group (Squad.tactics_read) reacts to a smaller margin
## (react_margin) and tags from quarter time rather than half time
## (tag_quarter).
## His senior coach's tendency (Squad.coach_style, COACH_STYLES) moves when
## he reacts, never what his players can do.
## The Assistant's report and the break sheet say all of this in football
## words (RivalRead), from these same constants and functions.
## The plan that beats each of the main three (the triangle at PLANS).
const COUNTER := {"controlled": "attacking", "defensive": "controlled", "attacking": "defensive"}
## How much less (PlanFit.plan_score) a counter may be worth than the usual
## game and still be played.
const COUNTER_GIVE := 0.3
## The first quarter a rival coach answers the plan you ran (the one before).
const COUNTER_Q := 2
## The margin (points) that moves a rival coach whose box reads the game
## averagely (Squad.tactics_read 0); a sharper box needs REACT_SPAN less per
## point of read (react_margin).
const REACT_BASE := 18.0
const REACT_SPAN := 8.0
## A box this sharp (Squad.tactics_read; CoachEffects.level(STRONG_CUT))
## tags from quarter time (TAG_Q_SHARP); any other waits for half time
## (TAG_Q_SLOW).
const TAG_SHARP_READ := 0.4
const TAG_Q_SHARP := 2
const TAG_Q_SLOW := 3
## Aerial contests one of your men must have won roaming (player_stats
## "roam_wins") before the rival coach sends a forward to stand him.
const LOOSE_MINDER_WINS := 2


## The margin that moves a coach whose box reads the game at `read`.
static func react_margin(read: float) -> float:
	return REACT_BASE - REACT_SPAN * read


## The first quarter a box reading the game at `read` sends its tagger.
static func tag_quarter(read: float) -> int:
	return TAG_Q_SHARP if read >= TAG_SHARP_READ else TAG_Q_SLOW


## How the scoreboard has `side`'s coach going into the quarter, by the rule
## ai_tactics plays: "protect" (well in front: he shuts up shop), "chase"
## (well behind: he chases), "lost_q" (behind after half time and outscored
## last quarter: he chases), "" (neither: his usual game, or his answer to
## yours). Pure: no dice, nothing set.
func ai_mood(side: int) -> String:
	var margin := score(side) - score(1 - side)
	var react := react_margin(float((squads[side] as Squad).tactics_read))
	var st := _style(side)
	if margin >= react * float(st["protect"]) + float(st["add"]):
		return "protect"
	if margin <= -(react * float(st["chase"]) + float(st["add"])):
		return "chase"
	if margin < 0 and current_quarter >= int(st["lost_q"]) and _lost_quarter(side, current_quarter - 1):
		# Behind after half time and still losing ground: the usual game is
		# not working, so it chases. Only what a coach sees - the scoreboard.
		return "lost_q"
	return ""


## Why `side`'s coach plays the plan ai_tactics gives him this quarter: his
## mood (ai_mood), "counter" (his answer to the plan you ran last quarter),
## or "usual". Pure, like ai_mood.
func ai_why(side: int) -> String:
	var mood := ai_mood(side)
	if mood != "":
		return mood
	return "counter" if _counter_plan(side, _usual(side)) != "" else "usual"


## The plan that beats what the other side ran last quarter, when `side`'s
## coach would play it instead of `plan`; "" when he stays. From the second
## quarter only.
func _counter_plan(side: int, plan: String) -> String:
	if current_quarter < COUNTER_Q or tactics_history.is_empty():
		return ""
	# What they ran last quarter is on show: beat it if that costs little.
	var theirs := plan_key(str(((tactics_history[-1]["plans"] as Array)[1 - side] as Dictionary).get("gameplan", "balanced")))
	var beat := str(COUNTER.get(theirs, ""))
	if beat == "" or beat == plan:
		return ""
	var sq: Squad = squads[side]
	if PlanFit.plan_score(sq.ground, beat, sq.plan_know) >= PlanFit.plan_score(sq.ground, plan, sq.plan_know) - COUNTER_GIVE:
		return beat
	return ""


func ai_tactics(side: int) -> Dictionary:
	var opp := 1 - side
	var read := float((squads[side] as Squad).tactics_read)
	var margin := score(side) - score(opp)
	var st := _style(side)
	var plan := _usual(side)
	var mood := ai_mood(side)
	if mood == "protect":
		plan = "controlled"
	elif mood != "":
		plan = "attacking"
	else:
		var beat := _counter_plan(side, plan)
		if beat != "":
			plan = beat
	var fire := margin <= float(st["fire_at"]) and current_quarter >= int(st["fire_q"])
	var t := {"gameplan": plan, "pep": "fire_up" if fire else "steady"}
	t["interceptor_id"] = _ai_interceptor(side, (squads[side] as Squad).ground)

	# The AI never reads the opponent's hidden structural call. It only makes
	# the spare accountable after the match log/stats show that player has
	# actually influenced enough aerial contests.
	var observed_spare_wins := 0
	for p in (squads[opp] as Squad).ground:
		var ost: Dictionary = player_stats.get(str(p.get("id", "")), {})
		observed_spare_wins = maxi(observed_spare_wins, int(ost.get("roam_wins", 0)))
	if observed_spare_wins >= LOOSE_MINDER_WINS:
		t["spare_accountable"] = true
		var minders := Matchups.minder_candidates((squads[side] as Squad).ground)
		if not minders.is_empty():
			t["spare_minder_id"] = str(minders[0]["id"])

	var tagger = tagger_of(side)
	if current_quarter >= tag_quarter(read) and tagger != null and Roles.is_tagger(tagger):
		var best := ""
		var best_inf := -1.0
		for p in (squads[opp] as Squad).ground:
			if not taggable(p):
				continue
			var inf := CoachReport.influence(player_stats.get(str(p["id"]), {}))
			if inf > best_inf:
				best_inf = inf
				best = str(p["id"])
		if best != "":
			t["tag_id"] = best
	return t


## The men a rival coach (or your assistant) may send loose, from `ground`:
## a key defender on a key forward stays on him unless a free key defender
## would take the forward, so a key forward is never left to a smaller man
## for the loose man's sake. The coach's own pick of the loose man is his.
func _loose_pool(side: int, ground: Array) -> Array:
	return loose_pool(duels[side], str(interceptor[side]), (squads[side] as Squad).ground,
			(squads[1 - side] as Squad).ground, ground)


## _loose_pool from the match-ups themselves: `d` forward id -> defender id
## for the side picking, `loose` its loose man now, `own` and `opp` the two
## grounds, `ground` the men to pick from.
static func loose_pool(d: Dictionary, loose: String, own: Array, opp: Array, ground: Array) -> Array:
	var on := {}
	for fid in d:
		on[str(d[fid])] = str(fid)
	var free_key := false
	for p in Matchups.defenders(own):
		var pid := str(p["id"])
		if not on.has(pid) and pid != loose \
				and PlayerProfile.player_type(p) == "Key defender":
			free_key = true
	if free_key:
		return ground
	return ground.filter(func(p):
		var fid := str(on.get(str(p["id"]), ""))
		if fid == "" or PlayerProfile.player_type(p) != "Key defender":
			return true
		return not Matchups.is_key_forward(_find(opp, fid)))


## The loose man a rival coach starts a match with, as MatchSim.new picks
## him: his best interceptor among the men he can spare from the default
## match-ups. {} for none. The Assistant's report names him from this.
static func loose_pick(own: Array, opp: Array) -> Dictionary:
	return Matchups.best_interceptor(loose_pool(Matchups.defaults(opp, own), "", own, opp, own))


## The player with id `id` in `group`, or {}.
static func _find(group: Array, id: String) -> Dictionary:
	for p in group:
		if str(p["id"]) == id:
			return p
	return {}


## A rival coach's loose defender for the quarter, from `ground`: his best
## interceptor, unless he is chasing the game late and wants every man on a
## forward. "" for none.
func _ai_interceptor(side: int, ground: Array) -> String:
	var react := react_margin(float((squads[side] as Squad).tactics_read))
	var margin := score(side) - score(1 - side)
	var st := _style(side)
	var spare := Matchups.best_interceptor(_loose_pool(side, ground))
	if spare.is_empty() or (margin <= -react * float(st["loose"]) and current_quarter >= int(st["loose_q"])):
		return ""
	return str(spare["id"])


## A rival senior coach's match-day tendency (director, 2026-10-11; bounded
## 2026-11-03): the same rule as everyone's, with its margins moved by at most
## a quarter either way, never dice and never a reaction he refuses to make.
## protect / chase: the share of his react margin at which he shuts up shop /
## chases; add: points on both; lost_q: the quarter from which a lost quarter
## makes him chase; loose / loose_q: the share of react behind, and the
## quarter, at which he pulls his loose man to chase; fire_at / fire_q: when
## he fires them up.
##   balanced  the plain rule.
##   stubborn  backs his structure: waits a quarter longer either way.
##   reactive  throws the magnets around: reacts at 75% of the margin.
##   gambler   goes for broke: chases and pulls his loose man at 75% of the
##             margin, fires them up at 9 down.
##   cautious  sits on a lead: shuts up shop at 75% of the margin.
const COACH_STYLES := {
	"balanced": {"protect": 1.0, "chase": 1.0, "add": 0.0, "lost_q": 3, "loose": 1.0, "loose_q": 3, "fire_at": -12.0, "fire_q": 3},
	"stubborn": {"protect": 1.25, "chase": 1.25, "add": 0.0, "lost_q": 3, "loose": 1.25, "loose_q": 3, "fire_at": -12.0, "fire_q": 3},
	"reactive": {"protect": 0.75, "chase": 0.75, "add": 0.0, "lost_q": 3, "loose": 0.75, "loose_q": 3, "fire_at": -12.0, "fire_q": 3},
	"gambler": {"protect": 1.0, "chase": 0.75, "add": 0.0, "lost_q": 3, "loose": 0.75, "loose_q": 3, "fire_at": -9.0, "fire_q": 3},
	"cautious": {"protect": 0.75, "chase": 1.0, "add": 0.0, "lost_q": 3, "loose": 1.0, "loose_q": 3, "fire_at": -12.0, "fire_q": 3},
}


## `side`'s usual game (standing): the plan its coach settled on for the
## season, or the one its list suits. Only an AI club picks its plan this
## way; yours is always your own call.
func _usual(side: int) -> String:
	return str(standing[side])


## `side`'s coach's tendency: his style only for an AI club; your club is you.
func _style(side: int) -> Dictionary:
	var sq: Squad = squads[side]
	var key := sq.coach_style if sq.ai_plans else "balanced"
	return COACH_STYLES.get(key, COACH_STYLES["balanced"])


## Whether `side` was outscored in quarter `q` (1-4).
func _lost_quarter(side: int, q: int) -> bool:
	if q < 1 or q > q_goals.size():
		return false
	var pts := func(s: int) -> int: return int(q_goals[q - 1][s]) * 6 + int(q_behinds[q - 1][s])
	return pts.call(side) < pts.call(1 - side)


## A tag is a midfield job: only a midfielder (centre or wing) is picked for
## one by the AI and the match moments.
static func taggable(p: Dictionary) -> bool:
	return midfielder_on_ground(p) and can_be_tagged(p)


## What the coach may tag: anyone who can play midfield, by his first or
## second position, wherever he lines up today (director, 2026-10-14: a
## mid/forward like Rankine could not be tagged). A ruck or defender with no
## midfield position still cannot, and nor does a ruckman, even one who also
## lists midfield (director, 2026-10-18: "no one tags ruckmen"; "ruckmen can
## be stopped by other ruckmen").
static func can_be_tagged(p: Dictionary) -> bool:
	var pos := Ratings.positions(p)
	return pos.has("MID") and str(pos[0]) != "RUCK"


## Playing in the midfield today and a midfielder by position. The match-day
## copy carries the slot as its role, so a ruck picked in a midfield slot
## would otherwise count; he counts only if midfield is one of his own
## positions (the rare ruck who is also a midfielder). The director's PC
## playtest, 2026-10-07: the team's ruckman was sent to tag.
static func midfielder_on_ground(p: Dictionary) -> bool:
	if str(p.get("role", "")) != "MID":
		return false
	var own := str(p.get("own_role", "MID"))
	return own == "MID" or Ratings.second_positions(p).has("MID")


## Who `side` sends to its tag: the coach's own choice (tactics "tagger_id")
## while he is a midfielder on the ground, otherwise the assistant's man
## (tagger_for: the best hold for the least given up, on starting legs, so
## the job does not hop between players as they tire). A chosen man who
## goes to the bench or out of the midfield hands the job back.
func tagger_of(side: int):
	var ground: Array = (squads[side] as Squad).ground
	var want := str((tactics[side] as Dictionary).get("tagger_id", ""))
	if want != "":
		for p in ground:
			if str(p["id"]) == want and midfielder_on_ground(p):
				return p
	return tagger_for(ground)


## Who goes to the player a side tags, before the bounce: the first of
## tag_order on starting legs. null with no midfielder on the ground.
static func tagger_for(ground: Array):
	var order := tag_order(ground)
	return null if order.is_empty() else order[0]


## What sending `p` to a tag gives up of his own game: his part in the
## side's midfield contest from his ratings (as _mid_value: disposal, and
## contested ball unless he plays on a wing).
static func tag_give_up(p: Dictionary, ground: Array) -> float:
	var n_mids := 0
	var n_centre := 0
	for q in ground:
		if str(q.get("role", "")) == "MID":
			n_mids += 1
			if not Roles.on_wing(q):
				n_centre += 1
	var a: Dictionary = p.get("attr", {})
	var v := 0.22 * float(a.get("disposal", 0)) / float(maxi(1, n_mids))
	if not Roles.on_wing(p):
		v += 0.42 * float(a.get("contested", 0)) / float(maxi(1, n_centre))
	return v


## The side's midfielders on the ground in the order a coach would send them
## to a tag: the tightest hold first (Roles.tag_keep, on `legs` by id, else his
## starting legs), then the least given up of his own game. The assistant
## and the AI send the first; the break screen lists them in this order.
static func tag_order(ground: Array, legs: Dictionary = {}) -> Array:
	var rows := []
	for p in ground:
		if not midfielder_on_ground(p):
			continue
		var e := float(legs.get(str(p["id"]), _start_energy(p)))
		rows.append([Roles.tag_keep(p, e), tag_give_up(p, ground), str(p["id"]), p])
	rows.sort_custom(func(a, b):
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) < float(b[0])
		if not is_equal_approx(float(a[1]), float(b[1])):
			return float(a[1]) < float(b[1])
		return str(a[2]) < str(b[2]))
	return rows.map(func(r): return r[3])

