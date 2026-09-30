class_name CoachReport
extends RefCounted
## Half-time assistant coach report.
##
## Pure analysis over a MatchSim result after two quarters: who is up and who
## is down on both sides, what gameplan the opposition has actually used in Q1
## and Q2 (from MatchSim.tactics_history, not guesswork), and what the team
## numbers say about where the game is being won. No RNG draws, no sim changes.

const PLAN_NAMES := {
	"balanced": "Balanced",
	"attacking": "Attack corridor",
	"defensive": "Defensive press",
	"contest": "Win contest",
	"controlled": "Controlled tempo",
	"through_stars": "Through stars",
	"fast": "Fast movement",
	"press": "High press",
}

const PEP_NAMES := {
	"steady": "Stay composed",
	"fire_up": "Fire them up",
	"calm": "Calm the group",
}

const PEP_EFFECTS := {
	"steady": "No change.",
	"fire_up": "A lift at the contest while you are chasing the game; level or in front it does nothing for you. Either way legs go quicker and tempers fray.",
	"calm": "Settle them down: fewer errors, less rattled by pressure and legs last longer, but less ground gained.",
}

## What each plan does and gives up, in football words, from MatchSim.PLANS.
## The one description of a plan: selection, coaching, the quarter break
## and the assistant's report all read it. No percentages; how much a plan
## gives depends on the players who carry it (GameState.plan_fit_line).
const PLAN_SUMMARY := {
	"balanced": "Play it straight: no extra edge, and nothing for them to exploit.",
	"attacking": "Go through the corridor: more ground and better shots, but more turnovers, heavier legs, and they score more on the rebound. The better your runners, the more it gives. Beats Controlled tempo; a Defensive press squeezes it.",
	"defensive": "Press up the ground: harder to score against, but fewer numbers forward and heavier legs. The more pressure players you have, the more it bites. Beats Attack corridor; Controlled tempo plays through it.",
	"contest": "Numbers at the stoppage: win more of the clearances, but the ball moves a little slower and you are a little exposed on the rebound. Leans on your ball-winners and ruck.",
	"controlled": "Keep the ball: fewer errors, less rattled by pressure and fresher legs, but less ground gained. Asks nothing special of your list. Plays through a Defensive press; Attack corridor runs past it.",
	"through_stars": "Go through your best three: they see more of the ball and finish better, with fewer errors, but they know where it's going and the pressure comes. Worth more the further they stand above the rest.",
	"fast": "Go through the corridor: more ground and better shots, but more turnovers, heavier legs, and they score more on the rebound.",
	"press": "Press up the ground: harder to score against, but fewer numbers forward and heavier legs.",
}

const PEP_SUMMARY := {
	"steady": "",
	"fire_up": "A lift at the contest when you are chasing the game; legs go quicker and tempers fray.",
	"calm": "Fewer errors and less rattled by pressure, legs last longer; less ground gained.",
}

const TEAM_COMPARE := [
	["disposals", "Disposals", 4, false],
	["marks", "Marks", 3, false],
	["tackles", "Tackles", 2, false],
	["pressure_acts", "Pressure acts", 6, false],
	["inside50", "Inside 50s", 2, false],
	["clearances", "Clearances", 2, false],
	["hitouts", "Hit-outs", 3, false],
	["rebounds", "Rebound 50s", 2, false],
	["one_percenters", "One percenters", 2, false],
	["clangers", "Clangers", 1, true],
	["frees_for", "Frees for", 1, false],
]


const IMPACT_LABELS := {
	"gameplan": "gameplan", "pep": "pep talk",
	"legs": "legs (fatigue and rotations)", "calls": "in-game calls",
	"traits": "traits and synergies", "form": "team form",
}


## Where the points came from between two impact snapshots (MatchSim.impact),
## from `side`'s point of view: [{"label", "pts"}], biggest first, anything
## under `min_pts` dropped. "Their gameplan -2.1" cost you 2.1 points.
static func impact_lines(now: Array, before: Array, side: int, min_pts := 0.3) -> Array:
	var out := []
	for cause in IMPACT_LABELS:
		var mine := _imp(now, side, cause) - _imp(before, side, cause)
		var theirs := _imp(now, 1 - side, cause) - _imp(before, 1 - side, cause)
		if absf(mine) >= min_pts:
			out.append({"label": "Your " + str(IMPACT_LABELS[cause]), "pts": mine})
		if absf(theirs) >= min_pts:
			out.append({"label": "Their " + str(IMPACT_LABELS[cause]), "pts": -theirs})
	out.sort_custom(func(a, b): return absf(float(a["pts"])) > absf(float(b["pts"])))
	return out


static func _imp(arr: Array, side: int, cause: String) -> float:
	if arr.size() <= side:
		return 0.0
	return float((arr[side] as Dictionary).get(cause, 0.0))


static func plan_label(key: String) -> String:
	return str(PLAN_NAMES.get(key, "Balanced"))


static func plan_effect(key: String) -> String:
	return plan_summary(key)


static func plan_summary(key: String) -> String:
	return str(PLAN_SUMMARY.get(key, PLAN_SUMMARY["balanced"]))


static func pep_summary(key: String) -> String:
	return str(PEP_SUMMARY.get(key, ""))


static func pep_label(key: String) -> String:
	return str(PEP_NAMES.get(key, "Stay composed"))


static func pep_effect(key: String) -> String:
	return str(PEP_EFFECTS.get(key, str(PEP_EFFECTS["steady"])))


## Same best-on-ground weighting the full-time screen uses, so half-time form
## and the final votes tell one consistent story.
static func influence(st: Dictionary) -> float:
	return float(st.get("disposals", 0.0)) \
		+ float(st.get("goals", 0.0)) * 5.0 \
		+ float(st.get("marks", 0.0)) * 0.8 \
		+ float(st.get("inside50", 0.0)) * 2.0 \
		+ float(st.get("tackles", 0.0)) * 0.5 \
		+ float(st.get("pressure_acts", 0.0)) * 0.3 \
		+ float(st.get("hitouts", 0.0)) * 0.7 \
		+ float(st.get("clearances", 0.0)) * 1.2 \
		+ float(st.get("one_percenters", 0.0)) * 0.6 \
		- float(st.get("clangers", 0.0)) * 2.0


## What a player of this rating would normally produce by this stage. Stars are
## expected to carry more ball, so a quiet star reads as down while a quiet
## depth defender reads as par. Calibrated so overall 50 ≈ 9 influence at
## half-time and overall 90 ≈ 22.
static func expected_influence(overall: int, quarters := 2) -> float:
	var per_q := 4.5 + (float(overall) - 50.0) * 0.16
	per_q = maxf(1.5, per_q)
	return per_q * float(maxi(1, quarters))


static func stat_line(st: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("%d disp" % int(st.get("disposals", 0.0)))
	var kicks := int(st.get("kicks", 0.0))
	var hands := int(st.get("handballs", 0.0))
	if kicks + hands > 0:
		parts.append("(%dK %dH)" % [kicks, hands])
	var g := int(st.get("goals", 0.0))
	var b := int(st.get("behinds", 0.0))
	if g + b > 0:
		parts.append("%d.%d" % [g, b])
	var marks := int(st.get("marks", 0.0))
	if marks > 0:
		parts.append("%dM" % marks)
	var tackles := int(st.get("tackles", 0.0))
	if tackles > 0:
		parts.append("%dT" % tackles)
	var ho := int(st.get("hitouts", 0.0))
	if ho > 0:
		parts.append("%dHO" % ho)
	var clr := int(st.get("clearances", 0.0))
	if clr > 0:
		parts.append("%dCLR" % clr)
	var i50 := int(st.get("inside50", 0.0))
	if i50 > 0:
		parts.append("%dI50" % i50)
	var rb := int(st.get("rebounds", 0.0))
	if rb > 0:
		parts.append("%dRB" % rb)
	var one := int(st.get("one_percenters", 0.0))
	if one > 0:
		parts.append("%d1%%" % one)
	var clng := int(st.get("clangers", 0.0))
	if clng >= 2:
		parts.append("%dCLG" % clng)
	return " ".join(parts)


static func resolve_name(player_id: String, fallback := "Player") -> String:
	if player_id == "":
		return fallback
	# GameDB resolves the current label mode (fictional or real AFL name) by ID.
	var label := GameDB.player_display_name_by_id(player_id, "")
	if label != "":
		return label
	return fallback


static func rank_side(roster_side: Array, player_stats: Dictionary, quarters := 2) -> Array:
	var out: Array = []
	for p in roster_side:
		if not (p is Dictionary):
			continue
		var pid := str((p as Dictionary).get("id", ""))
		var st: Dictionary = player_stats.get(pid, {})
		var ov := int((p as Dictionary).get("overall", 50))
		var inf := influence(st)
		var exp := expected_influence(ov, quarters)
		out.append({
			"id": pid,
			"num": int((p as Dictionary).get("num", 0)),
			"name": resolve_name(pid, str((p as Dictionary).get("name", "Player"))),
			# His own position, not the slot he was in when the report was
			# taken (rotations move players through other slots).
			"role": str((p as Dictionary).get("list_role", (p as Dictionary).get("role", ""))),
			"overall": ov,
			"stats": st,
			"influence": inf,
			"expected": exp,
			"delta": inf - exp,
			"line": stat_line(st),
		})
	out.sort_custom(func(a, b): return float(a["influence"]) > float(b["influence"]))
	return out


static func _by_delta(ranked: Array) -> Array:
	var out := ranked.duplicate()
	out.sort_custom(func(a, b): return float(a["delta"]) < float(b["delta"]))
	return out


## First n entries. Array.slice end bounds are inclusive in Godot, which reads
## badly next to Python, so take() keeps call sites obvious.
static func _take(ranked: Array, n: int) -> Array:
	var out: Array = []
	for i in range(mini(n, ranked.size())):
		out.append(ranked[i])
	return out


static func _quarters_played(res: Dictionary) -> int:
	var snaps: Array = res.get("quarter_teams", [])
	if not snaps.is_empty():
		return clampi(snaps.size(), 1, 4)
	var hist: Array = res.get("tactics_history", [])
	if not hist.is_empty():
		return clampi(hist.size(), 1, 4)
	return 2


static func _quarter_value(snaps: Array, snap_idx: int, side: int, key: String) -> float:
	if snap_idx < 0 or snap_idx >= snaps.size():
		return 0.0
	var snap: Dictionary = snaps[snap_idx]
	var teams: Array = snap.get("team", [{}, {}])
	if side < 0 or side >= teams.size():
		return 0.0
	var cur := float((teams[side] as Dictionary).get(key, 0.0))
	if snap_idx == 0:
		return cur
	var prev_teams: Array = (snaps[snap_idx - 1] as Dictionary).get("team", [{}, {}])
	if side < 0 or side >= prev_teams.size():
		return cur
	return cur - float((prev_teams[side] as Dictionary).get(key, 0.0))


static func _quarter_score(snaps: Array, snap_idx: int, side: int) -> int:
	if snap_idx < 0 or snap_idx >= snaps.size():
		return 0
	var cur: Array = (snaps[snap_idx] as Dictionary).get("score", [0, 0])
	var cur_v := int(cur[side]) if side < cur.size() else 0
	if snap_idx == 0:
		return cur_v
	var prev: Array = (snaps[snap_idx - 1] as Dictionary).get("score", [0, 0])
	var prev_v := int(prev[side]) if side < prev.size() else 0
	return cur_v - prev_v


## Main entry point. my_side is 0 for home, 1 for away from this match's
## perspective; the report is always framed as "us vs them". When full-match
## snapshots exist (skip to full time, Q4 box, full-time review) the half-time
## numbers are reconstructed from the Q2 snapshot so the report never shows
## second-half stats by mistake.
static func half_time_report(res: Dictionary, my_side: int) -> Dictionary:
	var snaps: Array = res.get("quarter_teams", [])
	if snaps.size() >= 2 and (snaps[1] as Dictionary).has("team"):
		var ht: Dictionary = snaps[1]
		# Rebuild a half-time view from the Q2 snapshot without duplicating
		# the ~1,100-event log; the report only reads the keys below.
		var ht_players: Dictionary = res.get("players", {})
		if ht.has("players"):
			ht_players = (ht.get("players", {}) as Dictionary).duplicate(true)
		var ht_res := {
			"roster": res.get("roster", [[], []]),
			"team": (ht.get("team", [{}, {}]) as Array).duplicate(true),
			"players": ht_players,
			"score": (ht.get("score", [0, 0]) as Array).duplicate(),
			"goals": (ht.get("goals", [0, 0]) as Array).duplicate(),
			"behinds": (ht.get("behinds", [0, 0]) as Array).duplicate(),
			"tactics_history": res.get("tactics_history", []),
			"quarter_teams": res.get("quarter_teams", []),
			"home": res.get("home", ""),
			"away": res.get("away", ""),
		}
		return _build_report(ht_res, my_side, 2)
	return _build_report(res, my_side, _quarters_played(res))


## The same report over the whole match, for full time.
static func match_report(res: Dictionary, my_side: int) -> Dictionary:
	return _build_report(res, my_side, _quarters_played(res))


static func _build_report(res: Dictionary, my_side: int, quarters: int) -> Dictionary:
	var opp_side := 1 - my_side
	var roster: Array = res.get("roster", [[], []])
	var my_roster: Array = roster[my_side] if roster.size() > my_side else []
	var opp_roster: Array = roster[opp_side] if roster.size() > opp_side else []
	var player_stats: Dictionary = res.get("players", {})
	var teams: Array = res.get("team", [{}, {}])
	var my_team: Dictionary = {}
	var opp_team: Dictionary = {}
	if teams.size() > my_side and teams[my_side] is Dictionary:
		my_team = teams[my_side]
	if teams.size() > opp_side and teams[opp_side] is Dictionary:
		opp_team = teams[opp_side]

	var my_ranked := rank_side(my_roster, player_stats, quarters)
	var opp_ranked := rank_side(opp_roster, player_stats, quarters)
	var my_by_delta := _by_delta(my_ranked)
	var opp_by_delta := _by_delta(opp_ranked)

	var my_best := _take(my_ranked, 3)
	var opp_best := _take(opp_ranked, 3)
	# Strugglers are the biggest under-performers vs expectation, so a quiet
	# star surfaces ahead of a depth player having a par game.
	var my_worst := _take(my_by_delta, 3)
	var opp_worst := _take(opp_by_delta, 3)

	var edges := _team_edges(my_team, opp_team)
	var eff := _efficiency(my_team, opp_team)
	var plans := _split_plans(res, my_side, opp_side, quarters)
	var opp_observed := _observed_lines(res, plans["opp"], opp_side, my_side)
	var keys := _second_half_keys(res, my_side, opp_side, my_team, opp_team, my_ranked, opp_ranked, my_best, opp_best, eff)

	var score: Array = res.get("score", [0, 0])
	var my_score := int(score[my_side]) if score.size() > my_side else 0
	var opp_score := int(score[opp_side]) if score.size() > opp_side else 0
	var goals: Array = res.get("goals", [0, 0])
	var behinds: Array = res.get("behinds", [0, 0])
	var my_key := "home" if my_side == 0 else "away"
	var opp_key := "home" if opp_side == 0 else "away"
	return {
		"quarters": quarters,
		"my_side": my_side,
		"opp_side": opp_side,
		"my_code": str(res.get(my_key, "")),
		"opp_code": str(res.get(opp_key, "")),
		"my_score": my_score,
		"opp_score": opp_score,
		"my_goals": int(goals[my_side]) if goals.size() > my_side else 0,
		"my_behinds": int(behinds[my_side]) if behinds.size() > my_side else 0,
		"opp_goals": int(goals[opp_side]) if goals.size() > opp_side else 0,
		"opp_behinds": int(behinds[opp_side]) if behinds.size() > opp_side else 0,
		"margin": my_score - opp_score,
		"my_best": my_best,
		"my_worst": my_worst,
		"my_ranked": my_ranked,
		"opp_best": opp_best,
		"opp_worst": opp_worst,
		"edges": edges,
		"efficiency": eff,
		"my_plans": plans["mine"],
		"opp_plans": plans["opp"],
		"opp_observed": opp_observed,
		"keys": keys,
	}


static func _team_edges(my_team: Dictionary, opp_team: Dictionary) -> Array:
	var out: Array = []
	for spec in TEAM_COMPARE:
		var key := str(spec[0])
		var label := str(spec[1])
		var thresh := int(spec[2])
		var lower_better := bool(spec[3])
		var my_v := int(float(my_team.get(key, 0.0)))
		var opp_v := int(float(opp_team.get(key, 0.0)))
		var diff := my_v - opp_v
		var leader := "even"
		if absi(diff) > thresh:
			if lower_better:
				leader = "opp" if diff > 0 else "my"
			else:
				leader = "my" if diff > 0 else "opp"
		out.append({
			"key": key, "label": label, "my": my_v, "opp": opp_v,
			"diff": diff, "leader": leader, "lower_better": lower_better,
		})
	return out


static func _efficiency(my_team: Dictionary, opp_team: Dictionary) -> Dictionary:
	var my_i50 := maxf(1.0, float(my_team.get("inside50", 0.0)))
	var opp_i50 := maxf(1.0, float(opp_team.get("inside50", 0.0)))
	var my_g := float(my_team.get("goals", 0.0))
	var opp_g := float(opp_team.get("goals", 0.0))
	return {
		"my_conv": 100.0 * my_g / my_i50,
		"opp_conv": 100.0 * opp_g / opp_i50,
		"my_i50": int(my_i50),
		"opp_i50": int(opp_i50),
	}


static func _split_plans(res: Dictionary, my_side: int, opp_side: int, quarters: int) -> Dictionary:
	var hist: Array = res.get("tactics_history", [])
	var mine: Array = []
	var opp: Array = []
	# Half-time covers the quarters already simulated (normally Q1-Q2).
	var wanted := maxi(1, mini(quarters, 2))
	for h in hist:
		if not (h is Dictionary):
			continue
		var hd: Dictionary = h
		var q := int(hd.get("quarter", 0))
		if q < 1 or q > wanted:
			continue
		var plans: Array = hd.get("plans", [{}, {}])
		if plans.size() < 2:
			continue
		var my_t: Dictionary = {}
		var opp_t: Dictionary = {}
		if plans[my_side] is Dictionary:
			my_t = plans[my_side]
		if plans[opp_side] is Dictionary:
			opp_t = plans[opp_side]
		mine.append(_plan_entry(q, my_t))
		opp.append(_plan_entry(q, opp_t))
	mine.sort_custom(func(a, b): return int(a["quarter"]) < int(b["quarter"]))
	opp.sort_custom(func(a, b): return int(a["quarter"]) < int(b["quarter"]))
	return {"mine": mine, "opp": opp}


static func _plan_entry(q: int, t: Dictionary) -> Dictionary:
	var focus_id := str(t.get("focus_id", ""))
	var tag_id := str(t.get("tag_id", ""))
	var plan := str(t.get("gameplan", "balanced"))
	if plan == "":
		plan = "balanced"
	var pep := str(t.get("pep", "steady"))
	if pep == "":
		pep = "steady"
	return {
		"quarter": q,
		"gameplan": plan,
		"gameplan_label": plan_label(plan),
		"effect": plan_effect(plan),
		"pep": pep,
		"pep_label": pep_label(pep),
		"focus_id": focus_id,
		"tag_id": tag_id,
		"focus_name": resolve_name(focus_id, "") if focus_id != "" else "",
		"tag_name": resolve_name(tag_id, "") if tag_id != "" else "",
	}


## What each opposition quarter actually produced, so the coach can see whether
## a plan change worked. Uses per-quarter team snapshots when available.
static func _observed_lines(res: Dictionary, opp_plans: Array, opp_side: int, my_side: int) -> Array:
	var out: Array = []
	if opp_plans.is_empty():
		return out
	var snaps: Array = res.get("quarter_teams", [])
	if snaps.is_empty():
		for p in opp_plans:
			out.append("Q%d: %s - %s" % [int(p["quarter"]),
				str(p["gameplan_label"]), str(p["effect"])])
		return out
	for i in range(opp_plans.size()):
		var p: Dictionary = opp_plans[i]
		var q := int(p["quarter"])
		var snap_idx := q - 1
		if snap_idx < 0 or snap_idx >= snaps.size():
			continue
		var pts := _quarter_score(snaps, snap_idx, opp_side)
		var my_pts := _quarter_score(snaps, snap_idx, my_side)
		var i50 := int(_quarter_value(snaps, snap_idx, opp_side, "inside50"))
		var tkl := int(_quarter_value(snaps, snap_idx, opp_side, "tackles"))
		var clr := int(_quarter_value(snaps, snap_idx, opp_side, "clearances"))
		var line := "Q%d (%s): %d pts (us %d), %d inside 50s, %d tackles, %d clearances" % [
			q, str(p["gameplan_label"]), pts, my_pts, i50, tkl, clr]
		out.append(line)
	# Call out a visible shift between Q1 and Q2.
	if opp_plans.size() >= 2 and snaps.size() >= 2:
		var first: Dictionary = opp_plans[0]
		var second: Dictionary = opp_plans[1]
		if str(first["gameplan"]) != str(second["gameplan"]):
			var q2_i50 := int(_quarter_value(snaps, 1, opp_side, "inside50"))
			var q1_i50 := int(_quarter_value(snaps, 0, opp_side, "inside50"))
			var q2_tkl := int(_quarter_value(snaps, 1, opp_side, "tackles"))
			var q1_tkl := int(_quarter_value(snaps, 0, opp_side, "tackles"))
			var d_i50 := q2_i50 - q1_i50
			var d_tkl := q2_tkl - q1_tkl
			var d_pts := _quarter_score(snaps, 1, opp_side) - _quarter_score(snaps, 0, opp_side)
			var bits: PackedStringArray = []
			bits.append("%s pts" % _signed(d_pts))
			bits.append("%s inside 50s" % _signed(d_i50))
			bits.append("%s tackles" % _signed(d_tkl))
			out.append("Shift to %s changed their output: %s vs Q1." % [
				str(second["gameplan_label"]), ", ".join(bits)])
	return out


static func _edge(edges: Array, key: String) -> Dictionary:
	for e in edges:
		if str((e as Dictionary).get("key", "")) == key:
			return e
	return {"my": 0, "opp": 0, "diff": 0, "leader": "even"}


static func _signed(n: int) -> String:
	if n > 0:
		return "+%d" % n
	return str(n)


## What stands out at half time: the problems and the strengths, in the
## assistant's words. It says what is happening, never which call to make -
## that is the coach's job.
static func _second_half_keys(res: Dictionary, my_side: int, opp_side: int, my_team: Dictionary, opp_team: Dictionary, my_ranked: Array, _opp_ranked: Array, _my_best: Array, opp_best: Array, eff: Dictionary) -> Array:
	var keys: Array = []
	var score: Array = res.get("score", [0, 0])
	var my_score := int(score[my_side]) if score.size() > my_side else 0
	var opp_score := int(score[opp_side]) if score.size() > opp_side else 0
	var margin := my_score - opp_score
	var edges: Array = _team_edges(my_team, opp_team)

	# 1. Danger man - the opposition player hurting us most.
	if not opp_best.is_empty():
		var danger: Dictionary = opp_best[0]
		if float(danger["influence"]) >= 14.0 and float(danger["delta"]) >= 2.0:
			keys.append("%s is hurting us: %s - %s." % [
				str(danger["name"]), str(danger["line"]), _form_word(float(danger["delta"]))])

	# 2. Our quiet star - a high-rated player well below par.
	for p in my_ranked:
		if int(p["overall"]) >= 76 and float(p["delta"]) <= -4.0:
			keys.append("%s has been quiet: %s." % [str(p["name"]), str(p["line"])])
			break

	# 3. Stoppage.
	var clr := _edge(edges, "clearances")
	if int(clr["diff"]) <= -4:
		keys.append("They are winning the stoppages: clearances %d to %d." % [int(clr["opp"]), int(clr["my"])])
	elif int(clr["diff"]) >= 4:
		keys.append("We are on top at the stoppages: clearances %d to %d." % [int(clr["my"]), int(clr["opp"])])

	# 4. Territory.
	var i50 := _edge(edges, "inside50")
	if int(i50["diff"]) <= -5:
		keys.append("They have had more of the ball going forward: %d inside 50s to %d." % [
			int(i50["opp"]), int(i50["my"])])
	elif int(i50["diff"]) >= 5:
		keys.append("We have had more of the ball going forward: %d inside 50s to %d." % [
			int(i50["my"]), int(i50["opp"])])

	# 5. Pressure.
	var pa := _edge(edges, "pressure_acts")
	if int(pa["diff"]) <= -18:
		keys.append("Their pressure is getting to us: %d pressure acts to our %d." % [int(pa["opp"]), int(pa["my"])])
	elif int(pa["diff"]) >= 18:
		keys.append("Our pressure is biting: %d pressure acts to their %d." % [int(pa["my"]), int(pa["opp"])])

	# 6. Ruck.
	var ho := _edge(edges, "hitouts")
	if int(ho["diff"]) <= -6:
		keys.append("We are losing the ruck: hit-outs %d to %d." % [int(ho["my"]), int(ho["opp"])])

	# 7. Errors.
	var clg := _edge(edges, "clangers")
	if int(clg["my"]) - int(clg["opp"]) >= 4:
		keys.append("Too many errors: %d clangers to their %d." % [int(clg["my"]), int(clg["opp"])])

	# 8. Conversion.
	var my_conv := float(eff.get("my_conv", 0.0))
	var opp_conv := float(eff.get("opp_conv", 0.0))
	if my_conv + 4.0 < opp_conv and int(eff.get("my_i50", 0)) >= 10:
		keys.append("We are wasting our entries; they are making theirs count.")
	elif my_conv > opp_conv + 6.0 and int(eff.get("opp_i50", 0)) >= 10:
		keys.append("We are making our entries count; they are wasting theirs.")

	# 9. The state of the game, so the list is never empty.
	if keys.is_empty():
		if margin >= 18:
			keys.append("In control, %d points up." % margin)
		elif margin <= -18:
			keys.append("%d points down: we need scores." % absi(margin))
		else:
			keys.append("An arm-wrestle: nothing between the sides yet.")

	# Keep the box readable on a phone.
	return _take(keys, 5)


static func _form_word(delta: float) -> String:
	if delta >= 8.0:
		return "dominant"
	if delta >= 4.0:
		return "influential"
	if delta >= 1.0:
		return "busy"
	if delta <= -6.0:
		return "very quiet"
	if delta <= -3.0:
		return "quiet"
	return "even"


## The half-time report at a glance: what is happening, who matters, what
## stands out for the second half. Built from half_time_report(); nothing new
## is measured. {"read": [lines], "best": [...], "lift": [...],
## "danger": [...], "notes": [lines]} - each player {"name", "line"}.
## The full report keeps everything else.
const READ_STATS := ["inside50", "clearances", "hitouts", "pressure_acts", "marks", "disposals"]
const READ_WORDS := {"inside50": "inside 50s", "clearances": "clearances", "hitouts": "hit-outs",
		"pressure_acts": "pressure acts", "marks": "marks", "disposals": "disposals"}
## Which second-half notes say the same thing as a Match read line.
const NOTE_TOPICS := {"clearances": "stoppages", "inside50": "going forward", "pressure_acts": "pressure",
		"hitouts": "ruck"}


## A Player Rating below this over a full game is a quiet one (MatchNotes:
## an ordinary game is 50-80); scaled down for a half.
const LIFT_BELOW := 50.0


static func glance(report: Dictionary, full_time := false) -> Dictionary:
	var span := "game" if full_time else "half"
	var me := GameDB.club_name(str(report.get("my_code", "")))
	var them := GameDB.club_name(str(report.get("opp_code", "")))
	# The two clearest edges, in words.
	var edges := []
	for e in report.get("edges", []):
		var d: Dictionary = e
		if not READ_STATS.has(str(d.get("key", ""))) or str(d.get("leader", "even")) == "even":
			continue
		var hi := maxf(1.0, float(maxi(int(d["my"]), int(d["opp"]))))
		edges.append({"e": d, "gap": absf(float(int(d["my"]) - int(d["opp"]))) / hi})
	edges.sort_custom(func(a, b): return float(a["gap"]) > float(b["gap"]))
	var read: Array = []
	var read_keys := {}
	for x in edges.slice(0, 2):
		var d: Dictionary = x["e"]
		read_keys[str(d["key"])] = true
		var word := str(READ_WORDS.get(str(d["key"]), str(d["label"]).to_lower()))
		if str(d["leader"]) == "my":
			read.append("You lead the %s, %d to %d." % [word, int(d["my"]), int(d["opp"])])
		else:
			read.append("%s lead the %s, %d to %d." % [them, word, int(d["opp"]), int(d["my"])])
	# Their approach, only when it is not a plain game.
	var opp_plans: Array = report.get("opp_plans", [])
	if opp_plans.size() >= 2:
		var q1 := str((opp_plans[0] as Dictionary).get("gameplan", "balanced"))
		var q2 := str((opp_plans[1] as Dictionary).get("gameplan", "balanced"))
		if q1 != q2:
			read.append("%s switched to %s in the second quarter." % [them,
					str((opp_plans[1] as Dictionary).get("gameplan_label", q2)).to_lower()])
		elif q1 != "balanced":
			read.append("%s played %s all %s." % [them,
					str((opp_plans[0] as Dictionary).get("gameplan_label", q1)).to_lower(), span])
	if read.is_empty():
		read.append("An even %s: neither side is on top anywhere in particular." % span)
	var people := func(list: Array, n: int, keep: Callable) -> Array:
		var out := []
		for e in list:
			if out.size() >= n:
				break
			var d: Dictionary = e
			if keep.call(d):
				out.append({"name": str(d.get("name", "Player")),
						"line": MatchNotes.game_line(d.get("stats", {}))})
		return out
	var always := func(_d: Dictionary) -> bool: return true
	# Needs a lift: the lowest Player Ratings, the same number the screen
	# shows beside every name, and only below an ordinary game - a busy
	# defender with 24 disposals and 7 rebounds is never "quiet".
	var lift_pool: Array = (report.get("my_ranked", []) as Array).duplicate()
	lift_pool.sort_custom(func(a, b):
		return MatchNotes.rating(a.get("stats", {})) < MatchNotes.rating(b.get("stats", {})))
	var quiet := func(d: Dictionary) -> bool:
		return MatchNotes.rating(d.get("stats", {})) < LIFT_BELOW * float(int(report.get("quarters", 4))) / 4.0
	return {
		"read": read.slice(0, 3),
		"best": people.call(report.get("my_best", []), 2, always),
		"lift": people.call(lift_pool, 2, quiet),
		"danger": people.call(report.get("opp_best", []), 2, always),
		"notes": _glance_notes(report.get("keys", []), read_keys),
	}


## The assistant's notes in plain words: no player lines (they have their
## own sections), no score (it is at the top), nothing Match read already
## says, and no numbers - just the observation before the colon.
static func _glance_notes(keys: Array, read_keys: Dictionary) -> Array:
	var out := []
	for k in keys:
		var t := str(k)
		if t.contains("is hurting us") or t.contains("has been quiet") \
				or t.contains("points up") or t.contains("points down"):
			continue
		var dup := false
		for key in read_keys:
			if NOTE_TOPICS.has(key) and t.contains(str(NOTE_TOPICS[key])):
				dup = true
		if dup:
			continue
		t = t.split(":")[0].strip_edges()
		if not t.ends_with("."):
			t += "."
		out.append(t)
		if out.size() >= 3:
			break
	return out


static func verdict_for(entry: Dictionary, good: bool) -> String:
	var delta := float(entry["delta"])
	if good:
		if delta >= 8.0:
			return "Dominant"
		if delta >= 4.0:
			return "Influential"
		if delta >= 1.0:
			return "Busy"
		return "Solid"
	if delta <= -6.0:
		return "Very quiet"
	if delta <= -3.0:
		return "Quiet"
	if delta <= -1.0:
		return "Down"
	return "Par game"
