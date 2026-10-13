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
## Seams left for later slices: the game-plan focus (add it to "focuses"),
## the stops after blocks 2 and 3 (STOPS), cards and the papers.

const DATA_PATH := "res://data/preseason.json"
## The same sizes, should the file be missing from a build.
const DEFAULTS := {
	"weeks": 8,
	"blocks": [[1, 3], [4, 5], [6, 7]],
	"loads": ["light", "solid", "heavy"],
	"focuses": ["running", "skills"],
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
	"default_blocks": [["solid", "running"], ["solid", "skills"], ["solid", "skills"]],
	"ai_blocks": {
		"contending": [["solid", "running"], ["solid", "running"], ["solid", "skills"]],
		"building": [["solid", "running"], ["solid", "skills"], ["solid", "skills"]],
		"rebuilding": [["solid", "skills"], ["solid", "skills"], ["solid", "running"]],
	},
}

const LOAD_LABEL := {"light": "Light", "solid": "Solid", "heavy": "Heavy"}
const FOCUS_LABEL := {"running": "Running", "skills": "Skills"}
const BASES := ["thin", "sound", "strong"]
const DEFAULT_BASE := "sound"
## The weeks after which the pre-season stops for the coach: {week: stop}.
## Slice 1 stops only for the time trial.
const STOPS := {3: "trial"}

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
		if src is Array and i < (src as Array).size() and (src as Array)[i] is Array \
				and ((src as Array)[i] as Array).size() >= 2 \
				and valid_block(str((src as Array)[i][0]), str((src as Array)[i][1])):
			b = (src as Array)[i]
		out.append([str(b[0]), str(b[1])])
	return out


## The plan a coach's pre-season opens on.
static func default_blocks() -> Array:
	return _blocks(tune("default_blocks"))


## What an AI club runs, from where it is in its cycle (TradeValue.phase):
## contenders lean to running, rebuilders to skills, the rest spread it.
static func ai_blocks(phase: String) -> Array:
	var table: Dictionary = tune("ai_blocks")
	return _blocks(table.get(phase, table.get("building", [])))


## A fresh pre-season for `year`: `club_blocks` is club code -> its blocks.
static func new_state(year: int, club_blocks: Dictionary) -> Dictionary:
	var clubs := {}
	for code in club_blocks:
		clubs[str(code)] = {"blocks": _blocks(club_blocks[code]), "run": 0.0}
	return {"year": year, "week": 0, "clubs": clubs, "trial": {}, "trial_seen": false, "done": false}


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


const _SESSIONS := {"running": "running sessions", "skills": "skills sessions"}
const _PURPOSE := {"running": "for the fitness base", "skills": "so every fit player develops"}
const _OF_AREA := {"running": "of running", "skills": "of skills work"}
const _COUNT := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]


static func _other(focus: String) -> String:
	for f in focuses():
		if str(f) != focus:
			return str(f)
	return focus


static func _count(n: int) -> String:
	return str(_COUNT[n]) if n >= 0 and n < _COUNT.size() else str(n)


## An amount of work as weeks, in words: "three weeks", "a week and a half",
## "four and a half weeks". Anything that is not a whole or a half is a figure.
static func weeks_words(x: float) -> String:
	var halves := x * 2.0
	if not is_equal_approx(halves, roundf(halves)):
		return "%.1f weeks" % x
	var whole := int(floor(x + 0.001))
	var half := int(roundf(halves)) % 2 == 1
	if not half:
		return "one week" if whole == 1 else "%s weeks" % _count(whole)
	if whole == 0:
		return "half a week"
	if whole == 1:
		return "a week and a half"
	return "%s and a half weeks" % _count(whole)


## How long a session is beside a full one, in words, from its share of a
## full week's work: 1.0 full, 0.75 three-quarter, 0.5 half, 0.25 quarter.
static func session_words(share: float) -> String:
	for row in [[1.0, "full"], [0.75, "three-quarter"], [0.5, "half"], [0.25, "quarter"]]:
		if is_equal_approx(share, float(row[0])):
			return str(row[1])
	return "longer" if share > 1.0 else "shorter"


## "Three weeks", or for the block before Round 1 "The last two weeks".
static func _span(i: int) -> String:
	var b := block_weeks(i)
	var n := int(b[1]) - int(b[0]) + 1
	var words := "%s week%s" % [_count(n), "" if n == 1 else "s"]
	return ("The last %s" % words) if is_last_block(i) else _cap(words)


static func _cap(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


## What the block's weeks hold, said from the sizes in the data: how much of
## the focus they do and how long the other area's sessions are.
static func _work_line(load: String, focus: String, i: int) -> String:
	var b := block_weeks(i)
	var n := float(int(b[1]) - int(b[0]) + 1)
	var other := _other(focus)
	var mine := work(load, focus, focus)
	var theirs := str(_OF_AREA.get(other, "of everything else"))
	var rest := "%s sessions %s." % [_cap(session_words(work(load, focus, other))), theirs]
	var sessions := str(_SESSIONS.get(focus, focus + " sessions"))
	if is_equal_approx(mine, 1.0):
		return "%s: full %s, %s. %s" % [_span(i), sessions, str(_PURPOSE.get(focus, "")), rest]
	if mine > 1.0:
		return "%s: longer, harder %s, %s of work %s. %s" % [_span(i), sessions, weeks_words(n * mine),
				str(_PURPOSE.get(focus, "")), rest]
	return "%s: short %s, %s of work. %s" % [_span(i), sessions, weeks_words(n * mine), rest]


## What block `i`'s load and focus gain.
static func gain_line(load: String, focus: String, i: int) -> String:
	var last := is_last_block(i)
	match load:
		"light":
			if last:
				return "Fresh bodies for Round 1: less soft-tissue risk."
			return "Easier weeks on the track. Nothing that lasts to Round 1."
	return _work_line(load, focus, i)


## What it costs. A Solid block costs nothing: "None".
static func cost_line(load: String, focus: String, i: int) -> String:
	match load:
		"light":
			return _work_line(load, focus, i)
		"heavy":
			if is_last_block(i):
				return "Heavy legs and more soft-tissue risk in Round 1."
			return "Heavy legs on the track for these weeks. They are gone by Round 1."
	return "None"


const BASE_LABEL := {"thin": "a thin fitness base", "sound": "a sound fitness base", "strong": "a strong fitness base"}
const BASE_EFFECT := {
	"thin": "The side starts underdone and tires sooner for the first six rounds. A planned peak comes lower.",
	"sound": "The side starts the season level.",
	"strong": "Fresher legs and a little less soft-tissue risk through the first month.",
}
