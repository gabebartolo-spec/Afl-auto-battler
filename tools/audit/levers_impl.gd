extends "res://tools/balance/dynasty.gd"
## Which active lever should carry a well-managed club's flag upside? (The
## director: keep the autopilot slide; a well-managed club should win about
## one flag in 8-10 seasons.) Measurement only. Base: #228's dynasty "full"
## (contracts, free agency, trading up), upside drafter, coached on match day.
## LEV adds one lever on top (budget always sums to the club's $12m):
##   base  - nothing more
##   dev   - development: Development Elite (Minimal high performance and
##           football), the young-gun card's development week, and position
##           learning started on the highest-POT youngsters where offered
##   calls - match-day calls: your plan each quarter counters the plan the
##           opposition ran last quarter (calls_impl's "counter"), moments at
##           their default
##   draft - drafting: Recruiting Elite (sharper reads) and your intake picks
##           by upside (three-year expected rating) instead of the AI's pick
##   all   - dev + calls + draft, with Development and Recruiting both Strong
## Also: every premier's list-strength rank at the start of its flag season.
## Env: LEV, LEV_SEEDS (default 301..308), LEV_SEASONS (default 5).
## godot --headless --path . --script tools/audit/run_audit.gd -- levers_impl

const COUNTER := {"controlled": "attacking", "defensive": "controlled", "press": "controlled",
		"attacking": "defensive", "fast": "defensive"}

var lever := "base"
var _budget_year := -1


func _set_budget(gs) -> void:
	var plan := {}
	match lever:
		"dev":
			plan = {"high_performance": 0, "football": 0, "development": 3, "recruiting": 1}
		"draft":
			plan = {"high_performance": 0, "football": 0, "recruiting": 3, "development": 1}
		"all":
			plan = {"high_performance": 0, "football": 0, "development": 2, "recruiting": 2}
	if plan.is_empty():
		return
	# Lower first so the raises fit inside the year's budget.
	for area in ["high_performance", "football"]:
		gs.set_department_budget(area, int(plan[area]))
	for area in ["development", "recruiting"]:
		gs.set_department_budget(area, int(plan[area]))


func _start_learning(gs) -> void:
	var young := []
	for p in gs.my_list:
		young.append(p)
	young.sort_custom(func(a, b): return int(a.get("potential", 0)) > int(b.get("potential", 0)))
	for p in young:
		var jobs: Array = gs.learnable_jobs(p)
		if not jobs.is_empty():
			gs.set_player_plan(str(p["id"]), "learn_" + str(jobs[0]))


func _play_week(gs, user: String, coach: bool) -> bool:
	if _budget_year != int(gs.season_year):
		_budget_year = int(gs.season_year)
		if lever in ["dev", "all"]:
			_start_learning(gs)
		print("LEVSET %s | year %d | budget dev %d rec %d hp %d fb %d | learning projects %d" % [lever, int(gs.season_year),
				gs.department_budget_level("development"), gs.department_budget_level("recruiting"),
				gs.department_budget_level("high_performance"), gs.department_budget_level("football"), gs.active_projects()])
	if lever in ["dev", "all"] and str(gs.week_event.get("key", "")) == "young_gun":
		gs.resolve_week_event(1)
	if not (lever in ["calls", "all"]):
		return super(gs, user, coach)
	if not coach or not _has_match(gs, user) or not gs.prepare_interactive_match():
		gs.advance()
		return false
	var sim: MatchSim = gs.pending_sim
	var side: int = sim.moment_side
	var best := Matchups.best_interceptor((sim.squads[side] as Squad).ground)
	if not best.is_empty():
		sim.set_interceptor(side, str(best["id"]), false)
	var plan := "balanced"
	while sim.current_quarter <= 4:
		if sim.current_quarter > 1 and not sim.tactics_history.is_empty():
			var last: Dictionary = sim.tactics_history[sim.tactics_history.size() - 1]
			var theirs := str(((last["plans"] as Array)[1 - side] as Dictionary).get("gameplan", "balanced"))
			plan = str(COUNTER.get(theirs, "balanced"))
		sim.set_tactics(side, {"gameplan": plan})
		sim.begin_quarter()
		while not sim.continue_quarter():
			sim.resolve_moment(int(sim.pending_moment.get("default", 0)))
		sim.end_quarter()
	if sim.needs_extra_time():
		sim.run_extra_time()
	gs.finish_interactive_match(sim.result())
	return true


func _offseason(gs, user: String, mgmt: Dictionary) -> bool:
	# Funding is set in the off-season, before the National Draft, for the
	# coming year (GameState.set_department_budget): year one runs on Standard.
	_set_budget(gs)
	if not (lever in ["draft", "all"]):
		return super(gs, user, mgmt)
	var drafting: bool = gs.begin_intake_draft()
	for e in gs.offseason_log:
		if str(e.get("kind", "")) == "signed" and str(e.get("club", "")) == user:
			mgmt["signed"] += 1
	if not drafting:
		return gs.start_next_season()
	var d: Draft = gs.draft
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var code := d.current_club()
		var c: Dictionary = {}
		if code == user:
			var legal := []
			for p in d.board("", "", "", "overall", true):
				if d.can_pick_player(p):
					legal.append(p)
			legal.sort_custom(func(a, b):
				return (expected_overall(a, 0) + expected_overall(a, 1) + expected_overall(a, 2)) \
						> (expected_overall(b, 0) + expected_overall(b, 1) + expected_overall(b, 2)))
			if not legal.is_empty():
				c = legal[0]
		else:
			c = d._best_ai_pick(code)
		if c.is_empty() or not d._draft_pick(code, c):
			d._skip_current_pick()
	return gs.start_next_season()


func run() -> void:
	lever = OS.get_environment("LEV") if OS.get_environment("LEV") != "" else "base"
	var seeds := []
	var raw := OS.get_environment("LEV_SEEDS")
	for s in (raw if raw != "" else "301,302,303,304,305,306,307,308").split(","):
		seeds.append(int(s))
	var seasons := int(OS.get_environment("LEV_SEASONS")) if OS.get_environment("LEV_SEASONS") != "" else 5
	for s in seeds:
		_budget_year = -1
		var t := Time.get_ticks_msec()
		var rec: Array = run_career(int(s), "upside", seasons, 5, true, "full")
		for snap in rec:
			var u := str(snap["user"])
			var prem := str(snap["premier"])
			var prem_rank := int(snap["clubs"][prem]["rank"]) if prem != "" and (snap["clubs"] as Dictionary).has(prem) else -1
			print("LEV %s | seed %d | %s | year %d | rank %d | ladder %d | premier %s | premier's start rank %d" % [
					lever, int(s), u, int(snap["year"]), int(snap["clubs"][u]["rank"]), int(snap["user_ladder"]),
					"yes" if prem == u else "no", prem_rank])
		print("seed %d done (%d s)" % [int(s), (Time.get_ticks_msec() - t) / 1000])
