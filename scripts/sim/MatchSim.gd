class_name MatchSim
extends RefCounted
## The match engine. Simulates a game as a sequence of possession chains and
## emits a deterministic, seeded event log that the pitch view replays.
##
## Port of tools/sim_harness.py::MatchSim. The RNG call order below must match
## the Python harness exactly - that file is where the constants were tuned so
## simulated team totals reproduce real 2026 AFL numbers. Emitting events does
## not draw from the RNG, so the richer log costs nothing in calibration.

var squads: Array = []                 # [Squad home, Squad away]
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
var tactics := [{}, {}]      # per side: gameplan, focus_id, tag_id, pep
## How well each side's match-day players suit each plan (PlanFit): the
## plan's upside is scaled by it, its costs are not.
var plan_fit := [{}, {}]
## Each side's best three at the first bounce: who Through stars goes through.
var stars := [{}, {}]
## The plan each side's list suits as its usual game (PlanFit.standing_plan):
## where an AI club starts, and what it goes back to.
var standing := ["balanced", "balanced"]
## Named match-ups (Matchups, Gate 1.12): per defending side, which defender
## stands on each of the other side's key forwards. {forward id: defender id}.
var duels := [{}, {}]
## Defender given licence to leave his man and hunt aerial balls behind play.
## This is a role/assignment, not an extra player.
var interceptor := ["", ""]
var interceptor_changes: Array = []
## Every contest a matched forward and his direct opponent played:
## forward id -> {"side": attacking side, "contests": [[q, defender id,
## forward marked, goal from it]]}.
var duel_log := {}
## Match-ups changed during the match: [{"q", "side" (defending), "fwd", "def"}].
var duel_changes: Array = []
## The calls a side's coach has made himself (coach_interceptor, coach_matchup,
## his set-up before the bounce): his assistant leaves them alone for the
## rest of the match (Squad.assistant). {"interceptor": bool, "duels":
## {forward id: true}}.
var _own := [{"interceptor": false, "duels": {}}, {"interceptor": false, "duels": {}}]
## The contest in play, attached to the score or rebound it produces.
var _duel := {}
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
## Who won the ball back for the chain being played ({"side", "id"}), so a
## goal from a turnover can say whose intercept it came from.
var _won_back := {}
var _chain_from := {}
# Assistant-coach audit trail. Snapshots never touch the RNG, so calibration
# is unaffected. tactics_history[q] records the plans in force for that
# quarter; quarter_teams[q] records the cumulative team totals afterwards.
var tactics_history: Array = []
var quarter_teams: Array = []
## Finals cannot be drawn. With finals_mode on, a level score at the end of
## Q4 leads to extra time instead of the full-time siren.
var finals_mode := false
var extra_time_played := false

## Legs. Every player has energy (0-100): on-ground players tire each chain,
## the bench recovers, and coaches rotate tired players off. Energy scales a
## player's effective attributes (fit()), centred so an average match reads
## the same as before - a fresh player is a touch better, a cooked one worse.
var energy := {}
var rotation_policy := ["normal", "normal"]
var interchanges := [0, 0]
var _chain_no := 0
var _played := [{}, {}]      # side -> id -> true: everyone who took the field

## Where the result came from: expected points each cause added (positive
## helps that side). Pure arithmetic on the probabilities already rolled -
## no RNG draws - so it costs the calibration nothing.
var impact := [{}, {}]

## Match moments: live matches pause for the coach's call. Only the side in
## moment_side gets them, and they draw from their own RNG, so simulated
## matches (moment_side -1) never see one.
var moment_side := -1
var moment_rng := RandomNumberGenerator.new()
## Stat credits that must not disturb the match's own random sequence (who a
## free kick was paid to): results are identical with or without them.
var stat_rng := RandomNumberGenerator.new()
## Whether a mark inside 50 ends in a set shot and from where (SET_BANDS):
## its own stream, so the rest of the match draws exactly as before.
var shot_rng := RandomNumberGenerator.new()
## Smothers alter possession but use their own stream, so ordinary disposal
## outcomes keep the calibration RNG sequence they had before this feature.
var smother_rng := RandomNumberGenerator.new()
## General-play aerial contests alter real possession outcomes but use their
## own stream so ordinary non-aerial play keeps its prior RNG ordering.
var aerial_rng := RandomNumberGenerator.new()
## Spectacular-mark selection is presentation/stat context only.
var speccy_rng := RandomNumberGenerator.new()
## Post-free 50m infringements are independent of ordinary play rolls.
var discipline_rng := RandomNumberGenerator.new()
var mro_rng := RandomNumberGenerator.new()
var restart_rng := RandomNumberGenerator.new()
var free_rng := RandomNumberGenerator.new()
var _speccy_quota := 0
var _speccies := 0
## Boundary law rolls are isolated from the calibrated play RNG. Adding or
## tuning boundary frequency therefore does not silently re-roll ordinary
## disposals in chains that stay in play.
var boundary_rng := RandomNumberGenerator.new()
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
## Clanger-rate change at full form: 0.95x at +1, 1.05x at -1.
const FORM_COMPOSURE := 0.05
## Stoppage-win chance at full form (home_ground_bonus is 0.030).
const FORM_CONTEST := 0.010


func _init(home: Squad, away: Squad, seed: int = 0) -> void:
	squads = [home, away]
	form = [clampf(home.form, -1.0, 1.0), clampf(away.form, -1.0, 1.0)]
	rng.seed = seed
	moment_rng.seed = seed * 7 + 13
	stat_rng.seed = seed * 11 + 5
	shot_rng.seed = seed * 13 + 3
	smother_rng.seed = seed * 23 + 29
	aerial_rng.seed = seed * 73 + 79
	speccy_rng.seed = seed * 31 + 37
	discipline_rng.seed = seed * 41 + 43
	mro_rng.seed = seed * 47 + 53
	restart_rng.seed = seed * 59 + 61
	free_rng.seed = seed * 67 + 71
	_speccy_quota = speccy_quota(seed)
	boundary_rng.seed = seed * 17 + 19
	injury_rng.seed = seed * 13 + 7
	for side in range(2):
		synergies[side] = Traits.active((squads[side] as Squad).ground)
		standing[side] = PlanFit.standing_plan((squads[side] as Squad).ground)
		duels[side] = Matchups.defaults((squads[1 - side] as Squad).ground, (squads[side] as Squad).ground)
		for plan in PlanFit.LEAGUE:
			(plan_fit[side] as Dictionary)[plan] = PlanFit.fit((squads[side] as Squad).ground, plan)
		for p in PlanFit.carriers((squads[side] as Squad).ground, "through_stars"):
			(stars[side] as Dictionary)[str(p["id"])] = true
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
			var best := Matchups.best_interceptor((squads[side] as Squad).ground)
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


## Your set-up before the bounce: {forward id: defender id} on top of the
## default. Not a change during the match. These pairings are the coach's
## own, so his assistant then picks a loose man from the defenders left.
func set_matchups(def_side: int, m: Dictionary) -> void:
	for fid in m:
		((_own[def_side] as Dictionary)["duels"] as Dictionary)[str(fid)] = true
		set_matchup(def_side, str(fid), str(m[fid]), false)
	if not m.is_empty() and _assisted(def_side) and not bool((_own[def_side] as Dictionary)["interceptor"]):
		set_interceptor(def_side, _assistant_interceptor(def_side), false)


## The coach picks the loose defender himself ("" for none): it stays his
## call for the rest of the match.
func coach_interceptor(side: int, def_id: String) -> bool:
	if side < 0 or side > 1:
		return false
	(_own[side] as Dictionary)["interceptor"] = true
	return set_interceptor(side, def_id, current_quarter > 1 or _q_active)


## The coach puts `def_id` on their forward `fwd_id` himself: that match-up
## stays his call for the rest of the match.
func coach_matchup(def_side: int, fwd_id: String, def_id: String) -> bool:
	if def_side < 0 or def_side > 1:
		return false
	((_own[def_side] as Dictionary)["duels"] as Dictionary)[fwd_id] = true
	return set_matchup(def_side, fwd_id, def_id)


## Whether the assistant has any routine call left to make for `side`: on
## your side until you have taken the loose man and every match-up yourself.
func assistant_active(side: int) -> bool:
	if not _assisted(side):
		return false
	var own: Dictionary = _own[side]
	if not bool(own["interceptor"]):
		return true
	for fid in (duels[side] as Dictionary):
		if not (own["duels"] as Dictionary).has(str(fid)):
			return true
	return false


## Whether the coach made this call himself, rather than his assistant: the
## loose defender (`fwd_id` "") or the match-up on `fwd_id`. Always true for
## a side without an assistant.
func coach_call(side: int, fwd_id := "") -> bool:
	if side < 0 or side > 1 or not _assisted(side):
		return true
	var own: Dictionary = _own[side]
	return bool(own["interceptor"]) if fwd_id == "" else (own["duels"] as Dictionary).has(fwd_id)


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


## Chance the loose defender actually reaches this aerial contest. Making him
## accountable drags him away and sharply reduces it, at a cost to the attack.
func _roam_chance(def_side: int) -> float:
	var p := _roaming_interceptor(def_side)
	if p.is_empty():
		return 0.0
	var chance := clampf(0.10 + Matchups.interceptor_score(p) / 430.0, 0.20, 0.38)
	if bool((tactics[1 - def_side] as Dictionary).get("spare_accountable", false)):
		chance *= 0.40
	return chance


func _spare_accountable(attacking_side: int) -> bool:
	return bool((tactics[attacking_side] as Dictionary).get("spare_accountable", false)) 			and not _roaming_interceptor(1 - attacking_side).is_empty()


## An AI club moves a key defender when their forward has had the better of
## him: three or more contests last quarter and two in three won. It tries
## the next defender a coach would, not the ideal one.
func _ai_rematch(def_side: int) -> void:
	var d: Dictionary = duels[def_side]
	for fid in d.keys():
		var log: Dictionary = duel_log.get(str(fid), {})
		var n := 0
		var won := 0
		for c in log.get("contests", []):
			if int(c[0]) == current_quarter - 1 and str(c[1]) == str(d[fid]):
				n += 1
				if bool(c[2]):
					won += 1
		if n < 3 or float(won) / float(n) < 0.67:
			continue
		for p in Matchups.defenders((squads[def_side] as Squad).ground):
			if str(p["id"]) != str(d[fid]):
				set_matchup(def_side, str(fid), str(p["id"]))
				break


## Your assistant's routine calls for the quarter about to start, made at
## the break so the coach box shows them as your starting point: the loose
## defender a rival coach would pick, and a key defender moved off a forward
## who has had the better of him (as _ai_rematch). Whatever you have set
## yourself he leaves alone, and he never moves a defender you have put on
## someone.
func _assistant_calls(side: int) -> void:
	var own: Dictionary = _own[side]
	if not bool(own["interceptor"]):
		set_interceptor(side, _assistant_interceptor(side), true)
	var d: Dictionary = duels[side]
	var held := {}
	for fid in (own["duels"] as Dictionary):
		if d.has(fid):
			held[str(d[fid])] = true
	if bool(own["interceptor"]) and str(interceptor[side]) != "":
		held[str(interceptor[side])] = true
	for fid in d.keys():
		if (own["duels"] as Dictionary).has(str(fid)):
			continue
		var log: Dictionary = duel_log.get(str(fid), {})
		var n := 0
		var won := 0
		for c in log.get("contests", []):
			if int(c[0]) == current_quarter - 1 and str(c[1]) == str(d[fid]):
				n += 1
				if bool(c[2]):
					won += 1
		if n < 3 or float(won) / float(n) < 0.67:
			continue
		for p in Matchups.defenders((squads[side] as Squad).ground):
			var pid := str(p["id"])
			if pid != str(d[fid]) and not held.has(pid):
				set_matchup(side, str(fid), pid)
				break


## The loose defender a rival coach would use (_ai_interceptor), from the
## defenders you have not put on a forward yourself.
func _assistant_interceptor(side: int) -> String:
	var own_duels: Dictionary = (_own[side] as Dictionary)["duels"]
	var d: Dictionary = duels[side]
	var taken := {}
	for fid in own_duels:
		if d.has(fid):
			taken[str(d[fid])] = true
	var free := (squads[side] as Squad).ground.filter(func(p): return not taken.has(str(p["id"])))
	return _ai_interceptor(side, free)


func set_tactics(side: int, t: Dictionary) -> void:
	if side < 0 or side > 1:
		return
	tactics[side] = t.duplicate()
	if t.has("interceptor_id"):
		set_interceptor(side, str(t.get("interceptor_id", "")), current_quarter > 1 or _q_active)
	# A tag needs its man still in the match.
	var tag := str(t.get("tag_id", ""))
	if tag != "" and not taking_part(1 - side, tag):
		tactics[side]["tag_id"] = ""


## Gameplan trade-offs. Every plan gives something up, and the main three
## counter each other: Attack corridor beats Controlled tempo (no pressure to
## punish it), Controlled tempo beats the Defensive press (it plays through
## the pressure), and the press beats Attack corridor (it squeezes the
## corridor into turnovers). Keys: goal (own conversion), opp_goal (theirs),
## exposed (their conversion when you turn it over), gain (metres),
## clangers, press (pressure you apply), taken (pressure you take),
## contest (stoppage win), pace (how fast legs go).
## What each plan gains (scaled by how well the list suits it, PlanFit); the
## rest of its keys are what it gives up.
const PLAN_UPSIDE := {
	"attacking": ["goal", "gain"], "fast": ["goal", "gain"],
	"defensive": ["press", "opp_goal"], "press": ["press", "opp_goal"],
	"contest": ["contest"],
	"controlled": ["taken", "clangers", "goal", "pace"],
	"through_stars": ["star_ball", "star_goal", "clangers"],
}
const PLANS := {
	"attacking": {"goal": 1.05, "gain": 1.06, "clangers": 1.12, "pace": 1.12, "exposed": 1.07},
	"fast": {"goal": 1.05, "gain": 1.06, "clangers": 1.12, "pace": 1.12, "exposed": 1.07},
	"defensive": {"press": 1.09, "opp_goal": 0.965, "goal": 0.96, "gain": 0.95, "pace": 1.12},
	"press": {"press": 1.09, "opp_goal": 0.965, "goal": 0.96, "gain": 0.95, "pace": 1.12},
	"contest": {"contest": 0.025, "gain": 0.95, "exposed": 1.04},
	"controlled": {"taken": 0.96, "gain": 0.94, "goal": 1.01, "clangers": 0.93, "pace": 0.95},
	# Through stars: the ball to the best three and their finishing (star_ball,
	# star_goal), the ball in good hands; but they know where it's going.
	"through_stars": {"star_ball": 1.3, "star_goal": 1.18, "clangers": 0.92, "taken": 1.04},
}


## A plan's value for this side. Its upside grows with how well the players
## suit it (PlanFit) and how sharply the coaches execute it
## (Squad.tactics_exec, 1.0 = as written); what it gives up is the plan's
## own and does not move.
func _pv(side: int, key: String, fallback := 1.0) -> float:
	var plan := _plan(side)
	var v := float((PLANS.get(plan, {}) as Dictionary).get(key, fallback))
	var scale := 1.0
	if (PLAN_UPSIDE.get(plan, []) as Array).has(key):
		scale = float((squads[side] as Squad).tactics_exec) \
				* float((plan_fit[side] as Dictionary).get(plan, 1.0))
	return fallback + (v - fallback) * scale


## Pressure multiplier `side` faces from the opposition's plan, counters in.
## Controlled tempo takes the sting out of a press as far as its ball users
## can: a side of ordinary ones or better holds it off, poor ones only
## partly (PlanFit, "controlled").
func _press_on(side: int) -> float:
	var m := _pv(1 - side, "press")
	if m > 1.0 and _plan(side) == "controlled":
		var hold := clampf(float((plan_fit[side] as Dictionary).get("controlled", 1.0)), 0.0, 1.0)
		m = 1.0 + (m - 1.0) * (1.0 - hold)
	elif m > 1.0 and (_plan(side) == "attacking" or _plan(side) == "fast"):
		m *= 1.10
	return m


func _plan(side: int) -> String:
	return str((tactics[side] as Dictionary).get("gameplan", "balanced"))


func _pep(side: int) -> String:
	return str((tactics[side] as Dictionary).get("pep", "steady"))


func _focus_id(side: int) -> String:
	return str((tactics[side] as Dictionary).get("focus_id", ""))


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
	var sq: Squad = squads[side]
	var n_centre := 0
	var n_mids := 0
	for p in sq.ground:
		if str(p["role"]) == "MID":
			n_mids += 1
			if not Roles.on_wing(p):
				n_centre += 1
	if n_mids == 0:
		return 0.0
	var drag := 0.0
	var tagged := _on_ground(side, _tag_id(1 - side))
	if not tagged.is_empty() and taggable(tagged):
		drag += (1.0 - _tag_share(1 - side)) * _mid_value(tagged, n_centre, n_mids)
	if _tag_id(side) != "" and not _on_ground(1 - side, _tag_id(side)).is_empty():
		var t = tagger_for(sq.ground)
		if t != null:
			drag += TAGGER_COST * _mid_value(t, n_centre, n_mids)
	return drag


## One midfielder's part in his side's contest number (Squad._aggregate): his
## contested ball in the centre-square mean, his disposal in the midfield's.
func _mid_value(p: Dictionary, n_centre: int, n_mids: int) -> float:
	var v := 0.22 * _a(p, "disposal") / float(maxi(1, n_mids))
	if not Roles.on_wing(p):
		v += 0.42 * _a(p, "contested") / float(maxi(1, n_centre))
	return v


## How much of the ball the player `side` tags still gets: less when a
## tagger (Roles) is on the ground to do the job.
func _tag_share(side: int) -> float:
	var t = tagger_for((squads[side] as Squad).ground)
	return Roles.TAG_WITH_TAGGER if t != null and Roles.is_tagger(t) else Roles.TAG_PLAIN


# ---------------------------------------------------------------------------
# Stat bookkeeping
# ---------------------------------------------------------------------------
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
const CARRY_ROLES := {
	"back": {"DEF": 1.0, "MID": 1.0, "RUCK": 0.3, "FWD": 0.12},
	"middle": {"MID": 1.0, "RUCK": 1.0, "DEF": 1.0, "FWD": 0.3},
	"attack": {"MID": 1.0, "FWD": 1.0, "DEF": 0.2, "RUCK": 0.3},
	"inside": {"FWD": 1.0, "MID": 1.0, "RUCK": 0.3, "DEF": 0.05},
}
## Who takes the shot from an entry: a resting ruck or a defender pushed
## forward kicks the odd goal.
const SHOT_ROLES := {"FWD": 1.0, "MID": 1.0, "RUCK": 0.35, "DEF": 0.06}
## Who wins a clearance: forwards and defenders at a stoppage now and then.
const CLEARANCE_ROLES := {"MID": 1.0, "RUCK": 1.0, "FWD": 0.12, "DEF": 0.10}
## Who is credited a one-percenter (a spoil, smother or shepherd).
const ONE_PCT_ROLES := {"DEF": 1.0, "RUCK": 0.5, "MID": 0.3, "FWD": 0.1}


## `_weighted` over a whole group, each player's weight scaled by his line.
func _weighted_roles(group: Array, key: String, roles: Dictionary, power := 2.0, side := -1, purpose := ""):
	if group.is_empty():
		return null
	var ctx := _pick_ctx(side) if side >= 0 else {}
	var weights := []
	for p in group:
		var w: float = float(roles.get(str(p["role"]), 0.0)) * pow(maxf(1.0, _a(p, key)), power)
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
		var tagger = tagger_for((squads[side] as Squad).ground)
		if tagger != null:
			tagger_id = str(tagger["id"])
	var plan := _plan(side)
	return {"focus": _focus_id(side), "their_tag": their_tag,
			"tag_share": _tag_share(1 - side) if their_tag != "" else 1.0,
			"tagger": tagger_id, "stars": plan == "through_stars",
			"star_ball": _pv(side, "star_ball") if plan == "through_stars" else 1.0}


func _tactic_player_mult(side: int, p: Dictionary, purpose: String, ctx: Dictionary = {}) -> float:
	if ctx.is_empty():
		ctx = _pick_ctx(side)
	var out := 1.0
	var id := str(p["id"])
	var focused := id == str(ctx["focus"])
	# "transition" is a carry in the middle of the ground (pick_carrier).
	var carrying := purpose == "carrier" or purpose == "transition"
	# The wings run the ball through the middle and are not at the stoppage.
	if purpose == "transition" and Roles.on_wing(p):
		out *= Roles.WING_TRANSITION
	elif purpose == "clearance" and Roles.on_wing(p):
		out *= Roles.WING_STOPPAGE
	# A "run it through him" plan makes him the clear ball-winner in the
	# chain, not the shooter: a mid who gets more of the ball delivers more
	# inside 50s and his forwards still take the shots. A small early boost,
	# then the usage curve fades him back toward a low-30s disposal game.
	if focused and carrying:
		out *= 1.14
	if carrying and _trait(p, "ball_magnet"):
		out *= 1.10
	if purpose == "clearance" and _trait(p, "bull"):
		out *= 1.15
	# A Crumber lives at the feet of the pack: he is there when it spills.
	if purpose == "crumb" and _trait(p, "crumber"):
		out *= CRUMBER_AT_FEET
	if id == str(ctx["their_tag"]) and taggable(p) and (carrying or purpose == "shooter" or purpose == "crumb"):
		out *= float(ctx["tag_share"])
	# Our tagger is playing the man, not the ball.
	if carrying and id == str(ctx["tagger"]):
		out *= TAGGER_BALL
	if bool(ctx["stars"]) and (stars[side] as Dictionary).has(id):
		out *= float(ctx["star_ball"])
	if carrying:
		out *= _usage_mult(p, focused)
	return out


## Soft possession cap. Team disposal volume is unchanged — this only stops one
## player absorbing every chain once they have already had a huge game.
## Must match tools/sim_harness.py::usage_multiplier (the unfocused curve).
func _usage_mult(p: Dictionary, focused: bool) -> float:
	var d := 0.0
	var id := str(p["id"])
	if player_stats.has(id):
		d = float((player_stats[id] as Dictionary).get("disposals", 0.0))
	var start := 21.0 if focused else 18.0
	if d <= start:
		return 1.0
	var over := d - start
	var width := 5.4 if focused else 6.4
	return maxf(0.02, exp(-(over * over) / (width * width)))


func _pick(group: Array, weights: Array):
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return group[0]
	var r := rng.randf() * total
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
	var T := Ratings.T
	var lim := float(T["contest_clamp"])
	# Midfield legs scale the contest strength; the Legs line gets the credit.
	var drag0 := _tag_drag(0)
	var drag1 := _tag_drag(1)
	var c0: float = squads[0].contest * _mid_fit(0) - drag0
	var c1: float = squads[1].contest * _mid_fit(1) - drag1
	var legs_edge: float = ((c0 + drag0 - c1 - drag1) - (squads[0].contest - squads[1].contest)) / float(T["contest_swing"])
	_credit(0, "legs", legs_edge * POSSESSION_VALUE)
	_credit(1, "legs", -legs_edge * POSSESSION_VALUE)
	var form_edge := FORM_CONTEST * (float(form[0]) - float(form[1]))
	_credit(0, "form", FORM_CONTEST * float(form[0]) * POSSESSION_VALUE)
	_credit(1, "form", FORM_CONTEST * float(form[1]) * POSSESSION_VALUE)
	var p_home: float = (0.5
			+ (c0 - c1) / float(T["contest_swing"])
			+ home_edge() + form_edge)
	# The side with the run of play wins a little more of the ball.
	p_home += momentum_edge * momentum
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
			+ _contest_traits(side)


func _contest_traits(side: int) -> float:
	return 0.025 if synergies[side].has("engine_room") else 0.0


func _contest_plan(side: int) -> float:
	return _pv(side, "contest", 0.0)


## Fire them up lifts a side at the contest only while it is chasing the
## game; level or in front it has nothing to answer, so the lift is gone
## while the costs (legs, tempers: PEP_FIRE) stay.
func _contest_pep(side: int) -> float:
	if _pep(side) != "fire_up" or score(side) >= score(1 - side):
		return 0.0
	return 0.018


## Calm the group: a quarter-long, milder Slow it down (the "hold" call),
## as Fire them up is a milder Throw numbers at it - fewer clangers, less
## pressure felt and legs that last longer, for less ground gained.
const PEP_CALM := {"clangers": 0.92, "taken": 0.95, "gain": 0.92, "pace": 0.95}
## Fire them up: legs go quicker and tempers fray.
const PEP_FIRE := {"clangers": 1.10, "pace": 1.20}


## The pep talk's multiplier on one chain quantity (1.0 when it has none).
func _pep_mult(side: int, key: String) -> float:
	if _pep(side) == "calm":
		return float(PEP_CALM.get(key, 1.0))
	if _pep(side) == "fire_up":
		return float(PEP_FIRE.get(key, 1.0))
	return 1.0


func _contest_calls(side: int, stoppage: bool) -> float:
	var b := 0.0
	if _burst(side, "stack") and stoppage:
		b += 0.10
	if _burst(side, "surge"):
		b += 0.03
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
		w_all += w
		weights.append(w)
	return [weights, w_all / w_base if w_base > 0.0 else 1.0]


## Pay a football free with a real cause. Returns the mark after any 50.
func _award_context_free(receiving_side: int, mark_fp: float, offender, recipient,
		cause: String, label: String) -> float:
	_t(receiving_side, "frees_for")
	_p(recipient, "frees_for")
	_t(1 - receiving_side, "frees_against")
	_p(offender, "frees_against")
	_t(receiving_side, "free_" + cause)
	var who := GameDB.player_display_name(recipient) if recipient != null else "the opposition"
	_emit("free", receiving_side, mark_fp, recipient, "%s — free kick to %s" % [label, who])
	var ev: Dictionary = events[events.size() - 1]
	ev["free_cause"] = cause
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
	return free_rng.randf() < clampf(p, 0.006, 0.045)


## Holding the ball only exists after a legal tackle actually stops the carrier.
## More prior opportunity (later in the chain) makes it more likely; clean
## contested/disposal players are a little harder to catch.
func _holding_ball_free(carrier, touches: int) -> bool:
	if carrier == null:
		return false
	var p := HTB_PRIOR if touches > 1 else HTB_NO_PRIOR
	p *= 1.18 - 0.30 * _a(carrier, "contested") / 100.0
	p *= 1.12 - 0.24 * _a(carrier, "disposal") / 100.0
	return free_rng.randf() < clampf(p, 0.05, 0.28)


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
	var r := free_rng.randf()
	if r < clampf(def_p, 0.004, 0.035):
		return {"side": side, "offender": defender, "recipient": attacker,
				"cause": "marking", "label": "Holding in the marking contest"}
	if r < clampf(def_p, 0.004, 0.035) + clampf(att_p, 0.003, 0.025):
		return {"side": 1 - side, "offender": attacker, "recipient": defender,
				"cause": "marking", "label": "Blocking in the marking contest"}
	return {}


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
	var chance := FIFTY_BASE * (1.35 - 0.70 * discipline / 100.0)
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
	var chance := REPORT_BASE * (1.30 - 0.60 * discipline / 100.0)
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


## A won stoppage is worth about a possession chain's points.
const POSSESSION_VALUE := 1.0
const TURNOVER_VALUE := 0.5
const CLANGER_VALUE := 0.6


func _credit_contest(side: int, stoppage: bool) -> void:
	_credit(side, "gameplan", _contest_plan(side) * POSSESSION_VALUE)
	_credit(side, "pep", _contest_pep(side) * POSSESSION_VALUE)
	_credit(side, "calls", _contest_calls(side, stoppage) * POSSESSION_VALUE)
	_credit(side, "traits", _contest_traits(side) * POSSESSION_VALUE)


func _credit(side: int, cause: String, pts: float) -> void:
	if pts == 0.0:
		return
	var d: Dictionary = impact[side]
	d[cause] = float(d.get(cause, 0.0)) + pts


## Pressure by zone. Where the ball is, from the carrier's end: his back
## third (their forwards press), the middle (their midfield), his forward
## third (their defenders). Each role's share of the pressing there; a
## player's chance to be the one applying it is this times Pressure squared.
const PRESS_ZONES := [
	{"FWD": 1.0, "MID": 0.75, "RUCK": 0.30, "DEF": 0.10},
	{"FWD": 0.30, "MID": 1.0, "RUCK": 0.70, "DEF": 0.30},
	{"FWD": 0.10, "MID": 0.75, "RUCK": 0.30, "DEF": 1.0},
]
const PRESS_ZONE_EDGE := 20.0
## Non-tackle pressure acts per tackle chance, the share of those that turn
## the ball over outright, and the ground a rushed disposal still gains.
const PRESS_RUSH_RATIO := 2.0
const PRESS_TURNOVER := 0.08
const PRESS_RUSH_GAIN := 0.80
## A close defender occasionally gets boot to ball. Around one or two per
## match across both sides; pressure and the smotherer's ability move it.
const SMOTHER_BASE := 0.008
const SMOTHER_CAP := 0.022
## A subset of genuine 15m+ kicks outside forward 50 become aerial contests.
## Most ordinary kicks still use the calibrated chain model unchanged.
const GENERAL_AERIAL_P := 0.040
const GENERAL_SPOIL_BASE := 0.56
const GENERAL_MARK_ROLES := {"FWD": 1.0, "MID": 0.85, "DEF": 0.65, "RUCK": 0.70}


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


## Who applies the pressure: zone opportunity x Pressure squared, so the
## best pressers do most of it without doing all of it.
func _pick_presser(side: int, zone: int):
	var w: Dictionary = PRESS_ZONES[zone]
	var group: Array = (squads[side] as Squad).ground
	var weights := []
	var ctx := _pick_ctx(side)
	for p in group:
		weights.append(float(w.get(str(p["role"]), 0.0))
				* pow(maxf(1.0, _a(p, "pressure")), 2.0)
				* _tactic_player_mult(side, p, "tackler", ctx))
	return _pick(group, weights)


## General-play aerial contest on an unmarked kick. We only create one when
## the kick has enough length to plausibly be contested. A spoil is a fist to
## a real contest and leaves the ball loose; it is never automatic possession.
func _general_aerial(side: int, mark_fp: float, carrier, gain: float, rushed: bool) -> Dictionary:
	if rushed or gain < 18.0 or aerial_rng.randf() >= 0.22:
		return {}
	var opp := 1 - side
	var receiver = pick_carrier(side, mark_fp)
	var defenders := _by_roles((squads[opp] as Squad).ground, ["DEF", "MID"])
	if receiver == null or defenders.is_empty():
		return {}
	var defender = _weighted(defenders, "intercept", 2.0, opp, "defender")
	var receive := _a(receiver, "marking")
	var stop := 0.62 * _a(defender, "intercept") + 0.38 * _a(defender, "marking")
	var mark_p := clampf(0.34 + (receive - stop) / 240.0
			+ (0.05 if _trait(receiver, "aerial") else 0.0), 0.16, 0.55)
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
		return {"outcome": "mark", "actor": receiver}
	var spoil_p := clampf(0.36 + (stop - receive) / 220.0
			+ (0.07 if _trait(defender, "interceptor") else 0.0), 0.20, 0.65)
	if roll < mark_p + spoil_p:
		_t(opp, "spoils")
		_p(defender, "spoils")
		_t(opp, "one_percenters")
		_p(defender, "one_percenters")
		_emit("spoil", opp, mark_fp, defender,
				"%s spoils the aerial contest" % GameDB.player_display_name(defender))
		var sev: Dictionary = events[events.size() - 1]
		sev["general_play"] = true
		sev["against_id"] = str(receiver.get("id", ""))
		return {"outcome": "loose", "actor": defender}
	return {}


func pick_carrier(side: int, fp: float):
	var T := Ratings.T
	var sq: Squad = squads[side]
	var atk_fp := fp if side == 0 else -fp
	var zone: String
	var key: String
	var purpose := "carrier"
	if atk_fp < -10.0:
		zone = "back"
		key = "intercept"
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
	return _weighted_roles(sq.ground, key, CARRY_ROLES[zone], 2.0, side, purpose)


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
		var v := 0.58 * _a(p, "carry") + 0.42 * _a(p, "disposal")
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
func _general_aerial_contest(side: int, mark_fp: float, carrier) -> Dictionary:
	var opp := 1 - side
	var target = _weighted_roles((squads[side] as Squad).ground, "marking",
			GENERAL_MARK_ROLES, 2.0, side, "aerial_target")
	var defs := _by_roles((squads[opp] as Squad).ground, ["DEF"])
	if defs.is_empty():
		defs = (squads[opp] as Squad).ground
	var defender = _weighted(defs, "intercept", 2.0, opp, "aerial_defender")
	if target == null or defender == null:
		return {}
	var roaming := false
	var roamer := _roaming_interceptor(opp)
	if not roamer.is_empty() and str(roamer.get("id", "")) != str(defender.get("id", "")) 			and aerial_rng.randf() < _roam_chance(opp):
		defender = roamer
		roaming = true
		_t(opp, "roam_contests")
		_p(defender, "roam_contests")

	var infringement := _marking_free(side, target, defender)
	if not infringement.is_empty():
		var free_side := int(infringement["side"])
		var mark := _award_context_free(free_side, mark_fp,
				infringement["offender"], infringement["recipient"],
				str(infringement["cause"]), str(infringement["label"]))
		if roaming:
			if free_side == opp:
				_p(defender, "roam_wins")
			else:
				_p(defender, "roam_losses")
		return {"outcome": "free", "fp": mark, "actor": infringement["recipient"],
				"free_side": free_side}

	var mark_edge := (_a(target, "marking") - _a(defender, "intercept")) / 260.0
	if _trait(target, "aerial"):
		mark_edge += 0.05
	var mark_p := clampf(0.42 + mark_edge, 0.18, 0.70)
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
			mev["roaming_interceptor_id"] = str(defender.get("id", ""))
			_p(defender, "roam_losses")
		return {"outcome": "mark", "fp": mark_fp, "actor": target}

	var spoil_p := clampf(GENERAL_SPOIL_BASE
			+ (_a(defender, "intercept") - _a(target, "marking")) / 300.0
			+ (0.06 if _trait(defender, "interceptor") else 0.0), 0.30, 0.82)
	if aerial_rng.randf() < spoil_p:
		_t(opp, "spoils")
		_p(defender, "spoils")
		_t(opp, "one_percenters")
		_p(defender, "one_percenters")
		_emit("spoil", opp, mark_fp, defender,
				"%s spoils the marking contest" % GameDB.player_display_name(defender))
		var sev: Dictionary = events[events.size() - 1]
		sev["against_id"] = str(target.get("id", ""))
		sev["general_play"] = true
		if roaming:
			sev["roaming_interceptor"] = true
			_p(defender, "roam_wins")
		return {"outcome": "loose", "fp": mark_fp, "actor": defender}
	if roaming:
		_p(defender, "roam_losses")
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


## A ruckman by his own listing (first or second position), whatever spot
## he is standing in today.
static func _is_ruckman(p: Dictionary) -> bool:
	return str(p.get("own_role", p.get("role", ""))) == "RUCK" or str(p.get("role2", "")) == "RUCK"


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
	var T := Ratings.T
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

func _stoppage(side: int, opp: int, from_bounce: bool) -> void:
	if not from_bounce:
		return
	var T := Ratings.T
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
			mid = _weighted_roles(atk.ground, "contested", CLEARANCE_ROLES, 2.0, side, "clearance")
		_p(mid, "clearances")


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
	var T := Ratings.T
	var opp := 1 - side
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]
	var dir := 1.0 if side == 0 else -1.0
	var f50 := float(T["forward50_line"])
	var gline := float(T["goal_line"])

	_t(side, "chains")
	_stoppage(side, opp, from_bounce)

	var atk_fp := fp if side == 0 else -fp
	# A chain that starts inside its forward 50 (a ball-up won there) goes
	# through the normal entry below on its first disposal, so it can score.
	var touched_i50 := false

	var touches := 0
	var max_touches := int(T["max_touches_per_chain"])
	# The last disposal, until we know where it went: effective if his side
	# has it next, not if he is caught with it or the chain dies in a
	# stoppage or an entry is rebounded (disposal efficiency).
	var pending = null
	while touches < max_touches:
		touches += 1
		if pending != null:
			_effective(side, pending)
			pending = null
		var is_kick_in := from_kick_in and touches == 1
		var carrier = kick_in_taker(side) if is_kick_in else pick_carrier(side, fp)
		var kick_in_play_on := _kick_in_play_on(carrier) if is_kick_in else false
		_chain_touch[str(carrier["id"])] = carrier
		# Champion Data: a kick straight from the goal square is a team
		# kick-in, not a player disposal. Once the taker plays on it is his
		# disposal like ordinary play.
		var counts_disposal := not is_kick_in or kick_in_play_on
		if counts_disposal:
			_t(side, "disposals")
			_p(carrier, "disposals")
		if is_kick_in:
			_t(side, "kick_ins")
			_p(carrier, "kick_ins")
			if kick_in_play_on:
				_t(side, "kick_in_play_ons")
				_p(carrier, "kick_in_play_ons")
		pending = carrier if counts_disposal else null

		var hb_bias: float = (0.85
				+ 0.30 * (100.0 - _a(carrier, "marking")) / 100.0)
		var disposal_kind := "handball"
		var marked := false
		# A kick-in is kicked: no handball roll for its first disposal.
		if not (from_kick_in and touches == 1) \
				and rng.randf() < float(T["handball_share"]) * hb_bias:
			_t(side, "handballs")
			_p(carrier, "handballs")
			_emit("handball", side, fp, carrier, "%s handballs" % GameDB.player_display_name(carrier))
		else:
			disposal_kind = "kick"
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
		if is_kick_in:
			# The conservative exit buys space; playing on gains ground but
			# exposes the taker to more immediate pressure.
			pressure *= 0.68 if not kick_in_play_on else 0.92
		var p_base := pressure
		pressure *= _press_on(side)
		_credit(opp, "gameplan", (pressure - p_base) * TURNOVER_VALUE)
		if synergies[opp].has("lockdown_unit"):
			_credit(opp, "traits", pressure * 0.08 * TURNOVER_VALUE)
			pressure *= 1.08
		p_base = pressure
		pressure *= _pv(side, "taken")
		_credit(side, "gameplan", (p_base - pressure) * TURNOVER_VALUE)
		p_base = pressure
		pressure *= _pep_mult(side, "taken")
		_credit(side, "pep", (p_base - pressure) * TURNOVER_VALUE)
		if _burst(side, "hold"):
			_credit(side, "calls", pressure * 0.15 * TURNOVER_VALUE)
			pressure *= 0.85

		# One roll, three outcomes: a tackle, a pressured (rushed) disposal,
		# or no pressure at all. Both of the first two are pressure acts.
		var press_roll := rng.randf()
		var rushed := false
		if press_roll < pressure:
			var tackler = _pick_presser(opp, zone)
			_maybe_report(opp, tackler, carrier)
			_t(opp, "tackles")
			_p(tackler, "tackles")
			_t(opp, "pressure_acts")
			_p(tackler, "pressure_acts")
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
				continue
			_t(opp, "pressure_wins")
			# A legal tackle that stops him can be holding the ball; otherwise
			# it remains the ball-up the engine already had.
			if _holding_ball_free(carrier, touches):
				var mark := _award_context_free(opp, fp, carrier, tackler,
						"holding_ball", "Holding the ball")
				return {"outcome": "free", "fp": mark, "actor": tackler, "free_side": opp}
			_emit("tackle", opp, fp, tackler,
					"%s tackles %s - ball up" % [GameDB.player_display_name(tackler), GameDB.player_display_name(carrier)])
			return {"outcome": "stoppage", "fp": fp, "actor": carrier}
		if press_roll < pressure * (1.0 + PRESS_RUSH_RATIO):
			# Closed down without a tackle: the disposal is rushed. It gains
			# less ground, and sometimes goes straight to the opposition -
			# likelier against a strong presser, less likely from a clean
			# user of the ball.
			var presser = _pick_presser(opp, zone)
			_t(opp, "pressure_acts")
			_p(presser, "pressure_acts")
			var turn_p: float = (PRESS_TURNOVER
					* (0.80 + 0.40 * _a(presser, "pressure") / 100.0)
					* (1.20 - 0.40 * _a(carrier, "disposal") / 100.0))
			if rng.randf() < turn_p:
				_t(opp, "pressure_wins")
				_intercept(opp, presser, false)
				_emit("pressure", opp, fp, presser,
						"%s forces the turnover" % GameDB.player_display_name(presser))
				return {"outcome": "turnover", "fp": fp, "actor": presser}
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
				_emit("smother", opp, fp, smotherer,
						"%s smothers the kick" % GameDB.player_display_name(smotherer))
				return {"outcome": "loose", "fp": fp, "actor": smotherer}

		var prev_atk_fp := atk_fp
		var gain: float = (float(T["metres_gain_mean"])
				* (0.55 + 0.90 * _a(carrier, "carry") / 100.0))
		gain *= _pv(side, "gain") * _pep_mult(side, "gain")
		if synergies[side].has("supply_line"):
			gain *= 1.12
		if _burst(side, "flood") or _burst(side, "hold"):
			gain *= 0.85
		gain *= rng.randf_range(0.45, 1.75)
		if is_kick_in:
			gain *= 0.82 if not kick_in_play_on else 1.12
		if rushed:
			gain *= PRESS_RUSH_GAIN
		fp += gain * dir
		fp = clampf(fp, -gline, gline)
		atk_fp = fp if side == 0 else -fp
		_metres(side, carrier, atk_fp - prev_atk_fp)

		# Outside forward 50, a genuine long kick can become a contested
		# aerial ball. A mark retains it; a spoil makes the next chain loose.
		if disposal_kind == "kick" and not marked and gain >= 15.0 and atk_fp < f50 				and aerial_rng.randf() < GENERAL_AERIAL_P:
			var aerial := _general_aerial_contest(side, fp, carrier)
			if not aerial.is_empty():
				match str(aerial["outcome"]):
					"mark":
						_effective(side, carrier)
						pending = null
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
				# A mark keeps the same side's chain alive at the new field
				# position. It is not another disposal by the original kicker.
				pending = carrier
				continue

		# Rebound 50: winning it out of your own defensive arc.
		if prev_atk_fp < float(T["rebound_from"]) and atk_fp > float(T["rebound_to"]):
			_t(side, "rebounds")
			_p(carrier, "rebounds")

		if atk_fp >= f50 and not touched_i50:
			touched_i50 = true
			_t(side, "inside50")
			_p(carrier, "inside50")
			_emit("inside50", side, fp, carrier,
					"%s sends it inside 50" % GameDB.player_display_name(carrier))
			var entry := resolve_forward50(side, fp, carrier)
			# A rebound or a free paid to the defence makes the entry
			# ineffective. A free to the attacking side still retained the ball.
			var effective_entry := str(entry["outcome"]) != "turnover"
			if str(entry["outcome"]) == "free" and int(entry.get("free_side", side)) != side:
				effective_entry = false
			if effective_entry:
				_effective(side, carrier)
			return entry

		# A clean exit from your own defensive 50 is a rebound.
		if atk_fp > 5.0 and atk_fp - gain <= -f50:
			_t(opp, "rebounds")
			_p(carrier, "rebounds")

	return {"outcome": "stoppage", "fp": fp, "actor": null}


## Where the defending side kicks in from after `side` scores a behind: the
## middle of the goal square (9 m deep) at the end `side` attacks.
func kick_in_fp(side: int) -> float:
	var dir := 1.0 if side == 0 else -1.0
	return dir * (float(Ratings.T["goal_line"]) - GOAL_SQUARE_DEPTH * 0.5)


## Forward-50 entry resolution: contest the mark, then roll for goal / behind /
## rebound. This is where almost all of the scoring variance lives.
func resolve_forward50(side: int, fp: float, feeder) -> Dictionary:
	var T := Ratings.T
	var opp := 1 - side
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]

	var shooter = _weighted_roles(atk.ground, "goalkicking", SHOT_ROLES, float(T["shooter_power"]), side, "shooter")
	# Sides look for their key forwards on the way in: a share of entries go
	# to one of them (the better one more often), into his match-up.
	var keys := []
	for fid in (duels[opp] as Dictionary):
		var kf := _on_ground(side, str(fid))
		if not kf.is_empty():
			keys.append(kf)
	if not keys.is_empty() and rng.randf() < Matchups.KEY_TARGET:
		keys.sort_custom(func(a, b): return Matchups.forward_air(a) > Matchups.forward_air(b))
		shooter = keys[0] if keys.size() == 1 or rng.randf() < 0.6 else keys[1]

	var dgroup := _by_roles(dfn.ground, ["DEF"])
	if dgroup.is_empty():
		dgroup = dfn.ground
	var defender = _weighted(dgroup, "intercept", 2.0, opp, "defender")
	# A forward with a direct opponent contests it with him: their aerial
	# games decide it on top of the lines (Matchups).
	_duel = {}
	var duel_shift := 0.0
	var matched := _on_ground(opp, str((duels[opp] as Dictionary).get(str(shooter["id"]), "")))
	if not matched.is_empty():
		defender = matched
		duel_shift = Matchups.mark_shift(shooter, matched)

	# The loose interceptor can arrive as a third man. He is not a second
	# direct matchup: another defender still owns the forward assignment.
	var roaming := false
	var roamer := _roaming_interceptor(opp)
	var roam_shift := 0.0
	if not roamer.is_empty() and str(roamer.get("id", "")) != str(defender.get("id", "")) 			and aerial_rng.randf() < _roam_chance(opp):
		defender = roamer
		roaming = true
		roam_shift = -clampf((Matchups.interceptor_score(roamer) - 55.0) / 450.0, 0.0, 0.10)
		_t(opp, "roam_contests")
		_p(roamer, "roam_contests")

	# A marking infringement is paid from the contest itself, not from a
	# post-chain generic dice roll.
	var infringement := _marking_free(side, shooter, defender)
	if not infringement.is_empty():
		var free_side := int(infringement["side"])
		var mark_fp := _award_context_free(free_side, fp,
				infringement["offender"], infringement["recipient"],
				str(infringement["cause"]), str(infringement["label"]))
		if roaming:
			if free_side == opp:
				_p(defender, "roam_wins")
			else:
				_p(defender, "roam_losses")
		return {"outcome": "free", "fp": mark_fp, "actor": infringement["recipient"],
				"free_side": free_side}

	var mark_edge := 0.06 if _trait(shooter, "aerial") else 0.0
	# A named contest can be lopsided: a great forward on a small defender
	# marks nearly everything, so its ceiling is higher than the lines'.
	var mark_cap := 0.78 if matched.is_empty() else Matchups.DUEL_CAP
	# Sending a forward to make the spare accountable drags him away, but
	# costs a little aerial presence of your own.
	var accountable_cost := 0.035 if _spare_accountable(side) else 0.0
	var marked := rng.randf() < clampf(
			0.5 + (atk.fwd_mark - dfn.def_intercept) / 240.0 + mark_edge + duel_shift
			+ roam_shift - accountable_cost, 0.10, mark_cap)
	# A third-man arrival is not credited to the direct defender's 1v1 log.
	# Interceptor contests have their own evidence/stats and story.
	if not matched.is_empty() and not roaming:
		var fid := str(shooter["id"])
		if not duel_log.has(fid):
			duel_log[fid] = {"side": side, "contests": []}
		(duel_log[fid]["contests"] as Array).append([current_quarter, str(matched["id"]), marked, false])
		_duel = {"fwd": fid, "def": str(matched["id"]), "won": "fwd" if marked else "def",
				"q": current_quarter, "n": (duel_log[fid]["contests"] as Array).size()}
	if marked:
		_t(side, "marks")
		_p(shooter, "marks")
		# Most forward marks come on the lead; some are taken in a one-on-one
		# (stat_rng, so play is unchanged).
		var contested := stat_rng.randf() < 0.35 + mark_edge
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
		mev["contested"] = contested
		mev["speccy"] = speccy
		if roaming:
			mev["roaming_interceptor_id"] = str(defender.get("id", ""))
			_p(defender, "roam_losses")
	var spoil_edge := 0.05 if defender != null and _trait(defender, "interceptor") else 0.0
	var spoil_read := dfn.def_intercept
	if roaming and defender != null:
		spoil_read = 0.5 * dfn.def_intercept + 0.5 * Matchups.defender_air(defender)
	elif not matched.is_empty():
		# His own reading of the ball, alongside the line's.
		spoil_read = 0.5 * dfn.def_intercept + 0.5 * Matchups.defender_air(matched)
	# In a named contest the same aerial gap decides whether he gets a fist
	# to it (Matchups): a defender on top spoils more, one beaten spoils less.
	var spoilt := rng.randf() < clampf(0.30 + 0.35 * spoil_read / 100.0 + spoil_edge - duel_shift, 0.05, 0.95)
	if spoilt and not marked and defender != null:
		# He got a fist to it: a spoil (a credit only).
		_t(opp, "spoils")
		_p(defender, "spoils")
		if roaming:
			_p(defender, "roam_wins")
	if rng.randf() < float(T["one_percenter_share"]):
		_t(opp, "one_percenters")
		_p(_one_percenter(opp), "one_percenters")

	var goal_p := shot_chance(side, shooter, marked, spoilt, true, feeder, defender)
	var behind_p: float = (float(T["inside50_behind"])
			* (0.80 + 0.40 * _a(shooter, "goalkicking") / 100.0))
	# If the spare flies and does not kill the ball, the space behind him is
	# the price of the role: the resulting chance is slightly more dangerous.
	if roaming and not spoilt:
		goal_p *= 1.08 if marked else 1.04
		behind_p *= 1.03
		if not marked:
			_p(defender, "roam_losses")
	# Beaten in the air by his direct opponent, a key forward rarely gets the
	# shot himself: the ball spills or the defender clears it.
	if not matched.is_empty() and not marked:
		goal_p *= Matchups.BEATEN_SHOT
		behind_p *= Matchups.BEATEN_SHOT

	# A mark inside 50 is a set shot from a distance and angle, or the ball
	# goes on (SET_BANDS); the chances come from where he kicks from.
	var set_shot := {}
	var shot_fp := fp
	if marked:
		var split := _set_shot_split(goal_p, behind_p)
		goal_p = float(split["goal"])
		behind_p = float(split["behind"])
		set_shot = split["band"]
		if not set_shot.is_empty():
			shot_fp = (1.0 if side == 0 else -1.0) * (float(T["goal_line"]) - float(set_shot["metres"]))

	if side == moment_side and not set_shot.is_empty() and _moment_ready():
		var close := current_quarter >= 4 and absi(score(side) - score(opp)) <= 18
		# Asked about as often as before: a set shot is under half the marks,
		# and a game has more chains than the 180 this was set for.
		if moment_rng.randf() < (1.0 if close else 0.49 * 180.0 / float(T["chains_per_game"])):
			_offer_set_shot(side, shot_fp, shooter, defender, set_shot, feeder)
			return {"outcome": "moment", "fp": shot_fp, "actor": shooter}

	var roll := rng.randf()
	if roll < goal_p:
		_t(side, "goals")
		_p(shooter, "goals")
		_assist(side, feeder, shooter)
		_scored(side, 6, shooter)
		q_goals[current_quarter - 1][side] += 1
		_score_run(side)
		_emit("goal", side, shot_fp, shooter, _scoreline(side, "GOAL"))
		events[events.size() - 1]["set"] = not set_shot.is_empty()
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
		_tag_shot(not set_shot.is_empty())
		return {"outcome": "behind", "fp": kick_in_fp(side), "actor": shooter}

	# A spoil puts it on the deck rather than in the defender's hands: the
	# forwards crumb it now and then and snap, otherwise the defence clears.
	if spoilt and not marked:
		var crumb := _crumb(side, fp)
		if not crumb.is_empty():
			return crumb

	_t(opp, "rebounds")
	_p(defender, "rebounds")
	_intercept(opp, defender, not spoilt)
	if roaming and not spoilt:
		_p(defender, "roam_wins")
	_emit("rebound", opp, fp, defender,
			"%s rebounds it out of danger" % GameDB.player_display_name(defender))
	return {"outcome": "turnover", "fp": fp, "actor": defender}


## The ball off a spoil, on the ground inside 50: a crumbing forward (the
## small forwards who hunt it) wins it now and then and snaps. {} when the
## defence clears it or the snap misses everything.
func _crumb(side: int, fp: float) -> Dictionary:
	var crumber = _weighted_roles((squads[side] as Squad).ground, "pressure", CRUMB_ROLES, 2.0, side, "crumb")
	if crumber == null or rng.randf() >= CRUMB_P * (0.7 + 0.6 * _a(crumber, "pressure") / 100.0):
		return {}
	var snap := shot_chance(side, crumber, false, false) * CRUMB_SNAP
	var behind_p: float = float(Ratings.T["inside50_behind"]) * (0.80 + 0.40 * _a(crumber, "goalkicking") / 100.0)
	var r := rng.randf()
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
func _intercept(side: int, who, could_mark: bool) -> void:
	if who == null or (who as Dictionary).is_empty():
		return
	_t(side, "intercepts")
	_p(who, "intercepts")
	_won_back = {"side": side, "id": str(who.get("id", ""))}
	if could_mark and stat_rng.randf() < 0.35 * (0.5 + _a(who, "intercept") / 100.0):
		_t(side, "marks")
		_p(who, "marks")
		if stat_rng.randf() < 0.5:
			_t(side, "contested_marks")
			_p(who, "contested_marks")


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
	momentum = clampf(momentum + s * amount * (1.0 - s * momentum), -1.0, 1.0)


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
	var T := Ratings.T
	var opp := 1 - side
	var atk: Squad = squads[side]
	var dfn: Squad = squads[opp]
	var goal_p := float(T["inside50_goal"])
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
	if _plan(side) == "through_stars" and (stars[side] as Dictionary).has(str(shooter.get("id", ""))):
		own *= _pv(side, "star_goal")
	goal_p *= own
	if credit:
		_credit(side, "gameplan", 6.0 * (goal_p - before))
	before = goal_p
	# Controlled tempo picks the press apart and is too slow to punish an
	# attacking side on the rebound; everyone else meets both in full.
	if _plan(side) != "controlled":
		goal_p *= _pv(opp, "opp_goal")
		goal_p *= _pv(opp, "exposed")
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
		tr *= 1.08
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
		dtr *= 0.91
	goal_p *= dtr
	if credit:
		_credit(opp, "traits", 6.0 * (before - goal_p))
	before = goal_p
	var call_mult := 1.0
	# Throw numbers at it: more of your shots go in. Slow it down: fewer
	# shots at goal, both ends - the game goes quiet. Flood: numbers back.
	if _burst(side, "surge"):
		call_mult *= 1.12
	if _burst(side, "hold"):
		call_mult *= 0.90
	if _burst(side, "flood"):
		call_mult *= 0.90
	goal_p *= call_mult
	if credit:
		_credit(side, "calls", 6.0 * (goal_p - before))
	before = goal_p
	var opp_mult := 1.0
	if _burst(opp, "flood"):
		opp_mult *= 0.80
	if _burst(opp, "hold"):
		opp_mult *= 0.85
	if _burst(opp, "stack"):
		opp_mult *= 1.12
	if _burst(opp, "surge"):
		opp_mult *= 1.25
	goal_p *= opp_mult
	if credit:
		_credit(opp, "calls", 6.0 * (before - goal_p))
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
	var T := Ratings.T
	# A tired-star call lasts to the break.
	_held.clear()
	if current_quarter > 1:
		for id in energy:
			energy[id] = minf(float(energy_caps.get(id, 100.0)), float(energy[id]) + ENERGY_BREAK_RECOVER)
	# AI clubs pick their plan for the quarter from the score and what they
	# have seen (no dice: replays are unchanged).
	for side in range(2):
		if (squads[side] as Squad).ai_plans:
			set_tactics(side, ai_tactics(side))
			if current_quarter > 1:
				_ai_rematch(side)
	# Snapshot the plans in force this quarter - after the AI has picked its
	# own, so the break says what they actually ran, not last quarter's plan.
	# Before any rolls; duplicates only, no RNG draws.
	tactics_history.append({
		"quarter": current_quarter,
		"plans": [(tactics[0] as Dictionary).duplicate(), (tactics[1] as Dictionary).duplicate()],
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
	var T := Ratings.T
	while _q_i < _q_count:
		if not pending_moment.is_empty():
			return false
		current_minute = (current_quarter - 1) * 30 + int(30 * _q_i / maxi(1, _q_count)) + 1
		if moment_side >= 0 and _boundary_moment():
			return false
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
	return finals_mode and not extra_time_played and current_quarter > 4 \
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
	var T := Ratings.T
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
		while score(0) == score(1) and guard < GOLDEN_POINT_CHAINS:
			current_minute = 128 + int(guard / 4)
			_play_one_chain(T)
			guard += 1
	_emit_full_time("Full time (after extra time)")
	return result()


const GOLDEN_POINT_CHAINS := 60


func _emit_full_time(prefix: String) -> void:
	_emit("final", -1, 0.0, null, "%s - %s %d.%d (%d) | %s %d.%d (%d)" % [
			prefix, squads[0].name, goals(0), behinds(0), score(0),
			squads[1].name, goals(1), behinds(1), score(1)])


## Play `count` possession chains, stamping minutes across `span` minutes
## from `minute_base`. Shared by the four quarters and extra time; the RNG
## call order is exactly the original quarter loop's.
func _play_chains(count: int, minute_base: int, span: int) -> void:
	var T := Ratings.T
	for i in range(count):
		current_minute = minute_base + int(span * i / maxi(1, count)) + 1
		_play_one_chain(T)


func _play_one_chain(T: Dictionary) -> void:
	# A kick-in after a behind is not a stoppage: no ruck contest, no clearance.
	# A boundary throw-in is: it always starts with a contested stoppage.
	var from_kick_in := kick_in
	var from_boundary := boundary_throw_in
	kick_in = false
	boundary_throw_in = false
	var stoppage := at_centre or from_boundary \
			or (not from_kick_in and rng.randf() < float(T["stoppage_share"]))
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
	_chain_touch = {}
	_chain_from = _won_back if chain_origin == "turnover" else {}
	_won_back = {}
	var res := play_chain(side, start_fp, stoppage, from_kick_in)
	var outcome: String = res["outcome"]
	fp = res["fp"]
	if outcome == "moment":
		# The chain ends on the coach's call: resolve_moment() finishes it.
		return

	# Goal: centre bounce. Behind: the other side kicks in (fp is already the
	# goal square). A free gives the other side possession at the crossing;
	# a boundary exit restarts with a contested throw-in at the same fp.
	at_centre = (outcome == "score")
	kick_in = (outcome == "behind")
	boundary_throw_in = (outcome == "boundary")
	next_side = (1 - side) if ["turnover", "behind", "free"].has(outcome) else -1
	_prev_end = outcome
	if outcome == "score":
		fp = 0.0
	if ["boundary", "free", "loose"].has(outcome):
		_after_chain()
		return

	# End-of-chain error: a clanger, sometimes a free kick against.
	var cw := _clanger_weights(side)
	var clanger_p := float(T["clanger_per_chain"]) / HOTHEAD_BASE
	var hot_mult := float(cw[1])
	_credit(side, "traits", -clanger_p * (hot_mult - 1.0) * CLANGER_VALUE)
	clanger_p *= hot_mult
	var cl_mult := _pv(side, "clangers")
	_credit(side, "gameplan", clanger_p * (1.0 - cl_mult) * CLANGER_VALUE)
	clanger_p *= cl_mult
	var pep_cl := _pep_mult(side, "clangers")
	_credit(side, "pep", clanger_p * (1.0 - pep_cl) * CLANGER_VALUE)
	clanger_p *= pep_cl
	var form_cl := 1.0 - FORM_COMPOSURE * float(form[side])
	_credit(side, "form", clanger_p * (1.0 - form_cl) * CLANGER_VALUE)
	clanger_p *= form_cl
	if _burst(side, "hold"):
		_credit(side, "calls", clanger_p * 0.25 * CLANGER_VALUE)
		clanger_p *= 0.75
	if rng.randf() < clanger_p:
		var err = _pick(squads[side].ground, cw[0])
		_t(side, "clangers")
		_p(err, "clangers")
		_emit("clanger", side, fp, err,
				"%s gives away a clanger" % GameDB.player_display_name(err))
		# After a behind the kick-in comes first: no free is paid over it.
		if not kick_in and free_rng.randf() < float(T["clanger_is_free"]) * GENERIC_FREE_MULT:
			var recipient = _free_to(1 - side, fp if side == 0 else -fp)
			next_side = 1 - side
			_prev_end = "free"
			fp = _award_context_free(1 - side, fp, err, recipient,
					"general", "General infringement")
			# Play restarts from the free (and any 50), not another bounce.
			at_centre = false
			boundary_throw_in = false
	_after_chain()


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


func result() -> Dictionary:
	var s0 := score(0)
	var s1 := score(1)
	var winner := 0 if s0 > s1 else (1 if s1 > s0 else -1)
	var qsc := []
	for q in range(4):
		qsc.append([q_goals[q][0] * 6 + q_behinds[q][0],
				q_goals[q][1] * 6 + q_behinds[q][1]])
	return {
		"roster": rosters(),
		"stars": [(stars[0] as Dictionary).keys(), (stars[1] as Dictionary).keys()],
		"score": [s0, s1],
		"goals": [goals(0), goals(1)],
		"behinds": [behinds(0), behinds(1)],
		"quarters": qsc,
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
		"quarter_teams": quarter_teams.duplicate(true),
		"extra_time": extra_time_played,
		"impact": impact.duplicate(true),
		"moments": moments.duplicate(true),
		"interchanges": interchanges.duplicate(),
		"duels": duel_log.duplicate(true),
		"duel_changes": duel_changes.duplicate(true),
		"matchups": duels.duplicate(true),
		"interceptor": interceptor.duplicate(),
		"interceptor_changes": interceptor_changes.duplicate(true),
		"injuries": injuries.duplicate(true),
		"reports": reports.duplicate(true),
		"synergies": synergies.duplicate(true),
	}


# ---------------------------------------------------------------------------
# Legs: fatigue and rotations
# ---------------------------------------------------------------------------
const ENERGY_DRAIN := 0.9            # per chain on the ground, before modifiers
const ENERGY_BENCH_RECOVER := 4.0    # per chain on the bench
const ENERGY_BREAK_RECOVER := 20.0   # at each quarter break
const ROTATE_EVERY := 3              # chains between rotation checks
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
## Riding the stars, a star this cooked brings the one tired call of the match.
const TIRED_CALL := 45.0
## Energy below which a player is rotated off: stars are ridden harder.
const ROTATION_POLICIES := {
	"hard": {"label": "Rotate hard", "role": 80.0, "star": 68.0,
			"text": "Fresh legs all day: everyone comes off early, stars included."},
	"normal": {"label": "Normal rotations", "role": 70.0, "star": 50.0,
			"text": "Rotate the group, ride the stars a little longer."},
	"stars": {"label": "Ride the stars", "role": 68.0, "star": 25.0,
			"text": "Your stars stay on until they are cooked."},
}
## fit(): effective-attribute multiplier. 0.80 + 0.25 x energy puts an
## average match (~80 energy) at 1.0: fresh 1.05, cooked (30) 0.875.
const FIT_BASE := 0.80
const FIT_SLOPE := 0.25


func fit(p: Dictionary) -> float:
	var f := FIT_BASE + FIT_SLOPE * float(energy.get(str(p["id"]), 100.0)) / 100.0
	if (current_quarter >= 4 or finals_mode) and _trait(p, "big_game"):
		f += 0.05
	return f + ClubLife.form(p)


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
	var id := str(p.get("id", ""))
	if not _traits.has(id):
		_traits[id] = Traits.of(p)
	return (_traits[id] as Array).has(key)


## A player's attribute as he is playing right now.
func _a(p: Dictionary, key: String) -> float:
	return float(p["attr"][key]) * fit(p)


## Mean fit of the on-ground midfielders and rucks: who wins the stoppages.
func _mid_fit(side: int) -> float:
	var total := 0.0
	var n := 0
	for p in (squads[side] as Squad).ground:
		if str(p["role"]) == "MID" or str(p["role"]) == "RUCK":
			total += fit(p)
			n += 1
	return total / float(n) if n > 0 else 1.0


func set_rotation_policy(side: int, key: String) -> void:
	if side >= 0 and side <= 1 and ROTATION_POLICIES.has(key):
		rotation_policy[side] = key


func _after_chain() -> void:
	momentum *= MOMENTUM_DECAY
	# Distance, drain and recovery were set for 180 chains a game: a chain is
	# a share of the game's minutes, so per-game loads stay the same.
	var per_chain := 180.0 / float(Ratings.T["chains_per_game"])
	for side in range(2):
		var sq: Squad = squads[side]
		# Distance and fatigue both respond to the plan's tempo, pep talk and
		# "throw numbers at it". Running Machine / Engine reduce fatigue only:
		# good runners still log the kilometres they actually cover.
		var movement_pace := _pv(side, "pace") * _pep_mult(side, "pace")
		if _burst(side, "surge"):
			movement_pace *= 1.3
		var fatigue_pace := movement_pace
		if synergies[side].has("running_machine"):
			fatigue_pace *= 0.70
		var tagger_id := ""
		if _tag_id(side) != "":
			var tagger = tagger_for(sq.ground)
			if tagger != null:
				tagger_id = str(tagger["id"])
		for p in sq.ground:
			var id := str(p["id"])
			var role := str(p["role"])
			var gps := GPS_METRES_PER_CHAIN * per_chain * float(GPS_ROLE_MULT.get(role, 1.0)) * movement_pace
			if Roles.on_wing(p):
				gps *= GPS_WING_MULT
			if _chain_touch.has(id):
				gps *= GPS_TOUCH_MULT
			if id == _focus_id(side):
				gps *= GPS_FOCUS_MULT
			if id == tagger_id:
				gps *= GPS_TAGGER_MULT
			if id == _tag_id(1 - side):
				gps *= GPS_TAGGED_MULT
			# Short-term calls move specific lines as football would: slowing
			# down cuts running; a flood asks backs/mids to fold behind the
			# ball; stacking a stoppage pulls mids/rucks into the contest.
			if _burst(side, "hold"):
				gps *= 0.84
			elif _burst(side, "flood"):
				gps *= 1.10 if role == "MID" else (1.07 if role == "DEF" or role == "RUCK" else 0.94)
			elif _burst(side, "stack"):
				gps *= 1.08 if role == "MID" or role == "RUCK" else 0.98
			_t(side, "distance_run", gps)
			_p(p, "distance_run", gps)

			var dur := float((p["attr"] as Dictionary).get("durability", 70.0))
			var d := ENERGY_DRAIN * per_chain * float(ROLE_DRAIN.get(role, 1.0)) \
					* (1.2 - 0.4 * dur / 100.0) * fatigue_pace
			if _trait(p, "engine"):
				d *= 0.75
			exertion[id] = float(exertion.get(id, 0.0)) + d
			energy[id] = maxf(5.0, float(energy.get(id, 100.0)) - d)
		for p in sq.bench:
			var id := str(p["id"])
			energy[id] = minf(float(energy_caps.get(id, 100.0)), float(energy.get(id, 100.0)) + ENERGY_BENCH_RECOVER * per_chain)
		var b: Dictionary = bursts[side]
		for k in b.keys():
			b[k] = int(b[k]) - 1
			if int(b[k]) <= 0:
				b.erase(k)
	_chain_no += 1
	_check_injuries()
	if _chain_no % ROTATE_EVERY == 0:
		for side in range(2):
			_auto_rotate(side)


## Who will be hurt in this match, and when: one Injuries.roll per player
## in the 22 (the same chance as the old after-the-siren roll), at a minute
## of the four quarters.
func _plan_injuries() -> void:
	for side in range(2):
		var sq: Squad = squads[side]
		for p in sq.ground + sq.bench:
			var inj := Injuries.roll(injury_rng, p)
			if inj.is_empty():
				continue
			inj["side"] = side
			inj["id"] = str(p["id"])
			inj["at"] = injury_rng.randi_range(2, 118)
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
		if gi >= 0:
			var rep := _bench_for(side, str(hurt["role"]), 0.0)
			if rep >= 0:
				on = str((sq.bench[rep] as Dictionary)["id"])
				_swap(side, gi, rep)
				bi = rep
		if bi >= 0 and str((sq.bench[bi] as Dictionary)["id"]) == id:
			sq.bench.remove_at(bi)
			(injured_off[side] as Array).append(hurt)
		var rec := {"side": side, "id": id, "q": current_quarter, "min": current_minute,
				"weeks": int(inj["weeks"]), "kind": str(inj["kind"]), "on": on}
		injuries.append(rec)
		_emit("injury", side, fp, hurt, "%s is injured (%s)" % [GameDB.player_display_name(hurt), str(inj["kind"])])
		events[events.size() - 1]["on"] = on
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
	for i in range(sq.ground.size()):
		var p: Dictionary = sq.ground[i]
		if str(_held.get(str(p["id"]), "")) == "keep":
			continue
		var e := float(energy.get(str(p["id"]), 100.0))
		var line := float(policy["star"]) if int(p["overall"]) >= STAR_OVR else float(policy["role"])
		if e < line and e < worst_e:
			worst = i
			worst_e = e
	if worst < 0:
		return
	var bi := _bench_for(side, str((sq.ground[worst] as Dictionary)["role"]), 85.0, true)
	if bi >= 0:
		_swap(side, worst, bi)


## The freshest bench player (at or above `min_energy`) for a ground role,
## or -1. Natural or secondary role first; any bench player as a fallback.
## `rotation`: a routine interchange, which leaves a rested star on the bench.
func _bench_for(side: int, role: String, min_energy: float, rotation := false) -> int:
	var sq: Squad = squads[side]
	var best := -1
	var best_score := -1.0
	for i in range(sq.bench.size()):
		var p: Dictionary = sq.bench[i]
		var e := float(energy.get(str(p["id"]), 100.0))
		if e < min_energy or (rotation and str(_held.get(str(p["id"]), "")) == "rest"):
			continue
		var fits := str(p.get("role", "")) == role or str(p.get("role2", "")) == role \
				or str(p.get("list_tag", "")) == role
		var score := e + (100.0 if fits else 0.0)
		if score > best_score:
			best = i
			best_score = score
	return best


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
	"stack": {"label": "Stack the stoppage", "chains": 12, "for": "for the next few centre bounces"},
	"flood": {"label": "Flood behind the ball", "chains": 45, "for": "for the rest of the quarter"},
	"surge": {"label": "Throw numbers at it", "chains": 15, "for": "for the next ten minutes"},
	"hold": {"label": "Slow it down", "chains": 15, "for": "for the next ten minutes"},
}


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
## Q4, the last 20 minutes, at a centre bounce, within two goals, twice a
## match at most.
func _bounce_moment(margin: int) -> bool:
	if current_quarter == 4 and at_centre and current_minute >= 100 and absi(margin) <= 12 \
			and int(_asked.get("bounce", 0)) < 2:
		_asked["bounce"] = int(_asked.get("bounce", 0)) + 1
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
			or _asked.has("bounce_playtest"):
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
	_fire({"kind": "bounce", "default": 2,
		"title": "Centre bounce - %s with %d minutes left" % [state, 120 - current_minute],
		"text": "Set up for the rest of the game.",
		"options": [
			{"key": "stack", "label": "Stack the stoppage",
				"detail": "Extra numbers at the bounce: win far more clearances, but they score more easily if they get out."},
			{"key": "flood", "label": "Flood behind the ball",
				"detail": "Protect the lead: they score far less, and so do you."},
			{"key": "none", "label": "Play it straight",
				"detail": "No change."},
		]})


func _late_bounce_ready() -> bool:
	return moment_side >= 0 and current_quarter == 4 and _moments_this_q == MAX_MOMENTS_Q \
			and _chain_no - _last_moment_chain >= MOMENT_GAP


## Situations spotted between chains: a tired star, a hot opposition
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
	# A star running on empty - only when you have chosen to ride your stars.
	# Under Normal rotations or Rotate hard the rotations take tired players
	# off by themselves (_auto_rotate); riding them is the one policy that
	# leaves a star out there cooked, so it may bring one call a match.
	for p in (squads[me] as Squad).ground if rotation_policy[me] == "stars" else []:
		var id := str(p["id"])
		var e := float(energy.get(id, 100.0))
		if int(p["overall"]) >= STAR_OVR and e < TIRED_CALL and not _asked.has("tired"):
			# Only a real choice: someone on the bench has to be able to come on.
			var bi := _bench_for(me, str(p["role"]), 0.0)
			if bi < 0:
				continue
			_asked["tired"] = true
			var sub: Dictionary = (squads[me] as Squad).bench[bi]
			var last := current_quarter >= 4
			_fire({"kind": "tired", "player_id": id, "default": 1, "sub_id": str(sub["id"]),
				"title": "%s is running on empty" % GameDB.player_display_name(p),
				"text": "Your star's legs are gone. Tired players win less of the ball and kick fewer goals.",
				"options": [
					{"key": "rest", "label": "Rest him now",
						"detail": ("%s comes on. He sits out the rest of the match." if last
								else "%s comes on. He sits out the rest of the quarter and starts the next one fresh.") % GameDB.player_display_name(sub)},
					{"key": "keep", "label": "Keep him out there",
						"detail": "He plays on to the final siren, slowing as he goes." if last
								else "He plays on to the break, slowing as he goes, and starts the next quarter on tired legs."},
				]})
			return true
	# An opposition key forward getting on top: kicked a bag, or won three
	# contests this quarter against his man. The answer is a match-up.
	var mine: Dictionary = duels[me]
	for fid in mine.keys():
		var hotf := _on_ground(opp, str(fid))
		var cur := _on_ground(me, str(mine[fid]))
		if hotf.is_empty() or cur.is_empty():
			continue
		var bag := int((player_stats.get(str(fid), {}) as Dictionary).get("goals", 0.0))
		var wins := 0
		for c in (duel_log.get(str(fid), {}) as Dictionary).get("contests", []):
			if int(c[0]) == current_quarter and str(c[1]) == str(cur["id"]) and bool(c[2]):
				wins += 1
		var key := "duel|%s|%d" % [str(fid), current_quarter]
		if (bag < 3 and wins < 3) or _asked.has(key) or _asked.has("bag|" + str(fid)) and wins < 3:
			continue
		_asked[key] = true
		if bag >= 3:
			_asked["bag|" + str(fid)] = true
		var fname := GameDB.player_display_name(hotf)
		var cname := GameDB.player_display_name(cur)
		var opts := []
		for p in Matchups.defenders((squads[me] as Squad).ground):
			if str(p["id"]) == str(cur["id"]) or opts.size() >= 2:
				continue
			opts.append({"key": "def:" + str(p["id"]),
					"label": "Put %s on %s" % [GameDB.player_display_name(p), fname],
					"detail": Matchups.describe(p)})
		if opts.is_empty():
			continue
		opts.append({"key": "keep", "label": "Keep %s on %s" % [cname, fname],
				"detail": Matchups.describe(cur)})
		_fire({"kind": "duel", "player_id": str(fid), "default": opts.size() - 1,
			"title": ("%s has kicked %d" % [fname, bag]) if bag >= 3 else ("%s is getting on top" % fname),
			"text": "%s has won %d contests in the air against %s this quarter." % [fname, wins,
					cname] if wins > 0 else
					"%s is on %s. Change the match-up, or back %s in." % [cname, fname, cname],
			"options": opts})
		return true
	# An opposition midfielder kicking a bag: a tag is a midfield job, so
	# only a midfielder can be answered with one (a forward is a match-up).
	for id in player_stats:
		var st: Dictionary = player_stats[id]
		if int(st.get("goals", 0.0)) < 3 or _asked.has("hot|" + str(id)):
			continue
		var hot := _on_ground(opp, str(id))
		if hot.is_empty() or not taggable(hot) or _tag_id(me) == str(id):
			continue
		_asked["hot|" + str(id)] = true
		# The midfielder who would actually go to him (tagger_for).
		var minder = tagger_for((squads[me] as Squad).ground)
		var stopper := GameDB.player_display_name(minder) if minder != null else "a midfielder"
		var cost := ("Tagging is %s's job: he takes more of the ball off him and gives up little." % stopper) \
				if minder != null and Roles.is_tagger(minder) else \
				("%s is no tagger: he gives up his own game to do it." % stopper)
		_fire({"kind": "hot", "player_id": str(id), "default": 1,
			"title": "%s has kicked %d" % [GameDB.player_display_name(hot), int(st["goals"])],
			"text": "Their midfielder is hurting you on the scoreboard. A tag takes a good chunk of the ball off him, but your stopper stops playing his own game.",
			"options": [
				{"key": "tag", "label": "Tag him with %s" % stopper,
					"detail": "Until you call it off. " + cost},
				{"key": "leave", "label": "Back your defenders",
					"detail": "Keep the structure as it is."},
			]})
		return true
	# Three goals in a row against.
	# Once a run: the key is where the run started (their goals before it),
	# so a fourth or fifth goal in the same run asks nothing new. A new run -
	# after you score - can ask again.
	var run_key := "run|%d" % (goals(opp) - int(_run[opp]))
	if _run[opp] >= 3 and not _asked.has(run_key):
		_asked[run_key] = true
		_fire({"kind": "momentum", "default": 2,
			"title": "They have kicked %d in a row" % _run[opp],
			"text": "The game is getting away from you. Make a call for the next ten minutes.",
			"options": [
				{"key": "surge", "label": "Throw numbers at it",
					"detail": "Win more of the ball and more goals, but they score more when they get out, and it burns legs."},
				{"key": "hold", "label": "Slow it down",
					"detail": "Chip it around: fewer turnovers, a quieter game at both ends, less ground gained."},
				{"key": "none", "label": "Ride it out",
					"detail": "Trust the plan. No change."},
			]})
		return true
	# A tight last-quarter centre bounce.
	return _bounce_moment(margin)


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
	var mate_goal := clampf(shot_chance(side, mate, true, false) * 1.3, 0.05, 0.9) if not mate.is_empty() else 0.0
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
	options.append({"key": "bomb", "label": "Bomb it to the goal square",
		"detail": "Now and then it falls for a goal; more often a behind or they rebound it.",
		"goal": bomb_goal, "behind": 0.30})
	_fire({"kind": "set_shot", "default": 0, "player_id": str(shooter["id"]),
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
const SET_BANDS := [
	{"key": "close", "spot": "from 25 metres, straight in front", "metres": 25.0, "acc": 0.92, "share": 0.20},
	{"key": "front", "spot": "from 35 metres, straight in front", "metres": 35.0, "acc": 0.74, "share": 0.25},
	{"key": "angle", "spot": "from 45 metres on a slight angle", "metres": 45.0, "acc": 0.50, "share": 0.30},
	{"key": "pocket", "spot": "from the pocket, on a tight angle", "metres": 15.0, "acc": 0.35, "share": 0.15},
	{"key": "long", "spot": "from 55 metres out", "metres": 55.0, "acc": 0.25, "share": 0.10},
]
const SET_REF := 0.34
## Of the marks inside 50, the share that end in a set shot from the mark;
## the rest go on (a play-on, a switch, a turnover) and score less.
const SET_SHOT_SHARE := 0.45
## A missed set shot is usually a behind; now and then it falls short or
## goes out on the full.
const SET_MISS_BEHIND := 0.70


## The bands with this shot's chances filled in: {goal, behind} per band.
static func set_bands(goal_p: float) -> Array:
	var out := []
	for b in SET_BANDS:
		var band: Dictionary = b.duplicate()
		band["goal"] = clampf(float(b["acc"]) * goal_p / SET_REF, 0.03, 0.97)
		band["behind"] = (1.0 - float(band["goal"])) * SET_MISS_BEHIND
		out.append(band)
	return out


## A mark inside 50: a set shot from one of SET_BANDS, or the ball goes on.
## The split keeps the entry's expected goals and behinds exactly what they
## were, so scoring across the league is unchanged; only where they come
## from moves. {"band": {} or the band, "goal", "behind"}.
func _set_shot_split(goal_p: float, behind_p: float) -> Dictionary:
	var bands := set_bands(goal_p)
	var e_goal := 0.0
	var e_behind := 0.0
	for b in bands:
		e_goal += float(b["share"]) * float(b["goal"])
		e_behind += float(b["share"]) * float(b["behind"])
	if shot_rng.randf() < SET_SHOT_SHARE:
		var r := shot_rng.randf()
		for b in bands:
			r -= float(b["share"])
			if r < 0.0:
				return {"band": b, "goal": b["goal"], "behind": b["behind"]}
		var last: Dictionary = bands[bands.size() - 1]
		return {"band": last, "goal": last["goal"], "behind": last["behind"]}
	var rest := 1.0 - SET_SHOT_SHARE
	return {"band": {},
			"goal": maxf(0.0, (goal_p - SET_SHOT_SHARE * e_goal) / rest),
			"behind": maxf(0.0, (behind_p - SET_SHOT_SHARE * e_behind) / rest)}


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
	choice = clampi(choice, 0, maxi(0, options.size() - 1))
	var opt: Dictionary = options[choice] if not options.is_empty() else {}
	var side := int(m.get("side", moment_side))
	var key := str(opt.get("key", ""))
	var outcome := ""
	var points := 0
	match str(m.get("kind", "")):
		"set_shot":
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
		"duel":
			if key.begins_with("def:"):
				var did := key.trim_prefix("def:")
				coach_matchup(side, str(m["player_id"]), did)
				outcome = "%s goes to %s." % [GameDB.player_display_name(_on_ground(side, did)),
						GameDB.player_display_name(_on_ground(1 - side, str(m["player_id"])))]
			else:
				outcome = "The match-up stays."
		"momentum", "bounce":
			if BURSTS.has(key):
				(bursts[side] as Dictionary)[key] = int(BURSTS[key]["chains"])
				outcome = "%s %s." % [str(BURSTS[key]["label"]), str(BURSTS[key]["for"])]
			else:
				outcome = "No change."
	m["choice"] = choice
	m["choice_label"] = str(opt.get("label", ""))
	m["outcome"] = outcome
	m["points"] = points
	moments.append(m)
	_emit("moment", side, fp, null, "Coach's call: %s - %s" % [m["choice_label"], outcome])
	return m


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
	if key == "pass":
		_t(side, "disposals")
		_t(side, "kicks")
		_p(shooter, "disposals")
		_p(shooter, "kicks")
		if rng.randf() >= float(opt.get("pass", 0.6)):
			return _shot_turnover(side, defender, "%s's pass is intercepted" % GameDB.player_display_name(shooter))
		kicker = _on_ground(side, str(opt.get("mate_id", "")))
		if kicker.is_empty():
			kicker = shooter
		assist = shooter
		goal_p = float(opt.get("mate_goal", 0.5))
		behind_p = (1.0 - goal_p) * 0.6
	var roll := rng.randf()
	if roll < goal_p:
		_t(side, "goals")
		_p(kicker, "goals")
		_assist(side, assist, kicker)
		_scored(side, 6, kicker)
		q_goals[current_quarter - 1][side] += 1
		_score_run(side)
		_emit("goal", side, fp, kicker, _scoreline(side, "GOAL"))
		events[events.size() - 1]["set"] = true
		_trait_note(kicker)
		_tag_shot(true)
		_end_moment_chain("score", 0.0, side)
		return {"points": 6, "text": "GOAL to %s!" % GameDB.player_display_name(kicker)}
	if roll < goal_p + behind_p:
		_t(side, "behinds")
		_p(kicker, "behinds")
		_scored(side, 1, kicker)
		q_behinds[current_quarter - 1][side] += 1
		_emit("behind", side, fp, kicker, _scoreline(side, "Behind"))
		events[events.size() - 1]["set"] = true
		_tag_shot(true)
		_end_moment_chain("behind", kick_in_fp(side), side)
		return {"points": 1, "text": "Just a behind from %s." % GameDB.player_display_name(kicker)}
	return _shot_turnover(side, defender, "%s's shot is rebounded" % GameDB.player_display_name(kicker))


func _shot_turnover(side: int, defender: Dictionary, text: String) -> Dictionary:
	var opp := 1 - side
	_t(opp, "rebounds")
	if not defender.is_empty():
		_p(defender, "rebounds")
		_intercept(opp, defender, false)
		_emit("rebound", opp, fp, defender, "%s rebounds it out of danger" % GameDB.player_display_name(defender))
	_end_moment_chain("turnover", fp, side)
	return {"points": 0, "text": text + " - no score."}


func _end_moment_chain(outcome: String, new_fp: float, side: int) -> void:
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
## The opposition's plan for the coming quarter: its usual game (the plan
## its list suits, PlanFit.standing_plan), protecting a big lead or chasing
## a big deficit. It does not read and counter your plan. With a specialist
## tagger on the ground it tags your most influential midfielder from half
## time; without one it does not (a tag by a good midfielder costs more than
## it takes, _tag_drag).
## A sharper tactical group (Squad.tactics_read) reacts to a smaller margin
## and tags from half time rather than the last quarter.
func ai_tactics(side: int) -> Dictionary:
	var opp := 1 - side
	var read := float((squads[side] as Squad).tactics_read)
	var margin := score(side) - score(opp)
	var react := 18.0 - 8.0 * read
	var plan := str(standing[side])
	if margin >= react:
		plan = "controlled"
	elif margin <= -react:
		plan = "attacking"
	elif margin < 0 and current_quarter >= 3 and _lost_quarter(side, current_quarter - 1):
		# Behind after half time and still losing ground: the usual game is
		# not working, so it chases. Only what a coach sees - the scoreboard.
		plan = "attacking"
	var t := {"gameplan": plan, "pep": "fire_up" if margin <= -12 and current_quarter >= 3 else "steady"}
	t["interceptor_id"] = _ai_interceptor(side, (squads[side] as Squad).ground)

	# The AI never reads the opponent's hidden structural call. It only makes
	# the spare accountable after the match log/stats show that player has
	# actually influenced enough aerial contests.
	var observed_spare_wins := 0
	for p in (squads[opp] as Squad).ground:
		var ost: Dictionary = player_stats.get(str(p.get("id", "")), {})
		observed_spare_wins = maxi(observed_spare_wins, int(ost.get("roam_wins", 0)))
	if observed_spare_wins >= 2:
		t["spare_accountable"] = true

	var tagger = tagger_for((squads[side] as Squad).ground)
	if current_quarter >= (2 if read >= 0.4 else 3) and tagger != null and Roles.is_tagger(tagger):
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


## A rival coach's loose defender for the quarter, from `ground`: his best
## interceptor, unless he is chasing the game late and wants every man on a
## forward. "" for none.
func _ai_interceptor(side: int, ground: Array) -> String:
	var react := 18.0 - 8.0 * float((squads[side] as Squad).tactics_read)
	var margin := score(side) - score(1 - side)
	var spare := Matchups.best_interceptor(ground)
	if spare.is_empty() or (margin <= -react and current_quarter >= 3):
		return ""
	return str(spare["id"])


## Whether `side` was outscored in quarter `q` (1-4).
func _lost_quarter(side: int, q: int) -> bool:
	if q < 1 or q > q_goals.size():
		return false
	var pts := func(s: int) -> int: return int(q_goals[q - 1][s]) * 6 + int(q_behinds[q - 1][s])
	return pts.call(side) < pts.call(1 - side)


## A tag is a midfield job: only a midfielder (centre or wing) can be tagged.
static func taggable(p: Dictionary) -> bool:
	return str(p.get("role", "")) == "MID"


## Who goes to the player `side` tags: its tagger if one is on the ground,
## otherwise the midfielder with the most pressure in his game. null with no
## midfielder on the ground.
static func tagger_for(ground: Array):
	var best = null
	for p in ground:
		if str(p.get("role", "")) != "MID":
			continue
		if Roles.is_tagger(p):
			return p
		if best == null or float(p["attr"]["pressure"]) > float(best["attr"]["pressure"]):
			best = p
	return best

