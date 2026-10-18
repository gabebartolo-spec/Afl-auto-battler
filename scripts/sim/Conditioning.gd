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
## Develop and manage: extra development XP for players 22 and under, and the
## points of extra season room a season of it earns them (ceiling_step).
const DEVELOP_XP := 0.15
const DEVELOP_CEILING := 1


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
		c *= height * build_share(peak_w, chosen_at(rec, w)) * base_peak_share(rec)
	return c


# ---------------------------------------------------------------------------
# The fitness base (PreSeason.gd): the one value the pre-season hands over,
# written on the season's record at Round 1 as "base": thin / sound / strong.
# No base on the record is sound, which is exactly the game without one.
# ---------------------------------------------------------------------------
static func base_of(rec: Dictionary) -> String:
	# With the pre-season switched off (Features) a base already on a record
	# is left there and not read: the season plays as it did before bases.
	if not Features.on("preseason"):
		return PreSeason.DEFAULT_BASE
	var b := str(rec.get("base", PreSeason.DEFAULT_BASE))
	return b if PreSeason.BASES.has(b) else PreSeason.DEFAULT_BASE


## The share of a planned peak's height the base lets the side reach (the
## coach's share of it; the department's is PEAK_HEIGHT).
static func base_peak_share(rec: Dictionary) -> float:
	match base_of(rec):
		"thin":
			return float(PreSeason.tune("thin_peak_share"))
		"strong":
			return float(PreSeason.tune("strong_peak_share"))
	return 1.0


## The base's own part of the curve at week `w`: a thin base leaves the side
## underdone early, a strong one holds the legs a little longer, both fading
## to nothing over the first rounds. 0 for a sound base, every week.
static func base_curve(rec: Dictionary, w: int) -> float:
	var size := 0.0
	var span := 0.0
	match base_of(rec):
		"thin":
			size = -float(PreSeason.tune("thin_early"))
			span = float(PreSeason.tune("thin_weeks"))
		"strong":
			size = float(PreSeason.tune("strong_early"))
			span = float(PreSeason.tune("strong_weeks"))
	if span <= 0.0 or w < 0 or float(w) >= span:
		return 0.0
	return size * (1.0 - float(w) / span)


## The legs the side really has at week `w`: the plan's curve and the base's.
static func legs(rec: Dictionary, w: int, hp_level: int) -> float:
	return actual(rec, w, hp_level) + base_curve(rec, w)


## The share of a peak's height a plan chosen at week `from` can still build.
static func build_share(peak_w: int, from: int) -> float:
	if from <= 0:
		return 1.0
	return clampf(float(peak_w - from) / BUILD_LEAD, 0.0, 1.0)


## What the curve does to one player this week. Empty for a neutral week, so
## an unstamped player is exactly the pre-conditioning game.
## Develop and manage holds players short of their best legs, but managed
## loads are the point of it: its soft-tissue risk goes down, not up.
## `base` is the fitness base's part of the curve this week (base_curve): it
## moves the legs with the plan's, and soft-tissue risk in its own direction
## whatever the plan (an underdone side is at more risk, even a managed one).
static func stamps(c: float, plan := "", base := 0.0) -> Dictionary:
	if is_zero_approx(c) and is_zero_approx(base):
		return {}
	var injury := 1.0 - INJURY_K * c
	if plan == "develop":
		injury = 1.0 + INJURY_K * c
	var t := c
	if not is_zero_approx(base):
		injury *= 1.0 - INJURY_K * base
		t = c + base
	return {
		"cond_drain": 1.0 - DRAIN_K * t,
		"cond_cap": CAP_K * maxf(0.0, -t) - RESTORE_K * maxf(0.0, t),
		"cond_injury": injury,
	}


const STAMP_KEYS := ["cond_drain", "cond_cap", "cond_injury"]


static func stamp_list(list: Array, c: float, plan := "", base := 0.0) -> void:
	var st := stamps(c, plan, base)
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
	return DEVELOP_CEILING if chosen_at(rec, w) <= maxi(0, bye_w) else 0


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
# In words (the plan screens): the season line in football words; each plan
# and the department with their sizes and odds as percentages (plan_effect).
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


## The same line with the pre-season's base in it, while the base still does
## something: "Building, peak due in August, on a thin base". A strong base
## is named only for the rounds it holds the legs; a thin one all season,
## because the lower peak it leaves lasts. A sound base is never named.
static func status_line(rec: Dictionary, w: int) -> String:
	var words := status_words(rec, w)
	var b := base_of(rec)
	if b == PreSeason.DEFAULT_BASE:
		return words
	if is_zero_approx(base_curve(rec, w)) and is_equal_approx(base_peak_share(rec), 1.0):
		return words
	return "%s, on a %s base" % [words, b]


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


## What each plan does, for the picker (bible §4, director 2026-10-18: every
## option says what it does for you and what it costs, with the size and the
## odds, as percentages, never which is better). Every figure is worked out
## here from the constants the curve and the stamps use, at the club's
## high-performance level, so the words cannot drift from the rules. The
## templates carry no figure of their own (tests/test_fitness.gd checks).
const PLAN_UP_PEAK := "Upside: at its best in %s the side tires %s slower, has %s fewer soft-tissue injuries and up to %s more in the legs."
const PLAN_DOWN_PEAK := "Downside: building through to %s it tires %s faster, has %s less in the legs and %s more soft-tissue injuries."
const PLAN_UP_FAST := "Upside: at its best in %s the side tires %s slower and has %s fewer soft-tissue injuries."
const PLAN_DOWN_FAST := "Downside: from %s on, and through September, it tires up to %s faster, has up to %s less in the legs and up to %s more soft-tissue injuries."
const PLAN_ODDS := "Odds: the peak lands within %d weeks of plan about %s of the time; otherwise it comes early or late."
const PLAN_ODDS_SURE := "Odds: the peak lands within %d weeks of plan every season."
const PLAN_UP_STEADY := "Upside: the same legs every week, with no heavy weeks and no extra soft-tissue risk."
const PLAN_DOWN_STEADY := "Downside: no peak, so the side is no fresher in September than in March."
const PLAN_UP_DEVELOP := "Upside: players %d and under earn %s more development XP, and with the plan on since the bye they have %d more %s of room to grow this season. %s fewer soft-tissue injuries all year."
const PLAN_DOWN_DEVELOP := "Downside: all year the side tires %s faster and has %s less in the legs."


## A share as a percentage, as the plan screens say it: "12%", "7.5%".
static func pct(share: float) -> String:
	var v := share * 100.0
	if absf(v - roundf(v)) < 0.05:
		return "%d%%" % roundi(v)
	return "%.1f%%" % v


## Legs, which run 0 to 100: "6%".
static func legs_pct(legs: float) -> String:
	return "%d%%" % roundi(legs)


## The share of seasons the peak lands within the plateau (PLATEAU weeks
## either side of the plan), for a department level: from the very draw
## timing_offset makes (a normal spread of TIMING_SD weeks, rounded to a week
## and held within two spreads). Certain when the hold is inside the plateau.
static func on_time_share(hp_level: int) -> float:
	var sd := float(TIMING_SD[ClubBudget.clamp_level(hp_level)])
	if PLATEAU >= roundi(2.0 * sd):
		return 1.0
	# A draw x rounds to within PLATEAU weeks when |x| < PLATEAU + 0.5.
	return _erf((float(PLATEAU) + 0.5) / (sd * sqrt(2.0)))


## The error function (Abramowitz and Stegun 7.1.26, good to 1.5e-7).
static func _erf(x: float) -> float:
	var sgn := 1.0 if x >= 0.0 else -1.0
	var a := absf(x)
	var t := 1.0 / (1.0 + 0.3275911 * a)
	var poly := ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t
	return sgn * (1.0 - poly * exp(-a * a))


## The timing odds as a percentage, or "" when the peak always lands on time.
static func on_time_pct(hp_level: int) -> String:
	var share := on_time_share(hp_level)
	return "" if share >= 1.0 else "%d%%" % roundi(share * 100.0)


## The timing odds in a line, for a department level.
static func odds_words(hp_level: int) -> String:
	var p := on_time_pct(hp_level)
	if p == "":
		return PLAN_ODDS_SURE % PLATEAU
	return PLAN_ODDS % [PLATEAU, p]


## The months a peak aimed at `peak_w` sits at its best: "September",
## "March and April".
static func _best_months(peak_w: int) -> String:
	var a := month_of_week(maxi(0, peak_w - PLATEAU))
	var b := month_of_week(mini(LAST_WEEK, peak_w + PLATEAU))
	return a if a == b else "%s and %s" % [a, b]


## What `plan` does at a department level: its upside, its downside and, for a
## plan with a peak, the odds it lands on time, one line each.
static func plan_effect(plan: String, hp_level: int) -> String:
	var h := float(PEAK_HEIGHT[ClubBudget.clamp_level(hp_level)])
	var b := -BUILD_FLOOR
	var lines: PackedStringArray = []
	match plan:
		"peak":
			var pw := int(PEAK_WEEK["peak"])
			# The last week the side is still building at full depth.
			var deep := 0
			for w in range(pw + 1):
				if shape("peak", w, pw) <= BUILD_FLOOR:
					deep = w
			lines.append(PLAN_UP_PEAK % [_best_months(pw), pct(DRAIN_K * h), pct(INJURY_K * h), legs_pct(RESTORE_K * h)])
			lines.append(PLAN_DOWN_PEAK % [month_of_week(deep), pct(DRAIN_K * b), legs_pct(CAP_K * b), pct(INJURY_K * b)])
			lines.append(odds_words(hp_level))
		"fast":
			var fw := int(PEAK_WEEK["fast"])
			# The first week after the early peak that the side is heavier than steady.
			var heavy := LAST_WEEK
			for w in range(LAST_WEEK, fw, -1):
				if shape("fast", w, fw) < 0.0:
					heavy = w
			lines.append(PLAN_UP_FAST % [_best_months(fw), pct(DRAIN_K * h), pct(INJURY_K * h)])
			lines.append(PLAN_DOWN_FAST % [month_of_week(heavy), pct(DRAIN_K * b), legs_pct(CAP_K * b), pct(INJURY_K * b)])
			lines.append(odds_words(hp_level))
		"steady":
			lines.append(PLAN_UP_STEADY)
			lines.append(PLAN_DOWN_STEADY)
		"develop":
			var d := -DEVELOP_LEVEL
			# The age cut is the one xp_mult uses (ClubBudget.YOUNG_AGE).
			lines.append(PLAN_UP_DEVELOP % [int(ClubBudget.YOUNG_AGE), pct(DEVELOP_XP), DEVELOP_CEILING, "point" if DEVELOP_CEILING == 1 else "points",
					pct(INJURY_K * d)])
			lines.append(PLAN_DOWN_DEVELOP % [pct(DRAIN_K * d), legs_pct(CAP_K * d)])
	return "\n".join(lines)


## What the high-performance department does at a level (the Club budget):
## how fast legs recover, how high a planned peak goes and how often it lands
## on time, and what the level costs against Standard.
const HP_RECOVERY_UP := "Legs recover %s faster each week than at Standard."
const HP_RECOVERY_DOWN := "Legs recover %s slower each week than at Standard."
const HP_RECOVERY_EVEN := "Legs recover at the normal rate."
const HP_PEAK := "A planned peak reaches %s of its full height and lands within %d weeks of plan %s."
const HP_ODDS := "about %s of the time"
const HP_ODDS_SURE := "every season"
const HP_COST_MORE := "Costs %s more than Standard, taken from the other departments."
const HP_COST_LESS := "Frees %s for the other departments."
const HP_COST_EVEN := "Costs %s, an even share of the budget."


static func department_words(hp_level: int) -> String:
	var level := ClubBudget.clamp_level(hp_level)
	var r := ClubBudget.recovery_mult(level) - 1.0
	var recovery := HP_RECOVERY_EVEN
	if r > 0.0001:
		recovery = HP_RECOVERY_UP % pct(r)
	elif r < -0.0001:
		recovery = HP_RECOVERY_DOWN % pct(-r)
	var p := on_time_pct(level)
	var odds := HP_ODDS_SURE if p == "" else HP_ODDS % p
	var peak := HP_PEAK % [pct(float(PEAK_HEIGHT[level])), PLATEAU, odds]
	var diff := ClubBudget.cost_m(level) - ClubBudget.cost_m(ClubBudget.STANDARD)
	var cost := HP_COST_EVEN % ("$%.1fm" % ClubBudget.cost_m(level))
	if diff > 0.001:
		cost = HP_COST_MORE % ("$%.1fm" % diff)
	elif diff < -0.001:
		cost = HP_COST_LESS % ("$%.1fm" % -diff)
	return "%s %s %s" % [recovery, peak, cost]


## The plan sheet's department line: whose level the sizes and odds above are for.
const PLAN_DEPARTMENT := "Sizes and odds are for your %s high-performance department: a planned peak reaches %s of its full height."


static func department_line(hp_level: int) -> String:
	var level := ClubBudget.clamp_level(hp_level)
	return PLAN_DEPARTMENT % [ClubBudget.level_label(level), pct(float(PEAK_HEIGHT[level]))]
