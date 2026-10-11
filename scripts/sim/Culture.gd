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
			g["y0"] = mini(int(g["y0"]), y)
			g["y1"] = maxi(int(g["y1"]), y)
		else:
			at[k] = out.size()
			out.append({"why": k, "y0": y, "y1": y, "whens": [str(r.get("w", ""))],
					"d": int(r.get("d", 0)), "n": 1, "latest": int(r.get("d", 0))})
	# Newest season first; within a season, the order they came.
	var order := []
	for i in range(out.size()):
		order.append(i)
	order.sort_custom(func(a, b): return int(out[a]["y1"]) > int(out[b]["y1"]) or (int(out[a]["y1"]) == int(out[b]["y1"]) and a < b))
	var sorted := []
	for i in order:
		sorted.append(out[i])
	return sorted


## One grouped reason as a line: "Round 4 and Round 12, 2027. A run of four
## losses, twice. Togetherness fell." or "Off-season, 2025 to 2027. ... three
## off-seasons running."
static func group_text(strand_label: String, g: Dictionary) -> String:
	var whens: Array = g["whens"].duplicate()
	whens.reverse()
	var n := int(g["n"])
	var why := str(g["why"]).strip_edges().trim_suffix(".")
	var when := ""
	var years := ""
	var repeat := ""
	var off_seasons := true
	for w in whens:
		if str(w) != "Off-season":
			off_seasons = false
	if int(g["y0"]) != int(g["y1"]):
		years = "%d to %d" % [int(g["y0"]), int(g["y1"])]
		when = "Off-season" if off_seasons else "Over the seasons"
		repeat = (", %s off-seasons running" if off_seasons else ", %s times") % _count(n)
	else:
		years = str(int(g["y0"]))
		if whens.size() == 1:
			when = str(whens[0])
		else:
			var head := PackedStringArray()
			for w in whens.slice(0, whens.size() - 1):
				head.append(str(w))
			when = ", ".join(head) + " and " + str(whens[whens.size() - 1])
		if n == 2:
			repeat = ", twice"
		elif n > 2:
			repeat = ", %s times" % _count(n)
	var line := "%s, %s. %s%s." % [when, years, why, repeat]
	if int(g["d"]) <= 0:
		line += " It cost %s." % strand_label
	return line


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
