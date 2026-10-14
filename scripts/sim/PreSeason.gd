class_name PreSeason
extends RefCounted
## The pre-season (director, 2026-10-13): eight weeks between the off-season
## wrap and Round 1, planned in three blocks (weeks 1-3, 4-5, 6-7) with a
## quiet week 8. Each block has a training load and a focus.
##
## It adds no system of its own. Running work becomes one word on the club's
## season fitness record (Conditioning: thin / sound / strong); skills work is
## development XP spent by each player's training plan inside the season's
## training limit; a heavy or light last block is the existing heavy-legs or
## fresh week for Round 1. Every club runs it by these rules.
##
## The rules only: no state of the career, no clock. Every size is in
## data/preseason.json (the director's balance call). The only dice are the
## time trial's, from their own seed (trial_seed), so the pre-season never
## moves a match, a draft or a story card.
##
## The game-plan focus drills plans (plan familiarity, at the foot of this
## file). Seams left for later slices: the stops after blocks 2 and 3 (STOPS),
## cards and the papers.

const DATA_PATH := "res://data/preseason.json"
## The same sizes, should the file be missing from a build.
const DEFAULTS := {
	"weeks": 8,
	"blocks": [[1, 3], [4, 5], [6, 7]],
	"loads": ["light", "solid", "heavy"],
	"focuses": ["running", "skills", "plan"],
	"load_work": {"light": 0.5, "solid": 1.0, "heavy": 1.5},
	"focus_share": 1.0,
	"other_share": 0.5,
	"skills_week_xp": 8,
	"base_thin_below": 4.5,
	"base_strong_from": 6.0,
	"thin_early": 0.25,
	"thin_weeks": 6,
	"thin_peak_share": 0.85,
	"strong_early": 0.15,
	"strong_weeks": 4,
	"strong_peak_share": 1.0,
	"trial_best": 5,
	"trial_worst": 3,
	"trial_noise": 6.0,
	"heavy_week_injury": 0.008,
	"soft_tissue_kinds": ["hamstring", "calf", "groin", "quad"],
	"ai_old_age": 28.0,
	"papers_claim_up": 4,
	"papers_breakout_age": 22.0,
	"papers_short_wins_pos": 14,
	"papers_after": 6,
	"papers_within": 22,
	"papers_places": 1,
	"intra_week": 5,
	"intra_side_size": 23,
	"intra_injury_rate": 0.5,
	"intra_xp_games": 1.0,
	"intra_seen_uncertainty": 0.7,
	"intra_spare_number": 60,
	"familiar_default": 1,
	"familiar_mult": {"well": 1.0, "partly": 0.95, "barely": 0.9},
	"drill_step_weeks": 2.0,
	"drill_max_plans": 2,
	"fade_rounds": 8,
	"ai_plan_block": {"contending": 2, "building": 2, "rebuilding": 1},
	"default_blocks": [["solid", "running"], ["solid", "skills"], ["solid", "skills"]],
	"ai_blocks": {
		"contending": [["heavy", "running"], ["solid", "running"], ["solid", "skills"]],
		"building": [["solid", "running"], ["heavy", "skills"], ["solid", "skills"]],
		"rebuilding": [["heavy", "skills"], ["solid", "skills"], ["solid", "running"]],
	},
}

const LOAD_LABEL := {"light": "Light", "solid": "Solid", "heavy": "Heavy"}
const FOCUS_LABEL := {"running": "Running", "skills": "Skills", "plan": "Game plan"}
const BASES := ["thin", "sound", "strong"]
const DEFAULT_BASE := "sound"
## The weeks after which the pre-season stops for the coach: {week: stop}.
## The time trial, then the intra-club match. The practice match against
## another club is a later slice: it takes the week after its own block here.
const STOPS := {3: "trial", 5: "intra", 8: "papers"}

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = null
		if FileAccess.file_exists(DATA_PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = DEFAULTS.duplicate(true)
		if parsed is Dictionary:
			for k in parsed:
				if DEFAULTS.has(k):
					_data[k] = parsed[k]
		# The scouting read's own copy of its size (DraftScouting cannot ask us).
		DraftScouting.seen_uncertainty = float(_data.get("intra_seen_uncertainty", 0.7))
	return _data


## Tests and audits change a size, then call this to go back to the file.
static func reload() -> void:
	_data = {}


static func tune(key: String) -> Variant:
	return data().get(key, DEFAULTS.get(key))


static func weeks() -> int:
	return int(tune("weeks"))


static func block_count() -> int:
	return (tune("blocks") as Array).size()


## [first week, last week] of block `i`.
static func block_weeks(i: int) -> Array:
	var b: Array = (tune("blocks") as Array)[i]
	return [int(b[0]), int(b[1])]


## The block training week `w` (1-based) belongs to, or -1 for a quiet week.
static func block_of_week(w: int) -> int:
	for i in range(block_count()):
		var b := block_weeks(i)
		if w >= int(b[0]) and w <= int(b[1]):
			return i
	return -1


static func is_last_block(i: int) -> bool:
	return i == block_count() - 1


static func loads() -> Array:
	return tune("loads")


static func focuses() -> Array:
	return tune("focuses")


static func valid_block(load: String, focus: String) -> bool:
	return loads().has(load) and focuses().has(focus)


static func _blocks(src: Variant) -> Array:
	var out := []
	var fallback: Array = DEFAULTS["default_blocks"]
	for i in range(block_count()):
		var b: Array = fallback[mini(i, fallback.size() - 1)]
		if src is Array and i < (src as Array).size() and (src as Array)[i] is Array 				and ((src as Array)[i] as Array).size() >= 2 				and valid_block(str((src as Array)[i][0]), str((src as Array)[i][1])):
			b = (src as Array)[i]
		var row := [str(b[0]), str(b[1])]
		if str(b[1]) == "plan":
			row.append(clean_drills(b[2] if b.size() > 2 else []))
		out.append(row)
	return out


## The plan a coach's pre-season opens on.
static func default_blocks() -> Array:
	return _blocks(tune("default_blocks"))


## What an AI club runs, from its own situation: where it is in its cycle
## (TradeValue.phase) sets the focus and where it pushes, and an older list
## (`best22_age` at or over ai_old_age) does not push at all: its Heavy blocks
## are Solid. The same loads, by the same rules and risks, as the coach's.
static func ai_blocks(phase: String, best22_age := 0.0) -> Array:
	var table: Dictionary = tune("ai_blocks")
	var out := _blocks(table.get(phase, table.get("building", [])))
	if best22_age >= float(tune("ai_old_age")):
		for b in out:
			if str(b[0]) == "heavy":
				b[0] = "solid"
	return out


## A fresh pre-season for `year`: `club_blocks` is club code -> its blocks.
static func new_state(year: int, club_blocks: Dictionary) -> Dictionary:
	var clubs := {}
	for code in club_blocks:
		clubs[str(code)] = {"blocks": _blocks(club_blocks[code]), "run": 0.0}
	return {"year": year, "week": 0, "clubs": clubs, "trial": {}, "trial_seen": false, "done": false,
			"injuries": []}


## A week's work in one area ("running" or "skills") under a block's load and
## focus: 1.0 is a full Solid week on it.
static func work(load: String, focus: String, area: String) -> float:
	var share := float(tune("focus_share")) if focus == area else float(tune("other_share"))
	return float((tune("load_work") as Dictionary).get(load, 1.0)) * share


## Development XP a fit player earns from one week of the block, before his
## club's teachers and departments (the same multipliers a match's XP gets).
static func week_xp(load: String, focus: String) -> int:
	return int(round(float(tune("skills_week_xp")) * work(load, focus, "skills")))


## The weeks of running work a whole plan adds up to.
static func planned_run(blocks: Array) -> float:
	var run := 0.0
	for w in range(1, weeks() + 1):
		var i := block_of_week(w)
		if i >= 0 and i < blocks.size():
			run += work(str(blocks[i][0]), str(blocks[i][1]), "running")
	return run


## The fitness base that much running work gives: thin / sound / strong.
static func base_band(run: float) -> String:
	if run < float(tune("base_thin_below")):
		return "thin"
	if run >= float(tune("base_strong_from")):
		return "strong"
	return "sound"


## The week flag a club's players carry into Round 1 from the last block's
## load: the existing heavy-legs or fresh week (ClubLife), or "" for Solid.
static func round_one_flag(blocks: Array) -> String:
	if blocks.is_empty():
		return ""
	match str(blocks[blocks.size() - 1][0]):
		"heavy":
			return "heavy_legs"
		"light":
			return "fresh"
	return ""


static func injury_seed(career_seed: int, year: int, club: String, id: String, week: int) -> int:
	return hash(["preseason", "injury", career_seed, year, club, id, week])


## A Heavy training week's risk for one player: {} or {"weeks", "kind"}, a
## soft-tissue injury of the game's usual lengths (Injuries.SEVERITY). His
## durability moves the chance as it moves a match injury. The roll is his
## own for that week (injury_seed), so a reload replays it and nobody else's
## dice move. Light and Solid weeks carry no risk.
static func training_injury(p: Dictionary, load: String, career_seed: int, year: int,
		club: String, week: int) -> Dictionary:
	var base := float(tune("heavy_week_injury")) if load == "heavy" else 0.0
	if base <= 0.0 or int(p.get("injury_weeks", 0)) > 0:
		return {}
	var dur := float((p.get("attr", {}) as Dictionary).get("durability", 50))
	var rng := RandomNumberGenerator.new()
	rng.seed = injury_seed(career_seed, year, club, str(p["id"]), week)
	if rng.randf() >= base * clampf(1.5 - dur / 100.0, 0.5, 1.3):
		return {}
	var kinds: Array = tune("soft_tissue_kinds")
	if kinds.is_empty():
		return {}
	return {"weeks": Injuries._severity(rng), "kind": str(kinds[rng.randi_range(0, kinds.size() - 1)])}


# ---------------------------------------------------------------------------
# The intra-club match (director, 2026-10-14): two sides of the club's own
# list, with prospects from the coming National Draft filling the spots.
# ---------------------------------------------------------------------------
const INTRA_MODES := ["even", "best"]
const INTRA_MODE_LABEL := {"even": "Even sides", "best": "Best side v the rest"}
## What each way of picking the sides gains and costs, as it plays out.
const INTRA_GAIN := {
	"even": "Two sides matched on rating, so every player and prospect gets a fair test.",
	"best": "You coach your best 23 as one side, and every prospect is tested against them.",
}
const INTRA_COST := {
	"even": "Your best 23 are split across the two sides.",
	"best": "The rest of the list and the prospects are up against it, and may see little of the ball.",
}


static func intra_week() -> int:
	return int(tune("intra_week"))


static func intra_seed(career_seed: int, year: int, club: String) -> int:
	return hash(["preseason", "intra", career_seed, year, club])


## How many prospects the two sides need: two full sides, less the listed
## players fit to play, and never more than there are prospects.
static func invites_needed(fit_listed: int, prospects: int) -> int:
	return clampi(2 * int(tune("intra_side_size")) - fit_listed, 0, prospects)


## The two sides: [first, second], arrays of players. `listed` are the fit
## listed players, best first; `guests` the invited prospects (copies), best
## first. "best": the best side_size listed players are the first side, and
## everyone else and every guest the second. "even": the listed players are
## dealt alternately, then the guests, the first to whichever side is short.
static func intra_sides(listed: Array, guests: Array, mode: String) -> Array:
	var size := int(tune("intra_side_size"))
	var first := []
	var second := []
	if mode == "best":
		for i in range(listed.size()):
			(first if i < size else second).append(listed[i])
		for g in guests:
			(second if second.size() < size or first.size() >= size else first).append(g)
		return [first, second]
	for i in range(listed.size()):
		(first if i % 2 == 0 else second).append(listed[i])
	for g in guests:
		(first if first.size() <= second.size() else second).append(g)
	return [first, second]


## A prospect as he plays on the day: a copy with a spare jumper number, who
## cannot be hurt. Nothing done to it reaches the draft pool.
static func intra_guest(p: Dictionary, number: int, club: String) -> Dictionary:
	var g := p.duplicate(true)
	g["num"] = number
	g["club"] = club
	g["guest"] = true
	g["cond_injury"] = 0.0
	g.erase("injury_weeks")
	g.erase("injury_kind")
	return g


## What a recruiter would say he saw of a prospect, from what he did in the
## match: one line, the fact first.
static func prospect_line(stats: Dictionary) -> String:
	var g := int(stats.get("goals", 0))
	var d := int(stats.get("disposals", 0))
	var m := int(stats.get("marks", 0))
	var t := int(stats.get("tackles", 0))
	var h := int(stats.get("hitouts", 0))
	if g >= 3:
		return "Kicked %d goals against senior defenders." % g
	if d >= 22:
		return "Won plenty of the ball: %d disposals against senior bodies." % d
	if h >= 15:
		return "Held his own in the ruck: %d hit-outs." % h
	if m >= 7:
		return "Marked strongly: %d marks." % m
	if t >= 6:
		return "Tackled hard: %d tackles." % t
	if g >= 1:
		return "Kicked %s and had %d disposals." % ["a goal" if g == 1 else "%d goals" % g, d]
	if d >= 12:
		return "Found the ball %d times against senior bodies." % d
	if d >= 1:
		return "Had a quiet day against senior bodies: %d disposals." % d
	return "Saw almost nothing of the ball."


## The note on a prospect's draft card, or "" if `club` has not seen him.
static func seen_line(p: Dictionary, club: String) -> String:
	var seen: Dictionary = (p.get("seen", {}) as Dictionary).get(club, {}) if p.get("seen") is Dictionary else {}
	if seen.is_empty():
		return ""
	return "Seen in your %d intra-club match. %s" % [int(seen.get("year", 0)), str(seen.get("line", ""))]


## How much narrower `club`'s rating read on a prospect is for having seen
## him play (1.0: not seen, or the pre-season switched off). The rule lives
## with the scouting it changes (DraftScouting.seen_mult).
static func seen_mult(p: Dictionary, club: String) -> float:
	data()
	return DraftScouting.seen_mult(p, club)


static func trial_seed(career_seed: int, year: int, club: String, id: String) -> int:
	return hash(["preseason", "trial", career_seed, year, club, id])


## The two-kilometre time trial: the list's running fitness (durability, the
## rating the match uses for it) and the day's form. An injured player sits
## it out. Returns {"best": [ids, fastest first], "worst": [ids, last man
## last]}; nobody is in both.
static func trial(list: Array, career_seed: int, year: int, club: String) -> Dictionary:
	var rows := []
	var rng := RandomNumberGenerator.new()
	for p in list:
		if int(p.get("injury_weeks", 0)) > 0:
			continue
		var id := str(p["id"])
		rng.seed = trial_seed(career_seed, year, club, id)
		rows.append({"id": id, "v": float((p.get("attr", {}) as Dictionary).get("durability", 0))
				+ rng.randfn(0.0, float(tune("trial_noise")))})
	rows.sort_custom(_faster)
	var ids: Array = rows.map(func(r): return str(r["id"]))
	var n := mini(int(tune("trial_best")), ids.size())
	var m := mini(int(tune("trial_worst")), ids.size() - n)
	return {"best": ids.slice(0, n), "worst": ids.slice(ids.size() - m, ids.size())}


## Ties go to the id, so the same list gives the same order.
static func _faster(a: Dictionary, b: Dictionary) -> bool:
	if float(a["v"]) != float(b["v"]):
		return float(a["v"]) > float(b["v"])
	return str(a["id"]) < str(b["id"])


# ---------------------------------------------------------------------------
# In words (the plan screen): what each choice gains and costs, nothing hidden.
# ---------------------------------------------------------------------------
## "Weeks 1 to 3".
static func block_title(i: int) -> String:
	var b := block_weeks(i)
	return "Weeks %d to %d" % [int(b[0]), int(b[1])] if int(b[0]) != int(b[1]) else "Week %d" % int(b[0])


## What a block's load and focus gain, in a coach's words. The sizes behind
## them are in the data (the focus gets a full share of the week, the other
## area half of one; Heavy is half as much again of both, Light half of both),
## and each line says only what is true of them.
const _GAIN := {
	"running": {
		"solid": "Running first, for the fitness base. Skills work gets half the time.",
		"heavy": "A bigger fitness base than a Solid block builds, and more skills work too.",
	},
	"skills": {
		"solid": "Skills first, so every fit player develops. Running gets half the time.",
		"heavy": "More development than a Solid block gives, and more running too.",
	},
}


## What block `i`'s load and focus gain. `plans` are the plans a Game plan
## block drills.
static func gain_line(load: String, focus: String, i: int, plans := []) -> String:
	if focus == "plan":
		var drill := drill_sentence(plans)
		match load:
			"light":
				return "%s %s" % [gain_line("light", "running", i), drill]
			"heavy":
				return "%s More running and skills work than a Solid block on the plan." % drill
		return drill
	if load == "light":
		if is_last_block(i):
			return "Fresh legs and less soft-tissue risk in Round 1."
		return "An easier time on the track. Nothing carries to Round 1."
	return str((_GAIN.get(focus, {}) as Dictionary).get(load, ""))


## What it costs, or "" when it costs nothing (a Solid block).
static func cost_line(load: String, focus: String, i: int) -> String:
	var line := ""
	match load:
		"light":
			line = "Half the running and half the skills work of a Solid block."
			if focus == "plan":
				line = "Half the running and skills work of a Solid block on the plan."
		"heavy":
			if is_last_block(i):
				line = "A risk of soft-tissue injuries in these weeks, and sore legs in Round 1."
			else:
				line = "A risk of soft-tissue injuries in these weeks."
	if focus == "plan" and load != "light":
		var share := "Running and skills work both get half the time."
		line = share if line == "" else "%s %s" % [line, share]
	return line


const BASE_LABEL := {"thin": "a thin fitness base", "sound": "a sound fitness base", "strong": "a strong fitness base"}
const BASE_EFFECT := {
	"thin": "The side starts underdone: it tires sooner and carries more soft-tissue risk for the first six rounds. A planned peak comes lower.",
	"sound": "The side starts Round 1 at its usual fitness: no early lift, nothing lost.",
	"strong": "Fresher legs and a little less soft-tissue risk through the first month.",
}


# ---------------------------------------------------------------------------
# Plan familiarity (director, 2026-10-13: "Drill a plan, it works better",
# shown as "Plan fluency: high / medium / low"). A side knows each
# game plan at one of three levels. Drilling a plan in the pre-season moves it
# up a step; every plan slips a step over the off-season; a plan not played
# fades a step slowly through the year. A plan known less than well gives
# less of its upside in the match (MatchSim._pv); what a plan gives up does
# not change. Balanced is the base game and is always known well.
# ---------------------------------------------------------------------------
const LEVELS := ["barely", "partly", "well"]
const WELL := 2
const DRILL_PLANS := ["attacking", "defensive", "contest", "controlled", "through_stars"]


static func clamp_level(l: int) -> int:
	return clampi(l, 0, LEVELS.size() - 1)


static func level_word(level: int) -> String:
	return str(LEVELS[clamp_level(level)])


## What the coach reads (director, 2026-10-14): high / medium / low.
const FLUENCY := ["low", "medium", "high"]


static func fluency_word(level: int) -> String:
	return str(FLUENCY[clamp_level(level)])


## "Plan fluency: high".
static func known_line(level: int) -> String:
	return "Plan fluency: %s" % fluency_word(level)


## How much of a plan's upside a side at this level keeps (1.0 = all of it).
static func familiar_mult(level: int) -> float:
	return float((tune("familiar_mult") as Dictionary).get(level_word(level), 1.0))


## The starting level of a plan nobody has drilled: well for Balanced and
## for the club's usual plan, "familiar_default" for the rest.
static func start_level(plan: String, usual: String) -> int:
	if plan == "balanced" or plan == usual:
		return WELL
	return clamp_level(int(tune("familiar_default")))


## A new club record: every plan's level.
static func start_levels(usual: String) -> Dictionary:
	var out := {}
	for plan in ["balanced"] + DRILL_PLANS:
		out[plan] = start_level(str(plan), usual)
	return out


## The off-season: every plan but Balanced slips one step.
static func slip_levels(levels: Dictionary) -> Dictionary:
	var out := levels.duplicate()
	for plan in DRILL_PLANS:
		out[plan] = clamp_level(int(levels.get(plan, 0)) - 1)
	out["balanced"] = WELL
	return out


## Plans to drill, cleaned: real, unique, in order, at most drill_max_plans.
static func clean_drills(src: Variant) -> Array:
	var out := []
	if src is Array:
		for p in src:
			if DRILL_PLANS.has(str(p)) and not out.has(str(p)) and out.size() < int(tune("drill_max_plans")):
				out.append(str(p))
	return out


## What a Game plan block drills when the coach has not said: his usual plan
## if it takes drilling, else the plan the side knows least (first of equals).
static func default_drill(usual: String, levels: Dictionary) -> Array:
	if DRILL_PLANS.has(usual):
		return [usual]
	var best := str(DRILL_PLANS[0])
	for plan in DRILL_PLANS:
		if int(levels.get(plan, 0)) < int(levels.get(best, 0)):
			best = str(plan)
	return [best]


## The weeks of drilling each plan gets from a whole plan of blocks: a block's
## weeks are shared between the plans it drills.
static func drill_credit(blocks: Array) -> Dictionary:
	var out := {}
	for i in range(mini(blocks.size(), block_count())):
		var b: Array = blocks[i]
		if str(b[1]) != "plan" or b.size() < 3:
			continue
		var drills := clean_drills(b[2])
		if drills.is_empty():
			continue
		var w := block_weeks(i)
		var weeks := float(int(w[1]) - int(w[0]) + 1) / float(drills.size())
		for plan in drills:
			out[plan] = float(out.get(plan, 0.0)) + weeks
	return out


## Steps up that much drilling gives a plan.
static func drill_steps(credit: float) -> int:
	return int(floor(credit / float(tune("drill_step_weeks")) + 0.000001))


## A level after `credit` weeks of drilling.
static func drilled_level(level: int, credit: float) -> int:
	return clamp_level(level + drill_steps(credit))


## An AI club's blocks with its usual plan drilled in the block its phase
## sets aside (the same blocks, the same rules, as the coach's).
static func with_plan_block(blocks: Array, phase: String, usual: String) -> Array:
	if not DRILL_PLANS.has(usual):
		return blocks
	var table: Dictionary = tune("ai_plan_block")
	var i := clampi(int(table.get(phase, table.get("building", 2))), 0, blocks.size() - 1)
	var out := blocks.duplicate(true)
	out[i] = [str(out[i][0]), "plan", [usual]]
	return out


## "Fluency in Defensive press rises a step for every 2 weeks on it."
static func drill_sentence(plans: Array) -> String:
	var names := []
	for p in clean_drills(plans):
		names.append(CoachReport.plan_label(str(p)))
	if names.is_empty():
		return "Drills a game plan."
	if names.size() == 1:
		return "Fluency in %s rises a step for every %d weeks on it." % [names[0], int(tune("drill_step_weeks"))]
	return "Fluency in %s and %s rises a step for every %d weeks on each, sharing the weeks between them." % [names[0], names[1], int(tune("drill_step_weeks"))]


# ---------------------------------------------------------------------------
# The papers (director, 2026-10-13: "Predict, and you answer"). Week 8: the
# papers print a ladder and one story about your club; you answer it. Talking
# the club up lifts the board's mood now and puts a finish on the record: if
# the club is behind its own words by mid-season a card comes ("A reckoning
# later, no new target"). The board's goal never moves.
# ---------------------------------------------------------------------------
const PAPER_KINDS := ["finish", "breakout", "pressure"]
## The card each story is, in data/stories/media.json.
const PAPER_CARD := {"finish": "media_papers_finish", "breakout": "media_papers_breakout",
		"pressure": "media_papers_pressure"}
## Who writes it: the ladder is Dev Mehta's; the doubts and the pressure are Gary Haddon's.
const PAPER_WRITER := {"finish": "stats", "breakout": "sycophant", "pressure": "muckraker"}


static func papers_seed(career_seed: int, year: int, club: String) -> int:
	return hash("%d|papers|%d|%s" % [career_seed, year, club])


## The paper's ladder, best first. `ratings`: club -> the side it would pick,
## as TeamRating reads it, with this pre-season's injuries counted. Near-ties
## go to last year's finish (0 = none, last), then the board's own list ranking
## (`expect`), then the code, so the same lists always print the same ladder.
static func predicted_order(ratings: Dictionary, last: Dictionary, expect: Dictionary) -> Array:
	var codes: Array = ratings.keys()
	codes.sort_custom(func(a, b):
		if int(ratings[a]) != int(ratings[b]):
			return int(ratings[a]) > int(ratings[b])
		var la := int(last.get(a, 0))
		var lb := int(last.get(b, 0))
		la = la if la > 0 else 99
		lb = lb if lb > 0 else 99
		if la != lb:
			return la < lb
		var ea := int(expect.get(a, 99))
		var eb := int(expect.get(b, 99))
		if ea != eb:
			return ea < eb
		return str(a) < str(b))
	return codes


## The finish the coach names when he talks the club up: a few places above
## the paper's, never above first.
static func claim_rank(predicted: int) -> int:
	return clampi(predicted - int(tune("papers_claim_up")), 1, maxi(1, predicted))


## How far below its own words the club sits (0 when level or ahead).
static func places_behind(position: int, claim: int) -> int:
	if claim <= 0 or position <= 0:
		return 0
	return maxi(0, position - claim)


## Is the club behind its words enough for the papers to come back?
static func reckoning_due(position: int, claim: int) -> bool:
	return claim > 0 and places_behind(position, claim) >= int(tune("papers_places"))


## Does the paper rate the club below the board's goal? The goal's position
## for a ladder goal; for "win seven games" a finish outside the club's
## papers_short_wins_pos.
static func finishes_short(goal: Dictionary, predicted: int) -> bool:
	if goal.has("pos"):
		return predicted > int(goal["pos"])
	return predicted > int(tune("papers_short_wins_pos"))


## Which story the papers run: one of `eligible`, by the pre-season's own seed.
static func pick_paper(eligible: Array, seed: int) -> String:
	if eligible.is_empty():
		return "finish"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return str(eligible[rng.randi_range(0, eligible.size() - 1)])


## "13th".
static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suffix]
