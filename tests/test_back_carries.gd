extends RefCounted
## Back-zone carrying (row 92, T9.Q22, director 2026-11-06): a defender takes
## less of the ball in his own back zone (MatchSim.CARRY_BACK_RETUNED) and a
## midfielder drops back for more of it. Director 2026-11-07 ("Both fixes"):
## the back-zone carrier is picked on his ball use, not his intercepting; the
## rebound 50 is the disposal that takes it out of defensive 50; after a spoil
## the first touch is whoever wins the ground ball. Run through
## tests/run_back_carries_tests.gd.
## Seeded by design: every sim takes an explicit match seed.

var failures: Array[String] = []
var checks := 0

const DRAWS := 4000


func run() -> void:
	failures.clear()
	checks = 0
	GameDB.reload()
	_t("_test_weights")
	_t("_test_defender_leads_the_back_zone")
	_t("_test_back_carrier_follows_ball_use")
	_t("_test_no_rebound_at_the_contest")
	_t("_test_rebound_is_the_disposal_out_of_d50")
	_t("_test_no_rebound_outside_d50")
	_t("_test_spoil_goes_to_ground_ball_winner")
	print(Ran.line("Back carries", self))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func _sim(seed: int) -> MatchSim:
	return MatchSim.new(Squad.new("FRE", GameDB.club_list("FRE"), true, "FRE"),
			Squad.new("MEL", GameDB.club_list("MEL"), false, "MEL"), seed)


## Who the home side's carrier picks go to at field position fp: role -> count,
## plus "ids" (id -> count).
func _picks(sim: MatchSim, fp: float) -> Dictionary:
	var out := {"ids": {}}
	for i in range(DRAWS):
		var p = sim.pick_carrier(0, fp)
		var r := str(p["role"])
		out[r] = int(out.get(r, 0)) + 1
		out["ids"][str(p["id"])] = int((out["ids"] as Dictionary).get(str(p["id"]), 0)) + 1
	return out


func _test_weights() -> void:
	var tuned: Dictionary = MatchSim.CARRY_BACK_RETUNED
	_check(is_equal_approx(float(tuned["DEF"]), 0.55), "a defender's back-zone weight is row 92's 0.55 (%s)" % tuned["DEF"])
	for r in [["MID", 1.0], ["RUCK", 0.3], ["FWD", 0.12]]:
		_check(is_equal_approx(float(tuned[r[0]]), float(r[1])), "%s back-zone weight is %s" % r)
	# On ball use, each line's total weight is what row 92's intercept pick
	# gave it, for every club's list: who in a line gets it changes, not how
	# much each line gets.
	var sim := _sim(31)
	var same := true
	for club in GameDB.club_order:
		var ground: Array = (Squad.new(club, GameDB.club_list(club), true, club) as Squad).ground
		var roles: Dictionary = sim._back_roles(ground)
		var on_use := {}
		var on_int := {}
		for p in ground:
			var r := str(p["role"])
			on_use[r] = float(on_use.get(r, 0.0)) + float(roles[r]) * pow(maxf(1.0, sim._ball_use(p)), 2.0)
			on_int[r] = float(on_int.get(r, 0.0)) + float(tuned[r]) * pow(maxf(1.0, sim._a(p, "intercept")), 2.0)
		for r in on_int:
			same = same and absf(float(on_use[r]) - float(on_int[r])) <= 1e-6 * float(on_int[r])
	_check(same, "each line's back-zone weight on ball use equals its weight on intercept (row 92's split)")


## The pinned behaviour: 4,000 back-zone picks for Fremantle (seed 31): a
## defender still has most of the ball (about 60%).
func _test_defender_leads_the_back_zone() -> void:
	var on := _picks(_sim(31), -50.0)
	var d_on := float(on.get("DEF", 0)) / DRAWS
	_check(d_on > 0.5, "defenders still take most of the back zone's ball (%.1f%%)" % (100 * d_on))


## Two defenders, one a ball user (carry and disposal 90, intercept 30) and
## one a spoiler (intercept 90, carry and disposal 30): in the back zone the
## ball goes to the ball user, about (90/30)^2 = 9 to 1; the old intercept
## pick sent it the other way.
func _test_back_carrier_follows_ball_use() -> void:
	var sim := _sim(31)
	var defs := []
	for p in (sim.squads[0] as Squad).ground:
		if str(p["role"]) == "DEF":
			defs.append(p)
	_check(defs.size() >= 2, "Fremantle has two defenders on the ground")
	if defs.size() < 2:
		return
	var user: Dictionary = (defs[0] as Dictionary).duplicate(true)
	var spoiler: Dictionary = (defs[1] as Dictionary).duplicate(true)
	for k in ["carry", "disposal"]:
		user["attr"][k] = 90.0
		spoiler["attr"][k] = 30.0
	user["attr"]["intercept"] = 30.0
	spoiler["attr"]["intercept"] = 90.0
	var to_user := 0
	for i in range(DRAWS):
		if str(sim.pick_carrier(0, -50.0, [user, spoiler])["id"]) == str(user["id"]):
			to_user += 1
	var share := float(to_user) / DRAWS
	_check(share > 0.8, "the back-zone ball goes to the ball user, not the spoiler (%.1f%%)" % (100 * share))
	_check(is_equal_approx(sim._ball_use(user), 0.58 * sim._a(user, "carry") + 0.42 * sim._a(user, "disposal")),
			"ball use is kick_in_taker's carry/disposal blend")


## A failed entry: the defence has it, but no rebound 50 is credited at the
## contest, to the team or to the man who won it (seeded entries).
func _test_no_rebound_at_the_contest() -> void:
	var turnovers := 0
	var clean := true
	for seed in range(40):
		var sim := _sim(4100 + seed)
		sim.begin_quarter()
		var feeder: Dictionary = (sim.squads[0] as Squad).ground[0]
		var res: Dictionary = sim.resolve_forward50(0, 50.0, feeder)
		if str(res.get("outcome", "")) != "turnover":
			continue
		turnovers += 1
		var pid := str((res["actor"] as Dictionary)["id"])
		clean = clean and float(sim.team_stats[1].get("rebounds", 0.0)) == 0.0 \
				and float(sim.player_stats.get(pid, {}).get("rebounds", 0.0)) == 0.0
	_check(turnovers > 0, "some seeded entries are turned over (%d)" % turnovers)
	_check(clean, "a turned-over entry credits no rebound 50 at the contest")


## One definition (Champion Data): the rebound 50 is the kick, handball or run
## through a tackle that takes the ball from inside defensive 50 out of it,
## however the side came by it. Chains for side 1 from deep in its defensive 50 after a turnover, a
## ball-up there and a kick-in: each credits at most one rebound 50 (a chain
## only goes forward, so it leaves once), to a side-1 player who disposed of
## the ball in that chain, and the team count matches; every origin credits some.
func _test_rebound_is_the_disposal_out_of_d50() -> void:
	var at_most_one := true
	var right_man := true
	var by_origin := {"turnover": 0, "stoppage": 0, "kick_in": 0}
	for origin in by_origin:
		for seed in range(60):
			var c := _chain_from(4300 + seed, origin, 60.0)
			var total := 0
			for id in c["reb"]:
				total += int(c["reb"][id])
			at_most_one = at_most_one and total <= 1 and int(c["team"]) == total
			if total == 0:
				continue
			by_origin[origin] += 1
			var id: String = (c["reb"] as Dictionary).keys()[0]
			var disposed := false
			for ev in c["events"]:
				if str(ev.get("player_id", "")) == id and int(ev.get("side", -1)) == 1 \
						and str(ev.get("kind", "")) in ["kick", "handball", "mark", "kick_in"]:
					disposed = true
			right_man = right_man and disposed
	_check(at_most_one, "a chain out of defensive 50 credits one rebound 50 at most, and the team's matches")
	_check(right_man, "the rebound 50 is a side-1 player's who disposed of the ball in that chain")
	for origin in by_origin:
		_check(int(by_origin[origin]) > 5, "a chain out of defence from a %s credits a rebound 50 (%d of 60)" % [origin, by_origin[origin]])


## A chain that starts outside defensive 50 never leaves it, so it credits no
## rebound 50 (the old band, 67-73 m from goal, counted some of these).
func _test_no_rebound_outside_d50() -> void:
	var clean := true
	for seed in range(60):
		var c := _chain_from(4700 + seed, "turnover", 30.0)
		clean = clean and int(c["team"]) == 0 and (c["reb"] as Dictionary).is_empty()
	_check(clean, "a chain from 30 m out of defensive 50's line credits no rebound 50")


## Play one chain for side 1 (attacking toward negative fp) from fp: after a
## turnover there, a ball-up there, or a kick-in after side 0's behind.
## {"reb": id -> rebound 50s, "team": side 1's, "events": the chain's}.
func _chain_from(seed: int, origin: String, at_fp: float) -> Dictionary:
	var sim := _sim(seed)
	sim.begin_quarter()
	sim.at_centre = false
	sim.kick_in = origin == "kick_in"
	sim.boundary_throw_in = false
	sim._prev_locked = origin == "stoppage"
	sim.fp = sim.kick_in_fp(0) if origin == "kick_in" else at_fp
	sim._prev_end = "turnover" if origin == "turnover" else "general"
	sim.next_side = 1
	sim._won_back = {}
	var before := sim.events.size()
	sim._play_one_chain(sim._rates())
	var reb := {}
	for id in sim.player_stats:
		var n := int(sim.player_stats[id].get("rebounds", 0.0))
		if n > 0:
			reb[id] = n
	return {"reb": reb, "team": int(sim.team_stats[1].get("rebounds", 0.0)), "events": sim.events.slice(before)}


## A spoiled entry: whoever wins the ground ball has it (the spoiler only some
## of the time; always a defender, the men at the fall of the ball in their own
## 50), the feed names him, and the next chain's first touch is his.
## The intercept stays the spoiler's: a teammate who gathers is not credited one.
func _test_spoil_goes_to_ground_ball_winner() -> void:
	var spoils := 0
	var other_man := 0
	var first_touch_ok := true
	var text_ok := true
	var intercept_ok := true
	var defender_ok := true
	for seed in range(200):
		var sim := _sim(4500 + seed)
		sim.begin_quarter()
		var feeder: Dictionary = (sim.squads[0] as Squad).ground[0]
		var res: Dictionary = sim.resolve_forward50(0, 50.0, feeder)
		if str(res.get("outcome", "")) != "turnover":
			continue
		var ev: Dictionary = sim.events[sim.events.size() - 1]
		if not str(ev.get("text", "")).contains("spoils it"):
			continue
		spoils += 1
		var gid := str((res["actor"] as Dictionary)["id"])
		defender_ok = defender_ok and str((res["actor"] as Dictionary).get("role", "")) == "DEF"
		text_ok = text_ok and str(ev.get("kind", "")) == "rebound" and str(ev.get("player_id", "")) == gid \
				and str(sim._won_back.get("gatherer", "")) == gid and not bool(sim._won_back.get("marked", false))
		var sid := str(sim._won_back.get("id", ""))
		intercept_ok = intercept_ok and float(sim.team_stats[1].get("intercepts", 0.0)) == 1.0 \
				and float(sim.player_stats.get(sid, {}).get("intercepts", 0.0)) == 1.0 \
				and (gid == sid or float(sim.player_stats.get(gid, {}).get("intercepts", 0.0)) == 0.0)
		if not str(ev.get("text", "")).contains("and wins it"):
			other_man += 1
		# The next chain starts from him.
		sim.at_centre = false
		sim.kick_in = false
		sim.boundary_throw_in = false
		sim.fp = float(res["fp"])
		sim._prev_end = "turnover"
		sim.next_side = 1
		var before := sim.events.size()
		sim._play_one_chain(sim._rates())
		for e in sim.events.slice(before):
			if int(e.get("side", -1)) == 1 and str(e.get("player_id", "")) != "":
				first_touch_ok = first_touch_ok and str(e["player_id"]) == gid
				break
	_check(spoils > 5, "some seeded entries are spoiled to the deck (%d)" % spoils)
	_check(text_ok, "the feed names the ground-ball winner as the one who has it, gathered not marked")
	_check(other_man > 0, "the ground ball is not always the spoiler's (%d of %d to someone else)" % [other_man, spoils])
	_check(defender_ok, "the ground ball in defence goes to a defender, not a man up the ground")
	_check(first_touch_ok, "the next chain's first touch is the ground-ball winner's")
	_check(intercept_ok, "the intercept is the spoiler's; a teammate who gathers it is not credited one")
