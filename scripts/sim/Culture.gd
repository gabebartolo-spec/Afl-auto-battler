class_name Culture
extends RefCounted
## A club's culture: three slow, club-wide strands, shown in words and never as
## a meter (club-life stories, phase 2). Standards: how hard and how cleanly
## the group works. Togetherness: whether the group sticks by each other.
## Ambition: playing to win now, or patiently building.
##
## Each strand lives in GameState.relations under "k:<club>:<strand>", in the
## same {t, log} shape as player trust, so Trust.change keeps the reason of
## every move and a club with no entry is neutral (an older save has none).
## Every club has them and every club moves by the same rules, from facts the
## game already knows (results, ladder finish, the age and discipline of the
## list, new faces from other clubs, a promise you broke). Strands only ever
## move in small steps; the reasons are facts about the club in football
## words, never a verdict on a player's character.
##
## Effects (director, 2026-10-13: small, then measure, both ways; 2026-10-18:
## build them, and a patient club brings its young on), sizes in
## data/culture_effects.json, the same rule for every club, applied in GameState:
##   Standards    - how fast legs recover between games (Workload.advance_week)
##   Togetherness - how much being left out of the side costs a fit player's
##                  morale (ClubLife.morale_after_match)
##   Ambition     - winning now: the price a player will re-sign for, and a free
##                  agent's weighing of the club's offer (Contracts); patient or
##                  rebuilding: how fast under-22s and first-season draftees
##                  develop (match XP, GameState._club_xp) and how far in a
##                  season (a point of training ceiling, GameState.season_ceiling)
## A band in the middle does nothing; the screen says what each active band does.
## Effects move the odds of a season, never its certainty: each is a small tilt
## on a lever the game already has.

const STRANDS := [["standards", "Standards"], ["together", "Togetherness"], ["ambition", "Ambition"]]
## The most one moment moves a strand, either way.
const STEP_MAX := 6
## Run lengths that move Togetherness (once, on the game that reaches them).
const LOSING_RUNS := [4, 8]
const WINNING_RUNS := [5, 10]
## Season-end thresholds.
const FINALS_PLACES := 8
const BOTTOM_PLACES := 4
## Age and discipline are read against the league at season close, so a strand
## moves for the clubs that stand out and the league as a whole never drifts.
const AGE_GAP := 1.0
const DISCIPLINE_GAP := 2.5
## Each season a strand settles back a little towards neutral: culture is slow.
const SETTLE_RATE := 0.12
## New faces from other clubs at the rollover, against the league median.
const FACES_ABOVE := 4.0
const FACES_BELOW := 3.0

## Bands, highest first: [floor, key, words on the club's page, news phrase].
const BANDS := {
	"standards": [
		[40, "elite", "A hard-working, well-run group", "have become a hard-working, well-run group"],
		[12, "good", "A hard-working group", "have become a hard-working group"],
		[-11, "mid", "", ""],
		[-34, "loose", "A relaxed group", "have become a relaxed group"],
		[-100, "slack", "A group that has let its standards slip", "have let their standards slip"],
	],
	"together": [
		[40, "very", "A very tight group", "have become a very tight group"],
		[12, "tight", "A tight group", "have become a tight group"],
		[-11, "mid", "", ""],
		[-34, "cliques", "A group with some cliques", "are said to have cliques in the group"],
		[-100, "split", "A divided group", "are said to be a divided group"],
	],
	"ambition": [
		[40, "allin", "All in on winning now", "are all in on winning now"],
		[12, "now", "Pushing to win now", "are pushing to win now"],
		[-11, "mid", "", ""],
		[-34, "patient", "Patient, building for later", "are playing the long game"],
		[-100, "rebuild", "In a full rebuild", "are in a full rebuild"],
	],
}


static func key(club: String, strand: String) -> String:
	return "k:%s:%s" % [club, strand]


static func value(rel: Dictionary, club: String, strand: String) -> int:
	return Trust.value(rel, key(club, strand))


static func _band(strand: String, t: int) -> Array:
	var bands: Array = BANDS[strand]
	for b in bands:
		if t >= int(b[0]):
			return b
	return bands[bands.size() - 1]


static func band_key(strand: String, t: int) -> String:
	return str(_band(strand, t)[1])


## "A tight group", or "" while nothing stands out.
static func words(strand: String, t: int) -> String:
	return str(_band(strand, t)[2])


## A strand settles back a little towards neutral (no reason kept: it is the
## passing of time, not an event).
static func settle(rel: Dictionary, club: String, strand: String) -> void:
	var k := key(club, strand)
	var entry: Dictionary = rel.get(k, {})
	var t := int(entry.get("t", 0))
	if absi(t) < 3:
		return
	var step := maxi(1, int(round(float(absi(t)) * SETTLE_RATE)))
	entry["t"] = t - step if t > 0 else t + step
	rel[k] = entry


## Does a band make the league news for a rival? Never a negative claim about
## a real club: only the positive bands, and the patient and rebuilding ones.
## The negative bands show on your own club's page and nowhere else.
static func news_ok(strand: String, t: int) -> bool:
	return not ["loose", "slack", "cliques", "split"].has(band_key(strand, t)) and words(strand, t) != ""


## "have become a tight group", for the league news.
static func news_phrase(strand: String, t: int) -> String:
	return str(_band(strand, t)[3])


## Move a strand by `d` (capped), keeping the reason. Returns what moved.
static func change(rel: Dictionary, club: String, strand: String, d: int, why: String,
		year: int, when: String) -> int:
	return Trust.change(rel, key(club, strand), clampi(d, -STEP_MAX, STEP_MAX), why, year, when)


## The reasons, newest first: [{"y", "w", "d", "why"}]. A run that an older
## save logged again each week it stood (a bye, or finals weeks the club sat
## out) reads as the one run it was; the save itself is left as it is.
static func reasons(rel: Dictionary, club: String, strand: String) -> Array:
	var out := []
	var last := {}
	var log: Array = Trust.reasons(rel, key(club, strand))
	log.reverse()
	for r in log:
		var why := str(r.get("why", ""))
		var run := run_length(why)
		if run > 0:
			if last.has(why) and _same_run(last[why], r, run):
				continue
			last[why] = r
		out.append(r)
	out.reverse()
	return out


## From this round on a run still stands when the finals start (every season
## has at least 22 rounds, and the longest first mark is five games).
const LATE_ROUND := 21


## The games in the run a reason names ("A run of four losses": 4), else 0.
static func run_length(why: String) -> int:
	for n in LOSING_RUNS:
		if why == str(run_step(int(n), 0)[2]):
			return int(n)
	for n in WINNING_RUNS:
		if why == str(run_step(0, int(n))[2]):
			return int(n)
	return 0


## Is `r` the run already told by `prev`? A run of `run` games can only be
## reached again `run` + 1 rounds later (it has to break first), and never
## twice within one finals series.
static func _same_run(prev: Dictionary, r: Dictionary, run: int) -> bool:
	if int(prev.get("y", 0)) != int(r.get("y", 0)):
		return false
	var a := _round_of(str(prev.get("w", "")))
	var b := _round_of(str(r.get("w", "")))
	if a > 0 and b > 0:
		return b - a <= run
	# A final after a round: the same run only if that round closed the club's
	# home-and-away season (an earlier run would have had to break first).
	return b == 0 and (a == 0 or a >= LATE_ROUND)


static func _round_of(when: String) -> int:
	return int(when.trim_prefix("Round ")) if when.begins_with("Round ") else 0


## One reason as a line: "Round 6, 2027. A run of four losses. Togetherness fell."
static func reason_text(strand_label: String, r: Dictionary) -> String:
	var why := str(r.get("why", "")).strip_edges()
	if why != "" and not why.ends_with("."):
		why += "."
	return "%s, %d. %s %s %s." % [str(r.get("w", "")), int(r.get("y", 0)), why, strand_label,
			"rose" if int(r.get("d", 0)) > 0 else "fell"]


## The same reason repeated (a run of losses twice, discipline three seasons
## running) as one entry: [{"why", "y0", "y1", "whens", "d", "n", "latest"}],
## newest first. `latest` is the direction of the newest move in the entry.
static func grouped(rel: Dictionary, club: String, strand: String) -> Array:
	var out := []
	var at := {}
	for r in reasons(rel, club, strand):
		var k := str(r.get("why", ""))
		var y := int(r.get("y", 0))
		if at.has(k):
			var g: Dictionary = out[int(at[k])]
			(g["whens"] as Array).append(str(r.get("w", "")))
			g["d"] = int(g["d"]) + int(r.get("d", 0))
			g["n"] = int(g["n"]) + 1
			(g["years"] as Array).append(y)
			g["y0"] = mini(int(g["y0"]), y)
			g["y1"] = maxi(int(g["y1"]), y)
		else:
			at[k] = out.size()
			out.append({"why": k, "y0": y, "y1": y, "whens": [str(r.get("w", ""))],
					"d": int(r.get("d", 0)), "n": 1, "latest": int(r.get("d", 0)), "years": [y]})
	# Newest season first; within a season, the order they came.
	var order := []
	for i in range(out.size()):
		order.append(i)
	order.sort_custom(func(a, b): return int(out[a]["y1"]) > int(out[b]["y1"]) or (int(out[a]["y1"]) == int(out[b]["y1"]) and a < b))
	var sorted := []
	for i in order:
		sorted.append(out[i])
	return sorted


## Reasons that read differently when they run across seasons.
const PERFECT := {
	"The list holds itself to a higher standard than most clubs": "The list has held itself to a higher standard than most clubs",
	"The list lets its standards slip more than most clubs": "The list has let its standards slip more than most clubs",
}


## One grouped reason as a football sentence, the time at the end:
## "Played finals in 2026 and 2027." / "A run of four losses in round 10, 2026. It
## cost Togetherness." / "Five wins in a row, twice, in 2025 and 2026."
static func group_text(strand_label: String, g: Dictionary) -> String:
	var why := str(g["why"]).strip_edges().trim_suffix(".")
	var n := int(g["n"])
	var years := _distinct_sorted(g["years"] if g.has("years") else [int(g["y0"]), int(g["y1"])])
	var whens: Array = (g["whens"] as Array).duplicate()
	whens.reverse()
	var line := ""
	if PERFECT.has(why) and years.size() > 1:
		line = "%s for %s off-seasons." % [PERFECT[why], _count(n)]
	else:
		var when := _years_text(years)
		if years.size() == 1:
			var rounds := PackedStringArray()
			for w in whens:
				if str(w).begins_with("Round "):
					rounds.append(str(w).trim_prefix("Round "))
			if rounds.size() == 1:
				when = "round %s, %d" % [rounds[0], years[0]]
			elif rounds.size() > 1:
				when = "rounds %s and %s, %d" % [", ".join(rounds.slice(0, rounds.size() - 1)), rounds[rounds.size() - 1], years[0]]
		var count := ""
		if n > years.size():
			count = "twice" if n == 2 else "%s times" % _count(n)
		var head := why
		var tail := ""
		if why.contains(":"):
			head = why.substr(0, why.find(":"))
			tail = why.substr(why.find(":"))
		if count != "":
			head += ", " + count + ","
		line = "%s in %s%s." % [head, when, tail]
	if int(g["d"]) <= 0:
		line += " It cost %s." % strand_label
	return line


static func _years_text(years: Array) -> String:
	var ys := PackedStringArray()
	for y in years:
		ys.append(str(y))
	if ys.size() == 1:
		return ys[0]
	return ", ".join(ys.slice(0, ys.size() - 1)) + " and " + ys[ys.size() - 1]


static func _distinct_sorted(years: Array) -> Array:
	var seen := {}
	var out := []
	for y in years:
		if not seen.has(int(y)):
			seen[int(y)] = true
			out.append(int(y))
	out.sort()
	return out


const EFFECTS_PATH := "res://data/culture_effects.json"
static var _effects := {}


static func effects() -> Dictionary:
	if _effects.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(EFFECTS_PATH))
		_effects = parsed if parsed is Dictionary else {}
	return _effects


## The size of one effect for a strand's band (0.0 when the band does none).
static func effect_of(kind: String, strand: String, band: String) -> float:
	var by_strand: Dictionary = (effects().get(kind, {}) as Dictionary).get(strand, {})
	return float(by_strand.get(band, 0.0))


## The size of one effect at a club, from where its strand stands now.
static func club_effect(rel: Dictionary, club: String, kind: String, strand: String) -> float:
	return effect_of(kind, strand, band_key(strand, value(rel, club, strand)))


## Which strand each kind of effect belongs to.
const KIND_STRAND := {"recovery": "standards", "sting": "together",
		"resign_floor": "ambition", "free_agent_score": "ambition", "young_growth": "ambition",
		"young_ceiling": "ambition"}


## Does a patient club's young-player effect reach this player: under the
## table's age (under-22s), or in his first season on a list after the draft.
static func young_for_growth(p: Dictionary, season_year: int) -> bool:
	if float(p.get("age", 25.0)) < float(effects().get("young_age_below", 22)):
		return true
	return p.has("drafted_year") and season_year - int(p["drafted_year"]) <= int(effects().get("draftee_seasons", 1))


## What an active band does, in football words, from the applied number: "" in
## the middle band.
static func effect_line(strand: String, t: int) -> String:
	var band := band_key(strand, t)
	var little: Dictionary = effects().get("little_max", {})
	match strand:
		"standards":
			var x := effect_of("recovery", strand, band)
			if x == 0.0:
				return ""
			return "Players recover %s %s between games." % ["a little" if absf(x) <= float(little["recovery"]) else "much",
					"faster" if x > 0.0 else "slower"]
		"together":
			var x := effect_of("sting", strand, band)
			if x == 0.0:
				return ""
			return "Players take a missed game %s %s." % ["a little" if absf(x) <= float(little["sting"]) else "much",
					"better" if x > 0.0 else "worse"]
		"ambition":
			if effect_of("young_growth", strand, band) != 0.0 or effect_of("young_ceiling", strand, band) != 0.0:
				return "Young players come on quicker at a patient club."
			var r := effect_of("resign_floor", strand, band)
			var f := effect_of("free_agent_score", strand, band)
			if r == 0.0 and f == 0.0:
				return ""
			if absf(r) <= float(little["resign_floor"]) and absf(f) <= float(little["free_agent_score"]):
				return "Players are a little more willing to stay and to join."
			return "Players are keen to stay and to join."
	return ""


## What moves a strand, from the same constants the movers use.
static func moves_line(strand: String) -> String:
	match strand:
		"standards":
			return "Moves at the end of each season: up when your list is well more disciplined than the league's, down when it is well less."
		"together":
			return "Rises with finals (top %s), a premiership, runs of %s and %s wins and a settled list. Falls with a bottom-%s finish, runs of %s and %s losses, many new faces and promises you break." % [
					FINALS_PLACES, WINNING_RUNS[0], WINNING_RUNS[1], BOTTOM_PLACES, LOSING_RUNS[0], LOSING_RUNS[1]]
		"ambition":
			return "Moves at the end of each season with the age of your best 22: a year or more older than the league's average pushes it towards winning now, a year or more younger towards building for later."
	return ""


## One event as a line, the year shown beside it: "Round 10: a run of four losses. Togetherness fell."
## / "Semi Finals: a run of four losses. Togetherness fell."
static func event_text(strand_label: String, r: Dictionary) -> String:
	var why := str(r.get("why", "")).strip_edges().trim_suffix(".")
	var w := str(r.get("w", ""))
	# The week is named for anything that happened in one: a round, or a final.
	var lead := (w + ": " + why.substr(0, 1).to_lower() + why.substr(1)) if w != "" and w != "Off-season" else why
	return "%s. %s %s." % [lead, strand_label, "rose" if int(r.get("d", 0)) > 0 else "fell"]


## What a strand reads when no band is named: nothing yet, or which way its
## latest move went (so it never contradicts the reason below it).
static func quiet_words(latest: int, has_reasons: bool) -> String:
	if not has_reasons:
		return "Nothing stands out yet"
	if latest > 0:
		return "Starting to build"
	if latest < 0:
		return "Starting to slip"
	return "Holding steady"


## The strands that stand out, by name, for the row that leads to the sheet:
## "Standards, togetherness" (sentence case), or "Nothing stands out yet".
static func headline(rel: Dictionary, club: String) -> String:
	var names := PackedStringArray()
	for s in STRANDS:
		if words(str(s[0]), value(rel, club, str(s[0]))) != "":
			names.append(str(s[1]) if names.is_empty() else str(s[1]).to_lower())
	if names.is_empty():
		return "Nothing stands out yet"
	return ", ".join(names)


## The strands that stand out, in words: "A tight group. Pushing to win now."
static func summary(rel: Dictionary, club: String) -> String:
	var out := PackedStringArray()
	for s in STRANDS:
		var w := words(str(s[0]), value(rel, club, str(s[0])))
		if w != "":
			out.append(w)
	return ", ".join(out)


# --- The movers: pure, from facts -------------------------------------------

## Losses (or wins) in a row that just reached a threshold, else [].
static func run_step(losses: int, wins: int) -> Array:
	if LOSING_RUNS.has(losses):
		return ["together", -3, "A run of %s losses" % _count(losses)]
	if WINNING_RUNS.has(wins):
		return ["together", 3, "%s wins in a row" % _count(wins).capitalize()]
	return []


## The season's close for one club: [{"strand", "d", "why"}].
## `position` is 1-based on the ladder of `clubs`; `age_gap` is the best 22's
## average age minus the league's; `discipline_gap` is the list's discipline
## rating minus the league's.
static func season_steps(position: int, clubs: int, premier: bool, age_gap: float,
		discipline_gap: float) -> Array:
	var out := []
	if premier:
		out.append({"strand": "together", "d": 5, "why": "Premiers"})
	elif position <= FINALS_PLACES:
		out.append({"strand": "together", "d": 3, "why": "Played finals"})
	elif position > clubs - BOTTOM_PLACES:
		out.append({"strand": "together", "d": -3, "why": "Finished near the bottom of the ladder"})
	if age_gap >= AGE_GAP:
		out.append({"strand": "ambition", "d": 4, "why": "An experienced side"})
	elif age_gap <= -AGE_GAP:
		out.append({"strand": "ambition", "d": -4, "why": "A young side"})
	if discipline_gap >= DISCIPLINE_GAP:
		out.append({"strand": "standards", "d": 4, "why": "The list holds itself to a higher standard than most clubs"})
	elif discipline_gap <= -DISCIPLINE_GAP:
		out.append({"strand": "standards", "d": -4, "why": "The list lets its standards slip more than most clubs"})
	return out


## New faces from other clubs at the rollover, against the league's median for
## the off-season (some churn is normal): well above it costs Togetherness,
## well below it helps. [{"strand", "d", "why"}] or [].
static func new_faces_step(n: int, median: float) -> Array:
	if float(n) >= median + FACES_ABOVE:
		return [{"strand": "together", "d": -4, "why": "%s new faces from other clubs, well more than most" % _count(n).capitalize()}]
	if float(n) <= median - FACES_BELOW:
		return [{"strand": "together", "d": 3, "why": "A settled list: far fewer new faces from other clubs than most"}]
	return []


static func _count(n: int) -> String:
	var small := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	return small[n] if n >= 0 and n < small.size() else str(n)
