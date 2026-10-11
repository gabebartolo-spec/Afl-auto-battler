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
## They have no effect yet: P2-5 decides what they touch, measured.

const STRANDS := [["standards", "Standards"], ["together", "Togetherness"], ["ambition", "Ambition"]]
## The most one moment moves a strand, either way.
const STEP_MAX := 6
## Run lengths that move Togetherness (once, on the game that reaches them).
const LOSING_RUNS := [4, 8]
const WINNING_RUNS := [5, 10]
## Season-end thresholds.
const FINALS_PLACES := 8
const BOTTOM_PLACES := 4
const OLD_SIDE_AGE := 27.0
const YOUNG_SIDE_AGE := 24.5
const DISCIPLINE_GAP := 4.0
## New faces from other clubs at the rollover.
const MANY_NEW_FACES := 6
const FEW_NEW_FACES := 1

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


## "have become a tight group", for the league news.
static func news_phrase(strand: String, t: int) -> String:
	return str(_band(strand, t)[3])


## Move a strand by `d` (capped), keeping the reason. Returns what moved.
static func change(rel: Dictionary, club: String, strand: String, d: int, why: String,
		year: int, when: String) -> int:
	return Trust.change(rel, key(club, strand), clampi(d, -STEP_MAX, STEP_MAX), why, year, when)


## The reasons, newest first: [{"y", "w", "d", "why"}].
static func reasons(rel: Dictionary, club: String, strand: String) -> Array:
	return Trust.reasons(rel, key(club, strand))


## One reason as a line: "Round 6, 2027. A run of four losses. Togetherness fell."
static func reason_text(strand_label: String, r: Dictionary) -> String:
	var why := str(r.get("why", "")).strip_edges()
	if why != "" and not why.ends_with("."):
		why += "."
	return "%s, %d. %s %s %s." % [str(r.get("w", "")), int(r.get("y", 0)), why, strand_label,
			"rose" if int(r.get("d", 0)) > 0 else "fell"]


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
## `position` is 1-based on the ladder of `clubs`; `avg_age` is the best 22's
## average; `discipline_gap` is the list's discipline rating minus the league's.
static func season_steps(position: int, clubs: int, premier: bool, avg_age: float,
		discipline_gap: float) -> Array:
	var out := []
	if premier:
		out.append({"strand": "together", "d": 5, "why": "Premiers"})
	elif position <= FINALS_PLACES:
		out.append({"strand": "together", "d": 3, "why": "Played finals"})
	elif position > clubs - BOTTOM_PLACES:
		out.append({"strand": "together", "d": -3, "why": "Finished near the bottom of the ladder"})
	if avg_age >= OLD_SIDE_AGE:
		out.append({"strand": "ambition", "d": 4, "why": "An experienced side: the best 22 average %.1f" % avg_age})
	elif avg_age <= YOUNG_SIDE_AGE:
		out.append({"strand": "ambition", "d": -4, "why": "A young side: the best 22 average %.1f" % avg_age})
	if discipline_gap >= DISCIPLINE_GAP:
		out.append({"strand": "standards", "d": 4, "why": "The list's discipline is well above the league's"})
	elif discipline_gap <= -DISCIPLINE_GAP:
		out.append({"strand": "standards", "d": -4, "why": "The list's discipline is well below the league's"})
	return out


## New faces from other clubs at the rollover: [{"strand", "d", "why"}] or [].
static func new_faces_step(n: int) -> Array:
	if n >= MANY_NEW_FACES:
		return [{"strand": "together", "d": -4, "why": "%s new faces from other clubs" % _count(n).capitalize()}]
	if n <= FEW_NEW_FACES:
		return [{"strand": "together", "d": 3, "why": "A settled list: hardly a new face from another club"}]
	return []


static func _count(n: int) -> String:
	var small := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	return small[n] if n >= 0 and n < small.size() else str(n)
