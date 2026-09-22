class_name Ratings
extends RefCounted
## Derives 1-99 attributes, position, overall rating and draft value from raw
## AFL Tables season stats.
##
## Direct port of tools/sim_harness.py::derive_ratings. The Python harness is
## where the model was calibrated against real 2026 team totals, so if a
## constant changes there it must change here too (and vice versa).

## Tunables - single source of truth for match balance. Mirrored in
## tools/sim_harness.py (dict `T`).
const T := {
	"chains_per_game": 165,          # possession chains across BOTH teams
	"max_touches_per_chain": 11,
	"forward50_line": 35.0,          # metres from the centre square
	"goal_line": 85.0,
	"metres_gain_mean": 8.0,         # base metres per effective disposal
	"tackle_retention": 0.44,        # attacking team wins the ball back
	"pressure_base": 0.150,          # chance a touch is tackled
	"clanger_per_chain": 0.645,      # chance the chain ends in an error
	"clanger_is_free": 0.34,         # ...of which are free kicks against
	"mark_share_of_kicks": 0.330,
	"handball_share": 0.42,
	"inside50_goal": 0.243,          # of inside-50 entries
	"inside50_behind": 0.145,
	"stoppage_share": 0.38,          # chains that begin at a genuine stoppage
	"hitouts_per_stoppage": 0.75,    # split between the two rucks
	"clearance_per_stoppage": 0.78,  # to the team that wins the stoppage
	"one_percenter_share": 0.77,     # of inside-50 entries that yield a 1%
	"rebound_on_exit": 0.55,         # defensive-half chains that yield a reb50
	"shrink_games": 5.0,             # sample-size shrink for per-game rates
	"shrink_accuracy": 14.0,         # sample-size shrink for goal conversion
	"home_ground_bonus": 0.030,
	"contest_swing": 360.0,          # higher == less sensitive to strength
	"contest_clamp": 0.60,           # max stoppage win probability
}

## (metric name, source stat column). "hb" is special-cased as di - ki.
const METRIC_SPECS := [
	["disposals_pg", "di"], ["kicks_pg", "ki"], ["marks_pg", "mk"],
	["handballs_pg", "hb"], ["goals_pg", "gl"], ["behinds_pg", "bh"],
	["hitouts_pg", "ho"], ["tackles_pg", "tk"], ["rebounds_pg", "rb"],
	["inside50s_pg", "if50"], ["clearances_pg", "cl"], ["clangers_pg", "cg"],
	["frees_for_pg", "ff"], ["frees_against_pg", "fa"], ["brownlow_pg", "br"],
	["contested_pg", "cp"], ["contested_marks_pg", "cm"],
	["marks_inside50_pg", "mi"], ["one_percenters_pg", "onepct"],
	["bounces_pg", "bo"], ["goal_assists_pg", "ga"],
]

## On-ground structure: 18 players = 1 RUCK, 7 MID, 5 DEF, 5 FWD.
## Order matters - select_22() fills slots in this sequence.
const GROUND_SLOTS := [["RUCK", 1], ["MID", 7], ["DEF", 5], ["FWD", 5]]
const INTERCHANGE := 4
const LIST_SIZE := 44

## Overall-rating weights per role:
## [disposal, pressure, goalkicking, intercept, contested-or-ruck]
const ROLE_WEIGHTS := {
	"RUCK": [0.30, 0.10, 0.10, 0.20, 0.30],
	"FWD": [0.30, 0.08, 0.42, 0.08, 0.12],
	"MID": [0.44, 0.18, 0.14, 0.06, 0.18],
	"DEF": [0.26, 0.30, 0.06, 0.28, 0.10],
}


# ---------------------------------------------------------------------------
# Small maths helpers
# ---------------------------------------------------------------------------
static func percentile(vals: Array, q: float) -> float:
	var s := vals.duplicate()
	s.sort()
	if s.is_empty():
		return 0.0
	var i := q * float(s.size() - 1)
	var lo := int(floorf(i))
	var hi := mini(s.size() - 1, lo + 1)
	return float(s[lo]) + (float(s[hi]) - float(s[lo])) * (i - float(lo))


## Shrink a raw season total toward the league per-player-per-game rate so a
## two-game sample cannot outrank a 25-game sample.
static func shrunk_rate(total: float, games: float, league_rate: float,
		k: float) -> float:
	return (total + k * league_rate) / (games + k)


static func scale_attr(v: float) -> int:
	return int(round(1.0 + 98.0 * clampf(v, 0.0, 1.0)))


# ---------------------------------------------------------------------------
# Normalisation
# ---------------------------------------------------------------------------
## Deliberately NOT a percentile rank: most of these stats are zero for the
## majority of the pool (hit-outs, bounces, marks inside 50), so a percentile
## rank would hand a *high* score to a zero. Capped linear scaling against the
## 98th percentile keeps zero == zero.
static func build_norm_params(players: Array, keys: Array) -> Dictionary:
	var params := {}
	for k in keys:
		var vals := []
		for p in players:
			vals.append(p["rates"][k])
		var invert: bool = k == "clangers_pg" or k == "frees_against_pg"
		var e := {"invert": invert}
		match k:
			"accuracy":
				e["mode"] = "range"; e["lo"] = 0.22; e["hi"] = 0.82
			"games":
				e["mode"] = "range"; e["lo"] = 0.0; e["hi"] = 26.0
			"time_on_ground":
				e["mode"] = "range"; e["lo"] = 0.30; e["hi"] = 0.95
			"brownlow_pg":
				e["mode"] = "cap"; e["ref"] = percentile(vals, 1.0)
			_:
				e["mode"] = "cap"; e["ref"] = percentile(vals, 0.98)
		if e["mode"] == "cap" and float(e["ref"]) <= 0.0:
			e["ref"] = 1.0
		params[k] = e
	return params


static func norm(params: Dictionary, metric: String, v: float) -> float:
	var e: Dictionary = params[metric]
	var x := 0.0
	if e["mode"] == "range":
		var span := float(e["hi"]) - float(e["lo"])
		if is_zero_approx(span):
			span = 1.0
		x = (v - float(e["lo"])) / span
	else:
		x = v / float(e["ref"])
	if e["invert"]:
		x = 1.0 - x
	return clampf(x, 0.0, 1.0)


# ---------------------------------------------------------------------------
# League rates
# ---------------------------------------------------------------------------
## Average *per player per game* rate for each metric. This is the shrinkage
## target. It must NOT be the team-per-game figure: shrinking a player's
## disposals toward 364 (a whole team's output) makes fringe players superhuman.
static func player_league_rates(players: Array) -> Dictionary:
	var gm := 0.0
	for p in players:
		gm += maxf(1.0, p["gm"])
	gm = maxf(1.0, gm)
	var out := {}
	for spec in METRIC_SPECS:
		var metric: String = spec[0]
		var stat: String = spec[1]
		var total := 0.0
		for p in players:
			total += p["di"] - p["ki"] if stat == "hb" else p[stat]
		out[metric] = total / gm
	return out


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------
## Mutates each player dict, adding: rates, norm, attr, role, role_scores,
## overall, value. Call once at boot on the full player pool.
static func derive_all(players: Array) -> Array:
	if players.is_empty():
		return players
	var league := player_league_rates(players)
	var k_games: float = T["shrink_games"]
	var k_acc: float = T["shrink_accuracy"]

	# ---- per-game rates ---------------------------------------------------
	for p in players:
		var gm := maxf(1.0, p["gm"])
		var r := {}
		for spec in METRIC_SPECS:
			var metric: String = spec[0]
			var stat: String = spec[1]
			var total: float = p["di"] - p["ki"] if stat == "hb" else p[stat]
			r[metric] = shrunk_rate(total, gm, league[metric], k_games)
		var shots: float = p["gl"] + p["bh"]
		r["accuracy"] = (p["gl"] + k_acc * 0.52) / (shots + k_acc)
		r["contested_share"] = (p["cp"] + 40.0) / (maxf(1.0, p["di"]) + 100.0)
		r["games"] = gm
		r["time_on_ground"] = p["pctp"] / 100.0
		r["score_involved_pg"] = shrunk_rate(
				p["gl"] + p["bh"] + p["ga"] + p["mi"], gm, 4.0, k_games)
		p["rates"] = r

	# ---- normalisation params over the whole pool --------------------------
	var keys: Array = players[0]["rates"].keys()
	var params := build_norm_params(players, keys)

	for p in players:
		var q := {}
		for k in keys:
			q[k] = norm(params, k, p["rates"][k])
		p["norm"] = q

		# ---- 1-99 attributes ----------------------------------------------
		var a := {}
		a["disposal"] = scale_attr(0.60 * q["disposals_pg"]
				+ 0.25 * q["contested_pg"] + 0.15 * q["clearances_pg"])
		a["contested"] = scale_attr(0.45 * q["contested_pg"]
				+ 0.30 * q["clearances_pg"] + 0.25 * q["contested_share"])
		a["marking"] = scale_attr(0.50 * q["marks_pg"]
				+ 0.28 * q["contested_marks_pg"] + 0.22 * q["marks_inside50_pg"])
		a["pressure"] = scale_attr(0.62 * q["tackles_pg"]
				+ 0.38 * q["one_percenters_pg"])
		a["intercept"] = scale_attr(0.45 * q["rebounds_pg"]
				+ 0.28 * q["marks_pg"] + 0.27 * q["one_percenters_pg"])
		a["carry"] = scale_attr(0.45 * q["inside50s_pg"]
				+ 0.28 * q["bounces_pg"] + 0.27 * q["disposals_pg"])
		a["goalkicking"] = scale_attr(0.66 * q["goals_pg"]
				+ 0.34 * q["marks_inside50_pg"])
		a["accuracy"] = scale_attr(q["accuracy"])
		a["creating"] = scale_attr(0.45 * q["goal_assists_pg"]
				+ 0.30 * q["inside50s_pg"] + 0.25 * q["marks_inside50_pg"])
		a["ruck"] = scale_attr(0.70 * q["hitouts_pg"]
				+ 0.18 * q["clearances_pg"] + 0.12 * q["contested_marks_pg"])
		a["discipline"] = scale_attr(0.62 * q["clangers_pg"]
				+ 0.38 * q["frees_against_pg"])
		a["durability"] = scale_attr(0.55 * q["games"]
				+ 0.45 * q["time_on_ground"])
		a["star"] = scale_attr(0.68 * q["brownlow_pg"]
				+ 0.32 * q["disposals_pg"])
		p["attr"] = a

		# ---- role classification ------------------------------------------
		var hitouts_pg: float = p["ho"] / maxf(1.0, p["gm"])
		var scores := {
			"FWD": 0.50 * q["goals_pg"] + 0.26 * q["marks_inside50_pg"]
					+ 0.14 * q["goal_assists_pg"] + 0.10 * q["behinds_pg"],
			"MID": 0.42 * q["disposals_pg"] + 0.30 * q["contested_pg"]
					+ 0.28 * q["clearances_pg"],
			"DEF": 0.42 * q["rebounds_pg"] + 0.30 * q["one_percenters_pg"]
					+ 0.20 * q["marks_pg"] + 0.08 * (1.0 - q["goals_pg"]),
		}
		# Ruck is gated on actual hit-out volume, not on a normalised score:
		# without the gate every tall forward gets classified as a ruckman.
		scores["RUCK"] = (0.25 + 0.85 * q["hitouts_pg"]) if hitouts_pg >= 7.0 else -1.0
		p["role_scores"] = scores
		p["role"] = pick_role(scores)

		# ---- overall + draft value ----------------------------------------
		var w: Array = ROLE_WEIGHTS[p["role"]]
		var fifth: float = a["ruck"] if p["role"] == "RUCK" else a["contested"]
		var core: float = (w[0] * a["disposal"] + w[1] * a["pressure"]
				+ w[2] * a["goalkicking"] + w[3] * a["intercept"] + w[4] * fifth)
		var overall: float = 0.70 * core + 0.22 * a["star"] + 0.08 * a["durability"]
		# Pull thin samples back toward the middle: a 3-game player's rating is
		# mostly noise, so it should not look like a proven 25-game player's.
		var conf: float = minf(1.0, p["gm"] / 14.0)
		overall = 40.0 + (overall - 40.0) * (0.40 + 0.60 * conf)
		p["overall"] = int(clampi(roundi(overall), 1, 99))
		p["value"] = salary_value(p["overall"])

	return players


## First-max wins, matching the Python harness's insertion order
## (FWD, MID, DEF, RUCK) so ties resolve identically.
static func pick_role(scores: Dictionary) -> String:
	var best := "MID"
	var best_v := -INF
	for role in ["FWD", "MID", "DEF", "RUCK"]:
		var v: float = scores[role]
		if v > best_v:
			best_v = v
			best = role
	return best


## Draft salary-cap cost (1-10) derived from the overall rating.
static func salary_value(overall: int) -> int:
	var steps := [[90, 10], [85, 9], [79, 8], [73, 7], [67, 6],
			[61, 5], [55, 4], [48, 3], [41, 2]]
	for s in steps:
		if overall >= s[0]:
			return s[1]
	return 1


# ---------------------------------------------------------------------------
# Squad selection
# ---------------------------------------------------------------------------
## Best 18 on the ground respecting the 1R/7M/5D/5F structure, plus 4 on the
## bench. Structural shortfalls (a list with no recognised ruckman, say) are
## backfilled by overall rating so a team always fields 18.
static func select_22(list_players: Array) -> Dictionary:
	var pool := list_players.duplicate()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])

	var ground: Array = []
	var used := {}
	for slot in GROUND_SLOTS:
		var role: String = slot[0]
		var need: int = slot[1]
		var added := 0
		for p in pool:
			if added >= need:
				break
			if p["role"] == role and not used.has(p["id"]):
				ground.append(p)
				used[p["id"]] = true
				added += 1
	for p in pool:
		if ground.size() >= 18:
			break
		if not used.has(p["id"]):
			ground.append(p)
			used[p["id"]] = true

	var bench: Array = []
	for p in pool:
		if bench.size() >= INTERCHANGE:
			break
		if not used.has(p["id"]):
			bench.append(p)

	return {"ground": ground.slice(0, 18), "bench": bench}
