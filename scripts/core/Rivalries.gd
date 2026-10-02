class_name Rivalries
extends RefCounted
## Established club rivalries. Presentation/history only: being a rivalry
## never changes ratings, MatchSim odds or player attributes.
##
## Uneven counts are deliberate. A club can have several genuine rivals;
## this is not a pairing system and marquee fixtures are a separate concept.

const ESTABLISHED := [
	["COL", "CAR", "Collingwood–Carlton"],
	["ADE", "PAD", "The Showdown"],
	["HAW", "GEE", "Hawthorn–Geelong"],
	["FRE", "WCE", "The Western Derby"],
	["ESS", "COL", "Essendon–Collingwood"],
	["RIC", "CAR", "Richmond–Carlton"],
	["SYD", "GWS", "Sydney Derby"],
	["GWS", "WBD", "GWS–Western Bulldogs"],
	["BRL", "GCS", "The Pineapple Grapple"],
	["MEL", "COL", "Melbourne–Collingwood"],
	["WBD", "COL", "Western Bulldogs–Collingwood"],
	["PAD", "COL", "Port Adelaide–Collingwood"],
	["TAS", "CANB", "Expansion Cup"],
]


static func established(a: String, b: String) -> Dictionary:
	for row in ESTABLISHED:
		if (str(row[0]) == a and str(row[1]) == b) or (str(row[0]) == b and str(row[1]) == a):
			return {"clubs": [str(row[0]), str(row[1])], "name": str(row[2])}
	return {}


static func are_rivals(a: String, b: String) -> bool:
	return not established(a, b).is_empty()


static func label(a: String, b: String) -> String:
	return str(established(a, b).get("name", ""))


## Dynamic rivalry history is stored by canonical club-pair key.
## score is deliberately internal; UI exposes words and the football reasons.
const BREWING := 8
const RIVALS := 15
const CLOSE_MARGIN := 12

static func pair_key(a: String, b: String) -> String:
	var pair := [a, b]
	pair.sort()
	return "%s|%s" % [pair[0], pair[1]]


## Apply one completed match exactly once. Finals matter more, and close
## finals / Grand Finals are the strongest shared history. Ordinary games
## only build heat when close, so random repeated fixtures do not manufacture
## rivalries by themselves.
static func record_match(store: Dictionary, result: Dictionary, year: int) -> Dictionary:
	var a := str(result.get("home", ""))
	var b := str(result.get("away", ""))
	if a == "" or b == "" or a == b:
		return {}
	var key := pair_key(a, b)
	var rec: Dictionary = store.get(key, {
		"clubs": key.split("|"), "score": 0, "meetings": 0, "close": 0,
		"finals": 0, "grand_finals": 0, "last_year": 0, "events": []
	})
	var uid := "%d:%s:%s:%s" % [year, str(result.get("label", result.get("round", ""))), a, b]
	for e in rec.get("events", []):
		if str((e as Dictionary).get("id", "")) == uid:
			return rec
	var scores: Array = result.get("score", [0, 0])
	var margin := 999
	if scores.size() >= 2:
		margin = absi(int(scores[0]) - int(scores[1]))
	var label := str(result.get("label", ""))
	var is_final := bool(result.get("is_final", false)) or label.contains("Final")
	var is_gf := label.contains("Grand Final")
	var points := 0
	var reason := ""
	if is_gf:
		points = 7 if margin <= CLOSE_MARGIN else 6
		reason = "Grand Final meeting"
		rec["grand_finals"] = int(rec["grand_finals"]) + 1
	elif is_final:
		points = 5 if margin <= CLOSE_MARGIN else 4
		reason = "close final" if margin <= CLOSE_MARGIN else "finals meeting"
	elif margin <= CLOSE_MARGIN:
		points = 2
		reason = "close game"
	if points == 0:
		return rec
	rec["meetings"] = int(rec["meetings"]) + 1
	if margin <= CLOSE_MARGIN:
		rec["close"] = int(rec["close"]) + 1
	if is_final:
		rec["finals"] = int(rec["finals"]) + 1
	rec["score"] = int(rec["score"]) + points
	rec["last_year"] = year
	var events: Array = rec["events"]
	events.append({"id": uid, "year": year, "reason": reason, "margin": margin, "points": points})
	if events.size() > 8:
		events.pop_front()
	store[key] = rec
	return rec


## Rivalries cool slowly, but shared history does not vanish overnight.
static func age(store: Dictionary, year: int) -> void:
	for key in store:
		var rec: Dictionary = store[key]
		var gap := year - int(rec.get("last_year", year))
		if gap >= 3:
			rec["score"] = maxi(0, int(rec.get("score", 0)) - (gap - 2))


static func dynamic(store: Dictionary, a: String, b: String) -> Dictionary:
	return store.get(pair_key(a, b), {})


static func state(store: Dictionary, a: String, b: String) -> String:
	if not established(a, b).is_empty():
		return "established"
	var score := int(dynamic(store, a, b).get("score", 0))
	if score >= RIVALS:
		return "rivals"
	if score >= BREWING:
		return "brewing"
	return ""


static func context(store: Dictionary, a: String, b: String) -> String:
	var fixed := established(a, b)
	if not fixed.is_empty():
		return str(fixed["name"])
	var rec := dynamic(store, a, b)
	if rec.is_empty():
		return ""
	match state(store, a, b):
		"rivals":
			return "A rivalry forged over %d finals meeting%s and %d close game%s." % [
				int(rec.get("finals", 0)), "" if int(rec.get("finals", 0)) == 1 else "s",
				int(rec.get("close", 0)), "" if int(rec.get("close", 0)) == 1 else "s"]
		"brewing":
			return "A rivalry is brewing after repeated high-stakes meetings."
	return ""
