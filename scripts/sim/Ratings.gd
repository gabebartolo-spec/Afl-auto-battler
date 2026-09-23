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
	"pressure_base": 0.158,          # chance a touch is tackled
	"clanger_per_chain": 0.68,      # chance the chain ends in an error
	"clanger_is_free": 0.34,         # ...of which are free kicks against
	"mark_share_of_kicks": 0.330,
	"handball_share": 0.42,
	"inside50_goal": 0.252,          # of inside-50 entries
	"inside50_behind": 0.168,
	"stoppage_share": 0.38,          # chains that begin at a genuine stoppage
	"hitouts_per_stoppage": 0.81,    # split between the two rucks
	"clearance_per_stoppage": 0.815,  # to the team that wins the stoppage
	"one_percenter_share": 0.83,     # of inside-50 entries that yield a 1%
	"rebound_on_exit": 0.55,         # defensive-half chains that yield a reb50
	"rebound_from": -16.0,           # a carry from behind this line...
	"rebound_to": -13.0,             # ...to beyond this one is a rebound 50
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

## Raw season columns every player dict carries. GameDB.STAT_KEYS must match;
## prospects (no AFL stats) get these zero-filled for the display rows.
const STATS_ZERO_KEYS := ["gm", "ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "rb",
		"if50", "cl", "cg", "ff", "fa", "br", "cp", "up", "cm", "mi",
		"onepct", "bo", "ga", "pctp"]

## Engine role -> the three-letter position tag used by the CSVs.
const ROLE_SHORT_TO_POS := {"RUCK": "RUC", "MID": "MID", "DEF": "DEF", "FWD": "FWD"}

## Games of evidence the overall-confidence shrink should assume. Prospects
## are projections (no sample to shrink); players who have completed a
## simulated season carry their bumped "sample" so a small 2026 games count
## cannot suppress them forever. Everything else keeps its real season games.
static func effective_games(p: Dictionary) -> float:
	if p.has("sample"):
		return maxf(1.0, float(p["sample"]))
	if bool(p.get("projected", false)):
		return 14.0
	return maxf(1.0, float(p.get("gm", 0.0)))

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
		p["role2"] = assign_secondary(p)

		# ---- overall + draft value ----------------------------------------
		p["overall"] = rate_overall(a, str(p["role"]), float(p["gm"]))
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


## Raw blend, confidence shrink, then a stretch so the best 2026 players land
## near 90. Monotonic: Brownlow order is preserved. Must match
## tools/sim_harness.py (the shrink lives in derive_ratings; the stretch is
## scale_overall).
static func rate_overall(a: Dictionary, role: String, games: float) -> int:
	var w: Array = ROLE_WEIGHTS.get(role, ROLE_WEIGHTS["MID"])
	var fifth: float = float(a["ruck"]) if role == "RUCK" else float(a["contested"])
	var core: float = (float(w[0]) * float(a["disposal"]) + float(w[1]) * float(a["pressure"])
			+ float(w[2]) * float(a["goalkicking"]) + float(w[3]) * float(a["intercept"])
			+ float(w[4]) * fifth)
	var overall: float = 0.70 * core + 0.22 * float(a["star"]) + 0.08 * float(a["durability"])
	overall = position_stretch(overall, role)
	var conf: float = minf(1.0, games / 14.0)
	overall = 40.0 + (overall - 40.0) * (0.40 + 0.60 * conf)
	return scale_overall(overall)


## Key position concession. The stats a rating is built from (disposals,
## Brownlow votes) are midfield stats, so defenders, forwards and rucks
## bunch up well below the elite midfielders: in 2026 the best key defender
## rated 72 against a 92 midfielder, with the medians level. Each position's
## raw blend is re-anchored so its median sits on the midfield median and its
## 98th percentile on 85% of the way to the midfield one: the elite of every
## position reaches the high 80s. Beyond the 98th percentile the stretch
## goes one for one, so a single outlier is not blown out. Monotonic within a position, so team
## selection and the match engine (which rolls attributes) are unchanged.
## Anchors are the 2026 raw blends of players with 12+ games; they are fixed
## so generated prospects and later seasons use the same scale.
## Must match tools/sim_harness.py::position_stretch.
const STRETCH_TARGET := [49.36, 73.74]   # midfield p50, p50 + 0.85 * (p98 - p50)
const STRETCH_ANCHORS := {                # [p50, p98] of each position
	"DEF": [45.60, 56.07],
	"FWD": [47.70, 59.96],
	"RUCK": [48.04, 69.46],
}


static func position_stretch(raw: float, role: String) -> float:
	if not STRETCH_ANCHORS.has(role):
		return raw
	var anchor: Array = STRETCH_ANCHORS[role]
	var g50 := float(anchor[0])
	var g98 := float(anchor[1])
	var m50 := float(STRETCH_TARGET[0])
	var t98 := float(STRETCH_TARGET[1])
	if raw <= g50:
		return raw + (m50 - g50)
	if raw <= g98:
		return m50 + (raw - g50) * (t98 - m50) / (g98 - g50)
	# Past the 98th percentile, one for one: an outlier is not amplified.
	return t98 + (raw - g98)


static func scale_overall(raw: float) -> int:
	if raw < 32.0:
		return clampi(int(round(30.0 + (raw - 20.0) * (14.0 / 12.0))), 1, 99)
	var t := clampf((raw - 32.0) / 49.0, 0.0, 1.2)
	return clampi(int(round(44.0 + pow(t, 0.92) * 48.0)), 1, 99)


## Second role only when the season numbers clear a gate. Empty string means
## one role. Must match tools/sim_harness.py::assign_secondary.
static func assign_secondary(p: Dictionary) -> String:
	var scores: Dictionary = p["role_scores"]
	var primary := str(p["role"])
	var best := ""
	var best_v := -1.0
	for role in ["FWD", "MID", "DEF", "RUCK"]:
		if role == primary:
			continue
		var sc: float = float(scores.get(role, -1.0))
		if sc < 0.0 or not _secondary_ok(p, primary, role, sc):
			continue
		if sc > best_v:
			best_v = sc
			best = role
	return best


static func _secondary_ok(p: Dictionary, primary: String, role: String, sc: float) -> bool:
	var primary_sc: float = float(p["role_scores"].get(primary, 0.0))
	var games := maxf(1.0, float(p["gm"]))
	if role == "FWD":
		if sc < 0.46 or (int(p["gl"]) < 12 and int(p["mi"]) < 18):
			return false
		return sc >= primary_sc * 0.50
	if role == "MID":
		if sc < 0.52 or float(p["di"]) / games < 16.0:
			return false
		return sc >= primary_sc * 0.58
	if role == "DEF":
		if sc < 0.50 or (float(p["rb"]) + float(p["onepct"])) / games < 3.2:
			return false
		return sc >= primary_sc * 0.60
	if role == "RUCK":
		return float(p["ho"]) / games >= 5.0 and sc >= 0.75
	return false


static func role_tag(p: Dictionary) -> String:
	var primary := str(p.get("role", ""))
	var secondary := str(p.get("role2", ""))
	if secondary == "" or secondary == primary:
		return primary
	return "%s/%s" % [primary, secondary]


static func plays_role(p: Dictionary, role: String) -> bool:
	if role == "":
		return true
	return str(p.get("role", "")) == role or str(p.get("role2", "")) == role


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
			if str(p["role"]) == role and not used.has(p["id"]):
				ground.append(_for_slot(p, role))
				used[p["id"]] = true
				added += 1
		# A MID/FWD can fill a forward slot once the primary forwards are gone.
		for p in pool:
			if added >= need:
				break
			if str(p.get("role2", "")) == role and not used.has(p["id"]):
				ground.append(_for_slot(p, role))
				used[p["id"]] = true
				added += 1
	for p in pool:
		if ground.size() >= 18:
			break
		if not used.has(p["id"]):
			ground.append(_for_slot(p, str(p["role"])))
			used[p["id"]] = true

	var bench: Array = []
	for p in pool:
		if bench.size() >= INTERCHANGE:
			break
		if not used.has(p["id"]):
			bench.append(p)

	return {"ground": ground.slice(0, 18), "bench": bench}


## Copy so the match-day slot does not rewrite the list player's natural role.
static func _for_slot(p: Dictionary, slot: String) -> Dictionary:
	var copy := p.duplicate()
	copy["list_tag"] = role_tag(p)
	copy["role"] = slot
	return copy
