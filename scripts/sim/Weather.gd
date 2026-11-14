class_name Weather
extends RefCounted
## Match-day weather (ARD-M4-016, the director's decisions of 2026-10-06): one
## condition per match - a perfect day, wet, windy or hot - from the ground and
## the month, the same every time it's asked, so the forecast in the week is
## what's played. Evidence and conclusions: docs/research/WEATHER_EVIDENCE.md.
##
## Likelihoods come from Bureau of Meteorology monthly means per venue
## (data/weather_by_venue.json), fitted (row 61) so each condition comes up as
## often as it did at the real outdoor grounds, 2016-25, by the same measure its
## effects were sized on (tools/balance/afl_weather_rates.json: wet 0.3 mm or
## more in the match window, then windy, then hot):
##  - wet: the share of days with 1 mm of rain or more, x WET_K: 14.4% of
##    outdoor matches, about 1 in 9 league-wide with the roofed ground dry;
##  - windy: a soft cut-off on the mean 3 pm wind (WIND_CUT, capped at
##    WIND_CAP a venue-month): 12.0% of outdoor matches;
##  - hot: a soft cut-off on the mean maximum (HOT_CUT): 3.8% of outdoor
##    matches, about 70% of them in March and April (the Heat Policy, ABC).
## The cut-offs are fitted in tools/balance/weather_cutoffs.py.

const CONDITIONS := ["perfect", "wet", "windy", "hot"]
const LABELS := {"perfect": "Perfect day", "wet": "Wet", "windy": "Windy", "hot": "Hot"}
const DATA_PATH := "res://data/weather_by_venue.json"
const MONTHS := ["Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep"]
const WET_K := 0.52
const WIND_CUT := 21.6      # km/h, mean 3 pm wind
const HOT_CUT := 31.0       # C, mean maximum
const SOFT := 3.0           # width of both soft cut-offs
const WIND_CAP := 0.35
## A created club's ground has no station of its own: the state's AFL venue
## stands in for its climate.
const STATE_VENUE := {"VIC": "MCG", "SA": "Adelaide Oval", "WA": "Optus Stadium",
		"NSW": "SCG", "QLD": "The Gabba", "TAS": "Bellerive Oval", "ACT": "Manuka Oval",
		"NT": "The Gabba"}

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {"venues": {}, "roofed": []}
	return _data


## The month of a regular round (0-based; 24 rounds from mid-March to the end
## of August) or of the finals (September), as an index into MONTHS.
static func month_of_round(round_i: int, finals := false) -> int:
	if finals:
		return 6
	return clampi(int(floor((float(round_i) + 2.0) * 7.0 / 30.4)), 0, 5)


static func roofed(venue: String) -> bool:
	return (data().get("roofed", []) as Array).has(venue)


## {wet, windy, hot}: the chance of each at `venue` in month `m`. A ground the
## data doesn't know uses `state`'s venue, then the MCG.
static func chances(venue: String, m: int, state := "") -> Dictionary:
	if roofed(venue):
		return {"wet": 0.0, "windy": 0.0, "hot": 0.0}
	var venues: Dictionary = data().get("venues", {})
	var key := venue
	if not venues.has(key):
		key = str(STATE_VENUE.get(state, "MCG"))
	if not venues.has(key):
		return {"wet": 0.0, "windy": 0.0, "hot": 0.0}
	var row: Dictionary = ((venues[key] as Dictionary).get("months", {}) as Dictionary).get(MONTHS[clampi(m, 0, 6)], {})
	var wet := clampf(float(row.get("rain", 0.0)) * WET_K, 0.0, 1.0)
	var windy := minf(WIND_CAP, _soft(float(row.get("wind_3pm_kmh", 0.0)) - WIND_CUT))
	var hot := _soft(float(row.get("mean_max_c", 0.0)) - HOT_CUT)
	return {"wet": wet, "windy": windy, "hot": hot}


static func _soft(x: float) -> float:
	return 1.0 / (1.0 + exp(-x / SOFT))


## The condition for one match. `key` is anything that identifies it (season
## seed, round, the clubs): the same key always gives the same weather. Rain
## first, then wind on a dry day, then heat on a still one.
static func condition(venue: String, m: int, key: int, state := "") -> String:
	var c := chances(venue, m, state)
	var rng := RandomNumberGenerator.new()
	rng.seed = key
	if rng.randf() < float(c["wet"]):
		return "wet"
	if rng.randf() < float(c["windy"]):
		return "windy"
	if rng.randf() < float(c["hot"]):
		return "hot"
	return "perfect"


## The day may turn once, at a break (row 160, director 2026-11-12: "Yes, at a
## break"): at most once a match, at quarter time, half time or three-quarter
## time (each as likely), announced at that break, with the odds in the
## forecast. Every club's match plays the same rule. Measured on real match
## windows (tools/balance/weather_turns.py: Open-Meteo hourly weather at the
## outdoor AFL grounds, Saturdays 2016-25 at the usual starts, each half of the
## match classified in the game's order): 12.7% of matches turned, and how
## likely depends on how the day starts: a perfect day holds (3.8% turned), a
## wet, windy or hot one turns about a third of the time, mostly fining up.
## TURN_CHANCE: the share that turned, by the start's condition (5,406 perfect,
## 1,144 wet, 918 windy and 272 hot windows). TURN_TO: where those turned to.
## A roofed ground never turns.
const TURN_CHANCE := {"perfect": 0.04, "wet": 0.31, "windy": 0.36, "hot": 0.37}
const TURN_TO := {
	"perfect": {"wet": 0.68, "windy": 0.29, "hot": 0.03},
	"wet": {"perfect": 0.81, "windy": 0.17, "hot": 0.02},
	"windy": {"perfect": 0.70, "wet": 0.25, "hot": 0.05},
	"hot": {"perfect": 0.88, "windy": 0.06, "wet": 0.06},
}
const BREAKS := {1: "quarter time", 2: "half time", 3: "three-quarter time"}


## The chance the day turns at one of the breaks, starting as `start` at `venue`.
static func turn_chance(start: String, venue: String) -> float:
	if roofed(venue):
		return 0.0
	return float(TURN_CHANCE.get(start, 0.0))


## The day's turn: {"after": 1-3 (the break), "to": the condition from there},
## or {} when it holds. `key` is the match's own weather key (the same one
## condition() took): the same match always turns the same way, so the odds the
## forecast states are the ones played.
static func turn(start: String, venue: String, key: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, "turn"])
	if rng.randf() >= turn_chance(start, venue):
		return {}
	var after := 1 + rng.randi_range(0, 2)
	var to_row: Dictionary = TURN_TO.get(start, {})
	var r := rng.randf()
	var to := ""
	for c in CONDITIONS:
		if not to_row.has(c):
			continue
		to = c
		r -= float(to_row[c])
		if r < 0.0:
			break
	if to == "" or to == start:
		return {}
	return {"after": after, "to": to}


## The forecast's odds, in a coach's words: "" when the day can't turn.
static func turn_odds_line(chance: float) -> String:
	var pct := roundi(chance * 100.0)
	if pct <= 0:
		return ""
	return "%d%% chance it turns at a break" % pct


## The break's announcement: what the day has done and what it means from here.
const TURN_NEWS := {
	"wet": "The rain has come in at %s. Wet from here: a greasy ball, contested footy counts for more, fewer marks stick and set shots get harder.",
	"windy": "The wind has got up at %s. Windy from here: the breeze end matters and the ball is harder to hold.",
	"hot": "It has heated up by %s. Hot from here: a slower game, and legs tire sooner.",
	"perfect": "It has fined up by %s. A perfect day from here: the ball is dry and easier to mark.",
}


static func turn_news(after: int, to: String) -> String:
	return str(TURN_NEWS.get(to, "")) % str(BREAKS.get(after, "the break"))


## The match report's line for a day that turned: how it started and when it turned.
const TURN_REPORT := {
	"wet": "The rain came in at %s",
	"windy": "The wind got up at %s",
	"hot": "It heated up by %s",
	"perfect": "It fined up by %s",
}


static func turn_report_line(start: String, after: int, to: String) -> String:
	var what := "a dry ball from there, easier to mark." if to == "perfect" 			else report_line(to).trim_prefix(str(REPORT_LEAD.get(to, "")))
	return "It started %s. %s: %s" % [str(STARTED.get(start, "fine")),
			str(TURN_REPORT.get(to, "The weather turned at %s")) % str(BREAKS.get(after, "a break")), what]


const STARTED := {"perfect": "fine", "wet": "wet", "windy": "windy", "hot": "hot"}
const REPORT_LEAD := {"wet": "A wet day: ", "windy": "A windy day: ", "hot": "A hot day: "}


## The day in a coach's words, for the match report (none on a perfect day).
const REPORT := {
	"wet": "A wet day: a greasy ball, contested footy counted for more, fewer marks stuck and set shots were harder.",
	"windy": "A windy day: the breeze end mattered, and the ball was hard to hold.",
	"hot": "A hot day: a slower game with fewer tackles and stoppages, and legs tired sooner.",
}


static func report_line(condition_id: String) -> String:
	return str(REPORT.get(condition_id, ""))


static func label(condition_id: String) -> String:
	return str(LABELS.get(condition_id, LABELS["perfect"]))
