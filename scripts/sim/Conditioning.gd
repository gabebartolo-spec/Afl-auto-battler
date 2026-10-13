class_name Conditioning
extends RefCounted
## Season conditioning (season fitness spec, director 2026-10-11). Each club
## runs a season plan; it shapes one club-level curve over the season, from
## -1 (building hard: heavier legs, more soft-tissue risk) to +1 (at its
## peak: fresher legs, fewer soft-tissue injuries). Steady is 0 every week,
## exactly the game as it was before this existed.
##
## The curve reaches a match only through the stamps GameState writes on each
## player for the week (Workload.cond_cap / drain_mult, Injuries.chance), so
## the finals edge of a well-timed peak is the side's legs and injury list,
## nothing else.
##
## Weeks: 0..23 are the home-and-away rounds (Season.round_index before the
## round is played), 24..28 the finals weeks (wildcard to Grand Final).
##
## The high-performance department (ClubBudget "high_performance") sets how
## high the peak goes and how precisely it lands: each season the real peak
## sits a seeded number of weeks early or late, wider for a cheaper
## department. The planned curve is what the club aims at; the actual curve
## is what it gets.

const PLANS := ["peak", "steady", "fast", "develop"]
const DEFAULT_PLAN := "steady"
const PLAN_LABEL := {
	"peak": "Peak for September",
	"steady": "Steady all year",
	"fast": "Fast start",
	"develop": "Develop and manage",
}

const FINALS_FIRST := 24
const LAST_WEEK := 28
## Where each plan aims its peak (week), and how wide the top is either side.
const PEAK_WEEK := {"peak": 26, "fast": 3}
const PLATEAU := 2
## Fall per week away from the plateau, and the floor while building.
const SLOPE := 0.12
const BUILD_FLOOR := -0.5
## Develop and manage: a steady small deficit (managed game time).
const DEVELOP_LEVEL := -0.3

## By high-performance level (Minimal, Standard, Strong, Elite): how much of
## the full peak height the department reaches, and the spread (weeks) of
## where it actually lands.
const PEAK_HEIGHT := [0.6, 0.8, 0.9, 1.0]
const TIMING_SD := [4.0, 3.0, 2.0, 1.0]

## Revising the plan late costs part of the build: the new peak's height is
## scaled by the weeks left before it over this many (a pre-season choice
## gets all of it).
const BUILD_LEAD := 20.0

## How the curve reaches a match, sized from the Step 0 sensitivity audit
## (tools/audit/conditioning_impl.gd sens; paired matches, every home player
## stamped, n=1500 an arm): tiring x1.15 cost 2.30 +- 0.96 points a match,
## 4 legs off the cap 3.13 +- 0.99, 12 off 5.00 +- 1.06; injury risk x1.25
## added 0.18 +- 0.03 injuries a match. At the peak (c = 1) a side tires 15%
## slower; building hard (c = -0.5) it tires 7.5% faster with 2 legs off the
## cap. See docs/research/SEASON_FITNESS_AUDIT.md.
const DRAIN_K := 0.15        # tiring rate x(1 - DRAIN_K * c)
const CAP_K := 4.0           # legs off the energy cap at c = -1
## At a peak (c > 0) the cap gets back up to RESTORE_K legs that the season's
## workload took off it (Workload.energy_cap never goes above 100), so the
## upside shows where it matters: in loaded legs late in the season.
const RESTORE_K := 8.0
const INJURY_K := 0.25       # soft-tissue risk x(1 - INJURY_K * c)
## Develop and manage: extra development XP for players 22 and under.
const DEVELOP_XP := 0.15


static func valid_plan(plan: String) -> bool:
	return PLANS.has(plan)


## A fresh season's record for one club: the plan chosen at week 0 and this
## season's timing offset (seeded, so a reload replays it).
static func new_season(plan: String, year: int, club: String, hp_level: int, seed: int) -> Dictionary:
	return {"year": year, "changes": [[0, plan if valid_plan(plan) else DEFAULT_PLAN]],
		"offset": timing_offset(year, club, hp_level, seed)}


static func timing_offset(year: int, club: String, hp_level: int, seed: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["conditioning", seed, year, club])
	var sd := float(TIMING_SD[ClubBudget.clamp_level(hp_level)])
	return clampi(roundi(rng.randfn(0.0, sd)), -roundi(2.0 * sd), roundi(2.0 * sd))


## The plan in force at week `w`.
static func plan_at(rec: Dictionary, w: int) -> String:
	var plan := DEFAULT_PLAN
	for ch in rec.get("changes", []):
		if int(ch[0]) <= w:
			plan = str(ch[1])
	return plan


## The week the plan in force at `w` was chosen.
static func chosen_at(rec: Dictionary, w: int) -> int:
	var at := 0
	for ch in rec.get("changes", []):
		if int(ch[0]) <= w:
			at = int(ch[0])
	return at


## Record a plan change from week `w` on. Returns the updated record.
static func revise(rec: Dictionary, w: int, plan: String) -> Dictionary:
	if not valid_plan(plan):
		return rec
	var out := rec.duplicate(true)
	var changes: Array = out.get("changes", [])
	changes = changes.filter(func(ch): return int(ch[0]) < w)
	# Keeping the plan already in force restarts nothing: only a real change
	# costs part of the build.
	if changes.is_empty() or str(changes[changes.size() - 1][1]) != plan:
		changes.append([w, plan])
	out["changes"] = changes
	return out


## A plan's shape on its own: what the club aims at, before the department's
## height and timing.
static func shape(plan: String, w: int, peak_w: int) -> float:
	if plan == "develop":
		return DEVELOP_LEVEL
	if not PEAK_WEEK.has(plan):
		return 0.0
	var away := maxi(0, absi(w - peak_w) - PLATEAU)
	return maxf(BUILD_FLOOR, 1.0 - SLOPE * float(away))


## The planned curve at week `w`: the plan in force, at full height, on time,
## scaled for a late change.
static func planned(rec: Dictionary, w: int) -> float:
	return _value(rec, w, 0, 1.0)


## The actual curve at week `w`: the department's height and this season's
## timing offset.
static func actual(rec: Dictionary, w: int, hp_level: int) -> float:
	return _value(rec, w, int(rec.get("offset", 0)), float(PEAK_HEIGHT[ClubBudget.clamp_level(hp_level)]))


static func _value(rec: Dictionary, w: int, offset: int, height: float) -> float:
	var plan := plan_at(rec, w)
	if not PEAK_WEEK.has(plan):
		return shape(plan, w, 0)
	var peak_w := int(PEAK_WEEK[plan])
	var c := shape(plan, w, peak_w + offset)
	if c > 0.0:
		c *= height * build_share(peak_w, chosen_at(rec, w))
	return c


## The share of a peak's height a plan chosen at week `from` can still build.
static func build_share(peak_w: int, from: int) -> float:
	if from <= 0:
		return 1.0
	return clampf(float(peak_w - from) / BUILD_LEAD, 0.0, 1.0)


## What the curve does to one player this week. Empty for a neutral week, so
## an unstamped player is exactly the pre-conditioning game.
## Develop and manage holds players short of their best legs, but managed
## loads are the point of it: its soft-tissue risk goes down, not up.
static func stamps(c: float, plan := "") -> Dictionary:
	if is_zero_approx(c):
		return {}
	var injury := 1.0 - INJURY_K * c
	if plan == "develop":
		injury = 1.0 + INJURY_K * c
	return {
		"cond_drain": 1.0 - DRAIN_K * c,
		"cond_cap": CAP_K * maxf(0.0, -c) - RESTORE_K * maxf(0.0, c),
		"cond_injury": injury,
	}


const STAMP_KEYS := ["cond_drain", "cond_cap", "cond_injury"]


static func stamp_list(list: Array, c: float, plan := "") -> void:
	var st := stamps(c, plan)
	for p in list:
		for k in STAMP_KEYS:
			p.erase(k)
		for k in st:
			p[k] = st[k]


## Development XP multiplier for a player under a plan.
static func xp_mult(plan: String, p: Dictionary) -> float:
	if plan == "develop" and float(p.get("age", 25.0)) <= ClubBudget.YOUNG_AGE:
		return 1.0 + DEVELOP_XP
	return 1.0


## Develop and manage also lifts a young player's season training ceiling a
## point (the size of a good teacher's step): extra XP alone would sit unused
## once he reaches the ordinary ceiling. Only a season of it earns the point:
## the plan must have run since the pre-season or the club's bye (`bye_w`),
## so a switch to Develop in the last month buys no extra room.
static func ceiling_step(rec: Dictionary, w: int, bye_w: int, p: Dictionary) -> int:
	var plan := plan_at(rec, w)
	if xp_mult(plan, p) <= 1.0:
		return 0
	return 1 if chosen_at(rec, w) <= maxi(0, bye_w) else 0


## What an AI club runs, from where it is in its cycle (TradeValue.phase):
## contenders peak for September, rebuilders develop, the rest stay steady.
static func ai_plan(phase: String) -> String:
	if phase == "contending":
		return "peak"
	if phase == "rebuilding":
		return "develop"
	return "steady"


## The weeks a coach may revise the plan: the pre-season (week 0), the club's
## bye, round 14 (week 13) and the last month (week 20).
const ROUND_14 := 13
const LAST_MONTH := 20


static func revision_weeks(bye_w: int) -> Array:
	var out := [0, ROUND_14, LAST_MONTH]
	if bye_w > 0 and not out.has(bye_w):
		out.append(bye_w)
	out.sort()
	return out


# ---------------------------------------------------------------------------
# In words (the plan screens): football words, no percentages.
# ---------------------------------------------------------------------------
## Where each month starts, in weeks (the first rounds are March; the finals
## are September).
const MONTH_STARTS := [[0, "March"], [3, "April"], [7, "May"], [11, "June"],
		[15, "July"], [19, "August"], [24, "September"]]


static func month_of_week(w: int) -> String:
	var name := "March"
	for m in MONTH_STARTS:
		if w >= int(m[0]):
			name = str(m[1])
	return name


## The week the plan in force at `w` really peaks (its aim and this season's
## timing), or -1 for a plan with no peak.
static func peak_week(rec: Dictionary, w: int) -> int:
	var plan := plan_at(rec, w)
	if not PEAK_WEEK.has(plan):
		return -1
	return int(PEAK_WEEK[plan]) + int(rec.get("offset", 0))


## Where the club stands, in a line: "Building, peak due in August".
static func status_words(rec: Dictionary, w: int) -> String:
	var plan := plan_at(rec, w)
	if plan == "develop":
		return "Managing loads, developing the young players"
	var pw := peak_week(rec, w)
	if pw < 0:
		return "Steady, no peak planned"
	if w > pw + PLATEAU:
		return "Peak is behind you"
	if w >= pw - PLATEAU:
		return "Peaking now"
	var c := shape(plan, w, pw)
	var when := "peak due in %s" % month_of_week(pw)
	return ("Building, " if c <= 0.0 else "Coming into form, ") + when


## What a coach may do at a revision week, said as when it is.
static func revision_name(w: int, bye_w: int) -> String:
	if w == 0:
		return "the pre-season"
	if w == bye_w:
		return "the bye"
	if w == ROUND_14:
		return "round 14"
	return "the last month"


## When the plan can next be changed after week `w` ("" when there is no
## chance left): "round 14", "the last month".
static func next_revision_name(w: int, bye_w: int) -> String:
	for rw in revision_weeks(bye_w):
		if int(rw) > w:
			return revision_name(int(rw), bye_w)
	return ""


## What choosing `plan` at week `w` costs, if it costs anything, in a line.
static func late_cost(plan: String, w: int, bye_w: int) -> String:
	if w <= 0:
		return ""
	if PEAK_WEEK.has(plan):
		var share := build_share(int(PEAK_WEEK[plan]), w)
		if share <= 0.0:
			return "Too late to build a peak this year."
		return "Changing now leaves less time to build, so the peak comes lower."
	if plan == "develop" and w > maxi(0, bye_w):
		return "A season of it earns the young players their extra room. From now it only speeds their development."
	return ""


## What each plan does, for the picker: how the legs and the list are
## treated, nothing hidden.
const PLAN_EFFECT := {
	"peak": "Heavy legs through the home-and-away rounds, fresh ones for September. A little more soft-tissue risk while building, less at the peak.",
	"steady": "The same load every week. No build and no peak.",
	"fast": "Fresh legs in the opening rounds, heavier from winter on and again in September.",
	"develop": "Loads managed all year so the young players get the minutes. Results suffer a little. Players 22 and under develop faster and have a little more room to grow this season.",
}
