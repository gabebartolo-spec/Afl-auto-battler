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
	"chains_per_game": 200,          # possession chains across BOTH teams
	"max_touches_per_chain": 14,
	"forward50_line": 35.0,          # metres from the centre square
	"goal_line": 85.0,
	"metres_gain_mean": 9.7,         # base metres per effective disposal
	"tackle_retention": 0.44,        # attacking team wins the ball back
	"pressure_base": 0.160,          # chance a touch is tackled
	"clanger_per_chain": 0.625,     # chance the chain ends in an error
	"clanger_is_free": 0.34,         # ...of which are free kicks against
	"mark_share_of_kicks": 0.330,
	"handball_share": 0.44,
	"inside50_goal": 0.279,          # of inside-50 entries (0.269 before forward archetypes, ARD-M3-002)
	"inside50_behind": 0.180,
	"stoppage_share": 0.42,          # chains that begin at a genuine stoppage
	"hitouts_per_stoppage": 0.81,    # split between the two rucks
	"clearance_per_stoppage": 0.815,  # to the team that wins the stoppage
	"one_percenter_share": 0.83,     # of inside-50 entries that yield a 1%
	"rebound_on_exit": 0.55,         # defensive-half chains that yield a reb50
	"shooter_power": 0.5,            # how strongly shots go to the best kicks
	"rebound_from": -18.0,           # a carry from behind this line...
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

## On-ground structure: 18 players = 6 DEF, 6 MID, 6 FWD, where the ruck is
## counted with midfield (1 RUCK + 5 MID). Order matters - select_22() fills
## slots in this sequence.
const GROUND_SLOTS := [["RUCK", 1], ["MID", 5], ["DEF", 6], ["FWD", 6]]
## The match-day squad is 18 on the ground plus five interchange - 23, with
## no substitute role (ARD-M5-001, director 2026-10-06). Every bench player
## rotates, covers injuries and plays as fully as the other four.
const INTERCHANGE := 5
## The bench size selection uses: INTERCHANGE, changed only by audits that
## compare squad sizes on the same seeds (tools/audit/interchange_impl.gd).
static var bench_size := INTERCHANGE
## Audits only: false reproduces the old bench (best of the rest, no line
## cover, no dual ruck) for a before/after comparison.
static var bench_rules := true
## A second position (natural or learned) earns a spot on merit: a player
## left out who plays a line better than its weakest starter takes that spot
## (director, 2026-10-06). Audits only: false gives the old order, where a
## second position was used only once a line ran out of its own players.
static var merit_lines := true
## The lines an auto-picked bench covers before taking the best of the rest.
const BENCH_COVER := ["FWD", "DEF", "MID"]
## How close (OVR) a spare ruck must be for an AI club to run dual ruck.
const DUAL_RUCK_MARGIN := 5.0
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

## Overall-rating core per role: the attributes the match engine rewards a
## player in that role for (Squad._aggregate and the MatchSim rolls),
## weighted roughly by what each is worth to a result - measured by lifting
## one attribute across a role and replaying the match (docs/DESIGN.md,
## "Overall & salary"). Each role's weights add to 1.0.
## A mid wins the stoppage and keeps the ball when tackled (contested), then
## moves it (disposal, carry); a defender tackles (pressure) and wins the
## ball back inside 50 (intercept); a forward kicks goals and marks inside
## 50; a ruck wins the tap. What the engine never uses for a role - a
## defender's disposal, a ruck's intercept - is left out.
const ROLE_WEIGHTS := {
	"RUCK": {"ruck": 0.90, "contested": 0.10},
	"FWD": {"goalkicking": 0.30, "pressure": 0.20, "marking": 0.15, "accuracy": 0.15, "creating": 0.12, "carry": 0.08},
	"MID": {"contested": 0.55, "disposal": 0.13, "carry": 0.14, "pressure": 0.10, "goalkicking": 0.04, "accuracy": 0.04},
	"DEF": {"intercept": 0.40, "pressure": 0.35, "carry": 0.15, "contested": 0.10},
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
		var adj := float(ATTR_ADJUSTMENTS.get("%s|%s %s" % [p.get("club", ""), p.get("first", ""), p.get("last", "")], 1.0))
		if adj != 1.0:
			for k in a:
				a[k] = clampi(int(round(float(a[k]) * adj)), 1, 99)
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
		p["role"] = listed_primary(p, pick_role(scores))
		var fix := "%s|%s %s" % [p.get("club", ""), p.get("first", ""), p.get("last", "")]
		if ROLE_CORRECTIONS.has(fix):
			p["role"] = ROLE_CORRECTIONS[fix]
		p["role2"] = assign_secondary(p)

		# ---- overall + draft value ----------------------------------------
		p["overall"] = rate_overall(a, str(p["role"]), float(p["gm"]))
		p["value"] = salary_value(p["overall"])

	return players


## Players the stat classifier clearly gets wrong: listed and played as
## forwards, but a light goal year reads as midfield on the numbers. Only
## unambiguous cases (first positions); the listing otherwise only adds a
## second position (listed_secondary). Mirrored in tools/sim_harness.py.
const ROLE_CORRECTIONS := {
	"RIC|Maurice Rioli": "FWD",
	"WBD|Cody Weightman": "FWD",
}


## Director's player-data balance corrections: every attribute scaled by the
## factor, capped at 99, before OVR is rated. Named players only; never a
## reason to change the generation model. Mirrored in tools/sim_harness.py.
## Bowey's factor is the smallest that lifts his OVR 5% (68 to 71); his POT 5%
## (72 to 76) is set in data/potential_overrides.csv.
const ATTR_ADJUSTMENTS := {
	"MEL|Harvey Langford": 1.15,
	"MEL|Jake Bowey": 1.022,
	"PAD|Connor Rozee": 1.10,
}


## His club's listing is his first position when the numbers read him as a
## midfielder: a listed forward or defender with heavy possession is still a
## forward or defender who can go through the middle. The numbers win when
## his listed-line game has thinned out and he wins clearances, or when that
## listed game has gone altogether.
const LISTED_KEEP := 0.65
const LISTED_GONE := 0.50
const LISTED_MID_CLEARANCES := 1.5
const LISTED_TRUST_GAMES := 6.0


static func listed_primary(p: Dictionary, role: String) -> String:
	var listed := str(p.get("real_pos", ""))
	if role != "MID" or not (listed == "FWD" or listed == "DEF"):
		return role
	var scores: Dictionary = p["role_scores"]
	var games := float(p.get("gm", 0.0))
	if games < LISTED_TRUST_GAMES \
			or float(scores[listed]) >= LISTED_KEEP * float(scores["MID"]) \
			or (float(scores[listed]) >= LISTED_GONE * float(scores["MID"]) \
				and float(p.get("cl", 0.0)) / games < LISTED_MID_CLEARANCES):
		return listed
	return role


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


## Raw blend (role core, star power, durability), the position scale, a
## confidence shrink, then a stretch so the best 2026 players land near 90.
## Must match
## tools/sim_harness.py (the shrink lives in derive_ratings; the stretch is
## scale_overall).
static func rate_overall(a: Dictionary, role: String, games: float) -> int:
	var w: Dictionary = ROLE_WEIGHTS.get(role, ROLE_WEIGHTS["MID"])
	var core := 0.0
	for key in w:
		core += float(w[key]) * float(a[key])
	var overall: float = 0.70 * core + 0.22 * float(a["star"]) + 0.08 * float(a["durability"])
	overall = position_stretch(overall, role)
	var conf: float = minf(1.0, games / 14.0)
	overall = 40.0 + (overall - 40.0) * (0.40 + 0.60 * conf)
	return scale_overall(overall)


## Position scale. Each position's raw blend is mapped onto one shared
## scale at three points - its 10th, 50th and 98th percentiles - piecewise
## linearly, so every position's spread lands where the 2026 scale put it:
## medians level with the midfield median, and the elite of every position
## in the high 80s (the other positions' 98th percentile sits 85% of the way
## to the midfield one, the key position concession). Outside the 10th-98th
## band the map goes one for one, so an outlier is neither amplified nor
## squashed. Monotonic within a position.
## Anchors are the 2026 raw blends of players with 12+ games; they are fixed
## so generated prospects and later seasons use the same scale.
## Must match tools/sim_harness.py::position_stretch (and intake_harness.py).
const STRETCH_ANCHORS := {                # [p10, p50, p98] raw blend
	"MID": [41.22, 53.99, 82.62],
	"DEF": [40.07, 47.75, 58.86],
	"FWD": [36.86, 48.25, 61.42],
	"RUCK": [39.13, 66.27, 86.90],
}
const STRETCH_TARGETS := {                # where they land
	"MID": [37.74, 49.36, 78.04],
	"DEF": [43.07, 49.41, 73.72],
	"FWD": [38.38, 49.48, 78.04],
	"RUCK": [37.50, 49.36, 73.56],
}


static func position_stretch(raw: float, role: String) -> float:
	if not STRETCH_ANCHORS.has(role):
		return raw
	var g: Array = STRETCH_ANCHORS[role]
	var t: Array = STRETCH_TARGETS[role]
	if raw <= float(g[0]):
		return raw + (float(t[0]) - float(g[0]))
	if raw <= float(g[1]):
		return float(t[0]) + (raw - float(g[0])) * (float(t[1]) - float(t[0])) / (float(g[1]) - float(g[0]))
	if raw <= float(g[2]):
		return float(t[1]) + (raw - float(g[1])) * (float(t[2]) - float(t[1])) / (float(g[2]) - float(g[1]))
	# Past the 98th percentile, one for one: an outlier is not amplified.
	return float(t[2]) + (raw - float(g[2]))


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
	if best == "":
		best = listed_secondary(p)
	return best


## The line his club lists him in, as a second position, for a player the
## numbers read as a midfielder: a listed forward who kicks goals or marks
## inside 50, a listed defender who wins it back (rebound 50s and one
## percenters). His club's listing is the evidence; his own numbers have to
## back it up. Never changes his first position, rating or type.
## Mirrored in tools/sim_harness.py.
const LISTED_FWD_GOALS := 0.35      # goals a game
const LISTED_FWD_MARKS_I50 := 0.5   # marks inside 50 a game
const LISTED_DEF_ACTIONS := 2.0     # rebound 50s + one percenters a game


static func listed_secondary(p: Dictionary) -> String:
	if str(p.get("role", "")) != "MID":
		return ""
	var listed := str(p.get("real_pos", ""))
	var games := maxf(1.0, float(p.get("gm", 0.0)))
	if listed == "FWD" and (float(p.get("gl", 0.0)) / games >= LISTED_FWD_GOALS
			or float(p.get("mi", 0.0)) / games >= LISTED_FWD_MARKS_I50):
		return "FWD"
	if listed == "DEF" and (float(p.get("rb", 0.0)) + float(p.get("onepct", 0.0))) / games >= LISTED_DEF_ACTIONS:
		return "DEF"
	return ""


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
	var tag := primary
	for r in second_positions(p):
		if str(r) != primary:
			tag += "/" + str(r)
	return tag


## Every position he can be picked in: his own, his second, and any he has
## learned in training (GameState: learning another position).
static func positions(p: Dictionary) -> Array:
	var out := [str(p.get("own_role", p.get("role", "")))]
	for r in second_positions(p):
		if not out.has(r):
			out.append(r)
	return out


## His second position and any learned after it.
static func second_positions(p: Dictionary) -> Array:
	var out := []
	var r2 := str(p.get("role2", ""))
	if r2 != "":
		out.append(r2)
	for r in p.get("learned", []):
		if str(r) != "" and not out.has(str(r)):
			out.append(str(r))
	return out


static func plays_role(p: Dictionary, role: String) -> bool:
	if role == "":
		return true
	return str(p.get("role", "")) == role or second_positions(p).has(role)


## Plausible annual AFL salary from the overall rating. This is the simple
## list-management base salary used by the game, not a claim to reproduce
## every real AFL payment (match payments/ASAs are deliberately out of scope).
## The curve preserves the old 1-10 salary tiers while expressing them in
## football money: depth at the senior floor, established players in the
## hundreds of thousands, and genuine stars above $1m.
static func salary_value(overall: int) -> int:
	# Annual salary the market pays for a rating: it rises smoothly between
	# these points (no cliff for one rating point), from the senior minimum.
	var points := [[40, 155000], [48, 255000], [55, 335000], [61, 415000],
			[67, 515000], [73, 625000], [79, 740000], [85, 875000], [90, 1030000], [99, 1250000]]
	if overall <= int(points[0][0]):
		return int(points[0][1])
	for i in range(1, points.size()):
		if overall <= int(points[i][0]):
			var lo: Array = points[i - 1]
			var hi: Array = points[i]
			var t := float(overall - int(lo[0])) / float(int(hi[0]) - int(lo[0]))
			return int(round(lerpf(float(lo[1]), float(hi[1]), t) / 5000.0)) * 5000
	return int(points[points.size() - 1][1])


# ---------------------------------------------------------------------------
# Squad selection
# ---------------------------------------------------------------------------
## Best 18 on the ground respecting the 1R/5M/6D/6F structure, plus
## INTERCHANGE (5) on the bench: the match-day 23. (The name predates the
## fifth interchange.) Structural shortfalls (a list with no recognised ruckman, say) are
## backfilled by overall rating so a team always fields 18.
## `dual`: run a second ruck on the bench - 1 yes (a coach's call: he takes
## the first bench spot), 0 no, -1 the AI's rule (only when the spare ruck is
## within DUAL_RUCK_MARGIN of the bench player he would replace).
static func select_22(list_players: Array, dual := -1) -> Dictionary:
	var pool := list_players.duplicate()
	# A player promised a game this week (a kid given his chance, a talk) or a
	# run (Backing) is first in line for his own position; then the best
	# available.
	var promised := {}
	for p in pool:
		if p.has("expects_game") or Backing.is_active(p):
			promised[p["id"]] = true
	pool.sort_custom(func(a, b):
		var pa: bool = promised.has(a["id"])
		if pa != promised.has(b["id"]):
			return pa
		return float(a["overall"]) * Workload.selection_factor(a) > float(b["overall"]) * Workload.selection_factor(b))

	var ground: Array = []
	var used := {}
	for slot in GROUND_SLOTS:
		var role: String = slot[0]
		var need: int = slot[1]
		var added := 0
		# Ruck is a specialist job: among recognised primary/secondary rucks,
		# pick the best tap player rather than the highest overall. This keeps
		# a high-OVR part-timer from displacing the side's actual best ruck.
		if role == "RUCK":
			var recognised := []
			for p in pool:
				if plays_role(p, "RUCK") and not used.has(p["id"]):
					recognised.append(p)
			# The best tap player first, but a promised ruck is first in line.
			var first := []
			var others := []
			for p in by_ruck(recognised):
				if promised.has(p["id"]):
					first.append(p)
				else:
					others.append(p)
			for p in first + others:
				if added >= need:
					break
				ground.append(_for_slot(p, role))
				used[p["id"]] = true
				added += 1
		else:
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
				if second_positions(p).has(role) and not used.has(p["id"]):
					ground.append(_for_slot(p, role))
					used[p["id"]] = true
					added += 1
		# No recognised ruck on the list: the best tap player available goes
		# up as an emergency, not simply the best overall player.
		if role == "RUCK" and added < need:
			for p in by_ruck(pool):
				if added >= need:
					break
				if not used.has(p["id"]):
					ground.append(_for_slot(p, role))
					used[p["id"]] = true
					added += 1
	if merit_lines:
		_merit_swaps(pool, ground, used, promised)
	for p in pool:
		if ground.size() >= 18:
			break
		if not used.has(p["id"]):
			ground.append(_for_slot(p, str(p["role"])))
			used[p["id"]] = true

	# The bench covers the lines first - a forward, a defender and a
	# midfielder, the best of each left - then the best of the rest, so a
	# tired forward is relieved by a forward, as on a real interchange bench.
	# Dual ruck: the second ruck takes the first spot.
	var bench: Array = []
	var spare_ruck: Dictionary = {}
	for p in by_ruck(pool):
		if not used.has(p["id"]) and str(p.get("role", "")) == "RUCK":
			spare_ruck = p
			break
	if dual == 1 and bench_rules and not spare_ruck.is_empty():
		bench.append(spare_ruck)
		used[spare_ruck["id"]] = true
	for line in (BENCH_COVER if bench_rules else []):
		for p in pool:
			if bench.size() >= bench_size:
				break
			if not used.has(p["id"]) and str(p.get("role", "")) == line:
				bench.append(p)
				used[p["id"]] = true
				break
	for p in pool:
		if bench.size() >= bench_size:
			break
		if not used.has(p["id"]):
			bench.append(p)
			used[p["id"]] = true

	# The AI's call: a second ruck earns the last spot when he is close to
	# the player he'd replace.
	if dual == -1 and bench_rules and not spare_ruck.is_empty() and not used.has(spare_ruck["id"]) \
			and bench.size() >= bench_size and bench_size > BENCH_COVER.size():
		var last: Dictionary = bench[bench.size() - 1]
		if float(spare_ruck["overall"]) >= float(last["overall"]) - DUAL_RUCK_MARGIN:
			used.erase(last["id"])
			bench[bench.size() - 1] = spare_ruck
			used[spare_ruck["id"]] = true

	ground = ground.slice(0, 18)
	Roles.mark_wings(ground)
	return {"ground": ground, "bench": bench}


## True when a player can take the field (not injured, suspended or rested).
static func available(p: Dictionary) -> bool:
	return int(p.get("injury_weeks", 0)) <= 0 \
			and int(p.get("suspension_weeks", 0)) <= 0 \
			and not bool(p.get("rested", false))


## The match-day 22. With an empty selection the best available side is
## picked automatically (select_22). A selection is
## {"RUCK": [ids], "MID": [...], "WING": [...], "DEF": [...], "FWD": [...],
## "BENCH": [...], "OUT": [ids]} - WING names two of the five midfielders
## (Roles), MID the centre square: named players take their slots (any player can be named in
## any position), and a gap - an injured or departed player, or a slot left
## short - is filled the automatic way from the unnamed players, then the
## named bench, and only as a last resort from those you left OUT. Injured
## players never play.
static func select_side(list_players: Array, selection: Dictionary = {}) -> Dictionary:
	var pool: Array = []
	for p in list_players:
		if available(p):
			pool.append(p)
	# The dual-ruck call travels with the selection; a selection that is only
	# that call is still the auto-pick.
	var dual := -1
	if selection.has("DUAL_RUCK"):
		dual = 1 if bool(selection["DUAL_RUCK"]) else 0
		selection = selection.duplicate()
		selection.erase("DUAL_RUCK")
	if selection.is_empty():
		return select_22(pool, dual)
	pool.sort_custom(func(a, b):
		return float(a["overall"]) * Workload.selection_factor(a) > float(b["overall"]) * Workload.selection_factor(b))
	var by_id := {}
	for p in pool:
		by_id[str(p["id"])] = p
	var ground: Array = []
	var used := {}
	for slot in GROUND_SLOTS:
		var role: String = slot[0]
		var added := 0
		# Wings are two of the five midfield spots.
		var named: Array = selection.get(role, [])
		if role == "MID":
			named = (selection.get("WING", []) as Array) + named
		for id in named:
			if added >= int(slot[1]):
				break
			var p = by_id.get(str(id))
			if p == null or used.has(str(id)):
				continue
			ground.append(_for_slot(p, role))
			used[str(id)] = true
			added += 1
	# Fill order for gaps: 0 unnamed, 1 the named bench, 2 players left out.
	var tier := {}
	for id in selection.get("BENCH", []):
		if by_id.has(str(id)) and not used.has(str(id)):
			tier[str(id)] = 1
	for id in selection.get("OUT", []):
		if by_id.has(str(id)) and not used.has(str(id)):
			tier[str(id)] = 2
	for pass_tier in [0, 1, 2]:
		for slot in GROUND_SLOTS:
			var role: String = slot[0]
			var have := 0
			for g in ground:
				if str(g["role"]) == role:
					have += 1
			if role == "RUCK":
				# A missing named ruck is filled by the best available recognised
				# ruck in this selection tier, not whichever ruck has the best OVR.
				var recognised := []
				for p in pool:
					var id := str(p["id"])
					if not used.has(id) and int(tier.get(id, 0)) == pass_tier and plays_role(p, "RUCK"):
						recognised.append(p)
				for p in by_ruck(recognised):
					if have >= int(slot[1]):
						break
					var id := str(p["id"])
					ground.append(_for_slot(p, role))
					used[id] = true
					have += 1
			else:
				for key in ["role", "role2"]:
					for p in pool:
						if have >= int(slot[1]):
							break
						var id := str(p["id"])
						if used.has(id) or int(tier.get(id, 0)) != pass_tier:
							continue
						if (str(p.get("role", "")) == role) if key == "role" else second_positions(p).has(role):
							ground.append(_for_slot(p, role))
							used[id] = true
							have += 1
			for p in (by_ruck(pool) if role == "RUCK" else pool):
				if have >= int(slot[1]):
					break
				var id := str(p["id"])
				if used.has(id) or int(tier.get(id, 0)) != pass_tier:
					continue
				ground.append(_for_slot(p, role))
				used[id] = true
				have += 1
	var bench: Array = []
	for id in selection.get("BENCH", []):
		if bench.size() >= bench_size:
			break
		if by_id.has(str(id)) and not used.has(str(id)):
			bench.append(by_id[str(id)])
			used[str(id)] = true
	for pass_tier in [0, 2]:
		for p in pool:
			if bench.size() >= bench_size:
				break
			var id := str(p["id"])
			if not used.has(id) and int(tier.get(id, 0)) == pass_tier:
				bench.append(p)
				used[id] = true
	Roles.mark_wings(ground, selection.get("WING", []))
	return {"ground": ground, "bench": bench}


## His rating playing `line`: his own rating in his own line, else what his
## attributes make him there.
static func line_rating(p: Dictionary, line: String) -> float:
	if str(p.get("role", "")) == line or (p.get("attr", {}) as Dictionary).is_empty():
		return float(p.get("overall", 0))
	return float(rate_overall(p["attr"], line, effective_games(p)))


## The merit pass of the auto-pick: in the midfield, back and forward lines,
## the best player left out who can play the line (a second position) takes
## the place of its weakest starter when he rates higher there. A promised
## starter keeps his place; the ruck slot, the dual ruck and the bench's line
## cover are untouched (the dropped starter goes back to the pool and can make
## the bench).
static func _merit_swaps(pool: Array, ground: Array, used: Dictionary, promised: Dictionary) -> void:
	var by_id := {}
	for p in pool:
		by_id[p["id"]] = p
	for line in ["MID", "DEF", "FWD"]:
		# Who is left out and can play the line, valued once (most lines have
		# nobody, and the line is skipped without rating anyone).
		var cands := {}
		for p in pool:
			if not used.has(p["id"]) and second_positions(p).has(line):
				cands[p["id"]] = line_rating(p, line) * Workload.selection_factor(p)
		if cands.is_empty():
			continue
		var starters := {}
		for g in ground:
			if str(g["role"]) == line and not promised.has(g["id"]) and by_id.has(g["id"]):
				var q: Dictionary = by_id[g["id"]]
				starters[g["id"]] = line_rating(q, line) * Workload.selection_factor(q)
		for guard in range(6):
			var weak := -1
			var weak_v := INF
			for i in range(ground.size()):
				var id = ground[i]["id"]
				if str(ground[i]["role"]) == line and starters.has(id) and float(starters[id]) < weak_v:
					weak_v = float(starters[id])
					weak = i
			if weak < 0:
				break
			var best = null
			var best_v := weak_v
			for id in cands:
				if not used.has(id) and float(cands[id]) > best_v:
					best_v = float(cands[id])
					best = id
			if best == null:
				break
			used.erase(ground[weak]["id"])
			starters.erase(ground[weak]["id"])
			ground[weak] = _for_slot(by_id[best], line)
			used[best] = true
			starters[best] = best_v


## Players ordered by ruck work, best first (ties by overall), for filling
## an empty ruck spot with the nearest thing to a ruckman.
static func by_ruck(players: Array) -> Array:
	var out := players.duplicate()
	out.sort_custom(func(a, b):
		var ra := float(a["attr"]["ruck"])
		var rb := float(b["attr"]["ruck"])
		if ra != rb:
			return ra > rb
		return int(a["overall"]) > int(b["overall"]))
	return out


## Copy so the match-day slot does not rewrite the list player's natural role.
static func _for_slot(p: Dictionary, slot: String) -> Dictionary:
	var copy := p.duplicate()
	copy["list_tag"] = role_tag(p)
	# His own position, kept through every re-slotting (a copy of a copy
	# would otherwise take the last slot as his position). Display only.
	copy["own_role"] = str(p.get("own_role", p.get("role", "")))
	copy["role"] = slot
	return copy
