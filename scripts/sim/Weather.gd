class_name Weather
extends RefCounted
## Match-day weather (ARD-M4-016, the director's decisions of 2026-10-06): one
## condition per match - a perfect day, wet, windy or hot - from the ground and
## the month, the same every time it's asked, so the forecast in the week is
## what's played. Evidence and conclusions: docs/research/WEATHER_EVIDENCE.md.
##
## Likelihoods come from Bureau of Meteorology monthly means per venue
## (data/weather_by_venue.json):
##  - wet: the share of days with 1 mm of rain or more, x WET_K. With the roofed
##    ground always dry that makes about 1 match in 5 wet league-wide (SI
##    335/1,625; BB 630/2,819);
##  - windy: a soft cut-off on the mean 3 pm wind (WIND_CUT, capped at
##    WIND_CAP a venue-month), fitted to about 14% of outdoor matches (OUW
##    382/2,640);
##  - hot: a soft cut-off on the mean maximum (HOT_CUT), which puts about 70%
##    of hot days in March and April (the Heat Policy, ABC).
## The cut-offs are fitted in tools/balance/weather_cutoffs.py.

const CONDITIONS := ["perfect", "wet", "windy", "hot"]
const LABELS := {"perfect": "Perfect day", "wet": "Wet", "windy": "Windy", "hot": "Hot"}
const DATA_PATH := "res://data/weather_by_venue.json"
const MONTHS := ["Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep"]
const WET_K := 1.03
const WIND_CUT := 21.5      # km/h, mean 3 pm wind
const HOT_CUT := 28.6       # C, mean maximum
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


static func label(condition_id: String) -> String:
	return str(LABELS.get(condition_id, LABELS["perfect"]))
